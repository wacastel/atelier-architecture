#!/usr/bin/env python3
"""Measure a new native Atelier window through its first actual city presentation.

This deliberately does not time CLI rendering or use `open`, which could reuse
an already-running process. Existing Atelier processes are left alone.
"""

import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import statistics
import subprocess
import sys
import time


PROJECT = Path(__file__).resolve().parents[1]


def positive_int(value):
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return parsed


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def stop_child(process):
    """Only terminate the process group created for this benchmark child."""
    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            process.wait()
            return
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()


def run_child(command, log_path, timeout, native=False):
    environment = os.environ.copy()
    process = None
    with log_path.open("w") as log:
        try:
            launch_uptime = time.monotonic()
            if native:
                # CACurrentMediaTime and Python monotonic use the machine's
                # monotonic clock on macOS; do not use wall-clock Date here.
                environment["ATELIER_LAUNCH_UPTIME"] = repr(launch_uptime)
            process = subprocess.Popen(command, cwd=PROJECT, env=environment,
                                       stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            return_code = process.wait(timeout=timeout)
            elapsed = time.monotonic() - launch_uptime
            if return_code:
                raise RuntimeError(f"Child exited {return_code}; see {log_path}")
            return elapsed
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"Child exceeded {timeout:g}s; see {log_path}") from error
        finally:
            if process is not None:
                stop_child(process)


def validate_cache_mode(report, mode, report_path):
    """Require observed cache behavior to match the condition being measured."""
    expected_mode = {"baseline": "disabled", "cold": "rebuild", "warm": "automatic"}[mode]
    if report.get("cacheMode") != expected_mode:
        raise RuntimeError(f"Expected {mode} cacheMode={expected_mode}: {report_path}")
    for key in ("cacheSetupError", "cacheWriteError"):
        if report.get(key):
            raise RuntimeError(f"Cache failure ({key}) invalidates {mode}: {report_path}")
    expected_hit = mode == "warm"
    for key in ("sceneCacheHit", "collisionCacheHit"):
        if report.get(key) is not expected_hit:
            raise RuntimeError(f"Expected {mode} {key}={expected_hit}: {report_path}")
    renderer_caches = report.get("rendererCaches", {})
    pipelines = renderer_caches.get("pipelines", {})
    raster = renderer_caches.get("rasterBatches", {})
    if pipelines.get("error") != "" or raster.get("error") != "":
        raise RuntimeError(f"Missing or failed renderer cache state for {mode}: {report_path}")
    if raster.get("hit") is not expected_hit or raster.get("saved") is not (mode == "cold"):
        raise RuntimeError(f"Unexpected raster cache state for {mode}: {report_path}")
    if pipelines.get("loaded") is not expected_hit or pipelines.get("saved") is not (mode == "cold"):
        raise RuntimeError(f"Unexpected pipeline cache state for {mode}: {report_path}")
    hits, misses = pipelines.get("hits"), pipelines.get("misses")
    if type(hits) is not int or type(misses) is not int or hits < 0 or misses < 0:
        raise RuntimeError(f"Invalid pipeline cache hit/miss counts: {report_path}")
    if mode == "warm" and (hits <= 0 or misses != 0):
        raise RuntimeError(f"Warm pipelines were not fully reused: {report_path}")
    if mode == "cold" and misses <= 0:
        raise RuntimeError(f"Cold pipeline rebuild was not observed: {report_path}")
    if mode == "baseline" and (hits != 0 or misses != 0 or pipelines.get("path") != "disabled"):
        raise RuntimeError(f"Baseline pipeline cache was not disabled: {report_path}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--executable", type=Path,
                        default=PROJECT / "dist/Atelier.app/Contents/MacOS/ArchitectureEngine")
    parser.add_argument("--output", type=Path, default=PROJECT / "output/startup-benchmark")
    parser.add_argument("--mode", choices=("baseline", "cold", "warm", "all"), default="all",
                        help="baseline bypasses cache; cold rebuilds it; warm runs after CLI precaching")
    parser.add_argument("--runs", type=positive_int, default=3)
    parser.add_argument("--timeout", type=float, default=180,
                        help="maximum seconds for each child (default 180)")
    parser.add_argument("--cache-dir", type=Path,
                        help="optional isolated cache directory; default is inside output")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("The native presentation benchmark requires macOS and a logged-in display session.")
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("--timeout must be finite and positive")
    executable = args.executable.expanduser().resolve()
    if not executable.is_file() or not os.access(executable, os.X_OK):
        parser.error(f"Executable is missing or not executable: {executable}. Run scripts/build-app.sh first.")
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    cache = args.cache_dir.expanduser().resolve() if args.cache_dir else output / "cache"
    # A new results directory avoids mixing timings from different binaries.
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    results = output / stamp
    results.mkdir()
    modes = ("baseline", "cold", "warm") if args.mode == "all" else (args.mode,)
    document = {
        "schemaVersion": 1,
        "startedAtUTC": stamp,
        "measurement": "New native process launch to first positive city MTLDrawable presentedTime",
        "requiresActualPresentedTimestamp": True,
        "executable": str(executable),
        "executableSHA256": sha256(executable),
        "cacheDirectory": str(cache),
        "runsPerMode": args.runs,
        "limitations": [
            "Filesystem and operating-system caches are not purged between runs.",
            "Existing applications and GPU workloads are not stopped.",
            "First presentation does not measure steady-state FPS or path-tracing convergence.",
            "Callback-only reports without a positive actual presentedTime are diagnostic evidence and are rejected.",
        ],
        "modes": {},
    }
    summary_path = results / "summary.json"

    def save():
        summary_path.write_text(json.dumps(document, indent=2) + "\n")

    save()
    try:
        for mode in modes:
            entries = []
            document["modes"][mode] = {"runs": entries}
            if mode == "warm":
                print("Preparing the warm cache with the same command used by the build…", flush=True)
                elapsed = run_child([str(executable), "--precache-city", "chicago",
                                     "--cache-dir", str(cache),
                                     "--cache-report", str(results / "precache.json")],
                                    results / "precache.log", args.timeout)
                document["precacheProcessSeconds"] = elapsed
                precache_path = results / "precache.json"
                if not precache_path.is_file():
                    raise RuntimeError(f"Precache produced no report: {precache_path}")
                precache = json.loads(precache_path.read_text())
                worlds = precache.get("worlds", [])
                if (precache.get("passed") is not True or len(worlds) != 1
                        or worlds[0].get("world") != "chicago" or worlds[0].get("passed") is not True
                        or set(worlds[0].get("preparedRenderers", [])) != {"path", "direct", "raster"}):
                    raise RuntimeError(f"Chicago precache did not certify all three renderers: {precache_path}")
                save()
            for index in range(1, args.runs + 1):
                report_path = results / f"{mode}-{index}.json"
                command = [str(executable), "--startup-report", str(report_path),
                           "--startup-exit-after-first-frame", "--cache-dir", str(cache)]
                if mode == "baseline":
                    command.append("--no-city-cache")
                elif mode == "cold":
                    command.append("--force-rebuild-cache")
                print(f"{mode}: native launch {index}/{args.runs}…", flush=True)
                process_seconds = run_child(command, results / f"{mode}-{index}.log",
                                            args.timeout, native=True)
                if not report_path.is_file():
                    raise RuntimeError(f"No first-presentation report was written: {report_path}")
                report = json.loads(report_path.read_text())
                if report.get("passed") is not True or report.get("staticTriangles", 0) <= 0:
                    raise RuntimeError(f"No successful city presentation was recorded: {report_path}")
                timestamp = report.get("firstPresentedUptime")
                if (report.get("actualPresentTimestampAvailable") is not True
                        or report.get("timingSource") != "drawable presentedTime"
                        or isinstance(timestamp, bool) or not isinstance(timestamp, (int, float))
                        or not math.isfinite(timestamp) or timestamp <= 0):
                    raise RuntimeError(f"No positive actual presentation timestamp; callback proxies cannot "
                                       f"measure visible startup. Unlock the Mac and keep the app visible. "
                                       f"Diagnostic report retained: {report_path}")
                validate_cache_mode(report, mode, report_path)
                configuration = {key: report.get(key) for key in
                                 ("renderer", "quality", "drawableSize", "staticTriangles", "world",
                                  "timingSource", "actualPresentTimestampAvailable")}
                if any(value is None for value in configuration.values()):
                    raise RuntimeError(f"Missing comparison configuration in {report_path}")
                if "configuration" in document and document["configuration"] != configuration:
                    raise RuntimeError(f"Render configuration changed between launches: {report_path}")
                document["configuration"] = configuration
                seconds = report.get("launchToFirstPresentedSeconds")
                if isinstance(seconds, bool) or not isinstance(seconds, (int, float)) or not math.isfinite(seconds) or seconds <= 0:
                    raise RuntimeError(f"Missing valid launchToFirstPresentedSeconds in {report_path}")
                if seconds > process_seconds + 0.25:
                    raise RuntimeError(f"Presentation time exceeds the child lifetime: {report_path}")
                entries.append({"report": str(report_path),
                                "launchToFirstPresentedSeconds": seconds,
                                "processLifetimeSeconds": process_seconds})
                print(f"  City presentation: {seconds:.3f}s ({report['timingSource']})", flush=True)
                save()
            values = [entry["launchToFirstPresentedSeconds"] for entry in entries]
            document["modes"][mode].update({"medianSeconds": statistics.median(values),
                                            "minimumSeconds": min(values), "maximumSeconds": max(values)})
            save()
        if "baseline" in document["modes"] and "warm" in document["modes"]:
            baseline = document["modes"]["baseline"]["medianSeconds"]
            warm = document["modes"]["warm"]["medianSeconds"]
            document["warmMedianSpeedup"] = baseline / warm
            document["warmMedianReductionPercent"] = 100 * (1 - warm / baseline)
        document["completed"] = True
        save()
    except (OSError, ValueError, RuntimeError, KeyboardInterrupt) as error:
        document["completed"] = False
        document["error"] = str(error) or type(error).__name__
        save()
        print(f"Benchmark stopped: {document['error']}\nPartial results: {summary_path}", file=sys.stderr)
        return 1
    print(f"Results: {summary_path}")
    for mode, measured in document["modes"].items():
        print(f"{mode}: median {measured['medianSeconds']:.3f}s "
              f"(range {measured['minimumSeconds']:.3f}–{measured['maximumSeconds']:.3f}s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
