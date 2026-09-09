import Foundation
import simd

enum SkylineWalkthrough {
    static let duration = 120.0
    static let walkingViews: Set<Int> = []
    private typealias V = SIMD3<Float>
    private typealias K = CameraTrack.Key
    static func pose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0,min(7,view)), start = SkylineScene.stops[index].pose
        let t = max(0,min(duration,seconds.isFinite ? seconds:0))
        if t == 0 { return start }
        var keys = [K(0,start.position,start.target,start.fov)]
        switch index {
        case 0: keys += [K(40,V(2580,14,1150),V(720,160,-970),36),K(80,V(2770,24,980),V(740,165,-1000),35),K(120,V(2860,38,720),V(740,150,-900),36)]
        case 1: keys += [K(40,V(-13510,62,-1070),V(350,220,-880),8.8),K(80,V(-13430,69,-990),V(350,225,-850),8.6),K(120,V(-13340,76,-920),V(350,230,-820),8.8)]
        case 2: keys += [K(40,V(2860,18,1430),V(720,145,-850),35),K(80,V(2910,28,1240),V(720,150,-950),34),K(120,V(2820,38,1030),V(720,160,-1040),35)]
        case 3: keys += [K(40,V(2800,9,1010),V(730,160,-1000),35),K(80,V(2910,16,820),V(730,150,-1020),34),K(120,V(2950,28,590),V(730,150,-1000),36)]
        case 4: keys += [K(40,V(-280,225,-1100),V(0,240,0),49),K(80,V(-265,242,-1065),V(0,250,0),48),K(120,V(-245,260,-1035),V(0,260,0),49)]
        case 5: keys += [K(40,V(1590,24,-4010),V(1000,160,-1530),34),K(80,V(1730,40,-3760),V(1000,160,-1480),35),K(120,V(1940,60,-3510),V(990,160,-1400),36)]
        case 6: keys += [K(40,V(45,28,2470),V(0,190,0),34),K(80,V(25,42,2440),V(0,195,0),33),K(120,V(5,58,2410),V(0,200,0),34)]
        default: keys += [K(40,V(3250,105,1030),V(750,155,-1040),38),K(80,V(3040,95,1220),V(740,150,-990),37),K(120,V(2800,65,1290),V(730,155,-950),36)]
        }
        return CameraTrack(keys:keys).pose(at:t)
    }
    static func idlePose(view: Int, seconds: Double) -> CameraPose {
        let start = SkylineScene.stops[max(0,min(7,view))].pose
        let t = Float(max(0,seconds.isFinite ? seconds.truncatingRemainder(dividingBy:86400):0))
        let offset = start.position-start.target, angle = sin(t*0.015)*0.008
        let c=cos(angle), s=sin(angle)
        return CameraPose(position:start.target+V(offset.x*c+offset.z*s,offset.y,offset.z*c-offset.x*s),target:start.target,fov:start.fov-sin(t*0.018)*0.3)
    }
}
