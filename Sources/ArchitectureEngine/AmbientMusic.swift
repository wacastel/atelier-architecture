import Foundation
import Combine
import AVFoundation

struct AmbientMusicTrack: Equatable, Sendable {
    let location: String
    let title: String
    let filename: String

    static let playlist: [AmbientMusicTrack] = [
        .init(location: "paris", title: "Lanterns on the Seine", filename: "01-lanterns-on-the-seine.m4a"),
        .init(location: "chicago", title: "Between Steel and Sky", filename: "02-between-steel-and-sky.m4a"),
        .init(location: "millennium", title: "Clouds in Silver", filename: "03-clouds-in-silver.m4a"),
        .init(location: "lakefront", title: "A Longer Shore", filename: "04-a-longer-shore.m4a"),
        .init(location: "campus", title: "Small Constellations", filename: "05-small-constellations.m4a"),
        .init(location: "northside", title: "Gardens After Rain", filename: "06-gardens-after-rain.m4a"),
        .init(location: "robie", title: "Light Through Amber", filename: "07-light-through-amber.m4a"),
        .init(location: "skyline", title: "The City Opens", filename: "08-the-city-opens.m4a"),
        .init(location: "culturalcenter", title: "Light Beneath the Dome", filename: "09-light-beneath-the-dome.m4a"),
        .init(location: "navypier", title: "Turning Above the Water", filename: "10-turning-above-the-water.m4a")
    ]
}

/// The device seam lets the production transport be exercised without opening
/// an audio device. Tests use the same fade, routing and playlist implementation.
@MainActor protocol AmbientAudioPlayback: AnyObject {
    var volume: Float { get set }
    var currentTime: TimeInterval { get set }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    func play() -> Bool
    func pause()
    func stop()
}

@MainActor private final class NativeAmbientPlayback: AmbientAudioPlayback {
    private let player: AVAudioPlayer
    init(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player.numberOfLoops = 0
        guard player.prepareToPlay() else {
            throw NSError(domain: "Atelier.AmbientMusic", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Could not prepare the bundled soundtrack."])
        }
    }
    var volume: Float { get { player.volume } set { player.volume = newValue } }
    var currentTime: TimeInterval { get { player.currentTime } set { player.currentTime = newValue } }
    var duration: TimeInterval { player.duration }
    var isPlaying: Bool { player.isPlaying }
    func play() -> Bool { player.play() }
    func pause() { player.pause() }
    func stop() { player.stop() }
}

/// Offline soundtrack transport. A location chooses its own opening piece;
/// afterward the pieces form a continuous playlist, independent of views.
@MainActor final class AmbientMusicController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var volume: Double
    @Published private(set) var currentTitle: String
    @Published private(set) var errorMessage: String?

    static let defaultVolume = 0.16
    static let crossfadeDuration: TimeInterval = 3.0
    static let enabledPreference = "atelier.ambientMusic.enabled"
    static let volumePreference = "atelier.ambientMusic.volume"

    @MainActor private final class Voice {
        let player: AmbientAudioPlayback
        let index: Int
        var gain: Double = 0
        var from: Double = 0
        var to: Double = 0
        var started: TimeInterval = 0
        var interval: TimeInterval = 0
        var pauseWhenSilent = false
        init(player: AmbientAudioPlayback, index: Int) { self.player = player; self.index = index }
        func fade(to value: Double, duration: TimeInterval, now: TimeInterval) {
            from = gain; to = value; started = now; interval = duration
        }
        func update(now: TimeInterval, volume: Double) -> Bool {
            let t = min(1, max(0, (now - started) / max(0.001, interval)))
            // Equal-power interpolation keeps an ordinary crossfade gentle.
            let shaped = 0.5 - 0.5 * cos(t * .pi)
            gain = sqrt(max(0, from * from * (1 - shaped) + to * to * shaped))
            player.volume = Float(gain * volume)
            return t >= 1
        }
    }

    private let defaults: UserDefaults
    private let resolve: (String) -> URL?
    private let makePlayer: (URL) throws -> AmbientAudioPlayback
    private let clock: () -> TimeInterval
    private let automaticTimer: Bool
    private var timer: Timer?
    private var voices: [Voice] = []
    private var current: Voice?
    private var assignedIndex = 1
    private var selectedLocation: String?
    private var retryAfter: TimeInterval = 0
    private var failedIndex: Int?

    convenience init() {
        self.init(defaults: .standard, resolve: Self.resourceURL,
                  makePlayer: { try NativeAmbientPlayback(url: $0) })
    }

    /// Dependency injection is internal: app callers use the parameterless init.
    init(defaults: UserDefaults, resolve: @escaping (String) -> URL?,
         makePlayer: @escaping (URL) throws -> AmbientAudioPlayback,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         automaticTimer: Bool = true) {
        self.defaults = defaults; self.resolve = resolve; self.makePlayer = makePlayer
        self.clock = clock; self.automaticTimer = automaticTimer
        isEnabled = (defaults.object(forKey: Self.enabledPreference) as? Bool) ?? true
        let saved = (defaults.object(forKey: Self.volumePreference) as? NSNumber)?.doubleValue
        volume = saved.map { $0.isFinite ? min(1, max(0, $0)) : Self.defaultVolume } ?? Self.defaultVolume
        currentTitle = AmbientMusicTrack.playlist[assignedIndex].title
        // Do not start a device until the app supplies its initial location.
    }

    deinit { timer?.invalidate() }

    func setEnabled(_ value: Bool) {
        guard value != isEnabled else { return }
        let now = clock()
        tick(now: now)
        isEnabled = value
        defaults.set(value, forKey: Self.enabledPreference)
        if value {
            if let current {
                current.pauseWhenSilent = false
                if !current.player.isPlaying && !current.player.play() {
                    errorMessage = "The soundtrack could not resume."
                }
                current.fade(to: 1, duration: 0.45, now: now)
                startTimer()
            } else if selectedLocation != nil {
                _ = activate(index: assignedIndex, duration: 0.8, now: now)
            }
        } else {
            for voice in voices {
                voice.pauseWhenSilent = voice === current
                voice.fade(to: 0, duration: 0.25, now: now)
            }
            if !voices.isEmpty { startTimer() }
        }
    }

    func setVolume(_ value: Double) {
        guard value.isFinite else { return }
        volume = min(1, max(0, value))
        defaults.set(volume, forKey: Self.volumePreference)
        // Volume changes do not wait for the fade timer, even when muted.
        for voice in voices { voice.player.volume = Float(voice.gain * volume) }
    }

    func selectLocation(_ rawValue: String) {
        guard let index = AmbientMusicTrack.playlist.firstIndex(where: { $0.location == rawValue }),
              rawValue != selectedLocation else { return }
        let now = clock()
        if isEnabled {
            guard activate(index: index, duration: current == nil ? 0.8 : Self.crossfadeDuration, now: now) else { return }
        } else {
            // An off-state destination is prepared logically without opening a device.
            for voice in voices { voice.player.stop() }
            voices.removeAll(); current = nil
            stopTimer()
            currentTitle = AmbientMusicTrack.playlist[index].title
        }
        selectedLocation = rawValue
        assignedIndex = index
    }

    private func activate(index: Int, duration: TimeInterval, now: TimeInterval) -> Bool {
        // Engine synchronization can call selectLocation several times a second.
        // A failed destination must not repeatedly open a decoder or hit disk.
        if failedIndex == index && now < retryAfter { return false }
        let track = AmbientMusicTrack.playlist[index]
        do {
            guard let url = resolve(track.filename) else {
                throw NSError(domain: "Atelier.AmbientMusic", code: 2,
                              userInfo: [NSLocalizedDescriptionKey: "Missing bundled music: \(track.filename)"])
            }
            let player = try makePlayer(url)
            guard player.duration.isFinite, player.duration > Self.crossfadeDuration + 1 else {
                throw NSError(domain: "Atelier.AmbientMusic", code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "The soundtrack has an invalid duration."])
            }
            player.volume = 0
            player.currentTime = 0
            guard player.play() else {
                throw NSError(domain: "Atelier.AmbientMusic", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "The soundtrack could not start."])
            }
            for voice in voices {
                _ = voice.update(now: now, volume: volume)
                voice.pauseWhenSilent = false
                voice.fade(to: 0, duration: voice === current ? duration : min(0.3, duration), now: now)
            }
            // Bound decoder use under rapid repeated location changes. The
            // quietest already-retiring voice is discarded only during a burst.
            if voices.count >= 4, let quietest = voices.min(by: { $0.gain < $1.gain }) {
                quietest.player.stop(); voices.removeAll { $0 === quietest }
            }
            let voice = Voice(player: player, index: index)
            voice.fade(to: 1, duration: duration, now: now)
            voices.append(voice); current = voice
            currentTitle = track.title; errorMessage = nil; retryAfter = 0; failedIndex = nil
            startTimer()
            return true
        } catch {
            errorMessage = error.localizedDescription
            retryAfter = now + 5
            failedIndex = index
            return false
        }
    }

    /// Also exercised with a deterministic clock by the audio-device-free tests.
    func tick(now: TimeInterval) {
        guard now.isFinite else { return }
        var retired: [Voice] = []
        for voice in voices {
            if voice.update(now: now, volume: volume), voice.to == 0 {
                if voice.pauseWhenSilent { voice.player.pause() }
                else { voice.player.stop(); retired.append(voice) }
            }
        }
        voices.removeAll { v in retired.contains { $0 === v } }
        if isEnabled, let current, now >= retryAfter,
           current.player.duration - current.player.currentTime <= Self.crossfadeDuration || !current.player.isPlaying {
            _ = activate(index: (current.index + 1) % AmbientMusicTrack.playlist.count,
                         duration: Self.crossfadeDuration, now: now)
        }
        if !isEnabled && voices.allSatisfy({ !$0.player.isPlaying }) { stopTimer() }
    }

    private func startTimer() {
        guard automaticTimer, timer == nil else { return }
        let newTimer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.tick(now: self.clock())
            }
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    static func resourceURL(_ filename: String) -> URL? {
        var roots: [URL] = []
        if let resources = Bundle.main.resourceURL {
            roots.append(resources.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/Music"))
            roots.append(resources.appendingPathComponent("Resources/Music"))
        }
        roots.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/ArchitectureEngine/Resources/Music"))
        for root in roots {
            let candidate = root.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        #if SWIFT_PACKAGE
        let candidate = Bundle.module.bundleURL.appendingPathComponent("Resources/Music/\(filename)")
        if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        #endif
        return nil
    }
}
