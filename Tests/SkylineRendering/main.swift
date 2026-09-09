import Foundation
import Metal
import simd
import CryptoKit
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
let output=URL(fileURLWithPath:ProcessInfo.processInfo.environment["ATELIER_SKYLINE_OUTPUT"] ?? "output/v13-skyline-review/rendering",relativeTo:root).standardizedFileURL
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
func hash(_ url:URL)throws->String {var h=SHA256();let f=try FileHandle(forReadingFrom:url);defer{try? f.close()};while let b=try f.read(upToCount:4*1024*1024),!b.isEmpty {h.update(data:b)};return h.finalize().map{String(format:"%02x",$0)}.joined()}
let list=ProcessInfo.processInfo.environment["ATELIER_BENCHMARK_INPUTS"]!
var inputs=try String(contentsOfFile:list,encoding:.utf8).split(separator:"\n").map{URL(fileURLWithPath:String($0))}
if let files=FileManager.default.enumerator(at:root.appendingPathComponent("Sources/ArchitectureEngine/Resources"),includingPropertiesForKeys:[.isRegularFileKey]) {
    for case let url as URL in files where (try? url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile)==true {inputs.append(url)}
}
func inventory()throws->[String:String] {try Dictionary(uniqueKeysWithValues:Set(inputs.map(\.path)).sorted().map{($0.replacingOccurrences(of:root.path+"/",with:""),try hash(URL(fileURLWithPath:$0)))})}
let before=try inventory()
guard let device=MTLCreateSystemDefaultDevice() else {fatalError("Metal unavailable")}
let activity=ProcessInfo.processInfo.beginActivity(options:.userInitiated,reason:"Validate authored skyline renders")
defer {ProcessInfo.processInfo.endActivity(activity)}
let width=1280,height=800
print("Building shared Chicago world");fflush(stdout)
let scene=ArchitectureLocation.skyline.build(), renderer=try MetalRenderer(scene:scene,device:device)
print("World \(scene.triangleCount) triangles; renderer \(renderer.buildSeconds)s");fflush(stdout)
var checks=0
func check(_ condition:Bool,_ message:String) {checks+=1;if !condition {fatalError(message)}}
check(MemoryLayout<FrameUniforms>.stride==144,"Sunset must preserve the shared frame ABI")
let origin=SkylineScene.stops[2].pose
for mode in 0...3 {
    let u=renderer.uniforms(pose:origin,options:RenderOptions(lighting:mode))
    check(u.animation.z == (mode==3 ? 1:0),"Only sunset enables directional sunset atmosphere")
    check(u.sunColor.w == (mode>=2 ? 1:0),"Sunset and night enable architectural materials/lights")
    if mode==3 {
        check(u.sunDirection.x < -0.8 && u.sunDirection.z < -0.4 && u.sunDirection.y>0 && u.sunDirection.y<0.1,"Sunset is low WNW, behind the Adler skyline")
        check(u.sunColor.x > u.sunColor.y*2 && u.sunColor.y > u.sunColor.z*2,"Sunset uses warm direct irradiance")
    }
}
var results:[[String:Any]]=[]
// Every authored composition, followed by matched-pose day/sunset/night tracing.
let shots=(0..<8).map{($0,SkylineScene.preferredLighting[$0],false)}+[(0,1,true),(2,3,true),(3,2,true),(2,1,true),(2,2,true)]
for (view,lighting,rt) in shots {
    let pose=SkylineScene.stops[view].pose
    var options=RenderOptions(lighting:lighting);options.rayTracing=rt
    renderer.setSceneTime(0);renderer.frameSeed=0;renderer.resetAccumulation();renderer.resetReconstruction()
    let traces=renderer.rayTracingDispatchCount,guides=renderer.surfaceGuideDispatchCount,traffic=renderer.trafficUpdateCount,rasters=renderer.rasterFrameCount
    let start=Date()
    let bytes=try renderer.renderOffscreen(pose:pose,options:options,width:width,height:height,samples:rt ? 64:1)
    let name="view-\(view)-lighting-\(lighting)-\(rt ? "raytracing":"raster").png"
    try writePNG(bytes,width:width,height:height,to:output.appendingPathComponent(name))
    check(bytes.count==width*height*4,"All output pixels exist")
    if rt {check(renderer.rayTracingDispatchCount-traces==64 && renderer.rasterFrameCount==rasters,"RT retains requested 64 samples")}
    else {check(renderer.rayTracingDispatchCount==traces && renderer.surfaceGuideDispatchCount==guides && renderer.trafficUpdateCount==traffic && renderer.rasterFrameCount==rasters+1,"Raster has no ray queries/AS updates")}
    results.append(["view":view,"lighting":lighting,"mode":rt ? "rayTracing":"raster","image":name,"sha256":try hash(output.appendingPathComponent(name)),"wallSeconds":Date().timeIntervalSince(start),"lastGPUBufferMilliseconds":renderer.lastGPUTime,"rasterStatistics":renderer.rasterStatistics])
    print("Rendered \(name)");fflush(stdout)
}
let after=try inventory();check(before==after,"Rendering inputs stayed stable")
let report:[String:Any]=["status":"PASS","checks":checks,"device":device.name,"width":width,"height":height,"staticTriangles":scene.triangleCount,"rendererBuildSeconds":renderer.buildSeconds,"shots":results,"sourceAndResourceSHA256":before,"inputsStable":before==after,"executableSHA256":try hash(URL(fileURLWithPath:CommandLine.arguments[0])),"scope":"Authored still compositions and renderer contract checks, 8 raster plus 5 RT images. Timings are synchronous offscreen diagnostics, not native frame rate. Image aesthetic review is separate."]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("validation.json"),options:.atomic)
print("PASS: \(checks) checks, \(shots.count) skyline stills")
