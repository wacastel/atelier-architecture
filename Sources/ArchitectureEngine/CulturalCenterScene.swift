import Foundation
import simd

/// Seven architectural studies and an arrival from the existing Millennium Park.
enum CulturalCenterScene {
    private typealias V = SIMD3<Float>
    private static func pose(_ eye: V, _ target: V, _ fov: Float) -> CameraPose {
        CameraPose(position: CulturalCenterLayout.point(eye), target: CulturalCenterLayout.point(target), fov: fov)
    }
    static let stops: [TourStop] = [
        TourStop(id: 0, title: "The people's palace", subtitle: "CHICAGO CULTURAL CENTER · SHEPLEY, RUTAN & COOLIDGE · 1897", detail: "Explore the former central public library beside Millennium Park. Its limestone elevations, tall arched windows and classical upper stories frame a civic interior of marble, mosaics and stained glass.", pose: pose(V(42,22,78), V(0,15,15), 62)),
        TourStop(id: 1, title: "Washington Street welcomes you", subtitle: "THE SOUTH ENTRANCE · MARBLE & MOSAIC", detail: "Approach the Washington Street entrance at human scale, cross the open portal and enter the marble-lined lobby. The guided path follows the modeled entrance steps toward the great mosaic stair.", pose: CameraPose(position: CulturalCenterLayout.washingtonEyePath[0], target: CulturalCenterLayout.point(V(0,4,49)), fov: 68)),
        TourStop(id: 2, title: "A stair made of mosaics", subtitle: "THE GRAND STAIR · PATTERN, STONE & LIGHT", detail: "Climb the interpreted Washington stair through its central and returning flights. Pale marble, patterned mosaic surfaces and carved balustrades lead toward Preston Bradley Hall and its luminous dome.", pose: CameraPose(position: CulturalCenterLayout.mosaicStairEyePath[0], target: CulturalCenterLayout.point(V(0,7,43)), fov: 72)),
        TourStop(id: 3, title: "Under the Tiffany dome", subtitle: "PRESTON BRADLEY HALL · OPAL GLASS & BRONZE", detail: "Look upward into the Tiffany glass dome, whose concentric pattern and metal ribs are informed by the restoration references. This architectural interpretation keeps the glass, surrounding arches and room in the same physical scene.", pose: pose(V(0,13.55,25.5), V(0.6,24,29), 70)),
        TourStop(id: 4, title: "Preston Bradley Hall", subtitle: "THE FORMER LIBRARY · LONG VIEWS & ORNAMENT", detail: "Follow the hall's side aisle and look back across its marble and mosaic architecture. Daylight and warm interior fixtures reveal the relationship between the dome, arches, windows and reflective stone surfaces.", pose: pose(V(14,13.55,34), V(0,16,29), 74)),
        TourStop(id: 5, title: "The Grand Army rotunda", subtitle: "HEALY & MILLET GLASS · RESTORED COLOR", detail: "Enter the northern rotunda beneath its separate stained-glass dome. Restoration photographs inform the colored glass, decorative finishes and warm light; this dome is distinct from the Tiffany work in Preston Bradley Hall.", pose: pose(V(-2.5,13.55,-32), V(0.5,22.7,-29), 72)),
        TourStop(id: 6, title: "Color restored", subtitle: "MEMORIAL HALL · PAINT, GILDING & HISTORIC DETAIL", detail: "Move through the interpreted Grand Army of the Republic Memorial Hall, studying the restored palette, plaster details, woodwork and lighting. Selected public spaces and ornaments are reconstructed from plans and conservation photographs.", pose: pose(V(-4,13.55,-43), V(6.5,17,-44), 73)),
        TourStop(id: 7, title: "From the Bean to the palace", subtitle: "MILLENNIUM PARK · MICHIGAN AVENUE · TWO-MINUTE FLIGHT", detail: "Leave Cloud Gate, rise over the park and cross Michigan Avenue to the Cultural Center. This short connecting flight finishes at the building's opening view without loading a second Chicago world.", pose: MillenniumScene.stops[1].pose)
    ]
}
