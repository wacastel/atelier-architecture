# Navy Pier architectural reconstruction

This location extends the existing Chicago world. It adds an original procedural model of Navy Pier and its north marina, using a dated OpenStreetMap extract, the owner's plans, and inspected day, dusk, night and aerial photographs. The model is an architectural interpretation for exterior exploration, not an as-built survey.

## Coordinate contract

`NavyPierLayout` owns the local frame. Its origin is the mapped Centennial Wheel center at Willis-origin `(2357.4, 0, -1427.7)` metres. Local X points along the pier toward the lake, local Z toward the south dock. The east unit vector is normalized `(1, 0, -0.0222)`, preserving the pier's approximately 1.27° map skew. `point` and `local` are the only conversion functions used by the new model.

The pier deck is at Y = 0.24 m, the elevated Pier Park at 6.4 m, and the shared lake remains at the existing approximately −5.5 m datum. The main authored extent is approximately local X −188…737 m and Z −67…67 m. Boats and the north marina extend beyond it. Dock grade and intermediate floor heights are visual estimates.

Important mapped anchors, expressed in the local frame:

| Feature | X | Z | Basis |
| --- | ---: | ---: | --- |
| Family Pavilion | −150 | −1.2 | OSM 752899916 |
| Crystal Gardens | −86.5 | −1.8 | OSM 752899914 |
| Centennial Wheel | 0 | 0 | OSM 686996484 |
| The Yard / former Skyline Stage | 62.1 | −1.4 | OSM 205025619 / 741288462 |
| Chicago Shakespeare Theater | 142.4 | 45.8 | OSM 753474606 |
| Festival Hall | 367.6 | 3.7 | OSM 752904676 |
| Lakeview Terrace | 598.9 | −1.9 | OSM 752904679 |
| Aon Grand Ballroom | 669.8 | −1.2 | OSM 151989533 |
| North marina boathouse | 98.7 | −74.2 | OSM 1417040524 |

Sable's three modeled wings occupy the south side of the long hall, following the owner's site map and dusk photograph; individual room divisions and wing dimensions are estimated. The generic mapped shells and legacy paths on the authored pier are excluded by `NavyPierContext`, preventing a second set of buildings or roads from covering the new geometry. See [map and context sources](NAVY-PIER-MAP.md) for the dated extract and approach reconstruction.

## What is modeled

- **Centennial Wheel:** 42 enclosed blue cabins, two three-dimensional rim frames, 21 triangulated spokes, six inclined structural legs, hub disks with readable lettering, base plates and bolts, a service ladder, railings and a raised boarding platform. The owner's published 104-foot hub height is retained above Pier Park. The rim radius, including its tube thickness, is calibrated to the mapped 59.7408 m overall wheel height. The steel lattice remains white by day; blue and cyan strip materials give the night view its recognizable color.
- **Landward entrance:** a red brick Family Pavilion with separate window bays, pale bands and two lantern towers; twin curved glass roofs and mullion grids identify the Crystal Gardens volume.
- **Pier Park:** individual bowed Wave Wall stair treads, stair lighting and handrails, a carousel with poles and small sculpted horses, a Wave Swinger, teacups, a light tower and planted beds. The landscaping leaves sight lines to the wheel open.
- **Theaters:** The Yard's tent-like roof, glazed lobby and the taller Chicago Shakespeare facade with a round glazed stair tower. This is an exterior model; it does not reconstruct auditoria or stage machinery.
- **Long halls and Sable:** brick structural bays, windows, cornices, repeated barrel roofs, terminal projections, five lake-facing window registers with modeled angled reveals, a glass ground floor and columns. Hotel interiors and individual guest rooms are not modeled.
- **East End:** a curved brick ballroom drum, copper roof, pale cornice bands, twin square towers with lanterns, an interpreted USS Chicago anchor, flagpoles, a roof terrace, picnic furniture and a beer-garden entrance.
- **Waterfront:** detailed multideck excursion boats, a four-masted schooner with furled canvas, gangways, mooring lines, quayside fenders, railings, bollards, benches, restaurant glazing, tables, lamps and trees. Vessel geometry is original; no claim is made that a specific registered vessel is docked at that berth today.
- **North marina:** the current OSM centerlines are baked into `NavyPierLayout.marinaCenterlines`, including the angled fingers on ways 1417040532–1417040550. Small yachts align to their fingers. Dock widths, freeboard, shore ramps, furniture and berth occupancy are interpreted.

## Inspected image references

These images were opened and their pixels inspected while modeling; photographs were used as visual references, not copied onto the mesh or redistributed as app assets.

1. [Owner's wheel daylight photograph](https://navypier.org/wp-content/uploads/2022/11/navy-pier-centennial-wheel-photo-1-scaled.jpg): white radial trusses, blue enclosed cabins, central disk, broad tubular legs and glass barriers. The owner describes [21 spokes, 42 gondolas, six legs and the hub height](https://navypier.org/support-the-pier/articles/behind-the-scenes-at-the-centennial-wheel/). The [Chicago Architecture Center](https://www.architecture.org/online-resources/stories-of-chicago/chicagos-ferris-wheel-story) corroborates the overall 196-foot height.
2. [Owner's night photograph](https://navypier.org/wp-content/uploads/2022/12/navy-pier-centennial-wheel-at-night.jpg): blue wheel and spoke accents, warmer lower promenade glazing, illuminated stair edges and boats against the dark water. This guided the blue/warm balance; it is not a measured lighting plan.
3. [Owner's Sable dusk photograph](https://navypier.org/wp-content/uploads/2025/09/sable-hotel-navy-pier-chicago-scaled.jpg): dark cladding, angled window bays, projecting occupied floors, slim columns, warm scattered room light, docked white excursion boats and paved waterfront.
4. [Owner's 2023 request-for-concepts PDF, page 3](https://navypier.org/wp-content/uploads/2023/04/RFC_NavyPier_2023.pdf): an east-to-west aerial showing the ballroom's curved red brick body, green roof and twin towers, the long pier halls and waterfront trees. The same page includes the hotel's dusk exterior. This predates the new north marina; its photograph was not used to invent the current dock layout.
5. [Owner's level-two west plan](https://navypier.org/wp-content/uploads/2023/10/NavyPier_Level2_West-10.4.2023.pdf): the relative arrangement of the entrance, Crystal Gardens / Family Pavilion area, wheel, small rides, The Yard and theater.
6. [Owner's level-one east plan](https://navypier.org/wp-content/uploads/2023/10/NavyPier_Level1_East-10.4.2023.pdf): hotel/hall/ballroom arrangement, east apron, beer garden and excursion berths, including the four-masted Windy. Small inset photographs reinforce the anchor and public entrances.

[Field Operations' project account](https://www.fieldoperations.net/project/navy-pier) informed the emphasis on the South Dock's planted public promenade and Wave Wall. Its image CDN returned HTTP 403 during this session, so those particular images were not counted as inspected references.

## Lighting, rendering and performance

The model reuses the engine's triangle, material and local-light systems. No additional renderer or full-city acceleration structure is created by changing to this location. Decorative strips and boat lights use the existing night-gated emissive pattern, hotel windows use the existing window-light pattern, and every additional shadow light has a finite 13–65 m radius of influence. No thousands-of-lights brute-force pass or unbounded sun proxy is added.

Geometry is authored at useful inspection scale: separate structural bars, glazing frames, window reveals, railings and hulls. Tiny repeated joints and pavement seams use the existing materials or small bounded strips. The wheel, moored fleet and flags are static; the eight camera studies provide idle and walkthrough animation. There is no ride simulation, passenger animation or museum/attraction interior in this first pass.

The final model adds **525,840 triangles**, **174 bounded local night lights**, and **24 materials** beyond the base palette. The standalone CPU build completed in about 0.04 seconds on this machine (geometry construction only, excluding compilation and acceleration structures).

The CPU geometry check is `scripts/validate-navy-pier-geometry.sh`; all **17 checks passed**. The measured top is Y = 66.132 m, the maximum normal-length error is 1.79 × 10⁻⁷, and no nonfinite vertices or collapsed triangles were found. It checks the additional triangle budget, material indices, finite/unit normals, collapsed triangles after world placement, world/local transforms, wheel arrangement and top height, bounded night-light ranges, marina mapping, and preservation of the shared random sequence. Visual validation and complete-world frame performance belong to the parent release validation; a CPU geometry pass alone does not establish frame rate.

## Future refinements

Survey-quality roof/interior dimensions, verified hotel room counts, the complete arcade/retail layout, sculptural public art, exact vessel hulls, dynamic wheel rotation, and seasonal event lighting would require additional source material and implementation. Keep those separate from the present measured map anchors. If routes are brought down to walking height, validate each support surface, gate, ramp and stair against the collision world instead of assuming an exterior cinematic route is a walkable path.
