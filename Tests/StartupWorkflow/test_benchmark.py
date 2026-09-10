#!/usr/bin/env python3
"""Synthetic wrapper checks; these do not measure Atelier startup performance."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


PROJECT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("startup_benchmark", PROJECT / "scripts/benchmark-startup.py")
benchmark = importlib.util.module_from_spec(spec)
spec.loader.exec_module(benchmark)

FAKE_APP = '''#!/usr/bin/env python3
import json, os, pathlib, sys, time
a = sys.argv[1:]
with open(os.environ["ATELIER_WRAPPER_TEST_CALLS"], "a") as f:
    f.write(json.dumps(a) + "\\n")
if "--precache-city" in a:
    prepared = {"passed": True, "worlds": [{"passed": True, "world": "chicago",
                "preparedRenderers": ["path", "direct", "raster"]}]}
    pathlib.Path(a[a.index("--cache-report")+1]).write_text(json.dumps(prepared))
else:
    assert float(os.environ["ATELIER_LAUNCH_UPTIME"]) <= time.monotonic()
    report = {"passed": True, "staticTriangles": 10, "world": "synthetic",
              "renderer": "pathTracing", "quality": "balanced", "drawableSize": [1440, 960],
              "launchToFirstPresentedSeconds": 0.000001,
              "firstPresentedUptime": 100.000001,
              "processSpawnUptime": 100.0, "appStartedUptime": 100.0000002,
              "firstFrameRenderer": "raster", "backgroundRayPreparation": True,
              "rayTracingReadySeconds": 0.000002, "backgroundAccelerationBuildSeconds": 0.0000006,
              "rayTracingPreparationSucceeded": True,
              "timingSource": "drawable presentedTime", "actualPresentTimestampAvailable": True}
    mode = "disabled" if "--no-city-cache" in a else "rebuild" if "--force-rebuild-cache" in a else "automatic"
    warm, cold = mode == "automatic", mode == "rebuild"
    report.update({"cacheMode": mode, "sceneCacheHit": warm, "collisionCacheHit": warm, "focusCacheHit": warm,
        "rendererCaches": {"pipelines": {"error": "", "loaded": warm, "saved": cold,
            "hits": 24 if warm else 0, "misses": 24 if cold else 0,
            "path": "synthetic.metalarc" if mode != "disabled" else "disabled"},
        "rasterBatches": {"error": "", "hit": warm, "saved": cold}}})
    failure = os.environ.get("ATELIER_WRAPPER_TEST_INVALID")
    if failure == "missing-time":
        del report["launchToFirstPresentedSeconds"]
    elif failure == "callback-only":
        report["actualPresentTimestampAvailable"] = False
        report["timingSource"] = "presentation callback (OS timestamp unavailable)"
    elif failure == "scene-miss":
        report["sceneCacheHit"] = False
    elif failure == "focus-miss":
        report["focusCacheHit"] = False
    elif failure == "pipeline-miss":
        report["rendererCaches"]["pipelines"]["misses"] = 1
    elif failure == "raster-miss":
        report["rendererCaches"]["rasterBatches"]["hit"] = False
    elif failure == "wrong-mode":
        report["cacheMode"] = "automatic"
    elif failure == "missing-ray-ready":
        del report["rayTracingReadySeconds"]
    elif failure == "ray-failed":
        report["rayTracingPreparationSucceeded"] = False
        report["rayTracingPreparationError"] = "synthetic AS failure"
    elif failure == "invalid-first-renderer":
        report["firstFrameRenderer"] = "requested renderer"
    elif failure == "premature-ray-ready":
        report["rayTracingReadySeconds"] = 0.0000001
    elif failure == "non-raster-preview":
        report["firstFrameRenderer"] = "pathTracing"
    elif failure == "nonfinite-ray-ready":
        report["rayTracingReadySeconds"] = float("nan")
    elif failure == "ray-exceeds-lifetime":
        report["rayTracingReadySeconds"] = 60
    elif failure == "boolean-build-seconds":
        report["backgroundAccelerationBuildSeconds"] = True
    elif failure == "synchronous-ray-startup":
        report["backgroundRayPreparation"] = False
        report["firstFrameRenderer"] = "pathTracing"
        report["rayTracingReadySeconds"] = 0.0000007
    elif failure == "changed-first-renderer" and warm:
        report["backgroundRayPreparation"] = False
        report["firstFrameRenderer"] = "directRayTracing"
        report["rayTracingReadySeconds"] = 0.0000007
    pathlib.Path(a[a.index("--startup-report")+1]).write_text(json.dumps(report))
'''


@unittest.skipUnless(sys.platform == "darwin", "Native wrapper targets macOS")
class StartupWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="atelier-startup-wrapper-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.app = self.folder / "fake app"
        self.app.write_text(FAKE_APP)
        self.app.chmod(0o755)
        self.calls = self.folder / "calls.jsonl"

    def run_wrapper(self, mode="all", invalid=""):
        args = ["benchmark-startup.py", "--executable", str(self.app),
                "--output", str(self.folder / "reports"), "--mode", mode, "--runs", "2"]
        environment = {"ATELIER_WRAPPER_TEST_CALLS": str(self.calls)}
        if invalid:
            environment["ATELIER_WRAPPER_TEST_INVALID"] = invalid
        with patch.object(sys, "argv", args), patch.dict(os.environ, environment), \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            code = benchmark.main()
        reports = list((self.folder / "reports").glob("*/summary.json"))
        self.assertEqual(len(reports), 1)
        return code, json.loads(reports[0].read_text())

    def test_modes_use_fresh_native_children_and_precache_before_warm(self):
        code, report = self.run_wrapper()
        self.assertEqual(code, 0)
        self.assertTrue(report["completed"])
        self.assertEqual(report["schemaVersion"], 2)
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(len(calls), 7)
        for call in calls[:2]:
            self.assertIn("--no-city-cache", call)
            self.assertIn("--startup-exit-after-first-frame", call)
        for call in calls[2:4]:
            self.assertIn("--force-rebuild-cache", call)
        self.assertIn("--precache-city", calls[4])
        for call in calls[5:]:
            self.assertNotIn("--no-city-cache", call)
            self.assertNotIn("--force-rebuild-cache", call)
        for mode in ("baseline", "cold", "warm"):
            self.assertEqual(len(report["modes"][mode]["runs"]), 2)
            self.assertEqual(report["modes"][mode]["medianSeconds"], 0.000001)
            self.assertAlmostEqual(report["modes"][mode]["medianRayTracingResourcesReadySeconds"], 0.0000022, places=11)
            self.assertEqual(report["modes"][mode]["medianBackgroundAccelerationBuildSeconds"], 0.0000006)
            for entry in report["modes"][mode]["runs"]:
                self.assertEqual(entry["firstFrameRenderer"], "raster")
                self.assertTrue(entry["backgroundRayPreparation"])
        self.assertEqual(report["warmMedianSpeedup"], 1)
        self.assertEqual(report["warmRayTracingResourcesReadySpeedup"], 1)
        self.assertNotIn("firstFrameRenderer", report["configuration"])

    def test_missing_presentation_time_fails_and_retains_partial_evidence(self):
        code, report = self.run_wrapper(mode="baseline", invalid="missing-time")
        self.assertEqual(code, 1)
        self.assertFalse(report["completed"])
        self.assertIn("launchToFirstPresentedSeconds", report["error"])
        self.assertEqual(report["modes"]["baseline"]["runs"], [])

    def test_callback_only_timestamp_is_diagnostic_not_visible_startup(self):
        code, report = self.run_wrapper(mode="baseline", invalid="callback-only")
        self.assertEqual(code, 1)
        self.assertFalse(report["completed"])
        self.assertIn("No positive actual presentation timestamp", report["error"])
        self.assertEqual(report["modes"]["baseline"]["runs"], [])
        self.assertNotIn("warmMedianSpeedup", report)
        self.assertEqual(len(list((self.folder / "reports").glob("*/baseline-1.json"))), 1)

    def test_warm_scene_miss_is_rejected(self):
        code, report = self.run_wrapper(mode="warm", invalid="scene-miss")
        self.assertEqual(code, 1)
        self.assertIn("sceneCacheHit=True", report["error"])
        self.assertEqual(report["modes"]["warm"]["runs"], [])

    def test_warm_pipeline_miss_is_rejected(self):
        code, report = self.run_wrapper(mode="warm", invalid="pipeline-miss")
        self.assertEqual(code, 1)
        self.assertIn("Warm pipelines were not fully reused", report["error"])

    def test_warm_focus_miss_is_rejected(self):
        code, report = self.run_wrapper(mode="warm", invalid="focus-miss")
        self.assertEqual(code, 1)
        self.assertIn("focusCacheHit=True", report["error"])
        self.assertEqual(report["modes"]["warm"]["runs"], [])

    def test_warm_raster_miss_is_rejected(self):
        code, report = self.run_wrapper(mode="warm", invalid="raster-miss")
        self.assertEqual(code, 1)
        self.assertIn("Unexpected raster cache state", report["error"])

    def test_baseline_cache_mode_must_be_disabled(self):
        code, report = self.run_wrapper(mode="baseline", invalid="wrong-mode")
        self.assertEqual(code, 1)
        self.assertIn("cacheMode=disabled", report["error"])

    def test_missing_ray_readiness_is_rejected(self):
        code, report = self.run_wrapper(mode="baseline", invalid="missing-ray-ready")
        self.assertEqual(code, 1)
        self.assertIn("rayTracingReadySeconds", report["error"])
        self.assertEqual(report["modes"]["baseline"]["runs"], [])

    def test_failed_ray_preparation_is_rejected(self):
        code, report = self.run_wrapper(mode="baseline", invalid="ray-failed")
        self.assertEqual(code, 1)
        self.assertIn("Ray-tracing resources were not successfully prepared", report["error"])
        self.assertEqual(report["modes"]["baseline"]["runs"], [])

    def test_actual_first_renderer_must_be_reported(self):
        code, report = self.run_wrapper(mode="baseline", invalid="invalid-first-renderer")
        self.assertEqual(code, 1)
        self.assertIn("firstFrameRenderer", report["error"])

    def test_background_ray_readiness_cannot_precede_preview(self):
        code, report = self.run_wrapper(mode="baseline", invalid="premature-ray-ready")
        self.assertEqual(code, 1)
        self.assertIn("ready before first presentation", report["error"])

    def test_background_ray_preparation_requires_raster_preview(self):
        code, report = self.run_wrapper(mode="baseline", invalid="non-raster-preview")
        self.assertEqual(code, 1)
        self.assertIn("requires a raster first frame", report["error"])

    def test_ray_readiness_must_be_finite(self):
        code, report = self.run_wrapper(mode="baseline", invalid="nonfinite-ray-ready")
        self.assertEqual(code, 1)
        self.assertIn("Missing valid rayTracingReadySeconds", report["error"])

    def test_ray_readiness_cannot_exceed_child_lifetime(self):
        code, report = self.run_wrapper(mode="baseline", invalid="ray-exceeds-lifetime")
        self.assertEqual(code, 1)
        self.assertIn("readiness exceeds the child lifetime", report["error"])

    def test_ray_build_duration_cannot_be_boolean(self):
        code, report = self.run_wrapper(mode="baseline", invalid="boolean-build-seconds")
        self.assertEqual(code, 1)
        self.assertIn("Missing valid backgroundAccelerationBuildSeconds", report["error"])

    def test_synchronous_startup_has_distinct_resource_and_presentation_times(self):
        code, report = self.run_wrapper(mode="baseline", invalid="synchronous-ray-startup")
        self.assertEqual(code, 0)
        entry = report["modes"]["baseline"]["runs"][0]
        self.assertFalse(entry["backgroundRayPreparation"])
        self.assertEqual(entry["firstFrameRenderer"], "pathTracing")
        self.assertLess(entry["launchToRayTracingResourcesReadySeconds"], entry["launchToFirstPresentedSeconds"])

    def test_first_renderer_is_measured_separately_from_comparison_configuration(self):
        code, report = self.run_wrapper(invalid="changed-first-renderer")
        self.assertEqual(code, 0)
        self.assertEqual(report["configuration"]["renderer"], "pathTracing")
        self.assertEqual(report["modes"]["warm"]["runs"][0]["firstFrameRenderer"], "directRayTracing")

    def test_timeout_does_not_kill_unrelated_process(self):
        unrelated = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(20)"])
        try:
            with self.assertRaisesRegex(RuntimeError, "exceeded"):
                benchmark.run_child([sys.executable, "-c", "import time; time.sleep(20)"],
                                    self.folder / "timeout.log", 0.05)
            self.assertIsNone(unrelated.poll())
        finally:
            unrelated.terminate()
            unrelated.wait()


if __name__ == "__main__":
    unittest.main(verbosity=2)
