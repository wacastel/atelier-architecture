# Object focus — Atelier 2.2.0

Click visible geometry on a landmark or mapped building to focus the camera on that object. The focus name appears in the interface. Selection keeps the camera's position and turns its view toward the object's center; it takes manual control and leaves any active walkthrough, Chicago demo or idle cycle.

| Control | Behavior |
| --- | --- |
| Click a different visible object | Change focus to that object |
| Click the focused object again | Release focus and keep the current camera pose |
| Click sky or an unrecognized surface | Release focus and keep the current camera pose |
| Left or right mouse drag | Orbit around the focused object's center |
| Mouse wheel or two-finger trackpad scroll | Move closer to or farther from the focused object |
| Trackpad pinch | Move closer to or farther from the focused object while retaining focus |
| **Escape** or the focus label's clear button | Release focus; keyboard navigation remains available |
| **WASD / Q–E** | Clear focus and move manually |

A drag is distinct from a click, so finishing an orbit does not select an object beneath the pointer. Without focus, left dragging pans over the ground plane, right dragging or Shift-left dragging looks around, and scrolling changes flight speed. Pinching without a focus changes the optical field of view, preserving camera position and direction. Pinching with a focus changes the camera’s distance from the object instead. It takes manual control and ends any guided playback, but retains the selected object.

Orbit distance and elevation have limits around the selected object's envelope. Selecting from inside that envelope retains the starting position; the first orbit or zoom can move the camera outward to its clearance boundary. Orbiting is not a collision-checked pedestrian route around neighboring buildings.

A distant selection, such as Willis Tower from Oak Park, retains its entry distance as the outward orbit limit when it exceeds the usual object-relative limit. Rotation preserves that radius; scrolling or pinching moves inward gradually. Nearby selections retain their established limits. The historical [2.1.1 CPU regression](validation/v2.1.1/focus-navigation.json) covers the original distant orbit/scroll change; it does not validate the new pinch input.

Changing day/night lighting, exposure, rendering quality or ray-tracing mode retains focus. Moving the window, resizing it or entering full screen also retains focus. Titlebar movement and live resizing hold both the camera and scene clocks, including moving traffic and the planetarium show. They resume without a catch-up jump when the gesture ends. Opening help releases held movement keys and cancels an active pointer gesture.

Starting or seeking a walkthrough, using its shuttles, choosing a view or destination, starting idle cycling, or starting the Chicago demo clears focus. Use **Play / Space** to return to the selected view's guided route. The [Chicago demo instructions](DEMO.md) explain the complete 56-route sequence.

Robie House is a named focus target, including its separate roof and service-wing volumes. The Hyde Park map layer adds surrounding building targets along the southern corridor.

## Map selection and focus

The compact navigation map’s dot and text both identify the same architectural landmark. Hovering either highlights both; selecting either frames the landmark around its fixed centre with room for its geometry. This is a navigation action, rather than a viewport object-focus selection. Clicking a blank mapped point retains the general roof-cleared overlook behavior. After navigating, click visible geometry in the normal 3D viewport to begin an object orbit.

**B / Map mode** enters a north-up perspective overhead view and clears focus. Main-viewport object picking and orbit are disabled there: left dragging pans, right dragging is ignored, and pinch or scroll changes the ground coverage. **B** or **Escape** leaves Map mode at a roof-cleared 3D overlook of the current map centre. [Map mode controls](MAP-MODE.md).

## What a click can select

Picking casts a ray through the clicked viewport position into static scene geometry. It uses the first represented surface hit, then associates that position with a named landmark or mapped building footprint. It does not select a hidden building merely because the pointer falls inside that building's large bounding volume. Courtyards and footprint holes are retained in the mapped selection regions.

This is a static geometric selection system with practical limits:

- Glass counts as a surface. Picking does not trace optical transmission or choose objects seen only in a reflection.
- Small decorative triangles can be absent from the normal navigation geometry used for picking. Tiny decorations, plants, façade parts and moving traffic are not independent selectable targets. Because traffic is excluded, it does not act as a picking occluder.
- Selection identifies an architectural object or mapped building component, rather than every rendered mesh. Unrecognized surfaces clear focus.
- The camera's orbit clearance is based on the selected object's envelope. It does not guarantee a clear view or collision avoidance against the rest of the city.

Cloud Gate needs a special case: its finely tessellated shell was entirely absent from the normal navigation triangle set. A compact, additional picking hierarchy includes those omitted triangles within the Bean's region and combines its nearest hit with the ordinary scene query. The full curved shell can therefore be selected and can occlude objects behind it. This supplement is used only for picking; the existing walking collision and floor-support queries remain unchanged.

The focus catalog and picking structures are retained across all seven Chicago destinations along with the shared world. Switching between Chicago and Paris loads the appropriate independent world and catalog.

## Validation

Version 2.2.0 passed [1,605 focus regression checks](validation/v2.2/focus-navigation.txt), [6,260 manual-navigation/pinch-math checks](validation/v2.2/manual-navigation.json), [449 pointer/key checks](validation/v2.2/viewport-input.json) and [544 actual-controller checks](validation/v2.2/map-mode-integration.json). The controller fixture does not attach a Metal view or collision catalog; its scope does not establish native selected-object pinch dispatch. Physical trackpad pinch has not been exercised. [The current validation notes](MAP-MODE.md#validation) separate native observations from remaining checks. Earlier release checks remain in [Validation](VALIDATION.md).
