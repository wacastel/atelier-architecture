# Motion reconstruction — current additions in 1.3

Chicago retains the validated Paris reconstruction and adds thin-sheet glass. The first camera pane traces both reflection and transmission with deterministic Fresnel weights, reducing low-sample switching noise. Surface guides traverse the pane to the first opaque surface and retain full camera distance. Glass-background surfaces use current spatial filtering and reject temporal history, because reflected and transmitted images do not share one motion vector. Emissive windows and sky still preserve exact current coverage. The guide material flag is +0.75 for non-emissive surfaces behind glass and +0.5 for visible emitters, including emitters behind glass. [Details and limitations](GLASS.md).

Chicago's mapped nearby window occupancy is assigned per pane in deterministic room pairs. It therefore remains aligned with the actual window geometry. The Willis façade pattern follows the same intermediate elevation anchors as the model. Native viewport changes recreate history textures and recompute camera aspect. Location swaps pause submissions, drain the old GPU queue, and reset geometry/camera/lighting history before drawing the replacement scene.

At coarse night resolution, a pixel-center guide can see a dark mullion while its jittered rays include a lit neighboring window. Filtering only the dark-center pixels eroded legitimate window coverage. Spatial filtering now preserves the current 5 × 5 neighborhood around visible emitter guides when the pixel footprint exceeds 0.25 m. Smooth distant water and roofs retain filtering. A moving-window GPU fixture checks 17,520 mixed-coverage samples, alongside the existing disocclusion and light-trail tests.

Presentation now performs only exposure, tone mapping and sRGB conversion. Earlier reports labeled their comparison stream “raw,” but that low-sample stream still used the original 3 × 3 presentation filter; reconstructed and high-sample reference streams bypassed it. The historical reports are retained unchanged. Current comparisons use truly unfiltered samples, with the same strict image-error and temporal-error improvement requirements; percentages across those baseline policies are not directly comparable. A real GPU fixture verifies unchanged pixel coverage at 1, 4 and 128 samples. [Preserved discovery and method notes](validation/v1.3/motion-baseline-notes.md).

`swift scripts/validate-glass.swift` exercises real transmission/reflection/shadow/guide kernels. `swift scripts/validate-denoiser.swift` includes behind-glass temporal rejection and measured current-frame spatial noise reduction, as well as all earlier opaque surface, emission, sky and disocclusion checks. Fine glossy/subpixel and glass sampling grain can remain during motion.

## Paris reconstruction and prior measurements

# Motion reconstruction

The original moving preview discarded accumulated path samples whenever the
camera changed. Four new paths per pixel were then shown through a small,
depth-only presentation filter. A still camera could converge over hundreds of
samples, while every frame of an orbit or rivet close-up started again. The
result was visible Monte Carlo noise, particularly on indirect light and metal.

The replacement keeps useful lighting samples across camera movement. All
reconstruction runs in Metal compute kernels on the GPU, before exposure,
tone mapping and sRGB encoding.

## Frame pipeline

1. Trace the current frame's path samples in linear HDR.
2. Trace one deterministic pixel-center primary ray for world position, material,
   geometric normal, distance, procedural albedo and roughness. These guides do
   not jitter with the stochastic path samples.
3. Project each current world position into the previous camera. Bilinear
   history taps are accepted individually only when material, normal, world
   distance, tangent-plane distance and previous ray depth agree. Newly visible
   surfaces restart at one frame. Sky and visible emissive windows/fixtures keep
   current radiance exactly, bypassing temporal history and spatial filtering.
   Emissive guides use an integer material ID plus 0.5, separating them from
   nonemissive surfaces that share the same underlying material.
4. Measure luminance moments in a geometry- and albedo-aware current neighborhood and clip
   stale history against its variance. Blend accepted lighting into history,
   capped at 32 frames. Moving sharp reflections retain as few as two frames.
5. Apply three edge-avoiding à-trous passes with pixel steps 1, 2 and 4. Material,
   albedo, roughness, normal, tangent-plane distance and luminance weights prevent
   filtering through rivets, narrow ironwork and silhouettes. Filter strength
   falls as the stationary path sample count rises.
6. Present the reconstructed HDR result. Do not apply the older presentation
   filter to it. Preserve the temporal output for the next frame; do not feed
   the spatially filtered result back into temporal history.

The design follows the temporal accumulation and wavelet filtering principles of
[Schied et al., *Spatiotemporal Variance-Guided Filtering* (2017)](https://research.nvidia.com/labs/rtr/publication/schied2017spatiotemporal/)
and the multiple edge-stopping functions in
[Dammertz et al., *Edge-Avoiding À-Trous Wavelet Transform* (2010)](https://www.uni-ulm.de/fileadmin/website_uni_ulm/iui.inst.100/institut/Papers/atrousGIfilter.pdf).
This is a compact implementation tailored to static architectural geometry. Its
clipping variance comes from current-frame neighborhood moments; it does not
claim the complete SVGF algorithm or a learned ray-reconstruction model.

## Night silhouette ghosting

Reviewing an actual night-orbit video exposed faint horizontal gold trails beside
the upper tower. A deterministic pixel-center guide can hit sky while some of
that pixel's jittered path samples hit bright ironwork. Reprojecting this mixed
radiance as an infinite-distance sky surface carried the foreground highlight
into later frames. The variance-clipping floor allowed that incorrect highlight
to fade slowly, and spatial filtering spread it into adjacent sky pixels.

Sky-classified pixels now pass their current radiance through both reconstruction
stages unchanged, with a history count of one. The analytic sky itself is
noiseless; a stationary camera's raw progressive accumulation still converges
subpixel silhouette coverage. This preserves legitimate current highlights and
prevents old tower coverage from leaving a trail. Surface history, reflections
and geometry-aware filtering retain the reconstruction described above.

The same mixed-coverage problem can tag distant city geometry behind the tower.
Those pixels need surface reconstruction, so the luminance-deviation floor is
0.0005 in linear HDR, plus a relative term, rather than the previous 0.04 floor.
History more than twice the current neighborhood's upper confidence bound is
discarded immediately when the current sample lies within that bound. This
removes vanished gold highlights from dark buildings without retaining a faint
coloured remainder or disabling ordinary surface history.

## Shader interface

`TemporalUniforms` is 112 bytes, seven 16-byte vectors. The previous camera's
right and up vectors include the field-of-view scale used by the path tracer.
The forward vector is unit length. `sizeFlags` is width, height, valid history,
camera moving. `currentOrigin.xyz` is the camera position and its W component is 1 for night, 0 for daylight. `settings` is maximum history, actual current accumulated samples
per pixel, filter step, current pixel cone (`2 * length(currentUp) / height`).
The current cone keeps spatial filtering accurate during a field-of-view zoom;
previous camera scales remain responsible for temporal visibility tests.

`temporalResolve`, buffer 0 = `TemporalUniforms`:

| Texture | Meaning |
| --- | --- |
| 0 | Current linear radiance |
| 1 | Current world XYZ, material ID in W (+0.5 for emitters); sky direction XYZ, W = -1 |
| 2 | Current geometric normal XYZ, primary ray distance W |
| 3 | Current albedo RGB, roughness W |
| 4 | Previous temporal RGB, frame count W |
| 5 | Previous world/material guide |
| 6 | Previous normal/depth guide |
| 7 | Output temporal RGB, frame count W |

`spatialFilter`, buffer 0 = the same structure, with `settings.z` = 1, 2 or 4:

| Texture | Meaning |
| --- | --- |
| 0 | Input linear HDR, temporal output for the first pass |
| 1 | Current world/material guide |
| 2 | Current normal/depth guide |
| 3 | Current albedo/roughness guide |
| 4 | Output linear HDR, current primary depth in W |

World positions and normal/depth guides need 32-bit floats to retain millimetre
detail across this scene. History and filtered radiance can use 16-bit floats
within the path tracer's radiance range. All previous textures must remain
unchanged until temporal resolve finishes. Reset history on camera cuts, size or
lighting changes, and scene replacement. Ordinary camera motion should preserve
surface history. Sky pixels deliberately retain no temporal history.

## GPU validation

Run `swift scripts/validate-denoiser.swift`. It compiles and executes the actual
Metal kernels on reproducible 128 × 96 synthetic scenes; there is no CPU
substitute for the reconstruction under test. Results on the Apple M3 Ultra:

| 48-frame test | Raw RMS error | Temporal RMS error | Filtered RMS error |
| --- | ---: | ---: | ---: |
| Stationary plane | 0.37664 | 0.05493 | 0.00569 |
| Translating camera | 0.37664 | 0.02709 | 0.00434 |
| Pivoting camera | 0.37664 | 0.02425 | 0.00435 |

These controlled uniform-plane numbers verify reconstruction, and are not a
claim of the same reduction across the Eiffel scene. Bilinear reprojection adds
some spatial averaging in the moving cases.

The same test also verifies:

- A bounded 32-frame history and exact first-frame/camera-cut reset.
- Rejection of 96 newly revealed background pixels, including the case where
  foreground and background share a material. No bright foreground ghost remains.
- Preservation of one-pixel ironwork, same-material raised geometry, normal and
  material boundaries, and an albedo boundary through all three filter passes.
- Correct current-frame spatial thresholds across an eightfold FOV-scale change.
- Response to changed illumination through luminance clipping.
- A two-frame cap for moving mirror-like surfaces.
- Exact current-radiance passthrough for sky and finite RGB/depth output.
- A moving subpixel gold spire against dark sky: 4,320 mixed foreground/sky
  coverage samples remain intact, and 1,824 formerly bright sky pixels leave
  no residual trail (maximum clear-sky error 0.0). This 56-frame regression also
  covers pausing after movement, when raw accumulation resumes convergence.
- A transient gold highlight covering 224 pixels tagged as the same dark
  background surface: after 32 frames of contaminated history, the first fully
  uncovered frame restores the background (maximum RGB error 6.98 × 10⁻¹⁰).

The interactive result remains a biased reconstruction of a small number of
paths. Freshly revealed surfaces initially have fewer samples; very fine
subpixel geometry and difficult glossy reflections can still show residual
noise. Static-geometry world reprojection also assumes objects have not moved;
animated geometry would need object motion data and additional history tests.

## Version 1.2 city-window coverage

Mapped nearby facades introduce many more subpixel lit and unlit windows. Lit neighbors formerly widened a dark room's temporal luminance bounds, and moving emitter coverage could be treated as reusable surface lighting. Current-frame moment weights now respect the albedo and roughness discontinuity. At night, surfaces with a pixel footprint larger than 0.25 m use current-frame spatial reconstruction without temporal history: unresolved ironwork, window openings and their stone surrounds are no longer stable per-pixel surfaces. Close detail and nearby water retain reprojection. Visible emitters bypass both temporal and spatial reconstruction, retaining exact current jittered coverage; lit/unlit guides cannot borrow one another's history. This trades some fine-window sampling noise for correct motion and removes that source of bright trails. Water remains a nonemissive reflecting surface and retains the motion filter.

The GPU harness adds a neighboring-room regression and an exact-current-coverage emitter regression, while retaining the original sky, dark-background, geometry-edge, zoom and reflection checks. The real-scene suite now covers overview, ironwork, night silhouettes and day/night river views. Each case resets its seed independently, so a night-only run reproduces that case in the complete suite.

The original dark-city absolute RMSE threshold measured a much less detailed city region. New window coverage increased even the unfiltered Monte Carlo baseline above that threshold, so the suite now reports dark-region raw and reconstructed RMSE separately. It also runs a matching-seed, history-disabled spatial baseline. Maximum extra temporal brightness over the maximum of current raw, independent reference and spatial-only output must remain below 0.10 in normalized display RGB. The same dark-reference region is used, without eroding away pixels beside lit windows. The clear-sky RMSE threshold of 0.004 and deterministic zero-trail synthetic checks remain. Both image RMSE and temporal residual must improve for every tested route.

## Selective glossy path regularization

Daytime river and glass movie review exposed isolated bright samples that appeared when a second opaque path interaction was enabled. A broadly sampled first bounce can encounter a narrow secondary glossy sunlight lobe, producing rare, large contributions even with correct GGX sampling. The renderer follows [PBRT's selective path regularization](https://pbr-book.org/4ed/Light_Transport_I_Surface_Reflection/A_Better_Path_Tracer#sec:path-regularization): after the first non-delta scatter, a later GGX surface with `alpha < 0.3` uses `alpha = clamp(2 * alpha, 0.1, 0.3)`. Here `alpha = roughness²`, so the stored roughness is the square root of the adjusted alpha.

An explicit flag belongs to each path branch. Only an accepted ordinary BRDF sample sets it. Perfect thin-sheet reflection and transmission do not, and the saved camera-glass reflection starts with its own clear flag even though its bounce counter starts at one. Each opaque interaction constructs one adjusted surface shared by sunlight, local-light evaluation, BRDF sampling, the mixture PDF and throughput evaluation. Directly viewed surface roughness and surfaces first seen through perfect glass retain their original values. A path that has already scattered from an ordinary material can still be regularized after subsequently crossing glass.

This deliberately broadens some indirect glossy lighting and is biased; it is not an additional image blur or a global brightness reduction. The existing radiance cap of 32 is unchanged. `RenderOptions.regularization` defaults to true; `FrameUniforms.origin.w` carries the flag without changing the 128-byte ABI. Use `--no-regularization` to disable the rule in a comparison. `--raw` independently disables reconstruction, and presentation remains exposure, tone mapping and sRGB conversion only. Disabling both options still retains the existing sample cap and other documented rendering approximations.

Run `swift scripts/validate-regularization.swift`. It executes the production Metal tracer on small real triangle scenes and verifies the alpha rule, GGX mixture PDF, and agreement between direct-light and sampled-path evaluation. For each of 4,096 pixels, first-surface, two-sheet transmission and first camera-reflection radiance remain bit-identical with regularization enabled or disabled. A test-only observation at the saved reflection's opaque hit also proves its roughness is unchanged after the transmitted branch has sampled an ordinary material. A diffuse-patch/secondary-glossy-wall sunlight fixture reduces pixel variance from 0.0049735 to 0.0001459 and peak luminance from 0.91798 to 0.08684; mean luminance changes from 0.02774 to 0.03126. These controlled-fixture measurements demonstrate the variance/bias tradeoff and are not whole-scene quality claims. Negative controls fail if the implementation substitutes a bounce counter, shares state between camera-glass branches, or disables the rule.
