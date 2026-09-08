#!/usr/bin/env python3
"""Check an existing export's complete decode and exact presentation cadence."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("video", type=Path)
parser.add_argument("--seconds", type=float, required=True)
parser.add_argument("--fps", type=int, default=24)
parser.add_argument("--report", type=Path)
args = parser.parse_args()
if not math.isfinite(args.seconds) or args.seconds <= 0 or args.fps <= 0:
    parser.error("seconds and fps must be finite positive values")
if not args.video.is_file():
    parser.error(f"video does not exist: {args.video}")
ffprobe, ffmpeg = shutil.which("ffprobe"), shutil.which("ffmpeg")
if not ffprobe or not ffmpeg:
    parser.error("ffprobe and ffmpeg must be available on PATH")

probe = json.loads(subprocess.check_output([
    ffprobe, "-v", "error", "-select_streams", "v:0", "-count_frames",
    "-show_frames", "-show_entries", "frame=best_effort_timestamp_time",
    "-show_streams", "-show_format", "-of", "json", str(args.video)
], text=True))
frames = probe.pop("frames", [])
timestamps = [float(frame["best_effort_timestamp_time"]) for frame in frames]
expected = int(args.seconds * args.fps)  # Same whole-frame duration as the exporter.
errors = []
if len(timestamps) != expected:
    errors.append(f"Expected {expected} decoded frames; found {len(timestamps)}")
if not timestamps or not all(math.isfinite(t) for t in timestamps):
    errors.append("Missing or nonfinite presentation timestamps")
maximum_error = max((abs(t - i / args.fps) for i, t in enumerate(timestamps)), default=0)
if maximum_error > 0.00001:
    errors.append(f"Nonuniform frame cadence: maximum timestamp error {maximum_error:.6f}s")
decode = subprocess.run([
    ffmpeg, "-nostdin", "-v", "error", "-xerror", "-i", str(args.video),
    "-map", "0:v:0", "-f", "null", "-"
], capture_output=True, text=True)
if decode.returncode:
    errors.append("Complete decode failed: " + decode.stderr.strip())
digest = hashlib.sha256()
with args.video.open("rb") as stream:
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
report = {
    "passed": not errors, "path": str(args.video.resolve()), "sha256": digest.hexdigest(),
    "bytes": args.video.stat().st_size, "requestedSeconds": args.seconds,
    "fps": args.fps, "expectedFrames": expected, "decodedFrames": len(timestamps),
    "maximumTimestampErrorSeconds": maximum_error,
    "fullDecodePassed": decode.returncode == 0, "errors": errors, "probe": probe
}
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({key: report[key] for key in [
    "passed", "expectedFrames", "decodedFrames", "maximumTimestampErrorSeconds", "errors"
]}))
sys.exit(0 if report["passed"] else 1)
