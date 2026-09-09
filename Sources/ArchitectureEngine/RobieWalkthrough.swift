import Foundation
import simd

enum RobieWalkthrough {
    static let flybyView = 7
    static let walkingViews: Set<Int> = [2,3,4,5]
    private typealias V = SIMD3<Float>
    private typealias K = CameraTrack.Key
    static func duration(view: Int) -> Double { view == flybyView ? 360 : 120 }
    static func pose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0,min(7,view)), start = RobieScene.stops[index].pose
        let time = max(0,min(duration(view:index),seconds.isFinite ? seconds : 0))
        if time == 0 { return start }
        let at: (V) -> V = RobieHouseLayout.point
        func local(_ t: Double, _ p: V, _ target: V, _ fov: Float = 65) -> K { K(t,at(p),at(target),fov) }
        var keys = [K(0,start.position,start.target,start.fov)]
        switch index {
        case 0:
            keys += [local(24,V(-26,10,15),V(-6,4,0),61),local(48,V(-12,9,20),V(0,4,0),59),
                     local(72,V(7,10,22),V(0,4,0),60),local(96,V(25,11,18),V(2,4,0),62),
                     local(120,V(22,16,28),V(0,4,0),63)]
        case 1:
            keys += [local(25,V(-24,5.4,-3),V(-12,5,0),63),local(50,V(-27,6,4),V(-13,5.3,0),64),
                     local(75,V(-25,6,9),V(-11,5.5,1),63),local(100,V(-20,6,11),V(-11,5,1),64),
                     local(120,V(-18,5.5,11),V(-8,4.5,2),65)]
        case 2:
            keys += [local(30,V(-4,1.9,9.5),V(-1,2.7,3.5),65),local(60,V(0,1.9,9.5),V(4,2.8,3.2),64),
                     local(90,V(5,1.9,9.5),V(9,2.5,3.5),66),local(120,V(9,1.9,9.5),V(6,4.1,3.2),67)]
        case 3:
            keys += [local(30,V(-4,4.85,4.25),V(-1,4.9,3.15),64),local(60,V(-1,4.85,4.25),V(2,4.9,3.15),64),
                     local(90,V(3,4.85,4.25),V(7,4.9,3.15),64),local(120,V(8,4.85,4.25),V(10,4.7,2.5),66)]
        case 4:
            keys += [local(30,V(-5.8,4.85,1.9),V(0.8,4.6,-0.1),76),local(60,V(-2.3,4.85,1.9),V(0.8,4.7,-0.1),74),
                     local(90,V(-4.7,4.85,1.9),V(-10,4.8,0),76),local(120,V(-8.6,4.85,1.5),V(-12,4.8,0),73)]
        case 5:
            keys += [local(30,V(5.8,4.85,1.9),V(0.8,4.6,-0.1),75),local(60,V(3.3,4.85,1.9),V(8,4.6,-0.6),76),
                     local(90,V(6.4,4.85,1.9),V(12,4.8,0),75),local(120,V(10,4.85,1.65),V(7,4.9,-0.3),74)]
        case 6:
            keys += [local(30,V(5,18,20),V(0,6,-1),62),local(60,V(-12,18,17),V(0,6,-1),63),
                     local(90,V(-22,16,12),V(0,6,-1),63),local(120,V(-20,22,22),V(2,6,-2),64)]
        default:
            // Geographic keys are reconciled with the frozen Hyde Park map extract.
            keys += [K(24,V(2450,185,3250),V(1950,25,3000),66),
                     K(60,V(2880,135,4480),V(2662,-3,4773),66),
                     K(90,V(2910,100,4850),V(2662,-3,4773),67),
                     K(135,V(3590,150,6500),V(3408,0,6621),66),
                     K(185,V(4020,150,7490),V(3822,4,7356),67),
                     K(235,V(5110,95,9060),V(4925,0,9237),65),
                     K(270,V(4880,100,9610),V(4618,0,9560),66),
                     K(300,V(4270,105,9720),V(3850,15,9740),66),
                     K(324,V(3580,95,9730),V(3271,12,9838),65),
                     K(345,at(V(-35,38,17)),at(V(0,4,0)),63),
                     K(360,RobieScene.stops[0].pose.position,RobieScene.stops[0].pose.target,RobieScene.stops[0].pose.fov)]
        }
        return CameraTrack(keys:keys).pose(at:time)
    }
    static func idlePose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0,min(7,view)), t = Float(max(0,seconds.isFinite ? seconds : 0))
        let start = RobieScene.stops[index].pose
        if index == 0 {
            let offset = start.position-start.target, angle = sin(t*0.019)*0.075
            let c = cos(angle), s = sin(angle)
            return CameraPose(position:start.target+V(offset.x*c+offset.z*s,offset.y,offset.z*c-offset.x*s),target:start.target,fov:start.fov)
        }
        var p = start
        let forward = simd_normalize(p.target-p.position), right = simd_normalize(simd_cross(forward,V(0,1,0)))
        let amplitude: Float = walkingViews.contains(index) ? 0.07 : index == flybyView ? 4 : 0.6
        p.position += right*sin(t*0.03)*amplitude
        p.target += right*sin(t*0.021)*amplitude*0.16
        p.fov -= sin(t*0.025)*0.35
        return p
    }
}
