import Foundation
import Metal
import CryptoKit
import simd

// Bounded production-renderer check: no city build, window, music or replacement integrator.
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
let output=URL(fileURLWithPath:ProcessInfo.processInfo.environment["ATELIER_SUNSET_LIGHTS_OUTPUT"] ?? "output/sunset-lights-validation",relativeTo:root).standardizedFileURL
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
typealias V=SIMD3<Float>
var checks=0,failures:[String]=[],observations=[[String:Any]]()
func check(_ condition:Bool,_ message:String) { checks+=1;if !condition {failures.append(message);fputs("FAIL: \(message)\n",stderr)} }
let width=192,height=128
func quad(_ s:inout SceneData,_ a:V,_ b:V,_ c:V,_ d:V,_ m:UInt32) {
    for points in [[a,b,c],[a,c,d]] {let n=simd_normalize(simd_cross(points[1]-points[0],points[2]-points[0]));s.vertices += points.map{SceneVertex($0,n)};s.materialIndices.append(m)}
}
func luminance(_ image:Data,_ x:Int,_ y:Int)->Float {
    let b=[UInt8](image);var result:Float=0
    for yy in y-2...y+2 {for xx in x-2...x+2 {let i=(yy*width+xx)*4;result+=0.2126*Float(b[i+2])+0.7152*Float(b[i+1])+0.0722*Float(b[i])}}
    return result/25
}
func image(_ renderer:MetalRenderer,_ camera:CameraPose,_ options:RenderOptions)throws->Data {
    renderer.frameSeed=0
    return try renderer.renderOffscreen(pose:camera,options:options,width:width,height:height,samples:8)
}
func save(_ data:Data,_ label:String)throws {try writePNG(data,width:width,height:height,to:output.appendingPathComponent(label+".png"))}
guard let device=MTLCreateSystemDefaultDevice() else {fatalError("Metal required")}
let camera=CameraPose(position:V(0,2,10),target:V(0,2,0),fov:60)
var panels=SceneData();panels.name="Sunset window, fixture and vehicle lamp panels"
panels.materials=[SceneMaterial(V(0.02,0.025,0.03),roughness:0.1,emission:3,pattern:14),
                  SceneMaterial(V(0.8,0.4,0.1),roughness:1,emission:10,pattern:8),
                  SceneMaterial(V(0.7,0.85,0.95),roughness:1,emission:10,pattern:16)]
for i in 0..<3 {let x=Float(i-1)*4;quad(&panels,V(x-1.7,0,0),V(x+1.7,0,0),V(x+1.7,4,0),V(x-1.7,4,0),UInt32(i))}
let panelRenderer=try MetalRenderer(scene:panels,device:device)
check(MemoryLayout<FrameUniforms>.stride==144,"Frame ABI unchanged")
let modes:[(String,Bool,Bool)]=[("path",true,false),("direct",true,true),("raster",false,false)]
for (mode,ray,direct) in modes {
    var on=RenderOptions(exposure:0.4,bounces:1,lighting:3,denoising:false,rayTracing:ray,directRayTracing:direct)
    var off=on;off.sunsetBuildingLights=false
    let u=panelRenderer.uniforms(pose:camera,options:on),v=panelRenderer.uniforms(pose:camera,options:off)
    check(u.sunDirection==v.sunDirection && u.sunColor==v.sunColor && u.settings==v.settings,"\(mode): light preference changed sunlight")
    check(u.animation.z==1 && v.animation.z==2,"\(mode): renderer did not encode separate sunset light state")
    let lit=try image(panelRenderer,camera,on),unlit=try image(panelRenderer,camera,off)
    // Projected panel centers for the fixed 60-degree, 192x128 camera.
    let windowOn=luminance(lit,52,64),windowOff=luminance(unlit,52,64)
    let fixtureOn=luminance(lit,96,64),fixtureOff=luminance(unlit,96,64)
    check(windowOn>windowOff+15,"\(mode): modeled window did not switch off")
    check(fixtureOn>fixtureOff+15,"\(mode): architectural fixture did not switch off")
    check(abs(luminance(lit,140,64)-luminance(unlit,140,64))<0.01,"\(mode): vehicle lens changed with fixed lights")
    // Rays at the top center miss all geometry: sun/sky must match byte for byte.
    check(lit.subdata(in:((8*width+90)*4)..<((8*width+102)*4))==unlit.subdata(in:((8*width+90)*4)..<((8*width+102)*4)),"\(mode): sunset sky changed")
    try save(lit,"\(mode)-panels-on");try save(unlit,"\(mode)-panels-off")
    for lighting in [0,1,2] {
        on.lighting=lighting;off.lighting=lighting
        check(try image(panelRenderer,camera,on)==image(panelRenderer,camera,off),"\(mode): sunset setting changed lighting preset \(lighting)")
    }
    observations.append(["mode":mode,"windowOn":windowOn,"windowOff":windowOff,"fixtureOn":fixtureOn,"fixtureOff":fixtureOff])
}

// Local-light negative control detects accidentally re-enabling the indexed
// static light list after its uniform count has been set to zero.
var groundScene=SceneData();groundScene.materials=[SceneMaterial(V(repeating:0.16),roughness:1)]
quad(&groundScene,V(-14,0,-14),V(-14,0,14),V(14,0,14),V(14,0,-14),0)
var litFloor=groundScene
litFloor.lights=[SceneLight(positionRadius:SIMD4(0,4,0,0.2),directionCone:SIMD4(0,-1,0,-1),colorPower:SIMD4(0.2,1,0.3,250),parameters:SIMD4(30,1,1,0))]
let floorRenderer=try MetalRenderer(scene:litFloor,device:device),emptyFloorRenderer=try MetalRenderer(scene:groundScene,device:device)
let overhead=CameraPose(position:V(0,14,0),target:.zero,fov:60)
for (mode,ray,direct) in modes {for indexed in [true,false] {
    var on=RenderOptions(bounces:1,lighting:3,denoising:false,indexedLighting:indexed,rayTracing:ray,directRayTracing:direct)
    var off=on;off.sunsetBuildingLights=false
    let lit=try image(floorRenderer,overhead,on),unlit=try image(floorRenderer,overhead,off),absent=try image(emptyFloorRenderer,overhead,off)
    check(unlit==absent,"\(mode), indexed=\(indexed): disabled static light still contributes")
    check(luminance(lit,96,64)>luminance(unlit,96,64)+20,"\(mode), indexed=\(indexed): local-light positive control is not illuminated")
    on.lighting=2;off.lighting=2
    check(try image(floorRenderer,overhead,on)==image(floorRenderer,overhead,off),"\(mode), indexed=\(indexed): fixed night light was disabled")
}}

// Off-camera architecture is only visible by reflection. Check the shared
// emission policy in both ray algorithms, not just primary material shading.
var mirror=SceneData();mirror.materials=[SceneMaterial(V(repeating:0.95),roughness:0.02,metallic:1),SceneMaterial(V(0.8,0.1,0.01),roughness:1,emission:8)]
quad(&mirror,V(-5,-2,0),V(5,-2,0),V(5,6,0),V(-5,6,0),0)
quad(&mirror,V(-4,0,14),V(-4,4,14),V(4,4,14),V(4,0,14),1)
let mirrorRenderer=try MetalRenderer(scene:mirror,device:device)
for (mode,ray,direct) in modes {
    let on=RenderOptions(exposure:0.4,bounces:2,lighting:3,denoising:false,rayTracing:ray,directRayTracing:direct)
    var off=on;off.sunsetBuildingLights=false
    let lit=try image(mirrorRenderer,camera,on),unlit=try image(mirrorRenderer,camera,off)
    if ray {check(luminance(lit,96,64)>luminance(unlit,96,64)+10,"\(mode): offscreen reflected architectural emission did not switch off")}
    else {check(lit==unlit,"Raster environment-only mirror unexpectedly changed its sunset sky")}
    try save(lit,"\(mode)-mirror-on");try save(unlit,"\(mode)-mirror-off")
}

// Dynamic traffic light buffers remain enabled when fixed architectural lights
// are off. Use a mapped lane with one actual TLAS vehicle and transformed lamps.
var road=SceneData();road.materials=[SceneMaterial(V(repeating:0.25),roughness:1)]
quad(&road,V(-15,0,-110),V(-15,0,110),V(15,0,110),V(15,0,-110),0)
var trafficScene=road
trafficScene.trafficLanes=[SceneTrafficLane(id:119,points:[V(0,0.12,-100),V(0,0.12,100)],speedMetresPerSecond:12,spawnFadeMetres:8)]
let fleet=TrafficFleet(lanes:trafficScene.trafficLanes)
check(fleet.vehicles.count==1,"Traffic fixture has exactly one vehicle")
let trafficRenderer=try MetalRenderer(scene:trafficScene,device:device),roadRenderer=try MetalRenderer(scene:road,device:device)
trafficRenderer.setSceneTime((100-fleet.vehicles[0].phase)/12)
let trafficCamera=CameraPose(position:V(0,28,8),target:V(0,0,8),fov:60)
for (mode,ray,direct) in modes {
    let on=RenderOptions(bounces:1,lighting:3,denoising:false,rayTracing:ray,directRayTracing:direct)
    var off=on;off.sunsetBuildingLights=false
    let lit=try image(trafficRenderer,trafficCamera,on),unlit=try image(trafficRenderer,trafficCamera,off)
    check(lit==unlit,"\(mode): sunset fixed-light switch changed dynamic traffic")
    if ray {
        let empty=try image(roadRenderer,trafficCamera,off)
        // Ahead of the vehicle: z=18 maps near row103 for this north-up lens.
        check(luminance(unlit,96,103)>luminance(empty,96,103)+2,"\(mode): preserved headlights did not illuminate road")
    }
}

// Production shared-surface probes preserve projected content/boat cabins and
// remove procedural room emission, including Willis' patterned curtain wall.
let source=try String(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal"),encoding:.utf8)
let extra="""
kernel void sunsetSurfaceCheck(device float4 *out [[buffer(0)]],uint id [[thread_position_in_grid]]) {
    uint patterns[8]={7,13,14,15,16,17,12,8};
    SceneMaterial m;m.albedo=float4(0.2f,0.3f,0.4f,0.3f);m.properties=float4(0,1,patterns[id],0);
    float3 p=float3(11.1f,23.3f,42.7f),n=float3(0,0,1);
    Surface on=surfaceAt(m,p,n,0.01f,true,31,true),off=surfaceAt(m,p,n,0.01f,true,31,false);
    out[id]=float4(on.emission,off.emission,length(on.color-off.color),float(patterns[id]));
}
"""
let compile=MTLCompileOptions();compile.languageVersion = .version3_1
let library=try device.makeLibrary(source:source+extra,options:compile),pipeline=try device.makeComputePipelineState(function:library.makeFunction(name:"sunsetSurfaceCheck")!)
let queue=device.makeCommandQueue()!,command=queue.makeCommandBuffer()!,encoder=command.makeComputeCommandEncoder()!,buffer=device.makeBuffer(length:8*16,options:.storageModeShared)!
encoder.setComputePipelineState(pipeline);encoder.setBuffer(buffer,offset:0,index:0);encoder.dispatchThreads(MTLSize(width:8,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:1,depth:1));encoder.endEncoding();command.commit();command.waitUntilCompleted();if let error=command.error {throw error}
let surfaces=Array(UnsafeBufferPointer(start:buffer.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:8))
for value in surfaces {let pattern=Int(value.w);if [16,17,12].contains(pattern) {check(value.x==value.y && value.z==0,"Pattern \(pattern): vehicle/cabin/show material changed")}
else {check(value.y==0,"Pattern \(pattern): architectural emission remains enabled")}}
let hashes=try Dictionary(uniqueKeysWithValues:["Renderer","DirectRay","Raster"].map {name in (name,SHA256.hash(data:try Data(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/\(name).metal"))).map{String(format:"%02x",$0)}.joined())})
let report:[String:Any]=["passed":failures.isEmpty,"checks":checks,"failures":failures,"observations":observations,"device":device.name,"resolution":[width,height],"shaderSHA256":hashes,"scope":"Production Path, Direct and Raster: emissive windows/fixtures, offscreen reflections, fixed indexed/linear lights, unchanged sky and day/night, preserved vehicle/cabin/show material emission. Small synthetic scenes; no city FPS or native UI claim."]
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:output.appendingPathComponent("sunset-lights.json"));FileHandle.standardOutput.write(data);print("");exit(failures.isEmpty ? 0:1)
