# Version 2.7 evidence

These reports preserve bounded test results, the native version 2.6 baseline and final signed version 2.7 launch measurements. The [manifest](evidence-manifest.json) records each original output path, size and SHA-256; copied report contents are unchanged. Absolute paths inside reports identify their original local runs.

## Implementation checks

| Evidence | Result | Scope and limits |
| --- | ---: | --- |
| [Loading and compact metadata cache](startup-loading-unit.json) | 122,801 checks passed | CPU round trips for every authored/mapped focus record, exact Float bits, rebuilt index queries, invalid-cache rejection, atomic-write failure, loading phases, parallel ordering and presentation-gated completion. No city geometry or GPU initialization. Chicago's 16,528,400-byte catalog took 0.099 s to load versus 0.984 s to construct in this isolated run; these are not app-launch times. |
| [Playback and route validation](playback.txt) | 124,029 checks passed | Production camera/playback checks across all ten destinations, including the revised low North Branch route. Sampled routes report no blocked, unsupported or near-surface camera steps. CPU geometry/state evidence does not certify native motion quality. |
| [Controller integration](controller-integration.json) | 851 checks passed | Actual EngineController methods, navigation, focus and playback with inert audio and no native window, renderer or city construction. Physical held-key events and rendered output require separate review. |
| [Metal startup caches](startup-render-cache.json) | 49 checks passed | Small fixtures exercise pipeline archive hits, misses, changed/corrupt/unavailable storage, raster batch reuse, production renderer phases and deferred acceleration preparation. Deliberate error cases are expected test inputs. These timings do not measure full-city preparation. |
| [Sunset lighting](sunset-lights.json) | 63 checks passed | Production Path, Direct and Raster shaders at 192 × 128: windows, fixtures, reflections, indexed/linear lights, unchanged sky/day/night, and retained vehicle/cabin/show emission. Small synthetic scenes; no city FPS or native UI claim. |
| [Chicago facts and scheduling](loading-facts.json) | 80,546 checks passed | 100 offline facts, 25 source groups, shuffled coverage and three-second scheduling across 32 seeds and 500 selections per seed. Does not check web availability or live animation. |
| [Loading panel preview audit](loading-ui-preview.json) | Typecheck and visual audit passed | SwiftUI ImageRenderer previews at normal/compact sizes and completed/Paris states. Retains source hashes from the preview audit. This reuses the facts checks above; it is not an additional 80,546 checks, a native app integration test, or an uncached launch benchmark. Preview PNGs remain local and are not copied here. |

The [acceleration-build study](acceleration-build-study.json) compares default, fast-build and repeated-default construction on the existing 46,966,436-triangle city with three limited ray probes. All probes reported zero distance mismatches. Single observations with varying build times do not establish a repeatable fast-build advantage or complete rendering equivalence. The release retains the existing acceleration-build quality and changes when that work runs.

## Native baseline

The [baseline summary](before/summary.json), [precache report](before/precache.json) and [precache log](before/precache.log) preserve the unlocked native warm-cache run from `20260910T113255.381602Z`. It launched a fresh version 2.6 process three times, measured process spawn to a positive Metal drawable `presentedTime`, and verified scene, collision, raster and pipeline reuse.

| Run | Actual city presentation after spawn | Evidence |
| --- | ---: | --- |
| 1 | 10.629 s | [Report](before/warm-1.json) · [Log](before/warm-1.log) |
| 2 | 10.340 s | [Report](before/warm-2.json) · [Log](before/warm-2.log) |
| 3 | 10.858 s | [Report](before/warm-3.json) · [Log](before/warm-3.log) |
| Median | **10.629 s** | [Summary](before/summary.json) |

Configuration: Chicago, Path Tracing, balanced quality, 2880 × 1920 drawable pixels, 46,966,436 static triangles. The summary records the exact executable SHA-256. This baseline waited for ray-tracing resources before first city presentation; version 2.7 presents full geometry in Fast Raster first and reports ray-resource readiness separately.

## Final native version 2.7

The [after summary](after/summary.json) and its three reports measure the final signed executable, SHA-256 `31c1a095d4eefb7beb221b47fb4d604b8ee869d29d068af74067b6d506697736`. All scene, collision, compact focus, raster and pipeline caches hit, with no shader misses. No other Atelier process or test workload was active during the timed launches.

| Run | First actual city presentation | Ray-tracing resources ready | Evidence |
| --- | ---: | ---: | --- |
| 1 | 3.161 s | 4.806 s | [Report](after/warm-1.json) · [Log](after/warm-1.log) |
| 2 | 3.228 s | 5.150 s | [Report](after/warm-2.json) · [Log](after/warm-2.log) |
| 3 | 3.175 s | 4.984 s | [Report](after/warm-3.json) · [Log](after/warm-3.log) |
| Median | **3.175 s** | **4.984 s** | [Summary](after/summary.json) |

[The exact comparison](comparison.json) shows **70.1% less waiting** until the city is visible. The requested mode, quality, geometry and drawable dimensions match the baseline. The first displayed renderer intentionally changes to Fast Raster, with full city geometry. Ray-resource readiness does not measure the first ray-traced presentation or convergence. Intermediate builds and locked-session diagnostics are excluded.

## Final integration and package checks

- [Final controller integration](controller-integration-final.json): 851 CPU checks after error-state and cross-world default fixes.
- [Final loading/cache validation](startup-loading-final.json): 122,801 CPU checks including the final active-step text update.
- [Startup report ownership](startup-metrics-unit.json): 33 bounded checks, including replacement loads, concurrent later worlds and separate ray/cache failures.
- [Benchmark wrapper](benchmark-unit.txt): 19 synthetic-process checks; these tiny timings are not startup performance evidence.
- [Native UI review](native-ui-review.json): loading text/facts, timing inspector, sunset/light reselection, Paris return and low golden-hour river framing observed in the final app. Its separate [interactive launch report](native-ui-launch.json) is excluded from the controlled three-run benchmark.
- [Final all-world precache](build-precache-all.json) and [build log](build.log): Chicago and Paris prepared by the signed build command.
- [Package verification](package.json): 2.7.0 build 22, strict code signature verified, exact benchmark executable, public GitHub repository.

[Measurement method and current comparison](../../STARTUP.md).
