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
            precondition(condition, message)
            checks += 1
        }
        let minimum = ChicagoMapProjection.worldMinimum
        let maximum = ChicagoMapProjection.worldMaximum
        let samples: [SIMD2<Float>] = [minimum, maximum, SIMD2(minimum.x, maximum.y),
            SIMD2(maximum.x, minimum.y), .zero, SIMD2(3309.7, 9917.1),
            SIMD2(-1626, -7717.6), SIMD2(4925, 9237), SIMD2(2413.7, 1393.2)]
        for height: CGFloat in [180, 210, 390, 540, 900] {
            let cards = ChicagoMapSize.allCases.map { $0.cardSize(maximumHeight: height) }
            check(cards[0].height < cards[1].height && cards[1].height < cards[2].height,
                  "Size choices collapse to one height in a constrained window")
            check(cards.allSatisfy { $0.height <= min(540, height) }, "Map exceeds the available card height")
            for card in cards {
                let canvas = CGSize(width: card.width - 16, height: card.height - 64)
                let projection = ChicagoMapProjection(canvasSize: canvas)
                check(projection.scale > 0, "Card has no drawable map area")
                let east = projection.point(for: SIMD2(1000, 0))
                let south = projection.point(for: SIMD2(0, 1000))
                let origin = projection.point(for: .zero)
                check(east.x > origin.x && abs(east.y - origin.y) < 1e-8, "East is not screen-right")
                check(south.y > origin.y && abs(south.x - origin.x) < 1e-8, "North/south axis is inverted")
                check(abs(east.x - origin.x - (south.y - origin.y)) < 1e-8,
                      "Map distorts equal metre distances along the two axes")
                for sample in samples {
                    let screen = projection.point(for: sample)
                    let restored = projection.world(at: screen)
                    check(restored != nil && simd_distance(restored!, sample) < 0.01, "Map click does not recover its world anchor")
                }
                let rect = projection.fittedRect
                for outside in [CGPoint(x: rect.minX - 0.01, y: rect.midY),
                                CGPoint(x: rect.maxX + 0.01, y: rect.midY),
                                CGPoint(x: rect.midX, y: rect.minY - 0.01),
                                CGPoint(x: rect.midX, y: rect.maxY + 0.01)] {
                    check(projection.world(at: outside) == nil, "Letterbox click incorrectly navigates outside the map")
                }
                // Lake and city positions are both deliberate fly-navigation targets.
                let lake = SIMD2<Float>(5800, 0)
                check(projection.world(at: projection.point(for: lake)) != nil, "Map unexpectedly rejects water navigation")
            }
        }
        for canvas in [CGSize(width: 900, height: 170), CGSize(width: 170, height: 900), CGSize(width: 400, height: 400)] {
            let projection = ChicagoMapProjection(canvasSize: canvas)
            let ratio = projection.fittedRect.width / projection.fittedRect.height
            check(abs(ratio - 10000 / 22500) < 1e-9, "World aspect ratio is lost on resize")
            check(projection.world(at: CGPoint(x: CGFloat.nan, y: 0)) == nil, "Nonfinite map input is accepted")
        }
        check(ChicagoMapProjection(canvasSize: .zero).world(at: .zero) == nil, "Zero-size map accepts clicks")
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
                                     isVisible: .constant(true), size: .constant(.small), maximumHeight: 180) { _ in }
        let result: [String: Any] = ["passed": true, "checks": checks,
            "scope": "CPU coordinate/aspect/resize/heading and complete offline vector-data loading; no native UI or GPU execution",
            "resources": geometry.loadedResources, "vertices": geometry.vertexCount,
            "footprintRings": geometry.footprints.count, "streets": geometry.streets.count,
            "arterials": geometry.arterials.count, "waterPolygons": geometry.water.count,
            "loadSeconds": Date().timeIntervalSince(start)]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
