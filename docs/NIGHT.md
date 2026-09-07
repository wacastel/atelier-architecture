# Eiffel Tower after dark

Choose **Night** in the lighting menu or use the moon button, or use `--lighting 2` for a still, gallery or walkthrough export. The same eight viewpoints and routes work in every lighting mode.

## References inspected

Photographs were opened and visually inspected in the browser on September 7, 2026. They are references only: no downloaded photograph is included in the engine, textures, or output.

- The [official night gallery](https://www.toureiffel.paris/en/news/history-and-culture/everything-you-need-know-about-eiffel-tower-night), particularly Pierre Nicou's whole-tower photograph, informed the gold upper lattice, dark terrace bands, black shadow openings and subdued city. The page describes 336 yellow-orange interior spotlights.
- The [official illumination article](https://www.toureiffel.paris/en/news/visit/what-time-does-eiffel-tower-light-and-sparkle) describes 336 high-pressure sodium lamps. Its close-up photograph shows how bright inner members remain separated by nearly black unlit faces.
- Jim Zuckerman's [Eiffel Tower in the Rain](https://www.muralsyourway.com/eiffel-tower-in-the-rain-mural/p) informed the deep blue sky, bright local lamps and elongated golden reflections on rain-soaked stone beneath the arches.

## What is rendered

The rig contains **336 tower uplights**, organized through the four piers and upper truss bays, plus 56 arch/terrace accent projectors, 26 street lamps, and 12 pavilion lights. All 430 sources use inverse-square attenuation, finite range, cone falloff where appropriate, and actual Metal ray-traced visibility. Their positions and photometry are a reconstruction; the source intensity is calibrated in renderer units rather than asserted to be measured candela or electrical watts.

Painted iron retains its normal reflective material. It is **not self-illuminating**. Warm light reflects and bounces through the ironwork, onto other members, the surrounding stone and reflective surfaces. Tiny luminous fixture lenses make the lamps visible, and some city windows emit a restrained warm tone at night. The broad environment and city remain the existing interpreted geometry.

The night sky uses low navy radiance with a small amber horizon component. Rain darkens horizontal stone and adds smooth puddles of varying extent. The ground is a dielectric with a GGX water-like surface; the reflected tower comes from secondary scene rays, not a mirrored decal or projected photograph. Nearby façades retain reflected light and windows while the distant city remains subdued.

Four dominant lights at each surface are shadow traced deterministically. One weighted reservoir samples the remaining candidates and divides by its actual selection probability. Range and cone tests keep the candidate set small. A finite luminaire radius broadens the direct specular lobe to avoid singular point-source highlights; visibility uses the source center. These are practical preview approximations, not a full area-light photometric solution.

Specular paths now use the visible-normal GGX sampling method described by [Eric Heitz, JCGT 2018](https://jcgt.org/published/0007/04/01/), with the matching probability density. This reduces extreme grazing-angle path weights on close ironwork and wet paving. Deterministic primary geometry guides also support the renderer's separate temporal motion reconstruction.

This mode reproduces the steady golden illumination. It does not simulate the hourly sparkling display, moving searchlight shafts, volumetric clouds, surveyed Paris buildings, or the exact installed fixture layout. The visual target is the photographic relationship between light, shadow, color and reflection within the existing architectural reconstruction.
