import Foundation
import Metal
import simd

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

    init(scene:SceneData, fleet:TrafficFleet, device:MTLDevice, library:MTLLibrary) throws {
        self.device=device; self.fleet=fleet; staticTriangleCount=scene.triangleCount
        rasterSampleCount = device.supportsTextureSampleCount(4) ? 4 : device.supportsTextureSampleCount(2) ? 2 : 1
        let sampleCount=rasterSampleCount
        batches=RasterGeometry.batches(vertices:scene.vertices,indices:scene.materialIndices,materials:scene.materials)
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
