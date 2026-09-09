import Foundation
import simd

/// Metres in the shared Willis-origin east/south projection. The main wing is
/// aligned to OSM way 125667497; the plan proportions follow HABS IL-1005.
enum RobieHouseLayout {
    typealias V = SIMD3<Float>
    static let center = V(3309.7, 0, 9917.1)
    static let east = simd_normalize(V(1, 0, -0.02))
    static let south = simd_normalize(V(0.02, 0, 1))
    static let groundFloor: Float = 0.25
    static let mainFloor: Float = 3.20
    static let mainCeiling: Float = 6.35
    static let upperFloor: Float = 6.62
    static let prow: Float = 13.2206 // 86 feet 9 inches, prow to prow.
    static let buildingID: Int64 = 125667497
    static func point(_ p: V) -> V { center + east*p.x + V(0,p.y,0) + south*p.z }
    static func point(_ x: Float, _ y: Float, _ z: Float) -> V { point(V(x,y,z)) }
    static func local(_ p: V) -> V { let d=p-center;return V(simd_dot(d,east),d.y,simd_dot(d,south)) }
    static let living = point(-8,4.85,1.55)
    static let dining = point(8.4,4.85,1.55)
    static let hearth = point(0.4,4.7,0)
    static let balcony = point(-8,4.85,4.3)
    static let westPorch = point(-16.0,4.85,0)
    static let entry = point(-5.8,1.9,-4.8)
    static let garden = point(-8,1.9,9.5)
}

private struct RobiePalette {
    let brick: [UInt32], mortar: UInt32, stone: UInt32, oak: UInt32, oakLight: UInt32
    let plaster: UInt32, roof: UInt32, roofJoint: UInt32, copper: UInt32, glass: UInt32
    let amber: UInt32, oliveGlass: UInt32, came: UInt32, rug: UInt32, rugAccent: UInt32
    let upholstery: UInt32, dark: UInt32, lens: UInt32, paving: UInt32, soil: UInt32, green: UInt32, flower: UInt32
}

extension EiffelBuilder {
    func robieHouse() {
        func material(_ c:V,_ r:Float = 0.7,metal:Float = 0,emission:Float = 0,pattern:Float = 0,transmission:Float = 0)->UInt32 {
            let id=UInt32(scene.materials.count)
            scene.materials.append(SceneMaterial(c,roughness:r,metallic:metal,emission:emission,pattern:pattern,transmission:transmission));return id
        }
        let p=RobiePalette(
            brick:[material(V(0.245,0.096,0.048),0.87,pattern:1),material(V(0.285,0.112,0.053),0.85,pattern:1),material(V(0.216,0.079,0.042),0.88,pattern:1),material(V(0.264,0.101,0.052),0.86,pattern:1)],
            mortar:material(V(0.38,0.315,0.215),0.94),stone:material(V(0.60,0.535,0.405),0.80,pattern:1),
            oak:material(V(0.135,0.064,0.024),0.47,pattern:3),oakLight:material(V(0.26,0.135,0.056),0.54,pattern:3),
            plaster:material(V(0.64,0.49,0.31),0.93),roof:material(V(0.21,0.078,0.046),0.83,pattern:1),
            roofJoint:material(V(0.112,0.052,0.027),0.84),copper:material(V(0.18,0.155,0.095),0.49,metal:0.68),
            glass:material(V(0.98,0.985,0.96),0.08,transmission:1),
            amber:material(V(0.95,0.61,0.20),0.16,transmission:1),oliveGlass:material(V(0.66,0.73,0.47),0.16,transmission:1),
            came:material(V(0.065,0.073,0.062),0.52,metal:0.75),rug:material(V(0.49,0.44,0.31),0.98),
            rugAccent:material(V(0.21,0.155,0.087),0.98),upholstery:material(V(0.18,0.19,0.15),0.94),dark:material(V(0.024,0.019,0.014),0.86),
            lens:material(V(1,0.79,0.50),0.6,emission:0.9),paving:material(V(0.45,0.415,0.34),0.93,pattern:1),
            soil:material(V(0.059,0.042,0.022),1),green:material(V(0.095,0.20,0.052),0.94),flower:material(V(0.62,0.21,0.055),0.88))
        robieGrounds(p)
        robieMainWing(p)
        robieServiceWing(p)
        robieBelvedere(p)
        robieInterior(p)
        robieLighting(p)
    }

    private func rb(_ c:V,_ size:V,_ m:UInt32) {orientedBox(RobieHouseLayout.point(c),RobieHouseLayout.east,V(0,1,0),RobieHouseLayout.south,size,m)}
    private func rq(_ a:V,_ b:V,_ c:V,_ d:V,_ m:UInt32) {quad(RobieHouseLayout.point(a),RobieHouseLayout.point(b),RobieHouseLayout.point(c),RobieHouseLayout.point(d),m)}
    private func rbeam(_ a:V,_ b:V,_ width:Float,_ depth:Float,_ m:UInt32) {beam(RobieHouseLayout.point(a),RobieHouseLayout.point(b),width,depth,m)}

    /// Real recessed courses and subtly varied Roman-brick faces. Vertical
    /// joints remain brick-colored, preserving Wright's horizontal emphasis.
    private func robieMasonry(_ c:V,_ size:V,_ p:RobiePalette) {
        rb(c,size,p.mortar)
        for side in 0..<4 {
            let normal:V = side==0 ? V(0,0,1):side==1 ? V(0,0,-1):side==2 ? V(1,0,0):V(-1,0,0)
            let tangent=V(normal.z,0,-normal.x),width=side<2 ? size.x:size.z
            let depth=side<2 ? size.z:size.x
            let courses=max(1,Int(ceil(size.y/0.068))),course=size.y/Float(courses)
            for row in 0..<courses {
                let bottom = -size.y/2+Float(row)*course+0.0055,top=bottom+course-0.011
                let offset=Float(row%3)*0.102
                let count=Int(ceil((width+offset)/0.306))
                for col in 0..<count {
                    let low=max(-width/2,-width/2-offset+Float(col)*0.306)
                    let high=min(width/2,-width/2-offset+Float(col+1)*0.306-0.002)
                    guard high>low else{continue}
                    let base=c+normal*(depth/2+0.009)
                    let a=base+tangent*low+V(0,bottom,0),b=base+tangent*high+V(0,bottom,0)
                    let cc=base+tangent*high+V(0,top,0),d=base+tangent*low+V(0,top,0)
                    let m=p.brick[(row*7+col*13+side)%p.brick.count]
                    rq(a,b,cc,d,m)
                    // Close piers and hearth retain their shallow return edges.
                    // Long courtyard walls keep only the displaced face: the
                    // masonry backing already closes the tiny recessed joints.
                    if max(size.x,size.z)<5 {
                        rq(a-normal*0.009,a,b,b-normal*0.009,m)
                        rq(d,cc,cc-normal*0.009,d-normal*0.009,m)
                    }
                }
            }
        }
    }

    private func robieHipRoof(_ low:V,_ high:V,_ rise:Float,_ p:RobiePalette) {
        let z=(low.z+high.z)/2,hip=min((high.z-low.z)/2,(high.x-low.x)/2)
        let a=V(low.x,low.y,low.z),b=V(high.x,low.y,low.z),c=V(high.x,low.y,high.z),d=V(low.x,low.y,high.z)
        let e=V(low.x+hip,low.y+rise,z),f=V(high.x-hip,low.y+rise,z)
        rq(a,e,f,b,p.roof);rq(d,c,f,e,p.roof)
        tri(RobieHouseLayout.point(a),RobieHouseLayout.point(d),RobieHouseLayout.point(e),p.roof)
        tri(RobieHouseLayout.point(b),RobieHouseLayout.point(f),RobieHouseLayout.point(c),p.roof)
        rb(V((low.x+high.x)/2,low.y-0.13,z),V(high.x-low.x,0.24,high.z-low.z),p.plaster)
        for pair in [(a,b),(b,c),(c,d),(d,a)] {rbeam(pair.0+V(0,-0.07,0),pair.1+V(0,-0.07,0),0.18,0.11,p.copper)}
        for row in 1..<18 {
            let t=Float(row)/18
            let left=low.x+hip*t,right=high.x-hip*t,y=low.y+rise*t+0.008
            for side:Float in [-1,1] {
                let zz=z+side*(high.z-low.z)/2*(1-t)
                rbeam(V(left,y,zz),V(right,y,zz),0.016,0.020,p.roofJoint)
                let count=max(1,Int((right-left)/0.31))
                for j in 0..<count {
                    let x=left+(Float(j)+Float(row%2)*0.5)*0.31
                    if x>right-0.18{continue}
                    let nextT=min(1,t+1/Float(18))
                    rbeam(V(x,y,zz),V(x,low.y+rise*nextT+0.009,z+side*(high.z-low.z)/2*(1-nextT)),0.009,0.010,p.roofJoint)
                }
            }
        }
        rbeam(e+V(0,0.03,0),f+V(0,0.03,0),0.12,0.11,p.roofJoint)
        for pair in [(a,e),(d,e),(b,f),(c,f)] {rbeam(pair.0+V(0,0.01,0),pair.1+V(0,0.01,0),0.085,0.055,p.roofJoint)}
    }

    /// Independent transmitting colored glass and raised metal came. Flattened
    /// diamonds follow the photo's floral grammar without embedding photo art.
    private func robieGlass(_ a:V,_ b:V,bottom:Float,height:Float,_ p:RobiePalette,door:Bool = false) {
        let tangent=simd_normalize(b-a),normal=V(-tangent.z,0,tangent.x),width=simd_distance(a,b)
        let middle=(a+b)/2+V(0,bottom+height/2,0)
        func pt(_ x:Float,_ y:Float,_ n:Float = 0)->V {middle+tangent*x+V(0,y,0)+normal*n}
        rq(pt(-width/2,-height/2),pt(width/2,-height/2),pt(width/2,height/2),pt(-width/2,height/2),p.glass)
        for x:Float in [-width/2,width/2] {rbeam(pt(x,-height/2),pt(x,height/2),0.062,0.11,p.oak)}
        for y:Float in [-height/2,height/2] {rbeam(pt(-width/2,y),pt(width/2,y),0.078,0.11,p.oak)}
        let w=width*0.36
        func lead(_ x:Float,_ y:Float,_ xx:Float,_ yy:Float) {rbeam(pt(x,y,0.008),pt(xx,yy,0.008),0.012,0.016,p.came)}
        for x:Float in [-w,-w*0.65,w*0.65,w] {lead(x,-height*0.44,x,height*0.44)}
        for y:Float in [-0.22,0,0.22] {
            let yy=y*height
            lead(-w,yy,0,yy+height*0.076);lead(0,yy+height*0.076,w,yy)
            lead(-w,yy,0,yy-height*0.076);lead(0,yy-height*0.076,w,yy)
            let diamond = abs(y)<0.01 ? p.amber:p.oliveGlass
            rq(pt(-width*0.085,yy,0.004),pt(0,yy-height*0.036,0.004),pt(width*0.085,yy,0.004),pt(0,yy+height*0.036,0.004),diamond)
        }
        for y:Float in [-0.43,-0.36,0.36,0.43] {
            lead(-w,y*height,-w*0.65,y*height);lead(w*0.65,y*height,w,y*height)
        }
        for side:Float in [-1,1] {
            for j in 0..<8 {
                let y=height*(-0.30+Float(j)*0.075)
                lead(side*w,y,side*w*0.65,y+height*0.036)
            }
        }
        if door {rbeam(pt(width*0.38,-height*0.10,0.11),pt(width*0.38,-height*0.04,0.11),0.022,0.035,p.copper)}
        scene.detailCount += 1
    }

    private func robieMainWing(_ p:RobiePalette) {
        let floor=RobieHouseLayout.mainFloor
        // Prow-shaped perimeter is genuinely hollow on both principal levels.
        let points:[V]=[V(-11.9,0,-3.2),V(11.9,0,-3.2),V(11.9,0,-1.30),V(13.2206,0,0),V(11.9,0,1.30),V(11.9,0,3.2),V(-11.9,0,3.2),V(-11.9,0,1.30),V(-13.2206,0,0),V(-11.9,0,-1.30)]
        for i in points.indices {
            let a=points[i],b=points[(i+1)%points.count]
            tri(RobieHouseLayout.point(V(0,0.25,0)),RobieHouseLayout.point(b+V(0,0.25,0)),RobieHouseLayout.point(a+V(0,0.25,0)),p.oakLight)
            tri(RobieHouseLayout.point(V(0,floor,0)),RobieHouseLayout.point(b+V(0,floor,0)),RobieHouseLayout.point(a+V(0,floor,0)),p.oakLight)
        }
        rb(V(0,3.01,0),V(23.8,0.35,6.4),p.stone)
        // Major brick piers support the roof while the glazing remains open.
        for x:Float in [-11.45,11.45] {for z:Float in [-2.85,2.85] {
            robieMasonry(V(x,3.29,z),V(1.32,6.08,0.76),p)
            rb(V(x,0.18,z),V(1.48,0.30,0.90),p.stone)
            rb(V(x,3.20,z),V(1.46,0.16,0.92),p.stone)
        }}
        for level in [Float(0.25),floor] {
            let h:Float=level<1 ? 2.45:2.92
            for side:Float in [-1,1] {
                let z=side*3.2
                for i in 0..<18 {
                    let x = -10.8+Float(i)*1.2
                    // Main upper-hall connection on the north side stays open.
                    if side<0 && x > -3.7 && x < 4.2 {continue}
                    robieGlass(V(x,0,z),V(x+1.2,0,z),bottom:level+0.06,height:h,p,door:true)
                }
                rb(V(0,level+0.10,z),V(21.65,0.18,0.13),p.oak)
                rb(V(0,level+h+0.1,z),V(21.65,0.16,0.16),p.oak)
            }
            for side:Float in [-1,1] {
                let a=V(side*11.9,0,-1.3),b=V(side*13.2206,0,0),c=V(side*11.9,0,1.3)
                for pair in [(a,b),(b,c)] {
                    for j in 0..<3 {
                        robieGlass(simd_mix(pair.0,pair.1,V(repeating:Float(j)/3)),simd_mix(pair.0,pair.1,V(repeating:Float(j+1)/3)),bottom:level+0.65,height:h-0.60,p)
                    }
                    let mid=(pair.0+pair.1)/2+V(0,level+0.36,0),t=simd_normalize(pair.1-pair.0),n=V(-t.z,0,t.x)
                    orientedBox(RobieHouseLayout.point(mid),RobieHouseLayout.east*t.x+RobieHouseLayout.south*t.z,V(0,1,0),RobieHouseLayout.east*n.x+RobieHouseLayout.south*n.z,V(simd_distance(pair.0,pair.1),0.68,0.18),p.oak)
                }
                for z:Float in [-2.04,2.04] {
                    // One west leaf is held open toward the outdoor room.
                    if side<0 && z>0 && level>1 {
                        robieGlass(V(-12.00,0,1.38),V(-13.01,0,1.56),bottom:level+0.05,height:h,p,door:true)
                    } else {
                        robieGlass(V(side*11.9,0,z-0.60),V(side*11.9,0,z+0.60),bottom:level+0.05,height:h,p,door:true)
                    }
                }
            }
        }
        // The narrow south balcony and west outdoor room remain walkable.
        rb(V(0,3.10,4.3),V(23.3,0.20,2.2),p.stone)
        robieMasonry(V(0,3.60,5.35),V(20.8,0.90,0.38),p)
        rb(V(0,4.12,5.35),V(21.0,0.14,0.58),p.stone)
        rb(V(0,3.13,5.40),V(21.6,0.16,0.65),p.stone)
        for x:Float in [-10.65,10.65] {
            robieMasonry(V(x,2.0,5.0),V(1.35,3.7,1.2),p)
            robiePlanter(V(x,4.2,5.0),V(1.50,0.45,1.36),p)
        }
        rb(V(-16.05,3.06,0),V(5.70,0.28,6.9),p.stone)
        robieMasonry(V(-18.75,1.9,0),V(0.45,3.45,7.1),p)
        rb(V(-18.75,3.66,0),V(0.64,0.16,7.25),p.stone)
        for z:Float in [-3.45,3.45] {
            robieMasonry(V(-16.05,1.85,z),V(5.8,3.40,0.38),p)
            rb(V(-16.05,3.63,z),V(5.85,0.16,0.62),p.stone)
        }
        for z:Float in [-2.8,2.8] {
            robiePlanter(V(-18.7,3.81,z),V(1.24,0.20,1.12),p)
            robieTrailingPlant(V(-19.08,3.95,z),p)
        }
        robieHipRoof(V(-19.25,6.52,-4.65),V(15.15,6.52,4.65),0.82,p)
    }

    private func robieServiceWing(_ p:RobiePalette) {
        // North offset wing: guest room west, kitchen center, garage/service east.
        rb(V(10,0.21,-6.55),V(30.0,0.24,6.3),p.stone)
        robieMasonry(V(10,1.55,-9.65),V(30,2.7,0.40),p)
        robieMasonry(V(25,3.26,-6.55),V(0.44,6.1,6.60),p)
        rb(V(10,3.15,-6.55),V(30,0.20,6.50),p.stone)
        for z:Float in [-9.65,-3.50] {
            robieMasonry(V(10,3.60,z),V(30,0.90,0.38),p)
            rb(V(10,4.10,z),V(30.2,0.14,0.56),p.stone)
            for j in 0..<23 {
                let x = -4.7+Float(j)*1.28
                robieGlass(V(x,0,z),V(x+1.15,0,z),bottom:4.24,height:1.78,p)
                rb(V(x-0.055,5.18,z),V(0.13,2.08,0.30),p.oak)
            }
        }
        // Three south-facing doors are part of the architecture, not street decals.
        for x:Float in [15.4,19.1,22.8] {
            rb(V(x,1.55,-3.48),V(3.22,2.60,0.16),p.oak)
            for j in 0..<12 {rb(V(x-1.48+Float(j)*0.267,1.18,-3.37),V(0.022,1.86,0.035),p.oakLight)}
            for j in 0..<6 {
                let xx=x-1.42+Float(j)*0.48
                robieGlass(V(xx,0,-3.365),V(xx+0.42,0,-3.365),bottom:2.03,height:0.66,p)
            }
            for dx:Float in [-1.74,1.74] {robieMasonry(V(x+dx,1.63,-3.50),V(0.35,2.86,0.46),p)}
        }
        // Ground entrance is tucked behind the west guest room projection.
        robieMasonry(V(-5.0,1.68,-8.0),V(0.42,2.9,3.1),p)
        robieMasonry(V(-5.0,3.80,-6.55),V(0.42,1.15,6.30),p)
        for z:Float in [-8.9,-7.7,-6.5,-5.3] {robieGlass(V(-5,0,z),V(-5,0,z+1.1),bottom:4.30,height:1.70,p)}
        rb(V(-5.7,2.84,-4.7),V(2.0,0.22,2.0),p.stone)
        robieMasonry(V(-5.0,1.75,-3.45),V(0.42,2.8,1.4),p)
        rb(V(-4.90,1.67,-4.80),V(0.15,2.70,1.10),p.oak)
        rb(V(8.5,6.21,-6.55),V(33.4,0.22,8.0),p.plaster)
        robieHipRoof(V(-7.1,6.39,-10.8),V(26.1,6.39,-2.8),0.73,p)
        // Real upper hall links the principal rooms to the compact stair core.
        rb(V(0,3.12,-3.4),V(8.0,0.16,3.0),p.oakLight)
        rb(V(0,6.23,-4.8),V(8.0,0.20,0.35),p.oak)
    }

    private func robieBelvedere(_ p:RobiePalette) {
        // Set-back third floor is smaller than either long lower roof.
        let c=V(1.1,0,-2.65),s=V(11.8,0,9.3)
        rb(c+V(0,6.55,0),V(s.x,0.24,s.z),p.stone)
        for z:Float in [-7.30,2.0] {
            robieMasonry(V(1.1,7.12,z),V(11.8,0.98,0.42),p)
            rb(V(1.1,7.67,z),V(12.1,0.16,0.60),p.stone)
            for j in 0..<9 {
                let x = -4.58+Float(j)*1.28
                robieGlass(V(x,0,z),V(x+1.15,0,z),bottom:7.78,height:1.43,p)
                rb(V(x-0.05,8.52,z),V(0.12,1.60,0.20),p.oak)
            }
        }
        for x:Float in [-4.80,7.00] {
            robieMasonry(V(x,7.10,-2.65),V(0.42,1.0,9.3),p)
            rb(V(x,7.67,-2.65),V(0.60,0.16,9.55),p.stone)
            for j in 0..<7 {
                let z = -6.98+Float(j)*1.25
                robieGlass(V(x,0,z),V(x,0,z+1.13),bottom:7.78,height:1.43,p)
                rb(V(x,8.52,z-0.05),V(0.20,1.60,0.12),p.oak)
            }
        }
        robieHipRoof(V(-7.0,9.48,-9.0),V(9.1,9.48,3.7),1.03,p)
        // Chimney is broad and low; its two flues continue the pierced hearth.
        robieMasonry(V(0.65,8.61,-0.16),V(2.15,4.58,3.72),p)
        rb(V(0.65,10.97,-0.16),V(2.38,0.20,3.97),p.stone)
        for z:Float in [-1.4,1.08] {rb(V(0.65,11.09,z),V(1.32,0.07,0.8),p.dark)}
        robieMasonry(V(7.65,5.35,-9.1),V(0.95,9.9,0.80),p)
        rb(V(7.65,10.37,-9.1),V(1.12,0.15,0.99),p.stone)
    }

    private func robieInterior(_ p:RobiePalette) {
        // Principal level keeps a continuous south aisle around the hearth.
        rb(V(-5.8,3.225,0),V(10.3,0.035,5.50),p.rug)
        rb(V(7.1,3.225,0),V(8.1,0.035,5.50),p.rug)
        for x in stride(from:Float(-10),through:11,by:1.4) {for z:Float in [-1.9,0,1.9] {
            if x > -1.2 && x < 2.8 {continue}
            rb(V(x,3.247,z),V(0.28,0.006,0.032),p.rugAccent)
            rb(V(x,3.247,z),V(0.05,0.006,0.22),p.rugAccent)
        }}
        // Brick hearth with visible firebox, stone lintel and a genuine opening
        // above the mantle. Flues at each side frame the continuing ceiling.
        for z:Float in [-1.33,1.15] {robieMasonry(V(0.65,4.79,z),V(2.15,3.18,0.65),p)}
        robieMasonry(V(0.65,4.91,-0.09),V(2.15,1.37,1.73),p)
        rb(V(0.65,4.18,-0.09),V(2.38,0.19,2.30),p.stone)
        rb(V(0.65,5.68,-0.09),V(2.22,0.17,1.73),p.stone)
        rb(V(0.65,3.32,-0.09),V(2.42,0.18,2.78),p.stone)
        rb(V(0.65,3.81,-0.09),V(0.18,0.78,1.58),p.dark)
        for x:Float in [-0.12,1.45] {for z in stride(from:Float(-0.7),through:0.60,by:0.20) {rbeam(V(x,3.36,z),V(x,3.94,z),0.030,0.030,p.came)}}
        // Entry stair north of the hearth, wood privacy screen, inglenook bench.
        for step in 0..<17 {
            let y=0.25+Float(step+1)*(2.95/17),z = -1.72-Float(step)*0.17
            rb(V(1.9,y-0.065,z),V(1.28,0.13,0.18),p.oak)
        }
        rb(V(-1.22,3.66,-1.62),V(3.0,0.83,0.68),p.oak)
        rb(V(-1.22,4.12,-1.62),V(2.90,0.10,0.65),p.rugAccent)
        rb(V(-1.5,4.6,-2.40),V(3.0,0.75,0.16),p.plaster)
        for x in stride(from:Float(-2.95),through:0,by:0.13) {rb(V(x,5.27,-2.40),V(0.027,0.69,0.065),p.oak)}
        rb(V(-1.5,5.63,-2.40),V(3.0,0.10,0.18),p.oak)
        // Stepped oak ceiling and light screens reproduce the restored spatial
        // hierarchy: high central plaster, lowered wood-framed perimeter.
        rb(V(0,6.36,0),V(23.75,0.11,6.3),p.plaster)
        for side:Float in [-1,1] {
            rb(V(0,6.02,side*2.6),V(23.65,0.25,1.05),p.plaster)
            for z:Float in [1.99,3.12] {rb(V(0,5.85,side*z),V(23.70,0.10,0.115),p.oak)}
            rb(V(0,6.30,side*1.91),V(23.6,0.10,0.11),p.oak)
            rb(V(0,6.12,side*1.98),V(23.6,0.40,0.10),p.oak)
        }
        for x in stride(from:Float(-10.8),through:11.0,by:2.4) {
            rb(V(x,6.24,0),V(0.13,0.15,3.85),p.oak)
            for side:Float in [-1,1] {
                rb(V(x,6.02,side*2.35),V(0.13,0.45,0.95),p.oak)
                rb(V(x,5.80,side*2.65),V(0.13,0.10,1.03),p.oak)
                robieLayLight(V(x+1.15,5.858,side*2.58),p)
            }
        }
        // The historic table/chair arrangement is an interpretive furnishing
        // study; it is kept north of the clear walkthrough aisle.
        rb(V(6.7,3.95,-0.40),V(3.65,0.11,1.15),p.oak)
        for x:Float in [5.15,8.25] {for z:Float in [-0.82,0.02] {rb(V(x,3.59,z),V(0.12,0.67,0.12),p.oak)}}
        for x:Float in [5.3,6.7,8.1] {for side:Float in [-1,1] {
            let z:Float = -0.4+side*1.12
            rb(V(x,3.69,z),V(0.48,0.08,0.45),p.oak)
            for dx:Float in [-0.205,0.205] {for dz:Float in [-0.19,0.19] {rb(V(x+dx,3.47,z+dz),V(0.042,0.47,0.042),p.oak)}}
            let back=z+side*0.21
            for dx:Float in [-0.205,0.205] {rb(V(x+dx,4.03,back),V(0.052,1.48,0.048),p.oak)}
            rb(V(x,4.76,back),V(0.48,0.09,0.060),p.oak)
            for j in 0..<5 {rb(V(x-0.15+Float(j)*0.075,4.27,back),V(0.024,0.95,0.030),p.oak)}
        }}
        for x:Float in [-8.6,-5.1] {
            rb(V(x,3.59,-2.10),V(2.1,0.68,0.83),p.oak)
            rb(V(x,3.95,-2.05),V(1.92,0.16,0.68),p.upholstery)
            rb(V(x,4.27,-2.42),V(1.98,0.68,0.15),p.upholstery)
            for dx:Float in [-1.02,1.02] {rb(V(x+dx,4.13,-2.10),V(0.15,0.96,0.90),p.oak)}
        }
        for x in stride(from:Float(-9.7),through:10,by:2.4) {
            if x > -3.2 && x < 3.2 {continue}
            rb(V(x,3.61,-3.00),V(0.94,0.80,0.27),p.oak)
            for j in 0..<13 {rb(V(x-0.42+Float(j)*0.069,3.63,-2.84),V(0.024,0.62,0.055),p.dark)}
        }
        // Lower rooms are visible from the garden; their furniture is modest.
        rb(V(-6,1.14,0),V(2.6,0.15,1.5),p.oak)
        rb(V(-6,1.235,0),V(2.35,0.035,1.28),p.green)
        for x:Float in [-6.9,-5.1] {for z:Float in [-0.48,0.48] {rb(V(x,0.70,z),V(0.15,0.86,0.15),p.oak)}}
    }

    private func robieLayLight(_ c:V,_ p:RobiePalette) {
        rb(c,V(1.95,0.028,0.63),p.lens)
        for z:Float in [-0.33,0.33] {rb(c+V(0,-0.019,z),V(2.05,0.040,0.055),p.oak)}
        for x:Float in [-1.0,1.0] {rb(c+V(x,-0.019,0),V(0.055,0.04,0.68),p.oak)}
        for i in 0..<12 {
            let x = -0.88+Float(i)*0.16
            rbeam(c+V(x,-0.03,-0.28),c+V(x+0.26,-0.03,0),0.018,0.022,p.oak)
            rbeam(c+V(x+0.26,-0.03,0),c+V(x,-0.03,0.28),0.018,0.022,p.oak)
        }
    }

    private func robiePlanter(_ c:V,_ size:V,_ p:RobiePalette) {
        rb(c,size,p.stone)
        rb(c+V(0,size.y/2+0.012,0),V(max(0.1,size.x-0.16),0.035,max(0.1,size.z-0.16)),p.soil)
        let count=max(3,Int(size.x/0.22))
        for j in 0..<count {
            let x=(Float(j)+0.5)*size.x/Float(count)-size.x/2
            for side:Float in [-1,1] {
                let base=c+V(x,size.y/2+0.03,side*size.z*0.20)
                for k in 0..<4 {
                    let a=Float(k)*Float.pi/2+Float(j)*0.61
                    let end=base+V(cos(a)*0.17,0.14+Float(j%3)*0.025,sin(a)*0.15)
                    rbeam(base,end,0.022,0.026,p.green)
                    let tangent=V(-sin(a)*0.08,0,cos(a)*0.08)
                    rq(base, end+tangent, end+V(0,0.08,0),end-tangent,p.green)
                }
                if j%3==0 {rb(base+V(0,0.21,0),V(0.07,0.055,0.07),p.flower)}
            }
        }
    }

    private func robieTrailingPlant(_ c:V,_ p:RobiePalette) {
        for stem in 0..<7 {
            let z=(Float(stem)-3)*0.14,length:Float=1.05+Float((stem*7)%5)*0.18
            for j in 0..<14 {
                let t=Float(j)/13,base=c+V(-0.05-sin(t*2.1)*0.06,-t*length,z+sin(t*6+Float(stem))*0.04)
                if j<13 {rbeam(base,base+V(0,-length/13,0.018),0.012,0.012,p.green)}
                let w:Float=0.095+Float((stem+j)%3)*0.019
                rq(base+V(-0.025,w,0),base+V(-0.045,0,w),base+V(-0.025,-w,0),base+V(-0.045,0,-w),p.green)
            }
        }
    }

    private func robieGrounds(_ p:RobiePalette) {
        rb(V(4.1,0.055,-0.85),V(48.0,0.10,22.0),p.paving)
        rb(V(-1.4,0.13,7.0),V(29.4,0.08,3.0),grass)
        rb(V(17.2,0.14,0.70),V(14.3,0.08,6.35),p.paving)
        robieMasonry(V(-1.20,0.66,8.30),V(27.8,1.05,0.34),p)
        rb(V(-1.2,1.23,8.30),V(28.05,0.16,0.53),p.stone)
        for x:Float in [-15.25,12.85] {
            robieMasonry(V(x,0.76,8.3),V(0.82,1.28,0.82),p)
            rb(V(x,1.46,8.3),V(1.14,0.16,1.14),p.stone)
            cylinder(RobieHouseLayout.point(x,1.55,8.3),RobieHouseLayout.point(x,1.80,8.3),0.38,p.stone,segments:32)
            cylinder(RobieHouseLayout.point(x,1.82,8.3),RobieHouseLayout.point(x,2.04,8.3),0.65,p.stone,segments:40)
            robiePlanter(V(x,2.07,8.3),V(1.20,0.10,1.20),p)
        }
        robieMasonry(V(25.45,1.50,0.5),V(0.42,2.8,14.8),p)
        rb(V(25.45,2.99,0.5),V(0.58,0.18,15),p.stone)
        robieMasonry(V(19.40,1.5,7.8),V(12.5,2.8,0.42),p)
        rb(V(19.40,2.99,7.8),V(12.7,0.18,0.58),p.stone)
        // Side entry paving is legible as a quiet, indirect route from Woodlawn.
        rb(V(-12,0.16,-6.1),V(16.0,0.06,1.55),p.stone)
        for i in 0..<13 {rb(V(-19.5+Float(i)*1.12,0.20,-6.1),V(0.015,0.006,1.55),p.mortar)}
        robiePlanter(V(-12,0.39,-7.20),V(14.5,0.46,0.66),p)
        for x:Float in [-9,-5,5,9] {robiePlanter(V(x,0.27,6.45),V(1.65,0.25,0.70),p)}
        for j in 0..<22 {rb(V(-18.8+Float(j)*2.05,0.112,9.5),V(0.017,0.006,1.28),p.mortar)}
    }

    private func robieLighting(_ p:RobiePalette) {
        // Warm practical fixtures make the glass and oak readable at night.
        // Exterior accents are deliberately modest, not invented colored floods.
        for x in stride(from:Float(-10.8),through:11.0,by:2.4) {for side:Float in [-1,1] {
            let q=V(x,5.72,side*1.94)
            rb(q+V(0,0.12,0),V(0.26,0.065,0.27),p.copper)
            cylinder(RobieHouseLayout.point(q+V(0,-0.085,0)),RobieHouseLayout.point(q+V(0,0.05,0)),0.105,p.lens,segments:16)
            scene.lights.append(NightLighting.source(RobieHouseLayout.point(q+V(0,-0.11,0)),power:3.0,color:V(1,0.74,0.43),range:5.5,radius:0.13,alwaysOn:true))
        }}
        for x:Float in [-16.5,-8,0,8,20] {
            let q=V(x,0.28,7.4)
            rb(q,V(0.20,0.16,0.16),p.copper)
            scene.lights.append(NightLighting.source(RobieHouseLayout.point(q+V(0,0.12,0)),toward:RobieHouseLayout.point(x,4.5,3.8),power:14,color:V(1,0.70,0.36),range:10,radius:0.18,outerDegrees:68,innerDegrees:42))
        }
        // Small interpreted ground washes retain the west planter/limestone
        // silhouette visible in the evening reference without lighting the sky
        // or turning the sheltered roof into an invented floodlit monument.
        for z:Float in [-2.7,2.7] {
            let q=V(-20,0.35,z)
            rb(q-V(0,0.10,0),V(0.18,0.16,0.16),p.copper)
            scene.lights.append(NightLighting.source(RobieHouseLayout.point(q),toward:RobieHouseLayout.point(-18.7,3.9,z),power:22,color:V(1,0.76,0.47),range:8,radius:0.18,outerDegrees:80,innerDegrees:48))
        }
        for x:Float in [-16,-8,0,8,19] {
            let q=V(x,2.68,-4.6)
            scene.lights.append(NightLighting.source(RobieHouseLayout.point(q),toward:RobieHouseLayout.point(x,0.1,-5.8),power:4,color:V(1,0.77,0.49),range:6,radius:0.16))
        }
        for x:Float in [-6,6] {
            scene.lights.append(NightLighting.source(RobieHouseLayout.point(x,2.65,0),power:4,color:V(1,0.77,0.47),range:7,radius:0.25,alwaysOn:true))
        }
        for x:Float in [-2.8,5.1] {
            scene.lights.append(NightLighting.source(RobieHouseLayout.point(x,8.93,-2.9),power:6,color:V(1,0.74,0.43),range:7,radius:0.30))
        }
        for x:Float in [12,22] {
            scene.lights.append(NightLighting.source(RobieHouseLayout.point(x,5.80,-6.4),power:4,color:V(1,0.77,0.49),range:6,radius:0.25))
        }
    }
}
