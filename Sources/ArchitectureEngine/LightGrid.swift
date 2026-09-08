import Foundation
import simd

/// Conservative lists of finite-range lights. Indices retain scene order so
/// skipping lights outside their support does not change reservoir sampling.
struct LightGrid {
    // Metal ABI: three 16-byte vectors; uint2 ranges are offset/count pairs.
    struct Header {
        var originCellSize: SIMD4<Float>
        var dimensions: SIMD4<UInt32> // xyz dimensions, w enabled
        var counts: SIMD4<UInt32> // cells, indices, original lights, reserved
    }

    private(set) var header: Header
    private(set) var ranges: [SIMD2<UInt32>] = []
    private(set) var indices: [UInt32] = []
    private(set) var fallbackReason: String?
    var enabled: Bool { header.dimensions.w != 0 }
    var origin: SIMD3<Float> { SIMD3(header.originCellSize.x, header.originCellSize.y, header.originCellSize.z) }
    var cellSize: Float { header.originCellSize.w }
    var dimensions: SIMD3<UInt32> { SIMD3(header.dimensions.x, header.dimensions.y, header.dimensions.z) }

    init(lights: [SceneLight], cellSize: Float = 64,
         maxCellCount: Int = 262_144, maxIndexCount: Int = 4_194_304) {
        header = Header(originCellSize: SIMD4(0, 0, 0, cellSize), dimensions: .zero,
                        counts: SIMD4(0, 0, UInt32(clamping: lights.count), 0))
        // A disabled grid uses the existing linear kernels. Never partially
        // index invalid inputs or truncate a light list to satisfy a budget.
        fallbackReason = "empty light set"
        guard !lights.isEmpty else { return }
        fallbackReason = "invalid cell size or memory budget"
        guard cellSize.isFinite, cellSize > 0, maxCellCount > 0, maxIndexCount > 0,
              maxCellCount <= Int(UInt32.max), maxIndexCount <= Int(UInt32.max) else { return }
        fallbackReason = "light count exceeds index budget"
        guard lights.count <= maxIndexCount, lights.count <= Int(UInt32.max) else { return }

        var bounds: [(lo: SIMD3<Float>, hi: SIMD3<Float>)] = []
        bounds.reserveCapacity(lights.count)
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        for light in lights {
            let p = SIMD3(light.positionRadius.x, light.positionRadius.y, light.positionRadius.z)
            fallbackReason = "nonfinite light position or range"
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite, light.parameters.x.isFinite else { return }
            let radius = max(light.parameters.x, 0.1) // evaluateLight's finite support
            var a = SIMD3<Float>.zero, b = SIMD3<Float>.zero
            for axis in 0..<3 {
                // Outward padding covers Float subtraction, dot-product and
                // cell-division rounding at support and grid boundaries.
                let scale = max(abs(p[axis]), radius, cellSize)
                let margin = max(Double(0.001), Double(scale) * Double(Float.ulpOfOne) * 8)
                a[axis] = Float(Double(p[axis]) - Double(radius) - margin).nextDown
                b[axis] = Float(Double(p[axis]) + Double(radius) + margin).nextUp
                fallbackReason = "light support exceeds finite Float coordinates"
                guard a[axis].isFinite, b[axis].isFinite else { return }
            }
            bounds.append((a, b))
            lo = simd_min(lo, a); hi = simd_max(hi, b)
        }

        // A small light near zero may still be millions of metres from the
        // grid origin. Include that subtraction/division precision in every
        // support, including Metal's permitted arithmetic rounding.
        var worldMargin = SIMD3<Float>.zero
        for axis in 0..<3 {
            let scale = max(abs(Double(lo[axis])), abs(Double(hi[axis])), Double(hi[axis]) - Double(lo[axis]))
            worldMargin[axis] = Float(scale * Double(Float.ulpOfOne) * 8)
        }
        lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude); hi = -lo
        for index in bounds.indices {
            for axis in 0..<3 {
                bounds[index].lo[axis] = (bounds[index].lo[axis] - worldMargin[axis]).nextDown
                bounds[index].hi[axis] = (bounds[index].hi[axis] + worldMargin[axis]).nextUp
                fallbackReason = "padded light support exceeds finite Float coordinates"
                guard bounds[index].lo[axis].isFinite, bounds[index].hi[axis].isFinite else { return }
            }
            lo = simd_min(lo, bounds[index].lo); hi = simd_max(hi, bounds[index].hi)
        }

        var size = SIMD3<Int>.zero
        var cellCount = 1
        for axis in 0..<3 {
            let lastCell = floor((hi[axis] - lo[axis]) / cellSize)
            fallbackReason = "grid dimensions exceed cell budget"
            guard lastCell.isFinite, lastCell >= 0, Double(lastCell) < Double(maxCellCount) else { return }
            size[axis] = Int(lastCell) + 1
            guard size[axis] <= maxCellCount / cellCount else { return }
            cellCount *= size[axis]
        }

        var cellBounds: [(lo: SIMD3<Int>, hi: SIMD3<Int>)] = []
        cellBounds.reserveCapacity(lights.count)
        var indexCount = 0
        for bound in bounds {
            var a = SIMD3<Int>.zero, b = SIMD3<Int>.zero
            var coveredCells = 1
            for axis in 0..<3 {
                // Same Float expression as the shader's point lookup. The
                // monotone mapping and expanded bounds include edge cells.
                a[axis] = max(0, min(size[axis] - 1, Int(floor((bound.lo[axis] - lo[axis]) / cellSize))))
                b[axis] = max(0, min(size[axis] - 1, Int(floor((bound.hi[axis] - lo[axis]) / cellSize))))
                let extent = b[axis] - a[axis] + 1
                fallbackReason = "light lists exceed index budget"
                guard extent <= (maxIndexCount - indexCount) / coveredCells else { return }
                coveredCells *= extent
            }
            indexCount += coveredCells
            cellBounds.append((a, b))
        }

        let nx = size.x, ny = size.y
        func visit(_ bound: (lo: SIMD3<Int>, hi: SIMD3<Int>), _ body: (Int) -> Void) {
            for z in bound.lo.z...bound.hi.z {
                for y in bound.lo.y...bound.hi.y {
                    let row = (z * ny + y) * nx
                    for x in bound.lo.x...bound.hi.x { body(row + x) }
                }
            }
        }
        var counts = [UInt32](repeating: 0, count: cellCount)
        for bound in cellBounds { visit(bound) { counts[$0] += 1 } }
        ranges = [SIMD2<UInt32>](repeating: .zero, count: cellCount)
        var offset: UInt32 = 0
        for cell in 0..<cellCount {
            ranges[cell] = SIMD2(offset, counts[cell])
            offset += counts[cell]
        }
        indices = [UInt32](repeating: 0, count: indexCount)
        var cursors = ranges.map(\.x)
        for (index, bound) in cellBounds.enumerated() {
            visit(bound) { cell in
                indices[Int(cursors[cell])] = UInt32(index)
                cursors[cell] += 1
            }
        }
        header = Header(originCellSize: SIMD4(lo, cellSize),
                        dimensions: SIMD4(UInt32(size.x), UInt32(size.y), UInt32(size.z), 1),
                        counts: SIMD4(UInt32(cellCount), UInt32(indexCount), UInt32(lights.count), 0))
        fallbackReason = nil
    }

    /// CPU counterpart of Metal's lookup, useful for diagnostics and coverage
    /// tests. An enabled grid has no contributing lights outside these bounds.
    func cellIndex(at point: SIMD3<Float>) -> Int? {
        guard enabled, point.x.isFinite, point.y.isFinite, point.z.isFinite else { return nil }
        let q = (point - origin) / cellSize
        guard q.x >= 0, q.y >= 0, q.z >= 0,
              q.x < Float(dimensions.x), q.y < Float(dimensions.y), q.z < Float(dimensions.z) else { return nil }
        let x = Int(floor(q.x)), y = Int(floor(q.y)), z = Int(floor(q.z))
        return (z * Int(dimensions.y) + y) * Int(dimensions.x) + x
    }
}
