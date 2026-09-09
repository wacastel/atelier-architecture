import Foundation
import Metal
import MetalFX
import CryptoKit
import simd

// Uses the real renderer and shader resources. No application window, audio,
// alternate test integrator, or scene-specific render-path substitution.
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
let output=URL(fileURLWithPath:ProcessInfo.processInfo.environment["ATELIER_DIRECT_RAY_OUTPUT"] ?? "output/direct-ray-validation",relativeTo:root).standardizedFileURL
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
typealias V=SIMD3<Float>
var checks=0,failures:[String]=[],observations=[[String:Any]]()
func check(_ condition:Bool,_ message:String) {checks+=1;if !condition {failures.append(message);fputs("FAIL: \(message)\n",stderr)}}
func hash(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
let inputPaths=["SceneTypes.swift","CollisionWorld.swift","LightGrid.swift","Traffic.swift","TrafficMetal.swift","GeometryPartition.swift","RasterRenderer.swift","MetalRenderer.swift","Resources/Renderer.metal","Resources/Raster.metal","Resources/Denoise.metal","Resources/DirectRay.metal"]
func inventory()throws->[String:String] {try Dictionary(uniqueKeysWithValues:inputPaths.map{($0,hash(try Data(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/\($0)"))))})}
let before=try inventory()
let width=192,height=128
func triangle(_ scene:inout SceneData,_ a:V,_ b:V,_ c:V,_ m:UInt32) {
    let normal=simd_normalize(simd_cross(b-a,c-a))
    scene.vertices += [SceneVertex(a,normal),SceneVertex(b,normal),SceneVertex(c,normal)];scene.materialIndices.append(m)
}
func quad(_ scene:inout SceneData,_ a:V,_ b:V,_ c:V,_ d:V,_ m:UInt32) {triangle(&scene,a,b,c,m);triangle(&scene,a,c,d,m)}
func pixel(_ point:V,_ camera:CameraPose)->SIMD2<Int> {
    let forward=simd_normalize(camera.target-camera.position)
    var right=simd_cross(forward,V(0,1,0));if simd_length_squared(right)<0.001 {right=V(1,0,0)}
    right=simd_normalize(right);let up=simd_cross(right,forward),delta=point-camera.position
    let depth=simd_dot(delta,forward),half=tan(camera.fov * .pi/360)
    return SIMD2(Int((simd_dot(delta,right)/(depth*half*Float(width)/Float(height))+1)*Float(width)/2),
                 Int((1-simd_dot(delta,up)/(depth*half))*Float(height)/2))
}
func rgb(_ image:Data,_ point:SIMD2<Int>,radius:Int=1)->V {
    let bytes=[UInt8](image);var value=V.zero,count:Float=0
    for y in max(0,point.y-radius)...min(height-1,point.y+radius) {
        for x in max(0,point.x-radius)...min(width-1,point.x+radius) {
            let i=(y*width+x)*4;value += V(Float(bytes[i+2]),Float(bytes[i+1]),Float(bytes[i]));count+=1
        }
    }
    return value/count
}
func luminance(_ value:V)->Float {simd_dot(value,V(0.2126,0.7152,0.0722))}
func save(_ data:Data,_ name:String)throws {try writePNG(data,width:width,height:height,to:output.appendingPathComponent(name+".png"))}
func primaryDepth(_ renderer:MetalRenderer,_ point:SIMD2<Int>)throws->Float {
    guard let texture=renderer.accumulation,let buffer=renderer.device.makeBuffer(length:256,options:.storageModeShared),
          let command=renderer.queue.makeCommandBuffer(),let blit=command.makeBlitCommandEncoder() else {throw EngineError.message("Depth readback unavailable")}
    blit.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:point.x,y:point.y,z:0),sourceSize:MTLSize(width:1,height:1,depth:1),
              to:buffer,destinationOffset:0,destinationBytesPerRow:256,destinationBytesPerImage:256)
    blit.endEncoding();command.commit();command.waitUntilCompleted()
    if let error=command.error {throw error}
    return buffer.contents().load(fromByteOffset:12,as:Float.self)
}

var visibility=SceneData();visibility.name="Direct-ray depth and thin-sheet fixture"
visibility.materials=[SceneMaterial(V(0.01,0.02,0.85),roughness:0.9,emission:1),
                      SceneMaterial(V(0.85,0.01,0.01),roughness:0.9,emission:1),
                      SceneMaterial(V(0.96,0.98,1),roughness:0.04,transmission:0.93)]
quad(&visibility,V(-5,0,0),V(5,0,0),V(5,4,0),V(-5,4,0),0)
quad(&visibility,V(-1,1,2),V(1,1,2),V(1,3,2),V(-1,3,2),1)
quad(&visibility,V(1.7,0.6,3),V(4.5,0.6,3),V(4.5,3.4,3),V(1.7,3.4,3),2)
let camera=CameraPose(position:V(0,2,10),target:V(0,2,0),fov:60)
let depthWorld=CollisionWorld(scene:visibility)
check(abs((depthWorld.distance(origin:camera.position,direction:V(0,0,-1),maximum:20) ?? -1)-8)<0.001,"Fixture center ray meets the nearer red panel")
let glassPoint=V(3.0,2,3),glassDirection=simd_normalize(glassPoint-camera.position)
check(abs((depthWorld.distance(origin:camera.position,direction:glassDirection,maximum:20) ?? -1)-simd_distance(glassPoint,camera.position))<0.001,"Glass probe really crosses the sheet before the blue panel")

func reflectionScene(_ color:V)->SceneData {
    var scene=SceneData();scene.name="Offscreen geometry reflection fixture"
    scene.materials=[SceneMaterial(V(repeating:0.96),roughness:0.02,metallic:1),SceneMaterial(color,roughness:0.9,emission:1)]
    quad(&scene,V(-5,-2,0),V(5,-2,0),V(5,6,0),V(-5,6,0),0)
    // This panel is entirely behind the camera; a screen-space reflection or
    // environment-only approximation cannot know whether it is red or blue.
    quad(&scene,V(-4,0,14),V(-4,4,14),V(4,4,14),V(4,0,14),1)
    return scene
}
let redMirrorScene=reflectionScene(V(0.85,0.01,0.01)),blueMirrorScene=reflectionScene(V(0.01,0.02,0.85))
check(simd_dot(V(0,2,14)-camera.position,simd_normalize(camera.target-camera.position))<0,"Reflected test object lies behind the camera frustum")
let mirrorWorld=CollisionWorld(scene:redMirrorScene)
check(abs((mirrorWorld.distance(origin:V(0,2,0.001),direction:V(0,0,1),maximum:30) ?? -1)-13.999)<0.002,"Analytic reflected ray meets the offscreen object")

var shadowScene=SceneData();shadowScene.name="Directional hard-shadow fixture"
shadowScene.materials=[SceneMaterial(V(0.38,0.40,0.42),roughness:1),SceneMaterial(V(0.15,0.15,0.15),roughness:1)]
quad(&shadowScene,V(-12,0,-12),V(-12,0,12),V(12,0,12),V(12,0,-12),0)
for z:Float in [-0.6,0.6] {quad(&shadowScene,V(-0.6,0,z),V(0.6,0,z),V(0.6,3,z),V(-0.6,3,z),1)}
for x:Float in [-0.6,0.6] {quad(&shadowScene,V(x,0,-0.6),V(x,0,0.6),V(x,3,0.6),V(x,3,-0.6),1)}
quad(&shadowScene,V(-0.6,3,-0.6),V(-0.6,3,0.6),V(0.6,3,0.6),V(0.6,3,-0.6),1)
shadowScene.lights=[SceneLight(positionRadius:SIMD4(-5.5,4.8,6.8,0.15),directionCone:SIMD4(0,-1,0,-1),
    colorPower:SIMD4(1,0.8,0.5,220),parameters:SIMD4(30,1,0,0))]
var unblockedScene=shadowScene
unblockedScene.vertices=Array(shadowScene.vertices.prefix(6));unblockedScene.materialIndices=Array(shadowScene.materialIndices.prefix(2))
let overhead=CameraPose(position:V(0,16,0),target:.zero,fov:60)
// Independent ray/triangle oracle establishes the two fixed floor probes.
let shadowPoint=V(1.833333,0.001,-2.266667),litPoint = -shadowPoint+V(0,0.002,0)
let shadeWorld=CollisionWorld(scene:shadowScene),lowSun=simd_normalize(V(-0.55,0.48,0.68)),highSun=simd_normalize(V(-0.35,0.85,0.4))
check(shadeWorld.distance(origin:shadowPoint,direction:lowSun,maximum:20) != nil,"Low-angle sun probe is behind actual blocker")
check(shadeWorld.distance(origin:litPoint,direction:lowSun,maximum:20)==nil,"Opposite floor probe sees low-angle sun")
check(shadeWorld.distance(origin:shadowPoint,direction:highSun,maximum:20)==nil,"Higher sun moves the shadow away from the first probe")
let lamp=shadowScene.lights[0].positionRadius.xyz,lightRay=simd_normalize(lamp-shadowPoint)
check(shadeWorld.distance(origin:shadowPoint,direction:lightRay,maximum:simd_distance(lamp,shadowPoint)) != nil,"Night lamp is occluded by the same actual pillar")
check(CollisionWorld(scene:unblockedScene).distance(origin:shadowPoint,direction:lightRay,maximum:simd_distance(lamp,shadowPoint))==nil,"Removing the pillar really opens the lamp visibility ray")
for point in [shadowPoint,litPoint] {
    let coordinate=pixel(point,overhead)
    check(coordinate.x>2 && coordinate.x<width-3 && coordinate.y>2 && coordinate.y<height-3,"Shadow oracle projects safely inside capture")
}
check(!RenderOptions().directRayTracing && RenderOptions().rayTracing,"Existing default render options still select path tracing")
if CommandLine.arguments.contains("--cpu") {
    print(String(data:try JSONSerialization.data(withJSONObject:["passed":failures.isEmpty,"checks":checks,"failures":failures,"scope":"Independent fixture visibility/reflection/shadow geometry and default selector; no Metal device or GPU work"],options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
    exit(failures.isEmpty ? 0:1)
}

guard let device=MTLCreateSystemDefaultDevice(),device.supportsRaytracing else {throw EngineError.message("Actual ray-tracing device required; test is not skipped.")}
let activity=ProcessInfo.processInfo.beginActivity(options:.userInitiated,reason:"Validate deterministic direct ray tracing")
defer {ProcessInfo.processInfo.endActivity(activity)}
var metalFXSupported=false
if #available(macOS 26.0,*) {metalFXSupported=MTLFXTemporalDenoisedScalerDescriptor.supportsDevice(device)}
let renderer=try MetalRenderer(scene:visibility,device:device)
var direct=RenderOptions(lighting:2);direct.directRayTracing=true
let pathStart=renderer.rayTracingDispatchCount,guidesStart=renderer.surfaceGuideDispatchCount,directStart=renderer.directRayDispatchCount
renderer.frameSeed=0
let first=try renderer.renderPreviewOffscreen(pose:camera,options:direct,width:width,height:height,samples:1,resetHistory:true)
try save(first,"visibility-direct")
let center=rgb(first,pixel(V(0,2,2),camera)),through=rgb(first,pixel(glassPoint,camera)),blue=rgb(first,pixel(V(-3,2,0),camera))
observations.append(["case":"visibility","centerRGB":[center.x,center.y,center.z],"glassRGB":[through.x,through.y,through.z]])
check(center.x>center.z+40,"Closest red object must occlude the blue panel")
check(through.z>through.x+40 && blue.z>blue.x+40,"Thin glass must reveal the actual blue object behind it")
check(first.count==width*height*4,"Complete direct-ray BGRA readback")
check(renderer.rayTracingDispatchCount==pathStart && renderer.surfaceGuideDispatchCount==guidesStart,"Direct mode must bypass stochastic path dispatches and denoiser surface guides")
check(renderer.directRayDispatchCount==directStart+1 && renderer.sampleCount==1,"Direct preview submits exactly one deterministic dispatch")
renderer.focusHighlight=FocusHighlightData(volumes:[FocusHighlightVolume(minimum:V(-5,0,-0.1),maximum:V(5,4,0.1))])
let highlighted=try renderer.renderOffscreen(pose:camera,options:direct,width:width,height:height,samples:1)
check(rgb(highlighted,pixel(V(-3,2,0),camera)) != blue,"Direct presentation must highlight the selected visible blue surface")
check(rgb(highlighted,pixel(V(0,2,2),camera))==center,"Selection depth must keep the nearer red occluder untinted")
check(rgb(highlighted,SIMD2(width-3,2))==rgb(first,SIMD2(width-3,2)),"Selection must not tint sky")
renderer.focusHighlight=FocusHighlightData(volumes:[])
check(try renderer.renderOffscreen(pose:camera,options:direct,width:width,height:height,samples:1)==first,"Clearing direct focus removes all tint without history contamination")
try save(highlighted,"visibility-focused-direct")
for (seed,samples) in [(UInt32(7),2),(UInt32.max-1,2048)] {
    renderer.frameSeed=seed
    let dispatches=renderer.directRayDispatchCount
    let same=try renderer.renderOffscreen(pose:camera,options:direct,width:width,height:height,samples:samples)
    check(same==first,"Direct output must be byte-identical across seed \(seed) and \(samples) requested SPP")
    check(renderer.directRayDispatchCount==dispatches+1 && renderer.frameSeed==seed,"Requested SPP must not multiply direct work or consume random frame seeds")
}
var alternate=direct;alternate.denoising=false;alternate.lowDiscrepancySampling=false;alternate.regularization=false
let unchanged=try renderer.renderPreviewComparisonOffscreen(pose:camera,options:alternate,width:width,height:height,samples:32,resetHistory:true)
check(unchanged.raw==first && unchanged.reconstructed==first,"Direct capture must be independent of Monte Carlo and temporal reconstruction settings")
let changedPose=CameraPose(position:camera.position+V(0.25,0,0),target:camera.target,fov:camera.fov)
let moved=try renderer.renderPreviewOffscreen(pose:changedPose,options:direct,width:width,height:height,samples:1)
check(moved != first,"Camera motion must update the direct image immediately")
let returned=try renderer.renderPreviewOffscreen(pose:camera,options:direct,width:width,height:height,samples:1)
check(returned==first,"Returning camera must restore exact image without temporal lag")
let resized=try renderer.renderOffscreen(pose:camera,options:direct,width:113,height:79,samples:1)
check(resized.count==113*79*4,"Direct readback follows resized viewport")
check(try renderer.renderOffscreen(pose:camera,options:direct,width:width,height:height,samples:1)==first,"Resize round trip preserves direct view")

// A direct→path→raster→direct sequence verifies dispatch ownership with the
// same resident scene, not only that the new selector changes pixels.
var path=direct;path.directRayTracing=false;path.denoising=false
let oldTraces=renderer.rayTracingDispatchCount,oldDirect=renderer.directRayDispatchCount
_ = try renderer.renderOffscreen(pose:camera,options:path,width:width,height:height,samples:2)
check(renderer.rayTracingDispatchCount==oldTraces+2 && renderer.sampleCount==2 && renderer.directRayDispatchCount==oldDirect,"Legacy selection restores actual multi-sample path tracing")
var raster=direct;raster.rayTracing=false
let traces=renderer.rayTracingDispatchCount,rasterFrames=renderer.rasterFrameCount
_ = try renderer.renderOffscreen(pose:camera,options:raster,width:width,height:height,samples:17)
check(renderer.rasterFrameCount==rasterFrames+1 && renderer.rayTracingDispatchCount==traces && renderer.directRayDispatchCount==oldDirect,"Raster selector takes precedence and bypasses both ray integrators")
check(try renderer.renderOffscreen(pose:camera,options:direct,width:width,height:height,samples:1)==first,"Returning from both other modes restores deterministic direct view")

let redRenderer=try MetalRenderer(scene:redMirrorScene,device:device),blueRenderer=try MetalRenderer(scene:blueMirrorScene,device:device)
let redMirror=try redRenderer.renderOffscreen(pose:camera,options:direct,width:width,height:height,samples:1)
let blueMirror=try blueRenderer.renderOffscreen(pose:camera,options:direct,width:width,height:height,samples:1)
try save(redMirror,"reflection-red-direct");try save(blueMirror,"reflection-blue-direct")
let redPixel=rgb(redMirror,pixel(V(0,2,0),camera)),bluePixel=rgb(blueMirror,pixel(V(0,2,0),camera))
observations.append(["case":"offscreen-reflection","redRGB":[redPixel.x,redPixel.y,redPixel.z],"blueRGB":[bluePixel.x,bluePixel.y,bluePixel.z]])
check(redPixel.x>redPixel.z+40 && bluePixel.z>bluePixel.x+40,"Mirror must trace and distinguish real offscreen red and blue geometry")
let rasterRed=try redRenderer.renderOffscreen(pose:camera,options:raster,width:width,height:height,samples:1)
let rasterBlue=try blueRenderer.renderOffscreen(pose:camera,options:raster,width:width,height:height,samples:1)
check(rasterRed==rasterBlue,"Environment-only raster negative control cannot see the changed object behind the camera")
check(redMirror != rasterRed,"Direct reflection differs from the environment-only negative control")

let shadowRenderer=try MetalRenderer(scene:shadowScene,device:device)
var sun=direct;sun.lighting=0
let low=try shadowRenderer.renderOffscreen(pose:overhead,options:sun,width:width,height:height,samples:1)
sun.lighting=1
let high=try shadowRenderer.renderOffscreen(pose:overhead,options:sun,width:width,height:height,samples:1)
try save(low,"shadow-low-sun-direct");try save(high,"shadow-high-sun-direct")
let lowShadow=luminance(rgb(low,pixel(shadowPoint,overhead))),lowLit=luminance(rgb(low,pixel(litPoint,overhead)))
let highHere=luminance(rgb(high,pixel(shadowPoint,overhead))),highLit=luminance(rgb(high,pixel(litPoint,overhead)))
observations.append(["case":"sun-shadow","lowShadow":lowShadow,"lowLit":lowLit,"highHere":highHere,"highLit":highLit])
check(lowShadow<lowLit*0.85,"Actual low-sun occluder must darken the analytic shadow probe")
check(highHere>highLit*0.92,"Changed sun direction moves the hard shadow off the analytic probe")
sun.lighting=2
let blockedLamp=try shadowRenderer.renderOffscreen(pose:overhead,options:sun,width:width,height:height,samples:1)
let openRenderer=try MetalRenderer(scene:unblockedScene,device:device)
let openLamp=try openRenderer.renderOffscreen(pose:overhead,options:sun,width:width,height:height,samples:1)
let blockedLuminance=luminance(rgb(blockedLamp,pixel(shadowPoint,overhead))),openLuminance=luminance(rgb(openLamp,pixel(shadowPoint,overhead)))
check(blockedLuminance<openLuminance*0.85,"Night local light must obey actual blocker visibility, not only distance attenuation")
observations.append(["case":"local-light-shadow","blocked":blockedLuminance,"open":openLuminance])
try save(blockedLamp,"shadow-local-blocked-direct");try save(openLamp,"shadow-local-open-direct")

// Actual two-instance TLAS, transformed bus geometry and dynamically rebuilt
// headlight index. A separate empty-road scene is the light negative control.
var road=SceneData();road.name="Direct traffic and headlights fixture"
road.materials=[SceneMaterial(V(0.34,0.35,0.36),roughness:1)]
quad(&road,V(-15,0,-110),V(-15,0,110),V(15,0,110),V(15,0,-110),0)
var trafficScene=road
trafficScene.trafficLanes=[SceneTrafficLane(id:119,points:[V(0,0.12,-100),V(0,0.12,100)],speedMetresPerSecond:12,spawnFadeMetres:8)]
let fleet=TrafficFleet(lanes:trafficScene.trafficLanes)
check(fleet.vehicles.count==1,"Traffic fixture has one bounded, explicit vehicle")
let vehicle=fleet.vehicles[0],nearTime=(100-vehicle.phase)/12
let trafficCamera=CameraPose(position:V(0,28,8),target:V(0,0,8),fov:60)
let trafficRenderer=try MetalRenderer(scene:trafficScene,device:device),emptyRoadRenderer=try MetalRenderer(scene:road,device:device)
let roadOnly=try emptyRoadRenderer.renderOffscreen(pose:trafficCamera,options:direct,width:width,height:height,samples:1)
trafficRenderer.setSceneTime(nearTime)
let nearTraffic=try trafficRenderer.renderOffscreen(pose:trafficCamera,options:direct,width:width,height:height,samples:1)
let vehiclePixel=pixel(V(0,2,0),trafficCamera),nearDepth=try primaryDepth(trafficRenderer,vehiclePixel)
let headlightPixel=pixel(V(0,0.001,18),trafficCamera),emptyLuminance=luminance(rgb(roadOnly,headlightPixel)),headlightLuminance=luminance(rgb(nearTraffic,headlightPixel))
check(headlightLuminance>emptyLuminance+3,"Dynamic headlights must illuminate road beyond the visible vehicle")
let updateCount=trafficRenderer.trafficUpdateCount
trafficRenderer.frameSeed=231
check(try trafficRenderer.renderPreviewOffscreen(pose:trafficCamera,options:direct,width:width,height:height,samples:32)==nearTraffic,"Stationary traffic and headlight frame is deterministic across seeds and samples")
check(trafficRenderer.trafficUpdateCount==updateCount,"A repeated traffic clock must reuse its TLAS and light transforms")
trafficRenderer.setSceneTime(nearTime-4)
let farTraffic=try trafficRenderer.renderOffscreen(pose:trafficCamera,options:direct,width:width,height:height,samples:1)
let farDepth=try primaryDepth(trafficRenderer,vehiclePixel)
check(nearDepth+1.5<farDepth,"Direct primary rays must hit the moved TLAS vehicle, then its uncovered road")
check(farTraffic != nearTraffic && trafficRenderer.trafficUpdateCount==updateCount+1,"Changed clock updates geometry and dynamic-light data exactly once")
trafficRenderer.setSceneTime(nearTime)
check(try trafficRenderer.renderOffscreen(pose:trafficCamera,options:direct,width:width,height:height,samples:1)==nearTraffic,"Scrubbing traffic back restores exact direct geometry and lighting")
check(trafficRenderer.rayTracingDispatchCount==0 && trafficRenderer.surfaceGuideDispatchCount==0,"Direct traffic does not invoke stochastic path or temporal-guide kernels")
observations.append(["case":"traffic-TLAS-headlights","emptyRoadLuminance":emptyLuminance,"headlightLuminance":headlightLuminance,"nearDepth":nearDepth,"farDepth":farDepth,"vehicles":fleet.vehicles.count,"trafficUpdates":trafficRenderer.trafficUpdateCount])
try save(nearTraffic,"traffic-near-direct");try save(farTraffic,"traffic-far-direct");try save(roadOnly,"traffic-empty-negative-control")

let after=try inventory();check(before==after,"Production rendering inputs remain unchanged throughout fixture")
let report:[String:Any]=["passed":failures.isEmpty,"checks":checks,"failures":failures,"observations":observations,
    "device":device.name,"width":width,"height":height,"metalFXDenoisedScalerSupported":metalFXSupported,
    "fixtureSHA256":hash(try Data(contentsOf:URL(fileURLWithPath:#filePath))),
    "scriptSHA256":hash(try Data(contentsOf:root.appendingPathComponent("scripts/validate-direct-ray.sh"))),
    "operatingSystem":ProcessInfo.processInfo.operatingSystemVersionString,
    "sourceSHA256":before,"inputsStable":before==after,"visibilityImageSHA256":hash(first),
    "scope":"Actual production-kernel direct/path/raster selection, nearest occlusion and focus depth, offscreen specular reflection with raster negative control, directional and local hard shadows, thin-sheet transmission, seed/SPP/settings independence, motion return/resize, and one moving TLAS vehicle with dynamic headlights and empty-road control. Small fixtures; does not establish full-city speed, every traffic layout, native FPS, soft shadows or absence of geometric aliasing." ]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("validation.json"))
print("\(failures.isEmpty ? "PASS":"FAIL"): \(checks) checks, \(failures.count) failures; report \(output.path)/validation.json")
exit(failures.isEmpty ? 0:1)
