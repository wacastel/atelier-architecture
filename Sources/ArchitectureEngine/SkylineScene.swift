import Foundation
import simd

/// Lakefront compositions within the existing, geographically continuous Chicago scene.
/// These are cinematic viewpoints, including positions over water, not public walking routes.
enum SkylineScene {
    private typealias V = SIMD3<Float>
    private static func pose(_ p: V, _ target: V, _ fov: Float) -> CameraPose {
        CameraPose(position:p,target:target,fov:fov)
    }
    static let preferredLighting = [1,0,3,2,3,1,0,2]
    static let stops: [TourStop] = [
        TourStop(id:0,title:"The city across the water",subtitle:"ADLER LAKEFRONT · CLEAR DAY",detail:"The broad lakefront panorama looks northwest toward the downtown towers. Adler’s northern shoreline provides the reference composition: open water, a continuous urban silhouette and the tall markers of Willis Tower, Aon Center and the former John Hancock Center.",pose:pose(V(2410,8,1250),V(720,150,-900),37)),
        TourStop(id:1,title:"Harbor and horizon",subtitle:"BURNHAM HARBOR · WARM DAYLIGHT",detail:"Rise above the south lakefront with the harbor and Museum Campus in the foreground. Boats, parkland and the city’s varied rooflines show how the skyline belongs to a much larger landscape.",pose:pose(V(2660,62,2290),V(730,130,-700),34)),
        TourStop(id:2,title:"Sunset behind the skyline",subtitle:"ADLER PANORAMA · AMBER, ROSE & BLUE",detail:"A low west-northwest sun warms the sky behind the buildings. The directional sunset gradient lights and reflects in the scene while architectural lights come on. This is an authored late-day atmosphere informed by skyline photographs, not a date-specific solar simulation.",pose:pose(V(2750,12,1600),V(720,150,-900),36)),
        TourStop(id:3,title:"Lights on the lake",subtitle:"ADLER LAKEFRONT · AFTER DARK",detail:"Return close to the water for a night study of illuminated towers and the lake. The navy sky and restrained amber horizon follow the City of Chicago’s dusk reference; ray tracing carries the actual city lights into reflections.",pose:pose(V(2670,7,1130),V(730,160,-1000),36)),
        TourStop(id:4,title:"Monroe at sunset",subtitle:"MONROE HARBOR · THE EAST FACE OF DOWNTOWN",detail:"Move north along the offshore side of Monroe Harbor. Aon Center and the park-side towers take a different place in the silhouette, backed by the same westward sunset and framed by the existing harbor landscape.",pose:pose(V(2870,48,-300),V(720,155,-920),39)),
        TourStop(id:5,title:"The northern curve",subtitle:"NORTH AVENUE BEACH · CLEAR DAY",detail:"Look south from the North Avenue lakefront toward the Magnificent Mile and downtown. The former John Hancock Center anchors the nearer skyline while the beach and curving shore connect this view to Lincoln Park.",pose:pose(V(1560,16,-4220),V(1020,155,-1510),33)),
        TourStop(id:6,title:"A city beside a great lake",subtitle:"OFFSHORE FLIGHT · WARM DAYLIGHT",detail:"An elevated view sets the city against its long lake edge. This cinematic offshore flight reveals the park system, harbors and changing building heights within the same Chicago world.",pose:pose(V(3500,145,-1100),V(730,140,-650),40)),
        TourStop(id:7,title:"The luminous panorama",subtitle:"LAKE MICHIGAN · GRAND NIGHT VIEW",detail:"End with a wide night panorama, high enough to reveal the illuminated streets behind the waterfront. The slow camera motion preserves the silhouette while the full walkthrough draws closer to the Museum Campus edge.",pose:pose(V(3420,95,790),V(730,150,-1120),39))
    ]
}
