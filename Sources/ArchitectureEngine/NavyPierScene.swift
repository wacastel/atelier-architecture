import Foundation
import simd

/// The mapped pier shares the resident Chicago world. Offshore studies are
/// architectural flights, not claims of pedestrian access over the lake.
enum NavyPierScene {
    private static func pose(_ p: SIMD3<Float>, _ target: SIMD3<Float>, _ fov: Float) -> CameraPose {
        CameraPose(position: NavyPierLayout.point(p), target: NavyPierLayout.point(target), fov: fov)
    }
    static let stops: [TourStop] = [
        TourStop(id:0,title:"A pier for the city",subtitle:"LAKE MICHIGAN · CHICAGO’S WATERFRONT",detail:"The Centennial Wheel rises above a long ribbon of parks, theaters, hotel rooms and historic halls. A lakeward flight reveals Navy Pier’s mapped footprint, working docks and the city beyond, all within the shared Chicago landscape.",pose:pose(SIMD3(900,190,340),SIMD3(280,15,0),60)),
        TourStop(id:1,title:"The Centennial Wheel",subtitle:"WHITE STEEL · BLUE GONDOLAS · LIGHT ON THE LAKE",detail:"Move beside the wheel’s open steel structure, paired rim rings and enclosed gondolas. White supports and blue cabins establish its daytime silhouette; colored architectural lighting traces the circle after dark.",pose:pose(SIMD3(-75,24,100),SIMD3(0,35,0),55)),
        TourStop(id:2,title:"The gateway and the gardens",subtitle:"POLK BROS PARK · FAMILY PAVILION",detail:"Approach the pier through its landscaped gateway. Fountain water, planting, seating and the brick Family Pavilion frame the transition from Streeterville to the open lakefront promenade.",pose:pose(SIMD3(-285,20,75),SIMD3(-146,12,0),62)),
        TourStop(id:3,title:"Shakespeare on the water",subtitle:"CHICAGO SHAKESPEARE THEATER · SOUTH DOCK",detail:"Glide along the South Dock beside Chicago Shakespeare Theater and The Yard. Curved walls, glazing, roof structure and close promenade details bring the arts buildings down to a human scale.",pose:pose(SIMD3(135,9,98),SIMD3(142,18,40),64)),
        TourStop(id:4,title:"Rooms above the lake",subtitle:"SABLE HOTEL · BAYS, GLASS & THE SOUTH DOCK",detail:"Follow the hotel’s long south-facing elevation above the docks. Repeated angled window bays, metalwork and warm interior light accompany a gently rising study of the waterfront facade.",pose:pose(SIMD3(275,16,112),SIMD3(370,20,43),64)),
        TourStop(id:5,title:"The Grand Ballroom",subtitle:"THE EAST END · BRICK, ARCHES & A GREEN DOME",detail:"Circle the historic end of the pier. The Grand Ballroom’s dome, arched masonry openings and flanking towers rise above the lake, with cornices, railings and architectural lighting visible at close range.",pose:pose(SIMD3(744,23,85),SIMD3(669.8,17,-1.2),58)),
        TourStop(id:6,title:"Boats beside the pier",subtitle:"NORTH MARINA · DOCKS & THE CHICAGO SKYLINE",detail:"Travel above the north-side marina and moored boats, then look back toward the wheel and the city. Hulls, cabins, masts and dock fittings share the same reflective water and nighttime lighting as the pier.",pose:pose(SIMD3(350,24,-180),SIMD3(180,0,-108),64)),
        TourStop(id:7,title:"From Millennium Park to Navy Pier",subtitle:"CONTINUOUS CHICAGO FLIGHT · THREE MINUTES",detail:"Leave Millennium Park, turn toward the lake and fly north beside the harbor to Navy Pier. The flight finishes at the pier’s opening panorama without loading another Chicago scene.",pose:MillenniumScene.stops[0].pose)
    ]
}
