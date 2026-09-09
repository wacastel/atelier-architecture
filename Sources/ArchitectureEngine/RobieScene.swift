import Foundation
import simd

/// Seven close architectural studies and a continuous flight from McCormick Place.
enum RobieScene {
    private typealias V = SIMD3<Float>
    private static func pose(_ position: V, _ target: V, _ fov: Float) -> CameraPose {
        CameraPose(position: RobieHouseLayout.point(position), target: RobieHouseLayout.point(target), fov: fov)
    }
    static let stops: [TourStop] = [
        TourStop(id: 0, title: "A house on the prairie", subtitle: "FRANK LLOYD WRIGHT · HYDE PARK · 1910", detail: "Discover the Robie House’s horizontal brick and limestone bands, long roof cantilevers and interlocking terraces. Its mapped Woodlawn Avenue setting connects to the same Chicago landscape as McCormick Place and the lakefront.", pose: pose(V(-28,8,23), V(0,4,1), 60)),
        TourStop(id: 1, title: "The floating roof", subtitle: "CANTILEVER · DEEP EAVES · WEST PROW", detail: "Study the west-facing living-room prow beneath its dramatically projecting roof. Thin copper-colored edges, broad soffits and layered masonry make the building’s low proportions visible from nearby.", pose: pose(V(-22,4.85,1), V(-11,4.8,0), 65)),
        TourStop(id: 2, title: "Roman brick and limestone", subtitle: "GARDEN WALLS · MASONRY JOINTS · PLANTERS", detail: "Follow the garden edge at human scale. Long Roman-brick courses, recessed mortar, pale limestone coping and planted terraces echo the horizontal lines of the house.", pose: pose(V(-8,1.9,9.5), V(-4,3.0,3.2), 66)),
        TourStop(id: 3, title: "Light through art glass", subtitle: "SOUTH BALCONY · LEADED GLASS · RESTORED DETAILS", detail: "Move along the sheltered balcony beside the patterned doors and windows. Modeled leading and colored glass respond to the daylight; restrained warm interior light gives the façade depth after dark.", pose: pose(V(-8,4.85,4.25), V(-4,4.9,3.2), 65)),
        TourStop(id: 4, title: "The hearth at the center", subtitle: "LIVING ROOM · OAK TRIM · CONTINUOUS SPACE", detail: "Enter the restored living-room interpretation, where the central brick hearth divides the living and dining areas while preserving their connection. Oak ceiling frames, plaster planes and patterned lighting follow the conservation references.", pose: pose(V(-8,4.85,1.5), V(0.8,4.5,-0.1), 75)),
        TourStop(id: 5, title: "A room for gathering", subtitle: "DINING ROOM · BUILT-IN LIGHT · EAST PROW", detail: "Explore the dining side of the main floor and the relationship between furniture, art glass and the central chimney. Selected furnishings and illumination are architectural interpretations informed by the restored interior photographs.", pose: pose(V(8,4.85,1.65), V(3,4.5,-0.6), 75)),
        TourStop(id: 6, title: "Planes above the garden", subtitle: "BELVEDERE · ROOFLINES · THE HYDE PARK BLOCK", detail: "Rise above the terraces to read the overlapping roofs, upper bedroom level and offset service wing. Nearby mapped university and neighborhood buildings restore the urban context around Wright’s composition.", pose: pose(V(18,15,19), V(0,5,-1), 62)),
        TourStop(id: 7, title: "From McCormick Place to Robie House", subtitle: "SOUTH LAKEFRONT · HYDE PARK · SIX-MINUTE FLIGHT", detail: "Follow the shoreline from McCormick Place past 31st Street Harbor, Burnham Park and Promontory Point, then cross Hyde Park to Woodlawn Avenue. The flight ends at the Robie House’s opening view within one resident Chicago world.", pose: McCormickLayout.stop)
    ]
}
