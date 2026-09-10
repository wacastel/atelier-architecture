import Foundation
import AVFoundation

@MainActor final class FakePlayback: AmbientAudioPlayback {
    var volume: Float = 0
    var currentTime: TimeInterval = 0
    let duration: TimeInterval
    var isPlaying = false
    var starts = 0
    var pauses = 0
    var stops = 0
    var canPlay = true
    let filename: String
    init(_ filename: String, duration: TimeInterval = 130) { self.filename = filename; self.duration = duration }
    func play() -> Bool { starts += 1; isPlaying = canPlay; return canPlay }
    func pause() { pauses += 1; isPlaying = false }
    func stop() { stops += 1; isPlaying = false; currentTime = 0 }
}

@MainActor final class Harness {
    let defaults: UserDefaults
    let suite = "atelier.music.fixture.\(UUID().uuidString)"
    var now: TimeInterval = 100
    var players: [FakePlayback] = []
    var missing = Set<String>()
    var invalidDuration: TimeInterval?
    var refusePlayback = false
    var resolutions = 0
    var controller: AmbientMusicController!
    init(enabled: Bool? = nil, volume: Double? = nil) {
        defaults = UserDefaults(suiteName: suite)!
        if let enabled { defaults.set(enabled, forKey: AmbientMusicController.enabledPreference) }
        if let volume { defaults.set(volume, forKey: AmbientMusicController.volumePreference) }
        controller = AmbientMusicController(defaults: defaults, resolve: { [unowned self] name in
            self.resolutions += 1
            return self.missing.contains(name) ? nil : URL(fileURLWithPath: "/original/\(name)")
        }, makePlayer: { [unowned self] url in
            let player = FakePlayback(url.lastPathComponent, duration: self.invalidDuration ?? 130)
            player.canPlay = !self.refusePlayback
            self.players.append(player)
            return player
        }, clock: { [unowned self] in self.now }, automaticTimer: false)
    }
    func advance(_ seconds: Double) {
        now += seconds
        for player in players where player.isPlaying {
            player.currentTime = min(player.duration, player.currentTime + seconds)
            if player.currentTime >= player.duration { player.isPlaying = false }
        }
        controller.tick(now: now)
    }
    func finish() { controller.setEnabled(false); advance(1); defaults.removePersistentDomain(forName: suite) }
}

@MainActor var checks = 0
@MainActor func expect(_ value: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    precondition(value(), message)
}

@MainActor func tests() throws {
    let keys = ["paris", "chicago", "millennium", "lakefront", "campus", "northside", "robie", "skyline", "culturalcenter", "navypier"]
    expect(AmbientMusicTrack.playlist.map(\.location) == keys, "Location routing catalog is incomplete")
    expect(Set(AmbientMusicTrack.playlist.map(\.filename)).count == keys.count, "Locations share an opening asset")
    expect(Set(AmbientMusicTrack.playlist.map(\.title)).count == keys.count, "Track titles are ambiguous")
    for (index, key) in keys.enumerated() {
        let h = Harness()
        expect(h.controller.isEnabled && h.controller.volume == 0.16, "Safe initial preferences changed")
        expect(h.players.isEmpty, "Init starts audio before location selection")
        h.controller.selectLocation(key)
        expect(h.players.count == 1 && h.players[0].filename == AmbientMusicTrack.playlist[index].filename, "Incorrect assigned opening track")
        expect(h.controller.currentTitle == AmbientMusicTrack.playlist[index].title, "UI title does not match playback")
        expect(h.players[0].volume == 0, "New audio starts with a loud transient")
        h.advance(30)
        let position = h.players[0].currentTime
        h.controller.selectLocation(key)
        expect(h.players.count == 1 && h.players[0].currentTime == position, "Same-location view change restarts music")
        expect(abs(h.players[0].volume - 0.16) < 0.00001, "Initial fade never reaches preferred volume")
        h.controller.selectLocation("unknown")
        expect(h.players.count == 1, "Unknown location changed the track")
        h.finish()
    }

    let fade = Harness()
    fade.controller.selectLocation("chicago"); fade.advance(10)
    let old = fade.players[0]
    fade.controller.selectLocation("robie")
    let next = fade.players[1]
    expect(old.isPlaying && next.isPlaying && next.currentTime == 0, "Destination does not overlap/restart")
    fade.advance(1.5)
    expect(abs(old.volume * old.volume + next.volume * next.volume - 0.16 * 0.16) < 0.00001, "Crossfade power envelope has a dip/spike")
    fade.controller.setVolume(0.32)
    expect(abs(old.volume - Float(0.32 / sqrt(2))) < 0.00001, "Volume is unresponsive during crossfade")
    fade.advance(1.5)
    expect(!old.isPlaying && old.stops == 1 && next.isPlaying, "Retired track keeps consuming a decoder")
    expect(abs(next.volume - 0.32) < 0.00001, "Fade changed selected volume")
    fade.controller.setEnabled(false)
    expect(!fade.controller.isEnabled, "Off state does not update immediately")
    fade.advance(0.3)
    let pausedAt = next.currentTime
    expect(!next.isPlaying && next.volume == 0, "Off does not fade and pause")
    fade.advance(20)
    expect(next.currentTime == pausedAt && fade.players.count == 2, "Disabled playback advances")
    fade.controller.setEnabled(true); fade.advance(0.5)
    expect(next.isPlaying && next.currentTime > pausedAt && next.starts == 2, "On should resume its playhead")
    fade.controller.setVolume(0)
    expect(next.volume == 0 && next.isPlaying, "Zero-volume mute unexpectedly stops transport")
    fade.advance(3)
    expect(next.volume == 0, "Fade timer defeats mute")
    fade.controller.setVolume(5); expect(fade.controller.volume == 1, "Volume upper bound")
    fade.controller.setVolume(-2); expect(fade.controller.volume == 0, "Volume lower bound")
    fade.controller.setVolume(.nan); expect(fade.controller.volume == 0, "NaN volume entered audio device")
    fade.controller.setVolume(.infinity); expect(fade.controller.volume == 0, "Infinite volume entered audio device")
    fade.finish()

    let playlist = Harness()
    let lastLocation = keys.last!
    playlist.controller.selectLocation(lastLocation); playlist.advance(127)
    expect(playlist.players.count == 2 && playlist.controller.currentTitle == AmbientMusicTrack.playlist[0].title,
           "Playlist does not wrap after its last piece")
    playlist.advance(3.1)
    playlist.controller.selectLocation(lastLocation)
    expect(playlist.players.count == 2, "A same-location callback resets an advanced playlist")
    for index in 1..<keys.count {
        let active = playlist.players.last!
        active.currentTime = 127
        playlist.advance(0.01)
        expect(playlist.controller.currentTitle == AmbientMusicTrack.playlist[index].title, "Playlist sequence skipped a track")
        playlist.advance(3.1)
    }
    playlist.controller.selectLocation("paris")
    expect(playlist.players.last!.filename == AmbientMusicTrack.playlist[0].filename && playlist.players.last!.currentTime == 0,
           "A real location change does not restore its assigned opening piece")
    playlist.finish()

    let disabled = Harness(enabled: false, volume: 0.27)
    disabled.controller.selectLocation("paris"); disabled.controller.selectLocation("campus")
    expect(disabled.players.isEmpty && disabled.controller.currentTitle == AmbientMusicTrack.playlist[4].title,
           "Disabled selection unnecessarily decodes audio or leaves the wrong title")
    disabled.controller.setEnabled(true)
    expect(disabled.players.count == 1 && disabled.players[0].filename == AmbientMusicTrack.playlist[4].filename,
           "Enable starts the wrong deferred destination")
    disabled.controller.setVolume(0.23); disabled.controller.setEnabled(false); disabled.advance(1)
    let restored = AmbientMusicController(defaults: disabled.defaults, resolve: { _ in nil },
        makePlayer: { _ in preconditionFailure("Preference restoration must not open an audio device") }, automaticTimer: false)
    expect(!restored.isEnabled && restored.volume == 0.23, "Preferences were not persisted")
    disabled.finish()

    let failures = Harness()
    failures.controller.selectLocation("chicago"); failures.advance(10)
    failures.missing.insert(AmbientMusicTrack.playlist[6].filename)
    failures.controller.selectLocation("robie")
    expect(failures.players.count == 1 && failures.players[0].isPlaying && failures.controller.errorMessage != nil,
           "Missing track cuts off existing audio")
    let resolvedBeforeRetry = failures.resolutions
    for _ in 0..<10 { failures.advance(0.3); failures.controller.selectLocation("robie") }
    expect(failures.resolutions == resolvedBeforeRetry, "Repeated engine synchronization bypasses failure backoff")
    failures.missing.removeAll(); failures.advance(2.1); failures.controller.selectLocation("robie")
    expect(failures.players.count == 2 && failures.controller.errorMessage == nil, "Missing asset could not recover")
    failures.advance(4)
    failures.invalidDuration = 1
    failures.controller.selectLocation("campus")
    expect(failures.controller.currentTitle == AmbientMusicTrack.playlist[6].title, "Corrupt-duration track replaced playing title")
    failures.invalidDuration = nil; failures.refusePlayback = true; failures.advance(5.1)
    failures.controller.selectLocation("campus")
    expect(failures.players[1].isPlaying && failures.controller.errorMessage != nil, "Device start failure stops old piece")
    failures.refusePlayback = false; failures.advance(5.1)
    failures.controller.selectLocation("campus")
    expect(failures.controller.currentTitle == AmbientMusicTrack.playlist[4].title, "Device start failure cannot recover")
    failures.controller.tick(now: .nan)
    expect(failures.players.last!.volume.isFinite, "Invalid tick produces invalid gain")
    failures.finish()

    let burst = Harness()
    for step in 0..<80 {
        burst.controller.selectLocation(keys[step % keys.count])
        burst.advance(0.01)
        expect(burst.players.filter(\.isPlaying).count <= 4, "Rapid locations create unbounded active decoders")
        expect(burst.players.allSatisfy { $0.volume >= 0 && $0.volume <= 1 }, "Burst produces invalid volume")
    }
    burst.advance(4)
    expect(burst.players.filter(\.isPlaying).count == 1, "Burst leaves orphaned audio")
    burst.finish()

    // Real bundled codec decoding through AVFoundation, without playing sound.
    var assetReports: [[String: Any]] = []
    if CommandLine.arguments.contains("--assets") {
        for track in AmbientMusicTrack.playlist {
            guard let url = AmbientMusicController.resourceURL(track.filename) else { fatalError("Missing asset \(track.filename)") }
            let file = try AVAudioFile(forReading: url)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            expect(duration >= 120 && duration <= 180, "Track duration is outside the agreed 2–3 minutes")
            expect(file.processingFormat.channelCount == 2, "Track lost its stereo image")
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 44100)!
            try file.read(into: buffer)
            expect(buffer.frameLength > 0, "AVFoundation cannot decode bundled AAC")
            assetReports.append(["location": track.location, "durationSeconds": duration, "channels": 2])
        }
    }
    let report: [String: Any] = ["passed": true, "checks": checks, "assets": assetReports,
        "scope": "Actual controller with fake audio device and deterministic clock: all \(keys.count) assignments, view idempotence, equal-power crossfade, interrupted fades, off/resume/mute, persisted preferences, playlist wrap, error recovery, bounded decoder lifecycle. Optional bundled AAC decoding uses AVAudioFile without opening audio playback."]
    print(String(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
}

try MainActor.assumeIsolated { try tests() }
