# Chicago surroundings: sources and reconstruction

The Willis Tower scene uses actual OpenStreetMap footprints, building parts, roads, parks and river geometry. It shares the Eiffel scene's metre-scale, native Metal ray tracing, geometry detail, reflection, lighting and camera reconstruction systems. Nearby Chicago architecture is authored around those mapped outlines and tagged heights; this is not a surveyed digital twin or a photogrammetry asset.

## Map database

`scripts/data/chicago-osm-2026-09-07.json` preserves the Overpass response, including its OSM database timestamp **2026-09-07T22:11:33Z**. The source and derived database are **© OpenStreetMap contributors, ODbL 1.0**. [Attribution](https://www.openstreetmap.org/copyright) · [License](https://opendatacommons.org/licenses/odbl/1-0/).

The query sent to `https://overpass-api.de/api/interpreter` was:

```overpass
[out:json][timeout:90];
(way[building](around:1700,41.878876,-87.635918);
 way["building:part"](around:800,41.878876,-87.635918);
 relation[building](around:1700,41.878876,-87.635918);
 way[leisure=park](around:1700,41.878876,-87.635918);
 way[landuse=grass](around:1700,41.878876,-87.635918);
 way[natural=water](around:1700,41.878876,-87.635918);
 relation[natural=water](around:1700,41.878876,-87.635918);
 way[highway](around:1000,41.878876,-87.635918);
 way[waterway=river](around:2200,41.878876,-87.635918););
out geom;
```

Run `python3 scripts/prepare-chicago-context.py` to regenerate the bundled `Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json`. No third-party Python packages are required. The app uses this local database and works offline.

The result has **2,735 building and building-part polygons, 484 park/grass/water areas, 4,161 street and pedestrian ways, 13 movable bridge roadways, and four river polygons**. Source IDs, names, material tags, relation provenance and height provenance are preserved. Height sources comprise 192 explicit height tags, 1,522 level tags converted using an assumed 3.75 m storey, 967 explicitly marked estimates, 53 low bases beneath mapped building parts, and one tagged-height adjustment for the separately modeled 311 South Wacker crown. These are polygons, not a count of unique entire buildings.

Projection origin: **41.878876° N, 87.635918° W**. +x is east, +z south, +y up, in metres; upper street grade is zero. Longitude is scaled by the cosine of the origin latitude. The local equirectangular projection is appropriate for visual context, not cadastral surveying. The map's Willis whole-block polygon and its parts are excluded from the site rectangle so the detailed tower, Catalog and lobby are not duplicated.

Building relation outer ways are joined and simple polygons are triangulated. Courtyard provenance is retained, but polygon interiors currently fill courtyard holes; below-ground station concourses, roofs and incomplete construction are omitted. Where mapped building parts exist, the broad parent footprint becomes a low base and the parts establish the real setback massing. The far background beyond the mapped area is inexpensive, explicitly interpretive skyline context.

## Satellite and photographic references actually viewed

No remote image was downloaded into this project or used as a texture. References were viewed in the in-app browser:

- **Esri World Imagery**: viewed the actual aerial image through the public [World Imagery export service](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=-87.642,41.875,-87.631,41.883&bboxSR=4326&imageSR=3857&size=1280,1024&format=png&f=html), covering the tower, the South Branch, Union Station and the adjacent Loop blocks. The image shows the river's southward bend, bridge alignments, street grid, dense irregular building footprints, roof equipment and several planted plazas. Esri's imagery is a mosaic with potentially different acquisition dates; it informs broad spatial relationships rather than certifying the current state of construction. The final geometry follows the dated OSM snapshot, not traced image pixels.
- **[KPF: 311 South Wacker Drive](https://www.kpf.com/project/311-south-wacker-drive)**: viewed the architect's dusk photograph showing the rose/red granite exterior, illuminated cylindrical crown and Willis behind. KPF identifies a central glass cylinder with four satellites and a 293 m building height. The model adds five faceted cylindrical crown forms with physical mullions on the mapped tower part. The red-granite interpretation, podium, crown framing and rooftop equipment are original geometry.
- **[Chicago Loop Bridges: Jackson Boulevard bridge history](https://chicagoloopbridges.com/bridges12/SB12/JACK12-5.html)**: viewed the elevation derived from engineering drawings and the actual deck photograph, including weathered stone tender houses, dark hipped roofs, open railings and unobstructed above-deck views. The author documents the below-deck structural concept. Adams and Jackson are represented by actual map alignments, open parapets, deck trusses, leaf joints and paired tender houses; the bridge mechanisms remain static.
- **[Chicago Loop Bridges: night photographs](https://chicagoloopbridges.com/galleries12/night/night.html)**: viewed the Adams Street night image, where warm glazed lobbies and tender-house windows provide localized light against darker upper façades. This informed restrained, varied city window illumination, bridge lamps and reflection on the water.

Additional primary architectural information comes from [Goettsch Partners' Union Station restoration](https://www.gpchicago.com/architecture/chicago-union-station/) and [the station's own history](https://chicagounionstation.com/about/past). The model includes the east-side colonnade and barrel skylight as recognizable authored exterior details on the actual headhouse outline.

## Detail and night behavior

Nearby buildings receive separate window panes, facade piers, mullions, sills, cornices, entrance canopies, roof machinery and fan grilles. The smallest window-frame relief is concentrated at nearby lower floors; upper and distant windows retain individual geometric panes and major structural divisions. Mapped green areas and nearby streets receive organic smooth foliage, tree pits, curb edges, road markings, lamps, slatted benches, bins, and a few static cars. Planting, furniture, exact façades and storefront details are illustrative rather than surveyed.

The night window palette assigns roughly 27% occupancy in deterministic pairs of adjacent panes per story. Lit rooms have four calibrated brightness levels and warm/cool variation; unlit panes remain reflective. Each pane has a stable material, avoiding a moving world-space brightness boundary across the glass. 311 South Wacker's crown uses moderate night-only emission, so the cylinders remain distinguishable rather than a flat white glare. Luminaires add explicit light sources to illuminate nearby geometry and water.

The river has the actual mapped South Branch bank shape, including its bend past the tower. Four river relation polygons are clipped to the local region; a trapezoidal ground decomposition leaves their water surface open. Retaining walls, coping and near-bank rails follow those banks. Nearby bridge spans use the mapped center lines. The river material uses the same filtered multiscale normals and ray-traced dielectric reflection as the Seine. It is a static rippled surface, with no fluid simulation or caustics. The [river-tour operator confirms routes south past Willis Tower](https://shorelinesightseeing.com/faqs/). The compact 34 m tour boat is original geometry: hull bands, individual cabin windows, upper seating, rails, fenders, navigation lamps, mast, radar and deck lighting. It is not an exact replica of a particular operator's vessel.

Lake Michigan is a distant horizon plane with an approximate shoreline east of the close model. Upper street level is flattened; underground Wacker Drive, rail infrastructure, bridge interiors, accurate terrain grades, every shoreline detail, and exact building interiors remain outside this context reconstruction.

## Validation

`python3 scripts/validate-chicago-context.py` verifies unique polygon IDs, finite coordinates, positive triangle coverage equal to each footprint's area, plausible positive heights, the Willis-site exclusion, required bridge/river/neighbor IDs, river-versus-land area coverage, and byte-for-byte deterministic regeneration. The derived database SHA256 is `2b7b9ef2dd40798bc58994e43dc7fb71fac2cdda56e9cf8b34ee8f4bfd58a904`.

A native standalone geometry check validates that every vertex and normal is finite, triangle/material arrays agree, and every material ID is valid. The full application additionally validates both locations' routes, day/night views, resource loading and Metal execution. River camera candidates were rendered and inspected: the actual nearby office blocks obstruct direct low-altitude views toward Willis, so the river chapter looks along the water, boat and bridges rather than through those real buildings.
