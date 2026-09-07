import Foundation
import simd

/// Polygonal Wavefront OBJ/MTL input. Coordinates are preserved; `scale` converts
/// the source units to metres. No recentering, axis swap, or hidden fitting occurs.
enum OBJScene {
    static let materialLimitations = "OBJ imports RGB Kd, Ns, Ks and d/Tr from MTL. Texture, bump, displacement and reflection maps are not loaded. Ns/Ks are approximated by roughness/metallicity; translucent materials use opaque reflective glazing. Supply vn normals for smooth shading; smoothing groups without vn use flat face normals."

    struct ImportError: LocalizedError {
        let file: String
        let line: Int
        let message: String
        var errorDescription: String? { "\(file)\(line > 0 ? ":\(line)" : ""): \(message)" }
    }
    private struct Corner { let position: Int; let normal: Int? }
    private struct Material {
        var diffuse = SIMD3<Float>(repeating: 0.65)
        var specular = SIMD3<Float>(repeating: 0.04)
        var shininess: Float = 16
        var opacity: Float = 1
        var sceneMaterial: SceneMaterial {
            let spec = max(specular.x, max(specular.y, specular.z))
            let metal = max(0, min(1, (spec - 0.04) / 0.96))
            let rough = max(0.065, min(1, sqrt(2 / (shininess + 2))))
            return SceneMaterial(simd_clamp(diffuse, .zero, SIMD3(repeating: 0.97)),
                                 roughness: opacity < 0.999 ? min(rough, 0.13) : rough,
                                 metallic: opacity < 0.999 ? max(metal, 0.75) : metal,
                                 pattern: opacity < 0.999 ? 6 : 0)
        }
    }

    static func load(url: URL, scale: Float = 1) throws -> SceneData {
        guard scale.isFinite && scale > 0 else {
            throw ImportError(file: url.lastPathComponent, line: 0, message: "Scale must be a finite positive number of metres per source unit.")
        }
        let source = try read(url)
        var positions: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = []
        var textureCount = 0
        var scene = SceneData()
        scene.name = url.deletingPathExtension().lastPathComponent
        var materialNames = [""]
        var materialIDs: [String: UInt32] = ["": 0]
        var definitions: [String: Material] = [:]
        var selectedMaterial: UInt32 = 0
        var notices = Set<String>()
        let directory = url.deletingLastPathComponent()
        for (line, words) in try statements(source, file: url.lastPathComponent) {
            let key = words[0], args = Array(words.dropFirst())
            func fail(_ text: String) -> ImportError { ImportError(file: url.lastPathComponent, line: line, message: text) }
            switch key {
            case "v":
                guard args.count == 3 || args.count == 4 || args.count == 6 || args.count == 7 else { throw fail("Vertex requires x y z, optional homogeneous w, or the RGB vertex-colour extension.") }
                let values = try args.map { try number($0, url: url, line: line) }
                var p = SIMD3(values[0], values[1], values[2])
                if values.count == 4 || values.count == 7 {
                    guard values[3] != 0 else { throw fail("Homogeneous vertex weight w cannot be zero.") }
                    p /= values[3]
                }
                p *= scale
                guard p.x.isFinite && p.y.isFinite && p.z.isFinite else { throw fail("Scaled vertex position exceeds finite 32-bit coordinates.") }
                if values.count >= 6 { notices.insert("Per-vertex RGB colours are ignored; MTL surface colours are used.") }
                positions.append(p)
            case "vn":
                guard args.count == 3 else { throw fail("Vertex normal requires three numbers.") }
                let v = try args.map { try number($0, url: url, line: line) }
                let n = SIMD3(v[0], v[1], v[2])
                let magnitude = max(abs(n.x), max(abs(n.y), abs(n.z)))
                guard magnitude > 0 else { throw fail("Vertex normal cannot have zero length.") }
                normals.append(simd_normalize(n / magnitude))
            case "vt":
                guard (1...3).contains(args.count) else { throw fail("Texture coordinate requires one to three numbers.") }
                for value in args { _ = try number(value, url: url, line: line) }
                textureCount += 1
            case "f":
                guard args.count >= 3 else { throw fail("Face requires at least three corners.") }
                guard args.count <= 4096 else { throw fail("Face has more than 4096 corners; triangulate this polygon in the source application.") }
                var corners: [Corner] = []
                for token in args {
                    let fields = token.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
                    guard (1...3).contains(fields.count), !fields[0].isEmpty else { throw fail("Malformed face corner '\(token)'. Expected v, v/vt, v//vn or v/vt/vn.") }
                    let p = try index(fields[0], count: positions.count, kind: "vertex", url: url, line: line)
                    if fields.count >= 2, !fields[1].isEmpty { _ = try index(fields[1], count: textureCount, kind: "texture", url: url, line: line) }
                    if fields.count == 2 && fields[1].isEmpty { throw fail("Face corner '\(token)' has an empty texture index.") }
                    var n: Int?
                    if fields.count == 3 {
                        guard !fields[2].isEmpty else { throw fail("Face corner '\(token)' has an empty normal index.") }
                        n = try index(fields[2], count: normals.count, kind: "normal", url: url, line: line)
                    }
                    corners.append(Corner(position: p, normal: n))
                }
                if corners.count > 3 && corners.first!.position == corners.last!.position { corners.removeLast() }
                let triangles = try triangulate(corners.map { positions[$0.position] }, url: url, line: line)
                for triangle in triangles {
                    let p0 = positions[corners[triangle.0].position]
                    let p1 = positions[corners[triangle.1].position]
                    let p2 = positions[corners[triangle.2].position]
                    let normal64 = simd_normalize(simd_cross(SIMD3<Double>(p1) - SIMD3<Double>(p0), SIMD3<Double>(p2) - SIMD3<Double>(p0)))
                    let faceNormal = SIMD3<Float>(normal64)
                    for i in [triangle.0, triangle.1, triangle.2] {
                        let corner = corners[i]
                        scene.vertices.append(SceneVertex(positions[corner.position], corner.normal.map { normals[$0] } ?? faceNormal))
                    }
                    scene.materialIndices.append(selectedMaterial)
                }
            case "mtllib":
                guard !args.isEmpty else { throw fail("mtllib requires a material-library filename.") }
                // Accommodate filenames with spaces when that exact file exists;
                // otherwise follow OBJ's list of whitespace-separated libraries.
                let joined = args.joined(separator: " ")
                let filenames = FileManager.default.fileExists(atPath: directory.appendingPathComponent(joined).path) ? [joined] : args
                for filename in filenames {
                    let materialURL = directory.appendingPathComponent(filename)
                    let parsed = try loadMaterials(materialURL, notices: &notices)
                    definitions.merge(parsed) { _, newer in newer }
                }
            case "usemtl":
                guard !args.isEmpty else { throw fail("usemtl requires a material name.") }
                let name = args.joined(separator: " ")
                if let id = materialIDs[name] { selectedMaterial = id }
                else {
                    guard materialNames.count < Int(UInt32.max) else { throw fail("Too many materials for 32-bit material indices.") }
                    selectedMaterial = UInt32(materialNames.count)
                    materialIDs[name] = selectedMaterial
                    materialNames.append(name)
                }
            case "o", "g", "s": break
            case "l", "p": notices.insert("Point and line primitives are ignored; only polygon surfaces are rendered.")
            case "curv", "curv2", "surf": throw fail("Free-form curves/surfaces are unsupported; export a polygon mesh.")
            default: notices.insert("Unsupported OBJ statement '\(key)' was ignored.")
            }
        }
        guard !scene.vertices.isEmpty else { throw ImportError(file: url.lastPathComponent, line: 0, message: "No renderable polygon faces were found.") }
        scene.materials = materialNames.map { name in
            if let material = definitions[name] { return material.sceneMaterial }
            if !name.isEmpty { notices.insert("Material '\(name)' has no MTL definition; using neutral grey.") }
            return Material().sceneMaterial
        }
        if !notices.isEmpty {
            let message = "OBJ import notes (\(url.lastPathComponent)):\n" + notices.sorted().map { "  • " + $0 }.joined(separator: "\n") + "\n"
            FileHandle.standardError.write(Data(message.utf8))
        }
        return scene
    }

    private static func read(_ url: URL) throws -> String {
        do { return try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "\u{feff}", with: "") }
        catch { throw ImportError(file: url.path, line: 0, message: "Could not read UTF-8 file: \(error.localizedDescription)") }
    }
    private static func statements(_ text: String, file: String) throws -> [(Int, [String])] {
        var result: [(Int, [String])] = [], pending = "", start = 0
        for (offset, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let content = raw.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if pending.isEmpty { start = offset + 1 }
            if content.hasSuffix("\\") { pending += content.dropLast() + " "; continue }
            let joined = pending + content
            pending = ""
            let words = joined.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            if !words.isEmpty { result.append((start, words)) }
        }
        guard pending.isEmpty else { throw ImportError(file: file, line: start, message: "Unfinished line continuation at end of file.") }
        return result
    }
    private static func number(_ text: String, url: URL, line: Int) throws -> Float {
        guard let value = Float(text), value.isFinite else { throw ImportError(file: url.lastPathComponent, line: line, message: "Expected a finite number, found '\(text)'.") }
        return value
    }
    private static func index(_ text: String, count: Int, kind: String, url: URL, line: Int) throws -> Int {
        guard let value = Int(text), value != 0 else { throw ImportError(file: url.lastPathComponent, line: line, message: "Invalid \(kind) index '\(text)'; OBJ indices are nonzero integers.") }
        // Check before addition to avoid integer overflow for malicious indices.
        guard value > 0 ? value <= count : value >= -count else { throw ImportError(file: url.lastPathComponent, line: line, message: "\(kind.capitalized) index \(value) is out of range for \(count) declared entries.") }
        return value > 0 ? value - 1 : count + value
    }

    private static func loadMaterials(_ url: URL, notices: inout Set<String>) throws -> [String: Material] {
        var result: [String: Material] = [:], current: String?
        for (line, words) in try statements(read(url), file: url.lastPathComponent) {
            let key = words[0], args = Array(words.dropFirst())
            func fail(_ text: String) -> ImportError { ImportError(file: url.lastPathComponent, line: line, message: text) }
            if key == "newmtl" {
                guard !args.isEmpty else { throw fail("newmtl requires a name.") }
                current = args.joined(separator: " ")
                result[current!] = Material()
                continue
            }
            guard let name = current else { throw fail("Material property '\(key)' occurs before newmtl.") }
            var m = result[name]!
            switch key {
            case "Kd", "Ks":
                guard args.count == 1 || args.count == 3 else { throw fail("\(key) requires one or three RGB numbers; spectral and XYZ forms are unsupported.") }
                let values = try args.map { try number($0, url: url, line: line) }
                let value = SIMD3(values[0], values.count == 3 ? values[1] : values[0], values.count == 3 ? values[2] : values[0])
                if key == "Kd" { m.diffuse = value } else { m.specular = value }
            case "Ns":
                guard args.count == 1 else { throw fail("Ns requires one shininess number.") }
                m.shininess = try number(args[0], url: url, line: line)
                guard m.shininess >= 0 else { throw fail("Ns shininess cannot be negative.") }
            case "d", "Tr":
                let values = args.first == "-halo" ? Array(args.dropFirst()) : args
                guard values.count == 1 else { throw fail("\(key) requires one opacity number.") }
                let value = try number(values[0], url: url, line: line)
                guard (0...1).contains(value) else { throw fail("\(key) opacity must be between 0 and 1.") }
                m.opacity = key == "Tr" ? 1 - value : value
                if m.opacity < 0.999 { notices.insert("Translucent MTL materials use opaque reflective glazing; light transmission/refraction is not implemented.") }
            case "Ka", "Ke", "Ni", "illum", "Tf", "sharpness": break
            default:
                if key.hasPrefix("map_") || ["bump", "disp", "decal", "refl", "norm"].contains(key) {
                    notices.insert("Texture, normal, displacement and reflection maps are not loaded; MTL base colours are used.")
                } else { notices.insert("Unsupported MTL statement '\(key)' was ignored.") }
            }
            result[name] = m
        }
        return result
    }

    /// Ear clipping preserves concave boundaries, unlike a triangle fan. Rejects
    /// nonplanar/self-intersecting faces rather than silently making bad geometry.
    private static func triangulate(_ values: [SIMD3<Float>], url: URL, line: Int) throws -> [(Int, Int, Int)] {
        func fail(_ text: String) -> ImportError { ImportError(file: url.lastPathComponent, line: line, message: text) }
        let p = values.map(SIMD3<Double>.init)
        let origin = p[0]
        let relative = p.map { $0 - origin }
        var newell = SIMD3<Double>.zero
        for i in p.indices { newell += simd_cross(relative[i], relative[(i + 1) % p.count]) }
        let extent = max(relative.map { simd_length($0) }.max() ?? 0, 1e-12)
        let epsilon = extent * extent * 1e-12
        guard simd_length(newell) > epsilon else { throw fail("Face has zero area, repeated vertices, or crossing edges.") }
        let normal = simd_normalize(newell)
        guard relative.allSatisfy({ abs(simd_dot($0, normal)) <= max(1e-6, extent * 1e-5) }) else { throw fail("Face is nonplanar; triangulate it in the source application.") }
        if p.count == 3 { return [(0, 1, 2)] }
        let axis = abs(normal.x) > abs(normal.y) ? (abs(normal.x) > abs(normal.z) ? 0 : 2) : (abs(normal.y) > abs(normal.z) ? 1 : 2)
        let points: [SIMD2<Double>] = relative.map { axis == 0 ? SIMD2($0.y, $0.z) : (axis == 1 ? SIMD2($0.z, $0.x) : SIMD2($0.x, $0.y)) }
        func cross(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double { a.x * b.y - a.y * b.x }
        func turn(_ a: Int, _ b: Int, _ c: Int) -> Double { cross(points[b] - points[a], points[c] - points[a]) }
        let winding: Double = normal[axis] >= 0 ? 1 : -1
        for i in points.indices {
            let ni = (i + 1) % points.count
            guard simd_length_squared(points[i] - points[ni]) > epsilon * 1e-3 else { throw fail("Face contains consecutive duplicate vertices.") }
            for j in points.indices where j > i {
                let nj = (j + 1) % points.count
                if ni == j || nj == i { continue }
                let a = turn(i, ni, j), b = turn(i, ni, nj), c = turn(j, nj, i), d = turn(j, nj, ni)
                let boxesOverlap = max(min(points[i].x, points[ni].x), min(points[j].x, points[nj].x)) <= min(max(points[i].x, points[ni].x), max(points[j].x, points[nj].x))
                    && max(min(points[i].y, points[ni].y), min(points[j].y, points[nj].y)) <= min(max(points[i].y, points[ni].y), max(points[j].y, points[nj].y))
                if boxesOverlap && a * b <= epsilon * epsilon && c * d <= epsilon * epsilon { throw fail("Face has self-intersecting or overlapping edges.") }
            }
        }
        var remaining = Array(points.indices), triangles: [(Int, Int, Int)] = []
        while remaining.count > 3 {
            var clipped = false
            for k in remaining.indices {
                let a = remaining[(k + remaining.count - 1) % remaining.count], b = remaining[k], c = remaining[(k + 1) % remaining.count]
                let cornerArea = turn(a, b, c) * winding
                if abs(cornerArea) <= epsilon {
                    remaining.remove(at: k); clipped = true; break
                }
                if cornerArea < 0 { continue }
                let occupied = remaining.contains { t in
                    t != a && t != b && t != c && turn(a, b, t) * winding >= -epsilon && turn(b, c, t) * winding >= -epsilon && turn(c, a, t) * winding >= -epsilon
                }
                if !occupied { triangles.append((a, b, c)); remaining.remove(at: k); clipped = true; break }
            }
            guard clipped else { throw fail("Could not triangulate polygon; check its winding and duplicate vertices.") }
        }
        guard remaining.count == 3, turn(remaining[0], remaining[1], remaining[2]) * winding > epsilon else { throw fail("Polygon ends in a degenerate triangle.") }
        triangles.append((remaining[0], remaining[1], remaining[2]))
        return triangles
    }
}

/// Small integration fixtures for CLI self-test: material lookup, units, signed
/// indices, normalized normals, concavity, and rejection of invalid geometry.
func testOBJImporter() throws -> [String] {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("architecture-obj-test-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    func check(_ value: Bool, _ description: String) throws {
        if !value { throw OBJScene.ImportError(file: "OBJ self-test", line: 0, message: description) }
    }
    func fixture(_ name: String, _ text: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    _ = try fixture("wall.mtl", "newmtl stone\nKd 0.7 0.5 0.3\nKs 0.04\nNs 30\nd 1\n")
    let wall = try fixture("wall.obj", "mtllib wall.mtl\nv 0 0 0\nv 2 0 0\nv 2 1 0\nv 0 1 0\nvn 0 0 5\nusemtl stone\nf -4//-1 -3//-1 -2//-1 -1//-1\n")
    let scene = try OBJScene.load(url: wall, scale: 2)
    try check(scene.triangleCount == 2 && scene.materialIndices.count == 2, "Negative-index quad must produce two triangles.")
    try check(scene.vertices.allSatisfy { abs(simd_length(SIMD3($0.normal.x, $0.normal.y, $0.normal.z)) - 1) < 1e-5 }, "Supplied normals must be normalized.")
    try check(scene.vertices.map { $0.position.x }.max() == 4, "Unit conversion must preserve origin and multiply coordinates.")
    let material = scene.materials[Int(scene.materialIndices[0])]
    try check(abs(material.albedo.x - 0.7) < 1e-5 && abs(material.albedo.w - 0.25) < 1e-5, "MTL Kd/Ns material lookup failed.")
    let concave = try fixture("concave.obj", "v 0 0 0\nv 2 0 0\nv 2 2 0\nv 1 1 0\nv 0 2 0\nf 1 2 3 4 5\n")
    let concaveScene = try OBJScene.load(url: concave)
    var area: Float = 0
    for i in stride(from: 0, to: concaveScene.vertices.count, by: 3) {
        let a = concaveScene.vertices[i].position, b = concaveScene.vertices[i + 1].position, c = concaveScene.vertices[i + 2].position
        area += simd_length(simd_cross(SIMD3(b.x-a.x,b.y-a.y,b.z-a.z), SIMD3(c.x-a.x,c.y-a.y,c.z-a.z))) * 0.5
    }
    try check(concaveScene.triangleCount == 3 && abs(area - 3) < 1e-5, "Concave triangulation must preserve polygon area.")
    for (name, face) in [("range", "1 2 99"), ("zero", "0 2 3"), ("malformed", "1// 2 3"), ("degenerate", "1 1 2")] {
        let invalid = try fixture(name + ".obj", "v 0 0 0\nv 1 0 0\nv 0 1 0\nf \(face)\n")
        do {
            _ = try OBJScene.load(url: invalid)
            throw NSError(domain: "OBJTestAcceptedInvalidGeometry", code: 1)
        } catch let error as OBJScene.ImportError {
            try check(error.line == 4, "Malformed-face error must identify its source line.")
        }
    }
    return ["OBJ: negative-index quad, metre scaling and normalized normals", "MTL: named Kd/Ns/Ks/d material", "OBJ: concave polygon preserves area", "OBJ: malformed, zero, out-of-range and degenerate indices rejected"]
}
