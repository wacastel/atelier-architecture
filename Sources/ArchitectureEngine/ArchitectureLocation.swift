import Foundation

/// Scene metadata and camera routing shared by the app, exports, and validation.
enum ArchitectureLocation: String, CaseIterable, Identifiable {
    case paris
    case chicago
    case millennium
    case lakefront

    var id: String { rawValue }
    var name: String {
        switch self { case .paris: return "Eiffel Tower"; case .chicago: return "Willis Tower"; case .millennium: return "Millennium Park"; case .lakefront: return "Chicago Lakefront" }
    }
    var shortName: String { self == .paris ? "Paris" : "Chicago" }
    var subtitle: String {
        switch self { case .paris: return "PARIS, FRANCE   ·   1889"; case .chicago: return "CHICAGO, ILLINOIS   ·   1973"; case .millennium: return "CHICAGO, ILLINOIS   ·   ART & LANDSCAPE"; case .lakefront: return "MICHIGAN AVENUE   ·   PARKS & HARBORS" }
    }
    var number: String { self == .paris ? "01" : self == .chicago ? "02" : self == .millennium ? "03" : "04" }
    /// Chicago locations share one physical scene and acceleration structure.
    var world: String { self == .paris ? "paris" : "chicago" }
    var stops: [TourStop] {
        switch self { case .paris: return EiffelScene.stops; case .chicago: return WillisScene.stops; case .millennium: return MillenniumScene.stops; case .lakefront: return LakefrontScene.stops }
    }
    func duration(view: Int) -> Double {
        switch self { case .paris: return EiffelWalkthrough.duration; case .chicago: return WillisWalkthrough.duration; case .millennium: return MillenniumWalkthrough.duration(view: view); case .lakefront: return LakefrontWalkthrough.duration(view: view) }
    }
    var walkingViews: Set<Int> {
        switch self { case .paris: return [1,3,4,5,6]; case .chicago: return WillisWalkthrough.walkingViews; case .millennium: return MillenniumWalkthrough.walkingViews; case .lakefront: return LakefrontWalkthrough.walkingViews }
    }

    func build() -> SceneData { self == .paris ? EiffelScene.build() : WillisScene.build() }
    func pose(view: Int, seconds: Double) -> CameraPose {
        switch self {
        case .paris: return EiffelWalkthrough.pose(view: view, seconds: seconds)
        case .chicago: return WillisWalkthrough.pose(view: view, seconds: seconds)
        case .millennium: return MillenniumWalkthrough.pose(view: view, seconds: seconds)
        case .lakefront: return LakefrontWalkthrough.pose(view: view, seconds: seconds)
        }
    }
    func idlePose(view: Int, seconds: Double) -> CameraPose {
        // Avoid Float overflow if a recovered clock contains a centuries-long gap.
        let safeSeconds = seconds.isFinite ? (seconds > 86_400 ? seconds.truncatingRemainder(dividingBy: 86_400) : max(0, seconds)) : 0
        switch self {
        case .paris: return EiffelWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .chicago: return WillisWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .millennium: return MillenniumWalkthrough.idlePose(view: view, seconds: safeSeconds)
        case .lakefront: return LakefrontWalkthrough.idlePose(view: view, seconds: safeSeconds)
        }
    }
}
