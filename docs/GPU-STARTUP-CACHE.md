# GPU preparation and startup caches

Atelier's startup cache keeps derived raster batches and Metal pipeline binaries alongside the prepared scene. This does not change geometry, materials, lighting, render resolution, or the selected renderer.

## What the renderer reuses

- **Raster batches:** contiguous triangle ranges, conservative bounding boxes and glass classifications. A warm load avoids reading every city vertex merely to reconstruct the same culling metadata. The cache validates its version, scene identity, record layout, SHA-256 checksum, triangle/material counts, finite bounds, and complete contiguous triangle coverage. Truncated, stale or corrupt files are regenerated.
- **GPU pipelines:** all path tracing, direct ray tracing, reconstruction, presentation, traffic and raster variants use `MTLBinaryArchive`. Its identity includes the supplied application/scene cache key, shader source, Metal language version, GPU registry ID and name, and macOS version/build. Archive hits are verified with `failOnBinaryArchiveMiss`; any miss or incompatible archive falls back to compiling the same source and refreshes the local cache.

Cache directories that cannot be created or written do not prevent rendering. Raster records and pipeline archives are replaced atomically. Setting `cacheDirectory` to `nil` leaves the original uncached preparation path available for comparisons and fixtures.

## Display the city before ray tracing finishes

Interactive startup can pass `deferRayTracingBuild: true` to `MetalRenderer`. Geometry, materials, lights, traffic, raster batches and pipelines are prepared first. The first city frame uses the existing Fast Raster renderer while the selected Path Tracing or Direct Ray Tracing mode remains the requested mode. After that frame actually appears, `prepareRayTracing(progress:)` builds the immutable city acceleration structure on a separate Metal command queue. The viewport adopts the requested renderer once the build succeeds; its reconstruction history resets at the transition.

The normal acceleration build flags and every triangle remain unchanged. This changes when preparation happens rather than reducing scene quality. `rayTracingReady` is synchronized, simultaneous preparation requests join a single build, and world teardown waits for an active acceleration build. A failed build leaves the raster city usable. Headless rendering and the build/precache command use the original synchronous default, and an explicit offscreen ray request rejects a renderer whose acceleration structure is still pending.

First city visibility and ray-tracing resource readiness are separate measurements. `firstFrameRenderer` records the renderer of the first actually presented frame, so a raster preview cannot be mislabeled as completed path tracing. Resource readiness marks completion of the static city acceleration build; it does not measure the first displayed ray-traced frame, its traffic update, or convergence. The initializer's optional `startupProgress` callback reports phase beginnings and elapsed monotonic seconds; `prepareRayTracing(progress:)` reports the deferred phase separately.

## What remains per launch

Metal buffers must still be allocated and populated, and the static ray tracing acceleration structure must still be built for the current device. The Metal acceleration-structure API used by this renderer exposes build, refit and GPU copy/compaction operations; it does not expose a disk serialization operation. Copying opaque GPU allocation bytes to disk would not produce a supported reusable structure.

Loading a binary archive skips GPU-specific pipeline compilation. Creating a library from Metal source can still require source-to-AIR compilation, though the operating system maintains its own shader cache. A bundled offline `.metallib` could remove that step on installations with Apple's Metal compiler; `xcrun --find metal` reports that the compiler is unavailable in this machine's installed Command Line Tools, so the implementation uses the supported runtime archive API without requiring an Xcode installation.

## Measurement and validation

`MetalRenderer.startupPhaseSeconds` reports shader library, primary pipelines, scene buffers, light grids, static acceleration structure, traffic, raster, and cache-write durations. `startupCacheStatistics` reports real archive hits/misses and raster cache reuse separately. Overall launch timing waits for the first positive Metal drawable `presentedTime`, rather than stopping when CPU setup completes or substituting the callback delivery time. Zero and invalid timestamps are ignored and the probe remains armed for a later visible frame. A separate minimal MTKView probe received zero timestamps while this desktop session was locked; Apple documents zero timestamps for frames that were not presented or were dropped. Native comparisons must run with the desktop unlocked and the application visible; locked or occluded runs do not measure when the user can see the city.

Run `scripts/validate-startup-render-cache.sh` for bounded checks of archive creation/reload, shader/executable identity changes, corruption repair, exact compute output, raster metadata equality, partial final batches, forced rebuilds, unavailable cache directories, all 24 production pipeline hits, deferred raster availability, concurrent preparation, and identical small-scene output before and after deferred ray tracing in all three renderers. `--build-only` compiles this fixture without using a Metal device.

`scripts/benchmark-startup.py` records both launch-to-first-presentation and launch-to-ray-tracing-resources-ready, with the actual first-frame renderer and the acceleration build duration. Its warm condition requires scene, collision, focus, raster and all pipeline cache hits. The report keeps the requested renderer in the comparison configuration and the actual first renderer in each measurement. Invalid or incomplete resource preparation fails the benchmark while retaining its diagnostic report. `Tests/StartupWorkflow/test_benchmark.py` validates these measurement rules with synthetic child processes; its tiny fixture times are not performance evidence.

## Primary references

- [Apple: Build GPU binaries with Metal, WWDC20](https://developer.apple.com/videos/play/wwdc2020/10615/) explains AIR versus device compilation, archive collection/reuse, GPU and OS compatibility, and archive-miss fallback.
- [Apple: MTLBinaryArchive](https://developer.apple.com/documentation/metal/mtlbinaryarchive) documents the supported pipeline archive API.
- [Apple: MTLAccelerationStructureCommandEncoder](https://developer.apple.com/documentation/metal/mtlaccelerationstructurecommandencoder) describes supported acceleration-structure operations.

## Build-flag experiment

A bounded study on the M3 Ultra reused the validated 46,966,436-triangle Chicago scene. Default acceleration builds took 3.63 and 5.67 seconds; `preferFastBuild` took 5.45 seconds, with no convincing build-time improvement. The Catalog primary-ray probe also ran slower with the fast-build hint. These are individual acceleration/primary-ray measurements, not full-frame rates. The implementation therefore retains the original build flags. Apple documents that [preferFastBuild](https://developer.apple.com/documentation/metal/mtlaccelerationstructureusage/preferfastbuild) may reduce intersection performance. Deferring the normal build preserves the existing ray tracing behavior.
