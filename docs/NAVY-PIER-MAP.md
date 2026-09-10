# Navy Pier map and context

Navy Pier remains in the existing Chicago world. The map projection uses origin **41.878876° N, −87.635918° E**, metres east in `x`, metres south in `z`; the shared Lake Michigan surface stays at **y = −5.7 m**. Existing coast, land and traffic resources are preserved.

The new approach adds **Polk Bros Park, Jane Addams Memorial Park, Ohio Street Beach and Milton Lee Olive Park**, including their mapped lawns, gardens, pedestrian connections, six fountain footprints and 479 individual mapped trees. Their walks and road surfaces are joined offline before triangulation. The old approach paths are clipped at the replacement boundary and their outside fragments retained; the authored pier owns its promenades. Nearby Streeterville buildings use the existing footprints with more facade detail near the gateway. Six previously absent small ancillary buildings are added. Estimated heights and facade/fixture details are interpretations.

## Sources and reproducibility

- **OpenStreetMap**, retrieved September 9, 2026 in Chicago; server snapshot **2026-09-10T00:34:18Z**. Saved query: [chicago-navy-pier-osm-2026-09-09.overpass](../scripts/data/chicago-navy-pier-osm-2026-09-09.overpass), raw result: [JSON](../scripts/data/chicago-navy-pier-osm-2026-09-09.json), request/hash record: [provenance](../scripts/data/chicago-navy-pier-osm-2026-09-09.provenance.json). The extract contains **3,803 elements** across latitude 41.8878–41.8982, longitude −87.6195–−87.5978. Raw SHA-256: `3c1e953bc9f14492406a39b16c4a7aefeddca3a3ca7ea2e4d2d91b5973c32d40`.
- **USGS EROS, 2023 aerial photograph**, [page](https://eros.usgs.gov/earthshots/chicago-aerial-photography), [image](https://eros.usgs.gov/sites/eros.usgs.gov/files/2025-08/1-NavyPier-2023.png). Actual pixels inspected in the browser: the east–west pier, west gateway lawns, lakefront trail, northern water gap, Jardine plant and Olive Park guided layout checks. It predates the new marina, whose current layout comes from the newer map extract and separate pier reference research. No aerial image is bundled as a texture.
- **Navy Pier official accessible maps**, [west level two](https://navypier.org/wp-content/uploads/2023/10/NavyPier_Level2_West-10.4.2023.pdf) and [east level one](https://navypier.org/wp-content/uploads/2023/10/NavyPier_Level1_East-10.4.2023.pdf), support venue/dock relationships.
- **Chicago Park District**, [Jane Addams Memorial Park](https://www.chicagoparkdistrict.com/parks-facilities/addams-jane-memorial-park), identifies the park beside Ohio Street Beach and Navy Pier.

Derived map data is **© OpenStreetMap contributors**, under [ODbL 1.0](https://www.openstreetmap.org/copyright). Authored architecture and appearance are distinguished from mapped footprints. Existing neighboring resources are input dependencies, recorded by SHA-256 in the new derivative; the preparer never rewrites them.

```sh
python -m venv /tmp/atelier-map
/tmp/atelier-map/bin/pip install -r scripts/requirements-map.txt
/tmp/atelier-map/bin/python scripts/prepare-navy-pier-context.py
/tmp/atelier-map/bin/python scripts/validate-navy-pier-context.py
```

The offline preparer builds `Sources/ArchitectureEngine/Resources/NavyPier/NavyPierContext.json`. It includes 307 mapped building footprints for the navigation map, 187 clipped approach path centerlines, 238 retained legacy-path records, and 6,298 landscape/transport triangles. The full map extract does **not** mean 307 new building meshes: six small new structures are rendered, existing city buildings are reused, and the detailed pier replaces its generic parent/part shells.

## Layout anchors

Coordinates below are metres in the shared world. Footprints and centers are derived from the OSM elements, not picked from the screen.

| Feature | OSM way | x | z |
|---|---:|---:|---:|
| Centennial Wheel | 686996484 | 2357.4 | −1427.7 |
| Family Pavilion | 752899916 | 2208 | −1431 |
| Crystal Gardens footprint | 752899914 | 2268 | −1427 |
| Chicago Shakespeare Theater | 753474606 | 2507 | −1381 |
| Festival Hall | 752904676 | 2739.9 | −1422 |
| Aon Grand Ballroom | 151989533 | 3027 | −1444 |
| Polk Bros fountain | 363236831 | 2099.68 | −1423.38 |
| Jane Addams Memorial Park | 509654675 | 1937.5 | −1528 |
| Ohio Street Beach | 211039469 | 1910.8 | −1608 |

Pier way **24800238** bounds are x **2168.88–3097.79**, z **−1510.47–−1351.61**. Its long axis heads east and slightly north, approximately 1.25°. The detailed geometry owns x 2165–3105, z −1620–−1340, including marina water space. This is a replacement/suppression bound, **not** a solid land rectangle. Its deck is shaped separately; the surrounding water stays visible.

## Validation and limits

[Saved CPU validation](validation/v2.5/navy-pier-map.json) checks positive valid mesh triangles, disjoint transport/landscape surfaces, map/landmark masks, map source hashes, exact offline regeneration, and sampled pier land/water support. Source park overlap and duplicate Lake Point Tower part geometry were found and removed during these checks. Centimetre edge tolerances and 3 cm separation prevent sliver overlaps in joined paving and planting meshes.

The fountain footprints are mapped; nozzle placement and jet heights are an authored gentle-water interpretation. Existing mapped buildings retain their source heights; missing heights use estimates. This addition improves local park and waterfront context without rebuilding Chicago or inventing a new ground plane across Lake Michigan. GPU performance and final camera/lighting review belong to the release validation, separate from this CPU map check.

### Welcome Pavilion correction from rendered review

The first park render exposed a legacy height-estimation error: OSM way **751729625**, Peoples Energy Welcome Pavilion, had become a **45.4 m** generic block despite having neither a height nor a levels tag. Navy Pier's [official pavilion page](https://navypier.org/pier-locations/peoples-energy-welcome-pavilion/) describes a 4,000-square-foot visitor facility, and its [official exterior photograph](https://navypier.org/wp-content/uploads/2022/11/peoples-energy-welcome-pavilion-exterior.jpg), inspected at full resolution, shows a single-storey glass wall under a broad thin cantilever. Its documented green roof is described in the [Navy Pier sustainability page](https://navypier.org/support-the-pier/making-a-difference/sustainability/).

The old tall shell is now suppressed. The mapped roof footprint carries an authored low pavilion with recessed glazing, slim mullions, interior seating/fixtures and a sloping planted roof. The new record's 5.4 m height is explicitly a conservative **photo estimate**, not a surveyed dimension. This restores the actual low skyline of Polk Bros Park and clears the former camera obstruction without deleting the real welcome facility.

The same rendered review identified a second excessive legacy estimate on the North Lawn: Butterfly House way **1308482808** had been extruded to **37.8 m**. Its actual builder, [Foundation Mechanics](https://foundationmech.com/project/the-butterfly-house-at-navy-pier/), documents a **72 × 36 × 18 ft** steel-framed domed enclosure. The replacement uses a 21.9456 × 10.9728 m curved habitat with a 5.4864 m roof rise, arched ribs, mesh/cloth appearance and a small entry vestibule within the mapped apron. The corrected map record carries the documented 18 ft height. Unverified neighboring structures retain their existing estimates.
