import Foundation
import Metal
import simd
import CryptoKit

let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
let benchmarkEnvironment=ProcessInfo.processInfo.environment
let output=URL(fileURLWithPath:benchmarkEnvironment["ATELIER_BENCHMARK_OUTPUT"] ?? "output/v12-review/render-modes-benchmark",relativeTo:root).standardizedFileURL
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
func hash(_ url:URL)throws->String {var h=SHA256();let file=try FileHandle(forReadingFrom:url);defer{try? file.close()};while let bytes=try file.read(upToCount:4*1024*1024),!bytes.isEmpty {h.update(data:bytes)};return h.finalize().map{String(format:"%02x",$0)}.joined()}
let sourceList=ProcessInfo.processInfo.environment["ATELIER_BENCHMARK_INPUTS"]!
var inputs=try String(contentsOfFile:sourceList,encoding:.utf8).split(separator:"\n").map{URL(fileURLWithPath:String($0))}
let resources=root.appendingPathComponent("Sources/ArchitectureEngine/Resources")
if let files=FileManager.default.enumerator(at:resources,includingPropertiesForKeys:[.isRegularFileKey]) {
    for case let url as URL in files where (try? url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile)==true {inputs.append(url)}
}
let unique=Array(Set(inputs.map(\.path))).sorted()
func inventory()throws->[String:String] {try Dictionary(uniqueKeysWithValues:unique.map{($0.replacingOccurrences(of:root.path+"/",with:""),try hash(URL(fileURLWithPath:$0)))})}
let before=try inventory()
let width=1280,height=850,spp=4,warmup=2,measured=12
let start=Date()
guard let device=MTLCreateSystemDefaultDevice() else {fatalError("Metal device unavailable")}
print("Building one complete Chicago world");fflush(stdout)
let buildStart=Date(),scene=ArchitectureLocation.robie.build(),sceneSeconds=Date().timeIntervalSince(buildStart)
print("World \(scene.triangleCount) static triangles; scene build \(sceneSeconds)s");fflush(stdout)
let renderer=try MetalRenderer(scene:scene,device:device)
print("Renderer setup \(renderer.buildSeconds)s; \(renderer.allocatedMB)MiB");fflush(stdout)
struct Case {var name:String;var location:ArchitectureLocation;var view:Int;var start:Double;var idle:Bool;var night:Bool}
let cases=[Case(name:"robie-exterior-day",location:.robie,view:0,start:0,idle:true,night:false),
           Case(name:"robie-exterior-night",location:.robie,view:0,start:0,idle:true,night:true),
           Case(name:"robie-living-room-day",location:.robie,view:4,start:35,idle:false,night:false),
           Case(name:"robie-living-room-night",location:.robie,view:4,start:35,idle:false,night:true),
           Case(name:"willis-skyline-day",location:.chicago,view:0,start:0,idle:true,night:false)]
func stats(_ values:[Double])->[String:Double] {let sorted=values.sorted();return ["median":(sorted[(sorted.count-1)/2]+sorted[sorted.count/2])/2,"p95":sorted[Int(ceil(Double(sorted.count)*0.95))-1],"minimum":sorted.first!,"maximum":sorted.last!,"mean":values.reduce(0,+)/Double(values.count)]}
func vector(_ v:SIMD3<Float>)->[Float] {[v.x,v.y,v.z]}
var reports:[[String:Any]]=[]
var report:[String:Any]=["status":"RUNNING","device":device.name,"os":ProcessInfo.processInfo.operatingSystemVersionString,
    "resolution":[width,height],"rtSamplesPerFrame":spp,"rayBounces":3,"warmupFrames":warmup,"measuredFrames":measured,"cameraStepSeconds":1.0/30,
    "sceneBuildSeconds":sceneSeconds,"rendererBuildSeconds":renderer.buildSeconds,"staticTriangles":scene.triangleCount,"totalTrianglesIncludingTraffic":renderer.triangleCount,
    "sceneLights":scene.lights.count,"trafficVehicles":renderer.trafficVehicleCount,"sourceAndResourceSHA256":before,"executableSHA256":try hash(URL(fileURLWithPath:CommandLine.arguments[0])),
    "scope":"One complete shared Chicago scene/renderer, serial matched moving cameras. Wall includes synchronous offscreen readback; GPU is command-buffer time. These are not native window FPS or a universal performance guarantee.",
    "modeOrder":"Alternated per case; each mode receives2warmup frames before12measured frames. Both modes start identical pose/time/seed sequences; RT history resets at each mode/case start."]
func save()throws {report["cases"]=reports;try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("metrics.json"),options:.atomic)}
try save()
var failed=false
let requestedCases=benchmarkEnvironment["ATELIER_BENCHMARK_CASES"].map{Set($0.split(separator:",").map(String.init))}
let selectedCases=cases.filter{requestedCases?.contains($0.name) ?? true}
for (caseIndex,c) in selectedCases.enumerated() {
    var caseReport:[String:Any]=["name":c.name,"location":c.location.rawValue,"view":c.view,"night":c.night,"idle":c.idle,"routeStartSeconds":c.start]
    var modes:[String:[String:Any]]=[:]
    let modeOrder=caseIndex % 2 == 0 ? [false,true]:[true,false]
    let selectedModes=modeOrder.filter{rt in benchmarkEnvironment["ATELIER_BENCHMARK_MODE"].map{$0 == (rt ? "rayTracing":"raster")} ?? true}
    for rt in selectedModes {
        let mode=rt ? "rayTracing":"raster"
        var options=RenderOptions(lighting:c.night ? 2:0);options.rayTracing=rt
        let traceBefore=renderer.rayTracingDispatchCount,guideBefore=renderer.surfaceGuideDispatchCount,updatesBefore=renderer.trafficUpdateCount,rasterBefore=renderer.rasterFrameCount,transformsBefore=renderer.rasterTrafficTransformCount
        renderer.frameSeed=0;renderer.resetAccumulation();renderer.resetReconstruction()
        var gpu:[Double]=[],wall:[Double]=[],frames:[[String:Any]]=[],last=Data(),lastPose=c.location.stops[c.view].pose
        print("\(c.name) \(mode) starting");fflush(stdout)
        for frameIndex in 0..<warmup+measured {
            let seconds=c.start+Double(frameIndex)/30
            let pose=c.idle ? c.location.idlePose(view:c.view,seconds:seconds):c.location.pose(view:c.view,seconds:seconds)
            let tick=Date()
            renderer.setSceneTime(50+seconds)
            last=try renderer.renderPreviewOffscreen(pose:pose,options:options,width:width,height:height,samples:spp,resetHistory:frameIndex==0)
            let elapsed=Date().timeIntervalSince(tick)*1000
            lastPose=pose
            if frameIndex>=warmup {
                gpu.append(renderer.lastGPUTime);wall.append(elapsed)
                var f:[String:Any]=["frame":frameIndex-warmup,"routeSeconds":seconds,"gpuMilliseconds":renderer.lastGPUTime,"wallMilliseconds":elapsed]
                if !rt {f["raster"]=renderer.rasterStatistics}
                frames.append(f)
            }
        }
        let counters:[String:Int]=["rayDispatches":renderer.rayTracingDispatchCount-traceBefore,"surfaceGuideDispatches":renderer.surfaceGuideDispatchCount-guideBefore,
            "rayTracingTrafficUpdates":renderer.trafficUpdateCount-updatesBefore,"rasterFrames":renderer.rasterFrameCount-rasterBefore,"rasterTrafficTransforms":renderer.rasterTrafficTransformCount-transformsBefore]
        let modePassed=rt ? counters["rayDispatches"]==(warmup+measured)*spp && counters["surfaceGuideDispatches"]==warmup+measured && counters["rasterFrames"]==0
            : counters["rayDispatches"]==0 && counters["surfaceGuideDispatches"]==0 && counters["rayTracingTrafficUpdates"]==0 && counters["rasterFrames"]==warmup+measured
        failed = failed || !modePassed
        let name=c.name+"-"+mode+".png"
        try writePNG(last,width:width,height:height,to:output.appendingPathComponent(name))
        modes[mode]=["status":modePassed ? "PASS":"FAIL","gpuMilliseconds":stats(gpu),"wallMilliseconds":stats(wall),"counterDeltas":counters,"frames":frames,
                     "lastImage":name,"lastImageSHA256":try hash(output.appendingPathComponent(name)),"lastCamera":["position":vector(lastPose.position),"target":vector(lastPose.target),"fov":[lastPose.fov]],"rasterFinalStatistics":renderer.rasterStatistics,"allocatedMiB":renderer.allocatedMB]
        print("\(c.name) \(mode): GPUmedian \(stats(gpu)["median"]!)ms p95 \(stats(gpu)["p95"]!)ms; wallmedian \(stats(wall)["median"]!)ms; counters \(counters)");fflush(stdout)
        caseReport["modes"]=modes
        report["activeCase"]=caseReport;try save()
    }
    if let rtMode=modes["rayTracing"],let rasterMode=modes["raster"] {
        let rt=(rtMode["gpuMilliseconds"] as! [String:Double])["median"]!,raster=(rasterMode["gpuMilliseconds"] as! [String:Double])["median"]!
        caseReport["gpuMedianRTOverRasterRatio"]=rt/raster
    }
    reports.append(caseReport);report.removeValue(forKey:"activeCase");try save()
}
let after=try inventory();report["inputsStable"]=before==after;report["changedInputs"]=unique.compactMap{url->String? in let key=url.replacingOccurrences(of:root.path+"/",with:"");return before[key]==after[key] ? nil:key}
failed = failed || before != after
report["status"]=failed ? "FAIL":"PASS";report["elapsedSeconds"]=Date().timeIntervalSince(start)
try save()
let renderedFrames=reports.reduce(0){$0+($1["modes"] as! [String:[String:Any]]).count*(warmup+measured)}
print("\(failed ? "FAIL":"PASS"): matched full-city renderer benchmark, \(reports.count) cases / \(renderedFrames) rendered frames")
if failed {exit(1)}
