#!/usr/bin/env python3
"""Compose Atelier's original score from equations, without samples or downloads.

Requires Python + NumPy and FFmpeg/FFprobe. The seeded PCM composition is
deterministic; AAC bytes can differ across encoder versions. See docs/AMBIENT-MUSIC.md.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "Sources/ArchitectureEngine/Resources/Music"
RATE = 44100
COMPOSITION_VERSION = 1

# Each chord is root MIDI plus a voiced interval set. These original, short
# harmonic plans use familiar musical vocabulary; no existing melody is sampled.
MAJ9 = [0, 4, 7, 11, 14]
MIN9 = [0, 3, 7, 10, 14]
SIX9 = [0, 4, 7, 9, 14]
SUS = [0, 5, 7, 10, 14]
TRACKS = [
    dict(location="paris", title="Lanterns on the Seine", slug="lanterns-on-the-seine", bpm=58, seed=1901,
         key="D major", roots=[50, 47, 43, 45, 54, 47, 43, 50], qualities=[MAJ9, MIN9, MAJ9, SUS, MIN9, MIN9, SIX9, SIX9],
         motif=[2, 4, 3, 1, 2, 0, 1, 3], piano=1.0, pluck=0.52, pad=0.87),
    dict(location="chicago", title="Between Steel and Sky", slug="between-steel-and-sky", bpm=56, seed=1902,
         key="B-flat major", roots=[46, 43, 39, 41, 38, 43, 39, 46], qualities=[MAJ9, MIN9, MAJ9, SUS, MIN9, MIN9, SIX9, MAJ9],
         motif=[1, 2, 4, 3, 1, 0, 2, 1], piano=0.9, pluck=0.35, pad=1.0),
    dict(location="millennium", title="Clouds in Silver", slug="clouds-in-silver", bpm=62, seed=1903,
         key="E-flat major", roots=[51, 48, 44, 46, 48, 43, 44, 51], qualities=[MAJ9, MIN9, SIX9, SUS, MIN9, MIN9, MAJ9, SIX9],
         motif=[3, 2, 0, 1, 4, 2, 1, 0], piano=0.72, pluck=0.83, pad=0.8),
    dict(location="lakefront", title="A Longer Shore", slug="a-longer-shore", bpm=54, seed=1904,
         key="F major", roots=[41, 45, 38, 46, 43, 48, 46, 41], qualities=[MAJ9, MIN9, MIN9, MAJ9, MIN9, SUS, SIX9, SIX9],
         motif=[4, 2, 1, 0, 1, 3, 2, 0], piano=0.7, pluck=0.4, pad=1.0),
    dict(location="campus", title="Small Constellations", slug="small-constellations", bpm=60, seed=1905,
         key="A major", roots=[45, 42, 38, 40, 42, 49, 38, 45], qualities=[MAJ9, MIN9, MAJ9, SUS, MIN9, MIN9, SIX9, MAJ9],
         motif=[0, 3, 2, 4, 1, 2, 0, 1], piano=0.7, pluck=0.72, pad=0.91),
    dict(location="northside", title="Gardens After Rain", slug="gardens-after-rain", bpm=63, seed=1906,
         key="C major", roots=[48, 45, 41, 43, 40, 45, 41, 48], qualities=[SIX9, MIN9, MAJ9, SUS, MIN9, MIN9, SIX9, MAJ9],
         motif=[1, 3, 2, 0, 2, 4, 1, 0], piano=0.98, pluck=0.6, pad=0.77),
    dict(location="robie", title="Light Through Amber", slug="light-through-amber", bpm=55, seed=1907,
         key="A-flat major", roots=[44, 41, 37, 39, 48, 41, 37, 44], qualities=[MAJ9, MIN9, MAJ9, SUS, MIN9, MIN9, SIX9, SIX9],
         motif=[2, 1, 0, 3, 1, 2, 4, 0], piano=1.04, pluck=0.28, pad=0.86),
    dict(location="skyline", title="The City Opens", slug="the-city-opens", bpm=61, seed=1908,
         key="G major", roots=[43, 40, 36, 38, 47, 40, 36, 43], qualities=[MAJ9, MIN9, MAJ9, SUS, MIN9, MIN9, SIX9, MAJ9],
         motif=[0, 2, 3, 4, 2, 1, 3, 0], piano=0.82, pluck=0.64, pad=0.92),
    dict(location="culturalcenter", title="Light Beneath the Dome", slug="light-beneath-the-dome", bpm=57, seed=1909,
         key="D-flat major", roots=[49, 46, 42, 44, 53, 46, 42, 49], qualities=[MAJ9, MIN9, SIX9, SUS, MIN9, MIN9, MAJ9, SIX9],
         motif=[1, 4, 2, 3, 0, 2, 1, 0], piano=0.76, pluck=0.55, pad=0.90),
    dict(location="navypier", title="Turning Above the Water", slug="turning-above-the-water", bpm=59, seed=1910,
         key="E major", roots=[40, 44, 37, 45, 42, 47, 45, 40], qualities=[SIX9, MIN9, MIN9, MAJ9, MIN9, SUS, MAJ9, SIX9],
         motif=[0, 2, 4, 1, 3, 2, 1, 0], piano=0.78, pluck=0.68, pad=0.94),
]


def hz(note: float) -> float:
    return 440 * 2 ** ((note - 69) / 12)


def envelope(t: np.ndarray, duration: float, attack: float, release: float) -> np.ndarray:
    return np.sin(np.minimum(t / attack, 1) * math.pi / 2) ** 2 * np.sin(np.minimum(np.maximum(duration - t, 0) / release, 1) * math.pi / 2) ** 2


def instrument(note: int, duration: float, kind: str, rng: np.random.Generator) -> np.ndarray:
    t = np.arange(round(duration * RATE), dtype=np.float32) / RATE
    frequency = hz(note)
    phase = 2 * math.pi * frequency * t
    signal = np.zeros(len(t), dtype=np.float32)
    if kind == "pad":
        for partial, amplitude in [(1, 0.67), (2, 0.15), (3, 0.047), (4, 0.018)]:
            for detune in [-0.0011, 0.0013]:
                drift = 0.09 * np.sin(2 * math.pi * 0.075 * t + partial)
                signal += amplitude / 2 * np.sin(phase * partial * (1 + detune) + drift + partial * 0.3)
        signal *= envelope(t, duration, 1.45, 3.2)
        signal *= 0.9 + 0.1 * np.sin(t * 0.37 + 0.5)
    elif kind == "piano":
        for harmonic, amplitude in [(1, 0.80), (2.002, 0.24), (3.009, 0.10), (4.021, 0.039), (5.038, 0.014)]:
            signal += amplitude * np.sin(phase * harmonic) * np.exp(-t / (3.5 / harmonic ** 0.8))
        signal += 0.13 * np.sin(phase * 0.9992) * np.exp(-t / 3.7)
        # A very quiet, low-passed hammer softens the synthesized piano attack.
        noise = rng.standard_normal(len(t)).astype(np.float32)
        noise = np.convolve(noise, np.ones(15, dtype=np.float32) / 15, mode="same")
        signal += 0.008 * noise * np.exp(-t / 0.08)
        signal *= (1 - np.exp(-t / 0.018)) * envelope(t, duration, 0.012, 0.8)
    elif kind == "pluck":
        for harmonic, amplitude in [(1, 0.84), (2, 0.17), (3, 0.055)]:
            signal += amplitude * np.sin(phase * harmonic) * np.exp(-t / (1.9 / harmonic))
        signal *= (1 - np.exp(-t / 0.035)) * envelope(t, duration, 0.025, 0.7)
    elif kind == "bass":
        signal = (np.sin(phase) + 0.13 * np.sin(2 * phase)).astype(np.float32)
        signal *= envelope(t, duration, 0.55, 2.4)
    return signal.astype(np.float32)


def put(mix: np.ndarray, sound: np.ndarray, start: float, gain: float, pan: float) -> None:
    offset = max(0, round(start * RATE))
    count = min(len(sound), len(mix) - offset)
    if count <= 0:
        return
    angle = (pan + 1) * math.pi / 4
    mix[offset:offset + count, 0] += sound[:count] * (gain * math.cos(angle))
    mix[offset:offset + count, 1] += sound[:count] * (gain * math.sin(angle))


def voice_chord(root: int, intervals: list[int], previous: list[int] | None) -> list[int]:
    # Four sustained upper voices; closest legal register gives gentle motion.
    classes = [(root + interval) % 12 for interval in intervals[1:]]
    targets = previous or [52, 57, 62, 67]
    notes = [min([n for n in range(48, 75) if n % 12 == pitch], key=lambda n: abs(n - target))
             for pitch, target in zip(classes, targets)]
    return sorted(notes)


def compose(track: dict, path: Path) -> dict:
    rng = np.random.default_rng(track["seed"])
    beat = 60 / track["bpm"]
    bar = beat * 4
    duration = 32 * bar + 5.0
    dry = np.zeros((round(duration * RATE), 2), dtype=np.float32)
    previous = None
    events = []
    for measure in range(32):
        section = measure // 8
        dynamic = [0.76, 0.91, 1.0, 0.77][section]
        chord_index = (measure // 2) % 8
        root, quality = track["roots"][chord_index], track["qualities"][chord_index]
        if measure % 2 == 0:
            voiced = voice_chord(root, quality, previous)
            previous = voiced
            for number, note in enumerate(voiced):
                put(dry, instrument(note, 2 * bar + 3.2, "pad", rng), measure * bar,
                    0.038 * dynamic * track["pad"], [-0.47, 0.24, -0.18, 0.5][number])
                events.append([round(measure * bar, 4), "pad", note])
            bass = root - 12 if root >= 43 else root
            put(dry, instrument(bass, 2 * bar + 2.2, "bass", rng), measure * bar + 0.12,
                0.019 * dynamic, 0)
            events.append([round(measure * bar + 0.12, 4), "bass", bass])
        # A composed question/answer motif, with rests and a changed register in
        # the middle section. Rhythm and phrase contours remain intentional.
        motif_index = track["motif"][measure % 8]
        positions = [0.25, 1.75, 3.0] if measure % 4 != 3 else [0.5, 2.5]
        if section == 3 and measure % 2:
            positions = positions[:2]
        for step, position in enumerate(positions):
            interval = quality[(motif_index + [0, 2, 1][step]) % len(quality)]
            note = root + interval
            while note < 60:
                note += 12
            while note > 79:
                note -= 12
            if section == 2 and step == 1 and note <= 67:
                note += 12
            # Human-scale offsets are bounded at 25 ms, not timing randomness.
            start = measure * bar + position * beat + float(rng.uniform(-0.018, 0.025))
            gain = 0.098 * dynamic * track["piano"] * [1, 0.74, 0.64][step]
            put(dry, instrument(note, 7.0, "piano", rng), start, gain,
                [-0.19, 0.16, -0.05][step])
            events.append([round(start, 4), "piano", note])
        if measure % 2 == 1 and section != 3:
            for step, position in enumerate([1.0, 2.75]):
                note = root + quality[(measure + step + 2) % len(quality)]
                while note < 69:
                    note += 12
                while note > 84:
                    note -= 12
                start = measure * bar + position * beat
                put(dry, instrument(note, 4.5, "pluck", rng), start,
                    0.043 * dynamic * track["pluck"], [-0.52, 0.49][step])
                events.append([round(start, 4), "pluck", note])
    # A diffuse stereo room, deliberately quieter than the direct instruments.
    mix = dry.copy()
    for index, delay in enumerate([0.071, 0.113, 0.173, 0.239, 0.311, 0.419, 0.557, 0.733, 0.977, 1.213, 1.507, 1.919, 2.37]):
        samples = round(delay * RATE)
        source = dry[:-samples, ::-1] if index % 2 else dry[:-samples]
        mix[samples:] += source * (0.125 * math.exp(-delay / 1.4))
    fade_in = round(1.8 * RATE)
    fade_out = round(4.5 * RATE)
    mix[:fade_in] *= np.linspace(0, 1, fade_in, dtype=np.float32)[:, None] ** 1.3
    mix[-fade_out:] *= np.linspace(1, 0, fade_out, dtype=np.float32)[:, None] ** 1.3
    # Leave generous headroom before the two-pass loudness master.
    mix *= 0.65 / max(float(np.max(np.abs(mix))), 0.001)
    pcm = np.round(np.clip(mix, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(2); stream.setsampwidth(2); stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    return dict(durationSeconds=round(duration, 6), eventCount=len(events),
                compositionEventSHA256=hashlib.sha256(json.dumps(events, separators=(",", ":")).encode()).hexdigest(),
                sourcePCMSHA256=hashlib.sha256(pcm.tobytes()).hexdigest(),
                sections=["Opening: spacious motif", "Answer: plucked countermelody", "Lift: wider register", "Return: fewer notes and a tonic release"])


def run(command: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(command, check=True, text=True, capture_output=True)


def master(source: Path, target: Path, title: str) -> dict:
    base = ["ffmpeg", "-hide_banner", "-nostdin", "-i", str(source)]
    first = run(base + ["-af", "lowpass=f=10500,loudnorm=I=-21:TP=-3:LRA=7:print_format=json", "-f", "null", "-"])
    stats, _ = json.JSONDecoder().raw_decode(first.stderr[first.stderr.rfind("{"):])
    normalization = ("lowpass=f=10500,loudnorm=I=-21:TP=-3:LRA=7:linear=true:"
                     f"measured_I={stats['input_i']}:measured_TP={stats['input_tp']}:"
                     f"measured_LRA={stats['input_lra']}:measured_thresh={stats['input_thresh']}:"
                     f"offset={stats['target_offset']}")
    run(base + ["-af", normalization, "-ar", str(RATE), "-c:a", "aac", "-b:a", "128k",
                "-metadata", f"title={title}", "-metadata", "artist=Atelier Original Score",
                "-metadata", "album=Places in Quiet Light", "-metadata", "comment=Original procedural composition; no third-party samples.",
                "-movflags", "+faststart", "-y", str(target)])
    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DESTINATION)
    parser.add_argument("--location", choices=[track["location"] for track in TRACKS])
    args = parser.parse_args()
    if not shutil.which("ffmpeg"):
        parser.error("ffmpeg must be on PATH")
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if args.location and manifest_path.exists() else {}
    manifest.update(compositionVersion=COMPOSITION_VERSION, album="Places in Quiet Light", composer="Atelier original procedural score",
                    provenance="All notes, arrangements and synthesized timbres are original project work. No recordings, samples, downloaded music or third-party melodies are used.",
                    synthesis="Seeded NumPy additive synthesis, original 32-bar arrangements, voice-led pads, soft piano, sparse muted plucks, diffuse stereo delays.",
                    encoding="AAC LC, 128 kbit/s stereo, 44.1 kHz; two-pass target -21 LUFS, -3 dBTP, LRA 7.",
                    ffmpegVersion=run(["ffmpeg", "-version"]).stdout.splitlines()[0],
                    numpyVersion=np.__version__, generator="scripts/generate-ambient-music.py")
    existing = {track["location"]: track for track in manifest.get("tracks", [])}
    with tempfile.TemporaryDirectory(prefix="atelier-original-score-") as temporary:
        for index, track in enumerate(TRACKS):
            if args.location and track["location"] != args.location:
                continue
            source = Path(temporary) / f"{track['location']}.wav"
            filename = f"{index + 1:02}-{track['slug']}.m4a"
            print(f"Composing {track['title']}…", flush=True)
            composition = compose(track, source)
            stats = master(source, args.output / filename, track["title"])
            existing[track["location"]] = dict(location=track["location"], title=track["title"], filename=filename,
                tempoBPM=track["bpm"], key=track["key"], seed=track["seed"], **composition,
                sha256=hashlib.sha256((args.output / filename).read_bytes()).hexdigest(),
                bytes=(args.output / filename).stat().st_size, masteringInput=stats)
            manifest["tracks"] = [existing[item["location"]] for item in TRACKS if item["location"] in existing]
            manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
            print(f"Wrote {filename} ({composition['durationSeconds']:.1f} s)", flush=True)


if __name__ == "__main__":
    main()
