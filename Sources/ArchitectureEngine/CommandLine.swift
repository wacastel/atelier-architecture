import Foundation
import Metal
import simd
import AVFoundation
import VideoToolbox
import CoreText

@MainActor func runCommandLine() -> Bool {
    let args = Array(CommandLine.arguments.dropFirst())
    let cacheValueFlags: Set<String> = ["--cache-dir","--cache-report","--precache-city","--startup-report"]
    for flag in cacheValueFlags where args.contains(flag) {
        guard args.filter({$0==flag}).count==1,let i=args.firstIndex(of:flag),i+1<args.count,!args[i+1].isEmpty,!args[i+1].hasPrefix("--") else {
            fputs("\(flag) requires one value.\n",stderr);exit(2)
        }
    }
    if CityPrecache.runIfRequested() { return true }
    let exportFlags: Set<String> = ["--self-test","--render","--gallery","--video","--motion-test","--help"]
    if !args.contains(where:exportFlags.contains) {
        let switches: Set<String> = ["--startup-exit-after-first-frame","--no-city-cache","--force-rebuild-cache"]
        var i=0,valid=true
        while i<args.count {
            if ["--cache-dir","--startup-report"].contains(args[i]) { i+=2 }
            else if switches.contains(args[i]) { i+=1 }
            else { valid=false;break }
        }
        if valid { return false }
    }
    guard args.contains(where:{ ["--self-test","--render","--gallery","--video","--motion-test","--help"].contains($0) }) else {
        if args.contains(where: { $0.hasPrefix("--") }) {
            fputs("Choose --render, --gallery, --video or --self-test. Use --help for options.\n", stderr)
            exit(2)
        }
        return false
    }
    if args.contains("--help") {
        print("""
        ATELIER — native Apple Silicon architectural renderer
        --precache-city chicago|paris|all   Prepare launch caches without opening a window
        --cache-dir directory       Override local city cache storage
        --force-rebuild-cache       Rebuild prepared caches for this executable/resources
        --cache-report report.json  Write precache timings and cache status
        --startup-report report.json --startup-exit-after-first-frame
                                   Measure a new native window through first city presentation
        --no-city-cache             Disable cache reads/writes for a startup baseline
        --self-test                 Validate geometry, selected renderer and image output
        --render image.png          Render a still
        --gallery directory         Render every tour bookmark
        --video walkthrough.mp4     Export the guided walkthrough (native H.264)
        --location paris           paris / chicago / skyline / millennium / culturalcenter / lakefront / navypier / campus / northside / robie (default paris)
        --width 1920 --height 1080 --samples 64 --stop 0
        --at 28                    Render selected walkthrough at this second
        --camera x,y,z --target x,y,z --fov 60   Override a still camera
        --seconds 108 --fps 24       Video duration and frame rate
        --lighting 0                0 golden hour, 1 daylight, 2 illuminated night, 3 sunset (Skyline defaults to authored lighting)
        --sunset-lights-off         Disable fixed architectural/site lights only at sunset
        --single-view --stop 0      Export one full route (56–360 seconds)
        --idle                     Export the selected view’s slow idle animation
        --renderer path|direct|raster  Select renderer (default path)
        --raster                   Compatibility alias for --renderer raster
                                   Direct/raster render once; --samples applies to path tracing
        --raw                      Disable path-tracing motion reconstruction for comparison
        --no-regularization        Disable secondary glossy path regularization
        --random-sampling          Use independent random rays for sampler comparisons
        --linear-lights            Disable spatial light indexing for exact comparisons
        --motion-test directory    Measure actual moving-scene noise against 128spp references
        --motion-case name         Limit the moving-scene benchmark to one named case
        --obj building.obj --scale 1 Load another structure; scale converts units to meters
        """)
        return true
    }
    if args.contains("--obj") && (!args.contains("--render") || args.contains("--video") || args.contains("--gallery") || args.contains("--self-test")) {
        fputs("OBJ scenes currently support --render. The guided tour, gallery and navigation self-test use the selected built-in location.\n", stderr)
        exit(2)
    }
    func value(_ flag:String, _ fallback:String) -> String {
        if let i = args.firstIndex(of:flag), i+1 < args.count { return args[i+1] }; return fallback
    }
    func integer(_ flag:String, _ fallback:Int) -> Int { Int(value(flag,String(fallback))) ?? fallback }
    if args.filter({$0=="--renderer"}).count>1 || (args.last=="--renderer") {
        fputs("Specify --renderer once, followed by path, direct or raster.\n",stderr);exit(2)
    }
    let rendererName=value("--renderer",args.contains("--raster") ? "raster":"path").lowercased()
    guard ["path","direct","raster"].contains(rendererName) else {
        fputs("Unknown renderer. Choose --renderer path, direct or raster.\n",stderr);exit(2)
    }
    if args.contains("--raster") && rendererName != "raster" {
        fputs("--raster conflicts with --renderer \(rendererName). Choose one renderer.\n",stderr);exit(2)
    }
    if args.contains("--motion-test") && rendererName != "path" {
        fputs("--motion-test evaluates the original path-tracing reconstruction. Use --renderer path; direct and raster support --render, --gallery, --video and --self-test.\n",stderr);exit(2)
    }
    let rendererTitle=rendererName=="path" ? "Path Tracing":rendererName=="direct" ? "Direct Ray Tracing":"Fast Raster"
    do {
        // An offscreen export is user-requested work even when its app has no
        // visible window. Keep it eligible to run until this command completes.
        let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "Rendering the requested architectural scene")
        defer { ProcessInfo.processInfo.endActivity(activity) }
        let locationName=value("--location","paris").lowercased()
        let location: ArchitectureLocation
        switch locationName {
        case "paris", "eiffel": location = .paris
        case "chicago", "willis": location = .chicago
        case "skyline": location = .skyline
        case "millennium", "park": location = .millennium
        case "culturalcenter", "cultural-center", "cultural": location = .culturalcenter
        case "lakefront", "magmile", "grant": location = .lakefront
        case "navypier", "navy-pier", "pier": location = .navypier
        case "campus", "museum", "museums": location = .campus
        case "northside", "north", "wrigley", "zoo": location = .northside
        case "robie", "hydepark", "hyde-park": location = .robie
        default: throw EngineError.message("Unknown location. Choose paris, chicago, skyline, millennium, culturalcenter, lakefront, navypier, campus, northside or robie.")
        }
        guard let device = MTLCreateSystemDefaultDevice() else { throw EngineError.message("No Metal GPU.") }
        let start = Date()
        print("GPU: \(device.name) | hardware RT: \(device.supportsRaytracing) | unified memory: \(device.hasUnifiedMemory)")
        let scene: SceneData
        if args.contains("--obj") { scene = try OBJScene.load(url:URL(fileURLWithPath:value("--obj","")),scale:Float(value("--scale","1")) ?? 1) }
        else { scene = location.build() }
        if args.contains("--obj") { print(OBJScene.materialLimitations) }
        print("Scene: \(scene.name) | \(scene.triangleCount) triangles | \(scene.detailCount) geometric details | \(scene.materials.count) materials")
        guard scene.vertices.allSatisfy({ v in v.position.x.isFinite && v.position.y.isFinite && v.position.z.isFinite && v.normal.x.isFinite && v.normal.y.isFinite && v.normal.z.isFinite }) else { throw EngineError.message("Scene has nonfinite vertices.") }
        guard MemoryLayout<SceneVertex>.stride == 32, MemoryLayout<SceneMaterial>.stride == 32, MemoryLayout<FrameUniforms>.stride == 144, MemoryLayout<SceneLight>.stride == 64, MemoryLayout<TemporalUniforms>.stride == 112 else { throw EngineError.message("Swift/Metal ABI mismatch.") }
        let renderer = try MetalRenderer(scene:scene,device:device)
        print(String(format:"Metal pipelines + acceleration structure: %.2fs | allocated %.1f MiB",renderer.buildSeconds,renderer.allocatedMB))
        let width = max(64,min(8192,integer("--width",args.contains("--self-test") ? 640 : 1920)))
        let height = max(64,min(8192,integer("--height",args.contains("--self-test") ? 400 : 1080)))
        let samples = max(1,min(8192,integer("--samples",args.contains("--video") ? 8 : 64)))
        let stop = max(0,min(location.stops.count-1,integer("--stop",0)))
        let defaultLighting = location.preferredLighting(view: stop) ?? 0
        let options = RenderOptions(exposure:1,bounces:Float(max(1,min(8,integer("--bounces",3)))),lighting:max(0,min(3,integer("--lighting",defaultLighting))),sunsetBuildingLights:!args.contains("--sunset-lights-off"),denoising:!args.contains("--raw"),regularization:!args.contains("--no-regularization"),lowDiscrepancySampling:!args.contains("--random-sampling"),indexedLighting:!args.contains("--linear-lights"),rayTracing:rendererName != "raster",directRayTracing:rendererName=="direct",hazeDensity:args.contains("--obj") ? 0:location.hazeDensity(view:stop))
        print("Renderer: \(rendererTitle)\(rendererName=="path" ? "":" · one deterministic frame; requested SPP is ignored")")
        var pose = location.stops[stop].pose
        if args.contains("--at") {
            guard let seconds=Double(value("--at","0")),seconds.isFinite else { throw EngineError.message("--at requires finite seconds.") }
            pose=args.contains("--idle") ? location.idlePose(view:stop,seconds:seconds) : location.pose(view:stop,seconds:seconds)
            renderer.setSceneTime(args.contains("--idle") ? max(0,seconds) : max(0,min(location.duration(view:stop),seconds)))
        }
        if args.contains("--obj") {
            var lo = SIMD3<Float>(repeating:.greatestFiniteMagnitude), hi = -lo
            for v in scene.vertices { lo = simd_min(lo,v.position.xyz); hi = simd_max(hi,v.position.xyz) }
            let center = (lo+hi)/2, extent = max(1,simd_length(hi-lo))
            pose = CameraPose(position:center+SIMD3(extent*0.7,extent*0.4,extent*0.9),target:center)
        }
        func vector(_ flag:String, fallback:SIMD3<Float>) throws -> SIMD3<Float> {
            guard args.contains(flag) else { return fallback }
            let parts = value(flag, "").split(separator:",").compactMap { Float($0) }
            guard parts.count == 3, parts.allSatisfy({ $0.isFinite }) else { throw EngineError.message("\(flag) expects three finite coordinates separated by commas.") }
            return SIMD3(parts[0],parts[1],parts[2])
        }
        pose.position = try vector("--camera",fallback:pose.position)
        pose.target = try vector("--target",fallback:pose.target)
        if args.contains("--fov") {
            guard let fov=Float(value("--fov","")),fov.isFinite,fov>=5,fov<=140 else { throw EngineError.message("Field of view must be between 5 and 140 degrees.") }
            pose.fov=fov
        }
        guard simd_distance(pose.position,pose.target)>0.01 else { throw EngineError.message("Camera position and target must be different.") }
        if args.contains("--self-test") {
            for (w,h) in [(96,64),(64,96),(128,72),(96,64)] {
                let resized = try renderer.renderPreviewOffscreen(pose:pose,options:options,width:w,height:h,samples:2)
                let u=renderer.uniforms(pose:pose,options:options)
                let aspect=simd_length(u.right.xyz)/simd_length(u.up.xyz)
                guard resized.count==w*h*4,renderer.width==w,renderer.height==h,
                      abs(aspect-Float(w)/Float(h))<0.00001 else { throw EngineError.message("Viewport resize/aspect validation failed.") }
            }
            let first = try renderer.renderOffscreen(pose:pose,options:options,width:width,height:height,samples:1)
            let pixels = try renderer.renderOffscreen(pose:pose,options:options,width:width,height:height,samples:16)
            let bytes = [UInt8](pixels)
            var luminance: [Double] = []
            for i in stride(from:0,to:bytes.count,by:4) {
                let sum = Int(bytes[i]) + Int(bytes[i+1]) + Int(bytes[i+2])
                luminance.append(Double(sum)/3.0)
            }
            let mean = luminance.reduce(0,+)/Double(luminance.count)
            guard mean > 10 && mean < 250, (luminance.max()!-luminance.min()!) > 60 else { throw EngineError.message("Rendered image is blank or lacks range.") }
            if options.directRayTracing {
                guard first == pixels, renderer.sampleCount == 1, renderer.directRayDispatchCount > 0,
                      renderer.rayTracingDispatchCount == 0, renderer.surfaceGuideDispatchCount == 0,
                      renderer.rasterFrameCount == 0 else {
                    throw EngineError.message("Direct rays failed deterministic rendering or invoked a different renderer.")
                }
            } else if options.rayTracing {
                guard first != pixels, renderer.sampleCount == 16, renderer.directRayDispatchCount == 0 else { throw EngineError.message("Progressive ray accumulation failed.") }
            } else {
                guard first == pixels, renderer.sampleCount == 0, renderer.rayTracingDispatchCount == 0,
                      renderer.surfaceGuideDispatchCount == 0, renderer.directRayDispatchCount == 0, renderer.rasterFrameCount > 0 else {
                    throw EngineError.message("Ray-off path traced rays or failed deterministic raster rendering.")
                }
            }
            let path = URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/self-test.png")
            try writePNG(pixels,width:width,height:height,to:path)
            let collision = CollisionWorld(scene:scene)
            guard collision.distance(origin:SIMD3(0,3,90),direction:SIMD3(0,-1,0),maximum:10) != nil else { throw EngineError.message("Navigation ground intersection failed.") }
            let importerChecks = try testOBJImporter()
            var report: [String:Any] = ["passed":true,"device":device.name,"unifiedMemory":device.hasUnifiedMemory,"rayTracing":device.supportsRaytracing,"triangleCount":scene.triangleCount,"geometricDetails":scene.detailCount,"materials":scene.materials.count,"lights":scene.lights.count,"location":location.rawValue,"mappedBuildingFootprints":location == .paris ? ParisContext.database.buildings.count:ChicagoContext.database.buildings.count,"mapTimestamp":location == .paris ? ParisContext.database.timestamp:ChicagoContext.database.timestamp,"thinGlass":renderer.hasTransmission,"allocatedMiB":renderer.allocatedMB,"gpuLastSampleMilliseconds":renderer.lastGPUTime,"imageMeanByte":mean,"resolution":[width,height],"samples":16,"abiValidated":true,"navigationBVHNodes":collision.nodes.count,"importerChecks":importerChecks,"elapsedSeconds":Date().timeIntervalSince(start)]
            report["renderMode"] = options.directRayTracing ? "directRayTracing":options.rayTracing ? "pathTracing":"raster"
            report["renderer"] = rendererName
            report["pathTraceDispatches"] = renderer.rayTracingDispatchCount
            report["directRayDispatches"] = renderer.directRayDispatchCount
            report["rasterStatistics"] = renderer.rasterStatistics
            if rendererName != "path" {
                report["samples"] = options.directRayTracing ? 1:0
                report["gpuLastFrameMilliseconds"] = renderer.lastGPUTime
                report.removeValue(forKey:"gpuLastSampleMilliseconds")
            }
            if location.world == "chicago" {
                report["millenniumMapTimestamp"] = MillenniumContext.database.timestamp
                report["millenniumMappedAreas"] = MillenniumContext.database.areas.count
                report["millenniumMappedPaths"] = MillenniumContext.database.paths.count
                report["millenniumMappedTrees"] = MillenniumContext.database.trees.count
                report["lakefrontMapTimestamp"] = LakefrontContext.database.timestamp
                report["lakefrontAdditionalMappedBuildings"] = LakefrontContext.database.buildings.count
                report["lakefrontMappedSurfaces"] = LakefrontContext.database.areas.count
                report["lakefrontMappedTrees"] = LakefrontContext.database.trees.count
                report["lakefrontMappedPiers"] = LakefrontContext.database.piers.count
                report["museumCampusMapTimestamp"] = MuseumCampusContext.database.timestamp
                report["museumCampusAdditionalMappedBuildings"] = MuseumCampusContext.database.buildings.count
                report["museumCampusLandmarksAndParts"] = MuseumCampusContext.database.landmarks.count
                report["museumCampusAdditionalBoats"] = MuseumCampusContext.database.boats.count
                report["museumCampusAdditionalTrees"] = MuseumCampusContext.database.trees.count
                report["northSideMapTimestamp"] = NorthSideContext.database.timestamp
                report["northSideAdditionalMappedBuildings"] = NorthSideContext.database.buildings.count
                report["northSideMappedPaths"] = NorthSideContext.database.paths.count
                report["northSideAdditionalBoats"] = NorthSideContext.database.boats.count
                report["northSideAdditionalTrees"] = NorthSideContext.database.trees.count
                report["northSideLandmarksAndParts"] = NorthSideContext.database.landmarks.count
                report["hydeParkMapTimestamp"] = HydeParkContext.database.timestamp
                report["hydeParkAdditionalMappedBuildings"] = HydeParkContext.database.buildings.count
                report["hydeParkMappedPaths"] = HydeParkContext.database.paths.count
                report["hydeParkAdditionalBoats"] = HydeParkContext.database.boats.count
                report["hydeParkAdditionalTrees"] = HydeParkContext.database.trees.count + HydeParkContext.database.landcoverTrees.count
                for (label,lights) in [("night",scene.lights),("day",scene.lights.filter{$0.parameters.z>0.5})] {
                    let grid=LightGrid(lights:lights)
                    guard grid.enabled else { throw EngineError.message("Built-in \(label) light index exceeded its budget: \(grid.fallbackReason ?? "unknown")") }
                    report[label+"LightGridEnabled"]=grid.enabled
                    report[label+"LightGridCells"]=grid.ranges.count
                    report[label+"LightGridIndices"]=grid.indices.count
                    report[label+"LightGridMaximumCandidates"]=grid.ranges.map{$0.y}.max() ?? 0
                }
                report["vertexBufferBytes"]=renderer.vertexBuffer.length
                report["staticGeometrySections"]=renderer.staticGeometrySections
                report["trianglesPerStaticGeometry"]=GeometryPartition.trianglesPerGeometry
                report["deviceMaxBufferLengthBytes"]=device.maxBufferLength
                report["frameUniformBytes"] = MemoryLayout<FrameUniforms>.stride
                let fleet = TrafficFleet(lanes: scene.trafficLanes)
                report["trafficLanes"] = fleet.paths.count
                report["trafficVehicles"] = fleet.vehicles.count
                report["trafficTriangles"] = fleet.triangleCount
                report["trafficClockSeconds"] = renderer.sceneTime
                report["sharedChicagoWorld"] = true
            }
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:path.deletingLastPathComponent().appendingPathComponent("validation.json"))
            print("PASS: geometry, ABI, acceleration structure, \(rendererTitle)\(rendererName=="path" ? " and progressive accumulation":" and deterministic frame output"), image range, navigation BVH and OBJ importer.")
            print("Validation: \(path.deletingLastPathComponent().appendingPathComponent("validation.json").path)")
        }
        if args.contains("--motion-test") {
            try validateSceneMotion(scene:scene,device:device,folder:URL(fileURLWithPath:value("--motion-test","output/motion-validation")),width:width,height:height,frames:max(16,min(240,integer("--frames",48))),samples:integer("--samples",4),referenceSamples:max(64,integer("--reference-samples",128)),nightOnly:args.contains("--lighting") && integer("--lighting",0)==2,location:location,regularization:options.regularization,lowDiscrepancySampling:options.lowDiscrepancySampling,indexedLighting:options.indexedLighting,caseName:args.contains("--motion-case") ? value("--motion-case", "") : nil)
        }
        if args.contains("--render") {
            let pixels = try renderer.renderOffscreen(pose:pose,options:options,width:width,height:height,samples:samples)
            let url = URL(fileURLWithPath:value("--render","output/Eiffel.png"))
            try writePNG(pixels,width:width,height:height,to:url); print("Saved \(url.path)")
        }
        if args.contains("--gallery") {
            let folder = URL(fileURLWithPath:value("--gallery","output/gallery"))
            for (index, stop) in location.stops.enumerated() {
                var shotOptions = options
                shotOptions.hazeDensity = location.hazeDensity(view:index)
                if !args.contains("--lighting"), let lighting = location.preferredLighting(view:index) { shotOptions.lighting = lighting }
                let pixels = try renderer.renderOffscreen(pose:stop.pose,options:shotOptions,width:width,height:height,samples:samples)
                let url = folder.appendingPathComponent(String(format:"%02d",stop.id)+"-"+stop.title.lowercased().replacingOccurrences(of:" ",with:"-")+".png")
                try writePNG(pixels,width:width,height:height,to:url)
                print("Saved \(url.path)"); fflush(stdout)
            }
        }
        if args.contains("--video") {
            let url = URL(fileURLWithPath:value("--video","output/Eiffel-Walkthrough.mp4"))
            let defaultSeconds = args.contains("--single-view") || args.contains("--idle") ? location.duration(view: stop) : Double(location.stops.count*12)
            guard let requestedSeconds=Double(value("--seconds",String(defaultSeconds))),requestedSeconds.isFinite else { throw EngineError.message("--seconds requires a finite duration.") }
            let seconds = max(6,min(600,requestedSeconds))
            let fps = max(12,min(60,integer("--fps",24)))
            try exportVideo(renderer:renderer,url:url,width:width,height:height,seconds:seconds,fps:fps,samples:samples,options:options,singleView:args.contains("--single-view") || args.contains("--idle") ? stop : nil,idle:args.contains("--idle"),location:location,authoredLighting:!args.contains("--lighting"))
        }
        print(String(format:"Completed in %.2fs",Date().timeIntervalSince(start)))
    } catch { fputs("ERROR: \(error.localizedDescription)\n",stderr); exit(1) }
    return true
}

private func exportVideo(renderer:MetalRenderer,url:URL,width:Int,height:Int,seconds:Double,fps:Int,samples:Int,options:RenderOptions,singleView:Int? = nil,idle:Bool = false,location:ArchitectureLocation,authoredLighting:Bool = true) throws {
    guard width % 2 == 0 && height % 2 == 0 else { throw EngineError.message("H.264 dimensions must be even.") }
    try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
    // A fresh export never silently replaces an existing recording.
    if FileManager.default.fileExists(atPath:url.path) { throw EngineError.message("Video already exists at \(url.path); choose a new filename.") }
    let writer = try AVAssetWriter(outputURL:url,fileType:.mp4)
    // AutoLevel needs the source-rate hint to select a compatible bitstream.
    // Offline frame timestamps must remain independent of rendering wall time.
    let compression:[String:Any] = [
        AVVideoAverageBitRateKey:width*height*10,
        AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel,
        AVVideoExpectedSourceFrameRateKey:fps,
        kVTCompressionPropertyKey_RealTime as String:false
    ]
    let settings:[String:Any] = [AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:compression]
    let input = AVAssetWriterInput(mediaType:.video,outputSettings:settings)
    input.expectsMediaDataInRealTime = false
    let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? EngineError.message("Video encoder failed to start.") }
    writer.startSession(atSourceTime:.zero)
    let frameCount = Int(seconds*Double(fps))
    let duration = Double(location.stops.count)*12
    var previousChapter = -1
    for frame in 0..<frameCount {
        try autoreleasepool {
            let time = Double(frame)/Double(frameCount)*duration
            let shot: (pose:CameraPose,index:Int,seconds:Double)
            if let view = singleView {
                let local = idle ? Double(frame)/Double(fps) : Double(frame)/Double(max(1,frameCount-1))*location.duration(view: view)
                shot = (idle ? location.idlePose(view:view,seconds:local) : location.pose(view:view,seconds:local),view,local)
            } else {
                let chapter=min(location.stops.count-1,Int(time/12))
                let local=(time-Double(chapter)*12)/12*location.duration(view:chapter)
                shot=(location.pose(view:chapter,seconds:local),chapter,local)
            }
            renderer.setSceneTime(shot.seconds)
            var shotOptions = options
            shotOptions.hazeDensity = location.hazeDensity(view:shot.index)
            if authoredLighting, let lighting = location.preferredLighting(view:shot.index) { shotOptions.lighting = lighting }
            let pixels = try renderer.renderPreviewOffscreen(pose:shot.pose,options:shotOptions,width:width,height:height,samples:samples,resetHistory:previousChapter != shot.index)
            previousChapter = shot.index
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error ?? EngineError.message("Video encoder failed.") }
                Thread.sleep(forTimeInterval:0.001)
            }
            guard let pool = adapter.pixelBufferPool else { throw EngineError.message("Video pixel buffer pool unavailable.") }
            var optional:CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault,pool,&optional) == kCVReturnSuccess, let buffer = optional else { throw EngineError.message("Video pixel allocation failed.") }
            CVPixelBufferLockBaseAddress(buffer,[])
            let base = CVPixelBufferGetBaseAddress(buffer)!, rowBytes = CVPixelBufferGetBytesPerRow(buffer)
            pixels.withUnsafeBytes { bytes in
                for row in 0..<height { base.advanced(by:row*rowBytes).copyMemory(from:bytes.baseAddress!.advanced(by:row*width*4),byteCount:width*4) }
            }
            drawVideoCaption(base:base,rowBytes:rowBytes,width:width,height:height,stop:location.stops[shot.index],progress:Double(frame)/Double(frameCount),location:location)
            CVPixelBufferUnlockBaseAddress(buffer,[])
            guard adapter.append(buffer,withPresentationTime:CMTime(value:Int64(frame),timescale:Int32(fps))) else { throw writer.error ?? EngineError.message("Could not append video frame.") }
        }
        if frame % (fps*2) == 0 { print("Video \(Int(Double(frame)*100/Double(frameCount)))% · chapter \(previousChapter+1)"); fflush(stdout) }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value:0)
    writer.finishWriting { done.signal() }; done.wait()
    guard writer.status == .completed else { throw writer.error ?? EngineError.message("Video finalization failed.") }
    print("Saved \(url.path)")
}

private func drawVideoCaption(base:UnsafeMutableRawPointer,rowBytes:Int,width:Int,height:Int,stop:TourStop,progress:Double,location:ArchitectureLocation) {
    guard let context = CGContext(data:base,width:width,height:height,bitsPerComponent:8,bytesPerRow:rowBytes,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return }
    let scale = CGFloat(width)/1920
    context.scaleBy(x:scale,y:scale)
    let h = CGFloat(height)/scale
    context.setFillColor(CGColor(red:0.035,green:0.055,blue:0.07,alpha:0.84))
    context.fill(CGRect(x:30,y:h-176,width:570,height:145))
    func text(_ string:String,x:CGFloat,y:CGFloat,size:CGFloat,color:CGColor,maximumWidth:CGFloat? = nil) {
        func makeLine(_ fontSize:CGFloat)->CTLine {
            let font = CTFontCreateWithName("HelveticaNeue" as CFString,fontSize,nil)
            let attributes:[NSAttributedString.Key:Any] = [.font:font,.foregroundColor:color]
            return CTLineCreateWithAttributedString(NSAttributedString(string:string,attributes:attributes))
        }
        var line = makeLine(size)
        if let maximumWidth {
            let width = CGFloat(CTLineGetTypographicBounds(line,nil,nil,nil))
            if width > maximumWidth { line = makeLine(size * maximumWidth / width) }
        }
        context.textPosition = CGPoint(x:x,y:y); CTLineDraw(line,context)
    }
    let ivory = CGColor(red:0.95,green:0.94,blue:0.90,alpha:1), gold = CGColor(red:0.86,green:0.71,blue:0.47,alpha:1)
    let heading: String
    switch location {
    case .paris: heading = "A T E L I E R    /    E I F F E L"
    case .chicago: heading = "A T E L I E R    /    W I L L I S"
    case .skyline: heading = "A T E L I E R    /    C H I C A G O   S K Y L I N E"
    case .millennium: heading = "A T E L I E R    /    M I L L E N N I U M"
    case .culturalcenter: heading = "A T E L I E R    /    C U L T U R A L   C E N T E R"
    case .lakefront: heading = "A T E L I E R    /    L A K E F R O N T"
    case .navypier: heading = "A T E L I E R    /    N A V Y   P I E R"
    case .campus: heading = "A T E L I E R    /    M U S E U M   C A M P U S"
    case .northside: heading = "A T E L I E R    /    C H I C A G O   N O R T H   S I D E"
    case .robie: heading = "A T E L I E R    /    R O B I E   H O U S E"
    }
    text(heading,x:58,y:h-69,size:18,color:gold)
    text(stop.title,x:58,y:h-115,size:32,color:ivory,maximumWidth:514)
    text(stop.subtitle,x:58,y:h-148,size:13,color:ivory,maximumWidth:514)
    context.setFillColor(CGColor(red:0.035,green:0.055,blue:0.07,alpha:0.65)); context.fill(CGRect(x:30,y:28,width:1860,height:34))
    text("Architectural reconstruction  ·  Map data © OpenStreetMap contributors",x:45,y:39,size:14,color:ivory)
    context.setFillColor(gold); context.fill(CGRect(x:30,y:24,width:1860*progress,height:3))
}
