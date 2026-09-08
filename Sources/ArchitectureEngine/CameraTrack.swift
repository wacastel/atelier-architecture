import Foundation
import simd

/// Time-based Hermite interpolation with monotone tangents. Each coordinate
/// remains within its two adjacent keys; tight doorways never gain spline overshoot.
struct CameraTrack {
    struct Key {
        let seconds: Double
        let pose: CameraPose
        init(_ seconds: Double, _ position: SIMD3<Float>, _ target: SIMD3<Float>, _ fov: Float = 60) {
            self.seconds = seconds; pose = CameraPose(position: position, target: target, fov: fov)
        }
    }
    let keys: [Key]
    func pose(at seconds: Double) -> CameraPose {
        precondition(keys.count >= 2)
        let time = seconds.isFinite ? seconds : 0
        if time <= keys[0].seconds { return keys[0].pose }
        if time >= keys.last!.seconds { return keys.last!.pose }
        let right = keys.firstIndex(where: { $0.seconds >= time })!, left = right - 1
        let span = Float(keys[right].seconds - keys[left].seconds)
        let t = Float(time - keys[left].seconds) / span
        func value(_ extract: (CameraPose) -> Float) -> Float {
            func secant(_ i: Int) -> Float {
                (extract(keys[i+1].pose) - extract(keys[i].pose)) / Float(keys[i+1].seconds - keys[i].seconds)
            }
            func tangent(_ i: Int) -> Float {
                if i == 0 { return secant(0) }
                if i == keys.count - 1 { return secant(i-1) }
                let a=secant(i-1), b=secant(i)
                if a*b <= 0 { return 0 }
                let before=Float(keys[i].seconds-keys[i-1].seconds),after=Float(keys[i+1].seconds-keys[i].seconds)
                let w1=2*after+before,w2=after+2*before
                return (w1+w2)/(w1/a+w2/b)
            }
            let a=extract(keys[left].pose),b=extract(keys[right].pose),t2=t*t,t3=t2*t
            return (2*t3-3*t2+1)*a+(t3-2*t2+t)*span*tangent(left)+(-2*t3+3*t2)*b+(t3-t2)*span*tangent(right)
        }
        return CameraPose(position:SIMD3(value{$0.position.x},value{$0.position.y},value{$0.position.z}),target:SIMD3(value{$0.target.x},value{$0.target.y},value{$0.target.z}),fov:value{$0.fov})
    }
}
