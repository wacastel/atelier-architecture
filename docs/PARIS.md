# Eiffel Tower surroundings

The nearby city now uses a real OpenStreetMap geometry snapshot rather than the former regular grid of separated boxes. The distributed source and derived databases are available under ODbL 1.0, © OpenStreetMap contributors. [Copyright and attribution](https://www.openstreetmap.org/copyright) · [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/).

## Map provenance and reproducibility

Two Overpass API responses are preserved unchanged in `scripts/data/`:

- `paris-osm-2026-09-07.json`: OSM database timestamp **2026-09-07T21:11:18Z**. Building ways, parks, grass polygons and water areas within 1,100 m; roads and paths within 650 m of 48.8582602° N, 2.2944991° E.
- `paris-osm-relations-2026-09-07.json`: timestamp **2026-09-07T21:23:34Z**. Building relations within 1,100 m. Includes the two curved Palais de Chaillot wings that the way-only query missed.

The exact queries sent to `https://overpass-api.de/api/interpreter` were:

```overpass
[out:json][timeout:50];
(way[building](around:1100,48.8582602,2.2944991);
 way[leisure=park](around:1100,48.8582602,2.2944991);
 way[landuse=grass](around:1100,48.8582602,2.2944991);
 way[natural=water](around:1100,48.8582602,2.2944991);
 way[highway](around:650,48.8582602,2.2944991););
out geom;
```

```overpass
[out:json][timeout:50];
relation[building](around:1100,48.8582602,2.2944991);
out geom;
```

Run `python3 scripts/prepare-paris-context.py` to regenerate `Sources/ArchitectureEngine/Resources/Paris/ParisContext.json` from those included snapshots. The deterministic, dependency-free preprocessing projects longitude/latitude into metres, simplifies almost-collinear points to 20 cm tolerance, triangulates simple polygons, keeps way IDs and relation provenance, and stores the tagged height source for each building. The result contains **2,760 building footprints, 234 park/grass/water areas and 1,179 road/path ways**. It is copied into the app bundle; rendering does not need internet access.

The frame has its origin at the Eiffel Tower; +x points northeast at bearing 47°, +z southeast at 137°, and +y upwards. Conversion uses a local equirectangular projection with 111,320 m per degree and longitude scaled by cosine of the origin latitude. This is appropriate for the kilometre-scale visual context; it is not a geodetic surveying system.

The original 330 m Eiffel building polygon is excluded because the detailed tower replaces it. Tiny/roof-only/incomplete polygons are omitted. The authored Seine and quay corridor replaces map areas in that strip. Hole-free, closed relation members are supported; other courtyard relations remain in the source snapshot for future polygon-with-holes support. Buildings beyond the mapped radius are inexpensive procedural background context.

## Photographic references actually inspected

The parent task visually inspected the following web photographs while implementation proceeded. No remote photograph was downloaded or used as an asset:

- [Official Eiffel Tower gardens](https://www.toureiffel.paris/en/explore/gardens): irregular natural stone pond edges, leafy groves, perennial borders, paths and the historic brick chimney. The guide describes the two garden ponds and the garden's nighttime illumination.
- [Champ-de-Mars from the second level, Dennis G. Jarvis, 22 June 2014](https://commons.wikimedia.org/wiki/File:Champ-de-Mars_from_the_second_level_of_the_Eiffel_Tower,_Paris_22_June_2014.jpg): long central lawns, pale gravel paths, dense side groves and continuous pale stone Paris street frontages with dark mansard roofs.

The grass and water outlines follow the map. Trees and planting placement use those mapped areas, with an authored planting pattern. Close trees have smoothly shaded, irregular overlapping foliage clusters and individual leaf silhouettes. Garden details include stone pond margins, flower beds, hedges, clipped topiary, benches, bins, bollards and physical lamps. The chimney is an illustrative reconstruction of the official garden feature.

Nearby building walls follow the actual irregular footprints. OSM `height` takes priority, then `building:levels` converted using an assumed 3.15 m storey. Missing heights are explicitly marked `estimated`. Facade materials, exact windows, balconies, cornices, dormers and chimneys are authored interpretations. They are geometric surfaces, so they participate in occlusion, ray-traced reflection and shadowing. Near facades receive recessed glazing, frames and mullions, stone sills, projecting balconies and railings. Far windows use glass quads to keep costs proportional to visible detail. Palais de Chaillot uses its mapped wings and tagged 30 m height, a flat roof and classical vertical pilasters rather than apartment mansards.

## Day/night behavior and limits

Garden fixtures add real local lights to the night integrator. Nearby windows use the existing varied room lighting material, so the city is not uniformly emissive. Foliage, masonry, glass and ponds participate in the same path tracing and reflections as the tower; the lighting is shared between day and night.

This is a map-informed, authored architectural scene. It does not claim street-level photogrammetry, surveyed facade dimensions, exact vegetation, building interiors, dated storefront inventories, or a terrain survey. The Trocadéro terrain remains flattened; the river is a straight near-Pont-d'Iéna reach rather than a map-accurate model of every distant Seine bend. Some OSM courtyard relations are not yet rendered, and background buildings remain interpretive.

## Validation

`python3 scripts/validate-paris-context.py` passed: all 2,760 building IDs are unique; all coordinates are finite; positive triangles cover each source polygon without missing area; both actual garden pond IDs and the Palais de Chaillot relation are present; regeneration is byte-for-byte deterministic. Height provenance is 37 explicit height tags, 1,855 level tags and 868 marked estimates. A standalone native geometry check produced 7,967,408 context triangles, 26 local garden lights and no non-finite vertex coordinates in 0.69 seconds on the target Mac Studio.

The day overview, day Anatomy of Iron view and night overview were visually inspected after integration. Mapped continuous street frontages, mansards, ponds, organic planting and path divisions were visible in daylight. Night checks showed varied lit windows, garden light pools and the golden tower reflecting toward the quay, with the city remaining darker than the monument. The parent task additionally validates the complete nine-view galleries and playback navigation.
