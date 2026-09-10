import Foundation

/// Scene metadata and camera routing shared by the app, exports, and validation.
enum ArchitectureLocation: String, CaseIterable, Identifiable {
    case paris
    case chicago
    case skyline
    case millennium
    case culturalcenter
    case lakefront
    case navypier
    case campus
    case northside
    case robie

    var id: String { rawValue }
    var name: String {
        switch self { case .paris: return "Eiffel Tower"; case .chicago: return "Willis Tower"; case .skyline: return "Chicago Skyline"; case .millennium: return "Millennium Park"; case .culturalcenter: return "Chicago Cultural Center"; case .lakefront: return "Chicago Lakefront"; case .navypier: return "Navy Pier"; case .campus: return "Museum Campus"; case .northside: return "Chicago North Side"; case .robie: return "Robie House & Hyde Park" }
    }
    var shortName: String { self == .paris ? "Paris" : "Chicago" }
    var subtitle: String {
        switch self { case .paris: return "PARIS, FRANCE   ·   1889"; case .chicago: return "CHICAGO, ILLINOIS   ·   1973"; case .skyline: return "LAKEFRONT, RIVER & WESTERN HORIZON"; case .millennium: return "CHICAGO, ILLINOIS   ·   ART & LANDSCAPE"; case .culturalcenter: return "THE PEOPLE’S PALACE   ·   MOSAIC, MARBLE & GLASS   ·   1897"; case .lakefront: return "MICHIGAN AVENUE   ·   PARKS & HARBORS"; case .navypier: return "CHICAGO’S WATERFRONT   ·   THE PEOPLE’S PIER   ·   1916"; case .campus: return "MUSEUMS   ·   STARS   ·   THE SOUTH LAKEFRONT"; case .northside: return "OLD TOWN   ·   LINCOLN PARK   ·   WRIGLEYVILLE"; case .robie: return "FRANK LLOYD WRIGHT   ·   HYDE PARK   ·   1910" }
    }
    var number: String { String(format:"%02d", (Self.allCases.firstIndex(of:self) ?? 0)+1) }
    /// Chicago locations share one physical scene and acceleration structure.
    var world: String { self == .paris ? "paris" : "chicago" }
    var stops: [TourStop] {
        switch self { case .paris: return EiffelScene.stops; case .chicago: return WillisScene.stops; case .skyline: return SkylineScene.stops; case .millennium: return MillenniumScene.stops; case .culturalcenter: return CulturalCenterScene.stops; case .lakefront: return LakefrontScene.stops; case .navypier: return NavyPierScene.stops; case .campus: return MuseumCampusScene.stops; case .northside: return NorthSideScene.stops; case .robie: return RobieScene.stops }
    }
    func duration(view: Int) -> Double {
        switch self { case .paris: return EiffelWalkthrough.duration; case .chicago: return WillisWalkthrough.duration; case .skyline: return SkylineWalkthrough.duration; case .millennium: return MillenniumWalkthrough.duration(view: view); case .culturalcenter: return CulturalCenterWalkthrough.duration; case .lakefront: return LakefrontWalkthrough.duration(view: view); case .navypier: return NavyPierWalkthrough.duration(view: view); case .campus: return MuseumCampusWalkthrough.duration(view: view); case .northside: return NorthSideWalkthrough.duration(view: view); case .robie: return RobieWalkthrough.duration(view: view) }
    }
    var walkingViews: Set<Int> {
        switch self { case .paris: return [1,3,4,5,6]; case .chicago: return WillisWalkthrough.walkingViews; case .skyline: return SkylineWalkthrough.walkingViews; case .millennium: return MillenniumWalkthrough.walkingViews; case .culturalcenter: return CulturalCenterWalkthrough.walkingViews; case .lakefront: return LakefrontWalkthrough.walkingViews; case .navypier: return NavyPierWalkthrough.walkingViews; case .campus: return MuseumCampusWalkthrough.walkingViews; case .northside: return NorthSideWalkthrough.walkingViews; case .robie: return RobieWalkthrough.walkingViews }
    }

    /// Authored lighting for this destination; nil keeps the ordinary day/night pass.
    func preferredLighting(view: Int) -> Int? {
        self == .skyline ? SkylineScene.preferredLighting[max(0,min(7,view))] : nil
    }

    /// Explicit shot atmosphere, shared by interactive views and every export path.
    func hazeDensity(view: Int) -> Float {
        if self == .skyline { return SkylineScene.hazeDensity(view: view) }
        // Keep the lakeward panorama legible across the full pier and skyline.
        // The connecting flight retains Millennium Park's opening atmosphere.
        return self == .navypier && view != NavyPierWalkthrough.flybyView ? 0.000035 : 0
    }

    func build() -> SceneData { self == .paris ? EiffelScene.build() : WillisScene.build() }
    func pose(view: Int, seconds: Double) -> CameraPose {
        switch self {
        case .paris: return EiffelWalkthrough.pose(view: view, seconds: seconds)
        case .chicago: return WillisWalkthrough.pose(view: view, seconds: seconds)
        case .skyline: return SkylineWalkthrough.pose(view: view, seconds: seconds)
        case .millennium: return MillenniumWalkthrough.pose(view: view, seconds: seconds)
        case .culturalcenter: return CulturalCenterWalkthrough.pose(view: view, seconds: seconds)
        case .lakefront: return LakefrontWalkthrough.pose(view: view, seconds: seconds)
        case .navypier: return NavyPierWalkthrough.pose(view: view, seconds: seconds)
        case .campus: return MuseumCampusWalkthrough.pose(view: view, seconds: seconds)
        case .northside: return NorthSideWalkthrough.pose(view: view, seconds: seconds)
        case .robie: return RobieWalkthrough.pose(view: view, seconds: seconds)
        }
    }
    func idlePose(view: Int, seconds: Double) -> CameraPose {
        // Avoid Float overflow if a recovered clock contains a centuries-long gap.
        let safeSeconds = seconds.isFinite ? (seconds > 86_400 ? seconds.truncatingRemainder(dividingBy: 86_400) : max(0, seconds)) : 0
        switch self {
        case .paris: return EiffelWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .chicago: return WillisWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .skyline: return SkylineWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .millennium: return MillenniumWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .culturalcenter: return CulturalCenterWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .lakefront: return LakefrontWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .navypier: return NavyPierWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .campus: return MuseumCampusWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .northside: return NorthSideWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .robie: return RobieWalkthrough.idlePose(view: view, seconds: safeSeconds)
        }
    }
}
