import Foundation
import simd

enum NorthSideWalkthrough {
    static let zooFlybyView=0
    static let wrigleyFlybyView=6
    static let walkingViews:Set<Int>=[3,4]
    private typealias V=SIMD3<Float>
    private typealias K=CameraTrack.Key
    static func duration(view:Int)->Double { [240,120,120,120,150,120,240,150][max(0,min(7,view))] }

    static func pose(view:Int,seconds:Double)->CameraPose {
        let index=max(0,min(7,view)),start=NorthSideScene.stops[index].pose
        let time=max(0,min(duration(view:index),seconds.isFinite ? seconds:0))
        if time==0 {return start}
        var keys=[K(0,start.position,start.target,start.fov)]
        switch index {
        case 0:
            keys += [K(12,V(1620,175,-570),V(1290,40,-890),66),
                     K(25,V(1820,210,-980),V(1070,45,-1250),66),
                     K(50,V(1760,210,-1740),V(925,95,-2080),67),
                     K(78,V(1470,180,-2600),V(915,30,-3100),67),
                     K(109,V(1290,125,-3500),V(973,5,-3853),65),
                     K(136,V(1090,90,-4020),V(825,0,-4270),65),
                     K(165,V(743,78,-4470),V(253,7,-4610),67),
                     K(192,V(431,56,-4500),V(192,7,-4470),67),
                     K(220,V(334,21,-4310),V(292,4,-4343),72),
                     K(240,LincolnParkZooLayout.natureStart,LincolnParkZooLayout.pavilionCenter+V(0,3.8,0),76)]
        case 1:
            keys += [K(21,V(-440,26,-3768),V(-391,48,-3766),68),
                     K(45,V(-443,38,-3700),V(-397,34,-3740),67),
                     K(67,V(-360,66,-3640),V(-404,48,-3760),65),
                     K(88,V(88,65,-3640),V(98,9,-3550),67),
                     K(107,V(104,12,-3520),V(110,6,-3410),70),
                     K(120,V(107,5,-3420),V(112,6,-3350),72)]
        case 2:
            let at=NorthSideLandmarksLayout.beachPoint
            keys += [K(24,at(V(-76,23,9)),at(V(0,6,0)),64),
                     K(49,at(V(-55,13,-29)),at(V(-9,6,0)),67),
                     K(73,at(V(25,11,-32)),at(V(-10,5,0)),67),
                     K(97,at(V(66,25,-22)),at(V(4,5,0)),65),
                     K(120,at(V(58,29,44)),V(930,155,-2290),67)]
        case 3:
            let route=LincolnParkZooLayout.natureRoute
            for i in 1..<route.count {
                let target=i<4 ? LincolnParkZooLayout.pavilionCenter+V(0,3.8,0) : LincolnParkZooLayout.cafeCenter+V(0,8,0)
                keys.append(K(Double(i)*120/Double(route.count-1),route[i],target,76))
            }
        case 4:
            let route=LincolnParkZooLayout.zooRoute
            for i in 1..<route.count {
                let target=i<3 ? LincolnParkZooLayout.lionHouse+V(0,6,0) : V(301,6,-4740)
                keys.append(K(Double(i)*150/Double(route.count-1),route[i],target,75))
            }
        case 5:
            let route=LincolnParkZooLayout.conservatoryRoute
            for i in 1..<route.count {keys.append(K(Double(i)*12,route[i],LincolnParkZooLayout.conservatory+V(0,8,0),74))}
            keys += [K(62,V(18,27,-5090),V(71,9,-5070),70),
                     K(77,V(135,28,-5120),V(153,2,-5137),69),
                     K(92,V(193,12,-5100),LincolnParkZooLayout.lilyPool+V(0,0.5,0),71),
                     K(102,LincolnParkZooLayout.lilyStart,LincolnParkZooLayout.lilyPool+V(0,0.5,0),74),
                     K(120,LincolnParkZooLayout.lilyRoute[1],LincolnParkZooLayout.lilyPool+V(0,0.4,0),74)]
        case 6:
            keys += [K(29,V(625,140,-5010),V(320,12,-5260),65),
                     K(59,V(575,150,-5740),V(345,0,-5940),65),
                     K(92,V(420,165,-6550),V(180,0,-6830),66),
                     K(124,V(280,155,-7190),V(-135,0,-7380),66),
                     K(157,V(-320,180,-7540),V(-1120,26,-7720),65),
                     K(188,V(-1020,165,-7730),V(-1626,10,-7720),66),
                     K(216,V(-1490,120,-7910),V(-1640,12,-7710),66),
                     K(240,NorthSideScene.stops[7].pose.position,NorthSideScene.stops[7].pose.target,NorthSideScene.stops[7].pose.fov)]
        default:
            keys += [K(26,V(-1795,30,-7663),V(-1700,12,-7690),68),
                     K(51,V(-1770,75,-7780),V(-1633,10,-7714),67),
                     K(79,V(-1630,64,-7845),V(-1645,5,-7685),69),
                     K(106,V(-1510,63,-7710),V(-1638,5,-7710),69),
                     K(129,V(-1594,34,-7662),V(-1650,2,-7685),72),
                     K(150,V(-1639,6,-7698),V(-1602,5,-7771),75)]
        }
        return CameraTrack(keys:keys).pose(at:time)
    }

    static func idlePose(view:Int,seconds:Double)->CameraPose {
        let index=max(0,min(7,view)),t=Float(max(0,seconds.isFinite ? seconds:0))
        var pose=NorthSideScene.stops[index].pose
        let right=simd_normalize(simd_cross(simd_normalize(pose.target-pose.position),V(0,1,0)))
        let scale:Float=walkingViews.contains(index) ? 0.12:index==0 || index==6 ? 5:2
        pose.position += right*(sin(t*0.037)*scale)
        pose.target += right*(sin(t*0.026)*scale*0.22)
        pose.fov -= sin(t*0.021)*0.40
        return pose
    }
}
