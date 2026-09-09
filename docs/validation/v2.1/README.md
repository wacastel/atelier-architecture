# Atelier 2.1.0 — navigation, music and Skyline

This release adds a full-window Large map, incremental map/camera dragging, fixed flight-speed presets (400 m/s default), Shift-left drag rotation, Q-up/E-down, the R rendering shortcut, eight original ambient pieces, and eight Chicago Skyline lighting studies. Willis Tower is the startup destination. Chicago demo includes 56 routes; all locations together contain 65.

## Acceptance evidence

| Scope | Result / record |
| --- | --- |
| Manual camera math, speed and vertical input | 383 checks in [manual-navigation.json](manual-navigation.json) |
| Pointer ownership and Shift-left dispatch | 191 checks / 46 groups in [viewport-input.json](viewport-input.json) |
| Offline map geometry and interaction math | 4,657 checks in [navigation-map.json](navigation-map.json) |
| Playback and sampled routes | 92,743 checks in [Skyline playback report](skyline/playback.txt) |
| Skyline rendering | 38 checks and 13 reviewed stills in [validation.json](skyline/validation.json) and [visual-review.json](skyline/visual-review.json) |
| Raster regression | 39,485 checks in [raster-regression.json](skyline/raster-regression.json); existing day/night fixture images remain byte-identical |
| Music | 287 controller/codec checks and 147 technical audio checks in [music proof](ambient-music/proof.json) |
| Native app interaction | [Scoped native review](native-review.json): defaults, map sizes/drag/click, full-screen/resize, hotkeys, dropdown, music controls, Skyline lighting and demo boundary |
| Signed package | [Package manifest](package.json): native arm64 build 13, all 26 resource files match, eight music tracks present, ad hoc signature verified |
| Packaged GPU execution | [Two isolated-directory runs](package-rendering/runs.json): Skyline sunset ray tracing and raster both pass geometry, ABI, image range, resizing, collision and importer checks |

The packaged raster check records zero ray, surface-guide and ray-tracing traffic acceleration updates. Static Chicago geometry remains 45,496,818 triangles; traffic brings the native total to 45,658,630. Skyline reuses that world and adds camera routes rather than city geometry.

CUA cannot hold a modifier during its native drag operation or reliably hold a movement key across frames. Shift-left rotation and sustained Q/E movement therefore have CPU and event-wiring coverage, with this limitation recorded in the native review. Music measurements establish decodability, level and transport behavior; subjective listening was not assessed. Offscreen timings and sampled native HUD values are not a controlled performance guarantee for every view.

The [main guide](../../CITY-BUILDING-GUIDE.md), HTML and PDF were refreshed for this release. Reference provenance and visual limitations are documented in [Skyline](../../SKYLINE.md), [map navigation](../../NAVIGATION-MAP.md) and [ambient music](../../AMBIENT-MUSIC.md).
