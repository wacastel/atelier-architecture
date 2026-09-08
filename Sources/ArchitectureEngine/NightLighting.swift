import Foundation
import simd

/// A photographic reconstruction of the golden illumination, not an as-built
/// photometric survey. The 336 tower sources follow the published interior-uplight
/// principle; see docs/NIGHT.md for references and renderer-unit calibration.
enum NightLighting {
    typealias V = SIMD3<Float>
    static let sodium = V(1.0, 0.50, 0.15)

    static func source(_ position: V, toward target: V? = nil, power: Float,
                       color: V = sodium, range: Float = 42, radius: Float = 0.18,
                       outerDegrees: Float = 80, innerDegrees: Float = 48,
                       alwaysOn: Bool = false) -> SceneLight {
        let direction = target.map { simd_normalize($0-position) } ?? V(0,-1,0)
        return SceneLight(positionRadius: SIMD4(position,radius),
                          directionCone: SIMD4(direction,target == nil ? -1 : cos(outerDegrees * .pi / 180)),
                          colorPower: SIMD4(color,power),
                          parameters: SIMD4(range,cos(innerDegrees * .pi / 180),alwaysOn ? 1 : 0,0))
    }

    static func tower(section: (Float) -> (outer: Float, width: Float)) -> [SceneLight] {
        var lights: [SceneLight] = []
        let directions = [V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)]
        // Four projectors inside each of the four open piers in every truss bay.
        // Aim across and upward through the bay, preserving unlit side faces.
        let levels: [Float] = [2.3,8,14,20,26,32,38,44,50,56,64,72,81,91,102,113.5]
        for sx: Float in [-1,1] { for sz: Float in [-1,1] {
            for i in 0..<levels.count-1 {
                let y = levels[i]+0.65, nextY = levels[i+1]-0.4
                let s = section(y), t = section(nextY)
                let center = V(sx*(s.outer-s.width/2),y,sz*(s.outer-s.width/2))
                let target = V(sx*(t.outer-t.width/2),(y+nextY)*0.5,sz*(t.outer-t.width/2))
                for d in directions {
                    let p = center+d*s.width*0.10
                    lights.append(source(p,toward:target+d*t.width*0.53,
                                         power:y < 57 ? 460 : 300, range:y < 57 ? 42 : 31,
                                         outerDegrees:86,innerDegrees:58))
                }
            }
        }}
        // Four upward-facing sources per upper bay, in the hollow core.
        for i in 0..<22 {
            let y: Float = 118+Float(i)*7
            let s = section(y).outer, top = section(y+5).outer
            for d in directions {
                let p = d*max(1.1,s*0.35)+V(0,y,0)
                lights.append(source(p,toward:d*top+V(0,y+4.5,0),
                                     power:360+max(0,s-5)*35,range:27,
                                     outerDegrees:86,innerDegrees:59))
            }
        }
        for y: Float in [282,298] {
            for d in directions {
                lights.append(source(d*2.0+V(0,y,0),toward:V(0,y+15,0),power:240,range:36))
            }
        }
        precondition(lights.count == 336)
        // The arches and terrace fascia need the same grazing illumination as
        // the photos. These are separate architectural accent fixtures.
        for d in directions {
            let tangent = V(-d.z,0,d.x)
            for t: Float in [-0.8,-0.4,0,0.4,0.8] {
                let x = t*40, y = 8.5+34.5*sqrt(max(0,1-pow(x/43,2)))
                let outer = section(y).outer
                let p = tangent*x+d*(outer-4.2)+V(0,y-3.6,0)
                lights.append(source(p,toward:tangent*x+d*(outer-1.2)+V(0,y+3.0,0),
                                     power:190,range:22,outerDegrees:84,innerDegrees:56))
            }
            for (y,r): (Float,Float) in [(57,36.5),(115,21.5),(276,8.5)] {
                for t: Float in [-0.6,0.0,0.6] {
                    let p = d*(r+0.75)+tangent*(t*r)+V(0,y-3.2,0)
                    lights.append(source(p,toward:p-d*1.3+V(0,4,0),power:145,range:18))
                }
            }
        }
        return lights
    }
}
