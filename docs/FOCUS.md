# Object focus — Atelier 2.0

Click visible geometry on a landmark or mapped building to focus the camera on that object. The focus name appears in the interface. Selection keeps the camera's position and turns its view toward the object's center; it takes manual control and leaves any active walkthrough, Chicago demo or idle cycle.

| Control | Behavior |
| --- | --- |
| Click a different visible object | Change focus to that object |
| Click the focused object again | Release focus and keep the current camera pose |
| Click sky or an unrecognized surface | Release focus and keep the current camera pose |
| Left or right mouse drag | Orbit around the focused object's center |
| Mouse wheel or two-finger trackpad scroll | Move closer to or farther from the focused object |
| **Escape** or the focus label's clear button | Release focus; keyboard navigation remains available |
| **WASD / Q–E** | Clear focus and move manually |

A drag is distinct from a click, so finishing an orbit does not select an object beneath the pointer. Without focus, left dragging pans over the ground plane, right dragging looks around, and scrolling changes flight speed. Orbit distance and elevation have limits around the selected object's envelope. Selecting from inside that envelope retains the starting position; the first orbit or zoom can move the camera outward to its clearance boundary. Orbiting is not a collision-checked pedestrian route around neighboring buildings.

Changing day/night lighting, exposure, rendering quality or ray-tracing mode retains focus. Moving the window, resizing it or entering full screen also retains focus. Titlebar movement and live resizing hold both the camera and scene clocks, including moving traffic and the planetarium show. They resume without a catch-up jump when the gesture ends. Opening help releases held movement keys and cancels an active pointer gesture.

Starting or seeking a walkthrough, using its shuttles, choosing a view or destination, starting idle cycling, or starting the Chicago demo clears focus. Use **Play / Space** to return to the selected view's guided route. The [Chicago demo instructions](DEMO.md) explain the complete 48-route sequence.

Robie House is a named focus target, including its separate roof and service-wing volumes. The Hyde Park map layer adds surrounding building targets along the southern corridor.

## What a click can select

Picking casts a ray through the clicked viewport position into static scene geometry. It uses the first represented surface hit, then associates that position with a named landmark or mapped building footprint. It does not select a hidden building merely because the pointer falls inside that building's large bounding volume. Courtyards and footprint holes are retained in the mapped selection regions.

This is a static geometric selection system with practical limits:

- Glass counts as a surface. Picking does not trace optical transmission or choose objects seen only in a reflection.
- Small decorative triangles can be absent from the normal navigation geometry used for picking. Tiny decorations, plants, façade parts and moving traffic are not independent selectable targets. Because traffic is excluded, it does not act as a picking occluder.
- Selection identifies an architectural object or mapped building component, rather than every rendered mesh. Unrecognized surfaces clear focus.
- The camera's orbit clearance is based on the selected object's envelope. It does not guarantee a clear view or collision avoidance against the rest of the city.

Cloud Gate needs a special case: its finely tessellated shell was entirely absent from the normal navigation triangle set. A compact, additional picking hierarchy includes those omitted triangles within the Bean's region and combines its nearest hit with the ordinary scene query. The full curved shell can therefore be selected and can occlude objects behind it. This supplement is used only for picking; the existing walking collision and floor-support queries remain unchanged.

The focus catalog and picking structures are retained across all six Chicago destinations along with the shared world. Switching between Chicago and Paris loads the appropriate independent world and catalog. This document describes behavior and implementation limits; release checks are recorded separately in [Validation](VALIDATION.md).
