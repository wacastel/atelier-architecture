# Millennium Park in the Chicago world

Millennium Park uses the same metre-scale coordinates and ray-traced city as
Willis Tower. No miniature replica or separate backdrop is placed at the end of
the connecting flight. Origin is latitude 41.878876, longitude −87.635918;
X points east, Y up, Z south. Street grade is approximately Y=0. The authored
Grainger Plaza surface is Y=3; underground railway/garage spaces are not modeled.

## Map and aerial references

The fresh [OpenStreetMap](https://www.openstreetmap.org/#map=18/41.8827/-87.6225)
extract covers 41.8788…41.8846 N, −87.6245…−87.6195 E and contains 9,239 elements.
Snapshot time is **2026-09-08T00:55:31Z**. The offline park derivative retains
91 mapped planting/paving/water areas, 228 pedestrian ways, 626 individual tree
positions and twelve landmark outlines/centerlines. Source and derivative are
ODbL, © OpenStreetMap contributors. The broader existing Chicago extract supplies
nearby streets and buildings; its façade detail now responds to the park as well
as Willis Tower.

`scripts/prepare-millennium-context.py` performs the same local projection as
ChicagoContext, removes duplicate/collinear polygon vertices and triangulates
the remaining outlines deterministically. `scripts/validate-millennium-context.py`
checks coverage, finite coordinates, identities and byte-identical regeneration.
The original extract is in `scripts/data/millennium-osm-2026-09-08.json`.

The developer actually viewed this [Esri World Imagery aerial export](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=-87.625,41.879,-87.619,41.885&bboxSR=4326&imageSR=3857&size=1000,1200&format=png&f=html)
in the browser. It established the central plaza, north/south tree allees,
Pavilion/lawn arrangement, Lurie Garden, winding BP crossing and Modern Wing
relationship. Its imagery acquisition date is unspecified; authoritative current
positions come from OSM rather than assuming that the aerial mosaic is current.
No satellite tiles or reference photographs are redistributed as assets.

| Landmark | World X, Y, Z (metres) | Geometry source |
|---|---|---|
| Cloud Gate | 1042.46, 3, −424.15 | OSM way 137060274; published size and photos |
| Pritzker stage | 1162.7, 0.15, −508 | OSM way 126978545 |
| Crown Fountain north tower | 1008.30, 0.15, −316.18 | OSM way 126945440 |
| Crown Fountain south tower | 1009.75, 0.15, −264.88 | OSM way 126945441 |
| Lurie Garden | approximately 1175, 0.15, −283 | OSM way 126945427 and detailed beds |
| Millennium Monument | approximately 1002.6, 0.14, −566.9 | OSM way 231253695 |
| BP Bridge | mapped centerline X 1210…1355 | OSM way 25026666, boundary 524270341 |
| Nichols Bridgeway | X 1103.71…1114.46, Z −339.66…−165.94 | OSM way 90707301; museum model owns mesh |

The generic Chicago building pass excludes the park landmark IDs above and the
museum campus footprint, allowing the detailed models to occupy their actual
positions without overlapping generic boxes. Park surface paths/trees replace
the older generic park pass.

## Reference-based landmark geometry

**Cloud Gate.** Anish Kapoor's [own project page](https://anishkapoor.com/110/cloud-gate-2)
gives a 10 × 20 × 12.8 m stainless-steel envelope. The authored shell uses the
long axis north/south, a smooth closed surface, two low support regions, an
east/west arch and an inward-curving underside. It contains 171,264 triangles
with per-vertex derivative normals evaluated before applying the world origin,
avoiding precision loss that can otherwise roughen mirror reflections. Its
measured envelope is 12.8 m east/west,
20 m north/south and 9.985 m above a 15 mm surface offset. The slight ground
offset prevents coincident plaza/steel surfaces. This is an original geometric
interpretation, not a photogrammetric scan of the sculpture.

The developer actually inspected the Foundation's [day/underside photograph](https://images.squarespace-cdn.com/content/v1/679a73f84eac3060adaa6aca/98bf3146-7b31-40ef-af28-c1ae6455e1f5/C2024_06_01_078MillenniumPark.jpg)
and [Choose Chicago's night photograph](https://cdn.choosechicago.com/uploads/2019/07/bean-night.jpg).
These informed the convex skyline band, upward-curling mirrored underside,
dark blue upper shell at night and warm plaza/city reflections. Mirror material
uses metallic=1 and authored roughness 0.022; reflected buildings, trees, lights
and paving are actual scene geometry. There is no photographic reflection map.
The central walking line around Z=−424.15 is clear of fixtures and trees.
Eight broad warm floodlights on four modeled perimeter poles illuminate the
plaza, allowing its material and underside reflections to remain readable at
night. Fixture positions and light output are authored, not surveyed photometry.

**Jay Pritzker Pavilion.** The [Pritzker Prize's project description](https://www.pritzkerprize.com/ceremony-thom-mayne)
documents the 120-foot sculptural canopy, 4,000 fixed seats and overhead acoustic
trellis. The developer inspected the [Foundation's stage/trellis photo](https://images.squarespace-cdn.com/content/v1/679a73f84eac3060adaa6aca/8e9c3b85-2e47-45e9-b745-30d7c41b31dc/pritkerpavilionPP.jpg).
The reconstruction uses multiple smoothly curved steel ribbons with panel joints,
crossing tubular trellis families, suspended speaker boxes, timber stage and
3,840 individual seats with aisles. The Great Lawn follows its mapped outline.
The ribbon surfaces and seat arrangement are reference interpretations rather
than licensed Gehry fabrication/CAD data.

**Crown Fountain.** The [Foundation](https://www.millenniumparkfoundation.org/art-architecture)
credits Jaume Plensa and Krueck + Sexton. Its [official photograph](https://images.squarespace-cdn.com/content/v1/679a73f84eac3060adaa6aca/ee624696-92db-4bbb-8dee-a89f4e21a08f/crown.jfif)
was visually reviewed for opposing glass-block towers, cascades, paving and the
shallow reflecting pool. Tower height is the mapped 15.24 m; the pool uses the
13.74 × 68.11 m bounding envelope of relation 3154126's outer way 126945426.
Thousands of individual glass blocks, raised joints and water streams are modeled.
The LED panels show an original abstract water/sky color field. They do **not**
reproduce the real display's filmed Chicago resident portraits. Water geometry
is static; its shading uses the renderer's ripple model.

**Lurie Garden.** The developer inspected the [Foundation's garden photo](https://images.squarespace-cdn.com/content/v1/679a73f84eac3060adaa6aca/f071a91d-99ae-443a-8485-e55e5a1639b0/MP-20-Lurie-Garden-1.jpg).
The [garden's own description](https://www.luriegarden.org/seamrenovation/)
explains the Light Plate, Dark Plate, Shoulder Hedge and stone/water/wood Seam.
Mapped beds and hedges drive geometry; flowers, canopy shapes, hedge trellises
and furniture are authored at those positions. The scene depicts a completed
summer garden, not temporary renovation closures or exact individual plant species.

**Millennium Monument.** The [Chicago Public Library's project archive](https://www.chipublib.org/fa-millennium-park-inc/)
documents 24 paired fluted columns, an 80-foot diameter and nearly 40-foot
height. The reconstruction has paired limestone shafts, capitals, raised
entablature and a shallow circular fountain at the mapped semicircle.

**BP Bridge.** Its serpentine route comes from the actual 64-point OSM centerline.
The model adds a timber deck, plank joints, stainless side panels and railings,
with a continuous interpreted grade rising over Columbus Drive. Nearby generic
roads remain in the shared Chicago world. Nichols Bridgeway is constructed
with the Art Institute model to avoid a duplicate bridge.

**Exelon Pavilions.** The generic height estimates for two north pavilions were
too tall and gave the park fictitious office blocks. The authored replacements
follow [project supplier Tnemec's documented three-story northwest and two-story
northeast pavilions](https://tnemec.com/projects/exelon-pavilions-millenium-park/),
with dark photovoltaic façades and modeled frames. Their heights are interpreted
as 12 and 8.2 m; the south pavilions are 4 m. Four additional generic building
ways inside the Pritzker ribbons are suppressed because they represent portions
of the sculptural pavilion rather than independent office buildings.

## Verification and practical limits

The standalone park geometry check verifies finite positions and normals,
material references, nondegenerate Cloud Gate faces, unit mirror normals,
positive enclosed volume, published envelope and usable headroom along the
central arch route. Integrated day/night galleries and complete tour collision
checks are performed by the main build workflow.

Run `python3 scripts/validate-millennium-context.py` and
`bash scripts/validate-millennium-geometry.sh` from the project root. The park
adds 1,678,830 triangles and 84 lights; Cloud Gate accounts for 171,264 triangles.

All twelve final park stills (stops 0–5, day and night) were visually inspected
at 1600 × 1000, with 128 daylight and 256 nighttime samples per pixel. The
corrected Pavilion exposes broad ribbon faces around its dark stage; Cloud
Gate's skyline and underside reflections remain smooth. Exact image hashes,
findings and limits are recorded in `output/v5-review/park-visual-validation.json`.
The unfiltered stills retain sampling grain. Solid tree crowns, generic city
façades and the fountain's abstract display/static stream remain visible
simplifications; this review does not certify motion noise performance.

This model prioritizes actual locations, recognizable forms, close geometry,
reflections and continuous travel. It does not claim survey accuracy, reproduce
underground circulation, or provide an exhaustive digital twin of every park
installation. Lighting placement and photometry are authored from references.
Some sampling grain can remain in low-sample moving reflections; renderer
validation documents the measured quality/performance trade-offs separately.
