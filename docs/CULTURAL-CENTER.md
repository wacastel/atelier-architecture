# Chicago Cultural Center

Atelier 2.3 adds the Chicago Cultural Center to the existing Chicago world, beside Millennium Park. Eight two-minute studies cover its exterior, Washington Street entrance, mosaic stair, Tiffany dome, Preston Bradley Hall and the restored Grand Army of the Republic rooms. The final route connects the existing Cloud Gate view to the Cultural Center's opening exterior view.

## Routes and controls

| View | Study | Route |
| --- | --- | --- |
| 1 | The people's palace | An elevated exterior arc along the south and east elevations |
| 2 | Washington Street welcomes you | An entrance approach over the modeled exterior steps and through the open Washington portal |
| 3 | A stair made of mosaics | A climb through the central stair, intermediate landing and returning flight toward Preston Bradley Hall |
| 4 | Under the Tiffany dome | A slow passage along the central aisle with the camera looking up into the glass |
| 5 | Preston Bradley Hall | A side-aisle walk looking across the hall's arches, marble and mosaics |
| 6 | The Grand Army rotunda | A circuit beneath the distinct Healy & Millet glass dome |
| 7 | Color restored | A walk through Memorial Hall's interpreted restored interior |
| 8 | From the Bean to the palace | A two-minute flight from Cloud Gate across the existing park and Michigan Avenue setting |

Every bookmark has its own gentle idle movement. Play starts the selected walkthrough; Idle Play cycles through the views. The destination uses the ordinary day/night passes and the existing `N` lighting toggle, without the Skyline destination's authored lighting overrides. The six entrance and interior studies use walking routes; the exterior study and connecting flight are aerial cameras.

The Chicago Demo now contains **64 routes across eight Chicago destinations**, taking **118 minutes 36 seconds** at normal speed. Its order is Willis Tower, Chicago Skyline, Millennium Park, Chicago Cultural Center, Chicago Lakefront, Museum Campus, Chicago North Side and Robie House. Paris remains outside this demo. Random starting position, sequential continuation and previous/next navigation across destination boundaries retain their existing behavior.

## Reference and map basis

Research was checked on September 9, 2026. The [City's landmark record](https://webapps1.chicago.gov/landmarksweb/web/landmarkdetails.htm?lanId=1274) identifies the building at **78 East Washington Street**, completed in **1897** by **Shepley, Rutan & Coolidge**. It began as the central public library. Its limestone civic exterior and lavish public interior are the architectural subjects of this destination.

The building already exists in the offline Chicago map as [OSM relation 15899437](https://www.openstreetmap.org/relation/15899437), derived building ID `-158994370`. The overlapping North Side resource also carries this relation as `-15899437`. Both generic representations are excluded when assembling the detailed model, so their old solid volumes do not fill its new interiors. The mapped outer bounds are world x `882.20…930.10` and z `−613.27…−500.77` metres. The authored model uses their approximate centre, `(906.15, 0, −557.02)`, and the block's small skew. That centre corresponds to approximately **41.883880° N, 87.624985° W**, around 190 metres northwest of the modeled Cloud Gate centre. These are calculations from the bundled map, not survey coordinates or an asserted pedestrian distance.

The Tiffany dome and the northern Grand Army dome are different works. [Wight & Company's restoration account](https://www.wightco.com/work/preston-bradley-dome/) identifies Jacob A. Holzer's Tiffany design in Preston Bradley Hall and work on more than 30,000 pieces of glass. [Berglund's Grand Army restoration account](https://www.berglundco.com/projects/chicago-cultural-center-grand-army-of-the-republic-rooms) identifies the northern dome as Healy & Millet and describes the restored decorative finishes, mosaics and lighting. The older City overview's combined attribution of both domes is not used for this reconstruction.

The modeling reference pass inspected the actual plan and photograph pixels on PDF pages 52–53 (printed pages 96–97) of [Architectural Record, January 1978](https://www.usmodernist.org/AR/AR-1978-01.pdf). The plan supplied the north/south relationship of the two domed halls and the Washington circulation. The [City's interior visitor map](https://www.chicago.gov/content/dam/city/depts/dca/Chicago%20Cultural%20Center/cccmap.png) was also viewed: Memorial Hall occupies the eastern portion of the north wing, with Claudia Cassidy Theater to its west. That map corrected the hall's model and camera placement before route validation. Historical plans establish spatial organization; they are not treated as evidence that the current finishes remain unchanged.

The restored finishes instead follow the conservation teams' project imagery: [Holabird & Root's dome restoration](https://www.holabird.com/chicago-cultural-center-domes-restoration) for the Tiffany room, and [Harboe Architects' restored Grand Army rooms](https://www.harboearch.com/projects/american-portraiture-5ft5w), photographed by Tom Rossiter, for the northern rooms. Nine primary reference photographs were visually inspected during the modeling pass. These images guide color, glass patterns, decorative stone and fixture character; they are not pasted onto the model as facade textures.

## Reconstruction scope

The model and camera paths use a shared local layout: east is approximately world `(1, 0, −0.014)`, and south is approximately `(0.014, 0, 1)`, with both directions normalized. The Washington entrance is on the south side. Preston Bradley Hall occupies the southern wing; the Grand Army rotunda and Memorial Hall occupy the northern wing.

The Tiffany glass diameter is modeled at 38 feet (11.5824 metres), following the Chicago Architecture Center's value. The northern inner glass uses Harboe's 36-foot dimension (10.9728 metres), while Berglund reports a 40-foot span. Other Tiffany sources also report different dimensions. These figures are not presented as reconciled survey measurements; the [reference ledger](CULTURAL-CENTER-REFERENCES.md) records each source and the chosen model values. The principal room floor is modeled at 11.8 metres, the cornice at 31.7 metres and the protective skylight tops at 33.55 metres. These heights are authored estimates. The former generic map volume's 18.75-metre, level-derived height is not used as a verified building elevation.

Floor elevations, stair dimensions, small ornament and furnishing placement are authored estimates chosen to form continuous navigable rooms. They are not an as-built survey or an official museum tour. The selected public interiors are modeled within the building; the destination does not claim a complete reconstruction of every gallery, service room or temporary exhibition. The dome motifs interpret the architectural references rather than reproducing every historic glass piece.

The colored dome panes use rough opal surfaces with modest emission to approximate illuminated, diffusing glass. They deliberately do not use the renderer's perfect thin-sheet transmission branch, which produced clear mirror-like panes in the initial render review. Separate protective skylights retain clear glass. This treatment preserves the reference's milky glass character but is not a calibrated volumetric stained-glass simulation. Existing interior fixtures provide additional warm room lighting.

## Original ambient music

The destination selects **Light Beneath the Dome**, an original D-flat-major piece at 57 BPM, generated with the existing offline composition and synthesis tools. Piano, plucked notes and a sustained pad move through four sections over approximately **139.737 seconds**. It is the ninth bundled track; the previous eight AAC files remain byte-for-byte unchanged. Location and playlist playback retain the existing music controls.

The production music-controller fixture passes [299 checks](validation/v2.3/ambient-music.json), including AAC decoding without physical playback. Full-file technical validation passes [165 checks](validation/v2.3/ambient-audio.json) across all nine tracks. The new track measures −21.02 LUFS integrated loudness and −8.36 dBTP. The [preservation report](validation/v2.3/music-preservation.json) records the previous assets. These are transport, file and signal checks; they do not claim a listening review on the Mac's speakers.

## Validation status

Full-scene CPU playback passes [106,617 checks across all 73 routes](validation/v2.3/playback.txt) in Paris and Chicago. All eight Cultural Center routes have zero blocked, unsupported or near-surface positions in the sampled checks, and their idle paths also pass. The final [standalone building fixture](validation/v2.3/cultural-center-geometry.json) passes **2,912 checks** over **482,332 rendered triangles**, **124,860 navigation triangles** and **58 lights**. The integrated Chicago world has **45,953,309 static triangles**, including the Cultural Center and the removal of both generic mapped copies. Fine ornament can remain visible while being omitted from navigation geometry.

The [playback input inventory](validation/v2.3/playback-validation.json) records Cultural Center source `7d471139…`; the final appearance source is `225783cc…`. The latter changes only five opal materials, lamp emission and existing interior light powers. All vertex bytes and triangle material indices are identical, with geometry SHA-256 `aaf62b7f8496e6c051d94c5594f636072df42340622c76ed3400abb1d7aa628d`. CPU collision classification uses positions only, so those appearance refinements preserve the tested routes and floor support. The [negative-control explanation](validation/v2.3/README.md#route-and-appearance-input-equivalence) records the two expected old-material assertion failures and the final pass.

The revised control and music fixtures and the bounded renderer-selection fixture also pass; see the [2.3 evidence index](validation/v2.3/README.md). The [final full-city rendering fixture](validation/v2.3/cultural-rendering.json) passes **37 checks** and produces **18 stills at 1280 × 800**: all eight bookmarks by day and night in reconstructed ray tracing at 64 samples, plus a selected exterior in raster and ray tracing. All 18 were visually inspected, including the refined opal domes. [Day contact sheet](validation/v2.3/rendered/day-contact.jpg) · [Night contact sheet](validation/v2.3/rendered/night-contact.jpg) · [Raster focus](validation/v2.3/rendered/focused-raster.jpg) · [Ray-traced focus](validation/v2.3/rendered/focused-ray.jpg).

The [final package](validation/v2.3/package.json) is **Atelier 2.3.0, build 16**, native arm64 with strict signature verification passed and all **27 bundled resources** byte-identical to source. Its executable SHA-256 is `e2d67668000f0dfe34924d95d4365cd7eb0422c3e73e3874181b66b88b56820c`.

The [native review](validation/v2.3/native-review.json) confirms clicking the Cultural Center's actual map label centres and focuses the building, gold selection in ray tracing and raster, retention on a second roof click, clearing on the street and selecting again. **T** produced the vertical normal Fly camera while retaining focus. **B** remained a separate fixed Map mode, where selecting the Cultural Center kept the camera vertical, **T** stayed blocked and button zoom reduced the span from 198 to 158 metres without losing focus. Changing destination cleared the selection. The music interface showed **Light Beneath the Dome** at 16% volume. Native Play started and paused the Tiffany walkthrough, and the final paused nighttime ray-traced interior was inspected.

Physical trackpad pinch and sustained W/S travel were not verified by native automation; their calculations and controller transitions have CPU coverage. These stills and scoped interaction checks do not establish native frame rate, continuous-motion noise stability or subjective music quality.

The [standalone Cultural Center validator](../scripts/validate-cultural-center.sh) checks the landmark's mesh and navigable public rooms. The existing [playback validator](../scripts/validate-playback.sh) now includes the Cultural Center sources. It checks every authored route in both physical worlds, walking support, body and camera clearance, idle motion, transport state and Chicago Demo boundaries. The [ambient-controller validator](../scripts/validate-ambient-music.sh) and [audio validator](../scripts/validate-ambient-audio.py) cover the new playlist entry and asset.
