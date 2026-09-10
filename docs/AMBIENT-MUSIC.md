# Places in Quiet Light — Atelier's original soundtrack

Atelier 2.5 includes ten original ambient instrumental pieces, one opening piece for each location. The music is synthesized and bundled with the app. Playback needs no account, network connection, streaming service, or additional download.

The score uses soft piano-like tones, warm sustained harmonies, restrained bass, and occasional muted plucks. Every piece has a 32-bar arrangement with four sections: an opening motif, a countermelody, a modest rise in register, and a quieter return. These are original compositions and synthesized timbres, not recordings of a piano or licensed third-party music.

| Location key | Assigned opening piece | Duration | Tempo / tonal center |
| --- | --- | --- | --- |
| `paris` | Lanterns on the Seine | 2:17 | 58 BPM / D major |
| `chicago` | Between Steel and Sky | 2:22 | 56 BPM / B-flat major |
| `millennium` | Clouds in Silver | 2:09 | 62 BPM / E-flat major |
| `lakefront` | A Longer Shore | 2:27 | 54 BPM / F major |
| `campus` | Small Constellations | 2:13 | 60 BPM / A major |
| `northside` | Gardens After Rain | 2:07 | 63 BPM / C major |
| `robie` | Light Through Amber | 2:25 | 55 BPM / A-flat major |
| `skyline` | The City Opens | 2:11 | 61 BPM / G major |
| `culturalcenter` | Light Beneath the Dome | 2:20 | 57 BPM / D-flat major |
| `navypier` | Turning Above the Water | 2:15 | 59 BPM / E major |

These are ten pieces total. Each location chooses its own opening piece, then playback continues through the shared playlist in the order above, wrapping from the last piece to the first. The Navy Pier track was generated on its own; the previous nine encoded audio files remain unchanged.

## Playback and integration

`Sources/ArchitectureEngine/AmbientMusic.swift` provides `@MainActor AmbientMusicController`, an `ObservableObject`. It publishes read-only `isEnabled`, `volume`, `currentTitle`, and optional `errorMessage`. Its public app-facing methods are:

```swift
let music = AmbientMusicController()
music.selectLocation("chicago")
music.setEnabled(true)
music.setVolume(0.16)
```

The default is enabled at volume **0.16**. Enabled state and volume persist in `UserDefaults` under `atelier.ambientMusic.enabled` and `atelier.ambientMusic.volume`. Restoring the controller alone does not start a device; the app first supplies its current location.

- A different location starts its assigned piece from the beginning, with a three-second crossfade from the previous piece.
- Repeated selection of the same location does nothing to the transport. Changing a view or synchronizing the UI therefore preserves the music, including after the playlist has advanced.
- Three seconds before a piece ends, the next playlist piece starts with an overlapping equal-power fade. Every file also has quiet attack and release edges. A wrap is a crossfade between compositions, rather than a sample-exact loop of one waveform.
- Turning music off immediately updates the UI, fades out over 250 ms, and pauses the current playhead. Turning it on resumes that playhead with a short fade. Selecting a location while off changes the pending opening piece without opening a decoder.
- Volume changes apply immediately during a crossfade. Volume zero mutes while the transport continues. Values are clamped to 0–1; non-finite input is ignored.
- Under rapid location changes, old decoders retire promptly and no more than four play at once. A missing or invalid file leaves the existing piece intact and exposes an error. Repeated attempts at the same failed destination are limited to one every five seconds.

The native adapter uses `AVAudioPlayer`; fade and playlist timing run on a 30 Hz main-run-loop timer in common modes. This is independent of rendering frames, day/night lighting, view idle timing, and walkthrough speed. The controller does not change system volume, the display, or the audio output device. Root app integration owns the music controls and location callbacks.

The assets live in `Sources/ArchitectureEngine/Resources/Music/`. The existing Swift package copies `Resources` recursively and already links AVFoundation, so no new package dependency is required. Resource lookup tries the self-contained app bundle first, then development and SwiftPM locations. Exported video audio is a separate integration concern; this player does not add an audio track to a movie encoder.

## Original composition and reproducible assets

[`scripts/generate-ambient-music.py`](../scripts/generate-ambient-music.py) contains the complete musical plans, deterministic seeds, note scheduling, and synthesis. It uses NumPy and FFmpeg, with no network access or third-party samples. Pads use restrained harmonic partials and mild detuning; the piano-like voice has a soft attack and independently decaying partials; plucks are sparse and rounded. Chord tones move into nearby registers. A quiet stereo delay field gives the instruments space.

The generator creates stereo 44.1 kHz PCM, then performs a two-pass loudness master targeting **−21 LUFS**, with a **−3 dBTP ceiling**. It encodes AAC LC at 128 kbit/s. The nine shipped files total **20,019,519 bytes** (about 19.1 MiB). Each track is under 2.4 MB.

```bash
# From the repository root, using a Python environment containing NumPy:
python3 scripts/generate-ambient-music.py

# Recompose a single piece, preserving the other manifest entries:
python3 scripts/generate-ambient-music.py --location culturalcenter

# Generate an isolated set for comparison without changing shipped assets:
python3 scripts/generate-ambient-music.py --output output/music-candidate
```

FFmpeg and FFprobe must be on `PATH`. This project was generated with the bundled Python runtime's NumPy; exact versions are recorded in `Resources/Music/manifest.json`. The manifest records each piece's seed, event count, event hash, synthesized PCM hash, encoded file hash, duration, and mastering input measurements. PCM composition is deterministic for the recorded environment; AAC byte identity can depend on the FFmpeg encoder version. Keep the generator and manifest with the assets when changing the score.

All note sequences, arrangements, and synthesized audio in this soundtrack were created for this project. No downloaded recording, existing song melody, artist imitation, sampled instrument library, or external music license is involved. Familiar chords and synthesis techniques are musical vocabulary, rather than source recordings. The generated assets follow the repository's distribution terms.

## Validation and acceptance scope

```bash
# Production transport logic through a deterministic clock and fake audio device:
bash scripts/validate-ambient-music.sh

# Also decode every actual bundled AAC through AVFoundation, without playback:
bash scripts/validate-ambient-music.sh --assets

# Fully decode and measure all audio; this command does not play sound:
python3 scripts/validate-ambient-audio.py \
  --output output/ambient-music-review/audio-technical.json
```

### Version 2.3.0

The nine-track production controller and AAC-decode fixture passes [299 checks](validation/v2.3/ambient-music.json), and full-file audio measurement passes [165 checks](validation/v2.3/ambient-audio.json). The new piece is 139.737 seconds long and measures −21.02 LUFS and −8.36 dBTP. Its manifest includes the original composition seed, note-event hash, synthesized PCM hash and encoded file hash. The previous eight encoded files were compared before and after generation and are [unchanged](validation/v2.3/music-preservation.json). These checks do not play sound or establish native speaker output.

The [final 2.3.0 native app review](validation/v2.3/native-review.json) confirms that selecting the Cultural Center displays **Light Beneath the Dome** as Now Playing at **16% volume**. The [package integrity report](validation/v2.3/package.json) verifies that its new AAC and the other 26 bundled resources match source. This establishes the new destination's native music assignment and displayed controls; it does not claim a subjective listening or speaker-output assessment. [Native music capture](validation/v2.3/native/cultural-music.jpg).

### Historical version 2.1.0

The initial accepted controller and codec run passed **287 checks**. It exercises all eight location assignments, same-location idempotence, playlist wrap, power continuity across ordinary fades, volume changes during overlap, off/resume/mute, persistent settings, failed-resource backoff and recovery, decoder bounds during 80 rapid changes, and actual AAC decoding with `AVAudioFile`.

The audio measurement suite passed **147 checks** over every decoded sample. Encoded masters measured **−21.01 to −21.02 LUFS**, with true peaks between **−9.69 and −8.27 dBTP**, leaving substantial headroom. The checks include duration and channel count, manifest hashes, clipping/headroom, DC offset, quiet file edges, sample discontinuities, interior dropouts, stereo correlation, dynamic variation, and sampled high-frequency energy. Results are retained in [`validation/v2.1/ambient-music/`](validation/v2.1/ambient-music/).

Technical measurements cannot determine whether a listener finds a composition pleasant. No reliable perceptual listening tool was available to the composition agent, so these results do not claim a subjective listening pass or native speaker-output acceptance. The app review should audition the openings and middle sections, change locations during a fade, mute and resume, and verify that the volume remains comfortable on the selected speakers. Speaker-output and UI integration checks belong to the final native app review.

The [packaged native UI review](validation/v2.1/native-review.json) subsequently verified the 16% initial volume, on/off state, volume changes, natural playlist advancement, and the Willis/Skyline assigned opening titles. This establishes UI and routing behavior; it does not add a subjective listening or speaker-output claim.
