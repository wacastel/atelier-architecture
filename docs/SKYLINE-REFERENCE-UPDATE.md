# Skyline viewpoints beyond the lakefront

Research and actual image inspection: September 9, 2026. This document records reference evidence and the initial camera proposals. The version 2.1.1 implementation choices below distinguish those proposals from the selected camera paths. This document does not establish rendering or native application validation; [the Skyline release notes](SKYLINE.md#validation) track that evidence separately.

## Version 2.1.1 implementation choices

The selected opening camera for **Chicago from the west** retains the Oak Park origin approximately 13.6 km from Willis Tower and the authored 55 m height. Its 9° vertical field of view is a tighter telephoto crop than the initial 12–15° proposal below; it targets `(350, 210, -900)` and rises to 76 m during the route. **The river leads downtown** is explicitly an aerial study above Kinzie, opening at 210 m and rising to 260 m with a target height of 230–260 m to frame Willis beyond the contemporary foreground towers. **North from the South Branch** opens above Ping Tom at 18 m and rises to 58 m. The river views therefore do not claim to recreate the reference photographers’ ground or bridge heights.

The western view uses a per-view haze density of `0.000020 m⁻¹` and a consistent clear-blue daytime horizon. The existing far-west fallback ground slabs use plain, rough, muted-green land material, without paving or grass patterns that would be undersampled at this grazing angle. This is generalized, undetailed land; no intervening western-neighborhood infrastructure or map coverage has been added. The image observations and original proposed coordinates below remain research provenance, rather than claims that the final route duplicates a photograph’s lens or exact origin.

## Recommended replacements

Retain the eight-view structure, replacing zero-based views **1, 4 and 6** with Oak Park, Kinzie Street Bridge and Ping Tom Memorial Park respectively. These introduce three different origins: a western suburb facing east, the North Branch facing southeast, and the South Branch facing north. Keep the Adler sunset/night and North Avenue compositions for contrast.

Coordinates below are approximate geographic camera candidates, not recovered photograph GPS. Engine coordinates use the existing Willis origin `(41.878876, -87.635918)`, with x east and z south in meters. Heights and fields of view are authored estimates requiring scene clearance and framing checks.

| Replacement | Geographic area | Proposed engine camera → target | Vertical field of view | Geographic confidence |
| --- | --- | --- | --- | --- |
| 1 · Oak Park, looking east | Near 150 Forest Avenue, approximately 41.889079, -87.7996343 | `(-13569.5, 55, -1135.8)` → `(350, 180, -800)` | Start at 12–15°, refine while retaining both Willis and the northern towers | Building address and elevated eastward view are documented. Approximate building coordinate comes from its owner-authorized directory entry. The exact balcony position and y=55 are inferred. |
| 4 · Kinzie Street Bridge, looking southeast | Road bridge near 41.889120, -87.639340 | Approximately `(-284, 8, -1140)` → `(0, 170, -200)` | 45–52° | Bridge survey/photography site's map pin. Camera height, bank offset and target are authored; reconcile with current bridge geometry. |
| 6 · Ping Tom, looking north | East river edge around 41.8564, -87.6352 | Approximately `(60, 6, 2502)` → `(80, 145, 150)` | 32–40° | Neighborhood-scale estimate within the documented park/river setting, not a measured photo origin. Prefer the 18th Street bridge/boathouse area if its modeled foreground reads better. |

Oak Park is about **13.62 km in a straight line from Willis Tower**, calculated with the project's local geographic projection. Its suggested 45–65 m camera height is a plausible interpretation of a high-floor viewpoint; a 15th-floor caption does not establish surveyed floor or terrain elevations. A narrower telephoto view emphasizes the actual skyline but should retain some terrestrial foreground. It must not replace the western neighborhoods with Lake Michigan.

The initial broader estimate of 9–12° was refined to 12–15° after viewing the photograph: the northern towers spread much farther left than Willis. At a 16:10 viewport this is approximately 19–24° horizontally. This is an authored crop, not a claim about the reference lens settings.

## Images actually inspected

All photographs below were visibly rendered and inspected in Safari, not inferred from search thumbnails or captions. No photographs were downloaded, bundled or redistributed. Pixel dimensions are the selected browser image rendition or the size listed by the image viewer, not a claim that the screenshot displayed them at 1:1 scale.

### Oak Park — a documented western-suburb panorama

[YoChicago's original photograph](https://www.flickr.com/photos/yochicago1/29195721474/) is titled “Chicago skyline, from a 15th floor balcony at Vantage Oak Park apartments.” Its page dates the photograph to **September 20, 2016**, uploaded the following day. The [1024×576 image rendition](https://www.flickr.com/photos/yochicago1/29195721474/sizes/l/) was actually viewed; the size page lists an original of 6894×3878. The ordinary photo page initially showed an empty image area, so inspection used Flickr's public size viewer rather than treating the unloaded page as evidence.

Observed pixels: a clear cyan-blue sky above a long, distant skyline; Willis rises to the right of the central cluster, while Hancock is left of it. Tree canopy, low brick buildings, nearby flat roofs and a straight tree-lined street occupy much of the foreground. The city is visibly beyond a continuous land corridor, and its apparent size is smaller than in the lakefront photographs. The buildings receive clear daylight rather than appearing as backlit sunset silhouettes.

The photographer/publisher's [property article](https://yochicago.com/vantage-oak-park-150-forest-ave-oak-park/) explicitly says higher east-facing apartments see downtown. The developer's [2016 opening announcement](https://www.prnewswire.com/news-releases/vantage-oak-park-21-story-luxury-apartment-tower-now-open-300308535.html), issued by Golub & Company, identifies the 21-story building at 150 Forest Avenue. An [owner-authorized directory entry](https://vantage-oak-park.oakparkdirect.us/profile/) provides the approximate latitude/longitude used above. The historical Vantage name is retained when citing that photograph; the proposed view can simply be called “Oak Park — looking east.”

Inference for lighting: clear afternoon illumination or the existing warm-west sunlight should front-light the eastward view. A west-facing sunset sky must not be rotated behind this skyline just to imitate a lakefront sunset: the sunset is behind an east-facing camera. A sunrise would be a separate solar-direction preset, not the existing Sunset renamed.

### Kinzie — the North Branch corridor

The [UIC Library Digital Collections photograph](https://www.flickr.com/photos/uicdigital/6144403745/) identifies the camera as looking southeast from West Kinzie Street Bridge. Photographer C. William Brubaker took it in **1986**. Its [700×1024 rendition](https://www.flickr.com/photos/uicdigital/6144403745/sizes/l/) was actually viewed; the size page lists a 3619×5292 original.

Observed pixels: the raised railroad bridge cuts diagonally across the upper-left corner; river reflections fill the lower frame; masonry and glass towers form a compact vertical grouping with Willis prominent behind. A low elevated rail crossing runs horizontally in front of the buildings. The portrait photograph provides a strong river-and-bridge composition distinct from an open-water panorama.

[HistoricBridges.org's independently photographed road-bridge record](https://historicbridges.org/bridges/browser/?bridgebrowser=truss/kinzie/) supplies a map pin at approximately **41.889120, -87.639340**. This is the road bridge, not the separate raised railroad bridge just south of it. Its [photo-documentation gallery](https://historicbridges.org/bridges/browser/photosviewer.php?bridgebrowser=truss/kinzie/&gallerynum=1&gallerysize=1) is useful supplementary structural evidence; those gallery pixels were not part of this inspection.

The 1986 image is historical. It establishes a viewpoint and composition, **not today's unobstructed Willis sightline**. Modern buildings may occlude the old tower grouping. Keep current map geometry, choose a small bank offset or an honestly labeled elevated river view where needed, and do not delete newer buildings to force a historical match.

### Ping Tom — the South Branch, landscape and lights

The [Chicago Park District's park page](https://www.chicagoparkdistrict.com/parks-facilities/tom-ping-memorial-park) documents the South Branch location, riverside paths, boathouse, pagoda-style pavilion and a fieldhouse patio with skyline views. Two official **768×512** gallery images were actually viewed:

- [Red lattice and white shelter, IMG_8260.JPG](https://www.chicagoparkdistrict.com/sites/default/files/styles/coh_medium_landscape/public/images/location/IMG_8260.JPG?h=a69dd6f0&itok=yngaC7ZW): a covered foreground walkway, red screen, benches and low planting frame the distant city under an overcast sky. No capture date is supplied on the page.
- [Natural area and skyline](https://www.chicagoparkdistrict.com/sites/default/files/styles/coh_medium_landscape/public/images/location/Ping%2520Tom%2520Park%2520Natural%2520Area-028-Spring071016-DSE-3976%2520.jpg?h=b0bbe8d3&itok=ogsiC0cH): stone steps and a curving path through flowers and meadow planting; a raised truss structure at left; Willis above the trees. The filename contains a date-like string, but it is not treated as verified capture metadata.

For nighttime treatment, [Michael Hoffman's photograph](https://www.flickr.com/photos/mhoffman1/43355994142/) explicitly identifies the **18th Street Bridge** viewpoint and is dated **June 22, 2018**. Its [1024×587 public rendition](https://www.flickr.com/photos/mhoffman1/43355994142/sizes/l/) was actually viewed. Observed pixels: river at left, raised truss across the middle-left, a red-and-white boathouse and bright landscaped paths at right, warm downtown lights behind, and a cool-to-warm cloudy sky. This supports warm park lights and reflective river water; it does not justify copying cloud shapes or treating the photograph's color grading as measured radiometry.

## Implementation implications and limits

Oak Park needs a terrestrial foreground and sufficient geographic coverage. A camera alone does not establish that the entire roughly 14 km corridor is mapped. If distant neighborhood geometry remains approximate, label that limitation and avoid a close flythrough through unsupported context. The primary goal of this view is the eastward skyline silhouette and its relationship to the low urban canopy.

Current aerial perspective should be evaluated at the longer distance. With the existing RT daylight coefficient of 0.00028 per meter, Beer–Lambert transmission at 13.62 km is about 2.2%; the raster coefficient of 0.00018 gives about 8.6%. This mathematical observation predicts substantially reduced contrast, not a measured render result. Any adjustment should be a coherent atmosphere parameter and should preserve existing close scenes; changing camera position or removing buildings does not solve atmospheric over-attenuation.

All three proposed origins require route collision and final image checks in the actual scene. Bridge deck levels, intervening current buildings, terrain coverage and visible foreground detail can change the final camera placement. This research update makes no GPU-performance, camera-clearance or finished-image claims.
