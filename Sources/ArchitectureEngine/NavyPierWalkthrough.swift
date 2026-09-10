import Foundation
import simd

enum NavyPierWalkthrough {
    static let flybyView = 7
    static let walkingViews: Set<Int> = []
    static func duration(view: Int) -> Double { view == flybyView ? 180 : 120 }
    private typealias V = SIMD3<Float>
    private typealias K = CameraTrack.Key
    private static func key(_ t: Double, _ p: V, _ target: V, _ fov: Float) -> K {
        K(t,NavyPierLayout.point(p),NavyPierLayout.point(target),fov)
    }
    static func pose(view: Int, seconds: Double) -> CameraPose {
        let index=max(0,min(7,view)),start=NavyPierScene.stops[index].pose
        let t=max(0,min(duration(view:index),seconds.isFinite ? seconds:0))
        if t == 0 { return start }
        var keys=[K(0,start.position,start.target,start.fov)]
        switch index {
        case 0:
            keys += [key(40,V(710,190,500),V(280,15,0),60),key(80,V(460,180,570),V(280,15,0),60),key(120,V(180,165,570),V(280,15,0),62)]
        case 1:
            keys += [key(40,V(-50,34,105),V(0,37,0),54),key(80,V(30,44,106),V(0,37,0),53),key(120,V(88,54,100),V(0,37,0),55)]
        case 2:
            keys += [key(40,V(-263,15,89),V(-165,12,0),62),key(80,V(-218,12,96),V(-149,12,0),61),key(120,V(-150,17,105),V(-114,14,0),62)]
        case 3:
            keys += [key(40,V(110,8,95),V(133,18,42),63),key(80,V(166,9,99),V(145,18,42),62),key(120,V(210,14,110),V(145,20,42),64)]
        case 4:
            keys += [key(40,V(345,14,111),V(390,18,43),63),key(80,V(435,17,108),V(441,20,43),62),key(120,V(528,22,110),V(478,20,43),64)]
        case 5:
            keys += [key(40,V(755,19,42),V(669.8,17,-1.2),57),key(80,V(752,13,-39),V(669.8,17,-1.2),57),key(120,V(706,20,-94),V(669.8,18,-1.2),60)]
        case 6:
            keys += [key(40,V(242,19,-171),V(118,0,-112),64),key(80,V(109,21,-170),V(10,0,-105),62),key(120,V(-30,30,-173),V(0,30,0),62)]
        default:
            let end=NavyPierScene.stops[0].pose
            keys += [K(25,V(1480,180,-245),V(1210,24,-490),60),K(55,V(1910,130,-390),V(2050,20,-880),62),
                     K(95,V(2320,115,-690),V(2390,30,-1430),62),K(135,V(2340,135,-955),V(2480,20,-1430),61),
                     K(180,end.position,end.target,end.fov)]
        }
        return CameraTrack(keys:keys).pose(at:t)
    }
    static func idlePose(view: Int, seconds: Double) -> CameraPose {
        let index=max(0,min(7,view))
        if index == flybyView { return MillenniumWalkthrough.idlePose(view:0,seconds:seconds) }
        let start=NavyPierScene.stops[index].pose
        let t=Float(max(0,seconds.isFinite ? seconds.truncatingRemainder(dividingBy:86400):0))
        let offset=start.position-start.target,angle=sin(t*0.015)*0.009
        let c=cos(angle),s=sin(angle)
        return CameraPose(position:start.target+V(offset.x*c+offset.z*s,offset.y,offset.z*c-offset.x*s),target:start.target,fov:start.fov-sin(t*0.018)*0.3)
    }
}
