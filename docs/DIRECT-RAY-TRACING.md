# Direct ray tracing

Research and validation notes, 9 September 2026. The faster mode is a separate lighting algorithm using the existing Metal scene and acceleration structures. The original path tracer remains the default for richer indirect lighting; Fast Raster remains available as a separate raster rendering option.

## Why this approach

Ray tracing describes how the renderer queries geometry. It does not require random sampling. A Whitted-style renderer evaluates visible surfaces, direct lights, shadows and selected specular paths with a bounded ray tree. This can be deterministic while still reflecting objects outside the camera view. The original [Whitted paper](https://my.eng.utah.edu/~cs6958/papers/p343-whitted.pdf) and [PBRT's explanation of visibility and surface scattering](https://pbr-book.org/3ed-2018/Introduction/Photorealistic_Rendering_and_the_Ray-Tracing_Algorithm) describe this distinction.

Path tracing estimates a much larger light-transport integral. Limited random samples produce variance; replacing the GPU API or renderer library does not, by itself, remove that mathematical source of noise. More samples, better sampling and reconstruction reduce it, with time and quality tradeoffs. See [PBRT: Monte Carlo integration](https://pbr-book.org/4ed/Monte_Carlo_Integration).

Apple identifies M3 as an Apple family 9 GPU with hardware acceleration for ray traversal and intersections. Both this project's original path tracer and its direct-ray mode can use that hardware. The benefit of direct mode comes from doing less light-transport work, not from activating an accelerator the original mode neglected. [Apple: GPU advancements in M3](https://developer.apple.com/videos/play/tech-talks/111375/).

## The three rendering choices

| Mode | Purpose | Expected limits |
|---|---|---|
| Path Tracing | Existing sampled light transport, indirect illumination and reconstructed motion | Sampling variance remains possible, particularly during motion and in difficult interiors/reflections. More samples cost more GPU time. |
| Direct Ray Tracing | Deterministic direct lighting, scene visibility, hard shadows and bounded scene reflections/transmission | Approximate ambient illumination replaces diffuse interreflection. Soft penumbras and accurate rough reflection integration are sacrificed. |
| Fast Raster | Existing multisample raster rendering with analytic lighting | Its environment-based reflections and lighting approximations cannot reproduce arbitrary offscreen reflected objects or ray-traced shadows. |

Deterministic does not mean every moving edge is perfectly smooth. Subpixel railings, distant windows, specular geometry and hard shadow boundaries can still alias or shimmer as coverage changes. Traffic and animated lights also legitimately change between frames. Do not describe this mode as a guarantee of zero visible artifacts or a measured native frame rate.

The **R** hotkey cycles Path Tracing → Direct Ray Tracing → Fast Raster. The sunset building-light setting is shared by all three modes, including emissive surfaces visible through glass or reflected in traced geometry. It leaves sunset sun/sky and moving-vehicle lights intact.

The implementation reuses world geometry, materials, coordinate mapping, traffic structures, camera projection and presentation. `RenderOptions.rayTracing` selects ray rendering versus Fast Raster; `directRayTracing` selects the direct algorithm within ray rendering. The default `RenderOptions()` retains the original path tracer. App-level defaults are configured separately. The render selector must preserve camera, location, view, lighting and playback state.

`Resources/DirectRay.metal` traces one pixel-center primary ray, with at most three total ray branches and twelve transparent-layer intersections per branch. It uses the shared material shader and spatial light index. All locally supported lights contribute direct illumination, while four dominant lights receive geometric shadow checks; the fifth-ranked contribution controls a smooth transition between shadowed selections. Weaker lights can therefore contribute through occluders. Sharp materials receive bounded scene reflections; rougher materials blend toward an analytic environment approximation. These are deliberate quality/cost limits, not exact global illumination. `MetalRenderer.swift` submits one direct dispatch per frame and bypasses progressive sampling and temporal reconstruction in this mode.

Direct mode's presentation applies spatial edge antialiasing after tone mapping and sRGB conversion. It uses the current image alone, with no temporal lighting history. Selection still uses the original center-pixel depth, so smoothing an edge does not transfer landmark identity onto an occluder or the sky. The original Path and Raster presentation remain unchanged.

The command line accepts `--renderer path`, `--renderer direct` and `--renderer raster`; omitting the option keeps path tracing. Existing `--raster` commands remain valid. For example:

```sh
dist/Atelier.app/Contents/MacOS/ArchitectureEngine \
  --render output/Cultural-Center-Direct.png \
  --location culturalcenter --stop 3 --lighting 1 --renderer direct
```

The selector also applies to galleries, videos and self-tests. Direct and raster modes render once per requested frame, irrespective of `--samples`. `--motion-test` remains a test of the original path-tracing reconstruction and rejects either alternative renderer. Conflicting mode flags produce an error before GPU initialization.

## Apple alternatives considered

Apple's [hybrid rendering example](https://developer.apple.com/videos/play/wwdc2021/10150/) combines raster primary visibility with ray-traced secondary effects. It is a useful future optimization, particularly with tiled rendering. It also requires explicit choices about lighting, reflection quality and ray budgets. It does not automatically remove stochastic noise when those secondary effects still use random samples.

[MetalFX denoised upscaling](https://developer.apple.com/videos/play/wwdc2025/211/) is another potential improvement for the original sampled mode. Its inputs include color, depth, motion, world normals, roughness and diffuse/specular albedo. Apple also documents sampling and correlated-noise pitfalls. Adoption would require a separate integration and visual validation; this change does not implement it. The installed SDK marks the API available on macOS 26. Runtime eligibility must be checked with [supportsDevice](https://developer.apple.com/documentation/metalfx/mtlfxtemporaldenoisedscalerdescriptor/supportsdevice(_:)), rather than inferred solely from the computer name. The fixture records that capability without using MetalFX to render.

## Reproducible validation

From the repository root:

```sh
# Compile the fixture only: no device creation or GPU commands.
bash scripts/validate-direct-ray.sh --build-only

# Check independent test-scene geometry and selector defaults on the CPU.
bash scripts/validate-direct-ray.sh --cpu

# Run the actual Metal renderer. Schedule serially with all other GPU jobs.
bash scripts/validate-direct-ray.sh
```

The GPU fixture uses the production `MetalRenderer`, actual shader resources and acceleration structures. It tests:

- A nearer red panel occluding a blue panel, and real blue architecture visible through a clear sheet.
- A mirror reflecting a red or blue object entirely behind the camera. The two matching raster frames form a negative control: their environment-only reflection cannot distinguish the offscreen object.
- A hard shadow at an independently established ray/triangle intersection, then its movement when the sun direction changes. A night point-light case compares the same floor with and without a physical blocker.
- Byte-identical output for different frame seeds and requested sample counts, with reconstruction settings enabled and disabled.
- Immediate camera changes, an exact return to the prior camera, resize round trips and direct/path/raster mode transitions.
- Selection using actual primary depth: the selected surface changes color while a nearer occluder and sky remain unchanged.
- One moving vehicle in the actual instance acceleration structure, its dynamic headlights compared with an empty road, unchanged-time reuse and an exact scrub back to the earlier image.
- Rendering source hashes before and after execution, so results cannot silently combine different shader versions.

Reports and small fixture images are written to `output/direct-ray-validation/`; `ATELIER_DIRECT_RAY_OUTPUT` can select another output directory. The CPU checks do not prove the GPU features. The small GPU scenes do not establish full-city performance, all traffic behavior, native event delivery or photographic fidelity. A release should separately compare matched Chicago views and walkthrough motion, with the same resolution, scene, camera, time and lighting. Run those GPU jobs serially and record OS, device, source hashes, warmup and render settings. GPU command time and native presented frame rate are different measurements.

On 9 September 2026, the CPU geometry branch passed 12 checks. The final serial production-kernel fixture, rerun after adding edge antialiasing, passed **[48 checks](validation/v2.4/direct-ray.json)** on Apple M3 Ultra, macOS 26.6.2, at 192 × 128 pixels. All rendering inputs stayed unchanged during the run. Requested 1, 2 and 2048 sample counts and changed seeds produced the same direct image; the recorded dispatch count confirms one direct dispatch per capture. The offscreen red/blue reflection controls and point-light blocker-removal comparison passed. The moving vehicle uncovered its road in the depth buffer, illuminated a separate road probe and returned to the exact prior frame when scrubbed back. The initial eleven fixture images were also visually inspected. These are functional fixtures, not architectural beauty renders or frame-rate measurements.

The separate **[27-check presentation fixture](validation/v2.4/direct-presentation.json)** compared four slanted edges with independent 32 × 32 area-coverage references. The filter reduced error in all four cases, left flat pixels unchanged and retained one-pixel bright/dark rails. It also verified deterministic repeats, correct focus/foreground/sky classification, and byte-identical original Path/Raster plain and focused presentation against the committed legacy shader.

The runtime MetalFX denoised-scaler capability query returned true on this device. No MetalFX denoising was performed. The final GPU reports record `DirectRay.metal` SHA-256 **`b0770242af492fdd7f9a76c03d17f94f25bba828426098766452b9ee45d4ea97`**; later shader changes require a new run. Separately, [17 CPU parser cases](validation/v2.4/direct-ray-cli.json) passed using the exact command-line source prefix through renderer selection, with the export body replaced by a terminal mode print. That verifies argument handling without claiming packaged CLI or GPU export validation.

## Final shared-city comparison

The [final version 2.4 benchmark](validation/v2.4/render-modes.json) passed all ten cases across three renderers: **420 rendered frames**, comprising two warmup and twelve measured frames for each case/mode pair. One resident Chicago scene contained 45,953,309 static triangles and 168 moving vehicles, totaling 46,115,121 triangles. All modes received matching camera/time sequences at 1280 × 850; mode order rotated between cases. Path Tracing used four samples per frame and three bounces. Direct rendered once per frame with its final spatial edge presentation. Inputs remained unchanged.

| View | Path median GPU ms | Direct median GPU ms | Raster median GPU ms |
|---|---:|---:|---:|
| Robie exterior, day | 81.7 | 10.4 | 9.1 |
| Robie exterior, night | 88.7 | 10.5 | 6.5 |
| Robie living room, day | 296.1 | 17.9 | 8.7 |
| Robie living room, night | 294.4 | 18.2 | 9.2 |
| Willis skyline, day | 40.0 | 9.0 | 11.9 |
| Willis Catalog entrance, day | 72.6 | 10.4 | 10.2 |
| Cultural Center exterior, day | 110.5 | 10.2 | 11.5 |
| Cultural Center stair, day | 137.5 | 11.7 | 10.8 |
| Preston Bradley Hall, day | 157.5 | 16.1 | 11.7 |
| Preston Bradley Hall, night | 184.7 | 17.0 | 8.6 |

These are bounded **GPU command-buffer timings**, not native window FPS. The test ran serially with the native app closed; synchronous readback is included only in the separately reported wall times. Twelve measured frames per mode do not establish long-run performance across every route. The algorithms also produce different lighting, so the ratios are not equal-quality comparisons. [Open the illustrated comparison](validation/v2.4/render-mode-comparison.html) to inspect unretouched frames from the tested sequences.

Path Tracing remains the original default. Visible sampling grain can remain in the Cultural Center stair and other difficult interiors. The retained traffic-guide correction addresses traffic history and does not establish a cure for that interior grain; the investigated stronger filter did not provide enough actual-scene benefit to ship. [Path-noise investigation and limits](validation/v2.4/path-noise/review.json).

The [version 2.4.0 build 17 package](validation/v2.4/package.json) passed arm64 and signature checks with all four bundled shaders matching the tested sources. [Native checks](validation/v2.4/native.json) verified G full-screen round trips in normal and Map views, the renderer menu, R restoring Direct during playback, day/night walkthrough rendering, and selected landmark highlighting. The app was left on Preston Bradley Hall at night in Direct mode. Sustained physical held-key timing is outside the native automation's immediate-tap scope; actual held movement is exercised by the controller fixture.
