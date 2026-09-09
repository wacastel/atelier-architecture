import Foundation
import simd

/// Willis-origin metres. Footprint: OSM relation 15899437 (derived ID below).
/// The 1978 published plan establishes the two rotundas' north/south placement;
/// floor heights and circulation dimensions are authored estimates, not survey.
enum CulturalCenterLayout {
    typealias V = SIMD3<Float>
    static let buildingID: Int64 = -158994370
    static let center = V(906.15,0,-557.02)
    static let east = simd_normalize(V(1,0,-0.014))
    static let south = simd_normalize(V(0.014,0,1))
    static let halfWidth: Float = 23.2, halfLength: Float = 54.8
    static let groundFloor: Float = 0.9, stairLanding: Float = 6.35
    static let prestonFloor: Float = 11.8, garFloor: Float = 11.8
    static let corniceHeight: Float = 31.7
    static let tiffanyRadius: Float = 5.7912 // Published 38-foot glass diameter.
    static let garRadius: Float = 5.4864 // Harboe: 36-foot inner art-glass dome.
    /// Inner ring of OSM way1175466107, projected into this local frame.
    static let courtyard: [SIMD2<Float>] = [SIMD2(-6.3562,-3.8327),SIMD2(-6.3343,6.4434),SIMD2(7.4847,6.3808),
        SIMD2(7.4851,-5.487),SIMD2(5.6276,-5.4351),SIMD2(4.5941,-3.8464),SIMD2(2.1304,-2.5338),
        SIMD2(-0.3073,-2.49),SIMD2(-2.4077,-2.8534),SIMD2(-4.0013,-3.8888),SIMD2(-4.5744,-4.9879)]
    static func point(_ p: V) -> V { center + east*p.x + V(0,p.y,0) + south*p.z }
    static func local(_ p: V) -> V { let d=p-center;return V(simd_dot(d,east),d.y,simd_dot(d,south)) }
    static let prestonCenter = point(V(0,prestonFloor,29))
    static let tiffanyCenter = point(V(0,22.2,29))
    static let garCenter = point(V(0,garFloor,-29))
    static let garDomeCenter = point(V(0,21,-29))
    static let memorialCenter = point(V(6.5,garFloor,-44))
    static let washingtonEntrance = point(V(0,groundFloor,54.8))

    /// World eye positions. Small risers match the physical exterior steps.
    static let washingtonEyePath: [V] = {
        var p=[V(0,1.94,61),V(0,1.94,58.5)]
        for i in 0..<5 { p.append(V(0,0.19+Float(i+1)*0.142+1.75,58.3-(Float(i)+0.5)*0.38)) }
        p += [V(0,2.65,56.2),V(0,2.65,54),V(0,2.65,52.3)]
        return p.map(point)
    }()
    /// World eye positions, following the central flight and eastern return.
    /// The top aisle is x=10.4, safely outside the stairwell's x=9 edge.
    static let mosaicStairEyePath: [V] = {
        var p=[V(0,2.65,52.3)]
        for i in 0..<32 { p.append(V(0,groundFloor+Float(i+1)*(stairLanding-groundFloor)/32+1.75,52-(Float(i)+0.5)*10/32)) }
        p += [V(0,8.10,40.8),V(6,8.10,40.8),V(6,8.10,41.9)]
        for i in 0..<32 { p.append(V(6,stairLanding+Float(i+1)*(prestonFloor-stairLanding)/32+1.75,42+(Float(i)+0.5)*10/32)) }
        p += [V(6,13.55,53),V(10.4,13.55,53),V(10.4,13.55,37.5),V(10.4,13.55,32)]
        return p.map(point)
    }()
}

private struct CulturalPalette {
    let stone: UInt32, joint: UInt32, granite: UInt32, marble: UInt32, pink: UInt32, green: UInt32
    let gold: UInt32, bronze: UInt32, lead: UInt32, mahogany: UInt32, red: UInt32, olive: UInt32
    let ceiling: UInt32, floor: UInt32, dark: UInt32, clear: UInt32, lamp: UInt32, roof: UInt32
    let tesserae: [UInt32], opal: [UInt32]
}

extension EiffelBuilder {
    func culturalCenter() {
        func material(_ c: V, _ roughness: Float = 0.65, metal: Float = 0,
                      emission: Float = 0, pattern: Float = 0, transmission: Float = 0) -> UInt32 {
            let index=UInt32(scene.materials.count)
            scene.materials.append(SceneMaterial(c,roughness:roughness,metallic:metal,emission:emission,pattern:pattern,transmission:transmission))
            return index
        }
        let p=CulturalPalette(
            stone:material(V(0.64,0.61,0.53),0.88),joint:material(V(0.35,0.33,0.29),0.97),
            granite:material(V(0.24,0.255,0.235),0.86),marble:material(V(0.79,0.77,0.68),0.38),
            pink:material(V(0.64,0.49,0.40),0.42),green:material(V(0.065,0.15,0.12),0.39),
            gold:material(V(0.66,0.43,0.13),0.37,metal:0.66),bronze:material(V(0.23,0.16,0.072),0.42,metal:0.80),
            lead:material(V(0.085,0.093,0.071),0.55,metal:0.58),mahogany:material(V(0.15,0.037,0.016),0.45,pattern:3),
            red:material(V(0.43,0.13,0.055),0.94),olive:material(V(0.20,0.28,0.15),0.92),
            ceiling:material(V(0.61,0.46,0.24),0.78),floor:material(V(0.49,0.385,0.25),0.56),
            dark:material(V(0.04,0.035,0.023),0.70),clear:material(V(0.97,0.98,0.965),0.09,transmission:1),
            lamp:material(V(1,0.82,0.55),0.5,emission:0.75),roof:material(V(0.21,0.22,0.19),0.95),
            tesserae:[material(V(0.65,0.52,0.23),0.50),material(V(0.34,0.41,0.19),0.55),material(V(0.83,0.78,0.57),0.47),material(V(0.15,0.38,0.39),0.50),material(V(0.46,0.20,0.12),0.58)],
            // Milky art glass uses a diffuse radiance proxy. Positive transmission
            // selects the renderer's perfect clear-sheet path, which cannot
            // represent opalescent scattering and would reflect the city sharply.
            opal:[material(V(0.68,0.83,0.84),0.70,emission:0.34),
                  material(V(0.73,0.84,0.63),0.72,emission:0.32),
                  material(V(0.89,0.75,0.45),0.70,emission:0.30),
                  material(V(0.80,0.61,0.59),0.72,emission:0.30),
                  material(V(0.81,0.87,0.80),0.70,emission:0.34)])
        culturalExterior(p)
        culturalFloorsAndStair(p)
        culturalPrestonHall(p)
        culturalGAR(p)
        culturalLighting(p)
    }

    private func ccb(_ c: V, _ size: V, _ m: UInt32) {
        orientedBox(CulturalCenterLayout.point(c),CulturalCenterLayout.east,V(0,1,0),CulturalCenterLayout.south,size,m)
    }
    private func ccq(_ a: V, _ b: V, _ c: V, _ d: V, _ m: UInt32) {
        quad(CulturalCenterLayout.point(a),CulturalCenterLayout.point(b),CulturalCenterLayout.point(c),CulturalCenterLayout.point(d),m)
    }
    private func ccBeam(_ a: V, _ b: V, _ width: Float, _ depth: Float, _ m: UInt32) {
        beam(CulturalCenterLayout.point(a),CulturalCenterLayout.point(b),width,depth,m)
    }
    private func ccCylinder(_ a: V, _ b: V, _ radius: Float, _ m: UInt32, segments: Int = 12) {
        cylinder(CulturalCenterLayout.point(a),CulturalCenterLayout.point(b),radius,m,segments:segments)
    }
    private func ccEllipsoid(_ c: V, _ radius: V, _ m: UInt32, segments: Int = 12, rings: Int = 6) {
        // Near-spherical jewels/lamps do not depend on the small block skew.
        ellipsoid(CulturalCenterLayout.point(c),radius,m,segments:segments,rings:rings)
    }
    private func ccOrientedBox(_ c: V, _ tangent: V, _ size: V, _ m: UInt32) {
        let t=CulturalCenterLayout.east*tangent.x+CulturalCenterLayout.south*tangent.z
        orientedBox(CulturalCenterLayout.point(c),t,V(0,1,0),V(-t.z,0,t.x),size,m)
    }

    /// An arch is masonry around an actual void, including the curved reveal.
    /// No backing quad spans its doorway/window aperture.
    private func ccArch(_ base: V, tangent: V, width: Float, spring: Float, top: Float,
                        thickness: Float, material: UInt32, trim: UInt32, glazed: UInt32? = nil) {
        let r=width/2,n=V(-tangent.z,0,tangent.x),up=V(0,1,0)
        let segments=20
        for i in 0..<segments {
            let a=Float(i)*Float.pi/Float(segments),b=Float(i+1)*Float.pi/Float(segments)
            let v0=base+tangent*(cos(a)*r)+up*(spring+sin(a)*r)
            let v1=base+tangent*(cos(b)*r)+up*(spring+sin(b)*r)
            for side: Float in [-1,1] {
                let o=n*(side*thickness/2)
                ccq(v0+o,v1+o,base+tangent*(cos(b)*r)+up*top+o,base+tangent*(cos(a)*r)+up*top+o,material)
            }
            ccq(v0-n*thickness/2,v0+n*thickness/2,v1+n*thickness/2,v1-n*thickness/2,material)
            for offset: Float in [0.06,0.19,0.32] {
                let aa=base+tangent*(cos(a)*(r+offset))+up*(spring+sin(a)*(r+offset))+n*(thickness/2+0.035)
                let bb=base+tangent*(cos(b)*(r+offset))+up*(spring+sin(b)*(r+offset))+n*(thickness/2+0.035)
                ccBeam(aa,bb,0.09,0.075,trim)
            }
        }
        for side: Float in [-1,1] {
            ccOrientedBox(base+tangent*(side*(r+0.12))+up*(spring/2),tangent,V(0.24,spring,thickness+0.12),trim)
        }
        if let glass=glazed {
            ccq(base-tangent*r,base+tangent*r,base+tangent*r+up*spring,base-tangent*r+up*spring,glass)
            let center=base+up*spring
            for i in 0..<segments {
                let a=Float(i)*Float.pi/Float(segments),b=Float(i+1)*Float.pi/Float(segments)
                tri(CulturalCenterLayout.point(center),CulturalCenterLayout.point(center+tangent*(cos(a)*r)+up*(sin(a)*r)),CulturalCenterLayout.point(center+tangent*(cos(b)*r)+up*(sin(b)*r)),glass)
            }
        }
    }

    private func ccFacadeBay(_ base: V, tangent: V, width: Float, entrance: Bool, _ p: CulturalPalette) {
        let n=V(-tangent.z,0,tangent.x),up=V(0,1,0),opening=width*0.69
        // Three independently open registers, with a monumental middle arcade.
        for sign: Float in [-1,1] {
            ccOrientedBox(base+tangent*(sign*(width+opening)/4)+up*15.1,tangent,V((width-opening)/2,30.2,0.915),p.stone)
            for y: Float in stride(from:0.6,through:29.4,by:0.68) {
                ccOrientedBox(base+tangent*(sign*(width+opening)/4)+up*y+n*0.469,tangent,V((width-opening)/2-0.035,0.014,0.025),p.joint)
            }
        }
        if entrance {
            // Washington portal remains passable down its central 2.8 m aisle.
            ccArch(base+up*0.9,tangent:tangent,width:opening,spring:5.6,top:18.8,thickness:0.915,material:p.stone,trim:p.stone)
            for sign: Float in [-1,1] {
                ccOrientedBox(base+tangent*(sign*(opening/2-0.85))+up*2.4,tangent,V(1.35,3.0,0.12),p.clear)
                for dx: Float in [-0.66,0.66] {ccBeam(base+tangent*(sign*(opening/2-0.85)+dx)+up*0.9,base+tangent*(sign*(opening/2-0.85)+dx)+up*3.9,0.085,0.12,p.bronze)}
            }
            ccOrientedBox(base+up*4.0,tangent,V(opening,0.16,0.18),p.bronze)
        } else {
            ccOrientedBox(base+up*0.55,tangent,V(opening,1.1,0.915),p.granite)
            ccOrientedBox(base+up*4.9,tangent,V(opening,2.0,0.915),p.stone)
            ccOrientedBox(base+up*2.5,tangent,V(opening-0.1,2.8,0.08),p.clear)
            ccArch(base+up*5.9,tangent:tangent,width:opening,spring:7.15,top:12.9,thickness:0.915,material:p.stone,trim:p.stone,glazed:p.clear)
            for y: Float in [2.5,9.3,13.05] {ccOrientedBox(base+up*y,tangent,V(opening,0.13,0.15),p.bronze)}
            ccOrientedBox(base+up*10.15,tangent,V(0.13,8.5,0.14),p.bronze)
        }
        ccOrientedBox(base+up*19.15,tangent,V(opening,0.7,0.915),p.stone)
        // Paired windows and fluted engaged columns of the upper register.
        for sign: Float in [-1,1] {
            ccOrientedBox(base+tangent*(sign*opening/4)+up*24.4,tangent,V(opening/2-0.2,9.7,0.07),p.clear)
            ccOrientedBox(base+tangent*(sign*opening/4)+up*24.2,tangent,V(opening/2-0.2,0.13,0.15),p.bronze)
        }
        for offset in [-opening/2,Float(0),opening/2] {
            let c=base+tangent*offset+n*0.59
            ccCylinder(c+up*19.8,c+up*28.7,0.24,p.stone,segments:20)
            for i in 0..<8 {
                let a=Float(i)*2*Float.pi/8
                ccCylinder(c+V(cos(a)*0.246,20.2,sin(a)*0.246),c+V(cos(a)*0.246,28.4,sin(a)*0.246),0.024,p.joint,segments:4)
            }
            ccOrientedBox(c+up*19.65,tangent,V(0.78,0.32,0.72),p.stone)
            ccOrientedBox(c+up*28.9,tangent,V(0.83,0.40,0.76),p.stone)
        }
        ccOrientedBox(base+up*29.55,tangent,V(opening,0.9,0.915),p.stone)
        for i in 0..<Int(width/0.34) {
            let x = -width/2+(Float(i)+0.5)*0.34
            ccOrientedBox(base+tangent*x+up*30.18+n*0.52,tangent,V(0.17,0.25,0.42),p.stone)
        }
    }

    private func culturalExterior(_ p: CulturalPalette) {
        let w=CulturalCenterLayout.halfWidth,l=CulturalCenterLayout.halfLength
        for side: Float in [-1,1] {
            // Tangents chosen to put raised moldings on the outward face.
            let t=V(0,0,-side)
            for i in 0..<14 {
                let z = -l+(Float(i)+0.5)*(2*l/14)
                ccFacadeBay(V(side*w,0,z),tangent:t,width:2*l/14,entrance:false,p)
            }
            let t2=V(side,0,0)
            for i in 0..<5 {
                let x = -w+(Float(i)+0.5)*(2*w/5)
                ccFacadeBay(V(x,0,side*l),tangent:t2,width:2*w/5,entrance:i==2,p)
            }
            for (y,h,projection): (Float,Float,Float) in [(5.75,0.30,0.30),(18.9,0.32,0.42),(29.95,0.3,0.55),(30.65,0.54,0.95),(31.45,0.5,0.70)] {
                ccb(V(side*w,y,0),V(projection,h,l*2+projection),p.stone)
                ccb(V(0,y,side*l),V(w*2+projection,h,projection),p.stone)
            }
        }
        // Randolph's Doric entrance portico projects from the north end.
        for x: Float in [-6.4,-2.15,2.15,6.4] {
            ccCylinder(V(x,0.9,-57),V(x,6.3,-57),0.39,p.stone,segments:20)
            ccb(V(x,6.45,-57),V(1.1,0.4,1.1),p.stone)
        }
        ccb(V(0,7,-56),V(15.4,0.75,3.7),p.stone)
        ccb(V(0,0.68,-56.2),V(15.4,0.44,4),p.granite)
        for i in 0..<5 {
            let top: Float=0.19+Float(i+1)*0.142
            ccb(V(0,(0.19+top)/2,58.3-(Float(i)+0.5)*0.38),V(12.8,top-0.19,0.38),p.granite)
        }
        ccb(V(0,0.54,55.6),V(12.8,0.72,1.7),p.granite)
        for side: Float in [-1,1] {
            ccBeam(V(side*5.8,1.0,58.2),V(side*5.8,1.7,56.4),0.075,0.075,p.bronze)
            for z: Float in [56.5,57.3,58.1] {ccCylinder(V(side*5.8,0.4,z),V(side*5.8,1.7-(z-56.4)*0.39,z),0.033,p.bronze,segments:8)}
        }
        // Upper roof is segmented around both glazed skylights; no opaque
        // fallback roof crosses their apertures or the interior art glass.
        ccCourtyardPlate(halfWidth:23.2,north:-18.5,south:18.5,top:31,bottom:30.6,material:p.roof)
        for z: Float in [-29,29] {
            ccb(V(-15.5,30.8,z),V(15.4,0.4,21),p.roof)
            ccb(V(15.5,30.8,z),V(15.4,0.4,21),p.roof)
            for s: Float in [-1,1] {ccb(V(0,30.8,z+s*10.0),V(15.6,0.4,4.4),p.roof)}
            let r: Float=7.4
            for i in 0..<48 {
                let a=Float(i)*2*Float.pi/48,b=Float(i+1)*2*Float.pi/48
                for j in 0..<8 {
                    let u=Float(j)/8,v=Float(j+1)/8
                    func q(_ angle: Float,_ t: Float)->V {V(cos(angle)*r*(1-t),30.95+2.6*sin(t*Float.pi/2),z+sin(angle)*r*(1-t))}
                    ccq(q(a,u),q(b,u),q(b,v),q(a,v),p.clear)
                }
                ccBeam(V(cos(a)*r,30.95,z+sin(a)*r),V(0,33.55,z),0.048,0.06,p.bronze)
            }
        }
        for z: Float in [-48,48] {ccb(V(0,30.8,z),V(46.4,0.4,13.6),p.roof)}
        ccLabel("CHICAGO PUBLIC LIBRARY",V(0,29.38,55.31),V(1,0,0),height:0.65,material:p.bronze)
        ccLabel("CHICAGO CULTURAL CENTER",V(23.72,4.78,0),V(0,0,-1),height:0.40,material:p.bronze)
    }

    private func culturalFloorsAndStair(_ p: CulturalPalette) {
        ccb(V(0,0.63,0),V(46.4,0.54,109.6),p.marble)
        // Slab pieces explicitly leave the double-height grand stair open.
        ccCourtyardPlate(halfWidth:22.25,north:-54.6,south:39,top:11.8,bottom:11.4,material:p.marble)
        for i in CulturalCenterLayout.courtyard.indices {
            let a=CulturalCenterLayout.courtyard[i],b=CulturalCenterLayout.courtyard[(i+1)%CulturalCenterLayout.courtyard.count]
            let aa=V(a.x,0.9,a.y),bb=V(b.x,0.9,b.y),length=simd_distance(aa,bb),t=(bb-aa)/length
            ccOrientedBox((aa+bb)/2+V(0,14.85,0),t,V(length,29.7,0.35),p.stone)
            for y: Float in [4.0,8.5,15.0,21.0,27.0] {
                let n=V(-t.z,0,t.x)
                ccOrientedBox((aa+bb)/2+V(0,y,0)+n*0.18,t,V(max(0.4,length-0.75),2.7,0.04),p.clear)
            }
        }
        for side: Float in [-1,1] {ccb(V(side*15.6,11.60,46.8),V(13.2,0.4,15.6),p.marble)}
        ccb(V(0,11.60,53.2),V(18,0.4,2.4),p.marble)
        ccb(V(0,6.15,40.85),V(18,0.4,2.3),p.marble)
        for i in 0..<32 {
            let y: Float=0.9+Float(i+1)*5.45/32,z: Float=52-(Float(i)+0.5)*10/32
            ccb(V(0,(0.9+y)/2,z),V(4.8,y-0.9,10/32),p.marble)
            ccb(V(0,y+0.008,z-0.135),V(4.75,0.016,0.035),p.bronze)
            let yy: Float=6.35+Float(i+1)*5.45/32,zz: Float=42+(Float(i)+0.5)*10/32
            for sign: Float in [-1,1] {
                ccb(V(sign*6,(6.35+yy)/2,zz),V(4,yy-6.35,10/32),p.marble)
                ccb(V(sign*6,yy+0.008,zz+0.135),V(3.95,0.016,0.035),p.bronze)
            }
        }
        // Solid marble balustrades with inset green medallions and borders.
        for x: Float in [-2.65,2.65] {culturalStairRail(V(x,0.9,52),V(x,6.35,42),p)}
        for x: Float in [-8.3,-3.7,3.7,8.3] {culturalStairRail(V(x,6.35,42),V(x,11.8,52),p)}
        for sign: Float in [-1,1] {
            ccb(V(sign*9.35,5.8,47),V(0.6,10,14),p.marble)
            for z: Float in [42,46,50] {ccMosaicPanel(V(sign*9.01,8.4,z),tangent:V(0,0,-sign),width:2.5,height:2.6,p)}
        }
        culturalCoffers(center:V(0,22.0,46.5),width:18,depth:15,columns:6,rows:5,rich:false,p)
        // Walkable Preston floor pattern and quiet connecting circulation.
        for x: Float in stride(from:-20,through:20,by:2.5) {
            ccb(V(x,11.808,28.5),V(0.055,0.016,18.5),p.green)
        }
        for z: Float in stride(from:20,through:37.5,by:2.5) {ccb(V(0,11.808,z),V(41,0.016,0.055),p.green)}
    }

    private func culturalStairRail(_ a: V,_ b: V,_ p: CulturalPalette) {
        let dz=b.z-a.z,segments=10
        for i in 0..<segments {
            let t=(Float(i)+0.5)/Float(segments),c=a+(b-a)*t
            ccb(c+V(0,0.56,0),V(0.24,1.10,abs(dz)/Float(segments)+0.025),p.marble)
            // A sloped cap and paired mosaic medallions have actual relief.
            for sign: Float in [-1,1] {
                let face=c+V(sign*0.126,0.57,0)
                ccRosette(face,tangent:V(0,0,sign),radius:0.25,p)
            }
        }
        ccBeam(a+V(0,1.14,0),b+V(0,1.14,0),0.38,0.13,p.marble)
        for c in [a,b] {ccb(c+V(0,0.64,0),V(0.55,1.28,0.55),p.marble)}
    }

    /// Offline constrained triangulation of a rectangle minus the exact source
    /// courtyard ring. Both floor and roof retain the same hole and curved edge.
    private func ccCourtyardPlate(halfWidth: Float,north: Float,south: Float,top: Float,bottom: Float,material: UInt32) {
        let points=[SIMD2(-halfWidth,north),SIMD2(halfWidth,north),SIMD2(halfWidth,south),SIMD2(-halfWidth,south)]+CulturalCenterLayout.courtyard
        let triangles=[[0,3,4],[14,13,12],[8,11,10],[10,9,8],[5,4,3],[14,0,4],[11,14,12],[2,5,3],
                       [8,0,14],[11,8,14],[5,2,6],[0,8,1],[7,6,2],[1,8,7],[7,2,1]]
        for t in triangles {
            let a=points[t[0]],b=points[t[1]],c=points[t[2]]
            tri(CulturalCenterLayout.point(V(a.x,top,a.y)),CulturalCenterLayout.point(V(b.x,top,b.y)),CulturalCenterLayout.point(V(c.x,top,c.y)),material)
            tri(CulturalCenterLayout.point(V(c.x,bottom,c.y)),CulturalCenterLayout.point(V(b.x,bottom,b.y)),CulturalCenterLayout.point(V(a.x,bottom,a.y)),material)
        }
        for ring in [Array(points[0..<4]),CulturalCenterLayout.courtyard] {
            for i in ring.indices {
                let a=ring[i],b=ring[(i+1)%ring.count]
                ccq(V(a.x,bottom,a.y),V(b.x,bottom,b.y),V(b.x,top,b.y),V(a.x,top,a.y),material)
            }
        }
    }

    private func ccRosette(_ center: V, tangent: V, radius: Float, _ p: CulturalPalette) {
        let up=V(0,1,0),n=V(-tangent.z,0,tangent.x)
        for i in 0..<32 {
            let a=Float(i)*2*Float.pi/32,b=Float(i+1)*2*Float.pi/32
            ccq(center+tangent*(cos(a)*radius)+up*(sin(a)*radius),center+tangent*(cos(b)*radius)+up*(sin(b)*radius),
                center+tangent*(cos(b)*radius*0.76)+up*(sin(b)*radius*0.76),center+tangent*(cos(a)*radius*0.76)+up*(sin(a)*radius*0.76),p.gold)
        }
        for i in 0..<12 {
            let a=Float(i)*2*Float.pi/12,d=tangent*cos(a)+up*sin(a),side=tangent*(-sin(a))+up*cos(a)
            ccq(center+n*0.005+d*radius*0.18,center+n*0.005+d*radius*0.53+side*radius*0.16,
                center+n*0.005+d*radius*0.73,center+n*0.005+d*radius*0.53-side*radius*0.16,p.tesserae[i%p.tesserae.count])
        }
    }

    private func ccMosaicPanel(_ c: V, tangent: V, width: Float, height: Float, _ p: CulturalPalette, fine: Bool = false) {
        let n=V(-tangent.z,0,tangent.x),up=V(0,1,0)
        let cell: Float=fine ? 0.035:0.115,nx=max(1,Int(width/cell)),ny=max(1,Int(height/cell))
        for row in 0..<ny {for col in 0..<nx {
            let x = -width/2+(Float(col)+0.5)*width/Float(nx),y = -height/2+(Float(row)+0.5)*height/Float(ny)
            let w=width/Float(nx)*0.95,h=height/Float(ny)*0.95,pt=c+tangent*x+up*y
            let m=p.tesserae[(row*7+col*13)%11==0 ? 0:2]
            ccq(pt-tangent*w/2-up*h/2,pt+tangent*w/2-up*h/2,pt+tangent*w/2+up*h/2,pt-tangent*w/2+up*h/2,m)
        }}
        for side: Float in [-1,1] {
            ccBeam(c+tangent*(side*width/2)-up*height/2,c+tangent*(side*width/2)+up*height/2,0.065,0.025,p.gold)
            ccBeam(c-tangent*width/2+up*(side*height/2),c+tangent*width/2+up*(side*height/2),0.065,0.025,p.gold)
        }
        for sign: Float in [-1,1] {
            for i in 0..<3 {
                let y=(Float(i)-1)*height*0.29,rc=c+up*y+tangent*(sign*width*0.20)+n*0.014
                ccRosette(rc,tangent:tangent,radius:min(width*0.20,height*0.13),p)
            }
            var previous=c+tangent*(sign*width*0.36)-up*height*0.43+n*0.018
            for i in 1...36 {
                let t=Float(i)/36,pt=c+tangent*(sign*(width*0.24+sin(t*6*Float.pi)*width*0.13))+up*((t-0.5)*height*0.86)+n*0.018
                ccBeam(previous,pt,0.028,0.023,p.tesserae[1]);previous=pt
            }
        }
        scene.detailCount += 1
    }

    private func culturalCoffers(center c: V,width: Float,depth: Float,columns: Int,rows: Int,rich: Bool,_ p: CulturalPalette) {
        ccb(c+V(0,0.12,0),V(width,0.24,depth),rich ? p.dark:p.ceiling)
        let w=width/Float(columns),d=depth/Float(rows)
        for i in 0..<columns {for j in 0..<rows {
            let q=c+V(-width/2+(Float(i)+0.5)*w,-0.16,-depth/2+(Float(j)+0.5)*d)
            ccb(q+V(0,0.04,0),V(w-0.25,0.16,d-0.25),rich ? p.bronze:p.ceiling)
            for inset: Float in [0.12,0.25] {
                for side: Float in [-1,1] {
                    ccb(q+V(side*(w/2-inset),-0.10,0),V(0.055,0.11,d-inset*2),p.gold)
                    ccb(q+V(0,-0.10,side*(d/2-inset)),V(w-inset*2,0.11,0.055),p.gold)
                }
            }
            // Raised radial leaf-like ornaments in each recessed panel.
            for k in 0..<8 {
                let a=Float(k)*2*Float.pi/8
                ccBeam(q+V(cos(a)*0.12,-0.13,sin(a)*0.12),q+V(cos(a)*min(w,d)*0.29,-0.13,sin(a)*min(w,d)*0.29),0.045,0.055,p.gold)
            }
            if rich && (i+j)%2==0 {ccEllipsoid(q+V(0,-0.14,0),V(0.17,0.055,0.17),p.lamp,segments:10,rings:4)}
        }}
    }

    private func ccTripleArcade(center c: V,tangent: V,height: Float,_ p: CulturalPalette) {
        for x: Float in [-6.55,-2.18,2.18,6.55] {
            ccOrientedBox(c+tangent*x+V(0,2.9,0),tangent,V(0.85,5.8,0.9),p.marble)
            ccOrientedBox(c+tangent*x+V(0,5.82,0),tangent,V(1.10,0.25,1.05),p.marble)
            ccMosaicPanel(c+tangent*x+V(0,3.0,0)+V(-tangent.z,0,tangent.x)*0.465,tangent:tangent,width:0.62,height:3.8,p)
        }
        for x: Float in [-4.36,0,4.36] {
            ccArch(c+tangent*x,tangent:tangent,width:3.45,spring:5.8,top:height,thickness:0.9,material:p.marble,trim:p.marble)
            ccMosaicPanel(c+tangent*x+V(0,height-1.05,0)+V(-tangent.z,0,tangent.x)*0.466,tangent:tangent,width:3.6,height:1.8,p)
        }
    }

    private func culturalPrestonHall(_ p: CulturalPalette) {
        let f=CulturalCenterLayout.prestonFloor
        // Four triple-arched sides surround the Tiffany rotunda. The rooms on
        // either side remain open to its marble and opalescent-glass centerpiece.
        for side: Float in [-1,1] {
            ccTripleArcade(center:V(0,f,29+side*7),tangent:V(side,0,0),height:10.4,p)
            ccTripleArcade(center:V(side*7,f,29),tangent:V(0,0,-side),height:10.4,p)
        }
        for side: Float in [-1,1] {
            culturalCoffers(center:V(side*15.0,22.2,28.6),width:15.4,depth:18.8,columns:5,rows:6,rich:false,p)
            // Inner wall liners leave real exterior windows visible above.
            for z: Float in [21.5,28.6,35.7] {
                ccb(V(side*21.7,f+2.3,z),V(0.24,4.6,1.1),p.marble)
                ccMosaicPanel(V(side*21.54,f+3.4,z),tangent:V(0,0,-side),width:0.78,height:2.1,p)
            }
        }
        // Pendentive corners close the square roof only outside the round
        // opening. They do not span the glass with a hidden opaque slab.
        ccDomeDrum(V(0,21.4,29),inner:CulturalCenterLayout.tiffanyRadius,outer:7.15,height:0.8,p)
        ccArtDome(V(0,22.2,29),radius:CulturalCenterLayout.tiffanyRadius,rise:3.0,tiffany:true,p)
        for x: Float in [-15,-10,10,15] {
            for z: Float in [24,33] {ccPendant(V(x,20.7,z),drop:2.6,radius:0.54,multi:false,p)}
        }
        ccPendant(V(0,24.9,29),drop:6.5,radius:0.82,multi:false,p)
        ccMosaicPanel(V(13.4,15.4,38.8),tangent:V(-1,0,0),width:1.3,height:1.4,p,fine:true)
        ccLabel("PRESTON BRADLEY HALL",V(13.5,17.8,38.75),V(-1,0,0),height:0.21,material:p.bronze)
    }

    private func ccDomeDrum(_ base: V,inner: Float,outer: Float,height: Float,_ p: CulturalPalette) {
        for i in 0..<96 {
            let a=Float(i)*2*Float.pi/96,b=Float(i+1)*2*Float.pi/96
            func pt(_ r: Float,_ angle: Float,_ y: Float)->V {base+V(cos(angle)*r,y,sin(angle)*r)}
            ccq(pt(inner,a,0),pt(inner,b,0),pt(inner,b,height),pt(inner,a,height),p.marble)
            ccq(pt(inner,a,height),pt(inner,b,height),pt(outer,b,height),pt(outer,a,height),p.marble)
            for y: Float in [0.05,height-0.05] {ccBeam(pt(inner-0.035,a,y),pt(inner-0.035,b,y),0.07,0.07,p.gold)}
            if i%3==0 {ccEllipsoid(pt(inner-0.07,(a+b)/2,0.22),V(0.045,0.045,0.045),p.lamp,segments:6,rings:3)}
        }
        // Square corner infills outside the radial aperture.
        for i in 0..<96 {
            let a=Float(i)*2*Float.pi/96,b=Float(i+1)*2*Float.pi/96
            let ra=outer/max(abs(cos(a)),abs(sin(a))),rb=outer/max(abs(cos(b)),abs(sin(b)))
            ccq(base+V(cos(a)*outer,height,sin(a)*outer),base+V(cos(b)*outer,height,sin(b)*outer),
                base+V(cos(b)*rb,height,sin(b)*rb),base+V(cos(a)*ra,height,sin(a)*ra),p.marble)
        }
    }

    /// Colored glass cells and raised lead/gilded boundaries follow the two
    /// photographed ornamental grammars. No raster image or opaque dome proxy.
    private func ccArtDome(_ c: V,radius: Float,rise: Float,tiffany: Bool,_ p: CulturalPalette) {
        let sphere=(radius*radius+rise*rise)/(2*rise),segments=24,bands=tiffany ? 10:6
        let inner: Float=tiffany ? 1.2:0.8
        func pt(_ r: Float,_ a: Float,_ offset: Float = 0)->V {
            c+V(cos(a)*r,rise-sphere+sqrt(max(0,sphere*sphere-r*r))+offset,sin(a)*r)
        }
        for row in 0..<bands {
            let r0=inner+(radius-inner)*Float(row)/Float(bands),r1=inner+(radius-inner)*Float(row+1)/Float(bands)
            for col in 0..<segments {
                let a=Float(col)*2*Float.pi/Float(segments),b=Float(col+1)*2*Float.pi/Float(segments)
                for j in 0..<4 {for k in 0..<3 {
                    let rr0=r0+(r1-r0)*Float(j)/4,rr1=r0+(r1-r0)*Float(j+1)/4
                    let aa=a+(b-a)*Float(k)/3,bb=a+(b-a)*Float(k+1)/3
                    let color=tiffany ? p.opal[(j+col+row*3)%3]:p.opal[(j+k+col+row)%p.opal.count]
                    ccq(pt(rr0,aa),pt(rr1,aa),pt(rr1,bb),pt(rr0,bb),color)
                }}
                // Curved fish-scale cames for Tiffany; oval cartouches in GAR.
                let count=tiffany ? 3:1
                for k in 0..<count {
                    let middle=(a+b)/2+(Float(k)-Float(count-1)/2)*(b-a)/Float(count)
                    let cr=(r0+r1)/2
                    var last=V.zero
                    for j in 0...10 {
                        let angle=Float(j)*2*Float.pi/10
                        let rr=cr+cos(angle)*(r1-r0)*(tiffany ? 0.35:0.36)
                        let az=middle+sin(angle)*(b-a)*(tiffany ? 0.14:0.34)
                        let v=pt(rr,az,-0.016)
                        if j>0 {ccBeam(last,v,tiffany ? 0.013:0.022,0.018,p.lead)}
                        last=v
                    }
                    if !tiffany {
                        for j in 0..<6 {
                            let az=middle+Float(j-3)*(b-a)*0.075
                            ccEllipsoid(pt(cr,az,-0.018),V(0.055,0.028,0.055),p.opal[(j+col)%p.opal.count],segments:6,rings:3)
                        }
                    }
                }
                // Actual panel frames: 24 radial bays ×10 Tiffany ring tiers.
                for az in [a,b] {ccBeam(pt(r0,az,-0.025),pt(r1,az,-0.025),tiffany ? 0.047:0.07,0.055,tiffany ? p.gold:p.bronze)}
                for j in 0..<4 {
                    let aa=a+(b-a)*Float(j)/4,bb=a+(b-a)*Float(j+1)/4
                    ccBeam(pt(r1,aa,-0.025),pt(r1,bb,-0.025),0.055,0.055,tiffany ? p.gold:p.bronze)
                }
                scene.detailCount += 1
            }
        }
        for i in 0..<96 {
            let a=Float(i)*2*Float.pi/96,b=Float(i+1)*2*Float.pi/96
            tri(CulturalCenterLayout.point(pt(0,0)),CulturalCenterLayout.point(pt(inner,b)),CulturalCenterLayout.point(pt(inner,a)),p.opal[i%p.opal.count])
            if i%4==0 {ccBeam(pt(0,0,-0.022),pt(inner,a,-0.022),0.026,0.03,p.bronze)}
        }
        for i in 0..<12 {
            let a=Float(i)*2*Float.pi/12
            var previous=V.zero
            for j in 0...16 {
                let b=Float(j)*2*Float.pi/16,r=inner*0.70+cos(b)*inner*0.19,az=a+sin(b)*0.20
                let q=pt(r,az,-0.028)
                if j>0 {ccBeam(previous,q,0.025,0.03,p.gold)}
                previous=q
            }
        }
    }

    private func culturalGAR(_ p: CulturalPalette) {
        let f=CulturalCenterLayout.garFloor
        // Restored rotunda: pink marble below green walls, bronze lunettes,
        // richly framed mahogany doors and a separate Healy & Millet dome.
        for side: Float in [-1,1] {
            for axis in 0..<2 {
                let c=axis==0 ? V(0,f,-29+side*7.3):V(side*7.3,f,-29)
                let t=axis==0 ? V(-side,0,0):V(0,0,side),n=V(-t.z,0,t.x)
                for x: Float in [-6,-2,2,6] {
                    ccOrientedBox(c+t*x+V(0,2.65,0),t,V(1.0,5.3,0.65),p.pink)
                    ccOrientedBox(c+t*x+V(0,5.4,0),t,V(1.18,0.25,0.78),p.marble)
                }
                for x: Float in [-4,0,4] {
                    ccArch(c+t*x,tangent:t,width:2.75,spring:4.1,top:9.2,thickness:0.65,material:p.olive,trim:p.gold)
                    // Center north/south portals connect the two halls; other
                    // mahogany doors remain closed, with physical panel relief.
                    if axis==1 || x != 0 {
                        ccOrientedBox(c+t*x+V(0,2.0,0),t,V(2.65,4,0.13),p.mahogany)
                        for sign: Float in [-1,1] {for y: Float in [1,2.9] {
                            ccOrientedBox(c+t*(x+sign*0.68)+V(0,y,0)+n*0.09,t,V(1.1,1.4,0.055),p.mahogany)
                        }}
                    }
                    ccRosette(c+t*x+V(0,6.9,0)+n*0.34,tangent:t,radius:1.0,p)
                }
            }
        }
        ccDomeDrum(V(0,20.2,-29),inner:CulturalCenterLayout.garRadius,outer:7.65,height:0.8,p)
        ccArtDome(V(0,21,-29),radius:CulturalCenterLayout.garRadius,rise:3.2,tiffany:false,p)
        for x: Float in [-6,6] {for z: Float in [-35,-29,-23] {ccPendant(V(x,17.2,z),drop:0.45,radius:0.29,multi:true,p)}}
        // Gold/terracotta mosaic floor with pale borders and Greek-key frieze.
        ccb(V(0,f+0.008,-29),V(14.3,0.016,14.3),p.floor)
        for i in -2...2 {
            ccb(V(Float(i)*2.75,f+0.023,-29),V(0.09,0.012,14.2),p.marble)
            ccb(V(0,f+0.023,-29+Float(i)*2.75),V(14.2,0.012,0.09),p.marble)
        }
        for sign: Float in [-1,1] {for i in 0..<36 {
            let x = -6.9+Float(i)*0.39,z: Float = -29+sign*6.9
            ccb(V(x,f+0.03,z),V(0.28,0.018,0.055),p.dark)
            ccb(V(x+0.14,f+0.03,z-sign*0.12),V(0.055,0.018,0.29),p.dark)
        }}
        ccLabel("G A R MEMORIAL HALL",V(0,16.6,-36.89),V(-1,0,0),height:0.35,material:p.gold)
        // The city visitor plan puts Memorial Hall in the eastern two-thirds;
        // the separate Claudia Cassidy Theater occupies the western portion.
        for x: Float in [-7.8,20.8] {
            ccb(V(x,f+4.8,-44.8),V(0.45,9.6,17.6),p.red)
            ccb(V(x,f+2.5,-44.8),V(0.58,5,17.6),p.green)
        }
        for z: Float in [-53.1,-36.8] {
            ccb(V(6.5,f+7.0,z),V(28.6,5.2,0.45),p.red)
            if z < -40 {ccb(V(6.5,f+2.3,z),V(28.6,4.6,0.58),p.green)}
            else {
                ccb(V(-4.7,f+2.3,z),V(6.2,4.6,0.58),p.green)
                ccb(V(11.2,f+2.3,z),V(19.2,4.6,0.58),p.green)
            }
            for x: Float in [-5,2.8,8.2,13.6,19] {
                ccb(V(x,f+2.4,z+0.31),V(0.62,4.8,0.18),p.green)
                ccRosette(V(x,f+6.5,z+0.32),tangent:V(1,0,0),radius:1.05,p)
            }
        }
        for x: Float in [-7.42,20.42] {for z: Float in [-50,-44.8,-39.6] {
            ccb(V(x,f+2.7,z),V(0.35,5.4,0.7),p.green)
            for k in 0..<4 {ccBeam(V(x,f+0.2+Float(k)*1.3,z-0.32),V(x,f+0.6+Float(k)*1.3,z+0.31),0.013,0.025,p.marble)}
        }}
        culturalCoffers(center:V(6.5,21.6,-44.8),width:28.0,depth:16.6,columns:9,rows:5,rich:true,p)
        for x: Float in [-3,6.5,16] {for z: Float in [-49,-40.5] {ccPendant(V(x,21.4,z),drop:3.3,radius:0.75,multi:true,p)}}
    }

    private func ccPendant(_ ceiling: V,drop: Float,radius: Float,multi: Bool,_ p: CulturalPalette) {
        let c=ceiling-V(0,drop,0)
        ccCylinder(ceiling,c,0.036,p.bronze,segments:8)
        if multi {
            ccEllipsoid(c,V(radius*0.40,0.15,radius*0.40),p.bronze,segments:12,rings:4)
            for i in 0..<8 {
                let a=Float(i)*2*Float.pi/8,t=V(cos(a)*radius,-0.12,sin(a)*radius)
                ccBeam(c,c+t,0.047,0.047,p.bronze)
                ccEllipsoid(c+t+V(0,0.17,0),V(0.13,0.17,0.13),p.lamp,segments:10,rings:5)
            }
        } else {
            ccEllipsoid(c,V(radius,radius*0.56,radius),p.lamp,segments:20,rings:8)
            for i in 0..<12 {
                let a=Float(i)*2*Float.pi/12,b=Float(i+1)*2*Float.pi/12
                ccBeam(c+V(cos(a)*radius,0.02,sin(a)*radius),c+V(cos(b)*radius,0.02,sin(b)*radius),0.04,0.045,p.bronze)
                ccBeam(c+V(cos(a)*radius,0.02,sin(a)*radius),c-V(0,radius*0.56,0),0.023,0.032,p.bronze)
            }
        }
        scene.lights.append(NightLighting.source(CulturalCenterLayout.point(c-V(0,radius*0.62+0.10,0)),power:multi ? 48:38,
            color:V(1,0.80,0.52),range:18,radius:0.22,alwaysOn:true))
    }

    private func culturalLighting(_ p: CulturalPalette) {
        for c in [V(0,18.5,29),V(0,18.5,-29)] {
            for x: Float in [-4,4] {for z: Float in [-4,4] {
                let pos=c+V(x,0,z)
                scene.lights.append(NightLighting.source(CulturalCenterLayout.point(pos),power:18,color:V(0.80,0.89,1),range:14,radius:0.45,alwaysOn:true))
            }}
        }
        for z: Float in [42.5,48.5,53.5] {ccPendant(V(0,21.8,z),drop:3.1,radius:0.5,multi:false,p)}
        for y: Float in [4.8,10.3] {for side: Float in [-1,1] {
            let pos=V(side*8.8,y,47)
            ccEllipsoid(pos,V(0.18,0.24,0.18),p.lamp)
            scene.lights.append(NightLighting.source(CulturalCenterLayout.point(pos),power:28,color:V(1,0.81,0.58),range:12,radius:0.18,alwaysOn:true))
        }}
        for side: Float in [-1,1] {
            for z: Float in [-48,-32,-16,0,16,32,48] {
                let pos=V(side*24.0,1.3,z),target=V(side*23.5,17,z)
                ccb(pos,V(0.30,0.18,0.35),p.bronze)
                scene.lights.append(NightLighting.source(CulturalCenterLayout.point(pos),toward:CulturalCenterLayout.point(target),
                    power:260,color:V(1,0.72,0.38),range:35,radius:0.3,outerDegrees:72,innerDegrees:38))
            }
            for x: Float in [-17,-8,8,17] {
                let pos=V(x,1.3,side*56.0)
                scene.lights.append(NightLighting.source(CulturalCenterLayout.point(pos),toward:CulturalCenterLayout.point(V(x,17,side*55.0)),
                    power:240,color:V(1,0.74,0.44),range:34,radius:0.3,outerDegrees:72,innerDegrees:38))
            }
        }
    }

    /// Compact physical lettering for identification; ornamental inscriptions
    /// elsewhere are suggested by borders rather than fabricated quotations.
    private func ccLabel(_ text: String,_ center: V,_ tangent: V,height: Float,material: UInt32) {
        let glyphs: [Character:[String]]=[
            "A":["01110","10001","10001","11111","10001","10001","10001"],"B":["11110","10001","10001","11110","10001","10001","11110"],
            "C":["01111","10000","10000","10000","10000","10000","01111"],"D":["11110","10001","10001","10001","10001","10001","11110"],
            "E":["11111","10000","10000","11110","10000","10000","11111"],"G":["01111","10000","10000","10111","10001","10001","01111"],
            "H":["10001","10001","10001","11111","10001","10001","10001"],"I":["11111","00100","00100","00100","00100","00100","11111"],
            "L":["10000","10000","10000","10000","10000","10000","11111"],"M":["10001","11011","10101","10101","10001","10001","10001"],
            "N":["10001","11001","11001","10101","10011","10011","10001"],"O":["01110","10001","10001","10001","10001","10001","01110"],
            "P":["11110","10001","10001","11110","10000","10000","10000"],"R":["11110","10001","10001","11110","10100","10010","10001"],
            "S":["01111","10000","10000","01110","00001","00001","11110"],"T":["11111","00100","00100","00100","00100","00100","00100"],
            "U":["10001","10001","10001","10001","10001","10001","01110"],"Y":["10001","10001","01010","00100","00100","00100","00100"]]
        let unit=height/7,advance=unit*6,total=Float(text.count)*advance
        for (i,char) in text.enumerated() {
            guard let rows=glyphs[char] else {continue}
            for (row,line) in rows.enumerated() {for (col,value) in line.enumerated() where value=="1" {
                let q=center+tangent*(-total/2+Float(i)*advance+(Float(col)+0.5)*unit)+V(0,(3-Float(row))*unit,0)
                ccOrientedBox(q,tangent,V(unit*0.84,unit*0.84,0.018),material)
            }}
        }
    }
}
