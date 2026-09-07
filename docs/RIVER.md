# Seine, Pont d’Iéna and river craft

The ninth camera frames the Seine, the five open arches of Pont d’Iéna, and an original sightseeing cruiser. The bridge and banks are static geometry. Their water reflections come from the same ray-traced scene as the rest of the engine.

## References inspected

- [Association Française de Génie Civil: Pont d’Iéna](https://www.afgc.asso.fr/history-heritage/pont-diena-a-paris/): its ENPC photographs were visually inspected for the pale ashlar, shallow segmental arches, projecting arch stones, cornice, stone balustrade, cutwaters and sculptural pier reliefs. AFGC gives a total length of 155 m, useful width of 35 m, five 28 m arches, four intermediate piers, a 22 m carriageway and two 6.5 m pavements. It also identifies the eagle reliefs and four equestrian entrance groups.
- [Bateaux Parisiens fleet](https://www.bateauxparisiens.com/en/the-company/our-boats.html): the operator’s actual fleet photographs were inspected for the long, low white hulls, large raked panoramic glazing, glass/roof framing, open viewing areas and orange lifebuoys. The rotating night interior photo showed warm cabin light and broken amber reflections across river ripples.
- [Bateaux Parisiens practical information](https://www.bateauxparisiens.com/en/practical-info.html) and [sightseeing cruises](https://www.bateauxparisiens.com/en/cruise-tours.html) establish that sightseeing boats operate at Port de la Bourdonnais beside the Eiffel Tower, by day and night.

These photos are reference material only. No third-party photo is embedded in the renderer or redistributed in its assets. The boat is an original 48 m procedural interpretation, without an operator brand or a claim to reproduce a particular named ship.

## Geometry and materials

The bridge uses five circular segment arches with 28 m clear spans. Four 3.75 m piers bring the modeled overall length to 155 m. The 3.4 m rise and vertical levels are interpretive, not a surveyed navigation clearance. Each arch has a continuous intrados, separate side spandrels, a projecting segmented voussoir ring and crown keystone. Piers have pointed cutwaters and an original simplified eagle relief. Multiple cornice steps, hundreds of profiled balusters, parapet piers, twin lanterns, stepped plinths and small original horse-group studies complete the silhouette.

Quays include dressed retaining walls, coping, lower promenade paving, stairs with handrails, mooring rings, cleats, bollards and a small floating landing with a gangway. The cruiser has a faceted curved hull, contrasting rubbing strake, individual glazing panels and mullions, raked wheelhouse windows and wipers, radar/mast, rails, deck seating, stairs, lifebuoys, fenders, mooring cleats and colored navigation lights. Cabin and quay lamps illuminate surrounding surfaces and the water at night.

Water is a nonmetallic material using dielectric normal-incidence reflectance F0 = 0.02037, corresponding to IOR 1.333. Six analytic ripple wavelengths, from 7.2 m to 13 cm, perturb the shading normal. Their gradients are attenuated by the camera ray footprint, while unresolved waves increase roughness. This avoids adding a new source of high-frequency shimmer during movement. Reflections use the existing GGX importance-sampled ray tracing and motion reconstruction; there is no mirrored photograph or decal. A dark green diffuse term is an approximation of light scattered within the river. Refraction, caustics, animated fluid simulation and survey-correct bathymetry are not implemented.

The near-river corridor is an idealized straight section centered at z = −220 m, with water at y = −5.2 m, aligned to the local map frame documented in the Paris context notes. The immediate surroundings use mapped footprints; the waterline and elevations remain an authored approximation. The boat stays stationary so camera reprojection remains valid without object motion vectors.

## Verification

The actual M3 Ultra GPU validation passes for both daylight and night shaders, including exact accumulation reset, progressive arithmetic mean and the light buffer binding. Integrated day/night screenshots and ninth-route clearance checks are part of the application review.
