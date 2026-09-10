#!/usr/bin/env python3
"""Decode and measure all shipped soundtrack files; never plays audio or uses GPU."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(command, check=True, capture_output=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets", type=Path, default=ROOT / "Sources/ArchitectureEngine/Resources/Music")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    manifest = json.loads((args.assets / "manifest.json").read_text())
    checks = 0

    def expect(condition: bool, explanation: str) -> None:
        nonlocal checks
        checks += 1
        if not condition:
            raise AssertionError(explanation)

    expected_keys = ["paris", "chicago", "millennium", "lakefront", "campus", "northside", "robie", "skyline", "culturalcenter", "navypier"]
    expect([t["location"] for t in manifest["tracks"]] == expected_keys, "Incomplete or reordered soundtrack catalog")
    expect(len({t["sha256"] for t in manifest["tracks"]}) == len(expected_keys), "An audio asset is reused")
    expect(len({t["compositionEventSHA256"] for t in manifest["tracks"]}) == len(expected_keys), "Compositions share an identical event sequence")
    reports = []
    for track in manifest["tracks"]:
        path = args.assets / track["filename"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        expect(digest == track["sha256"], f"Stale manifest hash: {path.name}")
        probe = json.loads(run(["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)]).stdout)
        streams = probe["streams"]
        expect(len(streams) == 1 and streams[0]["codec_name"] == "aac", f"Expected one AAC stream: {path.name}")
        expect(streams[0]["channels"] == 2 and int(streams[0]["sample_rate"]) == 44100, f"Stereo/sample-rate mismatch: {path.name}")
        duration = float(probe["format"]["duration"])
        expect(120 <= duration <= 180, f"Track length outside 2–3 minutes: {path.name}")
        expect(abs(duration - track["durationSeconds"]) < 0.1, f"Encoder duration changed: {path.name}")
        expect(path.stat().st_size < 4_000_000, f"Unexpected asset size: {path.name}")
        decoded = run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le", "-"])
        samples = np.frombuffer(decoded.stdout, dtype="<f4").reshape(-1, 2)
        expect(bool(np.isfinite(samples).all()), f"Non-finite decoded samples: {path.name}")
        peak = float(np.max(np.abs(samples)))
        expect(peak < 0.78, f"Too little decoded sample headroom: {path.name}")
        dc = np.mean(samples, axis=0, dtype=np.float64)
        expect(float(np.max(np.abs(dc))) < 0.0005, f"DC offset: {path.name}")
        # Full decoded samples, not a duration/header-only check.
        edge_peak = float(max(np.max(np.abs(samples[:441])), np.max(np.abs(samples[-441:]))))
        expect(edge_peak < 0.003, f"Abrupt track endpoint: {path.name}")
        step_peak = float(np.max(np.abs(np.diff(samples, axis=0))))
        expect(step_peak < 0.16, f"Unexpected sharp transient: {path.name}")
        seconds = len(samples) // 44100
        windows = samples[:seconds * 44100].reshape(seconds, 44100, 2)
        rms = np.sqrt(np.mean(windows.astype(np.float64) ** 2, axis=(1, 2)))
        db = 20 * np.log10(np.maximum(rms, 1e-12))
        interior = db[5:-7]
        expect(float(np.min(interior)) > -49, f"Unexpected interior silence/dropout: {path.name}")
        expect(float(np.std(interior)) > 0.3, f"Arrangement has no measurable dynamics: {path.name}")
        expect(float(np.max(np.abs(np.diff(interior)))) < 14, f"Abrupt block-level loudness jump: {path.name}")
        left, right = samples[::100, 0], samples[::100, 1]
        correlation = float(np.corrcoef(left, right)[0, 1])
        expect(0.0 < correlation < 0.9999, f"Phase-inverted or fully mono stereo image: {path.name}")
        high_ratios = []
        for second in range(10, seconds - 10, 15):
            segment = np.mean(samples[second * 44100:(second + 1) * 44100], axis=1)
            spectrum = np.abs(np.fft.rfft(segment * np.hanning(len(segment)))) ** 2
            frequency = np.fft.rfftfreq(len(segment), 1 / 44100)
            high_ratios.append(float(np.sum(spectrum[frequency > 6000]) / max(np.sum(spectrum), 1e-20)))
        expect(max(high_ratios) < 0.005, f"Unexpected harsh high-frequency energy: {path.name}")
        loudness_result = run(["ffmpeg", "-hide_banner", "-nostdin", "-i", str(path), "-af",
                              "loudnorm=I=-21:TP=-3:LRA=7:print_format=json", "-f", "null", "-"])
        log = loudness_result.stderr.decode()
        loudness, _ = json.JSONDecoder().raw_decode(log[log.rfind("{"):])
        integrated = float(loudness["input_i"])
        true_peak = float(loudness["input_tp"])
        expect(-22.0 <= integrated <= -20.0, f"Unmatched master loudness: {path.name} ({integrated} LUFS)")
        expect(true_peak <= -2.5, f"AAC true peak lacks headroom: {path.name} ({true_peak} dBTP)")
        reports.append(dict(location=track["location"], filename=path.name, sha256=digest,
            durationSeconds=duration, bytes=path.stat().st_size, integratedLUFS=integrated,
            truePeakDBTP=true_peak, loudnessRangeLU=float(loudness["input_lra"]),
            samplePeakDBFS=20 * math.log10(peak), endpointPeak=edge_peak, maximumSampleStep=step_peak,
            interiorMinimumRMSDBFS=float(np.min(interior)), interiorRMSDeviationDB=float(np.std(interior)),
            stereoCorrelation=correlation, maximumAbove6kHzEnergyRatio=max(high_ratios),
            decodedSamplesPerChannel=len(samples)))
        print(f"PASS {path.name}: {duration:.1f} s, {integrated:.2f} LUFS, {true_peak:.2f} dBTP", flush=True)
    report = dict(passed=True, checks=checks, tracks=reports,
        totalBytes=sum(t["bytes"] for t in reports),
        scope="Full AAC decode, catalog/hash/duration/channel checks, loudness and true peak, DC/endpoint/transient/dropout measurements, stereo correlation and sampled spectral energy. These are technical audio checks; they do not substitute for subjective listening or native speaker-output QA.")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(dict(passed=True, checks=checks, totalBytes=report["totalBytes"])))


if __name__ == "__main__":
    main()
