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

// The new flight and dome program share ordinary transport; neither owns a wall clock.
var campusFlight = WalkthroughPlayback(location: .campus)
campusFlight.select(MuseumCampusWalkthrough.flybyView)
expect(campusFlight.duration == 180, "Art Institute to Field flight is three minutes")
campusFlight.seek(progress: 0.75)
expect(campusFlight.time == 135, "Museum flight seeking uses its complete timeline")
campusFlight.transport(.reverse); campusFlight.advance(5)
expect(campusFlight.time == 125, "Museum flight rewinds continuously")
campusFlight.select(4); campusFlight.toggle(); campusFlight.advance(40); campusFlight.toggle()
expect(campusFlight.duration == AdlerLayout.showPeriod, "The dome walkthrough presents the complete show period")
expect(samePose(ArchitectureLocation.campus.pose(view:4,seconds:180),ArchitectureLocation.campus.stops[4].pose), "The dome camera returns to its opening pose at the show loop")
let domeTime = campusFlight.time
campusFlight.advance(30)
expect(campusFlight.time == domeTime && domeTime == 40, "Paused planetarium retains its absolute show time")
expect(ArchitectureLocation.campus.world == ArchitectureLocation.chicago.world, "Museum Campus shares the resident Chicago world")

// Both North Side connections retain one shared world and a complete transport clock.
for view in [NorthSideWalkthrough.zooFlybyView, NorthSideWalkthrough.wrigleyFlybyView] {
    var northFlight = WalkthroughPlayback(location: .northside)
    northFlight.select(view)
    expect(northFlight.duration == 240, "North Side connection has a four-minute timeline")
    northFlight.seek(progress: 0.75)
    expect(northFlight.time == 180, "North Side flight seek uses its full duration")
    northFlight.transport(.reverse); northFlight.advance(5)
    expect(northFlight.time == 170, "North Side flight rewinds on its own timeline")
    northFlight.toggle(); let frozen = northFlight.pose; northFlight.advance(30)
    expect(northFlight.time == 170 && samePose(northFlight.pose, frozen), "North Side flight pause is exact")
    northFlight.transport(.forward); northFlight.advance(100)
    expect(northFlight.time == 240 && northFlight.state == .paused, "North Side flight ends at its destination")
}
expect(ArchitectureLocation.northside.world == ArchitectureLocation.millennium.world, "North Side connections share the existing Chicago world")
expect(samePose(NorthSideWalkthrough.pose(view:0,seconds:240),NorthSideScene.stops[3].pose), "Millennium–Zoo flight ends at the exact Nature Boardwalk bookmark")
expect(samePose(NorthSideWalkthrough.pose(view:6,seconds:240),NorthSideScene.stops[7].pose), "Zoo–Wrigley flight ends at the exact Wrigley bookmark")

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

// Chicago demo sequences full route durations across all five resident sets.
// Use an independent explicit order to catch accidental Paris inclusion/reordering.
let demoLocations: [ArchitectureLocation] = [.chicago, .millennium, .lakefront, .campus, .northside]
let demoRoutes = demoLocations.flatMap { location in location.stops.indices.map { (location, $0, location.duration(view: $0)) } }
let demoPass = demoRoutes.reduce(0.0) { $0 + $1.2 }
expect(WalkthroughPlayback.chicagoDemoLocations == demoLocations, "Demo follows Chicago enum order and excludes Paris")
expect(WalkthroughPlayback.chicagoDemoRouteCount == 40 && demoRoutes.count == 40, "Demo exposes all forty Chicago routes")
expect(WalkthroughPlayback.chicagoDemoDuration == demoPass, "Demo reports the sum of full route durations")
var demo = WalkthroughPlayback(location: .paris)
demo.select(8); demo.setLighting(1); demo.setSpeed(2); demo.setIdleSpeed(0.5); demo.manual()
demo.startChicagoDemo()
expect(demo.demoActive && demo.location == .chicago && demo.view == 0 && demo.time == 0 && demo.state == .playing && !demo.idleCycling, "Demo starts at Willis opening walkthrough from any location/state")
expect(demo.lighting == 1 && demo.speed == 2 && demo.idleSpeed == 0.5, "Starting demo preserves selected lighting and both pace preferences")
expect(demo.direction == .forward && demo.shuttle == 1 && demo.demoProgress == 0 && demo.demoTitle.contains("1/40"), "Demo starts with ordinary forward transport and clear progress/title")
demo.setSpeed(1); demo.setLighting(0)
for pass in 0..<3 {
    for (index, route) in demoRoutes.enumerated() {
        expect(demo.demoActive && demo.state == .playing && demo.location == route.0 && demo.view == route.1 && demo.time == 0, "Demo pass \(pass) reaches full route \(index) in order")
        expect(demo.demoRouteIndex == index && demo.duration == route.2 && samePose(demo.pose, route.0.stops[route.1].pose), "Demo route \(index) uses its exact bookmark and full duration")
        expect(demo.lighting == (pass % 2 == 0 ? 0 : 2), "Demo changes lighting only after the complete Chicago pass, not between locations")
        demo.advance(route.2)
    }
}
expect(demo.location == .chicago && demo.view == 0 && demo.lighting == 2 && demo.demoProgress == 0, "Completed demo repeats from Willis and alternates day/night")

// Carry through several route/location boundaries without losing fractional time.
let destinationIndex = 18
let destinationOffset = demoRoutes.prefix(destinationIndex).reduce(0.0) { $0 + $1.2 }
for pace in WalkthroughPlayback.speeds {
    var carried = WalkthroughPlayback(location: .northside)
    carried.setLighting(1); carried.setSpeed(pace); carried.startChicagoDemo()
    carried.advance((demoPass * 2 + destinationOffset + 0.375) / pace)
    expect(carried.location == demoRoutes[destinationIndex].0 && carried.view == demoRoutes[destinationIndex].1 && near(carried.time, 0.375), "Demo pace \(pace) carries fractional time through multiple full passes and locations")
    expect(carried.lighting == 0 && carried.state == .playing && carried.demoActive, "Two demo passes normalize neutral daylight while preserving transport")
    expect(near(carried.demoProgress, (destinationOffset + 0.375) / demoPass), "Demo full-pass progress includes preceding routes")
    var stepped = WalkthroughPlayback(), batched = WalkthroughPlayback()
    stepped.setSpeed(pace); stepped.startChicagoDemo(); batched.setSpeed(pace); batched.startChicagoDemo()
    for _ in 0..<800 { stepped.advance(0.125) }
    batched.advance(100)
    expect(stepped.location == batched.location && stepped.view == batched.view && near(stepped.time, batched.time) && stepped.lighting == batched.lighting, "Demo pace \(pace) is independent of elapsed-time chunk size")
}
for lighting in [0, 1, 2] {
    var large = WalkthroughPlayback()
    large.setLighting(lighting); large.startChicagoDemo(); large.advance(demoPass * 2 * 1_000_000_000 + 7.25)
    expect(large.location == .chicago && large.view == 0 && near(large.time, 7.25) && large.lighting == (lighting == 2 ? 2 : 0), "Huge even demo gap keeps correct route, carry and lighting parity")
    large.setSpeed(4); large.advance(Double.greatestFiniteMagnitude)
    expect(large.demoActive && large.state == .playing && demoLocations.contains(large.location) && large.view >= 0 && large.view < 8 && large.time.isFinite && large.time >= 0 && large.time < large.duration && large.demoProgress.isFinite && large.demoProgress >= 0 && large.demoProgress < 1, "Maximum finite demo gap avoids overflow and leaves valid bounded clocks")
}

// Space, lighting and pace retain sequencing; manual choices terminate it.
demo.startChicagoDemo(); demo.advance(9.5); demo.toggle()
let demoPaused = demo.pose, demoPausedTime = demo.time
demo.advance(1000); demo.setLighting(1); demo.toggleDayNight(); demo.setSpeed(0.5); demo.setIdleSpeed(4)
expect(demo.demoActive && demo.state == .paused && demo.time == demoPausedTime && samePose(demo.pose, demoPaused) && demo.lighting == 2, "Paused demo stays exact through elapsed time, lighting and pace changes")
demo.toggle(); demo.advance(1)
expect(demo.demoActive && demo.state == .playing && near(demo.time, 10), "Space resumes the same demo route at its selected pace")
let beforeInvalid = demo
for bad in [Double.nan, Double.infinity, -Double.infinity, -1, 0] { demo.advance(bad) }
demo.seek(progress: .nan); demo.setSpeed(.infinity)
expect(demo.demoActive && demo.location == beforeInvalid.location && demo.view == beforeInvalid.view && demo.time == beforeInvalid.time && demo.lighting == beforeInvalid.lighting && demo.speed == beforeInvalid.speed, "Invalid demo elapsed/seek/pace inputs preserve finite playback state")
for action in 0..<5 {
    var selected = demo
    switch action {
    case 0: selected.select(3)
    case 1: selected.nextView(1)
    case 2: selected.selectLocation(.campus)
    case 3: selected.toggleIdleCycling()
    default: selected.manual()
    }
    expect(!selected.demoActive, "Explicit navigation/idle action \(action) exits Chicago demo")
}
var stopped = demo
let stoppedPose = stopped.pose, stoppedTime = stopped.time
stopped.stopChicagoDemo(); stopped.advance(1000); stopped.stopChicagoDemo()
expect(!stopped.demoActive && stopped.state == .paused && stopped.time == stoppedTime && samePose(stopped.pose, stoppedPose), "Stopping demo is idempotent and holds the exact pose")
var alreadyPaused = demo; alreadyPaused.toggle(); let alreadyPausedPose = alreadyPaused.pose
alreadyPaused.stopChicagoDemo()
expect(alreadyPaused.state == .paused && samePose(alreadyPaused.pose, alreadyPausedPose), "Stopping paused demo never snaps its pose")
var manualDemo = demo; manualDemo.manual(); let manualDemoPose = manualDemo.pose; manualDemo.stopChicagoDemo()
expect(manualDemo.state == .manual && samePose(manualDemo.pose, manualDemoPose), "Inactive demo stop leaves manual navigation state untouched")

// Seeking and shuttling never jump backward or forward out of the current route.
var shuttleDemo = WalkthroughPlayback(); shuttleDemo.startChicagoDemo()
shuttleDemo.advance(demoRoutes[0].2 + 10)
let shuttleView = shuttleDemo.view, shuttleLocation = shuttleDemo.location
shuttleDemo.seek(progress: 0.75)
expect(shuttleDemo.demoActive && shuttleDemo.view == shuttleView && shuttleDemo.location == shuttleLocation && near(shuttleDemo.time, shuttleDemo.duration * 0.75), "Seeking within demo retains its current route and sequencing")
shuttleDemo.transport(.reverse); shuttleDemo.advance(1_000_000)
expect(shuttleDemo.demoActive && shuttleDemo.state == .paused && shuttleDemo.time == 0 && shuttleDemo.view == shuttleView && shuttleDemo.location == shuttleLocation, "Demo reverse pauses at current route start without selecting the previous route")
shuttleDemo.toggle(); shuttleDemo.advance(1)
expect(shuttleDemo.demoActive && shuttleDemo.direction == .forward && shuttleDemo.shuttle == 1 && shuttleDemo.time == 1, "Space at reverse boundary resumes ordinary forward demo motion")
shuttleDemo.transport(.forward); shuttleDemo.transport(.forward); shuttleDemo.toggle()
let shuttlePausedTime = shuttleDemo.time; shuttleDemo.advance(20); shuttleDemo.toggle()
expect(shuttleDemo.demoActive && shuttleDemo.shuttle == 4 && shuttleDemo.time == shuttlePausedTime, "Space preserves an in-route shuttle while pausing/resuming demo")
shuttleDemo.advance(1_000_000)
expect(shuttleDemo.demoActive && shuttleDemo.state == .paused && shuttleDemo.time == shuttleDemo.duration && shuttleDemo.view == shuttleView, "Fast-forward pauses at current demo route endpoint without crossing it")
shuttleDemo.toggle(); shuttleDemo.advance(0.75)
expect(shuttleDemo.demoActive && shuttleDemo.state == .playing && shuttleDemo.shuttle == 1 && shuttleDemo.view == shuttleView + 1 && near(shuttleDemo.time, 0.75), "Space from shuttle endpoint resumes automatic next-route sequencing with full carry")
shuttleDemo.toggle(); shuttleDemo.seek(progress: 1)
let soughtView = shuttleDemo.view
expect(shuttleDemo.demoActive && shuttleDemo.state == .paused && shuttleDemo.time == shuttleDemo.duration && shuttleDemo.view == soughtView, "Seeking to endpoint while paused stays in that demo route")
shuttleDemo.toggle(); shuttleDemo.advance(0.25)
expect(shuttleDemo.view == soughtView + 1 && near(shuttleDemo.time, 0.25), "Resume after endpoint seek continues to next full walkthrough")

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
