# Motion reconstruction — version 1.4

Millennium Park adds polished curved steel and a more demanding moving-lighting case. The current renderer combines Owen-scrambled Sobol path samples, smooth vertex-normal guides, bounded angular history for slow glossy motion, and symmetric coverage protection around fine material boundaries. Authored polished GGX lobes remain sharp, including nested Cloud Gate reflections. Conservative spatial light lists reduce the cost of night and always-on museum lighting without changing candidate order or illumination. The actual-scene suite compares raw and reconstructed paths against identical independent high-sample references, with unchanged image-error and temporal-error requirements. Detailed methods, approximation limits and GPU fixtures follow below.

## Retained version 1.3 glass and city safeguards

Chicago retains the validated Paris reconstruction and adds thin-sheet glass. The first camera pane traces both reflection and transmission with deterministic Fresnel weights, reducing low-sample switching noise. Surface guides traverse the pane to the first opaque surface and retain full camera distance. Glass-background surfaces use current spatial filtering and reject temporal history, because reflected and transmitted images do not share one motion vector. Emissive windows and sky still preserve exact current coverage. The guide material flag is +0.75 for non-emissive surfaces behind glass and +0.5 for visible emitters, including emitters behind glass. [Details and limitations](GLASS.md).

Chicago's mapped nearby window occupancy is assigned per pane in deterministic room pairs. It therefore remains aligned with the actual window geometry. The Willis façade pattern follows the same intermediate elevation anchors as the model. Native viewport changes recreate history textures and recompute camera aspect. Location swaps pause submissions, drain the old GPU queue, and reset geometry/camera/lighting history before drawing the replacement scene.

At coarse night resolution, a pixel-center guide can see a dark mullion while its jittered rays include a lit neighboring window. Filtering only the dark-center pixels eroded legitimate window coverage. Spatial filtering now preserves the current 5 × 5 neighborhood around visible emitter guides when the pixel footprint exceeds 0.25 m. Smooth distant water and roofs retain filtering. A moving-window GPU fixture checks 17,520 mixed-coverage samples, alongside the existing disocclusion and light-trail tests.

Presentation now performs only exposure, tone mapping and sRGB conversion. Earlier reports labeled their comparison stream “raw,” but that low-sample stream still used the original 3 × 3 presentation filter; reconstructed and high-sample reference streams bypassed it. The historical reports are retained unchanged. Current comparisons use truly unfiltered samples, with the same strict image-error and temporal-error improvement requirements; percentages across those baseline policies are not directly comparable. A real GPU fixture verifies unchanged pixel coverage at 1, 4 and 128 samples. [Preserved discovery and method notes](validation/v1.3/motion-baseline-notes.md).

`swift scripts/validate-glass.swift` exercises real transmission/reflection/shadow/guide kernels. `swift scripts/validate-denoiser.swift` includes behind-glass temporal rejection and measured current-frame spatial noise reduction, as well as all earlier opaque surface, emission, sky and disocclusion checks. Fine glossy/subpixel and glass sampling grain can remain during motion.

## Paris reconstruction and prior measurements


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
   interpolated shading normal, distance, procedural albedo and roughness. The
   guide normal matches the tracer’s smooth geometry normal before procedural
   ripple perturbation; flat faces retain their flat normal. These guides do
   not jitter with the stochastic path samples.
3. Project each current world position into the previous camera. Bilinear
   history taps are accepted individually only when material, normal, world
   distance, tangent-plane distance and previous ray depth agree. Newly visible
   surfaces restart at one frame. Sky and visible emissive windows/fixtures keep
   current radiance exactly, bypassing temporal history and spatial filtering.
   The material ID carries +0.5 for visible emitters, +0.75 for nonemissive
   opaque surfaces behind glass, and +0.125 for polished conductors. Glass
   rejects temporal history; polished conductors retain bounded angular history
   while bypassing surface-only spatial blur of reflected scene edges.
4. Measure luminance moments in a geometry- and albedo-aware current neighborhood and clip
   stale history against its variance. Blend accepted lighting into history,
   capped at 32 frames. Moving sharp reflections retain as few as two frames.
5. Apply three edge-avoiding à-trous passes with pixel steps 1, 2 and 4. Material,
   albedo, roughness, normal, tangent-plane distance and luminance weights prevent
   filtering through rivets, narrow ironwork and silhouettes. Filter strength
   falls as the stationary path sample count rises. High-contrast material
   boundaries preserve both sides’ local result to retain mixed jittered
   coverage; coarse night emitter neighborhoods retain their existing bypass.
6. Present the reconstructed HDR result with exposure, tone mapping and sRGB
   encoding only. Raw presentation uses the same unfiltered conversion. Preserve the temporal output for the next frame; do not feed
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
| 1 | Current world XYZ; W = material ID plus flag (+0.125 polished conductor, +0.5 emitter, +0.75 through-glass); sky direction XYZ, W = -1 |
| 2 | Current interpolated shading normal XYZ, primary ray distance W |
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

## Better distributed samples and slow glossy motion

Motion now uses a fast Owen-scrambled Sobol sequence for camera jitter, direct sunlight, ordinary BRDF directions, component selection and roulette. The first sixteen dimensions use Joe–Kuo direction numbers; subsequent path domains use independent scrambles when reusing dimensions. Conditional glass decisions and the local-light reservoir retain independent hash random numbers. Aligned groups of four camera samples cover all four pixel quadrants, improving unresolved window and lattice coverage where preserving the current image prevents aggressive denoising. This follows the low-discrepancy sampling and fast nested-scramble approach described in [PBRT's Sobol samplers](https://pbr-book.org/4ed/Sampling_and_Reconstruction/Sobol_Samplers). The data and code notices are retained in the shader, with the accompanying license in `Resources/Sampling-LICENSE.txt`.

`RenderOptions.lowDiscrepancySampling` defaults to true and uses `FrameUniforms.up.w`, preserving the ABI. `--random-sampling` selects the previous independent sampler for comparisons. Raw and reconstructed motion tests use the same sampling mode, and their reports identify it. This sampling change does not add filtering or change the BRDF, reflection geometry, exposure or radiance cap.

Smooth curved surfaces now supply interpolated vertex normals to the deterministic geometry guides, matching the path tracer. Using face normals for those guides had introduced artificial reconstruction boundaries at triangle edges on otherwise smooth reflective geometry.

The previous roughness-only history rule also limited a sharp mirror to two frames during any camera movement. Validated glossy history now considers how much the view direction at the reprojected surface actually changes. Slow movement may reuse up to sixteen frames while the history's estimated angular span stays within one tenth of GGX alpha; fast changes retain the previous two-frame safeguard. Rotation about an unchanged camera position does not itself change the view direction at a fixed surface. Geometry/material checks, current-frame luminance clipping, disocclusion rejection and all night/emitter/glass coverage bypasses remain active. This is a bounded heuristic for the existing combined-radiance filter, not a replacement for separate reflected-surface motion vectors. Full specular motion reconstruction needs separate specular signals and hit-distance information, as discussed in [NVIDIA's NRD integration guidance](https://github.com/NVIDIA-RTX/NRD/blob/master/README.md).

`swift scripts/validate-sampling.swift` executes actual GPU sample generation and glossy ray paths. Its four-sample subpixel-rectangle fixture reduces RMS coverage error by 36.1% and temporal residual by 28.9% compared with independent samples. The small first-surface glossy and secondary-glossy sunlight fixtures reduce RMS by 8.4% and 7.0%, respectively, against independent 1,024-sample references. These are controlled sampling tests, not measured whole-scene reductions. The denoiser suite adds slow glossy movement (raw RMS 0.37487 to temporal RMS 0.06981), bounded history, and exact rejection after a reflection is extinguished; it retains the fast-reflection and coverage regressions. The Metal suite verifies 1,024 smoothly interpolated guide normals across triangle boundaries. Actual Millennium tests cover a slow Bean idle view, an orbit, and close underside views by day and night; `--motion-case` selects a named case for targeted comparisons.

Polished sculpture also retains authored roughness down to 0.02, allowing Cloud Gate's 0.022 material to remain sharp. GGX now clamps its normalized-dot input to [0,1] and evaluates its denominator without the cancellation-prone subtraction or coarse denominator floor that distorted narrow lobes. A Float dot product can round one ULP above one; without the domain clamp, that tiny overshoot can create a false, enormous polished-lobe peak. The GPU boundary fixture checks both sides of one and out-of-domain values against finite, monotonic, peak-bounded behavior. A pure conductor samples only GGX, since it has no diffuse component; its BRDF and PDF use the same proposal. Near-delta conductors (`metallic >= 0.99` and `roughness <= 0.03`) do not start path regularization, preserving nested omphalos reflections. Their reflections still use the finite authored GGX distribution. Once a broader or diffuse scatter has occurred, subsequent polished lobes continue to receive the existing secondary regularization. The slow-history angular budget uses the actual smaller alpha. GPU regressions verify 32,768 conductor samples for roughness preservation, normal-incidence GGX peaks, PDF agreement, bounded energy and the near-mirror Fresnel limit; real nested-conductor paths retain exact radiance with regularization on or off, while a preceding diffuse surface still activates it.

Always-on museum interior sources use `SceneLight.parameters.z = 1`. The renderer builds a compact buffer containing only those fixtures and dispatches a separate `tracePaths<false, true>` daylight specialization. Daylight sky, sunlight and material behavior remain daylight; unflagged city lights stay off, and scenes without interior sources retain the original lightweight daylight kernel. Night continues to use the full scene-light buffer. The GPU suite verifies that the interior specialization adds direct illumination while zero interior sources produce exactly the ordinary daylight result.

## Contrasting material coverage and indexed lighting

Actual 8-SPP Bean night motion testing exposed another asymmetric coverage error: the plaza's 24 mm dark physical joints are narrower than some projected pixels. A deterministic center ray can land on pale stone while jittered radiance contains legitimate dark-joint coverage. Rejecting dark-material neighbors during filtering then erases that fractional coverage from the pale-center pixels. The spatial filter now preserves both sides of a contrasting material boundary within one pixel. Temporal visibility and illumination checks remain active, and stable regions farther from the boundary retain spatial reconstruction. This generalizes the existing symmetric night-window coverage safeguard to dark-on-light geometry. It does not thicken the geometry or replace the actual sample values.

Spatial strength uses an eight-sample confidence scale, `8 / (SPP + 8)`, so already converging samples receive less blur. A low-contrast contact-shadow fixture on a single untextured plane verifies that image detail survives even when albedo and geometry guides cannot identify its edge: maximum error falls from 0.03063 at 8 SPP to 0.01451 at 32 and 0.00460 at 128. The prior eighteen-sample scale fails the 128-SPP fidelity bound. This remains a biased reconstruction; the confidence scale is a tested quality choice, not an estimate of the exact path variance.

The albedo boundary weight also distinguishes moderate-contrast paving texture more strongly. Polished-conductor guides carry a `+0.125` material-ID fraction: their angularly validated temporal result bypasses surface-only spatial filtering, because real reflected scene edges are absent from primary albedo and geometry guides. Emissive `+0.5` and through-glass `+0.75` guide behavior remains unchanged. The GPU suite verifies exact preservation of 6,720 moving dark-joint coverage samples on neighboring pale-center guides, a moderate-contrast one-pixel texture joint (maximum error 0.002149), and sharp colored reflection edges. Removing the new material-boundary guard fails the dark-joint fixture. These tests supplement, rather than replace, the unchanged actual-scene image and temporal error requirements.

Night and always-on interior lighting now use conservative 64 m spatial light lists. Each source appears in every cell touched by its finite-range bounding box, with outward rounding that accounts for Float precision and subtraction from the grid origin. Each cell retains original ascending source indices, so the reservoir sees exactly the same positive-contribution candidates and consumes the same random values. This skips work on sources whose existing range test would return zero. Daytime uses a separate grid for its compact always-on fixture buffer; night uses the complete source buffer. Invalid inputs or bounded memory limits select the original linear traversal, and queries outside an enabled grid return no candidates. `--linear-lights` selects the original traversal for explicit image and timing comparisons.

`./scripts/validate-light-grid.sh` checks 43,860 support/order probes, including both sides of cell boundaries, negative coordinates, tiny-range sources sharing a grid with million-metre coordinates, invalid inputs and memory limits. `./scripts/validate-indexed-lighting.sh` binds the actual CPU grid to the production Metal kernels: 16,384 day/night pixels remain bit-identical with indexed and linear traversal, including cell boundaries, outside-grid queries, both samplers, disabled fallback and an active-count prefix. Reversing candidate order changes the reservoir result and is detected by the fixture. These correctness tests do not substitute for whole-scene GPU timing.

## Version 1.4 measured comparisons

[Preserved failure reports and negative controls](validation/v1.4/motion-discovery-notes.md) document the identified regressions and their fixes; the accuracy thresholds were not relaxed.

The final isolated Bean night comparison uses 32 moving frames at 960 × 600, three path interactions, and the same independent 128-SPP reference sequence for each variant. Image and temporal residual errors are measured over the second half. [Input hashes](validation/v1.4/motion-input.json) and [complete paired measurements](validation/v1.4/motion-comparison.json) identify the final packaged shaders. These GPU times describe that benchmark, not the 2560-pixel Ultra preset or an entire exported video.

| Moving stream | Image RMSE after reconstruction | Temporal residual after reconstruction | Mean GPU time |
| --- | ---: | ---: | ---: |
| Independent random, 4 SPP | 0.04585 | 0.06145 | 14.16 ms |
| Sobol, 4 SPP | 0.04127 | 0.05480 | 14.50 ms |
| Sobol, 8 SPP | 0.03603 | 0.04746 | 27.74 ms |
| Sobol, 8 SPP, linear light traversal | 0.03603 | 0.04746 | 66.48 ms |

At equal 4-SPP budgets, the new sampler reduces reconstructed image error by 10.0% and temporal error by 10.8% compared with the current renderer's independent-random mode. Increasing Sobol to 8 SPP improves those errors by 21.4% and 22.8%, respectively, relative to independent random at 4 SPP. These are cross-sampling comparisons between reconstructed streams. Separately, reconstruction itself improves the 8-SPP Sobol raw image error by 2.45% and temporal residual by 8.79% in this difficult night case. Neither comparison claims that fine glossy noise has disappeared.

Indexed lighting is 2.40 times faster than linear traversal in the isolated 8-SPP case. The controlled small-scene GPU fixture is bit-identical. Independent full-scene runs can differ at isolated ray boundaries, so exported frames are not claimed to be bit-identical across separate acceleration-structure builds; repeated indexed runs exhibit the same isolated variation. The paired report records the actual image differences.

All fifteen final [route-segment regressions](validation/v1.4/motion-summary.json) pass at 8 SPP: each improves both image RMSE and motion-compensated temporal residual against its matched raw stream. These are named 32-frame segments at 960 × 600 with independent 128-SPP references. Complete per-location data are preserved for [Chicago](validation/v1.4/motion-chicago.json), [Millennium Park](validation/v1.4/motion-millennium.json) and [Paris](validation/v1.4/motion-paris.json). Their timing values are excluded from performance claims because parts of the suite ran beside movie exports.

| Route segment | Image-error reduction vs raw | Temporal-error reduction vs raw |
| --- | ---: | ---: |
| Willis overview | 6.29% | 25.73% |
| Willis facade | 48.74% | 57.49% |
| Willis night | 0.08% | 1.16% |
| Chicago River, day | 52.54% | 54.96% |
| Chicago River, night | 25.77% | 27.41% |
| Cloud Gate idle | 49.25% | 65.90% |
| Cloud Gate orbit | 9.45% | 13.60% |
| Cloud Gate night | 2.45% | 8.79% |
| Bean underside, day | 27.15% | 31.07% |
| Bean underside, night | 28.55% | 29.36% |
| Eiffel overview | 3.44% | 33.61% |
| Anatomy of Iron | 41.79% | 61.65% |
| Eiffel night silhouette | 4.43% | 4.93% |
| Seine, day | 22.33% | 36.72% |
| Seine, night | 17.00% | 20.08% |

The final Paris night region has clear-sky RMSE 0.000072 and maximum unsupported temporal brightness 0.0. Dark-region image error improves from 0.021925 to 0.021490. The coarse Willis night segment deliberately receives little filtering to preserve fine lit-window coverage; its small improvement should not be generalized into a claim of noise-free distant windows.
