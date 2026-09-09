# Atelier 2.3.0 — Cultural Center and visible landmark focus

Build 16 adds the Chicago Cultural Center to the resident Chicago world, eight two-minute routes, a ninth original ambient track, and revised manual navigation. T points the normal camera straight down; B remains the separate fixed Map mode. W/S use a normalized horizontal heading. Map landmark actions explicitly choose focus; a viewport click retains the same selected object and otherwise releases it. Selection uses a gold surface tint and inner silhouette edge in both render modes.

| Scope | Result |
| --- | --- |
| Shared-world route transport, walking support and camera clearance across all 73 routes | 106,617 checks; [log](playback.txt), [exact input proof](playback-validation.json) |
| Standalone Cultural Center geometry, room apertures, stairs and opal materials | 2,912 checks; [report](cultural-center-geometry.json) |
| Actual controller, all 34 map destinations and mode isolation | 662 checks; [report](map-mode-integration.json) |
| Map sizes, placement, dot/text identity and catalog | 25,015 checks; [report](navigation-map.json) |
| Ground-parallel heading, normal top-down camera, framing and zoom | 6,765 checks; [report](manual-city-navigation.json) |
| Picking, selection transitions and exact-pole focused zoom | 1,662 checks; [log](focus-navigation.txt) |
| Pointer ownership and restricted Map controls | 449 checks; [log](viewport-input.txt) |
| Raster/RT selection and renderer regression | 39,496 checks; [report](raster.json) |
| Ambient controller and all nine decoded tracks | 299 checks; [report](ambient-music.json) |
| Full-file audio integrity, levels and joins | 165 checks; [report](ambient-audio.json) |
| Previous eight audio assets | Byte-identical; [report](music-preservation.json) |

The controller fixture uses production control code with inert audio and does not construct a Metal renderer or a city. Native event delivery and visual inspection are separate checks. The GPU selection fixture renders both paths, verifies the selected surface changes, keeps a foreground occluder and the sky unchanged, requires zero additional ray/surface-guide dispatches in raster mode, and verifies that clearing selection restores the exact unselected output. Its 16-sample raw RT images are test inputs, not a claim of noise-free motion.

Selection is applied after filmic presentation, outside material lighting, ray accumulation and denoiser history. It identifies visible surface points inside the selected architectural footprint/height volume. Raster glass preserves the underlying opaque surface depth; this is not a per-pane mesh-ID outline. District map entries use a named regional volume. The overlay adds no ray-tracing pass.

The model uses existing offline OSM coordinates, two inspected plans and nine inspected photographs. See the [reference ledger](../../CULTURAL-CENTER-REFERENCES.md) for dimensions, source disagreements, interpreted details and unmodeled rooms. The main [destination guide](../../CULTURAL-CENTER.md) documents the eight routes.

## Route and appearance input equivalence

The full-city playback run used Cultural Center source `7d471139cf7394e0f4451552312b41e74eead6f7503f6ba6040cde3990ca5fb2`; all 54 recorded inputs were stable across that run. The final appearance source is `225783cc61b22cb694d79a0822b3d23b606036fbe97a92b4850b6b01c7e2abfb`. It changes five dome-pane materials, lamp emission and existing interior light powers after the first render review, while preserving all vertex bytes and triangle material indices.

The [old-material negative control](cultural-opal-negative-control.json) and [final fixture](cultural-center-geometry.json) both report geometry SHA-256 `aaf62b7f8496e6c051d94c5594f636072df42340622c76ed3400abb1d7aa628d`, with 482,332 rendered triangles and 124,860 navigation triangles. The old version fails exactly the two new opal-material classification assertions; it retains its geometry, support and clearance results. Its `artGlassTriangles: 0` means no triangles satisfy the new rough-opal material predicate, not that its pane geometry was absent. The final version passes all 2,912 assertions and classifies 30,144 opal-pane triangles. CPU collision construction reads vertex positions only, so the unchanged geometry preserves the full-world route validation without another identical clearance run. This comparison does not itself establish the refined visual appearance.

The integrated Chicago scene contains 45,953,309 static triangles. Its 64 Chicago routes take 118 minutes 36 seconds at 1×; the nine Paris routes remain separate.

## Rendering, package and native review

The final [full-city gallery](cultural-rendering.json) passes 37 assertions and records 18 stills: eight authored views in day and night at 1280 × 800 with 64 reconstructed ray samples, plus the focused building in raster and reconstructed RT. All source/resource inputs remained unchanged during capture. Renderer allocation was 8,547 MB. The [day contact sheet](rendered/day-contact.jpg) and [night contact sheet](rendered/night-contact.jpg) were inspected, with individual dome and selected-building images also reviewed. The opal refinement removes the earlier clear-sheet appearance; marble, stair, arches and northern hall remain visible. Fine sampling grain remains, and this still gallery does not measure animation quality.

The [packaged application](package.json) is signed arm64 version 2.3.0, build 16. All 27 bundled resources exactly match source files; see the [build log](build-app.txt). The executable hash in that manifest also identifies the app used for [native review](native-review.json).

Native checks cover actual map-text clicks, selected-roof retention, street-click release, gold presentation in both render modes, focused normal T, isolated B Map mode, selected overhead button zoom, location transitions, the assigned soundtrack title and a paused nighttime Tiffany view. [Map label focus](native/map-label-focus.jpg), [raster focus](native/raster-focus.jpg), [released selection](native/focus-released.jpg), [normal T](native/normal-top-down-focused.jpg), [fixed Map focus](native/map-mode-focus.jpg), [assigned music](native/cultural-music.jpg).

Physical pinch, hover-only delivery, sustained native W/S key holds and speaker output were not established by this automation. Short key taps do not establish elapsed flight motion. CPU fixtures cover the corresponding camera/selection transforms and controller transitions. Ray-traced interiors remain demanding: the native nighttime dome displayed about 5 FPS during this scoped interaction, while the selected exterior was responsive in fast raster. These incidental counters are not a controlled FPS comparison; R remains the fast-raster switch.
