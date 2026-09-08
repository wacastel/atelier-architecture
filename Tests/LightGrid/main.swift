import Foundation
import simd

func light(_ p: SIMD3<Float>, _ range: Float) -> SceneLight {
    SceneLight(positionRadius: SIMD4(p, 0.5), directionCone: SIMD4(0, -1, 0, -1),
               colorPower: SIMD4(1, 0.8, 0.6, 100), parameters: SIMD4(range, 1, 0, 0))
}
func candidates(_ grid: LightGrid, _ point: SIMD3<Float>) -> [UInt32] {
    guard let cell = grid.cellIndex(at: point) else { return [] }
    let pair = grid.ranges[cell]
    return Array(grid.indices[Int(pair.x)..<Int(pair.x + pair.y)])
}
// Independent finite-support oracle from evaluateLight, before normals/cones.
func canContribute(_ source: SceneLight, _ point: SIMD3<Float>) -> Bool {
    let delta = SIMD3(source.positionRadius.x, source.positionRadius.y, source.positionRadius.z) - point
    let distanceSquared = simd_dot(delta, delta)
    let radius = max(source.parameters.x, 0.1)
    return distanceSquared < radius * radius && distanceSquared >= 1e-7
}
var testedPoints = 0
var visitedCandidates = 0
func check(_ grid: LightGrid, _ lights: [SceneLight], _ point: SIMD3<Float>) {
    precondition(grid.enabled)
    let list = candidates(grid, point)
    precondition(list == list.sorted() && Set(list).count == list.count, "Noncanonical original light order")
    let full = lights.indices.filter { canContribute(lights[$0], point) }.map(UInt32.init)
    let indexed = list.filter { canContribute(lights[Int($0)], point) }
    precondition(full == indexed, "Dropped light at \(point): expected \(full), indexed \(indexed)")
    // A day-only buffer may use a compact subset; also verify every prefix's
    // reservoir visitation sequence when hosts impose an active-light count.
    for count in [0, 1, lights.count / 2, lights.count] {
        precondition(full.filter { $0 < count } == indexed.filter { $0 < count })
    }
    testedPoints += 1; visitedCandidates += list.count
}
func validateStorage(_ grid: LightGrid, _ lights: [SceneLight]) {
    precondition(grid.enabled && grid.fallbackReason == nil)
    precondition(Int(grid.header.counts.x) == grid.ranges.count)
    precondition(Int(grid.header.counts.y) == grid.indices.count)
    precondition(Int(grid.header.counts.z) == lights.count)
    var offset: UInt32 = 0
    for pair in grid.ranges {
        precondition(pair.x == offset && UInt64(pair.x) + UInt64(pair.y) <= grid.indices.count)
        let ids = Array(grid.indices[Int(pair.x)..<Int(pair.x + pair.y)])
        precondition(ids == ids.sorted() && Set(ids).count == ids.count)
        precondition(ids.allSatisfy { $0 < lights.count })
        offset += pair.y
    }
    precondition(Int(offset) == grid.indices.count)
}
func disabled(_ lights: [SceneLight], _ size: Float = 64, cells: Int = 262_144, ids: Int = 4_194_304) {
    let grid = LightGrid(lights: lights, cellSize: size, maxCellCount: cells, maxIndexCount: ids)
    precondition(!grid.enabled && grid.fallbackReason != nil && grid.ranges.isEmpty && grid.indices.isEmpty)
    precondition(grid.header.dimensions == .zero && grid.cellIndex(at: .zero) == nil)
}

precondition(MemoryLayout<LightGrid.Header>.size == 48 && MemoryLayout<LightGrid.Header>.stride == 48)
precondition(MemoryLayout<LightGrid.Header>.alignment == 16)
precondition(MemoryLayout<LightGrid.Header>.offset(of: \.originCellSize) == 0)
precondition(MemoryLayout<LightGrid.Header>.offset(of: \.dimensions) == 16)
precondition(MemoryLayout<LightGrid.Header>.offset(of: \.counts) == 32)
precondition(MemoryLayout<SIMD2<UInt32>>.stride == 8)

let special = [light(SIMD3(-64, -64, -64), 64), light(SIMD3(64, 0, 64), 1),
               light(SIMD3(64, 0, 64), 1), light(.zero, -10), light(SIMD3(-0.1, 0.1, 0), 0)]
for size: Float in [0.5, 7, 64, 128] {
    let grid = LightGrid(lights: special, cellSize: size)
    // The half-metre variant deliberately exceeds the bounded dense volume.
    if size == 0.5 { precondition(!grid.enabled); continue }
    validateStorage(grid, special)
    check(grid, special, grid.origin)
    for source in special {
        let center = SIMD3(source.positionRadius.x, source.positionRadius.y, source.positionRadius.z)
        check(grid, special, center)
        for axis in 0..<3 {
            for sign: Float in [-1, 1] {
                var point = center
                point[axis] += sign * max(source.parameters.x, 0.1)
                check(grid, special, point)
                point[axis] = point[axis].nextDown; check(grid, special, point)
                point[axis] = point[axis].nextUp.nextUp; check(grid, special, point)
            }
        }
    }
    // Probe immediately on both sides of every plane along each grid axis,
    // including its outer boundary, using points near the overlapping lights.
    for axis in 0..<3 {
        for plane in 0...Int(grid.dimensions[axis]) {
            for anchor in [SIMD3<Float>(-64, -64, -64), SIMD3(64, 0, 64), .zero] {
                var point = anchor
                point[axis] = grid.origin[axis] + Float(plane) * size
                check(grid, special, point)
                point[axis] = point[axis].nextDown; check(grid, special, point)
                point[axis] = point[axis].nextUp.nextUp; check(grid, special, point)
            }
        }
    }
    precondition(grid.cellIndex(at: SIMD3(.nan, 0, 0)) == nil)
    precondition(grid.cellIndex(at: SIMD3(.infinity, 0, 0)) == nil)
    check(grid, special, SIMD3(100_000, -100_000, 100_000))
}

struct Random {
    var state: UInt64 = 0x1a37_9254_009e_d852
    mutating func value(_ lo: Float, _ hi: Float) -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = Float(UInt32(truncatingIfNeeded: state >> 32)) / Float(UInt32.max)
        return lo + (hi - lo) * unit
    }
}
var random = Random()
var city: [SceneLight] = []
for _ in 0..<360 {
    city.append(light(SIMD3(random.value(-1300, 1300), random.value(0, 430), random.value(-1300, 1300)), random.value(0.1, 230)))
}
let started = Date()
let cityGrid = LightGrid(lights: city)
let constructionSeconds = Date().timeIntervalSince(started)
validateStorage(cityGrid, city)
let initialCandidates = visitedCandidates, initialPoints = testedPoints
for _ in 0..<20_000 {
    check(cityGrid, city, SIMD3(random.value(-1600, 1600), random.value(-100, 530), random.value(-1600, 1600)))
}
// Concentrate additional queries near each light's actual support, including
// near-tangent directions where roundoff can otherwise erase a contributor.
for source in city {
    let center = SIMD3(source.positionRadius.x, source.positionRadius.y, source.positionRadius.z)
    for _ in 0..<20 {
        let direction = simd_normalize(SIMD3(random.value(-1, 1), random.value(-1, 1), random.value(-1, 1)))
        for fraction: Float in [0.9999998, 1, 1.0000002] {
            check(cityGrid, city, center + direction * source.parameters.x * fraction)
        }
    }
}
let cityAverageCandidates = Double(visitedCandidates - initialCandidates) / Double(testedPoints - initialPoints)
// Small supports at moderately large coordinates stress Float spacing without
// requiring a huge world grid. Finite-but-unindexable inputs must fall back.
for offset: Float in [-1_000_000, 1_000_000] {
    let sources = [light(SIMD3(offset, offset, offset), 0.1), light(SIMD3(offset + 0.5, offset, offset), 3)]
    let grid = LightGrid(lights: sources)
    validateStorage(grid, sources)
    for step in -64...64 {
        check(grid, sources, SIMD3(offset + Float(step) * 0.0625, offset, offset))
    }
}
for offset: Float in [-1_000_000, 1_000_000] {
    let sources = [light(SIMD3(offset, 0, 0), 0.1), light(SIMD3(0.03, 0, 0), 0.1)]
    let grid = LightGrid(lights: sources)
    validateStorage(grid, sources)
    for step in -200...200 {
        check(grid, sources, SIMD3(Float(step) * 0.001, 0, 0))
    }
}

disabled([])
for size: Float in [0, -64, .nan, .infinity, Float.leastNonzeroMagnitude] { disabled(special, size) }
for value: Float in [.nan, .infinity, -.infinity] {
    disabled([light(SIMD3(value, 0, 0), 1)])
    disabled([light(.zero, value)])
}
disabled([light(SIMD3(Float.greatestFiniteMagnitude, 0, 0), 1)])
disabled([light(.zero, Float.greatestFiniteMagnitude)])
disabled([light(SIMD3(1e30, 1e30, 1e30), 1)])
disabled([light(SIMD3(-1e10, 0, 0), 1), light(SIMD3(1e10, 0, 0), 1)])
disabled(special, cells: 1)
disabled(special, cells: 0)
disabled(special, ids: 1)
disabled(special, ids: 0)
disabled([light(.zero, 100), light(.zero, 100)], ids: 80)

print("PASS: \(testedPoints) finite support/order queries; negative coordinates, cell planes, tangent supports, empty/outside/nonfinite and bounded-memory fallbacks")
print("PASS: 48-byte Metal header / 8-byte ranges; sorted unique original IDs and complete active-prefix visitation")
print("Synthetic 360-light city: \(cityGrid.ranges.count) cells, \(cityGrid.indices.count) indices, \(String(format: "%.3f", constructionSeconds * 1000)) ms build; mean \(String(format: "%.2f", cityAverageCandidates)) candidate IDs per tested point")
