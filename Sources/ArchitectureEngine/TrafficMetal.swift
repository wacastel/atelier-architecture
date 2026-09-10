import Foundation
import Metal
import simd

/// The city BLAS is never refit. A small, separately updateable traffic BLAS
/// shares world-space vertex/material buffers, with a two-instance identity TLAS.
/// Queue-ordered compute writes and refits precede every dependent tracing pass.
final class TrafficMetal {
    let fleet: TrafficFleet
    let staticTriangleCount: Int
    let acceleration: MTLAccelerationStructure
    let bottomLevel: MTLAccelerationStructure
    let tracePipelines: [MTLComputePipelineState]
    let surfacePipeline: MTLComputePipelineState
    private let transformPipeline: MTLComputePipelineState
    private let localVertices: MTLBuffer
    private let owners: MTLBuffer
    private let descriptor: MTLPrimitiveAccelerationStructureDescriptor
    private let topDescriptor: MTLInstanceAccelerationStructureDescriptor
    private let scratch: MTLBuffer
    private let topScratch: MTLBuffer
    private let device: MTLDevice
    private var encodedTime: Double?
    private var lastBuildTime: Double?
    private(set) var updateCount = 0
    private(set) var rebuildCount = 0
    private(set) var lightGrid: LightGrid
    private(set) var lightBuffer: MTLBuffer
    private(set) var lightRanges: MTLBuffer
    private(set) var lightIndices: MTLBuffer

    static func buffer<T>(_ values: [T], device: MTLDevice) throws -> MTLBuffer {
        guard !values.isEmpty,
              let buffer = values.withUnsafeBytes({ device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared) }) else { throw EngineError.message("Traffic buffer allocation failed.") }
        return buffer
    }
    init(fleet: TrafficFleet, staticTriangleCount: Int, staticAcceleration: MTLAccelerationStructure,
         vertices: MTLBuffer, device: MTLDevice, library: MTLLibrary, pipelineCache: MetalPipelineCache? = nil) throws {
        self.fleet=fleet; self.staticTriangleCount=staticTriangleCount; self.device=device
        func pipeline(_ name:String) throws -> MTLComputePipelineState {
            guard let function=library.makeFunction(name:name) else { throw EngineError.message("Missing traffic kernel: \(name)") }
            if let pipelineCache { return try pipelineCache.compute(function) }
            return try device.makeComputePipelineState(function:function)
        }
        tracePipelines = try ["pathTraceTrafficDay", "pathTraceTrafficDayInteriors", "pathTraceTrafficNight", "pathTraceTrafficDayIndexed", "pathTraceTrafficNightIndexed"].map(pipeline)
        surfacePipeline=try pipeline("primarySurfaceTraffic")
        transformPipeline=try pipeline("transformTraffic")
        localVertices=try Self.buffer(fleet.vertices,device:device)
        owners=try Self.buffer(fleet.owners,device:device)
        let initialLights=fleet.lights(transforms:fleet.transforms(at:0))
        lightGrid=LightGrid(lights:initialLights)
        lightBuffer=try Self.buffer(initialLights,device:device)
        lightRanges=try Self.buffer(lightGrid.ranges.isEmpty ? [SIMD2<UInt32>(0,0)]:lightGrid.ranges,device:device)
        lightIndices=try Self.buffer(lightGrid.indices.isEmpty ? [UInt32(0)]:lightGrid.indices,device:device)
        let geometry=MTLAccelerationStructureTriangleGeometryDescriptor()
        geometry.vertexBuffer=vertices
        geometry.vertexBufferOffset=staticTriangleCount*3*MemoryLayout<SceneVertex>.stride
        geometry.vertexStride=MemoryLayout<SceneVertex>.stride; geometry.vertexFormat = .float3
        geometry.triangleCount=fleet.triangleCount; geometry.opaque=true
        descriptor=MTLPrimitiveAccelerationStructureDescriptor()
        descriptor.geometryDescriptors=[geometry]; descriptor.usage=[.refit,.preferFastBuild]
        let sizes=device.accelerationStructureSizes(descriptor:descriptor)
        guard let bottom=device.makeAccelerationStructure(size:sizes.accelerationStructureSize),
              let scratch=device.makeBuffer(length:max(sizes.buildScratchBufferSize,sizes.refitScratchBufferSize),options:.storageModePrivate) else { throw EngineError.message("Traffic BVH allocation failed.") }
        bottomLevel=bottom; self.scratch=scratch; bottom.label="Moving traffic BVH"
        var instances:[MTLAccelerationStructureInstanceDescriptor]=[]
        for index in 0..<2 {
            var instance=MTLAccelerationStructureInstanceDescriptor()
            instance.transformationMatrix.columns=(MTLPackedFloat3Make(1,0,0),MTLPackedFloat3Make(0,1,0),MTLPackedFloat3Make(0,0,1),MTLPackedFloat3Make(0,0,0))
            instance.options = .opaque; instance.mask=0xFF
            instance.accelerationStructureIndex=UInt32(index)
            instances.append(instance)
        }
        topDescriptor=MTLInstanceAccelerationStructureDescriptor()
        topDescriptor.instancedAccelerationStructures=[staticAcceleration,bottom]
        topDescriptor.instanceDescriptorBuffer=try Self.buffer(instances,device:device)
        topDescriptor.instanceCount=2; topDescriptor.usage=[.refit,.preferFastBuild]
        let topSizes=device.accelerationStructureSizes(descriptor:topDescriptor)
        guard let top=device.makeAccelerationStructure(size:topSizes.accelerationStructureSize),
              let topScratch=device.makeBuffer(length:max(topSizes.buildScratchBufferSize,topSizes.refitScratchBufferSize),options:.storageModePrivate) else { throw EngineError.message("Traffic instance BVH allocation failed.") }
        acceleration=top; self.topScratch=topScratch; top.label="Immutable city and moving traffic instances"
    }
    func invalidate() { encodedTime=nil;lastBuildTime=nil }
    func encodeUpdate(_ command:MTLCommandBuffer, time:Double, vertices:MTLBuffer) throws {
        guard encodedTime != time else { return }
        let transforms=fleet.transforms(at:time)
        let matrices=try Self.buffer(transforms,device:device)
        let lights=fleet.lights(transforms:transforms)
        lightGrid=LightGrid(lights:lights)
        lightBuffer=try Self.buffer(lights,device:device)
        lightRanges=try Self.buffer(lightGrid.ranges.isEmpty ? [SIMD2<UInt32>(0,0)]:lightGrid.ranges,device:device)
        lightIndices=try Self.buffer(lightGrid.indices.isEmpty ? [UInt32(0)]:lightGrid.indices,device:device)
        guard let transform=command.makeComputeCommandEncoder() else { throw EngineError.message("Traffic transform encoder unavailable.") }
        transform.label="Transform only vehicle vertices"
        transform.setComputePipelineState(transformPipeline)
        transform.setBuffer(localVertices,offset:0,index:0)
        transform.setBuffer(owners,offset:0,index:1)
        transform.setBuffer(matrices,offset:0,index:2)
        transform.setBuffer(vertices,offset:staticTriangleCount*3*MemoryLayout<SceneVertex>.stride,index:3)
        var count=UInt32(fleet.vertices.count)
        transform.setBytes(&count,length:4,index:4)
        transform.dispatchThreads(MTLSize(width:fleet.vertices.count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:128,height:1,depth:1))
        transform.endEncoding()
        guard let encoder=command.makeAccelerationStructureCommandEncoder() else { throw EngineError.message("Traffic BVH update encoder unavailable.") }
        // Large scrubs/wraps and periodic topology refreshes rebuild only this
        // small BVH. The multi-million-triangle city is always left untouched.
        let rebuild=encodedTime == nil || abs(time-(lastBuildTime ?? time))>2 || abs(time-(encodedTime ?? time))>0.25
        if rebuild {
            encoder.build(accelerationStructure:bottomLevel,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0)
            lastBuildTime=time; rebuildCount += 1
        } else {
            encoder.refit(sourceAccelerationStructure:bottomLevel,descriptor:descriptor,destinationAccelerationStructure:nil,scratchBuffer:scratch,scratchBufferOffset:0)
        }
        if encodedTime == nil {
            encoder.build(accelerationStructure:acceleration,descriptor:topDescriptor,scratchBuffer:topScratch,scratchBufferOffset:0)
        } else {
            encoder.refit(sourceAccelerationStructure:acceleration,descriptor:topDescriptor,destinationAccelerationStructure:nil,scratchBuffer:topScratch,scratchBufferOffset:0)
        }
        encoder.endEncoding(); encodedTime=time; updateCount += 1
    }
    /// All per-frame buffers are immutable after creation and retained by the
    /// command encoder, so two frames in flight never race CPU pointer writes.
    func bind(_ encoder:MTLComputeCommandEncoder, moving:Bool) {
        var counts=SIMD4<UInt32>(UInt32(staticTriangleCount),UInt32(fleet.vehicles.count),UInt32(fleet.vehicles.count*3),moving ? 1:0)
        var header=lightGrid.header
        encoder.setBytes(&counts,length:16,index:9)
        encoder.setBytes(&header,length:MemoryLayout<LightGrid.Header>.stride,index:10)
        encoder.setBuffer(lightRanges,offset:0,index:11)
        encoder.setBuffer(lightIndices,offset:0,index:12)
        encoder.setBuffer(lightBuffer,offset:0,index:13)
        // TLAS indirection alone does not declare residency of its children.
        encoder.useResource(bottomLevel,usage:.read)
        if let city=topDescriptor.instancedAccelerationStructures?.first { encoder.useResource(city,usage:.read) }
    }
}
