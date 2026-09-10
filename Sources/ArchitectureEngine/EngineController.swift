import Foundation
import AppKit
import MetalKit
import SwiftUI
import simd

enum ArchitectureRendererMode: String, CaseIterable, Identifiable {
    case pathTracing, directRayTracing, raster
    var id: String { rawValue }
    var title: String {
        switch self { case .pathTracing: return "Path Tracing"; case .directRayTracing: return "Direct Ray Tracing"; case .raster: return "Fast Raster" }
    }
    var next: Self {
        switch self { case .pathTracing: return .directRayTracing; case .directRayTracing: return .raster; case .raster: return .pathTracing }
    }
    var explanation: String {
        switch self {
        case .pathTracing: return "Multi-bounce reflections, shadows and indirect lighting. Still views progressively refine."
        case .directRayTracing: return "Deterministic rays for hard shadows and reflections, with an ambient-light approximation instead of multi-bounce indirect lighting."
        case .raster: return "Fast direct lighting and environment reflections. Local reflections, refraction, traced shadows and indirect lighting are omitted."
        }
    }
}

@MainActor protocol ViewportInputResetting: AnyObject {
    func cancelViewportInput()
}

@MainActor final class EngineController: ObservableObject {
    @Published var status = "Preparing Willis Tower and Chicago…"
    @Published private(set) var location: ArchitectureLocation = .chicago
    @Published var isFullscreen = false
    @Published var isReady = false
    @Published var errorMessage: String?
    @Published var fps = 0.0
    @Published var gpuMilliseconds = 0.0
    @Published var samples = 0
    @Published var triangleCount = 0
    @Published var memoryMB = 0.0
    @Published var deviceName = "Apple Silicon"
    @Published var tourPlaying = false
    @Published private(set) var chicagoDemoActive = false
    @Published private(set) var chicagoDemoTitle = ""
    @Published private(set) var focusedObjectName: String?
    @Published var tourProgress = 0.0
    @Published var playbackSpeed = 1.0
    @Published var idleSpeed = 1.0
    @Published var idleCycling = true
    @Published var idleSecondsRemaining = WalkthroughPlayback.idleViewDuration
    @Published var playbackState: WalkthroughPlayback.State = .idle
    @Published var transportLabel = "Idle drift"
    @Published var playbackSeconds = 0.0
    @Published var currentStop = 0
    @Published var quality = 1
    @Published var lighting = 0
    @Published private(set) var sunsetBuildingLights = true
    @Published var exposure = 1.0
    @Published private(set) var navigationMode = 1
    @Published private(set) var mapViewSpan: Float = 1800
    var isMapMode: Bool { navigationMode == 2 }
    var cameraPose: CameraPose { pose }
    private var mapEntryHeading = SIMD3<Float>(0,0,-1)
    private var lastHorizontalHeading = SIMD3<Float>(0,0,-1)
    @Published private(set) var flySpeed = ManualCityNavigation.defaultFlySpeed
    @Published private(set) var rendererMode: ArchitectureRendererMode = .pathTracing
    var rayTracingEnabled: Bool { rendererMode != .raster }
    @Published private(set) var mapSelectionRevision = 0
    @Published var navigationMapVisible = true
    @Published var navigationMapSize: ChicagoMapSize = .small
    @Published private(set) var mapCamera = ChicagoMapCamera(position: SIMD2(230,275), target: SIMD2(0,0))
    @Published var showHelp = false {
        didSet {
            if showHelp { keys.removeAll(); (view as? ViewportInputResetting)?.cancelViewportInput() }
        }
    }
    @Published var statsVisible = true
    @Published var altitude: Float = 0
    private var renderer: MetalRenderer?
    private var collision: CollisionWorld?
    private var focusCatalog: LandmarkFocusCatalog?
    private var focusSelection = FocusSelection()
    private var movingWindow = false
    private weak var view: MTKView?
    private var delegate: ViewDelegate?
    private var keys = Set<UInt16>()
    private var flightScroll: Float = 0
    let music = AmbientMusicController()
    private var pose = CameraPose(position: SIMD3(230,105,275),target:SIMD3(0,141,0))
    private var previousTime = CACurrentMediaTime()
    private var lastStats = 0.0
    private var frameTimes: [Double] = []
    private var dirty = true
    private var historyDirty = true
    private var playback = WalkthroughPlayback(location: .chicago)
    private let sceneQueue = DispatchQueue(label: "Atelier.scene-loading", qos: .userInitiated)
    private var loadGeneration = 0
    private var captured = false
    private var sceneSeconds = 0.0
    private var loaded = false
    var stops: [TourStop] { location.stops }
    var walkthroughDuration: Double { playback.duration }
    var timeLabel: String { String(format: "%02d:%02d / %02d:%02d", Int(playbackSeconds) / 60, Int(playbackSeconds) % 60, Int(walkthroughDuration) / 60, Int(walkthroughDuration) % 60) }

    func attach(view: MTKView) {
        StartupMetrics.shared.mark("viewAttachedSeconds")
        self.view = view
        guard !loaded else { return }; loaded = true
        guard let device = MTLCreateSystemDefaultDevice() else { errorMessage = "No Metal GPU is available."; return }
        deviceName = device.name
        view.device = device; view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true; view.preferredFramesPerSecond = 60
        let delegate = ViewDelegate(controller:self); self.delegate = delegate; view.delegate = delegate
        view.autoResizeDrawable = true
        loadLocation(location, device: device)
    }
    func selectLocation(_ value: ArchitectureLocation) {
        guard !isMapMode, let device = view?.device else { return }
        if value == location {
            if playback.demoActive {
                playback.selectLocation(value)
                applyViewSelection(); synchronizePlayback(); previousTime = CACurrentMediaTime()
                focusViewport()
            }
            return
        }
        if isReady && location.world == value.world {
            // The park and tower are bookmarks in the same world. Keep the GPU
            // scene resident, changing only the camera and its playback clock.
            location = value; playback.selectLocation(value); lighting = playback.effectiveLighting
            applyViewSelection(); synchronizePlayback(); previousTime = CACurrentMediaTime()
            view?.window?.title = "ATELIER / \(value.name)"; focusViewport()
            return
        }
        loadLocation(value, device: device)
    }
    func toggleLocation() {
        let locations = playback.demoActive ? WalkthroughPlayback.chicagoDemoLocations : ArchitectureLocation.allCases
        selectLocation(locations[(locations.firstIndex(of: location)! + 1) % locations.count])
    }
    func toggleChicagoDemo() {
        guard isReady, !isMapMode, let device = view?.device else { return }
        clearObjectFocus()
        keys.removeAll()
        if playback.demoActive {
            playback.stopChicagoDemo()
        } else {
            let selectedLighting = location.world == "chicago" ? playback.lighting : lighting
            if location.world != "chicago" { loadLocation(.chicago, device: device) }
            playback.setLighting(selectedLighting)
            playback.startChicagoDemo()
            lighting = playback.effectiveLighting
            location = playback.location
            applyViewSelection()
            view?.window?.title = "ATELIER / \(location.name)"
        }
        synchronizePlayback(); previousTime = CACurrentMediaTime()
        dirty = true; focusViewport()
    }
    func startChicagoFlyby() {
        startConnectingFlight(to: .millennium, view: MillenniumWalkthrough.flybyView)
    }
    func startMuseumCampusFlyby() {
        startConnectingFlight(to: .campus, view: MuseumCampusWalkthrough.flybyView)
    }
    func startNorthSideFlyby(toWrigley: Bool = false) {
        startConnectingFlight(to: .northside, view: toWrigley ? NorthSideWalkthrough.wrigleyFlybyView : NorthSideWalkthrough.zooFlybyView)
    }
    func startRobieFlyby() {
        startConnectingFlight(to: .robie, view: RobieWalkthrough.flybyView)
    }
    func startNavyPierFlyby() { startConnectingFlight(to:.navypier,view:NavyPierWalkthrough.flybyView) }
    func startCulturalCenterFlyby() { startConnectingFlight(to:.culturalcenter,view:7) }
    private func startConnectingFlight(to destination: ArchitectureLocation, view index: Int) {
        guard isReady, !isMapMode, location.world == "chicago" else { return }
        let selectedLighting = lighting
        selectLocation(destination); selectStop(index)
        setLighting(selectedLighting)
        if playback.state != .playing { toggleTour() }
    }
    private func loadLocation(_ selected: ArchitectureLocation, device: MTLDevice) {
        loadGeneration += 1
        let generation = loadGeneration
        let previousRenderer = renderer
        // Main-thread drawing stops before the previous GPU queue is drained.
        isReady = false; view?.isPaused = true; keys.removeAll()
        previousRenderer?.waitUntilIdle()
        renderer = nil; collision = nil; focusCatalog = nil; clearObjectFocus(); errorMessage = nil
        location = selected; playback.selectLocation(selected)
        lighting = playback.effectiveLighting; applyViewSelection(); synchronizePlayback()
        status = "Preparing \(selected.name) and \(selected.shortName)…"
        view?.window?.title = "ATELIER / \(selected.name)"
        triangleCount = 0; memoryMB = 0; samples = 0; fps = 0
        frameTimes.removeAll()
        sceneQueue.async { [weak self] in
            // The serial loader avoids concurrent multi-million-triangle builds.
            // Superseded requests are skipped before allocating a new scene.
            let current = DispatchQueue.main.sync { self?.loadGeneration == generation }
            guard current else { return }
            do {
                let preparationStart=CACurrentMediaTime()
                StartupMetrics.shared.mark("preparationStartedSeconds")
                let cache: CityCacheContext?
                do { cache=try CityCache.context(world:selected.world) }
                catch { cache=nil; StartupMetrics.shared.set("cacheSetupError",error.localizedDescription) }
                let cachedScene=cache.flatMap { $0.forceRebuild ? nil:CityCache.loadScene(from:$0.sceneURL,key:$0.key) }
                let scene = cachedScene ?? selected.build()
                StartupMetrics.shared.set("sceneCacheHit",cachedScene != nil)
                StartupMetrics.shared.set("scenePreparationSeconds",CACurrentMediaTime()-preparationStart)
                let rendererStart=CACurrentMediaTime()
                guard DispatchQueue.main.sync(execute: { self?.loadGeneration == generation }) else { return }
                let nextRenderer = try MetalRenderer(scene:scene,device:device,cacheDirectory:cache?.directory,cacheKey:cache?.key ?? "",forceRebuildCache:cache?.forceRebuild ?? false)
                StartupMetrics.shared.set("rendererPreparationSeconds",CACurrentMediaTime()-rendererStart)
                StartupMetrics.shared.set("rendererPhases",nextRenderer.startupPhaseSeconds)
                StartupMetrics.shared.set("rendererCaches",nextRenderer.startupCacheStatistics)
                let focusStart=CACurrentMediaTime()
                let nextFocusCatalog = LandmarkFocusCatalog(world: selected.world)
                StartupMetrics.shared.set("focusPreparationSeconds",CACurrentMediaTime()-focusStart)
                let denseRegions = nextFocusCatalog.authored.filter { $0.id == "chicago:cloud-gate" }.map {
                    CollisionWorld.PickingRegion(minimum: $0.bounds.minimum, maximum: $0.bounds.maximum)
                }
                let collisionStart=CACurrentMediaTime()
                let cachedCollision=cache.flatMap { $0.forceRebuild ? nil:CollisionWorld.loadCache(from:$0.collisionURL,cacheKey:$0.key,detailedPickingRegions:denseRegions,expectedSceneTriangleCount:scene.triangleCount) }
                let nextCollision = cachedCollision ?? CollisionWorld(scene:scene,detailedPickingRegions:denseRegions)
                StartupMetrics.shared.set("collisionCacheHit",cachedCollision != nil)
                StartupMetrics.shared.set("collisionPreparationSeconds",CACurrentMediaTime()-collisionStart)
                StartupMetrics.shared.set("world",selected.world)
                StartupMetrics.shared.set("staticTriangles",scene.triangleCount)
                StartupMetrics.shared.set("cacheMode",cache == nil ? "disabled":(cache!.forceRebuild ? "rebuild":"automatic"))
                // Misses are saved after the first visible-city submission, so
                // first-time persistence does not extend the loading screen.
                let persistence: (() -> String?)?
                if let cache, cachedScene == nil || cachedCollision == nil {
                    persistence = {
                        do {
                            if cachedScene == nil { try CityCache.writeScene(scene,to:cache.sceneURL,key:cache.key) }
                            if cachedCollision == nil { try nextCollision.writeCache(to:cache.collisionURL,cacheKey:cache.key,detailedPickingRegions:denseRegions) }
                            return nil
                        } catch { return error.localizedDescription }
                    }
                } else { persistence=nil }
                nextRenderer.firstPresentationHandler = { time, exact in
                    StartupMetrics.shared.presented(at:time,exactTimestamp:exact,afterPresentation:persistence)
                }
                DispatchQueue.main.async {
                    guard let self, self.loadGeneration == generation else { return }
                    self.renderer = nextRenderer; self.collision = nextCollision; self.focusCatalog = nextFocusCatalog
                    self.triangleCount = nextRenderer.triangleCount
                    self.memoryMB = nextRenderer.allocatedMB
                    self.status = "Hardware ray tracing ready"
                    StartupMetrics.shared.set("renderer",self.rendererMode.rawValue)
                    StartupMetrics.shared.set("quality",["responsive","balanced","maximum"][max(0,min(2,self.quality))])
                    StartupMetrics.shared.mark("cityReadySeconds")
                    StartupMetrics.shared.set("drawableSize",[self.view?.drawableSize.width ?? 0,self.view?.drawableSize.height ?? 0])
                    self.isReady = true; self.applyViewSelection()
                    self.previousTime = CACurrentMediaTime(); self.synchronizePlayback()
                    self.view?.isPaused = false; self.focusViewport()
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, self.loadGeneration == generation else { return }
                    self.errorMessage = error.localizedDescription
                    self.status = "Renderer could not start"
                }
            }
        }
    }
    func toggleFullscreen() {
        keys.removeAll(); (view as? ViewportInputResetting)?.cancelViewportInput()
        previousTime = CACurrentMediaTime()
        view?.window?.toggleFullScreen(nil); focusViewport()
    }
    func windowPresentationChanged() { isFullscreen = view?.window?.styleMask.contains(.fullScreen) ?? false }
    func windowWillMove() {
        // Native titlebar dragging runs its own event tracking loop. Hold both
        // camera and scene clocks until the mouse is released, then resume exactly.
        movingWindow = true; keys.removeAll(); previousTime = CACurrentMediaTime()
    }
    func drawableSizeDidChange(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
        dirty = true; historyDirty = true
        previousTime = CACurrentMediaTime()
    }
    var options: RenderOptions { RenderOptions(exposure:Float(exposure),bounces:quality == 0 ? 2 : (quality == 2 ? 5 : 3),lighting:lighting,sunsetBuildingLights:sunsetBuildingLights,rayTracing:rayTracingEnabled,directRayTracing:rendererMode == .directRayTracing,hazeDensity:isMapMode ? 0.0000001:location.hazeDensity(view:currentStop)) }
    func setRendererMode(_ mode: ArchitectureRendererMode) {
        guard isReady, mode != rendererMode else { return }
        rendererMode = mode
        dirty = true; historyDirty = true; samples = 0
        status = "\(mode.title) enabled"
        previousTime = CACurrentMediaTime(); focusViewport()
    }
    func cycleRenderer() { setRendererMode(rendererMode.next) }
    func setSunsetBuildingLights(_ enabled: Bool) {
        guard sunsetBuildingLights != enabled else { return }
        sunsetBuildingLights = enabled
        if lighting == 3 { dirty = true; historyDirty = true; samples = 0 }
    }
    func toggleNavigationMap() { navigationMapVisible.toggle(); focusViewport() }
    func setFlySpeed(_ value: Float) {
        guard value.isFinite else { return }
        flySpeed = ManualCityNavigation.nearestSpeed(value)
    }
    func stepFlySpeed(_ direction: Int) { setFlySpeed(ManualCityNavigation.steppedSpeed(flySpeed,direction:direction)); focusViewport() }
    private func roofHeight(_ x: Float, _ z: Float) -> Float {
        guard let hit = collision?.distance(origin:SIMD3(x,1500,z),direction:SIMD3(0,-1,0),maximum:1600) else { return 0 }
        return 1500-hit
    }
    private func publishCamera() {
        mapCamera = ChicagoMapCamera(position:SIMD2(pose.position.x,pose.position.z),target:SIMD2(pose.target.x,pose.target.z))
        altitude = pose.position.y; dirty = true
    }
    private func applyMapPose(center: SIMD2<Float>) {
        guard let next = ManualCityNavigation.mapPose(center:center,span:mapViewSpan) else { return }
        pose = next; publishCamera(); previousTime = CACurrentMediaTime()
    }
    func toggleMapMode() { setNavigationMode(isMapMode ? 1:2) }
    /// A normal-camera shortcut, independent of the restricted Map mode.
    func pointCameraDown() {
        guard isReady, !isMapMode, !showHelp, !movingWindow else { return }
        lastHorizontalHeading=ManualCityNavigation.horizontalHeading(forward:pose.target-pose.position,fallback:lastHorizontalHeading)
        guard let next=ManualCityNavigation.topDown(pose:pose,center:focusSelection.orbit?.focus.center,roof:roofHeight) else { return }
        beginManualNavigation(keepingFocus:true);keys.removeAll();navigationMode=1
        pose=next
        if let focus=focusSelection.orbit?.focus { _ = focusSelection.choose(focus,pose:next) }
        (view as? ViewportInputResetting)?.cancelViewportInput()
        publishCamera();historyDirty=true;previousTime=CACurrentMediaTime();focusViewport()
    }
    func setNavigationMode(_ value: Int) {
        guard isReady, (0...2).contains(value), value != navigationMode else { return }
        if value == 2 {
            guard location.world == "chicago" else { return }
            mapEntryHeading = pose.target-pose.position
            let center = simd_clamp(SIMD2(pose.target.x,pose.target.z),ChicagoMapProjection.worldMinimum,ChicagoMapProjection.worldMaximum)
            mapViewSpan = max(1800,min(12_000,simd_distance(pose.position,pose.target)*tan(pose.fov * .pi/360)*2))
            beginManualNavigation(); keys.removeAll(); navigationMode = 2
            (view as? ViewportInputResetting)?.cancelViewportInput()
            applyMapPose(center:center); mapSelectionRevision &+= 1
        } else {
            if isMapMode {
                let center = SIMD2(pose.target.x,pose.target.z)
                guard let destination = ManualCityNavigation.overview(point:center,heading:mapEntryHeading,roof:roofHeight) else { return }
                navigationMode = 1
                adoptCityDestination(point:center,destination:destination,mapMode:false)
            }
            beginManualNavigation(); keys.removeAll(); navigationMode = value
            if navigationMode == 0, let distance = collision?.distance(origin:pose.position+SIMD3(0,0.3,0),direction:SIMD3(0,-1,0),maximum:1500) {
                let shift = SIMD3<Float>(0,0.3-distance+1.75,0)
                pose.position += shift; pose.target += shift
            }
            publishCamera()
        }
        (view as? ViewportInputResetting)?.cancelViewportInput()
        dirty = true; historyDirty = true; focusViewport()
    }
    func zoomMap(_ inward: Bool) { magnify(inward ? 0.25:-0.2) }
    func magnify(_ magnification: Double) {
        guard isReady, !showHelp, !movingWindow, abs(magnification)>0.0000001,
              let zoom = ManualCityNavigation.pinchLogScale(magnification:magnification) else { return }
        beginManualNavigation(keepingFocus:true); keys.removeAll()
        if isMapMode {
            guard let span = ManualCityNavigation.pinchMapSpan(mapViewSpan,magnification:magnification) else { return }
            mapViewSpan = span; applyMapPose(center:SIMD2(pose.target.x,pose.target.z))
        } else if var orbit = focusSelection.orbit {
            orbit.dolly(logScale:-zoom); focusSelection.orbit = orbit; pose = orbit.pose
        } else if let fov = ManualCityNavigation.pinchFOV(pose.fov,magnification:magnification) { pose.fov = fov }
        publishCamera(); previousTime = CACurrentMediaTime()
    }
    func navigateCity(to landmark: ChicagoMapLandmark) {
        guard isReady, !showHelp, !movingWindow, location.world == "chicago" else { return }
        if isMapMode {
            mapViewSpan = max(100,min(24_000,landmark.framingRadius*3))
            guard let destination = ManualCityNavigation.mapPose(center:landmark.point,span:mapViewSpan) else { return }
            adoptCityDestination(point:landmark.point,destination:destination,mapMode:true)
        } else {
            let aspect = Float((view?.bounds.width ?? 1440)/max(1,view?.bounds.height ?? 960))
            guard let destination = ManualCityNavigation.landmarkOverview(target:landmark.target,radius:landmark.framingRadius,
                heading:pose.target-pose.position,aspect:aspect,roof:roofHeight) else { return }
            adoptCityDestination(point:landmark.point,destination:destination,mapMode:false)
        }
        let authored = landmark.focusID.flatMap { id in
            focusCatalog?.lookup(id:id) ?? LandmarkFocusCatalog(world:"chicago",includeMapped:false).lookup(id:id)
        }
        if let focus=authored ?? LandmarkFocusCatalog.semanticTarget(center:landmark.target,radius:landmark.framingRadius,name:landmark.name,id:"map:"+landmark.id) {
            let focusedPose=focusSelection.choose(focus,pose:pose)
            if !isMapMode { pose=focusedPose }
            synchronizeFocus();publishCamera()
        }
    }
    func navigateCity(to point: SIMD2<Float>) {
        guard isReady, !showHelp, !movingWindow, location.world == "chicago", point.x.isFinite, point.y.isFinite,
              point.x >= -4000, point.x <= 6000, point.y >= -11500, point.y <= 11000 else { return }
        let destination: CameraPose?
        if isMapMode { destination = ManualCityNavigation.mapPose(center:point,span:mapViewSpan) }
        else { destination = ManualCityNavigation.overview(point:point,heading:pose.target-pose.position,roof:roofHeight) }
        guard let destination else { return }
        adoptCityDestination(point:point,destination:destination,mapMode:isMapMode)
    }
    private func adoptCityDestination(point: SIMD2<Float>, destination: CameraPose, mapMode: Bool) {
        let selectedLighting = lighting
        // Internal selection updates destination metadata, then installs the
        // requested pose atomically; no intermediate route frame is rendered.
        navigationMode = 1
        // A district's opening route may start in another district (the North
        // Side opens near Millennium Park). Match every bookmark so Wrigley
        // selects its own tour, and Play starts the nearby architectural study.
        var nearestLocation = location, nearestView = currentStop
        var nearestDistance = Float.greatestFiniteMagnitude
        for candidate in WalkthroughPlayback.chicagoDemoLocations where candidate != .skyline {
            for (index, stop) in candidate.stops.enumerated() {
                let anchor = stop.pose.target
                let distance = simd_distance_squared(SIMD2(anchor.x,anchor.z),point)
                if distance < nearestDistance {
                    nearestDistance = distance; nearestLocation = candidate; nearestView = index
                }
            }
        }
        beginManualNavigation()
        if nearestLocation != location { selectLocation(nearestLocation) }
        selectStop(nearestView)
        beginManualNavigation(); setLighting(selectedLighting); keys.removeAll(); navigationMode = mapMode ? 2:1
        pose = destination
        mapCamera = ChicagoMapCamera(position:SIMD2(pose.position.x,pose.position.z),target:point)
        altitude = pose.position.y; dirty = true; historyDirty = true
        previousTime = CACurrentMediaTime(); focusViewport()
    }
    func panCityMap(_ requested: SIMD2<Float>) -> SIMD2<Float> {
        guard isReady, !showHelp, !movingWindow, location.world == "chicago" else { return .zero }
        let actual = ManualCityNavigation.mapTranslation(camera: SIMD2(pose.position.x,pose.position.z), requested: requested)
        guard simd_length_squared(actual) > 0 else { return .zero }
        let mode = navigationMode
        beginManualNavigation(keepingFocus:mode == 2); keys.removeAll(); navigationMode = mode == 2 ? 2:1
        applyCityMapTranslation(actual)
        previousTime = CACurrentMediaTime(); focusViewport()
        return actual
    }
    private func applyCityMapTranslation(_ actual: SIMD2<Float>) {
        let translation = SIMD3(actual.x,0,actual.y)
        pose.position += translation; pose.target += translation
        publishCamera()
    }
    private func applyViewSelection() {
        mapSelectionRevision &+= 1
        clearObjectFocus()
        currentStop = playback.view; pose = playback.pose; altitude = pose.position.y
        navigationMode = location.walkingViews.contains(playback.view) ? 0 : 1
        keys.removeAll(); dirty = true; historyDirty = true
    }
    func selectStop(_ index: Int) {
        guard !isMapMode, stops.indices.contains(index) else { return }
        playback.select(index); applyViewSelection(); previousTime = CACurrentMediaTime()
        synchronizePlayback(); focusViewport()
    }
    func toggleTour() {
        guard !isMapMode else { return }
        clearObjectFocus()
        let wasIdle = playback.state == .idle || playback.state == .manual
        let previousPlaybackTime = playback.time
        playback.toggle(); keys.removeAll(); previousTime = CACurrentMediaTime()
        if wasIdle || playback.time != previousPlaybackTime { historyDirty = true; pose = playback.pose }
        synchronizePlayback(); focusViewport()
        dirty = true
    }
    func cycleView(_ direction: Int) {
        guard !isMapMode else { return }
        if playback.demoActive {
            playback.navigateDemoView(offset: direction)
            location = playback.location; lighting = playback.effectiveLighting
            applyViewSelection(); synchronizePlayback(); previousTime = CACurrentMediaTime()
            view?.window?.title = "ATELIER / \(location.name)"; focusViewport()
        } else { selectStop((currentStop + direction + stops.count) % stops.count) }
    }
    func toggleIdleCycling() {
        guard !isMapMode else { return }
        clearObjectFocus()
        let enteringIdle = playback.state != .idle
        playback.toggleIdleCycling(); keys.removeAll(); previousTime = CACurrentMediaTime()
        if enteringIdle { applyViewSelection() }
        synchronizePlayback(); focusViewport()
    }
    func setIdleSpeed(_ value: Double) { playback.setIdleSpeed(value); synchronizePlayback(); focusViewport() }
    func stepIdleSpeed(_ direction: Int) { playback.stepIdleSpeed(direction); synchronizePlayback(); focusViewport() }
    func shuttle(_ direction: WalkthroughPlayback.Direction) {
        guard !isMapMode else { return }
        clearObjectFocus()
        if playback.state == .idle || playback.state == .manual { historyDirty = true }
        playback.transport(direction); pose = playback.pose; keys.removeAll()
        dirty = true; synchronizePlayback(); focusViewport()
    }
    func seekTour(_ progress: Double) {
        guard !isMapMode else { return }
        clearObjectFocus()
        playback.seek(progress: progress); pose = playback.pose; keys.removeAll()
        dirty = true; historyDirty = true; synchronizePlayback()
    }
    func setPlaybackSpeed(_ value: Double) { playback.setSpeed(value); synchronizePlayback(); focusViewport() }
    func focusViewport() { if let view { view.window?.makeFirstResponder(view) } }
    private func synchronizePlayback() {
        lighting = playback.effectiveLighting
        if !StartupMetrics.benchmark { music.selectLocation(location.rawValue) }
        chicagoDemoActive = playback.demoActive; chicagoDemoTitle = playback.demoTitle
        tourPlaying = playback.state == .playing
        playbackState = playback.state; playbackSpeed = playback.speed
        idleCycling = playback.idleCycling; idleSpeed = playback.idleSpeed
        idleSecondsRemaining = max(0, WalkthroughPlayback.idleViewDuration - playback.idleDwellTime) / playback.idleSpeed
        playbackSeconds = playback.time; tourProgress = playback.progress
        switch playback.state {
        case .idle: transportLabel = playback.idleCycling ? "Idle view cycle" : "Idle · holding view"
        case .manual: transportLabel = isMapMode ? "Map · pan and zoom":"Manual exploration"
        case .paused: transportLabel = "Paused · " + (playback.direction == .reverse ? "← " : "") + String(format: "%g×", abs(playback.effectiveRate))
        case .playing:
            let rate = String(format: "%g×", abs(playback.effectiveRate))
            transportLabel = (playback.direction == .reverse ? "Rewind " : (playback.shuttle > 1 ? "Fast forward " : "Walkthrough ")) + rate
        }
    }
    private func beginManualNavigation(keepingFocus: Bool = false) {
        if !keepingFocus { clearObjectFocus() }
        if playback.state != .manual { playback.manual(); synchronizePlayback() }
    }
    func clearObjectFocus() {
        guard focusedObjectName != nil || focusSelection.orbit != nil else { return }
        focusSelection = FocusSelection(); focusedObjectName = nil
        renderer?.focusHighlight=FocusHighlightData(volumes:[]);dirty=true
    }
    private func synchronizeFocus() {
        focusedObjectName=focusSelection.orbit?.focus.name
        let volumes=(focusSelection.orbit?.focus.volumes ?? []).map { volume in
            FocusHighlightVolume(minimum:volume.bounds.minimum,maximum:volume.bounds.maximum,
                points:volume.triangles.isEmpty ? volume.points:volume.triangles.map { volume.points[$0] },
                triangulated:!volume.triangles.isEmpty)
        }
        renderer?.focusHighlight=FocusHighlightData(volumes:volumes)
        dirty=true
    }
    func focusObject(at normalizedPoint: SIMD2<Float>, aspect: Float) {
        guard isReady, !showHelp, !movingWindow, let collision, let focusCatalog,
              let ray = FocusRay.make(normalized: normalizedPoint, aspect: aspect, pose: pose) else { return }
        var hit = focusCatalog.pick(ray: ray, world: collision)
        if let current=focusSelection.orbit?.focus,current.id.hasPrefix("map:"),
           let distance=collision.pickingDistance(origin:ray.origin,direction:ray.direction,maximum:50_000),
           current.contains(ray.origin+ray.direction*distance) { hit=current }
        beginManualNavigation(keepingFocus: true); keys.removeAll()
        let selectedPose=focusSelection.tap(hit,pose:pose)
        if !isMapMode { pose=selectedPose }
        synchronizeFocus()
        altitude = pose.position.y; dirty = true; historyDirty = true
        focusViewport()
    }
    func resetView() { selectStop(0) }
    func setQuality(_ value: Int) { quality = max(0,min(2,value)); dirty = true; historyDirty = true }
    func setLighting(_ value: Int) { playback.setLighting(value); lighting = playback.effectiveLighting; dirty = true; historyDirty = true }
    func toggleDayNight() { playback.toggleDayNight(); lighting = playback.effectiveLighting; dirty = true; historyDirty = true; focusViewport() }
    func setExposure(_ value: Double) { exposure = value; dirty = true; historyDirty = true }
    func moveKey(_ code: UInt16, pressed: Bool) {
        if pressed {
            guard isReady, !showHelp, !movingWindow else { return }
            let permitted: Set<UInt16> = isMapMode ? [13,0,1,2,56,60]:[13,0,1,2,12,14,56,60]
            guard permitted.contains(code) else { return }
            keys.insert(code)
            if [UInt16(13), 0, 1, 2, 12, 14].contains(code) { beginManualNavigation(keepingFocus:isMapMode) }
        } else { keys.remove(code) }
    }
    func look(deltaX: Float, deltaY: Float) {
        guard isReady, !isMapMode, !showHelp, !movingWindow, deltaX.isFinite, deltaY.isFinite, abs(deltaX) + abs(deltaY) > 0.01 else { return }
        beginManualNavigation(keepingFocus: true)
        if var orbit = focusSelection.orbit {
            orbit.rotate(yawDelta: -deltaX * 0.003, pitchDelta: deltaY * 0.003)
            focusSelection.orbit = orbit; pose = orbit.pose; dirty = true
            return
        }
        let direction = simd_normalize(pose.target-pose.position)
        let yaw = atan2(direction.x,-direction.z) + deltaX*0.003
        let pitch = max(-1.50,min(1.50,asin(direction.y)-deltaY*0.003))
        pose.target = pose.position + SIMD3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
        dirty = true
    }
    func pan(from: SIMD2<Float>, to: SIMD2<Float>, viewport: SIMD2<Float>) {
        guard isReady, !showHelp, !movingWindow else { return }
        if isMapMode {
            guard let delta = ManualCityNavigation.mapPan(delta:to-from,viewport:viewport,span:mapViewSpan) else { return }
            _ = panCityMap(delta); return
        }
        if focusSelection.orbit != nil { look(deltaX:to.x-from.x,deltaY:to.y-from.y); return }
        guard let delta = ManualCityNavigation.pan(pose:pose,from:from,to:to,viewport:viewport) else { return }
        beginManualNavigation(); navigationMode = 1
        pose.position += delta; pose.target += delta; dirty = true
    }
    func scroll(_ amount: Float, precise: Bool = false) {
        guard isReady, !showHelp, !movingWindow, amount.isFinite else { return }
        if isMapMode { magnify(exp(Double(amount)*(precise ? 0.005:0.10))-1); return }
        if var orbit = focusSelection.orbit {
            orbit.dolly(logScale: -amount * (precise ? 0.003 : 0.10))
            focusSelection.orbit = orbit; pose = orbit.pose; dirty = true
        } else {
            flightScroll -= amount
            let threshold: Float = precise ? 48 : 1
            if abs(flightScroll) >= threshold {
                setFlySpeed(ManualCityNavigation.steppedSpeed(flySpeed,direction:flightScroll > 0 ? 1 : -1))
                flightScroll = 0
            }
        }
    }
    func captureScreenshot() { captured = true }
    func draw(_ view: MTKView) {
        guard let renderer, isReady else { return }
        if let error = renderer.takeGPUError() {
            errorMessage = "Metal rendering failed: " + error
            view.isPaused = true
            return
        }
        let time = CACurrentMediaTime()
        if movingWindow && NSEvent.pressedMouseButtons == 0 {
            movingWindow = false; previousTime = time
        }
        let suspended = movingWindow || view.inLiveResize
        let elapsed = max(0.001,time-previousTime)
        let dt = Double(ManualCityNavigation.frameSeconds(elapsed)); previousTime = time
        frameTimes.append(elapsed); if frameTimes.count > 90 { frameTimes.removeFirst() }
        let automaticMotion = playback.state == .idle || playback.state == .playing
        let previousLocation = playback.location, previousStop = playback.view, previousLighting = playback.effectiveLighting
        if !suspended { playback.advance(min(0.5, elapsed)) }
        if playback.effectiveLighting != previousLighting { lighting = playback.effectiveLighting; dirty = true; historyDirty = true }
        if playback.location != previousLocation || playback.view != previousStop {
            // Every demo destination shares this resident Chicago scene. Adopting
            // the playback location must not restart its first route via selectLocation.
            location = playback.location
            applyViewSelection(); synchronizePlayback()
            view.window?.title = "ATELIER / \(location.name)"
        }
        if !suspended {
            if automaticMotion { pose = playback.pose; dirty = true }
            else if playback.state == .manual { updateMovement(Float(dt)) }
            switch playback.state {
            case .idle: sceneSeconds = playback.idleTime
            case .playing, .paused: sceneSeconds = playback.time
            case .manual: sceneSeconds += dt
            }
        }
        renderer.setSceneTime(sceneSeconds)
        let width = min(Int(view.drawableSize.width), quality == 0 ? 960 : (quality == 2 ? 2560 : 1440))
        do {
            if try renderer.draw(view:view,pose:pose,options:options,renderWidth:max(64,width),reset:dirty,samplesPerFrame:quality == 2 ? 8 : 4,resetHistory:historyDirty) { dirty = false; historyDirty = false }
            if captured {
                captured = false
                let folder = FileManager.default.urls(for:.picturesDirectory,in:.userDomainMask).first!.appendingPathComponent("Atelier")
                let name = "\(location.shortName)-\(Int(Date().timeIntervalSince1970)).png"
                let pixels = try renderer.renderOffscreen(pose:pose,options:options,width:1920,height:1280,samples:32)
                try writePNG(pixels,width:1920,height:1280,to:folder.appendingPathComponent(name))
                status = "Saved Pictures/Atelier/\(name)"
                dirty = true; historyDirty = true
            }
        } catch { errorMessage = error.localizedDescription }
        if time-lastStats > 0.3 {
            lastStats = time
            fps = Double(frameTimes.count) / max(0.001,frameTimes.reduce(0,+))
            gpuMilliseconds = renderer.lastGPUTime; samples = Int(renderer.sampleCount)
            memoryMB = renderer.allocatedMB; altitude = pose.position.y
            if location.world == "chicago" {
                mapCamera = ChicagoMapCamera(position:SIMD2(pose.position.x,pose.position.z),target:SIMD2(pose.target.x,pose.target.z))
            }
            synchronizePlayback()
        }
    }
    /// Advance only the manual camera. Kept independent of GPU submission so
    /// input/lifecycle tests exercise the actual held-key integration.
    func updateMovement(_ elapsed: Float) {
        guard isReady, !showHelp, !movingWindow, playback.state == .manual,
              elapsed.isFinite, elapsed > 0, !keys.isEmpty else { return }
        let dt = min(0.5,elapsed)
        if isMapMode {
            let requested = ManualCityNavigation.mapKeyboardPan(keys:keys,span:mapViewSpan,seconds:dt)
            let actual = ManualCityNavigation.mapTranslation(camera:SIMD2(pose.position.x,pose.position.z),requested:requested)
            if simd_length_squared(actual) > 0 { applyCityMapTranslation(actual) }
            return
        }
        // Walking retains short collision/support steps; flight uses elapsed
        // wall time so a slow render does not silently slow the camera too.
        if navigationMode == 0 && dt > 0.05 {
            let count = Int(ceil(dt/0.05))
            for _ in 0..<count { updateMovement(dt/Float(count)) }
            return
        }
        let f = ManualCityNavigation.horizontalHeading(forward:pose.target-pose.position,fallback:lastHorizontalHeading)
        lastHorizontalHeading=f
        let right = simd_normalize(simd_cross(f,SIMD3<Float>(0,1,0)))
        var delta = SIMD3<Float>.zero
        if keys.contains(13) { delta += f }; if keys.contains(1) { delta -= f }
        if keys.contains(0) { delta -= right }; if keys.contains(2) { delta += right }
        if navigationMode == 1 { delta.y += ManualCityNavigation.verticalDirection(keys: keys) }
        guard simd_length_squared(delta) > 0 else { return }
        delta = ManualCityNavigation.displacement(direction:delta,speed:navigationMode == 0 ? 4:flySpeed,seconds:dt,boosted:keys.contains(56) || keys.contains(60))
        var destination = pose.position + delta
        destination.y = max(1.8,destination.y)
        if navigationMode == 0 {
            // A downward support ray allows stair stepping and prevents stepping off an observation deck.
            if let distance = collision?.distance(origin:destination+SIMD3(0,0.45,0),direction:SIMD3(0,-1,0),maximum:2.8) {
                let floor = destination.y+0.45-distance
                destination.y = floor+1.75
            } else { return }
            if collision?.canMove(from:pose.position,to:destination) == false { return }
        }
        let actual = destination-pose.position
        pose.position = destination; pose.target += actual; dirty = true
    }
}

@MainActor final class ViewDelegate: NSObject, MTKViewDelegate {
    weak var controller: EngineController?
    init(controller: EngineController) { self.controller = controller }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { controller?.drawableSizeDidChange(size) }
    func draw(in view: MTKView) { controller?.draw(view) }
}
