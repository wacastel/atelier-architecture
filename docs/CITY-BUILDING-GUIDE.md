# Building a city section in Atelier

**A practical field guide for extending the shared architectural world**

Prepared 9 September 2026. Based on repository workflows through the 1.9.1 road correction, commit `91fd5b7`, with a 2.0 navigation/render-mode integration appendix. Figures retain their recorded release scope. Examples are not a promise that a future location will fit the same budget. Read current source, validation evidence and `--help` before applying them to a later release.

Atelier turns dated map data and inspected architectural references into original, metre-scale geometry, then tests that geometry in one navigable city. The aim is convincing architecture at walking distance, coherent surroundings in flight, and honest evidence about what is modeled and measured.

This guide is available as Markdown, an offline HTML document, and a printable PDF. All commands assume the repository root. On the development Mac that is `/Users/william/dev/architecture`. Paths in backticks are repository-relative.

## Contents

1. [Define the section and hand off context](#scope)
2. [Research a place and preserve the evidence](#research)
3. [Keep one coordinate system](#coordinates)
4. [Extend the resident world without duplicates](#world)
5. [Make roads, sidewalks and shorelines continuous](#transport)
6. [Spend detail on architecture people can inspect](#model)
7. [Author eight studies and a connecting flight](#routes)
8. [Prove geometry, navigation and controls](#cpu)
9. [Review images and measure motion](#motion)
10. [Protect renderer capacity and compare performance](#capacity)
11. [Package, reproduce and publish a release](#release)
12. [Start the next location in a fresh context](#starter)
13. [Extend the map and both rendering modes](#navigation)

**The working sequence**

Evidence and boundaries; mapped context; landmark geometry; routes and lighting; CPU checks; serial GPU review; signed package and recorded release.

The same Chicago scene currently supplies six destination menus. Paris is a separate world. A destination is a camera and playback entry point, not automatically another loaded city.

<!-- page -->
<a id="scope"></a>
## 1. Define the section and hand off context

Begin with a bounded geographical area and one architectural story. Name the main landmark, its surrounding blocks, the link to an existing destination, and the places a visitor must be able to enter. Reserve seven or eight focal studies before spending effort on distant detail. A connecting flight can occupy one of those eight slots, as it does at Robie House.

**Write a short scope note before implementation.** Include the requested date or restored condition, reference quality, intended interiors, known omissions, proposed world bounds, and a first budget. Distinguish features required for the tour from optional finishing work. Do not expand a road repair into a surveyed tunnel project merely because a bridge tag appears.

### Handoff checklist

- Record repository path, current commit, branch, dirty files and ownership of active edits. Run `git status --short`, `git branch --show-current`, and `git log -1 --oneline`.
- Read `README.md`, `docs/VALIDATION.md`, the neighboring location document, and the actual builder, route and context files. Older overview prose can lag behind source.
- Preserve accepted user decisions: geographic scope, eight views, interior access, day/night treatment, connecting endpoints, demo behavior and release authorization.
- Name source snapshots, their timestamps and SHA-256 hashes, authored exclusion masks, local transforms, and any deliberate grade interpretation.
- List tests already run with exact inputs and result paths. Distinguish a source check, a CPU mesh test, a packaged GPU check and an image someone actually inspected.
- State who owns the GPU, which process is running, what is frozen, and which source changes would invalidate existing evidence.
- Keep unresolved issues visible. Record rejected camera candidates and failed rendering experiments when they explain a remaining limitation.

### Divide work by stable interfaces

Useful independent work packages are map/context preparation, the landmark model, route/controller integration, and validation/documentation. Give the model a stable `Layout.point(_:)` transform and safe local camera coordinates early. Agree on context schema and the authored-site mask before either worker places trees or masonry.

Use one integration owner for shared files such as `ChicagoWorld.swift`, `ArchitectureLocation.swift`, `EngineController.swift`, and playback code. Parallel CPU reads and isolated component work are useful; concurrent edits to the same switch statement and overlapping GPU jobs make results harder to trust.

**Exit condition:** another collaborator can identify what to build, what to preserve, where the data came from, and how completion will be demonstrated without reconstructing the conversation.

<!-- page -->
<a id="research"></a>
## 2. Research a place and preserve the evidence

Use maps for position and topology, photographs for architectural character, and measured drawings or published dimensions for proportions. These sources answer different questions. A satellite mosaic does not establish an interior plan; a historic elevation may show a condition that restoration has since changed.

### A reference set that can support the model

- Obtain a dated OpenStreetMap extract containing building and building-part ways/relations, relevant roads and paths, parks, water, shorelines, docks and tree features. Include the entire flight corridor, not only the final landmark.
- Save the exact query and raw response under `scripts/data/`. Preserve the OSM database timestamp, source IDs, relation roles, tags and a SHA-256 digest. The Hyde Park example is `chicago-hyde-park-osm-2026-09-08.json`.
- Inspect actual satellite/aerial pixels to reconcile block orientation, roof massing, water boundaries, planted areas and access routes. Record the provider credit, viewer URL and viewing date; acquisition dates may vary within a mosaic.
- Inspect daytime, nighttime and close-detail photographs. Record specific observations: mullion rhythm, masonry joints, roof edges, soffits, entrance depth, lit window patterns and where darkness remains.
- Prefer the owner, architect, conservator, official park/harbor body, HABS/Library of Congress or published measured plans for decisive facts. Resolve conflicting dates and conditions explicitly.

### Write an evidence ledger

For each important feature, retain: **feature / source URL or source ID / inspected page or image / fact used / interpretation / confidence**. Example: Robie House's 86-foot-9-inch prow span comes from conservation/measured-plan references; individual brick placement, fixture powers and furniture arrangement remain authored interpretations. The source map fixes the site, not every roof pitch.

The Robie workflow and original reference links are in [ROBIE-HOUSE.md](ROBIE-HOUSE.md). The wider map, harbor, satellite and nighttime observations are in [HYDE-PARK.md](HYDE-PARK.md). Keep working reference imagery outside tracked assets unless its redistribution is separately permitted. The existing project does not bundle third-party photographs or satellite tiles as textures.

### Attribution travels with the data

Retain **© OpenStreetMap contributors** and the ODbL notice in raw/derived data, project documentation and visible map/export credits. Follow the [OSM attribution and license guidance](https://www.openstreetmap.org/copyright) for the medium being distributed. Keep imagery-provider credits separate from OSM provenance. Viewing an image does not make it a freely redistributable asset.

**Exit condition:** the model's major spatial and architectural decisions have traceable evidence, and estimated details are labeled before they become polished renders.

<!-- page -->
<a id="coordinates"></a>
## 3. Keep one coordinate system

Chicago uses the Willis Tower origin at latitude **41.878876**, longitude **-87.635918**. World units are metres: **+x east, +y up, +z south**. A latitude increase therefore makes z smaller. Use the existing projection for every extension; recentering a new district would break camera flights, reflections, traffic and picking.

```python
import math
LAT0, LON0 = 41.878876, -87.635918

def project(lat, lon):
    x = (lon - LON0) * 111320 * math.cos(math.radians(LAT0))
    z = (LAT0 - lat) * 111320
    return round(x, 3), round(z, 3)
```

This is the repository's local equirectangular approximation. Millimetre rounding stabilizes computation; it does not confer millimetre survey accuracy. Upper street grade is approximately zero. Lake Michigan is at y = -5.7 in this world, not an absolute geographic elevation datum.

### Separate local architecture from global placement

A landmark's `Layout` should expose its mapped center, orientation, floor elevations and a local-to-world transform. Robie's local origin is `(3309.7, 0, 9917.1)` with a roughly 1.15-degree block skew. `RobieHouseLayout.point(_:)` transforms both model geometry and route poses; tests also verify its inverse. One shared transform prevents a camera from quietly using a different rotation than the building.

### Make the derivative reproducible

The existing `scripts/prepare-hyde-park-context.py` reads saved inputs and previous derivatives offline, preserving earlier resources. It writes `Sources/ArchitectureEngine/Resources/HydePark/HydeParkContext.json`, including hashes, height sources, road policies and the authored mask. Use it as a schema and topology reference, not a generic command that fetches a new neighborhood.

```sh
python3 -m venv .venv-gis
.venv-gis/bin/python -m pip install 'shapely==2.1.2'
.venv-gis/bin/python scripts/prepare-hyde-park-context.py
.venv-gis/bin/python scripts/validate-hyde-park-context.py
```

These reproduce the existing Hyde Park derivative. For a new district, create a separately named preparer with explicit saved inputs and destination. Pin dependencies and record versions. Keep the app independent of Python and network access.

Preserve polygon holes, multipart relations and building-part provenance. A broad parent footprint must not become a second solid shell over detailed setbacks or a courtyard. Keep explicit tagged heights separate from storey-based conversions and estimates; record each conversion assumption.

**Exit condition:** known landmarks and connecting nodes align in the shared frame, and rerunning the derivative yields the same data and provenance.

<!-- page -->
<a id="world"></a>
## 4. Extend the resident world without duplicates

`ChicagoWorld.build()` creates one `EiffelBuilder`, adds the existing environments and landmarks, and returns a single `SceneData`. `ArchitectureLocation.world` maps every Chicago destination to `"chicago"`; its `build()` reaches the shared city through `WillisScene.build()`. `EngineController` reuses resident resources for Chicago location changes.

### Integrate a district through explicit layers

- Add a context loader and environment builder for the new offline derivative. Use existing palette and geometry APIs where they express the intended material and scale.
- Add the detailed landmark builder, then call both builders from `ChicagoWorld.swift` in the intended order. Do not build the whole city a second time inside a landmark.
- Register metadata, bookmarks, route dispatch, duration and walking-view sets in `ArchitectureLocation.swift`. Update CLI location parsing in `CommandLine.swift` and any enumerated test/source lists.
- Extend the actual focus catalog in `LandmarkFocus.swift` with named authored volumes or mapped footprints. Selection must relate to visible geometry, including courtyard holes.
- Add resource notices and documentation. `Package.swift` copies the `Resources` tree; the release still needs to prove the new file is present and loadable from the copied app.

### Reconcile overlapping source extracts

Before emitting geometry, compare OSM IDs with every prior resource that overlaps the new area. Handle relation members and parent building footprints, not only identical top-level way IDs. Preserve the established road/traffic node sequence when extending it. A connection should share an exact endpoint, not merely look close in an aerial image.

Reserve an **authored-site exclusion mask** for detailed grounds. Robie's example is x = 3288-3339, z = 9904-9928. Generic building shells, paths, trees and ground overlays must not fill its interiors or terraces. The same mask must guide context preparation and runtime suppression. Include a small, documented clearance margin where needed.

Keep existing terrain and water ownership explicit. Extend only uncovered land/water regions; subtract previously emitted coverage and preserve shoreline holes. Maintain deterministic seeds, and restore a builder's shared random state after local generation so adding a district does not reshuffle trees or materials elsewhere.

### Growth is a measured decision

Prefer the continuous Chicago world while geometry, light indices, navigation construction and representative rendering remain within tested limits. Split a remote district into another world only after measurements or scope justify the tradeoff; then describe the loading transition and omit a purported continuous flight through unloaded geometry.

**Exit condition:** one physical building occupies each authored site, previous resources remain accounted for, and a location switch changes the visitor's viewpoint without duplicating the city.

<!-- page -->
<a id="transport"></a>
## 5. Make roads, sidewalks and shorelines continuous

The 57th Street correction is a useful warning: independent rectangles along a curved path can overlap on the inside, leave wedges on the outside and carry sidewalks straight through junctions. Correct centerline coordinates alone do not prove correct visible road geometry.

### The corrected Hyde Park pattern

1. Sanitize path points and retain width, lane, bridge, layer and sidewalk provenance. Respect explicit one-lane tags and `sidewalk:both=separate`; do not generate a second sidewalk over a mapped one.
2. Form connected road strokes with flat end caps and bounded miter joins. Union compatible ground-level carriageways and reconcile coverage with retained roads.
3. Subtract carriageways from explicit pedestrian pavement. Subtract both from generated sidewalk bands, following a stated material precedence.
4. Node all material boundaries together on a common precision grid, polygonize the common faces and assign materials before triangulation. Independently rounding already-subtracted boundaries reintroduced thin overlaps in the first attempted fix.
5. Test the emitted triangle meshes, not just their input polygons. At large world coordinates, repeat winding checks with the actual Float32 arithmetic used by Swift.

The current Hyde Park transport resource uses 512-metre tiles, a 0.01-metre numeric grid and a miter limit of 2. Ground asphalt is y = 0.12; walking surfaces are y = 0.19. These are renderer conventions for this flat model, not surveyed road elevations. Its validated transport tops total 218,062 triangles under a 250,000-triangle component budget.

### Relative layers are not metres

Six short bridge-tagged sections once floated at y = 7 while adjoining paths stayed near zero. Their tags now remain in the derivative, but an explicit grade interpretation places the visible surface segments at adjoining model grade. The [Chicago Park District documents two pedestrian underpasses](https://www.chicagoparkdistrict.com/parks-facilities/57th-street-underpass-mural-artwork); this world still omits the depressed tunnel/approach geometry. Do not claim clearance or accurate underground reconstruction from this repair.

```sh
.venv-gis/bin/python scripts/validate-hyde-park-roads.py
.venv-gis/bin/python scripts/validate-hyde-park-roads.py \
  --negative-controls
```

The independent oracle checks actual coverage, disjoint material areas, Float32 winding, six adjoining crossings, lane widths, bend wedges and full highway tails. Its damaged-data controls restore the old kinds of defects. Coverage includes the new Lake Shore Drive centerline through z = 10927.527, beyond the base terrain's z = 10800 boundary; road markings must never outlive the asphalt below them.

**Exit condition:** ground, water, road and pavement surfaces have deliberate ownership, complete joins and verified visible coverage at both district boundaries and local junctions.

<!-- page -->
<a id="model"></a>
## 6. Spend detail on architecture people can inspect

Build the silhouette and physical rooms first: massing, slabs, roofs, openings, terraces and circulation. Test standing height and entrances before adding ornament. A beautiful facade does not compensate for a roof missing from the interior or a decorative beam occupying the walking aisle.

### Use distance and purpose to allocate detail

- **Focal geometry:** model features that alter silhouettes, cast nearby shadows or are approached in a route: masonry relief, mullions, joints, railings, structural braces, art-glass came and roof returns.
- **Nearby context:** preserve mapped footprints and roof massing; add windows, cornices, entrances, storefront depth and selected roof equipment where visitors see them.
- **Distant context:** reduce bays, floors represented by detail, roof props and vegetation complexity. The current code uses authored distance-based detail at build time; it is not a general streaming or automatic runtime-LOD system.
- **Navigation geometry:** inspect what `CollisionWorld` retains. Tiny visible ornament may be omitted from its BVH; meaningful slabs and barriers must survive. Rendered and navigation triangle counts are different budgets.

Use `EiffelBuilder` primitives and `SceneMaterial` deliberately. Smooth normals suit curved metal and foliage; hard architectural edges need appropriate face normals. Use actual geometry for close shadow-forming detail and filtered procedural patterns for economical surface variation. Repeated deterministic materials are preferable to a changing world-space pattern that makes window brightness crawl during movement.

### Light the place, including its darkness

Match the role and distribution of reference lights: warm practicals through glazing, restrained masonry washes, dock fixtures, readable entrances and occasional justified color. Pair visible emissive fixtures with bounded explicit lights when they must illuminate surrounding surfaces. Interior practicals can remain active by day; exterior accents follow night mode. Authored powers and ranges are not calibrated photometry.

Glossy metal, water and thin glass need enough surrounding geometry to reflect. Reuse the actual shared-world materials. In ray-tracing mode, Cloud Gate reflects modeled surroundings; water uses filtered analytic ripple normals and Fresnel response. Thin-sheet glass does not reproduce thick refracting tank volumes, caustics or fluid simulation.

### Keep a component budget

Robie's standalone house is a useful scoped example: 438,350 rendered triangles, 190 art-glass panels and 38 lights, under a 500,000-triangle house test cap. Hyde Park's separate context remains under its 7-million-triangle test cap. Treat these as recorded examples, not automatic allowances for every new landmark.

**Exit condition:** close studies reveal physical architectural detail, walking spaces stay usable, daytime and nighttime materials remain readable, and all estimates and incomplete interiors are documented.

<!-- page -->
<a id="routes"></a>
## 7. Author eight studies and a connecting flight

Pick focal points that reveal different architectural relationships, rather than eight nearly identical exterior angles. A useful sequence is: full composition, structural feature, landscape/approach, material detail, principal interior, secondary interior, roof or neighborhood overview, and a connecting flight.

`RobieScene.swift` supplies eight `TourStop` values. `RobieWalkthrough.swift` supplies duration, `walkingViews`, full-route `pose(view:seconds:)`, and gentle `idlePose(view:seconds:)`. Its first seven studies last 120 seconds; the McCormick connection lasts 360 seconds. These are examples, not a required duration for every location.

### Route construction rules

- Start at the exact bookmark pose. Use `CameraTrack.Key` and the existing bounded Hermite interpolation, with time, position, target and field of view. Clamp invalid or out-of-range time inputs consistently.
- Use local layout transforms for close architecture and mapped world coordinates along a connecting flight. Add intermediate keys near roofs, trees, bridge structures, stairs and doorway turns.
- Check the whole path, not only keyframes. Smooth interpolation can intersect geometry between safe endpoints. Walking routes need body clearance and supported floors; a flyover still needs intentional visual clearance.
- Keep idle motion much smaller and slower than the walkthrough. Robie's ground and interior idle shifts are centimeters, helping prevent a gentle sway from entering nearby walls or glass.
- End a connecting flight at a real destination bookmark. Robie's final flight key equals `RobieScene.stops[0].pose`; it does not approximate the arrival with a separate duplicate camera constant.

### Preserve the established playback contract

Manual view selection holds a softly animated view outside demo mode. Idle Play resumes the ordered cycle, switching day/night after each complete pass. Guided Play starts the current view's route. Walkthrough pace and idle speed stay independent.

Chicago Demo starts at a random Chicago location/view, then proceeds sequentially. Choosing a Chicago view or location keeps it running there. Previous/next crosses location boundaries; a full-city wrap changes day/night. Paris is excluded. Extend the actual demo routing and tests when adding a destination rather than relying on a hard-coded total from this guide.

Manual movement and object focus take camera control. Pausing freezes the common scene clock used by traffic and Adler's show; seeking and exporting use deterministic absolute time. Window moving/resizing must hold the camera and scene clocks, then resume without a catch-up jump.

**Exit condition:** each view has a clear purpose, its idle and full route are separately usable, and the connecting flight proves continuity in both geometry and playback.

<!-- page -->
<a id="cpu"></a>
## 8. Prove geometry, navigation and controls

Use small component checks to locate defects, then validate the complete world. A derivative can be geometrically valid while the renderer omits it; a room can have the right dimensions while a camera clips its furniture.

### Check the data and the actual mesh

Validate input hashes, duplicate IDs, relation holes, heights and their provenance, authored masks, water/land coverage, shoreline continuity and deterministic regeneration. For harbors, test boat footprints against water, docks and other boats; occupancy remains representative rather than a live inventory.

Build the actual `SceneData` and check finite vertices, unit normals, noncollapsed triangles, material indices and component budgets. Add meaningful rays: a room has a floor and ceiling, a balcony is supported, a window is a physical surface, a hearth opening remains open. Do not substitute a duplicate formula for checking the emitted geometry.

```sh
./scripts/validate-robie-house.sh
./scripts/validate-hyde-park-geometry.sh
./scripts/validate-navigation.sh
./scripts/validate-playback.sh
./scripts/validate-focus-navigation.sh
./scripts/validate-focus-navigation-integration.sh
./scripts/validate-viewport-input.sh
./scripts/validate-traffic.sh --cpu
./scripts/validate-light-grid.sh
```

These are existing CPU checks, not a universal one-command acceptance suite for an unregistered new district. Add the new builder/routes to their actual source lists and cases as needed, then retain complete reports.

### Exercise behavior, not only initial state

- Sweep head, torso and leg clearance in both directions along walking aisles; check floor support and near-surface samples between route keys.
- Test every demo boundary, starting index, manual selection while paused or shuttling, and independent speed/lighting preferences. Include large elapsed-time changes and nonfinite inputs where supported.
- Pick the first represented visible surface, then associate it with the intended landmark. Check occlusion, footprint holes, repeated-click deselection, sky deselection and retention across lighting/window changes.
- Separate click from drag. Move and resize the native window with the viewport still; test focus loss, key release, portrait/wide aspect ratios and full-screen transitions.

Focus orbit uses the selected object's envelope; it is not a collision-checked pedestrian route around the rest of the city. Tiny detail and traffic can be absent from picking/navigation. Record those limits rather than implying every rendered triangle is selectable.

**Exit condition:** component and full-world tests pass, and the report says which navigation geometry, routes and UI behaviors were actually exercised.

<!-- page -->
<a id="motion"></a>
## 9. Review images and measure motion

First inspect low-cost stills of all eight bookmarks by day and night. Look for missing structures, blocked compositions, implausible scale, floating surfaces, doubled shells, black interiors and lights that erase material detail. Then inspect intermediate route frames and motion. A high-sample still can look clean while the same material sparkles or smears during movement.

```sh
./scripts/build-app.sh
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --location robie --gallery output/review-robie-day \
  --width 960 --height 600 --samples 128 --lighting 1
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --location robie --gallery output/review-robie-night \
  --width 960 --height 600 --samples 128 --lighting 2
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --location millennium --motion-test output/review-bean \
  --motion-case cloud-gate-orbit --frames 32 \
  --width 640 --height 400 --samples 8 --reference-samples 128
```

Run rendering jobs **serially**, including shader fixtures and app previews. Independent CPU work can continue, but record overlap if it affects setup or wall-time comparisons. The motion example selects an existing case; add representative named cases for a new district in the actual motion test harness.

### Understand the two motion measurements

The paired harness presents raw and reconstructed results from the same current trace and compares them with independent higher-sample references. Image RMSE measures image error. Temporal residual measures consecutive error differences after subtracting reference motion. Require the acceptance criteria for both; lower noise with blurred shadows is not an automatic improvement.

The renderer combines sampling, filtered material detail, selective glossy-path regularization and temporal/spatial reconstruction. These are separate causes and should be tested separately. `--raw`, `--random-sampling` and `--no-regularization` enable controlled comparisons. Preserve actual-kernel fixtures such as `validate-denoiser.swift`, `validate-sampling.swift` and `validate-regularization.swift` when changing those paths.

The fast Hyde Park flight exposed blur from repeated bilinear history reprojection. A screen-displacement history cap improved that case, while compatible slow views could retain longer accumulation. This is a documented tradeoff, not proof that all moving glass, fine ironwork, water or night silhouettes are noiseless. See [MOTION.md](MOTION.md) and the release evidence in [VALIDATION.md](VALIDATION.md).

**Exit condition:** every delivered view is visually reviewed, relevant motion cases pass, original failures remain traceable, and sampled-frame review is not described as a full movie review.

<!-- page -->
<a id="capacity"></a>
## 10. Protect renderer capacity and compare performance

Large unified memory removes one constraint, not every implementation boundary. Check triangle counts, actual buffer byte ranges, shader indexing, light-index coverage, build time and representative render cost after extending the world. Allocating all 512 GB is neither necessary nor a useful performance target.

### The observed 4 GiB lesson

The expanded city first rendered only part of Robie's grounds beyond a vertex-data boundary. CPU geometry checks had passed. Widening shader indices alone did not restore the missing house. `GeometryPartition.swift` now limits each descriptor to `1 << 24` triangles; with 32-byte vertices and three vertices per triangle, each full descriptor spans 1.5 GiB. Shader intersection helpers combine the geometry ID and local primitive ID into the shared global index, while traffic retains its separate instance offset.

This is an observed compatibility failure and tested workaround on this machine, not a claimed published Apple 4 GiB limit. [Apple's acceleration-structure documentation](https://developer.apple.com/documentation/metal/ray-tracing-with-acceleration-structures) describes the underlying API.

```sh
./scripts/validate-large-geometry-gpu.sh
./scripts/validate-indexed-lighting.sh
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --location chicago --self-test
```

Run these GPU jobs one after another. The bounded large-buffer fixture uses production offsets and shader lookup code over a buffer larger than 4 GiB, but submits only 32 static triangles plus a traffic triangle. Full-city images separately establish representative scene coverage. Earlier huge synthetic fixture failures remain recorded; the smaller test does not retroactively prove them resolved.

### Check that local-light indexing remains enabled

Extending Chicago exceeded a previous dense grid budget. `LightGrid.swift` uses 64-metre cells, a 1,048,576-cell cap and an 8 MiB range array. Finite support and ordered candidate lists preserve the defined lighting behavior. If bounds exceed the budget it falls back to the complete linear list rather than silently dropping lights. Require day and night index status in packaged checks; compare actual pixels with `--linear-lights` when changing the index.

### Compare like with like

Freeze executable, shader/model hashes, scene, camera/time sequence, resolution, samples, references, lighting and reconstruction options. Run A/B jobs serially in the same device state; report build/setup time, paired GPU time and wall time separately. Keep failed ablations and outliers. A scoped CLI activity token did not explain away the historical slowdown investigation.

The 1.9.1 record contains 45,496,818 static city triangles and an 8,283.47 MiB Metal allocation in one 640×400 self-test. These are dated, scoped measurements. Paired GPU timings include tracing, reconstruction and both presentations; reference renders also add wall time. Never invert these timings into native preview FPS or claim a city-wide frame-rate guarantee.

<!-- page -->
<a id="release"></a>
## 11. Package, reproduce and publish a release

Freeze source and resource inputs before the final review. Record exact commands, executable and resource hashes, device, quality settings, result paths and review scope under a new `docs/validation/` release directory. If an edit changes geometry, routes or shaders, rerun affected checks. Retaining old navigation evidence needs a demonstrated identity of the defined navigation data, not an assumption that a fixture is small.

```sh
./scripts/build-app.sh
codesign --verify --deep --strict dist/Atelier.app
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --help
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --location robie --video output/Robie-Review-New.mp4 \
  --seconds 96 --fps 24 --width 1280 --height 720 --samples 8
python3 scripts/validate-video-timing.py output/Robie-Review-New.mp4 \
  --seconds 96 --fps 24 --report output/robie-timing.json
```

The movie command compresses all eight complete routes into chapters; it does not record every route at normal speed. A six-minute connecting-route export instead uses `--single-view --stop 7 --seconds 360`. View numbers are zero-based in the CLI. Video output requires a new filename. Timing validation needs FFmpeg and FFprobe on PATH and checks complete decoding, frame count and uniform timestamps; visual/motion review remains separate.

### Verify the artifact people will launch

The build script produces native arm64 code, copies offline resources, writes version/build metadata, verifies an ad-hoc signature and replaces the generated app only after staging succeeds. Test a copied app from outside the repository with repository reads denied, as the release evidence does. Verify every bundled resource against its source hash. Confirm the launcher detects source/resource changes and that About, build metadata and release notes agree.

The app is locally signed, not notarized for distribution to arbitrary Macs. Include that packaging scope. Do not present an older movie as footage of a later geometry correction; the 1.9 recordings are explicitly historical after the 1.9.1 road fix.

### GitHub and version workflow

The existing remote is [wacastel/atelier-architecture](https://github.com/wacastel/atelier-architecture). Inspect `git remote -v` and the working diff first. Preserve unrelated changes. Stage named source, map, documentation and validation artifacts; review `git diff --cached --stat` and `git diff --cached` before committing. Keep temporary references, scratch builds and large intermediate frames out of tracked files.

Use the user's authorized publication scope to decide branch push, pull request or release. A push command sends committed history; verify branch, remote and included commits before sending it. Record the final commit and any tag after publication. Never claim the repository was pushed merely because the local app built or a commit exists.

**Exit condition:** the signed, copied package reproduces the reviewed world, its limitations are current, and publication state is verified independently of local completion.

<!-- page -->
<a id="starter"></a>
## 12. Start the next location in a fresh context

Copy the prompt below and fill the bracketed values. Attach this guide and the current scope/evidence note when starting with a new collaborator or a fresh context. Treat the bracketed values as planning inputs, not invented source facts.

```text
Extend Atelier at [repository path], starting from [branch/commit].
Build [landmark + surrounding district] in the existing Chicago world,
with a connection from [existing bookmark] to [arrival bookmark].
The required interiors are [rooms]; omit [explicit exclusions].

Read docs/CITY-BUILDING-GUIDE.md, README.md, docs/VALIDATION.md,
the neighboring location docs and actual source before editing.
Preserve current controls, demo semantics and previous source data.
Inspect dated OSM data, satellite/aerial views, day/night photos
and official plans. Record inspected references and estimates.
Use the Willis east/up/south metre frame; agree on the authored
mask, layout transform and source ownership before adding context.

Author eight distinct focal views, gentle idle motion, full routes,
day/night lighting and the connecting flight. Use shared materials
and bounded detail. Reconcile road/sidewalk topology and grades;
retain source tags and explicitly document omitted underground work.

Validate actual data, triangles, navigation, focus and playback.
Run GPU jobs serially; inspect every day/night view and relevant
motion cases. Compare performance only with matched inputs.
Package and test a copied offline app, record hashes and evidence,
and deliver updated docs, review images and a walkthrough movie.
Publication authorization: [local only / branch push / PR / release].
Active owners or frozen files: [list]. GPU owner: [name or free].
Known failures and evidence paths: [list].
```

### Keep these repository references close

- **Integration:** `ChicagoWorld.swift`, `ArchitectureLocation.swift`, `EngineController.swift`, `CommandLine.swift` under `Sources/ArchitectureEngine/`.
- **Architecture and routes:** `RobieHouse.swift`, `RobieScene.swift`, `RobieWalkthrough.swift`, `CameraTrack.swift`; [Robie evidence](ROBIE-HOUSE.md).
- **Maps and transport:** `scripts/prepare-hyde-park-context.py`, `scripts/validate-hyde-park-roads.py`; [Hyde Park methodology](HYDE-PARK.md).
- **Rendering:** `MetalRenderer.swift`, `GeometryPartition.swift`, `LightGrid.swift`, `Resources/Renderer.metal`, `Resources/Denoise.metal`; [motion notes](MOTION.md), [glass limits](GLASS.md).
- **Behavior and proof:** [demo contract](DEMO.md), [focus limits](FOCUS.md), [current validation record](VALIDATION.md), and the exact `Tests/` fixture behind each validation script.

This workflow produces a referenced architectural reconstruction. It does not imply photogrammetry, surveyed terrain, complete collections/interiors, BIM ingestion, automatic city streaming, live traffic/boat inventories or universally noiseless rendering. Preserve those distinctions as the world grows.

<!-- page -->
<a id="navigation"></a>
## 13. Extend the map and both rendering modes

The 2.0 navigation contract adds an offline map, panning, flight speeds and native raster rendering. Extend these alongside the tours. Native acceptance and package results belong in `docs/VALIDATION.md`.

### Map and manual movement

- **M** toggles the Chicago map overlay. Its **S / M / L** buttons select map size. Clicking the map takes manual Fly control and chooses an elevated overview using local roof-height queries, preserving day/night.
- Update bounds in all three places: `ChicagoMapProjection`, `ManualCityNavigation.overview` and `EngineController.navigateCity`. Extend the map catalog/geometry in `NavigationMap.swift`, then test clicks beyond the old extent; changing only the map bounds leaves navigation rejecting those clicks. This lightweight north-up 2D map uses the shared east/south frame and simplified footprints/paths, without another `SceneData` or renderer.
- **Left drag** pans the ground plane unless an object is focused, in which case it orbits that object. **Right drag** looks around or orbits a focused object. Continue distinguishing a click from a drag.
- **F** selects Walk/Fly. Minus/plus and keypad minus/plus step flight speeds through **8, 30, 80, 180, 400 and 800 m/s**, starting at **80 m/s**. Shift multiplies movement by three. Unfocused scroll adjusts speed; focused scroll zooms toward the object.

`ManualCityNavigation.swift` supplies pan, displacement and overview math. Test coordinate round trips, margins, roof clearance, state retention and invalid input. Movement uses elapsed time. Map overviews and flying do not certify pedestrian clearance.

### A real alternative to tracing rays

**T** switches mode while retaining the camera. `RenderOptions.rayTracing` defaults to true. `RasterRenderer.swift` and `Resources/Raster.metal` provide depth-tested raster drawing; disabling denoising alone would not disable tracing.

Raster frames use no ray queries or traffic acceleration-structure refits. Startup still builds ray-tracing structures for mode switching, retaining that memory cost and hardware requirement. Raster lighting/reflections are approximate, without traced global illumination or shadows. Review its fidelity separately.

```sh
./scripts/validate-manual-city-navigation.sh
./scripts/validate-navigation-map.sh
./scripts/validate-raster.sh --cpu
./scripts/validate-raster.sh
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --location chicago --raster --self-test
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --location robie --raster --render output/Robie-Raster-Review.png \
  --stop 0 --width 960 --height 600 --lighting 1
```

The first three commands are CPU only; run the rest serially on the GPU. Check batching, conservative visibility, depth/glass and zero ray/guide dispatches or ray-tracing traffic updates during raster frames. Inspect matching day/night views. `--motion-test` measures ray-tracing reconstruction and rejects `--raster`. Compare modes with matched inputs; do not claim native FPS from offscreen timings.
