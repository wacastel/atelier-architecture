import Foundation
import Metal
import simd
import CryptoKit

let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }

var checks=0
func check(_ condition: Bool, _ description: String) {
    checks += 1
    if !condition { fatalError(description) }
}
guard let device=MTLCreateSystemDefaultDevice() else { fatalError("Metal required") }
let output=URL(fileURLWithPath:ProcessInfo.processInfo.environment["ATELIER_PIPELINE_TEST_OUTPUT"] ?? "output/startup-pipeline-validation")
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let cacheDirectory=output.appendingPathComponent("cache-" + UUID().uuidString)
defer { try? FileManager.default.removeItem(at:cacheDirectory) }
let source="""
#include <metal_stdlib>
using namespace metal;
kernel void twice(device uint *v [[buffer(0)]], uint t [[thread_position_in_grid]]) { v[t] = t * 2; }
struct Vertex { float4 position [[position]]; };
vertex Vertex screen(uint i [[vertex_id]]) { float2 p[3] = {float2(-1,-1),float2(3,-1),float2(-1,3)}; return {float4(p[i],0,1)}; }
fragment float4 solid() { return float4(0.2,0.4,0.8,1); }
"""
let library=try device.makeLibrary(source:source,options:nil)
let function=library.makeFunction(name:"twice")!
func descriptor()->MTLRenderPipelineDescriptor {
    let d=MTLRenderPipelineDescriptor();d.vertexFunction=library.makeFunction(name:"screen");d.fragmentFunction=library.makeFunction(name:"solid");d.colorAttachments[0].pixelFormat = .bgra8Unorm;return d
}
func execute(_ pipeline:MTLComputePipelineState)->[UInt32] {
    let buffer=device.makeBuffer(length:64*4,options:.storageModeShared)!
    let command=device.makeCommandQueue()!.makeCommandBuffer()!,encoder=command.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(pipeline);encoder.setBuffer(buffer,offset:0,index:0)
    encoder.dispatchThreads(MTLSize(width:64,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:32,height:1,depth:1))
    encoder.endEncoding();command.commit();command.waitUntilCompleted();check(command.error==nil,"Compute command must succeed")
    return Array(UnsafeBufferPointer(start:buffer.contents().assumingMemoryBound(to:UInt32.self),count:64))
}
let identity=MetalPipelineCache.digest(Data(source.utf8))+"|fixture-executable-v1"
let cold=MetalPipelineCache(device:device,identity:identity,directory:cacheDirectory)
let initial=try cold.compute(function);_ = try cold.render(descriptor());cold.save()
check(!cold.loaded,"Cold archive must not be reported as loaded")
check(cold.misses==2,"Cold compute and render entries must miss")
check(cold.saveSucceeded,"Cold archive must serialize")
let expected=(0..<64).map{UInt32($0*2)}
check(execute(initial)==expected,"Cold compute produces expected output")
let warm=MetalPipelineCache(device:device,identity:identity,directory:cacheDirectory)
let cached=try warm.compute(function);_ = try warm.render(descriptor());warm.save()
check(warm.loaded,"Warm archive must load")
check(warm.hits==2 && warm.misses==0,"Warm compute and render must prove binary-archive hits")
check(!warm.saveSucceeded,"Warm read must not rewrite archive")
check(execute(cached)==expected,"Warm compute must equal uncached")
let changed=MetalPipelineCache(device:device,identity:identity+"new-code",directory:cacheDirectory)
_ = try changed.compute(function)
check(!changed.loaded && changed.misses==1,"Changed source/executable identity must invalidate archive")
let archivePath=cold.statistics["path"] as! String
try Data("broken archive".utf8).write(to:URL(fileURLWithPath:archivePath),options:.atomic)
let corrupt=MetalPipelineCache(device:device,identity:identity,directory:cacheDirectory)
check(execute(try corrupt.compute(function))==expected,"Corrupt archive must fall back without changing output")
corrupt.save();check(corrupt.saveSucceeded,"Corrupt archive must be repairable")
let repaired=MetalPipelineCache(device:device,identity:identity,directory:cacheDirectory)
_ = try repaired.compute(function)
check(repaired.loaded && repaired.hits==1,"Repaired archive must yield real hits")
let disabled=MetalPipelineCache(device:device,identity:identity,directory:nil)
check(execute(try disabled.compute(function))==expected,"Disabled cache must preserve output")
let unwritable=MetalPipelineCache(device:device,identity:identity,directory:URL(fileURLWithPath:"/dev/null/atelier-test"))
check(execute(try unwritable.compute(function))==expected,"Unavailable cache directory must preserve output")
// Real spatial batching is exactly preserved, including glass classification
// and small non-512 final blocks. Corrupt/mismatched files regenerate safely.
var scene=SceneData()
scene.materials=[SceneMaterial(SIMD3(0.7,0.6,0.5)),SceneMaterial(SIMD3(0.3,0.5,0.7),transmission:0.8)]
for triangle in 0..<18453 {
    let x=Float(triangle / 2048) * 200, y=Float(triangle % 40)
    scene.vertices += [SceneVertex(SIMD3(x,y,0),SIMD3(0,0,1)),
        SceneVertex(SIMD3(x+1,y,0),SIMD3(0,0,1)),SceneVertex(SIMD3(x,y+1,0),SIMD3(0,0,1))]
    scene.materialIndices.append(triangle % 1500 == 0 ? 1:0)
}
let batchDir=cacheDirectory.appendingPathComponent("raster")
let batchKey="fixture-scene-v1"
func batchesEqual(_ a:[RasterBatch],_ b:[RasterBatch])->Bool {
    a.count==b.count && zip(a,b).allSatisfy { x,y in
        x.firstTriangle==y.firstTriangle && x.triangleCount==y.triangleCount && x.minimum==y.minimum && x.maximum==y.maximum && x.transparent==y.transparent
    }
}
let batchCold=RasterBatchCache.loadOrBuild(scene:scene,directory:batchDir,key:batchKey,forceRebuild:false)
let batchWarm=RasterBatchCache.loadOrBuild(scene:scene,directory:batchDir,key:batchKey,forceRebuild:false)
check(!batchCold.hit && batchCold.saved,"Cold raster batches must save")
check(batchWarm.hit && !batchWarm.saved,"Warm raster batches must load without rewrite")
check(batchesEqual(batchCold.batches,batchWarm.batches),"Warm raster bounds/material classifications must exactly match generated batches")
check(batchWarm.batches.last!.firstTriangle+batchWarm.batches.last!.triangleCount==scene.triangleCount,"Raster cache retains final partial block")
let batchForced=RasterBatchCache.loadOrBuild(scene:scene,directory:batchDir,key:batchKey,forceRebuild:true)
check(!batchForced.hit && batchForced.saved,"Force rebuild must bypass valid raster cache")
let batchChanged=RasterBatchCache.loadOrBuild(scene:scene,directory:batchDir,key:batchKey+"changed",forceRebuild:false)
check(!batchChanged.hit && batchChanged.saved,"Changed scene identity must regenerate raster cache")
let batchFile=batchDir.appendingPathComponent("raster-batches-v1.cache")
var damaged=try Data(contentsOf:batchFile);damaged[damaged.count-12] ^= 1
try damaged.write(to:batchFile,options:.atomic)
let batchCorrupt=RasterBatchCache.loadOrBuild(scene:scene,directory:batchDir,key:batchKey+"changed",forceRebuild:false)
check(!batchCorrupt.hit && batchCorrupt.saved && batchCorrupt.error != nil,"Checksum mismatch must regenerate raster cache")
check(batchesEqual(batchCorrupt.batches,batchCold.batches),"Repair must preserve exact raster geometry")
try Data([0,255]).write(to:batchFile,options:.atomic)
let batchTruncated=RasterBatchCache.loadOrBuild(scene:scene,directory:batchDir,key:batchKey,forceRebuild:false)
check(!batchTruncated.hit && batchTruncated.saved,"Truncated cache must regenerate")
var altered=scene;altered.materialIndices.removeLast();altered.vertices.removeLast(3)
let batchCounts=RasterBatchCache.loadOrBuild(scene:altered,directory:batchDir,key:batchKey,forceRebuild:false)
check(!batchCounts.hit && batchCounts.saved,"Changed triangle count must regenerate even if caller reuses identity")
let batchDisabled=RasterBatchCache.loadOrBuild(scene:scene,directory:nil,key:batchKey,forceRebuild:false)
check(!batchDisabled.hit && !batchDisabled.saved && batchesEqual(batchDisabled.batches,batchCold.batches),"Disabled cache must preserve batches")
let batchUnavailable=RasterBatchCache.loadOrBuild(scene:scene,directory:URL(fileURLWithPath:"/dev/null/atelier-test"),key:batchKey,forceRebuild:false)
check(!batchUnavailable.hit && !batchUnavailable.saved && batchesEqual(batchUnavailable.batches,batchCold.batches),"Unavailable cache directory must preserve batches")
// Exercise every production pipeline (including the seven traffic variants)
// against a tiny deterministic scene. Geometry and the three rendered images
// must remain unchanged when the prepared pipeline/batch files are reused.
var renderScene=SceneData();renderScene.name="Startup renderer fixture"
renderScene.materials=[SceneMaterial(SIMD3(0.7,0.5,0.25),roughness:0.7)]
let corners:[SIMD3<Float>]=[SIMD3(-2,0,0),SIMD3(2,0,0),SIMD3(2,3,0),SIMD3(-2,0,0),SIMD3(2,3,0),SIMD3(-2,3,0)]
renderScene.vertices=corners.map { SceneVertex($0,SIMD3(0,0,1)) };renderScene.materialIndices=[0,0]
renderScene.trafficLanes=[SceneTrafficLane(id:9,points:[SIMD3(1000,0,0),SIMD3(1400,0,0)],speedMetresPerSecond:12,spawnFadeMetres:15)]
let productionDir=cacheDirectory.appendingPathComponent("production")
let coldRenderer=try MetalRenderer(scene:renderScene,device:device,cacheDirectory:productionDir,cacheKey:"full-render-fixture")
let warmRenderer=try MetalRenderer(scene:renderScene,device:device,cacheDirectory:productionDir,cacheKey:"full-render-fixture")
let productionCold=coldRenderer.startupCacheStatistics["pipelines"] as! [String:Any]
let productionWarm=warmRenderer.startupCacheStatistics["pipelines"] as! [String:Any]
let rasterWarm=warmRenderer.startupCacheStatistics["rasterBatches"] as! [String:Any]
check(coldRenderer.trafficVehicleCount>0,"Full-render fixture must instantiate traffic variants")
check(productionCold["misses"] as? Int == 24 && productionCold["saved"] as? Bool == true,"First renderer must archive all 24 production pipelines")
check(productionWarm["hits"] as? Int == 24 && productionWarm["misses"] as? Int == 0,"Warm renderer must prove all 24 production pipeline hits")
check(rasterWarm["hit"] as? Bool == true,"Warm renderer must consume saved raster batches")
let camera=CameraPose(position:SIMD3(0,1.5,6),target:SIMD3(0,1.5,0),fov:55)
for mode in 0..<3 {
    let options=RenderOptions(bounces:1,lighting:1,denoising:false,rayTracing:mode != 2,directRayTracing:mode==1)
    let first=try coldRenderer.renderOffscreen(pose:camera,options:options,width:96,height:64,samples:1)
    let second=try warmRenderer.renderOffscreen(pose:camera,options:options,width:96,height:64,samples:1)
    check(first==second,"Cached renderer must exactly preserve image for mode \(mode)")
}
var presentedTimes:[Double]=[], presentationExact:[Bool]=[]
let presentation=FirstPresentationProbe { time,exact in presentedTimes.append(time);presentationExact.append(exact) }
presentation.record(0);presentation.record(.nan);presentation.record(.infinity);presentation.record(-1)
check(presentedTimes.isEmpty && presentationExact.isEmpty,"Dropped, undisplayed, and invalid timestamps must leave the presentation probe armed")
presentation.record(123.45);presentation.record(123.46);presentation.record(0)
check(presentedTimes==[123.45] && presentationExact==[true],"Only the first positive actual presentation timestamp is reported, exactly once")
let report:[String:Any]=["checks":checks,"passed":true,"device":device.name,"cold":cold.statistics,"warm":warm.statistics,"corrupt":corrupt.statistics,"changed":changed.statistics,"unavailable":unwritable.statistics,"rasterBatchCount":batchCold.batches.count,"productionCold":productionCold,"productionWarm":productionWarm,"productionRaster":rasterWarm,"productionColdPhases":coldRenderer.startupPhaseSeconds,"productionWarmPhases":warmRenderer.startupPhaseSeconds]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("startup-render-cache.json"))
print("PASS: \(checks) startup-render-cache checks")
