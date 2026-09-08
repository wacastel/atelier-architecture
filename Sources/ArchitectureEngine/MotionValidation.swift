import Foundation
import Metal
import simd

/// Real-scene regression: paired presentations of one low-SPP trace accumulation
/// versus independent high-SPP references along the same camera trajectory.
func validateSceneMotion(scene:SceneData,device:MTLDevice,folder:URL,width:Int,height:Int,frames:Int,samples:Int,referenceSamples:Int,nightOnly:Bool = false,location:ArchitectureLocation = .paris,regularization:Bool = true,lowDiscrepancySampling:Bool = true,indexedLighting:Bool = true,caseName:String? = nil) throws {
    let reconstructed = try MetalRenderer(scene:scene,device:device)
    let reference = try MetalRenderer(scene:scene,device:device)
    let spatialOnly = try MetalRenderer(scene:scene,device:device)
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    var reports:[[String:Any]] = []
    var failures:[String] = []
    let cases: [(view: Int, night: Bool, tag: String)] = location == .paris ? [
        (0, false, "overview"), (2, false, "iron"), (0, true, "night-silhouette"),
        (8, false, "river-day"), (8, true, "river-night")
    ] : location == .chicago ? [(0,false,"willis-overview"),(2,false,"willis-facade"),(0,true,"willis-night"),(7,false,"chicago-river"),(7,true,"chicago-river-night")] : location == .lakefront ? [
        (3,false,"hancock-braces"),(1,false,"historic-water-tower"),(4,true,"buckingham-night"),
        (6,false,"harbor-reflections"),(7,true,"lakefront-traffic-night")
    ] : location == .campus ? [
        (1,false,"field-hall"),(2,false,"shedd-tanks"),(3,false,"adler-gallery"),
        (4,false,"planetarium-show"),(6,true,"burnham-harbor-night"),(7,true,"mccormick-night")
    ] : [
        (1,false,"cloud-gate-idle"),(1,false,"cloud-gate-orbit"),(1,true,"cloud-gate-night"),
        (2,false,"beneath-cloud-gate"),(2,true,"beneath-cloud-gate-night")]
    let selected=cases.filter { (!nightOnly || $0.night) && (caseName == nil || $0.tag == caseName) }
    guard !selected.isEmpty else { throw EngineError.message("No matching motion case. Available cases: "+cases.map{$0.tag}.joined(separator:", ")) }
    for test in selected {
        let view = test.view, night = test.night
        let silhouette = location == .paris && night && view == 0
        reconstructed.frameSeed=0; reference.frameSeed=0; spatialOnly.frameSeed=0
        let rawOptions = RenderOptions(lighting:night ? 2 : 0,denoising:false,regularization:regularization,lowDiscrepancySampling:lowDiscrepancySampling,indexedLighting:indexedLighting), filteredOptions = RenderOptions(lighting:night ? 2 : 0,regularization:regularization,lowDiscrepancySampling:lowDiscrepancySampling,indexedLighting:indexedLighting)
        // Keep independent reference paths identical across sampling-mode
        // comparisons. Only the low-SPP stream changes when --random-sampling
        // is selected; the high-SPP ground truth always uses the Sobol sequence.
        var referenceOptions=rawOptions
        referenceOptions.lowDiscrepancySampling=true
        var skyError = 0.0, skyCompared = 0, darkCityError = 0.0, darkCityCompared = 0
        var rawDarkCityError = 0.0, maximumUnsupportedBrightness = 0.0, maximumTemporalExcess = 0.0
        var rawError = 0.0, filteredError = 0.0, rawFlicker = 0.0, filteredFlicker = 0.0
        var compared = 0, flickerCompared = 0, previousRaw:[Float] = [], previousFiltered:[Float] = []
        var gpuTimes:[Double] = []
        let tag = test.tag
        for frame in 0..<frames {
            try autoreleasepool {
                // Slow overview pivot; closer detail pan advances along its authored route.
                let campusOffsets: [Int:Double] = [1:80,2:79,3:64,4:40,6:20,7:139]
                let time = location == .campus ? (campusOffsets[view] ?? 0)+Double(frame)/30*3 : view == 0 ? Double(frame)/30*8 : 5+Double(frame)/30*3
                let pose = test.tag == "cloud-gate-idle" ? location.idlePose(view:view,seconds:Double(frame)/30) : silhouette ? location.pose(view:0,seconds:Double(frame)/24) : view == 8 ? location.pose(view:view,seconds:16+Double(frame)/24) : view == 0 ? location.idlePose(view:view,seconds:time) : location.pose(view:view,seconds:time)
                let sceneTime = test.tag == "cloud-gate-idle" ? Double(frame)/30 : silhouette ? Double(frame)/24 : view == 8 ? 16+Double(frame)/24 : time
                for renderer in [reconstructed,reference,spatialOnly] { renderer.setSceneTime(sceneTime) }
                let pair = try reconstructed.renderPreviewComparisonOffscreen(pose:pose,options:filteredOptions,width:width,height:height,samples:max(1,samples),resetHistory:frame==0)
                let a=pair.raw,b=pair.reconstructed
                let spatial = silhouette ? try spatialOnly.renderPreviewOffscreen(pose:pose,options:filteredOptions,width:width,height:height,samples:max(1,samples),resetHistory:true) : nil
                gpuTimes.append(reconstructed.lastGPUTime)
                let truth = try reference.renderOffscreen(pose:pose,options:referenceOptions,width:width,height:height,samples:referenceSamples)
                let av = [UInt8](a), bv = [UInt8](b), tv = [UInt8](truth)
                let sv = spatial.map{[UInt8]($0)}
                var ra=[Float](repeating:0,count:width*height*3), rb=ra
                var pixel=0
                for i in stride(from:0,to:av.count,by:4) {
                    for c in 0..<3 {
                        let ea=Float(Int(av[i+c])-Int(tv[i+c]))/255, eb=Float(Int(bv[i+c])-Int(tv[i+c]))/255
                        ra[pixel]=ea; rb[pixel]=eb
                        let x = (i/4)%width, y = (i/4)/width
                        // Clear sky to the right of the spire: the earlier mixed-
                        // coverage reprojection produced bright horizontal trails here.
                        if silhouette && frame >= frames/2 && x > width*57/100 && x < width*70/100 && y > height*8/100 && y < height*42/100 {
                            skyError += Double(eb*eb); skyCompared += 1
                        }
                        if silhouette && frame >= frames/2 && x > width*56/100 && x < width*70/100 && y > height*58/100 && y < height*66/100 && max(tv[i],max(tv[i+1],tv[i+2])) < 32 {
                            darkCityError += Double(eb*eb); darkCityCompared += 1
                            rawDarkCityError += Double(ea*ea)
                            let unsupported = Double(Int(bv[i+c])-max(Int(av[i+c]),Int(tv[i+c])))/255
                            maximumUnsupportedBrightness=max(maximumUnsupportedBrightness,unsupported)
                            if let sv {
                                let temporalExcess=Double(Int(bv[i+c])-max(Int(sv[i+c]),max(Int(av[i+c]),Int(tv[i+c]))))/255
                                maximumTemporalExcess=max(maximumTemporalExcess,temporalExcess)
                            }
                        }
                        if frame >= frames/2 {
                            rawError += Double(ea*ea); filteredError += Double(eb*eb); compared += 1
                            if !previousRaw.isEmpty {
                                let da=ea-previousRaw[pixel], db=eb-previousFiltered[pixel]
                                rawFlicker += Double(da*da); filteredFlicker += Double(db*db); flickerCompared += 1
                            }
                        }
                        pixel += 1
                    }
                }
                previousRaw=ra; previousFiltered=rb
                if frame == frames-1 {
                    try writePNG(a,width:width,height:height,to:folder.appendingPathComponent(tag+"-raw.png"))
                    try writePNG(b,width:width,height:height,to:folder.appendingPathComponent(tag+"-reconstructed.png"))
                    try writePNG(truth,width:width,height:height,to:folder.appendingPathComponent(tag+"-reference.png"))
                    if let spatial { try writePNG(spatial,width:width,height:height,to:folder.appendingPathComponent(tag+"-spatial-only.png")) }
                }
            }
            if frame % 16 == 0 { print("Motion validation \(tag): \(frame)/\(frames)"); fflush(stdout) }
        }
        let rawRMS=sqrt(rawError/Double(compared)), filteredRMS=sqrt(filteredError/Double(compared))
        let rawTemporal=sqrt(rawFlicker/Double(flickerCompared)), filteredTemporal=sqrt(filteredFlicker/Double(flickerCompared))
        let report:[String:Any] = ["view":tag,"frames":frames,"resolution":[width,height],"samplesPerFrame":samples,"referenceSamples":referenceSamples,"rawRMSE":rawRMS,"reconstructedRMSE":filteredRMS,"rawTemporalResidualRMSE":rawTemporal,"reconstructedTemporalResidualRMSE":filteredTemporal,"temporalNoiseReductionPercent":100*(1-filteredTemporal/rawTemporal),"imageErrorReductionPercent":100*(1-filteredRMS/rawRMS),"meanReconstructedGPUms":gpuTimes.reduce(0,+)/Double(gpuTimes.count),"darkCityRMSE":darkCityCompared > 0 ? sqrt(darkCityError/Double(darkCityCompared)) as Any : NSNull(),"clearSkyRMSE":skyCompared > 0 ? sqrt(skyError/Double(skyCompared)) as Any : NSNull()]
        var detailed=report
        detailed["rawDarkCityRMSE"]=darkCityCompared>0 ? sqrt(rawDarkCityError/Double(darkCityCompared)) as Any:NSNull()
        detailed["maximumUnsupportedDarkBrightness"]=silhouette ? maximumUnsupportedBrightness as Any:NSNull()
        detailed["maximumUnsupportedTemporalBrightness"]=silhouette ? maximumTemporalExcess as Any:NSNull()
        detailed["darkCitySamples"]=darkCityCompared
        reports.append(detailed)
        print(String(format:"\(tag): RMS %.5f → %.5f, temporal residual %.5f → %.5f (%.1f%% reduction)",rawRMS,filteredRMS,rawTemporal,filteredTemporal,100*(1-filteredTemporal/rawTemporal))); fflush(stdout)
        if silhouette {
            let city=sqrt(darkCityError/Double(max(1,darkCityCompared))), sky=sqrt(skyError/Double(max(1,skyCompared)))
            let rawCity=sqrt(rawDarkCityError/Double(max(1,darkCityCompared)))
            print(String(format:"Night regions: dark city %.6f → %.6f, clear sky %.6f; maximum unsupported temporal brightness %.6f",rawCity,city,sky,maximumTemporalExcess))
            // Mapped facades add real subpixel window coverage to this region.
            // Separate its Monte Carlo error from brightness introduced solely
            // by temporal history, using matching-seed spatial-only output.
            if darkCityCompared<1000 || city>=rawCity { failures.append("Dark city reconstruction failed to improve matched raw image error") }
            if maximumTemporalExcess>0.10 { failures.append("Unsupported bright temporal history survived over dark city") }
            if sky >= 0.004 { failures.append("Bright silhouette left a stale trail in the night sky") }
        }
        if filteredRMS >= rawRMS || filteredTemporal >= rawTemporal { failures.append("Actual-scene reconstruction regressed on \(tag)") }
    }
    let data:[String:Any] = ["device":device.name,"location":location.rawValue,"pathRegularization":regularization,"indexedLighting":indexedLighting,"referenceSampling":"Independent Fast Owen-scrambled Sobol paths, identical across sampling-mode comparisons","sampling":lowDiscrepancySampling ? "Fast Owen-scrambled Sobol" : "Independent hash RNG","glossyHistory":"View-angle change bounded by 0.1 GGX alpha; fast changes retain two-frame safeguard, slow compatible glossy history at most 16 frames.","passed":failures.isEmpty,"failures":failures,"pairing":"Raw and reconstructed presentations share one trace accumulation, acceleration structure and scene-time update; the high-SPP reference remains independent.","timingIncludes":"Trace, reconstruction and both paired presentations; this is validation cost, not normal preview frame time.","rawPresentation":"Unfiltered radiance followed only by exposure, tone mapping and sRGB encoding; no legacy preview filter.","measurement":"Display-space RGB RMSE against independent high-sample references; second half of each moving sequence. Temporal residual is consecutive error difference, with reference motion subtracted, not raw image difference.","scenes":reports]
    try JSONSerialization.data(withJSONObject:data,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("metrics.json"))
    if !failures.isEmpty { throw EngineError.message(failures.joined(separator:"; ")) }
}
