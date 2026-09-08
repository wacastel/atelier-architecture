import Foundation
import simd

var failures: [String] = []
var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
    checks += 1
    if !condition() { failures.append(description) }
}
func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.000001 }
func samePose(_ a: CameraPose, _ b: CameraPose) -> Bool {
    simd_distance(a.position, b.position) < 0.00001 && simd_distance(a.target, b.target) < 0.00001 && abs(a.fov - b.fov) < 0.00001
}

var clock = WalkthroughPlayback()
clock.advance(10)
expect(clock.state == .idle && clock.time == 0 && clock.idleTime == 10, "Idle uses its own clock")
clock.toggle(); clock.advance(7.25); clock.toggle()
let pausedPose = clock.pose
clock.advance(20)
expect(clock.state == .paused && near(clock.time, 7.25) && samePose(pausedPose, clock.pose), "Pause freezes exact time and camera")
clock.toggle(); clock.advance(0.75)
expect(near(clock.time, 8), "Resume retains elapsed time")
for speed in WalkthroughPlayback.speeds {
    clock.select(2); clock.setSpeed(speed); clock.toggle(); clock.advance(2)
    expect(near(clock.time, 2 * speed), "Playback speed \(speed) advances accurately")
}
clock.setSpeed(1); clock.select(1); clock.toggle(); clock.advance(20)
for rate in [2, 4, 8, 2] {
    clock.transport(.reverse)
    expect(clock.shuttle == rate && clock.effectiveRate == -Double(rate), "Rewind cycles to \(rate)x")
}
clock.advance(1)
expect(near(clock.time, 18), "Rewind decreases the current time")
clock.transport(.forward)
expect(clock.shuttle == 2 && clock.effectiveRate == 2, "Opposite direction resets to 2x")
clock.transport(.forward); clock.advance(1)
expect(clock.shuttle == 4 && near(clock.time, 22), "Repeated fast-forward increases transport speed")
clock.toggle(); clock.advance(3)
expect(near(clock.time, 22), "Pausing shuttle freezes time")
clock.toggle(); clock.advance(1)
expect(near(clock.time, 26), "Resuming shuttle preserves direction, speed and time")
clock.seek(progress: 0.99); clock.advance(10)
expect(clock.state == .paused && clock.time == clock.duration && clock.progress == 1, "Forward clamps and pauses at endpoint")
clock.transport(.reverse); clock.advance(100)
expect(clock.state == .paused && clock.time == 0, "Reverse clamps and pauses at start")
clock.toggle(); clock.advance(1)
expect(clock.time == 1 && clock.direction == .forward, "Play from rewound start resumes forward")
clock.select(0); clock.nextView(-1)
expect(clock.view == EiffelScene.stops.count - 1 && clock.state == .idle && clock.time == 0, "Previous view wraps to last and resets idle")
clock.nextView(1)
expect(clock.view == 0, "Next view wraps to first")
clock.manual(); clock.advance(10)
expect(clock.state == .manual && clock.time == 0 && clock.idleTime == 0, "Manual control disables automatic clocks")
clock.seek(progress: 0.5)
expect(clock.state == .paused && clock.time == 28, "Seeking from manual freezes at chosen time")
clock.seek(progress: .nan); clock.advance(.infinity)
expect(clock.time == 28, "Invalid timestamps do not corrupt playback")
clock.select(3)
expect(clock.time == 0 && clock.shuttle == 1 && clock.direction == .forward, "Selecting another view clears transport")

// Idle cycling is independent of walkthrough transport and deliberately selected views.
var idle = WalkthroughPlayback()
expect(idle.idleCycling && idle.view == 0, "Startup cycles from the opening view")
idle.advance(19.9)
expect(idle.view == 0 && near(idle.idleTime, 19.9), "First idle view stays for its full dwell")
idle.advance(0.2)
expect(idle.view == 1 && near(idle.idleTime, 0.1) && near(idle.idleDwellTime, 0.1), "Automatic cut selects next view and preserves fractional elapsed time")
idle.advance(20 * Double(EiffelScene.stops.count - 1))
expect(idle.view == 0 && near(idle.idleTime, 0.1), "Idle sequence wraps through every view in order")
idle.select(2); idle.advance(100)
expect(!idle.idleCycling && idle.view == 2 && near(idle.idleTime, 100), "Explicit selection holds the view while its idle camera continues")
let heldPose = idle.pose
idle.toggleIdleCycling()
expect(idle.idleCycling && idle.view == 2 && samePose(idle.pose, heldPose), "Idle Play resumes cycling from the held view without a camera jump")
idle.advance(20)
expect(idle.view == 3 && idle.idleTime == 0, "Resumed idle gives the held view a full dwell before advancing")
idle.toggleIdleCycling(); idle.advance(25)
expect(!idle.idleCycling && idle.view == 3 && idle.idleTime == 25, "Idle Pause stops switching while keeping gentle motion")
idle.toggle(); idle.advance(3)
expect(idle.state == .playing && !idle.idleCycling && idle.view == 3 && idle.time == 3, "Play starts the current view's walkthrough independently of idle cycling")
idle.toggleIdleCycling()
expect(idle.state == .idle && idle.idleCycling && idle.view == 3 && idle.time == 0 && idle.idleTime == 0, "Idle Play leaves a walkthrough for the current bookmark's idle sequence")
idle.manual(); idle.advance(100)
expect(!idle.idleCycling && idle.state == .manual && idle.view == 3, "Manual navigation stops the idle sequence")
for speed in WalkthroughPlayback.speeds {
    idle.select(0); idle.setIdleSpeed(speed); idle.setSpeed(4); idle.toggleIdleCycling()
    idle.advance(10 / speed)
    expect(idle.view == 0 && near(idle.idleTime, 10), "Idle speed \(speed) scales gentle camera motion")
    idle.advance(10 / speed)
    expect(idle.view == 1 && idle.idleTime == 0, "Idle speed \(speed) scales automatic dwell")
    expect(idle.speed == 4 && idle.idleSpeed == speed, "Idle speed \(speed) leaves walkthrough pace unchanged")
}
idle.setIdleSpeed(1); idle.stepIdleSpeed(-1)
expect(idle.idleSpeed == 0.5, "Slower idle keyboard step selects the previous preset")
idle.stepIdleSpeed(1)
expect(idle.idleSpeed == 1, "Faster idle keyboard step selects the next preset")
for _ in 0..<10 { idle.stepIdleSpeed(1) }
expect(idle.idleSpeed == 4, "Idle speed stops at the maximum preset")
for _ in 0..<10 { idle.stepIdleSpeed(-1) }
expect(idle.idleSpeed == 0.25, "Idle speed stops at the minimum preset")
idle.setIdleSpeed(.nan); idle.setIdleSpeed(3)
expect(idle.idleSpeed == 0.25, "Invalid idle speeds leave the current preset intact")
idle.select(0); idle.toggleIdleCycling(); idle.nextView(-1)
expect(!idle.idleCycling && idle.view == EiffelScene.stops.count - 1, "Keyboard view selection also stops cycling")
idle.toggleIdleCycling(); idle.seek(progress: 0.25)
expect(!idle.idleCycling && idle.state == .paused && idle.time == 14, "Seeking stops the idle sequence at the current walkthrough time")
idle.toggleIdleCycling(); idle.transport(.forward)
expect(!idle.idleCycling && idle.state == .playing, "Shuttle transport leaves idle cycling for the current walkthrough")

for view in 0..<EiffelScene.stops.count {
    let start = EiffelScene.stops[view].pose
    expect(samePose(EiffelWalkthrough.pose(view: view, seconds: 0), start), "View \(view + 1) starts walkthrough at exact bookmark")
    expect(samePose(EiffelWalkthrough.idlePose(view: view, seconds: 0), start), "View \(view + 1) starts idle at exact bookmark")
    expect(!samePose(EiffelWalkthrough.idlePose(view: view, seconds: 10), start), "View \(view + 1) idle visibly changes pose")
    expect(simd_distance(EiffelWalkthrough.pose(view: view, seconds: 14).position, start.position) > 0.5, "View \(view + 1) has a meaningful authored camera route")
    expect(samePose(tourPose(at: Double(view) * 12).pose, start), "Legacy export chapter \(view + 1) begins at bookmark")
}
let overview = EiffelWalkthrough.idlePose(view: 0, seconds: 10)
let origin = EiffelScene.stops[0].pose.position
let angle = acos(simd_dot(simd_normalize(SIMD2(origin.x, origin.z)), simd_normalize(SIMD2(overview.position.x, overview.position.z))))
expect(abs(angle * 180 / .pi - 3.5) < 0.002, "Overview idle pivots at 0.35 degrees per second")
expect(simd_distance(EiffelWalkthrough.pose(view: 0, seconds: 56).position, origin) < 0.001, "Overview walkthrough completes a full orbit")

// Location routing and day/night cycles use the real number of bookmarks.
for location in ArchitectureLocation.allCases {
    var cycle = WalkthroughPlayback(location: location)
    let count = location.stops.count
    expect(count == (location == .paris ? 9 : 8), "\(location.name) exposes the requested view count")
    expect(cycle.lighting == 0 && cycle.idleCycling && cycle.view == 0, "\(location.name) starts a daytime pass")
    for pass in 0..<4 {
        for index in 0..<count {
            expect(cycle.view == index && cycle.lighting == (pass % 2 == 0 ? 0 : 2), "\(location.name) pass \(pass) view \(index) has correct lighting")
            cycle.advance(WalkthroughPlayback.idleViewDuration)
        }
    }
    cycle.select(count - 1); cycle.setLighting(2); cycle.advance(500)
    expect(cycle.view == count - 1 && cycle.lighting == 2 && !cycle.idleCycling, "\(location.name) manual view and night choice hold")
    cycle.toggleIdleCycling(); cycle.advance(20)
    expect(cycle.view == 0 && cycle.lighting == 0, "\(location.name) resumes from manual night into a day pass at the wrap")
    cycle.setLighting(1); cycle.advance(20 * Double(count))
    expect(cycle.view == 0 && cycle.lighting == 2, "\(location.name) daylight override alternates into night")
    cycle.setLighting(1); cycle.advance(20 * Double(count) * 2)
    expect(cycle.view == 0 && cycle.lighting == 0, "\(location.name) a full daylight/night pair normalizes a manual daylight preset")
    cycle.setLighting(2)
    cycle.advance(20 * Double(count) * 2 * 1_000_000_000 + 21)
    expect(cycle.view == 1 && cycle.lighting == 2 && near(cycle.idleDwellTime, 1), "\(location.name) huge even cycle jump preserves day/night parity")
    cycle.advance(Double.greatestFiniteMagnitude)
    expect(cycle.view >= 0 && cycle.view < count && cycle.pose.position.x.isFinite && cycle.pose.position.y.isFinite, "\(location.name) maximum finite elapsed time keeps a finite camera and valid index")
    cycle.setIdleSpeed(0.5); cycle.setSpeed(2); cycle.select(3); cycle.toggle(); cycle.advance(5)
    let other: ArchitectureLocation = location == .paris ? .chicago : .paris
    cycle.selectLocation(other)
    expect(cycle.location == other && cycle.view == 0 && cycle.time == 0 && cycle.lighting == 0 && cycle.idleCycling, "Location switching starts the new daytime idle sequence")
    expect(cycle.speed == 2 && cycle.idleSpeed == 0.5, "Location switching preserves independent pace preferences")
    for view in 0..<count {
        cycle.selectLocation(location); cycle.select(view)
        expect(samePose(cycle.pose, location.stops[view].pose), "\(location.name) selected view \(view) starts exactly at its bookmark")
        cycle.toggle(); cycle.advance(14)
        expect(samePose(cycle.pose, location.pose(view: view, seconds: 28)), "\(location.name) view \(view) plays its own route at the chosen pace")
        expect(simd_distance(location.pose(view: view, seconds: 14).position, location.stops[view].pose.position) > 0.5, "\(location.name) view \(view) has a meaningful route")
        expect(!samePose(location.idlePose(view: view, seconds: 10), location.stops[view].pose), "\(location.name) view \(view) has gentle idle motion")
    }
}

// The long flight uses its own clock throughout seeking, shuttling and pause.
var flight = WalkthroughPlayback(location: .millennium)
flight.select(MillenniumWalkthrough.flybyView)
expect(flight.duration == 240, "Connecting flight has a four-minute timeline")
flight.seek(progress: 0.75)
expect(flight.time == 180, "Flyby seek uses its complete duration")
flight.transport(.forward); flight.advance(30)
expect(flight.time == 240 && flight.state == .paused, "Flyby shuttle reaches and pauses at the museum endpoint")
flight.select(2)
expect(flight.duration == 56 && flight.time == 0, "A park bookmark restores the short route duration")
expect(ArchitectureLocation.chicago.world == ArchitectureLocation.millennium.world, "Chicago destinations identify the same resident world")
expect(ArchitectureLocation.paris.world != ArchitectureLocation.chicago.world, "Paris remains an independent world")
expect(ArchitectureLocation.lakefront.world == ArchitectureLocation.chicago.world, "The lakefront retains the resident Chicago world")

// The day/night shortcut must not restart or resume a selected animation.
for location in ArchitectureLocation.allCases {
    var lightingClock = WalkthroughPlayback(location: location)
    lightingClock.select(2); lightingClock.toggle(); lightingClock.advance(9)
    lightingClock.toggle()
    let frozenPose = lightingClock.pose, frozenTime = lightingClock.time
    lightingClock.toggleDayNight(); lightingClock.advance(3)
    expect(lightingClock.lighting == 2 && lightingClock.state == .paused && lightingClock.time == frozenTime && samePose(lightingClock.pose, frozenPose), "\(location.name) N changes to night while preserving pause and camera")
    lightingClock.toggleDayNight()
    expect(lightingClock.lighting == 0 && lightingClock.view == 2 && !lightingClock.idleCycling, "\(location.name) N restores day and preserves the manual view hold")
    lightingClock.setLighting(1); lightingClock.toggleDayNight()
    expect(lightingClock.lighting == 2, "\(location.name) neutral daylight toggles directly to night")
    lightingClock.toggleIdleCycling(); lightingClock.advance(7)
    let dwell = lightingClock.idleDwellTime, idleTime = lightingClock.idleTime
    lightingClock.toggleDayNight()
    expect(lightingClock.idleCycling && lightingClock.idleDwellTime == dwell && lightingClock.idleTime == idleTime, "\(location.name) N preserves the idle sequence and dwell clock")
}

// Verify actual production geometry, including intermediate positions and body clearance.
// All Chicago bookmark sets intentionally share the same resident geometry.
// Build each world once so the larger map does not multiply validation cost.
for worldName in ["paris", "chicago"] {
let locations = ArchitectureLocation.allCases.filter { $0.world == worldName }
let scene = locations[0].build(), world = CollisionWorld(scene: scene)
for location in locations {
print("Validating camera geometry: \(location.name)")
let walkingViews = location.walkingViews
let axes: [SIMD3<Float>] = [SIMD3(1,0,0), SIMD3(-1,0,0), SIMD3(0,1,0), SIMD3(0,-1,0), SIMD3(0,0,1), SIMD3(0,0,-1)]
for view in 0..<location.stops.count {
    var previous = location.pose(view: view, seconds: 0)
    var blocked = 0, unsupported = 0, close = 0
    let steps = max(560, Int(location.duration(view: view) * 10))
    for frame in 1...steps {
        let pose = location.pose(view: view, seconds: Double(frame) / Double(steps) * location.duration(view: view))
        expect(pose.position.x.isFinite && pose.position.y.isFinite && pose.position.z.isFinite && simd_length(pose.target - pose.position) > 0.1, "View \(view + 1) has valid camera at \(frame)")
        if !world.canMove(from: previous.position, to: pose.position) {
            if blocked == 0 || frame % 20 == 0 { print("Obstruction: view=\(view + 1), seconds=\(Double(frame) * 0.1), position=\(pose.position)") }
            blocked += 1
        }
        if axes.contains(where: { world.distance(origin: pose.position, direction: $0, maximum: 0.18) != nil }) {
            if close == 0 || frame % 20 == 0 { print("Near surface: view=\(view + 1), seconds=\(Double(frame) * 0.1), position=\(pose.position)") }
            close += 1
        }
        if walkingViews.contains(view), world.distance(origin: pose.position + SIMD3(0,0.45,0), direction: SIMD3(0,-1,0), maximum: 2.8) == nil { unsupported += 1 }
        previous = pose
    }
    expect(blocked == 0, "View \(view + 1) has \(blocked) obstructed camera steps")
    expect(unsupported == 0, "View \(view + 1) has \(unsupported) unsupported walking positions")
    expect(close == 0, "View \(view + 1) has \(close) camera positions too close to geometry")
    print("View \(view + 1): \(steps) steps, blocked=\(blocked), unsupported=\(unsupported), near-surface=\(close)")
    previous = location.idlePose(view: view, seconds: 0)
    for tick in 1...120 {
        let idle = location.idlePose(view: view, seconds: Double(tick))
        expect(world.canMove(from: previous.position, to: idle.position), "View \(view + 1) idle has body clearance at \(tick)s")
        expect(!axes.contains(where: { world.distance(origin: idle.position, direction: $0, maximum: 0.18) != nil }), "View \(view + 1) idle has camera clearance at \(tick)s")
        previous = idle
    }
}
}
}
print("Playback: \(checks) checks; failures: \(failures)")
if !failures.isEmpty { exit(1) }
