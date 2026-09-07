import Foundation

/// Scene metadata and camera routing shared by the app, exports, and validation.
enum ArchitectureLocation: String, CaseIterable, Identifiable {
    case paris
    case chicago

    var id: String { rawValue }
    var name: String { self == .paris ? "Eiffel Tower" : "Willis Tower" }
    var shortName: String { self == .paris ? "Paris" : "Chicago" }
    var subtitle: String { self == .paris ? "PARIS, FRANCE   ·   1889" : "CHICAGO, ILLINOIS   ·   1973" }
    var number: String { self == .paris ? "01" : "02" }
    var stops: [TourStop] { self == .paris ? EiffelScene.stops : WillisScene.stops }
    var duration: Double { self == .paris ? EiffelWalkthrough.duration : WillisWalkthrough.duration }
    var walkingViews: Set<Int> { self == .paris ? [1, 3, 4, 5, 6] : WillisWalkthrough.walkingViews }

    func build() -> SceneData { self == .paris ? EiffelScene.build() : WillisScene.build() }
    func pose(view: Int, seconds: Double) -> CameraPose {
        self == .paris ? EiffelWalkthrough.pose(view: view, seconds: seconds) : WillisWalkthrough.pose(view: view, seconds: seconds)
    }
    func idlePose(view: Int, seconds: Double) -> CameraPose {
        // Avoid Float overflow if a recovered clock contains a centuries-long gap.
        let safeSeconds = seconds.isFinite ? (seconds > 86_400 ? seconds.truncatingRemainder(dividingBy: 86_400) : max(0, seconds)) : 0
        return self == .paris ? EiffelWalkthrough.idlePose(view: view, seconds: safeSeconds) : WillisWalkthrough.idlePose(view: view, seconds: safeSeconds)
    }
}
