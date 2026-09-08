# Chicago lakefront and Grant Park

The lakefront extension occupies the same Chicago coordinate world as Willis Tower, Millennium Park and the Art Institute. No landmark is moved to make a composition. The origin remains 41.878876° N, −87.635918° E, with metres east as +X, street height as Y=0, and metres south as +Z. The river and lake share the existing scene's water elevation, Y=−5.7 m.

## Mapped extent and provenance

The principal OpenStreetMap extract covers 41.865…41.913° N, −87.640…−87.607° E. It contains 36,890 tagged elements and was retrieved from Overpass with a database timestamp of **2026-09-08T06:20:24Z**. Through carriageways extend beyond that box, to approximately 41.8445…41.9324° N, so vehicles enter and leave beyond the curated cameras. The local Lake Michigan outer boundary and separate harbor/river relations cover a larger clipping region. Their union includes water west of the harbor breakwaters; omitting these harbor polygons would incorrectly fill the marinas with land.

The committed derivative contains 2,998 additional building footprints/parts, 2,307 landscape areas, 9,864 street/path lines, 8,807 tree positions, 254 pier lines, two continuous Lake Shore Drive carriageways and six traffic lane lines. These are **map feature counts**, not a claim that every feature has equally detailed geometry. Original Loop context is retained. Authored Hancock/Water Tower Place/Water Tower/Pumping Station, Wrigley/Tribune, Willis, Millennium and museum geometry replaces the corresponding generic map extrusions.

The bounded land surface is the geometric complement of the union of Lake Michigan, its harbors, the Chicago River and the open-air railway corridor. Constrained triangles preserve the holes. The old rectangular lakefront ground and synthetic eastern buildings are removed. Ground and water meet at mapped outlines; mapped piers and breakwaters supply the raised surfaces above the harbor. Landward distant context remains approximate. Terrain is not a surveyed elevation model.

Data is © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright), licensed under [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/). Raw extracts are retained in `scripts/data/chicago-lakefront-*.json`; the distributable derivative is `Resources/Lakefront/LakefrontContext.json`. No satellite pixels or reference photographs are bundled.

## References actually viewed

These references were opened and visually inspected on 8 September 2026, alongside the map geometry. Satellite acquisition dates were not supplied by the export and must not be inferred from the viewing date.

- [Chicago Park District: Buckingham Fountain](https://www.chicagoparkdistrict.com/parks-facilities/clarence-f-buckingham-memorial-fountain), including its [daytime photograph](https://files.chicagoparkdistrict.com/styles/coh_medium_landscape/s3/2025-05/buckingham%20fountain%20750x500.png?h=9e499333&itok=8HJny2B6). This informed the pink Georgia marble, green bronze sea-horse groups, concentric basins, fluted supports, white central bouquet, outward arcs and falling curtains.
- [National Park Service: Grant Park](https://www.nps.gov/places/grant-park-chicago.htm), including the [fountain photograph](https://www.nps.gov/common/uploads/cropped_image/primary/841EAF7E-E304-0C6F-7A77628103F5B99C.jpg?mode=crop&quality=90&width=1600), also visually inspected during modeling.
- [Chicago Harbors: DuSable Harbor](https://www.chicagoharbors.info/harbors/dusable/) and its [aerial photograph](https://www.chicagoharbors.info/wp-content/uploads/2013/05/DSC_0120-500x320.jpg). The reference shows the marina's east-west docks, perpendicular fingers and western skyline. The operator describes 420 slips; the model renders a representative occupied subset.
- [Chicago Harbors: Monroe Harbor](https://www.chicagoharbors.info/harbors/monroe/) and its [aerial photograph](https://www.chicagoharbors.info/wp-content/uploads/2013/05/mon-5-500x320.jpg). Monroe's 392 mooring cans serve boats in open water. The model uses individual moorings, not an invented finger-pier marina.
- [Esri World Imagery: lakefront/harbor aerial](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=-87.625,41.869,-87.606,41.893&bboxSR=4326&imageSR=3857&size=1000,1400&format=png&f=html), inspected both north and south by scrolling the exported image. It confirms the current shoreline, DuSable piers, Monroe moorings, Lake Shore Drive curvature and the four formal garden groups around Buckingham Fountain.
- [Esri World Imagery: Grant Park aerial](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=-87.626,41.868,-87.614,41.882&bboxSR=4326&imageSR=3857&size=1000,1200&format=png&f=image), also visually inspected during modeling; it shows the broad axes, railway corridor west of Columbus Drive and ballfields south of the fountain.

The reconstruction follows the current mapped surface layout. It does **not** implement proposed Lake Shore Drive tunnels, railway caps or lake expansion from the 2026 Grant Park planning renderings.

## Architectural and landscape interpretation

Buckingham Fountain's center is (1404.55, 0, 342.20). The outer basin derives from OSM way 561821879. The Park District publishes basin diameters of 280, 103, 60 and 24 feet and an upper basin height of 25 feet. These set the modeled tier envelopes. The fluted profiles, sea-horse sculptures and jets are authored geometry guided by the photographs, not photogrammetric replicas. The normal summer cascade and central bouquet are shown; the exceptional 150-foot major display and any current maintenance/operating schedule are not simulated.

A supplemental extract includes 130 landscape relations (95 retained after filtering), including Grant Park relation 19511979. The initial way-only pass omitted that park baseline; the validator now checks grass coverage at four real park positions.

The formal gardens follow mapped outlines and retain pale edging, low planted beds, flowers, path axes and trees. Nearby trees receive branched trunks and several crowns; distant trees use one or three simpler crowns. Nearby facades have individual windows, window surrounds, piers and roof equipment. Far facades group windows into coarser bays and floors. Buildings without height tags use recorded estimates; facade materials and lighting are interpretations.

DuSable's six principal east-west docks lie around Z=−624, −663, −704, −750, −798 and −853 m, between X≈1924 and 2086 m. Boat placements follow the side arms of mapped fingers so their hulls avoid transverse walkways. Modeled sailboats carry furled sails, booms, masts, standing rigging, cabin glazing, railings and fenders; powerboats have glazed cabins and roof decks. Monroe's boats are a representative seasonal arrangement at individual mooring cans. Neither arrangement is a current boat inventory. Boats are static scenery; dynamic motion is reserved for road traffic.

Pavement, dock seams, edge beams, piles, power pedestals, breakwater blocks, road barriers and lighting are explicit geometry. Fountain floods, marina pedestal lights and overhead road luminaires produce actual ray-traced illumination and reflections. Their photometry and warm night palette are illustrative rather than measured lighting surveys.


The open-air railway corridor follows mapped land-use way 95473933, bounded to Z=58…1350 m to preserve the Art Institute and covered station sections. Ground and both old/new park surfaces are cut away across the same 73,257.6 m² footprint. Twenty-nine clipped rail lines retain their mapped alignment and 1.435 m gauge; ties, steel rail heads, catenary poles/wires and retaining walls are physical geometry. Forty-one mapped road/path spans have real deck thickness. Guardrails have gaps at those crossings. The interpreted ballast floor lies at Y=−7.2 m, providing room for rolling-stock and catenary below crossing decks; this depth is not a surveyed elevation. The supplemental railway extract contains 75 ways, including underground portions that are excluded from this visible reconstruction.

## Traffic geometry contract

`LakefrontContext.database.trafficLanes` exposes stable lane IDs, `[X,Y,Z]` points in travel order, `speedMetresPerSecond` and `spawnFadeMetres`. `chicagoLakefront()` copies these into `SceneData.trafficLanes`; the renderer owns vehicles and animation. No traffic mesh is baked into the static lakefront.

The source contains two complete directed chains, totaling 89 OSM ways. Their lengths are 10,325.8 and 10,495.9 m. Six lanes populate three positions per direction at 3.55 m spacing, within the modeled 15.6 m carriageways. This represents a selected through-traffic population, not every lane in the variable 3–6-lane source tags. Traffic uses 40 mph (17.8816 m/s), with 550 m remote endpoint fades. Points are resampled at approximately 5 m, preserving the mapped plan alignment.

The upper-deck elevation around the Chicago River is a smooth interpretation between Grand/Randolph approaches. Both road surfaces and traffic consume the exact same point heights, eliminating visible floating or buried vehicles. Road elevation is not inferred solely from OSM `layer` tags and is not claimed as survey-grade. Current map chains are never joined across missing segments or across arbitrary water.

## Reproduction and validation

The app has no GIS runtime dependency. Offline processing uses Python plus `shapely==2.1.2`, pinned in `scripts/requirements-map.txt`; constrained triangulation follows [Shapely's documented API](https://shapely.readthedocs.io/en/stable/reference/shapely.constrained_delaunay_triangles.html).

```sh
python3 -m venv /tmp/atelier-lakefront-map
/tmp/atelier-lakefront-map/bin/pip install -r scripts/requirements-map.txt
/tmp/atelier-lakefront-map/bin/python scripts/prepare-lakefront-context.py
/tmp/atelier-lakefront-map/bin/python scripts/validate-lakefront-context.py
scripts/validate-lakefront-geometry.sh
```

The map validator checks finite coordinates, unique feature IDs, triangle orientation/coverage, known land and water points, the bounded land/water/railway complement, actual source node connectivity, lane grades/separation/remote endpoints and byte-identical regeneration. The CPU geometry harness builds the real lakefront implementation and checks finite unit normals, valid materials, absence of collapsed faces and traffic assignment, with downward surface samples verifying an open railway trench.

The complete lakefront-only build contains 3,708,200 triangles, 372 lights and 243 representative boats (66 at DuSable and 177 at Monroe). CPU construction and validation take under one second on the host; this is not an interactive GPU performance claim. The integrated production scene passes all 29,753 playback and camera-clearance checks. Separate traffic fixtures verify deterministic placement, GPU refits, pause/rewind and local reflection-history rejection; see the [release validation record](VALIDATION.md). Visual fidelity remains an architectural reconstruction, not an as-built survey or navigational model.
