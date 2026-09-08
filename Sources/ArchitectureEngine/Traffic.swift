import Foundation
import simd

/// Absolute-time, arc-length traffic. No frame delta or random mutable state is
/// involved: scrubbing backward and rendering the same time reproduce each pose.
struct TrafficPath {
    let id: Int64
    let points: [SIMD3<Float>]
    let distances: [Double]
    let speed: Double
    let fade: Double
    var length: Double { distances.last ?? 0 }
    init?(_ lane: SceneTrafficLane) {
        guard lane.speedMetresPerSecond.isFinite, lane.speedMetresPerSecond > 0,
              lane.spawnFadeMetres.isFinite, lane.points.count >= 2,
              lane.points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }) else { return nil }
        var clean = [lane.points[0]], cumulative = [Double(0)]
        for point in lane.points.dropFirst() {
            let distance = Double(simd_distance(point, clean.last!))
            guard distance.isFinite else { return nil }
            if distance > 0.01 {
                let delta=point-clean.last!
                guard simd_length(SIMD2(delta.x,delta.z))>0.01,
                      (cumulative.last!+distance).isFinite else { return nil }
                clean.append(point); cumulative.append(cumulative.last! + distance)
            }
        }
        guard let length = cumulative.last, length > 80 else { return nil }
        id = lane.id; points = clean; distances = cumulative
        speed = Double(lane.speedMetresPerSecond)
        fade = min(length * 0.1, max(12, Double(lane.spawnFadeMetres)))
    }
    func point(at distance: Double) -> SIMD3<Float> {
        let distance = min(length, max(0, distance))
        var low = 0, high = distances.count - 1
        while low + 1 < high {
            let middle = (low + high) / 2
            if distances[middle] <= distance { low = middle } else { high = middle }
        }
        let t = Float((distance - distances[low]) / (distances[high] - distances[low]))
        return points[low] + (points[high] - points[low]) * t
    }
    func transform(distance: Double, wheelbase: Float) -> simd_float4x4 {
        let p = point(at: distance)
        // A wheelbase tangent follows bends continuously rather than snapping
        // to the segment heading at every OpenStreetMap node. Grade is retained.
        let extent = Double(max(2, wheelbase)) * 0.5
        var tangent=point(at: distance + extent) - point(at: distance - extent)
        if simd_length_squared(SIMD2(tangent.x,tangent.z))<0.000001 {
            // A malformed exact hairpin can cancel the symmetric secant. Keep
            // a finite one-sided direction rather than normalizing zero.
            tangent=point(at:min(length,distance+extent))-point(at:max(0,distance))
            if simd_length_squared(SIMD2(tangent.x,tangent.z))<0.000001 { tangent=points[1]-points[0] }
        }
        let forward = simd_normalize(tangent)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0,1,0), forward))
        let up = simd_normalize(simd_cross(forward, right))
        let boundary = min(distance, length - distance)
        let t = Float(min(1, max(0, boundary / fade)))
        // The mapped corridor extends kilometres beyond curated cameras. At its
        // open streaming boundary, smoothly contract vehicles before wrapping;
        // never teleport a full-sized visible body between the two endpoints.
        let scale = max(0.0001, t*t*(3-2*t))
        return simd_float4x4(SIMD4(right*scale,0), SIMD4(up*scale,0), SIMD4(forward*scale,0), SIMD4(p + SIMD3(0,0.025,0),1))
    }
}

struct TrafficVehicle {
    let path: Int
    let phase: Double
    let bus: Bool
    var wheelbase: Float { bus ? 6.3 : 2.75 }
    var halfLength: Float { bus ? 6 : 2.4 }
}

struct TrafficFleet {
    let paths: [TrafficPath]
    let vehicles: [TrafficVehicle]
    let vertices: [SceneVertex]
    let owners: [UInt32]
    let materialIndices: [UInt32]
    let materials: [SceneMaterial]
    var triangleCount: Int { vertices.count / 3 }

    init(lanes: [SceneTrafficLane]) {
        paths = lanes.compactMap(TrafficPath.init)
        if paths.isEmpty {
            vehicles=[];vertices=[];owners=[];materialIndices=[];materials=[]
            return
        }
        var fleet: [TrafficVehicle] = []
        for (pathIndex, path) in paths.enumerated() {
            let count = max(1, Int(min(28, path.length / 360)))
            let spacing = path.length / Double(count)
            let seed = UInt64(bitPattern:path.id) &* 6364136223846793005 &+ 1442695040888963407
            let offset = Double(seed % 10000) / 10000 * spacing
            for car in 0..<count {
                fleet.append(TrafficVehicle(path:pathIndex, phase:(Double(car)*spacing+offset).truncatingRemainder(dividingBy:path.length), bus:(car+pathIndex*3)%13 == 0))
            }
        }
        vehicles = fleet
        let palette: [SIMD3<Float>] = [SIMD3(0.47,0.51,0.56),SIMD3(0.052,0.078,0.105),SIMD3(0.59,0.60,0.57),SIMD3(0.24,0.025,0.018),SIMD3(0.016,0.065,0.19),SIMD3(0.82,0.80,0.71)]
        var mesh = TrafficMesh()
        for color in palette { mesh.materials.append(SceneMaterial(color,roughness:0.23,metallic:0.63)) }
        mesh.materials += [
            SceneMaterial(SIMD3(0.012,0.017,0.021),roughness:0.85), // rubber 6
            SceneMaterial(SIMD3(0.37,0.40,0.43),roughness:0.17,metallic:0.9), // wheels/trim 7
            SceneMaterial(SIMD3(0.035,0.080,0.105),roughness:0.09,metallic:0.72), // reflective glazing 8
            SceneMaterial(SIMD3(0.94,0.88,0.70),roughness:0.18,emission:2.8,pattern:16), // headlights 9
            SceneMaterial(SIMD3(0.82,0.018,0.007),roughness:0.2,emission:1.2,pattern:16), // tail lamps 10
            SceneMaterial(SIMD3(0.72,0.73,0.67),roughness:0.45), // plates 11
            SceneMaterial(SIMD3(0.025,0.085,0.31),roughness:0.33,metallic:0.35), // bus band 12
            SceneMaterial(SIMD3(0.9,0.31,0.027),roughness:0.22,emission:0.7,pattern:16) // marker lights 13
        ]
        for (index, vehicle) in fleet.enumerated() {
            mesh.owner = UInt32(index)
            mesh.vehicle(bus:vehicle.bus, paint:UInt32(index % palette.count))
        }
        vertices=mesh.vertices; owners=mesh.owners; materialIndices=mesh.indices; materials=mesh.materials
    }
    func distance(for vehicle: TrafficVehicle, time: Double) -> Double {
        let path = paths[vehicle.path]
        let time = time.isFinite ? time : 0
        // Reduce in Double before multiplication, keeping huge/scrubbed times
        // finite and retaining travel direction for negative timeline values.
        let period = path.length / path.speed
        let raw = vehicle.phase + time.truncatingRemainder(dividingBy:period) * path.speed
        let remainder = raw.truncatingRemainder(dividingBy:path.length)
        return remainder < 0 ? remainder + path.length : remainder
    }
    func transforms(at time: Double) -> [simd_float4x4] {
        vehicles.map { paths[$0.path].transform(distance:distance(for:$0,time:time), wheelbase:$0.wheelbase) }
    }
    func lights(transforms: [simd_float4x4]) -> [SceneLight] {
        var result: [SceneLight] = []; result.reserveCapacity(vehicles.count * 3)
        for (vehicle,matrix) in zip(vehicles,transforms) {
            let scale = simd_length(matrix.columns.0.xyz)
            let forward = simd_normalize(matrix.columns.2.xyz), up = simd_normalize(matrix.columns.1.xyz)
            let height: Float = vehicle.bus ? 0.9 : 0.64
            let span: Float = vehicle.bus ? 0.93 : 0.67
            for side: Float in [-1,1] {
                let position = (matrix * SIMD4(side*span,height,vehicle.halfLength+0.04,1)).xyz
                result.append(SceneLight(positionRadius:SIMD4(position,0.12),directionCone:SIMD4(simd_normalize(forward-up*0.13),0.78),colorPower:SIMD4(1,0.88,0.69,65*scale*scale),parameters:SIMD4(65,0.95,0,0)))
            }
            let rear = (matrix * SIMD4(0,height,-vehicle.halfLength-0.04,1)).xyz
            result.append(SceneLight(positionRadius:SIMD4(rear,0.45),directionCone:SIMD4(-forward,0.15),colorPower:SIMD4(1,0.018,0.004,2.2*scale*scale),parameters:SIMD4(12,0.65,0,0)))
        }
        return result
    }
}

/// Small explicit meshes, with modeled wheels, mirrors, door joints, glazing,
/// lamp lenses, bus doors/roof equipment. Their local geometry never changes.
private struct TrafficMesh {
    var vertices: [SceneVertex] = [], owners: [UInt32] = [], indices: [UInt32] = []
    var materials: [SceneMaterial] = []
    var owner: UInt32 = 0
    mutating func tri(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ m:UInt32) {
        let cross = simd_cross(b-a,c-a)
        guard simd_length_squared(cross)>1e-12 else { return }
        let n=simd_normalize(cross)
        vertices += [SceneVertex(a,n),SceneVertex(b,n),SceneVertex(c,n)]
        owners += [owner,owner,owner]; indices.append(m)
    }
    mutating func quad(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ d:SIMD3<Float>,_ m:UInt32) { tri(a,b,c,m);tri(a,c,d,m) }
    mutating func box(_ c:SIMD3<Float>,_ s:SIMD3<Float>,_ m:UInt32) {
        let a=c-s/2,b=c+s/2
        let p:[SIMD3<Float>]=[SIMD3(a.x,a.y,a.z),SIMD3(b.x,a.y,a.z),SIMD3(b.x,b.y,a.z),SIMD3(a.x,b.y,a.z),SIMD3(a.x,a.y,b.z),SIMD3(b.x,a.y,b.z),SIMD3(b.x,b.y,b.z),SIMD3(a.x,b.y,b.z)]
        for f in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[3,7,6,2],[0,1,5,4]] { quad(p[f[0]],p[f[1]],p[f[2]],p[f[3]],m) }
    }
    mutating func wheel(x:Float,z:Float,bus:Bool) {
        let radius:Float=bus ? 0.49:0.34, half:Float=bus ? 0.17:0.13
        for j in 0..<20 {
            let a=Float(j)*2*Float.pi/20,b=Float(j+1)*2*Float.pi/20
            let pa=SIMD3<Float>(x-half,radius+cos(a)*radius,z+sin(a)*radius)
            let pb=SIMD3<Float>(x-half,radius+cos(b)*radius,z+sin(b)*radius)
            let qa=pa+SIMD3(2*half,0,0),qb=pb+SIMD3(2*half,0,0)
            quad(pa,pb,qb,qa,6)
            for side:Float in [-1,1] {
                let center=SIMD3<Float>(x+side*(half+0.003),radius,z)
                let ra=center+SIMD3(0,cos(a)*radius*0.64,sin(a)*radius*0.64)
                let rb=center+SIMD3(0,cos(b)*radius*0.64,sin(b)*radius*0.64)
                tri(center,ra,rb,7)
                quad(center+SIMD3(0,cos(a)*radius,sin(a)*radius),center+SIMD3(0,cos(b)*radius,sin(b)*radius),rb,ra,6)
            }
        }
    }
    mutating func vehicle(bus:Bool,paint:UInt32) {
        let width:Float=bus ? 2.5:1.86, length:Float=bus ? 12:4.8
        box(SIMD3(0,bus ? 0.66:0.49,0),SIMD3(width, bus ? 0.64:0.46,length),bus ? 5:paint)
        if bus {
            box(SIMD3(0,1.68,0),SIMD3(2.48,1.70,11.85),5)
            box(SIMD3(0,2.94,0),SIMD3(2.46,0.28,11.8),5)
            box(SIMD3(0,1.31,0),SIMD3(2.51,0.27,11.8),12)
            for side:Float in [-1,1] {
                for i in 0..<8 { box(SIMD3(side*1.252,2.16,-4.82+Float(i)*1.27),SIMD3(0.026,0.94,1.12),8) }
                for z:Float in [-3.0,4.7] { box(SIMD3(side*1.273,1.42,z),SIMD3(0.025,2.30,1.05),6);box(SIMD3(side*1.29,1.65,z),SIMD3(0.01,1.74,0.92),8);box(SIMD3(side*1.30,1.65,z),SIMD3(0.015,1.75,0.028),7) }
                for z:Float in [-3.85,2.45] { wheel(x:side*1.18,z:z,bus:true) }
                box(SIMD3(side*1.51,2.35,5.67),SIMD3(0.20,0.44,0.25),6)
            }
            box(SIMD3(0,2.14,5.934),SIMD3(2.24,1.20,0.04),8)
            box(SIMD3(0,2.83,5.945),SIMD3(1.58,0.18,0.045),6)
            box(SIMD3(0,2.83,5.972),SIMD3(1.12,0.052,0.01),13)
            box(SIMD3(0,3.18,-1.1),SIMD3(1.72,0.30,3.4),7)
            for x:Float in [-0.78,0,0.78] { box(SIMD3(x,3.1,5.65),SIMD3(0.09,0.06,0.10),13) }
        } else {
            // Sloped windshield/rear glass and a narrower roof avoid box-car silhouettes.
            let a=SIMD3<Float>(-0.78,0.78,-1.40),b=SIMD3<Float>(0.78,0.78,-1.40)
            let c=SIMD3<Float>(0.67,1.43,-0.78),d=SIMD3<Float>(-0.67,1.43,-0.78)
            let e=SIMD3<Float>(-0.67,1.43,0.66),f=SIMD3<Float>(0.67,1.43,0.66)
            let g=SIMD3<Float>(0.81,0.78,1.28),h=SIMD3<Float>(-0.81,0.78,1.28)
            quad(a,b,c,d,8);quad(d,c,f,e,paint);quad(e,f,g,h,8);quad(a,d,e,h,8);quad(b,g,f,c,8)
            box(SIMD3(0,0.76,1.73),SIMD3(1.77,0.13,1.23),paint)
            box(SIMD3(0,0.77,-1.87),SIMD3(1.77,0.12,0.92),paint)
            for side:Float in [-1,1] {
                for z:Float in [-1.41,1.34] { wheel(x:side*0.86,z:z,bus:false) }
                box(SIMD3(side*0.74,1.10,-0.08),SIMD3(0.10,0.60,0.071),paint)
                box(SIMD3(side*0.94,0.62,-0.14),SIMD3(0.012,0.28,0.012),6)
                for z:Float in [-0.71,0.73] { box(SIMD3(side*0.94,0.70,z),SIMD3(0.018,0.028,0.14),7) }
                box(SIMD3(side*1.01,1.03,0.77),SIMD3(0.24,0.13,0.23),paint)
                box(SIMD3(side*1.01,1.03,0.654),SIMD3(0.19,0.086,0.012),7)
            }
        }
        for side:Float in [-1,1] {
            box(SIMD3(side*(bus ? 0.93:0.67),bus ? 0.9:0.64,length/2+0.014),SIMD3(bus ? 0.29:0.38,0.17,0.040),9)
            box(SIMD3(side*(bus ? 1.06:0.72),bus ? 0.90:0.64,-length/2-0.012),SIMD3(0.23,bus ? 0.35:0.17,0.035),10)
        }
        box(SIMD3(0,bus ? 0.75:0.51,length/2+0.025),SIMD3(bus ? 0.70:0.60,0.15,0.035),6)
        for z:Float in [-length/2-0.045,length/2+0.048] {
            box(SIMD3(0,bus ? 0.45:0.36,z),SIMD3(width*0.88,0.09,0.08),7)
            box(SIMD3(0,bus ? 0.59:0.47,z+sign(z)*0.044),SIMD3(0.30,0.145,0.015),11)
        }
    }
}
