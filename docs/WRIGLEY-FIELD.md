# Wrigley Field and Gallagher Way

The North Side scene contains an authored open ballpark in the same Chicago coordinate system as the Loop, Lincoln Park and the lakefront. `WrigleyField.swift` reconstructs the mapped field and stadium outlines, the green seating decks and exposed roof structure, the ivy-covered outfield wall, manual scoreboard, contemporary video boards, red marquee and Gallagher Way. It does not load photographic textures or copyrighted reference images into the scene.

## Placement and measured constraints

The world origin is latitude **41.878876**, longitude **−87.635918**, with metres east on X, up on Y and south on Z. The home-plate anchor is approximately **(−1650.3, 0.12, −7685.1)**; the diamond points about **39.5° east of north**. The street datum and field floor are interpretive relative elevations, not surveyed elevations.

The fresh OpenStreetMap snapshot is dated **2026-09-08T15:38:06Z**. The stadium relation spans X **−1724.372…−1531.185**, Z **−7808.697…−7618.195**. The original polygon rings and triangulation for the pitch, dirt surfaces and plaza are embedded as a bounded extract in the builder. Those retain the irregular outfield corners and the bend of the street-facing stadium edge.

| Mapped component | OSM identifier | Reconstruction use |
| --- | --- | --- |
| Stadium | relation 17379974 | Exterior boundary and shape of the main seating decks |
| Playing surface | relation 2083717 | Grass boundary, foul territory and outfield wall |
| Infield and warning-track dirt | relation 17380286 | Triangulated surfaces and grass cutouts |
| Manual scoreboard | way 1265761901 | Center-field location and orientation |
| Left and right video boards | ways 1265781812, 1265761902 | Position and approximate envelopes |
| Gallagher Way | way 1265774541 | Plaza paving outline |
| Gallagher office | way 445947684 / relation 17380054 | Adjacent terraced office massing |

Published outfield distances, in feet: **355 / 368 / 400 / 368 / 353**. Wall heights: **11½ feet**, or **15 feet** in the corners. [Chicago Cubs dimensions](https://www.mlb.com/cubs/ballpark/information/history).

The scoreboard face measures **75 × 27 feet (22.86 × 8.2296 m)**. [Chicago Cubs scoreboard](https://www.mlb.com/cubs/guide/wrigley-field-scoreboard). Its mounting elevation is estimated from the viewed photos; it is not a surveyed structural elevation.

The authored diamond uses a **27.432 m** construction square, **18.4404 m** plate-to-pitching-rubber reference and **0.4572 m** bases. The infield anchors supplement the mapped outline; OpenStreetMap boundary points are not sufficiently precise to treat every foul-corner distance as a survey measurement. [Official Baseball Rules, field diagrams](https://img.mlbstatic.com/mlb-images/image/upload/mlb/ub08blsefk8wkkd2oemz.pdf).

## Reference images actually inspected

All observations below were made by viewing the images in Chrome on **2026-09-08**, not by relying on search captions. External photographs were used for visual reference only.

| Reference | Images viewed | Features used |
| --- | --- | --- |
| [Wrigley Field Events, owner event catalog](https://www.wrigleyfieldevents.com/perch/resources/menus/2024-wfe-catalog-v2.pdf) | PDF pages 1, 18, 20 and 29 | Green seating, ivy and brick, the manual scoreboard and two screens; exposed steel concourse, open roof-light frames; Gallagher lawn, paving, café furniture and warm night lighting. Page 4 was also inspected but is a title page, not a stadium photo. |
| [Esri World Imagery, Wrigley close aerial](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=-87.658,41.947,-87.653,41.950&bboxSR=4326&imageSR=3857&size=1200,1000&format=png&f=html) | Actual aerial export | Field orientation, stadium’s rounded southwest corner, separate outfield bleachers, Gallagher plaza west of the stadium, surrounding street grid and rooftop context. Imagery acquisition date is unknown; the map footprint controls ground placement. |
| [Musco, installed Wrigley architectural lighting](https://www.musco.com/project/wrigley-field-architecture/) | Night marquee hero and two installed-photo gallery images | Warm white sign lettering on the red marquee, brightly legible exposed roof-light frames, restrained colored steelwork accents, warm entrances and neighboring streets. The page loaded in Chrome; the text-only web fetch encountered validation. |
| [National Park Service, Wrigley Field](https://www.nps.gov/places/wrigley-field.htm) | Text reference | Historic fabric and manual scoreboard context. Its linked photo was discovered but is not claimed as an additional actual visual inspection. |

The lighting follows the photographic appearance rather than a fixture schedule. Six open steel frames sit roughly ten metres above the roof. Broad overlapping white sources light the field; smaller sources reveal the scoreboard, marquee and plaza. The colored façade accents and static screen content are an authored architectural presentation, not a replay of a particular game or event. Emissive fixtures preserve their color at night; actual local lights produce illumination and reflected light on other surfaces.

## Walkable scope and detail

`WrigleyFieldLayout` exposes the coordinate transform, major camera anchors and a clear entrance route from the marquee through an interpretive passage to the field. The passage has actual floor, walls and ceiling geometry. This is a camera-access reconstruction; it does not imply that visitors may enter the real playing field or that it reproduces every real service passage.

The close-detail geometry includes separate seat pans and backs, aisle gaps, concrete risers, open structural columns and braces, individual folded ivy leaves, the wall’s projecting safety basket, foul poles, dugout benches, a three-dimensional clock and hand-operated scoreboard cells. The marquee lettering is generated geometry. The display boards show original demonstration text; the manual board is static and does not present live scores. The W flag is an illustrative traditional element.

The stands preserve the overall mapped profile and use repeated authored seating modules. They do not reproduce a ticket-level seat inventory. Stadium suites, club rooms, restaurants, service systems and structural connections are simplified. Gallagher office heights and façade modules are interpretations of the mapped storey counts and images. Surrounding Wrigleyville buildings retain the shared map-derived context; they are not individually surveyed façades.

## Validation

Run the CPU-only component check with:

```sh
scripts/validate-wrigley-field.sh
```

The fixture builds the actual mesh, checks finite coordinates, unit normals, non-degenerate triangles, material indices and bounded geometry/light counts; it also checks published dimension constants, local/world coordinate round trips and 606 samples along the gate-to-field passage. All 18 primary field-light rays are checked against the actual mesh to prevent a roof from obstructing their field targets. An explicit street-grade plane supports the short exterior portion in this isolated fixture. Integrated playback must separately validate surrounding buildings, furniture and vegetation. The fixture is not a visual-quality test.

Current component checkpoint: **261,507 triangles, 65 local lights**, with all 606 passage samples passing. The first integrated night review identified an overbright roof and dim field. After correcting field-light placement and refining the scoreboard illumination, six images from the third packaged build were actually inspected: day/night overviews, field details and the aerial approach at 50 seconds. That still-image review accepted the field/roof balance, readable boards, geometry and framing. Its exact image and source hashes, findings and limitations are recorded in [Wrigley final visual review](validation/v1.7/wrigley-final-visual-review.json). Integrated playback, motion reconstruction and exported movies require their separate checks; the six-image record does not claim full-duration video acceptance.

## Data provenance

© [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), licensed under [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). The prepared source table is `scripts/data/chicago-north-side-landmarks-2026-09-08.json`; its SHA-256 at extraction was `51351d8a57ee35045d2f133d089e5baf6cf3f5cfdcb9e5256e3f5e4e1000902c`. The raw snapshot SHA-256 is `0598f62a401eb021574c1c356a9017ac277aee8c2209a9eedf07cf9d4b406049`.

The shared North Side environment suppresses the generic stadium, its building parts and the authored Gallagher plaza/office footprints, preventing a solid generic slab from filling the ballpark or overlapping its detailed stands.
