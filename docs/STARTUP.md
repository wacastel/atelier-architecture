# Faster city startup

Atelier prepares the shared Chicago world before it can draw the opening Willis Tower view. Version 2.6 adds a reusable city cache and a build workflow that prepares it before the next GUI launch. All nine Chicago destinations share this preparation; Paris has a separate world.

## Build and prepare the next launch

From the project directory:

```sh
./scripts/build-app.sh
open dist/Atelier.app
```

The build compiles a release executable, packages and signs the app, then runs its Chicago precache command. Only after that succeeds does it replace `dist/Atelier.app`. The previous app remains available if compilation, signing or precaching fails. The precache command opens no window.

The launcher also accepts an explicit build command:

```sh
./Launch\ Atelier.command build
```

Double-clicking the launcher still opens Atelier, rebuilding and precaching first when source files or assets have changed. Quit an older running Atelier before opening the new build; replacing the app on disk does not replace an already-running process.

To prepare both worlds:

```sh
./scripts/build-app.sh --precache-city all
```

Chicago is the default because Willis Tower is the opening location. `--precache-city paris` prepares only the Eiffel Tower world. Use `--no-precache` to package without preparing a cache during development or when measuring the uncached baseline. The build writes its precache report to `dist/precache-report.json`.

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

If a presentation callback supplies no positive `presentedTime`, the app ignores that dropped or undisplayed frame and keeps waiting for the first actual presentation. This avoids treating an initial dropped frame as either a visible city or a failed launch. The wrapper independently requires a positive actual presentation timestamp and rejects callback-only reports from older instrumented builds. It also rejects comparisons if the timing source or rendering configuration changes between runs.

Initial diagnostic runs returned zero timestamps while this Mac's session was locked. Those runs do not establish an M3 Ultra or macOS limitation, and they are not valid measurements of the city becoming visible. A locked session can prevent normal window presentation and cause the benchmark to time out; such failed runs retain diagnostic reports and are excluded from performance claims.

Three conditions run in sequence:

- **Baseline:** `--no-city-cache` bypasses both cache reads and writes.
- **Cold:** `--force-rebuild-cache` regenerates the world cache during a native launch.
- **Warm:** the CLI precache command prepares the cache before native launches are timed, matching the build workflow.

The wrapper checks observed cache state against each condition. A baseline must actually disable caching; a cold run must rebuild; a warm run must report scene, collision and raster cache hits plus complete Metal pipeline reuse with no misses. Cache errors or a silent rebuild invalidate that condition instead of being mislabeled as a successful warm launch.

Each condition defaults to three new processes. JSON reports and process logs go in a timestamped directory under `output/startup-benchmark/`; `summary.json` records the executable SHA-256, each accepted timing, median, range and warm-versus-baseline speedup. The entire app report is retained beside the summary, including the renderer, drawable dimensions, cache state and timing source. Failed runs retain their reports and logs but contribute no timing sample. The benchmark uses an isolated cache inside its output directory unless `--cache-dir` is supplied. It does not delete the normal application cache.

For a single condition or a longer timeout:

```sh
./scripts/benchmark-startup.py --mode baseline --runs 3
./scripts/benchmark-startup.py --mode warm --runs 3 --timeout 300
```

Run this in an **unlocked, active macOS display session**, and keep it unlocked for every run. The app opens a real window and exits after its first positive city presentation timestamp and any pending cache persistence; only the presentation time contributes to the startup sample. The benchmark does not quit an existing Atelier process or stop other GPU work. For representative timing, keep the display configuration and other workloads the same between conditions. The default timeout is 180 seconds per child; on timeout or interruption, the wrapper terminates only its own child process group.

These are application cold/warm measurements. The benchmark does not purge macOS filesystem caches. First presentation does not measure steady-state frame rate or the time required for path-traced noise to converge. A cache also does not imply that Metal device resources can all be reused across processes: those parts of renderer setup still occur at launch.

## Validation

The final signed build successfully prepared both worlds before replacing the app. A subsequent packaged `--precache-city all` reused scene, collision and raster caches for both worlds, plus all 24 Chicago and 17 Paris Metal pipeline variants. These single headless observations used the same final executable and scene identity:

| Chicago preparation phase | Build without existing cache | Subsequent cache reuse |
| --- | ---: | ---: |
| Scene geometry build or load | 3.871 s | 1.984 s |
| Collision/navigation build or load | 6.848 s | 1.219 s |
| Renderer setup and three small offscreen frames | 10.343 s | 12.887 s |

Sources: [build precache report](validation/v2.6/build-precache.json) and [packaged all-world report](validation/v2.6/packaged-precache-all.json). These are separate-process, single observations of preparation phases. They are **not** measurements of launch to the first visible city frame. GPU buffers and acceleration structures still need rebuilding, and other workloads affect GPU preparation and rendering. No full-startup speedup is claimed from this table.

The Chicago cache occupies approximately 6.97 GB; Paris occupies approximately 1.30 GB. The cache includes scene geometry, navigation acceleration data, raster batches and device-specific pipeline archives. Both are disposable and can be regenerated by the build or precache command.

The native first-visible benchmark remains unverified because the Mac was locked during attempted measurements. A valid comparison requires unlocked native runs. Eight synthetic wrapper tests cover mode selection, report preservation, actual-timestamp requirements, cache-hit checks and safe timeout cleanup; those tests do not measure application startup speed.
