import Foundation
import CryptoKit
import Darwin
import simd

/// CPU navigation BVH. Tiny decorative triangles are omitted; rendered geometry remains intact.
final class CollisionWorld {
    struct Triangle { var a, b, c: SIMD3<Float>; var center: SIMD3<Float> { (a+b+c)/3 } }
    struct Node { var lo, hi: SIMD3<Float>; var left: Int; var right: Int; var start: Int; var count: Int }
    /// Optional small-surface retention is solely for picking. These metre-scale
    /// regions do not change the navigation triangle list or movement queries.
    struct PickingRegion {
        let minimum, maximum: SIMD3<Float>
        fileprivate func overlaps(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Bool {
            let lo=simd_min(a,simd_min(b,c)),hi=simd_max(a,simd_max(b,c))
            return lo.x<=maximum.x && hi.x>=minimum.x && lo.y<=maximum.y && hi.y>=minimum.y && lo.z<=maximum.z && hi.z>=minimum.z
        }
    }
    var triangles: [Triangle] = []
    var nodes: [Node] = []
    private var pickingDetail: CollisionWorld?
    private(set) var sourceTriangleCount = 0
    private var retainedPickingRegions: [[UInt32]] = []
    var detailedPickingTriangleCount: Int { pickingDetail?.triangles.count ?? 0 }
    var detailedPickingNodeCount: Int { pickingDetail?.nodes.count ?? 0 }

    init(scene: SceneData, detailedPickingRegions: [PickingRegion] = []) {
        sourceTriangleCount = scene.triangleCount
        retainedPickingRegions = Self.regionIdentity(detailedPickingRegions)
        var detail: [Triangle] = []
        for i in stride(from: 0, to: scene.vertices.count, by: 3) {
            let a = scene.vertices[i].position.xyz, b = scene.vertices[i+1].position.xyz, c = scene.vertices[i+2].position.xyz
            if max(simd_length_squared(b-a), simd_length_squared(c-a)) > 0.16 {
                triangles.append(Triangle(a:a,b:b,c:c))
            } else if detailedPickingRegions.contains(where: { $0.overlaps(a,b,c) }) {
                detail.append(Triangle(a:a,b:b,c:c))
            }
        }
        if !triangles.isEmpty { _ = build(0, triangles.count) }
        if !detail.isEmpty { pickingDetail=CollisionWorld(pickingTriangles:detail) }
    }
    private init(pickingTriangles: [Triangle]) {
        triangles=pickingTriangles
        if !triangles.isEmpty { _ = build(0,triangles.count) }
    }
    private init(cachedTriangles: [Triangle], cachedNodes: [Node]) {
        triangles = cachedTriangles; nodes = cachedNodes
    }

    // This cache stores the already partitioned BVHs, not a second approximation
    // of the city. Changing the executable/resource key or picking regions makes
    // it a miss. The format is local to this machine's Swift POD ABI and version.
    private struct CacheHeader: Codable {
        var version: Int
        var cacheKey: String
        var triangleStride, nodeStride, intWidth: Int
        var sourceTriangles, navigationTriangles, navigationNodes, detailTriangles, detailNodes: Int
        var regions: [[UInt32]]
    }
    private static let cacheMagic = Data("ATLCBVH1".utf8)
    private static let cacheVersion = 1
    private static func regionIdentity(_ regions: [PickingRegion]) -> [[UInt32]] {
        regions.map { [$0.minimum.x.bitPattern, $0.minimum.y.bitPattern, $0.minimum.z.bitPattern,
                       $0.maximum.x.bitPattern, $0.maximum.y.bitPattern, $0.maximum.z.bitPattern] }
    }

    /// A missing, stale, truncated, corrupt, or structurally invalid cache is a
    /// normal miss. Queries never see arrays until their bounds/tree are checked.
    static func loadCache(from url: URL, cacheKey: String, detailedPickingRegions: [PickingRegion] = [],
                          expectedSceneTriangleCount: Int? = nil) -> CollisionWorld? {
        guard let file = try? Data(contentsOf: url, options: .mappedIfSafe), file.count >= 48,
              file.prefix(8) == cacheMagic else { return nil }
        let headerSize64 = file.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt64.self).littleEndian }
        guard headerSize64 <= 131_072, headerSize64 <= UInt64(file.count - 48) else { return nil }
        let headerEnd = 16 + Int(headerSize64)
        guard let header = try? JSONDecoder().decode(CacheHeader.self, from: file.subdata(in: 16..<headerEnd)),
              header.version == cacheVersion, header.cacheKey == cacheKey,
              header.triangleStride == MemoryLayout<Triangle>.stride, header.nodeStride == MemoryLayout<Node>.stride,
              header.intWidth == Int.bitWidth, header.regions == regionIdentity(detailedPickingRegions),
              header.sourceTriangles >= 0, expectedSceneTriangleCount == nil || expectedSceneTriangleCount == header.sourceTriangles
        else { return nil }
        let counts = [header.navigationTriangles, header.navigationNodes, header.detailTriangles, header.detailNodes]
        let strides = [MemoryLayout<Triangle>.stride, MemoryLayout<Node>.stride, MemoryLayout<Triangle>.stride, MemoryLayout<Node>.stride]
        var remaining = file.count - headerEnd - 32
        for (count, stride) in zip(counts, strides) {
            guard count >= 0, count <= remaining / stride else { return nil }
            remaining -= count * stride
        }
        guard remaining == 0, header.navigationTriangles <= header.sourceTriangles,
              header.detailTriangles <= header.sourceTriangles - header.navigationTriangles else { return nil }
        // Hashing a mapped Data slice does not copy the large BVH payload.
        guard Data(SHA256.hash(data: file.prefix(file.count - 32))) == file.suffix(32) else { return nil }
        var offset = headerEnd
        func readArray<T>(_ type: T.Type, _ count: Int) -> [T] {
            let byteCount = count * MemoryLayout<T>.stride
            defer { offset += byteCount }
            return Array<T>(unsafeUninitializedCapacity: count) { buffer, initializedCount in
                if byteCount > 0 {
                    file.withUnsafeBytes { bytes in
                        UnsafeMutableRawBufferPointer(buffer).copyMemory(from: UnsafeRawBufferPointer(rebasing: bytes[offset..<(offset + byteCount)]))
                    }
                }
                initializedCount = count
            }
        }
        let navigationTriangles = readArray(Triangle.self, header.navigationTriangles)
        let navigationNodes = readArray(Node.self, header.navigationNodes)
        let detailTriangles = readArray(Triangle.self, header.detailTriangles)
        let detailNodes = readArray(Node.self, header.detailNodes)
        guard validCachedTree(triangles: navigationTriangles, nodes: navigationNodes),
              validCachedTree(triangles: detailTriangles, nodes: detailNodes) else { return nil }
        let result = CollisionWorld(cachedTriangles: navigationTriangles, cachedNodes: navigationNodes)
        result.sourceTriangleCount = header.sourceTriangles
        result.retainedPickingRegions = header.regions
        if !detailTriangles.isEmpty { result.pickingDetail = CollisionWorld(cachedTriangles: detailTriangles, cachedNodes: detailNodes) }
        return result
    }

    /// Write beside the destination and rename atomically, so another launch
    /// sees either the previous complete BVH or the new complete BVH. A failed
    /// write does not change the working in-memory navigation world.
    func writeCache(to url: URL, cacheKey: String, detailedPickingRegions: [PickingRegion] = []) throws {
        guard retainedPickingRegions == Self.regionIdentity(detailedPickingRegions) else {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSLocalizedDescriptionKey: "Collision cache picking regions do not match the built world."])
        }
        let header = CacheHeader(version: Self.cacheVersion, cacheKey: cacheKey,
            triangleStride: MemoryLayout<Triangle>.stride, nodeStride: MemoryLayout<Node>.stride, intWidth: Int.bitWidth,
            sourceTriangles: sourceTriangleCount, navigationTriangles: triangles.count, navigationNodes: nodes.count,
            detailTriangles: detailedPickingTriangleCount, detailNodes: detailedPickingNodeCount, regions: retainedPickingRegions)
        let metadata = try JSONEncoder().encode(header)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath: temporary.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        var digest = SHA256()
        func write(_ bytes: Data) throws { digest.update(data: bytes); try handle.write(contentsOf: bytes) }
        try write(Self.cacheMagic)
        var metadataSize = UInt64(metadata.count).littleEndian
        try withUnsafeBytes(of: &metadataSize) { try write(Data($0)) }
        try write(metadata)
        func writeArray<T>(_ array: [T]) throws {
            try array.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress, !bytes.isEmpty else { return }
                // This borrowed Data remains inside the array's lifetime; no
                // second multi-hundred-megabyte serialization buffer is created.
                try write(Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: base), count: bytes.count, deallocator: .none))
            }
        }
        try writeArray(triangles); try writeArray(nodes)
        if let detail = pickingDetail { try writeArray(detail.triangles); try writeArray(detail.nodes) }
        try handle.write(contentsOf: Data(digest.finalize()))
        try handle.synchronize(); try handle.close()
        guard rename(temporary.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }

    private static func validCachedTree(triangles: [Triangle], nodes: [Node]) -> Bool {
        guard !triangles.isEmpty else { return nodes.isEmpty }
        guard !nodes.isEmpty, nodes.count <= triangles.count * 2 else { return false }
        func finite(_ p: SIMD3<Float>) -> Bool { p.x.isFinite && p.y.isFinite && p.z.isFinite }
        func contains(_ lo: SIMD3<Float>, _ hi: SIMD3<Float>, _ p: SIMD3<Float>) -> Bool {
            p.x >= lo.x && p.y >= lo.y && p.z >= lo.z && p.x <= hi.x && p.y <= hi.y && p.z <= hi.z
        }
        // Every child is later than its parent in the builder's preorder array.
        // Requiring exactly one parent rules out cycles, shared nodes and orphans.
        var parents = [UInt8](repeating: 0, count: nodes.count)
        var covered = 0
        for (index, node) in nodes.enumerated() {
            guard finite(node.lo), finite(node.hi), node.lo.x <= node.hi.x, node.lo.y <= node.hi.y, node.lo.z <= node.hi.z,
                  node.start >= 0, node.start < triangles.count, node.count >= 0, node.count <= triangles.count - node.start else { return false }
            if node.count == 0 {
                guard node.left > index, node.right > index, node.left < nodes.count, node.right < nodes.count, node.left != node.right else { return false }
                for childIndex in [node.left, node.right] {
                    guard parents[childIndex] == 0 else { return false }
                    parents[childIndex] = 1
                    let child = nodes[childIndex]
                    guard contains(node.lo, node.hi, child.lo), contains(node.lo, node.hi, child.hi) else { return false }
                }
            } else {
                guard node.left == -1, node.right == -1, node.start == covered else { return false }
                for triangle in triangles[node.start..<(node.start + node.count)] {
                    guard finite(triangle.a), finite(triangle.b), finite(triangle.c),
                          contains(node.lo, node.hi, triangle.a), contains(node.lo, node.hi, triangle.b), contains(node.lo, node.hi, triangle.c) else { return false }
                }
                covered += node.count
            }
        }
        return parents[0] == 0 && parents.dropFirst().allSatisfy { $0 == 1 } && covered == triangles.count
    }
    /// Combine the existing city BVH with only its opt-in omitted triangles.
    /// Both are nearest-hit queries, so either ordinary or dense foreground
    /// geometry still prevents selecting an object behind it.
    func pickingDistance(origin: SIMD3<Float>, direction: SIMD3<Float>, maximum: Float) -> Float? {
        let ordinary=distance(origin:origin,direction:direction,maximum:maximum)
        let fine=pickingDetail?.distance(origin:origin,direction:direction,maximum:ordinary ?? maximum)
        return fine ?? ordinary
    }
    private func build(_ start: Int, _ end: Int) -> Int {
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        var clo = lo, chi = hi
        for i in start..<end {
            let t = triangles[i]
            lo = simd_min(lo, simd_min(t.a, simd_min(t.b,t.c))); hi = simd_max(hi, simd_max(t.a, simd_max(t.b,t.c)))
            clo = simd_min(clo,t.center); chi = simd_max(chi,t.center)
        }
        let index = nodes.count
        nodes.append(Node(lo:lo,hi:hi,left:-1,right:-1,start:start,count:end-start))
        if end-start <= 12 { return index }
        let extent = chi-clo
        let axis = extent.x > extent.y ? (extent.x > extent.z ? 0 : 2) : (extent.y > extent.z ? 1 : 2)
        let split = (clo[axis]+chi[axis])*0.5
        var middle = start
        for i in start..<end where triangles[i].center[axis] < split {
            if i != middle { triangles.swapAt(i,middle) }; middle += 1
        }
        if middle == start || middle == end { return index }
        let l = build(start,middle), r = build(middle,end)
        nodes[index].left = l; nodes[index].right = r; nodes[index].count = 0
        return index
    }
    func distance(origin: SIMD3<Float>, direction: SIMD3<Float>, maximum: Float) -> Float? {
        guard !nodes.isEmpty else { return nil }
        var closest = maximum, found = false, stack = [0]
        while let index = stack.popLast() {
            let n = nodes[index]
            var near: Float = 0, far = closest
            for axis in 0..<3 {
                if abs(direction[axis]) < 1e-8 {
                    if origin[axis] < n.lo[axis] || origin[axis] > n.hi[axis] { far = -1; break }
                } else {
                    let a = (n.lo[axis]-origin[axis])/direction[axis], b = (n.hi[axis]-origin[axis])/direction[axis]
                    near = max(near,min(a,b)); far = min(far,max(a,b))
                }
            }
            if far < near { continue }
            if n.count == 0 { stack.append(n.left); stack.append(n.right); continue }
            for i in n.start..<(n.start+n.count) {
                let t = triangles[i], e1 = t.b-t.a, e2 = t.c-t.a
                let p = simd_cross(direction,e2), determinant = simd_dot(e1,p)
                if abs(determinant) < 1e-7 { continue }
                let inverse = 1/determinant, s = origin-t.a, u = simd_dot(s,p)*inverse
                if u < 0 || u > 1 { continue }
                let q = simd_cross(s,e1), v = simd_dot(direction,q)*inverse
                if v < 0 || u+v > 1 { continue }
                let d = simd_dot(e2,q)*inverse
                if d > 0.001 && d < closest { closest = d; found = true }
            }
        }
        return found ? closest : nil
    }
    func canMove(from: SIMD3<Float>, to: SIMD3<Float>) -> Bool {
        let delta = to-from, length = simd_length(delta)
        if length < 0.0001 { return true }
        let direction = delta/length
        // Head, torso, and leg sweeps with a conservative personal-space margin.
        for y: Float in [0,-0.7,-1.35] {
            if distance(origin: from+SIMD3(0,y,0),direction:direction,maximum:length+0.28) != nil { return false }
        }
        return true
    }
}
extension SIMD4 where Scalar == Float { var xyz: SIMD3<Float> { SIMD3(x,y,z) } }
