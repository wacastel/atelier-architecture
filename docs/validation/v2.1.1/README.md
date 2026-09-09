# Atelier 2.1.1 — map marker and skyline viewpoints

Build 14 adds the dotted camera marker, three distinct Skyline origins, a clear-distance atmosphere for Oak Park, and continuous orbit distance when selecting a faraway landmark. Eight Skyline routes and the existing Chicago world remain; static geometry is still 45,496,818 triangles. The far-west ground slabs have a plain matte land material, without new suburban infrastructure or map coverage.

| Scope | Result |
| --- | --- |
| Map projection, marker containment, bearing/distance and interaction math | 21,434 checks; [report](navigation-map.json) |
| Distant and nearby focus/orbit | 1,605 checks; [report](focus-navigation.json); old behavior fails the 21 new distant assertions |
| Playback and sampled routes | 92,867 checks, no failures; [log](skyline/playback.txt) |
| Skyline GPU contract and stills | 131 checks, 24 stills; [render report](skyline/validation.json), [visual review](skyline/visual-review.json) |
| Raster regression | 39,485 checks; [report](raster-regression.json) |
| Packaged Oak Park execution | RT and raster self-tests pass from separate working directories; [commands and hashes](package-rendering/runs.json) |
| Signed arm64 application | All 26 resources match their source files; [package manifest](package.json), [build log](build-app.txt) |
| Native UI | **Blocked by the locked Mac**; [remaining checks](native-review.json) |

The gallery includes eight authored raster compositions, ten RT studies at 64 samples, and midpoint/end raster frames for the three new routes. Three labeled contact sheets record the inspected final images. Route sampling and still renders do not establish continuous-motion noise or native window frame rate. Raster retains its existing approximate environment reflections, glass and indirect-light limitations.

Oak Park is approximately 13.6 km west of Willis. Its cropped telephoto framing follows the documented eastward view, while its intervening land stays generalized. Kinzie and Ping Tom are elevated compositions inspired by the reference photographs, not exact reproductions of the photographers’ camera heights or newly reconstructed park/bridge details. [Reference evidence](../../SKYLINE-REFERENCE-UPDATE.md) and [final camera/lighting choices](../../SKYLINE.md).

CUA could not open the application for interaction checks because the Mac was locked. The user was asked to unlock it. This release does not claim native verification of the dotted marker, its live tracking, the revised viewpoint selection or distant object focus. Earlier native results apply only to their recorded release.
