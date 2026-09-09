import Foundation
import SwiftUI
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

    /// Keep the choices distinct even when a short application window limits the card.
    func cardSize(maximumHeight: CGFloat) -> CGSize {
        let available = maximumHeight.isFinite ? max(180, min(540, maximumHeight)) : 540
        let fraction: CGFloat = self == .small ? 0.52 : self == .medium ? 0.76 : 1
        let height = 140 + (available - 140) * fraction
        let width: CGFloat = self == .small ? 212 : self == .medium ? 266 : 324
        return CGSize(width: width, height: height)
    }
}

struct ChicagoMapProjection: Equatable, Sendable {
    static let worldMinimum = SIMD2<Float>(-4000, -11500)
    static let worldMaximum = SIMD2<Float>(6000, 11000)
    let canvasSize: CGSize
    let inset: CGFloat

    init(canvasSize: CGSize, inset: CGFloat = 8) {
        self.canvasSize = canvasSize
        self.inset = max(0, inset.isFinite ? inset : 0)
    }

    var scale: CGFloat {
        guard canvasSize.width.isFinite, canvasSize.height.isFinite else { return 0 }
        let width = max(0, canvasSize.width - inset * 2)
        let height = max(0, canvasSize.height - inset * 2)
        return min(width / 10000, height / 22500)
    }

    var fittedRect: CGRect {
        let extent = CGSize(width: 10000 * scale, height: 22500 * scale)
        return CGRect(x: (canvasSize.width - extent.width) / 2,
                      y: (canvasSize.height - extent.height) / 2,
                      width: extent.width, height: extent.height)
    }

    func point(for world: SIMD2<Float>) -> CGPoint {
        let rect = fittedRect
        return CGPoint(x: rect.minX + CGFloat(world.x - Self.worldMinimum.x) * scale,
                       y: rect.minY + CGFloat(world.y - Self.worldMinimum.y) * scale)
    }

    /// Z increases south, exactly like a top-down screen's Y. Do not invert this axis.
    func world(at point: CGPoint) -> SIMD2<Float>? {
        guard scale > 0, point.x.isFinite, point.y.isFinite else { return nil }
        let rect = fittedRect
        guard point.x >= rect.minX, point.x <= rect.maxX,
              point.y >= rect.minY, point.y <= rect.maxY else { return nil }
        return SIMD2(Float((point.x - rect.minX) / scale) + Self.worldMinimum.x,
                     Float((point.y - rect.minY) / scale) + Self.worldMinimum.y)
    }
}

struct ChicagoMapLandmark: Identifiable, Sendable {
    let id: String
    let name: String
    let point: SIMD2<Float>
    let eastLabel: Bool

    // Architectural anchors already used by the city. These labels do not load a scene.
    static let all: [ChicagoMapLandmark] = [
        .init(id: "robie", name: "Robie House", point: SIMD2(3309.7, 9917.1), eastLabel: false),
        .init(id: "wrigley", name: "Wrigley Field", point: SIMD2(-1626, -7717.6), eastLabel: false),
        .init(id: "willis", name: "Willis Tower", point: SIMD2(0, 0), eastLabel: false),
        .init(id: "zoo", name: "Lincoln Park Zoo", point: SIMD2(214.4, -4726.1), eastLabel: false),
        .init(id: "millennium", name: "Millennium Park", point: SIMD2(1130, -540), eastLabel: true),
        .init(id: "adler", name: "Adler Planetarium", point: SIMD2(2413.7, 1393.2), eastLabel: true),
        .init(id: "mccormick", name: "McCormick Place", point: SIMD2(1950, 3000), eastLabel: false),
        .init(id: "point", name: "Promontory Point", point: SIMD2(4925, 9237), eastLabel: true),
        .init(id: "harbor", name: "31st St Harbor", point: SIMD2(2662, 4773), eastLabel: true),
        .init(id: "hancock", name: "John Hancock", point: SIMD2(1062.9, -2220), eastLabel: true),
        .init(id: "oldtown", name: "Old Town", point: SIMD2(-404, -3740), eastLabel: false),
        .init(id: "art", name: "Art Institute", point: SIMD2(1088, -145), eastLabel: true),
        .init(id: "field", name: "Field Museum", point: SIMD2(1600, 1370), eastLabel: false),
        .init(id: "beach", name: "North Ave Beach", point: SIMD2(972, -3853), eastLabel: true)
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
        for folder in ["Chicago", "Lakefront", "MuseumCampus", "NorthSide", "HydePark"] {
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

private struct ChicagoMapLabel {
    let landmark: ChicagoMapLandmark
    let marker: CGPoint
    let rect: CGRect
    static func layout(projection: ChicagoMapProjection) -> [ChicagoMapLabel] {
        var labels: [ChicagoMapLabel] = []
        let limit = projection.canvasSize.height < 150 ? 4 : projection.canvasSize.height < 240 ? 8 : 14
        for landmark in ChicagoMapLandmark.all.prefix(limit) {
            let p = projection.point(for: landmark.point)
            let width = CGFloat(landmark.name.count) * 5.0 + 8
            let x = landmark.eastLabel ? min(projection.canvasSize.width - width - 3, p.x + 8) : max(3, p.x - width - 8)
            let rect = CGRect(x: x, y: max(3, min(projection.canvasSize.height - 17, p.y - 7)), width: width, height: 14)
            if !labels.contains(where: { $0.rect.insetBy(dx: -2, dy: -2).intersects(rect) }) {
                labels.append(ChicagoMapLabel(landmark: landmark, marker: p, rect: rect))
            }
        }
        return labels
    }
}

private struct ChicagoMapBasemap: View, Equatable {
    let geometry: ChicagoMapGeometry
    let canvasSize: CGSize
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.canvasSize == rhs.canvasSize }
    var body: some View {
        Canvas { context, size in
            let projection = ChicagoMapProjection(canvasSize: size)
            context.fill(Path(projection.fittedRect), with: .color(Color(red: 0.24, green: 0.29, blue: 0.27)))
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
            context.clip(to: Path(projection.fittedRect))
            context.fill(path(geometry.parks, closed: true), with: .color(Color(red: 0.24, green: 0.37, blue: 0.29)), style: FillStyle(eoFill: true))
            for polygon in geometry.water {
                context.fill(path(polygon, closed: true), with: .color(Color(red: 0.10, green: 0.23, blue: 0.30)), style: FillStyle(eoFill: true))
            }
            context.fill(path(geometry.footprints, closed: true), with: .color(.white.opacity(0.20)), style: FillStyle(eoFill: true))
            context.stroke(path(geometry.streets, closed: false), with: .color(.white.opacity(0.20)), lineWidth: 0.45)
            context.stroke(path(geometry.arterials, closed: false), with: .color(Color(red: 0.75, green: 0.76, blue: 0.65).opacity(0.65)), lineWidth: 0.8)
            context.stroke(Path(projection.fittedRect), with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }
}

/// A lightweight picture-in-picture navigation aid; the controller owns landing safety.
struct ChicagoNavigationMap: View {
    let camera: ChicagoMapCamera
    @Binding var isVisible: Bool
    @Binding var size: ChicagoMapSize
    var maximumHeight: CGFloat = 540
    let onNavigate: (SIMD2<Float>) -> Void
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
        let card = size.cardSize(maximumHeight: maximumHeight)
        let canvas = CGSize(width: card.width - 16, height: card.height - 64)
        return VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "map").foregroundStyle(accent)
                Text("CHICAGO").font(.system(size: 10, weight: .semibold)).tracking(1.2)
                Spacer(minLength: 2)
                ForEach(ChicagoMapSize.allCases) { option in
                    Button { size = option } label: {
                        Text(option.abbreviation).font(.system(size: 10, weight: .semibold))
                            .frame(width: 18, height: 22)
                            .background(size == option ? accent.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain).help("\(option.rawValue.capitalized) map")
                        .accessibilityLabel("\(option.rawValue.capitalized) map")
                        .accessibilityIdentifier("chicago.map.size.\(option.rawValue)")
                }
                Button { isVisible = false } label: { Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).frame(width: 20, height: 22) }
                    .buttonStyle(.plain).help("Hide map (M)").accessibilityLabel("Hide Chicago map")
                    .accessibilityIdentifier("chicago.map.hide")
            }
            mapCanvas(size: canvas)
            HStack(spacing: 3) {
                Text("N ↑").foregroundStyle(accent)
                Text("· Click to fly")
                Spacer(minLength: 0)
                Text("© OpenStreetMap").foregroundStyle(.white.opacity(0.5))
            }.font(.system(size: 8))
        }
        .padding(8).frame(width: card.width, height: card.height)
        .background(Color(red: 0.075, green: 0.105, blue: 0.115).opacity(0.96), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .foregroundStyle(.white)
        .accessibilityIdentifier("chicago.navigation-map")
    }

    private func mapCanvas(size: CGSize) -> some View {
        let projection = ChicagoMapProjection(canvasSize: size)
        let labels = ChicagoMapLabel.layout(projection: projection)
        return ZStack {
            Color.black.opacity(0.15)
            if let geometry = store.geometry {
                ChicagoMapBasemap(geometry: geometry, canvasSize: size).equatable()
                Canvas { context, _ in
                    for landmark in ChicagoMapLandmark.all {
                        let p = projection.point(for: landmark.point)
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(accent))
                    }
                    for label in labels {
                        var leader = Path()
                        leader.move(to: label.marker)
                        leader.addLine(to: CGPoint(x: label.landmark.eastLabel ? label.rect.minX : label.rect.maxX, y: label.rect.midY))
                        context.stroke(leader, with: .color(accent.opacity(0.55)), lineWidth: 0.6)
                        context.fill(Path(roundedRect: label.rect, cornerRadius: 2), with: .color(.black.opacity(0.65)))
                        context.draw(Text(label.landmark.name).font(.system(size: 9, weight: .medium)).foregroundColor(.white),
                                     at: CGPoint(x: label.rect.midX, y: label.rect.midY))
                    }
                    let finite = camera.position.x.isFinite && camera.position.y.isFinite
                    if finite {
                        let rect = projection.fittedRect, point = projection.point(for: camera.position)
                        let p = CGPoint(x: max(rect.minX, min(rect.maxX, point.x)), y: max(rect.minY, min(rect.maxY, point.y)))
                        let forward = CGPoint(x: CGFloat(camera.heading.x), y: CGFloat(camera.heading.y))
                        let right = CGPoint(x: -forward.y, y: forward.x)
                        var arrow = Path()
                        arrow.move(to: CGPoint(x: p.x + forward.x * 8, y: p.y + forward.y * 8))
                        arrow.addLine(to: CGPoint(x: p.x - forward.x * 5 + right.x * 4, y: p.y - forward.y * 5 + right.y * 4))
                        arrow.addLine(to: CGPoint(x: p.x - forward.x * 3, y: p.y - forward.y * 3))
                        arrow.addLine(to: CGPoint(x: p.x - forward.x * 5 - right.x * 4, y: p.y - forward.y * 5 - right.y * 4))
                        arrow.closeSubpath()
                        context.stroke(arrow, with: .color(.black.opacity(0.8)), lineWidth: 2.5)
                        context.fill(arrow, with: .color(Color(red: 1, green: 0.88, blue: 0.46)))
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
        .gesture(SpatialTapGesture().onEnded { tap in
            guard store.geometry != nil else { return }
            if let label = labels.first(where: { $0.rect.insetBy(dx: -2, dy: -2).contains(tap.location) }) {
                onNavigate(label.landmark.point)
            } else if let world = projection.world(at: tap.location) { onNavigate(world) }
        })
        .accessibilityLabel("Chicago navigation map, north up")
        .accessibilityHint("Select a landmark or map position to fly there. The arrow shows your camera position and heading.")
        .accessibilityChildren {
            ForEach(ChicagoMapLandmark.all) { landmark in
                Button("Fly to \(landmark.name)") { onNavigate(landmark.point) }
            }
        }
    }
}
