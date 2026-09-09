# Chicago Skyline — lighting studies

Chicago Skyline adds eight two-minute camera routes within the existing Chicago world. It follows Willis Tower in the destination menu and Chicago demo: Willis → Skyline → Millennium Park → Lakefront → Museum Campus → North Side → Robie House. Chicago now has 56 full walkthrough routes, totaling 6,156 seconds (102 minutes 36 seconds) at 1× before repetition. Paris remains outside the Chicago demo.

## Choosing the viewpoint

Adler’s lakefront is the primary composition. The planetarium’s own [visitor information](https://www.adlerplanetarium.org/plan-your-visit/) describes its lakefront city view, and [Choose Chicago’s photography guide](https://www.choosechicago.com/blog/tours-attractions/7-photo-spots-for-the-best-chicago-skyline-views/) includes the area in front of Adler among its recommended skyline viewpoints. Open water separates the camera from the buildings, allowing Willis Tower and the northern towers to read together. This also gives nighttime reflections room in the foreground.

North Avenue provides the contrasting southward view: the former John Hancock Center becomes the nearer landmark and the lakefront curves toward downtown. The [Chicago Park District’s North Avenue Beach page](https://www.chicagoparkdistrict.com/parks-facilities/north-avenue-beach) establishes the beach and its Lincoln Park setting. Monroe Harbor and elevated offshore positions supply complementary angles. These are cinematic camera studies, some over water, rather than a claim that every camera position is a publicly accessible walking route.

Three photographic references were actually viewed in Safari on September 9, 2026:

| Reference | Observed features used |
| --- | --- |
| [City of Chicago — skyline at dusk from Adler, January 2022](https://chicagoimagegallery.cityofchicago.org/Chicago-Skylines/i-M9qzZx9) | Broad, low skyline composition; cobalt sky; warm and white tower lights; elongated reflections across the lake. The winter snow and ice were not transplanted into this summer landscape. |
| [City of Chicago — Lake Michigan sunrise, January 2026](https://chicagoimagegallery.cityofchicago.org/Chicago-Skylines/i-t3kGmq9) | Clear blue sky, warm morning illumination on facades, open-water foreground and the relative scale of the tower band. The reference is seasonal and does not establish an exact camera coordinate. |
| [Lewis Carlyle Photography — Chicago Skyline Sunset](https://lewiscarlyle.com/product/chicago-skyline-sunset/) | A west-facing panorama with amber near the horizon, rose higher in the sky and cooler blue above; the warm atmosphere repeats across the water. Cloud shapes and photograph pixels are not copied. |

The cameras use the same coordinates, mapped building footprints, harbor geometry and shoreline as the existing Chicago scene. No duplicate skyline mesh or second Chicago acceleration structure is introduced. Existing context limitations remain: many background facades and untagged heights are interpretations, and the city is not a survey-grade reconstruction. No reference photographs are bundled or redistributed.

## Eight studies

| View | Title | Authored lighting |
| --- | --- | --- |
| 1 | The city across the water | Clear day |
| 2 | Harbor and horizon | Warm daylight |
| 3 | Sunset behind the skyline | Sunset |
| 4 | Lights on the lake | Night |
| 5 | Monroe at sunset | Sunset |
| 6 | The northern curve | Clear day |
| 7 | A city beside a great lake | Warm daylight |
| 8 | The luminous panorama | Night |

Each bookmark starts its own 120-second route. Idle motion makes a much gentler orbit around the composition, with a small change in field of view. Vertical fields of view are approximately 33–40°, chosen to keep the silhouette legible rather than reduce it to a thin strip beneath a wide-angle sky.

During an ordinary Skyline pass, idle and demo playback follow the authored lighting table. The next complete idle pass is all night; the following pass restores the authored studies. In Chicago demo, the base day/night pass flips only at the full city-list boundary. `N` toggles from the lighting actually visible, so pressing it on an authored night view selects day. An explicit lighting choice holds across subsequent views and in-demo destination changes until the full idle or Chicago pass wraps. Starting a fresh Chicago demo clears that temporary override while retaining the base day/night parity. View changes and lighting controls preserve the established pause, shuttle and speed behavior.

## Sunset rendering

Lighting preset `3` is an actual atmosphere and light change. The sun points west-northwest at approximately four degrees above the horizon in the shared east/south coordinate system. Its warm irradiance casts direct light and traced shadows. A directional amber horizon transitions through rose into a blue zenith; architectural lights and illuminated window materials are active. The environment is evaluated consistently for camera, reflection and illumination rays, so ray-traced water and glass respond to the sunset sky. This is an illustrative late-day preset, not an astronomical date/time model or measured atmospheric simulation.

The renderer uses a previously reserved uniform component for sunset. Uniform size, the three-bounce budget, existing light-grid limits, geometry partitions, motion reconstruction and raster MSAA remain unchanged. Presets `0`, `1` and `2` retain their existing daylight/night paths. Raster mode uses the same directional atmosphere and material lighting, with its established limitations: analytic environment reflections, approximate transparent glass, and no ray-traced local reflections, shadows or indirect illumination. The sunset does not add ray queries to raster mode.

## Validation

`./scripts/validate-playback.sh` validates transport semantics and samples all routes against the shared collision scene. The Skyline integration passes 92,743 checks, including all eight new routes, per-view lighting, manual override persistence, `N` from authored night, fresh-demo override clearing and full-pass day/night parity. Route checks report no blocked or near-surface Skyline samples; offshore views deliberately do not require pedestrian support.

`./scripts/validate-skyline-rendering.sh` builds one complete Chicago scene and renders all eight authored compositions in raster mode plus matched day, sunset and night ray-traced references. It checks the unchanged 144-byte frame uniform layout, low westward sun, warm irradiance, stable input hashes and zero ray/guide/traffic-AS work in raster mode. All 13 stills passed [visual review](validation/v2.1/skyline/visual-review.json). The signed application passed [isolated working-directory sunset checks in both rendering modes](validation/v2.1/package-rendering/runs.json) and [native interaction checks](validation/v2.1/native-review.json). Offscreen timing does not establish native window frame rate.

The completed [render report](validation/v2.1/skyline/validation.json) records 38 checks and 13 stills at 1280×800 (64 samples for RT). [All 13 images were visually reviewed](validation/v2.1/skyline/visual-review.json). The [playback log](validation/v2.1/skyline/playback.txt) and [39,485-check raster regression](validation/v2.1/skyline/raster-regression.txt) retain their actual results. These checks do not substitute for final application/package or continuous-motion validation.
