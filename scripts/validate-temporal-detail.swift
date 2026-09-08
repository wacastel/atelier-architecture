#!/usr/bin/env swift
// Same-material moving illumination detail: real production Metal kernels,
// exact pixel-integrated truth, and independent noise/detail measurements.
// Run: swift scripts/validate-temporal-detail.swift [--shader PATH] [--report PATH]
// This fixture does not render scene geometry or change production inputs.
import Foundation
import Metal
import simd
import CryptoKit
import Darwin
setbuf(stdout, nil)

struct DetailUniforms {
    var previousOrigin, previousRight, previousUp, previousForward: SIMD4<Float>
    var currentOrigin: SIMD4<Float>
    var sizeFlags: SIMD4<UInt32>
    var settings: SIMD4<Float>
}
let root = URL(fileURLWithPath: #filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
var shaderURL = root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Denoise.metal")
var reportURL: URL?
var arg = 1
while arg < CommandLine.arguments.count {
    let flag = CommandLine.arguments[arg]
    guard arg + 1 < CommandLine.arguments.count else { fatalError("Missing value for \(flag)") }
    let value = URL(fileURLWithPath: CommandLine.arguments[arg + 1])
    switch flag {
    case "--shader": shaderURL = value
    case "--report": reportURL = value
    default: fatalError("Unknown argument \(flag)")
    }
    arg += 2
}
precondition(MemoryLayout<DetailUniforms>.stride == 112, "Temporal uniform ABI changed")
guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
    fatalError("A local Metal GPU is required")
}
let source = try String(contentsOf: shaderURL, encoding: .utf8)
let compileOptions = MTLCompileOptions(); compileOptions.languageVersion = .version3_1
let library = try device.makeLibrary(source: source, options: compileOptions)
let temporal = try device.makeComputePipelineState(function: library.makeFunction(name: "temporalResolve")!)
let spatial = try device.makeComputePipelineState(function: library.makeFunction(name: "spatialFilter")!)
// Negative control changes only confidence, not RGB or any geometry guides.
// Feeding confidence=1 at EVERY spatial pass reproduces current-SPP-only
// strength, even if the tested kernel correctly propagates accepted history.
let controlLibrary = try device.makeLibrary(source: """
#include <metal_stdlib>
using namespace metal;
kernel void oneFrameConfidence(texture2d<float,access::read> input [[texture(0)]],
                               texture2d<float,access::write> output [[texture(1)]],
                               uint2 p [[thread_position_in_grid]]) {
    if (p.x>=input.get_width() || p.y>=input.get_height()) return;
    output.write(float4(input.read(p).rgb,1.0f),p);
}
""", options: compileOptions)
let forceOne = try device.makeComputePipelineState(function: controlLibrary.makeFunction(name: "oneFrameConfidence")!)
let width = 192, height = 64, pixelCount = width * height, frames = 48, warmup = 16
let region = MTLRegionMake2D(0, 0, width, height)
let worldPixel: Float = 10 / Float(width)
func makeTexture(_ name: String) -> MTLTexture {
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: width, height: height, mipmapped: false)
    descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite]
    let texture = device.makeTexture(descriptor: descriptor)!; texture.label = name
    let zero = [SIMD4<Float>](repeating: .zero, count: pixelCount)
    zero.withUnsafeBytes { texture.replace(region: region, mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
    return texture
}
func write(_ values: [SIMD4<Float>], _ texture: MTLTexture) {
    values.withUnsafeBytes { texture.replace(region: region, mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width * 16) }
}
func read(_ texture: MTLTexture) -> [SIMD4<Float>] {
    var values = [SIMD4<Float>](repeating: .zero, count: pixelCount)
    values.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: width * 16, from: region, mipmapLevel: 0) }
    return values
}
func random(_ key: UInt32) -> Float {
    var x = key; x ^= x >> 16; x = x &* 0x7feb352d; x ^= x >> 15; x = x &* 0x846ca68b; x ^= x >> 16
    return Float(x >> 8) / 16_777_216
}
struct DetailPattern {
    let name: String
    let stripeWidth: Double // 0: half-plane shadow; negative: uniform plane
    func measure(_ t: Double) -> Double {
        if stripeWidth < 0 { return 0 }
        if stripeWidth == 0 { return max(t, 0) }
        let cycle = floor(t / 24), within = t - cycle * 24
        return cycle * stripeWidth + min(max(within - 10, 0), stripeWidth)
    }
    func truth(_ t: Double) -> Float {
        // Exact unit-width box-filter integral, not a center-sampled step that
        // aliases independently of temporal reconstruction during a pan.
        Float(1 - 0.7 * (measure(t + 0.5) - measure(t - 0.5)))
    }
    func edgeDistance(_ t: Double) -> Double {
        if stripeWidth < 0 { return .infinity }
        if stripeWidth == 0 { return abs(t) }
        let within = t - floor(t / 24) * 24
        return min(abs(within - 10), abs(within - 10 - stripeWidth))
    }
}
struct Errors {
    var squared: Double = 0, samples = 0
    var truthSum: Double = 0, valueSum: Double = 0, truthSquared: Double = 0, product: Double = 0
    mutating func add(_ value: Float, _ truth: Float) {
        let a = Double(value), b = Double(truth)
        squared += (a-b)*(a-b); samples += 1
        truthSum += b; valueSum += a; truthSquared += b*b; product += a*b
    }
    var rms: Double { samples > 0 ? sqrt(squared / Double(samples)) : 0 }
    var contrastSlope: Double {
        let n = Double(max(samples, 1)), denominator = truthSquared - truthSum*truthSum/n
        return denominator > 1e-10 ? (product-truthSum*valueSum/n)/denominator : 1
    }
    var json: [String: Any] { ["rmse": rms, "samples": samples, "contrastSlope": contrastSlope] }
}
struct DetailMetrics {
    var edge = Errors(), flat = Errors(), all = Errors()
    var json: [String: Any] { ["edge": edge.json, "flat": flat.json, "all": all.json] }
}
var checks = [[String: Any]](), failures = [String]()
func check(_ condition: Bool, _ message: String) {
    checks.append(["passed": condition, "assertion": message])
    if !condition { failures.append(message) }
    print("\(condition ? "PASS" : "FAIL"): \(message)")
}
struct SequenceResult {
    var metrics: [String: DetailMetrics]
    var minimumStableHistory: Float, maximumCountError: Float
    var resetRGBError: Float, resetMinimumCount: Float, resetMaximumCount: Float
}
func sequence(_ pattern: DetailPattern, pixelsPerFrame: Double, noise: Bool) throws -> SequenceResult {
    let raw = makeTexture("current radiance"), albedo = makeTexture("same material albedo")
    let worlds = [makeTexture("world 0"), makeTexture("world 1")]
    let normals = [makeTexture("normal 0"), makeTexture("normal 1")]
    let histories = [makeTexture("history 0"), makeTexture("history 1")]
    let combined = [makeTexture("combined 0"), makeTexture("combined 1")]
    let spatialOnly = [makeTexture("spatial only 0"), makeTexture("spatial only 1")]
    let lostConfidence = [makeTexture("negative 0"), makeTexture("negative 1")]
    let oneFrame = makeTexture("one frame confidence scratch")
    var metrics = Dictionary(uniqueKeysWithValues: ["raw", "temporalOnly", "spatialOnly", "combined", "lostConfidenceControl"].map { ($0, DetailMetrics()) })
    var stableMinimum: Float = .infinity, countError: Float = 0
    var resetError: Float = 0, resetMinimum: Float = .infinity, resetMaximum: Float = 0
    // Last frame is an explicit invalid-history reveal. It is excluded from
    // steady-state error statistics and must recover original 1-frame strength.
    for frame in 0...frames {
        let offset = Double(frame) * pixelsPerFrame
        let originX = Float(offset) * worldPixel
        let previousX = Float(Double(max(0, frame-1)) * pixelsPerFrame) * worldPixel
        let current = frame % 2, previous = 1-current
        var values = [SIMD4<Float>](repeating: .zero, count: pixelCount), points = values, normal = values, colors = values
        var truth = [Float](repeating: 0, count: pixelCount)
        for y in 0..<height { for x in 0..<width {
            let i = y*width+x, t = Double(x) + 0.5 - Double(width)/2 + offset
            let sx = 2*(Float(x)+0.5)/Float(width)-1
            let sy = (1-2*(Float(y)+0.5)/Float(height))*Float(height)/Float(width)
            let delta = SIMD3<Float>(sx*5, sy*5, 5)
            points[i] = SIMD4(delta+SIMD3(originX,0,0),0)
            normal[i] = SIMD4(0,0,-1,simd_length(delta))
            colors[i] = SIMD4(0.55,0.55,0.55,0.72)
            truth[i] = pattern.truth(t)
            // Independent, bounded additive MC-like noise; amplitude never
            // clips the 0.3-radiance shadow, so the input remains unbiased.
            let perturbation = noise ? (random(UInt32(i) &+ UInt32(frame) &* 197_633)-0.5)*0.52 : 0
            values[i] = SIMD4(SIMD3(repeating: truth[i]+perturbation),normal[i].w)
        } }
        write(values,raw); write(points,worlds[current]); write(normal,normals[current]); write(colors,albedo)
        var u = DetailUniforms(previousOrigin:SIMD4(previousX,0,0,0),previousRight:SIMD4(1,0,0,0),previousUp:SIMD4(0,Float(height)/Float(width),0,0),previousForward:SIMD4(0,0,1,0),currentOrigin:SIMD4(originX,0,0,0),sizeFlags:SIMD4(UInt32(width),UInt32(height),frame>0 && frame<frames ? 1:0,1),settings:SIMD4(32,8,1,2/Float(width)))
        let command = queue.makeCommandBuffer()!
        func dispatch(_ pipeline: MTLComputePipelineState, _ textures: [MTLTexture]) {
            let e = command.makeComputeCommandEncoder()!; e.setComputePipelineState(pipeline)
            for (index, texture) in textures.enumerated() { e.setTexture(texture,index:index) }
            if pipeline !== forceOne { e.setBytes(&u,length:MemoryLayout<DetailUniforms>.stride,index:0) }
            e.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1)); e.endEncoding()
        }
        dispatch(temporal,[raw,worlds[current],normals[current],albedo,histories[previous],worlds[previous],normals[previous],histories[current]])
        func filter(_ input: MTLTexture, _ outputs: [MTLTexture], forcingOne: Bool) {
            for (index, step) in [1,2,4].enumerated() {
                let stageInput = index==0 ? input:outputs[(index-1)%2]
                if forcingOne { dispatch(forceOne,[stageInput,oneFrame]) }
                u.settings.z = Float(step)
                dispatch(spatial,[forcingOne ? oneFrame:stageInput,worlds[current],normals[current],albedo,outputs[index%2]])
            }
        }
        filter(histories[current],combined,forcingOne:false)
        filter(raw,spatialOnly,forcingOne:true)
        filter(histories[current],lostConfidence,forcingOne:true)
        command.commit(); command.waitUntilCompleted(); if let error = command.error { throw error }
        let history = read(histories[current]), full = read(combined[0]), only = read(spatialOnly[0]), lost = read(lostConfidence[0])
        let images = ["raw":values,"temporalOnly":history,"spatialOnly":only,"combined":full,"lostConfidenceControl":lost]
        for image in images.values {
            precondition(image.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w.isFinite }, "Non-finite GPU output")
        }
        for y in 8..<(height-8) { for x in 16..<(width-16) {
            let i = y*width+x
            if frame == frames {
                resetError = max(resetError,abs(full[i].x-only[i].x))
                resetMinimum = min(resetMinimum,full[i].w); resetMaximum = max(resetMaximum,full[i].w)
                continue
            }
            guard frame >= warmup else { continue }
            let d = pattern.edgeDistance(Double(x)+0.5-Double(width)/2+offset)
            countError = max(countError,abs(full[i].w-history[i].w))
            if d>5 { stableMinimum = min(stableMinimum,history[i].w) }
            for (name, image) in images {
                metrics[name]!.all.add(image[i].x,truth[i])
                if d<=2.5 { metrics[name]!.edge.add(image[i].x,truth[i]) }
                if d>5 { metrics[name]!.flat.add(image[i].x,truth[i]) }
            }
        } }
    }
    return SequenceResult(metrics:metrics,minimumStableHistory:stableMinimum,maximumCountError:countError,resetRGBError:resetError,resetMinimumCount:resetMinimum,resetMaximumCount:resetMaximum)
}

var results = [[String: Any]]()
let patterns = [DetailPattern(name:"one-pixel-shadow",stripeWidth:1),DetailPattern(name:"two-pixel-shadow",stripeWidth:2),DetailPattern(name:"four-pixel-shadow",stripeWidth:4),DetailPattern(name:"sun-shadow-step",stripeWidth:0)]
var negativeControlCaught = 0
for pattern in patterns {
    let result = try sequence(pattern,pixelsPerFrame:0.37,noise:true), m = result.metrics
    let raw = m["raw"]!, temporal = m["temporalOnly"]!, combined = m["combined"]!, negative = m["lostConfidenceControl"]!
    check(temporal.flat.rms < raw.flat.rms*0.45,"\(pattern.name): valid history reduces flat-region RMS noise by more than 55%")
    check(combined.flat.rms < raw.flat.rms*0.45,"\(pattern.name): full reconstruction retains useful diffuse noise reduction")
    check(combined.edge.rms < negative.edge.rms,"\(pattern.name): preserving confidence improves edge RMSE over current-SPP-only negative control")
    // A small numerical tolerance permits an imperfect but useful resampling
    // result. It does not allow broad flat regions to hide softened edges.
    check(combined.edge.rms <= temporal.edge.rms*1.08,"\(pattern.name): extra spatial passes add at most 8% edge-band RMS error to temporal-only result")
    check(result.maximumCountError == 0,"\(pattern.name): spatial passes retain each center's exact temporal confidence")
    check(result.resetMinimumCount == 1 && result.resetMaximumCount == 1 && result.resetRGBError < 0.000001,"\(pattern.name): invalid history restores one-frame confidence and original spatial-only RGB")
    if negative.edge.rms > temporal.edge.rms*1.08 { negativeControlCaught += 1 }
    print(String(format:"DETAIL %@: edge raw %.6f / temporal %.6f / spatial %.6f / combined %.6f / confidence-lost %.6f",pattern.name,raw.edge.rms,temporal.edge.rms,m["spatialOnly"]!.edge.rms,combined.edge.rms,negative.edge.rms))
    results.append(["name":pattern.name,"noise":true,"pixelsPerFrame":0.37,"metrics":m.mapValues{$0.json},"minimumStableHistory":result.minimumStableHistory,"maximumConfidenceError":result.maximumCountError,"resetRGBError":result.resetRGBError])
}
check(negativeControlCaught>=2,"Lost-confidence GPU negative control exposes excessive edge error in at least two patterns")
// Diagnostic controls separate bilinear history resampling diffusion from the
// composition regression. Zero-error assertions are inappropriate for box-
// filtered subpixel images repeatedly interpolated at noninteger positions.
// Integer-pixel reprojection should, however, preserve exact noiseless history.
for shift in [0.37,1.0] {
    let result = try sequence(patterns[1],pixelsPerFrame:shift,noise:false)
    if shift==1 { check(result.metrics["temporalOnly"]!.all.rms<0.00001,"Integer-pixel pan preserves noiseless same-material shadow history") }
    results.append(["name":"noiseless-two-pixel-shadow","noise":false,"pixelsPerFrame":shift,"diagnosticOnly":shift != 1,"metrics":result.metrics.mapValues{$0.json}])
}

// Test the scope of each active a-trous stencil independently. Sparse center
// guides see one window; other dark-center guides still have valid incoming
// fractional radiance from unresolved thin windows. The input here is the HDR
// arriving at THIS pass. An exact bypass preserves it; this fixture does not
// claim to recover any changes an earlier pass may already have introduced.
func validateEmitterSupport() throws -> [String: Any] {
    let expanded = "for (int y = -2*step; y <= 2*step; ++y) for (int x = -2*step; x <= 2*step; ++x) {"
    let original = "for (int y = -2; y <= 2; ++y) for (int x = -2; x <= 2; ++x) {"
    guard source.components(separatedBy:expanded).count == 2 else {
        check(false,"Expanded emitter-support negative-control hook must occur exactly once")
        return ["hookFound":false]
    }
    let oldSource = source.replacingOccurrences(of:expanded,with:original)
    let oldLibrary = try device.makeLibrary(source:oldSource,options:compileOptions)
    let oldSpatial = try device.makeComputePipelineState(function:oldLibrary.makeFunction(name:"spatialFilter")!)
    let input = makeTexture("coverage HDR"), world = makeTexture("coverage world"), normal = makeTexture("coverage normal"), color = makeTexture("coverage color")
    let output = makeTexture("expanded support output"), oldOutput = makeTexture("original support output")
    let cx = width/2, cy = height/2
    var cases = [[String: Any]](), totalExposed = 0
    for step in [1,2,4] {
        for mode in ["coarse-night","coarse-day","near-night"] {
            let night = mode != "coarse-day", depth: Float = mode == "near-night" ? 5:100
            var hdr = [SIMD4<Float>](repeating:.zero,count:pixelCount), points = hdr, normals = hdr, albedo = hdr
            let background = SIMD3<Float>(0.015,0.018,0.023)
            for y in 0..<height { for x in 0..<width {
                let i = y*width+x, d = max(abs(x-cx),abs(y-cy)), emitter = d==0
                let point = SIMD3<Float>((2*(Float(x)+0.5)/Float(width)-1)*depth,(1-2*(Float(y)+0.5)/Float(height))*Float(height)/Float(width)*depth,depth)
                points[i] = SIMD4(point,emitter ? 0.5:0)
                normals[i] = SIMD4(0,0,-1,simd_length(point))
                albedo[i] = SIMD4(0.08,0.09,0.10,0.6)
                // Every ring has nonconstant, finite incoming mixed coverage;
                // its exact values are truth for this bypass contract. Outside
                // the rings is an independent zero-mean-noise flat panel.
                let rgb: SIMD3<Float>
                if emitter { rgb = SIMD3(0.8,0.4,0.1) }
                else if d<=9 {
                    let fraction = Float((x*7+y*3)%5+1)*0.015
                    rgb = background*(1-fraction)+SIMD3<Float>(0.8,0.4,0.1)*fraction
                } else {
                    let noise = (random(UInt32(i)&+789_131)-0.5)*0.012
                    rgb = background+SIMD3(repeating:noise)
                }
                // Coarse night temporal resolve intentionally restarts at one.
                hdr[i] = SIMD4(rgb,1)
            } }
            write(hdr,input); write(points,world); write(normals,normal); write(albedo,color)
            var u = DetailUniforms(previousOrigin:.zero,previousRight:SIMD4(1,0,0,0),previousUp:SIMD4(0,Float(height)/Float(width),0,0),previousForward:SIMD4(0,0,1,0),currentOrigin:SIMD4(0,0,0,night ? 1:0),sizeFlags:SIMD4(UInt32(width),UInt32(height),1,1),settings:SIMD4(32,8,Float(step),2/Float(width)))
            let command = queue.makeCommandBuffer()!
            for (pipeline,target) in [(spatial,output),(oldSpatial,oldOutput)] {
                let e = command.makeComputeCommandEncoder()!; e.setComputePipelineState(pipeline)
                for (index,t) in [input,world,normal,color,target].enumerated() { e.setTexture(t,index:index) }
                e.setBytes(&u,length:MemoryLayout<DetailUniforms>.stride,index:0)
                e.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1)); e.endEncoding()
            }
            command.commit(); command.waitUntilCompleted(); if let error = command.error { throw error }
            let now = read(output), before = read(oldOutput)
            precondition(now.allSatisfy{$0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w.isFinite},"Non-finite emitter-support output")
            var protected = 0, protectedMismatch = 0, oldOuterChanged = 0, ringCounts = [Int:Int](), oldMaximumError: Float = 0
            var flatRaw = Errors(), flatFiltered = Errors(), outsideChanged = 0
            for y in 8..<(height-8) { for x in 16..<(width-16) {
                let i = y*width+x, d = max(abs(x-cx),abs(y-cy))
                if d<=2*step {
                    protected += 1; ringCounts[d,default:0] += 1
                    if now[i] != hdr[i] { protectedMismatch += 1 }
                    if d>2 && before[i] != hdr[i] {
                        oldOuterChanged += 1
                        oldMaximumError = max(oldMaximumError,abs(before[i].x-hdr[i].x),abs(before[i].y-hdr[i].y),abs(before[i].z-hdr[i].z))
                    }
                }
                // Farther than the entire current stencil from coverage rings:
                // a guard that bypasses all far-night pixels must fail here.
                if d>9+2*step {
                    flatRaw.add(hdr[i].x,background.x); flatFiltered.add(now[i].x,background.x)
                    if now[i] != hdr[i] { outsideChanged += 1 }
                }
            } }
            if mode == "coarse-night" {
                check(protectedMismatch==0,"Step \(step): all \(protected) coarse-night pixels within radius \(2*step) preserve exact incoming RGBA")
                check(ringCounts[2*step]==16*step,"Step \(step): outer square ring including corners is actually exercised")
                check(outsideChanged>0 && flatFiltered.rms<flatRaw.rms,"Step \(step): ordinary noise beyond protected support still reduces")
                if step>1 {
                    check(oldOuterChanged>0,"Step \(step): original radius-2 GPU control changes valid dark-center coverage outside its guard")
                    totalExposed += oldOuterChanged
                } else {
                    check(now==before,"Step 1 remains exactly equivalent to original radius-2 guard")
                }
            } else {
                check(now==before,"Step \(step): \(mode) output is exactly unchanged by expanded coarse-night guard")
            }
            cases.append(["step":step,"mode":mode,"radius":2*step,"protectedSamples":protected,"protectedMismatches":protectedMismatch,"originalGuardChangedOuterSamples":oldOuterChanged,"originalGuardMaximumRGBError":oldMaximumError,"flatRawRMSE":flatRaw.rms,"flatFilteredRMSE":flatFiltered.rms,"ringCounts":Dictionary(uniqueKeysWithValues:ringCounts.map{(String($0.key),$0.value)})])
        }
    }
    check(totalExposed>0,"Expanded-support fixture exposes the original guard's coverage loss")
    return ["cases":cases,"negativeControl":"Only replace expanded 2*step emitter-search bounds with original radius 2; all production shading, confidence and other safeguards remain identical.","assumptions":["The >0.25 m night guard is conservative coverage protection, not an estimate of an individual window's physical radius.","Input values are known incoming current-pass coverage; exact identity, not a calibrated RMSE tolerance, is required inside the guarded square.","Each spatial pass is isolated: preserving an input cannot undo blur from prior passes.","Daytime and near-footprint cases must remain bit-identical to the original-radius shader."]]
}
let emitterSupport = try validateEmitterSupport()
let report: [String: Any] = ["passed":failures.isEmpty,"device":device.name,"shaderPath":shaderURL.path,"shaderSHA256":SHA256.hash(data:Data(source.utf8)).map{String(format:"%02x",$0)}.joined(),"width":width,"height":height,"frames":frames,"warmupFrames":warmup,"currentSPP":8,"maximumHistory":32,"scope":"Real production temporal and three spatial GPU passes on a same-material plane; exact box-filtered reference; raw inputs shared by all ablations; additional per-pass coarse-night coverage fixture; no scene ray tracing or FPS claim","criteriaNote":"Edge and flat-region errors measured independently. Eight-percent temporal-to-combined edge tolerance is a new fixture quality budget, not a change to existing scene-validation thresholds. Emitter-support protection uses exact RGBA identity, ring cardinality, negative-control change detection and bit-exact unaffected-mode comparisons.","results":results,"emitterSupport":emitterSupport,"checks":checks,"failures":failures,"limits":["Synthetic additive noise does not model all BRDF, visibility, or low-SPP outliers.","Fractional-pan noiseless diagnostics expose residual temporal resampling bias but do not assert that all such bias is eliminated.","The detail negative control discards confidence only; it is not a complete historical shader snapshot."]]
if let reportURL {
    try FileManager.default.createDirectory(at:reportURL.deletingLastPathComponent(),withIntermediateDirectories:true)
    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:reportURL)
}
print("\(failures.isEmpty ? "PASS":"FAIL"): moving same-material temporal-detail fixture (\(failures.count) failed checks)")
exit(failures.isEmpty ? 0:1)
