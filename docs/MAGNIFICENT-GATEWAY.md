# Wrigley and Tribune: Michigan Avenue gateway

`MagnificentGateway.swift` replaces the generic Wrigley and Tribune building masses with bounded architectural meshes in the existing shared Chicago world. The public entry point is `EiffelBuilder.magnificentGateway()`.

## Measured anchors and references

| Element | Source anchor | Reconstruction |
|---|---|---|
| Wrigley south base | OSM relation-derived building −174605391 | Exact six-point outline and triangulated roof; 67.5m body height is an interpretation |
| Wrigley north base | OSM relation-derived building −174605390 | Exact five-point outline; 89.6m body height |
| Wrigley clock shaft | Four mapped tower corners near 919.642,−1182.870 | Rotated shaft, four round clock faces, layered upper crown |
| Wrigley overall height | Owner brochure425ft | 129.54m |
| Tribune low base | OSM 150407241 | Exact eleven-point outline; 22.5m mapped base height |
| Tribune main shaft | Supplied mapped nine-point tower outline | Limestone wall piers and spandrels rising to 111m before the crown |
| Tribune architectural top | Current CVU/CTBUH 141.7m | 141.7m highest masonry pinnacle; overall tip measurement is separate |

The [Wrigley owner brochure, architecture page](https://zeller.us/thewrigleybuilding/wp-content/uploads/sites/21/2021/09/Wrigley-BRO-09-2021-1.pdf) describes 250,000 terracotta tiles in six shades, progressing from warmer white at the base toward cooler white above, and identifies 425ft as the tower height. The model uses six corresponding material bands. Its Giralda-derived upper silhouette is an interpretation of the documented architectural influence, not a measured ornament survey.

The [Chicago Architecture Center’s Wrigley account](https://www.architecture.org/online-resources/buildings-of-chicago/wrigley-building) documents the Spanish Colonial Revival character, white terracotta, floodlighting and the fourteenth-floor connecting bridge. Both third- and fourteenth-floor bridges are modeled across the mapped gap rather than filling the courtyard with a solid building mass. Their precise deck elevations, cross-sections and glazing subdivisions are authored estimates. The four 5.97m clock faces use actual circular meshes, sixty fixed black ticks, and fixed 10:10 hands; they do not follow the computer clock. A [PBS visit with the building’s clock keepers](https://www.pbs.org/video/brooklyn-tower-and-the-wrigley-building-xcecqx/) describes the four faces and their 19ft 7in dimension.

The [CAC Tribune account](https://www.architecture.org/online-resources/buildings-of-chicago/tribune-tower) identifies Indiana limestone, vertical piers, horizontal spandrels and the Gothic crown’s Rouen Cathedral influence. The mesh includes strong vertical relief, a central octagonal upper stage, paired lancet tracery, eight open flying-buttress assemblies and crocketed pinnacles. The entrance has a recessed Gothic portal and small inset stone panels suggesting the documented embedded fragments; individual historic fragments, sculpted figures and inscriptions are not reproduced. The [current CVU/CTBUH record](https://www.skyscrapercenter.com/chicago/tribune-tower/9017) distinguishes 141.7m architectural height from 145.8m overall tip height; the latter is not used as the masonry crown target.

## Rendering and limitations

The final mesh contains 197,877 triangles and 303 architectural light sources. Windows are individually bounded opaque reflective panes with fixed, sparse room occupancy at night. Sills, lintels, terracotta relief panels, cornice dentils, clock hands and crown struts are actual triangles participating in ray-traced shadows and reflections. Street-level glazing dividers are solid geometry; higher dividers use thin planar surfaces to preserve their silhouettes within the triangle budget. These are exterior reconstructions; no claim of survey-accurate Wrigley or Tribune interiors is made.

Overlapping architectural light banks cover lower, middle and upper facades, with separate clock-stage, loggia and dome washes. Compact visible housings mark cornice fixtures; effective group-source positions, throw and radii are calibrated photometric approximations rather than literal surveyed lamp locations. Wrigley uses neutral/cool white washes and modestly lit clock faces; Tribune uses warmer limestone accents. Beam shapes and renderer-unit power remain photographic approximations, not measured photometry. The live view uses the common lighting mode, sampler and reconstruction pipeline.

`Tests/MagnificentGateway/main.swift` checks finite mesh data and normals, material indices, the neighborhood footprint envelope, architectural heights, all four clock diameters and their actual hands/ticks, both bridges, fixture validity and the triangle budget. The full scene’s normal navigation and motion checks remain separate.

Run `./scripts/validate-magnificent-gateway.sh` from a checkout to compile the production scene dependencies and execute these CPU checks without opening the app or using the GPU.

The focused night proof, `output/v6-review/final-night/00-the-magnificent-mile.png`, was inspected at 1600×1000. Wrigley's white facade, clock hands, upper arches and dome remain readable together; Tribune's warmer shaft, lancet crown and flying buttresses are visible. The fixture and image hashes are recorded in `docs/validation/v1.5/magnificent-gateway.json`. This is still-image review, not a certification of temporal stability, motion noise or survey accuracy.
