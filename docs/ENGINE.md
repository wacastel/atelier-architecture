# Atelier engine notes

Atelier is a native Swift/Metal architectural walkthrough application for Apple Silicon. Five destinations use two resident-world definitions: Paris, and one continuous Chicago scene containing the Loop, Millennium Park, the lakefront, Museum Campus and McCormick Place. One world is resident at a time. Chicago location changes reuse its renderer and navigation resources. Vehicles and Adler's procedural projection animate independently of static architectural meshes, from the same absolute timeline as the camera.

Current geometry counts, allocations and validation results are in [VALIDATION.md](VALIDATION.md). The models are architectural reconstructions with documented interpretations, not surveyed digital twins or complete museum collections.

## Application and data flow

`ArchitectureMain` handles export and validation arguments before starting AppKit. The application embeds an `MTKView` beneath SwiftUI controls. `EngineController` builds scene geometry, the Metal renderer and the navigation BVH on a serial background queue. A generation token prevents a superseded location request from installing stale resources. The GPU queue is drained before replacing a world.

`SceneData` contains unindexed triangles, face or smooth normals, one material index per triangle, compact materials, explicit finite lights and mapped traffic lanes. The common `EiffelBuilder` provides geometry primitives used by all architectural modules. Offline OpenStreetMap derivatives establish plans, streets, water, paths and contextual buildings; specific landmark modules supply the detailed architecture. Map and authored-geometry provenance is documented per location.

The Swift/Metal ABI uses 16-byte fields. `SceneVertex` and `SceneMaterial` each occupy 32 bytes, `FrameUniforms` 144 bytes, `SceneLight` 64 bytes and `TemporalUniforms` 112 bytes. The final `FrameUniforms.animation` vector begins at offset 128. Its first component is the 180-second dome phase and its second indicates projection motion. Earlier lighting, traffic, glass and sampling flags retain their original fields. Standalone shader fixtures and the packaged self-test check this layout.

## Hardware rendering

The renderer requires `MTLDevice.supportsRaytracing` and compiles the bundled shaders as Metal language 3.1. Static city geometry occupies a triangle acceleration structure. A separate small vehicle structure and instance hierarchy are refitted when traffic advances; the city structure is not rebuilt per frame. Primary, reflection, transmission and occlusion rays use Metal triangle intersectors. See Apple's [ray-tracing acceleration structures](https://developer.apple.com/documentation/metal/ray-tracing-with-acceleration-structures) for the underlying API.

Materials provide diffuse and GGX specular response, metallic surfaces, emission and opt-in thin-sheet transmission. Windows, water waves, masonry, granite and the dome use procedural surface definitions with footprint filtering where applicable. Direct lighting uses shadow rays and bounded explicit sources. Separate day/interior and night light grids conservatively reduce the candidates evaluated at a hit. Selected indoor practicals remain active in daylight. Finite source ranges and authored fixture intensities are rendering approximations, not calibrated photometric surveys.

Thin glass carries reflected and transmitted paths with documented limits; it is not a volumetric aquarium simulation. Boats are moored representative occupancy, not a live harbor inventory. The animated vehicles participate in traced shadows and reflections. Their headlights and local reactive guides follow the vehicle geometry. [Glass](GLASS.md) · [Motion reconstruction](MOTION.md) · [Night lighting](NIGHT.md).

## Motion and the projection clock

Preview reconstruction combines current samples with compatible history using world position, depth, normal, material and albedo guides. It rejects disocclusion and incompatible reflection, emission and transmission history, then applies an edge-aware spatial filter. Sampling, indirect-path regularization and reconstruction are separately testable. Fine grain and softness can remain in difficult moving reflections and small details; the pipeline does not guarantee a noiseless image at every viewpoint.

`setSceneTime(_:)` supplies deterministic absolute seconds to vehicles and the original Adler show. Repeating the same time preserves progressive accumulation. Changing time invalidates stationary accumulation, while local reactive guides prevent stale dome images and nearby illumination from persisting. A cheap reflected-ray/sphere test limits projection-reflection visibility queries to rays that can actually reach the dome. Unrelated Chicago surfaces retain their history. Pause, rewind, seek, idle animation and offline export all use this clock.

The 180-second dome program uses analytic star, aurora and planet radiance; it is an original visual composition rather than an astronomical ephemeris or copied commercial show. Geometry contains an inward-facing 21-metre projection shell, opaque backing, public gallery passages and seats. [Adler implementation and tests](ADLER.md).

## Camera controls and output

`WalkthroughPlayback` keeps walkthrough and idle speeds independent. Manual bookmark selection holds that view; Idle Play resumes ordered cycling and alternates day/night after each pass. Both connecting Chicago flights preserve the selected lighting. `CameraTrack` uses bounded Hermite interpolation; the Field entrance follows its staircase incline rather than easing height independently into risers. The three-minute dome camera returns to its opening pose.

Static navigation uses a CPU BVH, head/torso/leg ray sweeps with a forward margin, and downward floor queries. It is a lightweight camera controller, not a rigid-body or pedestrian simulation. Authored-route tests sample intermediate camera positions, body clearance, near surfaces and floor support. Moving vehicles are not part of this static navigation BVH.

Render targets preserve the actual drawable aspect, including portrait windows and native full-screen mode. Quality presets bound render width, samples and path interactions; both axes remain within 8192 pixels. Unified memory is used directly, but allocating the machine's full 512 GB is unnecessary. Reported Metal allocation totals are viewport-dependent and are separate from whole-process memory and frame-rate measurements.

The CLI renders stills, complete bookmark galleries, paired motion tests and uniformly timestamped H.264 recordings with AVFoundation. A single-view export defaults to that route's duration. `--seconds` retimes the entire route; `--idle` instead follows real idle seconds. Multi-view exports compress each complete route into a chapter. Video output requires a new filename. An OBJ/MTL import path supports still rendering, with the importer's documented material limits; arbitrary imported-building tours, BIM metadata, USD/glTF ingestion and texture/material capture are not implemented.

## Build and verification

The application has no third-party runtime dependencies. `scripts/build-app.sh` builds a native release arm64 executable, packages offline maps/shaders/icon resources, writes the app metadata and verifies an ad-hoc signature. The launcher rebuilds when source or resources change. A copied application is tested from temporary directories with source-repository reads denied, to establish that runtime resources are self-contained. The app is not notarized for distribution to other computers.

Verification covers the Swift/Metal ABI, actual shader kernels, deterministic sampling, glass, lighting grids, traffic, paired capture and the projection clock. Geometry fixtures check finite vertices and normals, materials, nondegenerate triangles, landmark bounds and published dimensions. Full-world playback tests and day/night image reviews remain necessary after component tests. Actual-scene motion reports compare reconstructed and unfiltered presentations of the same trace against independent high-sample references; their GPU times include validation work and are not ordinary preview FPS. Reproduction commands and current evidence are linked from [README](../README.md) and [VALIDATION.md](VALIDATION.md).

Future engineering work includes architectural instancing/streaming, richer material capture, surveyed/BIM asset ingestion, more complete interiors, improved dynamic navigation and continued measurement of difficult moving reflections. These are distinct from the working renderer and authored locations described above.
