# Chicago Cultural Center: model evidence

Researched and visually inspected on 9 September 2026. The original geometry lives in `Sources/ArchitectureEngine/CulturalCenter.swift`. No reference photographs, satellite tiles or third-party textures are bundled with the app.

## Position and plan

The existing source snapshot, `scripts/data/chicago-osm-2026-09-07.json`, records OpenStreetMap database time **2026-09-07T22:11:33Z**. Relation **15899437** comprises outer ways **115914788** and **1175466106**, and inner courtyard way **1175466107**. The two existing derivatives use IDs **−158994370** and **−15899437**; both generic buildings must be suppressed when this authored building is added. Map data is © OpenStreetMap contributors, [ODbL attribution](https://www.openstreetmap.org/copyright).

`CulturalCenterLayout` retains the Willis-origin projection: +X east, +Y up, +Z south. Its center is `(906.15, 0, −557.02)`, with local east proportional to `(1, 0, −0.014)`. The nominal body is 46.4 × 109.6 metres. Portico, cornices and entrance steps extend beyond it. The mapped courtyard ring is preserved in the upper-floor and roof meshes; its constrained triangulation was prepared with Shapely 2.1.2. The facade's small perimeter setbacks are simplified.

Two plans were actually inspected:

- The [City of Chicago visitor map](https://www.chicago.gov/content/dam/city/depts/dca/Chicago%20Cultural%20Center/cccmap.png), a 3102 × 1846 pixel image, identifies Washington Street to the south, Randolph Street to the north, Preston Bradley Hall on the third floor and GAR on the second. It also places Memorial Hall in the eastern portion of the north wing, with Claudia Cassidy Theater to its west. That distinction corrected the first authored hall outline.
- The [January 1978 Architectural Record](https://www.usmodernist.org/AR/AR-1978-01.pdf), publication pages 96–97 / PDF pages 52–53, reproduces Holabird & Root's third-floor plan and restoration photographs. Both pages were rendered and viewed. The plan supports the separated north/south rotundas, transverse southern hall and central circulation. It is a historic renovation plan, not a current measured survey.

The official map has no elevations. Ground floor 0.9 m, intermediate stair landing 6.35 m and modeled public hall floors 11.8 m are **authored estimates**. The two wings' different floor numbering is preserved in the descriptions; equal model heights do not establish equal real-world elevations. The 31.7 m cornice and 33.55 m protective skylight apex are reconstruction dimensions, not new measurements.

## Photograph ledger

All entries below mean pixels were viewed, not merely that a search result or caption was read. Reference copies remain under ignored `output/cultural-center-reference-images/` for this review only.

| Source | Images inspected | Decisions supported |
|---|---|---|
| [Chicago Architecture Center](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-cultural-center) | Four gallery photographs: Washington exterior at blue hour, close Tiffany/arch view, grand staircase, upward dome view | Granite base, limestone arcade and fluted upper register; restrained warm exterior light; pale marble, inset green medallions, mosaics and luminous blue-green glass. Exterior photography is credited there to Eric Allix Rogers. |
| [Harboe Architects: GAR restoration](https://www.harboearch.com/projects/american-portraiture-5ft5w) | `GRAND-ARMY-OF-THE-REPUBLIC-ROOMS-09-ROTUNDA-AFTER.jpg` and `…03-MEMORIAL-HALL-AFTER.jpg`, credited to Tom Rossiter | Restored rotunda's pink marble, green upper walls, bronze lunettes, paneled mahogany doors and pastel glass. Memorial Hall's darker green marble, warm red walls, gilded coffers and multi-arm lights. |
| [Holabird & Root: dome restoration](https://www.holabird.com/chicago-cultural-center-domes-restoration) | `bradley8.jpg`, `bradley2.jpg`, `Dome from stair.jpg` | Tiffany fish-scale grammar, radial/concentric frames, central roundels, triple-arched openings, ornamental drum, bowl pendants and stair balustrades. |

These nine photographs, the official visitor map and the two historic publication pages form the inspected visual set. No new satellite-image alignment or photogrammetric reconstruction is claimed.

## Dimensions and attribution that need care

The [Chicago Architecture Center](https://www.architecture.org/online-resources/buildings-of-chicago/chicago-cultural-center) gives the Tiffany dome a 38-foot diameter and approximately 30,000 glass pieces, and describes three-foot exterior masonry walls. The model uses a **5.7912 m radius** and 0.915 m wall thickness. Other restoration pages report different dome spans: Holabird & Root's page says 48 feet, while [Botti Studio](https://www.bottistudio.com/cultural-center-) says 40 feet. The 38-foot value is an explicit modeling choice; these figures are not presented as reconciled survey measurements.

[Harboe's project account](https://www.harboearch.com/projects/american-portraiture-5ft5w) specifies a 36-foot inner GAR dome, 146 panels and more than 46,000 glass pieces. [Berglund Construction](https://www.berglundco.com/projects/chicago-cultural-center-grand-army-of-the-republic-rooms) identifies its stained glass as **Healy & Millet**, the restored decorative scheme as Tiffany's, and reports a 40-foot span and 62,000 pieces. The model follows Harboe's inner-dome radius of **5.4864 m** and the actual restored photographs. It does not equate the GAR glass authorship with Preston Bradley's Tiffany dome or claim to reproduce every historic pane.

The modeled Tiffany dome has 24 radial bays and ten ring tiers with raised metal boundaries, colored opal surfaces, fish-scale cames and central roundels. GAR uses a separate geometry pattern with oval cartouches and a different palette. Individual floral motifs, central symbols, tessera colors, lamp powers and placement are authored interpretations. The opal panes use rough, opaque surfaces with restrained emission to approximate diffusing, illuminated glass; the clear protective skylights retain transmission. This distinction avoids applying the renderer's perfect thin-sheet reflection model to milky glass. It is not calibrated daylight transport through every original glass layer.

## Modeled scope and limitations

The building contains actual entrance and window apertures, thick wall segments, upper engaged columns and cornices, bronze-framed glazing, physical exterior steps, a central and returning mosaic stair, Preston Bradley Hall with four triple-arched sides, its Tiffany dome, the northern GAR rotunda and the adjoining Memorial Hall. Both domes have separate protective glazing above them. Selected mosaic panels use finer tessera geometry for close inspection.

Offices, the theater, exhibition installations, concealed services, exact historic inscriptions, accessibility routes and all five floors' complete partitions are not reconstructed. The model represents an unobstructed architectural visit, without temporary exhibitions or restoration scaffolding. Its warm night lighting follows the inspected photographic character; fixture counts and powers are not an as-built lighting inventory. No measured native frame rate or photographic equivalence is claimed.

## Verification

Run `bash scripts/validate-cultural-center.sh` from the repository root. It builds only the standalone landmark and a CPU navigation BVH. The fixture checks finite/nondegenerate geometry, material references, the <500,000-triangle and ≤90-light budgets, genuine open doorways, two separate dome hits, preservation of the mapped courtyard, exact entrance/stair path continuity, floor support and bidirectional clearance through the modeled stairs and halls. Tiny ornament can be omitted from navigation while remaining visible geometry.

The report is `output/cultural-center-geometry.json`. It also records a hash of all vertices and material indices so a material-only appearance correction can be distinguished from a navigation geometry change. The first full-world draft exposed overly clear domes and overbright marble; the revised opal materials and lower interior light powers preserve all geometry. A retained negative control verifies that the original clear-sheet materials fail the new opal checks. Full shared-city routes, generic-building exclusion, native controls and day/night render review are separate integration checks; the standalone fixture cannot prove them. See [CULTURAL-CENTER.md](CULTURAL-CENTER.md) for the eight studies and current release validation.
