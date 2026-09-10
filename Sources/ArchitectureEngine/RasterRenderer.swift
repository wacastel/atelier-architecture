import Foundation
import Metal
import simd
import CryptoKit

/// Conservative, contiguous spatial batches. The original unindexed vertex and
/// material buffers are never reordered or copied. No triangle-size LOD removes
/// details: a batch is omitted only when its complete AABB is outside the frustum.
struct RasterBatch {
    var firstTriangle: Int
    var triangleCount: Int
    var minimum: SIMD3<Float>
    var maximum: SIMD3<Float>
    var transparent: Bool
    var center: SIMD3<Float> { (minimum + maximum) * 0.5 }
}
struct RasterFrustum {
    var planes: [SIMD4<Float>]
    init(frame: FrameUniforms) {
        let f = frame.forward.xyz, r = simd_normalize(frame.right.xyz), u = simd_normalize(frame.up.xyz)
        let sx = simd_length(frame.right.xyz), sy = simd_length(frame.up.xyz)
        let o = frame.origin.xyz
        func plane(_ normal: SIMD3<Float>, _ offset: Float = 0) -> SIMD4<Float> {
            SIMD4(normal, -simd_dot(normal, o) + offset)
        }
        // Infinite far plane avoids clipping this continuous city's skyline.
        planes = [plane(f,-0.04), plane(f*sx+r), plane(f*sx-r), plane(f*sy+u), plane(f*sy-u)]
    }
    func contains(_ batch: RasterBatch) -> Bool {
        for p in planes {
            let positive = SIMD3<Float>(p.x >= 0 ? batch.maximum.x:batch.minimum.x,
                                        p.y >= 0 ? batch.maximum.y:batch.minimum.y,
                                        p.z >= 0 ? batch.maximum.z:batch.minimum.z)
            if simd_dot(p.xyz,positive)+p.w < -0.002 { return false }
        }
        return true
    }
}
enum RasterGeometry {
    static func batches(vertices: [SceneVertex], indices: [UInt32], materials: [SceneMaterial]) -> [RasterBatch] {
        var result: [RasterBatch] = []
        result.reserveCapacity(indices.count / 512 + 1)
        // Small initial blocks keep repeated city facades spatially coherent.
        // Merge nearby blocks to reduce CPU encoding and vertex invocation setup.
        for first in stride(from:0,to:indices.count,by:512) {
            let end = min(first+512,indices.count)
            var lo=SIMD3<Float>(repeating:.greatestFiniteMagnitude), hi = -lo
            var transmission=false
            for triangle in first..<end {
                transmission = transmission || materials[Int(indices[triangle])].properties.w > 0
                for vertex in triangle*3..<triangle*3+3 {
                    let p=vertices[vertex].position.xyz
                    lo=simd_min(lo,p); hi=simd_max(hi,p)
                }
            }
            if let last=result.last, last.transparent == transmission, last.triangleCount+end-first <= 8192 {
                let combinedLo=simd_min(last.minimum,lo), combinedHi=simd_max(last.maximum,hi)
                if simd_length_squared(combinedHi-combinedLo) <= 128*128 {
                    result[result.count-1].triangleCount += end-first
                    result[result.count-1].minimum=combinedLo; result[result.count-1].maximum=combinedHi
                    continue
                }
            }
            result.append(RasterBatch(firstTriangle:first,triangleCount:end-first,minimum:lo,maximum:hi,transparent:transmission))
        }
        return result
    }
}

/// Native depth-tested raster rendering; this type has no acceleration-structure
/// member, intersection function, compute ray pass, or traffic BVH update path.
final class RasterRenderer {
    private let device: MTLDevice
    private let opaquePipeline: MTLRenderPipelineState
    private let glassPipeline: MTLRenderPipelineState
    private let skyPipeline: MTLRenderPipelineState
    private let opaqueDepth: MTLDepthStencilState
    private let glassDepth: MTLDepthStencilState
    private let skyDepth: MTLDepthStencilState
    private let batches: [RasterBatch]
    let cacheStatistics: [String: Any]
    private let staticTriangleCount: Int
    private let fleet: TrafficFleet
    private let localTraffic: MTLBuffer?
    private let trafficOwners: MTLBuffer?
    private var color: MTLTexture?
    private var multisampleColor: MTLTexture?
    let rasterSampleCount: Int
    private var depth: MTLTexture?
    private var lastTrafficTime: Double?
    private var transforms: MTLBuffer?
    private(set) var frameCount = 0
    private(set) var trafficTransformCount = 0
    private(set) var visibleTriangleCount = 0
    private(set) var visibleBatchCount = 0
    var batchCount: Int { batches.count }
    private(set) var transparentBatchCount = 0
    private(set) var cullingMilliseconds: Double = 0

    init(scene:SceneData, fleet:TrafficFleet, device:MTLDevice, library:MTLLibrary, pipelineCache:MetalPipelineCache? = nil,
         cacheDirectory:URL? = nil, cacheKey:String = "", forceRebuildCache:Bool = false) throws {
        self.device=device; self.fleet=fleet; staticTriangleCount=scene.triangleCount
        rasterSampleCount = device.supportsTextureSampleCount(4) ? 4 : device.supportsTextureSampleCount(2) ? 2 : 1
        let sampleCount=rasterSampleCount
        let batchStart=ProcessInfo.processInfo.systemUptime
        let cached=RasterBatchCache.loadOrBuild(scene:scene,directory:cacheDirectory,key:cacheKey,forceRebuild:forceRebuildCache)
        batches=cached.batches
        cacheStatistics=["hit":cached.hit,"saved":cached.saved,"batches":batches.count,
            "seconds":ProcessInfo.processInfo.systemUptime-batchStart,"error":cached.error ?? ""]
        func pipeline(vertex:String,fragment:String,blending:Bool=false) throws -> MTLRenderPipelineState {
            let desc=MTLRenderPipelineDescriptor()
            desc.vertexFunction=library.makeFunction(name:vertex);desc.fragmentFunction=library.makeFunction(name:fragment)
            desc.colorAttachments[0].pixelFormat = .rgba16Float
            desc.depthAttachmentPixelFormat = .depth32Float
            desc.rasterSampleCount=sampleCount
            if blending {
                let a=desc.colorAttachments[0]!
                a.isBlendingEnabled=true;a.rgbBlendOperation = .add;a.alphaBlendOperation = .add
                a.sourceRGBBlendFactor = .sourceAlpha;a.destinationRGBBlendFactor = .oneMinusSourceAlpha
                // Alpha retains opaque surface distance for selection; glass
                // opacity still controls only the existing RGB blend factors.
                a.sourceAlphaBlendFactor = .zero;a.destinationAlphaBlendFactor = .one
            }
            if let pipelineCache { return try pipelineCache.render(desc) }
            return try device.makeRenderPipelineState(descriptor:desc)
        }
        opaquePipeline=try pipeline(vertex:"rasterVertex",fragment:"rasterOpaqueFragment")
        glassPipeline=try pipeline(vertex:"rasterVertex",fragment:"rasterGlassFragment",blending:true)
        skyPipeline=try pipeline(vertex:"fullscreenVertex",fragment:"rasterSkyFragment")
        func depthState(_ write:Bool,_ compare:MTLCompareFunction) throws -> MTLDepthStencilState {
            let desc=MTLDepthStencilDescriptor();desc.isDepthWriteEnabled=write;desc.depthCompareFunction=compare
            guard let state=device.makeDepthStencilState(descriptor:desc) else { throw EngineError.message("Raster depth state unavailable.") };return state
        }
        opaqueDepth=try depthState(true,.greaterEqual);glassDepth=try depthState(false,.greaterEqual);skyDepth=try depthState(false,.always)
        if fleet.vertices.isEmpty { localTraffic=nil;trafficOwners=nil }
        else {
            localTraffic=try TrafficMetal.buffer(fleet.vertices,device:device)
            trafficOwners=try TrafficMetal.buffer(fleet.owners,device:device)
        }
    }
    func invalidate() { lastTrafficTime=nil }
    func resize(width:Int,height:Int) throws {
        guard color?.width != width || color?.height != height else { return }
        func texture(_ format:MTLPixelFormat,_ label:String,samples:Int=1) throws -> MTLTexture {
            let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:width,height:height,mipmapped:false)
            d.storageMode = .private;d.usage = samples>1 ? [.renderTarget]:[.renderTarget,.shaderRead]
            if samples>1 {d.textureType = .type2DMultisample;d.sampleCount=samples}
            guard let result=device.makeTexture(descriptor:d) else {throw EngineError.message("Raster target allocation failed.")}
            result.label=label;return result
        }
        color=try texture(.rgba16Float,"Raster linear HDR")
        multisampleColor=rasterSampleCount>1 ? try texture(.rgba16Float,"Raster multisample HDR",samples:rasterSampleCount):nil
        depth=try texture(.depth32Float,"Raster reversed-Z depth",samples:rasterSampleCount)
    }
    func encode(_ command:MTLCommandBuffer, frame:FrameUniforms, sceneTime:Double,
                vertices:MTLBuffer, indices:MTLBuffer, materials:MTLBuffer,
                lights:MTLBuffer, lightGrid:LightGrid, lightRanges:MTLBuffer, lightIndices:MTLBuffer) throws -> MTLTexture {
        try resize(width:Int(frame.viewport.x),height:Int(frame.viewport.y))
        guard let color, let depth else { throw EngineError.message("Raster targets unavailable.") }
        if !fleet.vertices.isEmpty && lastTrafficTime != sceneTime {
            transforms=try TrafficMetal.buffer(fleet.transforms(at:sceneTime),device:device)
            lastTrafficTime=sceneTime;trafficTransformCount += 1
        }
        let start=Date(),frustum=RasterFrustum(frame:frame)
        var visible=batches.filter { frustum.contains($0) }
        // Front-to-back improves depth rejection; glass is submitted afterward
        // back-to-front without depth writes. Sorting is at conservative batch
        // granularity, so intersecting glass sheets remain an approximation.
        visible.sort { simd_distance_squared($0.center,frame.origin.xyz) < simd_distance_squared($1.center,frame.origin.xyz) }
        visibleTriangleCount=visible.reduce(0){$0+$1.triangleCount}+fleet.triangleCount
        visibleBatchCount=visible.count
        transparentBatchCount=visible.filter(\.transparent).count
        cullingMilliseconds=Date().timeIntervalSince(start)*1000
        let pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=multisampleColor ?? color;pass.colorAttachments[0].loadAction = .clear
        if multisampleColor != nil {
            pass.colorAttachments[0].resolveTexture=color
            pass.colorAttachments[0].storeAction = .multisampleResolve
        } else {pass.colorAttachments[0].storeAction = .store}
        pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare;pass.depthAttachment.clearDepth=0
        guard let encoder=command.makeRenderCommandEncoder(descriptor:pass) else {throw EngineError.message("Raster encoder unavailable.")}
        encoder.label="Ray tracing OFF — native raster geometry, sky and glass"
        var u=frame,header=lightGrid.header,draw=SIMD4<UInt32>(0,UInt32(staticTriangleCount),0,0)
        encoder.setCullMode(.none) // authored thin sheets and museum interiors are two-sided
        encoder.setFragmentBytes(&u,length:MemoryLayout<FrameUniforms>.stride,index:0)
        encoder.setFragmentBuffer(materials,offset:0,index:3)
        encoder.setFragmentBuffer(lights,offset:0,index:5)
        encoder.setFragmentBytes(&header,length:MemoryLayout<LightGrid.Header>.stride,index:6)
        encoder.setFragmentBuffer(lightRanges,offset:0,index:7);encoder.setFragmentBuffer(lightIndices,offset:0,index:8)
        encoder.setRenderPipelineState(skyPipeline);encoder.setDepthStencilState(skyDepth)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
        encoder.setVertexBytes(&u,length:MemoryLayout<FrameUniforms>.stride,index:0)
        encoder.setVertexBuffer(vertices,offset:0,index:1);encoder.setVertexBuffer(indices,offset:0,index:2)
        encoder.setVertexBytes(&draw,length:16,index:4)
        // Dummy bindings are valid even for the nontraffic specialization's
        // unused resources and avoid validation warnings from optional buffers.
        encoder.setVertexBuffer(trafficOwners ?? indices,offset:0,index:5)
        encoder.setVertexBuffer(transforms ?? vertices,offset:0,index:6)
        encoder.setRenderPipelineState(opaquePipeline);encoder.setDepthStencilState(opaqueDepth)
        for batch in visible { encoder.drawPrimitives(type:.triangle,vertexStart:batch.firstTriangle*3,vertexCount:batch.triangleCount*3) }
        if let localTraffic, fleet.triangleCount>0 {
            draw.x=1;encoder.setVertexBytes(&draw,length:16,index:4);encoder.setVertexBuffer(localTraffic,offset:0,index:1)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:fleet.vertices.count)
            draw.x=0;encoder.setVertexBytes(&draw,length:16,index:4);encoder.setVertexBuffer(vertices,offset:0,index:1)
        }
        if transparentBatchCount>0 {
            encoder.setRenderPipelineState(glassPipeline);encoder.setDepthStencilState(glassDepth)
            for batch in visible.reversed() where batch.transparent { encoder.drawPrimitives(type:.triangle,vertexStart:batch.firstTriangle*3,vertexCount:batch.triangleCount*3) }
        }
        encoder.endEncoding();frameCount += 1
        return color
    }
}

/// A small derived cache avoids scanning all 140+ million city vertices on
/// every launch. Records use explicit numeric fields, never raw Swift Bools or
/// pointers; version, source key, layout, checksum, and ranges are validated.
enum RasterBatchCache {
    private struct Record {
        var first: UInt32 = 0
        var count: UInt32 = 0
        var transparent: UInt32 = 0
        var reserved: UInt32 = 0
        var minimum = SIMD4<Float>(repeating: 0)
        var maximum = SIMD4<Float>(repeating: 0)
    }
    private struct Header: Codable {
        var version: Int
        var key: String
        var triangles: Int
        var materials: Int
        var count: Int
        var stride: Int
        var checksum: String
    }
    struct Result {
        let batches: [RasterBatch]
        let hit: Bool
        let saved: Bool
        let error: String?
    }
    static func loadOrBuild(scene: SceneData, directory: URL?, key: String, forceRebuild: Bool) -> Result {
        guard let directory, !key.isEmpty else {
            return Result(batches: RasterGeometry.batches(vertices:scene.vertices,indices:scene.materialIndices,materials:scene.materials),hit:false,saved:false,error:nil)
        }
        let url = directory.appendingPathComponent("raster-batches-v1.cache")
        var error: String?
        if !forceRebuild, FileManager.default.fileExists(atPath:url.path) {
            do { return Result(batches:try load(url,scene:scene,key:key),hit:true,saved:false,error:nil) }
            catch let failure { error = failure.localizedDescription }
        }
        let batches=RasterGeometry.batches(vertices:scene.vertices,indices:scene.materialIndices,materials:scene.materials)
        do {
            try save(batches,url:url,scene:scene,key:key)
            return Result(batches:batches,hit:false,saved:true,error:error)
        } catch let failure {
            return Result(batches:batches,hit:false,saved:false,error:failure.localizedDescription)
        }
    }
    private static func invalid() -> NSError { NSError(domain:"Atelier.RasterBatchCache",code:1,userInfo:[NSLocalizedDescriptionKey:"Raster batch cache is incompatible or damaged; regenerated from the scene."]) }
    private static func hash(_ data: Data) -> String { SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined() }
    private static func load(_ url:URL, scene:SceneData, key:String) throws -> [RasterBatch] {
        let maxRecords=(scene.triangleCount+511)/512
        let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size>=8, size<=65544+maxRecords*48 else { throw invalid() }
        let data=try Data(contentsOf:url)
        guard data.count>=8 else { throw invalid() }
        let headerBytes=data.prefix(8).enumerated().reduce(UInt64(0)) { $0 | UInt64($1.element) << UInt64($1.offset*8) }
        guard headerBytes<=65536, headerBytes<=UInt64(data.count-8) else { throw invalid() }
        let split=8+Int(headerBytes)
        let header=try JSONDecoder().decode(Header.self,from:data.subdata(in:8..<split))
        let recordSize=MemoryLayout<Record>.stride
        guard header.version==1, header.key==key, header.triangles==scene.triangleCount,
              header.materials==scene.materials.count, header.count>=0,
              header.count<=maxRecords, header.stride==recordSize,
              recordSize==48, header.count==(data.count-split)/recordSize,
              (data.count-split)%recordSize==0 else { throw invalid() }
        let payload=data.subdata(in:split..<data.count)
        guard hash(payload)==header.checksum else { throw invalid() }
        var records=[Record](repeating:Record(),count:header.count)
        records.withUnsafeMutableBytes { target in _ = payload.copyBytes(to:target) }
        var expected=0, batches:[RasterBatch]=[]
        batches.reserveCapacity(header.count)
        for record in records {
            let count=Int(record.count),lo=record.minimum,hi=record.maximum
            guard Int(record.first)==expected, count>0, count<=8192,
                  count<=scene.triangleCount-expected, record.transparent<=1, record.reserved==0,
                  lo.w==0,hi.w==0,lo.x.isFinite,lo.y.isFinite,lo.z.isFinite,
                  hi.x.isFinite,hi.y.isFinite,hi.z.isFinite,
                  lo.x<=hi.x,lo.y<=hi.y,lo.z<=hi.z else { throw invalid() }
            batches.append(RasterBatch(firstTriangle:expected,triangleCount:count,
                minimum:lo.xyz,maximum:hi.xyz,transparent:record.transparent==1))
            expected+=count
        }
        guard expected==scene.triangleCount else { throw invalid() }
        return batches
    }
    private static func save(_ batches:[RasterBatch],url:URL,scene:SceneData,key:String) throws {
        guard scene.triangleCount<=Int(UInt32.max) else { throw invalid() }
        let records=batches.map { batch in
            Record(first:UInt32(batch.firstTriangle),count:UInt32(batch.triangleCount),
                transparent:batch.transparent ? 1:0,reserved:0,
                minimum:SIMD4(batch.minimum,0),maximum:SIMD4(batch.maximum,0))
        }
        let payload=records.withUnsafeBytes { Data($0) }
        let header=Header(version:1,key:key,triangles:scene.triangleCount,
            materials:scene.materials.count,count:records.count,stride:MemoryLayout<Record>.stride,checksum:hash(payload))
        let encoded=try JSONEncoder().encode(header)
        var size=UInt64(encoded.count).littleEndian
        var data=withUnsafeBytes(of:&size) { Data($0) }
        data.append(encoded);data.append(payload)
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:url,options:.atomic)
    }
}
