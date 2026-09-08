import Foundation
import Metal
import simd

let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
func require(_ value:Bool,_ message:String) { if !value { fputs("FAIL: \(message)\n",stderr);exit(1) } }
func finite(_ m:simd_float4x4)->Bool { [m.columns.0,m.columns.1,m.columns.2,m.columns.3].allSatisfy{ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w.isFinite } }
func lane(_ points:[SIMD3<Float>],id:Int64=42)->SceneTrafficLane { SceneTrafficLane(id:id,points:points,speedMetresPerSecond:16,spawnFadeMetres:24) }
let route=lane([SIMD3(0,0,-1000),SIMD3(0,0,0),SIMD3(150,6,200),SIMD3(150,0,1000)])
let path=TrafficPath(route)!
require(abs(path.point(at:500).z + 500)<0.0001,"Arc length interpolation moved off the mapped lane")
require(simd_distance(path.point(at:1000),SIMD3(0,0,0))<0.0001,"Road node distance/grade mismatch")
let before=path.transform(distance:999.999,wheelbase:2.75).columns.2.xyz
let after=path.transform(distance:1000.001,wheelbase:2.75).columns.2.xyz
require(simd_dot(before,after)>0.999,"Vehicle orientation snaps at a map node")
let grade=path.transform(distance:1100,wheelbase:2.75)
require(grade.columns.2.y>0 && grade.columns.3.y>0,"Vehicle failed to follow bridge grade")
for malformed in [lane([]),lane([.zero,.zero]),lane([.zero,SIMD3(0,200,0)]),lane([.zero,SIMD3(Float.nan,0,100)]),lane([SIMD3(-Float.greatestFiniteMagnitude,0,0),SIMD3(Float.greatestFiniteMagnitude,0,0)])] {
    require(TrafficPath(malformed)==nil,"Invalid road accepted")
    require(TrafficFleet(lanes:[malformed]).vehicles.isEmpty,"Invalid road spawned traffic")
}
let fleet=TrafficFleet(lanes:[route,lane(route.points.reversed(),id:43)])
require(fleet.vehicles.contains{$0.bus} && fleet.vehicles.contains{!$0.bus},"Fleet lacks cars/buses")
require(fleet.vertices.count==fleet.owners.count && fleet.vertices.count==fleet.materialIndices.count*3,"Vehicle mesh ABI mismatch")
require(fleet.owners.allSatisfy{Int($0)<fleet.vehicles.count},"Vehicle ownership out of range")
require(fleet.materialIndices.allSatisfy{Int($0)<fleet.materials.count},"Vehicle material out of range")
for time in [-1e300,-500.1,0,0.016,1000,1e300] {
    let a=fleet.transforms(at:time),b=fleet.transforms(at:time)
    require(a==b && a.allSatisfy(finite),"Absolute-time traffic is nondeterministic/nonfinite")
    let lights=fleet.lights(transforms:a)
    require(lights.count==fleet.vehicles.count*3 && lights.allSatisfy{$0.positionRadius.x.isFinite && $0.colorPower.w.isFinite},"Moving light transforms invalid")
}
let first=fleet.vehicles[0],period=fleet.paths[first.path].length/fleet.paths[first.path].speed
let start=fleet.distance(for:first,time:17.5),loop=fleet.distance(for:first,time:17.5+period)
require(abs(start-loop)<1e-8,"Absolute-time periodic motion drifts")
for distance in [Double(0),0.001,path.length-0.001,path.length] {
    require(simd_length(path.transform(distance:distance,wheelbase:3).columns.0.xyz)<0.001,"A full-size car teleports at the streaming boundary")
}
print("PASS: arc length, bend continuity, bridge grade, bounded endpoint streaming, cars/buses, malformed lanes, huge/negative time and deterministic light/pose ABI")
struct MappedLanes:Decodable {
    struct Lane:Decodable {var id:Int64;var points:[[Float]];var speedMetresPerSecond:Float;var spawnFadeMetres:Float}
    var trafficLanes:[Lane]
}
let mapURL=root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json")
if FileManager.default.fileExists(atPath:mapURL.path) {
    let decoded=try JSONDecoder().decode(MappedLanes.self,from:Data(contentsOf:mapURL))
    require(decoded.trafficLanes.count==6,"Mapped corridor does not contain both three-lane directions")
    let lanes=decoded.trafficLanes.map{SceneTrafficLane(id:$0.id,points:$0.points.map{SIMD3($0[0],$0[1],$0[2])},speedMetresPerSecond:$0.speedMetresPerSecond,spawnFadeMetres:$0.spawnFadeMetres)}
    let mapped=TrafficFleet(lanes:lanes)
    require(mapped.paths.count==6 && mapped.vehicles.count==168,"Mapped traffic path was dropped or fleet count changed")
    var checks=0
    for time in stride(from:0.0,through:600,by:7.25) {
        let poses=mapped.transforms(at:time)
        for (vehicle,pose) in zip(mapped.vehicles,poses) {
            let path=mapped.paths[vehicle.path]
            let distance=mapped.distance(for:vehicle,time:time)
            require(finite(pose),"Mapped traffic pose is nonfinite")
            require(simd_distance(pose.columns.3.xyz,path.point(at:distance)+SIMD3(0,0.025,0))<0.001,"Vehicle moved off its exact mapped road grade")
            let laneVehicleCount=mapped.vehicles.filter{$0.path==vehicle.path}.count
            require(path.length/Double(laneVehicleCount)>Double(vehicle.halfLength*2+20),"Lane fleet has overlapping vehicle spacing")
            checks += 1
        }
    }
    print("PASS: \(checks) actual mapped road placements across six lanes, both directions and ten minutes; 168 vehicles retain lane grade and safe longitudinal spacing")
}
if CommandLine.arguments.contains("--cpu") { exit(0) }
guard let device=MTLCreateSystemDefaultDevice() else { fatalError("Metal required") }
var scene=SceneData();scene.name="Traffic validation"
scene.materials=[SceneMaterial(SIMD3(0.4,0.42,0.44),roughness:0.6)]
let n=SIMD3<Float>(0,1,0)
scene.vertices=[SceneVertex(SIMD3(-200,0,-1500),n),SceneVertex(SIMD3(-200,0,1500),n),SceneVertex(SIMD3(200,0,1500),n),SceneVertex(SIMD3(-200,0,-1500),n),SceneVertex(SIMD3(200,0,1500),n),SceneVertex(SIMD3(200,0,-1500),n)]
scene.materialIndices=[0,0]
scene.materials.append(SceneMaterial(SIMD3(0.85,0.86,0.87),roughness:0.022,metallic:1))
let mirrorNormal=SIMD3<Float>(1,0,0)
scene.vertices += [SceneVertex(SIMD3(-140,0,-20),mirrorNormal),SceneVertex(SIMD3(-140,0,20),mirrorNormal),SceneVertex(SIMD3(-140,10,20),mirrorNormal),SceneVertex(SIMD3(-140,0,-20),mirrorNormal),SceneVertex(SIMD3(-140,10,20),mirrorNormal),SceneVertex(SIMD3(-140,10,-20),mirrorNormal)]
scene.materialIndices += [1,1]
let road=lane([SIMD3(0,0,-1000),SIMD3(0,0,1000)])
scene.trafficLanes=[road]
let model=TrafficFleet(lanes:scene.trafficLanes)
let lead=model.vehicles[0]
let time=(1000-lead.phase)/16
let renderer=try MetalRenderer(scene:scene,device:device)
require(renderer.trafficVehicleCount==model.vehicles.count,"Production renderer did not opt into traffic")
var options=RenderOptions();options.denoising=false;options.bounces=2
let camera=CameraPose(position:SIMD3(9,5,12),target:SIMD3(0,1,0),fov:48)
renderer.setSceneTime(time)
renderer.frameSeed=0
let image=try renderer.renderOffscreen(pose:camera,options:options,width:96,height:64,samples:4)
let updates=renderer.trafficUpdateCount
require(updates==1,"Traffic transformed more than once within progressive batch")
let expected=model.transforms(at:time)
let gpuVertices=renderer.vertexBuffer.contents().bindMemory(to:SceneVertex.self,capacity:scene.vertices.count+model.vertices.count)
var maxError:Float=0
for index in stride(from:0,to:model.vertices.count,by:11) {
    let source=model.vertices[index],matrix=expected[Int(model.owners[index])]
    let cpu=matrix*source.position,gpu=gpuVertices[scene.vertices.count+index].position
    maxError=max(maxError,simd_length(cpu-gpu))
}
require(maxError<0.0005,"GPU dynamic transform differs from CPU mapped placement: \(maxError)")
let samples=renderer.sampleCount
renderer.setSceneTime(time)
require(renderer.sampleCount==samples,"Same-time pause reset progressive convergence")
renderer.frameSeed=0
let repeated=try renderer.renderOffscreen(pose:camera,options:options,width:96,height:64,samples:4)
require(image==repeated && renderer.trafficUpdateCount==updates,"Paused traffic changes image/BVH")
renderer.setSceneTime(time+0.05)
require(renderer.sampleCount==0,"Moving traffic did not reset stationary-camera accumulation")
renderer.frameSeed=0
let moved=try renderer.renderOffscreen(pose:camera,options:options,width:96,height:64,samples:4)
require(moved != image && renderer.trafficUpdateCount==updates+1,"Actual traffic refit did not change ray-traced image")
renderer.setSceneTime(time)
renderer.frameSeed=0
let rewound=try renderer.renderOffscreen(pose:camera,options:options,width:96,height:64,samples:4)
require(image==rewound,"Rewinding traffic failed exact same-time geometry/image")
// View only the road ahead: lamp emission on vehicle lenses is outside this
// image. The difference must come from actual ray-traced headlight illumination.
options.lighting=2;options.bounces=1
let roadCamera=CameraPose(position:SIMD3(0,6,16),target:SIMD3(0,0,15),fov:25)
renderer.frameSeed=0
let lit=try renderer.renderOffscreen(pose:roadCamera,options:options,width:64,height:48,samples:8)
var plain=scene;plain.trafficLanes=[]
let baseline=try MetalRenderer(scene:plain,device:device)
require(baseline.trafficVehicleCount==0,"Static path unexpectedly instanced")
baseline.frameSeed=0
let unlit=try baseline.renderOffscreen(pose:roadCamera,options:options,width:64,height:48,samples:8)
func brightness(_ image:Data)->Double { let bytes=[UInt8](image);var sum=0.0;for i in stride(from:0,to:bytes.count,by:4) {sum+=Double(bytes[i])+Double(bytes[i+1])+Double(bytes[i+2])};return sum/Double(bytes.count/4)/3 }
require(brightness(lit)>brightness(unlit)+5,"Headlights failed to illuminate real roadway")
// Continuous live frames use dynamic reactive guides; pausing then permits
// ordinary stationary material guides and sample accumulation again.
options.denoising=true
for step in 0..<5 { renderer.setSceneTime(time+Double(step)/24);_ = try renderer.renderPreviewOffscreen(pose:camera,options:options,width:96,height:64,samples:4) }
let endCount=renderer.trafficUpdateCount
renderer.setSceneTime(time+4.0/24)
_ = try renderer.renderPreviewOffscreen(pose:camera,options:options,width:96,height:64,samples:4)
require(renderer.trafficUpdateCount==endCount,"Paused reconstructed frame updated dynamic BVH")
print("PASS: actual hardware TLAS/traffic BLAS build+refit; world vertex max error \(maxError)m; deterministic rewind/pause and stationary-camera invalidation")
print("PASS: moving night headlights illuminate road outside visible car/lamp geometry (mean pixel \(brightness(unlit)) → \(brightness(lit)))")
// Exercise both indexed and linear night/interior traffic specializations.
var interiorScene=scene
interiorScene.lights=[SceneLight(positionRadius:SIMD4(3,5,12,0.3),directionCone:SIMD4(0,-1,0,-1),colorPower:SIMD4(1,0.8,0.6,20),parameters:SIMD4(30,0.5,1,0))]
let interiorRenderer=try MetalRenderer(scene:interiorScene,device:device)
interiorRenderer.setSceneTime(time)
for lighting in [0,2] {
    var indexed=RenderOptions();indexed.lighting=lighting;indexed.denoising=false
    interiorRenderer.frameSeed=0
    let indexedImage=try interiorRenderer.renderOffscreen(pose:roadCamera,options:indexed,width:32,height:24,samples:4)
    indexed.indexedLighting=false;interiorRenderer.frameSeed=0
    let linearImage=try interiorRenderer.renderOffscreen(pose:roadCamera,options:indexed,width:32,height:24,samples:4)
    require(indexedImage==linearImage,"Traffic changed indexed/linear static-light reservoir behavior")
}
// Read actual production center-ray guides, including a mirror 140m from
// traffic (outside all local lamp bounds), to prove reflection reactivity is
// spatially selective rather than a global history reset.
let source=try String(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal"),encoding:.utf8)
let compile=MTLCompileOptions();compile.languageVersion = .version3_1
let library=try device.makeLibrary(source:source,options:compile)
let probe=try TrafficMetal(fleet:model,staticTriangleCount:scene.triangleCount,staticAcceleration:renderer.accelerationStructure,vertices:renderer.vertexBuffer,device:device,library:library)
func guide(_ camera:CameraPose,moving:Bool)throws->SIMD4<Float> {
    let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:1,height:1,mipmapped:false)
    descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
    let textures=(0..<3).map{_ in device.makeTexture(descriptor:descriptor)!}
    let command=renderer.queue.makeCommandBuffer()!
    try probe.encodeUpdate(command,time:time,vertices:renderer.vertexBuffer)
    var u=renderer.uniforms(pose:camera,options:RenderOptions());u.viewport=SIMD4(1,1,0,0);u.forward.w=moving ? 1:0
    let encoder=command.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(probe.surfacePipeline)
    encoder.setBytes(&u,length:MemoryLayout<FrameUniforms>.stride,index:0)
    encoder.setBuffer(renderer.vertexBuffer,offset:0,index:1);encoder.setBuffer(renderer.indexBuffer,offset:0,index:2);encoder.setBuffer(renderer.materialBuffer,offset:0,index:3)
    encoder.setAccelerationStructure(probe.acceleration,bufferIndex:4);probe.bind(encoder,moving:moving)
    for (index,texture) in textures.enumerated(){encoder.setTexture(texture,index:index)}
    encoder.dispatchThreads(MTLSize(width:1,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:1,height:1,depth:1));encoder.endEncoding();command.commit();command.waitUntilCompleted();if let error=command.error{throw error}
    var pixel=SIMD4<Float>.zero
    textures[0].getBytes(&pixel,bytesPerRow:16,from:MTLRegionMake2D(0,0,1,1),mipmapLevel:0)
    return pixel
}
func flag(_ guide:SIMD4<Float>)->Float{guide.w-floor(guide.w)}
let direct=CameraPose(position:SIMD3(5,1.2,0),target:SIMD3(0,1.2,0))
let reflected=CameraPose(position:SIMD3(5,2,15),target:SIMD3(-280,0.7,0))
let distant=CameraPose(position:SIMD3(170,5,0),target:SIMD3(170,0,0))
require(flag(try guide(direct,moving:true))==0.875,"Moving vehicle inherited stationary history guide")
require(flag(try guide(reflected,moving:true))==0.875,"Distant mirror failed to track moving reflected vehicle")
require(flag(try guide(roadCamera,moving:true))==0.875,"Moving headlights/shadows retained stale roadway history")
require(flag(try guide(distant,moving:true))==0,"Unseen distant traffic invalidated unrelated static architecture")
require(flag(try guide(reflected,moving:false))==0.125,"Paused mirror lost original polished guide/convergence")
require(flag(try guide(direct,moving:false)) != 0.875,"Paused traffic retained dynamic rejection")
print("PASS: all five traffic kernels execute; static light index equivalence retained; actual guides reject moving bodies, nearby roadway and distant reflected cars while preserving unrelated/paused surfaces")

// Encode two frames before either is submitted. GPU snapshots must still use
// each frame's own immutable matrix buffer, not the last CPU pose written.
var queued:[MTLCommandBuffer]=[],snapshots:[MTLBuffer]=[]
let bytes=model.vertices.count*MemoryLayout<SceneVertex>.stride
for offset in [0.01,0.02] {
    let command=renderer.queue.makeCommandBuffer()!
    try probe.encodeUpdate(command,time:time+offset,vertices:renderer.vertexBuffer)
    let snapshot=device.makeBuffer(length:bytes,options:.storageModeShared)!
    let blit=command.makeBlitCommandEncoder()!
    blit.copy(from:renderer.vertexBuffer,sourceOffset:scene.vertices.count*MemoryLayout<SceneVertex>.stride,to:snapshot,destinationOffset:0,size:bytes);blit.endEncoding()
    queued.append(command);snapshots.append(snapshot)
}
for command in queued {command.commit()}
for command in queued {command.waitUntilCompleted();if let error=command.error{throw error}}
for (frame,offset) in [0.01,0.02].enumerated() {
    let transforms=model.transforms(at:time+offset)
    let actual=snapshots[frame].contents().bindMemory(to:SceneVertex.self,capacity:model.vertices.count)
    for index in stride(from:0,to:model.vertices.count,by:17) {
        require(simd_length(actual[index].position-transforms[Int(model.owners[index])]*model.vertices[index].position)<0.0005,"Two queued frames raced their traffic transforms")
    }
}
print("PASS: two queued GPU updates retain their own immutable frame transforms")
if CommandLine.arguments.contains("--benchmark") {
    let lanes=(0..<6).map { index in lane([SIMD3(Float(index)*3.6,0,-5200),SIMD3(Float(index)*3.6,0,5200)],id:Int64(index)) }
    let fleet=TrafficFleet(lanes:lanes)
    let combined=try TrafficMetal.buffer(scene.vertices+fleet.vertices,device:device)
    let large=try TrafficMetal(fleet:fleet,staticTriangleCount:scene.triangleCount,staticAcceleration:renderer.accelerationStructure,vertices:combined,device:device,library:library)
    var cpu:[Double]=[],gpu:[Double]=[]
    for frame in 0..<41 {
        let command=renderer.queue.makeCommandBuffer()!
        let start=Date()
        try large.encodeUpdate(command,time:Double(frame)/30,vertices:combined)
        let elapsed=Date().timeIntervalSince(start)*1000
        command.commit();command.waitUntilCompleted();if let error=command.error{throw error}
        if frame>10 {cpu.append(elapsed);gpu.append((command.gpuEndTime-command.gpuStartTime)*1000)}
    }
    print(String(format:"TRAFFIC UPDATE ONLY: %d vehicles, %d triangles; CPU pose/light-grid+encoding median %.3fms; GPU vertex-transform+BLAS/TLAS refit median %.3fms (30 warm frames; synthetic corridor, excludes city path tracing)",fleet.vehicles.count,fleet.triangleCount,cpu.sorted()[cpu.count/2],gpu.sorted()[gpu.count/2]))
}
