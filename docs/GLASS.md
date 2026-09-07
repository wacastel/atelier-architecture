# Transparent architectural glass

Atelier 1.3 adds opt-in transparent sheets for the Willis Skydeck, Ledge, and selected Catalog glazing. The Eiffel scene retains its original opaque reflective window materials. Material `properties.w` now stores transmission; `SceneMaterial(..., transmission: 1)` selects a thin sheet. The existing 32-byte material and 128-byte frame ABIs remain unchanged; `FrameUniforms.right.w` indicates whether the scene contains transmissive materials.

The implementation evaluates unpolarized air/glass Fresnel at IOR 1.5 and accounts for repeated internal reflections with `R_sheet = 2R / (1 + R)`. At normal incidence a clear sheet reflects approximately 7.69 percent. The first camera sheet traces both branches with deterministic Fresnel weights, preventing low-sample previews from switching between a fully reflected and fully transmitted image. Later path encounters choose reflection or transmission in proportion to their Fresnel contributions. Transmission is parallel to the incident ray and applies the material tint. Single sheets represent complete parallel panes; they should not be doubled into front/back optical surfaces.

Transmitted crossings have a separate bounded traversal allowance so a window does not consume the entire low-depth preview budget. Shadow rays traverse up to 16 sheets with angle-dependent attenuation; opaque objects still block them. This extends existing Metal triangle traversal without changing the geometry acceleration format. Scenes with no transmissive materials retain the faster opaque shadow query.

The deterministic visibility pass looks through sheets to the first opaque surface and records the total camera distance. A fractional guide flag requires current-frame temporal coverage through glass: reflected and transmitted images have different motion, so averaging both against one surface's history would create false trails. Compatible opaque surfaces behind glass retain current-frame spatial filtering; visible emitters and sky retain exact coverage. This conservative choice leaves some sampling grain in moving glass views. Stills progressively converge.

This is a thin, smooth, parallel-pane approximation. It does not model solid-volume refraction, rough glass, spectral dispersion, thick laminated edges, or focused caustics. The bronze office curtain wall and distant city glazing remain opaque reflection/emission proxies; inspected Skydeck panels use actual transmission.

## References and validation

The reflection/transmission sampling follows the principles in [Physically Based Rendering, Dielectric BSDF](https://pbr-book.org/4ed/Reflection_Models/Dielectric_BSDF). Native traversal uses [Apple Metal ray tracing](https://developer.apple.com/videos/play/wwdc2023/10128/).

Run `swift scripts/validate-glass.swift` on a Metal ray-tracing GPU. It exercises production shader code against real triangle acceleration structures: numerical normal/grazing Fresnel, tinted shadow attenuation, an opaque blocker behind a pane, a red emissive target visible through glass at a one-opaque-bounce limit, an opaque control, and behind-glass depth/material guides. `scripts/validate-metal.swift` separately retains daylight/night accumulation and dispatch checks.
