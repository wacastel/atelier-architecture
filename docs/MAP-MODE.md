# Map navigation — Atelier 2.2.0

Chicago has two map controls: **M** shows or hides a compact navigation inset, and **B** changes the main viewport to a fixed overhead Map mode. Both use the existing resident Chicago world. Paris retains normal 3D navigation; the overhead mode is available only in Chicago.

## Compact navigation map

Small, Medium and Large all remain picture-in-picture overlays. The largest card is bounded to 45% of the viewport’s width and 45% of its height, at most 20.25% of the viewport area; smaller sizes use the same fit factor. Large no longer fills the application window. The inset keeps north at the top and preserves geographic proportions.

The map draws from a catalog of 33 named landmarks. Larger cards expose more labels: the representative downtown layout shows approximately seven in Small, fourteen in Medium and twenty in Large. These are not fixed counts. Visibility depends on map centre, zoom, available space and overlap avoidance; labels can be omitted when they would obscure one another or the camera marker. The Places menu always lists the full catalog.

Hover a landmark dot or its text to highlight both. Clicking either selects the same landmark identity, even when the label has been moved aside to make room. In normal 3D exploration, the camera frames the landmark’s fixed architectural centre and envelope, accounting for the window’s aspect ratio and nearby roofs. Clicking bare map ground instead selects a general roof-cleared overlook. These navigation actions preserve lighting, enter manual exploration and end automatic playback; they associate the nearest existing architectural study with Play. They do not activate object focus.

Dragging moves the inset and real camera together, and release after a drag does not become a click. The inset’s magnifier buttons change its map scale; its recenter button returns the inset to the camera. A 24-point dotted marker indicates the camera. For a position outside map coverage, or outside the current crop, an edge indication reports direction and distance rather than presenting that edge as the actual camera location.

## Main overhead Map mode

Press **B**, use the **Map mode** button, or choose **Map** in the Navigation picker. The main camera looks straight down with north up. It is a **perspective overhead view**, not an orthographic projection. The existing buildings, water and traffic remain rendered by the selected ray-tracing or raster mode.

| Control in Map mode | Behavior |
| --- | --- |
| Left drag, including Shift-left drag | Pan while preserving the north-up orientation |
| Pinch or mouse wheel / two-finger scroll | Zoom the overhead view |
| **− / +** or the main map’s magnifier buttons | Zoom out / in |
| Inset landmark dot, text or Places selection | Recenter the overhead view and fit the named landmark |
| Bare inset-map click | Recenter the overhead view at that point |
| **R / N / M / H / ?** | Rendering mode / day-night / inset visibility / interface visibility / help |
| **B / Escape / Return to 3D view** | Exit to a 3D overlook above the current map centre |

Right dragging is ignored, and clicking geometry in the main viewport does not focus an object. Fly/Walk movement keys, camera rotation, view-selection shortcuts and animation transport are inactive. Exit Map mode before resuming a guided route or ordinary camera exploration. Entering Map mode takes manual control and clears any object focus. Exiting uses the current map centre, with camera height adjusted for nearby roofs; it does not jump back to the entry position.

Zoom controls the visible **vertical span at ground level**, from 50 m to 24 km. The camera stays at least 650 m above the scene’s ground origin. Close zooms narrow the lens while wider views raise the camera; the centre and north-up orientation remain fixed. Roofs are elevated above the reference ground plane, so their apparent size follows perspective. Panning stays within the established Chicago navigation bounds; Map mode does not add geographic coverage or buildings.

## Pinch in normal exploration

Without object focus, pinching changes the optical field of view between 1.5° and 100° without translating or rotating the camera. With focus, it moves the camera toward or away from the object and preserves that focus. Pinching takes manual control, so it ends an active idle cycle, walkthrough or Chicago demo. Wheel and two-finger scrolling retain the previous flight-speed behavior when the normal 3D view has no focus. [Object focus and its limits](FOCUS.md).

These navigation changes do not alter music, scene geometry or the 56-route Chicago demo. The [Chicago Cultural Center suggestion](NEXT-CHICAGO-LANDMARK.md) remains a proposal for a future request; no new landmark was built for this update.

## Validation

Version 2.2.0’s CPU and package checks passed. [The release evidence index](validation/v2.2/README.md) separates those results from native interaction coverage.

| Scope | Result and evidence |
| --- | --- |
| Compact sizing, 33-landmark catalog, label layout and semantic dot/text hit targets | [24,864 map checks passed](validation/v2.2/navigation-map.json); the central overview contains 7 / 14 / 20 labels in S / M / L |
| Pinch math, optical zoom, landmark framing and overhead camera bounds | [6,260 manual-navigation checks passed](validation/v2.2/manual-navigation.json) |
| Actual controller mode transitions, camera/playback metadata and 33 landmark selections | [544 controller checks passed](validation/v2.2/map-mode-integration.json), with no Metal view or native event dispatch and an inert music stub |
| Pointer ownership and Map-mode key restrictions | [449 input checks passed](validation/v2.2/viewport-input.json) |
| Focus orbit and selection regression | [1,605 focus checks passed](validation/v2.2/focus-navigation.txt), without city geometry or GPU dispatch |
| Final application package | [Version 2.2.0, build 15](validation/v2.2/package.json): native arm64, strict signature verification passed, all 26 bundled resources match source |

The [native review passed its scoped checks](validation/v2.2/native-review.json). A fresh launch of the final packaged executable confirmed Willis at 400 m/s, the compact Large inset, coordinate clicks on Willis text and the Adler dot, fixed overhead Map mode, left-drag panning, magnifier zoom from 1.8 km to 1.4 km N–S, and blocked Space/2/Up keys. Map settings correctly disabled flight speed and opening-view Reset. Selecting Adler kept Map mode active at a 195 m N–S span; the accessible Frame Willis action returned to Willis within Map mode.

Earlier captures with the same navigation and renderer code also covered all three inset sizes, **B** returning to an overlook at the current Adler centre, ray-traced day/night, raster day, a 1003×686 window and full screen. Those images precede only the final N–S span-label and disabled-Reset UI changes; the final-build observations above followed those changes. The native report keeps these scopes separate.

Physical trackpad pinch and hover-only event delivery remain **unverified**. The available automation did not establish hover delivery when a small scroll positioned the pointer over a label. CPU hit-testing and pinch calculations do not establish those native behaviors. No dedicated GPU validation harness or FPS benchmark was run for this update, and the native stills do not establish continuous-motion quality.

The final package executable SHA-256 is `5714cd946c77399321e8ea1ebab3da8d49041105e195c20762df264cc1a74f70`. Reproducible CPU commands are `./scripts/validate-navigation-map.sh`, `./scripts/validate-manual-city-navigation.sh`, `./scripts/validate-map-mode-integration.sh`, `./scripts/validate-viewport-input.sh` and `./scripts/validate-focus-navigation.sh`.
