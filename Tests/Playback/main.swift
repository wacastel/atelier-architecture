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

// The Robie connection has its own six-minute transport clock and joins the
// opening house bookmark exactly, within the same resident Chicago geometry.
var robieFlight = WalkthroughPlayback(location: .robie)
robieFlight.select(RobieWalkthrough.flybyView)
expect(robieFlight.duration == 360, "McCormick–Robie flight has its complete six-minute timeline")
expect(samePose(ArchitectureLocation.robie.pose(view: RobieWalkthrough.flybyView, seconds: robieFlight.duration), ArchitectureLocation.robie.stops[0].pose), "McCormick–Robie flight ends at the exact opening house bookmark")
expect(ArchitectureLocation.robie.world == ArchitectureLocation.campus.world, "Robie House and McCormick Place retain one resident Chicago world")
robieFlight.seek(progress: 0.75); robieFlight.transport(.reverse); robieFlight.advance(5)
expect(robieFlight.time == 260, "Robie flight seek and rewind use the entire six-minute route")
robieFlight.toggle(); let robiePausedPose = robieFlight.pose; robieFlight.advance(30)
expect(robieFlight.time == 260 && samePose(robieFlight.pose, robiePausedPose), "Pausing the Robie flight holds its exact route time and camera")
for view in ArchitectureLocation.robie.stops.indices where view != RobieWalkthrough.flybyView {
    expect(ArchitectureLocation.robie.duration(view: view) == 120, "Robie house study \(view) retains its full two-minute timeline")
}

let cultural = ArchitectureLocation.culturalcenter
expect(cultural.world == ArchitectureLocation.millennium.world, "Cultural Center and Millennium Park share one Chicago world")
expect(cultural.walkingViews == Set([1,2,3,4,5,6]), "Cultural Center entrance, stair and room studies require walking support")
expect(samePose(cultural.stops[CulturalCenterWalkthrough.flybyView].pose,MillenniumScene.stops[1].pose), "Cultural Center connection starts at the exact Cloud Gate bookmark")
expect(samePose(cultural.pose(view:CulturalCenterWalkthrough.flybyView,seconds:120),cultural.stops[0].pose), "Cultural Center connection ends at its exact exterior bookmark")
expect(simd_distance(CulturalCenterLayout.washingtonEyePath.last!,CulturalCenterLayout.mosaicStairEyePath[0])<0.0001, "Washington entrance route joins the mosaic stair at one shared eye position")
for view in cultural.stops.indices {
    expect(cultural.duration(view:view)==120, "Cultural Center view \(view) retains two minutes")
    expect(cultural.preferredLighting(view:view)==nil, "Cultural Center view \(view) follows the standard day/night passes")
    expect(samePose(cultural.pose(view:view,seconds:-1),cultural.stops[view].pose), "Cultural Center negative time clamps to its bookmark")
    expect(samePose(cultural.pose(view:view,seconds:.nan),cultural.stops[view].pose), "Cultural Center invalid time cannot corrupt its camera")
    expect(samePose(cultural.pose(view:view,seconds:1000),cultural.pose(view:view,seconds:120)), "Cultural Center route has an exact bounded endpoint")
}

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

// The new pier flight connects exact existing bookmarks in one resident city.
expect(NavyPierScene.stops.count == 8, "Navy Pier has eight complete studies")
expect(ArchitectureLocation.navypier.world == ArchitectureLocation.millennium.world, "Navy Pier retains the shared Chicago world")
expect(samePose(NavyPierScene.stops[7].pose,MillenniumScene.stops[0].pose), "Navy Pier connecting flight starts at the Millennium Park bookmark")
expect(samePose(NavyPierWalkthrough.pose(view:7,seconds:180),NavyPierScene.stops[0].pose), "Navy Pier connecting flight ends at the opening pier bookmark")

// Skyline lighting uses authored per-view studies unless the user overrides a pass.
let skylinePresets = [3,1,3,2,2,1,0,2]
expect(ArchitectureLocation.skyline.walkingViews.isEmpty, "Offshore skyline cameras do not claim walking support")
for (view,preset) in skylinePresets.enumerated() {
    var study = WalkthroughPlayback(location:.skyline)
    study.select(view)
    expect(study.effectiveLighting == preset && study.lighting == 0, "Skyline study \(view) selects authored lighting without changing base day-pass parity")
    expect(study.duration == 120, "Skyline study \(view) retains its full two-minute route")
    study.toggle(); study.advance(8); study.toggle()
    study.toggleDayNight()
    expect(study.effectiveLighting == (preset == 2 ? 0:2) && study.time == 8 && study.state == .paused, "Skyline N toggles from the displayed preset and preserves pause/time")
    study.select((view+1)%8)
    expect(study.effectiveLighting == (preset == 2 ? 0:2), "Skyline manual lighting holds across selected views")
}
// The added cameras must be different geographical compositions, not nearby lake orbits.
for t in stride(from:0.0,through:120.0,by:4.0) {
    let west=SkylineWalkthrough.pose(view:1,seconds:t)
    expect(west.position.x < -12_000 && west.target.x > west.position.x+12_000 && west.fov >= 5 && west.fov <= 12,"Western route stays beyond Chicago and faces east with a telephoto lens")
    let river=SkylineWalkthrough.pose(view:4,seconds:t), south=SkylineWalkthrough.pose(view:6,seconds:t)
    expect(river.position.z < -1000 && river.target.z > river.position.z+900,"Kinzie route keeps its southward river composition")
    expect(south.position.z > 2300 && south.target.z < south.position.z-2300,"Ping Tom route keeps its distinct northward composition")
    expect(simd_distance(west.position,river.position)>12_000 && simd_distance(river.position,south.position)>3300,"New studies remain geographically distinct throughout their routes")
}
var skylineCycle = WalkthroughPlayback(location:.skyline)
skylineCycle.setLighting(3)
skylineCycle.advance(160)
expect(skylineCycle.view == 0 && skylineCycle.effectiveLighting == 2 && !skylineCycle.lightingOverridden, "A complete Skyline idle pass clears explicit sunset and starts all-night pass")
skylineCycle.advance(160)
expect(skylineCycle.effectiveLighting == 3 && skylineCycle.lighting == 0, "The following Skyline pass restores the opening sunset study")
skylineCycle.advance(3*20)
expect(skylineCycle.view == 3 && skylineCycle.effectiveLighting == 2 && skylineCycle.lighting == 0, "An authored night study does not flip the base pass")
skylineCycle.toggleDayNight(); skylineCycle.advance(5*20)
expect(skylineCycle.effectiveLighting == 2 && skylineCycle.lighting == 2, "N from an authored night study does not reverse full-pass parity")
var skylineDemo = WalkthroughPlayback(location:.skyline)
skylineDemo.setLighting(3); skylineDemo.startChicagoDemo(routeIndex:8)
expect(!skylineDemo.lightingOverridden && skylineDemo.location == .skyline && skylineDemo.effectiveLighting == 3, "A fresh demo clears manual override and restores the opening Skyline sunset")
skylineDemo.setLighting(3); skylineDemo.navigateDemoView(offset:7)
expect(skylineDemo.effectiveLighting == 3, "Demo navigation within a pass preserves explicit sunset")
skylineDemo.selectLocation(.chicago); skylineDemo.selectLocation(.skyline)
expect(skylineDemo.effectiveLighting == 3 && skylineDemo.demoActive, "In-demo Chicago selections preserve deliberate lighting override")
skylineDemo.navigateDemoView(offset:WalkthroughPlayback.chicagoDemoRouteCount)
expect(!skylineDemo.lightingOverridden && skylineDemo.effectiveLighting == 2, "Full demo pass clears the override and advances night parity")

// Chicago demo sequences full route durations across every resident Chicago set.
// Use an independent explicit order to catch accidental Paris inclusion/reordering.
let demoLocations: [ArchitectureLocation] = [.chicago, .skyline, .millennium, .culturalcenter, .lakefront, .navypier, .campus, .northside, .robie]
let demoRoutes = demoLocations.flatMap { location in location.stops.indices.map { (location, $0, location.duration(view: $0)) } }
let demoPass = demoRoutes.reduce(0.0) { $0 + $1.2 }
expect(WalkthroughPlayback.chicagoDemoLocations == demoLocations, "Demo follows Chicago enum order and excludes Paris")
expect(WalkthroughPlayback.chicagoDemoRouteCount == demoRoutes.count && demoRoutes.count == demoLocations.reduce(0) { $0 + $1.stops.count }, "Demo exposes every view from every Chicago location")
expect(WalkthroughPlayback.chicagoDemoDuration == demoPass, "Demo reports the sum of full route durations")
var demo = WalkthroughPlayback(location: .paris)
demo.select(8); demo.setLighting(1); demo.setSpeed(2); demo.setIdleSpeed(0.5); demo.manual()
demo.startChicagoDemo(routeIndex: 0)
expect(demo.demoActive && demo.location == .chicago && demo.view == 0 && demo.time == 0 && demo.state == .playing && !demo.idleCycling, "Explicit demo route zero starts at Willis opening walkthrough from any location/state")
expect(demo.lighting == 1 && demo.speed == 2 && demo.idleSpeed == 0.5, "Starting demo preserves selected lighting and both pace preferences")
expect(demo.direction == .forward && demo.shuttle == 1 && demo.demoProgress == 0 && demo.demoTitle.contains("1/\(demoRoutes.count)"), "Demo starts with ordinary forward transport and clear progress/title")
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

// Each possible random opening keeps the fixed sequence until a new demo starts.
// The full-city boundary changes lighting even when the opening was mid-city.
for startIndex in demoRoutes.indices {
    var started = WalkthroughPlayback(location: .paris)
    started.setLighting(2); started.startChicagoDemo(routeIndex: startIndex)
    for step in demoRoutes.indices {
        let absoluteIndex = startIndex + step
        let expectedIndex = absoluteIndex % demoRoutes.count
        let route = demoRoutes[expectedIndex]
        expect(started.demoRouteIndex == expectedIndex && started.location == route.0 && started.view == route.1 && started.time == 0 && started.state == .playing, "Opening route \(startIndex) advances sequentially to step \(step)")
        expect(started.lighting == (absoluteIndex < demoRoutes.count ? 2 : 0), "Opening route \(startIndex) changes lighting only at the city boundary")
        started.advance(route.2)
    }
    expect(started.demoRouteIndex == startIndex && started.lighting == 0 && started.time == 0, "A full pass from opening \(startIndex) visits every route and returns in opposite lighting")
}

struct DemoSeedGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var result = state
        result = (result ^ (result >> 30)) &* 0xBF58476D1CE4E5B9
        result = (result ^ (result >> 27)) &* 0x94D049BB133111EB
        return result ^ (result >> 31)
    }
}
var randomA = DemoSeedGenerator(state: 0xA7E11E), randomB = randomA
var seededOpenings = Set<Int>()
for sample in 0..<512 {
    var first = WalkthroughPlayback(location: .paris), repeated = WalkthroughPlayback(location: .campus)
    first.setLighting(2); first.setSpeed(4); first.setIdleSpeed(0.25)
    first.startChicagoDemo(using: &randomA); repeated.startChicagoDemo(using: &randomB)
    let opening = first.demoRouteIndex
    seededOpenings.insert(opening)
    expect(first.demoActive && first.state == .playing && first.location.world == "chicago" && first.view >= 0 && first.view < first.location.stops.count, "Seeded opening \(sample) selects a valid Chicago location and view")
    expect(first.demoRouteIndex == repeated.demoRouteIndex, "An injected random seed reproduces opening \(sample)")
    expect(first.lighting == 2 && first.speed == 4 && first.idleSpeed == 0.25 && first.direction == .forward && first.shuttle == 1 && first.time == 0, "Random opening preserves lighting and both pace preferences")
    first.advance(first.duration / first.speed)
    expect(first.demoRouteIndex == (opening + 1) % demoRoutes.count && first.time == 0, "Random opening \(sample) proceeds to its sequential successor without reshuffling")
}
expect(seededOpenings.count == demoRoutes.count, "Fixed seed stream exercises every Chicago location and view as a random opening")
var systemRandomDemo = WalkthroughPlayback(location: .paris)
systemRandomDemo.startChicagoDemo()
expect(systemRandomDemo.demoActive && demoLocations.contains(systemRandomDemo.location) && systemRandomDemo.time == 0 && systemRandomDemo.state == .playing, "Default system-random start begins a valid Chicago walkthrough")
for routeIndex in [-1, -demoRoutes.count, demoRoutes.count, demoRoutes.count + 1, Int.min, Int.max] {
    var normalized = WalkthroughPlayback()
    normalized.startChicagoDemo(routeIndex: routeIndex)
    let expectedIndex = ((routeIndex % demoRoutes.count) + demoRoutes.count) % demoRoutes.count
    expect(normalized.demoRouteIndex == expectedIndex && normalized.state == .playing, "Explicit opening index \(routeIndex) normalizes without overflow")
}

// Previous/next can cross every location boundary in either direction. They
// resume a paused/shuttled route from its opening without changing the pace.
for originIndex in demoRoutes.indices {
    for offset in [-1, 1] {
        var navigated = WalkthroughPlayback()
        navigated.setLighting(0); navigated.setSpeed(2); navigated.setIdleSpeed(4)
        navigated.startChicagoDemo(routeIndex: originIndex)
        navigated.advance(3); navigated.transport(.reverse); navigated.toggle()
        navigated.nextView(offset)
        let expectedIndex = (originIndex + offset + demoRoutes.count) % demoRoutes.count
        let crossedCity = (originIndex == 0 && offset == -1) || (originIndex == demoRoutes.count - 1 && offset == 1)
        expect(navigated.demoRouteIndex == expectedIndex && navigated.location == demoRoutes[expectedIndex].0 && navigated.view == demoRoutes[expectedIndex].1 && navigated.time == 0, "Demo \(originIndex) offset \(offset) reaches the adjacent route across location boundaries")
        expect(navigated.demoActive && navigated.state == .playing && navigated.direction == .forward && navigated.shuttle == 1 && !navigated.idleCycling, "Demo adjacent navigation resumes ordinary forward playback")
        expect(navigated.lighting == (crossedCity ? 2 : 0) && navigated.speed == 2 && navigated.idleSpeed == 4, "Only an entire city wrap changes preferences during adjacent navigation")
        navigated.nextView(-offset)
        expect(navigated.demoRouteIndex == originIndex && navigated.lighting == 0, "Previous and next are reversible across every city/location boundary")
    }
}
for offset in [-demoRoutes.count * 3, -demoRoutes.count * 2, -demoRoutes.count, demoRoutes.count, demoRoutes.count * 2, demoRoutes.count * 3] {
    var skippedPass = WalkthroughPlayback()
    skippedPass.setLighting(1); skippedPass.startChicagoDemo(routeIndex: 3)
    skippedPass.navigateDemoView(offset: offset)
    expect(skippedPass.demoRouteIndex == 3 && skippedPass.lighting == (abs(offset / demoRoutes.count) % 2 == 0 ? 0 : 2), "Multi-pass navigation \(offset) normalizes daylight and respects lighting parity")
}
for offset in [Int.min, Int.max] {
    var hugeNavigation = WalkthroughPlayback()
    hugeNavigation.startChicagoDemo(routeIndex: 0); hugeNavigation.navigateDemoView(offset: offset)
    expect(hugeNavigation.demoRouteIndex == ((offset % demoRoutes.count) + demoRoutes.count) % demoRoutes.count && hugeNavigation.time == 0 && hugeNavigation.state == .playing, "Huge navigation offset \(offset) remains finite and bounded")
}
var noNavigation = WalkthroughPlayback()
noNavigation.select(3); noNavigation.toggle(); noNavigation.advance(9)
let nonDemoBefore = noNavigation
noNavigation.navigateDemoView(offset: 1)
expect(noNavigation.location == nonDemoBefore.location && noNavigation.view == nonDemoBefore.view && noNavigation.time == nonDemoBefore.time && noNavigation.state == nonDemoBefore.state && !noNavigation.demoActive, "Explicit demo navigation is inert outside demo mode")
noNavigation.startChicagoDemo(routeIndex: 3); noNavigation.advance(9); noNavigation.toggle()
let zeroOffsetBefore = noNavigation
noNavigation.navigateDemoView(offset: 0)
expect(noNavigation.time == zeroOffsetBefore.time && noNavigation.state == .paused && noNavigation.demoRouteIndex == zeroOffsetBefore.demoRouteIndex, "Zero demo navigation preserves an exact pause")

// Carry through several route/location boundaries without losing fractional time.
let destinationIndex = 18
let destinationOffset = demoRoutes.prefix(destinationIndex).reduce(0.0) { $0 + $1.2 }
for pace in WalkthroughPlayback.speeds {
    var carried = WalkthroughPlayback(location: .northside)
    carried.setLighting(1); carried.setSpeed(pace); carried.startChicagoDemo(routeIndex: 0)
    carried.advance((demoPass * 2 + destinationOffset + 0.375) / pace)
    expect(carried.location == demoRoutes[destinationIndex].0 && carried.view == demoRoutes[destinationIndex].1 && near(carried.time, 0.375), "Demo pace \(pace) carries fractional time through multiple full passes and locations")
    expect(carried.lighting == 0 && carried.state == .playing && carried.demoActive, "Two demo passes normalize neutral daylight while preserving transport")
    expect(near(carried.demoProgress, (destinationOffset + 0.375) / demoPass), "Demo full-pass progress includes preceding routes")
    var stepped = WalkthroughPlayback(), batched = WalkthroughPlayback()
    stepped.setSpeed(pace); stepped.startChicagoDemo(routeIndex: 0); batched.setSpeed(pace); batched.startChicagoDemo(routeIndex: 0)
    for _ in 0..<800 { stepped.advance(0.125) }
    batched.advance(100)
    expect(stepped.location == batched.location && stepped.view == batched.view && near(stepped.time, batched.time) && stepped.lighting == batched.lighting, "Demo pace \(pace) is independent of elapsed-time chunk size")
}
for lighting in [0, 1, 2] {
    var large = WalkthroughPlayback()
    large.setLighting(lighting); large.startChicagoDemo(routeIndex: 0); large.advance(demoPass * 2 * 1_000_000_000 + 7.25)
    expect(large.location == .chicago && large.view == 0 && near(large.time, 7.25) && large.lighting == (lighting == 2 ? 2 : 0), "Huge even demo gap keeps correct route, carry and lighting parity")
    large.setSpeed(4); large.advance(Double.greatestFiniteMagnitude)
    expect(large.demoActive && large.state == .playing && demoLocations.contains(large.location) && large.view >= 0 && large.view < large.location.stops.count && large.time.isFinite && large.time >= 0 && large.time < large.duration && large.demoProgress.isFinite && large.demoProgress >= 0 && large.demoProgress < 1, "Maximum finite demo gap avoids overflow and leaves valid bounded clocks")
}

// Space, lighting and pace retain sequencing; Chicago selections resume it.
demo.startChicagoDemo(routeIndex: 0); demo.advance(9.5); demo.toggle()
let demoPaused = demo.pose, demoPausedTime = demo.time
demo.advance(1000); demo.setLighting(1); demo.toggleDayNight(); demo.setSpeed(0.5); demo.setIdleSpeed(4)
expect(demo.demoActive && demo.state == .paused && demo.time == demoPausedTime && samePose(demo.pose, demoPaused) && demo.lighting == 2, "Paused demo stays exact through elapsed time, lighting and pace changes")
demo.toggle(); demo.advance(1)
expect(demo.demoActive && demo.state == .playing && near(demo.time, 10), "Space resumes the same demo route at its selected pace")
let beforeInvalid = demo
for bad in [Double.nan, Double.infinity, -Double.infinity, -1, 0] { demo.advance(bad) }
demo.seek(progress: .nan); demo.setSpeed(.infinity)
expect(demo.demoActive && demo.location == beforeInvalid.location && demo.view == beforeInvalid.view && demo.time == beforeInvalid.time && demo.lighting == beforeInvalid.lighting && demo.speed == beforeInvalid.speed, "Invalid demo elapsed/seek/pace inputs preserve finite playback state")
for action in 0..<3 {
    var selected = demo
    switch action {
    case 0: selected.selectLocation(.paris)
    case 1: selected.toggleIdleCycling()
    default: selected.manual()
    }
    expect(!selected.demoActive, "Paris, idle play or manual navigation action \(action) exits Chicago demo")
}
// Choosing any Chicago location/view resumes its full route, including a paused
// demo, the same destination, and a route that was previously being rewound.
for location in demoLocations {
    var selected = demo
    selected.toggle(); selected.transport(.reverse); selected.toggle()
    selected.selectLocation(location)
    expect(selected.demoActive && selected.state == .playing && selected.location == location && selected.view == 0 && selected.time == 0, "Selecting \(location.name) resumes its first route without leaving demo")
    expect(selected.lighting == 2 && selected.speed == 0.5 && selected.idleSpeed == 4 && selected.direction == .forward && selected.shuttle == 1 && !selected.idleCycling, "Chicago destination choice retains preferences and restores ordinary forward demo transport")
    selected.advance(7); selected.selectLocation(location)
    expect(selected.demoActive && selected.state == .playing && selected.view == 0 && selected.time == 0, "Selecting the current Chicago destination restarts its first full demo route")
    for view in location.stops.indices {
        selected.toggle(); selected.select(view)
        expect(selected.demoActive && selected.state == .playing && selected.location == location && selected.view == view && selected.time == 0 && samePose(selected.pose, location.stops[view].pose), "Selecting \(location.name) view \(view) retains and resumes demo at its exact bookmark")
        selected.advance(2)
        expect(near(selected.time, 1), "Selected demo route uses the preserved walkthrough pace")
    }
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
var shuttleDemo = WalkthroughPlayback(); shuttleDemo.startChicagoDemo(routeIndex: 0)
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
