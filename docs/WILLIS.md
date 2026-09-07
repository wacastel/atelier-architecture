# Willis Tower — Chicago

Atelier's Chicago project is an original, metre-scale architectural reconstruction. It shares the native Metal ray tracer, material system, motion reconstruction, navigation, independent idle/playback clocks, and day/night controls with Paris. The two locations have separate geometry and cameras.

## Survey anchors and architectural form

The local origin is **41.878876° N, 87.635918° W**. Coordinates use **x east, y up, z south**, in metres; street grade is y=0. The tower's nine tubes each measure **22.86 × 22.86 m (75 × 75 ft)**, forming a **68.58 m** square. The modeled architectural roof is **442.14 m (1,450 ft)**. These dimensions and the black aluminum/bronze-tinted glass material language follow [SOM's project record](https://www.som.com/projects/willis-tower-formerly-sears-tower/).

Tube termination is geographic, so changing viewpoint does not alter the structural arrangement:

| Tube | Termination |
| --- | --- |
| Northwest and southeast | Floor 50 |
| Northeast and southwest | Floor 66 |
| North, east, and south | Floor 90 |
| West and center | Upper occupied/mechanical crown through floor 110 |

Intermediate elevations are authored interpolations: setbacks follow the mapped building-part height tags at 200, 260, and 355 m; floors 108–110 form the mechanical crown. The **103rd-floor Skydeck is anchored at 412.3944 m (1,353 ft)**. The roof and Skydeck elevations are published measurements; intermediate slab elevations are not an as-built floor survey. The masts terminate at 527.3 and 520.6 m as a visual interpretation of the contemporary unequal antennae.

The exterior contains individual recessed window panes, dark spandrels, structural column caps, intermediate mullions, gaskets, sill rebates, mechanical louvers, roof parapets, and close-range cap-strip fixings. The façade's column rhythm uses five 15-foot structural bays per tube, with three glazing subdivisions per bay. Structural engineer Srinivasa Iyengar describes the tower's 15-foot column spacing in his [Art Institute of Chicago oral history](https://artic.contentdm.oclc.org/digital/api/collection/caohp/id/24167/download). [AISC's 1975 architectural awards publication](https://www.aisc.org/contentassets/ce38e97209574daeacee4a0273d2e10a/aae_1975.pdf), pages 24–25, documents the bundled-tube arrangement and belt-truss principle.

## Catalog and the Skydeck

The contemporary base includes a Jackson Boulevard entrance, open atrium, café furniture, transparent curtain walls, entry canopy, and roof garden. A **22.86 m square doubly curved skylight** is framed with a fine diagonal steel lattice. Curved planting paths and stone benches, ornamental grasses, purple flower heads, small trees, metal-capped glass balustrades, café chairs, and downlights create detail at walking distance.

The roof garden and glass skylight were informed by actual photographs on [Gensler's Willis Tower repositioning project](https://www.gensler.com/projects/willis-tower-repositioning). The garden photograph was visually inspected in the browser: it shows a raised curved skylight, sweeps of lawn and paving, continuous curved benches, mixed perennial planting, thin black light poles, and a glazed podium. The model uses those architectural cues with a simplified layout. [The building operator's experience page](https://www.willistower.com/experience) confirms the public Catalog rooftop greenspace and its five-level dining and retail program.

The observation gallery is walkable, with a restrained pale ceiling, structural mullions, wood-topped benches, elevator-core enclosure, interpretive consoles, and five west-facing Ledge boxes. Each box projects **1.31064 m (4.3 ft)**, with approximately **3.048 m width and height**. The current five-box count was checked against Skydeck’s live Ledge page, rather than retaining the original four-box 2009 configuration. Its photograph was also visually inspected: the clear side panels, narrow edge fittings, and bolted laminated-floor frame informed the close model. Thin glass panels use dielectric reflection and transmission in the renderer. The surrounding office windows remain opaque reflective architectural glazing. Ledge edge seals, fittings, overhead retraction tracks, and glass-floor edge supports are geometry. Projection/elevation follow [Skydeck's current Ledge page](https://theskydeck.com/plan-a-visit/the-ledge/); approximate box width/height and retracting support concept follow [SOM's Ledge description](https://www.som.com/projects/willis-tower-formerly-sears-tower/).

The public interior, furniture arrangement, podium circulation, and rooftop equipment are authored interpretations. They are not survey-grade reconstructions of tenant spaces or a substitute for the building's public visitor information. The roof inspection camera is an aerial architectural view, not a public-access route.

## Eight views

| Key | View | Camera behavior |
| --- | --- | --- |
| 1 | Chicago's great tower | Slow idle orbit; full elevated walkthrough orbit |
| 2 | Welcome to Catalog | Human-height entrance and atrium approach |
| 3 | Black aluminum, bronze glass | Close façade dolly from the roof terrace |
| 4 | A garden above the Loop | Roof garden, café terrace, and skylight walk |
| 5 | Inside the Skydeck | Observation-gallery walk with transmitted city views |
| 6 | Out on the Ledge | Glass-box approach, downward panorama, and retreat |
| 7 | Crown of the skyline | Aerial inspection of masts and mechanical roofs |
| 8 | Along the Chicago River | South Branch river, bridges, and city perspective |

The river view deliberately looks along the real river canyon: existing office towers between the South Branch and Willis obscure the lower tower from water level. Its route frames the boat and bridges without relocating those buildings.

Every view starts its own 56-second route at the selected bookmark. Interior and terrace routes use line-segment interpolation with eased motion, avoiding spline overshoot. Views 2–6 use walking mode; the overall, crown, and river views use flying mode. The app's Idle Play clock cycles through eight daytime views and eight nighttime views repeatedly. An explicit view selection holds that view until Idle Play resumes.

## Night references and lighting

The official [Willis Tower about page](https://www.willistower.com/about?c=0&p=1) contains a nighttime skyline photograph beside “A beacon for the world to see.” It was actually visually inspected. The tower remains largely dark, scattered office windows form small bright rectangles, the broadcast masts carry colored light, and the surrounding city is a mix of warm and cool illumination. The operator describes an antenna color schedule that varies for events.

Atelier follows that balance: the dark façade is not broadly floodlit; deterministic sparse windows glow in mixed white temperatures. Cool-white mast projectors and low continuous mast radiance, small red aviation lamps, warm podium/terrace downlights, streetlights, and neighboring offices illuminate the city. Small recessed roof-level wall washers make the close aluminum inspection readable at night while the upper tower remains dark. Mast lights are an authored neutral presentation, not a live reproduction of a particular evening's color schedule. Reflection and light transport use scene geometry. Illumination values are calibrated renderer units rather than surveyed photometric fixtures.

## Reproduction and limitations

`WillisScene.swift` defines geometry and bookmarks; `WillisWalkthrough.swift` defines routes. `ChicagoEnvironment.swift` consumes the bundled map snapshot; see `CHICAGO.md` for map provenance, aerial-image inspection, and context detail levels. Reference photographs were viewed as design references, not redistributed or baked into textures. No third-party building mesh is bundled.

This is a detailed architectural visualization, not a surveyed digital twin. The bundle topology, tube size, geographic orientation, roof height, and Skydeck/Ledge dimensions are explicitly constrained. Intermediate floor heights, subtle façade finishes, local interior layouts, vegetation, fixtures, equipment, and tenant window occupancy are approximations. Thin glass transmits rays without volumetric refraction or caustics. The city outside the mapped region is lower-detail context. Fine night reflections can retain path-tracing grain during movement.
