# Faster city startup

Version 2.7 displays the complete Chicago geometry in Fast Raster as soon as it is ready, then prepares ray-tracing acceleration structures in the background. The selected renderer takes over automatically when those resources are ready. This reduces the work required before the city first appears while retaining the existing ray-tracing geometry and build quality. All nine Chicago destinations share one prepared world; Paris has a separate world.

Scene geometry and navigation data load in parallel. Reusable caches cover geometry, collision/navigation acceleration data, landmark focus targets, raster batches and device-specific Metal pipelines. The compact landmark catalog avoids reconstructing thousands of focus targets at each launch. The build command prepares these caches before opening the GUI.

## Loading feedback and timings

The Chicago loading panel shows **Loading the Windy City**, the current preparation step, a progress bar, elapsed time and completed step durations. The percentage tracks weighted preparation steps rather than estimating remaining seconds. It reaches 100% only after Metal reports an actual city-frame presentation. The completed panel remains briefly visible as the city appears.

A fact card at the bottom rotates among **100 Chicago facts every three seconds** while loading. A shuffled bag visits every fact before repeating, avoids immediate repeats between bags, and respects Reduce Motion. Facts and source names are bundled for offline use; Paris does not show Chicago facts. [Fact ledger and institutional sources](CHICAGO-FACTS.md).

After launch, click the **stopwatch / City** control in the statistics panel to inspect preparation durations and the separate time when ray-tracing resources became ready. Navigation and scene work overlap, so their durations should not be summed to infer total startup time. **Open detailed launch report** opens:

```text
~/Library/Logs/Atelier/last-startup.json
```

The report records the first presented renderer, requested renderer, cache hits, preparation phases, actual presentation timestamp and background ray-tracing preparation. A later write adds completion of background work. The on-screen stopwatch starts when city loading begins; the benchmark below additionally includes process launch overhead.

## Build and prepare the next launch

From the project directory:

```sh
./scripts/build-app.sh
open dist/Atelier.app
```

The build compiles a release executable, packages and signs the app, then runs its Chicago precache command, including landmark focus data. Only after that succeeds does it replace `dist/Atelier.app`. The previous app remains available if compilation, signing or precaching fails. The precache command opens no window.

The launcher also accepts an explicit build command:

```sh
./Launch\ Atelier.command build
```

Double-clicking the launcher still opens Atelier, rebuilding and precaching first when source files or assets have changed. Quit an older running Atelier before opening the new build; replacing the app on disk does not replace an already-running process.

To prepare both worlds:

```sh
./scripts/build-app.sh --precache-city all
```

Chicago is the default because Willis Tower is the opening location. `--precache-city all` prepares Chicago and Paris, including their focus catalogs. `--precache-city paris` prepares only the Eiffel Tower world. Use `--no-precache` to package without preparing a cache during development or when measuring the uncached baseline. The build writes its precache report to `dist/precache-report.json`.

## Prepare an existing build

The same operation can run independently of compilation:

```sh
dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --precache-city chicago \
  --cache-report output/chicago-precache.json
```

Use `--force-rebuild-cache` to regenerate an existing cache. `--cache-dir /absolute/path` selects an alternate directory for the precache command or startup benchmark. To use that directory in a normal GUI launch, set the corresponding environment variable:

```sh
ATELIER_CACHE_DIR="/absolute/path" dist/Atelier.app/Contents/MacOS/ArchitectureEngine
```

Routine launches use the normal application cache automatically:

```text
~/Library/Caches/local.atelier.architecture/City/v1/<content-hash>/<world>/
```

The cache key hashes the packaged executable and all geometry JSON resources. A code or geometry resource change requires a matching cache, which the default build command prepares. Signing happens before precaching so the cache is prepared for the exact executable that will launch. Moving the app from its staging folder to `dist` does not change those bytes. Old content hashes are retained; this version does not automatically remove older caches. The cache is disposable generated data, separate from the application and source files.

## Measure launch to visible city

```sh
./scripts/benchmark-startup.py --runs 3
```

The benchmark starts a new native app process for every run. It measures from the process launch timestamp to the first city drawable's positive Metal `presentedTime`, obtained through `MTLDrawable.addPresentedHandler`. It does not stop at creation of the window, disappearance of the loading message, or completion of an offscreen render.

If a presentation callback supplies no positive `presentedTime`, the app ignores that dropped or undisplayed frame and keeps waiting for the first actual presentation. This avoids treating an initial dropped frame as either a visible city or a failed launch. The wrapper independently requires a positive actual presentation timestamp and rejects callback-only reports from older instrumented builds. It also rejects comparisons if the timing source, requested renderer, quality, drawable dimensions or scene identity changes between runs. The actual first-frame renderer is recorded separately: version 2.7 intentionally presents a Fast Raster preview before the requested ray-traced renderer is ready.

Historical diagnostic runs made while the Mac was locked returned zero presentation timestamps. Those runs are excluded from visible-startup measurements; they do not establish a hardware or macOS limitation. The current comparison uses unlocked native runs. A locked session can prevent presentation and cause a timeout, with diagnostic evidence retained.

Three conditions run in sequence:

- **Baseline:** `--no-city-cache` bypasses both cache reads and writes.
- **Cold:** `--force-rebuild-cache` regenerates the world cache during a native launch.
- **Warm:** the CLI precache command prepares the cache before native launches are timed, matching the build workflow.

The wrapper checks observed cache state against each condition. A baseline must actually disable caching; a cold run must rebuild; a warm run must report scene, collision, focus and raster cache hits plus complete Metal pipeline reuse with no misses. Cache errors or a silent rebuild invalidate that condition instead of being mislabeled as a successful warm launch.

Each condition defaults to three new processes. JSON reports and process logs go in a timestamped directory under `output/startup-benchmark/`; `summary.json` records the executable SHA-256, each accepted timing, median, range and warm-versus-baseline speedup. The entire app report is retained beside the summary, including the requested and first-frame renderers, drawable dimensions, cache state, timing source, background acceleration-build duration and launch-to-ray-resources-ready time. Failed runs retain their reports and logs but contribute no timing sample. The benchmark uses an isolated cache inside its output directory unless `--cache-dir` is supplied. It does not delete the normal application cache.

For a single condition or a longer timeout:

```sh
./scripts/benchmark-startup.py --mode baseline --runs 3
./scripts/benchmark-startup.py --mode warm --runs 3 --timeout 300
```

Run this in an **unlocked, active macOS display session**, and keep it unlocked for every run. The app opens a real window and exits after the first positive city presentation timestamp, background ray-tracing preparation and pending cache persistence. Only the presentation time contributes to the visible-startup sample; ray-resource readiness is reported separately and must succeed. The benchmark does not quit an existing Atelier process or stop other GPU work. For representative timing, keep the display configuration and other workloads the same between conditions. The default timeout is 180 seconds per child; on timeout or interruption, the wrapper terminates only its own child process group.

These are application cold/warm measurements. The benchmark does not purge macOS filesystem caches. First presentation measures the usable full-geometry raster preview in version 2.7. It does not measure steady-state frame rate, first ray-traced presentation, or the time required for path-traced noise to converge. A cache also does not imply that Metal device resources can all be reused across processes: those parts of renderer setup still occur at launch.

## Validation

An unlocked native **version 2.6 warm-cache baseline measured 10.629 seconds median across three fresh launches** from process spawn to actual city presentation. That release waited for ray-tracing resources before presenting the city. Version 2.7 moves that work after the first full-geometry raster frame and records its readiness separately.

| Native warm launch | Runs | Median launch to first actual city presentation | First-frame renderer |
| --- | ---: | ---: | --- |
| Version 2.6 baseline | 3 | 10.629 s | Path Tracing |
| Version 2.7 final compact-cache build | 3 | 3.175 s | Fast Raster preview |

The final signed build reduced median waiting time by **70.1%**. Its three visible-city measurements were **3.161, 3.228 and 3.175 seconds**. Ray-tracing resources became ready at a separate **4.984-second median** (4.806–5.150 seconds). Both versions used Chicago, balanced Path Tracing as the requested mode, 2880 × 1920 drawable pixels and 46,966,436 static triangles. The first visible image intentionally changes from Path Tracing to a Fast Raster preview; this is not a measurement of the first displayed ray-traced frame or convergence. [Exact comparison](validation/v2.7/comparison.json) · [Native reports and test evidence](validation/v2.7/evidence-index.md).

A bounded compact-catalog check measured approximately **16.5 MB** for Chicago's focus data, with **0.10 s to load versus 0.98 s to construct**. These are individual CPU preparation observations, not full-launch timings. Existing scene and collision caches are much larger; the complete generated cache remains disposable.

Historical version 2.6 headless reports are retained as [build precache evidence](validation/v2.6/build-precache.json) and [packaged all-world evidence](validation/v2.6/packaged-precache-all.json). Offscreen preparation and synthetic wrapper checks do not establish visible startup speed. The benchmark rejects absent actual timestamps, cache misses in warm runs and failed background ray-tracing preparation, and preserves partial evidence on failure.
