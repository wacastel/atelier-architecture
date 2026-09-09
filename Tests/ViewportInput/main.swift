import Foundation

// CPU contract tests: the AppKit adapter supplies hit-testing and lifecycle
// signals. These sequences verify that only an owned viewport gesture can turn
// those signals into look/selection; they do not simulate AppKit event delivery.
typealias Gesture = ViewportPointerGesture
typealias Point = SIMD2<Float>
typealias Origin = SIMD2<Double>
let start = Point(100, 80)
let origin = Origin(300, 220)
var checks = 0
var failures: [String] = []
var groups: [String] = []

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures.append(message) }
}
func group(_ name: String, _ body: () -> Void) {
    groups.append(name)
    body()
}
func begin(_ gesture: inout Gesture, _ button: Gesture.Button = .left,
           at point: Point = start, windowOrigin: Origin = origin, inside: Bool = true) {
    gesture.begin(button: button, point: point, windowOrigin: windowOrigin, insideViewport: inside)
}

for button: Gesture.Button in [.left, .right] {
    group("Orphan events: \(button)") {
        var gesture = Gesture()
        expect(gesture.drag(button: button, point: start + Point(20, 10), windowOrigin: origin) == nil,
               "An orphan \(button) drag must not produce look input")
        expect(gesture.end(button: button, point: start, windowOrigin: origin) == nil,
               "An orphan \(button) release must not select")
        expect(!gesture.isActive, "Orphan events must not acquire ownership")
    }
}

// Negative control for the previous unconditional mouseDragged forwarding:
// the same titlebar/window-background sequences contain nonzero event deltas.
// A receiver that forwards every delta would turn the camera; the new contract
// emits neither look nor selection for these rejected beginnings.
var legacyRejectedLookEvents = 0
var protectedRejectedLookEvents = 0
for region in ["native titlebar", "window background", "toolbar/control", "help overlay"] {
    group("Rejected begin: \(region)") {
        var gesture = Gesture()
        begin(&gesture, inside: false)
        expect(!gesture.isActive, "\(region) must not capture the pointer")
        var previous = start
        for point in [start + Point(12, 0), start + Point(25, 8), start + Point(15, 4)] {
            let eventDelta = point - previous
            if eventDelta != .zero { legacyRejectedLookEvents += 1 }
            if gesture.drag(button: .left, point: point, windowOrigin: origin) != nil {
                protectedRejectedLookEvents += 1
            }
            previous = point
        }
        expect(gesture.end(button: .left, point: start, windowOrigin: origin) == nil,
               "\(region) release must not accidentally select a landmark")
    }
}
expect(legacyRejectedLookEvents == 12 && protectedRejectedLookEvents == 0,
       "Rejected-region sequences must distinguish unconditional forwarding from owned gestures")
expect(Gesture.clickSlop == 4, "The user-facing click tolerance is four view points")

for offset in [Point.zero, Point(4, 0), Point(0, -4), Point(2, 2)] {
    group("Click inside four-point radius: \(offset)") {
        var gesture = Gesture()
        begin(&gesture)
        expect(gesture.isActive, "A valid viewport begin must own the pointer")
        expect(gesture.drag(button: .left, point: start + offset, windowOrigin: origin) == nil,
               "Motion within click tolerance must not turn the camera")
        expect(gesture.end(button: .left, point: start + offset, windowOrigin: origin) == start + offset,
               "An undragged left click must select at its release position")
        expect(!gesture.isActive, "Release must relinquish ownership")
        expect(gesture.end(button: .left, point: start + offset, windowOrigin: origin) == nil,
               "A duplicated release must not select twice")
    }
}

group("Small click jitter is not cumulative camera motion") {
    var gesture = Gesture()
    begin(&gesture)
    for offset in [Point(3, 0), Point(-3, 0), Point(0, 3), Point(0, -3), Point.zero] {
        expect(gesture.drag(button: .left, point: start + offset, windowOrigin: origin) == nil,
               "A jittering click inside the radius must not become a drag")
    }
    expect(gesture.end(button: .left, point: start, windowOrigin: origin) == start,
           "Jitter within the radius still permits exactly one selection")
}

for button: Gesture.Button in [.left, .right] {
    group("Intentional viewport drag: \(button)") {
        var gesture = Gesture()
        begin(&gesture, button)
        expect(gesture.drag(button: button, point: start + Point(3, 0), windowOrigin: origin) == nil,
               "Both buttons must honor click slop")
        expect(gesture.drag(button: button, point: start + Point(6, 2), windowOrigin: origin) == Point(3, 2),
               "An owned drag must emit local point delta after crossing slop")
        expect(gesture.drag(button: button, point: start + Point(8, -1), windowOrigin: origin) == Point(2, -3),
               "Subsequent intentional motion must retain its signed delta")
        expect(gesture.drag(button: button, point: start, windowOrigin: origin) == Point(-8, 1),
               "Returning to the start does not convert an established drag to a click")
        expect(gesture.end(button: button, point: start, windowOrigin: origin) == nil,
               "An established drag must never select at release")
        expect(!gesture.isActive, "Completed drag must not retain ownership")
    }
}

group("Radial rather than per-axis click tolerance") {
    var gesture = Gesture()
    begin(&gesture)
    expect(gesture.drag(button: .left, point: start + Point(3, 3), windowOrigin: origin) == Point(3, 3),
           "Diagonal displacement exceeding four points must become a drag")
    expect(gesture.end(button: .left, point: start + Point(3, 3), windowOrigin: origin) == nil,
           "Diagonal drag must not select")
}

group("Release semantics") {
    var gesture = Gesture()
    begin(&gesture, .right)
    expect(gesture.end(button: .right, point: start, windowOrigin: origin) == nil,
           "A stationary right click must not select")
    begin(&gesture)
    expect(gesture.end(button: .left, point: start + Point(10, 0), windowOrigin: origin) == nil,
           "A distant release with no intermediate motion event must not select")
    expect(!gesture.isActive, "Distant release must clear capture")
}

for wrongEventIsDrag in [true, false] {
    for owner: Gesture.Button in [.left, .right] {
        group("Mismatched button cancels: owner=\(owner), drag=\(wrongEventIsDrag)") {
            var gesture = Gesture()
            let other: Gesture.Button = owner == .left ? .right : .left
            begin(&gesture, owner)
            let result = wrongEventIsDrag
                ? gesture.drag(button: other, point: start + Point(8, 2), windowOrigin: origin)
                : gesture.end(button: other, point: start, windowOrigin: origin)
            expect(result == nil, "A different button must not act on captured ownership")
            expect(!gesture.isActive, "Mismatched event must cancel ownership")
            expect(gesture.end(button: owner, point: start, windowOrigin: origin) == nil,
                   "Old owner release after cancellation must not select")
        }
    }
}

group("A new begin resets earlier ownership") {
    var gesture = Gesture()
    begin(&gesture)
    _ = gesture.drag(button: .left, point: start + Point(7, 0), windowOrigin: origin)
    begin(&gesture, inside: false)
    expect(!gesture.isActive, "A new rejected begin must discard a stale capture")
    expect(gesture.drag(button: .left, point: start + Point(20, 0), windowOrigin: origin) == nil,
           "Rejected begin must not inherit old camera drag state")
    begin(&gesture, .right)
    expect(gesture.drag(button: .right, point: start + Point(5, 0), windowOrigin: origin) == Point(5, 0),
           "A subsequent valid begin must recover normally")
    _ = gesture.end(button: .right, point: start + Point(5, 0), windowOrigin: origin)
}

for translation in [Origin(80, 0), Origin(0, -40), Origin(0.5, 0.25)] {
    group("Native window translation: \(translation)") {
        var gesture = Gesture()
        begin(&gesture)
        expect(gesture.drag(button: .left, point: start, windowOrigin: origin + translation) == nil,
               "Window movement must cancel even when the pointer's local coordinates are unchanged")
        expect(!gesture.isActive, "Native translation must relinquish capture")
        expect(gesture.end(button: .left, point: start, windowOrigin: origin + translation) == nil,
               "Window-move release must not select")
        expect(gesture.drag(button: .left, point: start + Point(10, 0), windowOrigin: origin) == nil,
               "Returning the window must not resurrect a cancelled drag")
        begin(&gesture)
        _ = gesture.drag(button: .left, point: start + Point(8, 0), windowOrigin: origin)
        expect(gesture.drag(button: .left, point: start + Point(8, 0), windowOrigin: origin + translation) == nil,
               "Native translation must also cancel an established camera drag")
        expect(gesture.end(button: .left, point: start, windowOrigin: origin) == nil,
               "Cancelled established drag must not later select")
        begin(&gesture)
        expect(gesture.end(button: .left, point: start, windowOrigin: origin + translation) == nil,
               "Window movement first observed on release must also reject selection")
    }
}

for value: Float in [.nan, .infinity, -.infinity] {
    for point in [Point(value, 1), Point(1, value)] {
        group("Invalid pointer coordinate: \(point)") {
            var gesture = Gesture()
            begin(&gesture, at: point)
            expect(!gesture.isActive, "Nonfinite begin coordinates must be rejected")
            begin(&gesture)
            expect(gesture.drag(button: .left, point: point, windowOrigin: origin) == nil,
                   "Nonfinite drag coordinates must not enter camera math")
            expect(!gesture.isActive, "Invalid drag must cancel rather than preserve stale ownership")
            begin(&gesture)
            expect(gesture.end(button: .left, point: point, windowOrigin: origin) == nil,
                   "Nonfinite release must not select")
        }
    }
}
for value: Double in [.nan, .infinity, -.infinity] {
    for badOrigin in [Origin(value, 1), Origin(1, value)] {
        group("Invalid window origin: \(badOrigin)") {
            var gesture = Gesture()
            begin(&gesture, windowOrigin: badOrigin)
            expect(!gesture.isActive, "Nonfinite window origin must reject a begin")
            begin(&gesture)
            expect(gesture.drag(button: .left, point: start + Point(8, 0), windowOrigin: badOrigin) == nil,
                   "Nonfinite window origin must reject camera movement")
            expect(!gesture.isActive, "Invalid window origin must cancel ownership")
        }
    }
}

for axis in 0..<2 {
    group("Finite input subtraction overflow: axis \(axis)") {
        var extreme = Point.zero
        extreme[axis] = Float.greatestFiniteMagnitude
        var gesture = Gesture()
        begin(&gesture, at: -extreme)
        expect(gesture.drag(button: .left, point: extreme, windowOrigin: origin) == nil,
               "Finite endpoints whose displacement overflows must not emit infinity")
        expect(!gesture.isActive, "Displacement overflow must cancel ownership")
        expect(gesture.end(button: .left, point: -extreme, windowOrigin: origin) == nil,
               "Cancelled overflow sequence must not select when returning to its start")

        begin(&gesture, at: .zero)
        expect(gesture.drag(button: .left, point: extreme, windowOrigin: origin) == extreme,
               "A representable signed delta remains valid despite a large squared distance")
        expect(gesture.drag(button: .left, point: -extreme, windowOrigin: origin) == nil,
               "Previous-point delta overflow must be rejected even when start displacement is finite")
        expect(!gesture.isActive, "Previous-point overflow must cancel ownership")

        begin(&gesture, at: -extreme)
        _ = gesture.drag(button: .left, point: .zero, windowOrigin: origin)
        expect(gesture.drag(button: .left, point: extreme, windowOrigin: origin) == nil,
               "Start displacement overflow must be rejected even when the incremental delta is finite")
        expect(!gesture.isActive, "Start displacement overflow must cancel ownership")
        begin(&gesture, at: -extreme)
        expect(gesture.end(button: .left, point: extreme, windowOrigin: origin) == nil,
               "A finite distant release whose subtraction overflows must not select")
    }
}

for lifecycle in ["mouse exit/release loss", "window resigns key", "first responder resigns",
                  "Escape", "live resize", "fullscreen transition", "window move", "view detached"] {
    group("Lifecycle cancellation: \(lifecycle)") {
        var gesture = Gesture()
        begin(&gesture)
        gesture.cancel()
        gesture.cancel()
        expect(!gesture.isActive, "Cancellation must be idempotent for \(lifecycle)")
        expect(gesture.drag(button: .left, point: start + Point(20, 0), windowOrigin: origin) == nil,
               "Cancelled \(lifecycle) gesture must not look")
        expect(gesture.end(button: .left, point: start, windowOrigin: origin) == nil,
               "Cancelled \(lifecycle) gesture must not select")
        begin(&gesture)
        expect(gesture.end(button: .left, point: start, windowOrigin: origin) == start,
               "Fresh click must work following \(lifecycle)")
    }
}

group("Shift-left drag rotation keeps ordinary pan and right look") {
    expect(Gesture.action(button:.left,shift:false) == .pan, "Ordinary left drag must pan")
    expect(Gesture.action(button:.left,shift:true) == .look, "Shift-left drag must rotate")
    expect(Gesture.action(button:.right,shift:false) == .look, "Right drag must retain rotation")
    expect(Gesture.action(button:.right,shift:true) == .look, "Shift must not turn right drag into pan")
}
group("Map mode allows only pan, zoom, explicit exit and display controls") {
    for shift in [false,true] {
        expect(Gesture.action(button:.left,shift:shift,mapMode:true) == .pan,"Map left drag pans even with Shift held")
        expect(Gesture.action(button:.right,shift:shift,mapMode:true) == .ignore,"Map right drag cannot tilt or orbit")
    }
    let allowed:Set<UInt16> = [13,0,1,2,5,11,53,46,15,45,4,44,27,78,24,69]
    for code:UInt16 in 0...126 {
        expect(Gesture.allowsKey(code,mapMode:true) == allowed.contains(code),"Map keyboard routing \(code) cannot invoke ordinary camera controls")
        expect(Gesture.allowsKey(code,mapMode:false),"Normal mode retains existing key routing \(code)")
    }
}
let passed = failures.isEmpty
let report: [String: Any] = [
    "passed": passed, "checks": checks, "sequenceGroups": groups,
    "failures": failures,
    "negativeControl": ["legacyUnconditionalLookEvents": legacyRejectedLookEvents,
                        "ownedGestureLookEvents": protectedRejectedLookEvents],
    "scope": "CPU pointer ownership contract; AppKit hit-testing/event delivery and native-window smoke tests are separate validation."
]
if let index = CommandLine.arguments.firstIndex(of: "--json"), index + 1 < CommandLine.arguments.count {
    let url = URL(fileURLWithPath: CommandLine.arguments[index + 1])
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}
print("Viewport input \(passed ? "PASS" : "FAIL"): \(checks) checks across \(groups.count) event sequences; rejected-drag control \(legacyRejectedLookEvents) → \(protectedRejectedLookEvents).")
for failure in failures { fputs("FAIL: \(failure)\n", stderr) }
if !passed { exit(1) }
