# Chicago Skyline — lighting studies

Chicago Skyline adds eight two-minute camera routes within the existing Chicago world. It follows Willis Tower in the destination menu and Chicago demo: Willis → Skyline → Millennium Park → Lakefront → Museum Campus → North Side → Robie House. Chicago now has 56 full walkthrough routes, totaling 6,156 seconds (102 minutes 36 seconds) at 1× before repetition. Paris remains outside the Chicago demo.

## Choosing the viewpoint

Adler’s lakefront is the primary composition. The planetarium’s own [visitor information](https://www.adlerplanetarium.org/plan-your-visit/) describes its lakefront city view, and [Choose Chicago’s photography guide](https://www.choosechicago.com/blog/tours-attractions/7-photo-spots-for-the-best-chicago-skyline-views/) includes the area in front of Adler among its recommended skyline viewpoints. Open water separates the camera from the buildings, allowing Willis Tower and the northern towers to read together. This also gives nighttime reflections room in the foreground.

North Avenue provides the contrasting southward view: the former John Hancock Center becomes the nearer landmark and the lakefront curves toward downtown. The [Chicago Park District’s North Avenue Beach page](https://www.chicagoparkdistrict.com/parks-facilities/north-avenue-beach) establishes the beach and its Lincoln Park setting. Version 2.1.1 replaces three overlapping lakefront compositions with an eastward telephoto view from Oak Park, a view above Kinzie Street Bridge, and a northward view above Ping Tom Memorial Park. These are cinematic camera studies, including elevated and offshore positions; their heights do not imply public observation decks.

Three photographic references were actually viewed in Safari on September 9, 2026:

| Reference | Observed features used |
| --- | --- |
| [City of Chicago — skyline at dusk from Adler, January 2022](https://chicagoimagegallery.cityofchicago.org/Chicago-Skylines/i-M9qzZx9) | Broad, low skyline composition; cobalt sky; warm and white tower lights; elongated reflections across the lake. The winter snow and ice were not transplanted into this summer landscape. |
| [City of Chicago — Lake Michigan sunrise, January 2026](https://chicagoimagegallery.cityofchicago.org/Chicago-Skylines/i-t3kGmq9) | Clear blue sky, warm morning illumination on facades, open-water foreground and the relative scale of the tower band. The reference is seasonal and does not establish an exact camera coordinate. |
| [Lewis Carlyle Photography — Chicago Skyline Sunset](https://lewiscarlyle.com/product/chicago-skyline-sunset/) | A west-facing panorama with amber near the horizon, rose higher in the sky and cooler blue above; the warm atmosphere repeats across the water. Cloud shapes and photograph pixels are not copied. |

The three added origins draw on five more photographs actually viewed in Safari: YoChicago’s elevated eastward Oak Park panorama, UIC Library’s historical Kinzie bridge photograph, two Chicago Park District Ping Tom images, and Michael Hoffman’s nighttime view from the 18th Street Bridge. [The reference update](SKYLINE-REFERENCE-UPDATE.md) records URLs, image sizes, observed composition, coordinates and the distinction between photographic facts and authored camera choices. The historical Kinzie photograph informs the river composition; modern mapped buildings remain in place.

The cameras use the same coordinates, mapped building footprints, harbor geometry and shoreline as the existing Chicago scene. No duplicate skyline mesh or second Chicago acceleration structure is introduced. Oak Park’s camera is approximately 13.6 km west of Willis Tower, outside the detailed mapped corridor. The two existing far-west fallback ground slabs now use plain, rough, muted-green land material without a paving or grass pattern: this is generalized, undetailed land, not a reconstruction of the intervening western neighborhoods. No additional infrastructure, triangles or map coverage are introduced. Many background facades and untagged heights remain interpretations, and the city is not a survey-grade reconstruction. No reference photographs are bundled or redistributed.

## Eight studies

| View | Title | Origin | Authored lighting |
| --- | --- | --- | --- |
| 1 | The city across the water | Adler lakefront | Clear day |
| 2 | Chicago from the west | Oak Park, facing east | Clear day |
| 3 | Sunset behind the skyline | Adler panorama | Sunset |
| 4 | Lights on the lake | Adler lakefront | Night |
| 5 | The river leads downtown | Above Kinzie Street Bridge | Night |
| 6 | The northern curve | North Avenue Beach | Clear day |
| 7 | North from the South Branch | Above Ping Tom Memorial Park | Warm daylight |
| 8 | The luminous panorama | Lake Michigan | Night |

Each bookmark starts its own 120-second route. Idle motion makes a much gentler orbit around the composition, with a small change in field of view. Oak Park opens at a 55 m camera height with a cropped 9° vertical telephoto field of view; its route rises to 76 m. The Kinzie study starts 210 m above the scene ground and rises to 260 m, with a target height rising from 230 to 260 m and a 48–50° vertical field of view. This elevated composition reveals Willis beyond the contemporary foreground towers. Ping Tom’s route rises from 18 to 58 m. The other views use approximately 33–39° vertical fields of view. These heights are authored flight positions, not surveyed balcony or bridge elevations.

The map uses a 24-point dotted camera marker. For a camera outside the mapped area, it reports the direction and distance beyond the map instead of implying that the camera sits on a mapped street. Focusing a distant building preserves the entry distance, so beginning an orbit from Oak Park does not pull the camera abruptly into downtown. The map continues to cover the existing modeled corridor.

During an ordinary Skyline pass, idle and demo playback follow the authored lighting table. The next complete idle pass is all night; the following pass restores the authored studies. In Chicago demo, the base day/night pass flips only at the full city-list boundary. `N` toggles from the lighting actually visible, so pressing it on an authored night view selects day. An explicit lighting choice holds across subsequent views and in-demo destination changes until the full idle or Chicago pass wraps. Starting a fresh Chicago demo clears that temporary override while retaining the base day/night parity. View changes and lighting controls preserve the established pause, shuttle and speed behavior.

## Sunset rendering

Lighting preset `3` is an actual atmosphere and light change. The sun points west-northwest at approximately four degrees above the horizon in the shared east/south coordinate system. Its warm irradiance casts direct light and traced shadows. A directional amber horizon transitions through rose into a blue zenith; architectural lights and illuminated window materials are active. The environment is evaluated consistently for camera, reflection and illumination rays, so ray-traced water and glass respond to the sunset sky. This is an illustrative late-day preset, not an astronomical date/time model or measured atmospheric simulation.

The renderer uses a previously reserved uniform component for sunset. Uniform size, the three-bounce budget, existing light-grid limits, geometry partitions, motion reconstruction and raster MSAA remain unchanged. Raster mode uses the same directional atmosphere and material lighting, with its established limitations: analytic environment reflections, approximate transparent glass, and no ray-traced local reflections, shadows or indirect illumination. The sunset does not add ray queries to raster mode.

## The longer western view

Oak Park uses a per-view haze density of `0.000020 m⁻¹` to retain skyline contrast across the roughly 13.6 km sightline. Its clear-day horizon is coherently bluer in the sky, reflection environment and aerial perspective; it is not a rotated west-facing sunset. The override occupies the previously reserved `FrameUniforms.animation.w`, preserving the 144-byte uniform layout. Every other view supplies zero and retains its established atmosphere. The setting changes the illustrative clear-air treatment for this distant study; it does not add a weather simulation or model the missing western neighborhoods.

## Validation

### Version 2.1.1

The final renderer and route checks passed with the revised Oak Park, Kinzie and Ping Tom compositions. [The release evidence index](validation/v2.1.1/README.md) records the scope and remaining native checks.

| Scope | Result and evidence |
| --- | --- |
| Route clearance and playback semantics | [92,867 checks passed across all 65 routes](validation/v2.1.1/skyline/playback.txt), including all eight Skyline routes |
| Renderer contracts and still images | [131 checks passed; 24 stills](validation/v2.1.1/skyline/validation.json): eight authored raster views, ten ray-traced images, and six route midpoint/end images; [visual review](validation/v2.1.1/skyline/visual-review.json) |
| Map geometry and off-map indication | [21,434 CPU checks passed](validation/v2.1.1/navigation-map.json) |
| Distant focus and orbit | [1,605 CPU checks passed](validation/v2.1.1/focus-navigation.json), including 21 assertions demonstrating failures in the old behavior |
| Raster regression | [39,485 checks passed](validation/v2.1.1/raster-regression.json) |
| Application package | [Version 2.1.1, build 14](validation/v2.1.1/package.json): native arm64, strict ad-hoc signature verification passed, all 26 bundled resources match source |
| Native off-map marker and distant focus/orbit | [Blocked while the Mac is locked](validation/v2.1.1/native-review.json); requires the user to unlock it |

The final package’s executable SHA-256 is `8610cd488eeb864047785001b84be0861420c68d877d9cc377c4e740bdaa9ab1`. Its isolated-working-directory Oak Park self-tests [passed in both ray-tracing and raster modes](validation/v2.1.1/package-rendering/runs.json). The shared Chicago scene remains at 45,496,818 static triangles. Still-image and CPU results do not establish continuous-motion quality or native window frame rate, and the locked session prevented final native interaction verification.

### Historical version 2.1.0

`./scripts/validate-playback.sh` validates transport semantics and samples all routes against the shared collision scene. The original Skyline integration passed 92,743 checks, including its eight routes, per-view lighting, manual override persistence, `N` from authored night, fresh-demo override clearing and full-pass day/night parity. Route checks reported no blocked or near-surface Skyline samples; offshore views deliberately do not require pedestrian support.

The version 2.1.0 run of `./scripts/validate-skyline-rendering.sh` built one complete Chicago scene and rendered its eight authored compositions in raster mode plus matched day, sunset and night ray-traced references. It checked the unchanged 144-byte frame uniform layout, low westward sun, warm irradiance, stable input hashes and zero ray/guide/traffic-AS work in raster mode. All 13 stills passed [visual review](validation/v2.1/skyline/visual-review.json). That signed application passed [isolated working-directory sunset checks in both rendering modes](validation/v2.1/package-rendering/runs.json) and [native interaction checks](validation/v2.1/native-review.json). Offscreen timing does not establish native window frame rate.

The completed [render report](validation/v2.1/skyline/validation.json) records 38 checks and 13 stills at 1280×800 (64 samples for RT). [All 13 images were visually reviewed](validation/v2.1/skyline/visual-review.json). The [playback log](validation/v2.1/skyline/playback.txt) and [39,485-check raster regression](validation/v2.1/skyline/raster-regression.txt) retain their actual results. This historical evidence does not establish validation of version 2.1.1 or continuous motion along its revised routes.
