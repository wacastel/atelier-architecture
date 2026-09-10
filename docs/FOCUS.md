# Object focus — Atelier 2.4.0

Click visible geometry on a landmark or mapped building to focus the camera on that object. The focus name appears in the interface, and a tint and outline mark its selected visible surfaces. Normal 3D selection keeps the camera's position and turns its view toward the object's center; it takes manual control and leaves any active walkthrough, Chicago demo or idle cycle. Fixed Map mode can show the same selection while retaining its vertical camera.

| Control | Behavior |
| --- | --- |
| Click a visible object while unfocused | Select that object |
| Click a different visible object while focused | Release the current focus and keep the pose; another click can select the new object |
| Click the focused object again | Keep its selection and current camera pose |
| Click sky or an unrecognized surface | Release focus and keep the current camera pose |
| Left or right mouse drag | Orbit around the focused object's center |
| Mouse wheel or two-finger trackpad scroll | Move closer to or farther from the focused object |
| Trackpad pinch | Move closer to or farther from the focused object while retaining focus |
| **T** in normal 3D exploration | Look exactly down at the selected object's centre, preserving focus and lens, with roof clearance |
| **Escape** or the focus label's clear button | Release focus; keyboard navigation remains available |
| **WASD / Q–E** in normal exploration | Clear focus and move manually |
| **WASD** in fixed Map | Pan cardinally while retaining selection, height and lens; Shift triples speed |
| **G / ⌃⌘F** | Toggle full screen while retaining focus and resetting held movement |

A drag is distinct from a click, so finishing an orbit does not select an object beneath the pointer. These orbit and dolly controls apply to the normal 3D camera. Fixed Map mode always pans and zooms its ground coverage, including while an object is selected. Without focus in normal exploration, left dragging pans over the ground plane, right dragging or Shift-left dragging looks around, and scrolling changes flight speed. Pinching without a focus changes the optical field of view, preserving camera position and direction. Pinching with a focus changes the camera’s distance from the object instead. It takes manual control and ends any guided playback, but retains the selected object.

**T** keeps normal Fly navigation available. With no focus it keeps the camera's horizontal position and points at the local surface; with focus it moves horizontally over the selected object's centre. It preserves height unless nearby roofs require a higher position, allowing at least 40 metres of clearance. Focused pinch or scroll preserves the exact vertical direction; an explicit orbit drag changes the angle and restores the ordinary 85-degree orbit limit. **WASD** follows a horizontal compass heading at every camera pitch, while **Q / E** controls Fly altitude.

Orbit distance and elevation have limits around the selected object's envelope. Selecting from inside that envelope retains the starting position; the first orbit or zoom can move the camera outward to its clearance boundary. Orbiting is not a collision-checked pedestrian route around neighboring buildings.

A distant selection, such as Willis Tower from Oak Park, retains its entry distance as the outward orbit limit when it exceeds the usual object-relative limit. Rotation preserves that radius; scrolling or pinching moves inward gradually. Nearby selections retain their established limits. The historical [2.1.1 CPU regression](validation/v2.1.1/focus-navigation.json) covers the original distant orbit/scroll change; it does not validate the new pinch input.

Changing day/night lighting, exposure, rendering quality or the renderer retains focus. The renderer menu selects Path Tracing, Direct Ray Tracing or Fast Raster; **R** cycles Path Tracing → Direct Ray Tracing → Fast Raster. Moving the window, resizing it or entering full screen with **G**, **⌃⌘F** or the button also retains focus. Held movement is cleared for window/full-screen transitions and mode changes. Titlebar movement and live resizing hold both the camera and scene clocks, including moving traffic and the planetarium show. They resume without a catch-up jump when the gesture ends. Opening help releases held movement keys and cancels an active pointer gesture.

Starting or seeking a walkthrough, using its shuttles, choosing a view or destination, starting idle cycling, or starting the Chicago demo clears focus. Use **Play / Space** to return to the selected view's guided route. The [Chicago demo instructions](DEMO.md) explain its transport controls; the current sequence includes 64 Chicago routes.

The Cultural Center is a named focus target with its rotated footprint and roof envelope. Robie House retains its separate roof and service-wing volumes, and the Hyde Park map layer provides surrounding building targets along the southern corridor.

## Map selection and focus

The compact navigation map's dot and text identify the same architectural landmark. Hovering either highlights both. Selecting either, or choosing a Places entry, frames and focuses the landmark in one action, replacing a prior focus deliberately. Authored landmarks use their stable architectural identity; broader park and district entries use a shallow region envelope. Clicking a blank mapped point chooses the general roof-cleared overlook and clears focus.

**B / Map mode** enters a north-up perspective overhead view and clears the entry focus. A later map/Places selection or viewport click can select an object and display its highlight. Selection does not tilt the camera: left dragging pans, right dragging is ignored, and pinch or scroll changes ground coverage. Viewport clicks use the same retain-same/clear-elsewhere policy. **B** or **Escape** leaves Map mode at a roof-cleared 3D overlook of the current map centre and clears that map selection. [Map mode controls](MAP-MODE.md).

The highlight is a presentation overlay on visible surfaces within the selection envelope. It does not change material colors, illumination, traced reflections or the accumulated lighting. It is not an X-ray outline of hidden geometry. Broad region selections and a surface near an envelope boundary can include more than a single architectural mesh; transparency and raster depth have the limits described by the renderer validation.

## What a click can select

Picking casts a ray through the clicked viewport position into static scene geometry. It uses the first represented surface hit, then associates that position with a named landmark or mapped building footprint. It does not select a hidden building merely because the pointer falls inside that building's large bounding volume. Courtyards and footprint holes are retained in the mapped selection regions.

This is a static geometric selection system with practical limits:

- Glass counts as a surface. Picking does not trace optical transmission or choose objects seen only in a reflection.
- Small decorative triangles can be absent from the normal navigation geometry used for picking. Tiny decorations, plants, façade parts and moving traffic are not independent selectable targets. Because traffic is excluded, it does not act as a picking occluder.
- Selection identifies an architectural object or mapped building component, rather than every rendered mesh. Unrecognized surfaces clear focus.
- The camera's orbit clearance is based on the selected object's envelope. It does not guarantee a clear view or collision avoidance against the rest of the city.

Cloud Gate needs a special case: its finely tessellated shell was entirely absent from the normal navigation triangle set. A compact, additional picking hierarchy includes those omitted triangles within the Bean's region and combines its nearest hit with the ordinary scene query. The full curved shell can therefore be selected and can occlude objects behind it. This supplement is used only for picking; the existing walking collision and floor-support queries remain unchanged.

The focus catalog and picking structures are retained across all eight Chicago destinations along with the shared world. Switching between Chicago and Paris loads the appropriate independent world and catalog.

## Validation

Version 2.4.0 passes [755 actual-controller checks](validation/v2.4/map-mode-integration.json), including selection retention during repeated Map WASD steps, full-screen input reset, all three renderer choices and remembered ray-tracer toggling. [6,824 navigation checks](validation/v2.4/manual-city-navigation.json) verify compass directions, speed and framing math, while [449 pointer/key checks](validation/v2.4/viewport-input.json) cover pointer ownership and the updated key allowlist. No native window, Metal device or city collision world is constructed by these fixtures. The [Direct GPU fixture](validation/v2.4/direct-ray.json) and [presentation fixture](validation/v2.4/direct-presentation.json) separately verify primary-depth selection and occluder/sky exclusion. [Native app checks](validation/v2.4/native.json) verify the Cultural Center highlight and focus retention through R mode switches. The older checks below remain evidence for their original scope.

### Historical version 2.3.0

Version 2.3.0 passes [1,662 focus checks](validation/v2.3/focus-navigation.txt), [6,765 manual-navigation checks](validation/v2.3/manual-city-navigation.json) and [662 actual-controller checks](validation/v2.3/map-mode-integration.json). These cover same-object retention, clearing a different hit without replacement, semantic map selection, horizontal travel, T and exact-pole focused zoom. The [39,496-check GPU fixture](validation/v2.3/raster.json) includes selected-surface changes in both render modes, unchanged foreground/sky and exact output restoration after clearing selection. No added ray pass is used for raster selection.

The [final city gallery](validation/v2.3/cultural-rendering.json) includes inspected Cultural Center focus images in raster and reconstructed ray tracing. The [signed build 16 package](validation/v2.3/package.json) and [native review](validation/v2.3/native-review.json) confirm map-label focus, gold selection in both renderers, retention on another click of the same roof, clearing on the street, selecting again and **T** producing a vertical focused normal camera. In fixed Map mode, selection retained the vertical camera through button zoom; changing destination cleared it.

Physical pinch and sustained W/S travel were not established by native automation. CPU math and controller fixtures cover their defined behavior, but do not establish physical event delivery. These results do not claim a native frame-rate benchmark or continuous-motion noise acceptance. [Release evidence and limits](validation/v2.3/README.md).

### Historical version 2.2.0

Version 2.2.0 passed [1,605 focus regression checks](validation/v2.2/focus-navigation.txt), [6,260 manual-navigation/pinch-math checks](validation/v2.2/manual-navigation.json), [449 pointer/key checks](validation/v2.2/viewport-input.json) and [544 actual-controller checks](validation/v2.2/map-mode-integration.json). The controller fixture does not attach a Metal view or collision catalog; its scope does not establish native selected-object pinch dispatch. Physical trackpad pinch has not been exercised. [The current validation notes](MAP-MODE.md#validation) separate native observations from remaining checks. Earlier release checks remain in [Validation](VALIDATION.md).
