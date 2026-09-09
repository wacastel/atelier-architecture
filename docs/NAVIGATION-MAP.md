# Chicago navigation map

The map uses the bundled OpenStreetMap derivatives for Chicago, Lakefront, Museum Campus, North Side and Hyde Park. It draws simplified two-dimensional water, parks, building footprints and roads with SwiftUI Canvas. Loading occurs once on a utility task; it does not construct the city scene or render another 3D viewport.

Small and Medium are picture-in-picture maps. Large uses the available application window, with its controls still visible. The map fills its canvas edge to edge and preserves the same metre scale in both directions. Chicago's long north–south corridor is cropped to the current view, so dragging, zoom controls and the Places menu provide access to other districts. Recenter returns the map to the current camera. A dashed boundary marks the modeled extent; clicks outside it do not navigate.

Click a map point or landmark to choose a safe overhead position. Dragging more than four screen points instead translates the map and the real camera continuously. Releasing a drag does not also trigger a click, including when the pointer returns to its starting position. The north-up map uses world X east and world Z south.

A bright dotted square marks your camera in Small, Medium and Large maps; the arrow inside it shows the direction you are looking. The square stays fully visible near an edge. If your camera is beyond the visible map, an edge marker gives its direction and distance. “Off-screen” means the camera remains in the mapped city but lies outside the current crop. “Outside map” identifies a camera beyond the modeled boundary, such as a distant western skyline viewpoint; its distance is measured from that boundary. The marker does not make those surrounding areas available for map-click navigation.

## Controller integration

`ChicagoNavigationMap` takes `camera`, `isVisible`, `size`, `maximumHeight`, `maximumWidth`, `onNavigate` and `onPan`. Supply the full available window dimensions when `size == .large`; the view does not impose a 540-point height limit on Large.

`onNavigate` receives an absolute world `(x, z)` point. `onPan` receives an incremental world translation and returns the translation actually applied after the controller's bounds or safety checks. The controller translates both camera position and target and publishes the resulting map camera immediately. The map applies the same returned translation to its center, keeping the camera marker stationary under an unconstrained drag. A drag must not repeatedly select locations or calculate new overhead landings. The host uses a selection revision as the view identity so selecting another view, or resetting the same view, recenters the map; incremental dragging does not change that revision.

The map keeps world bounds at X −4000…6000 m and Z −11500…11000 m. Extending the city requires updating these bounds, the overview and map-translation guards in `ManualCityNavigation`, the `EngineController.navigateCity` guard and the landmark catalog, as well as including the appropriate offline resource. The map is a simplified navigation aid: small buildings and minor paths are omitted at city scale, and it does not imply detailed modeled coverage everywhere inside its rectangular extent. © OpenStreetMap contributors, ODbL 1.0; the bundled data retains its original provenance.

## Validation

Run `scripts/validate-navigation-map.sh` for CPU checks of aspect-preserving fill, full-window sizing, inverse coordinates, recentering and zoom, incremental anchored dragging, controller-clamped translation, click-versus-drag behavior, camera heading, dotted-square bounds, off-map bearing/distance and all five offline datasets. The script neither launches the application nor executes GPU work. The [native review](validation/v2.1/native-review.json) separately verified all three map sizes, map dragging, a landmark click, full-screen behavior and resizing. Selecting or resetting a view recenters the map; dragging after free flight beyond coverage permits inward movement without snapping against the gesture.
