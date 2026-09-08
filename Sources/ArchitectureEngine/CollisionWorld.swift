import Foundation
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
    var detailedPickingTriangleCount: Int { pickingDetail?.triangles.count ?? 0 }
    var detailedPickingNodeCount: Int { pickingDetail?.nodes.count ?? 0 }

    init(scene: SceneData, detailedPickingRegions: [PickingRegion] = []) {
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
