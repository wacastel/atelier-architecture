# GPU preparation and startup caches

Atelier's startup cache keeps derived raster batches and Metal pipeline binaries alongside the prepared scene. This does not change geometry, materials, lighting, render resolution, or the selected renderer.

## What the renderer reuses

- **Raster batches:** contiguous triangle ranges, conservative bounding boxes and glass classifications. A warm load avoids reading every city vertex merely to reconstruct the same culling metadata. The cache validates its version, scene identity, record layout, SHA-256 checksum, triangle/material counts, finite bounds, and complete contiguous triangle coverage. Truncated, stale or corrupt files are regenerated.
- **GPU pipelines:** all path tracing, direct ray tracing, reconstruction, presentation, traffic and raster variants use `MTLBinaryArchive`. Its identity includes the supplied application/scene cache key, shader source, Metal language version, GPU registry ID and name, and macOS version/build. Archive hits are verified with `failOnBinaryArchiveMiss`; any miss or incompatible archive falls back to compiling the same source and refreshes the local cache.

Cache directories that cannot be created or written do not prevent rendering. Raster records and pipeline archives are replaced atomically. Setting `cacheDirectory` to `nil` leaves the original uncached preparation path available for comparisons and fixtures.

## What remains per launch

Metal buffers must still be allocated and populated, and the static ray tracing acceleration structure must still be built for the current device. The Metal acceleration-structure API used by this renderer exposes build, refit and GPU copy/compaction operations; it does not expose a disk serialization operation. Copying opaque GPU allocation bytes to disk would not produce a supported reusable structure.

Loading a binary archive skips GPU-specific pipeline compilation. Creating a library from Metal source can still require source-to-AIR compilation, though the operating system maintains its own shader cache. A bundled offline `.metallib` could remove that step on installations with Apple's Metal compiler; `xcrun --find metal` reports that the compiler is unavailable in this machine's installed Command Line Tools, so the implementation uses the supported runtime archive API without requiring an Xcode installation.

## Measurement and validation

`MetalRenderer.startupPhaseSeconds` reports shader library, primary pipelines, scene buffers, light grids, static acceleration structure, traffic, raster, and cache-write durations. `startupCacheStatistics` reports real archive hits/misses and raster cache reuse separately. Overall launch timing waits for the first positive Metal drawable `presentedTime`, rather than stopping when CPU setup completes or substituting the callback delivery time. Zero and invalid timestamps are ignored and the probe remains armed for a later visible frame. A separate minimal MTKView probe received zero timestamps while this desktop session was locked; Apple documents zero timestamps for frames that were not presented or were dropped. Native comparisons must run with the desktop unlocked and the application visible; locked or occluded runs do not measure when the user can see the city.

Run `scripts/validate-startup-render-cache.sh` for bounded checks of archive creation/reload, shader/executable identity changes, corruption repair, exact compute output, raster metadata equality, partial final batches, forced rebuilds, unavailable cache directories, all 24 production pipeline hits, and identical small-scene output in all three renderers. `--build-only` compiles this fixture without using a Metal device.

## Primary references

- [Apple: Build GPU binaries with Metal, WWDC20](https://developer.apple.com/videos/play/wwdc2020/10615/) explains AIR versus device compilation, archive collection/reuse, GPU and OS compatibility, and archive-miss fallback.
- [Apple: MTLBinaryArchive](https://developer.apple.com/documentation/metal/mtlbinaryarchive) documents the supported pipeline archive API.
- [Apple: MTLAccelerationStructureCommandEncoder](https://developer.apple.com/documentation/metal/mtlaccelerationstructurecommandencoder) describes supported acceleration-structure operations.
