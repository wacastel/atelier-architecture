# Validation record

Recorded 8 September 2026 on the local Apple M3 Ultra Mac Studio with 512 GB unified memory. The current release is **1.7.0 / build 8**. Earlier sections preserve their original measurements and limitations.

## Version 1.7 Chicago North Side

The sixth destination adds **eight animated studies** of Old Town, North Avenue Beach, Lincoln Park, the zoo, Conservatory/Lily Pool and Wrigley Field. Two continuous **240-second** flights connect Millennium Park to Lincoln Park Zoo and the zoo to Wrigley through the northern lakefront and harbors. All five Chicago destinations share one resident scene and navigation world. Selecting a view holds its gentle idle motion; the established walkthrough, shuttle, idle pace, day/night, full-screen and resize controls remain available.

The signed native arm64 package contains **39,792,802 static Chicago triangles, 355 materials and 3,222 static lights**. Six mapped traffic lanes carry **168 vehicles / 161,812 moving triangles** in a separate refitted structure. At 640 × 400 / 16 samples, the self-test reports **7,255.92 MiB** of Metal allocations. The night light index remains enabled at **182,160 cells**, with at most **164 candidates** in a cell; the vertex buffer is **3,835,642,944 bytes**, below the device's **373,662,154,752-byte** single-buffer limit. These are scoped allocation/capacity measurements, not whole-process memory or a frame-rate guarantee. [Chicago](validation/v1.7/chicago-self-test.json) · [Paris](validation/v1.7/paris-self-test.json).

A matched Field Hall benchmark records **38.84 ms** before expansion and **38.72 ms** with the complete North Side resident. These isolated paired-validation GPU durations include tracing, reconstruction and two presentations. They support retaining the continuous world for this trace; they do not establish a universal city-wide FPS. [Comparison](validation/v1.7/resident-world-comparison.json). A copied app also passes both-city self-tests while an OS sandbox denies reads from this repository. Package resources match source, the **144-byte** frame ABI remains intact and the strict local signature verifies. [Standalone proof](validation/v1.7/standalone-bundle.json) · [Package](validation/v1.7/final-package-input.json) · [Build](validation/v1.7/build-validation.txt).

Production playback passes **57,517 checks across all 49 routes**, including complete new routes, supported walking poses, head/torso/leg clearance and sampled idle motion. Both northern flights end at the exact subsequent bookmark. The eight existing CPU geometry/navigation suites pass; their initial Modern Wing duplicate-shell failure remains recorded and was fixed by restoring authored-site suppression. [Playback](validation/v1.7/playback-validation.txt) · [CPU regressions](validation/v1.7/cpu-regression.json) · [Map/geometry](NORTH-SIDE.md).

The dated OSM extract adds **31,425 building footprints/parts, 19,878 path segments, 3,752 tagged tree positions and 104 representative boats, plus 248 authored canopy trees inside mapped woodland and scrub belts**, with detailed Wells Street ground-floor frontage. Footprints and published measurements constrain the landmarks; actually viewed satellite/aerial images and architectural/night photographs inform roof shapes, details and light placement. Zoo lighting is an original seasonal ZooLights-inspired interpretation. Detailed focal structures coexist with simpler contextual facades and vegetation. [Old Town/beach](NORTH-SIDE-LANDMARKS.md) · [Zoo](LINCOLN-PARK-ZOO.md) · [Wrigley](WRIGLEY-FIELD.md).

## Version 1.7 motion checks

All **33 actual-scene motion cases pass**, including every previous case and seven northern cases. Each uses 640 × 400, 32 frames, eight current samples and an independent 128-sample reference, with the second half measured. Both reconstructed image RMSE and temporal residual must strictly improve over the paired raw trace. This release's resolution differs from the historical 960 × 600 reports; percentages describe reconstruction benefit over matching raw samples, not improvement over a past release. [Summary and exact source hashes](validation/v1.7/motion-summary.json).

| North Side moving view | Raw image RMSE | Reconstructed image RMSE | Temporal residual reduction |
| --- | ---: | ---: | ---: |
| old-town-brick | 0.022705 | 0.022276 | 19.1% |
| north-avenue-beach | 0.026237 | 0.025761 | 40.3% |
| nature-boardwalk | 0.050577 | 0.035261 | 42.4% |
| zoolights-night | 0.024908 | 0.023906 | 17.7% |
| conservatory-glass | 0.033877 | 0.031371 | 10.6% |
| wrigley-field | 0.038844 | 0.031628 | 32.6% |
| wrigley-night | 0.018187 | 0.017006 | 8.0% |

The first northern run exposed redundant filtering of accumulated roof seams and sun shadows. Spatial passes now preserve accepted temporal confidence and reduce their strength accordingly. Separate ablations showed a coarse-night window issue existed with the old shader too: the emitter guard covered only two pixels while later wavelet passes reached four and eight. The guard now follows the current pass's footprint. Original failures, ablations and unchanged acceptance criteria are preserved. [Discovery](validation/v1.7/motion-discovery-notes.json) · [Renderer method](MOTION.md).

The production denoiser, new moving-shadow/detail fixture, paired-presentation fixture and Adler GPU suite pass. New tests separately measure edge error and diffuse noise, preserve per-pixel confidence/reset behavior, and deliberately discard confidence or shorten the emitter guard as negative controls. Fine grain, subpixel sampling and temporal resampling softness remain possible; neither fixtures nor sampled camera traces imply universal noise elimination. [Denoiser](validation/v1.7/denoiser-validation.txt) · [Detail and coverage](validation/v1.7/temporal-detail.json) · [Paired presentation](validation/v1.7/paired-motion-validation.txt) · [Adler](validation/v1.7/adler-validation.txt).

## Version 1.7 visual and native review

The final package's day/night galleries, selected route details and three 1920 × 1200 hero stills were actually inspected. Reviews cover the neighborhoods, beach house and lakefront, South Pond and zoo, Conservatory/Lily Pool and Wrigley Field. Colored zoo arches and tree lights, the red marquee and white stadium field banks remain readable at night. Repeated contextual facades, faceted vegetation and finite-sample ground grain remain visible. [Context](validation/v1.7/wells-final-visual-review.json) · [Zoo](validation/v1.7/zoo-final-visual-review.json) · [Wrigley](validation/v1.7/wrigley-final-visual-review.json) · [Hero stills](validation/v1.7/release-hero-visuals.json).

Recording review caught an upright Fisher Bridge ramp caused by its beam reference axis. Corrected width/grade tests, thirty deck-support rays and a negative control detect the original defect; later day/night images confirm the unobstructed approach. A subsequent harbor flight exposed a clipped-map deduplication error: the old Lincoln Park outline suppressed its larger northern replacement. The missing mapped remainder now supplies 194.7 hectares of lawn and 248 separately identified representative woodland trees, preserving earlier geometry and excluding roads, paths, water, beaches and mapped hard surfaces. Both corrected components and the complete final camera/motion suites pass. The earlier failed drafts remain preserved. [Bridge discovery](validation/v1.7/north-day-tour-ramp-discovery.json) · [Bridge correction](validation/v1.7/fisher-ramp-correction.json) · [Harbor discovery](validation/v1.7/zoo-wrigley-flight-landcover-discovery.json) · [Landcover correction](validation/v1.7/landcover-correction.json).

The unlit harbor and park foreground remains very dark in the sampled night flight. That view does not support a claim about fine nighttime boat or planting detail. [Independent landcover review](validation/v1.7/landcover-still-visual-followup.json). Final-frame comparisons from the motion sequences were also inspected separately from their quantitative metrics. [Neighborhoods/Willis](validation/v1.7/root-motion-visual-review.json) · [Zoo](validation/v1.7/zoo-motion-visual-review.json) · [Wrigley](validation/v1.7/wrigley-motion-visual-review.json).

Actual native checks verified Space play/pause, both three-speed shuttles, paused lighting changes, manual view holds, idle pace/cycling and day/night wraps, independent walkthrough pace, all six locations and both new flight commands. Full-screen entry/exit and ordinary window zoom/resize were observed in screenshots. These checks used the package immediately before the landcover-only correction; all relevant current UI, controller, playback and renderer source files match exactly. The earlier record preserves its Mac-lock interruption. Once the Mac became accessible, the final package also passed an actual startup, night-mode, current-view play/pause and paused-lighting smoke check; it was left running the daytime idle cycle. [Final native smoke](validation/v1.7/native-final-smoke.json). [Native controls and exact scope](validation/v1.7/native-controls.json).

The release source inventory differs from the measured package inventory only by removal of one trailing space in a map preparation script; its parsed Python AST is identical. Runtime source, resources and tests remain unchanged. [Release inventory](validation/v1.7/release-source-input.json) · [Formatting equivalence](validation/v1.7/source-formatting-cleanup.json).

## Version 1.7 finished demonstrations

Four final silent H.264 movies use **1920 × 1080 at 24 FPS**. Both connecting flights retain their complete four-minute timing; the day and night montages compress each full camera route and its scene clock into a twelve-second chapter. All **16,128 frames / 672 seconds** pass complete decoding and uniform presentation-timestamp checks. Sampled visual review covers all eight day/night chapters, eleven points along the first flight, ten along the second and six additional Fisher Bridge frames. This is complete automated decoding plus sampled visual inspection, not visual inspection of every frame. [Media summary](validation/v1.7/media-summary.json) · [Local movies and export commands](DEMO.md#version-17-demonstration-artifacts).

| Final movie | Duration | Samples per frame | Media and visual evidence |
| --- | ---: | ---: | --- |
| North Side by day | 96 seconds | 16 | [Decode/timing](validation/v1.7/north-day-tour-media.json) · [Sampled review](validation/v1.7/north-day-tour-visual-review.json) |
| Millennium Park → Lincoln Park Zoo | 240 seconds | 12 | [Decode/timing](validation/v1.7/millennium-zoo-flight-media.json) · [Sampled review](validation/v1.7/millennium-zoo-flight-visual-review.json) |
| Lincoln Park Zoo → Wrigley Field | 240 seconds | 12 | [Decode/timing](validation/v1.7/zoo-wrigley-flight-media.json) · [Sampled review](validation/v1.7/zoo-wrigley-flight-visual-review.json) |
| North Side at night | 96 seconds | 24 | [Decode/timing](validation/v1.7/north-night-tour-media.json) · [Sampled review](validation/v1.7/north-night-tour-visual-review.json) |

The sampled final flights show clear tower and pavilion approaches, corrected bridge ramps and restored northern park lawns. The night tour keeps distinct colored zoo lamps and reflections, Wrigley's field lighting and boards, and readable captions and attribution. Unlit harbor/pond areas remain dark; finite-sample grain, repeated context facades and simplified planting remain visible. Movies stay local in `output/`; references, source data and validation records are committed. The final integrity audit verifies all **143 source inputs, 18 application files**, current movie hashes and their matching review reports. [Release verification](validation/v1.7/release-verification.json).

## Version 1.6 Museum Campus

The fifth destination adds eight animated studies of the Field Museum, Shedd Aquarium, Adler Planetarium, Soldier Field, Burnham Harbor and all four McCormick Place buildings with their associated hotels, arena and connecting structures. A continuous **180-second** Art Institute–Field Museum flight crosses Grant Park and enters Stanley Field Hall. Selected connected interiors include that hall, Shedd's two-tank rotunda and oceanarium, and Adler's welcome gallery and domed theater. The original silent planetarium program lasts **180 seconds**, shares the camera's play/pause/rewind clock and returns to its opening camera position. All four Chicago destinations share one resident city.

The final signed native arm64 app contains **26,950,320 static Chicago triangles, 238 materials and 2,640 explicit static lights**. Its 640 × 400 / 16-sample self-test reports **4,951.95 MiB** of Metal allocations. The app uses a separate refitted structure for moving traffic; static architecture is not rebuilt per frame. This allocation is viewport-dependent and is separate from whole-process memory or a frame-rate guarantee. [Chicago self-test](validation/v1.6/campus-self-test.json) · [Paris self-test](validation/v1.6/paris-self-test.json).

The copied application passes both-city self-tests from temporary working directories while an OS sandbox denies reads from this repository. These cover geometry, the **144-byte** Swift/Metal frame uniform, hardware ray tracing, accumulation, viewport resizing/aspect, navigation and the OBJ/MTL importer. All packaged resources match their source files and the strict local signature verifies. [Standalone package](validation/v1.6/standalone-bundle.json) · [Build](validation/v1.6/build-validation.txt) · [Package hashes](validation/v1.6/final-package-input.json).

Production geometry passes **42,882 playback and clearance checks across all 41 routes**, including every new complete route, walking support, sampled head/torso/leg clearance and 120 seconds of idle motion per bookmark. Controller coverage includes manual view holds, independent idle and walkthrough speeds, 2×/4×/8× shuttle, day/night wraps, five destinations, both connecting flights and preservation of paused clocks. Dedicated navigation and component geometry checks also pass. [Playback](validation/v1.6/playback-validation.txt) · [Navigation](validation/v1.6/navigation-validation.txt) · [Museum geometry](validation/v1.6/museum-buildings-geometry.json) · [Campus/stadium geometry](validation/v1.6/museum-campus-geometry-validation.json) · [McCormick geometry](validation/v1.6/mccormick-validation.txt).

The new map layer contains **3,382 contextual building polygons, 626 areas, 5,189 paths, 2,745 tree positions and 358 piers**. It places **151 representative moored boats**, including 31 with detailed lit cabins. The six existing vehicle lanes extend south while preserving their original northern samples. The primary OSM snapshot is timestamped **2026-09-08 12:08:37 UTC**; supplemental roads and shoreline use 12:21:50 UTC. Mapped site masks remove duplicate generic museum/stadium blocks, and fresh shoreline polygons repair the exposed southern edge of the earlier ground surface. [Map checks](validation/v1.6/museum-campus-map-validation.json) · [References and scope](MUSEUM-CAMPUS.md) · [Museum interiors](MUSEUM-BUILDINGS.md) · [McCormick Place](MCCORMICK-PLACE.md).

## Version 1.6 motion and projection checks

All **26 actual-scene motion cases pass** the unchanged requirement that both image error and temporal residual improve. Tests use 960 × 600, 32 frames, eight current samples and independent 128-sample references, comparing reconstructed and unfiltered presentations of the exact same trace. Measurements use the second half of each sequence. The twenty previous cases remain in the suite. These percentages measure reconstruction benefit over matching raw samples, not improvement over the previous release. [Summary and source hashes](validation/v1.6/motion-summary.json).

| Museum Campus moving view | Raw image RMSE | Reconstructed image RMSE | Temporal residual reduction |
| --- | ---: | ---: | ---: |
| field-hall | 0.073550 | 0.034516 | 55.8% |
| shedd-tanks | 0.063099 | 0.036228 | 48.0% |
| adler-gallery | 0.027929 | 0.012138 | 58.1% |
| planetarium-show | 0.005306 | 0.002377 | 58.5% |
| burnham-harbor-night | 0.011103 | 0.010287 | 7.5% |
| mccormick-night | 0.012732 | 0.011285 | 12.5% |

[Campus](validation/v1.6/motion-campus.json) · [Lakefront](validation/v1.6/motion-lakefront.json) · [Millennium Park](validation/v1.6/motion-millennium.json) · [Willis/Chicago](validation/v1.6/motion-chicago.json) · [Paris](validation/v1.6/motion-paris.json).

The first full-world theater test exposed an overly broad coverage bypass: it correctly rejected old projection images but also left stochastic seat lighting unfiltered, producing zero reconstruction gain. Stationary rough, opaque, nonemissive dielectric surfaces near the dome now reject temporal lighting history while receiving the existing edge-aware spatial filter. The screen, sharp reflections, glass and traffic retain exact current coverage. Acceptance thresholds and the measured camera trace were retained. [Preserved discovery](validation/v1.6/motion-campus-discovery.json) · [Diagnosis](validation/v1.6/motion-discovery-notes.json).

Actual GPU fixtures reduce controlled diffuse image error **62.4%** and temporal residual **62.0%**, detect stale illumination when the new temporal guard is deliberately removed, preserve contrasting material edges and keep fully reactive surfaces exact. All **147,456** tested legacy-guide components remain bit-identical to the prior denoiser policy. The shared denoiser regression passes. [Diffuse reconstruction and negative controls](validation/v1.6/adler-diffuse-reconstruction.json).

The show also passes deterministic advancement, pause, rewind and loop checks, local/reflected guide checks and a **6,144-component** day/night legacy path comparison. A separate negative control reproduces the bright polar slivers found during visual review; bounded spherical star distances correct that defect. Existing ABI/shader suites remain separately scoped in their evidence. [Adler GPU validation](validation/v1.6/adler-validation.json) · [Polar correction](validation/v1.6/adler-polar-correction.json) · [Renderer method](MOTION.md).

The scene is an architectural reconstruction. Selected interiors and exhibits, unmeasured building heights, decorative details, artificial light intensities, road grades and boat occupancy include authored interpretations. It is not a surveyed digital twin or a complete current museum inventory. Fine grain and reconstruction softness remain possible in moving reflections and small detail. Fixtures and sampled routes do not establish a universal frame-rate guarantee.

## Version 1.6 visual and native review

All sixteen final-package day/night bookmark stills were inspected at **1600 × 1000**, using 256 daytime and 384 nighttime samples. Review covered museum entrance framing, the corrected low Shedd glass ticket pavilion, Adler's granite and copper silhouette, its projected sky, Soldier Field's historic colonnades, harbor boats and piers, and the McCormick halls, pylons, promenade and shoreline. Earlier inspection found and corrected guessed tall Shedd context blocks and path corner gaps; those failure records remain preserved. [Field/Shedd](validation/v1.6/final-museum-gallery-visuals.json) · [Adler](validation/v1.6/final-adler-gallery-visuals.json) · [Soldier/Burnham](validation/v1.6/final-campus-gallery-visuals.json) · [Art Institute/McCormick](validation/v1.6/final-root-gallery-visuals.json) · [Shedd context correction](validation/v1.6/shedd-context-correction.json).

Three final **1920 × 1200** interior stills were inspected and copied into the repository: Stanley Field Hall, Shedd's two habitats and the Adler show. Additional interior, stadium bowl, close-boat and far-south shoreline images were inspected before the last local Shedd correction; their records identify that earlier snapshot. The six final motion-test images and paired raw dome image were also inspected. Dark unlit night areas, fine glass grain and simplified procedural exhibits remain explicit limitations. [Final interior stills](validation/v1.6/release-hero-visuals.json) · [Motion still review](validation/v1.6/motion-visual-review.json) · [Earlier interior samples](validation/v1.6/museum-interior-final-visuals.json) · [Earlier campus samples](validation/v1.6/museum-campus-final-visuals.json).

Actual native UI operation verified eight campus cards, current-view Space playback and pause, 2×/4×/8× shuttle in both directions, keyboard view selection, idle pace and observed night-to-day wrap, N preserving a paused clock, fullscreen entry/exit and live window resizing. All five destinations and both connecting flights were exercised, including a Paris roundtrip. These checks use the final controller and shaders and precede the last local Shedd geometry/camera correction; exact input hashes identify their scope. Keyboard transport was tested with the viewport focused. Sampled HUD readings are not a sustained frame-rate benchmark. [Native UI evidence](validation/v1.6/native-ui.json).

## Version 1.6 finished demonstrations

Four final silent H.264 movies use **1920 × 1080 at 24 FPS**: a 96-second day tour, the full 180-second Art Institute–Field Museum flight, the full 180-second Adler show and a 96-second night tour. The first three use 16 samples per frame; the night montage uses 24. All **13,248 frames** pass full FFmpeg decoding and uniform presentation-timestamp checks. Ten extracted frames per movie were actually inspected for composition, route progression, captions, attribution and conspicuous rendering defects. This is complete automated decoding plus sampled visual review, not visual inspection of every frame.

The two montages compress each full route and its scene clock into twelve-second chapters. The dedicated flight and show retain their ordinary three-minute timing. The flyover crosses the existing Grant Park world and enters Stanley Field Hall; the show returns close to its opening frame at the end of its loop. Interiors retain authored exhibits and artificial lighting. Reflective glass/water can retain fine grain, while unlit night foregrounds and roof surfaces remain dark.

[Day media](validation/v1.6/museum-day-tour-media.json) · [Day visual samples](validation/v1.6/museum-day-tour-visuals.json) · [Flight media](validation/v1.6/museum-flyover-media.json) · [Flight visual samples](validation/v1.6/museum-flyover-visuals.json) · [Show media](validation/v1.6/adler-show-media.json) · [Show visual samples](validation/v1.6/adler-show-visuals.json) · [Night media](validation/v1.6/museum-night-tour-media.json) · [Night visual samples](validation/v1.6/museum-night-tour-visuals.json) · [Local demos](DEMO.md#version-16-demonstration-artifacts) · [Release manifest](validation/v1.6/release-manifest.json).

The final packaged app was reopened after every export and checked again at the corrected Shedd day/night camera and the active dome show. A paused timeline remained exactly fixed while sample accumulation continued. The app was left running the 1× Museum Campus day/night idle cycle with all eight cards and controls visible. [Final native launch](validation/v1.6/native-final-launch.json).

## Version 1.5 Chicago Lakefront

Chicago Lakefront adds eight animated studies of the Magnificent Mile, historic Water Tower, Water Tower Place, former John Hancock Center, Buckingham Fountain, Grant Park, harbors and Lake Shore Drive. Wrigley and Tribune towers frame the Michigan Avenue route. The fourth destination shares the resident Chicago world with Willis Tower and Millennium Park; the original continuous four-minute tower-to-museum flight remains available. **N** and the moon button toggle day/night while preserving the selected view, transport state and animation clocks.

The signed native arm64 app contains **24,106,218 static Chicago triangles, 150 materials and 1,778 explicit static lights**. A separate dynamic structure contains **168 vehicles / 161,812 triangles** across six mapped traffic lanes. The 640 × 400 / 16-sample self-test reports **4,439.77 MiB** of Metal allocations, and passes geometry, Swift/Metal ABI, hardware ray tracing, image range, accumulation, viewport aspect/resizing, navigation and OBJ/MTL import. A copied app passes Chicago and Paris tests from temporary working directories while an OS sandbox denies repository reads. [Chicago self-test](validation/v1.5/lakefront-self-test.json) · [Paris self-test](validation/v1.5/paris-self-test.json) · [Standalone package proof](validation/v1.5/standalone-bundle.json) · [Build](validation/v1.5/build-validation.txt).

The final production geometry passes **29,753 playback and clearance checks** across all 33 routes, including 120 seconds of idle motion per bookmark, the 90-second Michigan Avenue route, the 120-second Lake Shore Drive flight and the original 240-second museum flight. No sampled route is blocked, unsupported where walking is required, or too near a surface. Dedicated navigation regressions also pass. Controller checks include distinct shuttle presses, independent idle/route speeds, manual holds, alternating day/night passes and lighting toggles preserving time and pause in every destination. [Playback](validation/v1.5/playback-validation.txt) · [Navigation](validation/v1.5/navigation-validation.txt).

The additional bundled map database contains **2,998 building/building-part polygons, 2,307 areas, 9,864 paths, 8,807 tree positions and 254 piers**. The principal OSM snapshot is timestamped 8 September 2026, 06:20:24 UTC. Validation checks finite coordinates, deterministic regeneration, known grass/land/water coverage, directed road connectivity, lane separation/grades and the open railway trench. The visible rail corridor includes 29 clipped rail segments and 41 road/path crossings. Landmark meshes use published architectural envelopes, mapped footprints, inspected photographs and aerial imagery. [Map checks](validation/v1.5/lakefront-map-validation.json) · [Lakefront geometry](validation/v1.5/lakefront-geometry-validation.json) · [Lakefront method and references](LAKEFRONT.md) · [Landmark geometry](validation/v1.5/magnificent-mile-geometry-validation.json) · [Tower lighting coverage](validation/v1.5/water-tower-light-coverage.json) · [Wrigley/Tribune checks](validation/v1.5/magnificent-gateway.json).

All sixteen final day/night bookmark stills were visually inspected at 1600 × 1000, with 128/256 samples respectively. Additional samples cover close harbor boats, the open railway corridor, the Grant Park arrival and the Lake Shore Drive bend around Lake Point Tower. Review checked landmark framing, entrances, crown/antenna silhouettes, fountain tiers and jets, piers, boats, road traffic and night reflections. [Corrected day gallery](validation/v1.5/day-gallery-corrected-visuals.json) · [Night gallery and earlier day review](validation/v1.5/lakefront-release-visuals.json) · [Landmark and route-sample review](validation/v1.5/root-visual-validation.json).

The traffic implementation refits only a small dynamic acceleration structure and its top-level instances; the static city remains resident. Focused fixtures pass **13,944 mapped vehicle placement checks**, exact pause/rewind image reproduction with matched samples, independent queued-frame transforms, moving headlights and local reflection/shadow-history rejection. Unrelated stationary surfaces retain their history. Existing Metal, glass, reconstruction and indexed-light tests pass; indexed and linear static light evaluation are bit-identical across 16,384 fixture pixels. The update-only synthetic 168-vehicle workload measures median 0.144 ms CPU and 0.325 ms GPU, excluding city tracing, presentation and reconstruction. [Focused traffic results](validation/v1.5/traffic-fixtures.json) · [Motion implementation and limits](MOTION.md).

The motion harness now captures raw and reconstructed presentation from the exact same trace accumulation, with a separate high-sample reference. Its GPU fixture verifies 55,296 accumulation channels at 1/8/32 samples with maximum display-byte error zero, the unchanged trace budget, one traffic update per frame and byte-identical paired outputs when filtering is disabled. Normal preview calls perform no extra capture. [Measurement method](MOTION.md#paired-reconstruction-measurement-v15) · [Paired GPU fixture](validation/v1.5/paired-motion-fixture.json).

Daytime movie review exposed a horizontal haze discontinuity on distant buildings. A continuous aerial-perspective field replaces the discontinuous ground/sky lookup for daylight haze and first camera-ray background misses. The background uses the same 0.8 asymptote as distant haze and retains the solar disk. Reflected and transmitted environment paths retain their existing lookup. A GPU fixture reduces the horizon radiance step from 0.36701 to 0.000899 and the distant-facade row step from 0.08409 to 0.000874. The separate primary-background row step falls from 0.366843 to 0.000682. Negative controls detect both original defects, while all 65,536 tested night radiance/depth components and the environment lookup remain exactly unchanged. Corrected 60- and 119-second flight frames were visually inspected. The daytime gallery and tour were regenerated. [Atmosphere correction](validation/v1.5/atmosphere-correction.json).

The scene remains an architectural reconstruction. Nearby facade articulation, vegetation, boat designs, sculptural ornaments, lighting and terrain elevations contain authored interpretations. Boat placements represent seasonal occupancy, not a current inventory. Fine grain and reconstruction softness remain in difficult moving reflections; neither these fixtures nor the memory measurement imply a universal frame-rate guarantee.

## Version 1.5 final motion checks

All **20 actual-scene cases pass** the unchanged requirement that both image error and temporal residual improve. Each sequence uses 960 × 600, 32 frames, eight current samples and independent 128-sample references. Metrics use the second half of each trace. These percentages compare reconstruction with unfiltered presentation of the exact same traced samples, not with a previous release. [Summary and source inputs](validation/v1.5/motion-summary.json).

| Lakefront moving view | Raw image RMSE | Reconstructed image RMSE | Temporal residual reduction |
| --- | ---: | ---: | ---: |
| hancock-braces | 0.027921 | 0.019872 | 34.1% |
| historic-water-tower | 0.058617 | 0.032117 | 48.6% |
| buckingham-night | 0.028712 | 0.025188 | 35.1% |
| harbor-reflections | 0.036071 | 0.028873 | 25.0% |
| lakefront-traffic-night | 0.013797 | 0.012763 | 7.6% |

[Lakefront](validation/v1.5/motion-lakefront.json) · [Millennium Park](validation/v1.5/motion-millennium.json) · [Willis/Chicago](validation/v1.5/motion-chicago.json) · [Paris](validation/v1.5/motion-paris.json). The preliminary Willis-night image-error failure is preserved with its diagnosis; acceptance thresholds, reference samples and camera traces were retained. [Discovery record](validation/v1.5/motion-discovery-notes.md). Fine sampling grain can remain in moving glossy surfaces.

## Version 1.5 finished demonstrations

The final daytime tour is **96.000 seconds / 2,304 frames**, with twelve-second chapters traversing all eight complete routes. The night Lake Shore Drive flight retains its full **120.000 seconds / 2,880 frames**. Both are H.264 High, 1920 × 1080, 24 FPS and three path interactions; day uses 16 samples/frame and night 24. Camera and traffic follow the same route clock. Chapter cuts reset reconstruction, while the single-view night flight has no chapter cuts.

Full FFmpeg error-checking decode passes all **5,184 frames**, and every presentation timestamp matches the expected 1/24-second cadence within 0.000001 seconds. Movie sizes are 254,135,688 and 313,553,115 bytes. Both exports ran sequentially without process suspension. [Day media proof](validation/v1.5/day-tour-media.json) · [Night media proof](validation/v1.5/night-drive-media.json).

Visual review covers ten sampled frames from the day tour, including every chapter, and ten along the night drive. Captions, attribution, principal framing, boats, road traffic, lights and reflections were checked. This combines complete automated decoding with sampled visual review; it does not mean every frame was watched. Fine grain and simplified background facades, vegetation and waterfront surfacing remain visible. [Day visuals](validation/v1.5/day-tour-visuals.json) · [Night visuals](validation/v1.5/night-drive-visuals.json) · [Local demo links](DEMO.md#version-15-demonstration-artifacts).

The night movie was completed before the final daylight-only haze correction and conditional caption fit. Its original source/executable hashes are preserved in [night media inputs](validation/v1.5/night-media-input.json). The [atmosphere GPU comparison](validation/v1.5/atmosphere-correction.json) verifies unchanged night kernels, and the [CoreText width check](validation/v1.5/caption-widths.txt) confirms the night caption retains its original font and draw path. The final daytime movie includes both corrections.

[Final application/source manifest](validation/v1.5/release-manifest.json) records native arm64 architecture, strict signature verification and source/package hashes. The final copied bundle passes both-city self-tests with repository reads denied. The final app was launched and its process observed running. The Mac remained locked, preventing a fresh native UI inspection; current automated control/viewport checks and earlier native UI checks are scoped separately. [Native launch and UI check scope](validation/v1.5/native-ui.json).

## Version 1.4 Millennium Park and the shared Chicago world

Willis Tower and Millennium Park now use one scene, acceleration structure and navigation world. The park adds eight animated viewpoints, including a continuous **240-second** flight from Willis Tower through Millennium Park into an interpreted Art Institute gallery. The other seven studies last 56 seconds. Paris retains nine routes and Willis retains eight.

The signed native arm64 app contains **13,539,844 Chicago triangles, 94 materials and 1,049 explicit lights**, with 23,203 generated geometric details and 2,735 mapped building/building-part polygons. At 640 × 400, the 16-sample self-test passes geometry, Swift/Metal ABI, hardware acceleration, image range, accumulation, viewport aspect/resizing, navigation and OBJ/MTL import; reported Metal allocation is **2,486.17 MiB**. A copied app passes both Chicago and Paris self-tests from separate temporary working directories while an OS sandbox denies all reads from this repository, including `.build`. The original repository and build directory remain untouched. [Chicago self-test](validation/v1.4/millennium-self-test.json) · [Paris self-test](validation/v1.4/paris-self-test.json) · [Standalone bundle proof](validation/v1.4/standalone-bundle.json).

The production geometry passes **22,258 playback and clearance checks** across all 25 routes. The harness samples each ordinary route at 10 Hz and the entire connecting flight at 2,400 positions, plus 120 seconds of idle motion per bookmark. No tested movement is obstructed, unsupported on a walking route, or too close to a surface. Dedicated navigation checks include the raised Cloud Gate plaza and arch, the Modern Wing entrance, Griffin Court and gallery, alongside the previous Paris and Willis cases. [Playback](validation/v1.4/playback-validation.txt) · [Navigation](validation/v1.4/navigation-validation.txt).

The new bundled OpenStreetMap snapshot has **91 areas, 228 paths, 626 tree positions and 12 identified landmarks**. Its source timestamp is 8 September 2026, 00:55:31 UTC. Validation covers finite coordinates, landmark coverage, polygon triangulation and deterministic regeneration. A separate geometry fixture checks Cloud Gate's closed manifold, dimensions, smooth normals and walkable underside. The park layer contains **1,678,830 triangles and 84 lights**. Primary-source photographs, published dimensions and visually inspected aerial imagery constrain the authored reconstruction. [Map check](validation/v1.4/millennium-map-validation.txt) · [Geometry check](validation/v1.4/millennium-geometry-validation.txt) · [Park sources and limits](MILLENNIUM.md) · [Art Institute sources and limits](ART-INSTITUTE.md).

The final eight-bookmark day/night gallery uses 1600 × 1000 images at 128/256 samples. Park review covers all six park viewpoints in each lighting mode; museum review additionally covers the historic entrance, Modern Wing, Nichols Bridgeway, Griffin Court and gallery. Final Cloud Gate hero stills use 1920 × 1200 at 256/512 samples. The visibly smooth shell reflects modeled buildings and paving, and the nighttime lower shell retains the warm plaza illumination seen in photographic references. [Park visuals](validation/v1.4/park-visual-validation.json) · [Museum visuals](validation/v1.4/museum-visual-validation.json) · [Final heroes and route endpoints](validation/v1.4/root-final-visual-validation.json).

Native UI operation verified the third destination, four-minute flight, exact pause, 2×/4×/8× transport, endpoint inside the museum, location roundtrips, retained Chicago resources, preserved flight lighting, keyboard idle speeds, a night-to-day cycle wrap, and full-screen entry/exit. All controls and attribution remained visible. [Native UI evidence](validation/v1.4/native-ui.json).

The renderer now uses Owen-scrambled Sobol paths, smooth reflective-surface guides, angularly bounded glossy history, and a corrected narrow GGX lobe. A domain clamp prevents rounded dot products above one from producing false polished highlights. Spatial filtering preserves both sides of thin high-contrast paving boundaries. Dedicated GPU fixtures exercise real shader kernels and intentionally broken variants; nine negative controls detect the corresponding sampling, reflection, guide, history, coverage and GGX-domain regressions. [Renderer method](MOTION.md) · [Negative controls](validation/v1.4/motion-negative-controls.json).

A conservative spatial light index retains original candidate order and falls back to the complete linear light list if its inputs or memory bounds cannot be indexed safely. **43,860 CPU coverage/order checks** and **16,384 GPU comparison pixels** pass; the GPU fixture's indexed and linear radiance are bit-identical. This fixture result is distinct from whole-scene image comparisons. Daylight museum fixtures use a filtered always-on buffer and matching index. [CPU light-grid checks](validation/v1.4/light-grid-validation.txt) · [GPU indexed-light checks](validation/v1.4/motion-indexed-lighting-validation.txt).

The gallery arrangement, paintings, Crown Fountain's abstract displays, vegetation, material finishes and lighting are authored interpretations. This release is not a surveyed digital twin or a reproduction of the museum's current exhibition layout. Motion checks measure specific traces and retain explicit image-error and ghosting limits; they do not establish scene-wide noise elimination or a universal frame-rate guarantee.

## Version 1.4 final motion checks

All **15 actual-scene cases pass** the unchanged image-error and temporal-error requirements at 960 × 600, 32 frames, eight current samples and independent 128-sample references. Measurements use the second half of each sequence. The following reductions compare reconstruction with matching unfiltered paths; they are separate from the cross-sampler comparison below. Correctness runs shared the GPU with exports, so their timing fields are excluded from performance claims. [Summary and source hashes](validation/v1.4/motion-summary.json).

| Moving view | Raw image RMSE | Reconstructed image RMSE | Temporal residual reduction |
| --- | ---: | ---: | ---: |
| millennium / cloud-gate-idle | 0.033080 | 0.016787 | 65.9% |
| millennium / cloud-gate-orbit | 0.038446 | 0.034813 | 13.6% |
| millennium / cloud-gate-night | 0.036934 | 0.036031 | 8.8% |
| millennium / beneath-cloud-gate | 0.060168 | 0.043835 | 31.1% |
| millennium / beneath-cloud-gate-night | 0.074184 | 0.053005 | 29.4% |
| chicago / willis-overview | 0.028678 | 0.026875 | 25.7% |
| chicago / willis-facade | 0.020733 | 0.010627 | 57.5% |
| chicago / willis-night | 0.024938 | 0.024919 | 1.2% |
| chicago / chicago-river | 0.070942 | 0.033670 | 55.0% |
| chicago / chicago-river-night | 0.042262 | 0.031370 | 27.4% |
| paris / overview | 0.027306 | 0.026368 | 33.6% |
| paris / iron | 0.055553 | 0.032336 | 61.6% |
| paris / night-silhouette | 0.038220 | 0.036525 | 4.9% |
| paris / river-day | 0.042878 | 0.033303 | 36.7% |
| paris / river-night | 0.049377 | 0.040985 | 20.1% |

[Millennium results](validation/v1.4/motion-millennium.json) · [Willis/Chicago results](validation/v1.4/motion-chicago.json) · [Paris results](validation/v1.4/motion-paris.json). Paris clear-sky RMSE is **0.000072**, and maximum unsupported temporal night brightness is **0**. The small Willis night gain reflects intentionally conservative treatment of unresolved lit windows. Fine grain remains in moving glossy reflections.

The separately isolated Bean night comparison uses identical independent references across sampler modes. At four samples, Sobol lowers reconstructed image error **10.0%** and temporal residual **10.8%** relative to the current renderer’s independent-random mode. Eight Sobol samples lower those errors **21.4%** and **22.8%**, respectively, versus independent random at four samples. Indexed lighting takes **27.74 ms**, compared with **66.48 ms** for linear light traversal at eight samples, a **2.40×** throughput improvement in this specific 960 × 600 benchmark. Four-sample indexed rendering takes **14.50 ms**. These are measured GPU frame durations for this trace, not native window FPS guarantees. [Paired results](validation/v1.4/motion-comparison.json) · [Method and limitations](MOTION.md#version-14-measured-comparisons).

The failed preliminary paving and Willis-night measurements remain preserved. Symmetric material-boundary coverage and sample-aware spatial strength correct their respective causes; acceptance thresholds were not relaxed. [Discovery notes and failed inputs](validation/v1.4/motion-discovery-notes.md).

## Version 1.4 finished demonstrations

The final daytime flight is **240.000 seconds / 5,760 frames** and the final night Bean orbit is **56.000 seconds / 1,344 frames**. Both are H.264 High, 1920 × 1080 at 24 FPS with three path interactions; the day recording uses 16 samples/frame and the night recording 24. Full FFmpeg `-xerror` decoding passes all **7,104 frames**, and each presentation timestamp matches its expected 1/24-second cadence within 0.000001 seconds. Movie sizes are respectively **627,846,109** and **147,131,001 bytes**. [Day media proof](validation/v1.4/day-flyby-media.json) · [Night media proof](validation/v1.4/night-bean-media.json) · [Local demos and flight landmarks](DEMO.md#version-14-demonstration-artifacts).

The final movies were exported sequentially without process suspension. An earlier recording decoded correctly but had three missing frames; that failure is retained as a negative control for the new reusable cadence validator. The final offline encoder explicitly supplies its expected source frame rate and disables real-time encoding. [Encoder correction and preserved failure](validation/v1.4/export-timing-notes.md).

Visual review covers 16 sampled daytime frames from tower departure through the gallery endpoint, plus nine sampled frames around the complete night Bean orbit. Captions and map attribution are readable. Sampled park and museum approaches are unobstructed, and the Bean retains curved reflections of surrounding geometry and illumination. Fine grain and reconstruction softness remain in difficult reflections. This combines complete automated decoding with sampled visual review, rather than visual inspection of every frame.

The final signed app was launched again after both exports and its process was observed running. The Mac was locked, preventing a fresh on-screen inspection at that point; the earlier native controls review is explicitly scoped in its record. The copied final bundle separately passed both-city self-tests while repository reads were denied. [Package/source manifest](validation/v1.4/release-manifest.json) · [Native UI and final launch record](validation/v1.4/native-ui.json).

## Version 1.3 Chicago and two-location application

The native arm64 app builds and passes local signature verification. Chicago contains **8,652,712 triangles**, **22,804 generated geometric details**, **54 materials**, **816 explicit lights**, and **2,735 mapped building/building-part polygons**. The final 640 × 400 / 16-sample self-test passes geometry, Swift/Metal ABI, hardware ray tracing, image range, accumulation, navigation, and OBJ/MTL import. Reported Metal allocations were **1,606.65625 MiB** at that resolution. [Chicago self-test](validation/v1.3/chicago-self-test.json).

Both cities load from a copied app bundle launched outside the repository while the development `.build` directory is temporarily absent. That packaging check used the final resource-loading code and preceded only the 208-triangle Catalog roof infill. The final Chicago geometry subsequently passed the self-test above. [Standalone bundle proof](validation/v1.3/standalone-bundle.json) · [Paris self-test](validation/v1.3/paris-self-test.json).

The production geometry and playback controller pass **13,914 checks** across all eight Chicago and nine Paris routes: 560 walkthrough samples per route, idle clearance, supported walking paths, independent idle/walkthrough speeds, transport, manual view holds, location changes, and alternating complete day/night passes. Dedicated navigation checks include the Skydeck and transparent Ledge floors, outer glass barriers, Catalog entry, and the preserved Paris rail/void cases. [Playback](validation/v1.3/playback-validation.txt) · [Navigation](validation/v1.3/navigation-validation.txt).

Actual native UI operation verified Chicago ↔ Paris roundtrips, current-view Space playback, exact pause, 2×/4×/8× transport, keyboard idle speed, manual holds, an observed transition to the night pass, full-screen entry/exit, live viewport resizing, and the final compact layout with all controls and attribution visible. The self-test also renders landscape, portrait, and wide targets and checks their dimensions and camera aspect. GPU exports shared the device during some UI checks, so observed FPS is not a sustained performance benchmark. [Native UI evidence](validation/v1.3/native-ui.json).

All sixteen Chicago day/night gallery images were visually inspected, together with additional route samples and the final 1920 × 1200 overview stills. The day gallery uses 128 samples and night 256; the final hero stills use 256 and 512 respectively. Review covered tower proportions, camera clearance, curtain-wall details, the roof garden and skylight, five Ledge boxes, crown lighting, river/bridge/boat framing, and night reflections. [Building review](validation/v1.3/building-visuals.json) · [Context review](validation/v1.3/context-visuals.json).

Bundled Chicago and Paris map data pass finite-coordinate, positive-area, triangulation-coverage and deterministic-regeneration checks. Chicago additionally checks named bridge/river/landmark IDs, Willis exclusion from the context geometry, and river/ground area partition. Published dimensions and photographs constrain the architecture; interiors, façade finishes, distant buildings, vegetation, boat design and lighting remain authored approximations. [Chicago map check](validation/v1.3/chicago-map-validation.txt) · [Paris map check](validation/v1.3/paris-map-validation.txt) · [Model scope](WILLIS.md) · [Context scope](CHICAGO.md).

The Metal regression executes actual daylight/night ray kernels and checks finite output, exact progressive averaging/reset, ordered encoder batching and light-buffer bindings. Thin-sheet glass checks cover numerical Fresnel, tinted shadow transmission, opaque blockers, through-glass emission at a low bounce limit, and deterministic background guides. Reconstruction tests retain the previous sky, disocclusion, material-edge, zoom, and emissive-coverage guards and add current-frame filtering behind glass. [Metal](validation/v1.3/metal-validation.txt) · [Glass](validation/v1.3/glass-validation.txt) · [Reconstruction](validation/v1.3/denoiser-validation.txt).

Fine sampling grain remains in moving glass, thin detail and difficult night reflections. These tests establish the checked behavior, not a surveyed digital twin, exhaustive navigation proof, complete physical light transport, or a scene-wide frame-rate guarantee.

## Version 1.3 final motion and reflection checks

All ten actual-scene cases pass at 960 × 600, 48 frames, four current samples and independent 128-sample references. Both image RMSE and temporal residual must improve. These results use the final selective path regularization and **truly unfiltered** raw presentation. The [pre-correction report](validation/v1.3/motion-before-correction.json) is preserved, including its failed night case; its older “raw” stream still used the legacy presentation filter, so percentages across those baseline policies are not directly comparable. [Method notes](validation/v1.3/motion-baseline-notes.md).

| Location / moving view | Raw image RMSE | Reconstructed image RMSE | Temporal residual reduction |
| --- | ---: | ---: | ---: |
| Chicago / willis-overview | 0.050991 | 0.034317 | 46.64% |
| Chicago / willis-facade | 0.034809 | 0.012710 | 70.04% |
| Chicago / willis-night | 0.042231 | 0.040895 | 5.11% |
| Chicago / chicago-river | 0.099315 | 0.037804 | 62.76% |
| Chicago / chicago-river-night | 0.050944 | 0.037221 | 28.63% |
| Paris / overview | 0.050246 | 0.036237 | 44.27% |
| Paris / iron | 0.086037 | 0.040132 | 70.47% |
| Paris / night-silhouette | 0.056418 | 0.049739 | 13.13% |
| Paris / river-day | 0.075982 | 0.042506 | 53.27% |
| Paris / river-night | 0.066008 | 0.052998 | 22.75% |

[Chicago motion report](validation/v1.3/chicago-motion.json) · [Paris motion report](validation/v1.3/paris-motion.json). Paris's night region checks also pass: dark-city image error improves, clear-sky RMSE is 0.000236 (limit 0.004), and maximum unsupported temporal brightness is 0.000000 (limit 0.10). GPU timings in the reports include concurrent exports and are not isolated benchmarks.

Review of the first day movie exposed bright secondary-reflection speckles. Paired one/two/three-bounce renders isolated their origin, and the final selective glossy path regularization removes the prominent isolated outliers in paired river and Ledge views. Matched 16→128-sample comparisons reduce MSE by 41.08% for the river and 20.38% for the Ledge. Each mode is compared with its own reference: these measure convergence, not unbiased physical truth. The final sixteen day/night gallery images were inspected again after the correction. [Diagnosis](validation/v1.3/firefly-diagnosis.json) · [Paired and final-gallery review](validation/v1.3/regularization-review.json) · [Convergence measurements](validation/v1.3/regularization-convergence-metrics.json).

The new GPU fixture preserves exact first-surface, two-sheet transmission and camera-glass reflection radiance for 4,096 pixels each, and catches incorrect shared-branch state. Its secondary glossy fixture reduces variance by 97.1%, with a measured mean change from 0.02774 to 0.03126; the bias is explicit. Separate mixed-window and presentation fixtures also reject their respective old shader implementations. [Regularization checks](validation/v1.3/regularization-validation.txt) · [Negative controls](validation/v1.3/regularization-negative-control.txt) · [Implementation and opt-out](MOTION.md#selective-glossy-path-regularization).

## Version 1.3 finished demonstrations

Both final H.264 movies are **96.000 seconds, 1920 × 1080, 24 FPS and 2,304 frames**. They use three path interactions, motion reconstruction and selective glossy path regularization; daytime uses 16 samples/frame and night uses 24. Full FFmpeg `-xerror` decoding passed for all 4,608 frames. All eight chapter midpoints in each movie were visually inspected for composition, glass/reflection detail, obstructions, captions, attribution and conspicuous speckles. This is a complete decode plus sampled visual review, not frame-by-frame visual inspection of every frame.

The corrected day river and Ledge chapters remove the previously conspicuous isolated white fireflies while retaining the reflection shapes and transparent floor. Night frames retain lit office panes, white antennas, warm boat/bridge illumination and water reflections. Fine sampling grain remains in dark glossy surfaces and some glass views. Day and night movie sizes are respectively 240,920,212 and 252,203,915 bytes. [Day media proof](validation/v1.3/day-media.json) · [Night media proof](validation/v1.3/night-media.json) · [Local demo files and chapter list](DEMO.md#version-13-demonstration-artifacts).

Final day/night overview stills were regenerated at 1920 × 1200 with 256/512 samples and inspected. Their copies are included in the GitHub README. The signed app was reopened after both exports and visually checked with all eight Chicago cards, the complete viewport, transport, idle controls and map attribution present; it resumed the default 1× day/night idle cycle. [Package/source manifest](validation/v1.3/release-manifest.json) · [Native UI record](validation/v1.3/native-ui.json).

## Version 1.2 Paris and river update

The final app is native arm64, version **1.2.0 / build 3**, and passes local signature verification. Its packaged resources load when launched from outside the repository. The final scene contains **8,645,884 triangles**, **41 materials**, **586 explicit lights**, **12,743 generated geometric details**, and **2,760 mapped building footprints**. Its 640 × 400 / 16-sample self-test passed geometry, Swift/Metal ABI, hardware acceleration, image range, accumulation, navigation and OBJ/MTL import. Metal allocations at that test resolution were **1,605.375 MiB**. [Current self-test](../output/v3-review/validation.json).

The final production geometry passes **7,334 playback and clearance checks**: 560 walkthrough steps and 120 idle samples per view, including the ninth river route. Floor-support, body-sweep, rail/void safety and manual-navigation checks also pass. The native UI was operated to verify automatic ordered cycling, keyboard idle speed, manual selection holding past the next dwell, current-view Space playback, pause, 2×/4×/8× transport, Idle Play and night mode. All nine cards fit the tested window. [Playback log](../output/v3-review/playback-validation.txt) · [Navigation log](../output/v3-review/navigation-validation.txt).

All nine day and night gallery views were visually inspected. Review prompted a clearer Iron route, smoother near foliage, exposed lower quays and twelve modest summit downlights. The final river night still and daytime Paris still were inspected at 1920 × 1200. Mapped polygons pass finite-coordinate, positive-area, triangulation-coverage and deterministic-preprocessing checks. Facades and terrain remain authored approximations; see [Paris](PARIS.md) and [river](RIVER.md) scope notes.

The Metal shader harness passes daylight/night pipeline execution, finite rays, exact reset, exact progressive averaging and light bindings. The reconstruction GPU suite retains its sky/disocclusion/edge/zoom tests and adds nonuniform emissive coverage, adjacent lit/unlit rooms, and unresolved distant night coverage. [GPU trace log](../output/v3-review/metal-validation.txt) · [Reconstruction log](../output/v3-review/denoiser-validation.txt).

Five real-scene comparisons use 48 frames at 960 × 600, four current samples and independent 128-sample references. Each case has an independent deterministic seed. Day cases were measured before the final night-only footprint guard; the night cases were rerun after it. The unchanged daylight behavior and final night results are combined with explicit provenance in the [motion report](../output/v3-review/motion-validation.json).

| Motion | Raw image RMSE | Reconstructed image RMSE | Temporal residual reduction |
| --- | ---: | ---: | ---: |
| Overview pivot | 0.038520 | 0.036365 | 25.41% |
| Iron pan | 0.055235 | 0.040192 | 53.63% |
| River daylight | 0.058858 | 0.042569 | 39.27% |
| Night silhouette | 0.048675 | 0.048323 | 2.70% |
| River night | 0.058092 | 0.052999 | 12.57% |

The richer city raises the raw dark-region error through real subpixel window coverage. The final dark-region RMSE improves from **0.026323 to 0.022825**. Its maximum brightness attributable only to temporal history, after comparison with matching raw, reference and spatial-only frames, is **0.000000**; the limit is 0.10. Clear-sky RMSE is **0.000236**, below 0.004. The ROI was not narrowed to exclude pixels beside lit windows. The original absolute dark-region 0.01 threshold was replaced with separate noise and temporal-contamination measures, not simply increased. [Method and coverage tradeoff](MOTION.md#version-12-city-window-coverage).

Fine subpixel sampling noise remains, especially in distant night ironwork/windows and difficult reflections. These measurements cover selected motions and do not establish a scene-wide frame-rate guarantee. Some runs shared the GPU with image/movie exports.

## Version 1.2 finished media

The daytime movie is **108.000 seconds, 1920 × 1080, 24/1 FPS, 2,592 frames**, with eight samples per frame. The night river movie is **56.000 seconds, 1440 × 900, 24/1 FPS, 1,344 frames**, with twelve samples per frame. Both are native H.264 exports with three path interactions, final motion reconstruction and visible OpenStreetMap attribution. Full FFmpeg decoding with `-xerror` passed for both. All nine daytime chapter midpoints and five night route samples were visually inspected for camera clearance, detail, captions and obvious light trails. The night river retains some sampling grain; no detached light trails were apparent in the reviewed frames.

[Day media report](../output/v3-review/day-media-validation.json) · [Night media report](../output/v3-review/night-media-validation.json) · [Demo links](DEMO.md#version-12-demonstration-artifacts). The final packaged app was reopened successfully and left cycling its night viewpoints.

## Version 1.1 renderer baseline

The version 1.1 application self-test passed with **2,075,004 triangles**, **10,643 generated geometric details**, **19 materials**, 458,409 navigation BVH nodes, and all checked Swift/Metal ABI layouts valid. The night scene has **430 explicit light sources**. The current test renders 640 × 400 with 16 accumulated samples and passes image-range, accumulation, navigation and OBJ/MTL importer checks. [Machine-readable self-test](../output/validation.json); [night rig details](NIGHT.md).

The [2560 × 1600 night still](../output/Eiffel-Tower-Night.png), rendered at 256 samples, has been visually reviewed. The updated [96-second eight-view movie](../output/Eiffel-Walkthrough-v2-1080p.mp4) and [56-second night orbit](../output/Eiffel-Night-Walkthrough-1080p.mp4) were exported at 1920 × 1080 / 24 FPS, with 8 and 12 samples per frame respectively and three path interactions. Both passed full decoding with FFmpeg `-xerror`: 2,304 daytime frames / 96.000 seconds and 1,344 night frames / 56.000 seconds. All eight daytime chapter midpoints and night frames at 2, 14, 28, 42 and 54 seconds were visually reviewed. The reviewed night frames have clean tower edges against both sky and city, without the previously observed horizontal gold trails. [Final media report](../output/v2-review/media-validation.json). [Artifact descriptions](DEMO.md#current-demonstration-artifacts).

## Version 1.1 walkthrough regression

`./scripts/validate-playback.sh` passes **6,492 checks** against the production scene, playback code and CPU navigation BVH. It compiles to a temporary executable, returns a nonzero status on failure and removes its temporary files.

The clock checks cover separate idle/walkthrough time, exact pause/resume, all five pace settings, rewind/fast-forward 2×/4×/8× cycling, opposite-direction resets, endpoint clamps, view wrapping, manual cancellation, seeking and invalid timestamps. Every route and idle animation begins at its selected bookmark. The overview verifies a complete walkthrough orbit and a 0.35-degree-per-second idle pivot.

For every one of the eight views, the harness samples **560 walkthrough positions** at 0.1-second intervals and **120 idle positions** at one-second intervals. All tested paths have clear body sweeps and at least 18 cm of cardinal camera clearance. Ground/deck/pavilion walking routes retain floor support. The run reported zero obstructed movements, unsupported walking samples or near-surface camera samples. Anatomy of Iron's starting camera was moved outward from a nearby member, with field of view adjusted to preserve close framing.

These are sampled route and clock checks, rather than an exhaustive proof of arbitrary manual navigation. Native runtime review also verified Space, repeated Right at 2×/4×/8×, opposite Left at 2×, Up/Down view selection, and the night control. The final app was opened in its night overview idle state. [Playback harness](../Tests/Playback/main.swift).

## Version 1.1 motion reconstruction checks

The independent `swift scripts/validate-denoiser.swift` harness executes the production Metal reconstruction kernels on synthetic scenes. Its detailed checks and measured synthetic results are documented in [MOTION.md](MOTION.md).

The final Eiffel comparison, after correcting bright silhouette history trails, passed at **960 × 600**, **48 frames** per view and **four samples per frame**, against independent **128-sample reference frames**. Measurements use the second half of each sequence after history has developed. [Persisted metrics](../output/v2-review/motion/metrics.json).

| Moving view | Raw image RMSE | Reconstructed image RMSE | Image error reduction | Temporal residual reduction |
| --- | ---: | ---: | ---: | ---: |
| Overview pivot | 0.035948 | 0.032304 | 10.14% | 31.64% |
| Ironwork pan | 0.043961 | 0.030511 | 30.60% | 40.70% |
| Night silhouette | 0.047533 | 0.045663 | 3.93% | 12.54% |

The corresponding raw/reconstructed temporal residual RMSE values are 0.048960 / 0.033471 for the overview, 0.061775 / 0.036634 for ironwork, and 0.064129 / 0.056088 for the night silhouette. These are measured reductions for the selected camera traces, not a claim that all scenes or motions improve by the same amount.

The night regression also measures defined regions of dark city and clear sky, where a bright silhouette previously left stale horizontal trails. Dark-city RMSE is **0.007468**, below the **0.01** failure threshold; clear-sky RMSE is **0.000232**, below **0.004**. Both use normalized display-space RGB against the reference image. These checks guard against a low global error score concealing visible ghosting in dark regions.

Mean reconstructed-frame GPU durations in this run were **21.68 ms** for the overview, **62.31 ms** for ironwork and **49.49 ms** at night. Two movie exports were sharing the GPU during measurement; these timings include that contention and are not isolated performance benchmarks.

Reproduce this comparison with:

```sh
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --motion-test output/motion-validation --width 960 --height 600 \
  --frames 48 --samples 4 --reference-samples 128
```

This compares moving golden-hour overview and ironwork sequences plus a night silhouette sequence against independently rendered high-sample reference images. Add `--lighting 2` to run only the night silhouette test. It writes raw/reconstructed/reference PNGs and `metrics.json`. The reported image error is display-space RGB RMSE; temporal residual error measures consecutive errors after reference motion has been subtracted. The command fails if reconstruction increases either error measure or exceeds either night ghosting threshold. Scene-wide performance and photographic night fidelity should be assessed separately from these focused tests.

## Original-release baseline

The following tables, interactive observation and original movie validation record the earlier release. The paths `output/validation.json` and `output/self-test.png` are overwritten by each subsequent self-test, so their latest contents can differ from the preserved baseline values below.

## Scene and renderer self-test

The latest [machine-readable report](../output/validation.json) and [self-test image](../output/self-test.png) are written by the executable. The table below preserves the successful original-release self-test.

| Measurement | Result |
| --- | ---: |
| Overall result | Passed |
| Device | Apple M3 Ultra |
| Metal ray tracing available | Yes |
| Unified memory | Yes |
| Scene triangles | 2,065,596 |
| Generated geometric details | 10,643 |
| Materials | 18 |
| Navigation BVH nodes | 458,409 |
| Render dimensions | 1440 × 960 |
| Final accumulated samples | 16 |
| Metal allocations at reporting time | 402.328125 MiB |
| Final batch mean GPU time per sample | 5.691 ms |
| Mean RGB image byte | 180.262 / 255 |
| Complete command elapsed time | 0.554 s |
| Swift/Metal ABI check | Passed |

The self-test validates finite vertex positions and normals, the 32-byte vertex/material and 128-byte uniform layouts, triangle/material consistency, Metal pipeline and acceleration-structure construction, a nonblank image with useful dynamic range, changing progressive samples, the expected sample count, and a navigation ground ray. The offscreen timing is the final command-buffer GPU duration divided by its sample count. It is not directly comparable with the interactive frame timing below, which includes several samples and presentation.

OBJ/MTL checks in the same run passed for negative-index quads, metre scaling, normalized normals, named Kd/Ns/Ks/d materials, concave-polygon area preservation, and rejection of malformed, zero, out-of-range, and degenerate indices.

To reproduce at the recorded resolution:

```sh
./scripts/build-app.sh
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --self-test --width 1440 --height 960
```

The command replaces `output/self-test.png` and `output/validation.json` with measurements from the new run. Timings can vary with competing work, thermal state, shader caches, and the selected GPU.

## Navigation regression

The independent CPU navigation regression passed against the same final scene used by the renderer. It compiles the production `SceneTypes.swift`, `EiffelScene.swift` and `CollisionWorld.swift` together with [Tests/Navigation/main.swift](../Tests/Navigation/main.swift), so it exercises the actual navigation mesh and BVH without requiring the graphical app or Metal rendering.

Run the preserved test with:

```sh
./scripts/validate-navigation.sh
```

The script compiles into a temporary directory, runs the checks, returns a nonzero exit status on failure, and removes its temporary executable. It needs the installed Apple Swift toolchain and no external dependencies. The persisted harness is identical to the one that produced the successful independent results.

| Authored walking stop | Measured floor Y | Observed local movement |
| --- | ---: | --- |
| Beneath the arches | 0.11 m, on a paving inlay | All four cardinal 0.2 m steps passed |
| First terrace | 57 m | All four cardinal 0.2 m steps passed |
| Visitor pavilion | 57.05 m | All four cardinal 0.2 m steps passed |
| Second terrace | 115 m | All four cardinal 0.2 m steps passed |
| Summit gallery | 276 m | All four cardinal 0.2 m steps passed |

Continuous movement checks, using the app's support-ray and `canMove` rules in 0.1 m increments, completed a 77 m ground route beneath the arches, a 13.5 m first-terrace route, both east-pavilion doorways with a 24 m central aisle route, the mirrored west pavilion's 30 m route, a 7 m second-terrace route and a 4 m summit-gallery route.

Negative checks correctly blocked travel toward the first terrace's central void at Z≈13.90 m, its outside edge at Z≈36.00 m, the second terrace's central void at Z≈7.60 m, and the summit railing at Z≈7.40 m. Support rays returned no nearby walking surface in the first and second central voids or beyond the first terrace. The harness reported no failures. The navigation BVH contained 1,647,988 retained triangles in 458,409 nodes; the full rendered scene contained 2,065,596 triangles.

These checks cover the authored walking starts, representative connected routes, pavilion access and specific edge cases. They are not an exhaustive proof of every possible camera motion, all stair routes or pedestrian accessibility.

## Shader regression

The current production shader was independently exercised with:

```sh
swift scripts/validate-metal.swift
```

Observed output:

```text
PASS: Metal shader + presentation pipelines on Apple M3 Ultra
PASS: actual 32×32 hardware ray trace, finite RGB and expected five-metre hit
PASS: exact frame-zero reset; progressive mean maximum error 0.0
PASS: 32 sequential commands versus 32 encoders in one batch; maximum RGB error 0.0, differing components 0/3072
```

The test creates a real two-triangle Metal acceleration structure and compiles both the production compute and fullscreen presentation pipelines. It evaluates independently seeded samples, resets the accumulation with a repeated seed, and checks that the combined image equals the arithmetic mean. All RGB values must remain finite, and the known triangle must appear at approximately five metres. This directly covers accumulation correctness and a basic GPU intersection path; it does not establish complete BRDF energy conservation or convergence against an independent reference renderer.

The batching regression compares 32 samples submitted as individually completed command buffers with the same 32 samples encoded into one command buffer. Both runs reuse the same acceleration structure, texture, materials, camera and random seeds, beginning with an explicit frame-zero history reset. All 3,072 RGB components matched exactly on the M3 Ultra (maximum absolute float error 0.0; the test permits at most 0.000001). Reusing the acceleration structure isolates command/encoder ordering from differences in BVH construction between processes. This verifies the 32-encoder offscreen batching schedule in the controlled fixture; it does not imply that separately rebuilt production scenes must match bit for bit.

## Native app and packaging

The arm64 release build and app packaging completed successfully. Verified checks include:

- `bash -n` for the build script and launcher.
- `swift package dump-package` accepting the package manifest.
- `file` identifying the packaged executable as Mach-O 64-bit arm64.
- `plutil -lint` accepting the application property list.
- `codesign --verify --deep --strict` accepting the locally signed app.
- Packaged `--help` execution and launcher forwarding with `Launch Atelier.command --help`.
- A real packaged 64 × 64, one-sample PNG export through the bundled Metal renderer.
- A subsequent full release rebuild and signature verification after the window sizing correction.

The packaged smoke render preceded the final geometry refinement, so its earlier triangle count is not used as the current scene count. The final self-test table above reports the current geometry.

Native UI inspection confirmed the corrected window geometry after removing SwiftUI intrinsic-size propagation from the Metal viewport. The opening-view performance panel reported **59 FPS**, **8.9 ms GPU frame time**, **2,065,596 triangles**, and approximately **466 MiB** of Metal allocations. The default Balanced mode caps internal width at 1440 pixels, uses three path interactions, and submits four samples per displayed frame. These values are an observed opening-view snapshot, not an automated sustained benchmark or a guarantee for every camera position. The self-test's smaller allocation count is expected to differ because the desktop app also has drawable and UI resources.

The display is asked to refresh at 60 Hz; a GPU duration below one refresh interval does not by itself establish end-to-end latency or available throughput. The program reports `MTLDevice.currentAllocatedSize`, not all physical RAM, peak process memory, or a measured 512 GB working set. Apple's [storage-mode documentation](https://developer.apple.com/documentation/metal/choosing-a-resource-storage-mode-for-apple-gpus) describes shared and private GPU resources; its [ray-tracing guide](https://developer.apple.com/videos/play/wwdc2023/10128/) documents the acceleration-structure APIs used here.

## Demonstration media verification

| Artifact | Export configuration | Verification status |
| --- | --- | --- |
| `output/Eiffel-Walkthrough-1080p.mp4` | 1920 × 1080, 96 s, 24 FPS, 64 samples/frame, four path interactions | Passed: H.264 High, 2,304 frames, exact 96.000 s, complete decode and eight chapter-frame reviews |
| `output/Eiffel-Tower-4K.png` | 3840 × 2160, 512 samples, five path interactions | Generated and visually reviewed |
| `output/final-review/` | Eight chapter views at 1440 × 960, 128 samples each | Generated and visually reviewed |

The native layout was also visually inspected after the sizing fix; all eight chapter buttons, the render settings toolbar, the performance panel and the scene fit inside the window. Close-up geometry, interior lighting, tower framing and summit views were reviewed in the gallery.

The final MP4 is **251,484,830 bytes**, H.264 High profile with YUV 4:2:0, 1920 × 1080, 24/1 FPS, **2,304 frames**, and **96.000000 seconds**. `ffprobe` metadata assertions passed. FFmpeg decoded the complete recording with `-xerror` and extracted chapter midpoints at 6, 18, 30, 42, 54, 66, 78, and 90 seconds; no decoder errors occurred. All eight extracted frames were visually inspected for composition, intended scene, caption readability and close detail. The pavilion retains some Monte Carlo grain at 64 samples/frame. The tour uses authored chapter cuts and short dolly moves; it does not claim a continuous elevator ride.

See [media-validation.json](../output/media-validation.json) for metadata and [video-review](../output/video-review/) for the inspected frames. The 4K still's dimensions were independently checked as 3840 × 2160. The movie export completed in 1,205.75 seconds while other validation and the live preview shared the GPU for part of the run; this elapsed time is not an isolated export benchmark.

The finalized application was rebuilt with its original icon and locally verified signature. Invalid command-line actions and unsupported OBJ/tour combinations return an explicit error instead of silently rendering the Eiffel tour with the wrong geometry. A final app launch succeeded after the export.

## What these checks establish

The release-specific evidence above establishes that the engine builds, loads both cities from its local app bundle, dispatches genuine Metal ray queries on the M3 Ultra, accumulates samples correctly in the regression scene, renders the mapped architectural scenes, and exposes measured runtime statistics. These checks do not certify a surveyed reconstruction, all possible navigation paths, complete modern-rendering feature support, or arbitrary city-scale memory/performance behavior. See the [Willis](WILLIS.md), [Chicago](CHICAGO.md), [Eiffel](MODEL.md), and [engine](ENGINE.md) scope notes.
