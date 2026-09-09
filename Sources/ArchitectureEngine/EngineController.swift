import Foundation
import AppKit
import MetalKit
import SwiftUI
import simd

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
    @Published var exposure = 1.0
    @Published var navigationMode = 1
    @Published private(set) var flySpeed = ManualCityNavigation.defaultFlySpeed
    @Published private(set) var rayTracingEnabled = true
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
        guard let device = view?.device else { return }
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
        guard isReady, let device = view?.device else { return }
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
    private func startConnectingFlight(to destination: ArchitectureLocation, view index: Int) {
        guard isReady, location.world == "chicago" else { return }
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
                let scene = selected.build()
                guard DispatchQueue.main.sync(execute: { self?.loadGeneration == generation }) else { return }
                let nextRenderer = try MetalRenderer(scene: scene, device: device)
                let nextFocusCatalog = LandmarkFocusCatalog(world: selected.world)
                let denseRegions = nextFocusCatalog.authored.filter { $0.id == "chicago:cloud-gate" }.map {
                    CollisionWorld.PickingRegion(minimum: $0.bounds.minimum, maximum: $0.bounds.maximum)
                }
                let nextCollision = CollisionWorld(scene: scene, detailedPickingRegions: denseRegions)
                DispatchQueue.main.async {
                    guard let self, self.loadGeneration == generation else { return }
                    self.renderer = nextRenderer; self.collision = nextCollision; self.focusCatalog = nextFocusCatalog
                    self.triangleCount = nextRenderer.triangleCount
                    self.memoryMB = nextRenderer.allocatedMB
                    self.status = "Hardware ray tracing ready"
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
    func toggleFullscreen() { view?.window?.toggleFullScreen(nil); focusViewport() }
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
    var options: RenderOptions { RenderOptions(exposure:Float(exposure),bounces:quality == 0 ? 2 : (quality == 2 ? 5 : 3),lighting:lighting,rayTracing:rayTracingEnabled,hazeDensity:location.hazeDensity(view:currentStop)) }
    func toggleRayTracing() {
        guard isReady else { return }
        rayTracingEnabled.toggle(); dirty = true; historyDirty = true; samples = 0
        status = rayTracingEnabled ? "Ray tracing enabled" : "Fast raster rendering enabled"
        previousTime = CACurrentMediaTime(); focusViewport()
    }
    func toggleNavigationMap() { navigationMapVisible.toggle(); focusViewport() }
    func setFlySpeed(_ value: Float) {
        guard value.isFinite else { return }
        flySpeed = ManualCityNavigation.nearestSpeed(value)
    }
    func stepFlySpeed(_ direction: Int) { setFlySpeed(ManualCityNavigation.steppedSpeed(flySpeed,direction:direction)); focusViewport() }
    func setNavigationMode(_ value: Int) {
        guard isReady else { return }
        beginManualNavigation(); keys.removeAll(); navigationMode = value == 0 ? 0 : 1
        if navigationMode == 0, let distance = collision?.distance(origin:pose.position+SIMD3(0,0.3,0),direction:SIMD3(0,-1,0),maximum:1500) {
            let shift = SIMD3<Float>(0,0.3-distance+1.75,0)
            pose.position += shift; pose.target += shift
        }
        dirty = true; historyDirty = true; focusViewport()
    }
    func navigateCity(to point: SIMD2<Float>) {
        guard isReady, !showHelp, !movingWindow, location.world == "chicago", point.x.isFinite, point.y.isFinite,
              point.x >= -4000, point.x <= 6000, point.y >= -11500, point.y <= 11000 else { return }
        let selectedLighting = lighting
        let heading = pose.target-pose.position
        func roof(_ x: Float, _ z: Float) -> Float {
            guard let hit = collision?.distance(origin:SIMD3(x,1500,z),direction:SIMD3(0,-1,0),maximum:1600) else { return 0 }
            return 1500-hit
        }
        guard let destination = ManualCityNavigation.overview(point:point,heading:heading,roof:roof) else { return }
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
        beginManualNavigation(); setLighting(selectedLighting); keys.removeAll(); navigationMode = 1
        pose = destination
        mapCamera = ChicagoMapCamera(position:SIMD2(pose.position.x,pose.position.z),target:point)
        altitude = pose.position.y; dirty = true; historyDirty = true
        previousTime = CACurrentMediaTime(); focusViewport()
    }
    func panCityMap(_ requested: SIMD2<Float>) -> SIMD2<Float> {
        guard isReady, !showHelp, !movingWindow, location.world == "chicago" else { return .zero }
        let actual = ManualCityNavigation.mapTranslation(camera: SIMD2(pose.position.x,pose.position.z), requested: requested)
        guard simd_length_squared(actual) > 0 else { return .zero }
        beginManualNavigation(); keys.removeAll(); navigationMode = 1
        let translation = SIMD3(actual.x,0,actual.y)
        pose.position += translation; pose.target += translation
        mapCamera = ChicagoMapCamera(position:SIMD2(pose.position.x,pose.position.z),target:SIMD2(pose.target.x,pose.target.z))
        dirty = true; previousTime = CACurrentMediaTime(); focusViewport()
        return actual
    }
    private func applyViewSelection() {
        mapSelectionRevision &+= 1
        clearObjectFocus()
        currentStop = playback.view; pose = playback.pose; altitude = pose.position.y
        navigationMode = location.walkingViews.contains(playback.view) ? 0 : 1
        keys.removeAll(); dirty = true; historyDirty = true
    }
    func selectStop(_ index: Int) {
        guard stops.indices.contains(index) else { return }
        playback.select(index); applyViewSelection(); previousTime = CACurrentMediaTime()
        synchronizePlayback(); focusViewport()
    }
    func toggleTour() {
        clearObjectFocus()
        let wasIdle = playback.state == .idle || playback.state == .manual
        let previousPlaybackTime = playback.time
        playback.toggle(); keys.removeAll(); previousTime = CACurrentMediaTime()
        if wasIdle || playback.time != previousPlaybackTime { historyDirty = true; pose = playback.pose }
        synchronizePlayback(); focusViewport()
        dirty = true
    }
    func cycleView(_ direction: Int) {
        if playback.demoActive {
            playback.navigateDemoView(offset: direction)
            location = playback.location; lighting = playback.effectiveLighting
            applyViewSelection(); synchronizePlayback(); previousTime = CACurrentMediaTime()
            view?.window?.title = "ATELIER / \(location.name)"; focusViewport()
        } else { selectStop((currentStop + direction + stops.count) % stops.count) }
    }
    func toggleIdleCycling() {
        clearObjectFocus()
        let enteringIdle = playback.state != .idle
        playback.toggleIdleCycling(); keys.removeAll(); previousTime = CACurrentMediaTime()
        if enteringIdle { applyViewSelection() }
        synchronizePlayback(); focusViewport()
    }
    func setIdleSpeed(_ value: Double) { playback.setIdleSpeed(value); synchronizePlayback(); focusViewport() }
    func stepIdleSpeed(_ direction: Int) { playback.stepIdleSpeed(direction); synchronizePlayback(); focusViewport() }
    func shuttle(_ direction: WalkthroughPlayback.Direction) {
        clearObjectFocus()
        if playback.state == .idle || playback.state == .manual { historyDirty = true }
        playback.transport(direction); pose = playback.pose; keys.removeAll()
        dirty = true; synchronizePlayback(); focusViewport()
    }
    func seekTour(_ progress: Double) {
        clearObjectFocus()
        playback.seek(progress: progress); pose = playback.pose; keys.removeAll()
        dirty = true; historyDirty = true; synchronizePlayback()
    }
    func setPlaybackSpeed(_ value: Double) { playback.setSpeed(value); synchronizePlayback(); focusViewport() }
    func focusViewport() { if let view { view.window?.makeFirstResponder(view) } }
    private func synchronizePlayback() {
        lighting = playback.effectiveLighting
        music.selectLocation(location.rawValue)
        chicagoDemoActive = playback.demoActive; chicagoDemoTitle = playback.demoTitle
        tourPlaying = playback.state == .playing
        playbackState = playback.state; playbackSpeed = playback.speed
        idleCycling = playback.idleCycling; idleSpeed = playback.idleSpeed
        idleSecondsRemaining = max(0, WalkthroughPlayback.idleViewDuration - playback.idleDwellTime) / playback.idleSpeed
        playbackSeconds = playback.time; tourProgress = playback.progress
        switch playback.state {
        case .idle: transportLabel = playback.idleCycling ? "Idle view cycle" : "Idle · holding view"
        case .manual: transportLabel = "Manual exploration"
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
    }
    func focusObject(at normalizedPoint: SIMD2<Float>, aspect: Float) {
        guard isReady, !showHelp, !movingWindow, let collision, let focusCatalog,
              let ray = FocusRay.make(normalized: normalizedPoint, aspect: aspect, pose: pose) else { return }
        let hit = focusCatalog.pick(ray: ray, world: collision)
        beginManualNavigation(keepingFocus: true); keys.removeAll()
        focusSelection.toggle(hit, pose: pose)
        if let orbit = focusSelection.orbit { pose = orbit.pose }
        focusedObjectName = focusSelection.orbit?.focus.name
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
            keys.insert(code)
            if [UInt16(13), 0, 1, 2, 12, 14].contains(code) { beginManualNavigation() }
        } else { keys.remove(code) }
    }
    func look(deltaX: Float, deltaY: Float) {
        guard isReady, !showHelp, !movingWindow, deltaX.isFinite, deltaY.isFinite, abs(deltaX) + abs(deltaY) > 0.01 else { return }
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
        if focusSelection.orbit != nil { look(deltaX:to.x-from.x,deltaY:to.y-from.y); return }
        guard let delta = ManualCityNavigation.pan(pose:pose,from:from,to:to,viewport:viewport) else { return }
        beginManualNavigation(); navigationMode = 1
        pose.position += delta; pose.target += delta; dirty = true
    }
    func scroll(_ amount: Float, precise: Bool = false) {
        guard isReady, !showHelp, !movingWindow, amount.isFinite else { return }
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
    private func updateMovement(_ dt: Float) {
        if keys.isEmpty { return }
        // Walking retains short collision/support steps; flight uses elapsed
        // wall time so a slow render does not silently slow the camera too.
        if navigationMode == 0 && dt > 0.05 {
            let count = Int(ceil(dt/0.05))
            for _ in 0..<count { updateMovement(dt/Float(count)) }
            return
        }
        var f = simd_normalize(pose.target-pose.position)
        if navigationMode == 0 { f.y = 0; f = simd_normalize(f) }
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
