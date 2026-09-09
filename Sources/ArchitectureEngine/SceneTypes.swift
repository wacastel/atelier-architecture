import Foundation
import simd

// GPU ABI: every field occupies 16 bytes. Unindexed triangles, three vertices each.
struct SceneVertex {
    var position: SIMD4<Float>
    var normal: SIMD4<Float>
    init(_ p: SIMD3<Float>, _ n: SIMD3<Float>) { position = SIMD4(p, 1); normal = SIMD4(n, 0) }
}
struct SceneMaterial {
    var albedo: SIMD4<Float> // rgb linear base color, w roughness
    var properties: SIMD4<Float> // x metallic, y emission, z pattern, w thin-sheet transmission (0 = opaque)
    init(_ color: SIMD3<Float>, roughness: Float = 0.6, metallic: Float = 0, emission: Float = 0, pattern: Float = 0, transmission: Float = 0) {
        albedo = SIMD4(color, roughness); properties = SIMD4(metallic, emission, pattern, transmission)
    }
}
struct SceneData {
    var vertices: [SceneVertex] = []
    var materialIndices: [UInt32] = [] // one per triangle
    var materials: [SceneMaterial] = []
    var lights: [SceneLight] = []
    var trafficLanes: [SceneTrafficLane] = []
    var detailCount: Int = 0
    var name: String = "Eiffel Tower"
    var triangleCount: Int { vertices.count / 3 }
}
/// Road-centre paths in travel order; the surface builder supplies the same grade.
/// Kept dependency-free so geometry/CPU validation can still import SceneTypes alone.
struct SceneTrafficLane {
    var id: Int64
    var points: [SIMD3<Float>]
    var speedMetresPerSecond: Float
    var spawnFadeMetres: Float
}
// GPU light ABI: metres, linear RGB and luminous intensity in renderer units.
struct SceneLight {
    var positionRadius: SIMD4<Float>
    var directionCone: SIMD4<Float>
    var colorPower: SIMD4<Float>
    var parameters: SIMD4<Float>
}
struct TemporalUniforms {
    var previousOrigin: SIMD4<Float>
    var previousRight: SIMD4<Float>
    var previousUp: SIMD4<Float>
    var previousForward: SIMD4<Float>
    var currentOrigin: SIMD4<Float>
    var sizeFlags: SIMD4<UInt32>
    var settings: SIMD4<Float>
}
struct CameraPose {
    var position: SIMD3<Float>
    var target: SIMD3<Float>
    var fov: Float = 52
}
struct TourStop: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let detail: String
    let pose: CameraPose
}

/// Compact surface-selection volumes for presentation only. A selected surface
/// is tinted after reconstruction, so selection never enters lighting/history.
/// Points are X/Z polygon vertices or triples preserving triangulated holes.
struct FocusHighlightVolume {
    var minimum: SIMD3<Float>
    var maximum: SIMD3<Float>
    var points: [SIMD2<Float>] = []
    var triangulated: Bool = false
}
struct FocusHighlightData: Equatable {
    let packed: [SIMD4<Float>]
    init(volumes: [FocusHighlightVolume]) {
        var data = [SIMD4<Float>.zero]
        var count = 0
        for volume in volumes {
            let lo=volume.minimum,hi=volume.maximum
            guard lo.x.isFinite,lo.y.isFinite,lo.z.isFinite,hi.x.isFinite,hi.y.isFinite,hi.z.isFinite,
                  lo.x<=hi.x,lo.y<=hi.y,lo.z<=hi.z,volume.points.count<=65_536,
                  volume.points.allSatisfy({$0.x.isFinite && $0.y.isFinite}),
                  volume.points.isEmpty || (volume.points.count>=3 && (!volume.triangulated || volume.points.count%3==0)) else { continue }
            data.append(SIMD4(lo,Float(volume.points.count)))
            data.append(SIMD4(hi,volume.points.isEmpty ? 0:volume.triangulated ? 2:1))
            data += volume.points.map { SIMD4($0.x,$0.y,0,0) }
            count += 1
        }
        data[0].x=Float(count); packed=data
    }
    var isEmpty: Bool { packed[0].x==0 }
}
struct FrameUniforms {
    var origin: SIMD4<Float> // camera XYZ, selective path regularization enabled W
    var right: SIMD4<Float>
    var up: SIMD4<Float> // camera up XYZ, low-discrepancy sampling enabled W
    var forward: SIMD4<Float>
    var sunDirection: SIMD4<Float>
    var sunColor: SIMD4<Float>
    var viewport: SIMD4<UInt32> // width, height, accumulated frames, global frame seed
    var settings: SIMD4<Float> // exposure, maximum bounces, sun angular radius, sky intensity
    var animation: SIMD4<Float> = .zero // bounded show seconds, show moving, sunset, optional haze density
}
