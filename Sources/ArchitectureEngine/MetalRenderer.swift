import Foundation
import Metal
import MetalKit
import AppKit
import simd

struct RenderOptions: Equatable {
    var exposure: Float = 1.0
    var bounces: Float = 3
    var lighting: Int = 0
    var sunsetBuildingLights: Bool = true
    var denoising: Bool = true
    var regularization: Bool = true
    var lowDiscrepancySampling: Bool = true
    var indexedLighting: Bool = true
    var rayTracing: Bool = true
    var directRayTracing: Bool = false
    var hazeDensity: Float = 0 // metres⁻¹; zero uses the established day/night atmosphere
    var architectureLightsEnabled: Bool { lighting != 3 || sunsetBuildingLights }
    var sunsetState: Float { lighting == 3 ? (sunsetBuildingLights ? 1 : 2) : 0 }
}

enum EngineError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(m) = self { return m }; return nil }
}

final class MetalRenderer {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let tracePipeline: MTLComputePipelineState
    private let directPipeline: MTLComputePipelineState
    private let directTrafficPipeline: MTLComputePipelineState
    let nightTracePipeline: MTLComputePipelineState
    let dayInteriorTracePipeline: MTLComputePipelineState
    let indexedNightTracePipeline: MTLComputePipelineState
    let indexedDayInteriorTracePipeline: MTLComputePipelineState
    let presentPipeline: MTLRenderPipelineState
    private let focusedPresentPipeline: MTLRenderPipelineState
    private let directPresentPipeline: MTLRenderPipelineState
    private let directFocusedPresentPipeline: MTLRenderPipelineState
    var focusHighlight = FocusHighlightData(volumes: [])
    private var uploadedHighlight: FocusHighlightData?
    private var highlightBuffer: MTLBuffer?
    let surfacePipeline: MTLComputePipelineState
    let temporalPipeline: MTLComputePipelineState
    let spatialPipeline: MTLComputePipelineState
    let lightBuffer: MTLBuffer
    let lightCount: Int
    let dayInteriorLightBuffer: MTLBuffer
    let dayInteriorLightCount: Int
    private let nightLightGrid:LightGrid
    private let dayLightGrid:LightGrid
    private let nightLightRanges:MTLBuffer
    private let nightLightIndices:MTLBuffer
    private let dayLightRanges:MTLBuffer
    private let dayLightIndices:MTLBuffer
    private let traffic: TrafficMetal?
    private let rasterRenderer: RasterRenderer
    private(set) var rayTracingDispatchCount = 0
    private(set) var directRayDispatchCount = 0
    private(set) var surfaceGuideDispatchCount = 0
    var rasterFrameCount: Int { rasterRenderer.frameCount }
    var rasterTrafficTransformCount: Int { rasterRenderer.trafficTransformCount }
    var rasterStatistics: [String: Any] {
        ["frames":rasterRenderer.frameCount,"batches":rasterRenderer.batchCount,"rasterSamples":rasterRenderer.rasterSampleCount,
         "visibleBatches":rasterRenderer.visibleBatchCount,"visibleTriangles":rasterRenderer.visibleTriangleCount,
         "transparentBatches":rasterRenderer.transparentBatchCount,"cullingMilliseconds":rasterRenderer.cullingMilliseconds,
         "trafficTransforms":rasterRenderer.trafficTransformCount,"localLightBudget":64,
         "rayDispatches":rayTracingDispatchCount,"surfaceGuideDispatches":surfaceGuideDispatchCount,
         "rayTracingTrafficUpdates":trafficUpdateCount]
    }
    private(set) var sceneTime: Double = 0
    private var trafficMoving = false
    private let hasAnimatedProjection: Bool
    private var projectionMoving = false
    var trafficVehicleCount: Int { traffic?.fleet.vehicles.count ?? 0 }
    var trafficUpdateCount: Int { traffic?.updateCount ?? 0 }
    let hasTransmission: Bool
    private var worldGuides: [MTLTexture] = []
    private var normalGuides: [MTLTexture] = []
    private var albedoGuide: MTLTexture?
    private var histories: [MTLTexture] = []
    private var filters: [MTLTexture] = []
    private var historyIndex = 0
    private var historyValid = false
    private var previousFrame: FrameUniforms?
    private var previousOptions: RenderOptions?
    private var finalFiltered: MTLTexture?
    private var previousPose: CameraPose?
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let materialBuffer: MTLBuffer
    let accelerationStructure: MTLAccelerationStructure
    let staticGeometrySections: [[String:Int]]
    let triangleCount: Int
    let detailCount: Int
    let buildSeconds: Double
    var accumulation: MTLTexture?
    var width = 0, height = 0
    var sampleCount: UInt32 = 0
    var frameSeed: UInt32 = 0
    private let metricsLock = NSLock()
    private var gpuTime: Double = 0
    private var gpuError: String?
    var lastGPUTime: Double {
        get { metricsLock.lock(); defer { metricsLock.unlock() }; return gpuTime }
        set { metricsLock.lock(); gpuTime = newValue; metricsLock.unlock() }
    }
    func takeGPUError() -> String? {
        metricsLock.lock(); defer { metricsLock.unlock() }
        let result = gpuError; gpuError = nil; return result
    }
    var lastUniforms: FrameUniforms?
    private let semaphore = DispatchSemaphore(value: 2)
    var allocatedMB: Double { Double(device.currentAllocatedSize) / 1048576 }

    init(scene: SceneData, device: MTLDevice) throws {
        let start = Date()
        self.device = device
        guard device.supportsRaytracing else { throw EngineError.message("This GPU does not support Metal ray tracing.") }
        guard let queue = device.makeCommandQueue() else { throw EngineError.message("Could not create Metal command queue.") }
        self.queue = queue
        let resourceBundle = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle")) } ?? Bundle.module
        guard let url = resourceBundle.url(forResource: "Renderer", withExtension: "metal", subdirectory: "Resources") else { throw EngineError.message("Renderer.metal is missing from the application resources.") }
        guard let denoiseURL = resourceBundle.url(forResource: "Denoise", withExtension: "metal", subdirectory: "Resources") else { throw EngineError.message("Denoising shader resource is missing.") }
        guard let rasterURL = resourceBundle.url(forResource: "Raster", withExtension: "metal", subdirectory: "Resources") else { throw EngineError.message("Raster shader resource is missing.") }
        guard let directURL = resourceBundle.url(forResource: "DirectRay", withExtension: "metal", subdirectory: "Resources") else { throw EngineError.message("Direct ray tracing shader resource is missing.") }
        let source = try String(contentsOf: url,encoding:.utf8) + "\n" + String(contentsOf: denoiseURL,encoding:.utf8) + "\n" + String(contentsOf:rasterURL,encoding:.utf8) + "\n" + String(contentsOf:directURL,encoding:.utf8)
        let options = MTLCompileOptions()
        options.languageVersion = .version3_1
        let library = try device.makeLibrary(source: source, options: options)
        guard let kernel = library.makeFunction(name: "pathTrace"), let vertex = library.makeFunction(name: "fullscreenVertex"), let fragment = library.makeFunction(name: "presentFragment") else { throw EngineError.message("Metal shader entry points are missing.") }
        tracePipeline = try device.makeComputePipelineState(function: kernel)
        guard let direct=library.makeFunction(name:"directRayTrace"),let directTraffic=library.makeFunction(name:"directRayTraceTraffic") else { throw EngineError.message("Direct ray tracing entry points are missing.") }
        directPipeline=try device.makeComputePipelineState(function:direct)
        directTrafficPipeline=try device.makeComputePipelineState(function:directTraffic)
        guard let nightKernel = library.makeFunction(name:"pathTraceNight") else { throw EngineError.message("Night ray tracing shader is missing.") }
        nightTracePipeline = try device.makeComputePipelineState(function:nightKernel)
        guard let dayInteriorKernel=library.makeFunction(name:"pathTraceDayInteriors") else { throw EngineError.message("Daylight interior ray tracing shader is missing.") }
        dayInteriorTracePipeline=try device.makeComputePipelineState(function:dayInteriorKernel)
        guard let indexedNightKernel=library.makeFunction(name:"pathTraceNightIndexed"),
              let indexedDayKernel=library.makeFunction(name:"pathTraceDayInteriorsIndexed") else {throw EngineError.message("Indexed lighting ray tracing shaders are missing.")}
        indexedNightTracePipeline=try device.makeComputePipelineState(function:indexedNightKernel)
        indexedDayInteriorTracePipeline=try device.makeComputePipelineState(function:indexedDayKernel)
        guard let surface = library.makeFunction(name: "primarySurface"),
              let temporal = library.makeFunction(name: "temporalResolve"),
              let spatial = library.makeFunction(name: "spatialFilter") else { throw EngineError.message("Reconstruction shader entry points are missing.") }
        surfacePipeline = try device.makeComputePipelineState(function: surface)
        temporalPipeline = try device.makeComputePipelineState(function: temporal)
        spatialPipeline = try device.makeComputePipelineState(function: spatial)
        let presentation = MTLRenderPipelineDescriptor()
        presentation.vertexFunction = vertex; presentation.fragmentFunction = fragment
        presentation.colorAttachments[0].pixelFormat = .bgra8Unorm
        presentPipeline = try device.makeRenderPipelineState(descriptor: presentation)
        presentation.fragmentFunction = library.makeFunction(name:"focusedPresentFragment")
        focusedPresentPipeline = try device.makeRenderPipelineState(descriptor:presentation)
        presentation.fragmentFunction = library.makeFunction(name:"directPresentFragment")
        directPresentPipeline = try device.makeRenderPipelineState(descriptor:presentation)
        presentation.fragmentFunction = library.makeFunction(name:"directFocusedPresentFragment")
        directFocusedPresentPipeline = try device.makeRenderPipelineState(descriptor:presentation)
        guard !scene.vertices.isEmpty, scene.vertices.count % 3 == 0,
              scene.materialIndices.count == scene.triangleCount,
              scene.materialIndices.allSatisfy({ Int($0) < scene.materials.count }) else { throw EngineError.message("Invalid scene triangle or material buffers.") }
        func buffer<T>(_ values: [T]) throws -> MTLBuffer {
            let result = values.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }
            guard let result else { throw EngineError.message("Could not allocate scene buffer.") }; return result
        }
        let fleet=TrafficFleet(lanes:scene.trafficLanes)
        if fleet.vertices.isEmpty {
            vertexBuffer=try buffer(scene.vertices)
        } else {
            let staticBytes=scene.vertices.count*MemoryLayout<SceneVertex>.stride
            let trafficBytes=fleet.vertices.count*MemoryLayout<SceneVertex>.stride
            guard let combined=device.makeBuffer(length:staticBytes+trafficBytes,options:.storageModeShared) else { throw EngineError.message("Scene and traffic vertex allocation failed.") }
            _ = scene.vertices.withUnsafeBytes { memcpy(combined.contents(),$0.baseAddress!,staticBytes) }
            // Traffic starts in local coordinates and is GPU-transformed before
            // its first BLAS build. Static geometry always reads only the prefix.
            _ = fleet.vertices.withUnsafeBytes { memcpy(combined.contents().advanced(by:staticBytes),$0.baseAddress!,trafficBytes) }
            vertexBuffer=combined
        }
        vertexBuffer.label = "Unified static vertices and updateable vehicle tail"
        indexBuffer = try buffer(scene.materialIndices + fleet.materialIndices.map{$0+UInt32(scene.materials.count)}); indexBuffer.label = "Triangle materials"
        materialBuffer = try buffer(scene.materials + fleet.materials); materialBuffer.label = "Architectural materials"
        lightCount = scene.lights.count
        hasTransmission = scene.materials.contains { $0.properties.w > 0 }
        hasAnimatedProjection = scene.materials.contains { Int($0.properties.z.rounded()) == 17 }
        let lights = scene.lights.isEmpty ? [SceneLight(positionRadius:.zero,directionCone:.zero,colorPower:.zero,parameters:.zero)] : scene.lights
        lightBuffer = try buffer(lights); lightBuffer.label = "Architectural lighting"
        let interiorLights=scene.lights.filter{$0.parameters.z>0.5}
        dayInteriorLightCount=interiorLights.count
        dayInteriorLightBuffer=try buffer(interiorLights.isEmpty ? [SceneLight(positionRadius:.zero,directionCone:.zero,colorPower:.zero,parameters:.zero)] : interiorLights)
        dayInteriorLightBuffer.label="Always-on interior lighting"
        nightLightGrid=LightGrid(lights:scene.lights)
        dayLightGrid=LightGrid(lights:interiorLights)
        nightLightRanges=try buffer(nightLightGrid.ranges.isEmpty ? [SIMD2<UInt32>(0,0)]:nightLightGrid.ranges)
        nightLightIndices=try buffer(nightLightGrid.indices.isEmpty ? [UInt32(0)]:nightLightGrid.indices)
        dayLightRanges=try buffer(dayLightGrid.ranges.isEmpty ? [SIMD2<UInt32>(0,0)]:dayLightGrid.ranges)
        dayLightIndices=try buffer(dayLightGrid.indices.isEmpty ? [UInt32(0)]:dayLightGrid.indices)
        triangleCount = scene.triangleCount + fleet.triangleCount; detailCount = scene.detailCount + fleet.vehicles.count
        let descriptor = MTLPrimitiveAccelerationStructureDescriptor()
        let geometries = GeometryPartition.descriptors(vertexBuffer: vertexBuffer, triangleCount: scene.triangleCount)
        descriptor.geometryDescriptors = geometries
        staticGeometrySections = geometries.map { ["vertexBufferOffsetBytes":$0.vertexBufferOffset,
            "triangleCount":$0.triangleCount,"vertexSpanBytes":$0.triangleCount*3*MemoryLayout<SceneVertex>.stride] }
        let sizes = device.accelerationStructureSizes(descriptor: descriptor)
        guard let acceleration = device.makeAccelerationStructure(size: sizes.accelerationStructureSize),
              let scratch = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate),
              let command = queue.makeCommandBuffer(), let encoder = command.makeAccelerationStructureCommandEncoder() else { throw EngineError.message("Could not allocate ray tracing acceleration structure.") }
        accelerationStructure = acceleration; acceleration.label = scene.name + " static triangle BVH"
        encoder.build(accelerationStructure: acceleration, descriptor: descriptor, scratchBuffer: scratch, scratchBufferOffset: 0)
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        traffic = fleet.vertices.isEmpty ? nil : try TrafficMetal(fleet:fleet,staticTriangleCount:scene.triangleCount,staticAcceleration:acceleration,vertices:vertexBuffer,device:device,library:library)
        rasterRenderer = try RasterRenderer(scene:scene,fleet:fleet,device:device,library:library)
        buildSeconds = Date().timeIntervalSince(start)
    }

    /// Nonthrowing absolute timeline input. Calling with the same time is a
    /// strict no-op, so paused views keep their BVH and progressive convergence.
    func setSceneTime(_ seconds: Double) {
        let seconds=seconds.isFinite ? seconds:0
        guard seconds != sceneTime else { return }
        sceneTime=seconds
        if traffic != nil { trafficMoving=true; resetAccumulation() }
        if hasAnimatedProjection { projectionMoving=true; resetAccumulation() }
    }
    func resetAccumulation() { sampleCount = 0 }
    /// Call after stopping submissions, before replacing a location's resources.
    func waitUntilIdle() {
        guard let fence = queue.makeCommandBuffer() else { return }
        fence.commit(); fence.waitUntilCompleted()
    }
    func resetReconstruction() { historyValid = false; finalFiltered = nil; previousFrame = nil }

    func resize(width: Int, height: Int, rayTracing: Bool = true) throws {
        guard width > 0 && height > 0 && width <= 8192 && height <= 8192 else { throw EngineError.message("Render size must be between 1 and 8192 pixels per axis.") }
        if !rayTracing {
            try rasterRenderer.resize(width:width,height:height)
            if width != self.width || height != self.height { resetAccumulation();resetReconstruction() }
            self.width=width;self.height=height
            return
        }
        guard width != self.width || height != self.height || accumulation?.width != width || accumulation?.height != height else { return }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
        desc.storageMode = .private; desc.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: desc) else { throw EngineError.message("Could not allocate HDR accumulation texture.") }
        texture.label = "Progressive linear HDR"
        var nextWorld:[MTLTexture] = [], nextNormal:[MTLTexture] = [], nextHistory:[MTLTexture] = [], nextFilters:[MTLTexture] = []
        func auxiliary(_ format: MTLPixelFormat, _ label: String) throws -> MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:format,width:width,height:height,mipmapped:false)
            descriptor.storageMode = .private; descriptor.usage = [.shaderRead,.shaderWrite]
            guard let result = device.makeTexture(descriptor:descriptor) else { throw EngineError.message("Could not allocate motion reconstruction resources.") }
            result.label = label; return result
        }
        for i in 0..<2 {
            nextWorld.append(try auxiliary(.rgba32Float,"World positions \(i)"))
            nextNormal.append(try auxiliary(.rgba32Float,"Surface normal and depth \(i)"))
            nextHistory.append(try auxiliary(.rgba32Float,"Reprojected radiance \(i)"))
            nextFilters.append(try auxiliary(.rgba32Float,"Edge-preserving filter \(i)"))
        }
        let nextAlbedo = try auxiliary(.rgba16Float,"Albedo and roughness")
        accumulation = texture; self.width = width; self.height = height; sampleCount = 0
        worldGuides = nextWorld; normalGuides = nextNormal; histories = nextHistory; filters = nextFilters; albedoGuide = nextAlbedo
        previousFrame = nil; previousPose = nil; historyIndex = 0; resetReconstruction()
    }

    func uniforms(pose: CameraPose, options: RenderOptions) -> FrameUniforms {
        let forward = simd_normalize(pose.target - pose.position)
        var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
        if simd_length_squared(right) < 0.0001 { right = SIMD3(1, 0, 0) }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(right, forward))
        let halfFov = tan(pose.fov * .pi / 360)
        let sun = options.lighting == 3 ? simd_normalize(SIMD3<Float>(-0.862, 0.07, -0.5)) : options.lighting == 0 ? simd_normalize(SIMD3<Float>(-0.55, 0.48, 0.68)) : simd_normalize(SIMD3<Float>(-0.35, 0.85, 0.4))
        let color = options.lighting == 3 ? SIMD3<Float>(3.4,1.25,0.40) : options.lighting == 2 ? SIMD3<Float>(0.012,0.018,0.032) : options.lighting == 0 ? SIMD3<Float>(4.5, 3.5, 2.6) : SIMD3<Float>(4.1, 3.95, 3.65)
        var frame = FrameUniforms(origin: SIMD4(pose.position, options.regularization ? 1 : 0), right: SIMD4(right * halfFov * Float(width) / Float(height), hasTransmission ? 1 : 0), up: SIMD4(up * halfFov, options.lowDiscrepancySampling ? 1 : 0), forward: SIMD4(forward, trafficMoving ? 1 : 0), sunDirection: SIMD4(sun, Float(options.architectureLightsEnabled ? (options.lighting >= 2 ? lightCount:dayInteriorLightCount) : 0)), sunColor: SIMD4(color, options.lighting >= 2 ? 1 : 0), viewport: SIMD4(UInt32(width), UInt32(height), sampleCount, frameSeed), settings: SIMD4(options.exposure, options.bounces, 0.009, options.lighting == 0 ? 0.85 : 1.0))
        if hasAnimatedProjection {
            let period=180.0, phase=sceneTime.truncatingRemainder(dividingBy:period)
            frame.animation=SIMD4(Float(phase<0 ? phase+period:phase),projectionMoving ? 1:0,0,0)
        }
        // Sunset state: 1 keeps architectural lights; 2 switches them off.
        // The atmosphere still tests > 0.5, preserving the same sun and sky.
        frame.animation.z = options.sunsetState
        frame.animation.w = options.hazeDensity.isFinite ? max(0,min(0.01,options.hazeDensity)) : 0
        return frame
    }

    private func encodeTrace(_ command: MTLCommandBuffer, pose: CameraPose, options: RenderOptions) throws -> FrameUniforms {
        rayTracingDispatchCount += 1
        try traffic?.encodeUpdate(command,time:sceneTime,vertices:vertexBuffer)
        guard let texture = accumulation, let encoder = command.makeComputeCommandEncoder() else { throw EngineError.message("Ray tracing encoder unavailable.") }
        var u = uniforms(pose: pose, options: options)
        encoder.label = "Hardware path tracing"
        let night=options.lighting>=2
        let grid=night ? nightLightGrid:dayLightGrid
        let indexed=options.indexedLighting && grid.enabled
        if let traffic {
            let variant=night ? (indexed ? 4:2) : dayInteriorLightCount>0 ? (indexed ? 3:1):0
            encoder.setComputePipelineState(traffic.tracePipelines[variant])
            traffic.bind(encoder,moving:trafficMoving)
        } else {
            encoder.setComputePipelineState(night ? (indexed ? indexedNightTracePipeline:nightTracePipeline) : dayInteriorLightCount>0 ? (indexed ? indexedDayInteriorTracePipeline:dayInteriorTracePipeline) : tracePipeline)
        }
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&u, length: MemoryLayout<FrameUniforms>.stride, index: 0)
        encoder.setBuffer(vertexBuffer, offset: 0, index: 1)
        encoder.setBuffer(indexBuffer, offset: 0, index: 2)
        encoder.setBuffer(materialBuffer, offset: 0, index: 3)
        encoder.setAccelerationStructure(traffic?.acceleration ?? accelerationStructure, bufferIndex: 4)
        encoder.setBuffer(options.lighting >= 2 ? lightBuffer:dayInteriorLightBuffer, offset:0, index:5)
        if indexed {
            var header=grid.header
            encoder.setBytes(&header,length:MemoryLayout<LightGrid.Header>.stride,index:6)
            encoder.setBuffer(night ? nightLightRanges:dayLightRanges,offset:0,index:7)
            encoder.setBuffer(night ? nightLightIndices:dayLightIndices,offset:0,index:8)
        }
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        encoder.endEncoding()
        sampleCount &+= 1; frameSeed &+= 1
        lastUniforms = u
        return u
    }

    private func encodeDirect(_ command:MTLCommandBuffer,pose:CameraPose,options:RenderOptions) throws -> FrameUniforms {
        resetAccumulation();resetReconstruction()
        try traffic?.encodeUpdate(command,time:sceneTime,vertices:vertexBuffer)
        guard let texture=accumulation,let encoder=command.makeComputeCommandEncoder() else { throw EngineError.message("Direct ray encoder unavailable.") }
        var u=uniforms(pose:pose,options:options)
        let night=options.lighting>=2
        var header=(night ? nightLightGrid:dayLightGrid).header
        if !options.indexedLighting { header.dimensions.w=0 }
        encoder.label="Deterministic direct rays — visibility, shadows and reflections"
        encoder.setComputePipelineState(traffic == nil ? directPipeline:directTrafficPipeline)
        traffic?.bind(encoder,moving:trafficMoving)
        encoder.setTexture(texture,index:0)
        encoder.setBytes(&u,length:MemoryLayout<FrameUniforms>.stride,index:0)
        encoder.setBuffer(vertexBuffer,offset:0,index:1);encoder.setBuffer(indexBuffer,offset:0,index:2)
        encoder.setBuffer(materialBuffer,offset:0,index:3)
        encoder.setAccelerationStructure(traffic?.acceleration ?? accelerationStructure,bufferIndex:4)
        encoder.setBuffer(night ? lightBuffer:dayInteriorLightBuffer,offset:0,index:5)
        encoder.setBytes(&header,length:MemoryLayout<LightGrid.Header>.stride,index:6)
        encoder.setBuffer(night ? nightLightRanges:dayLightRanges,offset:0,index:7)
        encoder.setBuffer(night ? nightLightIndices:dayLightIndices,offset:0,index:8)
        encoder.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1))
        encoder.endEncoding();directRayDispatchCount+=1;sampleCount=1;lastUniforms=u
        return u
    }

    private func encodePresentation(_ command: MTLCommandBuffer, descriptor: MTLRenderPassDescriptor, uniforms: FrameUniforms, texture: MTLTexture? = nil, selectionDepth: MTLTexture? = nil, directRayTracing: Bool = false) throws {
        if !focusHighlight.isEmpty, uploadedHighlight != focusHighlight {
            let data=focusHighlight.packed
            highlightBuffer=data.withUnsafeBytes { device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared) }
            guard highlightBuffer != nil else { throw EngineError.message("Selection highlight allocation failed.") }
            uploadedHighlight=focusHighlight
        }
        guard let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else { throw EngineError.message("Presentation encoder unavailable.") }
        var u = uniforms
        encoder.label = "Filmic presentation"
        encoder.setRenderPipelineState(directRayTracing
            ? (focusHighlight.isEmpty ? directPresentPipeline:directFocusedPresentPipeline)
            : (focusHighlight.isEmpty ? presentPipeline:focusedPresentPipeline))
        encoder.setFragmentTexture(texture ?? accumulation, index: 0)
        encoder.setFragmentBytes(&u, length: MemoryLayout<FrameUniforms>.stride, index: 0)
        if !focusHighlight.isEmpty {
            encoder.setFragmentTexture(selectionDepth ?? accumulation,index:1)
            encoder.setFragmentBuffer(highlightBuffer,offset:0,index:1)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func encodeReconstruction(_ command: MTLCommandBuffer, uniforms: FrameUniforms, moving: Bool) throws -> MTLTexture {
        surfaceGuideDispatchCount += 1
        let current = 1-historyIndex
        guard let surface = command.makeComputeCommandEncoder() else { throw EngineError.message("Surface guide encoder unavailable.") }
        var frame = uniforms
        surface.label = "Stable primary surfaces"
        surface.setComputePipelineState(traffic?.surfacePipeline ?? surfacePipeline)
        traffic?.bind(surface,moving:trafficMoving)
        surface.setBytes(&frame,length:MemoryLayout<FrameUniforms>.stride,index:0)
        surface.setBuffer(vertexBuffer,offset:0,index:1)
        surface.setBuffer(indexBuffer,offset:0,index:2)
        surface.setBuffer(materialBuffer,offset:0,index:3)
        surface.setAccelerationStructure(traffic?.acceleration ?? accelerationStructure,bufferIndex:4)
        surface.setTexture(worldGuides[current],index:0)
        surface.setTexture(normalGuides[current],index:1)
        surface.setTexture(albedoGuide,index:2)
        let grid = MTLSize(width:width,height:height,depth:1), group = MTLSize(width:8,height:8,depth:1)
        surface.dispatchThreads(grid,threadsPerThreadgroup:group); surface.endEncoding()
        let previous = previousFrame ?? frame
        var t = TemporalUniforms(previousOrigin:previous.origin,previousRight:previous.right,previousUp:previous.up,previousForward:previous.forward,currentOrigin:SIMD4(frame.origin.xyz,frame.sunColor.w),sizeFlags:SIMD4(UInt32(width),UInt32(height),historyValid ? 1 : 0,moving ? 1 : 0),settings:SIMD4(32,Float(sampleCount),1,2*simd_length(frame.up.xyz)/Float(height)))
        guard let temporal = command.makeComputeCommandEncoder() else { throw EngineError.message("Temporal encoder unavailable.") }
        temporal.label = "Motion reprojection and visibility rejection"
        temporal.setComputePipelineState(temporalPipeline)
        temporal.setBytes(&t,length:MemoryLayout<TemporalUniforms>.stride,index:0)
        let inputs:[MTLTexture?] = [accumulation,worldGuides[current],normalGuides[current],albedoGuide,histories[historyIndex],worldGuides[historyIndex],normalGuides[historyIndex],histories[current]]
        for (i,texture) in inputs.enumerated() { temporal.setTexture(texture,index:i) }
        temporal.dispatchThreads(grid,threadsPerThreadgroup:group); temporal.endEncoding()
        var input = histories[current]
        for (pass,step) in [Float(1),2,4].enumerated() {
            guard let spatial = command.makeComputeCommandEncoder() else { throw EngineError.message("Spatial filter encoder unavailable.") }
            t.settings.z = step
            spatial.label = "Surface-aware spatial filtering \(pass+1)"
            spatial.setComputePipelineState(spatialPipeline)
            spatial.setBytes(&t,length:MemoryLayout<TemporalUniforms>.stride,index:0)
            spatial.setTexture(input,index:0); spatial.setTexture(worldGuides[current],index:1)
            spatial.setTexture(normalGuides[current],index:2); spatial.setTexture(albedoGuide,index:3)
            spatial.setTexture(filters[pass%2],index:4)
            spatial.dispatchThreads(grid,threadsPerThreadgroup:group); spatial.endEncoding()
            input = filters[pass%2]
        }
        historyIndex = current; historyValid = true; previousFrame = frame
        finalFiltered = input
        return input
    }

    private func moved(_ pose: CameraPose) -> Bool {
        guard let old = previousPose else { return true }
        return simd_distance(old.position,pose.position)>0.00001 || simd_distance(old.target,pose.target)>0.00001 || abs(old.fov-pose.fov)>0.00001
    }

    func draw(view: MTKView, pose: CameraPose, options: RenderOptions, renderWidth: Int, reset: Bool, samplesPerFrame: Int = 4, resetHistory: Bool = false) throws -> Bool {
        guard let drawable = view.currentDrawable, let descriptor = view.currentRenderPassDescriptor else { return false }
        let aspect = max(1,view.drawableSize.height) / max(1,view.drawableSize.width)
        let requestedWidth = Double(max(1,min(8192,renderWidth)))
        let requestedHeight = max(1,requestedWidth*aspect)
        let scale = min(1,8192/requestedHeight)
        try resize(width:max(1,Int(requestedWidth*scale)),height:max(1,Int(requestedHeight*scale)),rayTracing:options.rayTracing)
        let moving = moved(pose)
        if reset || moving || trafficMoving || projectionMoving || previousOptions != options { resetAccumulation() }
        if resetHistory || previousOptions != options { resetReconstruction() }
        semaphore.wait()
        guard let command = queue.makeCommandBuffer() else { semaphore.signal(); return false }
        let beforeSubmission = sampleCount
        do {
            var u = uniforms(pose: pose, options: options)
            let texture:MTLTexture?
            if options.rayTracing && options.directRayTracing {
                u=try encodeDirect(command,pose:pose,options:options);texture=accumulation
            } else if options.rayTracing {
                let tracing = sampleCount < 4096
                if tracing {
                    for _ in 0..<max(1,samplesPerFrame) { u = try encodeTrace(command, pose: pose, options: options) }
                }
                if options.denoising {
                    texture = tracing || finalFiltered == nil ? try encodeReconstruction(command,uniforms:u,moving:moving) : finalFiltered
                } else { texture = nil; resetReconstruction() }
            } else {
                texture = try encodeRaster(command,uniforms:u,options:options)
            }
            let selectionDepth = options.rayTracing ? (options.denoising && !options.directRayTracing ? normalGuides[historyIndex]:accumulation):texture
            try encodePresentation(command, descriptor: descriptor, uniforms: u, texture:texture,selectionDepth:selectionDepth,
                                   directRayTracing:options.rayTracing && options.directRayTracing)
            command.present(drawable)
            command.addCompletedHandler { [weak self] buffer in
                if let self {
                    self.metricsLock.lock()
                    self.gpuTime = max(0, buffer.gpuEndTime - buffer.gpuStartTime) * 1000
                    if let error = buffer.error { self.gpuError = error.localizedDescription }
                    self.metricsLock.unlock()
                    self.semaphore.signal()
                }
            }
            command.commit(); previousPose = pose; previousOptions = options; trafficMoving=false; projectionMoving=false
            return true
        } catch { traffic?.invalidate(); sampleCount = beforeSubmission; resetReconstruction(); semaphore.signal(); throw error }
    }

    private func encodeRaster(_ command:MTLCommandBuffer, uniforms:FrameUniforms, options:RenderOptions) throws -> MTLTexture {
        resetAccumulation();resetReconstruction();lastUniforms=uniforms
        return try rasterRenderer.encode(command,frame:uniforms,sceneTime:sceneTime,
            vertices:vertexBuffer,indices:indexBuffer,materials:materialBuffer,
            lights:options.lighting >= 2 ? lightBuffer:dayInteriorLightBuffer,
            lightGrid:options.lighting >= 2 ? nightLightGrid:dayLightGrid,
            lightRanges:options.lighting >= 2 ? nightLightRanges:dayLightRanges,
            lightIndices:options.lighting >= 2 ? nightLightIndices:dayLightIndices)
    }

    private func renderRasterOffscreen(pose:CameraPose,options:RenderOptions,width:Int,height:Int) throws -> Data {
        try resize(width:width,height:height,rayTracing:false)
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:false)
        desc.storageMode = .shared;desc.usage = [.renderTarget,.shaderRead]
        guard let output=device.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw EngineError.message("Raster export unavailable.")}
        let u=uniforms(pose:pose,options:options)
        let texture=try encodeRaster(command,uniforms:u,options:options)
        let pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=output;pass.colorAttachments[0].loadAction = .dontCare;pass.colorAttachments[0].storeAction = .store
        try encodePresentation(command,descriptor:pass,uniforms:u,texture:texture,selectionDepth:texture)
        command.commit();command.waitUntilCompleted()
        if let error=command.error {rasterRenderer.invalidate();throw error}
        lastGPUTime=max(0,command.gpuEndTime-command.gpuStartTime)*1000
        previousPose=pose;previousOptions=options;trafficMoving=false;projectionMoving=false
        var data=Data(count:width*height*4)
        data.withUnsafeMutableBytes {output.getBytes($0.baseAddress!,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
        return data
    }

    /// Uses the interactive reconstruction path offscreen, retaining validated history between frames.
    func renderPreviewOffscreen(pose: CameraPose, options: RenderOptions, width: Int, height: Int, samples: Int, resetHistory: Bool = false) throws -> Data {
        try renderPreviewCapture(pose:pose,options:options,width:width,height:height,samples:samples,resetHistory:resetHistory,captureRaw:false).image
    }

    /// Validation compares two presentations of exactly the same traced samples.
    /// Independent AS builds/refits can resolve coplanar intersections differently;
    /// equal random seeds alone do not guarantee identical raw radiance streams.
    func renderPreviewComparisonOffscreen(pose:CameraPose,options:RenderOptions,width:Int,height:Int,samples:Int,resetHistory:Bool = false) throws -> (raw:Data,reconstructed:Data) {
        let result=try renderPreviewCapture(pose:pose,options:options,width:width,height:height,samples:samples,resetHistory:resetHistory,captureRaw:true)
        guard let raw=result.raw else { throw EngineError.message("Paired raw presentation unavailable.") }
        return (raw,result.image)
    }

    private func renderPreviewCapture(pose:CameraPose,options:RenderOptions,width:Int,height:Int,samples:Int,resetHistory:Bool,captureRaw:Bool) throws -> (image:Data,raw:Data?) {
        if !options.rayTracing {
            let image=try renderRasterOffscreen(pose:pose,options:options,width:width,height:height)
            return (image,captureRaw ? image:nil)
        }
        if options.directRayTracing {
            let image=try renderDirectOffscreen(pose:pose,options:options,width:width,height:height)
            return (image,captureRaw ? image:nil)
        }
        try resize(width:width,height:height)
        // Camera motion controls angular history. Traffic has separate local
        // reactive guides and must not cap unrelated stationary mirror history.
        let moving = moved(pose)
        resetAccumulation()
        if resetHistory || previousOptions != options { resetReconstruction() }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:false)
        desc.storageMode = .shared; desc.usage = [.renderTarget,.shaderRead]
        guard let output = device.makeTexture(descriptor:desc), let command = queue.makeCommandBuffer() else { throw EngineError.message("Preview output unavailable.") }
        let rawOutput=captureRaw ? device.makeTexture(descriptor:desc):nil
        if captureRaw && rawOutput == nil { throw EngineError.message("Paired raw output unavailable.") }
        var submitted=false
        defer { if !submitted { traffic?.invalidate(); resetAccumulation(); resetReconstruction() } }
        var u = uniforms(pose:pose,options:options)
        for _ in 0..<max(1,samples) { u = try encodeTrace(command,pose:pose,options:options) }
        if let rawOutput {
            let rawPass=MTLRenderPassDescriptor()
            rawPass.colorAttachments[0].texture=rawOutput;rawPass.colorAttachments[0].loadAction = .dontCare;rawPass.colorAttachments[0].storeAction = .store
            try encodePresentation(command,descriptor:rawPass,uniforms:u)
        }
        let texture = options.denoising ? try encodeReconstruction(command,uniforms:u,moving:moving) : nil
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = output; pass.colorAttachments[0].loadAction = .dontCare; pass.colorAttachments[0].storeAction = .store
        try encodePresentation(command,descriptor:pass,uniforms:u,texture:texture,
                               selectionDepth:options.denoising ? normalGuides[historyIndex]:accumulation)
        command.commit(); submitted=true; command.waitUntilCompleted()
        if let error = command.error { traffic?.invalidate(); resetReconstruction(); throw error }
        previousPose = pose; previousOptions = options; trafficMoving=false; projectionMoving=false
        lastGPUTime = max(0,command.gpuEndTime-command.gpuStartTime)*1000
        func readback(_ texture:MTLTexture)->Data {
            var data=Data(count:width*height*4)
            data.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0) }
            return data
        }
        return (readback(output),rawOutput.map(readback))
    }

    func renderOffscreen(pose: CameraPose, options: RenderOptions, width: Int, height: Int, samples: Int) throws -> Data {
        if !options.rayTracing { return try renderRasterOffscreen(pose:pose,options:options,width:width,height:height) }
        if options.directRayTracing { return try renderDirectOffscreen(pose:pose,options:options,width:width,height:height) }
        // Same command queue serializes this with any preceding interactive frames.
        try resize(width: width, height: height); resetAccumulation(); resetReconstruction()
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        desc.storageMode = .shared; desc.usage = [.renderTarget, .shaderRead]
        guard let output = device.makeTexture(descriptor: desc) else { throw EngineError.message("Could not allocate export texture.") }
        // Batch ordered dispatches to avoid a CPU/GPU round trip for every sample.
        // A bounded batch keeps exports responsive to other GPU users.
        let count = max(1, samples)
        for firstSample in stride(from: 0, to: count, by: 32) {
            guard let command = queue.makeCommandBuffer() else { throw EngineError.message("Export command unavailable.") }
            let end = min(firstSample + 32, count)
            let beforeSubmission = sampleCount
            do {
                for sample in firstSample..<end {
                    let u = try encodeTrace(command, pose: pose, options: options)
                    if sample == count - 1 {
                        let pass = MTLRenderPassDescriptor()
                        pass.colorAttachments[0].texture = output
                        pass.colorAttachments[0].loadAction = .dontCare
                        pass.colorAttachments[0].storeAction = .store
                        try encodePresentation(command, descriptor: pass, uniforms: u)
                    }
                }
            } catch { traffic?.invalidate(); sampleCount = beforeSubmission; throw error }
            command.commit(); command.waitUntilCompleted()
            if let error = command.error { traffic?.invalidate(); resetAccumulation(); throw error }
            lastGPUTime = max(0, command.gpuEndTime - command.gpuStartTime) * 1000 / Double(end-firstSample)
        }
        trafficMoving=false; projectionMoving=false
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { output.getBytes($0.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0) }
        return data
    }
    private func renderDirectOffscreen(pose:CameraPose,options:RenderOptions,width:Int,height:Int) throws -> Data {
        var submitted=false
        defer { if !submitted { traffic?.invalidate() } }
        try resize(width:width,height:height)
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:false)
        desc.storageMode = .shared;desc.usage = [.renderTarget,.shaderRead]
        guard let output=device.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {throw EngineError.message("Direct ray export unavailable.")}
        let u=try encodeDirect(command,pose:pose,options:options)
        let pass=MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture=output;pass.colorAttachments[0].loadAction = .dontCare;pass.colorAttachments[0].storeAction = .store
        try encodePresentation(command,descriptor:pass,uniforms:u,texture:accumulation,selectionDepth:accumulation,directRayTracing:true)
        command.commit();submitted=true;command.waitUntilCompleted()
        if let error=command.error {traffic?.invalidate();throw error}
        lastGPUTime=max(0,command.gpuEndTime-command.gpuStartTime)*1000
        previousPose=pose;previousOptions=options;trafficMoving=false;projectionMoving=false
        var data=Data(count:width*height*4)
        data.withUnsafeMutableBytes {output.getBytes($0.baseAddress!,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
        return data
    }
}

func writePNG(_ data: Data, width: Int, height: Int, to url: URL) throws {
    guard let provider = CGDataProvider(data: data as CFData),
          let cg = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: [.byteOrder32Little, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)], provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
          let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { throw EngineError.message("Could not encode PNG.") }
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: url)
}
