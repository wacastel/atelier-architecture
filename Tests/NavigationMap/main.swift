import Foundation
import SwiftUI
import simd

@main
enum NavigationMapTests {
    static func loadDataset() throws -> (ChicagoMapGeometry, Bool) {
        let map = try ChicagoMapGeometry.load(resourceRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/ArchitectureEngine/Resources"))
        return (map, Thread.isMainThread)
    }
    @MainActor static func main() async throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            guard condition else {
                FileHandle.standardError.write(Data("FAIL after \(checks) checks: \(message)\n".utf8))
                exit(1)
            }
            checks += 1
        }
        let minimum = ChicagoMapProjection.worldMinimum
        let maximum = ChicagoMapProjection.worldMaximum
        let samples: [SIMD2<Float>] = [minimum, maximum, SIMD2(minimum.x, maximum.y),
            SIMD2(maximum.x, minimum.y), .zero, SIMD2(3309.7, 9917.1),
            SIMD2(-1626, -7717.6), SIMD2(4925, 9237), SIMD2(2413.7, 1393.2)]
        for height: CGFloat in [180, 210, 390, 540, 900, 1600] {
            for width: CGFloat in [300, 620, 1440, 2560] {
                let cards = ChicagoMapSize.allCases.map { $0.cardSize(maximumHeight: height, maximumWidth: width) }
                check(cards[0].height < cards[1].height && cards[1].height < cards[2].height,
                      "Size choices collapse to one height in a constrained window")
                check(cards[0].width < cards[1].width && cards[1].width < cards[2].width,
                      "Small/Medium/Large widths are indistinguishable")
                check(cards.allSatisfy { $0.height <= height && $0.width <= width }, "Map exceeds the available card dimensions")
                check(cards[2] == CGSize(width: width, height: height), "Large does not fill the supplied application viewport")
                for card in cards {
                    let canvas = CGSize(width: card.width, height: card.height - 66)
                    for zoom: CGFloat in [1, 2.25, 16] {
                        let projection = ChicagoMapProjection(canvasSize: canvas, zoom: zoom)
                        check(projection.scale > 0, "Card has no drawable map area")
                        check(projection.coverageRect.width + 0.001 >= canvas.width && projection.coverageRect.height + 0.001 >= canvas.height,
                              "Aspect-fill leaves letterbox gutters")
                        let east = projection.point(for: SIMD2(1000, 0))
                        let south = projection.point(for: SIMD2(0, 1000))
                        let origin = projection.point(for: .zero)
                        check(east.x > origin.x && abs(east.y - origin.y) < 1e-8, "East is not screen-right")
                        check(south.y > origin.y && abs(south.x - origin.x) < 1e-8, "North/south axis is inverted")
                        check(abs(east.x - origin.x - (south.y - origin.y)) < 1e-8,
                              "Map distorts equal metre distances along the two axes")
                        for sample in samples {
                            let local = projection.centered(on: sample)
                            let screen = local.point(for: sample)
                            let restored = local.world(at: screen)
                            check(restored != nil && simd_distance(restored!, sample) < 0.02,
                                  "Recenter/zoom cannot expose and recover anchor \(sample), canvas \(canvas), zoom \(zoom), screen \(screen), result \(String(describing: restored))")
                        }
                        for outside in [CGPoint(x: -0.01, y: canvas.height/2), CGPoint(x: canvas.width+0.01, y: canvas.height/2),
                                        CGPoint(x: canvas.width/2, y: -0.01), CGPoint(x: canvas.width/2, y: canvas.height+0.01)] {
                            check(projection.world(at: outside) == nil, "Off-canvas pointer navigates")
                        }
                        // A real camera and map translated equally must keep the camera marker stationary,
                        // while the initially grabbed ground anchor follows the pointer exactly.
                        let movement = CGSize(width: 31, height: -14)
                        let delta = projection.panDelta(screenDelta: movement)!
                        let moved = ChicagoMapProjection(canvasSize: canvas, center: projection.center+delta, zoom: zoom)
                        let before = projection.point(for: .zero), after = moved.point(for: .zero)
                        check(abs(after.x-before.x-movement.width) < 0.002 && abs(after.y-before.y-movement.height) < 0.002,
                              "Grabbed map anchor does not follow the drag")
                        let cameraAfter = moved.point(for: delta)
                        check(hypot(cameraAfter.x-before.x, cameraAfter.y-before.y) < 0.002,
                              "Translating camera and map makes the camera marker drift")
                        // A clamped controller response is authoritative: move the map by the applied delta.
                        let applied = delta * 0.25
                        let clamped = ChicagoMapProjection(canvasSize: canvas, center: projection.center+applied, zoom: zoom)
                        let adjusted = clamped.point(for: applied)
                        check(hypot(adjusted.x-before.x, adjusted.y-before.y) < 0.002,
                              "A partially accepted drag detaches the marker from the map")
                    }
                }
            }
        }
        let full = ChicagoMapProjection(canvasSize: CGSize(width: 1800, height: 1100))
        check(full.world(at: full.point(for: SIMD2(5800, 0))) != nil, "Lake fly-navigation is rejected")
        let movedBeyond = ChicagoMapProjection(canvasSize: CGSize(width: 1000, height: 500), center: SIMD2(10000, 0))
        check(movedBeyond.world(at: CGPoint(x: 500, y: 250)) == nil, "Unmodeled city coordinate is accepted")
        check(full.world(at: CGPoint(x: CGFloat.nan, y: 0)) == nil, "Nonfinite map input is accepted")
        check(ChicagoMapProjection(canvasSize: .zero).world(at: .zero) == nil, "Zero-size map accepts clicks")
        check(full.panDelta(screenDelta: CGSize(width: CGFloat.nan, height: 0)) == nil, "Nonfinite pan delta is accepted")
        var drag = ChicagoMapDrag()
        check(drag.update(translation: CGSize(width: 2, height: 1)) == nil, "A click wiggle moves the real camera")
        check(drag.end(translation: CGSize(width: 2, height: 1)), "A genuine click is lost")
        check(drag.update(translation: CGSize(width: 8, height: 0)) == CGSize(width: 8, height: 0), "Initial drag displacement is lost")
        check(drag.update(translation: CGSize(width: 13, height: -2)) == CGSize(width: 5, height: -2), "Drag callback is cumulative rather than incremental")
        check(drag.update(translation: .zero) == CGSize(width: -13, height: 2), "Returning drag does not restore its starting position")
        check(!drag.end(translation: .zero), "Returning to drag origin incorrectly generates a click on release")
        check(drag.end(translation: .zero), "Gesture state did not reset after a drag")
        for direction: SIMD2<Float> in [SIMD2(0, -1), SIMD2(1, 0), SIMD2(0, 1), SIMD2(-1, 0)] {
            let camera = ChicagoMapCamera(position: SIMD2(50, -100), target: SIMD2(50, -100) + direction * 100)
            check(simd_distance(camera.heading, direction) < 1e-6, "Camera marker heading disagrees with geographic direction")
        }
        check(ChicagoMapCamera(position: .zero, target: .zero).heading == SIMD2(0, -1), "Degenerate heading is unstable")
        check(ChicagoMapCamera(position: .zero, target: SIMD2(.nan, 0)).heading == SIMD2(0, -1), "Nonfinite heading is unstable")
        let corner: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(50, 0), SIMD2(100, 0), SIMD2(100, 100)]
        let reduced = ChicagoMapGeometry.simplify(corner, tolerance: 5, closed: false)
        check(reduced.first == corner.first && reduced.last == corner.last && reduced.contains(SIMD2(100, 0)),
              "Map simplification loses an endpoint or a meaningful road corner")
        let square: [SIMD2<Float>] = [SIMD2(0, 0), SIMD2(100, 0), SIMD2(100, 100), SIMD2(0, 100)]
        check(abs(ChicagoMapGeometry.area(ChicagoMapGeometry.simplify(square, tolerance: 7, closed: true)) - 10000) < 0.01,
              "Footprint simplification changes a rectangular building")
        let start = Date()
        let loaded = try await Task.detached { try loadDataset() }.value
        let geometry = loaded.0
        check(!loaded.1, "Offline map construction ran on the main thread")
        check(geometry.loadedResources == 5, "Map omits a Chicago region")
        check(geometry.water.count >= 5 && geometry.water.contains(where: { $0.count > 1 }), "Water groups lose their island/hole rings")
        check(geometry.footprints.count > 500 && geometry.streets.count > 500 && geometry.arterials.count > 50,
              "Offline map is missing its buildings or street network")
        check(geometry.vertexCount < 200000, "Overview map exceeds its lightweight vector budget")
        let _ = ChicagoNavigationMap(camera: .init(position: .zero, target: SIMD2(0, -1)),
                                     isVisible: .constant(true), size: .constant(.small), maximumHeight: 180, maximumWidth: 620,
                                     onNavigate: { _ in }, onPan: { $0 })
        let result: [String: Any] = ["passed": true, "checks": checks,
            "scope": "CPU fill/aspect/inverse/zoom/recenter/resize, incremental anchored pan, click-vs-drag, heading and complete offline data loading; no native UI or GPU execution",
            "resources": geometry.loadedResources, "vertices": geometry.vertexCount,
            "footprintRings": geometry.footprints.count, "streets": geometry.streets.count,
            "arterials": geometry.arterials.count, "waterPolygons": geometry.water.count,
            "loadSeconds": Date().timeIntervalSince(start)]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
