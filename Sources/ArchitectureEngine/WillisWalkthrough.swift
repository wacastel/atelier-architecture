import Foundation
import simd

enum WillisWalkthrough {
    static let duration=56.0
    static let walkingViews:Set<Int>=[1,2,3,4,5]
    private typealias V=SIMD3<Float>
    private struct Key {let t:Float;let pose:CameraPose;init(_ t:Float,_ p:V,_ target:V,_ fov:Float){self.t=t;pose=CameraPose(position:p,target:target,fov:fov)}}
    private static func rotate(_ p:V,_ angle:Float)->V {V(p.x*cos(angle)+p.z*sin(angle),p.y,p.z*cos(angle)-p.x*sin(angle))}
    static func pose(view:Int,seconds:Double)->CameraPose {
        let index=max(0,min(7,view)),start=WillisScene.stops[index].pose
        let t=Float(max(0,min(1,seconds.isFinite ? seconds/duration:0)))
        if t==0 {return start}
        if index==0 {
            var result=start;result.position=rotate(start.position,t*2 * .pi)
            result.position.y += 35*sin(t * .pi)*sin(t * .pi)
            return result
        }
        var keys=[Key(0,start.position,start.target,start.fov)]
        switch index {
        case 1:keys += [Key(0.28,V(0,1.85,74),V(0,3,52),66),Key(0.62,V(0,1.85,61),V(0,3.8,48),69),Key(0.85,V(0,1.85,57),V(0,17,49),72),Key(1,V(0,1.85,54),V(0,22,48),75)]
        case 2:keys += [Key(0.30,V(-23.5,18.75,36.6),V(-22.7,21.4,34.29),43),Key(0.67,V(-20,18.75,37.0),V(-21,20.2,34.29),46),Key(1,V(-18,18.75,37.4),V(-17.9,29,34.29),52)]
        case 3:keys += [Key(0.30,V(27,18.75,62.8),V(2,20,47),65),Key(0.64,V(23,18.75,62.4),V(11,18.8,63),66),Key(1,V(16,18.75,61.8),V(-5,21.5,43),66)]
        case 4:keys += [Key(0.31,V(-30.5,414.1444,2.8),V(-60,408,-15),70),Key(0.67,V(-30.4,414.1444,-2.8),V(-45,410,-12),68),Key(1,V(-27,414.1444,-6.5),V(-17,414.1,-9),64)]
        case 5:keys += [Key(0.32,V(-34.7,414.1444,0),V(-105,320,-15),71),Key(0.63,V(-35.02,414.1444,0),V(-60,120,-10),76),Key(0.82,V(-34.6,414.1444,0),V(-90,390,-42),67),Key(1,V(-32.65,414.1444,0),V(-14,414.2,4),65)]
        case 6:keys += [Key(0.32,V(-70,482,58),V(-15,479,0),58),Key(0.68,V(-62,501,-52),V(-12,470,0),61),Key(1,V(56,477,-87),V(-12,465,0),59)]
        default:keys += [Key(0.30,V(-184,10,53),V(-164,-1,27),76),Key(0.65,V(-181,8,-18),V(-152,1,101),76),Key(1,V(-158,13,67),V(-180,9,-50),79)]
        }
        for i in 1..<keys.count where t<=keys[i].t {
            let a=keys[i-1],b=keys[i],linear=(t-a.t)/(b.t-a.t),u=linear*linear*(3-2*linear)
            return CameraPose(position:a.pose.position+(b.pose.position-a.pose.position)*u,target:a.pose.target+(b.pose.target-a.pose.target)*u,fov:a.pose.fov+(b.pose.fov-a.pose.fov)*u)
        }
        return keys.last!.pose
    }
    static func idlePose(view:Int,seconds:Double)->CameraPose {
        let index=max(0,min(7,view)),elapsed=Float(max(0,seconds.isFinite ? seconds:0))
        var result=WillisScene.stops[index].pose
        if index==0 {result.position=rotate(result.position,elapsed * .pi/180*0.25)}
        else {
            let forward=simd_normalize(result.target-result.position),right=simd_normalize(simd_cross(forward,V(0,1,0)))
            let scale:Float=index>=6 ? 5:1,phase=elapsed*0.075
            result.position += right*sin(phase)*0.045*scale
            result.target += right*sin(phase*0.71)*0.18*scale
            result.fov -= sin(phase*0.52)*0.65
        }
        return result
    }
}
