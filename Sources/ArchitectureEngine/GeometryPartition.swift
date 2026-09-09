import Foundation
import Metal

/// A geometry descriptor's vertex span stays below 4 GiB even when the shared
/// city buffer grows beyond it. Renderer.metal resolves geometry-local IDs
/// using this same fixed triangle count; the last section may be shorter.
enum GeometryPartition {
    static let trianglesPerGeometry = 1 << 24

    static func descriptors(vertexBuffer: MTLBuffer, triangleCount: Int) -> [MTLAccelerationStructureTriangleGeometryDescriptor] {
        precondition(triangleCount > 0 && triangleCount <= Int(UInt32.max))
        return stride(from: 0, to: triangleCount, by: trianglesPerGeometry).map { first in
            let geometry = MTLAccelerationStructureTriangleGeometryDescriptor()
            geometry.vertexBuffer = vertexBuffer
            geometry.vertexBufferOffset = first * 3 * MemoryLayout<SceneVertex>.stride
            geometry.vertexStride = MemoryLayout<SceneVertex>.stride
            geometry.vertexFormat = .float3
            geometry.triangleCount = min(trianglesPerGeometry, triangleCount - first)
            geometry.opaque = true
            return geometry
        }
    }
}
