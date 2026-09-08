import Foundation
import AppKit
import MetalKit
import SwiftUI
import simd

@MainActor final class EngineController: ObservableObject {
    @Published var status = "Preparing Chicago North Side…"
    @Published private(set) var location: ArchitectureLocation = .northside
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
    @Published var showHelp = false
    @Published var statsVisible = true
    @Published var altitude: Float = 0
    private var renderer: MetalRenderer?
    private var collision: CollisionWorld?
    private weak var view: MTKView?
    private var delegate: ViewDelegate?
    private var keys = Set<UInt16>()
    private var pose = CameraPose(position: SIMD3(230,105,275),target:SIMD3(0,141,0))
    private var previousTime = CACurrentMediaTime()
    private var lastStats = 0.0
    private var frameTimes: [Double] = []
    private var dirty = true
    private var historyDirty = true
    private var playback = WalkthroughPlayback(location: .northside)
    private let sceneQueue = DispatchQueue(label: "Atelier.scene-loading", qos: .userInitiated)
    private var loadGeneration = 0
    private var captured = false
    private var movementSpeed: Float = 8
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
        guard value != location, let device = view?.device else { return }
        if isReady && location.world == value.world {
            // The park and tower are bookmarks in the same world. Keep the GPU
            // scene resident, changing only the camera and its playback clock.
            location = value; playback.selectLocation(value); lighting = playback.lighting
            applyViewSelection(); synchronizePlayback(); previousTime = CACurrentMediaTime()
            view?.window?.title = "ATELIER / \(value.name)"; focusViewport()
            return
        }
        loadLocation(value, device: device)
    }
    func toggleLocation() {
        let locations = ArchitectureLocation.allCases
        selectLocation(locations[(locations.firstIndex(of: location)! + 1) % locations.count])
    }
    func startChicagoFlyby() {
        guard isReady, location.world == "chicago" else { return }
        let selectedLighting = lighting
        selectLocation(.millennium); selectStop(MillenniumWalkthrough.flybyView)
        setLighting(selectedLighting); toggleTour()
    }
    func startMuseumCampusFlyby() {
        guard isReady, location.world == "chicago" else { return }
        let selectedLighting = lighting
        selectLocation(.campus); selectStop(MuseumCampusWalkthrough.flybyView)
        setLighting(selectedLighting); toggleTour()
    }
    func startNorthSideFlyby(toWrigley: Bool = false) {
        guard isReady, location.world == "chicago" else { return }
        let selectedLighting = lighting
        selectLocation(.northside)
        selectStop(toWrigley ? NorthSideWalkthrough.wrigleyFlybyView : NorthSideWalkthrough.zooFlybyView)
        setLighting(selectedLighting); toggleTour()
    }
    private func loadLocation(_ selected: ArchitectureLocation, device: MTLDevice) {
        loadGeneration += 1
        let generation = loadGeneration
        let previousRenderer = renderer
        // Main-thread drawing stops before the previous GPU queue is drained.
        isReady = false; view?.isPaused = true; keys.removeAll()
        previousRenderer?.waitUntilIdle()
        renderer = nil; collision = nil; errorMessage = nil
        location = selected; playback.selectLocation(selected)
        lighting = playback.lighting; applyViewSelection(); synchronizePlayback()
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
                let nextCollision = CollisionWorld(scene: scene)
                DispatchQueue.main.async {
                    guard let self, self.loadGeneration == generation else { return }
                    self.renderer = nextRenderer; self.collision = nextCollision
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
    func drawableSizeDidChange(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
        dirty = true; historyDirty = true
        previousTime = CACurrentMediaTime()
    }
    var options: RenderOptions { RenderOptions(exposure:Float(exposure),bounces:quality == 0 ? 2 : (quality == 2 ? 5 : 3),lighting:lighting) }
    private func applyViewSelection() {
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
        let wasIdle = playback.state == .idle || playback.state == .manual
        let previousPlaybackTime = playback.time
        playback.toggle(); keys.removeAll(); previousTime = CACurrentMediaTime()
        if wasIdle || playback.time != previousPlaybackTime { historyDirty = true; pose = playback.pose }
        synchronizePlayback(); focusViewport()
        dirty = true
    }
    func cycleView(_ direction: Int) { selectStop((currentStop + direction + stops.count) % stops.count) }
    func toggleIdleCycling() {
        let enteringIdle = playback.state != .idle
        playback.toggleIdleCycling(); keys.removeAll(); previousTime = CACurrentMediaTime()
        if enteringIdle { applyViewSelection() }
        synchronizePlayback(); focusViewport()
    }
    func setIdleSpeed(_ value: Double) { playback.setIdleSpeed(value); synchronizePlayback(); focusViewport() }
    func stepIdleSpeed(_ direction: Int) { playback.stepIdleSpeed(direction); synchronizePlayback(); focusViewport() }
    func shuttle(_ direction: WalkthroughPlayback.Direction) {
        if playback.state == .idle || playback.state == .manual { historyDirty = true }
        playback.transport(direction); pose = playback.pose; keys.removeAll()
        dirty = true; synchronizePlayback(); focusViewport()
    }
    func seekTour(_ progress: Double) {
        playback.seek(progress: progress); pose = playback.pose; keys.removeAll()
        dirty = true; historyDirty = true; synchronizePlayback()
    }
    func setPlaybackSpeed(_ value: Double) { playback.setSpeed(value); synchronizePlayback(); focusViewport() }
    func focusViewport() { if let view { view.window?.makeFirstResponder(view) } }
    private func synchronizePlayback() {
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
    private func beginManualNavigation() {
        if playback.state != .manual { playback.manual(); synchronizePlayback() }
    }
    func resetView() { selectStop(0) }
    func setQuality(_ value: Int) { quality = max(0,min(2,value)); dirty = true; historyDirty = true }
    func setLighting(_ value: Int) { playback.setLighting(value); lighting = playback.lighting; dirty = true; historyDirty = true }
    func toggleDayNight() { playback.toggleDayNight(); lighting = playback.lighting; dirty = true; historyDirty = true; focusViewport() }
    func setExposure(_ value: Double) { exposure = value; dirty = true; historyDirty = true }
    func moveKey(_ code: UInt16, pressed: Bool) {
        if pressed {
            keys.insert(code)
            if [UInt16(13), 0, 1, 2, 12, 14].contains(code) { beginManualNavigation() }
        } else { keys.remove(code) }
    }
    func look(deltaX: Float, deltaY: Float) {
        guard deltaX.isFinite, deltaY.isFinite, abs(deltaX) + abs(deltaY) > 0.01 else { return }
        beginManualNavigation()
        let direction = simd_normalize(pose.target-pose.position)
        let yaw = atan2(direction.x,-direction.z) + deltaX*0.003
        let pitch = max(-1.50,min(1.50,asin(direction.y)-deltaY*0.003))
        pose.target = pose.position + SIMD3(sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch))
        dirty = true
    }
    func scroll(_ amount: Float) { movementSpeed = max(1,min(80,movementSpeed * exp(-amount*0.035))) }
    func captureScreenshot() { captured = true }
    func draw(_ view: MTKView) {
        guard let renderer, isReady else { return }
        if let error = renderer.takeGPUError() {
            errorMessage = "Metal rendering failed: " + error
            view.isPaused = true
            return
        }
        let time = CACurrentMediaTime(), elapsed = max(0.001,time-previousTime)
        let dt = min(0.05,elapsed); previousTime = time
        frameTimes.append(elapsed); if frameTimes.count > 90 { frameTimes.removeFirst() }
        let automaticMotion = playback.state == .idle || playback.state == .playing
        let previousStop = playback.view, previousLighting = playback.lighting
        playback.advance(min(0.25, elapsed))
        if playback.lighting != previousLighting { lighting = playback.lighting; dirty = true; historyDirty = true }
        if playback.view != previousStop { applyViewSelection(); synchronizePlayback() }
        if automaticMotion { pose = playback.pose; dirty = true }
        else if playback.state == .manual { updateMovement(Float(dt)) }
        switch playback.state {
        case .idle: sceneSeconds = playback.idleTime
        case .playing, .paused: sceneSeconds = playback.time
        case .manual: sceneSeconds += dt
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
            synchronizePlayback()
        }
    }
    private func updateMovement(_ dt: Float) {
        if keys.isEmpty { return }
        var f = simd_normalize(pose.target-pose.position)
        if navigationMode == 0 { f.y = 0; f = simd_normalize(f) }
        let right = simd_normalize(simd_cross(f,SIMD3<Float>(0,1,0)))
        var delta = SIMD3<Float>.zero
        if keys.contains(13) { delta += f }; if keys.contains(1) { delta -= f }
        if keys.contains(0) { delta -= right }; if keys.contains(2) { delta += right }
        if navigationMode == 1 { if keys.contains(14) { delta.y += 1 }; if keys.contains(12) { delta.y -= 1 } }
        guard simd_length_squared(delta) > 0 else { return }
        let speed = (navigationMode == 0 ? min(movementSpeed,4) : movementSpeed) * ((keys.contains(56) || keys.contains(60)) ? 3 : 1)
        delta = simd_normalize(delta)*speed*dt
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
