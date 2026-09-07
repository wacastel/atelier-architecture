# Eiffel Tower reconstruction

This scene is an original, deterministic procedural architectural study created for ATELIER. It is not a scan, photogrammetric asset, licensed survey, structural analysis, or an as-built BIM model. The silhouette and major levels use the tower operator’s published dimensions. Structural panel spacing, member sections, connections, furnishings, pavilion layouts, landscape and city blocks are interpreted to make a detailed, explorable rendering demonstration.

## Reference dimensions

World coordinates are metres, with Y pointing upward and the tower axis at X=Z=0. Published anchors used here are the current 330 m height, 125 m base span, 25 m ground-level pillar width, and the principal visitor levels at approximately 57 m, 115 m and 276 m. The four lower piers have a piecewise curved profile, and the upper lattice narrows continuously to the summit structure and antenna.

Sources consulted on 7 September 2026:

- [SETE / Eiffel Tower: key figures, French metric edition](https://www.toureiffel.paris/fr/le-monument/chiffres-cle). Dimensional anchors and the historical scale of the ironwork. The English page’s unit conversions and floor-area wording are inconsistent, so the model does not claim a verified floor area.
- [SETE / Eiffel Tower: explore the monument](https://www.toureiffel.paris/en/explore). The three visitor levels and the first-floor experience.
- [SETE / Eiffel Tower: redevelopment of the first floor](https://www.toureiffel.paris/en/news/events/redevelopment-first-floor-eiffel-tower). Inspiration for a first-floor urban space containing visitor pavilions, a circulation terrace and a central open void. The implemented pavilions are original interpretations, not copies of the Moatti–Rivière interior plans.
- [SETE / Eiffel Tower: first-floor visitor guide](https://www.toureiffel.paris/en/explore/first-floor). Visitor services, exhibits and surrounding public circulation informed the demonstration’s interior program.

No downloaded photographs, textures, meshes, scanned drawings or third-party 3D assets are redistributed. The model and all material variation are generated from code.

## Geometry and materials

The following features exist as ray-intersectable geometry:

- Four splayed piers, each with four open lattice faces, I-section primary chords, diagonal flanges, secondary lattice strips, riveted connection plates and rounded rivet heads.
- Four curved entrance arch trusses with paired ribs, radial ties and spandrel members.
- First and second terraces with open central voids, deep lattice fascias, structural underside beams, narrow board joints and steel balustrades.
- Switchback stairs through one lower pier, stepped treads, inclined stringers, handrails and landings; a short exposed service stair on the first terrace.
- Inclined lift guides, representative cabins, central upper lift rails and service landings.
- Two first-floor visitor pavilions with open doorways, steel-framed bays, clerestory glazing, timber floors, ceiling fixtures, benches and connection exhibits.
- A summit circulation gallery, wire enclosure, upper trusses, service mast and antennas.
- A paved esplanade, formal lawn panels, modeled trees, benches and street lamps. The river, bridges and roofed city blocks extending approximately 3.5 km from the tower provide a deliberately simplified Paris-like context; they are not georeferenced reproductions of individual buildings or the exact street plan.

The iron uses muted brown/bronze linear base colours, roughness and metallic response. Additional procedural shader patterns provide surface-scale variation. Rivets and the near-view plate surfaces remain real geometry, independent of the shader pattern. Materials marked as glass use a reflective opaque approximation in the initial renderer; the scene’s open pavilion bays and real mesh openings allow inspection of interior structure. The demonstration does not claim physically simulated architectural glass transmission.

The historical monument contains vastly more individual iron pieces and rivets than this procedural study. The scene reports its actual rendered triangle count and modeled rivet count at runtime; these counters describe this reconstruction, not the inventory of the real tower. All detail is currently resident rather than streamed by distance.

## Walk surfaces and chapter poses

The terrace floor surfaces use the following navigation bounds. Each is a square ring described by the maximum absolute X or Z coordinate; a central square remains open.

| Surface | Floor Y | Outer half extent | Central void half extent |
| --- | ---: | ---: | ---: |
| Esplanade | 0.10 m | 90 m paved square | none |
| First terrace | 57 m | 36.5 m | 13.5 m |
| Second terrace | 115 m | 21.5 m | 7.5 m |
| Summit gallery | 276 m | 8.5 m | 3 m occupied centre |

The east visitor pavilion occupies approximately X=20…32 m, Z=−12…12 m, with doors centred on X=26 m at the north and south ends. Its mirrored counterpart occupies the west side. The roof is at 62.5 m. The geometry supports viewing these spaces; navigation is an architectural inspection system rather than a certified pedestrian accessibility or evacuation simulation.

The eight curated chapters progress through a skyline overview, ground arch view, near-field iron connection, first terrace, pavilion interior, second terrace, summit and return panorama. Each chapter is an inspection pose with a gentle local camera move. Transitions between chapters use cuts or fades to avoid suggesting a physically continuous path through intervening floors and structure.

## Extending fidelity

A future survey-grade project should replace the procedural interpretation with appropriately licensed survey or BIM geometry, verified floor plans, exact member sections and connections, georeferenced context, transmission-tested glazing and collision surfaces derived from the intended walking routes. The rendering pipeline and import path are separate from the Eiffel-specific scene generator so other structures can be introduced without replacing the engine.
