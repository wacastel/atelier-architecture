# Atelier 2.6 startup-cache validation

The signed arm64 app is built and both worlds are precached. The native launch-to-visible comparison remains pending: the Mac was locked during the attempted measurements. No full startup speedup is claimed from offscreen results.

## Verified

- `build-precache.json` and `packaged-precache-all.json`: cold preparation followed by cache reuse in new processes using the same signed executable. Chicago loads all 24 pipeline variants; Paris loads all 17. Both worlds reuse scene, navigation and raster caches.
- `city-cache.json`: 71 CPU checks of exact scene data, traffic metadata, corruption, invalidation and atomic replacement.
- `collision-cache-unit.json` and `collision-cache-city.json`: malformed cache rejection, exact navigation arrays and equivalent navigation/picking queries, including the full Chicago world and Cloud Gate's detailed picking data. The large check count includes element-by-element comparisons.
- `renderer-cache.json`: 40 checks of actual Metal archive reuse, invalidation, corruption recovery, raster metadata and identical small-scene images in all three renderers. Dropped timestamps leave the presentation probe armed.
- `startup-metrics.json`: 17 checks, including overlapping world loads and background cache writes, using the actual reporting class.
- `benchmark-workflow.json`: eight synthetic wrapper tests. Invalid timestamps and unexpected cache misses are rejected rather than counted as startup results.
- `controller-integration.json`: 851 checks of actual controller methods and existing navigation/playback semantics; its report lists the fixture's native/GPU limitations.
- `cli-options.json` and `precache-failures.json`: invalid arguments and unavailable renderer-cache destinations fail clearly.
- `package.json`: code signature verification, executable hash, 30 matching packaged resources and actual cache sizes.

See [the startup guide](../../STARTUP.md) for measured preparation phases, commands, cache storage and the native benchmark procedure. Metal buffers and ray-tracing acceleration structures are still recreated at launch. The measurements do not cover steady-state frame rate or image convergence.
