#!/usr/bin/env swift
// Run `swift scripts/validate-metal.swift`. Uses a tiny real GPU acceleration
// structure to check ABI, shader/pipeline compilation, finite path-traced output,
// accumulation reset, numerical progressive mean, encoder batching, and both
// specialized daylight/night kernels with a real buffer-backed night light.
// Requires a Metal GPU.
import Foundation
import Metal
import simd

private struct Vertex { var position: SIMD4<Float>; var normal: SIMD4<Float> }
private struct Material { var color: SIMD4<Float>; var properties: SIMD4<Float> }
private struct Light {
    var positionRadius, directionCone, colorPower, parameters: SIMD4<Float>
}
private struct Uniforms {
    var origin, right, up, forward, sunDirection, sunColor: SIMD4<Float>
    var viewport: SIMD4<UInt32>
    var settings: SIMD4<Float>
}
private func require(_ condition: Bool, _ message: String) {
    if !condition { fatalError("Metal validation failed: " + message) }
}

guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    fatalError("Metal validation requires a local Metal GPU and command queue.")
}
require(device.supportsRaytracing, "Device does not support Metal ray tracing.")
require(MemoryLayout<Vertex>.stride == 32 && MemoryLayout<Material>.stride == 32 &&
        MemoryLayout<Uniforms>.stride == 128 && MemoryLayout<Light>.stride == 64,
        "Swift/Metal vertex, material, uniform or light ABI changed.")
let root = URL(fileURLWithPath: #filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceURL = CommandLine.arguments.count>1 ? URL(fileURLWithPath:CommandLine.arguments[1]) : root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal")
let source = try String(contentsOf: sourceURL, encoding: .utf8)
let options = MTLCompileOptions()
options.languageVersion = .version3_1
let library = try device.makeLibrary(source: source, options: options)
let kernel = try device.makeComputePipelineState(function: library.makeFunction(name: "pathTrace")!)
let nightKernel = try device.makeComputePipelineState(function: library.makeFunction(name: "pathTraceNight")!)
let interiorKernel = try device.makeComputePipelineState(function: library.makeFunction(name:"pathTraceDayInteriors")!)
let renderDescriptor = MTLRenderPipelineDescriptor()
renderDescriptor.vertexFunction = library.makeFunction(name: "fullscreenVertex")!
renderDescriptor.fragmentFunction = library.makeFunction(name: "presentFragment")!
renderDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
let presentationPipeline = try device.makeRenderPipelineState(descriptor: renderDescriptor)

let normal = SIMD4<Float>(0, 0, 1, 0)
private let vertices = [
    Vertex(position: SIMD4(-4,-4,0,1), normal: normal), Vertex(position: SIMD4(4,-4,0,1), normal: normal),
    Vertex(position: SIMD4(4,4,0,1), normal: normal), Vertex(position: SIMD4(-4,-4,0,1), normal: normal),
    Vertex(position: SIMD4(4,4,0,1), normal: normal), Vertex(position: SIMD4(-4,4,0,1), normal: normal)
]
let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: .storageModeShared)!
private let material = Material(color: SIMD4(0.7, 0.2, 0.1, 0.5), properties: .zero)
let materialBuffer = device.makeBuffer(bytes: [material], length: MemoryLayout<Material>.stride, options: .storageModeShared)!
// This source is inactive in the daylight kernel and when the uniform light
// count is zero. Night checks below must read this exact binding at buffer 5.
private let light = Light(positionRadius: SIMD4(0,2,3,0.18), directionCone: SIMD4(0,-1,0,-1),
                          colorPower: SIMD4(1,0.5,0.15,25), parameters: SIMD4(20,0.5,1,0))
let lightBuffer = device.makeBuffer(bytes:[light], length:MemoryLayout<Light>.stride, options:.storageModeShared)!
let indexBuffer = device.makeBuffer(bytes: [UInt32(0), UInt32(0)], length: 8, options: .storageModeShared)!
let geometry = MTLAccelerationStructureTriangleGeometryDescriptor()
geometry.vertexBuffer = vertexBuffer
geometry.vertexStride = MemoryLayout<Vertex>.stride
geometry.vertexFormat = .float3
geometry.triangleCount = 2
geometry.opaque = true
let accelerationDescriptor = MTLPrimitiveAccelerationStructureDescriptor()
accelerationDescriptor.geometryDescriptors = [geometry]
let sizes = device.accelerationStructureSizes(descriptor: accelerationDescriptor)
let acceleration = device.makeAccelerationStructure(size: sizes.accelerationStructureSize)!
let scratch = device.makeBuffer(length: sizes.buildScratchBufferSize, options: .storageModePrivate)!
let build = queue.makeCommandBuffer()!
let builder = build.makeAccelerationStructureCommandEncoder()!
builder.build(accelerationStructure: acceleration, descriptor: accelerationDescriptor, scratchBuffer: scratch, scratchBufferOffset: 0)
builder.endEncoding()
build.commit()
build.waitUntilCompleted()
if let error = build.error { throw error }

let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: 32, height: 32, mipmapped: false)
textureDescriptor.storageMode = .shared
textureDescriptor.usage = [.shaderRead, .shaderWrite]
let texture = device.makeTexture(descriptor: textureDescriptor)!

func encodeTrace(into command: MTLCommandBuffer, accumulatedFrames: UInt32, seed: UInt32,
                 night: Bool = false, lightCount: UInt32 = 0, interiors:Bool = false) {
    var uniforms = Uniforms(origin: SIMD4(0,0,5,1), right: SIMD4(0.5,0,0,0), up: SIMD4(0,0.5,0,0),
                            forward: SIMD4(0,0,-1,0), sunDirection: SIMD4(-0.4,0.8,1,0), sunColor: SIMD4(3.5,3.2,2.7,0),
                            viewport: SIMD4(32,32,accumulatedFrames,seed), settings: SIMD4(1,3,0.00465,0.7))
    uniforms.sunColor.w = night ? 1 : 0
    uniforms.sunDirection.w = Float(lightCount)
    let encoder = command.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(night ? nightKernel : interiors ? interiorKernel:kernel)
    encoder.setTexture(texture, index: 0)
    encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
    encoder.setBuffer(vertexBuffer, offset: 0, index: 1)
    encoder.setBuffer(indexBuffer, offset: 0, index: 2)
    encoder.setBuffer(materialBuffer, offset: 0, index: 3)
    encoder.setAccelerationStructure(acceleration, bufferIndex: 4)
    encoder.setBuffer(lightBuffer,offset:0,index:5)
    encoder.dispatchThreads(MTLSize(width: 32, height: 32, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    encoder.endEncoding()
}

func readPixels() -> [SIMD4<Float>] {
    var pixels = [SIMD4<Float>](repeating: .zero, count: 1024)
    texture.getBytes(&pixels, bytesPerRow: 32 * 16, from: MTLRegionMake2D(0, 0, 32, 32), mipmapLevel: 0)
    return pixels
}

func render(accumulatedFrames: UInt32, seed: UInt32, night: Bool = false,
            lightCount: UInt32 = 0, interiors:Bool = false) throws -> [SIMD4<Float>] {
    let command = queue.makeCommandBuffer()!
    encodeTrace(into: command, accumulatedFrames: accumulatedFrames, seed: seed, night:night, lightCount:lightCount,interiors:interiors)
    command.commit()
    command.waitUntilCompleted()
    if let error = command.error { throw error }
    return readPixels()
}

let first = try render(accumulatedFrames: 0, seed: 11)
let second = try render(accumulatedFrames: 0, seed: 12)
let reset = try render(accumulatedFrames: 0, seed: 11)
let mean = try render(accumulatedFrames: 1, seed: 12)
var meanError: Float = 0, resetError: Float = 0
for i in 0..<1024 {
    for channel in 0..<3 {
        require(first[i][channel].isFinite && second[i][channel].isFinite && mean[i][channel].isFinite, "Non-finite RGB at pixel \(i).")
        meanError = max(meanError, abs(mean[i][channel] - (first[i][channel] + second[i][channel]) * 0.5))
        resetError = max(resetError, abs(first[i][channel] - reset[i][channel]))
    }
}
require(meanError < 0.00001, "Accumulation is not the arithmetic mean (error \(meanError)).")
require(resetError == 0, "Frame-zero reset retained prior history (error \(resetError)).")
require(mean[528].x > 0.2 && mean[528].w > 4.9 && mean[528].w < 5.1, "Expected illuminated triangle at camera distance five metres.")

// Keep the exact same acceleration structure, resources, seed sequence and
// frame-zero reset for both schedules. This isolates encoder-ordering hazards
// from nondeterministic BVH construction or ambiguous coplanar intersections.
var sequential = [SIMD4<Float>]()
for sample: UInt32 in 0..<32 {
    sequential = try render(accumulatedFrames: sample, seed: 100 + sample)
}
let batch = queue.makeCommandBuffer()!
for sample: UInt32 in 0..<32 {
    encodeTrace(into: batch, accumulatedFrames: sample, seed: 100 + sample)
}
batch.commit()
batch.waitUntilCompleted()
if let error = batch.error { throw error }
let batched = readPixels()
var batchError: Float = 0
var differentComponents = 0
for i in 0..<1024 {
    for channel in 0..<3 {
        require(sequential[i][channel].isFinite && batched[i][channel].isFinite, "Non-finite batch comparison RGB at pixel \(i).")
        let difference = abs(sequential[i][channel] - batched[i][channel])
        batchError = max(batchError, difference)
        if difference != 0 { differentComponents += 1 }
    }
}
require(batchError <= 0.000001, "32-encoder batch differs from 32 sequential commands (maximum RGB error \(batchError)).")

// A source count of zero leaves only the night sky. Enabling the bound point
// source must add warm direct light, so a missing buffer or wrong kernel cannot
// quietly pass as a merely dark image. Also exercise progressive night history.
let nightUnlit = try render(accumulatedFrames:0,seed:301,night:true)
let nightFirst = try render(accumulatedFrames:0,seed:301,night:true,lightCount:1)
let nightSecond = try render(accumulatedFrames:0,seed:302,night:true,lightCount:1)
let nightReset = try render(accumulatedFrames:0,seed:301,night:true,lightCount:1)
let nightMean = try render(accumulatedFrames:1,seed:302,night:true,lightCount:1)
var nightMeanError: Float = 0
for i in 0..<1024 { for channel in 0..<4 {
    require(nightUnlit[i][channel].isFinite && nightFirst[i][channel].isFinite &&
            nightSecond[i][channel].isFinite && nightMean[i][channel].isFinite,
            "Non-finite night output at pixel \(i).")
    if channel < 3 {
        require(nightReset[i][channel] == nightFirst[i][channel], "Night frame-zero reset retained prior history.")
        nightMeanError = max(nightMeanError,abs(nightMean[i][channel] - (nightFirst[i][channel]+nightSecond[i][channel])*0.5))
    }
}}
require(nightMeanError < 0.00001,"Night accumulation is not the arithmetic mean.")
require(nightFirst[528].x > nightUnlit[528].x+0.1,"Bound night light did not illuminate the visible triangle.")
require(nightFirst[528].x > nightFirst[528].y && nightFirst[528].y > nightFirst[528].z,
        "Night source color or light buffer ABI is incorrect.")
require(nightFirst[528].w > 4.9 && nightFirst[528].w < 5.1,"Night primary hit depth changed.")

print("PASS: specialized daylight/night + presentation pipelines on \(device.name)")
print("PASS: actual 32×32 hardware ray trace, finite RGB and expected five-metre hit")
print("PASS: exact frame-zero reset; progressive mean maximum error \(meanError)")
print("PASS: 32 sequential commands versus 32 encoders in one batch; maximum RGB error \(batchError), differing components \(differentComponents)/3072")
print("PASS: 64-byte night light at buffer 5 adds warm illumination; finite output, exact reset, progressive mean error \(nightMeanError)")

let dayWithoutLocal=try render(accumulatedFrames:0,seed:401)
let dayIgnoringCityLights=try render(accumulatedFrames:0,seed:401,lightCount:1)
let dayInteriorZero=try render(accumulatedFrames:0,seed:401,interiors:true)
let dayInteriorLit=try render(accumulatedFrames:0,seed:401,lightCount:1,interiors:true)
require(dayWithoutLocal==dayIgnoringCityLights && dayWithoutLocal==dayInteriorZero,"Daylight specialization changed sky/sun or enabled ordinary city lamps")
require(dayInteriorLit[528].x>dayWithoutLocal[528].x+0.1,"Always-on interior-light specialization failed to illuminate the day scene")
require(dayInteriorLit.allSatisfy{$0.x.isFinite && $0.y.isFinite && $0.z.isFinite},"Daytime interior-light output is nonfinite")
print("PASS: daylight interior specialization adds opted-in illumination and preserves identical day sky/sun with zero interior lights")

// Exercise the actual presentation shader with sharp, same-depth HDR features.
// Low-SPP presentation previously applied an undocumented 3x3 filter, making
// --raw comparisons measure a filtered baseline instead of the traced pixels.
var presentationValues = [SIMD4<Float>](repeating: SIMD4(0.003,0.009,0.018,5), count: 1024)
for y in 0..<32 { for x in 0..<32 {
    if (x + 2*y) % 5 == 0 { presentationValues[y*32+x] = SIMD4(0.8,0.13,0.035,5) }
    if x == 16 { presentationValues[y*32+x] = SIMD4(0.1,0.7,0.2,5) }
} }
presentationValues.withUnsafeBytes { texture.replace(region: MTLRegionMake2D(0,0,32,32), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 32*16) }
let presentationDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 32, height: 32, mipmapped: false)
presentationDescriptor.storageMode = .shared; presentationDescriptor.usage = [.renderTarget]
let presentationOutput = device.makeTexture(descriptor: presentationDescriptor)!
func displayByte(_ value: Float) -> UInt8 {
    let mapped = min(1,max(0,(value*(2.51*value+0.03))/(value*(2.43*value+0.59)+0.14)))
    let encoded:Float = mapped <= 0.0031308 ? mapped*12.92 : 1.055*pow(mapped,1/2.4)-0.055
    return UInt8(min(255,max(0,Int((encoded*255).rounded()))))
}
func present(sampleCount: UInt32) throws -> [UInt8] {
    var uniforms = Uniforms(origin: SIMD4(0,0,5,1), right: SIMD4(0.5,0,0,0), up: SIMD4(0,0.5,0,0),
                            forward: SIMD4(0,0,-1,0), sunDirection: SIMD4(-0.4,0.8,1,0), sunColor: SIMD4(3.5,3.2,2.7,0),
                            viewport: SIMD4(32,32,sampleCount,0), settings: SIMD4(1,3,0.00465,0.7))
    let command = queue.makeCommandBuffer()!, pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = presentationOutput
    pass.colorAttachments[0].loadAction = .dontCare; pass.colorAttachments[0].storeAction = .store
    let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
    encoder.setRenderPipelineState(presentationPipeline)
    encoder.setFragmentTexture(texture,index:0)
    encoder.setFragmentBytes(&uniforms,length:MemoryLayout<Uniforms>.stride,index:0)
    encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3)
    encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
    if let error = command.error { throw error }
    var bytes = [UInt8](repeating:0,count:1024*4)
    bytes.withUnsafeMutableBytes { presentationOutput.getBytes($0.baseAddress!,bytesPerRow:32*4,from:MTLRegionMake2D(0,0,32,32),mipmapLevel:0) }
    return bytes
}
let highSamplePresentation = try present(sampleCount:128)
var maximumPresentationError = 0
for sampleCount:UInt32 in [1,4,128] {
    let bytes = try present(sampleCount:sampleCount)
    require(bytes == highSamplePresentation,"Presentation changed pixel coverage at \(sampleCount) samples")
    for index in 0..<1024 {
        for channel in 0..<3 {
            let error = abs(Int(bytes[index*4+channel])-Int(displayByte(presentationValues[index][2-channel])))
            maximumPresentationError = max(maximumPresentationError,error)
            require(error <= 1,"Presentation spatially filtered or incorrectly mapped pixel \(index), channel \(channel), samples \(sampleCount)")
        }
        require(bytes[index*4+3] == 255,"Presentation changed output alpha")
    }
}
print("PASS: actual presentation at1/4/128samples preserves per-pixel HDR coverage and applies only tone/sRGB mapping (maximum byte error \(maximumPresentationError))")

// Smooth vertex normals must reach the deterministic guide just as they do
// the path tracer; facet normals would falsely break a curved mirror's history.
private var curvedVertices=vertices
for i in curvedVertices.indices {
    let p=curvedVertices[i].position
    curvedVertices[i].normal=SIMD4(simd_normalize(SIMD3(p.x*0.05,p.y*0.05,1)),0)
}
curvedVertices.withUnsafeBytes {vertexBuffer.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count)}
let guides=(0..<3).map{_ in device.makeTexture(descriptor:textureDescriptor)!}
let guideKernel=try device.makeComputePipelineState(function:library.makeFunction(name:"primarySurface")!)
private var guideUniforms=Uniforms(origin:SIMD4(0,0,5,1),right:SIMD4(0.5,0,0,0),up:SIMD4(0,0.5,0,1),forward:SIMD4(0,0,-1,0),sunDirection:SIMD4(0,1,1,0),sunColor:SIMD4(1,1,1,0),viewport:SIMD4(32,32,0,0),settings:SIMD4(1,2,0.009,1))
let guideCommand=queue.makeCommandBuffer()!,guideEncoder=guideCommand.makeComputeCommandEncoder()!
guideEncoder.setComputePipelineState(guideKernel);guideEncoder.setBytes(&guideUniforms,length:128,index:0)
guideEncoder.setBuffer(vertexBuffer,offset:0,index:1);guideEncoder.setBuffer(indexBuffer,offset:0,index:2);guideEncoder.setBuffer(materialBuffer,offset:0,index:3);guideEncoder.setAccelerationStructure(acceleration,bufferIndex:4)
for (i,t) in guides.enumerated(){guideEncoder.setTexture(t,index:i)}
guideEncoder.dispatchThreads(MTLSize(width:32,height:32,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));guideEncoder.endEncoding();guideCommand.commit();guideCommand.waitUntilCompleted()
if let error=guideCommand.error {throw error}
var guidePositions=[SIMD4<Float>](repeating:.zero,count:1024),guideNormals=guidePositions
guides[0].getBytes(&guidePositions,bytesPerRow:32*16,from:MTLRegionMake2D(0,0,32,32),mipmapLevel:0)
guides[1].getBytes(&guideNormals,bytesPerRow:32*16,from:MTLRegionMake2D(0,0,32,32),mipmapLevel:0)
for i in guidePositions.indices {
    let p=guidePositions[i],n=guideNormals[i],expected=simd_normalize(SIMD3(p.x*0.05,p.y*0.05,1))
    require(simd_distance(SIMD3(n.x,n.y,n.z),expected)<0.00001,"Smooth reflective surface guide used a facet normal")
}
print("PASS: 1,024 smooth curved-surface guide normals match the tracer's vertex interpolation across triangle edges")
