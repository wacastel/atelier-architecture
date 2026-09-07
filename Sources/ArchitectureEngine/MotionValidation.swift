import Foundation
import Metal
import simd

/// Real-scene regression: matched 4spp camera trajectories versus independent
/// 128spp references, with identical seeds for raw and reconstructed streams.
func validateSceneMotion(scene:SceneData,device:MTLDevice,folder:URL,width:Int,height:Int,frames:Int,samples:Int,referenceSamples:Int,nightOnly:Bool = false,location:ArchitectureLocation = .paris,regularization:Bool = true) throws {
    let raw = try MetalRenderer(scene:scene,device:device)
    let reconstructed = try MetalRenderer(scene:scene,device:device)
    let reference = try MetalRenderer(scene:scene,device:device)
    let spatialOnly = try MetalRenderer(scene:scene,device:device)
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    var reports:[[String:Any]] = []
    var failures:[String] = []
    let cases: [(view: Int, night: Bool, tag: String)] = location == .paris ? [
        (0, false, "overview"), (2, false, "iron"), (0, true, "night-silhouette"),
        (8, false, "river-day"), (8, true, "river-night")
    ] : [(0,false,"willis-overview"),(2,false,"willis-facade"),(0,true,"willis-night"),(7,false,"chicago-river"),(7,true,"chicago-river-night") ]
    for test in cases where !nightOnly || test.night {
        let view = test.view, night = test.night
        let silhouette = location == .paris && night && view == 0
        raw.frameSeed=0; reconstructed.frameSeed=0; reference.frameSeed=0; spatialOnly.frameSeed=0
        let rawOptions = RenderOptions(lighting:night ? 2 : 0,denoising:false,regularization:regularization), filteredOptions = RenderOptions(lighting:night ? 2 : 0,regularization:regularization)
        var skyError = 0.0, skyCompared = 0, darkCityError = 0.0, darkCityCompared = 0
        var rawDarkCityError = 0.0, maximumUnsupportedBrightness = 0.0, maximumTemporalExcess = 0.0
        var rawError = 0.0, filteredError = 0.0, rawFlicker = 0.0, filteredFlicker = 0.0
        var compared = 0, flickerCompared = 0, previousRaw:[Float] = [], previousFiltered:[Float] = []
        var gpuTimes:[Double] = []
        let tag = test.tag
        for frame in 0..<frames {
            try autoreleasepool {
                // Slow overview pivot; closer detail pan advances along its authored route.
                let time = view == 0 ? Double(frame)/30*8 : 5+Double(frame)/30*3
                let pose = silhouette ? location.pose(view:0,seconds:Double(frame)/24) : view == 8 ? location.pose(view:view,seconds:16+Double(frame)/24) : view == 0 ? location.idlePose(view:view,seconds:time) : location.pose(view:view,seconds:time)
                let a = try raw.renderPreviewOffscreen(pose:pose,options:rawOptions,width:width,height:height,samples:max(1,samples),resetHistory:frame==0)
                let b = try reconstructed.renderPreviewOffscreen(pose:pose,options:filteredOptions,width:width,height:height,samples:max(1,samples),resetHistory:frame==0)
                let spatial = silhouette ? try spatialOnly.renderPreviewOffscreen(pose:pose,options:filteredOptions,width:width,height:height,samples:max(1,samples),resetHistory:true) : nil
                gpuTimes.append(reconstructed.lastGPUTime)
                let truth = try reference.renderOffscreen(pose:pose,options:rawOptions,width:width,height:height,samples:referenceSamples)
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
    let data:[String:Any] = ["device":device.name,"location":location.rawValue,"pathRegularization":regularization,"passed":failures.isEmpty,"failures":failures,"rawPresentation":"Unfiltered radiance followed only by exposure, tone mapping and sRGB encoding; no legacy preview filter.","measurement":"Display-space RGB RMSE against independent high-sample references; second half of each moving sequence. Temporal residual is consecutive error difference, with reference motion subtracted, not raw image difference.","scenes":reports]
    try JSONSerialization.data(withJSONObject:data,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("metrics.json"))
    if !failures.isEmpty { throw EngineError.message(failures.joined(separator:"; ")) }
}
