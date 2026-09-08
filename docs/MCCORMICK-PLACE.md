# McCormick Place reconstruction

The four convention buildings, the Grand Concourse, the east Sky Bridge, the Hyatt complex, Marriott Marquis, Wintrust Arena, Hilton complex and historic Lakeside Technology Center occupy the same Chicago metre grid as the museums and lakefront. `McCormickPlace.swift` uses the frozen Museum Campus map derivative for footprint rings and triangulated roofs. The eighth Museum Campus study makes a three-minute flight around the campus.

This is an architectural reconstruction, not a construction survey. The map establishes plans and locations; photographed façade rhythms, structural systems and materials guide the authored detail. The exhibition halls are exterior models. The selected museum interiors are documented separately.

## Reference review

The following primary sources and images were inspected on September 8, 2026. Images were viewed in the browser for reference; no photographic textures or third-party photographs are bundled in the app.

| Source | Evidence used |
| --- | --- |
| [McCormick Place floor plans](https://www.mccormickplace.com/floor-plans/) and [campus planning PDF](https://www.mccormickplace.com/wp-content/uploads/floor-plan-images/pdfs/mccormick-place-floorplans.pdf) | Four principal buildings; Grand Concourse; pedestrian bridges; roads, railway and hotel relationships. The PDF's first-page campus diagram was visually inspected. |
| [Owner's photo gallery](https://www.mccormickplace.com/gallery/) | The entrance canopies, glazing and campus material palette. |
| [Lakeside photograph](https://www.mccormickplace.com/wp-content/uploads/general-images/Lakeside-1.jpg) | Black steel pavilion, deep overhang, recessed glass, exposed bents and raised lake terrace. |
| [West Gate 41 photograph](https://www.mccormickplace.com/wp-content/uploads/general-images/West-Gate-41.jpg) | Silver canopy, pilotis, open loggia, projecting glass beacons and paved forecourt. |
| [Owner's campus aerial from the northwest](https://www.mccormickplace.com/wp-content/uploads/2025/07/Aerial-photo-of-the-McCormick-Place-campus-from-the-northwest.jpg) | Four-building massing, hotels, Wintrust's Chicago-flag roof, historic brick neighbor, skyline and bridges. |
| [SOM: North Building](https://www.som.com/projects/mccormick-place-phase-2-exposition-center-expansion-north-building/) | Twelve cable pylons and construction above active railway tracks. The close roof photograph shows slotted pylons, cable sockets and anchors; the full-building photograph shows broad solid wall panels and narrow glazing bands. Both photographs were visually inspected. |
| [South Building specifications](https://www.mccormickplace.com/floor-plans/south-specs/) | Large exhibition spans and 40-foot hall ceilings; this is clear ceiling height, not a building-height tag. |
| [West Building planning PDF](https://mccormickplace.com/wp-content/uploads/floor-plan-images/pdfs/West-Building.pdf) | Roof-garden level and linked circulation; 40-foot Hall F ceiling. |
| [Epstein: West roof garden](https://www.epsteinglobal.com/news/open-house-chicago-2019) | A planted portion of the roof, rather than vegetation covering every exhibition roof. |
| [CVU: Marriott Marquis Chicago](https://www.skyscrapercenter.com/chicago/mccormick-place-marriott-marquis/15747) | 135.2-metre architectural top and 40 floors. |
| [Marriott's opening announcement](https://www.prnewswire.com/news-releases/marriott-marquis-makes-its-debut-in-chicago-300517395.html) | Forty-storey hotel and linked meeting facilities. |
| [MPEA Hyatt renovation drawings](https://www.mpea.com/wp-content/uploads/2024/09/Exhibit-6-Hyatt-Regency-McCormick-Place-MPEA_CMAR-Drawings.pdf) | South Tower guestroom floors through level 33. |
| [Esri World Imagery, McCormick extent](https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?bbox=-87.628,41.846,-87.605,41.857&bboxSR=4326&imageSR=3857&size=1280,800&format=png&f=image) | Visually inspected satellite view: angled Lakeside footprint, curved South edge, North roof, West roof terraces, connecting concourse, hotel/arena blocks, roads and rail alignment. Imagery acquisition date was not exposed; inspection date is not acquisition date. |

## Geometry and interpretation

The Lakeside roof uses the parent footprint's 30-metre height. Two OSM parts report 100 metres with a 90-metre minimum: these conflict with the owner's photographs and are deliberately not turned into enormous towers. North's twelve pylons, paired cables, sockets and roof anchors are real geometry. Their exact engineering sections and heights are interpreted from photographs. Its largely solid panel façades follow the architect's full-building photograph.

The West canopy, planted terrace beds and glass beacons, South façade/roof ribs, raised Grand Concourse and glazed expressway bridge have separate modeled surfaces. McCormick's hotel towers use separate mapped parts rather than extruding their broad podiums to tower height. Marriott's sloping top reaches the independently verified 135.2 metres. Hyatt's South Tower height is an explicit architectural estimate of 119 metres based on its documented floors and photographed proportions; the contradictory 50-metre map tag is not treated as surveyed height. Minor service structures, hotel interiors, roof equipment, planted-bed layouts and some pedestrian bridge cross-sections remain interpretations.

Window bays use finite geometry and a deterministic occupancy pattern. Large roofs keep coarse surface meshes; only canopies, pylons, bridges, nearby façades and planted terraces receive small detail. Night fixtures are bounded practical approximations of architectural and promenade lighting, not a measured photometric survey. Wintrust's flag roof is original geometry based on the actual aerial.

## Checks

`./scripts/validate-mccormick.sh` checks valid triangle/material packing, finite positions, unit normals, nondegenerate triangles, bounded geometry, mapped roof coverage, the Marriott top, and sampled head, torso and leg clearance along the full camera path against the authored campus. The full-world playback and motion regressions additionally include surrounding buildings, live traffic and the new campus lighting.
