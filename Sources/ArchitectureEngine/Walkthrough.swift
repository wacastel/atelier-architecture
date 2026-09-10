import Foundation
import simd

/// A separate clock for every selected view. No rendering or event-loop dependency.
struct WalkthroughPlayback {
    enum State: String { case idle, playing, paused, manual }
    enum Direction: Int { case reverse = -1, forward = 1 }
    static let speeds: [Double] = [0.25, 0.5, 1, 2, 4]
    static let idleViewDuration = 20.0
    static let chicagoDemoLocations = ArchitectureLocation.allCases.filter { $0.world == "chicago" }
    private struct DemoRoute {
        let location: ArchitectureLocation
        let view: Int
        let start: Double
        let duration: Double
    }
    private static let chicagoDemoRoutes: [DemoRoute] = {
        var routes: [DemoRoute] = [], start = 0.0
        for location in chicagoDemoLocations {
            for view in location.stops.indices {
                let duration = location.duration(view: view)
                routes.append(DemoRoute(location: location, view: view, start: start, duration: duration))
                start += duration
            }
        }
        return routes
    }()
    static var chicagoDemoRouteCount: Int { chicagoDemoRoutes.count }
    /// Full route seconds at the ordinary 1x pace, before day/night repetition.
    static var chicagoDemoDuration: Double {
        guard let last = chicagoDemoRoutes.last else { return 0 }
        return last.start + last.duration
    }
    private(set) var location: ArchitectureLocation = .paris
    private(set) var lighting = 0
    private(set) var lightingOverridden = false
    // An explicit bookmark selection restores its authored study without
    // changing the automatic sequence's day/night pass parity.
    private var selectedAuthoredLighting: Int?
    /// Renderer-facing lighting. A normal Skyline pass follows its authored
    /// studies; a night pass stays night. Explicit changes hold until pass wrap.
    var effectiveLighting: Int {
        if let selectedAuthoredLighting, !lightingOverridden { return selectedAuthoredLighting }
        if !lightingOverridden && lighting != 2, let authored = location.preferredLighting(view:view) { return authored }
        return lighting
    }
    private(set) var view = 0
    private(set) var state: State = .idle
    private(set) var time = 0.0
    private(set) var idleTime = 0.0
    private(set) var idleDwellTime = 0.0
    private(set) var idleSpeed = 1.0
    private(set) var idleCycling = true
    private(set) var speed = 1.0
    private(set) var direction: Direction = .forward
    private(set) var shuttle = 1
    private(set) var demoActive = false
    var duration: Double { location.duration(view: view) }
    var progress: Double { time / duration }
    var effectiveRate: Double { speed * Double(shuttle * direction.rawValue) }
    /// Zero-based route position; only meaningful while demoActive is true.
    var demoRouteIndex: Int {
        Self.chicagoDemoRoutes.firstIndex { $0.location == location && $0.view == view } ?? 0
    }
    var demoProgress: Double {
        guard demoActive, Self.chicagoDemoDuration > 0 else { return 0 }
        return (Self.chicagoDemoRoutes[demoRouteIndex].start + time) / Self.chicagoDemoDuration
    }
    var demoTitle: String {
        "Chicago demo · \(location.name) · \(demoRouteIndex + 1)/\(Self.chicagoDemoRouteCount)"
    }

    init(location: ArchitectureLocation = .paris) { self.location = location }
    /// Choose a fresh random location and view for each new demo. An explicit
    /// flattened route index is useful for reproducible exports and validation.
    mutating func startChicagoDemo(routeIndex: Int? = nil) {
        lightingOverridden = false
        if let routeIndex {
            beginDemoRoute(routeIndex)
        } else {
            var generator = SystemRandomNumberGenerator()
            startChicagoDemo(using: &generator)
        }
    }
    /// Location and view are separate random draws, so locations keep equal
    /// weight if a future destination has a different number of bookmarks.
    mutating func startChicagoDemo<R: RandomNumberGenerator>(using generator: inout R) {
        lightingOverridden = false
        guard let chosenLocation = Self.chicagoDemoLocations.randomElement(using: &generator),
              let chosenView = chosenLocation.stops.indices.randomElement(using: &generator),
              let index = Self.chicagoDemoRoutes.firstIndex(where: { $0.location == chosenLocation && $0.view == chosenView }) else { return }
        beginDemoRoute(index)
    }
    private mutating func beginDemoRoute(_ index: Int) {
        let count = Self.chicagoDemoRouteCount
        guard count > 0 else { return }
        let route = Self.chicagoDemoRoutes[((index % count) + count) % count]
        location = route.location; view = route.view
        selectedAuthoredLighting = nil
        time = 0; idleTime = 0; idleDwellTime = 0
        direction = .forward; shuttle = 1
        state = .playing; idleCycling = false; demoActive = true
    }
    /// Exiting a demo holds the exact current pose; explicit navigation can then
    /// select another location/view or enter manual/idle control normally.
    mutating func stopChicagoDemo() {
        guard demoActive else { return }
        demoActive = false; idleCycling = false
        if state == .playing { state = .paused }
    }
    mutating func selectLocation(_ value: ArchitectureLocation) {
        if demoActive, let index = Self.chicagoDemoRoutes.firstIndex(where: { $0.location == value }) {
            beginDemoRoute(index)
            restoreAuthoredLightingForSelection()
            return
        }
        let pace = speed, drift = idleSpeed
        self = WalkthroughPlayback(location: value)
        speed = pace; idleSpeed = drift
    }
    mutating func setLighting(_ value: Int) { selectedAuthoredLighting = nil; lighting = max(0, min(3, value)); lightingOverridden = true }
    /// Lighting changes preserve the selected view, transport and both clocks.
    mutating func toggleDayNight() { lighting = effectiveLighting == 2 ? 0 : 2; selectedAuthoredLighting = nil; lightingOverridden = true }
    private mutating func restoreAuthoredLightingForSelection() {
        guard let authored = location.preferredLighting(view:view) else { return }
        selectedAuthoredLighting = authored; lightingOverridden = false
    }
    private mutating func completeLightingPasses(_ wraps: Int, crossedPair: Bool = false) {
        guard wraps != 0 || crossedPair else { return }
        selectedAuthoredLighting = nil
        lightingOverridden = false
        if lighting != 2 { lighting = 0 }
        if wraps % 2 != 0 { lighting = lighting == 2 ? 0 : 2 }
    }

    /// During a demo, explicit Chicago choices immediately play that route and
    /// keep sequencing. Outside a demo they hold the selected idle view.
    mutating func select(_ index: Int) {
        view = ((index % location.stops.count) + location.stops.count) % location.stops.count
        restoreAuthoredLightingForSelection()
        time = 0; idleTime = 0; idleDwellTime = 0; state = demoActive ? .playing : .idle; direction = .forward; shuttle = 1
        idleCycling = false
    }
    mutating func nextView(_ offset: Int) {
        if demoActive { navigateDemoView(offset: offset) }
        else { select(view + offset % location.stops.count) }
    }
    /// Previous/next move through one continuous Chicago route list. Crossing
    /// either end also crosses day/night; an ordinary location boundary does not.
    mutating func navigateDemoView(offset: Int) {
        let count = Self.chicagoDemoRouteCount
        guard demoActive, count > 0, offset != 0 else { return }
        // Reduce before addition so even Int.min/max offsets remain bounded.
        var destination = demoRouteIndex + offset % count
        var wraps = offset / count
        if destination < 0 { destination += count; wraps -= 1 }
        if destination >= count { destination -= count; wraps += 1 }
        completeLightingPasses(wraps)
        beginDemoRoute(destination)
        if wraps == 0 { restoreAuthoredLightingForSelection() }
    }
    mutating func setSpeed(_ value: Double) {
        guard Self.speeds.contains(value) else { return }
        speed = value
    }
    mutating func setIdleSpeed(_ value: Double) {
        guard Self.speeds.contains(value) else { return }
        idleSpeed = value
    }
    mutating func stepIdleSpeed(_ offset: Int) {
        guard let current = Self.speeds.firstIndex(of: idleSpeed) else { return }
        idleSpeed = Self.speeds[max(0, min(Self.speeds.count - 1, current + offset))]
    }
    mutating func toggleIdleCycling() {
        stopChicagoDemo()
        if state == .idle && idleCycling { idleCycling = false; return }
        if state != .idle {
            time = 0; idleTime = 0; state = .idle; direction = .forward; shuttle = 1
        }
        idleDwellTime = 0
        idleCycling = true
    }
    mutating func toggle() {
        idleCycling = false
        if state == .playing { state = .paused; return }
        if state == .manual { time = 0; direction = .forward; shuttle = 1 }
        if time >= duration && direction == .forward {
            // A route-local shuttle/seek can hold the endpoint. Space resumes
            // normal sequencing from that endpoint instead of replaying it.
            if demoActive { shuttle = 1 } else { time = 0 }
        }
        if time <= 0 && direction == .reverse { direction = .forward; shuttle = 1 }
        state = .playing
    }
    mutating func transport(_ requested: Direction) {
        // Distinct presses cycle 2x, 4x, 8x; changing direction begins at 2x.
        shuttle = direction == requested && shuttle > 1 ? (shuttle == 8 ? 2 : shuttle * 2) : 2
        direction = requested; state = .playing; idleCycling = false
    }
    mutating func seek(progress: Double) {
        guard progress.isFinite else { return }
        time = min(1, max(0, progress)) * duration
        idleCycling = false
        if state != .playing { state = .paused }
    }
    mutating func manual() { state = .manual; idleCycling = false; demoActive = false }
    mutating func advance(_ elapsed: Double) {
        guard elapsed.isFinite, elapsed > 0 else { return }
        if state == .idle {
            let increment = elapsed * idleSpeed
            guard increment.isFinite else { return }
            if idleCycling {
                let count = location.stops.count
                // A complete day + night pair leaves the state unchanged. Reduce
                // before conversion/addition, including astronomically large gaps.
                let period = Self.idleViewDuration * Double(count * 2)
                let total = idleDwellTime + increment.truncatingRemainder(dividingBy: period)
                let steps = Int(floor(total / Self.idleViewDuration))
                let next = view + steps
                let wraps = next / count
                // A manually chosen neutral daylight (1) joins the normal day
                // preset (0) after its first completed day/night pair.
                completeLightingPasses(wraps, crossedPair:increment >= period)
                view = next % count
                let crossedView = increment >= Self.idleViewDuration - idleDwellTime
                if crossedView { selectedAuthoredLighting = nil }
                idleDwellTime = total.truncatingRemainder(dividingBy: Self.idleViewDuration)
                idleTime = crossedView ? idleDwellTime : idleTime + increment
            } else {
                // The camera remains gentle and finite after a suspended session.
                idleTime += increment.truncatingRemainder(dividingBy: 86_400)
                if idleTime > 86_400 { idleTime = idleTime.truncatingRemainder(dividingBy: 86_400) }
            }
            return
        }
        guard state == .playing else { return }
        if demoActive && direction == .forward && shuttle == 1 {
            advanceChicagoDemo(elapsed)
            return
        }
        time = min(duration, max(0, time + elapsed * effectiveRate))
        if (time == duration && direction == .forward) || (time == 0 && direction == .reverse) { state = .paused }
    }
    private mutating func advanceChicagoDemo(_ elapsed: Double) {
        let pass = Self.chicagoDemoDuration
        guard pass.isFinite, pass > 0 else { return }
        // Reduce in wall-clock seconds BEFORE multiplication. This avoids
        // overflow and unbounded route loops after very large suspended gaps.
        // Two complete Chicago passes leave day/night parity unchanged.
        let pairSeconds = pass * 2 / speed
        let increment = elapsed.truncatingRemainder(dividingBy: pairSeconds) * speed
        let absolute = Self.chicagoDemoRoutes[demoRouteIndex].start + time + increment
        let wraps = Int(floor(absolute / pass))
        completeLightingPasses(wraps, crossedPair:elapsed >= pairSeconds)
        let position = absolute.truncatingRemainder(dividingBy: pass)
        guard let route = Self.chicagoDemoRoutes.last(where: { $0.start <= position }) else { return }
        if location != route.location || view != route.view || wraps != 0 || elapsed >= pairSeconds { selectedAuthoredLighting = nil }
        location = route.location; view = route.view
        time = min(route.duration, max(0, position - route.start))
        idleTime = 0; idleDwellTime = 0
    }
    var pose: CameraPose {
        state == .idle ? location.idlePose(view: view, seconds: idleTime) : location.pose(view: view, seconds: time)
    }
}

/// Authored routes use clear terrace aisles and short interior dolly moves.
/// Segment interpolation stays on the validated line, without spline overshoot.
enum EiffelWalkthrough {
    static let duration = 56.0
    private typealias V = SIMD3<Float>
    private struct Key {
        let fraction: Float
        let pose: CameraPose
        init(_ fraction: Float, _ position: V, _ target: V, _ fov: Float) {
            self.fraction = fraction; pose = CameraPose(position: position, target: target, fov: fov)
        }
    }
    private static func rotate(_ value: V, angle: Float) -> V {
        V(value.x * cos(angle) + value.z * sin(angle), value.y, value.z * cos(angle) - value.x * sin(angle))
    }
    static func pose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0, min(EiffelScene.stops.count - 1, view))
        let start = EiffelScene.stops[index].pose
        let t = Float(min(1, max(0, seconds.isFinite ? seconds / duration : 0)))
        if t == 0 { return start }
        if index == 0 {
            // One complete orbit, with a gentle rise to reveal the terraces.
            var result = start
            result.position = rotate(start.position, angle: t * 2 * .pi)
            result.position.y += 24 * sin(t * .pi) * sin(t * .pi)
            return result
        }
        if index == 7 {
            var result = start
            let phase = t * t * (3 - 2 * t)
            result.position = rotate(start.position, angle: -phase * .pi * 0.72)
            result.position.y += 22 * sin(t * .pi) * sin(t * .pi)
            result.fov -= 5 * sin(t * .pi) * sin(t * .pi)
            return result
        }
        var route = [Key(0, start.position, start.target, start.fov)]
        switch index {
        case 1:
            route += [Key(0.38, V(0, 2, 42), V(0, 39, 0), 69),
                      Key(0.76, V(0, 2, 7), V(0, 54, -15), 75),
                      Key(1, V(0, 2, -12), V(-27, 28, -42), 69)]
        case 2:
            route += [Key(0.22, V(32.8, 9.5, 48.6), V(38.5, 8.4, 48), 36),
                      Key(0.58, V(32, 9.8, 46.8), V(38.5, 8.8, 48), 42),
                      Key(1, V(32.4, 9.6, 46.3), V(38.5, 8.5, 48), 44)]
        case 3:
            route += [Key(0.4, V(17, 58.75, 28), V(26, 59.5, 4), 63),
                      Key(0.7, V(5, 58.75, 28), V(0, 85, 0), 68),
                      Key(1, V(-12, 58.75, 28), V(-3, 61, 31), 60)]
        case 4:
            route += [Key(0.18, V(26, 58.8, 4), V(30.2, 58.8, 0), 64),
                      Key(0.62, V(26, 58.8, -9), V(27, 59.5, -17), 69),
                      Key(0.85, V(26, 58.8, -15), V(26, 60, -3), 66),
                      Key(1, V(26, 58.8, -10), V(30.2, 58.8, -7), 61)]
        case 5:
            route += [Key(0.45, V(-4, 116.75, 17.5), V(-9, 158, 0), 66),
                      Key(0.72, V(-1, 116.75, 17.5), V(-80, 75, 160), 68),
                      Key(1, V(6, 116.75, 17.5), V(140, 62, 250), 61)]
        case 8:
            route += [Key(0.34, V(118, 3, -257), V(78, -2, -205), 58),
                      Key(0.68, V(65, 2, -251), V(3, -0.5, -222), 59),
                      Key(1, V(41, 5, -267), V(0, 70, -68), 60)]
        default:
            route += [Key(0.35, V(4, 277.75, 6.6), V(190, 140, 100), 65),
                      Key(0.75, V(-4, 277.75, 6.6), V(-220, 105, 160), 68),
                      Key(1, V(-1, 277.75, 6.6), V(0, 40, 230), 60)]
        }
        for i in 1..<route.count where t <= route[i].fraction {
            let a = route[i - 1], b = route[i]
            let linear = (t - a.fraction) / (b.fraction - a.fraction)
            let u = linear * linear * (3 - 2 * linear)
            return CameraPose(position: a.pose.position + (b.pose.position - a.pose.position) * u,
                              target: a.pose.target + (b.pose.target - a.pose.target) * u,
                              fov: a.pose.fov + (b.pose.fov - a.pose.fov) * u)
        }
        return route.last!.pose
    }
    static func idlePose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0, min(EiffelScene.stops.count - 1, view))
        var result = EiffelScene.stops[index].pose
        let elapsed = Float(max(0, seconds.isFinite ? seconds : 0))
        if index == 0 {
            result.position = rotate(result.position, angle: elapsed * .pi / 180 * 0.35)
        } else {
            let phase = elapsed * 0.085
            let forward = simd_normalize(result.target - result.position)
            let right = simd_normalize(simd_cross(forward, V(0, 1, 0)))
            let scale: Float = index >= 7 ? 12 : 1
            result.position += right * sin(phase) * 0.07 * scale
            result.target += right * sin(phase * 0.73) * 0.22 * scale
            result.fov -= sin(phase * 0.55) * 0.8
        }
        return result
    }
}

/// A 12-second chapter for each view keeps command-line exports aligned with the bookmarks.
func tourPose(at seconds: Double) -> (pose: CameraPose, index: Int) {
    let time = max(0, min(Double(EiffelScene.stops.count) * 12, seconds.isFinite ? seconds : 0))
    let index = min(EiffelScene.stops.count - 1, Int(time / 12))
    let local = min(12, time - Double(index) * 12) / 12 * EiffelWalkthrough.duration
    return (EiffelWalkthrough.pose(view: index, seconds: local), index)
}
