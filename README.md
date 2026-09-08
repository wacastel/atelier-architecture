# Atelier

A native Apple Silicon architectural walkthrough engine built with Swift, AppKit, SwiftUI, and Metal hardware ray tracing. Six locations share the same renderer, navigation system, animation controls, day/night lighting, and export tools:

- **Chicago North Side** — eight studies connecting Millennium Park, Old Town, North Avenue Beach, Lincoln Park Zoo, the conservatory and lily pool, Wrigleyville and Wrigley Field. Two four-minute flights connect Millennium Park to the zoo and the zoo to Wrigley, with mapped neighborhoods, beaches and harbors in the same resident world.
- **Museum Campus, Chicago** — eight studies of the Field Museum, Shedd Aquarium, Adler Planetarium and its original animated dome show, Soldier Field, Burnham Harbor boats and all four McCormick Place buildings. A continuous three-minute flight connects the Art Institute to the Field Museum; selected public interiors are walkable.
- **Chicago Lakefront** — eight views along the Magnificent Mile, the historic Water Tower and pumping station, Water Tower Place, the former John Hancock Center, Wrigley and Tribune towers, Buckingham Fountain, Grant Park, moored harbor boats and light traffic on Lake Shore Drive.
- **Millennium Park, Chicago** — eight views, reflective Cloud Gate with a walkable underside, Pritzker Pavilion, Crown Fountain, gardens, the detailed Art Institute and a continuous four-minute flight from Willis Tower through the park into the museum.
- **Willis Tower, Chicago** — eight views, the nine bundled tubes and their mapped setbacks, individually modeled curtain-wall panels and connections, Catalog entrance and roof garden, Skydeck at its published elevation, five transparent Ledge boxes, broadcast antennas, and mapped Loop surroundings.
- **Eiffel Tower, Paris** — nine views, detailed ironwork and rivets, observation terraces and visitor spaces, mapped gardens and nearby buildings, the Seine, Pont d’Iéna, and a river cruiser.

Nearby layouts use bundled OpenStreetMap snapshots. Architectural photographs, published dimensions, and aerial/satellite references inform the models. These are detailed architectural reconstructions, not surveyed digital twins: interiors, façade treatments, vegetation, boats, and lighting contain authored interpretations. [North Side and maps](docs/NORTH-SIDE.md) · [Old Town and beach-house references](docs/NORTH-SIDE-LANDMARKS.md) · [Lincoln Park Zoo](docs/LINCOLN-PARK-ZOO.md) · [Wrigley Field](docs/WRIGLEY-FIELD.md) · [Museum Campus and maps](docs/MUSEUM-CAMPUS.md) · [Field and Shedd interiors](docs/MUSEUM-BUILDINGS.md) · [Adler and the dome show](docs/ADLER.md) · [McCormick Place](docs/MCCORMICK-PLACE.md) · [Lakefront and map methodology](docs/LAKEFRONT.md) · [Magnificent Mile landmarks](docs/MAGNIFICENT-MILE.md) · [Wrigley and Tribune](docs/MAGNIFICENT-GATEWAY.md) · [Park methodology](docs/MILLENNIUM.md) · [Art Institute](docs/ART-INSTITUTE.md) · [Willis methodology](docs/WILLIS.md) · [Chicago map data and references](docs/CHICAGO.md) · [Paris methodology](docs/PARIS.md).

![Wrigley Field and Wrigleyville under the lights](docs/images/North-Side-Wrigley-Night.png)

![Seasonal colored lights at Lincoln Park Zoo](docs/images/North-Side-Zoo-Night.png)

## Run

Double-click **Launch Atelier.command**, or run:

```sh
./scripts/build-app.sh
open dist/Atelier.app
```

The launcher rebuilds when source or assets have changed. The packaged app contains both cities and works without network access or the source directory. It opens at Chicago North Side. Use the location menu or **L** to cycle between Eiffel Tower, Willis Tower, Millennium Park, Chicago Lakefront, Museum Campus and Chicago North Side. All five Chicago destinations reuse one resident world and its GPU/navigation resources; switching to Paris loads its independent scene.

Requires macOS 14 or later, the Xcode Command Line Tools with Swift 5.10 or newer to build, and a Metal ray-tracing capable GPU. Hardware validation is performed on this Mac Studio's M3 Ultra with 512 GB unified memory. The build creates an ad-hoc signed, native arm64 app; it is not notarized for distribution to other computers.

## Explore

The opening idle cycle visits each view in order during daytime, switches to night after the last view, visits the sequence again, then returns to day. At 1×, each view lasts 20 seconds. The idle speed controls both the gentle camera motion and the dwell time, independently of walkthrough pace. Selecting a view holds it with gentle motion; **Play** starts that view's own walkthrough. Routes last 56–240 seconds; North Side routes last 120–240 seconds. The **Chicago connecting flights** menu offers **Willis → Park → Art Institute** (four minutes), **Art Institute → Field Museum** (three minutes), **Millennium Park → Lincoln Park Zoo** (four minutes), and **Lincoln Park Zoo → Wrigley Field** (four minutes), preserving the chosen day/night lighting.

**Chicago Demo / C** starts all 40 full Chicago routes in order: Willis Tower → Millennium Park → Chicago Lakefront → Museum Campus → Chicago North Side, eight routes at each destination. One pass lasts **66 minutes 36 seconds at 1×**. Starting preserves the chosen lighting and walkthrough pace; after each complete Chicago pass, the sequence returns to Willis with the opposite day/night lighting. **Space** pauses and resumes without leaving the demo. **Stop Chicago Demo / C** ends it while holding the current camera pose. Manual view or location selection, idle cycling, and manual navigation leave the demo. The five Chicago destinations keep the same resident city throughout. [Demo instructions](docs/DEMO.md).

Click visible landmark or building geometry to focus it, then drag to orbit and use a mouse wheel or two-finger trackpad scroll to move closer or farther away. Clicking the same object again, clicking sky, or pressing **Escape** releases focus. Selecting a focus takes manual control of the camera. [Focus controls and picking limits](docs/FOCUS.md).

| Control | Action |
| --- | --- |
| Location menu / **L** | Cycle all six locations; begin a fresh daytime idle cycle |
| View card / **1–8** (Chicago), **1–9** (Paris) | Select and hold a view |
| **↑ / ↓** | Previous / next view; stop cycling |
| **Idle Play / Idle Pause**, or **I** | Resume the view cycle / hold the current view |
| **[ / ]** | Decrease / increase idle speed: 0.25×, 0.5×, 1×, 2×, 4× |
| **Play / Space** | Start, pause, or resume the selected walkthrough |
| **Chicago Demo / C** | Start all 40 Chicago routes / stop and hold the current pose |
| **← / →** | Rewind / fast forward; distinct presses cycle 2×, 4×, 8× |
| **Pace / timeline** | Set walkthrough pace independently / seek |
| **N / Moon button** | Toggle day/night without restarting or resuming the animation |
| **Lighting settings** | Choose warm daylight, neutral daylight or night; idle wraps alternate day/night |
| **Full-screen button / ⌃⌘F** | Enter / leave native macOS full-screen mode |
| Window titlebar / edges | Move / resize; hold camera and scene clocks during the gesture, then resume without a time jump |
| Click visible geometry | Focus a landmark or building; click the same object or sky to release |
| Mouse drag | Orbit a focused object; otherwise look around manually |
| **WASD / Q–E / Shift** | Manual movement / vertical flight / faster movement; movement clears focus |
| Mouse wheel / two-finger scroll | Zoom toward or away from a focused object; otherwise adjust manual movement speed |
| **H / ? / Esc** | Hide interface / show controls / clear focus, release keys and close help |
| **⌘R / ⌘⇧S** | Return to the location’s opening view / save a render to Pictures/Atelier |

Manual movement takes control of the camera; local traffic continues. Pausing a walkthrough freezes both its camera and traffic clock. Walk mode uses floor support and collision checks; Fly mode allows unrestricted inspection. Individual routes are authored architectural studies. Millennium Park’s eighth route connects Willis Tower, the park and an interpreted Modern Wing gallery without a scene cut or teleport. Full-screen and ordinary window sizes retain the same rendering and input controls. The view cards scroll horizontally when needed.

Seeking and the arrow-key shuttles stay within the current route, including during the Chicago demo. A shuttle pauses at the route's beginning or end; **Space** resumes forward at a rewound beginning, or continues to the next demo route from a forward endpoint. Lighting and pace changes keep the demo active. Lighting changes, window moves, resizing and full screen retain an object focus; moving or resizing the window freezes both camera animation and the shared traffic/show clock until the gesture ends.

[Robie House and a Hyde Park connection](docs/NEXT-CHICAGO-LANDMARK.md) is a proposal for a future addition; it is not included in the current scene.

## Rendering

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

## Render and record

The command-line interface uses the same scenes and shaders as the application. `--location` defaults to `paris` for compatibility with earlier export commands; choose `chicago` for Willis Tower, `millennium` for the park and museum, `lakefront` for the Magnificent Mile, Grant Park and harbors, `campus` for Museum Campus and McCormick Place, or `northside` for Old Town, Lincoln Park and Wrigley Field. View numbers are zero-based on the command line.

```sh
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

# Full scene self-tests; Chicago destinations share geometry but use distinct cameras.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location paris --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location chicago --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location millennium --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location lakefront --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location campus --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location northside --self-test

# Actual Bean motion against independent higher-sample references.
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location millennium \
  --motion-test output/millennium-motion --frames 48 \
  --width 960 --height 600 --samples 4 --reference-samples 128
```

Playback checks cover all six destinations in both cities, camera clearance and floor support, eight/nine-view wrapping, manual selection, independent speeds, transport, location changes, the full 90/120/150/180/240-second routes, day/night hotkey state preservation and alternating day/night passes. Landmark checks validate finite geometry, Cloud Gate’s envelope and underside headroom. Light-grid CPU checks exercise conservative candidate coverage and fallbacks; GPU checks compare indexed and linear lighting and include negative controls. Sampling checks exercise the actual Sobol and polished-GGX shader routines. The application self-test also renders landscape, portrait, and wide viewports and checks their camera aspect ratios.

With `--location northside`, the motion command checks Old Town brickwork, beach-house shadows, the Nature Boardwalk, ZooLights-inspired night lighting, Conservatory glass and the Wrigley field by day/night. With `--location campus`, the motion command checks the Field hall, Shedd tanks, Adler gallery and changing dome show, Burnham Harbor at night and McCormick Place. With `--location lakefront`, the motion command checks Hancock braces, historic stonework, the fountain at night, harbor reflections and moving traffic. With `--location millennium`, it runs the Bean’s idle/orbit, night reflection and underside cases. Use `--motion-case cloud-gate-orbit` to select one case, or `--lighting 2` for the nighttime cases. Reports compare image error and motion-compensated temporal residuals against independent higher-sample references; they do not certify every camera or quality setting as noiseless. Quality and frame-rate measurements are reported separately from these reproduction commands.

The repository bundles raw map snapshots and derived geometry for all six destinations. The Millennium snapshot is a separate park/museum extract anchored to the same coordinate origin as Willis Tower. These commands regenerate the bundled databases offline from their recorded inputs:

```sh
python3 scripts/prepare-paris-context.py
python3 scripts/prepare-chicago-context.py
python3 scripts/prepare-millennium-context.py
```

The lakefront, Museum Campus and North Side derivatives use the pinned GIS dependency and exact offline reproduction commands in [lakefront documentation](docs/LAKEFRONT.md), [Museum Campus documentation](docs/MUSEUM-CAMPUS.md) and [North Side documentation](docs/NORTH-SIDE.md). See the location documentation for input dates, dependencies, coordinate systems, and known approximations. Reference images inform authored detail; the map-preparation scripts reproduce map geometry, not the photographic interpretation.

Map data **© OpenStreetMap contributors**, available under the **Open Database License (ODbL)**. Attribution is visible in the app and exported video captions. Original and derived map databases retain their ODbL notices under `Resources/Paris/`, `Resources/Chicago/`, `Resources/Millennium/` and the lakefront, Museum Campus and North Side resources. Reference photographs and satellite images are consulted visually and are not redistributed as textures or project assets.
