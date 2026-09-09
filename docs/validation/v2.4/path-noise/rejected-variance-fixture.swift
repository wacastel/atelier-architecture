#!/usr/bin/env swift
// Executes the real Metal reconstruction kernels on reproducible synthetic
// surfaces. No CPU implementation stands in for the GPU under test.
import Foundation
import Metal
import simd
import Darwin
setbuf(stdout, nil)

private struct TemporalUniforms {
    var previousOrigin, previousRight, previousUp, previousForward: SIMD4<Float>
    var currentOrigin: SIMD4<Float>
    var sizeFlags: SIMD4<UInt32>
    var settings: SIMD4<Float>
}
private func require(_ condition: Bool, _ message: String) {
    if !condition { fatalError("Denoiser validation failed: " + message) }
}
require(MemoryLayout<TemporalUniforms>.stride == 112, "Temporal uniform ABI must be 112 bytes")
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    fatalError("Denoiser validation requires a local Metal GPU")
}
let root = URL(fileURLWithPath: #filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
let sourceURL=CommandLine.arguments.count>1 ? URL(fileURLWithPath:CommandLine.arguments[1]) : root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Denoise.metal")
let source = try String(contentsOf:sourceURL,encoding:.utf8)
let options = MTLCompileOptions()
options.languageVersion = .version3_1
let library = try device.makeLibrary(source: source, options: options)
let temporal = try device.makeComputePipelineState(function: library.makeFunction(name: "temporalResolve")!)
let spatial = try device.makeComputePipelineState(function: library.makeFunction(name: "spatialFilter")!)
let width = 128, height = 96, count = width * height
let rowBytes = width * MemoryLayout<SIMD4<Float>>.stride
let region = MTLRegionMake2D(0, 0, width, height)
func texture(_ name: String) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = [.shaderRead, .shaderWrite]
    let result = device.makeTexture(descriptor: descriptor)!
    result.label = name
    let zeros = [SIMD4<Float>](repeating: .zero, count: count)
    zeros.withUnsafeBytes { result.replace(region: region, mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: rowBytes) }
    return result
}
let raw = texture("raw")
let worlds = [texture("world 0"), texture("world 1")]
let normals = [texture("normal 0"), texture("normal 1")]
let albedo = texture("albedo")
let histories = [texture("history 0"), texture("history 1")]
let filters = [texture("filter 0"), texture("filter 1")]
func read(_ texture: MTLTexture) -> [SIMD4<Float>] {
    var output = [SIMD4<Float>](repeating: .zero, count: count)
    output.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: rowBytes, from: region, mipmapLevel: 0) }
    return output
}
func write(_ values: [SIMD4<Float>], _ texture: MTLTexture) {
    values.withUnsafeBytes { texture.replace(region: region, mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: rowBytes) }
}
func random(_ value: UInt32) -> Float {
    var n = value
    n ^= n >> 16; n = n &* 0x7feb352d
    n ^= n >> 15; n = n &* 0x846ca68b
    n ^= n >> 16
    return Float(n >> 8) / 16_777_216
}
enum Surface { case plane, occlusion, thinIron, sameMaterialOffset, normalEdge, materialEdge, albedoEdge, sky }
func populate(frame: Int, originX: Float, yaw: Float = 0, scene: Surface = .plane, noise: Bool = true, roughness: Float = 0.6) -> [SIMD4<Float>] {
    var radiance = [SIMD4<Float>](repeating: .zero, count: count)
    var world = radiance, normal = radiance, colors = radiance, reference = radiance
    let origin = SIMD3<Float>(originX, 0, 0)
    for y in 0..<height { for x in 0..<width {
        let index = y * width + x
        let sx = 2 * (Float(x) + 0.5) / Float(width) - 1
        let sy = 1 - 2 * (Float(y) + 0.5) / Float(height)
        let ray = SIMD3<Float>(sx * cos(yaw) + sin(yaw), sy * 0.75, cos(yaw) - sx * sin(yaw))
        var depth: Float = 5, light: Float = 1, material: Float = 0
        var n = SIMD3<Float>(0, 0, -1)
        var color = SIMD3<Float>(repeating: 0.5)
        switch scene {
        case .plane: break
        case .occlusion:
            let front = originX + ray.x * 4 < 0
            depth = front ? 4 : 6; light = front ? 4 : 0.25
            material = front ? 1 : 0
        case .thinIron:
            let iron = x == width / 2
            depth = iron ? 4 : 6; light = iron ? 2.5 : 0.2
            material = iron ? 1 : 0
        case .sameMaterialOffset:
            let raised = x == width / 2
            depth = raised ? 4.95 : 5; light = raised ? 2.5 : 0.2
        case .normalEdge:
            if x == width / 2 { n = simd_normalize(SIMD3(0.8, 0, -0.6)); light = 2.5 } else { light = 0.2 }
        case .materialEdge:
            if x == width / 2 { material = 2; light = 2.5 } else { light = 0.2 }
        case .albedoEdge:
            if x < width / 2 { color = SIMD3(0.05, 0.05, 0.05); light = 0.1 } else { light = 2.0 }
        case .sky: break
        }
        let point = origin + ray * (depth / ray.z)
        world[index] = scene == .sky ? SIMD4(simd_normalize(ray), -1) : SIMD4(point, material)
        normal[index] = SIMD4(n, scene == .sky ? 60000 : simd_length(point - origin))
        colors[index] = SIMD4(color, roughness)
        let perturbation = noise ? (random(UInt32(index) &+ UInt32(frame) &* 197_633) - 0.5) * 1.3 : 0
        radiance[index] = SIMD4(SIMD3(repeating: max(0, light + perturbation)), normal[index].w)
        reference[index] = SIMD4(SIMD3(repeating: light), 1)
    } }
    write(radiance, raw); write(world, worlds[frame % 2]); write(normal, normals[frame % 2]); write(colors, albedo)
    return reference
}
func render(frame: Int, originX: Float, previousX: Float, previousYaw: Float = 0, previousFOVScale: Float = 1, valid: Bool = true, moving: Bool = true, spp: Float = 4, night: Bool = false) throws -> (history: [SIMD4<Float>], filtered: [SIMD4<Float>]) {
    let current = frame % 2, previous = 1 - current
    var uniforms = TemporalUniforms(previousOrigin: SIMD4(previousX, 0, 0, 0), previousRight: SIMD4(cos(previousYaw), 0, -sin(previousYaw), 0) * previousFOVScale,
                                    previousUp: SIMD4(0, 0.75 * previousFOVScale, 0, 0), previousForward: SIMD4(sin(previousYaw), 0, cos(previousYaw), 0),
                                    currentOrigin: SIMD4(originX, 0, 0, night ? 1 : 0),
                                    sizeFlags: SIMD4(UInt32(width), UInt32(height), valid ? 1 : 0, moving ? 1 : 0),
                                    settings: SIMD4(32, spp, 1, 1.5 / Float(height)))
    let command = queue.makeCommandBuffer()!
    func dispatch(_ pipeline: MTLComputePipelineState, _ bindings: [MTLTexture], _ constants: TemporalUniforms) {
        var constants = constants
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        for (index, texture) in bindings.enumerated() { encoder.setTexture(texture, index: index) }
        encoder.setBytes(&constants, length: MemoryLayout<TemporalUniforms>.stride, index: 0)
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1), threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
        encoder.endEncoding()
    }
    dispatch(temporal, [raw, worlds[current], normals[current], albedo, histories[previous], worlds[previous], normals[previous], histories[current]], uniforms)
    for (index, step) in [1, 2, 4].enumerated() {
        uniforms.settings.z = Float(step)
        dispatch(spatial, [index == 0 ? histories[current] : filters[(index - 1) % 2], worlds[current], normals[current], albedo, filters[index % 2]], uniforms)
    }
    command.commit(); command.waitUntilCompleted()
    if let error = command.error { throw error }
    let result = (history: read(histories[current]), filtered: read(filters[0]))
    for (index, value) in result.filtered.enumerated() {
        require(value.x.isFinite && value.y.isFinite && value.z.isFinite && value.w.isFinite, "Non-finite filtered pixel \(index)")
    }
    return result
}
func rmse(_ image: [SIMD4<Float>], _ reference: [SIMD4<Float>], border: Int = 8) -> Double {
    var squared: Double = 0, samples = 0
    for y in border..<(height - border) { for x in border..<(width - border) {
        let error = Double(image[y * width + x].x - reference[y * width + x].x)
        squared += error * error; samples += 1
    } }
    return sqrt(squared / Double(samples))
}

for motion in ["stationary", "translating", "pivoting"] {
    let moving = motion != "stationary"
    var previousX: Float = 0
    var previousYaw: Float = 0
    var lastHistory = [SIMD4<Float>](), lastFiltered = lastHistory, reference = lastHistory
    for frame in 0..<48 {
        let originX = motion == "translating" ? Float(frame) * 0.02 : 0
        let yaw = motion == "pivoting" ? Float(frame) * 0.003 : 0
        reference = populate(frame: frame, originX: originX, yaw: yaw)
        let result = try render(frame: frame, originX: originX, previousX: previousX, previousYaw: previousYaw, valid: frame > 0, moving: moving)
        lastHistory = result.history; lastFiltered = result.filtered
        previousX = originX
        previousYaw = yaw
    }
    let rawError = rmse(read(raw), reference), historyError = rmse(lastHistory, reference), filteredError = rmse(lastFiltered, reference)
    require(historyError < rawError * 0.45, "Temporal reprojection did not reduce \(moving ? "moving" : "stationary") noise sufficiently")
    require(filteredError < rawError * 0.2, "Three-pass reconstruction did not reduce noise sufficiently")
    require(lastHistory[count / 2 + width / 2].w >= 28 && lastHistory.allSatisfy { $0.w <= 32 }, "History did not accumulate to bounded 32-frame count")
    print(String(format: "PASS: %@ plane raw RMSE %.5f → temporal %.5f → filtered %.5f (%.1f× lower RMS noise)", motion, rawError, historyError, filteredError, rawError / filteredError))
}

// Newly revealed background pixels had foreground at their reprojected previous
// screen location. They must restart at one sample even if material IDs match.
for sameMaterial in [false, true] {
    _ = populate(frame: 0, originX: -0.18, scene: .occlusion, noise: false)
    if sameMaterial { var values = read(worlds[0]); for i in values.indices { values[i].w = 0 }; write(values, worlds[0]) }
    _ = try render(frame: 0, originX: -0.18, previousX: -0.18, valid: false)
    let reference = populate(frame: 1, originX: 0.18, scene: .occlusion, noise: false)
    if sameMaterial { var values = read(worlds[1]); for i in values.indices { values[i].w = 0 }; write(values, worlds[1]) }
    let result = try render(frame: 1, originX: 0.18, previousX: -0.18)
    var newlyVisible = 0
    let points = read(worlds[1])
    for i in points.indices where reference[i].x == 0.25 {
        let point = SIMD3(points[i].x, points[i].y, points[i].z)
        let foregroundXInPrevious = -0.18 + (point.x + 0.18) * 4 / point.z
        if foregroundXInPrevious < -0.035 {
            newlyVisible += 1
            require(result.history[i].w == 1, "Disocclusion reused old history")
            require(abs(result.filtered[i].x - 0.25) < 0.0001, "Disocclusion left a bright ghost")
        }
    }
    require(newlyVisible > 50, "Test did not expose enough background pixels")
    print("PASS: \(newlyVisible) newly revealed background pixels reject \(sameMaterial ? "same-material depth" : "material") history; no bright ghost")
}

for scene in [Surface.thinIron, .sameMaterialOffset, .normalEdge, .materialEdge, .albedoEdge] {
    let reference = populate(frame: 0, originX: 0, scene: scene, noise: false)
    let result = try render(frame: 0, originX: 0, previousX: 0, valid: false)
    let error = rmse(result.filtered, reference)
    require(error < 0.0003, "Spatial reconstruction erased a one-pixel geometry/material feature (\(scene), RMSE \(error))")
    print(String(format: "PASS: one-pixel %@ feature survives three filter passes (RMSE %.7f)", String(describing: scene), error))
}

let zoomReference = populate(frame: 0, originX: 0, scene: .sameMaterialOffset, noise: false)
let zoomResult = try render(frame: 0, originX: 0, previousX: 0, previousFOVScale: 8, valid: false)
require(rmse(zoomResult.filtered, zoomReference) < 0.0003, "A large FOV change incorrectly broadened the current spatial filter")
print("PASS: current-frame pixel cone preserves fine geometry across an eightfold FOV-scale change")

_ = populate(frame:0,originX:0,noise:false,roughness:0.022)
var polishedWorld=read(worlds[0]),reflection=read(raw)
for i in polishedWorld.indices {
    polishedWorld[i].w=0.125
    let bright=(i%width/2)%2==0
    reflection[i]=bright ? SIMD4(0.8,0.6,0.4,reflection[i].w):SIMD4(0.03,0.05,0.09,reflection[i].w)
}
write(polishedWorld,worlds[0]);write(reflection,raw)
let reflectedEdges=try render(frame:0,originX:0,previousX:0,valid:false)
require(rmse(reflectedEdges.filtered,reflection)<0.000001,"Surface-only spatial filtering blurred sharp polished reflections")
print("PASS: sharp reflected scene edges absent from primary geometry/albedo guides retain exact coverage")

_ = populate(frame:0,originX:0,noise:false)
var jointRadiance=read(raw),jointAlbedo=read(albedo)
for i in jointRadiance.indices {
    let value:Float=i%width==width/2 ? 0.5:0.7
    jointRadiance[i]=SIMD4(value,value,value,jointRadiance[i].w)
    jointAlbedo[i]=SIMD4(value,value,value,0.6)
}
write(jointRadiance,raw);write(jointAlbedo,albedo)
let joints=try render(frame:0,originX:0,previousX:0,valid:false)
let maximumJointError=zip(joints.filtered,jointRadiance).map{abs($0.x-$1.x)}.max()!
require(maximumJointError<0.004,"Moderate-contrast paving joints were eroded by the spatial filter")
print(String(format:"PASS: one-pixel moderate-contrast paving joints retain detail (maximum error %.6f)",maximumJointError))

// Real plaza joints are separate dark geometry. Pixel-center guides on the
// adjacent pale paving can still contain valid jittered coverage of that joint.
// This is distinct from an albedo-only edge or a centered thin-geometry test.
var mixedJointSamples=0
for frame in 0..<6 {
    _ = populate(frame:frame,originX:0,noise:false)
    var points=read(worlds[frame%2]),colors=read(albedo),values=read(raw)
    for y in 0..<height {for x in 0..<width {
        let i=y*width+x,d=abs((x+frame)%16-7)
        points[i].w=d==0 ? 2:0
        colors[i]=d==0 ? SIMD4(0.025,0.028,0.03,0.6):SIMD4(0.65,0.61,0.55,0.6)
        let coverage:Float=d==0 ? 0.8:d==1 ? 0.22:0
        let rgb=SIMD3<Float>(0.7,0.62,0.52)*(1-coverage)+SIMD3<Float>(0.025,0.028,0.03)*coverage
        values[i]=SIMD4(rgb,values[i].w)
    }}
    write(points,worlds[frame%2]);write(colors,albedo);write(values,raw)
    let result=try render(frame:frame,originX:0,previousX:0,valid:false,spp:8)
    for y in 8..<(height-8) {for x in 8..<(width-8) {
        let i=y*width+x,d=abs((x+frame)%16-7)
        if d<=1 {
            require(result.filtered[i].x==values[i].x && result.filtered[i].y==values[i].y && result.filtered[i].z==values[i].z,"Spatial filtering erased valid dark-joint coverage from the neighboring stone")
            require(result.filtered[i].w==result.history[i].w,"Dark-joint bypass changed accepted history confidence")
            if d==1 {mixedJointSamples += 1}
        }
    }}
}
require(mixedJointSamples>1000,"Dark-joint fixture did not exercise adjacent pale-center coverage")
print("PASS: \(mixedJointSamples) moving dark-joint coverage samples on pale-center guides survive all spatial passes exactly")

// A converged thin contact shadow is a radiance feature, not an albedo or
// geometry boundary. More samples should reduce reconstruction bias as well as
// stochastic variance; a high-SPP image must retain this low-contrast detail.
_ = populate(frame:0,originX:0,noise:false)
var shadowRadiance=read(raw)
for i in shadowRadiance.indices {
    let value:Float=i%width==width/2 ? 0.95:1.0
    shadowRadiance[i]=SIMD4(value,value,value,shadowRadiance[i].w)
}
write(shadowRadiance,raw)
var shadowErrors:[Float]=[]
for spp:Float in [8,32,128] {
    let result=try render(frame:0,originX:0,previousX:0,valid:false,spp:spp)
    shadowErrors.append(zip(result.filtered,shadowRadiance).map{abs($0.x-$1.x)}.max()!)
}
print("Contact-shadow maximum errors at 8/32/128 SPP: \(shadowErrors)")
require(shadowErrors[0]>shadowErrors[1] && shadowErrors[1]>shadowErrors[2],"Converging samples failed to reduce spatial reconstruction bias")
require(shadowErrors[2]<0.006,"High-SPP spatial filtering erased a converged low-contrast contact shadow")
print("PASS: converged contact-shadow detail survives as spatial strength falls with sample count")

_ = populate(frame: 0, originX: 0, noise: false)
_ = try render(frame: 0, originX: 0, previousX: 0, valid: false)
_ = populate(frame: 1, originX: 0, noise: false)
write([SIMD4<Float>](repeating: SIMD4(0, 0, 0, 5), count: count), raw)
let lightingChange = try render(frame: 1, originX: 0, previousX: 0)
require(lightingChange.history.allSatisfy { $0.x < 0.12 }, "Luminance clipping failed to reject stale illumination")
let reset = try render(frame: 1, originX: 0, previousX: 0, valid: false)
require(reset.history.allSatisfy { $0.w == 1 && $0.x == 0 }, "Camera-cut reset retained history")
print("PASS: luminance clipping reacts to a lighting change; camera-cut reset is exact")

for frame in 0..<8 {
    _ = populate(frame: frame, originX: Float(frame) * 0.01, noise: true, roughness: 0.065)
    let result = try render(frame: frame, originX: Float(frame) * 0.01, previousX: Float(max(0, frame - 1)) * 0.01, valid: frame > 0)
    require(result.history.allSatisfy { $0.w <= 2.001 }, "Sharp reflection history was not limited during movement")
}
print("PASS: moving mirror-like surfaces retain at most two frames to avoid reflection trails")

var slowMirrorRawError:Double=0,slowMirrorHistoryError:Double=0
var longestSlowMirrorHistory:Float=0
for frame in 0..<48 {
    let x=Float(frame)*0.0001
    let reference=populate(frame:frame,originX:x,noise:true,roughness:0.065)
    let rawError=rmse(read(raw),reference)
    let result=try render(frame:frame,originX:x,previousX:Float(max(0,frame-1))*0.0001,valid:frame>0)
    if frame>=24 {
        slowMirrorRawError += rawError
        slowMirrorHistoryError += rmse(result.history,reference)
        longestSlowMirrorHistory=max(longestSlowMirrorHistory,result.history.map{$0.w}.max()!)
    }
}
require(longestSlowMirrorHistory>12 && longestSlowMirrorHistory<=16.001,"Slow glossy motion should retain bounded angularly compatible history")
require(slowMirrorHistoryError<slowMirrorRawError*0.35,"Slow glossy motion history failed to reduce sampling noise")
_ = populate(frame:48,originX:0.0048,noise:false,roughness:0.065)
write([SIMD4<Float>](repeating:SIMD4(0,0,0,5),count:count),raw)
let mirrorExtinguished=try render(frame:48,originX:0.0048,previousX:0.0047)
require(mirrorExtinguished.history.allSatisfy{$0.x<0.00001 && $0.y<0.00001 && $0.z<0.00001},"Longer slow-mirror history retained an extinguished reflection")
print(String(format:"PASS: slow glossy view-change history RMS %.5f → %.5f; at most 16 frames and exact extinguished-reflection rejection",slowMirrorRawError/24,slowMirrorHistoryError/24))

for frame in 0..<8 {
    _ = populate(frame: frame, originX: Float(frame), scene: .sky)
    let current = read(raw)
    let result = try render(frame: frame, originX: Float(frame), previousX: Float(max(0, frame - 1)), valid: frame > 0)
    require(result.history.allSatisfy { $0.w == 1 }, "Analytic sky retained temporal history")
    require(zip(result.filtered,current).allSatisfy { $0.x==$1.x && $0.y==$1.y && $0.z==$1.z }, "Analytic sky was modified by reconstruction")
    require(zip(result.filtered,result.history).allSatisfy { $0.w==$1.w }, "Analytic sky bypass changed accepted history confidence")
}
print("PASS: analytic sky bypasses temporal/spatial reconstruction without altering current coverage")

// A static, subpixel-width gold spire moves across the screen as the camera
// translates. Four deterministic coverage samples emulate the path tracer's
// jitter: some pixels have a sky center guide but include bright foreground
// radiance. Reprojecting those pixels as infinite sky caused the observed gold
// trails in the real Eiffel night orbit. Test both moving and freshly paused
// frames, and verify that legitimate current silhouette coverage stays intact.
let skyRadiance = SIMD3<Float>(0.003, 0.005, 0.012)
let spireRadiance = SIMD3<Float>(8, 3, 0.6)
var previousMixedSky = Set<Int>()
var exposedTrailingPixels = 0, testedMixedPixels = 0
var largestClearSkyError: Float = 0
var previousOrigin: Float = -1
for frame in 0..<56 {
    let originX = -1 + Float(min(frame, 47)) * 0.043
    let moving = frame < 48
    var values = [SIMD4<Float>](repeating: .zero, count: count)
    var world = values, normal = values, color = values
    var mixedSky = Set<Int>()
    for y in 0..<height { for x in 0..<width {
        let index = y * width + x
        let sx = 2 * (Float(x) + 0.5) / Float(width) - 1
        let sy = 1 - 2 * (Float(y) + 0.5) / Float(height)
        let ray = SIMD3<Float>(sx, sy * 0.75, 1)
        let worldX = originX + ray.x * 5
        let centerHitsSpire = abs(worldX) < 0.035
        var coverage: Float = 0
        for jitter: Float in [0.125, 0.375, 0.625, 0.875] {
            let sampleX = originX + (2 * (Float(x) + jitter) / Float(width) - 1) * 5
            if abs(sampleX) < 0.035 { coverage += 0.25 }
        }
        world[index] = centerHitsSpire ? SIMD4(SIMD3(originX, 0, 0) + ray * 5, 1) : SIMD4(simd_normalize(ray), -1)
        normal[index] = centerHitsSpire ? SIMD4(0, 0, -1, simd_length(ray * 5)) : SIMD4(0, 0, 0, 60000)
        color[index] = centerHitsSpire ? SIMD4(0.5, 0.3, 0.1, 0.6) : SIMD4(0, 0, 0, 1)
        values[index] = SIMD4(skyRadiance * (1 - coverage) + spireRadiance * coverage, normal[index].w)
        if !centerHitsSpire && coverage > 0 { mixedSky.insert(index) }
    } }
    write(values, raw); write(world, worlds[frame % 2]); write(normal, normals[frame % 2]); write(color, albedo)
    let result = try render(frame: frame, originX: originX, previousX: previousOrigin, valid: frame > 0, moving: moving)
    for index in values.indices where world[index].w < 0 {
        require(result.history[index].w == 1, "A mixed-coverage sky pixel retained history")
        if mixedSky.contains(index) {
            testedMixedPixels += 1
            require(result.filtered[index].x==values[index].x && result.filtered[index].y==values[index].y && result.filtered[index].z==values[index].z, "Current subpixel spire coverage was erased or smeared")
            require(result.filtered[index].w==result.history[index].w, "Subpixel spire bypass changed accepted history confidence")
        } else {
            let error = abs(result.filtered[index].x - skyRadiance.x)
            largestClearSkyError = max(largestClearSkyError, error)
            require(error < 0.000001, "A bright gold trail remained in newly clear sky")
            if previousMixedSky.contains(index) { exposedTrailingPixels += 1 }
        }
    }
    previousMixedSky = mixedSky; previousOrigin = originX
}
require(testedMixedPixels > 1000 && exposedTrailingPixels > 1000, "Moving-spire test did not exercise enough mixed/clear transitions")
print("PASS: \(testedMixedPixels) bright subpixel/sky coverage samples preserved; \(exposedTrailingPixels) formerly bright sky pixels leave no trail (maximum clear-sky error \(largestClearSkyError))")

// The same coverage mismatch can tag a distant building instead of sky. Keep
// its geometry/material and screen projection identical while a transient gold
// foreground contribution disappears. The first fully clear frame must return
// to the dark background without a colour/luminance remainder from history.
let background = SIMD3<Float>(0.0008, 0.0010, 0.0016)
var maximumBackgroundError: Float = 0
var highlightPixels = 0
for frame in 0..<40 {
    _ = populate(frame: frame, originX: 0, noise: false)
    var values = read(raw)
    for y in 0..<height { for x in 0..<width {
        let index = y * width + x
        let transientHighlight = frame < 32 && x >= 42 && x <= 45 && y >= 20 && y <= 75
        values[index] = SIMD4(transientHighlight ? background * 0.75 + spireRadiance * 0.25 : background, values[index].w)
    } }
    write(values, raw)
    let result = try render(frame: frame, originX: 0, previousX: 0, valid: frame > 0, moving: true)
    if frame == 31 { require(result.history[width * 40 + 43].w >= 28, "Transient background highlight did not build a long history") }
    if frame >= 32 {
        for y in 20...75 { for x in 42...45 {
            let index = y * width + x
            let expected = SIMD4(background, values[index].w)
            let filtered = result.filtered[index]
            let error = max(abs(filtered.x - expected.x), abs(filtered.y - expected.y), abs(filtered.z - expected.z))
            maximumBackgroundError = max(maximumBackgroundError, error)
            require(error < 0.000001, "A vanished gold highlight left a trail over dark same-material geometry")
            if frame == 32 { require(result.history[index].w == 1, "A disappeared coverage highlight did not immediately reset history"); highlightPixels += 1 }
        } }
    }
}
print("PASS: \(highlightPixels) gold mixed-coverage pixels over dark geometry clear in their first uncovered frame (maximum RGB error \(maximumBackgroundError))")
// A lit window next to an unlit room shares the facade plane and material ID,
// but its different color must not widen the dark room's temporal clip range.
for frame in 0..<2 {
    _ = populate(frame: frame, originX: 0, noise: false, roughness: 0.13)
    var values = read(raw), colors = read(albedo)
    for y in 0..<height { for x in 0..<width {
        let index=y*width+x, lit=x%4==0
        colors[index]=lit ? SIMD4(0.97,0.65,0.31,0.13) : SIMD4(0.085,0.14,0.145,0.13)
        values[index]=SIMD4(lit || frame==0 ? SIMD3(0.8,0.4,0.1) : background,values[index].w)
    } }
    write(values,raw); write(colors,albedo)
    let result=try render(frame:frame,originX:0,previousX:0,valid:frame>0)
    if frame==1 {
        for y in 8..<(height-8) { for x in 8..<(width-8) where x%4 != 0 {
            let index=y*width+x
            require(result.history[index].w==1,"Neighboring lit room allowed a stale highlight to survive in dark room")
            require(simd_length(SIMD3(result.filtered[index].x,result.filtered[index].y,result.filtered[index].z)-background)<0.00001,"Lit window smeared into dark room")
        } }
    }
}
print("PASS: neighboring lit windows do not preserve stale illumination on dark same-material rooms")
for frame in 0..<3 {
    _ = populate(frame:frame,originX:0,noise:false,roughness:0.13)
    var world=read(worlds[frame%2]),values=read(raw)
    for i in world.indices {
        world[i].w=0.5
        let bright=((i%width)+frame)%4<2
        values[i]=SIMD4(bright ? SIMD3(0.8,0.4,0.1):background,values[i].w)
    }
    write(world,worlds[frame%2]);write(values,raw)
    let result=try render(frame:frame,originX:0,previousX:0,valid:frame>0)
    require(result.history.allSatisfy{$0.w==1},"Emissive coverage retained temporal history")
    require(zip(result.filtered,values).allSatisfy { $0.x==$1.x && $0.y==$1.y && $0.z==$1.z },"Emissive window coverage was smeared")
    require(zip(result.filtered,result.history).allSatisfy { $0.w==$1.w },"Emissive bypass changed accepted history confidence")
}
print("PASS: emissive subpixel windows retain exact current coverage without spatial/temporal trails")
for frame in 0..<3 {
    _ = populate(frame:frame,originX:0,noise:false)
    var values=read(raw), depths=read(normals[frame%2])
    for i in values.indices {
        values[i]=SIMD4((i%width+frame)%4<2 ? SIMD3(0.8,0.4,0.1):background,500)
        depths[i].w=500
    }
    write(values,raw);write(depths,normals[frame%2])
    let result=try render(frame:frame,originX:0,previousX:0,valid:frame>0,night:true)
    require(result.history.allSatisfy{$0.w==1},"Unresolved distant night coverage reused history")
    for i in values.indices {require(result.history[i].x==values[i].x && result.history[i].y==values[i].y && result.history[i].z==values[i].z,"Distant facade retained stale illumination")}
}
print("PASS: unresolved distant night facades use current spatial reconstruction without temporal trails")
print("PASS: all GPU outputs finite on \(device.name)")

// Reflection and transmission do not share one motion vector. Glass-background
// lighting must use no temporal history, while current spatial filtering can
// reduce sampling noise without spreading across the window/material boundary.
for frame in 0..<3 {
    let truth=populate(frame:frame,originX:0,noise:true)
    var world=read(worlds[frame%2]);let values=read(raw)
    for i in world.indices { world[i].w=0.75 }
    write(world,worlds[frame%2])
    let result=try render(frame:frame,originX:0,previousX:0,valid:frame>0)
    require(result.history.allSatisfy{$0.w==1},"Glass reflection reused background temporal motion")
    var rawError:Float=0,filteredError:Float=0
    for i in values.indices {
        require(result.history[i].x==values[i].x,"Glass history did not use exact current illumination")
        rawError += pow(values[i].x-truth[i].x,2)
        filteredError += pow(result.filtered[i].x-truth[i].x,2)
    }
    require(filteredError<rawError,"Glass current-frame spatial filter did not reduce noise")
}
print("PASS: through-glass surfaces reject temporal history and reduce current spatial noise")

// Coarse night windows have mixed jittered coverage even when the deterministic
// center ray lands on a dark frame. Emitter-only bypass used to preserve the
// bright centers but erode their legitimate fractional neighboring coverage.
var preservedMixedWindowSamples = 0
for frame in 0..<6 {
    _ = populate(frame:frame,originX:0,noise:false,roughness:0.13)
    var points=read(worlds[frame%2]), depths=read(normals[frame%2]), colors=read(albedo), values=read(raw)
    for y in 0..<height { for x in 0..<width {
        let index=y*width+x, distanceFromWindow=abs((x+frame)%12-5)
        let centerSeesEmitter=distanceFromWindow==0
        let fraction:Float=distanceFromWindow==0 ? 0.8 : distanceFromWindow==1 ? 0.25 : distanceFromWindow==2 ? 0.05 : 0
        points[index]=SIMD4(SIMD3(points[index].x,points[index].y,points[index].z)*100,centerSeesEmitter ? 0.5:0)
        depths[index].w *= 100
        colors[index]=centerSeesEmitter ? SIMD4(0.97,0.65,0.31,0.13) : SIMD4(0.025,0.028,0.032,0.13)
        values[index]=SIMD4(background*(1-fraction)+SIMD3<Float>(0.8,0.4,0.1)*fraction,depths[index].w)
    } }
    write(points,worlds[frame%2]);write(depths,normals[frame%2]);write(colors,albedo);write(values,raw)
    let result=try render(frame:frame,originX:0,previousX:0,valid:frame>0,night:true)
    for y in 8..<(height-8) { for x in 8..<(width-8) {
        let index=y*width+x, distanceFromWindow=abs((x+frame)%12-5)
        if distanceFromWindow<=2 {
            require(result.history[index].w==1,"Mixed distant window reused temporal history")
            require(result.filtered[index].x==values[index].x && result.filtered[index].y==values[index].y && result.filtered[index].z==values[index].z,"Spatial filtering erased valid mixed window coverage from a non-emitter center")
            require(result.filtered[index].w==result.history[index].w,"Mixed-window bypass changed accepted history confidence")
            if distanceFromWindow>0 {preservedMixedWindowSamples += 1}
        }
    } }
}
require(preservedMixedWindowSamples>1000,"Mixed window fixture did not exercise enough non-emitter coverage samples")
print("PASS: \(preservedMixedWindowSamples) moving night-window coverage samples on dark-center guides survive all three spatial passes exactly")

// The conservative coverage guard must leave ordinary far-surface noise
// reduction available, rather than making every night pixel equivalent to raw.
let coarseTruth=populate(frame:0,originX:0,noise:true)
var coarseWorld=read(worlds[0]),coarseDepth=read(normals[0]),coarseValues=read(raw)
for i in coarseWorld.indices {
    coarseWorld[i]=SIMD4(SIMD3(coarseWorld[i].x,coarseWorld[i].y,coarseWorld[i].z)*100,0)
    coarseDepth[i].w *= 100;coarseValues[i].w=coarseDepth[i].w
}
write(coarseWorld,worlds[0]);write(coarseDepth,normals[0]);write(coarseValues,raw)
let coarseResult=try render(frame:0,originX:0,previousX:0,valid:false,night:true)
require(rmse(coarseResult.filtered,coarseTruth)<rmse(coarseValues,coarseTruth)*0.5,"Coarse night non-emissive surfaces lost spatial noise reduction")
print("PASS: smooth distant night surfaces retain spatial noise reduction away from emissive coverage")


// A moving vehicle can occupy the same screen/world-plane neighborhood while
// its color, headlight pool or reflection moves. +0.875 must retain the exact
// current signal; its disoccluded static pixel must reject the previous flag.
for frame in 0..<4 {
    _ = populate(frame:frame,originX:0,noise:false,roughness:0.022)
    var points=read(worlds[frame%2]),values=read(raw)
    for i in points.indices {
        let active=frame<3
        points[i].w=active ? 0.875:0
        values[i]=SIMD4(active && ((i%width+frame)%5<2) ? SIMD3(0.65,0.015,0.005):background,values[i].w)
    }
    write(points,worlds[frame%2]);write(values,raw)
    let result=try render(frame:frame,originX:0,previousX:0,valid:frame>0)
    require(result.history.allSatisfy{$0.w==1},"Moving/disoccluded traffic retained stationary history")
    for i in values.indices { require(simd_length(SIMD3(result.filtered[i].x-values[i].x,result.filtered[i].y-values[i].y,result.filtered[i].z-values[i].z))<0.00001,"Moving traffic/reflection coverage blurred or left a trail") }
}
print("PASS: moving vehicle/light/reflection guides preserve exact current coverage and clear immediately after disocclusion")

// A reflected stripe can be visible in radiance without an albedo or primary
// geometry edge. Scaling identical illumination down to night levels must not
// turn its fixed absolute luminance tolerance into a much broader blur.
var relativeReflectionBias:[Double]=[]
for intensity:Float in [1,0.01] {
    _ = populate(frame:0,originX:0,noise:false,roughness:0.6)
    var points=read(worlds[0]),depths=read(normals[0]),values=read(raw)
    for y in 0..<height { for x in 0..<width {
        let i=y*width+x
        points[i]=SIMD4(SIMD3(points[i].x,points[i].y,points[i].z)*100,0)
        depths[i].w *= 100
        let signal:Float=x%16<2 ? 1:0.02
        values[i]=SIMD4(SIMD3(repeating:signal*intensity),depths[i].w)
    } }
    write(points,worlds[0]);write(depths,normals[0]);write(values,raw)
    let result=try render(frame:0,originX:0,previousX:0,valid:false,spp:8,night:true)
    relativeReflectionBias.append(rmse(result.filtered,values)/Double(intensity))
}
require(relativeReflectionBias[1]<=relativeReflectionBias[0]*1.1,"Dimming identical reflected detail to night levels increased relative spatial blur by more than ten percent")
// This must remain a filter, not a bypass that passes the detail test by leaving
// all low-radiance Monte Carlo noise untouched.
let dimTruth=populate(frame:0,originX:0,noise:true).map{SIMD4($0.x*0.01,$0.y*0.01,$0.z*0.01,$0.w)}
var dimPoints=read(worlds[0]),dimDepths=read(normals[0]),dimValues=read(raw)
for i in dimValues.indices {
    dimPoints[i]=SIMD4(SIMD3(dimPoints[i].x,dimPoints[i].y,dimPoints[i].z)*100,0);dimDepths[i].w *= 100
    dimValues[i]=SIMD4(dimValues[i].x*0.01,dimValues[i].y*0.01,dimValues[i].z*0.01,dimDepths[i].w)
}
write(dimPoints,worlds[0]);write(dimDepths,normals[0]);write(dimValues,raw)
let dimResult=try render(frame:0,originX:0,previousX:0,valid:false,spp:8,night:true)
require(rmse(dimResult.filtered,dimTruth)<rmse(dimValues,dimTruth)*0.5,"Dim night surface noise reduction was lost")
print("PASS: dim reflected detail retains comparable relative bias (\(relativeReflectionBias)); smooth dim surfaces retain more than 50 percent RMS noise reduction")


// A fast camera pan over a rough, single-material plane must retain its hard
// sun-shadow detail. Geometry/normal/albedo guides deliberately contain no edge:
// the only edge is illumination. Truth is the exact pixel box integral of a
// world-fixed periodic shadow, so a center-sampled alias is not our reference.
// The negative control removes only the new history-cap application, retaining
// the actual production reprojection, clipping and every spatial pass.
let resamplingApplication = "maximumHistory=min(maximumHistory,resamplingLimit);"
require(source.components(separatedBy: resamplingApplication).count == 2,
        "Fast-shadow negative control cannot identify exactly one resampling-history cap")
let legacyFastSource = source.replacingOccurrences(of: resamplingApplication,
                                                  with: "// Negative control: uncapped resampling history.")
let legacyFastLibrary = try device.makeLibrary(source: legacyFastSource, options: options)
let legacyFastTemporal = try device.makeComputePipelineState(function: legacyFastLibrary.makeFunction(name: "temporalResolve")!)

private struct FastShadowError {
    var squared = 0.0, samples = 0
    var edgeSquared = 0.0, edgeSamples = 0
    var flatSquared = 0.0, flatSamples = 0
    var residualSquared = 0.0, residualSamples = 0
    var truthSum = 0.0, valueSum = 0.0, truthSquared = 0.0, product = 0.0
    var rms: Double { sqrt(squared / Double(max(samples, 1))) }
    var edgeRMS: Double { sqrt(edgeSquared / Double(max(edgeSamples, 1))) }
    var flatRMS: Double { sqrt(flatSquared / Double(max(flatSamples, 1))) }
    var residualRMS: Double { sqrt(residualSquared / Double(max(residualSamples, 1))) }
    var contrastSlope: Double {
        let n = Double(max(samples, 1)), denominator = truthSquared - truthSum * truthSum / n
        return denominator > 1e-12 ? (product - truthSum * valueSum / n) / denominator : 1
    }
    mutating func add(value: Float, truth: Float, edge: Bool, previousError: Float?) {
        let a = Double(value), b = Double(truth), e = a-b
        squared += e*e; samples += 1
        truthSum += b; valueSum += a; truthSquared += b*b; product += a*b
        if edge { edgeSquared += e*e; edgeSamples += 1 }
        else { flatSquared += e*e; flatSamples += 1 }
        if let previousError { let change = e-Double(previousError); residualSquared += change*change; residualSamples += 1 }
    }
}
private func fastShadowSequence(pixelsPerFrame: Float, noisy: Bool) throws -> [String: FastShadowError] {
    let productionHistory = [texture("fast-shadow history 0"),texture("fast-shadow history 1")]
    let legacyHistory = [texture("legacy fast-shadow history 0"),texture("legacy fast-shadow history 1")]
    let productionSpatial = [texture("fast-shadow spatial 0"),texture("fast-shadow spatial 1")]
    let legacySpatial = [texture("legacy fast-shadow spatial 0"),texture("legacy fast-shadow spatial 1")]
    let names = ["raw","temporal","combined","legacyTemporal","legacyCombined"]
    var metrics = Dictionary(uniqueKeysWithValues: names.map { ($0,FastShadowError()) })
    var previousErrors = [String:[Float]]()
    let frames = 64, warmup = 16, worldPixel: Float = 10/Float(width)
    func shadowIntegral(_ t: Double) -> Double {
        let cycle = floor(t/32), within = t-cycle*32
        return cycle*8 + min(max(within,0),8)
    }
    for frame in 0..<frames {
        let current = frame%2, previous = 1-current
        let shift = Float(frame)*pixelsPerFrame, oldShift = Float(max(0,frame-1))*pixelsPerFrame
        let originX = shift*worldPixel, previousX = oldShift*worldPixel
        var points = [SIMD4<Float>](repeating:.zero,count:count)
        var depths = points, values = points, colors = points
        var truth = [Float](repeating:0,count:count), edges = [Bool](repeating:false,count:count)
        for y in 0..<height { for x in 0..<width {
            let i = y*width+x, t = Double(x)+0.5+Double(shift)
            let value = Float(1-0.75*(shadowIntegral(t+0.5)-shadowIntegral(t-0.5)))
            let sx = 2*(Float(x)+0.5)/Float(width)-1
            let sy = 1-2*(Float(y)+0.5)/Float(height)
            let p = SIMD3<Float>(originX+sx*5,sy*3.75,5)
            points[i] = SIMD4(p,0)
            depths[i] = SIMD4(0,0,-1,simd_length(p-SIMD3(originX,0,0)))
            colors[i] = SIMD4(0.5,0.5,0.5,0.7)
            let perturbation: Float = noisy ? (random(UInt32(i) &+ UInt32(frame) &* 197_633)-0.5)*0.35 : 0
            values[i] = SIMD4(SIMD3(repeating:value+perturbation),depths[i].w)
            truth[i] = value
            let phase = t-floor(t/32)*32
            edges[i] = min(min(phase,32-phase),abs(phase-8)) <= 3
        } }
        write(points,worlds[current]);write(depths,normals[current]);write(colors,albedo);write(values,raw)
        var uniforms = TemporalUniforms(previousOrigin:SIMD4(previousX,0,0,0),previousRight:SIMD4(1,0,0,0),
            previousUp:SIMD4(0,0.75,0,0),previousForward:SIMD4(0,0,1,0),currentOrigin:SIMD4(originX,0,0,0),
            sizeFlags:SIMD4(UInt32(width),UInt32(height),frame>0 ? 1:0,1),settings:SIMD4(32,8,1,1.5/Float(height)))
        let command = queue.makeCommandBuffer()!
        func dispatch(_ pipeline: MTLComputePipelineState, _ textures: [MTLTexture], _ constants: TemporalUniforms) {
            var constants = constants
            let encoder = command.makeComputeCommandEncoder()!
            encoder.setComputePipelineState(pipeline)
            for (index, texture) in textures.enumerated() { encoder.setTexture(texture,index:index) }
            encoder.setBytes(&constants,length:MemoryLayout<TemporalUniforms>.stride,index:0)
            encoder.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1))
            encoder.endEncoding()
        }
        for (pipeline, history, spatialTargets) in [(temporal,productionHistory,productionSpatial),(legacyFastTemporal,legacyHistory,legacySpatial)] {
            dispatch(pipeline,[raw,worlds[current],normals[current],albedo,history[previous],worlds[previous],normals[previous],history[current]],uniforms)
            for (pass,step) in [Float(1),2,4].enumerated() {
                uniforms.settings.z = step
                dispatch(spatial,[pass==0 ? history[current]:spatialTargets[(pass-1)%2],worlds[current],normals[current],albedo,spatialTargets[pass%2]],uniforms)
            }
            uniforms.settings.z = 1
        }
        command.commit();command.waitUntilCompleted()
        if let error = command.error { throw error }
        let outputs = ["raw":values,"temporal":read(productionHistory[current]),"combined":read(productionSpatial[0]),
                       "legacyTemporal":read(legacyHistory[current]),"legacyCombined":read(legacySpatial[0])]
        for name in names {
            let output = outputs[name]!
            var error = [Float](repeating:0,count:count)
            for y in 12..<(height-12) { for x in 16..<(width-16) {
                let i = y*width+x
                require(output[i].x.isFinite && output[i].w.isFinite,"Fast-shadow reconstruction produced a nonfinite sample")
                error[i] = output[i].x-truth[i]
                if frame >= warmup {
                    metrics[name]!.add(value:output[i].x,truth:truth[i],edge:edges[i],previousError:previousErrors[name]?[i])
                }
            } }
            previousErrors[name] = error
        }
    }
    return metrics
}
for speed:Float in [1.37,3.37] {
    let m = try fastShadowSequence(pixelsPerFrame:speed,noisy:true)
    let raw = m["raw"]!, temporal = m["temporal"]!, combined = m["combined"]!
    let legacyTemporal = m["legacyTemporal"]!, legacyCombined = m["legacyCombined"]!
    print(String(format:"FAST SHADOW %.2f px/frame: image raw %.6f / temporal %.6f / combined %.6f / legacy temporal %.6f / legacy combined %.6f; edge %.6f / legacy %.6f; temporal residual %.6f / raw %.6f; contrast %.5f / legacy %.5f",speed,raw.rms,temporal.rms,combined.rms,legacyTemporal.rms,legacyCombined.rms,combined.edgeRMS,legacyCombined.edgeRMS,combined.residualRMS,raw.residualRMS,combined.contrastSlope,legacyCombined.contrastSlope))
    require(temporal.edgeRMS < legacyTemporal.edgeRMS*0.95,"Fast pan history cap failed to improve same-material shadow-edge RMSE over uncapped temporal control")
    require(combined.edgeRMS < legacyCombined.edgeRMS*0.95,"Spatial passes erased the fast-pan shadow-edge improvement")
    require(combined.rms < raw.rms*0.85,"Fast-pan reconstruction failed to reduce matched raw image error")
    require(combined.residualRMS < raw.residualRMS*0.85,"Fast-pan reconstruction failed to reduce motion-subtracted temporal error")
    require(combined.flatRMS < raw.flatRMS*0.65,"Fast-pan reconstruction lost useful flat-region noise reduction")
    require(combined.contrastSlope > 0.85 && combined.contrastSlope > legacyCombined.contrastSlope,"Fast-pan reconstruction failed to retain shadow contrast")
}
private let cleanFast = try fastShadowSequence(pixelsPerFrame:3.37,noisy:false)
print(String(format:"FAST SHADOW noiseless: temporal edge %.6f / legacy %.6f; combined edge %.6f / legacy %.6f",cleanFast["temporal"]!.edgeRMS,cleanFast["legacyTemporal"]!.edgeRMS,cleanFast["combined"]!.edgeRMS,cleanFast["legacyCombined"]!.edgeRMS))
require(cleanFast["temporal"]!.edgeRMS < cleanFast["legacyTemporal"]!.edgeRMS*0.9,"Noiseless fast-pan history did not reduce bilinear shadow diffusion")
require(cleanFast["combined"]!.edgeRMS < cleanFast["legacyCombined"]!.edgeRMS*0.9,"Noiseless fast-pan spatial output did not preserve the temporal edge improvement")
print("PASS: fast rough-plane pans retain hard-shadow detail, improve paired image/temporal error, and catch uncapped-history negative controls")

// Residual variance can remain after valid history has reached its cap, as in
// indirectly lit marble. Exercise the real spatial kernels on such histories,
// with a fixed mean and independent noise. The control removes only adaptive
// strength; both paths retain all geometry/coverage/luminance weights.
let residualApplication = "strength=max(strength,0.75f*residualNoise*confidence*isolatedResidual*smoothstep(0.25f,0.38f,albedo.w));"
require(source.components(separatedBy:residualApplication).count==2,"Residual-noise control could not identify the adaptive application")
let fixedStrengthSource=source.replacingOccurrences(of:residualApplication,with:"// Negative control: sample-count strength only.")
let fixedStrengthLibrary=try device.makeLibrary(source:fixedStrengthSource,options:options)
let fixedStrengthSpatial=try device.makeComputePipelineState(function:fixedStrengthLibrary.makeFunction(name:"spatialFilter")!)
let residualInput=texture("valid noisy history"),residualOutputs=[texture("residual pass 0"),texture("residual pass 1")]
func residualSpatial(_ pipeline:MTLComputePipelineState,_ values:[SIMD4<Float>])->[SIMD4<Float>] {
    write(values,residualInput)
    let command=queue.makeCommandBuffer()!
    var uniforms=TemporalUniforms(previousOrigin:SIMD4(0,0,0,0),previousRight:SIMD4(1,0,0,0),previousUp:SIMD4(0,0.75,0,0),previousForward:SIMD4(0,0,1,0),currentOrigin:SIMD4(0,0,0,0),sizeFlags:SIMD4(UInt32(width),UInt32(height),1,1),settings:SIMD4(32,4,1,1.5/Float(height)))
    for (pass,step) in [Float(1),2,4].enumerated() {
        uniforms.settings.z=step
        let encoder=command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline)
        for (slot,texture) in [pass==0 ? residualInput:residualOutputs[(pass-1)%2],worlds[0],normals[0],albedo,residualOutputs[pass%2]].enumerated() {encoder.setTexture(texture,index:slot)}
        encoder.setBytes(&uniforms,length:MemoryLayout<TemporalUniforms>.stride,index:0)
        encoder.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));encoder.endEncoding()
    }
    command.commit();command.waitUntilCompleted()
    require(command.error==nil,"Residual fixture GPU command failed")
    return read(residualOutputs[0])
}
var residualCurrent=0.0,residualControl=0.0
for roughness:Float in [0.38,0.7] {
    _=populate(frame:0,originX:0,noise:false,roughness:roughness)
    for frame in 0..<8 {
        var values=[SIMD4<Float>](repeating:.zero,count:count),truth=values
        for i in values.indices {
            let signal:Float=0.16+0.04*Float(i%width)/Float(width)
            let noise=(random(UInt32(i)&+UInt32(frame)&*197_633)-0.5)*0.26
            values[i]=SIMD4(SIMD3(repeating:signal+noise),32)
            truth[i]=SIMD4(SIMD3(repeating:signal),32)
        }
        let a=residualSpatial(spatial,values),b=residualSpatial(fixedStrengthSpatial,values)
        residualCurrent += pow(rmse(a,truth),2);residualControl += pow(rmse(b,truth),2)
    }
}
let residualRatio=sqrt(residualCurrent/residualControl)
require(residualRatio<0.90,"Valid rough-surface histories did not reduce residual RMS by at least ten percent over fixed sample-count strength")
// A coherent, one-pixel-wide illumination line must not be classified as noise,
// even when it has no albedo or geometry edge. Cover all four grid directions.
for direction in 0..<4 {
    _=populate(frame:0,originX:0,noise:false,roughness:0.7)
    var values=[SIMD4<Float>](repeating:.zero,count:count)
    for y in 0..<height {for x in 0..<width {
        let coordinate=direction==0 ? x:direction==1 ? y:direction==2 ? x+y:x-y
        let lit=((coordinate%16)+16)%16==0
        values[y*width+x]=SIMD4(SIMD3(repeating:lit ? Float(1):0.02),32)
    }}
    let a=residualSpatial(spatial,values),b=residualSpatial(fixedStrengthSpatial,values)
    for i in a.indices {require(simd_length(a[i]-b[i])<0.00001,"Adaptive residual filtering blurred a coherent illumination line")}
}
for flag:Float in [0.125,0.25,0.5,0.75,0.875] {
    _=populate(frame:0,originX:0,noise:true,roughness:0.6)
    var points=read(worlds[0]),values=read(raw)
    for i in points.indices {points[i].w=flag;values[i].w=32}
    write(points,worlds[0])
    let a=residualSpatial(spatial,values),b=residualSpatial(fixedStrengthSpatial,values)
    for i in a.indices {require(simd_length(a[i]-b[i])<0.00001,"Adaptive residual filtering changed protected glass/metal/emitter/dynamic coverage")}
}
print(String(format:"PASS: converged rough-history residual RMS ratio %.6f versus fixed-strength control; four coherent one-pixel illumination directions and all five protected coverage tags unchanged",residualRatio))
