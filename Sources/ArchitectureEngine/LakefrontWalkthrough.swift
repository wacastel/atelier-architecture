import Foundation
import simd

enum LakefrontWalkthrough {
    static let walkingViews: Set<Int> = [1, 2]
    static func duration(view: Int) -> Double { view == 7 ? 120 : view == 0 ? 90 : 56 }
    private typealias V = SIMD3<Float>
    private typealias K = CameraTrack.Key

    static func pose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0, min(LakefrontScene.stops.count - 1, view))
        let start = LakefrontScene.stops[index].pose
        let t = max(0, min(duration(view: index), seconds.isFinite ? seconds : 0))
        if t == 0 { return start }
        var keys = [K(0, start.position, start.target, start.fov)]
        switch index {
        case 0:
            keys += [K(22,V(976,104,-1350),V(979,105,-1900),63),K(46,V(973,105,-1630),V(1040,150,-2150),65),K(68,V(977,118,-1880),V(1063,178,-2220),65),K(90,V(976,142,-2010),V(1063,205,-2220),67)]
        case 1:
            keys += [K(18,V(978,1.8,-2019),V(951.6,15,-2036.52),78),K(37,V(978,1.8,-2040),V(951.6,16,-2036.52),82),K(56,V(972,1.8,-2061),V(951.6,24,-2036.52),80)]
        case 2:
            keys += [K(18,V(980,2,-2102),V(1025,32,-2130),82),K(38,V(980,2,-2134),V(998,9,-2147),78),K(56,V(980,2,-2158),V(1079,104,-2118),80)]
        case 3:
            keys += [K(18,V(1300,305,-2210),V(1062.85,222,-2219.95),65),K(36,V(1220,380,-2410),V(1062.85,260,-2219.95),65),K(56,V(1000,445,-2450),V(1062.85,315,-2219.95),67)]
        case 4:
            keys += [K(18,V(1348,14,404),V(1404.55,8,342.2),62),K(37,V(1411,13,398),V(1404.55,10,342.2),65),K(56,V(1462,13,363),V(1404.55,9,342.2),64)]
        case 5:
            keys += [K(18,V(1510,22,510),V(1220,35,50),63),K(37,V(1485,20,460),V(1210,40,20),62),K(56,V(1465,18,402),V(1220,45,-60),62)]
        case 6:
            keys += [K(12,V(2107,2,-668),V(2077.835,-4,-668.588),57),K(27,V(2107,3,-751),V(2076.74,-4,-755.312),61),K(36,V(2107,28,-835),V(1980,-1,-740),64),K(56,V(2130,48,-910),V(1750,20,-570),63)]
        default:
            // Keys follow the mapped road bends, with the camera displaced
            // toward the lake and above bridge decks and harbor rigging.
            keys += [K(20,V(1229,54,-2530),V(1510,12,-2180),65),K(28,V(1480,58,-2350),V(1535,12,-2110),65),K(40,V(1666,48,-1990),V(1750,8,-1600),65),K(60,V(2050,80,-1360),V(1790,8,-870),65),K(80,V(1939,45,-745),V(1700,3,-390),64),K(100,V(1647,40,-180),V(1550,4,335),65),K(120,V(1660,65,440),V(1404,10,342),66)]
        }
        return CameraTrack(keys: keys).pose(at: t)
    }

    static func idlePose(view: Int, seconds: Double) -> CameraPose {
        let index = max(0, min(LakefrontScene.stops.count - 1, view))
        var result = LakefrontScene.stops[index].pose
        let t = Float(max(0, seconds.isFinite ? seconds : 0))
        let forward = simd_normalize(result.target-result.position)
        let right = simd_normalize(simd_cross(forward,V(0,1,0)))
        let scale: Float = walkingViews.contains(index) ? 0.4 : index == 3 ? 7 : 3
        // Bounded drift keeps each studied façade or garden path in view even
        // when a manually selected bookmark is held for a long time.
        result.position += right * (sin(t*0.055)*scale)
        result.target += right * (sin(t*0.039)*scale*0.3)
        result.fov -= sin(t*0.031)*0.55
        return result
    }
}
