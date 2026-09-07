import Foundation
import simd

/// A deterministic, metre-scale architectural reconstruction. See docs/MODEL.md.
/// The mesh contains the actual flange, plate, rail and rivet surfaces used by ray tracing.
enum EiffelScene {
    static let stops: [TourStop] = [
        TourStop(id: 0, title: "The Paris skyline", subtitle: "330 METRES · FOUR CURVED PIERS", detail: "Explore the monument above mapped Paris streets, gardens and building footprints, with individually modeled windows, balconies and roof details in the nearby city.", pose: CameraPose(position: SIMD3(230, 105, 275), target: SIMD3(0, 139, 0), fov: 60)),
        TourStop(id: 1, title: "Beneath the arches", subtitle: "ESPLANADE · HUMAN SCALE", detail: "Stand beneath the sweeping arch trusses. Four open lattice piers carry the first terrace, 57 metres overhead.", pose: CameraPose(position: SIMD3(0, 2.0, 77), target: SIMD3(0, 38, 0), fov: 69)),
        TourStop(id: 2, title: "Anatomy of iron", subtitle: "FLANGES · GUSSETS · RIVETS", detail: "Move close to the modeled connection plates and rounded rivet heads. These details are geometry, casting their own ray-traced shadows.", pose: CameraPose(position: SIMD3(33.0, 9.3, 49.0), target: SIMD3(38.5, 8.25, 48.0), fov: 38)),
        TourStop(id: 3, title: "The first terrace", subtitle: "57 METRES · INSIDE THE STRUCTURE", detail: "An open central void, steel balustrades, deck boards and inclined piers surround this walkable first-floor terrace.", pose: CameraPose(position: SIMD3(3.5, 58.75, 28.0), target: SIMD3(20, 68, -5), fov: 63)),
        TourStop(id: 4, title: "The visitor pavilion", subtitle: "FIRST FLOOR · INTERIOR STUDY", detail: "Enter an interpreted visitor gallery with steel frames, timber flooring, benches and exhibit plinths. Its layout is illustrative rather than an as-built interior survey.", pose: CameraPose(position: SIMD3(25.2, 58.75, 7.5), target: SIMD3(24.0, 59.0, -8.5), fov: 69)),
        TourStop(id: 5, title: "Above the city", subtitle: "115 METRES · SECOND TERRACE", detail: "Inspect the upper lattice and the compact second-floor circulation ring, with the city stretching beyond the balustrade.", pose: CameraPose(position: SIMD3(3, 116.75, 17.5), target: SIMD3(8, 151, 0), fov: 66)),
        TourStop(id: 6, title: "The summit gallery", subtitle: "276 METRES · PANORAMIC WALK", detail: "The open summit gallery surrounds a central lift enclosure beneath the antenna structure. The skyline below is a procedural contextual city.", pose: CameraPose(position: SIMD3(0, 277.75, 6.6), target: SIMD3(115, 125, 230), fov: 65)),
        TourStop(id: 7, title: "A structure in light", subtitle: "FROM CONNECTION TO MONUMENT", detail: "Return to the complete structure. Progressive Metal ray tracing resolves the fine ironwork, contact shadows and reflected light as the camera rests.", pose: CameraPose(position: SIMD3(-175, 78, 255), target: SIMD3(0, 134, 0), fov: 64)),
        RiverView.stop
    ]

    static func build() -> SceneData {
        let b = EiffelBuilder()
        b.parisEnvironment()
        b.riverEnvironment()
        b.tower()
        b.nightLighting()
        return b.scene
    }
}

final class EiffelBuilder {
    typealias V = SIMD3<Float>
    var scene = SceneData()
    let iron: UInt32 = 0, ironLight: UInt32 = 1, ironDark: UInt32 = 2, bronze: UInt32 = 3
    let limestone: UInt32 = 4, pavement: UInt32 = 5, timber: UInt32 = 6, glass: UInt32 = 7
    let grass: UInt32 = 8, leaf: UInt32 = 9, leafLight: UInt32 = 10, bark: UInt32 = 11
    let facade: UInt32 = 12, facadeWarm: UInt32 = 13, roof: UInt32 = 14, water: UInt32 = 15
    let interior: UInt32 = 16, lamp: UInt32 = 17, cityWindow: UInt32 = 18
    var randomState: UInt64 = 0x1889_57_115_276

    init() {
        scene.name = "Eiffel Tower · Paris"
        scene.vertices.reserveCapacity(2_400_000)
        scene.materialIndices.reserveCapacity(800_000)
        scene.materials = [
            SceneMaterial(V(0.245, 0.207, 0.158), roughness: 0.53, metallic: 0.34, pattern: 2),
            SceneMaterial(V(0.34, 0.285, 0.217), roughness: 0.49, metallic: 0.42, pattern: 2),
            SceneMaterial(V(0.115, 0.099, 0.077), roughness: 0.59, metallic: 0.28, pattern: 2),
            SceneMaterial(V(0.42, 0.34, 0.22), roughness: 0.35, metallic: 0.83, pattern: 2),
            SceneMaterial(V(0.64, 0.60, 0.51), roughness: 0.88, pattern: 1),
            SceneMaterial(V(0.47, 0.455, 0.405), roughness: 0.90, pattern: 1),
            SceneMaterial(V(0.34, 0.245, 0.16), roughness: 0.67, pattern: 3),
            SceneMaterial(V(0.085, 0.14, 0.145), roughness: 0.13, metallic: 0.55, pattern: 6),
            SceneMaterial(V(0.16, 0.235, 0.10), roughness: 1, pattern: 4),
            SceneMaterial(V(0.12, 0.22, 0.09), roughness: 0.95, pattern: 4),
            SceneMaterial(V(0.23, 0.32, 0.11), roughness: 0.95, pattern: 4),
            SceneMaterial(V(0.19, 0.125, 0.075), roughness: 0.94, pattern: 3),
            SceneMaterial(V(0.62, 0.58, 0.48), roughness: 0.86, pattern: 1),
            SceneMaterial(V(0.53, 0.48, 0.39), roughness: 0.88, pattern: 1),
            SceneMaterial(V(0.12, 0.145, 0.16), roughness: 0.6, metallic: 0.22, pattern: 5),
            SceneMaterial(V(0.07, 0.145, 0.16), roughness: 0.17, metallic: 0.4),
            SceneMaterial(V(0.56, 0.535, 0.46), roughness: 0.78),
            SceneMaterial(V(1.0, 0.70, 0.34), roughness: 0.4, emission: 2.5, pattern: 8),
            SceneMaterial(V(0.085, 0.14, 0.145), roughness: 0.13, metallic: 0.55, pattern: 7)
        ]
    }

    func tri(_ a: V, _ b: V, _ c: V, _ m: UInt32) {
        let cross = simd_cross(b - a, c - a)
        guard simd_length_squared(cross) > 1e-12 else { return }
        let n = simd_normalize(cross)
        scene.vertices.append(SceneVertex(a, n)); scene.vertices.append(SceneVertex(b, n)); scene.vertices.append(SceneVertex(c, n))
        scene.materialIndices.append(m)
    }
    func smoothTri(_ a: V, _ b: V, _ c: V, _ na: V, _ nb: V, _ nc: V, _ m: UInt32) {
        scene.vertices.append(SceneVertex(a, na)); scene.vertices.append(SceneVertex(b, nb)); scene.vertices.append(SceneVertex(c, nc))
        scene.materialIndices.append(m)
    }
    func quad(_ a: V, _ b: V, _ c: V, _ d: V, _ m: UInt32) { tri(a,b,c,m); tri(a,c,d,m) }
    func box(_ center: V, _ size: V, _ m: UInt32) { orientedBox(center, V(1,0,0), V(0,1,0), V(0,0,1), size, m) }
    func orientedBox(_ c: V, _ x: V, _ y: V, _ z: V, _ size: V, _ m: UInt32) {
        let u = x * size.x * 0.5, v = y * size.y * 0.5, w = z * size.z * 0.5
        let p0=c-u-v-w, p1=c+u-v-w, p2=c+u+v-w, p3=c-u+v-w
        let p4=c-u-v+w, p5=c+u-v+w, p6=c+u+v+w, p7=c-u+v+w
        quad(p0,p3,p2,p1,m); quad(p4,p5,p6,p7,m)
        quad(p0,p4,p7,p3,m); quad(p1,p2,p6,p5,m)
        quad(p0,p1,p5,p4,m); quad(p3,p7,p6,p2,m)
    }
    func beam(_ a: V, _ b: V, _ width: Float, _ depth: Float, _ m: UInt32, iSection: Bool = false, normal: V? = nil) {
        let length = simd_distance(a,b)
        guard length > 0.001 else { return }
        let y = (b-a)/length
        let ref = normal ?? (abs(y.y) < 0.92 ? V(0,1,0) : V(0,0,1))
        var x = simd_cross(y,ref)
        if simd_length_squared(x) < 0.00001 { x = simd_cross(y,V(1,0,0)) }
        x = simd_normalize(x)
        let z = simd_normalize(simd_cross(x,y)), c = (a+b)*0.5
        if iSection {
            let flange = max(0.028, depth * 0.12)
            orientedBox(c+z*(depth-flange)*0.5,x,y,z,V(width,length,flange),m)
            orientedBox(c-z*(depth-flange)*0.5,x,y,z,V(width,length,flange),m)
            orientedBox(c,x,y,z,V(max(0.025,width*0.15),length,depth-flange*2),m)
        } else { orientedBox(c,x,y,z,V(width,length,depth),m) }
    }
    func cylinder(_ a: V, _ b: V, _ radius: Float, _ m: UInt32, segments: Int = 8) {
        let axis = simd_normalize(b-a)
        let u = simd_normalize(simd_cross(axis,abs(axis.y)<0.9 ? V(0,1,0) : V(1,0,0)))
        let v = simd_cross(axis,u)
        for i in 0..<segments {
            let t0=Float(i)*2*Float.pi/Float(segments), t1=Float(i+1)*2*Float.pi/Float(segments)
            let n0=u*cos(t0)+v*sin(t0), n1=u*cos(t1)+v*sin(t1)
            let p0=a+n0*radius,p1=a+n1*radius,p2=b+n1*radius,p3=b+n0*radius
            smoothTri(p0,p2,p1,n0,n1,n1,m); smoothTri(p0,p3,p2,n0,n0,n1,m)
            tri(a,p0,p1,m); tri(b,p2,p3,m)
        }
    }
    func rivet(_ center: V, _ normal: V, _ radius: Float = 0.075, _ m: UInt32? = nil, segments: Int = 8, bands: Int = 2) {
        let n = simd_normalize(normal)
        let u = simd_normalize(simd_cross(n,abs(n.y)<0.9 ? V(0,1,0) : V(1,0,0)))
        let v=simd_cross(n,u), material=m ?? ironLight
        // Close inspection heads use more latitude bands to keep their silhouettes smooth.
        for j in 0..<bands {
            let p0=Float(j)*Float.pi/(2*Float(bands)), p1=Float(j+1)*Float.pi/(2*Float(bands))
            for i in 0..<segments {
                let a0=Float(i)*2*Float.pi/Float(segments),a1=Float(i+1)*2*Float.pi/Float(segments)
                let r0=u*cos(a0)+v*sin(a0),r1=u*cos(a1)+v*sin(a1)
                let n00=r0*cos(p0)+n*sin(p0),n01=r1*cos(p0)+n*sin(p0)
                let n10=r0*cos(p1)+n*sin(p1),n11=r1*cos(p1)+n*sin(p1)
                let a=center+n00*radius,b=center+n01*radius,c=center+n11*radius,d=center+n10*radius
                smoothTri(a,b,c,n00,n01,n11,material)
                if j<bands-1 { smoothTri(a,c,d,n00,n11,n10,material) }
            }
        }
        scene.detailCount += 1
    }
    func connection(_ c: V, _ u: V, _ v: V, _ normal: V, scale: Float = 1, dense: Bool = true) {
        let n=simd_normalize(normal), x=simd_normalize(u), y=simd_normalize(v)
        let p=c+n*0.16
        orientedBox(p,x,y,n,V(1.28*scale,1.48*scale,0.10),iron)
        let offsets: [Float] = dense ? [-0.45,-0.15,0.15,0.45] : [-0.40,0.40]
        for dx in offsets {
            for dy: Float in [-0.52,0.52] { rivet(p+x*dx*scale+y*dy*scale+n*0.065,n,0.070*scale) }
        }
        if dense { for dy: Float in [-0.20,0.20] { for dx: Float in [-0.45,0.45] { rivet(p+x*dx*scale+y*dy*scale+n*0.065,n,0.070*scale) } } }
    }
    func rnd() -> Float { randomState = randomState &* 6364136223846793005 &+ 1442695040888963407; return Float((randomState >> 40) & 0xFFFFFF)/Float(0xFFFFFF) }
    func mix(_ a: Float,_ b: Float,_ t: Float) -> Float { a+(b-a)*t }

    let profile: [(Float,Float,Float)] = [(0,62.5,25),(8,58.5,23.8),(20,51.8,21),(32,45.8,18.7),(44,40.7,16.5),(57,35.3,14.5),(73,29.3,12.4),(92,24.2,10.5),(115,19.7,8.3),(140,15.5,0),(170,11.45,0),(200,8.6,0),(230,6.75,0),(255,5.3,0),(276,4.7,0),(300,2.5,0)]
    func section(_ y: Float) -> (outer: Float, width: Float) {
        for i in 1..<profile.count where y <= profile[i].0 {
            let a=profile[i-1],b=profile[i],t=max(0,min(1,(y-a.0)/(b.0-a.0)))
            return (mix(a.1,b.1,t),mix(a.2,b.2,t))
        }
        return (2.5,0)
    }
    func legCorners(_ y: Float,_ sx: Float,_ sz: Float) -> [V] {
        let s=section(y),c=s.outer-s.width*0.5,w=s.width*0.5
        return [V(sx*c-w,y,sz*c-w),V(sx*c+w,y,sz*c-w),V(sx*c+w,y,sz*c+w),V(sx*c-w,y,sz*c+w)]
    }
    func tower() {
        let ys: [Float] = [2.3,8,14,20,26,32,38,44,50,56,64,72,81,91,102,113.5]
        for sx: Float in [-1,1] { for sz: Float in [-1,1] {
            box(V(sx*50,0.9,sz*50),V(26.5,1.6,26.5),limestone)
            box(V(sx*50,1.85,sz*50),V(25.4,0.3,25.4),pavement)
            for j in 0..<ys.count-1 {
                let lo=legCorners(ys[j],sx,sz),hi=legCorners(ys[j+1],sx,sz)
                let chord: Float = ys[j]<57 ? 1.05 : 0.76
                for e in 0..<4 {
                    beam(lo[e],hi[e],chord,chord*1.10,iron,iSection:true)
                    let f=(e+1)%4,a=lo[e],b=lo[f],c=hi[f],d=hi[e]
                    let u=simd_normalize(b-a),v=simd_normalize((c+d-a-b)*0.5),n=simd_normalize(simd_cross(u,v))
                    beam(a,b,0.48,0.46,iron,iSection:true,normal:n)
                    beam(a,c,0.37,0.30,iron,iSection:true,normal:n)
                    beam(b,d,0.37,0.30,iron,iSection:true,normal:n)
                    let middle=(a+b+c+d)*0.25
                    // Fine lattice strips fill each wide panel without closing it into a solid surface.
                    for k in 1..<4 {
                        let t=Float(k)/4
                        let p=a+(b-a)*t,q=d+(c-d)*t
                        beam(p,q,0.115,0.115,ironLight)
                        let mid=(p+q)*0.5
                        beam(a+(b-a)*max(0,t-0.25),mid,0.115,0.09,iron)
                        beam(mid,d+(c-d)*min(1,t+0.25),0.115,0.09,iron)
                    }
                    connection(middle,u,v,n,scale:ys[j]<57 ? 1.15 : 0.82,dense:true)
                    connection(a+u*0.48,u,v,n,scale:ys[j]<57 ? 0.9 : 0.68,dense:j<9)
                    connection(b-u*0.48,u,v,n,scale:ys[j]<57 ? 0.9 : 0.68,dense:j<9)
                    if j<9 {
                        // Repeated fastening along the broad diagonal flange.
                        for k in 1..<8 {
                            let t=Float(k)/8,p=a+(c-a)*t
                            rivet(p+n*0.18,n,0.064)
                            rivet(b+(d-b)*t+n*0.18,n,0.064)
                        }
                    }
                }
            }
        } }
        arches()
        deck(y:57,outer:36.5,inner:13.5,depth:2.5)
        deck(y:115,outer:21.5,inner:7.5,depth:2.1)
        upperTower()
        stairs()
        elevators()
        pavilion(x:26)
        pavilion(x:-26)
        terraceFurniture()
        summit()
        // A close-view gusset on the accessible inner face of the south-east pier.
        inspectionConnection()
    }

    func arches() {
        for side in 0..<4 {
            func rotated(_ p:V)->V {
                switch side { case 0:return p; case 1:return V(-p.z,p.y,p.x);case 2:return V(-p.x,p.y,-p.z);default:return V(p.z,p.y,-p.x) }
            }
            func point(_ t:Float,_ lower:Bool,_ inset:Float)->V {
                let x = -43*cos(t), y = 8.5 + 34.5*sin(t) - (lower ? 2.2 : 0)
                return rotated(V(x,y,section(y).outer-inset))
            }
            for i in 0..<48 {
                let t0=Float(i)*Float.pi/48,t1=Float(i+1)*Float.pi/48
                for inset: Float in [0.7,2.1] {
                    let a=point(t0,false,inset),b=point(t1,false,inset),c=point(t0,true,inset),d=point(t1,true,inset)
                    beam(a,b,0.44,0.44,iron,iSection:true);beam(c,d,0.4,0.4,iron,iSection:true)
                    beam(a,c,0.22,0.20,iron);beam(a,d,0.17,0.15,ironLight)
                }
                beam(point(t0,false,0.7),point(t0,false,2.1),0.21,0.21,iron)
                let p=point(t0,false,1.4)
                if abs(-43*cos(t0))<34.5 && i%2==0 {
                    let top=rotated(V(-43*cos(t0),54.4,35.2))
                    beam(p,top,0.24,0.24,iron,iSection:true)
                    if i%4==0 {
                        let next=rotated(V(-43*cos(t1+Float.pi/48),54.4,35.2))
                        beam(p,next,0.15,0.15,ironLight)
                    }
                }
            }
        }
    }

    func squareRing(y:Float,outer:Float,inner:Float,thickness:Float,material:UInt32) {
        box(V(0,y-thickness*0.5, (outer+inner)*0.5),V(outer*2,thickness,outer-inner),material)
        box(V(0,y-thickness*0.5,-(outer+inner)*0.5),V(outer*2,thickness,outer-inner),material)
        box(V((outer+inner)*0.5,y-thickness*0.5,0),V(outer-inner,thickness,inner*2),material)
        box(V(-(outer+inner)*0.5,y-thickness*0.5,0),V(outer-inner,thickness,inner*2),material)
    }
    func railing(_ a: V,_ b: V,height:Float = 1.24,spacing:Float = 1.35,mesh:Bool = false) {
        let span=simd_distance(a,b),count=max(1,Int(ceil(span/spacing)))
        let n=simd_normalize(b-a),perp=V(-n.z,0,n.x)
        for h:Float in [0.10,0.63,height] { beam(a+V(0,h,0),b+V(0,h,0),h==height ? 0.065:0.043,0.065,ironLight) }
        for i in 0...count {
            let p=a+(b-a)*Float(i)/Float(count)
            beam(p,p+V(0,height,0),0.065,0.065,iron)
            box(p+V(0,0.035,0),V(0.17,0.07,0.17),ironDark)
            if i<count {
                let q=a+(b-a)*Float(i+1)/Float(count)
                beam(p+V(0,0.16,0),q+V(0,0.61,0),0.022,0.022,iron)
                beam(p+V(0,0.61,0),q+V(0,0.16,0),0.022,0.022,iron)
                if mesh { for h in 1...5 { beam(p+V(0,Float(h)*0.18,0)+perp*0.014,q+V(0,Float(h)*0.18,0)+perp*0.014,0.011,0.011,iron) } }
            }
        }
    }
    func deck(y:Float,outer:Float,inner:Float,depth:Float) {
        squareRing(y:y,outer:outer,inner:inner,thickness:0.28,material:timber)
        // Structural fascia reads as a deep lattice cornice rather than a monolithic slab.
        for face in 0..<4 {
            func p(_ x:Float,_ h:Float,_ inset:Float=0)->V {
                switch face {case 0:return V(x,h,outer-inset);case 1:return V(outer-inset,h,-x);case 2:return V(-x,h,-outer+inset);default:return V(-outer+inset,h,x)}
            }
            beam(p(-outer,y-0.3),p(outer,y-0.3),0.27,0.32,iron,iSection:true)
            beam(p(-outer,y-depth),p(outer,y-depth),0.28,0.35,iron,iSection:true)
            let count=Int(outer*1.1)
            for j in 0..<count {
                let x0 = -outer+2*outer*Float(j)/Float(count),x1 = -outer+2*outer*Float(j+1)/Float(count)
                beam(p(x0,y-depth),p(x1,y-0.30),0.16,0.16,ironLight)
                beam(p(x0,y-0.30),p(x1,y-depth),0.16,0.16,iron)
                beam(p(x0,y-0.3),p(x0,y-depth),0.12,0.14,iron)
                if j%2==0 { beam(p(x0,y-0.4),p(x0,y-depth,outer-inner),0.25,0.48,iron,iSection:true) }
            }
            railing(p(-outer+0.16,y,0.16),p(outer-0.16,y,0.16))
            let innerOffset=outer-inner
            railing(p(-inner,y,innerOffset),p(inner,y,innerOffset),spacing:1.4)
            // Narrow deck board joints modeled for oblique interior inspection.
            if y<120 {
                for j in 0..<Int(outer*2/0.55) {
                    let x = -outer+Float(j)*0.55
                    let start:Float = abs(x)<inner ? inner+0.10 : 0
                    beam(p(x,y+0.007,outer-start),p(x,y+0.007,0.30),0.012,0.009,ironDark)
                }
            }
        }
    }

    func upperTower() {
        let ys:[Float]=[117,124,131,138,145,152,159,166,173,180,187,194,201,208,215,222,229,236,243,250,257,264,271,276]
        for j in 0..<ys.count-1 {
            let y0=ys[j],y1=ys[j+1],s0=section(y0).outer,s1=section(y1).outer
            let lo=[V(-s0,y0,-s0),V(s0,y0,-s0),V(s0,y0,s0),V(-s0,y0,s0)]
            let hi=[V(-s1,y1,-s1),V(s1,y1,-s1),V(s1,y1,s1),V(-s1,y1,s1)]
            for e in 0..<4 {
                let f=(e+1)%4,a=lo[e],b=lo[f],c=hi[f],d=hi[e]
                let n=simd_normalize(simd_cross(b-a,d-a)),u=simd_normalize(b-a),v=simd_normalize((c+d-a-b)*0.5)
                beam(a,d,0.62,0.66,iron,iSection:true)
                beam(a,b,0.29,0.32,iron,iSection:true,normal:n)
                beam(a,c,0.25,0.23,iron,iSection:true,normal:n);beam(b,d,0.25,0.23,iron,iSection:true,normal:n)
                let mid=(a+b+c+d)*0.25
                beam((a+b)*0.5,(c+d)*0.5,0.19,0.19,ironLight)
                beam((a+d)*0.5,(b+c)*0.5,0.15,0.17,iron)
                for k in 1..<4 {
                    let t=Float(k)/4
                    beam(a+(b-a)*t,d+(c-d)*t,0.065,0.07,ironLight)
                }
                connection(mid,u,v,n,scale:0.64,dense:true)
                connection(a+u*0.3,u,v,n,scale:0.55,dense:false)
            }
        }
        // Twin central lift guides and their intermittent service landings remain visible through the truss.
        for x:Float in [-1.9,1.9] { for z:Float in [-1.7,1.7] { beam(V(x,115,z),V(x,276,z),0.16,0.18,ironDark,iSection:true) } }
        for y in stride(from:Float(129),through:Float(268),by:14) {
            squareRing(y:y,outer:3.1,inner:2.0,thickness:0.12,material:ironDark)
            for z:Float in [-1.7,1.7] { beam(V(-1.9,y,z),V(1.9,y+14,z),0.10,0.10,ironDark) }
        }
    }

    func stairs() {
        let flights=14
        for f in 0..<flights {
            let y0:Float=2.2+Float(f)*(54.8/Float(flights)),y1:Float=2.2+Float(f+1)*(54.8/Float(flights))
            let s0=section(y0),s1=section(y1),c0=s0.outer-s0.width*0.5,c1=s1.outer-s1.width*0.5
            let sign:Float=f%2==0 ? 1 : -1
            let a=V(c0-1,y0,c0-sign*3.6),b=V(c1-1,y1,c1+sign*3.6)
            let horizontal=V(b.x-a.x,0,b.z-a.z),u=simd_normalize(horizontal),cross=V(u.z,0,-u.x)
            let steps=22,stepDepth=simd_length(horizontal)/Float(steps)
            for i in 0..<steps {
                let t=Float(i+1)/Float(steps),p=a+(b-a)*t
                orientedBox(p-V(0,0.065,0),cross,V(0,1,0),u,V(2.05,0.13,stepDepth+0.025),ironLight)
                beam(p+cross*1.00-u*stepDepth*0.46,p-cross*1.00-u*stepDepth*0.46,0.035,0.035,ironDark)
                if i%3==0 { for s:Float in [-1,1] { beam(p+cross*s,p+cross*s+V(0,1.02,0),0.045,0.045,iron) } }
            }
            for s:Float in [-1,1] {
                beam(a+cross*s,b+cross*s,0.16,0.28,iron,iSection:true)
                beam(a+cross*s+V(0,1.02,0),b+cross*s+V(0,1.02,0),0.05,0.06,ironLight)
                beam(a+cross*s+V(0,0.5,0),b+cross*s+V(0,0.5,0),0.035,0.035,iron)
            }
            box(b-V(0,0.08,0),V(3.6,0.16,2.4),ironLight)
        }
        // One extra exposed gallery stair connects the first terrace to a small service mezzanine.
        let a=V(-6,57,31),b=V(6,62.7,31),steps=30
        for i in 0..<steps { let t=Float(i+1)/Float(steps);box(a+(b-a)*t-V(0,0.075,0),V(0.41,0.15,1.9),ironLight) }
        for z:Float in [30.05,31.95] {beam(V(-6,57,z),V(6,62.7,z),0.18,0.25,iron,iSection:true);beam(V(-6,58.05,z),V(6,63.75,z),0.065,0.065,ironLight)}
        box(V(7,62.6,31),V(2,0.2,2.2),ironLight)
    }

    func elevators() {
        for sx:Float in [-1,1] {
            for zoff:Float in [-1.5,1.5] {
                var previous=V(sx*50,2,50+zoff)
                for y in stride(from:Float(8),through:Float(114),by:6) {
                    let s=section(y),p=V(sx*(s.outer-s.width*0.5),y,s.outer-s.width*0.5+zoff)
                    beam(previous,p,0.24,0.24,ironDark,iSection:true)
                    previous=p
                }
            }
            let y:Float=sx>0 ? 26:78,s=section(y),c=s.outer-s.width*0.5
            liftCabin(V(sx*c,y,c),size:V(4.5,3.2,3.8))
        }
        liftCabin(V(0,208,0),size:V(3.4,3.0,3.0))
    }
    func liftCabin(_ c:V,size:V) {
        box(c-V(0,size.y*0.45,0),V(size.x,0.35,size.z),ironLight)
        box(c+V(0,size.y*0.5,0),V(size.x+0.16,0.18,size.z+0.16),iron)
        for sx:Float in [-1,1] { for sz:Float in [-1,1] { beam(c+V(sx*size.x*0.48,-size.y*0.5,sz*size.z*0.48),c+V(sx*size.x*0.48,size.y*0.5,sz*size.z*0.48),0.14,0.14,ironLight) } }
        for z:Float in [-1,1] {
            box(c+V(0,0,z*size.z*0.49),V(size.x-0.3,size.y-0.5,0.04),glass)
            beam(c+V(0,-size.y*0.5,z*size.z*0.5),c+V(0,size.y*0.5,z*size.z*0.5),0.10,0.10,iron)
        }
    }

    func pavilion(x:Float) {
        let y:Float=57
        box(V(x,62.50,0),V(12.7,0.28,24.5),iron)
        box(V(x,62.30,0),V(12.1,0.10,23.9),interior)
        box(V(x,y+0.025,0),V(11.8,0.05,23.8),timber)
        for dx:Float in [-6,6] {
            // Open bays alternate with reflective clerestory glazing; doorways remain clear.
            for z in stride(from:Float(-12),through:Float(12),by:3) {
                beam(V(x+dx,y,z),V(x+dx,62.4,z),0.15,0.18,iron,iSection:true)
                if z<12 {
                    box(V(x+dx,y+0.4,z+1.5),V(0.14,0.8,2.8),ironDark)
                    box(V(x+dx,61.70,z+1.5),V(0.055,1.12,2.8),glass)
                    beam(V(x+dx,61.12,z+0.08),V(x+dx,61.12,z+2.92),0.09,0.09,iron)
                    beam(V(x+dx,58.0,z),V(x+dx,61.1,z+3),0.065,0.065,ironLight)
                }
            }
            beam(V(x+dx,y+0.85,-12),V(x+dx,y+0.85,12),0.12,0.12,iron)
        }
        for z:Float in [-12,12] {
            for dx:Float in [-6,-1.7,1.7,6] { beam(V(x+dx,y,z),V(x+dx,62.4,z),0.15,0.15,iron) }
            for dx:Float in [-3.85,3.85] {
                box(V(x+dx,58.0,z),V(4.15,2.0,0.12),ironDark)
                box(V(x+dx,60.25,z),V(4.15,2.3,0.05),glass)
            }
            beam(V(x-6,61.5,z),V(x+6,61.5,z),0.16,0.20,iron)
        }
        for z in stride(from:Float(-10),through:Float(10),by:4) {
            beam(V(x-6,62.12,z),V(x+6,62.12,z),0.14,0.27,iron,iSection:true)
            box(V(x,62.04,z),V(6,0.035,0.10),lamp)
        }
        // Museum-style plinths, precision connection exhibits and timber seats.
        for z:Float in [-7,0,7] {
            box(V(x+4.2,57.5,z),V(1.7,1.0,1.7),interior)
            box(V(x+4.2,58.04,z),V(1.9,0.08,1.9),ironDark)
            beam(V(x+3.7,58.1,z-0.35),V(x+4.7,59.35,z+0.35),0.26,0.27,iron,iSection:true)
            for i in 0..<5 { rivet(V(x+4.22,58.25+Float(i)*0.17,z+0.18),V(0,0,1),0.07) }
            bench(V(x-3.5,57,z),alongX:false)
        }
    }
    func bench(_ c:V,alongX:Bool=true) {
        let u=alongX ? V(1,0,0):V(0,0,1),w=alongX ? V(0,0,1):V(-1,0,0)
        for i in 0..<5 { orientedBox(c+V(0,0.47,0)+w*(Float(i)-2)*0.105,u,V(0,1,0),w,V(2.4,0.085,0.09),timber) }
        for s:Float in [-1,1] {
            orientedBox(c+u*s*0.85+V(0,0.23,0),u,V(0,1,0),w,V(0.09,0.46,0.5),ironDark)
            beam(c+u*s*0.85-w*0.28+V(0,0.25,0),c+u*s*0.85-w*0.36+V(0,0.98,0),0.075,0.075,iron)
        }
        for i in 0..<3 { orientedBox(c-w*0.34+V(0,0.70+Float(i)*0.105,0),u,V(0,1,0),w,V(2.4,0.09,0.08),timber) }
    }
    func terraceFurniture() {
        for x:Float in [-9,0,9] { bench(V(x,57,-30));bench(V(x,57,33.5)) }
        for x:Float in [-10,10] {
            for z:Float in [-17.8,17.8] {
                cylinder(V(x,115,z),V(x,116.15,z),0.10,ironLight)
                cylinder(V(x,116.25,z-0.36),V(x,116.43,z+0.45),0.16,ironLight,segments:12)
                cylinder(V(x,116.43,z+0.45),V(x,116.45,z+0.51),0.14,glass,segments:12)
            }
        }
    }

    func summit() {
        deck(y:276,outer:8.5,inner:3.0,depth:1.5)
        box(V(0,278.0,0),V(6.0,4.0,6.0),ironDark)
        for face in 0..<4 {
            for i in -2...2 {
                let x=Float(i)*1.05
                if face%2==0 {box(V(x,278.1,face==0 ? 3.015 : -3.015),V(0.88,2.2,0.035),glass)}
                else {box(V(face==1 ? 3.015 : -3.015,278.1,x),V(0.035,2.2,0.88),glass)}
            }
        }
        squareRing(y:280.5,outer:8.1,inner:2.8,thickness:0.20,material:iron)
        // Low-output gallery downlights reveal the walking surface and screen without
        // spilling toward the distant city. Sources sit below their modeled diffusers.
        for side in 0..<4 {
            for offset:Float in [-5,0,5] {
                let p:V = side%2==0 ? V(offset,280.20,side==0 ? 6.35:-6.35) : V(side==1 ? 6.35:-6.35,280.20,offset)
                box(p+V(0,0.065,0),V(0.52,0.07,0.18),ironDark)
                box(p+V(0,0.020,0),V(0.43,0.018,0.12),lamp)
                scene.lights.append(NightLighting.source(p,toward:p-V(0,4,0),power:7.5,
                                                        color:V(1,0.74,0.47),range:8.5,radius:0.18,
                                                        outerDegrees:70,innerDegrees:40))
            }
        }
        for x:Float in [-7.8,7.8] {for z in stride(from:Float(-7.8),through:Float(7.8),by:2.6) {beam(V(x,276,z),V(x,280.4,z),0.11,0.11,iron)}}
        for z:Float in [-7.8,7.8] {for x in stride(from:Float(-5.2),through:Float(5.2),by:2.6) {beam(V(x,276,z),V(x,280.4,z),0.11,0.11,iron)}}
        // Open protective wire screen, visible in close-up without opaque glazing.
        for side in 0..<4 { for j in 0...30 {
            let t = -7.8+Float(j)*0.52
            let a:V = side%2==0 ? V(t,276,side==0 ? 8.1 : -8.1) : V(side==1 ? 8.1 : -8.1,276,t)
            beam(a,a+V(0,4.35,0),0.012,0.012,ironDark)
        } }
        for y in stride(from:Float(276.4),through:Float(280.4),by:0.5) { for z:Float in [-8.1,8.1] {beam(V(-8.1,y,z),V(8.1,y,z),0.012,0.012,ironDark)};for x:Float in [-8.1,8.1] {beam(V(x,y,-8.1),V(x,y,8.1),0.012,0.012,ironDark)} }
        for j in 0..<5 {
            let y0:Float=280.5+Float(j)*4.4,y1=y0+4.4,w0:Float=4.4-Float(j)*0.64,w1=w0-0.64
            for sx:Float in [-1,1] {for sz:Float in [-1,1] {
                beam(V(sx*w0,y0,sz*w0),V(sx*w1,y1,sz*w1),0.36,0.36,iron,iSection:true)
                beam(V(sx*w0,y0,sz*w0),V(-sx*w1,y1,sz*w1),0.14,0.14,iron)
                beam(V(sx*w0,y0,sz*w0),V(sx*w1,y1,-sz*w1),0.14,0.14,iron)
            }}
        }
        box(V(0,302.5,0),V(4,0.45,4),ironDark)
        cylinder(V(0,302.7,0),V(0,314,0),0.82,ironLight,segments:16)
        cylinder(V(0,314,0),V(0,324,0),0.42,interior,segments:12)
        cylinder(V(0,324,0),V(0,330,0),0.16,ironLight,segments:10)
        for y in stride(from:Float(304),through:Float(322),by:2) {
            let r:Float=y<314 ? 1.2:0.65
            for k in 0..<4 {let t=Float(k)*Float.pi/2;box(V(cos(t)*r,y,sin(t)*r),V(0.32,1.2,0.32),interior)}
        }
    }
    func inspectionConnection() {
        let c=V(38.5,8,48),n=V(-1,0,0),u=V(0,0,1),v=V(0,1,0)
        orientedBox(c,u,v,-n,V(2.35,2.65,0.14),iron)
        beam(V(38.62,5.5,46),V(38.62,10.6,50),0.56,0.42,iron,iSection:true,normal:n)
        for row in -3...3 {for col in -2...2 {
            if abs(row)==3 || abs(col)==2 || (row==0 && col==0) {
                rivet(c+n*0.10+u*Float(col)*0.40+v*Float(row)*0.34,n,0.105,segments:20,bands:5)
            }
        }}
        // Plate bears directly onto the inner pier chord; three tie members make the connection legible.
        beam(V(38.6,6.7,46.8),V(34.5,14,45.3),0.28,0.30,iron,iSection:true)
        beam(V(38.6,8,48),V(58,8,48),0.32,0.32,iron,iSection:true)
    }

    func environment() {
        box(V(0,-1.4,0),V(100_000,2.7,100_000),limestone)
        box(V(0,0.035,0),V(183,0.13,183),pavement)
        // Square cobble inlays and four approach axes establish scale under the ironwork.
        for i in -8...8 {
            let q=Float(i)*10
            box(V(q,0.105,0),V(0.065,0.01,181),limestone)
            box(V(0,0.105,q),V(181,0.01,0.065),limestone)
        }
        for x:Float in [-1,1] {
            for z in stride(from:Float(120),through:Float(430),by:62) {
                box(V(x*49,0.10,z),V(54,0.18,52),grass)
                box(V(x*49,0.17,z-26.6),V(55.2,0.32,0.65),limestone)
                box(V(x*49,0.17,z+26.6),V(55.2,0.32,0.65),limestone)
                box(V(x*21.7,0.17,z),V(0.65,0.32,52),limestone)
                box(V(x*76.3,0.17,z),V(0.65,0.32,52),limestone)
            }
            for z in stride(from:Float(-112),through:Float(448),by:18) {
                if z > -90 && z < 85 { continue }
                tree(V(x*94,0,z),height:9+rnd()*3)
                tree(V(x*112,0,z+7),height:9+rnd()*3)
            }
        }
        for x in stride(from:Float(-110),through:Float(110),by:19) {tree(V(x,0,-103),height:10+rnd()*2)}
        for x:Float in [-83,83] {for z in stride(from:Float(92),through:Float(425),by:31) {bench(V(x,0.2,z),alongX:false);streetLamp(V(x>0 ? x+3:x-3,0,z+10))}}
        for x:Float in [-80,80] {for z:Float in [-79,79] {streetLamp(V(x,0,z))}}
        // Interpretive river and masonry embankments beyond the esplanade.
        box(V(0,-0.055,-195),V(7000,0.15,88),water)
        for z:Float in [-241,-149] {
            box(V(0,0.6,z),V(7000,2.2,3.2),limestone)
            box(V(0,1.9,z),V(7000,0.4,4.0),pavement)
        }
        for x:Float in [0,-345,345] {
            box(V(x,2.5,-195),V(24,1.8,101),limestone)
            for sz:Float in [-1,1] {box(V(x+sz*12.0,3.9,-195),V(0.7,1.2,103),limestone)}
            for z:Float in [-224,-195,-166] {box(V(x,0.0,z),V(22,5.0,5),limestone)}
        }
        // A regular, varied urban fabric is intentionally contextual, not a georeferenced city model.
        for ix in -9...9 {for iz in -10...9 {
            let x=Float(ix)*57,z=Float(iz)*57
            if abs(x)<153 && z > -140 && z<490 {continue}
            if z < -133 && z > -260 {continue}
            if abs(x)<28 && z < -250 {continue}
            let jitterX=(rnd()-0.5)*5,jitterZ=(rnd()-0.5)*5
            cityBuilding(V(x+jitterX,0,z+jitterZ),width:30+rnd()*15,depth:29+rnd()*14,height:13+rnd()*17)
        }}
        // Low-cost roof geometry carries the urban fabric to the atmospheric horizon.
        // These buildings deliberately omit facade windows below their useful screen footprint.
        for ix in -43...43 { for iz in -43...43 {
            let x=Float(ix)*82,z=Float(iz)*82
            if abs(x)<580 && abs(z)<630 { continue }
            if z > -260 && z < -130 { continue }
            let jitterX=(rnd()-0.5)*8,jitterZ=(rnd()-0.5)*8
            if (ix*7+iz*11)%71==0 {
                box(V(x,0.035,z),V(68,0.08,69),grass)
                continue
            }
            distantBuilding(V(x+jitterX,0,z+jitterZ),width:53+rnd()*19,depth:50+rnd()*22,height:14+rnd()*21)
        }}
    }
    func distantBuilding(_ p:V,width:Float,depth:Float,height:Float) {
        box(p+V(0,height*0.5,0),V(width,height,depth),rnd()>0.4 ? facade:facadeWarm)
        let w=width*0.5,d=depth*0.5,y=height,top=height+3.5+rnd()*2.0
        let a=p+V(-w,y,-d),b=p+V(w,y,-d),c=p+V(w,y,d),e=p+V(-w,y,d)
        let f=p+V(-w+3,top,-d+3),g=p+V(w-3,top,-d+3),h=p+V(w-3,top,d-3),i=p+V(-w+3,top,d-3)
        quad(a,f,g,b,roof);quad(b,g,h,c,roof);quad(c,h,i,e,roof);quad(e,i,f,a,roof);quad(f,i,h,g,roof)
        // Dark courtyard recesses and raised roof blocks break up the repeated urban cells.
        if rnd()>0.3 { box(p+V(0,top+0.025,0),V(width*0.31,0.04,depth*0.39),ironDark) }
        for k in 0..<2 {
            let x=(k==0 ? -1.0:1.0)*width*0.28,z=(rnd()-0.5)*depth*0.55
            box(p+V(x,top+0.9,z),V(1.2,1.8,2.0),facadeWarm)
        }
    }
    func ellipsoid(_ c:V,_ r:V,_ m:UInt32,segments:Int=10,rings:Int=6) {
        for j in 0..<rings {
            let v0 = -Float.pi/2+Float(j)*Float.pi/Float(rings),v1 = -Float.pi/2+Float(j+1)*Float.pi/Float(rings)
            for i in 0..<segments {
                let a0=Float(i)*2*Float.pi/Float(segments),a1=Float(i+1)*2*Float.pi/Float(segments)
                let p0=V(cos(v0)*cos(a0),sin(v0),cos(v0)*sin(a0)),p1=V(cos(v0)*cos(a1),sin(v0),cos(v0)*sin(a1))
                let p2=V(cos(v1)*cos(a1),sin(v1),cos(v1)*sin(a1)),p3=V(cos(v1)*cos(a0),sin(v1),cos(v1)*sin(a0))
                quad(c+p0*r,c+p3*r,c+p2*r,c+p1*r,m)
            }
        }
    }
    func tree(_ p:V,height:Float) {
        cylinder(p,p+V(0,height*0.75,0),0.23+rnd()*0.1,bark,segments:8)
        for k in 0..<5 {
            let t=Float(k)*2.3999,offset=V(cos(t)*1.8,height*(0.65+0.06*Float(k%3)),sin(t)*1.8)
            cylinder(p+V(0,height*0.45,0),p+offset,0.10,bark,segments:6)
            ellipsoid(p+offset,V(2.7+rnd(),2.8+rnd(),2.7+rnd()),k%2==0 ? leaf:leafLight)
        }
    }
    func streetLamp(_ p:V) {
        cylinder(p,p+V(0,4.4,0),0.055,ironDark)
        cylinder(p,p+V(0,0.3,0),0.17,ironDark)
        box(p+V(0,4.45,0),V(0.48,0.08,0.48),ironDark)
        box(p+V(0,4.73,0),V(0.34,0.52,0.34),lamp)
        box(p+V(0,5.03,0),V(0.55,0.08,0.55),ironDark)
        scene.lights.append(NightLighting.source(p+V(0,4.72,0),power:65,
                                                color:V(1,0.64,0.32),range:35,radius:0.4))
    }
    func cityBuilding(_ p:V,width:Float,depth:Float,height:Float) {
        let mat=rnd()>0.42 ? facade:facadeWarm
        box(p+V(0,height*0.5,0),V(width,height,depth),mat)
        box(p+V(0,height+0.12,0),V(width+0.8,0.35,depth+0.8),limestone)
        let y=height+0.28,top=height+4.1,w=width*0.5,d=depth*0.5
        let a=p+V(-w,y,-d),b=p+V(w,y,-d),c=p+V(w,y,d),e=p+V(-w,y,d)
        let f=p+V(-w+2.8,top,-d+2.8),g=p+V(w-2.8,top,-d+2.8),h=p+V(w-2.8,top,d-2.8),i=p+V(-w+2.8,top,d-2.8)
        quad(a,f,g,b,roof);quad(b,g,h,c,roof);quad(c,h,i,e,roof);quad(e,i,f,a,roof);quad(f,i,h,g,roof)
        for story in 0..<Int(height/3.4) {
            let sy=2.2+Float(story)*3.4
            for side in 0..<4 {
                let length=side%2==0 ? width:depth,count=max(2,Int(length/3.4))
                for j in 0..<count {
                    let q = -length*0.5+(Float(j)+0.5)*length/Float(count)
                    let c:V=side%2==0 ? V(q,sy,side==0 ? d+0.018:-d-0.018) : V(side==1 ? w+0.018:-w-0.018,sy,q)
                    box(p+c,side%2==0 ? V(1.05,1.65,0.04):V(0.04,1.65,1.05),cityWindow)
                    if story==1 || story==Int(height/3.4)-1 {
                        box(p+c-V(0,0.95,0),side%2==0 ? V(1.6,0.12,0.30):V(0.30,0.12,1.6),limestone)
                    }
                }
            }
        }
        for _ in 0..<3 {
            let x=(rnd()-0.5)*(width-8),z=(rnd()-0.5)*(depth-8)
            box(p+V(x,height+4.5,z),V(0.8,2.4,1.2),facadeWarm)
            box(p+V(x,height+5.75,z),V(1.0,0.15,1.4),limestone)
        }
    }

    func nightLighting() {
        let towerLights = NightLighting.tower(section:section)
        scene.lights += towerLights
        for light in towerLights {
            let p = V(light.positionRadius.x,light.positionRadius.y,light.positionRadius.z)
            box(p-V(0,0.09,0),V(0.24,0.12,0.25),ironDark)
            box(p,V(0.18,0.035,0.18),lamp)
        }
        for x: Float in [-26,26] {
            for z in stride(from:Float(-10),through:Float(10),by:4) {
                scene.lights.append(NightLighting.source(V(x,61.88,z),toward:V(x,57,z),power:55,
                                                        color:V(1,0.78,0.5),range:14,radius:0.25,
                                                        outerDegrees:88,innerDegrees:65))
            }
        }
    }
}
