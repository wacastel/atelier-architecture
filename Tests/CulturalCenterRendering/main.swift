import Foundation
import Metal
import CryptoKit
import simd

let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
let draft=CommandLine.arguments.contains("--draft")
let output=root.appendingPathComponent(draft ? "output/v16-review/cultural-draft":"output/v16-review/cultural-rendering")
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
func hash(_ url:URL)throws->String { SHA256.hash(data:try Data(contentsOf:url)).map{String(format:"%02x",$0)}.joined() }
let inputs=try String(contentsOfFile:ProcessInfo.processInfo.environment["ATELIER_BENCHMARK_INPUTS"]!,encoding:.utf8).split(separator:"\n").map(String.init)
func inventory()throws->[String:String] { try Dictionary(uniqueKeysWithValues:inputs.map{($0.replacingOccurrences(of:root.path+"/",with:""),try hash(URL(fileURLWithPath:$0)))}) }
let before=try inventory()
guard let device=MTLCreateSystemDefaultDevice() else {fatalError("Metal unavailable")}
let activity=ProcessInfo.processInfo.beginActivity(options:.userInitiated,reason:"Review Cultural Center in its shared Chicago world")
defer {ProcessInfo.processInfo.endActivity(activity)}
let width=draft ? 800:1280,height=draft ? 500:800,samples=draft ? 16:64
print("Building shared Chicago world");fflush(stdout)
let scene=ArchitectureLocation.culturalcenter.build(),renderer=try MetalRenderer(scene:scene,device:device)
print("World \(scene.triangleCount) triangles; renderer \(renderer.buildSeconds)s");fflush(stdout)
var checks=0
func check(_ okay:Bool,_ message:String) {checks+=1;if !okay {fatalError(message)}}
check(MemoryLayout<FrameUniforms>.stride==144,"Selection must preserve the shared frame ABI")
check(ArchitectureLocation.culturalcenter.world==ArchitectureLocation.chicago.world,"Destination reuses physical Chicago")
check(CulturalCenterScene.stops.count==8,"Eight Cultural Center views")
var results=[[String:Any]]()
let views=draft ? [0,2,3,5]:Array(0..<8)
for lighting in (draft ? [0]:[0,2]) {for view in views {
    let pose=CulturalCenterScene.stops[view].pose
    let options=RenderOptions(lighting:lighting)
    renderer.setSceneTime(0);renderer.frameSeed=0;renderer.resetAccumulation();renderer.resetReconstruction()
    let traces=renderer.rayTracingDispatchCount,start=Date()
    let bytes=try renderer.renderPreviewOffscreen(pose:pose,options:options,width:width,height:height,samples:samples,resetHistory:true)
    let name="view-\(view+1)-\(lighting==0 ? "day":"night").png"
    try writePNG(bytes,width:width,height:height,to:output.appendingPathComponent(name))
    check(bytes.count==width*height*4,"Complete BGRA output")
    check(renderer.rayTracingDispatchCount-traces==samples,"Requested ray samples retained")
    results.append(["view":view,"lighting":lighting,"image":name,"wallSeconds":Date().timeIntervalSince(start),"samples":samples,"mode":"reconstructed RT","sha256":try hash(output.appendingPathComponent(name))])
    print("Rendered \(name)");fflush(stdout)
}}
if !draft {
    let focus=LandmarkFocusCatalog(world:"chicago",includeMapped:false).lookup(id:"chicago:cultural-center")!
    let highlighted=FocusHighlightData(volumes:focus.volumes.map { volume in
        FocusHighlightVolume(minimum:volume.bounds.minimum,maximum:volume.bounds.maximum,
            points:volume.triangles.isEmpty ? volume.points:volume.triangles.map { volume.points[$0] },
            triangulated:!volume.triangles.isEmpty)
    })
    // Actual resident geometry, both modes of presenting a selected landmark.
    for rt in [false,true] {
        var options=RenderOptions(lighting:0);options.rayTracing=rt
        let pose=ManualCityNavigation.landmarkOverview(target:focus.center,radius:66,heading:SIMD3(-1,0,-1),roof:{_,_ in 0})!
        renderer.focusHighlight=highlighted;renderer.frameSeed=0;renderer.resetAccumulation();renderer.resetReconstruction()
        let traces=renderer.rayTracingDispatchCount,guides=renderer.surfaceGuideDispatchCount
        let bytes=try renderer.renderPreviewOffscreen(pose:pose,options:options,width:width,height:height,samples:rt ? 32:1,resetHistory:true)
        let name="focused-\(rt ? "ray":"raster").png"
        try writePNG(bytes,width:width,height:height,to:output.appendingPathComponent(name))
        if !rt {check(renderer.rayTracingDispatchCount==traces && renderer.surfaceGuideDispatchCount==guides,"Raster focus adds no rays")}
        results.append(["image":name,"mode":rt ? "RT reconstructed focus":"raster focus","sha256":try hash(output.appendingPathComponent(name))])
    }
    renderer.focusHighlight=FocusHighlightData(volumes:[])
}
let after=try inventory();check(before==after,"Rendering inputs remained unchanged")
let report:[String:Any]=["status":"PASS","checks":checks,"device":device.name,"draft":draft,"width":width,"height":height,"staticTriangles":scene.triangleCount,"allocatedMB":renderer.allocatedMB,"rendererBuildSeconds":renderer.buildSeconds,"shots":results,"sourceSHA256":before,"inputsStable":before==after,"scope":"Actual Chicago stills, authored eight views in day/night, and selected Cultural Center in raster and reconstructed RT. Separate visual review required. Not a motion-noise or native-FPS benchmark."]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("validation.json"))
print("PASS: \(checks) checks, \(results.count) stills")
