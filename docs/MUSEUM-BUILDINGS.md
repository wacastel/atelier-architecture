# Field Museum and Shedd Aquarium

`MuseumBuildings.swift` adds both museums to the shared Chicago world. The exterior anchors use the September 8, 2026 OpenStreetMap extract, projected from 41.878876° N, 87.635918° W, with east +X and south +Z. OSM `ele=185/186` values are absolute elevations and are not used as building heights.

## Field Museum

The original east–west block, north and south entrance projections, and east pavilion follow mapped way 24825537. The entrance reconstruction has four fluted Ionic columns between broad rectangular side piers (antae), pediments, cornice courses, dentils, window surrounds, bronze doors, shallow stairs, and simplified caryatid window porches. The four-column arrangement was checked against the museum's frontal photograph; the eight caryatids are documented in its [historical bulletin](https://libsysdigi.library.uiuc.edu/oca/Books2008-03/fieldmuseumofnat/fieldmuseumofnat45chica/fieldmuseumofnat45chica.pdf).

Stanley Field Hall uses the museum's published 300 × 70 ft plan (91.44 × 21.336 m) and 76 ft ceiling height (23.1648 m above the modeled main floor). The walkable hall includes ground-level Ionic columns, upper arcades and balconies, a glazed vault, bronze rails, four suspended garden clouds, and selected side galleries. Interior lamps remain active in both daylight and nighttime modes.

The sauropod skeleton, two elephant forms, suspended pterosaurs, mineral cases and crystals are original procedural interpretations. They suggest the hall's current exhibit character without claiming an anatomically exact Máximo cast, a scan of the Akeley elephants, or the museum's full collection. No museum artwork or photographic textures are embedded.

The main floor is modeled at +4.5 m relative to local grade. The 24 north and south steps rise 0.1875 m each over 0.77 m treads. The authored walkthrough enters the north portico and follows a clear side aisle past the displays. A selected mineral gallery opens from the east side of the hall; other exhibition wings have exterior detail without a complete floor-plan reproduction.

## Shedd Aquarium

The original octagonal building and rotunda align with relation 17430414 and parts 766506552/766511382. The model includes its Doric west portico, pediment, marble wall courses, ornamental cornices, glazed dome and supporting drum. The eastern Oceanarium crescent is reconstructed against the mapped shore-facing outline. The south service building, Phelps Theater and north pavilion retain their mapped footprints as simpler exterior shells.

The July 21, 2026 official visitor plan shows a ground-level main entrance beside the south ticketing pavilion/drop-off, with public circulation to the main level. The authored route uses that south approach, a clear gradual ramp, the rotunda, representative aquarium galleries, and a supported Oceanarium overlook. The ramp is an interpretive connection, not an as-built accessibility plan. The historic west portico remains open as an architectural view.

A close aerial and the structural engineer's completed-project photograph show the south ticket pavilion as one tall glazed storey beneath a thin rounded cream roof. The nearby Museum Campus Cafe is also a low building. Their OSM records contain no height or level counts; their reconstructed heights are visual estimates. This check identified inappropriate generic multi-storey height estimates in the surrounding map context and supplied the reference evidence for their correction.

The rotunda represents the current **Wonder of Water** arrangement: two separate curved habitats with a passage between them, freshwater plants on one side and coral forms on the other, beneath a connected gold scalloped crown. Each modeled habitat is approximately 106 m³ with a 3.3528 m viewing height, matching the scale of the official 28,110-US-gallon capacity and [architect's eleven-foot description](https://www.linkedin.com/posts/valerio-dewalt-train_shedd-aquariums-iconic-rotunda-has-been-activity-7273456214326276096-d5wd). The fish, corals and plants are static authored geometry, not a statement of current animal inventory. Curved transparent panes use the engine's thin-sheet glass transport; water absorption, volumetric scattering, thick-acrylic refraction and aquarium life-support systems are not simulated.

The Oceanarium includes the large curved lake window, exposed ceiling structure, stepped seating, rock shores and a calm reflective pool. Its public overlook is modeled on the main-level height for a continuous accessible demonstration route; the real facility has several vertically separated visitor levels. The model does not reproduce all pools, backstage areas, or scheduled animal presentations.

## Evidence and precision

Reference images and plans were actually inspected in browser screenshots, including the museum-owned Field floor plan and frontal/south facade photographs, Field Hall event photograph, the current Shedd visitor plan, a facade conservator's profile, the Oceanarium designer's interior photograph, and day/night photographs. Aerial imagery establishes context; its acquisition date is unknown and roof displacement makes it unsuitable for survey-grade dimensions. The ground footprints use OSM instead.

The exact Field Hall dimensions are published. Other floor elevations, museum exterior heights, ornamental profiles and exhibit placements are architectural estimates derived from the mapped footprint and photographs. Night lighting follows the observed warm stone facade washes and illuminated interiors; fixture positions and photometry are authored, and event color lighting is not copied as a permanent installation.

Reference evidence with URLs, viewing notes and dates is in [museum-buildings.json](references/museum-buildings.json). Principal sources:

- [Field Museum architecture and Hall dimensions](https://www.fieldmuseum.org/page/about/history/architecture), [Hall ceiling](https://www.fieldmuseum.org/page/stanley-field-hall-balcony), and [maps and guides](https://www.fieldmuseum.org/maps-and-guides).
- [Field floating gardens](https://www.fieldmuseum.org/blog/bringing-great-cretaceous-outdoors-inside) and [museum photo archive](https://www.fieldmuseum.org/blog/photo-archives-general-gallery).
- [Shedd Wonder of Water](https://www.sheddaquarium.org/exhibits/wonder-of-water), [current visitor map](https://www.sheddaquarium.org/map), and [plan a visit](https://www.sheddaquarium.org/plan-a-visit).
- [Shedd entry and ticket pavilion structural presentation](https://seaoi.org/event-6235358), including the completed pavilion photograph credited to VDT / Carolyn Everett.
- [Vertical Access facade profile](https://vertical-access.com/wp-content/uploads/2016/06/shedd_aquarium.pdf) and [Space Haus Oceanarium design](https://www.spacehaus.net/zoos-and-aquariums/shedd-aquarium-abbott-oceanarium).

## Verification

Run `scripts/validate-museum-buildings.sh` for independent CPU geometry and route checks. It validates finite, normalized geometry, material indices, triangle/light budgets, all straight route segments at 101 samples each, floor support and head/torso/leg sweeps. Outdoor approach points use an explicit street-grade plane in this isolated fixture. The app's integrated playback validation separately checks the actual animated curves against the complete Chicago world, including vegetation and neighboring structures. Still-image and final movie review are recorded separately under `output/v7-review`; source geometry checks alone are not visual validation.

The final Shedd bookmark begins southwest of the historic west portico, with the low glazed ticket pavilion in front. This ground-level composition keeps the portico readable; the central dome is not visible from every exterior approach. The first camera point was moved within the same connected grounds while retaining the later route keys and timing.
