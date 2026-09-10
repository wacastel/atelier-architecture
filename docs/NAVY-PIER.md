# Navy Pier — a new Chicago destination

Version 2.5.0 adds Navy Pier to the shared Chicago scene, after Chicago Lakefront in the location list and Chicago demo. Seven two-minute architectural studies and a three-minute connecting flight add eight routes. The full Chicago demo now contains 72 routes. The pier uses the existing Metal acceleration structures, renderer selector, day/night passes, focus controls, map navigation and ambient-music transport.

## Architecture and setting

The model develops the Centennial Wheel and its enclosed gondolas, Pier Park, the Family Pavilion and glazed garden roofs, Chicago Shakespeare Theater and The Yard, the long Festival Hall and Sable Hotel elevations, the historic Grand Ballroom and east end, waterfront promenades and boats. The mapped approach includes Polk Bros Park, Jane Addams Park, Ohio Street Beach and Olive Park. The source ledger and modeling limits are recorded in [architectural references](NAVY-PIER-ARCHITECTURE.md) and [map/aerial evidence](NAVY-PIER-MAP.md).

The map fixes the footprint and arrangement; photographs inform masonry, metalwork, roofs, glazing and light placement. Ornament, hotel bays, boat details and fixture powers are authored interpretations. This release concentrates on the exteriors, public decks and landscape; it does not reconstruct museum exhibitions, theater productions or every interior room. The wheel and boats are modeled static geometry. Camera motion provides the guided animation.

No third-party aerial or architectural photographs are bundled as textures. The app loads a derived OpenStreetMap resource offline, with attribution, source IDs and reproducible preparation inputs. Existing overlapping generic geometry is suppressed within the authored site instead of rendering a second pier through the detailed one.

## Eight views

| View | Study | Length at 1× |
| --- | --- | --- |
| 1 | A pier for the city — the complete waterfront composition | 2:00 |
| 2 | The Centennial Wheel — structure, cabins and colored light | 2:00 |
| 3 | The gateway and the gardens — Polk Bros Park and Family Pavilion | 2:00 |
| 4 | Shakespeare on the water — theater and South Dock | 2:00 |
| 5 | Rooms above the lake — Sable Hotel's south elevation | 2:00 |
| 6 | The Grand Ballroom — historic dome and east end | 2:00 |
| 7 | Boats beside the pier — north marina and skyline | 2:00 |
| 8 | From Millennium Park to Navy Pier | 3:00 |

Each view has a gentle idle orbit. Play starts its own route; transport, pace, view holding and day/night cycling follow the existing controls. These are cinematic camera positions, including positions above water. They do not claim that every camera position is accessible on foot. The connecting flight starts at Millennium Park's opening bookmark and ends exactly at Navy Pier's opening bookmark.

## Presentation and controls

The wheel's blue/cyan light accents contrast with warm masonry and promenade illumination at night. All three renderers show the same modeled geometry. Path and Direct Ray Tracing use actual scene intersections for reflections and shadows; Fast Raster retains its existing approximations. The sunset building-lights setting also controls the pier's fixed decorative and site fixtures, while preserving the sky, sun and vehicle lighting. Day and night settings keep their established behavior.

**R** cycles Path Tracing → Direct Ray Tracing → Fast Raster → Path Tracing, preserving the camera and playback state. The renderer menu still offers direct selection. In lighting settings, **Building lights at sunset** defaults to on and can be switched off for an unlit architectural silhouette against the sunset.

The inset map adds Navy Pier at every size, Centennial Wheel and Grand Ballroom at medium/large, and Shakespeare Theater, Sable Hotel and Polk Bros Park at large. Label placement continues to avoid collisions. Landmark selection resolves the modeled focus identity, with separate focus volumes for the wheel, theater, hotel and ballroom.

“Turning Above the Water,” an original 2:15 ambient piece, starts when selecting Navy Pier and then joins the shared playlist. The previous nine music assets are unchanged.

## Reproduce

```sh
./scripts/build-app.sh
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location navypier \
  --gallery output/navy-pier-day --renderer raster --lighting 1
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location navypier \
  --gallery output/navy-pier-night --renderer direct --lighting 2
./dist/Atelier.app/Contents/MacOS/ArchitectureEngine --location skyline \
  --stop 0 --renderer direct --lighting 3 --sunset-lights-off \
  --render output/willis-unlit-sunset.png
```

The final signed arm64 **2.5.0 build 20** package has all **30 bundled resources matching source**. [Package verification](validation/v2.5/package.json). The shared static city contains **46,966,436 triangles**, with approximately **8,520.5 MiB** of offscreen Metal allocations. The authored pier itself adds 525,840 triangles and 174 bounded local lights; new context and nearby detail account for the remainder. These are geometry/allocation measurements, not native frame-rate claims.

Validation passes include **121,182 playback checks** with no blocked or near-surface camera samples, **17 pier geometry checks**, **25,052 map checks**, **851 actual-controller checks**, **449 viewport input checks**, **63 GPU sunset-light checks**, **281 audio transport checks** and **183 decoded-audio checks**. Full-world focus/navigation integration also passes. [Saved evidence](validation/v2.5). Controller and input fixtures are distinct from native UI interaction; no final native UI timing or sustained FPS result is claimed.

All eight bookmarks were inspected in daylight (Fast Raster) and at night (Direct Ray), plus a matched skyline sunset with lights on/off. [Day contact sheet](validation/v2.5/day-contact.jpg) · [Night contact sheet](validation/v2.5/night-contact.jpg) · [Sunset comparison](validation/v2.5/sunset-comparison.jpg) · [Visual review and limits](validation/v2.5/visual-review.json). The review corrected two implausible legacy building heights, improved the overview framing and refined decorative lighting. A deterministic ray tracer removes Monte Carlo grain; it does not make every material, sampled edge or water ripple identical to a photograph.
