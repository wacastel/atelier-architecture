import Foundation
import QuartzCore
import AppKit

/// Measures the city drawable's presentation notification, not window creation.
/// Invalid drawable timestamps are ignored by the renderer's presentation probe.
final class StartupMetrics: @unchecked Sendable {
    static let shared = StartupMetrics()
    let started = CACurrentMediaTime()
    private let lock = NSLock()
    private var values: [String: Any] = [:]
    private var didPresent = false
    private var rayPreparationReport: [String:Any] = [:]
    static var arguments: [String] { Array(CommandLine.arguments.dropFirst()) }
    static func argument(_ flag: String) -> String? {
        let a=arguments
        guard let i=a.firstIndex(of:flag), i+1<a.count else { return nil }
        return a[i+1]
    }
    static var benchmark: Bool { arguments.contains("--startup-exit-after-first-frame") }
    func set(_ key: String,_ value: Any) {
        lock.lock(); values[key]=value; lock.unlock()
        if Self.benchmark { fputs("Startup \(key): \(value)\n",stderr) }
    }
    func mark(_ key: String) { set(key,CACurrentMediaTime()-started) }
    func recordRayPreparation(presentationUptime: Double,seconds: Double,buildSeconds: Double?,error: String?) {
        lock.lock();defer { lock.unlock() }
        // A superseded load may never present. Ownership follows the actual
        // first visible drawable, rather than an assumed load generation.
        guard didPresent,values["firstPresentedUptime"] as? Double == presentationUptime else { return }
        var report: [String:Any] = ["rayTracingPreparationSucceeded":error == nil]
        if let error {
            report["rayTracingPreparationFailedSeconds"]=seconds
            report["rayTracingPreparationError"]=error
        } else { report["rayTracingReadySeconds"]=seconds }
        if let buildSeconds { report["backgroundAccelerationBuildSeconds"]=buildSeconds }
        rayPreparationReport=report
    }
    private func writeReport(_ report: [String: Any]) {
        do {
            let destination: URL
            if let path=Self.argument("--startup-report") { destination=URL(fileURLWithPath:path) }
            else { destination=FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Atelier/last-startup.json") }
            try FileManager.default.createDirectory(at:destination.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:destination,options:.atomic)
        } catch { fputs("Startup report: \(error.localizedDescription)\n",stderr) }
    }
    func presented(at uptime: Double,exactTimestamp: Bool,afterPresentation work: (() -> String?)? = nil) {
        guard uptime.isFinite,uptime>0 else { return }
        lock.lock()
        let first = !didPresent
        if first {
            didPresent=true
            values["firstCityPresentedSeconds"]=uptime-started
            values["firstPresentedUptime"]=uptime
            values["appStartedUptime"]=started
            values["clock"]="mach monotonic uptime"
            values["actualPresentTimestampAvailable"]=exactTimestamp
            values["timingSource"]=exactTimestamp ? "drawable presentedTime":"presentation callback (OS timestamp unavailable)"
            if let raw=ProcessInfo.processInfo.environment["ATELIER_LAUNCH_UPTIME"],let spawn=Double(raw),spawn<=started {
                values["launchToFirstPresentedSeconds"]=uptime-spawn
                values["processSpawnUptime"]=spawn
            }
            values["passed"]=true
        }
        // Future world loads update their own preparation fields. Preserve the
        // launch's metadata before asynchronous persistence can overlap them.
        let firstReport = first ? values : nil
        lock.unlock()
        if let firstReport { writeReport(firstReport) }
        // Persist a newly visited second world too, without replacing launch time.
        let finish = {
            if first && Self.benchmark { DispatchQueue.main.async { NSApplication.shared.terminate(nil) } }
        }
        if let work {
            DispatchQueue.global(qos:.utility).async {
                let start=CACurrentMediaTime(), error=work()
                if let error { fputs("City cache persistence: \(error)\n",stderr) }
                if var report=firstReport {
                    self.lock.lock();let rayReport=self.rayPreparationReport;self.lock.unlock()
                    report.merge(rayReport){_,new in new}
                    report["postPresentationWorkSeconds"]=CACurrentMediaTime()-start
                    if rayReport.isEmpty { report["cachePersistenceAfterFirstFrameSeconds"]=CACurrentMediaTime()-start }
                    if let error { report["cacheWriteError"]=error }
                    self.writeReport(report)
                }
                finish()
            }
        } else { finish() }
    }
}
