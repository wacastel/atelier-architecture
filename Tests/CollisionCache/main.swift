import Foundation
import CryptoKit
import simd

typealias V = SIMD3<Float>
var checks = 0
var failures: [String] = []
var metrics: [String: Any] = [:]
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures.append(message) }
}
func timed<T>(_ operation: () throws -> T) rethrows -> (T, Double) {
    let start = ProcessInfo.processInfo.systemUptime
    let value = try operation()
    return (value, ProcessInfo.processInfo.systemUptime - start)
}
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("atelier-collision-cache-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let cacheURL = directory.appendingPathComponent("collision.bin")
let corruptURL = directory.appendingPathComponent("corrupt.bin")
let key = String(repeating: "b", count: 64) + ":chicago"

#if CITY_CACHE_VALIDATION
let (catalog, catalogSeconds) = timed { LandmarkFocusCatalog(world: "chicago") }
let bean = catalog.authored.first { $0.id == "chicago:cloud-gate" }!
let regions = [CollisionWorld.PickingRegion(minimum: bean.bounds.minimum, maximum: bean.bounds.maximum)]
let (scene, geometrySeconds) = timed { ChicagoWorld.build() }
metrics["catalogSeconds"] = catalogSeconds
metrics["geometrySeconds"] = geometrySeconds
#else
var scene = SceneData()
scene.materials = [SceneMaterial(V(0.7, 0.7, 0.7))]
func triangle(_ a: V, _ b: V, _ c: V) {
    let normal = simd_normalize(simd_cross(b - a, c - a))
    scene.vertices += [SceneVertex(a, normal), SceneVertex(b, normal), SceneVertex(c, normal)]
    scene.materialIndices.append(0)
}
for x in -9..<9 {
    for y in 0..<20 {
        let a = V(Float(x), Float(y), -6)
        triangle(a, a + V(1, 0, 0), a + V(1, 1, 0))
        triangle(a, a + V(1, 1, 0), a + V(0, 1, 0))
    }
}
for x in -5..<5 {
    for z in -5..<5 {
        let a = V(Float(x * 2), 0, Float(z * 2))
        triangle(a, a + V(2, 0, 0), a + V(2, 0, 2))
        triangle(a, a + V(2, 0, 2), a + V(0, 0, 2))
    }
}
// Omitted fine triangles in a retained picking region and one outside it.
for i in 0..<30 {
    let p = V(Float(i % 6) * 0.045 - 0.14, 3 + Float(i / 6) * 0.045, -5)
    triangle(p, p + V(0.04, 0, 0), p + V(0.02, 0.04, 0))
}
triangle(V(20, 3, -5), V(20.04, 3, -5), V(20.02, 3.04, -5))
let regions = [CollisionWorld.PickingRegion(minimum: V(-0.3, 2.9, -5.1), maximum: V(0.3, 3.4, -4.9))]
#endif

let (world, buildSeconds) = timed { CollisionWorld(scene: scene, detailedPickingRegions: regions) }
let (_, writeSeconds) = try timed { try world.writeCache(to: cacheURL, cacheKey: key, detailedPickingRegions: regions) }
let (loaded, readSeconds) = timed {
    CollisionWorld.loadCache(from: cacheURL, cacheKey: key, detailedPickingRegions: regions, expectedSceneTriangleCount: scene.triangleCount)
}
expect(loaded != nil, "A complete matching cache loads")
guard let restored = loaded else { fatalError("Cannot continue without round-trip cache") }
metrics["sourceTriangles"] = scene.triangleCount
metrics["navigationTriangles"] = world.triangles.count
metrics["navigationNodes"] = world.nodes.count
metrics["detailedPickingTriangles"] = world.detailedPickingTriangleCount
metrics["detailedPickingNodes"] = world.detailedPickingNodeCount
metrics["buildSeconds"] = buildSeconds
metrics["writeSeconds"] = writeSeconds
metrics["readAndValidateSeconds"] = readSeconds
metrics["cacheBytes"] = (try FileManager.default.attributesOfItem(atPath: cacheURL.path)[.size] as? NSNumber)?.int64Value ?? 0
expect(restored.triangles.count == world.triangles.count && restored.nodes.count == world.nodes.count, "Navigation BVH counts survive round trip")
expect(restored.detailedPickingTriangleCount == world.detailedPickingTriangleCount && restored.detailedPickingNodeCount == world.detailedPickingNodeCount, "Fine-picking BVH counts survive round trip")
for i in world.triangles.indices {
    let a = world.triangles[i], b = restored.triangles[i]
    expect(a.a == b.a && a.b == b.b && a.c == b.c, "Triangle \(i) retains exact coordinates and partition order")
}
for i in world.nodes.indices {
    let a = world.nodes[i], b = restored.nodes[i]
    expect(a.lo == b.lo && a.hi == b.hi && a.left == b.left && a.right == b.right && a.start == b.start && a.count == b.count,
           "Node \(i) retains exact bounds, links and leaf range")
}

// Identical queries exercise actual intersection/picking and movement semantics,
// not merely file bytes. Seeded directions include misses and occluded surfaces.
var seed: UInt64 = 1910
func random() -> Float { seed = seed &* 6364136223846793005 &+ 1; return Float(seed >> 40) / Float(1 << 24) }
for index in 0..<2048 {
    #if CITY_CACHE_VALIDATION
    let origin = V(-1_000 + random() * 4_500, 2 + random() * 600, -11_000 + random() * 18_000)
    #else
    let origin = V(-12 + random() * 24, 0.1 + random() * 22, -12 + random() * 24)
    #endif
    let direction = simd_normalize(V(random() * 2 - 1, random() * 2 - 1, random() * 2 - 1))
    let maximum: Float = 50_000
    expect(world.distance(origin: origin, direction: direction, maximum: maximum) == restored.distance(origin: origin, direction: direction, maximum: maximum), "Navigation ray \(index) matches")
    expect(world.pickingDistance(origin: origin, direction: direction, maximum: maximum) == restored.pickingDistance(origin: origin, direction: direction, maximum: maximum), "Fine-picking ray \(index) matches")
    expect(world.canMove(from: origin, to: origin + direction * 2) == restored.canMove(from: origin, to: origin + direction * 2), "Movement sweep \(index) matches")
}

#if CITY_CACHE_VALIDATION
for (expected, position, target) in [
    ("chicago:adler-planetarium", V(2381, 8, 1393.247), V(2413.718, 8, 1393.247)),
    ("chicago:willis-tower", V(-80, 100, 0), V(-4, 100, 0)),
    ("chicago:cloud-gate", V(1027, 8, -424.15), V(1042.46, 8, -424.15)),
    ("chicago:robie-house", RobieHouseLayout.point(V(-23, 5, 0)), RobieHouseLayout.point(V(-10, 5, 0)))
] {
    let ray = FocusRay.make(normalized: SIMD2(0.5, 0.5), aspect: 16/9, pose: CameraPose(position: position, target: target))!
    expect(catalog.pick(ray: ray, world: restored)?.id == expected, "Actual cached city selects \(expected)")
}
#else
let original = try Data(contentsOf: cacheURL)
let metadataLength = original.withUnsafeBytes { Int($0.loadUnaligned(fromByteOffset: 8, as: UInt64.self).littleEndian) }
let payloadStart = 16 + metadataLength
let nodesStart = payloadStart + world.triangles.count * MemoryLayout<CollisionWorld.Triangle>.stride
func validDigest(_ data: Data) -> Data {
    var output = data.dropLast(32)
    output.append(contentsOf: SHA256.hash(data: output))
    return Data(output)
}
func rejects(_ bytes: Data, _ message: String) throws {
    try bytes.write(to: corruptURL)
    expect(CollisionWorld.loadCache(from: corruptURL, cacheKey: key, detailedPickingRegions: regions) == nil, message)
}
func changeHeader(_ update: (inout [String: Any]) -> Void) throws -> Data {
    var dictionary = try JSONSerialization.jsonObject(with: original.subdata(in: 16..<payloadStart)) as! [String: Any]
    update(&dictionary)
    let replacement = try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    var bytes = Data(original.prefix(8))
    var length = UInt64(replacement.count).littleEndian
    withUnsafeBytes(of: &length) { bytes.append(contentsOf: $0) }
    bytes.append(replacement)
    bytes.append(original[payloadStart...])
    return validDigest(bytes)
}
func changedValue<T>(_ value: T, at offset: Int) -> Data {
    var bytes = original
    var copy = value
    withUnsafeBytes(of: &copy) { bytes.replaceSubrange(offset..<(offset + $0.count), with: $0) }
    return validDigest(bytes)
}
expect(CollisionWorld.loadCache(from: directory.appendingPathComponent("missing.bin"), cacheKey: key, detailedPickingRegions: regions) == nil, "Missing cache is a miss")
expect(CollisionWorld.loadCache(from: cacheURL, cacheKey: "different-executable:chicago", detailedPickingRegions: regions) == nil, "Executable/world identity changes invalidate cache")
expect(CollisionWorld.loadCache(from: cacheURL, cacheKey: key, detailedPickingRegions: []) == nil, "Changed picking region selection invalidates cache")
let moved = [CollisionWorld.PickingRegion(minimum: regions[0].minimum + V(0.01, 0, 0), maximum: regions[0].maximum)]
expect(CollisionWorld.loadCache(from: cacheURL, cacheKey: key, detailedPickingRegions: moved) == nil, "A changed picking region bound invalidates cache")
expect(CollisionWorld.loadCache(from: cacheURL, cacheKey: key, detailedPickingRegions: regions, expectedSceneTriangleCount: scene.triangleCount + 1) == nil, "Changed source triangle count invalidates cache")
for length in [0, 1, 7, 8, 15, 16, 31, 47, payloadStart - 1, payloadStart, original.count - 33, original.count - 1] {
    try rejects(Data(original.prefix(length)), "Truncation at byte \(length) is a safe miss")
}
var bitFlip = original
bitFlip[payloadStart + 6] ^= 0x80
try rejects(bitFlip, "Payload corruption is detected by checksum")
var badDigest = original
badDigest[badDigest.count - 1] ^= 1
try rejects(badDigest, "Checksum corruption is a miss")
var trailing = original
trailing.append(0)
try rejects(trailing, "Trailing data is rejected")
try rejects(try changeHeader { $0["version"] = 99 }, "Future cache format is a miss")
try rejects(try changeHeader { $0["triangleStride"] = 36 }, "Changed triangle ABI is a miss")
try rejects(try changeHeader { $0["nodeStride"] = 48 }, "Changed node ABI is a miss")
try rejects(try changeHeader { $0["intWidth"] = 32 }, "Changed integer ABI is a miss")
try rejects(try changeHeader { $0["navigationTriangles"] = Int.max }, "Oversized allocation claims are rejected before allocation")
try rejects(try changeHeader { $0["navigationNodes"] = -1 }, "Negative array counts are rejected")
try rejects(try changeHeader { $0["sourceTriangles"] = 0 }, "Impossible source triangle count is rejected")
try rejects(changedValue(Float.nan, at: payloadStart), "NaN triangle coordinates are rejected even with a valid checksum")
try rejects(changedValue(Float.nan, at: nodesStart), "NaN bounds are rejected even with a valid checksum")
let leftOffset = MemoryLayout<CollisionWorld.Node>.offset(of: \.left)!
let rightOffset = MemoryLayout<CollisionWorld.Node>.offset(of: \.right)!
let startOffset = MemoryLayout<CollisionWorld.Node>.offset(of: \.start)!
let countOffset = MemoryLayout<CollisionWorld.Node>.offset(of: \.count)!
try rejects(changedValue(0, at: nodesStart + leftOffset), "Cyclic child index is rejected")
try rejects(changedValue(world.nodes.count, at: nodesStart + rightOffset), "Out-of-range child index is rejected")
try rejects(changedValue(world.nodes[0].left, at: nodesStart + rightOffset), "A shared child is rejected")
let leaf = world.nodes.firstIndex { $0.count > 0 }!
try rejects(changedValue(Int.max, at: nodesStart + leaf * MemoryLayout<CollisionWorld.Node>.stride + countOffset), "Overflowing leaf range is rejected")
try rejects(changedValue(-1, at: nodesStart + leaf * MemoryLayout<CollisionWorld.Node>.stride + startOffset), "Negative leaf start is rejected")
try rejects(changedValue(1, at: nodesStart + leaf * MemoryLayout<CollisionWorld.Node>.stride + startOffset), "Overlapping or omitted leaf range is rejected")
try rejects(changedValue(Float(0), at: nodesStart), "Parent bounds that exclude descendants are rejected")
do {
    try world.writeCache(to: cacheURL, cacheKey: key, detailedPickingRegions: [])
    expect(false, "Writer must reject mismatched fine-picking regions")
} catch { expect(true, "Writer rejects mismatched fine-picking regions") }
expect(CollisionWorld.loadCache(from: cacheURL, cacheKey: key, detailedPickingRegions: regions) != nil, "A rejected replacement preserves the previous valid cache")
try world.writeCache(to: cacheURL, cacheKey: key, detailedPickingRegions: regions)
expect(CollisionWorld.loadCache(from: cacheURL, cacheKey: key, detailedPickingRegions: regions) != nil, "Atomic replacement preserves a valid cache")
let directoryDestination = directory.appendingPathComponent("not-a-file")
try FileManager.default.createDirectory(at: directoryDestination, withIntermediateDirectories: true)
do {
    try world.writeCache(to: directoryDestination, cacheKey: key, detailedPickingRegions: regions)
    expect(false, "An invalid disk destination must report write failure")
} catch { expect(true, "An invalid disk destination reports failure without touching the in-memory BVH") }
expect(world.nodes.count == restored.nodes.count, "Write failure leaves in-memory navigation intact")
let remainingFiles = try FileManager.default.contentsOfDirectory(atPath: directory.path)
expect(remainingFiles.allSatisfy { !$0.hasSuffix(".tmp") }, "Successful/rejected writes leave no temporary payload")
let emptyURL = directory.appendingPathComponent("empty.bin")
let empty = CollisionWorld(scene: SceneData())
try empty.writeCache(to: emptyURL, cacheKey: "empty")
let loadedEmpty = CollisionWorld.loadCache(from: emptyURL, cacheKey: "empty", expectedSceneTriangleCount: 0)
expect(loadedEmpty != nil && loadedEmpty!.triangles.isEmpty && loadedEmpty!.nodes.isEmpty, "An empty world round trips")
expect(loadedEmpty?.distance(origin: .zero, direction: V(0, 0, -1), maximum: 10) == nil, "Empty cached world is a safe query miss")
var onlyFineScene = SceneData()
onlyFineScene.vertices = [SceneVertex(V(0, 3, -5), V(0, 0, 1)), SceneVertex(V(0.04, 3, -5), V(0, 0, 1)), SceneVertex(V(0.02, 3.04, -5), V(0, 0, 1))]
let onlyFine = CollisionWorld(scene: onlyFineScene, detailedPickingRegions: regions)
let onlyFineURL = directory.appendingPathComponent("only-fine.bin")
try onlyFine.writeCache(to: onlyFineURL, cacheKey: "fine", detailedPickingRegions: regions)
let fineRestored = CollisionWorld.loadCache(from: onlyFineURL, cacheKey: "fine", detailedPickingRegions: regions)
expect(fineRestored != nil && fineRestored!.triangles.isEmpty && fineRestored!.detailedPickingTriangleCount == 1, "Fine-only picking index round trips without ordinary geometry")
expect(fineRestored?.distance(origin: V(0.02, 3.01, 0), direction: V(0, 0, -1), maximum: 10) == nil, "Fine geometry stays excluded from movement")
expect(fineRestored?.pickingDistance(origin: V(0.02, 3.01, 0), direction: V(0, 0, -1), maximum: 10) == 5, "Fine geometry remains selectable after loading")
#endif

let report: [String: Any] = ["passed": failures.isEmpty, "checks": checks, "failures": failures, "metrics": metrics,
    "scope": "CPU collision BVH cache round trip, exact triangles and nodes, navigation/picking/movement query equivalence; small fixture additionally validates stale, corrupt and structurally invalid cache rejection."]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]))
print("")
if !failures.isEmpty { exit(1) }
