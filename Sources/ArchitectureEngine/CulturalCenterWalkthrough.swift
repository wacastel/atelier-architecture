import Foundation
import simd

enum CulturalCenterWalkthrough {
    static let duration = 120.0
    static let flybyView = 7
    static let walkingViews: Set<Int> = [1,2,3,4,5,6]
    private typealias V = SIMD3<Float>
    private typealias K = CameraTrack.Key

    static func pose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0,min(7,view)), start = CulturalCenterScene.stops[index].pose
        let time = max(0,min(duration,seconds.isFinite ? seconds : 0))
        if time == 0 { return start }
        func local(_ t: Double, _ p: V, _ target: V, _ fov: Float = 70) -> K {
            K(t,CulturalCenterLayout.point(p),CulturalCenterLayout.point(target),fov)
        }
        var keys = [K(0,start.position,start.target,start.fov)]
        switch index {
        case 0:
            keys += [local(30,V(44,27,50),V(0,15,13),61),local(60,V(48,30,5),V(0,17,0),60),
                     local(90,V(48,35,-52),V(0,17,-25),61),local(120,V(45,42,-75),V(0,17,-30),62)]
        case 1,2:
            let path = index == 1 ? CulturalCenterLayout.washingtonEyePath : CulturalCenterLayout.mosaicStairEyePath
            var lengths = [Float](repeating:0,count:path.count)
            for i in 1..<path.count { lengths[i] = lengths[i-1]+simd_distance(path[i-1],path[i]) }
            let total = max(0.01,lengths.last!)
            for i in 1..<path.count {
                let t = Double(lengths[i]/total)*duration
                let target: V
                if i == path.count-1 {
                    target = CulturalCenterLayout.point(index == 1 ? V(0,7,43):V(0,18,29))
                } else {
                    let ahead = path[min(path.count-1,i+2)]-path[i]
                    target = path[i]+simd_normalize(ahead)*5+V(0,0.65,0)
                }
                keys.append(K(t,path[i],target,index == 1 ? 68:72))
            }
        case 3:
            keys += [local(30,V(0,13.55,29.5),V(0.6,24,29),69),local(60,V(0,13.55,33.5),V(0.6,23.8,29),70),
                     local(90,V(0,13.55,30.5),V(0.6,24.5,29),71),local(120,V(0,13.55,26),V(0.6,23.5,29),70)]
        case 4:
            keys += [local(30,V(15,13.55,29),V(0,17,29),73),local(60,V(14,13.55,24),V(0,18,29),73),
                     local(90,V(10.5,13.55,27),V(0,16,32),74),local(120,V(12,13.55,33.5),V(0,18,29),74)]
        case 5:
            keys += [local(30,V(2.5,13.55,-32),V(0.5,22.7,-29),72),local(60,V(2.5,13.55,-26),V(0.5,22.7,-29),71),
                     local(90,V(-2.5,13.55,-26),V(0.5,22.7,-29),72),local(120,V(-2.5,13.55,-31),V(0.5,21.5,-29),73)]
        case 6:
            keys += [local(30,V(-1,13.55,-47.5),V(6.5,17,-44),73),local(60,V(11,13.55,-47.5),V(6.5,17,-44),72),
                     local(90,V(17,13.55,-43),V(6.5,17,-44),73),local(120,V(10,13.55,-39),V(6.5,17,-46),73)]
        default:
            keys += [K(18,V(1007,22,-425),V(1042.46,7.7,-424.15),57),
                     K(38,V(1010,45,-475),CulturalCenterLayout.point(V(0,15,0)),60),
                     K(62,V(1010,55,-560),CulturalCenterLayout.point(V(0,17,0)),61),
                     K(86,V(972,45,-495),CulturalCenterLayout.point(V(0,16,15)),62),
                     K(103,V(966,30,-464),CulturalCenterLayout.point(V(0,15,15)),62),
                     K(120,CulturalCenterScene.stops[0].pose.position,CulturalCenterScene.stops[0].pose.target,CulturalCenterScene.stops[0].pose.fov)]
        }
        return CameraTrack(keys:keys).pose(at:time)
    }

    static func idlePose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0,min(7,view)), start = CulturalCenterScene.stops[index].pose
        let t = Float(max(0,seconds.isFinite ? seconds.truncatingRemainder(dividingBy:86_400):0))
        if index == 0 {
            let offset = start.position-start.target, angle = sin(t*0.016)*0.025
            let c = cos(angle), s = sin(angle)
            return CameraPose(position:start.target+V(offset.x*c+offset.z*s,offset.y,offset.z*c-offset.x*s),target:start.target,fov:start.fov)
        }
        var result = start
        let forward = simd_normalize(start.target-start.position)
        let right = simd_normalize(simd_cross(forward,V(0,1,0)))
        let amount: Float = index == flybyView ? 0.5:0.04
        result.position += right*sin(t*0.025)*amount
        result.target += right*sin(t*0.019)*amount*0.15
        result.fov -= sin(t*0.018)*0.30
        return result
    }
}
