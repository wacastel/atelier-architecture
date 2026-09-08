import Foundation
import simd

enum MuseumCampusWalkthrough {
    static let flybyView = 0
    static let walkingViews: Set<Int> = [1,2,3,4]
    private typealias V = SIMD3<Float>
    private typealias K = CameraTrack.Key
    static func duration(view:Int)->Double { [180,120,120,150,180,90,90,180][max(0,min(7,view))] }

    static func pose(view:Int,seconds:Double)->CameraPose {
        let index=max(0,min(7,view)),start=MuseumCampusScene.stops[index].pose
        let time=max(0,min(duration(view:index),seconds.isFinite ? seconds:0))
        if time==0 {return start}
        var keys=[K(0,start.position,start.target,start.fov)]
        switch index {
        case 0:
            keys += [K(24,V(1320,90,125),V(1404,9,342),65),K(49,V(1510,88,530),V(1550,20,1040),64),K(76,V(1630,82,1020),V(1565,23,1409),66),K(98,V(1562,25,1245),V(1565,18,1385),69),K(116,MuseumBuildingsLayout.fieldRoute[0],MuseumBuildingsLayout.fieldPoint(V(0,15,-53)),74)]
            let times:[Double]=[130,140,150,163,175,180]
            for i in 1..<MuseumBuildingsLayout.fieldRoute.count {
                let p=MuseumBuildingsLayout.fieldRoute[i]
                keys.append(K(times[i-1],p,MuseumBuildingsLayout.fieldPoint(V(i<3 ? 0:0,13,Float(-40+i*11))),76))
            }
        case 1:
            let times:[Double]=[19,34,52,82,106,120]
            for i in 1..<MuseumBuildingsLayout.fieldRoute.count {
                keys.append(K(times[i-1],MuseumBuildingsLayout.fieldRoute[i],MuseumBuildingsLayout.fieldPoint(V(i<3 ? 0:-2,12,Float(-40+i*10))),76))
            }
        case 2:
            let route=MuseumBuildingsLayout.sheddRoute
            for i in 1..<route.count {
                let target:V
                if i<3 {target=MuseumBuildingsLayout.sheddPoint(V(0,13,0))}
                else if i<6 {target=MuseumBuildingsLayout.sheddPoint(V(-12,6,12))}
                else if i<8 {target=MuseumBuildingsLayout.sheddPoint(V(0,7,0))}
                else if i<route.count-2 {target=MuseumBuildingsLayout.sheddPoint(V(Float((i-8)*15+6),6.5,0))}
                else {target=MuseumBuildingsLayout.sheddPoint(V(88,4.5,0))}
                keys.append(K(Double(i)*120/Double(route.count-1),route[i],target,i<8 ? 80:76))
            }
        case 3:
            let c=AdlerLayout.center
            keys += [K(15,c+V(-36,1.8,1.5),c+V(-20,8,0),71),
                     K(30,AdlerLayout.entrance,c+V(-14,5,0),74),
                     K(38,c+V(-16,4.55,0),AdlerLayout.welcome,76),
                     K(45,AdlerLayout.welcome,c+V(-8,5,-16),77),
                     K(52,c+V(-14,4.55,-10),c+V(-5,5,-17),78),
                     K(62,c+V(-5,4.55,-16),c+V(2,5,-18),78),
                     K(70,c+V(-14,4.55,-10),AdlerLayout.theaterDoor,78),
                     K(77,AdlerLayout.theaterDoor,c+V(-8,5,-4.4),85),
                     K(81,c+V(-8,4.55,-4.4),c+V(-6,5,0),91),
                     K(85,c+V(-8,4.55,0),AdlerLayout.theaterLook,96),
                     K(92,AdlerLayout.theaterCenter,AdlerLayout.theaterLook,98),
                     K(120,AdlerLayout.theaterCenter+V(0.6,0,0.2),c+V(7,8.5,1),99),
                     K(150,AdlerLayout.theaterCenter+V(0.1,0,-0.2),c+V(6,9,-2),100)]
        case 4:
            keys += [K(20,AdlerLayout.theaterCenter,AdlerLayout.theaterLook,98),
                     K(60,AdlerLayout.theaterCenter+V(0.6,0,0.2),AdlerLayout.center+V(7,8.5,-1),99),
                     K(90,AdlerLayout.theaterCenter+V(0.1,0,-0.2),AdlerLayout.center+V(5,9,2),100),
                     K(120,AdlerLayout.theaterCenter+V(-0.4,0,0.2),AdlerLayout.center+V(7,8,1),98),
                     K(150,AdlerLayout.theaterCenter+V(-0.7,0,-0.2),AdlerLayout.center+V(5,9,0),99),
                     K(180,start.position,start.target,start.fov)]
        case 5:
            keys += [K(20,V(1790,60,1850),V(1650,15,1840),68),K(40,V(1630,90,2080),V(1592,19,1850),70),K(60,V(1440,100,1880),V(1585,8,1835),71),K(74,SoldierFieldLayout.fieldCamera+V(0,85,0),SoldierFieldLayout.field,74),K(90,SoldierFieldLayout.fieldCamera,SoldierFieldLayout.point(V(0,11,25)),78)]
        case 6:
            keys += [K(18,V(2120,11,1970),V(2081,-1,1971),67),K(34,V(2070,12,2050),V(2011,-1,2116),67),K(52,V(2050,23,2280),V(2054,-1,2204),65),K(70,V(1915,40,2440),V(1980,0,2040),66),K(90,V(1880,60,2060),V(2220,15,1400),65)]
        default:
            keys += [K(30,V(2240,145,3240),V(1770,22,3140),68),K(60,V(1600,165,3520),V(1470,27,3190),68),K(90,V(1080,175,3210),V(1330,27,3180),67),K(115,V(1045,185,2820),V(1345,62,2815),66),K(140,V(1610,150,2510),V(1620,32,2780),66),K(165,V(1845,80,2720),V(1690,28,2860),68),K(180,V(1810,43,2880),V(1850,15,2970),70)]
        }
        var result=CameraTrack(keys:keys).pose(at:time)
        if index==0 || index==1 {
            // Independent Hermite easing of height and horizontal travel can
            // put a camera into a stair riser or above its support. Follow the
            // actual staircase's linear incline while preserving smooth motion
            // over the shallow treads; endpoint poses remain exact.
            let delta=result.position-MuseumBuildingsLayout.fieldCenter
            let angle=MuseumBuildingsLayout.fieldAngle
            let localX=cos(angle)*delta.x+sin(angle)*delta.z
            let localZ = -sin(angle)*delta.x+cos(angle)*delta.z
            if abs(localX)<2 && localZ >= -86.20 && localZ <= -67.72 {
                result.position.y=1.8+(localZ+86.20)/18.48*MuseumBuildingsLayout.fieldFloor
            }
        }
        return result
    }

    static func idlePose(view:Int,seconds:Double)->CameraPose {
        let index=max(0,min(7,view)),t=Float(max(0,seconds.isFinite ? seconds:0))
        var pose=MuseumCampusScene.stops[index].pose
        let right=simd_normalize(simd_cross(simd_normalize(pose.target-pose.position),V(0,1,0)))
        let scale:Float=walkingViews.contains(index) ? 0.18:index==7 ? 5:2.5
        pose.position += right*(sin(t*0.045)*scale)
        pose.target += right*(sin(t*0.033)*scale*0.3)
        pose.fov -= sin(t*0.025)*0.45
        return pose
    }
}
