import Foundation
import simd

/// Lakefront, river and distant western compositions of the shared Chicago scene.
/// These are cinematic viewpoints, including positions over water, not public walking routes.
enum SkylineScene {
    private typealias V = SIMD3<Float>
    private static func pose(_ p: V, _ target: V, _ fov: Float) -> CameraPose {
        CameraPose(position:p,target:target,fov:fov)
    }
    // Willis remains on the centerline of the user's waterfront sunset composition.
    static let acrossWaterTarget: SIMD3<Float> = V(-8,110,0)
    static let preferredLighting = [3,1,3,2,2,1,0,2]
    /// A clear-distance study; zero preserves the renderer's existing atmosphere.
    static func hazeDensity(view: Int) -> Float { view == 1 ? 0.000020 : 0 }
    static let stops: [TourStop] = [
        TourStop(id:0,title:"The city across the water",subtitle:"ADLER LAKEFRONT · WILLIS AT SUNSET",detail:"Willis Tower anchors the center of this low waterfront panorama. Rose and amber sunset colors warm the skyline, while the setting sun and illuminated buildings reflect across the open water. The gentle orbit and guided flight keep the tower at the heart of the composition.",pose:pose(V(2410,8,1250),acrossWaterTarget,37)),
        TourStop(id:1,title:"Chicago from the west",subtitle:"OAK PARK · EASTWARD TELEPHOTO",detail:"Look east from Oak Park toward the city rising beyond the western neighborhoods. The compressed silhouette places the former John Hancock Center to the left and Willis Tower to the right, following the skyline photographed from Vantage Oak Park.",pose:pose(V(-13569.5,55,-1135.8),V(350,210,-900),9)),
        TourStop(id:2,title:"Sunset behind the skyline",subtitle:"ADLER PANORAMA · AMBER, ROSE & BLUE",detail:"A low west-northwest sun warms the sky behind the buildings. The directional sunset gradient lights and reflects in the scene while architectural lights come on. This is an authored late-day atmosphere informed by skyline photographs, not a date-specific solar simulation.",pose:pose(V(2750,12,1600),V(720,150,-900),36)),
        TourStop(id:3,title:"Lights on the lake",subtitle:"ADLER LAKEFRONT · AFTER DARK",detail:"Return close to the water for a night study of illuminated towers and the lake. The navy sky and restrained amber horizon follow the City of Chicago’s dusk reference; ray tracing carries the actual city lights into reflections.",pose:pose(V(2670,7,1130),V(730,160,-1000),36)),
        TourStop(id:4,title:"The river leads downtown",subtitle:"ABOVE KINZIE STREET BRIDGE · AFTER DARK",detail:"Above the North Branch, look south toward the bend in the river and the downtown towers. The bridge crossing provides a different frame for the city: close river walls, illuminated glass and Willis Tower beyond the modern riverfront buildings.",pose:pose(V(-289,210,-1135),V(0,230,0),50)),
        TourStop(id:5,title:"The northern curve",subtitle:"NORTH AVENUE BEACH · CLEAR DAY",detail:"Look south from the North Avenue lakefront toward the Magnificent Mile and downtown. The former John Hancock Center anchors the nearer skyline while the beach and curving shore connect this view to Lincoln Park.",pose:pose(V(1560,16,-4220),V(1020,155,-1510),33)),
        TourStop(id:6,title:"North from the South Branch",subtitle:"PING TOM PARK OVERLOOK · WARM DAYLIGHT",detail:"Look north from above the river beside Ping Tom Memorial Park. Willis Tower rises beyond the South Loop, revealing the skyline from the opposite side of the city to the North Avenue Beach view.",pose:pose(V(60,18,2502),V(0,190,0),35)),
        TourStop(id:7,title:"The luminous panorama",subtitle:"LAKE MICHIGAN · GRAND NIGHT VIEW",detail:"End with a wide night panorama, high enough to reveal the illuminated streets behind the waterfront. The slow camera motion preserves the silhouette while the full walkthrough draws closer to the Museum Campus edge.",pose:pose(V(3420,95,790),V(730,150,-1120),39))
    ]
}
