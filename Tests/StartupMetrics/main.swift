import Foundation
import QuartzCore

var checks = 0
var failures: [String] = []
func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !value() { failures.append(message) }
}
guard let path = StartupMetrics.argument("--startup-report"), !StartupMetrics.benchmark else {
    fatalError("This bounded test requires --startup-report and must not terminate AppKit.")
}
let url = URL(fileURLWithPath: path)
func report() -> [String: Any] {
    guard let data = try? Data(contentsOf: url), let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
    return result
}
func completedReport() -> [String: Any] {
    let deadline = ProcessInfo.processInfo.systemUptime + 4
    while ProcessInfo.processInfo.systemUptime < deadline {
        let current = report()
        if current["cachePersistenceAfterFirstFrameSeconds"] != nil { return current }
        Thread.sleep(forTimeInterval: 0.005)
    }
    return report()
}

let metrics = StartupMetrics()
metrics.set("world", "chicago")
metrics.set("staticTriangles", 46_966_436)
metrics.set("scenePreparationSeconds", 1.25)
metrics.set("rendererCaches", ["pipelines": ["hits": 18], "rasterBatches": ["hit": false]])
let firstGate = DispatchSemaphore(value: 0)
let firstStarted = DispatchSemaphore(value: 0)
let firstTime = metrics.started + 0.1
metrics.presented(at: firstTime, exactTimestamp: true) {
    firstStarted.signal()
    _ = firstGate.wait(timeout: .now() + 4)
    return "first-city-write-error"
}
expect(firstStarted.wait(timeout: .now() + 2) == .success, "First-world persistence starts asynchronously")
let initial = report()
expect(initial["world"] as? String == "chicago", "First presentation writes the original world immediately")
expect(initial["cachePersistenceAfterFirstFrameSeconds"] == nil, "Initial report does not wait for cache persistence")
expect(initial["firstPresentedUptime"] as? Double == firstTime, "Initial report has the actual first presentation timestamp")

// Start a second world while the first world's disk write is deliberately held.
metrics.set("world", "paris")
metrics.set("staticTriangles", 123)
metrics.set("scenePreparationSeconds", 99.0)
metrics.set("rendererCaches", ["pipelines": ["hits": 0], "rasterBatches": ["hit": true]])
let secondDone = DispatchSemaphore(value: 0)
metrics.presented(at: firstTime + 1, exactTimestamp: false) {
    secondDone.signal()
    return "second-city-write-error"
}
expect(secondDone.wait(timeout: .now() + 2) == .success, "Second-world persistence still runs")
expect(report()["world"] as? String == "chicago", "Second presentation does not replace the launch report")
firstGate.signal()
let completed = completedReport()
expect(completed["cachePersistenceAfterFirstFrameSeconds"] != nil, "First-world persistence completion is recorded")
expect(completed["world"] as? String == "chicago", "Completed report retains the first world's identity")
expect(completed["staticTriangles"] as? Int == 46_966_436, "Completed report retains the first world's triangle count")
expect(completed["scenePreparationSeconds"] as? Double == 1.25, "Completed report retains first-world phase timings")
let caches = completed["rendererCaches"] as? [String: Any]
let pipelines = caches?["pipelines"] as? [String: Any]
expect(pipelines?["hits"] as? Int == 18, "Nested renderer metadata remains part of the first snapshot")
expect(completed["firstPresentedUptime"] as? Double == firstTime && completed["actualPresentTimestampAvailable"] as? Bool == true, "Later presentation cannot change launch timestamp/source")
expect(completed["cacheWriteError"] as? String == "first-city-write-error", "Cache error belongs to the first world's work, not the later world")

let success = StartupMetrics()
success.set("world", "chicago")
success.presented(at: success.started + 0.1, exactTimestamp: false) { nil }
let successReport = completedReport()
expect(successReport["cachePersistenceAfterFirstFrameSeconds"] != nil && successReport["cacheWriteError"] == nil, "Successful persistence records duration without a prior error")
expect(successReport["timingSource"] as? String == "presentation callback (OS timestamp unavailable)", "Callback proxy retains its explicit label")

let warm = StartupMetrics()
warm.set("world", "chicago")
warm.presented(at: warm.started + 0.1, exactTimestamp: true)
let warmReport = report()
expect(warmReport["passed"] as? Bool == true && warmReport["cachePersistenceAfterFirstFrameSeconds"] == nil, "Warm-cache startup writes a report without scheduling persistence")
warm.set("world", "paris")
warm.presented(at: warm.started + 1, exactTimestamp: true)
expect(report()["world"] as? String == "chicago", "Repeated no-write presentation retains the launch report")

let output: [String: Any] = ["passed": failures.isEmpty, "checks": checks, "failures": failures,
    "scope": "Actual StartupMetrics class with bounded semaphore-controlled overlapping world persistence; no native window, renderer, city build, or GPU work."]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]))
print("")
if !failures.isEmpty { exit(1) }
