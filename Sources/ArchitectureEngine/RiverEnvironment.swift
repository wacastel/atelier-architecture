import Foundation
import simd

/// Pont d'Iéna dimensions and reference interpretation are documented in docs/RIVER.md.
/// The near-river coordinate frame is shared with ParisEnvironment.swift.
enum RiverView {
    static let stop = TourStop(id: 8, title: "The Seine & Pont d’Iéna", subtitle: "FIVE STONE ARCHES · RIVER CRUISER", detail: "Follow the Seine past a detailed sightseeing cruiser and the five masonry arches of Pont d’Iéna. Dressed stone, quay fittings, balustrades and warm riverfront lighting reflect in multi-scale ripples. The boat is an original interpretation of Paris river craft.", pose: CameraPose(position: SIMD3(122, 9, -290), target: SIMD3(0, 14, -180), fov: 58))
}

extension EiffelBuilder {
    func riverMaterial(_ c: V, roughness: Float = 0.65, metallic: Float = 0, emission: Float = 0, pattern: Float = 0) -> UInt32 {
        let index = UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(c, roughness: roughness, metallic: metallic, emission: emission, pattern: pattern))
        return index
    }

    func riverEnvironment() {
        let river = riverMaterial(V(0.018,0.045,0.040),roughness:0.11,pattern:9)
        let stone = riverMaterial(V(0.56,0.52,0.43),roughness:0.86,pattern:10)
        let coping = riverMaterial(V(0.66,0.62,0.53),roughness:0.72,pattern:10)
        let darkStone = riverMaterial(V(0.32,0.32,0.26),roughness:0.94,pattern:10)
        let asphalt = riverMaterial(V(0.065,0.070,0.067),roughness:0.92,pattern:11)
        quad(V(-4500,-5.2,-297.5),V(-4500,-5.2,-142.5),V(4500,-5.2,-142.5),V(4500,-5.2,-297.5),river)
        for side: Float in [-1,1] {
            let bank: Float = -220+side*77.5
            let outer: Float = bank+side*11.5
            // River wall, low waterside promenade, upper retaining wall, coping.
            box(V(0,-4.05,bank+side*0.7),V(9000,2.4,1.4),darkStone)
            box(V(0,-2.9,bank+side*5.9),V(9000,0.35,11.8),pavement)
            box(V(0,-1.5,outer+side*0.6),V(9000,3.0,1.2),stone)
            box(V(0,0.10,outer+side*0.6),V(9000,0.2,1.5),coping)
            box(V(0,-2.75,bank+side*0.5),V(9000,0.18,1.1),coping)
            for x in stride(from:Float(-610),through:Float(610),by:14) where abs(x)>21 {
                // Quay bollards and actual torus mooring rings.
                cylinder(V(x,-2.75,bank+side*1.8),V(x,-2.25,bank+side*1.8),0.15,ironDark,segments:12)
                cylinder(V(x-0.25,-2.40,bank+side*1.8),V(x+0.25,-2.40,bank+side*1.8),0.12,ironDark,segments:10)
                riverTorus(V(x,-3.6,bank-side*0.022),V(0,0,1),major:0.21,minor:0.034,material:ironDark)
                if Int(x+610)%28==0 { streetLamp(V(x,-2.72,bank+side*7.6)) }
            }
            for x in stride(from:Float(-600),through:Float(600),by:110) where abs(x)>35 {
                riverStaircase(x:x,bank:bank,side:side,material:stone)
            }
            // Top promenade safety rail and narrow square piers, kept away from access.
            for x in stride(from:Float(-650),through:Float(650),by:2.5) where abs(x)>19 {
                cylinder(V(x,0.2,outer),V(x,1.25,outer),0.029,ironDark,segments:6)
            }
            for y: Float in [0.48,1.26] {
                cylinder(V(-650,y,outer),V(-19,y,outer),0.031,ironDark,segments:6)
                cylinder(V(19,y,outer),V(650,y,outer),0.031,ironDark,segments:6)
            }
        }
        pontDIena(stone:stone,coping:coping,darkStone:darkStone,asphalt:asphalt)
        riverCruiser(center:V(86,-5.2,-205))
        // A small floating landing stage with access gangway at Port de la Bourdonnais.
        let deck: V = V(143,-4.2,-153)
        box(deck,V(60,0.85,9),ironDark)
        box(deck+V(0,0.5,0),V(59,0.15,8.6),timber)
        for x: Float in [116,129,143,157,170] {
            for z: Float in [-156.8,-149.2] {
                cylinder(V(x,-3.62,z),V(x,-2.65,z),0.036,ironLight,segments:8)
                cylinder(V(x,-4.95,z),V(x,-4.18,z),0.19,ironDark,segments:10)
            }
        }
        for z: Float in [-156.8,-149.2] { cylinder(V(115.7,-2.65,z),V(170.3,-2.65,z),0.04,ironLight,segments:8) }
        beam(V(141,-2.68,-139.2),V(141,-3.56,-148.8),2.0,0.13,ironLight)
        for sx: Float in [-1,1] { beam(V(141+sx*1,-1.65,-139.2),V(141+sx*1,-2.5,-148.8),0.045,0.045,ironLight) }
    }

    private func riverStaircase(x:Float,bank:Float,side:Float,material:UInt32) {
        let start=bank+side*3.3
        for i in 0..<16 {
            let t=Float(i), y:Float = -2.72+t*0.18
            box(V(x,y-0.10,start+side*t*0.50),V(3.4,0.2,0.50),material)
        }
        for sx: Float in [-1,1] {
            let a=V(x+sx*1.65,-1.70,start),b=V(x+sx*1.65,1.02,start+side*7.5)
            beam(a,b,0.042,0.042,ironDark)
            for i in 0...4 { let t=Float(i)/4; let p=a+(b-a)*t; cylinder(p-V(0,1,0),p,0.031,ironDark,segments:6) }
        }
    }

    private func pontDIena(stone:UInt32,coping:UInt32,darkStone:UInt32,asphalt:UInt32) {
        let width: Float = 35, low:Float = -2.2, rise:Float = 3.4, span:Float = 28
        let radius = (span*span*0.25+rise*rise)/(2*rise)
        let centerY = low+rise-radius
        let angle = asin(span*0.5/radius)
        // Five truly open circular segment arches, with four intermediate piers.
        // Every wedge has its own curved intrados; the road does not fill the openings.
        for arch in 0..<5 {
            let zCenter:Float = -283.5+Float(arch)*31.75
            for i in 0..<48 {
                let a = -angle+Float(i)*2*angle/48, b = -angle+Float(i+1)*2*angle/48
                let z0=zCenter+radius*sin(a),z1=zCenter+radius*sin(b)
                let y0=centerY+radius*cos(a),y1=centerY+radius*cos(b)
                quad(V(-width/2,y0,z0),V(width/2,y0,z0),V(width/2,y1,z1),V(-width/2,y1,z1),stone)
                for sx:Float in [-1,1] {
                    let x=sx*width/2
                    quad(V(x,y0,z0),V(x,y1,z1),V(x,2.28,z1),V(x,2.28,z0),stone)
                }
            }
            // Dressed voussoir ring projects from the spandrel on both faces.
            for sx:Float in [-1,1] {
                for i in 0..<31 {
                    let a = -angle+Float(i)*2*angle/31+0.00055
                    let b = -angle+Float(i+1)*2*angle/31-0.00055
                    let outer=radius+0.62, x=sx*17.57
                    let p0=V(x,centerY+radius*cos(a),zCenter+radius*sin(a))
                    let p1=V(x,centerY+radius*cos(b),zCenter+radius*sin(b))
                    let p2=V(x,centerY+outer*cos(b),zCenter+outer*sin(b))
                    let p3=V(x,centerY+outer*cos(a),zCenter+outer*sin(a))
                    quad(p0,p1,p2,p3,i%7==0 ? stone:coping)
                    quad(p0,p0-V(sx*0.1,0,0),p1-V(sx*0.1,0,0),p1,coping)
                }
                // Projecting crown keystone and weathered crown moulding.
                box(V(sx*17.66,1.88,zCenter),V(0.25,0.83,0.9),coping)
            }
        }
        for pier in 0..<4 {
            let z:Float = -267.625+Float(pier)*31.75
            box(V(0,-2.24,z),V(width,8.97,3.75),stone)
            for sx:Float in [-1,1] {
                let p0=V(sx*17.5,-6.8,z-1.875),p1=V(sx*19.8,-6.8,z),p2=V(sx*17.5,-6.8,z+1.875)
                let height:Float=5.4
                quad(p0,p1,p1+V(0,height,0),p0+V(0, height,0),darkStone)
                quad(p1,p2,p2+V(0,height,0),p1+V(0,height,0),darkStone)
                tri(p0+V(0,height,0),p1+V(0,height,0),p2+V(0,height,0),coping)
                riverEagleRelief(V(sx*17.58,0.72,z),normal:V(sx,0,0),material:coping)
                scene.lights.append(NightLighting.source(V(sx*20.2,-0.9,z),toward:V(sx*17.4,1.2,z),power:30,color:V(1,0.73,0.43),range:18,radius:0.28,outerDegrees:82,innerDegrees:50))
            }
        }
        box(V(0,2.46,-220),V(35,0.36,155),stone)
        box(V(0,2.68,-220),V(22,0.08,155),asphalt)
        for sx:Float in [-1,1] {
            box(V(sx*14.2,2.80,-220),V(6.5,0.22,155),pavement)
            box(V(sx*11.0,2.79,-220),V(0.25,0.34,155),coping)
            // Multi-part cornice below the stone parapet.
            for layer in 0..<3 { box(V(sx*(17.45+Float(layer)*0.045),2.08+Float(layer)*0.19,-220),V(0.4+Float(layer)*0.17,0.17,156),coping) }
            box(V(sx*17.02,3.02,-220),V(0.80,0.28,156),coping)
            box(V(sx*17.02,4.10,-220),V(0.92,0.22,156),coping)
            for z in stride(from:Float(-296.8),through:Float(-143.2),by:0.86) {
                // Profiled stone balusters: narrow waist, broad caps, stepped feet.
                box(V(sx*17.02,3.22,z),V(0.43,0.15,0.40),coping)
                cylinder(V(sx*17.02,3.29,z),V(sx*17.02,3.89,z),0.11,coping,segments:8)
                ellipsoid(V(sx*17.02,3.53,z),V(0.18,0.22,0.18),coping,segments:8,rings:5)
                box(V(sx*17.02,3.94,z),V(0.42,0.11,0.39),coping)
            }
            for z in stride(from:Float(-297.5),through:Float(-142.5),by:31) {
                box(V(sx*17.02,3.51,z),V(1.05,1.12,1.08),coping)
                box(V(sx*17.02,4.17,z),V(1.16,0.18,1.19),coping)
                riverBridgeLamp(V(sx*15.4,2.9,z),material:ironDark)
            }
            for z:Float in [-305,-135] {
                box(V(sx*16.7,0.55,z),V(4.4,1.1,5.3),stone)
                box(V(sx*16.7,1.3,z),V(3.8,0.4,4.6),coping)
                riverHorseGroup(V(sx*16.7,1.52,z),facing:sx,material:coping)
            }
        }
        // Sloped access from the bridge road to the original plaza elevation.
        for end:Float in [-1,1] {
            let edge:Float = -220+end*77.5, finish=edge+end*25
            quad(V(-17.5,2.64,edge),V(17.5,2.64,edge),V(17.5,0.18,finish),V(-17.5,0.18,finish),pavement)
        }
    }

    private func riverEagleRelief(_ p:V,normal n:V,material:UInt32) {
        let t=V(0,0,1)
        riverTorus(p+n*0.04,n,major:0.92,minor:0.07,material:material)
        ellipsoid(p+n*0.12,V(0.17,0.58,0.23),material,segments:10,rings:8)
        ellipsoid(p+V(0,0.56,0)+n*0.19,V(0.17,0.19,0.18),material,segments:10,rings:6)
        for side:Float in [-1,1] {
            for feather in 0..<7 {
                let t0=Float(feather)/6
                beam(p+t*(side*0.1)+V(0,0.18,0)+n*0.15,p+t*(side*(1.0-t0*0.27))+V(0,0.50-t0*0.70,0)+n*0.13,0.105,0.12,material)
            }
        }
    }

    private func riverBridgeLamp(_ p:V,material:UInt32) {
        cylinder(p,p+V(0,5.3,0),0.075,material,segments:12)
        cylinder(p,p+V(0,0.7,0),0.20,material,segments:12)
        for y:Float in [0.75,3.9,5.15] { riverTorus(p+V(0,y,0),V(0,1,0),major:0.12,minor:0.035,material:material) }
        for side:Float in [-1,1] {
            beam(p+V(0,4.7,0),p+V(0,5.45,side*0.6),0.055,0.055,material)
            let c=p+V(0,5.72,side*0.62)
            box(c,V(0.32,0.48,0.32),lamp)
            box(c+V(0,0.27,0),V(0.5,0.09,0.5),material)
            for dx:Float in [-1,1] { for dz:Float in [-1,1] { beam(c+V(dx*0.18,-0.27,dz*0.18),c+V(dx*0.2,0.26,dz*0.2),0.025,0.025,material) } }
            cylinder(c+V(0,0.3,0),c+V(0,0.54,0),0.035,material,segments:8)
            scene.lights.append(NightLighting.source(c,power:62,color:V(1,0.68,0.35),range:36,radius:0.29))
        }
    }

    private func riverHorseGroup(_ p:V,facing:Float,material:UInt32) {
        // Small sculptural silhouettes at the four entrances; an original study,
        // not a scan or a claim of exact reproduction of the four historic statues.
        ellipsoid(p+V(0,1.62,0),V(0.57,0.73,1.22),material,segments:14,rings:9)
        for x:Float in [-0.36,0.36] { for z:Float in [-0.72,0.72] {
            beam(p+V(x,1.42,z),p+V(x,0.13,z+facing*0.22),0.19,0.19,material)
            box(p+V(x,0.07,z+facing*0.22),V(0.27,0.15,0.39),material)
        } }
        beam(p+V(0,1.85,facing*0.82),p+V(0,2.82,facing*1.08),0.6,0.54,material)
        ellipsoid(p+V(0,2.80,facing*1.35),V(0.27,0.31,0.55),material,segments:12,rings:7)
        for x:Float in [-0.17,0.17] { beam(p+V(x,2.95,facing*1.15),p+V(x,3.3,facing*1.2),0.12,0.12,material) }
        beam(p+V(0,1.8,-facing*1.1),p+V(0,0.7,-facing*1.5),0.17,0.19,material)
        ellipsoid(p+V(0.88,1.8,0.2),V(0.29,0.58,0.22),material,segments:10,rings:8)
        ellipsoid(p+V(0.88,2.56,0.2),V(0.23,0.28,0.23),material,segments:10,rings:7)
        for x:Float in [0.68,1.04] { beam(p+V(x,1.35,0.2),p+V(x,0.1,0.2),0.2,0.2,material) }
        beam(p+V(0.72,2,0.1),p+V(0.4,2.5,0.6*facing),0.18,0.18,material)
    }

    private func riverTorus(_ c:V,_ normal:V,major:Float,minor:Float,material:UInt32,segments:Int=20) {
        let n=simd_normalize(normal)
        let u=simd_normalize(simd_cross(n,abs(n.y)<0.9 ? V(0,1,0):V(1,0,0))),v=simd_cross(n,u)
        for i in 0..<segments { for j in 0..<8 {
            func point(_ a:Int,_ b:Int)->(V,V) {
                let t=Float(a)*2*Float.pi/Float(segments),q=Float(b)*2*Float.pi/8
                let radial=u*cos(t)+v*sin(t),nn=radial*cos(q)+n*sin(q)
                return (c+radial*major+nn*minor,nn)
            }
            let a=point(i,j),b=point(i+1,j),d=point(i,j+1),e=point(i+1,j+1)
            smoothTri(a.0,b.0,e.0,a.1,b.1,e.1,material);smoothTri(a.0,e.0,d.0,a.1,e.1,d.1,material)
        } }
    }

    private func riverCruiser(center c:V) {
        let white=riverMaterial(V(0.78,0.80,0.75),roughness:0.28,metallic:0.12,pattern:2)
        let navy=riverMaterial(V(0.025,0.054,0.076),roughness:0.30,metallic:0.25,pattern:2)
        let steel=riverMaterial(V(0.58,0.61,0.60),roughness:0.22,metallic:0.86)
        let teak=riverMaterial(V(0.31,0.18,0.080),roughness:0.56,pattern:3)
        let cabin=riverMaterial(V(0.10,0.18,0.19),roughness:0.095,metallic:0.45,pattern:12)
        let orange=riverMaterial(V(0.92,0.15,0.020),roughness:0.50)
        let seats=riverMaterial(V(0.14,0.26,0.32),roughness:0.63)
        let rubber=riverMaterial(V(0.018,0.020,0.021),roughness:0.88)
        let stations:[(Float,Float)] = [(-24,1.2),(-23,3.7),(-21,4.75),(-16,4.8),(12,4.8),(17,4.6),(20,3.7),(22,2.4),(24,0.1)]
        for i in 0..<stations.count-1 {
            let a=stations[i],b=stations[i+1]
            for side:Float in [-1,1] {
                for band in 0..<4 {
                    let y0:[Float]=[-1.15,-0.1,0.52,0.94],y1:[Float]=[-0.1,0.52,0.94,1.35]
                    let w0:[Float]=[0.70,0.92,1,1],w1:[Float]=[0.92,1,1,1]
                    quad(c+V(a.0,y0[band],side*a.1*w0[band]),c+V(b.0,y0[band],side*b.1*w0[band]),c+V(b.0,y1[band],side*b.1*w1[band]),c+V(a.0,y1[band],side*a.1*w1[band]),band==0 || band==2 ? navy:white)
                }
                beam(c+V(a.0,0.48,side*(a.1+0.03)),c+V(b.0,0.48,side*(b.1+0.03)),0.15,0.15,rubber)
                beam(c+V(a.0,1.40,side*a.1),c+V(b.0,1.40,side*b.1),0.13,0.13,steel)
                if a.0 >= 12 || b.0 <= -16 {
                    for y:Float in [1.87,2.35] {
                        beam(c+V(a.0,y,side*a.1),c+V(b.0,y,side*b.1),0.036,0.036,steel)
                    }
                }
            }
            quad(c+V(a.0,1.34,-a.1),c+V(b.0,1.34,-b.1),c+V(b.0,1.34,b.1),c+V(a.0,1.34,a.1),teak)
        }
        // Panoramic main cabin, individual mullions, sill panels and a curved glass roof.
        let cabinStart:Float = -16, cabinEnd:Float = 12, half:Float = 3.90
        for side:Float in [-1,1] {
            box(c+V(-2,1.65,side*half),V(28,0.55,0.14),white)
            for i in 0..<14 {
                let x=cabinStart+Float(i)*2
                quad(c+V(x+0.09,1.95,side*half),c+V(x+1.91,1.95,side*half),c+V(x+1.91,3.88,side*3.30),c+V(x+0.09,3.88,side*3.30),cabin)
                beam(c+V(x,1.83,side*half),c+V(x,3.95,side*3.30),0.095,0.095,steel)
                box(c+V(x+1,1.85,side*3.92),V(1.77,0.095,0.16),steel)
            }
            beam(c+V(cabinEnd,1.83,side*half),c+V(cabinEnd,3.95,side*3.30),0.095,0.095,steel)
        }
        for x:Float in [cabinStart,cabinEnd] {
            quad(c+V(x,1.86,-half),c+V(x,1.86,half),c+V(x,3.91,3.3),c+V(x,3.91,-3.3),cabin)
            for z:Float in [-2.6,0,2.6] { beam(c+V(x,1.86,z),c+V(x,3.95,z*0.846),0.1,0.1,steel) }
        }
        box(c+V(-2,4.01,0),V(28.6,0.20,6.80),white)
        box(c+V(-4,4.17,0),V(21.5,0.09,6.4),teak)
        // Open upper observation deck: fine railings and individually modelled seats.
        for side:Float in [-1,1] {
            for i in 0...22 {
                let x:Float = -15+Float(i)
                cylinder(c+V(x,4.2,side*3.13),c+V(x,5.16,side*3.13),0.035,steel,segments:8)
            }
            for y:Float in [4.66,5.16] { cylinder(c+V(-15,y,side*3.13),c+V(7,y,side*3.13),0.035,steel,segments:8) }
        }
        for x:Float in [-15,7] { cylinder(c+V(x,5.16,-3.13),c+V(x,5.16,3.13),0.038,steel,segments:8) }
        for x in stride(from:Float(-13.5),through:Float(5.5),by:1.15) {
            for z:Float in [-2.25,-1.35,1.35,2.25] {
                box(c+V(x,4.63,z),V(0.58,0.12,0.65),seats)
                box(c+V(x-0.24,4.93,z),V(0.12,0.60,0.65),seats)
                for sz:Float in [-1,1] { cylinder(c+V(x,4.21,z+sz*0.24),c+V(x,4.59,z+sz*0.24),0.028,steel,segments:6) }
            }
        }
        // Wheelhouse at the bow, raked windscreen, wipers, roof, radar and mast.
        box(c+V(15.0,2.16,0),V(5.1,1.6,4.8),white)
        quad(c+V(17.58,2.23,-2.25),c+V(17.58,2.23,2.25),c+V(16.92,3.41,2.03),c+V(16.92,3.41,-2.03),cabin)
        for side:Float in [-1,1] { box(c+V(14.95,2.88,side*2.42),V(3.9,0.86,0.04),cabin) }
        box(c+V(14.78,3.49,0),V(5.55,0.18,5.1),white)
        for z:Float in [-1.48,0,1.48] { beam(c+V(17.6,2.28,z),c+V(17.02,3.27,z),0.041,0.041,navy) }
        cylinder(c+V(14.5,3.6,0),c+V(14.5,5.65,0),0.047,steel,segments:10)
        box(c+V(14.5,4.55,0),V(0.16,0.1,1.6),white)
        cylinder(c+V(11.6,4.12,0),c+V(11.6,4.45,0),0.24,white,segments:14)
        box(c+V(11.6,4.50,0),V(1.6,0.15,0.25),white)
        // Bow deck, boarding stairs, lifebuoys, rubber fenders and cleats.
        for side:Float in [-1,1] {
            for x:Float in [-22,-18,18,20,22] {
                let w:Float = x>18 ? (24-x)*0.65+0.15:3.8
                cylinder(c+V(x,1.4,side*w),c+V(x,2.35,side*w),0.035,steel,segments:8)
            }
            for i in 0..<6 {
                let x:Float = -20+Float(i)*7
                cylinder(c+V(x,0.13,side*4.94),c+V(x,1.0,side*4.94),0.19,rubber,segments:12)
                beam(c+V(x,1.0,side*4.94),c+V(x,1.39,side*4.76),0.025,0.025,steel)
            }
            for x:Float in [-14,5] {
                riverTorus(c+V(x,4.72,side*3.2),V(0,0,1),major:0.31,minor:0.092,material:orange,segments:28)
                for s:Float in [-1,1] { box(c+V(x+s*0.30,4.72,side*3.2),V(0.12,0.14,0.2),white) }
            }
            for x:Float in [-21,21] {
                cylinder(c+V(x,1.36,side*2.2),c+V(x,1.60,side*2.2),0.09,steel,segments:10)
                cylinder(c+V(x-0.22,1.60,side*2.2),c+V(x+0.22,1.60,side*2.2),0.065,steel,segments:10)
            }
        }
        for i in 0..<13 {
            let t=Float(i)
            box(c+V(-18.4+t*0.27,1.47+t*0.21,0),V(0.29,0.1,1.45),white)
        }
        for side:Float in [-1,1] { beam(c+V(-18.4,2.45,side*0.77),c+V(-15.2,4.97,side*0.77),0.038,0.038,steel) }
        for x:Float in [-20,-11,-2,7,18] {
            let p=c+V(x,2.9,0)
            scene.lights.append(NightLighting.source(p,power:14,color:V(1,0.76,0.46),range:10,radius:0.22))
        }
        for side:Float in [-1,1] {
            // Low-power deck fittings reveal the hull and upper seats as broad
            // reflected light; no emissive hull material is used.
            for x:Float in [-12,-3,6] {
                scene.lights.append(NightLighting.source(c+V(x,1.50,side*5.08),toward:c+V(x,0.3,side*4.85),power:4.8,color:V(1,0.80,0.54),range:11,radius:0.30,outerDegrees:87,innerDegrees:68))
                scene.lights.append(NightLighting.source(c+V(x,5.0,side*2.98),toward:c+V(x,4.25,0),power:3.8,color:V(1,0.79,0.51),range:7,radius:0.25,outerDegrees:87,innerDegrees:68))
                box(c+V(x,1.48,side*4.95),V(0.23,0.08,0.14),lamp)
                box(c+V(x,5.01,side*3.12),V(0.18,0.07,0.14),lamp)
            }
            for x:Float in [-12,-5,2] {
                let p=c+V(x,3.58,side*3.79)
                box(p,V(1.0,0.08,0.06),lamp)
                scene.lights.append(NightLighting.source(p+V(0,0,side*0.10),toward:p+V(0,-2,side*3),power:6,color:V(1,0.65,0.3),range:15,radius:0.2,outerDegrees:85,innerDegrees:65))
            }
        }
        for (p,color):(V,V) in [(V(15,3.65,-2.3),V(1,0.045,0.025)),(V(15,3.65,2.3),V(0.1,1,0.28)),(V(-23,2.35,0),V(1,0.91,0.7))] {
            let material=riverMaterial(color,roughness:0.4,pattern:8)
            ellipsoid(c+p,V(0.12,0.12,0.12),material,segments:10,rings:6)
            scene.lights.append(NightLighting.source(c+p,power:1.6,color:color,range:7,radius:0.14))
        }
        scene.detailCount += 2100
    }
}
