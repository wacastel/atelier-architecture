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
        for height: CGFloat in [270, 315, 410, 540, 900, 1600] {
            for width: CGFloat in [300, 620, 1440, 2560] {
                let cards = ChicagoMapSize.allCases.map { $0.cardSize(maximumHeight: height, maximumWidth: width) }
                check(cards[0].height < cards[1].height && cards[1].height < cards[2].height,
                      "Size choices collapse to one height in a constrained window")
                check(cards[0].width < cards[1].width && cards[1].width < cards[2].width,
                      "Small/Medium/Large widths are indistinguishable")
                check(cards.allSatisfy { $0.height <= height && $0.width <= width }, "Map exceeds the available card dimensions")
                check(cards[2].width <= 430 && cards[2].height <= 410, "Large exceeds its compact ideal size")
                check(abs(cards[0].width/260-cards[2].width/430) < 1e-8 && abs(cards[1].height/330-cards[2].height/410) < 1e-8,
                      "Constrained sizes no longer use one common fit factor")
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
                        for position in samples + [SIMD2(-20000, 0), SIMD2(20000, 0), SIMD2(0, -20000), SIMD2(0, 20000)] {
                            guard let marker = ChicagoMapCameraMarker.make(position: position, projection: projection) else {
                                check(false, "Camera marker is missing from a supported map size"); continue
                            }
                            let stroke = marker.square.insetBy(dx: -2.25, dy: -2.25)
                            check(stroke.minX >= 0 && stroke.minY >= 0 && stroke.maxX <= canvas.width && stroke.maxY <= canvas.height,
                                  "Dotted camera marker or its backing stroke clips at the map edge")
                            check(marker.square.width == 24 && marker.square.height == 24,
                                  "Camera square size changes with map size or zoom")
                            if let rect = marker.labelRect {
                                check(rect.minX >= 0 && rect.minY >= 0 && rect.maxX <= canvas.width && rect.maxY <= canvas.height,
                                      "Off-map position label leaves the canvas")
                                check(!rect.intersects(marker.square), "Off-map text hides the camera square")
                            }
                            if position.x < minimum.x || position.x > maximum.x || position.y < minimum.y || position.y > maximum.y {
                                check(marker.outsideCoverage && marker.label?.hasPrefix("Outside map:") == true,
                                      "Camera outside modeled coverage appears to occupy an ordinary city position")
                            }
                            if marker.offscreen {
                                let a = SIMD2<Double>(Double(marker.projectedPosition.x-canvas.width/2), Double(marker.projectedPosition.y-canvas.height/2))
                                let b = SIMD2<Double>(Double(marker.center.x-canvas.width/2), Double(marker.center.y-canvas.height/2))
                                let angle = simd_dot(simd_normalize(a), simd_normalize(b))
                                check(angle > 0.999999, "Edge marker distorts the bearing toward an off-screen camera")
                                check(marker.label != nil, "Off-screen camera is silently clamped onto the map")
                            }
                        }
                    }
                }
            }
        }
        for viewport in [CGSize(width: 900, height: 600), CGSize(width: 1100, height: 700),
                         CGSize(width: 1440, height: 900), CGSize(width: 2560, height: 1600)] {
            let cards = ChicagoMapSize.allCases.map { $0.cardSize(maximumHeight: min(410, viewport.height*0.45),
                                                                 maximumWidth: min(430, viewport.width*0.45)) }
            for card in cards {
                check(card.width*card.height < viewport.width*viewport.height*0.25, "Map takes a quarter or more of the viewport")
                check(card.width >= 170 && card.height-66 >= 95, "Smallest supported window cannot display controls and camera marker")
            }
            check(cards[0].width+40 < cards[1].width && cards[1].width+50 < cards[2].width,
                  "Compact size choices are not visibly distinct")
        }
        for size in ChicagoMapSize.allCases {
            check(size.cardSize(maximumHeight: 0, maximumWidth: 0) == .zero, "Zero budget manufactures a larger map")
            check(size.cardSize(maximumHeight: .nan, maximumWidth: .infinity).width.isFinite, "Invalid size budget produces nonfinite layout")
        }
        check(Set(ChicagoMapLandmark.all.map(\.id)).count == ChicagoMapLandmark.all.count, "Semantic landmark IDs are not unique")
        check(ChicagoMapLandmark.all.count == 34, "Map catalog must include the Cultural Center as its 34th destination")
        for landmark in ChicagoMapLandmark.all {
            check(landmark.point.x >= minimum.x && landmark.point.x <= maximum.x && landmark.point.y >= minimum.y && landmark.point.y <= maximum.y,
                  "Landmark target lies outside actual navigation coverage")
            check(landmark.targetHeight.isFinite && landmark.targetHeight >= 0 && landmark.framingRadius.isFinite && landmark.framingRadius > 0,
                  "Semantic framing target is invalid")
            check(landmark.target == SIMD3(landmark.point.x, landmark.targetHeight, landmark.point.y), "Semantic target swaps world axes")
        }
        let willis = ChicagoMapLandmark.all.first { $0.id == "willis" }!
        let bean = ChicagoMapLandmark.all.first { $0.id == "cloud-gate" }!
        check(willis.target == SIMD3(-4, 205, 10) && willis.framingRadius >= 325, "Willis selection targets pavement or omits the antenna envelope")
        check(bean.target == SIMD3(1042.46, 7.8, -424.15) && bean.framingRadius == 18, "Cloud Gate selection loses its authored center and close framing")
        let focusIDs = ["willis":"chicago:willis-tower", "robie":"chicago:robie-house", "adler":"chicago:adler-planetarium",
                        "cloud-gate":"chicago:cloud-gate", "hancock":"chicago:hancock-center", "water-tower":"chicago:historic-water-tower",
                        "oldtown":"chicago:saint-michael", "beach":"chicago:north-avenue-beach-house",
                        "nature-pavilion":"chicago:nature-boardwalk-pavilion", "lakeside-center":"chicago:mccormick-lakeside",
                        "culturalcenter":"chicago:cultural-center"]
        for (id,expectedID) in focusIDs {
            check(ChicagoMapLandmark.all.first { $0.id==id }?.focusID == expectedID,
                  "Semantic map identity \(id) does not resolve to its authored focus \(expectedID)")
        }
        for id in ["zoo","millennium","mccormick","point","harbor"] {
            check(ChicagoMapLandmark.all.first { $0.id==id }?.focusID == nil,
                  "A district map destination incorrectly claims one unrelated physical building")
        }
        let cultural=ChicagoMapLandmark.all.first { $0.id=="culturalcenter" }
        check(cultural?.target == SIMD3(906.15,16.8,-557.02) && cultural?.framingRadius == 66,
              "Cultural Center map target does not match its authored center and enclosing radius")
        var labelCounts: [String: Int] = [:]
        for mapSize in ChicagoMapSize.allCases {
            let card = mapSize.cardSize(maximumHeight: 410, maximumWidth: 430)
            let canvas = CGSize(width: card.width, height: card.height-66)
            let overview = ChicagoMapProjection(canvasSize: canvas).centered(on: .zero)
            labelCounts[mapSize.rawValue] = ChicagoMapLabel.layout(projection: overview, size: mapSize).count
            for center in [SIMD2<Float>.zero, SIMD2(1800, 1500), SIMD2(214.4, -4726.1), SIMD2(3309.7, 9917.1)] {
                for zoom: CGFloat in [1, 2, 4, 8, 16] {
                    let projection = ChicagoMapProjection(canvasSize: canvas, zoom: zoom).centered(on: center)
                    let reserved = CGRect(x: canvas.width/2-12, y: canvas.height/2-12, width: 24, height: 24)
                    let labels = ChicagoMapLabel.layout(projection: projection, size: mapSize, avoiding: [reserved])
                    for (index, label) in labels.enumerated() {
                        check(projection.canvasRect.contains(label.rect) && projection.canvasRect.contains(label.dotRect), "Label or associated dot is clipped")
                        check(label.landmark.detailLevel <= mapSize.detailLevel, "Compact map ignores its landmark detail budget")
                        check(!label.rect.intersects(reserved), "Landmark text hides the dotted camera square")
                        let textPoint = CGPoint(x: label.rect.midX, y: label.rect.midY)
                        let fromText = ChicagoMapLabel.hitTest(textPoint, labels: labels)
                        let fromDot = ChicagoMapLabel.hitTest(label.marker, labels: labels)
                        check(fromText?.id == label.id && fromDot?.id == label.id, "Text and dot disagree about hovered/clicked landmark")
                        check(fromText?.target == label.landmark.target && fromDot?.framingRadius == label.landmark.framingRadius,
                              "Label displacement changes the semantic navigation target")
                        for other in labels.dropFirst(index+1) {
                            check(!label.rect.insetBy(dx: -2, dy: -2).intersects(other.rect), "Map labels overlap")
                            check(!label.rect.intersects(other.dotRect.insetBy(dx: 2, dy: 2)), "One label covers another landmark dot")
                        }
                    }
                    check(ChicagoMapLabel.hitTest(CGPoint(x: -1, y: -1), labels: labels) == nil, "Off-map hover selects a landmark")
                    check(ChicagoMapLabel.hitTest(CGPoint(x: CGFloat.nan, y: 0), labels: labels) == nil, "Nonfinite hover selects a landmark")
                }
            }
        }
        check(labelCounts["small"]! < labelCounts["medium"]! && labelCounts["medium"]! < labelCounts["large"]!,
              "Larger central Chicago maps do not expose progressively more landmarks: \(labelCounts)")
        let full = ChicagoMapProjection(canvasSize: CGSize(width: 1800, height: 1100))
        check(full.world(at: full.point(for: SIMD2(5800, 0))) != nil, "Lake fly-navigation is rejected")
        let movedBeyond = ChicagoMapProjection(canvasSize: CGSize(width: 1000, height: 500), center: SIMD2(10000, 0))
        check(movedBeyond.world(at: CGPoint(x: 500, y: 250)) == nil, "Unmodeled city coordinate is accepted")
        check(full.world(at: CGPoint(x: CGFloat.nan, y: 0)) == nil, "Nonfinite map input is accepted")
        check(ChicagoMapProjection(canvasSize: .zero).world(at: .zero) == nil, "Zero-size map accepts clicks")
        check(full.panDelta(screenDelta: CGSize(width: CGFloat.nan, height: 0)) == nil, "Nonfinite pan delta is accepted")
        let westMarker = ChicagoMapCameraMarker.make(position: SIMD2(-20000, 0), projection: full)!
        check(westMarker.direction == "W" && abs(westMarker.distanceMetres-16000) < 0.01,
              "Western-suburb distance is not measured from the existing coverage boundary")
        check(westMarker.label == "Outside map: W 16.0 km", "Western-suburb indicator is ambiguous")
        let centeredOutside = ChicagoMapProjection(canvasSize: CGSize(width: 1000, height: 500), center: SIMD2(-20000, 0), zoom: 2)
        let outsideVisible = ChicagoMapCameraMarker.make(position: SIMD2(-20000, 0), projection: centeredOutside)!
        check(outsideVisible.outsideCoverage && !outsideVisible.offscreen && outsideVisible.label != nil,
              "Panning the map over an outside camera hides its coverage warning")
        let northCrop = ChicagoMapCameraMarker.make(position: SIMD2(0, -10000), projection: full)!
        check(!northCrop.outsideCoverage && northCrop.offscreen && northCrop.direction == "N" && northCrop.label?.hasPrefix("Off-screen:") == true,
              "A cropped in-city position is confused with missing city coverage")
        let ordinary = ChicagoMapCameraMarker.make(position: full.center, projection: full)!
        check(ordinary.label == nil && ordinary.center == full.point(for: full.center), "Ordinary in-map camera position is displaced or mislabeled")
        check(ChicagoMapCameraMarker.make(position: SIMD2(.nan, 0), projection: full) == nil, "Nonfinite camera position produces a marker")
        check(ChicagoMapCameraMarker.make(position: .zero, projection: ChicagoMapProjection(canvasSize: .zero)) == nil,
              "Zero-size canvas produces a marker")
        check(ChicagoMapCameraMarker.make(position: SIMD2(Float.greatestFiniteMagnitude, 0), projection: full)?.distanceMetres.isFinite == true,
              "Finite distant camera overflows off-map distance calculations")
        check(full.world(at: full.point(for: SIMD2(-20000, 0))) == nil,
              "Camera indicator expanded actual navigation coverage into unmodeled suburbs")
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
                                     onNavigate: { _ in }, onLandmarkNavigate: { _ in }, onPan: { $0 })
        let result: [String: Any] = ["passed": true, "checks": checks,
            "scope": "CPU compact viewport-area budgets, fill/aspect/inverse/zoom/recenter/resize, semantic landmark centers, collision-aware label placement, shared dot/text hover-click hit tests, anchored pan, click-vs-drag, dotted camera marker/edge bearing/coverage distance, heading and complete offline loading; no native UI or GPU execution",
            "centralOverviewLabels": labelCounts, "landmarks": ChicagoMapLandmark.all.count,
            "resources": geometry.loadedResources, "vertices": geometry.vertexCount,
            "footprintRings": geometry.footprints.count, "streets": geometry.streets.count,
            "arterials": geometry.arterials.count, "waterPolygons": geometry.water.count,
            "loadSeconds": Date().timeIntervalSince(start)]
        print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
    }
}
