import Foundation

/// A camera gesture belongs to the viewport only when its matching mouse-down
/// began there. Window translation cancels ownership instead of becoming look input.
struct ViewportPointerGesture {
    enum Button { case left, right }
    enum Action { case pan, look }
    static func action(button: Button, shift: Bool) -> Action {
        button == .right || shift ? .look : .pan
    }
    private struct Capture {
        var button: Button
        var origin: SIMD2<Double>
        var start: SIMD2<Float>
        var previous: SIMD2<Float>
        var dragged = false
    }
    private var capture: Capture?
    var isActive: Bool { capture != nil }
    static let clickSlop: Float = 4

    mutating func begin(button: Button, point: SIMD2<Float>, windowOrigin: SIMD2<Double>, insideViewport: Bool) {
        capture = nil
        guard insideViewport, valid(point), windowOrigin.x.isFinite, windowOrigin.y.isFinite else { return }
        capture = Capture(button: button, origin: windowOrigin, start: point, previous: point)
    }
    mutating func drag(button: Button, point: SIMD2<Float>, windowOrigin: SIMD2<Double>) -> SIMD2<Float>? {
        guard var current = matching(button, point, windowOrigin) else { return nil }
        let displacement = point - current.start
        current.dragged = current.dragged || displacement.x * displacement.x + displacement.y * displacement.y > Self.clickSlop * Self.clickSlop
        let delta = point - current.previous
        guard valid(delta), valid(displacement) else { capture = nil; return nil }
        current.previous = point
        capture = current
        return current.dragged ? delta : nil
    }
    /// Only an un-dragged left click selects a landmark. Right drags retain look/orbit.
    mutating func end(button: Button, point: SIMD2<Float>, windowOrigin: SIMD2<Double>) -> SIMD2<Float>? {
        let current = matching(button, point, windowOrigin)
        capture = nil
        guard let current, button == .left, !current.dragged else { return nil }
        let delta = point - current.start
        return delta.x * delta.x + delta.y * delta.y <= Self.clickSlop * Self.clickSlop ? point : nil
    }
    mutating func cancel() { capture = nil }
    private mutating func matching(_ button: Button, _ point: SIMD2<Float>, _ origin: SIMD2<Double>) -> Capture? {
        guard let current = capture else { return nil }
        guard current.button == button, valid(point), origin == current.origin else { capture = nil; return nil }
        return current
    }
    private func valid(_ point: SIMD2<Float>) -> Bool { point.x.isFinite && point.y.isFinite }
}
