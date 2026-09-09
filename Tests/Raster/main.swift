import Foundation
import Metal
import simd

let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
let out=URL(fileURLWithPath:ProcessInfo.processInfo.environment["ATELIER_RASTER_VALIDATION_OUTPUT"] ?? "output/v12-raster-review/fixture",relativeTo:root).standardizedFileURL
var checks=0
func require(_ condition:Bool,_ message:String) { checks += 1;if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)} }
func frame(_ pose:CameraPose,width:Int=100,height:Int=100)->FrameUniforms {
    let f=simd_normalize(pose.target-pose.position),r=simd_normalize(simd_cross(f,SIMD3<Float>(0,1,0))),u=simd_cross(r,f)
    let tangent=tan(pose.fov * .pi/360)
    return FrameUniforms(origin:SIMD4(pose.position,0),right:SIMD4(r*tangent*Float(width)/Float(height),0),up:SIMD4(u*tangent,0),forward:SIMD4(f,0),sunDirection:.zero,sunColor:.zero,viewport:SIMD4(UInt32(width),UInt32(height),0,0),settings:.zero)
}
var scene=SceneData();scene.name="True ray-off regression fixture"
scene.materials=[SceneMaterial(SIMD3(0.32,0.34,0.36)),SceneMaterial(SIMD3(0.04,0.15,0.9),emission:0.6),
                 SceneMaterial(SIMD3(0.85,0.04,0.03),emission:0.6),SceneMaterial(SIMD3(0.72,0.87,0.95),roughness:0.04,transmission:0.93)]
func triangle(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ material:UInt32) {
    let n=simd_normalize(simd_cross(b-a,c-a));scene.vertices += [SceneVertex(a,n),SceneVertex(b,n),SceneVertex(c,n)];scene.materialIndices.append(material)
}
func quad(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ d:SIMD3<Float>,_ m:UInt32) {triangle(a,b,c,m);triangle(a,c,d,m)}
// Emission provides stable known colors independently of analytic environment
// lighting. Glass must reveal the blue panel behind it; the red panel is closer.
quad(SIMD3(-40,0,-120),SIMD3(-40,0,120),SIMD3(40,0,120),SIMD3(40,0,-120),0)
quad(SIMD3(-5,0,0),SIMD3(5,0,0),SIMD3(5,8,0),SIMD3(-5,8,0),1)
quad(SIMD3(-3,1,2),SIMD3(3,1,2),SIMD3(3,7,2),SIMD3(-3,7,2),3)
quad(SIMD3(-4,0,4),SIMD3(-2,0,4),SIMD3(-2,3,4),SIMD3(-4,3,4),2)
// Deliberately separated complete batches: these must be culled, while the
// near geometry crossing the frustum remains included.
for _ in 0..<2048 { triangle(SIMD3(900,0,-2),SIMD3(901,0,-2),SIMD3(900,1,-2),2) }
scene.lights=[SceneLight(positionRadius:SIMD4(0,5,5,0.2),directionCone:SIMD4(0,-1,0,-1),colorPower:SIMD4(1,0.45,0.14,18),parameters:SIMD4(20,1,0,0))]
scene.trafficLanes=[SceneTrafficLane(id:119,points:[SIMD3(0,0.12,-100),SIMD3(0,0.12,100)],speedMetresPerSecond:12,spawnFadeMetres:8)]
let camera=CameraPose(position:SIMD3(0,3,12),target:SIMD3(0,3,0),fov:48)
let batches=RasterGeometry.batches(vertices:scene.vertices,indices:scene.materialIndices,materials:scene.materials)
require(batches.reduce(0){$0+$1.triangleCount}==scene.triangleCount,"Batching must retain every triangle")
var end=0
for b in batches {
    require(b.firstTriangle==end,"Batch ranges must form an exact contiguous partition");end += b.triangleCount
    for v in scene.vertices[b.firstTriangle*3..<(b.firstTriangle+b.triangleCount)*3] {
        require(all(v.position.xyz .>= b.minimum) && all(v.position.xyz .<= b.maximum),"Batch bounds must enclose every referenced vertex")
    }
}
let frustum=RasterFrustum(frame:frame(camera)),visible=batches.filter{frustum.contains($0)}
require(visible.reduce(0){$0+$1.triangleCount}<scene.triangleCount,"Frustum must reject known offscreen geometry")
require(visible.contains{$0.firstTriangle==0},"Visible and near-plane-crossing geometry must remain")
// Test each plane independently including a box containing the camera and a
// distant skyline box; infinite-far reversed-Z must not cull large distances.
func box(_ p:SIMD3<Float>,radius:Float=0.1)->RasterBatch {RasterBatch(firstTriangle:0,triangleCount:1,minimum:p-SIMD3(repeating:radius),maximum:p+SIMD3(repeating:radius),transparent:false)}
require(frustum.contains(box(camera.position,radius:1)),"Camera-containing bounds must not be culled")
require(frustum.contains(box(SIMD3(0,3,-100000))),"No finite far plane may clip the continuous skyline")
for point in [SIMD3<Float>(0,3,20),SIMD3(100,3,0),SIMD3(-100,3,0),SIMD3(0,100,0),SIMD3(0,-100,0)] {
    require(!frustum.contains(box(point)),"A completely outside box must be rejected")
}
// Independent projected point oracle, varying FOV/aspect and camera direction.
for width in [64,128,320] {for height in [64,180] {for fov:Float in [30,52,90] {
    let pose=CameraPose(position:SIMD3(3,5,7),target:SIMD3(-4,2,-13),fov:fov)
    let f=frame(pose,width:width,height:height),test=RasterFrustum(frame:f)
    for x in stride(from:Float(-1),through:1,by:0.2) {for y in stride(from:Float(-1),through:1,by:0.2) {for z:Float in [0.05,1,50,20000] {
        let p=pose.position+(f.forward.xyz+f.right.xyz*x+f.up.xyz*y)*z
        require(test.contains(box(p,radius:max(0.001,z*0.0001))),"Independent projected visible point was wrongly culled")
    }}}
}}}
print("PASS CPU: \(checks) geometry coverage and conservative frustum checks")
if CommandLine.arguments.contains("--cpu") {exit(0)}
guard let device=MTLCreateSystemDefaultDevice() else {fatalError("Metal unavailable")}
let renderer=try MetalRenderer(scene:scene,device:device)
let expectedRasterSamples=device.supportsTextureSampleCount(4) ? 4 : device.supportsTextureSampleCount(2) ? 2 : 1
require(renderer.rasterStatistics["rasterSamples"] as? Int == expectedRasterSamples,"Raster must select supported4×MSAA with2×/1×fallback")
let width=192,height=128
var options=RenderOptions(rayTracing:false)
let fleet=TrafficFleet(lanes:scene.trafficLanes)
let time=(100-fleet.vehicles[0].phase)/12
renderer.setSceneTime(time)
let trace=renderer.rayTracingDispatchCount,guides=renderer.surfaceGuideDispatchCount,updates=renderer.trafficUpdateCount,seed=renderer.frameSeed
let a=try renderer.renderPreviewOffscreen(pose:camera,options:options,width:width,height:height,samples:1)
let b=try renderer.renderOffscreen(pose:camera,options:options,width:width,height:height,samples:2048)
require(a==b,"Ray-off paused frames must be deterministic and independent of SPP")
require(renderer.rayTracingDispatchCount==trace && renderer.surfaceGuideDispatchCount==guides && renderer.trafficUpdateCount==updates,"Ray-off must submit no ray, surface-guide or traffic AS work")
require(renderer.sampleCount==0 && renderer.frameSeed==seed,"Ray-off must not accumulate Monte Carlo samples")
require(renderer.rasterTrafficTransformCount==1,"Same-time raster traffic transforms must be reused")
let data=[UInt8](a),center=(height/4*width+width/2)*4
print("Glass center BGRA: \(Array(data[center..<center+4]))")
try writePNG(a,width:width,height:height,to:out.appendingPathComponent("day.png"))
require(Int(data[center])>Int(data[center+2])+20,"Transparent sheet must reveal the blue architecture behind it")
require(Set(stride(from:0,to:data.count,by:4).map{data[$0]}).count>20,"Raster output must contain shaded architecture, not a constant clear color")
for i in stride(from:3,to:data.count,by:4) {require(data[i]==255,"Presentation must remain opaque BGRA")}
options.denoising=false
let pair=try renderer.renderPreviewComparisonOffscreen(pose:camera,options:options,width:width,height:height,samples:32)
require(pair.raw==a && pair.reconstructed==a,"Paired and denoiser-disabled raster must retain one identical frame")
let resized=try renderer.renderOffscreen(pose:camera,options:options,width:113,height:79,samples:1)
require(resized.count==113*79*4,"Raster resize/readback dimensions incorrect")
let restored=try renderer.renderOffscreen(pose:camera,options:options,width:width,height:height,samples:1)
require(restored==a,"Resize must restore the same camera and image")
options.lighting=2
let night=try renderer.renderOffscreen(pose:camera,options:options,width:width,height:height,samples:1)
require(night != a,"Night lighting toggle must affect raster output")
renderer.setSceneTime(time+0.25)
let moved=try renderer.renderOffscreen(pose:camera,options:options,width:width,height:height,samples:1)
require(zip(moved,night).filter{$0 != $1}.count>20,"Raster traffic must visibly move at a changed absolute scene time")
require(renderer.rasterTrafficTransformCount==2 && renderer.trafficUpdateCount==updates,"Moving raster traffic must not refit ray tracing acceleration structures")
require(renderer.rayTracingDispatchCount==trace && renderer.surfaceGuideDispatchCount==guides,"All ray-off capture variants must bypass tracing")
options.rayTracing=true
_ = try renderer.renderPreviewOffscreen(pose:camera,options:options,width:width,height:height,samples:2,resetHistory:true)
require(renderer.rayTracingDispatchCount==trace+2 && renderer.sampleCount==2,"Switching back must restore actual path tracing")
require(renderer.trafficUpdateCount==updates+1,"RT must update the traffic BVH once at the current raster timeline")
let finalTrace=renderer.rayTracingDispatchCount,finalGuides=renderer.surfaceGuideDispatchCount,finalUpdates=renderer.trafficUpdateCount
options.rayTracing=false
_ = try renderer.renderOffscreen(pose:camera,options:options,width:width,height:height,samples:999)
require(renderer.rayTracingDispatchCount==finalTrace && renderer.surfaceGuideDispatchCount==finalGuides && renderer.trafficUpdateCount==finalUpdates,"RT→raster must again bypass all ray/AS passes")
try writePNG(a,width:width,height:height,to:out.appendingPathComponent("day.png"))
try writePNG(night,width:width,height:height,to:out.appendingPathComponent("night.png"))
var report=renderer.rasterStatistics;report["checks"]=checks;report["status"]="PASS";report["gpu"]=device.name
report["scope"]="Small actual-kernel multisample resolve/geometry/depth/glass/day-night/traffic/resize/capture/mode-switch fixture; deterministic same-time captures across one and2048requestedSPP. Device-supported sample count recorded; fallback devices not exercised onthishost. No full-city performance or visual-fidelity claim"
let json=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try json.write(to:out.appendingPathComponent("validation.json"))
print("PASS GPU: \(checks) total checks; true ray-off across all capture paths, traffic without AS updates, deterministic frames, transparent depth, resize and RT restoration")
