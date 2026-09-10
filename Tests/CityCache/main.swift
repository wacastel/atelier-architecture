import Foundation
import CryptoKit
import simd

typealias V = SIMD3<Float>
var checks = 0
var failures: [String] = []
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures.append(message) }
}
func bytes<T>(_ array: [T]) -> Data { array.withUnsafeBytes { Data($0) } }
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("atelier-city-cache-test-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
let url = directory.appendingPathComponent("scene.bin")
let damagedURL = directory.appendingPathComponent("damaged.bin")
let key = String(repeating: "b", count: 64) + ":chicago"
var scene = SceneData()
scene.name = "Chicago · Museum, lakefront & château 🏙"
scene.detailCount = 1910
scene.vertices = [
    SceneVertex(V(-0.0, 0.25, -10), V(0, 0, 1)), SceneVertex(V(10, 0.25, -10), V(0, 0, 1)), SceneVertex(V(0, 10.25, -10), V(0, 0, 1)),
    SceneVertex(V(-4.25, -0.0, 12), V(0, 1, 0)), SceneVertex(V(2, 0, 12), V(0, 1, 0)), SceneVertex(V(2, 0, 8), V(0, 1, 0))
]
scene.materialIndices = [0, 1]
scene.materials = [SceneMaterial(V(0.25, 0.5, 0.75), roughness: 0.03125, metallic: 1, emission: 2.5, pattern: 15, transmission: 0.75),
                   SceneMaterial(V(0.7, 0.6, 0.5), roughness: 0.625, metallic: 0, emission: 0, pattern: 0, transmission: 0)]
scene.lights = [SceneLight(positionRadius: SIMD4(10, 20, -30, 0.2), directionCone: SIMD4(0, -1, 0, 0.707),
                         colorPower: SIMD4(1, 0.8, 0.4, 150), parameters: SIMD4(1, 0.25, 0, 3)),
                SceneLight(positionRadius: SIMD4(-0.0, 2.5, 3.75, 0.001), directionCone: SIMD4(1, 0, 0, 1),
                         colorPower: SIMD4(0.2, 0.5, 1, 400), parameters: SIMD4(0, 0, 1, 0))]
scene.trafficLanes = [
    SceneTrafficLane(id: Int64.min, points: [V(-0.0, 0, -5), V(1.0 / 3.0, 0.125, -4), V(Float.leastNonzeroMagnitude, 1.5, Float.greatestFiniteMagnitude)], speedMetresPerSecond: 12.5, spawnFadeMetres: 17.125),
    SceneTrafficLane(id: Int64.max, points: [V(-1234.567, 3.125, 2345.678), V(654.321, 4.375, -321.654)], speedMetresPerSecond: 22.22222, spawnFadeMetres: 36.666668)
]
try CityCache.writeScene(scene, to: url, key: key)
let restored = CityCache.loadScene(from: url, key: key)
expect(restored != nil, "Matching cache loads")
if let restored {
    expect(bytes(restored.vertices) == bytes(scene.vertices), "Every vertex/normal byte survives round trip")
    expect(bytes(restored.materialIndices) == bytes(scene.materialIndices), "Every material index byte survives round trip")
    expect(bytes(restored.materials) == bytes(scene.materials), "Every material byte survives round trip")
    expect(bytes(restored.lights) == bytes(scene.lights), "Every static light byte survives round trip")
    expect(restored.name == scene.name && restored.detailCount == scene.detailCount, "Scene name and detail count survive round trip")
    expect(restored.trafficLanes.count == scene.trafficLanes.count, "All traffic lanes survive round trip")
    for (index, pair) in zip(scene.trafficLanes, restored.trafficLanes).enumerated() {
        let (a, b) = pair
        expect(a.id == b.id, "Lane \(index) retains full-width signed identity")
        expect(a.speedMetresPerSecond.bitPattern == b.speedMetresPerSecond.bitPattern && a.spawnFadeMetres.bitPattern == b.spawnFadeMetres.bitPattern,
               "Lane \(index) retains exact speed/fade Float values")
        expect(a.points.count == b.points.count && zip(a.points, b.points).allSatisfy { p, q in
            p.x.bitPattern == q.x.bitPattern && p.y.bitPattern == q.y.bitPattern && p.z.bitPattern == q.z.bitPattern
        }, "Lane \(index) retains exact coordinate Float bit patterns")
    }
}
let original = try Data(contentsOf: url)
let headerLength = original.withUnsafeBytes { Int($0.loadUnaligned(fromByteOffset: 8, as: UInt64.self).littleEndian) }
let payloadStart = (16 + headerLength + 63) / 64 * 64
expect(payloadStart % 64 == 0, "Scene payload begins at the documented 64-byte boundary")
expect(original[payloadStart..<(payloadStart + scene.vertices.count * MemoryLayout<SceneVertex>.stride)] == bytes(scene.vertices), "Payload layout begins with exact vertices")
func digest(_ source: Data) -> Data {
    var output = Data(source.dropLast(32))
    output.append(contentsOf: SHA256.hash(data: output))
    return output
}
func rejects(_ data: Data, _ message: String) throws {
    try data.write(to: damagedURL)
    expect(CityCache.loadScene(from: damagedURL, key: key) == nil, message)
}
func changeHeader(_ mutate: (inout [String: Any]) -> Void) throws -> Data {
    var header = try JSONSerialization.jsonObject(with: original.subdata(in: 16..<(16 + headerLength))) as! [String: Any]
    mutate(&header)
    let metadata = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
    var data = Data(original.prefix(8)), count = UInt64(metadata.count).littleEndian
    withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
    data.append(metadata)
    data.append(Data(repeating: 0, count: ((data.count + 63) / 64 * 64) - data.count))
    data.append(original[payloadStart...])
    return digest(data)
}
func replaceValue<T>(_ value: T, at offset: Int) -> Data {
    var data = original, copy = value
    withUnsafeBytes(of: &copy) { data.replaceSubrange(offset..<(offset + $0.count), with: $0) }
    return digest(data)
}
expect(CityCache.loadScene(from: directory.appendingPathComponent("missing.bin"), key: key) == nil, "Missing file is a miss")
expect(CityCache.loadScene(from: url, key: "different-executable:chicago") == nil, "Executable/resource identity change invalidates cache")
expect(CityCache.loadScene(from: url, key: String(repeating: "b", count: 64) + ":paris") == nil, "World identity change invalidates cache")
for length in [0, 1, 7, 8, 15, 16, 31, 47, 48, 16 + headerLength - 1, payloadStart, original.count - 33, original.count - 1] {
    try rejects(Data(original.prefix(length)), "Truncation at byte \(length) is a safe miss")
}
var badMagic = original; badMagic[0] ^= 1
try rejects(badMagic, "Invalid magic is rejected")
var corruptPayload = original; corruptPayload[payloadStart + 1] ^= 0x40
try rejects(corruptPayload, "Payload bit corruption is rejected")
var corruptDigest = original; corruptDigest[corruptDigest.count - 1] ^= 0x40
try rejects(corruptDigest, "Checksum corruption is rejected")
var trailing = original; trailing.append(0)
try rejects(trailing, "Unexpected trailing bytes are rejected")
for count: UInt64 in [0, 32 * 1024 * 1024, UInt64.max] {
    try rejects(replaceValue(count.littleEndian, at: 8), "Metadata length \(count) is rejected without integer overflow")
}
try rejects(try changeHeader { $0["version"] = 999 }, "A future format version is a miss")
try rejects(try changeHeader { $0["strides"] = [16, 4, 32, 64] }, "A changed vertex ABI is a miss")
try rejects(try changeHeader { $0["strides"] = [32, 8, 32, 64] }, "A changed index ABI is a miss")
try rejects(try changeHeader { $0["strides"] = [32, 4, 16, 64] }, "A changed material ABI is a miss")
try rejects(try changeHeader { $0["strides"] = [32, 4, 32, 32] }, "A changed light ABI is a miss")
for name in ["vertices", "indices", "materials", "lights"] {
    try rejects(try changeHeader { $0[name] = -1 }, "Negative \(name) count is rejected")
    try rejects(try changeHeader { $0[name] = Int.max }, "Oversized \(name) count is rejected before allocation")
}
try rejects(try changeHeader { $0["vertices"] = 4 }, "Incomplete triangle vertices are rejected")
try rejects(try changeHeader { $0["indices"] = 1 }, "Missing triangle material index is rejected")
try rejects(try changeHeader { $0["materials"] = 0 }, "Missing material table is rejected")
try rejects(try changeHeader { $0["detailCount"] = -1 }, "Negative detail metadata is rejected")
try rejects(try changeHeader { $0["vertices"] = "six" }, "Malformed typed header field is rejected")
try rejects(try changeHeader { $0.removeValue(forKey: "name") }, "Missing required metadata is rejected")
let indexStart = payloadStart + scene.vertices.count * MemoryLayout<SceneVertex>.stride
try rejects(replaceValue(UInt32(scene.materials.count), at: indexStart), "Out-of-range material reference is rejected even with valid checksum")
try rejects(replaceValue(UInt32.max, at: indexStart), "Maximum UInt32 material reference is rejected safely")
try rejects(try changeHeader {
    var lanes = $0["lanes"] as! [[String: Any]]
    lanes[0]["points"] = [[1, 2, 3]]
    $0["lanes"] = lanes
}, "Lane with fewer than two points is rejected")
try rejects(try changeHeader {
    var lanes = $0["lanes"] as! [[String: Any]]
    lanes[0]["points"] = [[1, 2], [3, 4]]
    $0["lanes"] = lanes
}, "Lane with malformed point dimensions is rejected")
try rejects(try changeHeader {
    var lanes = $0["lanes"] as! [[String: Any]]
    lanes[0]["speed"] = "NaN"
    $0["lanes"] = lanes
}, "Non-numeric lane speed is rejected")
try rejects(try changeHeader {
    var lanes = $0["lanes"] as! [[String: Any]]
    lanes[0]["points"] = [[1e100, 2, 3], [4, 5, 6]]
    $0["lanes"] = lanes
}, "Lane coordinate overflowing Float is rejected")

var minimum = SceneData()
minimum.vertices = Array(scene.vertices.prefix(3)); minimum.materialIndices = [0]; minimum.materials = [scene.materials[0]]
let minimumURL = directory.appendingPathComponent("minimum.bin")
try CityCache.writeScene(minimum, to: minimumURL, key: "minimum")
let minimalLoaded = CityCache.loadScene(from: minimumURL, key: "minimum")
expect(minimalLoaded?.triangleCount == 1 && minimalLoaded!.lights.isEmpty && minimalLoaded!.trafficLanes.isEmpty, "Minimum geometry and empty optional light/lane arrays load")
let emptyURL = directory.appendingPathComponent("empty.bin")
try CityCache.writeScene(SceneData(), to: emptyURL, key: "empty")
expect(CityCache.loadScene(from: emptyURL, key: "empty") == nil, "Empty geometry is rejected consistently with renderer requirements")
try CityCache.writeScene(scene, to: url, key: key)
expect(CityCache.loadScene(from: url, key: key) != nil, "Atomic replacement yields a complete cache")
let beforeFailedWrite = try Data(contentsOf: url)
var unencodable = scene
unencodable.trafficLanes[0].speedMetresPerSecond = .nan
do { try CityCache.writeScene(unencodable, to: url, key: key); expect(false, "Non-encodable metadata must fail") }
catch { expect(true, "Non-encodable metadata reports a write failure") }
let afterFailedWrite = try Data(contentsOf: url)
expect(afterFailedWrite == beforeFailedWrite, "Failed metadata encoding preserves the previous complete cache")
let directoryDestination = directory.appendingPathComponent("not-a-file")
try FileManager.default.createDirectory(at: directoryDestination, withIntermediateDirectories: true)
do { try CityCache.writeScene(scene, to: directoryDestination, key: key); expect(false, "Writing over a directory must fail") }
catch { expect(true, "Writing over a directory reports failure") }
expect(CityCache.loadScene(from: url, key: key) != nil, "An unrelated failed write preserves the working cache")
let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
expect(remaining.allSatisfy { !$0.hasSuffix(".tmp") }, "Successful and failed writes leave no temporary files")

let report: [String: Any] = ["passed": failures.isEmpty, "checks": checks, "failures": failures,
    "scope": "Minimal CPU scene-cache fixtures: exact vertex/index/material/light bytes and traffic values; stale, truncated, corrupt, malformed, and invalid-index rejection; empty optional arrays; atomic replacement and failed-write preservation."]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]))
print("")
if !failures.isEmpty { exit(1) }
