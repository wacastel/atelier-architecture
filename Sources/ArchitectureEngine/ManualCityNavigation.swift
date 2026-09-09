import Foundation
import simd

/// View-point input and wall-clock flight math, independent of AppKit/Metal.
enum ManualCityNavigation {
    static let flySpeeds: [Float] = [8, 30, 80, 180, 400, 800]
    static let defaultFlySpeed: Float = 400

    static func nearestSpeed(_ speed: Float) -> Float {
        guard speed.isFinite else { return defaultFlySpeed }
        return flySpeeds.min { abs($0-speed) < abs($1-speed) }!
    }
    static func verticalDirection(keys: Set<UInt16>) -> Float {
        (keys.contains(12) ? 1 : 0) - (keys.contains(14) ? 1 : 0)
    }
    /// Map dragging translates eye and target together and stays in the modeled corridor.
    static func mapTranslation(camera: SIMD2<Float>, requested: SIMD2<Float>) -> SIMD2<Float> {
        guard finite(camera), finite(requested) else { return .zero }
        let destination = camera + requested
        guard finite(destination) else { return .zero }
        // Free flight can start beyond coverage. Permit gradual movement back
        // without snapping against the drag or moving farther outside the city.
        let lower = simd_min(camera, SIMD2(-4000,-11500))
        let upper = simd_max(camera, SIMD2(6000,11000))
        let bounded = simd_clamp(destination, lower, upper)
        return bounded-camera
    }

    static func frameSeconds(_ elapsed: Double) -> Float {
        elapsed.isFinite ? Float(max(0, min(0.5, elapsed))) : 0
    }
    static func steppedSpeed(_ speed: Float, direction: Int) -> Float {
        guard speed.isFinite else { return defaultFlySpeed }
        if direction > 0 { return flySpeeds.first { $0 > speed + 0.01 } ?? flySpeeds.last! }
        return flySpeeds.last { $0 < speed - 0.01 } ?? flySpeeds.first!
    }
    static func displacement(direction: SIMD3<Float>, speed: Float, seconds: Float, boosted: Bool) -> SIMD3<Float> {
        guard finite(direction), speed.isFinite, seconds.isFinite,
              simd_length_squared(direction) > 0.000001, seconds > 0 else { return .zero }
        return simd_normalize(direction) * max(0, min(800, speed)) * min(0.5, seconds) * (boosted ? 3 : 1)
    }

    static func overview(point: SIMD2<Float>, heading input: SIMD3<Float>, roof: (Float,Float) -> Float) -> CameraPose? {
        guard finite(point), point.x >= -4000, point.x <= 6000, point.y >= -11500, point.y <= 11000 else { return nil }
        var heading = SIMD3(input.x,0,input.z)
        if !finite(heading) || simd_length_squared(heading) < 0.001 { heading = SIMD3(0,0,-1) }
        heading = simd_normalize(heading)
        let surface = roof(point.x,point.y)
        guard surface.isFinite else { return nil }
        let target = SIMD3(point.x,surface+4,point.y)
        var position = target-heading*180+SIMD3(0,150,0), ceiling = roof(target.x-heading.x*180,target.z-heading.z*180)
        guard ceiling.isFinite else { return nil }
        for offset in [SIMD2<Float>(-12,-12),SIMD2(12,-12),SIMD2(-12,12),SIMD2(12,12)] {
            let height = roof(position.x+offset.x,position.z+offset.y)
            guard height.isFinite else { return nil }
            ceiling = max(ceiling,height)
        }
        position.y = max(position.y,ceiling+40)
        return CameraPose(position:position,target:target,fov:60)
    }

    /// Grab the horizontal map plane: the same world point stays under the
    /// pointer after translation. A bounded screen-basis fallback handles sky.
    static func pan(pose: CameraPose, from: SIMD2<Float>, to: SIMD2<Float>, viewport: SIMD2<Float>, planeY: Float = 0) -> SIMD3<Float>? {
        guard finite(pose.position), finite(pose.target), finite(from), finite(to), finite(viewport),
              viewport.x > 0, viewport.y > 0, planeY.isFinite, pose.fov.isFinite,
              pose.fov > 1, pose.fov < 150, simd_length_squared(pose.target-pose.position) > 0.000001 else { return nil }
        let forward = simd_normalize(pose.target-pose.position)
        var right = simd_cross(forward, SIMD3<Float>(0,1,0))
        if simd_length_squared(right) < 0.0001 { right = SIMD3(1,0,0) }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(right,forward)), tangent = tan(pose.fov * .pi / 360)
        func intersection(_ point: SIMD2<Float>) -> SIMD3<Float>? {
            let normalized = point / viewport
            let ray = forward + right * ((normalized.x*2-1)*tangent*viewport.x/viewport.y) - up * ((normalized.y*2-1)*tangent)
            guard abs(ray.y) > 0.03 else { return nil }
            let t = (planeY-pose.position.y)/ray.y, result = pose.position+ray*t
            return t > 0 && finite(result) && simd_distance(result,pose.position) < 20_000 ? result : nil
        }
        if let a = intersection(from), let b = intersection(to) {
            let delta = a-b
            if simd_length(delta) <= 2_000 { return SIMD3(delta.x,0,delta.z) }
        }
        var flatForward = SIMD3(forward.x,0,forward.z)
        if simd_length_squared(flatForward) < 0.0001 { flatForward = SIMD3(0,0,-1) }
        flatForward = simd_normalize(flatForward)
        let flatRight = simd_normalize(simd_cross(flatForward,SIMD3(0,1,0)))
        let distance = max(10,min(2_000,abs(pose.position.y-planeY)/max(0.2,abs(forward.y))))
        let scale = 2*tangent*distance/viewport.y, pixels = to-from
        let delta = (-flatRight*pixels.x+flatForward*pixels.y)*scale
        return finite(delta) ? delta : nil
    }
    private static func finite(_ p: SIMD2<Float>) -> Bool { p.x.isFinite && p.y.isFinite }
    private static func finite(_ p: SIMD3<Float>) -> Bool { p.x.isFinite && p.y.isFinite && p.z.isFinite }
}
