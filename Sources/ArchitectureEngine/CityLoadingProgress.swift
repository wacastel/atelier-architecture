import Foundation

struct CityLoadingStep: Identifiable {
    enum State: Equatable { case pending, active, completed }
    let id: String
    let title: String
    var state: State = .pending
    var duration: Double?
}

struct CityLoadingSnapshot {
    var title: String
    var currentStep: String
    var progress: Double
    var elapsed: Double
    var steps: [CityLoadingStep]
}

/// Progress counts completed preparation phases, never elapsed-time guesses.
/// Parallel navigation work has its own interval. Presentation owns the final 5%.
struct CityLoadingProgress {
    static let definitions: [(String,String,Double)] = [
        ("identity", "Checking prepared city", 0.03),
        ("geometry", "Loading buildings and streets", 0.40),
        ("navigation", "Preparing landmarks and navigation", 0.27),
        ("shaders", "Loading Metal shaders", 0.04),
        ("buffers", "Preparing GPU geometry", 0.15),
        ("lighting", "Preparing lighting", 0.02),
        ("traffic", "Preparing boats and traffic", 0.02),
        ("raster", "Preparing the viewport", 0.02),
        ("presentation", "Displaying the city", 0.05)
    ]
    private(set) var snapshot: CityLoadingSnapshot
    private var starts: [String:Double] = [:]
    private let started: Double
    init(world: String = "chicago", started: Double = ProcessInfo.processInfo.systemUptime) {
        self.started=started
        snapshot=CityLoadingSnapshot(title:world == "chicago" ? "Loading the Windy City":"Loading the City of Light",
            currentStep:"Checking prepared city",progress:0,elapsed:0,
            steps:Self.definitions.map{CityLoadingStep(id:$0.0,title:$0.1)})
    }
    mutating func begin(_ id: String, at time: Double = ProcessInfo.processInfo.systemUptime) {
        guard let i=snapshot.steps.firstIndex(where:{$0.id==id}), snapshot.steps[i].state == .pending else { return }
        starts[id]=time; snapshot.steps[i].state = .active
        snapshot.currentStep=snapshot.steps[i].title; tick(at:time)
    }
    mutating func complete(_ id: String, at time: Double = ProcessInfo.processInfo.systemUptime) {
        guard id != "presentation" else { return }
        finishStep(id,at:time)
    }
    private mutating func finishStep(_ id: String,at time: Double) {
        guard let i=snapshot.steps.firstIndex(where:{$0.id==id}),snapshot.steps[i].state != .completed else { return }
        // Only a real presentation can finish this step; callers must not infer it
        // from isReady, command submission, or a completed offscreen render.
        snapshot.steps[i].state = .completed
        snapshot.steps[i].duration=max(0,time-(starts[id] ?? time))
        let done=Set(snapshot.steps.filter{$0.state == .completed}.map(\.id))
        snapshot.progress=min(done.contains("presentation") ? 1:0.95,Self.definitions.filter{done.contains($0.0)}.reduce(0){$0+$1.2})
        if done.count==Self.definitions.count { snapshot.progress=1; snapshot.currentStep="Chicago is ready to explore" }
        else if let active=snapshot.steps.last(where:{$0.state == .active}) { snapshot.currentStep=active.title }
        else if let next=snapshot.steps.first(where:{$0.state == .pending}) { snapshot.currentStep=next.title }
        tick(at:time)
    }
    mutating func tick(at time: Double = ProcessInfo.processInfo.systemUptime) {
        guard snapshot.progress<1 else { return }
        snapshot.elapsed=max(0,time-started)
    }
    mutating func presented(at time: Double = ProcessInfo.processInfo.systemUptime) {
        guard snapshot.progress<1,time.isFinite,time>=started,
              snapshot.steps.filter({$0.id != "presentation"}).allSatisfy({$0.state == .completed}) else { return }
        snapshot.elapsed=max(0,time-started)
        finishStep("presentation",at:time)
        snapshot.currentStep=snapshot.title.contains("Windy") ? "Chicago is ready to explore":"Paris is ready to explore"
    }
}
