import Foundation
import simd

// A direct swiftc fixture has no SwiftPM-generated resource accessor. Renderer
// resource lookup is unreachable in this CPU test and must fail if introduced.
extension Bundle {
    static var module: Bundle { fatalError("CPU Map fixture unexpectedly requested renderer resources") }
}

// The only substituted production type: audio must not start when the actual
// controller synchronizes playback. No renderer, scene, camera or input logic
// is stubbed. This fixture never attaches a view or requests a Metal device.
@MainActor final class AmbientMusicController {
    let isEnabled = false
    private(set) var selections: [String] = []
    func selectLocation(_ location: String) { selections.append(location) }
}

@MainActor func validateMapMode() -> Int32 {
    var checks = 0, failures: [String] = []
    func expect(_ condition: Bool, _ message: String) {
        checks += 1
        if !condition { failures.append(message) }
    }
    func same(_ lhs: CameraPose, _ rhs: CameraPose) -> Bool {
        lhs.position == rhs.position && lhs.target == rhs.target && lhs.fov == rhs.fov
    }
    func assertMap(_ engine: EngineController, _ label: String) {
        let pose = engine.cameraPose
        expect(engine.isMapMode && engine.navigationMode == 2, "\(label): left Map mode")
        expect(engine.playbackState == .manual && !engine.tourPlaying && !engine.chicagoDemoActive,
               "\(label): automatic playback can move Map camera")
        expect(pose.position.x == pose.target.x && pose.position.z == pose.target.z && pose.target.y == 0,
               "\(label): camera is not exactly downward")
        expect(pose.position.y >= 650 && pose.position.y.isFinite && pose.fov > 0 && pose.fov <= 60,
               "\(label): Map lens or height is unsafe")
        let coverage = 2 * Double(pose.position.y) * tan(Double(pose.fov) * Double.pi / 360)
        expect(abs(coverage - Double(engine.mapViewSpan)) < Double(engine.mapViewSpan) * 0.000002,
               "\(label): camera coverage differs from Map zoom")
        expect(engine.mapCamera.position == SIMD2(pose.position.x, pose.position.z)
               && engine.mapCamera.target == SIMD2(pose.target.x, pose.target.z),
               "\(label): PiP camera marker is stale")
    }

    let engine = EngineController()
    let unready = engine.cameraPose
    engine.toggleMapMode()
    expect(!engine.isMapMode && same(engine.cameraPose, unready), "Unready controller entered Map")
    engine.isReady = true
    engine.selectStop(2)
    engine.toggleTour()
    expect(engine.tourPlaying, "Test setup failed to start a real walkthrough")
    let entry = engine.cameraPose
    engine.setLighting(2)
    engine.toggleMapMode()
    assertMap(engine, "entry from playing walkthrough")
    expect(engine.cameraPose.target == SIMD3(entry.target.x, 0, entry.target.z), "Map entry did not retain current target X/Z")
    expect(engine.lighting == 2, "Map entry reset night lighting")
    expect(engine.options.hazeDensity == 0.0000001, "Map omitted its distant-visibility haze override")

    let blocked: [(String, () -> Void)] = [
        ("look", { engine.look(deltaX: 120, deltaY: -65) }),
        ("selectStop", { engine.selectStop(1) }),
        ("next view", { engine.cycleView(1) }),
        ("previous view", { engine.cycleView(-1) }),
        ("play/pause", { engine.toggleTour() }),
        ("idle cycle", { engine.toggleIdleCycling() }),
        ("seek", { engine.seekTour(0.65) }),
        ("forward shuttle", { engine.shuttle(.forward) }),
        ("reverse shuttle", { engine.shuttle(.reverse) }),
        ("reset", { engine.resetView() }),
        ("focus dispatch", { engine.focusObject(at: SIMD2(0.5, 0.5), aspect: 1.5) }),
        ("location toggle", { engine.toggleLocation() }),
        ("Chicago demo", { engine.toggleChicagoDemo() }),
        ("park connection", { engine.startChicagoFlyby() }),
        ("campus connection", { engine.startMuseumCampusFlyby() }),
        ("north connection", { engine.startNorthSideFlyby() }),
        ("Robie connection", { engine.startRobieFlyby() })
    ]
    for (name, action) in blocked {
        let before = engine.cameraPose, span = engine.mapViewSpan, stop = engine.currentStop
        action()
        expect(same(before, engine.cameraPose) && span == engine.mapViewSpan && stop == engine.currentStop,
               "\(name) changed Map camera or selected view")
        assertMap(engine, name)
    }

    for viewport in [SIMD2<Float>(1200, 800), SIMD2(800, 1400), SIMD2(2000, 700)] {
        let before = engine.cameraPose, span = engine.mapViewSpan
        let delta = SIMD2<Float>(36, -24)
        engine.pan(from: SIMD2(300, 250), to: SIMD2(300, 250) + delta, viewport: viewport)
        let moved = engine.cameraPose
        let expected = SIMD3(-delta.x * span / viewport.y, 0, -delta.y * span / viewport.y)
        expect(simd_distance(moved.position - before.position, expected) < 0.001,
               "Viewport pan did not map screen points to ground metres at aspect \(viewport)")
        expect(simd_distance(moved.target - before.target, expected) < 0.001
               && moved.position.y == before.position.y && moved.fov == before.fov,
               "Viewport pan changed Map orientation, altitude or lens")
        engine.pan(from: SIMD2(300, 250) + delta, to: SIMD2(300, 250), viewport: viewport)
        expect(simd_distance(engine.cameraPose.position, before.position) < 0.001, "Viewport pan inverse failed")
        assertMap(engine, "viewport pan")
    }
    let directBefore = engine.cameraPose
    let requested = SIMD2<Float>(110, -75), applied = engine.panCityMap(requested)
    expect(applied == requested && engine.cameraPose.target == directBefore.target + SIMD3(110, 0, -75),
           "PiP drag failed to move the same real Map camera")
    assertMap(engine, "PiP drag")

    let zoomCenter = engine.cameraPose.target, originalSpan = engine.mapViewSpan
    engine.magnify(0.25)
    expect(abs(engine.mapViewSpan - originalSpan / 1.25) < 0.001, "Positive Map pinch did not zoom in by 1.25")
    expect(engine.cameraPose.target == zoomCenter, "Map pinch drifted from its center")
    assertMap(engine, "pinch inward")
    engine.magnify(-0.2)
    expect(abs(engine.mapViewSpan - originalSpan) < 0.001, "Inverse Map pinch changed original coverage")
    engine.zoomMap(true)
    engine.zoomMap(false)
    expect(abs(engine.mapViewSpan - originalSpan) < 0.001, "Map zoom buttons are not inverse factors")
    let speedBefore = engine.flySpeed
    engine.scroll(1)
    expect(engine.mapViewSpan < originalSpan && engine.flySpeed == speedBefore, "Map scroll changed flight speed instead of zoom")
    engine.scroll(-1)
    expect(abs(engine.mapViewSpan - originalSpan) < 0.002, "Map wheel inverse failed")
    for _ in 0..<20 { engine.magnify(1) }
    expect(engine.mapViewSpan == 50, "Controller Map pinch escaped minimum coverage")
    assertMap(engine, "closest block")
    for _ in 0..<20 { engine.magnify(-0.5) }
    expect(engine.mapViewSpan == 24_000, "Controller Map pinch escaped whole-city coverage")
    assertMap(engine, "whole city")

    for point in [SIMD2<Float>(3313, 9915), SIMD2(-1626, -7718), SIMD2(5100, 9100)] {
        let span = engine.mapViewSpan
        engine.navigateCity(to: point)
        expect(engine.cameraPose.target == SIMD3(point.x, 0, point.y) && engine.mapViewSpan == span,
               "Raw Map click did not retain coverage and center")
        expect(engine.lighting == 2, "Raw Map click reset night mode")
        assertMap(engine, "raw Map click")
    }
    for landmark in ChicagoMapLandmark.all {
        engine.navigateCity(to: landmark)
        expect(engine.cameraPose.target == SIMD3(landmark.point.x, 0, landmark.point.y),
               "\(landmark.id): Map landmark click did not center its authored location")
        expect(abs(engine.mapViewSpan - max(100, min(24_000, landmark.framingRadius * 3))) < 0.001,
               "\(landmark.id): Map landmark click used the wrong framing coverage")
        expect(engine.lighting == 2, "\(landmark.id): Map landmark click reset lighting")
        assertMap(engine, "landmark \(landmark.id)")
    }
    for invalid in [Double.nan, .infinity, -.infinity, -1, -2] {
        let before = engine.cameraPose, span = engine.mapViewSpan
        engine.magnify(invalid)
        expect(same(before, engine.cameraPose) && span == engine.mapViewSpan, "Invalid pinch moved Map camera")
    }
    for invalid in [SIMD2<Float>(.nan, 0), SIMD2(.infinity, 0), SIMD2(6001, 0), SIMD2(0, -11501)] {
        let before = engine.cameraPose
        engine.navigateCity(to: invalid)
        expect(same(before, engine.cameraPose), "Invalid raw Map destination changed camera")
    }
    let helpPose = engine.cameraPose
    engine.showHelp = true
    engine.pan(from: .zero, to: SIMD2(40, 20), viewport: SIMD2(1000, 800))
    engine.magnify(0.5)
    engine.navigateCity(to: SIMD2(0, 0))
    expect(same(helpPose, engine.cameraPose), "Map input moved camera behind Help")
    engine.showHelp = false

    let exitCenter = engine.cameraPose.target
    engine.toggleMapMode()
    expect(!engine.isMapMode && engine.navigationMode == 1 && engine.playbackState == .manual,
           "Leaving Map did not return to manual Flyover")
    expect(engine.cameraPose.target.x == exitCenter.x && engine.cameraPose.target.z == exitCenter.z,
           "Leaving Map returned to an old location")
    expect(engine.cameraPose.position.y > engine.cameraPose.target.y
           && simd_distance(SIMD2(engine.cameraPose.position.x, engine.cameraPose.position.z),
                            SIMD2(exitCenter.x, exitCenter.z)) > 100,
           "Leaving Map retained the top-down orientation")
    expect(engine.lighting == 2, "Leaving Map reset night mode")
    expect(engine.options.hazeDensity != 0.0000001, "Map haze override leaked into Flyover")

    let normalBefore = engine.cameraPose
    engine.magnify(0.25)
    expect(engine.cameraPose.position == normalBefore.position && engine.cameraPose.target == normalBefore.target,
           "Unfocused optical pinch moved camera or its target")
    let ratio = tan(Double(normalBefore.fov) * Double.pi / 360)
        / tan(Double(engine.cameraPose.fov) * Double.pi / 360)
    expect(abs(ratio - 1.25) < 0.000001, "Normal controller pinch is not optical magnification")
    engine.magnify(-0.2)
    expect(abs(engine.cameraPose.fov - normalBefore.fov) < 0.00002, "Normal pinch inverse failed")
    for invalid in [Double.nan, .infinity, -.infinity, -1, -2] {
        let before = engine.cameraPose
        engine.magnify(invalid)
        expect(same(before, engine.cameraPose), "Invalid pinch moved normal camera")
    }
    for _ in 0..<20 { engine.magnify(1) }
    expect(engine.cameraPose.fov == 1.5, "Normal pinch escaped narrow-lens clamp")
    let willis = ChicagoMapLandmark.all.first { $0.id == "willis" }!
    engine.navigateCity(to: willis)
    expect(engine.cameraPose.fov == 50 && engine.cameraPose.target == willis.target && !engine.isMapMode,
           "Normal landmark click retained prior telephoto lens or missed whole-landmark center")
    for _ in 0..<20 { engine.magnify(-0.5) }
    expect(engine.cameraPose.fov == 100, "Normal pinch escaped wide-lens clamp")
    engine.toggleMapMode()
    assertMap(engine, "re-enter after optical zoom")
    expect(!engine.music.isEnabled && !engine.music.selections.isEmpty,
           "Audio stub did not exercise real playback synchronization")

    let report: [String: Any] = [
        "passed": failures.isEmpty, "checks": checks, "failures": failures,
        "scope": "CPU actual EngineController methods and production camera/playback/map metadata. Only AmbientMusicController is replaced by an inert stub; the absent SwiftPM Bundle.module accessor traps if reached. No view attachment, Metal device, renderer construction, city geometry build or audio playback.",
        "limitations": "No native event dispatch, rendered frame, collision/roof geometry or device-dependent location loading is exercised. Focus dispatch has no collision catalog; selected-object pinch is covered by the separate FocusOrbit tests.",
        "landmarkClicks": ChicagoMapLandmark.all.count, "audioSynchronizationCalls": engine.music.selections.count
    ]
    FileHandle.standardOutput.write(try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]))
    print("")
    return failures.isEmpty ? 0 : 1
}

exit(MainActor.assumeIsolated { validateMapMode() })
