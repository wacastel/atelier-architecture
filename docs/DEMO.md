# Chicago and Paris demonstrations — Atelier 1.3

The app opens on Willis Tower with eight animated bookmarks. Use **L** or the location menu to switch to Paris and its nine bookmarks. Every bookmark starts an independent 56-second walkthrough; Space starts/pauses it. Idle Play (**I**) automatically visits the bookmarks, switching from day to night after the final view and back to day after the next pass. **[ / ]** adjusts its speed independently of walkthrough pace. Selecting a view holds it. Native full-screen uses **Control–Command–F** or the toolbar button.

Chicago's eight chapters cover the tower skyline, Catalog entrance, close curtain wall, rooftop garden, Skydeck, five glass Ledge boxes, antenna crown, and South Branch river/boat/bridges. Published dimensions, OSM geometry and visually inspected photographs inform the reconstruction; authored interiors, façades and lighting remain interpretations. [Willis references](WILLIS.md) · [Chicago references](CHICAGO.md).

The current videos are generated locally under `output/` and are intentionally excluded from Git. The command-line examples in the repository README reproduce both locations' videos. An eight-view Chicago tour lasts 96 seconds with the complete routes compressed into twelve-second chapters; a nine-view Paris tour lasts 108 seconds. `--single-view --seconds 56` records one route at its ordinary 1× speed. `--idle` records the selected view's gentle drift.

## Earlier Paris demonstrations

The following notes describe earlier Paris releases; use `--location paris` explicitly for clarity when reproducing their exports.

# Eiffel walkthrough · v1.2

Open **Atelier.app** from `dist`, or double-click **Launch Atelier.command**. The app starts a gentle sequence through all nine views in order, with 20 seconds per view at the default idle speed. Selecting any view with **↑ / ↓**, **1–9**, or a view button stops the sequence and holds that view's gentle camera motion.

The separate **Idle Play / Idle Pause** button, or **I**, starts or stops automatic view switching. Idle Play begins from the current view and gives it a full dwell before advancing. Idle Pause keeps that view's gentle motion. **Idle Speed** has five settings: **0.25×, 0.5×, 1×, 2×, and 4×**. Press **[** to slow down or **]** to speed up. This setting scales both camera drift and view switching: each view lasts 80, 40, 20, 10, or 5 seconds respectively. It does not change walkthrough pace.

The main **Play** button or **Space** starts the current view's 56-second walkthrough and stops idle cycling. Press again to pause, and again to resume from the same time. A paused walkthrough freezes completely. **← / →** latch rewind and fast forward; repeated presses cycle 2×, 4×, and 8×, and an opposite press starts at 2×. Holding an arrow does not change the setting. **Pace** adjusts the walkthrough's base speed from 0.25× to 4×; the transport label shows the effective speed after the shuttle multiplier. Drag the timeline to seek. Playback pauses at either end, and Space at the forward endpoint restarts the selected view.

Click the viewport and use **WASD** plus drag for manual exploration. Q/E changes height in Fly mode; the mouse wheel changes manual movement speed. Manual navigation stops automatic view switching and takes control of the camera. **H** hides the interface. Settings switches Walk/Fly, quality, lighting and exposure.

For the night overview, press **1**, select the **moon button**, and leave the selected view held for a very slow orbit: 0.35 degrees per second at 1× Idle Speed. Press Space for the complete, faster orbit. **Settings → Lighting → Night** provides the same lighting mode. Press **9** to explore the Seine, sightseeing cruiser and five arches of Pont d’Iéna. The river route is a scenic camera flight over the water. Reflections use the traced scene geometry. See [night references](NIGHT.md) and [river references](RIVER.md).

The nine routes are independent studies: full overview orbit, ground approach beneath the arches, riveted connection and stair detail, first terrace, pavilion aisle, second terrace, summit panorama, exterior sweep, and the Seine with Pont d’Iéna and a river cruiser. The updated Anatomy of iron camera and route reveal the rivet plate while retaining foreground beams along the lower part of the frame. Nearby streets, gardens and building footprints use OpenStreetMap data; facade articulation, planting and the boat are authored interpretations. Map data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright).

Moving previews and new videos use [GPU motion reconstruction](MOTION.md). The v1.2 playback regression passes 7,334 checks, including the idle controls, 560 walkthrough camera steps per view and 120 seconds of idle camera movement per view. All nine routes pass the tested body-clearance checks; supported walking routes also pass floor-support checks.

## Version 1.2 demonstration artifacts

- [Nine-view daytime tour](../output/Eiffel-Paris-v3-Walkthrough-1080p.mp4): 108 seconds at 1920 × 1080 / 24 FPS, eight samples/frame and three path interactions. All 2,592 frames fully decoded; all nine chapter midpoints inspected.
- [Complete night river walkthrough](../output/Seine-v3-Night-Walkthrough.mp4): the full 56-second ninth route at 1×, 1440 × 900 / 24 FPS, twelve samples/frame and three path interactions. All 1,344 frames fully decoded; frames at 2, 14, 28, 42 and 54 seconds inspected.
- [Daytime Paris still](../output/Eiffel-Paris-v3-Day.png) and [night river still](../output/Seine-Pont-Iena-v3-Night.png): both 1920 × 1200, respectively 256 and 512 samples, visually reviewed.

The movies use the final version 1.2 scene and motion reconstruction. Captions and map attribution are readable. Fine noise remains in difficult night reflections; the pavilion interior is comparatively dim. [Day media report](../output/v3-review/day-media-validation.json) · [Night media report](../output/v3-review/night-media-validation.json).

## Recording the current nine views

`--video output/name.mp4 --single-view --stop N` records one complete selected route; indices are zero-based, 0–8. The default duration is 56 seconds, and `--seconds` stretches or compresses that route. Add `--lighting 2` for night. `--idle --stop N --seconds 20` records 20 seconds of that single view's idle movement at 1×, independent of the app's current settings. `--raw` disables motion reconstruction in a video for comparison. Choose a new filename for every video export.

Without `--single-view` or `--idle`, the exporter records all nine complete routes with chapter cuts, defaulting to **108 seconds**. Each full route is compressed into a 12-second chapter; live playback gives each selected route its full 56 seconds at 1×.

| Time | Chapter |
| --- | --- |
| 00:00 | The Paris skyline |
| 00:12 | Beneath the arches |
| 00:24 | Anatomy of iron |
| 00:36 | The first terrace |
| 00:48 | The visitor pavilion |
| 01:00 | Above the city |
| 01:12 | The summit gallery |
| 01:24 | A structure in light |
| 01:36 | The Seine & Pont d’Iéna |
| 01:48 | End |

## Earlier v1.1 demonstration artifacts

These files were rendered for **v1.1**. Their `v2` filename denotes the second recording, not the current v1.2 application. They show the earlier eight-view scene and precede the new map-based surroundings, revised ironwork framing, river cruiser, detailed bridge and idle cycling controls.

- [Earlier eight-view walkthrough](../output/Eiffel-Walkthrough-v2-1080p.mp4): a 96-second chaptered recording at 1920 × 1080 / 24 FPS, 8 samples per frame and three path interactions.
- [Earlier night walkthrough](../output/Eiffel-Night-Walkthrough-1080p.mp4): the full 56-second overview orbit at 1×, 1920 × 1080 / 24 FPS, 12 samples per frame and three path interactions.
- [Earlier night tower still](../output/Eiffel-Tower-Night.png): 2560 × 1600 at 256 samples, rendered and visually reviewed.

Both v1.1 movies use GPU motion reconstruction. Full decoding passed for all 2,304 daytime frames and 1,344 night frames. All eight chapter midpoints and five points in the night orbit were visually reviewed.

The v1.1 motion regression, after fixing bright silhouette trails, passed on 48-frame, 960 × 600 sequences with four samples per frame against independent 128-sample references. Temporal residual error fell 31.64% for the overview, 40.70% for ironwork and 12.54% for the night silhouette; image RMSE fell 10.14%, 30.60% and 3.93%, respectively. Night dark-city and clear-sky error also passed explicit ghosting thresholds. These measurements cover those specific earlier scenes and motions; timing fields were captured while two movie exports shared the GPU. [Results and method](VALIDATION.md#motion-reconstruction-checks).

## Original v1.0 artifacts

The original [1080p movie](../output/Eiffel-Walkthrough-1080p.mp4) runs for 96 seconds at 24 FPS, rendered at 64 samples per frame with four path interactions. It is a silent, chaptered visual tour of the original short camera moves. It predates the per-view routes, night lighting and motion reconstruction.

The original [4K overview](../output/Eiffel-Tower-4K.png) uses 512 samples and five path interactions. The original [chapter gallery](../output/final-review/) contains eight additional stills at 1440 × 960.

The tower, connection details and pavilion interiors remain procedural architectural interpretations. Published tower dimensions establish scale, while layouts and detail placement are reconstructed. See [MODEL.md](MODEL.md) for provenance and accuracy boundaries, and [VALIDATION.md](VALIDATION.md) for the completed checks.
