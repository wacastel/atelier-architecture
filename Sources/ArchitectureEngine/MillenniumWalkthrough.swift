import Foundation
import simd

enum MillenniumWalkthrough {
    static let flybyView = 7
    static let walkingViews: Set<Int> = [2, 3, 4]
    static func duration(view: Int) -> Double { view == flybyView ? 240 : 56 }
    private typealias V = SIMD3<Float>
    private typealias K = CameraTrack.Key
    static func pose(view: Int, seconds: Double) -> CameraPose {
        let index=max(0,min(MillenniumScene.stops.count-1,view)),start=MillenniumScene.stops[index].pose
        let t=max(0,min(duration(view:index),seconds.isFinite ? seconds:0))
        if t == 0 { return start }
        if index == 1 {
            let center=V(1042.46,7.7,-424.15),offset=start.position-center,angle=Float(t/56)*2 * .pi
            return CameraPose(position:center+V(offset.x*cos(angle)+offset.z*sin(angle),offset.y+1.2*pow(sin(angle/2),2),offset.z*cos(angle)-offset.x*sin(angle)),target:center,fov:start.fov)
        }
        var keys=[K(0,start.position,start.target,start.fov)]
        switch index {
        case 0:
            keys += [K(18,V(1270,150,-382),V(1095,14,-440),58),K(36,V(1190,135,-620),V(1085,9,-418),62),K(56,V(1060,115,-634),V(1125,12,-417),64)]
        case 2:
            keys += [K(18,V(1037,4.75,-424.15),V(1042.46,8.0,-424.15),75),K(32,V(1042.46,4.75,-424.15),V(1043,8.5,-424.0),88),K(43,V(1048,4.75,-424.15),V(1042.46,7.5,-424.15),79),K(56,V(1056,4.75,-424.15),V(1042.46,7.3,-424.15),67)]
        case 3:
            keys += [K(19,V(1164,2,-376),V(1165,21,-512),64),K(38,V(1164,2,-406),V(1165,26,-512),68),K(56,V(1164,2,-438),V(1165,20,-512),70)]
        case 4:
            keys += [K(20,V(997,2,-296),V(1008,8,-316.3),61),K(38,V(997,2,-304),V(1009,7,-265.6),68),K(56,V(997,2,-277),V(1008,9,-316.3),67)]
        case 5:
            keys += [K(20,V(1202,16,-281),V(1155,4,-288),62),K(38,V(1177,16,-314),V(1126,7,-261),61),K(56,V(1146,17,-275),V(1130,17,-183),63)]
        case 6:
            keys += [K(18,V(950,7,-98),V(989,10,-77),63),K(36,V(964,5,-76),V(994,7,-77),68),K(56,V(978,5,-76),V(1002,7,-77),68)]
        default:
            keys += [K(15,V(-320,545,230),V(0,320,0),54),K(42,V(190,540,120),V(900,60,-325),62),K(68,V(720,450,-125),V(1090,0,-420),60),K(88,V(1085,160,-290),V(1042,5,-424),59),K(108,V(1080,30,-394),V(1042,7,-424),58),K(125,V(1025,10,-393),V(1042,7,-424),65),K(141,V(1017,7,-436),V(1042,8,-424),63),K(157,V(1084,15,-448),V(1165,20,-512),63),K(166,V(1122,12,-428),V(1165,22,-512),64),K(171,V(1135,7,-409),V(1165,24,-512),64),K(177,V(1150,7,-408),V(1165,25,-512),65),K(193,V(1192,13,-316),V(1170,2,-285),64),K(207,V(1146,17,-255),V(1146,3,-187),62),K(217,V(1146,2,-211),V(1146,4,-184),64),K(225,V(1146,2,-184),V(1146,3,-160),64),K(230,V(1146,2,-178),V(1163,3,-178),67),K(240,V(1175,2,-178),V(1187,3,-178),67)]
        }
        return CameraTrack(keys:keys).pose(at:t)
    }
    static func idlePose(view: Int, seconds: Double) -> CameraPose {
        let index=max(0,min(MillenniumScene.stops.count-1,view)),elapsed=Float(max(0,seconds.isFinite ? seconds:0))
        var result=MillenniumScene.stops[index].pose
        if index == 0 || index == flybyView {
            let pivot=index == 0 ? V(1080,0,-425):V.zero,offset=result.position-pivot,angle=elapsed * .pi/180*0.18
            result.position=pivot+V(offset.x*cos(angle)+offset.z*sin(angle),offset.y,offset.z*cos(angle)-offset.x*sin(angle))
        } else {
            let forward=simd_normalize(result.target-result.position),right=simd_normalize(simd_cross(forward,V(0,1,0))),phase=elapsed*0.075
            let scale:Float = index == 2 ? 0.6:index == 1 ? 1.4:3
            result.position += right*sin(phase)*0.07*scale
            result.target += right*sin(phase*0.71)*0.18*scale
            result.fov -= sin(phase*0.52)*0.65
        }
        return result
    }
}
