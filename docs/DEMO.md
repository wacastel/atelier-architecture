# Millennium Park and the continuous Chicago flight — Atelier 1.4

The app now opens on **Millennium Park**, the third destination. Willis Tower and the park occupy one continuous Chicago world; changing between their bookmark sets keeps the same scene resident. Paris remains available from the location menu or **L**.

Select **From tower to museum** (view 8) and press **Space**, or use **Willis → Park → Art Institute** from either Chicago destination. The four-minute route departs Willis Tower, crosses above the Loop, descends to Cloud Gate, visits the park and enters a modeled Modern Wing gallery. The flight button preserves the chosen day/night mode. The **Pace** selector, timeline and 2×/4×/8× arrow-key shuttle all use the full four-minute route. Space pauses exactly where you are.

The other seven park bookmarks have their own 56-second routes and gentle idle movement. **Idle Play / I** cycles all eight views, switching day/night after each complete pass. Choosing a view holds it; **[ / ]** adjusts idle speed independently. The Bean reflects the actual shared Chicago geometry and lighting.

| View | Architectural study |
| --- | --- |
| 1 | Chicago's garden of art — park and skyline overview |
| 2 | A city in the Bean — orbiting Cloud Gate |
| 3 | Beneath Cloud Gate — walk through the reflective underside |
| 4 | Music under the skyline — Pritzker Pavilion and the Great Lawn |
| 5 | Water, glass and light — Crown Fountain |
| 6 | A garden and a bridge — Lurie Garden and Nichols Bridgeway |
| 7 | The Art Institute — Michigan Avenue entrance and museum architecture |
| 8 | From tower to museum — continuous four-minute Chicago flight |

The map positions and published landmark envelopes constrain the reconstruction. Millennium Park has its own bundled OpenStreetMap extract, sharing Willis Tower’s coordinate origin. Fine surfaces, planting, the sculptural shell and museum gallery arrangement are authored interpretations. The Art Institute combines its historic entrance and bronze-lion interpretations with a glazed Modern Wing, Nichols Bridgeway and an original exhibition room; it does not reproduce the current collection hang. [Park sources](MILLENNIUM.md) · [Museum sources](ART-INSTITUTE.md) · [Renderer improvements](MOTION.md).

Cloud Gate reflects the actual Chicago geometry, with multiple reflections in its concave underside. Scrambled Sobol sampling distributes rays more evenly across the sampling domain; stable GGX evaluation and pure-metal sampling preserve the polished reflection lobe. Consecutive very smooth metal reflections retain their authored roughness until an ordinary surface scatter begins selective path regularization. Fine sampling grain and reconstruction softness can still be visible during motion.

The museum uses neutral warm-white interior fixtures during both day and night. Exterior washes, roof lights and bridge lights switch on at night. A conservative light grid avoids evaluating distant sources outside their finite support, retains scene candidate order and falls back to a linear list if necessary. `--random-sampling`, `--no-regularization` and `--linear-lights` provide independent comparison modes; `--raw` disables motion reconstruction for video comparisons.

## Recording and checking the new flight

The following command records the complete Chicago flight at its ordinary pace:

```sh
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location millennium \
  --video output/Chicago-Park-Museum-Flyby.mp4 --single-view --stop 7 \
  --seconds 240 --fps 24 --width 1920 --height 1080 --samples 16
```

Choose a new output filename and add `--lighting 2` for night. The ordinary 1× route lasts 240 seconds; `--seconds` changes the recording’s duration while traversing the same complete route. The final frame includes the museum endpoint. Without `--single-view`, the park exporter instead creates eight compressed chapters, defaulting to 96 seconds. Individual studies use `--single-view --stop 0` through `--stop 6` and default to 56 seconds. `--idle` records the selected bookmark’s gentle movement independently of the app’s current controls.

The [README verification commands](../README.md#verify-and-reproduce) cover the three map snapshots, landmark mesh, conservative light-grid coverage, navigation, playback and the full four-minute clock. They also include the Metal, glass, denoising, path-regularization, Sobol/polished-GGX and indexed-lighting GPU checks. `--location millennium --motion-test output/millennium-motion` exercises actual Bean idle, orbit, night and underside sequences against higher-sample references; `--motion-case` selects one case. The demonstration records below include export settings, complete decoding, exact frame timing and sampled visual checks, separate from the motion benchmark’s image-error measurements. `scripts/validate-video-timing.py` validates an existing recording’s full decode and cadence.

`scripts/prepare-millennium-context.py` reproduces the third derived map database from its bundled raw snapshot; the Paris and Chicago preparation commands remain available. No network access is needed to run the app or regenerate these recorded map extracts.

## Version 1.4 demonstration artifacts

- [Willis → Millennium Park → Art Institute](../output/Chicago-Willis-Park-Art-Institute-1080p.mp4): the continuous four-minute daytime flight, 1920 × 1080, 24 FPS, 16 samples/frame and three path interactions. All **5,760 frames** decode successfully with uniform frame timing. [Media report](validation/v1.4/day-flyby-media.json).
- [Cloud Gate at night](../output/Cloud-Gate-Night-Walkthrough-1080p.mp4): the complete 56-second orbit, 1920 × 1080, 24 FPS, 24 samples/frame and three path interactions. All **1,344 frames** decode successfully with uniform frame timing. [Media report](validation/v1.4/night-bean-media.json).
- [Cloud Gate by day](../output/Millennium-Cloud-Gate-Day.png) and [by night](../output/Millennium-Cloud-Gate-Night.png): 1920 × 1200, respectively 256 and 512 samples. Visually reviewed copies are included in the repository's README.

| Time | Continuous flight landmark |
| --- | --- |
| 00:00 | Willis Tower departure |
| 00:42 | Crossing above the Loop |
| 01:28 | Millennium Park descent |
| 01:48 | Approaching Cloud Gate |
| 02:37 | Pritzker Pavilion |
| 03:13 | Lurie Garden |
| 03:27 | Modern Wing approach |
| 03:45 | Griffin Court |
| 03:50 | Entering the interpreted gallery |
| 04:00 | Museum endpoint |

The complete movies passed FFmpeg decoding and timestamp checks. Visual review samples 16 points along the flight and nine points in the night orbit; it does not inspect every frame. Fine sampling grain remains in difficult moving reflections, especially the first frame before history develops. The polished Bean reflects the rendered Chicago world; the museum's gallery and artwork are authored interpretations. Videos remain local under `output/` and are excluded from Git. The commands above reproduce them.

The existing Willis and Paris demonstrations below document preceding releases. They are historical artifacts and do not certify the new park’s motion quality or current quality-preset performance.

## Chicago and Paris demonstrations — Atelier 1.3

Atelier 1.3 opened on Willis Tower with eight animated bookmarks. **L** or the location menu switched to Paris and its nine bookmarks. Every bookmark started an independent 56-second walkthrough; Space started/paused it. Idle Play (**I**) automatically visited the bookmarks, switching from day to night after the final view and back to day after the next pass. **[ / ]** adjusted its speed independently of walkthrough pace. These controls remain available in 1.4 alongside the new four-minute route. Native full-screen uses **Control–Command–F** or the toolbar button.

Chicago's eight chapters cover the tower skyline, Catalog entrance, close curtain wall, rooftop garden, Skydeck, five glass Ledge boxes, antenna crown, and South Branch river/boat/bridges. Published dimensions, OSM geometry and visually inspected photographs inform the reconstruction; authored interiors, façades and lighting remain interpretations. [Willis references](WILLIS.md) · [Chicago references](CHICAGO.md).

The 1.3 videos were generated locally under `output/` and are intentionally excluded from Git. The command-line examples in the repository README render fresh videos of the current scenes. An eight-view Willis tour lasts 96 seconds with the complete routes compressed into twelve-second chapters; a nine-view Paris tour lasts 108 seconds. `--single-view --seconds 56` records one of those routes at its ordinary 1× speed. `--idle` records the selected view's gentle drift.

## Version 1.3 demonstration artifacts

These local files show the final 1.3 Chicago geometry and renderer. They are excluded from Git; current app exports retain the same Willis routes while including subsequent scene and renderer changes.

- [Day walkthrough](../output/Willis-Chicago-Day-Walkthrough-1080p.mp4): eight chapters, 96 seconds, 1920 × 1080, 24 FPS, 16 samples/frame and three path interactions. The complete recording decodes successfully and all eight chapter midpoints passed visual review. [Media report](validation/v1.3/day-media.json).
- [Night walkthrough](../output/Willis-Chicago-Night-Walkthrough-1080p.mp4): all eight chapters, 96 seconds, 1920 × 1080, 24 FPS, 24 samples/frame and three path interactions. Full decoding and all eight chapter-frame reviews passed. [Media report](validation/v1.3/night-media.json).
- [Day overview](../output/Willis-Tower-Day.png) and [night overview](../output/Willis-Tower-Night.png): 1920 × 1200, respectively 256 and 512 samples. Both were visually reviewed; copies are included in `docs/images/` for the GitHub README.

| Time | Chicago chapter |
| --- | --- |
| 00:00 | Chicago's great tower |
| 00:12 | Welcome to Catalog |
| 00:24 | Black aluminum, bronze glass |
| 00:36 | A garden above the Loop |
| 00:48 | Inside the Skydeck |
| 01:00 | Out on the Ledge |
| 01:12 | Crown of the skyline |
| 01:24 | Along the Chicago River |
| 01:36 | End |

The films compress each complete 56-second route into a twelve-second chapter. In the app, each walkthrough plays at its independent adjustable pace. The earlier bright secondary-reflection speckles were corrected with selective path regularization; fine sampling grain and some reconstruction softness remain. [Method and limits](MOTION.md#selective-glossy-path-regularization).

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

## Recording the nine Paris views

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
