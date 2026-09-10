import Foundation
import SwiftUI
import AppKit
import simd

/// The map uses the same east/south metre coordinates as the resident Chicago world.
struct ChicagoMapCamera: Equatable, Sendable {
    var position: SIMD2<Float>
    var target: SIMD2<Float>

    var heading: SIMD2<Float> {
        let direction = target - position
        let length = simd_length(direction)
        return length.isFinite && length > 0.0001 ? direction / length : SIMD2(0, -1)
    }
}

enum ChicagoMapSize: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large
    var id: String { rawValue }
    var abbreviation: String { String(rawValue.prefix(1)).uppercased() }

    /// The host supplies a budget below one quarter of its viewport area. All
    /// sizes share one fit factor, so constraints never collapse their ordering.
    func cardSize(maximumHeight: CGFloat, maximumWidth: CGFloat = 620) -> CGSize {
        let height = maximumHeight.isFinite ? max(0, maximumHeight) : 410
        let width = maximumWidth.isFinite ? max(0, maximumWidth) : 430
        let fit = min(1, min(width/430, height/410))
        let ideal: CGSize
        switch self {
        case .small: ideal = CGSize(width: 260, height: 250)
        case .medium: ideal = CGSize(width: 340, height: 330)
        case .large: ideal = CGSize(width: 430, height: 410)
        }
        return CGSize(width: ideal.width*fit, height: ideal.height*fit)
    }
    var detailLevel: Int { self == .small ? 0 : self == .medium ? 1 : 2 }
}

struct ChicagoMapProjection: Equatable, Sendable {
    static let worldMinimum = SIMD2<Float>(-4000, -11500)
    static let worldMaximum = SIMD2<Float>(6000, 11000)
    static let worldCenter = (worldMinimum + worldMaximum) / 2
    let canvasSize: CGSize
    let center: SIMD2<Float>
    let zoom: CGFloat

    init(canvasSize: CGSize, center: SIMD2<Float> = Self.worldCenter, zoom: CGFloat = 1) {
        self.canvasSize = canvasSize
        self.center = center.x.isFinite && center.y.isFinite ? center : Self.worldCenter
        self.zoom = zoom.isFinite ? max(1, min(16, zoom)) : 1
    }

    var scale: CGFloat {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite,
              canvasSize.width > 0, canvasSize.height > 0 else { return 0 }
        // Fill, rather than fit: one metre has the same scale on both axes.
        // The north/south corridor is explored by dragging or choosing a landmark.
        return max(canvasSize.width / 10000, canvasSize.height / 22500) * zoom
    }
    var canvasRect: CGRect { CGRect(origin: .zero, size: canvasSize) }
    var coverageRect: CGRect {
        let a = point(for: Self.worldMinimum), b = point(for: Self.worldMaximum)
        return CGRect(x: a.x, y: a.y, width: b.x-a.x, height: b.y-a.y)
    }
    /// Initial/recenter placement avoids empty margins near Robie or Wrigley.
    func centered(on point: SIMD2<Float>) -> ChicagoMapProjection {
        guard scale > 0, point.x.isFinite, point.y.isFinite else { return self }
        let half = SIMD2(Float(canvasSize.width / (2*scale)), Float(canvasSize.height / (2*scale)))
        let low = Self.worldMinimum + half, high = Self.worldMaximum - half
        let adjusted = SIMD2(max(low.x, min(high.x, point.x)), max(low.y, min(high.y, point.y)))
        return ChicagoMapProjection(canvasSize: canvasSize, center: adjusted, zoom: zoom)
    }
    func point(for world: SIMD2<Float>) -> CGPoint {
        CGPoint(x: canvasSize.width/2 + CGFloat(world.x-center.x)*scale,
                y: canvasSize.height/2 + CGFloat(world.y-center.y)*scale)
    }
    /// Z increases south, exactly like a top-down screen's Y. Do not invert this axis.
    func world(at point: CGPoint) -> SIMD2<Float>? {
        // World positions are Float metres; tolerate their ~1 mm quantization
        // when an exact city-boundary anchor projects just beyond a canvas edge.
        let edge = max(0.001, scale*0.0015)
        guard scale > 0, point.x.isFinite, point.y.isFinite,
              point.x >= -edge, point.x <= canvasSize.width+edge,
              point.y >= -edge, point.y <= canvasSize.height+edge else { return nil }
        let x = max(0, min(canvasSize.width, point.x)), y = max(0, min(canvasSize.height, point.y))
        let result = center + SIMD2(Float((x-canvasSize.width/2)/scale), Float((y-canvasSize.height/2)/scale))
        guard result.x >= Self.worldMinimum.x-0.002, result.x <= Self.worldMaximum.x+0.002,
              result.y >= Self.worldMinimum.y-0.002, result.y <= Self.worldMaximum.y+0.002 else { return nil }
        return SIMD2(max(Self.worldMinimum.x, min(Self.worldMaximum.x, result.x)),
                     max(Self.worldMinimum.y, min(Self.worldMaximum.y, result.y)))
    }
    /// Incremental grab-pan translation for both the map center and real 3D camera.
    func panDelta(screenDelta: CGSize) -> SIMD2<Float>? {
        guard scale > 0, screenDelta.width.isFinite, screenDelta.height.isFinite else { return nil }
        return SIMD2(-Float(screenDelta.width/scale), -Float(screenDelta.height/scale))
    }
}

/// A camera position is never silently represented by an unrelated edge point.
/// Distances outside coverage are measured from the nearest modeled boundary;
/// cropped in-city distances are measured from the visible map rectangle.
struct ChicagoMapCameraMarker: Sendable {
    static let side: CGFloat = 24
    let square: CGRect
    let projectedPosition: CGPoint
    let outsideCoverage: Bool
    let offscreen: Bool
    let distanceMetres: Double
    let direction: String?
    let label: String?
    let labelRect: CGRect?
    var center: CGPoint { CGPoint(x: square.midX, y: square.midY) }

    static func make(position: SIMD2<Float>, projection: ChicagoMapProjection) -> ChicagoMapCameraMarker? {
        let size = projection.canvasSize
        guard position.x.isFinite, position.y.isFinite, projection.scale > 0,
              size.width >= 60, size.height >= 60 else { return nil }
        let actual = projection.point(for: position)
        guard actual.x.isFinite, actual.y.isFinite else { return nil }
        let minimum = ChicagoMapProjection.worldMinimum, maximum = ChicagoMapProjection.worldMaximum
        let outside = position.x < minimum.x || position.x > maximum.x || position.y < minimum.y || position.y > maximum.y
        let edge = max(0.001, projection.scale*0.0015)
        let offscreen = actual.x < -edge || actual.x > size.width+edge || actual.y < -edge || actual.y > size.height+edge
        let inset = side/2 + 3
        var center = CGPoint(x: max(inset, min(size.width-inset, actual.x)),
                             y: max(inset, min(size.height-inset, actual.y)))
        if offscreen {
            // Intersect the bearing from canvas center with the safe edge box.
            // Independent x/y clamping would distort diagonal bearings.
            let dx = actual.x-size.width/2, dy = actual.y-size.height/2
            let tx = dx == 0 ? CGFloat.infinity : (size.width/2-inset)/abs(dx)
            let ty = dy == 0 ? CGFloat.infinity : (size.height/2-inset)/abs(dy)
            let t = min(tx, ty)
            center = CGPoint(x: size.width/2+dx*t, y: size.height/2+dy*t)
        }
        let square = CGRect(x: center.x-side/2, y: center.y-side/2, width: side, height: side)
        var distance = 0.0
        var direction: String?, label: String?, labelRect: CGRect?
        if outside || offscreen {
            let x = Double(position.x), z = Double(position.y)
            let nearestX: Double, nearestZ: Double
            if outside {
                nearestX = max(Double(minimum.x), min(Double(maximum.x), x))
                nearestZ = max(Double(minimum.y), min(Double(maximum.y), z))
            } else {
                let halfX = Double(size.width/(2*projection.scale)), halfZ = Double(size.height/(2*projection.scale))
                nearestX = max(Double(projection.center.x)-halfX, min(Double(projection.center.x)+halfX, x))
                nearestZ = max(Double(projection.center.y)-halfZ, min(Double(projection.center.y)+halfZ, z))
            }
            let dx = x-nearestX, dz = z-nearestZ
            distance = hypot(dx, dz)
            let index = (Int((atan2(dz, dx)/(.pi/4)).rounded())+8)%8
            let compass = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"][index]
            direction = compass
            let range = distance < 1 ? "<1 m" : distance < 1000 ? String(format: "%.0f m", distance)
                : distance < 1_000_000 ? String(format: "%.1f km", distance/1000) : "1,000+ km"
            let text = "\(outside ? "Outside map" : "Off-screen"): \(compass) \(range)"
            label = text
            let width = min(size.width-8, CGFloat(text.count)*5.5+12), height: CGFloat = 17
            let below = square.maxY+4
            let y = below+height <= size.height-4 ? below : max(4, square.minY-height-4)
            labelRect = CGRect(x: max(4, min(size.width-width-4, center.x-width/2)), y: y, width: width, height: height)
        }
        return ChicagoMapCameraMarker(square: square, projectedPosition: actual, outsideCoverage: outside,
                                      offscreen: offscreen, distanceMetres: distance, direction: direction,
                                      label: label, labelRect: labelRect)
    }
}

/// Shared by the SwiftUI gesture and CPU tests: once dragged, release cannot click.
struct ChicagoMapDrag: Sendable {
    static let threshold: CGFloat = 4
    private(set) var isDragging = false
    private var previous = CGSize.zero
    mutating func update(translation: CGSize) -> CGSize? {
        guard translation.width.isFinite, translation.height.isFinite else { return nil }
        if !isDragging && hypot(translation.width, translation.height) <= Self.threshold { return nil }
        isDragging = true
        let delta = CGSize(width: translation.width-previous.width, height: translation.height-previous.height)
        previous = translation
        return delta
    }
    mutating func end(translation: CGSize) -> Bool {
        let clicked = !isDragging && translation.width.isFinite && translation.height.isFinite
            && hypot(translation.width, translation.height) <= Self.threshold
        self = ChicagoMapDrag()
        return clicked
    }
}

struct ChicagoMapLandmark: Identifiable, Sendable {
    let id: String
    let name: String
    let point: SIMD2<Float>
    let eastLabel: Bool
    let targetHeight: Float
    let framingRadius: Float
    let detailLevel: Int
    var target: SIMD3<Float> { SIMD3(point.x, targetHeight, point.y) }
    /// Stable architectural identities, independent of display labels. Districts
    /// without one building use an explicit region focus in the controller.
    var focusID: String? {
        let names = ["robie":"robie-house","wrigley":"wrigley-field","willis":"willis-tower",
            "adler":"adler-planetarium","hancock":"hancock-center","oldtown":"saint-michael",
            "art":"art-institute","field":"field-museum","beach":"north-avenue-beach-house",
            "cloud-gate":"cloud-gate","shedd":"shedd-aquarium","soldier":"soldier-field",
            "water-tower":"historic-water-tower","buckingham":"buckingham-fountain",
            "conservatory":"lincoln-park-conservatory","tribune":"tribune-tower",
            "wrigley-building":"wrigley-building","pritzker":"pritzker-pavilion",
            "crown":"crown-fountain","water-tower-place":"water-tower-place",
            "pumping-station":"pumping-station","cafe-brauer":"cafe-brauer",
            "nature-pavilion":"nature-boardwalk-pavilion","nichols":"nichols-bridgeway",
            "lakeside-center":"mccormick-lakeside","mccormick-west":"mccormick-west",
            "mccormick-north":"mccormick-north","mccormick-south":"mccormick-south",
            "culturalcenter":"cultural-center","navypier":"navy-pier",
            "centennial-wheel":"centennial-wheel","grand-ballroom":"navy-pier-ballroom",
            "shakespeare":"chicago-shakespeare","sable":"sable-hotel"]
        return names[id].map { "chicago:"+$0 }
    }

    init(id: String, name: String, point: SIMD2<Float>, eastLabel: Bool,
         targetHeight: Float, framingRadius: Float, detailLevel: Int = 0) {
        self.id = id; self.name = name; self.point = point; self.eastLabel = eastLabel
        self.targetHeight = targetHeight; self.framingRadius = framingRadius; self.detailLevel = detailLevel
    }

    // Architectural anchors already used by the city. These labels do not load a scene.
    static let all: [ChicagoMapLandmark] = [
        .init(id: "robie", name: "Robie House", point: SIMD2(3309.7, 9917.1), eastLabel: false, targetHeight: 4.8, framingRadius: 32),
        .init(id: "wrigley", name: "Wrigley Field", point: SIMD2(-1626, -7717.6), eastLabel: false, targetHeight: 15, framingRadius: 155),
        .init(id: "willis", name: "Willis Tower", point: SIMD2(-4, 10), eastLabel: false, targetHeight: 205, framingRadius: 325),
        .init(id: "zoo", name: "Lincoln Park Zoo", point: SIMD2(214.4, -4726.1), eastLabel: false, targetHeight: 7.5, framingRadius: 240),
        .init(id: "millennium", name: "Millennium Park", point: SIMD2(1130, -540), eastLabel: true, targetHeight: 15, framingRadius: 280),
        .init(id: "culturalcenter", name: "Cultural Center", point: SIMD2(906.15, -557.02), eastLabel: false, targetHeight: 16.8, framingRadius: 66),
        .init(id: "navypier", name: "Navy Pier", point: SIMD2(2620, -1433), eastLabel: true, targetHeight: 18, framingRadius: 535),
        .init(id: "adler", name: "Adler Planetarium", point: SIMD2(2421.7, 1393.2), eastLabel: true, targetHeight: 11, framingRadius: 65),
        .init(id: "mccormick", name: "McCormick Place", point: SIMD2(1800, 3000), eastLabel: false, targetHeight: 25, framingRadius: 650),
        .init(id: "point", name: "Promontory Point", point: SIMD2(4925, 9237), eastLabel: true, targetHeight: 3, framingRadius: 190),
        .init(id: "harbor", name: "31st St Harbor", point: SIMD2(2662, 4773), eastLabel: true, targetHeight: 2, framingRadius: 380),
        .init(id: "hancock", name: "John Hancock", point: SIMD2(1062.85, -2219.95), eastLabel: true, targetHeight: 190, framingRadius: 275),
        .init(id: "oldtown", name: "Old Town", point: SIMD2(-404, -3740), eastLabel: false, targetHeight: 37, framingRadius: 150),
        .init(id: "art", name: "Art Institute", point: SIMD2(1090, -77), eastLabel: true, targetHeight: 12, framingRadius: 190),
        .init(id: "field", name: "Field Museum", point: SIMD2(1565, 1409.6), eastLabel: false, targetHeight: 15, framingRadius: 155),
        .init(id: "beach", name: "North Ave Beach", point: SIMD2(972, -3853), eastLabel: true, targetHeight: 7, framingRadius: 250),
        .init(id: "cloud-gate", name: "Cloud Gate", point: SIMD2(1042.46, -424.15), eastLabel: false, targetHeight: 7.8, framingRadius: 18, detailLevel: 1),
        .init(id: "shedd", name: "Shedd Aquarium", point: SIMD2(1842, 1254.6), eastLabel: true, targetHeight: 11, framingRadius: 115, detailLevel: 1),
        .init(id: "soldier", name: "Soldier Field", point: SIMD2(1590, 1838), eastLabel: false, targetHeight: 23, framingRadius: 225, detailLevel: 1),
        .init(id: "water-tower", name: "Historic Water Tower", point: SIMD2(951.6, -2036.52), eastLabel: false, targetHeight: 27, framingRadius: 36, detailLevel: 1),
        .init(id: "buckingham", name: "Buckingham Fountain", point: SIMD2(1404.55, 342.2), eastLabel: true, targetHeight: 6, framingRadius: 55, detailLevel: 1),
        .init(id: "conservatory", name: "Lincoln Park Conservatory", point: SIMD2(72.5, -5067.5), eastLabel: true, targetHeight: 10, framingRadius: 90, detailLevel: 1),
        .init(id: "centennial-wheel", name: "Centennial Wheel", point: SIMD2(2357.4, -1427.7), eastLabel: false, targetHeight: 37, framingRadius: 58, detailLevel: 1),
        .init(id: "grand-ballroom", name: "Grand Ballroom", point: SIMD2(3027, -1444), eastLabel: true, targetHeight: 18, framingRadius: 65, detailLevel: 1),
        .init(id: "tribune", name: "Tribune Tower", point: SIMD2(1013, -1281), eastLabel: true, targetHeight: 68, framingRadius: 90, detailLevel: 1),
        .init(id: "wrigley-building", name: "Wrigley Building", point: SIMD2(922, -1200), eastLabel: false, targetHeight: 60, framingRadius: 85, detailLevel: 1),
        .init(id: "pritzker", name: "Pritzker Pavilion", point: SIMD2(1162.5, -517), eastLabel: true, targetHeight: 19, framingRadius: 75, detailLevel: 1),
        .init(id: "crown", name: "Crown Fountain", point: SIMD2(1009, -290.6), eastLabel: false, targetHeight: 7.8, framingRadius: 35, detailLevel: 2),
        .init(id: "shakespeare", name: "Shakespeare Theater", point: SIMD2(2500.8, -1385.1), eastLabel: true, targetHeight: 18, framingRadius: 70, detailLevel: 2),
        .init(id: "sable", name: "Sable Hotel", point: SIMD2(2727.3, -1392.9), eastLabel: true, targetHeight: 19, framingRadius: 170, detailLevel: 2),
        .init(id: "polk-park", name: "Polk Bros Park", point: SIMD2(2099.68, -1423.38), eastLabel: false, targetHeight: 3, framingRadius: 110, detailLevel: 2),
        .init(id: "water-tower-place", name: "Water Tower Place", point: SIMD2(1118, -2120), eastLabel: true, targetHeight: 110, framingRadius: 175, detailLevel: 2),
        .init(id: "pumping-station", name: "Pumping Station", point: SIMD2(1000, -2036.5), eastLabel: true, targetHeight: 13.5, framingRadius: 40, detailLevel: 2),
        .init(id: "cafe-brauer", name: "Café Brauer", point: SIMD2(168, -4477), eastLabel: false, targetHeight: 12.5, framingRadius: 48, detailLevel: 2),
        .init(id: "nature-pavilion", name: "Nature Boardwalk Pavilion", point: SIMD2(294.4, -4337), eastLabel: true, targetHeight: 3, framingRadius: 18, detailLevel: 2),
        .init(id: "nichols", name: "Nichols Bridgeway", point: SIMD2(1109, -270.5), eastLabel: true, targetHeight: 10, framingRadius: 75, detailLevel: 2),
        .init(id: "lakeside-center", name: "Lakeside Center", point: SIMD2(1960, 2870), eastLabel: true, targetHeight: 16, framingRadius: 280, detailLevel: 2),
        .init(id: "mccormick-west", name: "McCormick West", point: SIMD2(1292, 3152.5), eastLabel: false, targetHeight: 17, framingRadius: 275, detailLevel: 2),
        .init(id: "mccormick-north", name: "McCormick North", point: SIMD2(1623.5, 2818), eastLabel: false, targetHeight: 28.5, framingRadius: 290, detailLevel: 2),
        .init(id: "mccormick-south", name: "McCormick South", point: SIMD2(1650.5, 3210), eastLabel: true, targetHeight: 17, framingRadius: 290, detailLevel: 2)
    ]
}

/// Immutable, simplified two-dimensional geometry. No SceneData or renderer is constructed.
struct ChicagoMapGeometry: Sendable {
    // Keep each polygon's rings together: even-odd holes belong to that polygon,
    // while overlapping water records from successive regions must fill as a union.
    var water: [[[SIMD2<Float>]]] = []
    var parks: [[SIMD2<Float>]] = []
    var footprints: [[SIMD2<Float>]] = []
    var streets: [[SIMD2<Float>]] = []
    var arterials: [[SIMD2<Float>]] = []
    var loadedResources = 0
    var vertexCount: Int { (water.flatMap { $0 } + parks + footprints + streets + arterials).reduce(0) { $0 + $1.count } }

    private struct PolygonRecord: Decodable {
        let id: Int64
        let points: [[Float]]
        let rings: [[[Float]]]?
        let kind: String?
    }
    private struct LineRecord: Decodable {
        let id: Int64
        let points: [[Float]]
        let kind: String
    }
    private struct DriveRecord: Decodable { let points: [[Float]] }
    private struct WaterRecord: Decodable {
        let surface: PolygonRecord
        private enum CodingKeys: String, CodingKey { case surface }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // NorthSide includes physical water elevations; the other regions
            // store their two-dimensional water polygons directly.
            if container.contains(.surface) {
                surface = try container.decode(PolygonRecord.self, forKey: .surface)
            } else {
                surface = try PolygonRecord(from: decoder)
            }
        }
    }
    private struct Archive: Decodable {
        let buildings: [PolygonRecord]
        let areas: [PolygonRecord]
        let paths: [LineRecord]
        let water: PolygonRecord?
        let rivers: [PolygonRecord]?
        let inlandWaters: [WaterRecord]?
        let roads: [DriveRecord]?
    }

    static func resourceURL(folder: String, root: URL? = nil) -> URL? {
        let relative = "\(folder)/\(folder)Context.json"
        var candidates: [URL] = []
        if let root { candidates.append(root.appendingPathComponent(relative)) }
        else {
            if let resources = Bundle.main.resourceURL {
                candidates.append(resources.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/\(relative)"))
                candidates.append(resources.appendingPathComponent("Resources/\(relative)"))
            }
            #if SWIFT_PACKAGE
            candidates.append(Bundle.module.bundleURL.appendingPathComponent("Resources/\(relative)"))
            #endif
            candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Sources/ArchitectureEngine/Resources/\(relative)"))
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func load(resourceRoot: URL? = nil) throws -> ChicagoMapGeometry {
        var map = ChicagoMapGeometry()
        var buildingIDs = Set<Int64>(), roadIDs = Set<Int64>(), parkIDs = Set<Int64>()
        var candidates: [(area: Float, id: Int64, rings: [[SIMD2<Float>]])] = []
        let major = Set(["motorway", "trunk", "primary", "secondary", "tertiary", "motorway_link", "trunk_link"])
        let local = Set(["residential", "unclassified", "living_street"])
        for folder in ["Chicago", "Lakefront", "MuseumCampus", "NorthSide", "HydePark", "NavyPier"] {
            guard let url = resourceURL(folder: folder, root: resourceRoot) else {
                throw CocoaError(.fileNoSuchFile)
            }
            // Decode just the map-facing fields and release this archive before the next file.
            let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: url))
            map.loadedResources += 1
            for record in [archive.water].compactMap({ $0 }) + (archive.rivers ?? []) + (archive.inlandWaters ?? []).map(\.surface) {
                let polygon = rings(record).map { simplify($0, tolerance: 9, closed: true) }.filter { $0.count > 2 }
                if !polygon.isEmpty { map.water.append(polygon) }
            }
            for record in archive.areas where parkIDs.insert(record.id).inserted {
                guard ["park", "garden", "grass", "pitch", "sand"].contains(record.kind ?? "") else { continue }
                for ring in rings(record) where area(ring) > 2500 {
                    map.parks.append(simplify(ring, tolerance: 18, closed: true))
                }
            }
            for record in archive.paths where roadIDs.insert(record.id).inserted {
                guard major.contains(record.kind) || local.contains(record.kind) else { continue }
                let points = points(record.points)
                guard points.count > 1 else { continue }
                let line = simplify(points, tolerance: major.contains(record.kind) ? 10 : 24, closed: false)
                guard major.contains(record.kind) || simd_distance(line.first!, line.last!) > 70 else { continue }
                if major.contains(record.kind) { map.arterials.append(line) }
                else { map.streets.append(line) }
            }
            for road in archive.roads ?? [] {
                let line = road.points.compactMap { q -> SIMD2<Float>? in
                    guard q.count >= 3, q[0].isFinite, q[2].isFinite else { return nil }
                    return SIMD2(q[0], q[2])
                }
                if line.count > 1 { map.arterials.append(simplify(line, tolerance: 10, closed: false)) }
            }
            for record in archive.buildings where buildingIDs.insert(record.id).inserted {
                let outline = rings(record)
                guard let exterior = outline.first, exterior.count > 2 else { continue }
                let footprintArea = area(exterior)
                let center = exterior.reduce(SIMD2<Float>.zero, +) / Float(exterior.count)
                let nearby = ChicagoMapLandmark.all.contains { simd_distance($0.point, center) < 700 }
                guard footprintArea > (nearby ? 400 : 1400) else { continue }
                let simplified: [[SIMD2<Float>]]
                if nearby { simplified = outline.map { simplify($0, tolerance: 7, closed: true) }.filter { $0.count > 2 } }
                else {
                    let minX = exterior.map(\.x).min()!, maxX = exterior.map(\.x).max()!
                    let minZ = exterior.map(\.y).min()!, maxZ = exterior.map(\.y).max()!
                    simplified = [[SIMD2(minX, minZ), SIMD2(maxX, minZ), SIMD2(maxX, maxZ), SIMD2(minX, maxZ)]]
                }
                candidates.append((footprintArea, record.id, simplified))
            }
        }
        // Tiny houses are below a pixel at city scale; retain the largest mapped footprints.
        candidates.sort { $0.area == $1.area ? $0.id < $1.id : $0.area > $1.area }
        map.footprints = candidates.prefix(5000).flatMap(\.rings)
        return map
    }

    private static func points(_ raw: [[Float]]) -> [SIMD2<Float>] {
        raw.compactMap { $0.count >= 2 && $0[0].isFinite && $0[1].isFinite ? SIMD2($0[0], $0[1]) : nil }
    }
    private static func rings(_ record: PolygonRecord) -> [[SIMD2<Float>]] {
        (record.rings ?? [record.points]).map(points).filter { $0.count > 2 }
    }
    static func area(_ ring: [SIMD2<Float>]) -> Float {
        guard let first = ring.first, ring.count > 2 else { return 0 }
        return abs((1..<(ring.count - 1)).reduce(Float(0)) { value, i in
            let a = ring[i] - first, b = ring[i + 1] - first
            return value + a.x * b.y - a.y * b.x
        }) / 2
    }
    static func simplify(_ points: [SIMD2<Float>], tolerance: Float, closed: Bool) -> [SIMD2<Float>] {
        guard points.count > (closed ? 3 : 2) else { return points }
        if closed {
            var ring = points
            if ring.last == ring.first { ring.removeLast() }
            guard ring.count > 3 else { return ring }
            let pivot = ring.indices.max { simd_distance_squared(ring[$0], ring[0]) < simd_distance_squared(ring[$1], ring[0]) }!
            guard pivot > 0 else { return ring }
            let a = simplify(Array(ring[0...pivot]), tolerance: tolerance, closed: false)
            let b = simplify(Array(ring[pivot...]) + [ring[0]], tolerance: tolerance, closed: false)
            let result = Array(a.dropLast()) + Array(b.dropLast())
            return result.count >= 3 ? result : ring
        }
        var keep: Set<Int> = [0, points.count - 1]
        var spans = [(0, points.count - 1)]
        let epsilon = max(0, tolerance) * max(0, tolerance)
        while let (start, end) = spans.popLast() {
            if end <= start + 1 { continue }
            let direction = points[end] - points[start], length = simd_length_squared(direction)
            var maximum = epsilon, index: Int?
            for i in (start + 1)..<end {
                let fraction = length > 0 ? max(0, min(1, simd_dot(points[i] - points[start], direction) / length)) : 0
                let distance = simd_distance_squared(points[i], points[start] + direction * fraction)
                if distance > maximum { maximum = distance; index = i }
            }
            if let index { keep.insert(index); spans.append((start, index)); spans.append((index, end)) }
        }
        return keep.sorted().map { points[$0] }
    }
}

@MainActor
private final class ChicagoMapStore: ObservableObject {
    static let shared = ChicagoMapStore()
    @Published private(set) var geometry: ChicagoMapGeometry?
    @Published private(set) var failed = false
    private var started = false
    func loadOnce() {
        guard !started else { return }
        started = true
        Task {
            do {
                let result = try await Task.detached(priority: .utility) { try ChicagoMapGeometry.load() }.value
                geometry = result
            } catch { failed = true }
        }
    }
}

/// The Canvas, hover handler, click handler and accessibility actions share these
/// exact landmark identities. Labels may move to avoid collisions; targets do not.
struct ChicagoMapLabel: Identifiable {
    let landmark: ChicagoMapLandmark
    let marker: CGPoint
    let rect: CGRect
    var id: String { landmark.id }
    var dotRect: CGRect { CGRect(x: marker.x-7, y: marker.y-7, width: 14, height: 14) }

    static func hitTest(_ point: CGPoint, labels: [ChicagoMapLabel]) -> ChicagoMapLandmark? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        // Closest actual dot wins where nearby buildings share a small map area.
        if let dot = labels.filter({ $0.dotRect.contains(point) }).min(by: {
            hypot($0.marker.x-point.x, $0.marker.y-point.y) < hypot($1.marker.x-point.x, $1.marker.y-point.y)
        }) { return dot.landmark }
        return labels.first { $0.rect.contains(point) }?.landmark
    }

    static func layout(projection: ChicagoMapProjection, size: ChicagoMapSize, avoiding: [CGRect] = []) -> [ChicagoMapLabel] {
        var labels: [ChicagoMapLabel] = []
        let limit = size == .small ? 7 : size == .medium ? 15 : 26
        let canvas = projection.canvasRect.insetBy(dx: 4, dy: 4)
        let candidates = ChicagoMapLandmark.all.filter { $0.detailLevel <= size.detailLevel }.compactMap { landmark -> (ChicagoMapLandmark, CGPoint)? in
            let p = projection.point(for: landmark.point)
            return canvas.insetBy(dx: 4, dy: 4).contains(p) ? (landmark, p) : nil
        }
        let dots = candidates.map { CGRect(x: $0.1.x-5, y: $0.1.y-5, width: 10, height: 10) }
        for (landmark, p) in candidates {
            guard labels.count < limit else { break }
            let text = (landmark.name as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .medium)])
            let width = ceil(text.width)+10, height: CGFloat = 18
            guard width <= canvas.width else { continue }
            var positions: [CGRect] = []
            for offset: CGFloat in [0, -20, 20, -40, 40, -60, 60] {
                for east in [landmark.eastLabel, !landmark.eastLabel] {
                    let x = east ? p.x+11 : p.x-width-11
                    positions.append(CGRect(x: max(canvas.minX, min(canvas.maxX-width, x)),
                                            y: p.y-height/2+offset, width: width, height: height))
                }
            }
            if let rect = positions.first(where: { rect in
                canvas.contains(rect) && !avoiding.contains(where: { $0.insetBy(dx: -2, dy: -2).intersects(rect) })
                    && !labels.contains(where: { $0.rect.insetBy(dx: -3, dy: -3).intersects(rect) })
                    && !dots.contains(where: { $0.intersects(rect) })
            }) {
                labels.append(ChicagoMapLabel(landmark: landmark, marker: p, rect: rect))
            }
        }
        return labels
    }
}

private struct ChicagoMapBasemap: View, Equatable {
    let geometry: ChicagoMapGeometry
    let projection: ChicagoMapProjection
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.projection == rhs.projection }
    var body: some View {
        Canvas { context, _ in
            context.fill(Path(projection.canvasRect), with: .color(Color(red: 0.16, green: 0.19, blue: 0.20)))
            context.fill(Path(projection.coverageRect), with: .color(Color(red: 0.24, green: 0.29, blue: 0.27)))
            func path(_ lines: [[SIMD2<Float>]], closed: Bool) -> Path {
                var result = Path()
                for line in lines {
                    guard let first = line.first else { continue }
                    result.move(to: projection.point(for: first))
                    for point in line.dropFirst() { result.addLine(to: projection.point(for: point)) }
                    if closed { result.closeSubpath() }
                }
                return result
            }
            context.clip(to: Path(projection.canvasRect))
            context.fill(path(geometry.parks, closed: true), with: .color(Color(red: 0.24, green: 0.37, blue: 0.29)), style: FillStyle(eoFill: true))
            for polygon in geometry.water {
                context.fill(path(polygon, closed: true), with: .color(Color(red: 0.10, green: 0.23, blue: 0.30)), style: FillStyle(eoFill: true))
            }
            context.fill(path(geometry.footprints, closed: true), with: .color(.white.opacity(0.20)), style: FillStyle(eoFill: true))
            context.stroke(path(geometry.streets, closed: false), with: .color(.white.opacity(0.20)), lineWidth: 0.45)
            context.stroke(path(geometry.arterials, closed: false), with: .color(Color(red: 0.75, green: 0.76, blue: 0.65).opacity(0.65)), lineWidth: 0.8)
            context.stroke(Path(projection.coverageRect), with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
        }
        .frame(width: projection.canvasSize.width, height: projection.canvasSize.height)
        .allowsHitTesting(false)
    }
}

/// A lightweight picture-in-picture navigation aid; the controller owns landing safety.
struct ChicagoNavigationMap: View {
    let camera: ChicagoMapCamera
    @Binding var isVisible: Bool
    @Binding var size: ChicagoMapSize
    var maximumHeight: CGFloat = 540
    var maximumWidth: CGFloat = 620
    let onNavigate: (SIMD2<Float>) -> Void
    let onLandmarkNavigate: (ChicagoMapLandmark) -> Void
    var onPan: (SIMD2<Float>) -> SIMD2<Float> = { _ in .zero }
    @State private var mapCenter: SIMD2<Float>?
    @State private var mapZoom: CGFloat = 1
    @State private var drag = ChicagoMapDrag()
    @State private var hoverPoint: CGPoint?
    @StateObject private var store = ChicagoMapStore.shared
    private let accent = Color(red: 0.84, green: 0.75, blue: 0.55)

    var body: some View {
        Group {
            if isVisible { expanded }
            else {
                Button { isVisible = true } label: {
                    Label("Map · M", systemImage: "map").font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 9)
                }
                .buttonStyle(.plain).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityLabel("Show Chicago map").accessibilityIdentifier("chicago.map.show")
            }
        }
        .onAppear { store.loadOnce() }
    }

    private var expanded: some View {
        let card = size.cardSize(maximumHeight: maximumHeight, maximumWidth: maximumWidth)
        let canvas = CGSize(width: card.width, height: max(0, card.height - 66))
        let narrow = card.width < 230
        return VStack(spacing: 0) {
            HStack(spacing: narrow ? 3 : 6) {
                if !narrow { Image(systemName: "map").foregroundStyle(accent) }
                Text(narrow ? "MAP" : "CHICAGO").font(.system(size: 10, weight: .semibold)).tracking(narrow ? 0 : 1.2)
                Spacer(minLength: 2)
                ForEach(ChicagoMapSize.allCases) { option in
                    Button { size = option } label: {
                        Text(option.abbreviation).font(.system(size: 10, weight: .semibold))
                            .frame(width: narrow ? 16 : 18, height: 22)
                            .background(size == option ? accent.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain).help("\(option.rawValue.capitalized) map")
                        .accessibilityLabel("\(option.rawValue.capitalized) map")
                        .accessibilityIdentifier("chicago.map.size.\(option.rawValue)")
                }
                Button { isVisible = false } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 20, height: 22) }
                    .buttonStyle(.plain).help("Hide map (M)").accessibilityLabel("Hide Chicago map")
                    .accessibilityIdentifier("chicago.map.hide")
            }
            .padding(.horizontal, narrow ? 6 : 9).frame(height: 34)
            mapCanvas(size: canvas)
            HStack(spacing: 5) {
                Text("N ↑").foregroundStyle(accent)
                Menu {
                    ForEach(ChicagoMapLandmark.all) { landmark in
                        Button(landmark.name) { navigate(landmark) }
                    }
                } label: { Text("Places") }.menuStyle(.borderlessButton).fixedSize()
                    .help("Choose any Chicago landmark")
                Button { mapZoom = max(1, mapZoom/1.5) } label: { Image(systemName: "minus.magnifyingglass") }
                    .disabled(mapZoom <= 1).accessibilityLabel("Zoom map out")
                Button { mapZoom = min(16, mapZoom*1.5) } label: { Image(systemName: "plus.magnifyingglass") }
                    .disabled(mapZoom >= 16).accessibilityLabel("Zoom map in")
                Button { mapCenter = nil; mapZoom = 1 } label: { Image(systemName: "location") }
                    .help("Recenter map on camera").accessibilityLabel("Recenter map on camera")
                Spacer(minLength: 0)
                if card.width >= 400 { Text("Drag to move").foregroundStyle(.white.opacity(0.65)) }
                if !narrow { Text("© OSM").foregroundStyle(.white.opacity(0.5)) }
            }.font(.system(size: narrow ? 9 : 10)).buttonStyle(.plain).padding(.horizontal, narrow ? 6 : 9).frame(height: 32)
                .help("© OpenStreetMap contributors · ODbL 1.0")
        }
        .frame(width: card.width, height: card.height)
        .background(Color(red: 0.075, green: 0.105, blue: 0.115).opacity(0.96), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 11))
        .accessibilityIdentifier("chicago.navigation-map")
    }

    private func navigate(_ point: SIMD2<Float>) {
        mapCenter = nil
        hoverPoint = nil
        onNavigate(point)
    }
    private func navigate(_ landmark: ChicagoMapLandmark) {
        mapCenter = nil
        hoverPoint = nil
        onLandmarkNavigate(landmark)
    }
    private func mapCanvas(size: CGSize) -> some View {
        let base = ChicagoMapProjection(canvasSize: size, zoom: mapZoom)
        let projection = mapCenter.map { ChicagoMapProjection(canvasSize: size, center: $0, zoom: mapZoom) }
            ?? base.centered(on: camera.position)
        let marker = ChicagoMapCameraMarker.make(position: camera.position, projection: projection)
        let reserved = [marker?.square, marker?.labelRect].compactMap { $0 }
        let labels = ChicagoMapLabel.layout(projection: projection, size: self.size, avoiding: reserved)
        let hoveredLandmarkID = drag.isDragging ? nil : hoverPoint.flatMap { ChicagoMapLabel.hitTest($0, labels: labels)?.id }
        return ZStack {
            Color.black.opacity(0.15)
            if let geometry = store.geometry {
                ChicagoMapBasemap(geometry: geometry, projection: projection).equatable()
                Canvas { context, _ in
                    for label in labels {
                        let highlighted = hoveredLandmarkID == label.id
                        let color = highlighted ? Color(red: 1, green: 0.9, blue: 0.56) : accent
                        let radius: CGFloat = highlighted ? 4 : 2.5
                        let dot = Path(ellipseIn: CGRect(x: label.marker.x-radius, y: label.marker.y-radius, width: radius*2, height: radius*2))
                        context.stroke(dot, with: .color(.black.opacity(0.85)), lineWidth: 2)
                        context.fill(dot, with: .color(color))
                        var leader = Path()
                        leader.move(to: label.marker)
                        leader.addLine(to: CGPoint(x: max(label.rect.minX, min(label.rect.maxX, label.marker.x)),
                                                  y: max(label.rect.minY, min(label.rect.maxY, label.marker.y))))
                        context.stroke(leader, with: .color(color.opacity(highlighted ? 1 : 0.55)), lineWidth: highlighted ? 1.3 : 0.6)
                        let backing = Path(roundedRect: label.rect, cornerRadius: 3)
                        context.fill(backing, with: .color(highlighted ? Color(red: 0.24, green: 0.21, blue: 0.12) : .black.opacity(0.72)))
                        if highlighted { context.stroke(backing, with: .color(color), lineWidth: 1) }
                        context.draw(Text(label.landmark.name).font(.system(size: 10, weight: .medium)).foregroundColor(highlighted ? color : .white),
                                     at: CGPoint(x: label.rect.midX, y: label.rect.midY))
                    }
                    if let marker {
                        let p = marker.center
                        let markerColor = marker.outsideCoverage ? Color(red: 1, green: 0.75, blue: 0.38) : Color(red: 1, green: 0.88, blue: 0.46)
                        if !marker.offscreen && marker.projectedPosition != p {
                            var leader = Path()
                            leader.move(to: marker.projectedPosition); leader.addLine(to: p)
                            context.stroke(leader, with: .color(.black.opacity(0.9)), lineWidth: 3)
                            context.stroke(leader, with: .color(markerColor), lineWidth: 1)
                        }
                        let outline = Path(marker.square)
                        context.fill(outline, with: .color(.black.opacity(0.45)))
                        context.stroke(outline, with: .color(.black.opacity(0.9)), lineWidth: 4.5)
                        context.stroke(outline, with: .color(markerColor),
                                       style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round, dash: [0.1, 4]))
                        let forward = CGPoint(x: CGFloat(camera.heading.x), y: CGFloat(camera.heading.y))
                        let right = CGPoint(x: -forward.y, y: forward.x)
                        var arrow = Path()
                        arrow.move(to: CGPoint(x: p.x + forward.x * 8, y: p.y + forward.y * 8))
                        arrow.addLine(to: CGPoint(x: p.x - forward.x * 5 + right.x * 4, y: p.y - forward.y * 5 + right.y * 4))
                        arrow.addLine(to: CGPoint(x: p.x - forward.x * 3, y: p.y - forward.y * 3))
                        arrow.addLine(to: CGPoint(x: p.x - forward.x * 5 - right.x * 4, y: p.y - forward.y * 5 - right.y * 4))
                        arrow.closeSubpath()
                        context.stroke(arrow, with: .color(.black.opacity(0.8)), lineWidth: 2.5)
                        context.fill(arrow, with: .color(markerColor))
                        if let label = marker.label, let rect = marker.labelRect {
                            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.black.opacity(0.92)))
                            context.draw(Text(label).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(markerColor),
                                         at: CGPoint(x: rect.midX, y: rect.midY))
                        }
                    }
                }.allowsHitTesting(false)
            } else {
                VStack(spacing: 6) {
                    if !store.failed { ProgressView().controlSize(.small) }
                    Text(store.failed ? "Map unavailable" : "Loading Chicago map…").font(.system(size: 10))
                }
            }
        }
        .frame(width: size.width, height: size.height).clipped().contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): hoverPoint = drag.isDragging ? nil : point
            case .ended: hoverPoint = nil
            }
        }
        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
            guard store.geometry != nil, let pixels = drag.update(translation: value.translation),
                  let requested = projection.panDelta(screenDelta: pixels) else { return }
            hoverPoint = nil
            let applied = onPan(requested)
            guard applied.x.isFinite, applied.y.isFinite else { return }
            mapCenter = projection.center + applied
        }.onEnded { value in
            guard drag.end(translation: value.translation), store.geometry != nil else { return }
            if let landmark = ChicagoMapLabel.hitTest(value.location, labels: labels) {
                navigate(landmark)
            } else if let world = projection.world(at: value.location) { navigate(world) }
        })
        .accessibilityLabel("Chicago navigation map, north up")
        .accessibilityValue(marker == nil ? "Camera position unavailable" : marker?.label ?? "Camera position marked by the dotted square")
        .accessibilityHint("Drag to move the map and camera together. Select a landmark or map position to fly there. Zoom or use Places to reach the whole city.")
        .accessibilityChildren {
            ForEach(ChicagoMapLandmark.all) { landmark in
                Button("Frame \(landmark.name)") { navigate(landmark) }
            }
        }
    }
}
