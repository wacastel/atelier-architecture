# Atelier

A native Apple Silicon architectural walkthrough engine built with Swift, AppKit, SwiftUI, Metal hardware ray tracing and a fast raster mode. Eight locations share the same renderer, navigation system, animation controls, day/night lighting, and export tools:

- **Robie House and Hyde Park, Chicago** — seven architectural studies of Frank Lloyd Wright’s Prairie house and a six-minute connecting flight from McCormick Place through the south lakefront and Hyde Park. The house and the intervening neighborhoods extend the same resident Chicago world.
- **Chicago North Side** — eight studies connecting Millennium Park, Old Town, North Avenue Beach, Lincoln Park Zoo, the conservatory and lily pool, Wrigleyville and Wrigley Field. Two four-minute flights connect Millennium Park to the zoo and the zoo to Wrigley, with mapped neighborhoods, beaches and harbors in the same resident world.
- **Museum Campus, Chicago** — eight studies of the Field Museum, Shedd Aquarium, Adler Planetarium and its original animated dome show, Soldier Field, Burnham Harbor boats and all four McCormick Place buildings. A continuous three-minute flight connects the Art Institute to the Field Museum; selected public interiors are walkable.
- **Chicago Lakefront** — eight views along the Magnificent Mile, the historic Water Tower and pumping station, Water Tower Place, the former John Hancock Center, Wrigley and Tribune towers, Buckingham Fountain, Grant Park, moored harbor boats and light traffic on Lake Shore Drive.
- **Millennium Park, Chicago** — eight views, reflective Cloud Gate with a walkable underside, Pritzker Pavilion, Crown Fountain, gardens, the detailed Art Institute and a continuous four-minute flight from Willis Tower through the park into the museum.
- **Chicago Skyline** — eight two-minute aerial studies of the existing city, with authored daylight, golden-hour, sunset and night presentations. It follows Willis Tower in the Chicago demo and uses the same resident geometry. [Skyline references and lighting](docs/SKYLINE.md).
- **Willis Tower, Chicago** — eight views, the nine bundled tubes and their mapped setbacks, individually modeled curtain-wall panels and connections, Catalog entrance and roof garden, Skydeck at its published elevation, five transparent Ledge boxes, broadcast antennas, and mapped Loop surroundings.
- **Eiffel Tower, Paris** — nine views, detailed ironwork and rivets, observation terraces and visitor spaces, mapped gardens and nearby buildings, the Seine, Pont d’Iéna, and a river cruiser.

Nearby layouts use bundled OpenStreetMap snapshots. Architectural photographs, published dimensions, and aerial/satellite references inform the models. These are detailed architectural reconstructions, not surveyed digital twins: interiors, façade treatments, vegetation, boats, and lighting contain authored interpretations. [Robie House architecture](docs/ROBIE-HOUSE.md) · [Hyde Park and the south lakefront](docs/HYDE-PARK.md) · [North Side and maps](docs/NORTH-SIDE.md) · [Old Town and beach-house references](docs/NORTH-SIDE-LANDMARKS.md) · [Lincoln Park Zoo](docs/LINCOLN-PARK-ZOO.md) · [Wrigley Field](docs/WRIGLEY-FIELD.md) · [Museum Campus and maps](docs/MUSEUM-CAMPUS.md) · [Field and Shedd interiors](docs/MUSEUM-BUILDINGS.md) · [Adler and the dome show](docs/ADLER.md) · [McCormick Place](docs/MCCORMICK-PLACE.md) · [Lakefront and map methodology](docs/LAKEFRONT.md) · [Magnificent Mile landmarks](docs/MAGNIFICENT-MILE.md) · [Wrigley and Tribune](docs/MAGNIFICENT-GATEWAY.md) · [Park methodology](docs/MILLENNIUM.md) · [Art Institute](docs/ART-INSTITUTE.md) · [Willis methodology](docs/WILLIS.md) · [Chicago map data and references](docs/CHICAGO.md) · [Paris methodology](docs/PARIS.md).

![Robie House in its mapped Hyde Park setting](docs/images/Robie-House-Day.png)

![Robie House living room and central hearth](docs/images/Robie-House-Living-Room.png)

![Wrigley Field and Wrigleyville under the lights](docs/images/North-Side-Wrigley-Night.png)

![Seasonal colored lights at Lincoln Park Zoo](docs/images/North-Side-Zoo-Night.png)

## Run

Double-click **Launch Atelier.command**, or run:

```sh
./scripts/build-app.sh
open dist/Atelier.app
```

The launcher rebuilds when source or assets have changed. The packaged app contains both cities and works without network access or the source directory. Version 2.1.0 opens at Willis Tower. Use the location menu or **L** to cycle between Eiffel Tower, Willis Tower, Chicago Skyline, Millennium Park, Chicago Lakefront, Museum Campus, Chicago North Side and Robie House. All seven Chicago destinations reuse one resident world and its GPU/navigation resources; switching to Paris loads its independent scene. During Chicago Demo, **L** cycles only the Chicago destinations and continues playback there.

Requires macOS 14 or later, the Xcode Command Line Tools with Swift 5.10 or newer to build, and a Metal ray-tracing capable GPU. Hardware validation is performed on this Mac Studio's M3 Ultra with 512 GB unified memory. The build creates an ad-hoc signed, native arm64 app; it is not notarized for distribution to other computers.

## Explore

The opening idle cycle visits each view in order during daytime, switches to night after the last view, visits the sequence again, then returns to day. At 1×, each view lasts 20 seconds. The idle speed controls both the gentle camera motion and the dwell time, independently of walkthrough pace. Outside Chicago Demo, selecting a view holds it with gentle motion; **Play** starts that view's own walkthrough. Routes last 56–360 seconds. Robie House has seven two-minute studies and a six-minute connecting flight. The **Chicago connecting flights** menu offers **Willis → Park → Art Institute** (four minutes), **Art Institute → Field Museum** (three minutes), **Millennium Park → Lincoln Park Zoo** (four minutes), **Lincoln Park Zoo → Wrigley Field** (four minutes), and **McCormick Place → Robie House** (six minutes), preserving the chosen day/night lighting.

**Chicago Demo / C** starts at a random view in a random Chicago location, then plays sequentially through Willis Tower → Chicago Skyline → Millennium Park → Chicago Lakefront → Museum Campus → Chicago North Side → Robie House. Each destination has eight routes; one complete **56-route pass lasts 102 minutes 36 seconds at 1×**. Starting preserves both pace preferences. Skyline views use their authored lighting during the automatic presentation; a manual lighting override holds for the current pass and resets at the next complete idle/demo cycle. The demo changes day/night when it wraps from Robie House’s final route to Willis Tower’s first route. A random opening partway through the sequence reaches that boundary before its first complete pass.

Selecting any Chicago location or view keeps the demo active and begins that route at normal forward playback. **↑ / ↓**, or the demo’s previous/next buttons, cross location boundaries: the last view advances to the first view in the next location, and the first view goes back to the final view in the previous location. A full-city wrap in either direction changes day/night. **Space** pauses and resumes; **Stop Chicago Demo / C** exits while holding the current pose. Selecting Paris, starting idle cycling, focusing an object, or taking manual camera control leaves the demo. [Demo instructions](docs/DEMO.md).

Click visible landmark or building geometry to focus it, then drag to orbit and use a mouse wheel or two-finger trackpad scroll to move closer or farther away. Clicking the same object again, clicking sky, or pressing **Escape** releases focus. Selecting a focus takes manual control of the camera. [Focus controls and picking limits](docs/FOCUS.md).

| Control | Action |
| --- | --- |
| Location menu / **L** | Choose a destination; during demo, L cycles only Chicago and keeps playback active |
| View card / **1–8** (Chicago), **1–9** (Paris) | Select and hold a view; during demo, begin its walkthrough and continue sequencing |
| **↑ / ↓** | Previous / next view; during demo, cross location boundaries and continue playback |
| **Idle Play / Idle Pause**, or **I** | Resume the view cycle / hold the current view |
| **[ / ]** | Decrease / increase idle speed: 0.25×, 0.5×, 1×, 2×, 4× |
| **Play / Space** | Start, pause, or resume the selected walkthrough |
| **Chicago Demo / C** | Start the 56-route Chicago sequence at a random location/view / stop and hold the current pose |
| **← / →** | Rewind / fast forward; distinct presses cycle 2×, 4×, 8× |
| **Pace / timeline** | Set walkthrough pace independently / seek |
| **N / Moon button** | Toggle day/night without restarting or resuming the animation |
| **Lighting settings** | Choose warm daylight, neutral daylight, sunset or night; Skyline also has authored view presets |
| **Full-screen button / ⌃⌘F** | Enter / leave native macOS full-screen mode |
| Window titlebar / edges | Move / resize; hold camera and scene clocks during the gesture, then resume without a time jump |
| Click visible geometry | Focus a landmark or building; click the same object or sky to release |
| Left mouse drag | Pan the city under the pointer; orbit when an object is focused |
| Shift + left mouse drag / right mouse drag | Look around; orbit when an object is focused |
| **M / map button** | Show/hide the map; S/M are picture-in-picture and L fills the app window; drag moves the real camera, click chooses an overhead destination |
| **F / speed menu / − / +** | Toggle Walk/Fly; choose or step the fixed flight presets from 8 to 800 m/s |
| **R / renderer badge** | Toggle ray tracing and fast raster at the same camera position |
| **WASD / Q / E / Shift** | Manual movement / fly up / fly down / 3× speed boost; movement clears focus |
| Mouse wheel / two-finger scroll | Zoom toward or away from a focused object; otherwise step the fixed flight-speed presets |
| **H / ? / Esc** | Hide interface / show controls / clear focus, release keys and close help |
| **⌘R / ⌘⇧S** | Return to the location’s opening view / save a render to Pictures/Atelier |

The north-up map uses the existing offline data and shows camera position and heading. Small and Medium are picture-in-picture overlays; Large fills the application window. Its aspect-preserving map fills the canvas without letterbox gutters. Zoom, drag and the Places menu expose the full north–south corridor. Clicking a landmark label or mapped position places the camera above that point with roof clearance and enters manual Fly mode, preserving day/night. It selects the nearest architectural study for the Play button and reuses the resident Chicago world. Dragging translates the map and real 3D camera together on each input event; releasing a drag does not also trigger a click. Use Small or Medium to see the 3D viewport moving beneath it. The map covers the modeled corridor; peripheral context remains less detailed. [Map behavior and limits](docs/NAVIGATION-MAP.md).

Flight starts at 400 m/s. The speed menu, minus/plus keys and unfocused scrolling step through 8, 30, 80, 180, 400 and 800 m/s; Shift temporarily triples the chosen speed. Movement uses elapsed time, so a low rendering frame rate no longer reduces travel speed proportionally. Left dragging pans across the ground plane; Shift-left dragging or right dragging changes the viewing direction. Q flies up and E flies down. Focused-object orbit and zoom remain available.

Manual movement takes control of the camera; local traffic continues. Pausing a walkthrough freezes both its camera and traffic clock. Walk mode uses floor support and collision checks; Fly mode allows unrestricted inspection. Individual routes are authored architectural studies. Millennium Park’s eighth route connects Willis Tower, the park and an interpreted Modern Wing gallery without a scene cut or teleport. Full-screen and ordinary window sizes retain the same rendering and input controls. The view cards scroll horizontally when needed.

Seeking and the arrow-key shuttles stay within the current route, including during the Chicago demo. A shuttle pauses at the route's beginning or end; **Space** resumes forward at a rewound beginning, or continues to the next demo route from a forward endpoint. Lighting and pace changes keep the demo active. Skyline's manual lighting override holds for the current pass; the next complete idle/demo cycle resumes the alternating authored/night passes. Lighting changes, window moves, resizing and full screen retain an object focus; moving or resizing the window freezes both camera animation and the shared traffic/show clock until the gesture ends.

Robie House’s eighth view connects McCormick Place to the house through 31st Street Harbor, the Oakwood lakefront, Promontory Point and Hyde Park. The full six-minute flight stays in the shared Chicago world and finishes at the house’s opening bookmark.

## Music

Eight original ambient pieces form one shared playlist, with a distinct opening piece assigned to each location. Soft piano, pads and plucks accompany the views. Music starts enabled at volume 0.16 on first use; enable and volume preferences persist. A location change selects its opening piece with a three-second crossfade, and tracks advance through the shared playlist before wrapping. Turning music off fades and pauses it; turning it on resumes. Volume zero mutes while playback continues. The native player does not add an audio track to CLI movie exports. [Composition, playback and evidence](docs/AMBIENT-MUSIC.md).

## Rendering

**R** switches between ray tracing and **Fast Raster**, preserving the current camera, lighting and playback. Raster draws the same city and moving traffic using a depth buffer, frustum culling, direct lighting, procedural materials, glass and approximate environment reflections. It submits no ray-tracing or surface-guide dispatches and no traffic acceleration-structure updates per frame. Four-sample anti-aliasing smooths fine geometry edges on this Mac (with a lower-sample fallback on other devices). It omits traced shadows, local reflections, refraction and indirect lighting; subpixel detail can still alias. It is useful for fast navigation, while ray tracing retains the more accurate architectural lighting. The initial acceleration structures are still built so switching back is immediate; raster does not eliminate the resident scene or startup memory cost.

A **legacy version 2.0** matched 1280 × 850 offscreen test on this M3 Ultra measured median GPU frame times of **13–14 ms in raster versus 76–90 ms in ray tracing for the Robie exterior**, and **about 14 ms versus 295–297 ms in the living room**, using four ray samples and three bounces. These are bounded historical GPU measurements, not a version 2.1 measurement or native app FPS guarantee. [Exact validation and limitations](docs/VALIDATION.md#version-20-navigation-and-render-modes).

The engine traces the actual modeled triangles using Metal acceleration structures, GGX reflections, direct-light shadow rays, and multibounce lighting. Cloud Gate’s polished shell and concave underside reflect the shared Chicago scene, including reflected reflections; they do not use a painted skyline. Water uses filtered analytic ripple normals and dielectric Fresnel reflections. Selected Chicago glazing uses thin-sheet transmission and reflection; the first camera pane traces both branches to reduce movement noise. [Glass implementation and limits](docs/GLASS.md).

Fast Owen-scrambled Sobol samples distribute camera, sun, and material samples across each pixel’s sampling domain. Pure metals sample their reflective GGX lobe directly, and a numerically stable GGX evaluation retains the narrow highlights of polished steel. `--random-sampling` restores independent random samples for controlled comparisons.

Selective path regularization broadens difficult secondary glossy reflections after an ordinary surface scatter, reducing bright motion speckles while preserving directly viewed materials and first reflections through perfect glass. A chain of very smooth metal reflections, such as Cloud Gate’s underside, retains its authored lobes until an ordinary scatter occurs. Those metal reflections still use finite GGX lobes. Regularization introduces a documented lighting bias; `--no-regularization` disables it for comparisons. [Method and GPU checks](docs/MOTION.md#selective-glossy-path-regularization).

A conservative spatial light grid restricts local-light evaluation to candidates whose declared finite range can reach the current cell. Candidate lists retain scene order, and the renderer falls back to the complete linear list if a grid cannot be built within its bounds. `--linear-lights` selects that baseline explicitly. Museum interior fixtures can remain on during daytime while the sun and sky retain daytime lighting; architectural exterior fixtures switch on at night.

Moving cars and buses occupy a small, separate Metal acceleration structure. Only the traffic geometry and its top-level instance structure are updated; the city remains resident. Absolute scene time reproduces the same vehicle positions during scrubbing and export. Moving headlights illuminate and shadow the actual roadway. Local reactive guides reject stale vehicle, reflection and nearby lighting history while preserving valid history on unrelated surfaces.

Motion reconstruction uses deterministic world position, depth, normal, material and albedo guides, rejects stale history, and filters within compatible surfaces. Spatial passes retain temporal sample confidence to avoid repeatedly softening accumulated roof seams and shadow detail. Distant night coverage, emissive windows, and mixed reflection/transmission require conservative history handling. Fine sampling grain can remain in reflective water, thin detail, and moving glass. Paused views progressively accumulate samples. [Motion reconstruction](docs/MOTION.md).

| Quality | Maximum render width | Path interactions | New samples/frame |
| --- | ---: | ---: | ---: |
| Interactive | 960 px | 2 | 4 |
| Balanced | 1440 px | 3 | 4 |
| Ultra | 2560 px | 5 | 8 |

Render dimensions preserve the actual drawable's aspect ratio, including portrait windows and full-screen displays; both axes are bounded by the renderer's 8192-pixel limit. GPU memory usage is scene- and viewport-dependent. Unified memory and native ray-tracing acceleration are used directly; allocating all 512 GB is unnecessary for these models.

## Building more city sections

The reusable [city-building guide (Markdown)](docs/CITY-BUILDING-GUIDE.md), [offline HTML edition](docs/city-building-guide.html) and [PDF edition](docs/City-Building-Guide.pdf) document research, map preparation, architectural modeling, shared-world integration, eight-view routes, lighting, performance checks, release packaging and a starter brief for a fresh context window.

## Render and record

The command-line interface uses the same scenes and shaders as the application. `--location` defaults to `paris` for compatibility with earlier export commands; choose `chicago` for Willis Tower, `skyline` for the aerial studies, `millennium` for the park and museum, `lakefront` for the Magnificent Mile, Grant Park and harbors, `campus` for Museum Campus and McCormick Place, `northside` for Old Town, Lincoln Park and Wrigley Field, or `robie` for Robie House and its south lakefront connection. View numbers are zero-based on the command line.

Add `--raster` to render, gallery, video or self-test commands for the fast renderer. Ray sample counts are ignored in raster mode; the temporal ray-tracing benchmark intentionally requires ray tracing.

```sh
# Complete six-minute flight from McCormick Place to Robie House.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location robie \
  --video output/McCormick-Place-to-Robie-House.mp4 --single-view --stop 7 \
  --seconds 360 --fps 24 --width 1920 --height 1080 --samples 16

# Seven house studies and the connecting route, with nighttime lighting.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location robie \
  --gallery output/robie-night --lighting 2 --samples 256

# The full four-minute route from the zoo through northern harbors to Wrigley.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location northside \
  --video output/Zoo-to-Wrigley.mp4 --single-view --stop 6 \
  --seconds 240 --fps 24 --width 1920 --height 1080 --samples 16

# All eight North Side scenes with reference-informed night lighting.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location northside \
  --gallery output/northside-night --lighting 2 --samples 256

# Full southbound connecting flight, including arrival inside Stanley Field Hall.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location campus \
  --video output/Art-Institute-to-Field-Museum.mp4 --single-view --stop 0 \
  --seconds 180 --fps 24 --width 1920 --height 1080 --samples 16

# Original planetarium show, with the same clock as camera, pause and rewind.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location campus \
  --video output/Adler-Dome-Show.mp4 --single-view --stop 4 \
  --seconds 180 --fps 24 --width 1920 --height 1080 --samples 16

# All eight new lakefront views and their Michigan Avenue landmarks.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location lakefront \
  --gallery output/lakefront-day --width 1920 --height 1200 --samples 128

# The full two-minute Lake Shore Drive flight, with deterministic moving traffic.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location lakefront \
  --video output/Lake-Shore-Drive-Night.mp4 --single-view --stop 7 \
  --lighting 2 --seconds 120 --fps 24 --width 1920 --height 1080 --samples 16

# Complete continuous flight at ordinary 1× speed, from tower to museum.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location millennium \
  --video output/Chicago-Park-Museum-Flyby.mp4 --single-view --stop 7 \
  --seconds 240 --fps 24 --width 1920 --height 1080 --samples 16

# All eight park/museum bookmarks, with actual traced nighttime reflections.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location millennium \
  --gallery output/millennium-night --lighting 2 --samples 256

# Geometry, GPU dispatch, accumulation, viewport resizing, and importer checks.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago --self-test

# All eight Chicago viewpoints, including a night gallery.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago \
  --gallery output/chicago-day --width 1920 --height 1200 --samples 128
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago \
  --gallery output/chicago-night --lighting 2 --width 1920 --height 1200 --samples 256

# Eight full routes compressed into twelve-second chapters (96 seconds total).
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago \
  --video output/Willis-Walkthrough.mp4 --seconds 96 --fps 24 \
  --width 1920 --height 1080 --samples 12

# A complete 56-second night route at its normal playback speed.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago \
  --video output/Willis-Night-Route.mp4 --single-view --stop 7 --lighting 2 \
  --seconds 56 --fps 24 --width 1920 --height 1080 --samples 16

# Inspect a route at a specific time, or export gentle idle motion with --idle.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago \
  --render output/Willis-Ledge.png --stop 5 --at 28 --samples 256

# Keep the complete Paris scene and its nine-view, 108-second export.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location paris \
  --video output/Paris-Walkthrough.mp4 --seconds 108 --fps 24 --samples 12
```

`--camera x,y,z --target x,y,z --fov 60` overrides a still camera. `--raw` disables reconstruction in moving previews and video comparisons; still exports already use unfiltered progressive radiance followed by exposure and tone mapping. `--obj building.obj --scale 1 --render image.png` imports another building for still rendering; imported materials have the limits described in [engine documentation](docs/ENGINE.md). Run `--help` for all options. Video exports require a new filename and never overwrite an existing recording.

Check an existing movie’s complete decoding, frame count and uniform presentation timestamps with:

```sh
python3 scripts/validate-video-timing.py output/Chicago-Park-Museum-Flyby.mp4 \
  --seconds 240 --fps 24 --report output/flyby-timing.json
```

Generated videos, high-resolution renders, build products and local reports stay in `output/` or `dist/` and are excluded from Git. [Demo notes](docs/DEMO.md) · [validation](docs/VALIDATION.md).

## Verify and reproduce

Version **2.1.0 (build 13)** has completed scoped [native interaction checks](docs/validation/v2.1/native-review.json), [signature and bundled-resource verification](docs/validation/v2.1/package.json), and [Skyline CPU/GPU review](docs/SKYLINE.md#validation). Native checks observed the Willis/400 m/s default, all map sizes and live camera dragging, resize/full-screen behavior, R while T stayed inactive, fixed speed selection, music controls and natural track advancement, authored Skyline lighting and a demo location boundary. The [packaged Skyline sunset self-tests](docs/validation/v2.1/package-rendering/runs.json) also passed in ray-tracing and raster modes from an isolated working directory. The catalog contains 56 Chicago routes and 65 routes including Paris's nine.

Sustained Q/E movement and Shift-held dragging have CPU and event-wiring coverage; the native automation could not reliably hold those inputs. Audio decoding and transport were checked, but subjective listening quality was not assessed. Older performance measurements remain labeled by release; the commands below describe reproducible checks rather than claiming every historical test was rerun.

```sh
# CPU: map geometry, landmark mesh, light-grid coverage, and camera controls.
python3 scripts/validate-paris-context.py
python3 scripts/validate-chicago-context.py
python3 scripts/validate-millennium-context.py
./scripts/validate-millennium-geometry.sh
./scripts/validate-magnificent-mile.sh
./scripts/validate-magnificent-gateway.sh
./scripts/validate-lakefront-geometry.sh
./scripts/validate-museum-campus-geometry.sh
./scripts/validate-museum-buildings.sh
./scripts/validate-mccormick.sh
./scripts/validate-north-side-geometry.sh
./scripts/validate-north-side-landmarks.sh
./scripts/validate-lincoln-park-zoo.sh
./scripts/validate-wrigley-field.sh
./scripts/validate-traffic.sh --cpu
./scripts/validate-light-grid.sh
./scripts/validate-playback.sh
./scripts/validate-navigation.sh

# GPU: real Metal kernels, glass, reconstruction, polished sampling, and lighting.
swift scripts/validate-metal.swift
swift scripts/validate-denoiser.swift
swift scripts/validate-temporal-detail.swift
./scripts/validate-adler.sh --gpu
swift scripts/validate-glass.swift
swift scripts/validate-regularization.swift
swift scripts/validate-sampling.swift
swift scripts/validate-atmosphere.swift
./scripts/validate-indexed-lighting.sh
./scripts/validate-traffic.sh
./scripts/validate-paired-motion.sh
./scripts/validate-large-geometry-gpu.sh

# Full scene self-tests; Chicago destinations share geometry but use distinct cameras.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location paris --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location millennium --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location lakefront --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location campus --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location northside --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location robie --self-test

# Actual Bean motion against independent higher-sample references.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location millennium \
  --motion-test output/millennium-motion --frames 48 \
  --width 960 --height 600 --samples 4 --reference-samples 128
```

The playback suite covers all eight destinations in both cities, camera clearance and floor support, eight/nine-view wrapping, manual selection, independent speeds, transport, location changes, the full 90/120/150/180/240/360-second routes, day/night hotkey state preservation and alternating day/night passes. Demo checks exercise every possible opening, reproducible seeded random starts, all Chicago next/previous boundaries, selection while paused or rewinding, preserved pace and lighting, and large elapsed-time jumps. Landmark checks validate finite geometry, Cloud Gate’s envelope and underside headroom. Light-grid CPU checks exercise conservative candidate coverage and fallbacks; GPU checks compare indexed and linear lighting and include negative controls. Sampling checks exercise the actual Sobol and polished-GGX shader routines. The application self-test also renders landscape, portrait, and wide viewports and checks their camera aspect ratios.

The default large-geometry GPU fixture checks production descriptor offsets and shader lookups across a vertex buffer larger than 4 GiB. It submits eight triangles in each of four separated sections, then probes four static sentinels and a traffic triangle beyond the boundary for correct hits, global IDs, vertices and materials. This bounded test covers 32 static triangles and one traffic triangle; full-city render checks are separate, and the fixture does not traverse every city triangle or each descriptor's full extent. `--legacy-sparse` and `--full-field` retain the original diagnostic modes.

With `--location northside`, the motion command checks Old Town brickwork, beach-house shadows, the Nature Boardwalk, ZooLights-inspired night lighting, Conservatory glass and the Wrigley field by day/night. With `--location campus`, the motion command checks the Field hall, Shedd tanks, Adler gallery and changing dome show, Burnham Harbor at night and McCormick Place. With `--location lakefront`, the motion command checks Hancock braces, historic stonework, the fountain at night, harbor reflections and moving traffic. With `--location millennium`, it runs the Bean’s idle/orbit, night reflection and underside cases. Use `--motion-case cloud-gate-orbit` to select one case, or `--lighting 2` for the nighttime cases. Reports compare image error and motion-compensated temporal residuals against independent higher-sample references; they do not certify every camera or quality setting as noiseless. Quality and frame-rate measurements are reported separately from these reproduction commands.

The repository bundles raw map snapshots and derived geometry for the two cities. Chicago Skyline reuses the existing Chicago datasets and geometry. The Millennium snapshot is a separate park/museum extract anchored to the same coordinate origin as Willis Tower. These commands regenerate the bundled databases offline from their recorded inputs:

```sh
python3 scripts/prepare-paris-context.py
python3 scripts/prepare-chicago-context.py
python3 scripts/prepare-millennium-context.py
```

The lakefront, Museum Campus, North Side and Hyde Park derivatives use the pinned GIS dependency and exact offline reproduction commands in [lakefront documentation](docs/LAKEFRONT.md), [Museum Campus documentation](docs/MUSEUM-CAMPUS.md), [North Side documentation](docs/NORTH-SIDE.md) and [Hyde Park documentation](docs/HYDE-PARK.md). See the location documentation for input dates, dependencies, coordinate systems, and known approximations. Reference images inform authored detail; the map-preparation scripts reproduce map geometry, not the photographic interpretation.

Map data **© OpenStreetMap contributors**, available under the **Open Database License (ODbL)**. Attribution is visible in the app and exported video captions. Original and derived map databases retain their ODbL notices under `Resources/Paris/`, `Resources/Chicago/`, `Resources/Millennium/` and the lakefront, Museum Campus, North Side and Hyde Park resources. Reference photographs and satellite images are consulted visually and are not redistributed as textures or project assets.
