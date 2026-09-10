import Foundation
import Metal
import QuartzCore

/// The build invokes the same cache readers, scene, navigation and renderer used
/// by the GUI. Chicago's nine locations share one prepared world.
enum CityPrecache {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--precache-city") else { return false }
        do {
            guard let choice=CityCache.argument("--precache-city"),["chicago","paris","all"].contains(choice),!CityCache.disabled else {
                throw CityCache.CacheError.invalid("Use --precache-city chicago|paris|all, without --no-city-cache.")
            }
            guard let device=MTLCreateSystemDefaultDevice() else { throw CityCache.CacheError.invalid("No Metal device is available for precaching.") }
            let activity=ProcessInfo.processInfo.beginActivity(options:[.userInitiated,.idleSystemSleepDisabled],reason:"Preparing Atelier city caches")
            defer { ProcessInfo.processInfo.endActivity(activity) }
            let start=CACurrentMediaTime()
            let locations: [ArchitectureLocation]=choice=="all" ? [.chicago,.paris]:[choice=="paris" ? .paris:.chicago]
            var reports=[[String:Any]]()
            for location in locations {
                let report=try autoreleasepool { () throws -> [String:Any] in
                    guard let cache=try CityCache.context(world:location.world) else { throw CityCache.CacheError.invalid("City cache disabled") }
                    var result:[String:Any]=["world":location.world,"cacheKey":cache.key,"directory":cache.directory.path]
                    var stage=CACurrentMediaTime()
                    let existing=cache.forceRebuild ? nil:CityCache.loadScene(from:cache.sceneURL,key:cache.key)
                    let scene=existing ?? location.build()
                    result["sceneHit"]=existing != nil
                    result["sceneLoadOrBuildSeconds"]=CACurrentMediaTime()-stage
                    if existing==nil { stage=CACurrentMediaTime();try CityCache.writeScene(scene,to:cache.sceneURL,key:cache.key);result["sceneWriteSeconds"]=CACurrentMediaTime()-stage }
                    let catalog=LandmarkFocusCatalog(world:location.world)
                    let regions=catalog.authored.filter{$0.id=="chicago:cloud-gate"}.map{CollisionWorld.PickingRegion(minimum:$0.bounds.minimum,maximum:$0.bounds.maximum)}
                    stage=CACurrentMediaTime()
                    let loadedCollision=cache.forceRebuild ? nil:CollisionWorld.loadCache(from:cache.collisionURL,cacheKey:cache.key,detailedPickingRegions:regions,expectedSceneTriangleCount:scene.triangleCount)
                    let collision=loadedCollision ?? CollisionWorld(scene:scene,detailedPickingRegions:regions)
                    result["collisionHit"]=loadedCollision != nil
                    result["collisionLoadOrBuildSeconds"]=CACurrentMediaTime()-stage
                    if loadedCollision==nil { stage=CACurrentMediaTime();try collision.writeCache(to:cache.collisionURL,cacheKey:cache.key,detailedPickingRegions:regions);result["collisionWriteSeconds"]=CACurrentMediaTime()-stage }
                    stage=CACurrentMediaTime()
                    let renderer=try MetalRenderer(scene:scene,device:device,cacheDirectory:cache.directory,cacheKey:cache.key,forceRebuildCache:cache.forceRebuild)
                    // Interactive launches tolerate cache failures. An explicit
                    // build must report them instead of promising a warm launch.
                    let cacheStats=renderer.startupCacheStatistics
                    let pipelines=cacheStats["pipelines"] as? [String:Any] ?? [:]
                    let raster=cacheStats["rasterBatches"] as? [String:Any] ?? [:]
                    let pipelineReady=(pipelines["saved"] as? Bool)==true ||
                        ((pipelines["loaded"] as? Bool)==true && (pipelines["misses"] as? Int)==0 && (pipelines["hits"] as? Int ?? 0)>0)
                    guard pipelineReady,(raster["hit"] as? Bool)==true || (raster["saved"] as? Bool)==true else {
                        throw CityCache.CacheError.invalid("Renderer caches could not be prepared. Metal: \(pipelines["error"] ?? "unavailable"). Raster: \(raster["error"] ?? "unavailable").")
                    }
                    for mode in 0..<3 {
                        let options=RenderOptions(rayTracing:mode != 2,directRayTracing:mode==1)
                        _=try renderer.renderOffscreen(pose:location.stops[0].pose,options:options,width:96,height:64,samples:1)
                    }
                    renderer.waitUntilIdle()
                    result["rendererAndWarmFramesSeconds"]=CACurrentMediaTime()-stage
                    result["rendererCaches"]=renderer.startupCacheStatistics
                    result["staticTriangles"]=scene.triangleCount
                    result["collisionTriangles"]=collision.triangles.count
                    result["collisionNodes"]=collision.nodes.count
                    result["preparedRenderers"]=["path","direct","raster"]
                    let cacheFiles=FileManager.default.enumerator(at:cache.directory,includingPropertiesForKeys:[.fileSizeKey,.isRegularFileKey])?.compactMap{$0 as? URL} ?? []
                    result["cacheBytes"]=try cacheFiles.reduce(0) { sum,url in
                        let values=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey])
                        return sum+(values.isRegularFile==true ? values.fileSize ?? 0:0)
                    }
                    result["passed"]=true
                    return result
                }
                reports.append(report)
                print("Prepared \(location.world): \(report["staticTriangles"]!) triangles")
            }
            let result:[String:Any]=["passed":true,"device":device.name,"totalSeconds":CACurrentMediaTime()-start,"worlds":reports,"scope":"Prepared CPU scene, navigation BVH, raster batches and Metal pipeline binaries; GPU buffers and acceleration structures are recreated at launch."]
            if let path=CityCache.argument("--cache-report") {
                let url=URL(fileURLWithPath:path)
                try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
                try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic)
            }
            return true
        } catch { fputs("City precache failed: \(error.localizedDescription)\n",stderr);exit(1) }
    }
}
