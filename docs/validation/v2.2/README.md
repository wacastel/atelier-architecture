# Atelier 2.2.0 — compact navigation and overhead Map mode

Build 15 adds compact map sizes, 33 semantic landmark destinations, linked dot/name highlighting, fixed north-up Map mode and pinch zoom routing. Map mode uses the same resident Chicago scene; geometry, shaders, music and the 56 Chicago routes are unchanged. Its haze override keeps the overhead view legible at city scale.

| Scope | Result |
| --- | --- |
| Map sizes, catalog, collision-free labels and text/dot hit identity | 24,864 checks; [report](navigation-map.json) |
| Camera framing, map pan/span and pinch math | 6,260 checks; [report](manual-navigation.json) |
| Actual EngineController transitions and 33 semantic destinations | 544 checks; [report](map-mode-integration.json) |
| Pointer ownership and Map key/button restrictions | 449 checks; [report](viewport-input.json) |
| Focus/orbit regression | 1,605 checks; [log](focus-navigation.txt) |
| Signed arm64 application and source/resource pairing | Pass, all 26 resources; [manifest](package.json), [build log](build-app.txt) |
| Native app interactions and rendered views | Scoped pass; [observations and limits](native-review.json) |

The Large inset is constrained to 45% of viewport width and height, at most 20.25% of its area. Representative downtown layouts display 7/14/20 labels in Small/Medium/Large, with counts varying as labels avoid collisions. The controller fixture uses the actual production camera, map and playback code with inert audio, and creates no renderer, Metal device or city geometry. It does not replace native event dispatch or collision-model checks.

Native checks cover map label/dot clicks, overhead panning and button zoom, blocked route shortcuts, return to the current neighborhood, compact-window/fullscreen layouts, and overhead day/night ray tracing plus daylight raster. Earlier screenshots precede two final UI-only refinements; images prefixed `final-` were captured after a fresh launch of the packaged executable in the manifest. [Final overhead view](native/final-map-mode.jpg), [final Adler centering](native/final-map-adler.jpg), [final disabled map settings](native/final-map-settings.jpg), [compact window](native/compact-window-large-map.jpg).

Physical trackpad pinch and hover-only event delivery remain unverified by native automation. Pinch transforms, shared hover/click identity and mode isolation have CPU/source coverage. Focus tests cover the dolly primitive; they do not inject a native focused pinch. These stills and scoped interactions are not a continuous-motion or FPS benchmark. No new offscreen GPU harness was run; historical renderer results retain their earlier release scope.

Controls and behavior are documented in [Map mode](../../MAP-MODE.md). The [Chicago Cultural Center](../../NEXT-CHICAGO-LANDMARK.md) is a researched suggestion for the next request, not a new modeled destination in this release.
