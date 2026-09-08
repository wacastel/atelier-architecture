import Foundation
import simd

/// Shared route anchors. Exterior extents follow the September 2026 OSM snapshot;
/// the passable gallery rooms are an architectural interpretation, not an as-built survey.
enum ArtInstituteLayout {
    static let michiganEntrance = SIMD3<Float>(983.4, 5, -76.5)
    static let modernEntrance = SIMD3<Float>(1146, 2, -199)
    static let griffinCourt = SIMD3<Float>(1146, 2, -178)
    static let gallery = SIMD3<Float>(1175, 2, -178)
    static let modernFloor: Float = 0.20
    static let historicFloor: Float = 3.2
    static let nicholsNorth = SIMD3<Float>(1103.71, 0.15, -339.66)
    static let nicholsTerrace = SIMD3<Float>(1114.46, 18, -166.02)
}

private struct MuseumPalette {
    var stone: UInt32, trim: UInt32, recess: UInt32, bronze: UInt32
    var clear: UInt32, darkGlass: UInt32, metal: UInt32, plaster: UInt32
    var floor: UInt32, wood: UInt32, roof: UInt32, warm: UInt32, art: [UInt32]
}

extension EiffelBuilder {
    func artInstitute() {
        func add(_ m: SceneMaterial) -> UInt32 {
            let i = UInt32(scene.materials.count); scene.materials.append(m); return i
        }
        let p = MuseumPalette(
            stone: add(SceneMaterial(V(0.62,0.58,0.49),roughness:0.77,pattern:10)),
            trim: add(SceneMaterial(V(0.74,0.70,0.61),roughness:0.66,pattern:1)),
            recess: add(SceneMaterial(V(0.27,0.25,0.21),roughness:0.83)),
            bronze: add(SceneMaterial(V(0.095,0.18,0.135),roughness:0.52,metallic:0.62,pattern:2)),
            clear: add(SceneMaterial(V(0.985,0.992,0.982),roughness:0.07,transmission:1)),
            darkGlass: add(SceneMaterial(V(0.065,0.075,0.062),roughness:0.16,metallic:0.42)),
            metal: add(SceneMaterial(V(0.63,0.65,0.62),roughness:0.30,metallic:0.66)),
            plaster: add(SceneMaterial(V(0.78,0.78,0.75),roughness:0.86)),
            floor: add(SceneMaterial(V(0.59,0.57,0.52),roughness:0.36,pattern:1)),
            wood: add(SceneMaterial(V(0.42,0.29,0.16),roughness:0.48,pattern:3)),
            roof: add(SceneMaterial(V(0.43,0.46,0.43),roughness:0.78)),
            warm: add(SceneMaterial(V(1,0.84,0.62),roughness:0.35,emission:1.0,pattern:8)),
            art: [V(0.13,0.29,0.43),V(0.57,0.25,0.15),V(0.72,0.59,0.28),V(0.17,0.36,0.30),V(0.76,0.72,0.60)].map {
                add(SceneMaterial($0,roughness:0.94))
            })
        museumHistoric(p)
        museumModernWing(p)
        museumNicholsBridge(p)
        museumCampus(p)
    }

    private func museumHistoric(_ p: MuseumPalette) {
        let y = ArtInstituteLayout.historicFloor
        box(V(1015, y-0.2, -77), V(65,0.4,100), p.floor)
        // Main wings stay hollow with ceilings and actual exterior walls.
        box(V(1046.8,12,-77),V(0.8,24,98),p.stone)
        for z:Float in [-126.1,-27.8] { box(V(1015,11.4,z),V(58,22.8,0.8),p.stone) }
        box(V(1015,21.25,-77),V(60,0.5,99),p.roof)
        for z:Float in [-110.4,-43.1] {
            box(V(1015,10.7,z),V(56,0.4,30),p.floor)
            box(V(1015,20.8,z),V(57,0.3,30),p.plaster)
        }
        // Seven bays per side flank the projected five-bay center pavilion.
        for side:Float in [-1,1] {
            let z = -76.5 + side*32.6
            box(V(987.25,1.6,z),V(1.5,3.2,35.3),p.stone)
            box(V(987.25,10.7,z),V(1.5,1.35,35.3),p.trim)
            box(V(987.25,20.0,z),V(1.5,2.0,35.3),p.stone)
            for i in 0..<7 {
                let zz = -76.5 + side*(18.1+Float(i)*4.85)
                box(V(987.2,6.65,zz),V(1.4,6.9,1.7),p.stone)
                box(V(987.0,6.3,zz+side*2.35),V(0.08,4.2,2.9),p.darkGlass)
                box(V(986.78,4.04,zz+side*2.35),V(0.5,0.26,3.15),p.trim)
                box(V(986.78,8.62,zz+side*2.35),V(0.48,0.24,3.15),p.trim)
                museumArchedNiche(V(986.72,15.4,zz+side*2.35),normal:V(-1,0,0),tangent:V(0,0,1),radius:1.52,lower:11.55,depth:0.4,open:false,p:p)
                box(V(987.2,15.15,zz),V(1.35,7.4,1.65),p.stone)
                // Carved circular medallions and narrow pilasters between blind arches.
                cylinder(V(986.35,18.0,zz),V(986.18,18.0,zz),0.27,p.trim,segments:16)
                box(V(986.48,14.75,zz),V(0.32,6.55,0.40),p.trim)
            }
        }
        // Central upper loggia: three deep round arches and two carved end panels.
        for zz:Float in [-89.9,-63.1] {box(V(983.9,13.3,zz),V(1.2,16.5,1.9),p.stone)}
        for zz:Float in [-87.9,-82.5,-76.5,-70.5,-65.1] {
            if abs(zz+76.5)<10 {
                museumArchedNiche(V(983.52,16.8,zz),normal:V(-1,0,0),tangent:V(0,0,1),radius:2.0,lower:11.5,depth:1.1,open:false,p:p)
            }
        }
        for zz:Float in [-86.0,-79.5,-73.5,-67.0] {
            box(V(983.5,15.05,zz),V(0.9,7.1,0.62),p.trim)
            box(V(983.4,11.75,zz),V(1.15,0.4,0.94),p.trim)
            box(V(983.4,18.25,zz),V(1.15,0.55,0.94),p.trim)
        }
        for zz:Float in [-87.8,-65.2] {box(V(983.65,15.1,zz),V(1.0,6.6,3.15),p.stone)}
        box(V(983.55,10.75,-76.5),V(1.6,1.1,29.0),p.trim)
        box(V(983.55,19.65,-76.5),V(1.6,2.3,29.0),p.stone)
        // Ground-level portals remain open at the three middle bays.
        for i in -2...2 {
            let zz = -76.5+Float(i)*5.7
            museumArchedNiche(V(983.35,6.8,zz),normal:V(-1,0,0),tangent:V(0,0,1),radius:1.85,lower:y,depth:1.0,open:abs(i)<2,p:p)
            if abs(i)<2 {
                for dz:Float in [-1.63,1.63] {
                    box(V(983.75,4.75,zz+dz),V(0.12,3.1,0.10),p.bronze)
                    box(V(984.4,4.7,zz+dz),V(1.1,2.95,0.07),p.darkGlass)
                }
            }
        }
        for i in -3...2 {box(V(983.85,6.65,-76.5+(Float(i)+0.5)*5.7),V(1.3,6.9,1.1),p.stone)}
        // Continuous cornices, dentils, and the triangular central pediment.
        for level:Float in [0.45,3.0,10.2,10.65,19.0,20.5,21.15] {
            box(V(986.65,level,-77),V(1.55,level>19 ? 0.3:0.22,100.0),p.trim)
        }
        for zz in stride(from:Float(-126),through:Float(-28),by:0.85) {
            box(V(986.1,20.62,zz),V(0.55,0.38,0.34),p.trim)
        }
        let a=V(982.75,21.1,-92.1),b=V(982.75,26.0,-76.5),c=V(982.75,21.1,-60.9)
        tri(a,b,c,p.stone); tri(a+V(1.3,0,0),c+V(1.3,0,0),b+V(1.3,0,0),p.stone)
        beam(a,b,0.45,0.68,p.trim); beam(b,c,0.45,0.68,p.trim)
        box(V(982.8,21.0,-76.5),V(1.1,0.55,32.1),p.trim)
        for zz:Float in [-92.1,-76.5,-60.9] {museumEllipsoid(V(982.9,zz == -76.5 ? 26.35:21.55,zz),V(0.24,0.47,0.24),p.trim)}
        // Broad entry stair and raised terrace; lion bases flank it.
        for i in 0..<16 {
            let h=Float(i+1)*0.2,w=13.2-Float(i)*0.55
            box(V(983.4-w/2,h/2,-76.5),V(w,h,26.8),p.trim)
        }
        for z:Float in [-97,-56] {
            box(V(977.1,1.4,z),V(4.9,2.8,3.5),p.stone)
            box(V(977.1,2.9,z),V(5.25,0.28,3.8),p.trim)
            museumLion(V(977.0,3.06,z),north:z < -76,p:p)
        }
        // Open central hall, coffered ceiling and monumental stair at its eastern end.
        box(V(1004.5,19.6,-76.5),V(39,0.3,27),p.plaster)
        for x:Float in [990,998,1006,1014] {for z:Float in [-87,-66] {
            cylinder(V(x,y,z),V(x,10.2,z),0.48,p.trim,segments:16)
            box(V(x,10.3,z),V(1.2,0.45,1.2),p.trim)
        }}
        for i in 0..<24 {
            let xx=1014+Float(i)*0.34,h=y+Float(i+1)*0.24
            box(V(xx,h-0.12,-76.5),V(0.36,0.24,8.4),p.trim)
        }
        for x:Float in [991,1000,1009] {museumLamp(V(x,9.5,-76.5),toward:V(x,3.3,-76.5),power:95,range:17,alwaysOn:true,p:p)}
        for zz:Float in [-112,-100,-89,-76.5,-64,-52,-39] {
            let fixtureY:Float = abs(zz+76.5)<13.4 ? 3.4:1.1
            museumLamp(V(980.5,fixtureY,zz),toward:V(985.8,13,zz),power:110,range:25,p:p)
        }
    }

    private func museumModernWing(_ p: MuseumPalette) {
        // Published 28m roof height; two pavilions and the north/south Griffin Court.
        box(V(1159.5,0.0,-178.5),V(93,0.4,40),p.floor)
        box(V(1138.5,0.0,-144),V(43,0.4,107),p.floor)
        for level:Float in [8.2,17.0,25.5] {
            box(V(1128.0,level,-146.0),V(20.0,0.36,95),p.floor)
            box(V(1181.5,level,-177.0),V(47.0,0.36,39),p.floor)
            // Suspended plaster soffits conceal the structural floor underside.
            box(V(1128.0,level-0.215,-146.0),V(20.0,0.06,95),p.plaster)
            box(V(1181.5,level-0.215,-177.0),V(47.0,0.06,39),p.plaster)
        }
        // Gallery walls stop short of the transparent public court.
        box(V(1118.0,12.8,-146.0),V(0.5,25.6,98),p.stone)
        box(V(1205,12.8,-177),V(0.6,25.6,42),p.stone)
        box(V(1181.5,12.8,-158.5),V(47,25.6,0.6),p.stone)
        box(V(1137.9,16.8,-146),V(0.35,17.3,95),p.plaster)
        box(V(1158.0,16.8,-177),V(0.35,17.3,40),p.plaster)
        // Passable east gallery portal is six metres wide at z=-178.
        box(V(1158.0,4.2,-190.0),V(0.38,8,10.0),p.plaster)
        box(V(1158.0,4.2,-164.8),V(0.38,8,12.4),p.plaster)
        box(V(1158.0,7.3,-178.0),V(0.38,1.8,7.0),p.plaster)
        box(V(1137.9,4.1,-147),V(0.35,7.8,69),p.plaster)
        box(V(1137.9,4.1,-190),V(0.35,7.8,11),p.plaster)
        for x in stride(from:Float(1118.5),through:Float(1204.5),by:2.2) {
            let entry=abs(x-1146)<4.2
            if !entry {quad(V(x,0.2,-198),V(x+2.05,0.2,-198),V(x+2.05,25.3,-198),V(x,25.3,-198),p.clear)}
            else {quad(V(x,5.1,-198),V(x+2.05,5.1,-198),V(x+2.05,25.3,-198),V(x,25.3,-198),p.clear)}
            box(V(x-0.05,12.8,-198.1),V(0.08,25.4,0.25),p.metal)
        }
        for yy:Float in [5,8.2,17,25.4] {box(V(1161.5,yy,-198.1),V(88,0.15,0.32),p.metal)}
        for z in stride(from:Float(-194),through:Float(-104),by:5.7) {
            for x:Float in [1139.4,1155.6] {
                cylinder(V(x,0.2,z),V(x,25.5,z),0.115,p.metal,segments:10)
            }
        }
        // Thin white flying-carpet blades preserve daylight through the court.
        for x in stride(from:Float(1114),through:Float(1209),by:0.72) {
            box(V(x,27.5,-177),V(0.38,0.44,49),p.plaster)
        }
        for z:Float in [-201,-189,-177,-165,-153] {box(V(1161.5,27.02,z),V(97,0.40,0.28),p.metal)}
        // Concealed roof washers reveal the white light-filter carpet at night.
        for x:Float in [1122,1138,1154,1170,1186,1202] {for z:Float in [-199.8,-155] {
            museumLamp(V(x,26.55,z),toward:V(x,27.5,z == -199.8 ? -189:-166),power:145,range:22,p:p)
        }}
        for z in stride(from:Float(-190),through:Float(-105),by:1.5) {
            box(V(1137.5,25.8,z),V(42,0.18,0.24),p.plaster)
        }
        quad(V(1138,24.8,-197),V(1158,24.8,-197),V(1158,24.8,-103),V(1138,24.8,-103),p.clear)
        for yy:Float in [3.4,11.2,20.0] {for xx:Float in [1169,1182,1196] {
            museumArtwork(V(xx,yy,-158.92),normal:V(0,0,-1),tangent:V(1,0,0),width:4.1,height:2.65,variant:Int(xx+yy)%5,p:p)
        }}
        // An authored gallery sequence visible through the east opening.
        box(V(1189,4.15,-177.3),V(0.25,7.9,39),p.plaster)
        box(V(1188.82,0.31,-177.3),V(0.055,0.19,39),p.trim)
        box(V(1188.80,0.425,-177.3),V(0.025,0.022,39),p.recess)
        museumArtwork(V(1188.82,3.4,-178),normal:V(-1,0,0),tangent:V(0,0,1),width:6,height:3.3,variant:2,p:p)
        for z:Float in [-189,-167] {museumArtwork(V(1188.82,3.25,z),normal:V(-1,0,0),tangent:V(0,0,1),width:3.8,height:2.6,variant:z < -178 ? 0:3,p:p)}
        box(V(1171.5,0.68,-186.5),V(5.0,0.32,1.3),p.wood)
        for x:Float in [1169.8,1173.2] {box(V(x,0.4,-186.5),V(0.3,0.6,1.0),p.metal)}
        for z:Float in [-191,-177,-163,-147,-131,-113] {
            museumLamp(V(1146,8.0,z),toward:V(1146,0.2,z),power:90,range:16,alwaysOn:true,p:p)
        }
        for z:Float in [-189,-178,-167] {
            museumLamp(V(1184,7.7,z),toward:V(1188,3.0,z),power:z == -178 ? 75:60,range:15,alwaysOn:true,p:p)
        }
        for z:Float in [-186,-170] {
            museumLamp(V(1168,7.7,z),toward:V(1168,0.2,z),power:42,range:14,alwaysOn:true,p:p)
        }
        for y:Float in [7.6,16.4,24.8] {for x:Float in [1168,1184,1198] {
            museumLamp(V(x,y,-191),toward:V(x,y-5,-174),power:70,range:14,alwaysOn:true,p:p)
            museumLamp(V(x,y-0.35,-165),toward:V(x,y-4,-158.9),power:85,range:14,alwaysOn:true,p:p)
        }}
        for y:Float in [7.6,16.4,24.8] {for z:Float in [-185,-166] {
            museumLamp(V(1128,y,z),toward:V(1118.4,y-4,z),power:80,range:15,alwaysOn:true,p:p)
        }}
        // Terrace reached by Nichols; guardrails frame the park without blocking it.
        box(V(1125,17.85,-172),V(26,0.3,42),p.floor)
        for z:Float in [-191,-153] {beam(V(1113,19.15,z),V(1137,19.15,z),0.06,0.06,p.metal)}
        for x:Float in [1113,1137] {for z in stride(from:Float(-189),through:Float(-153),by:2.5) {
            cylinder(V(x,18,z),V(x,19.15,z),0.025,p.metal,segments:6)
        }}
    }

    private func museumNicholsBridge(_ p: MuseumPalette) {
        let start=ArtInstituteLayout.nicholsNorth,end=V(1107.18,18,-165.95),segments=72
        func point(_ t:Float)->V {let q=start+(end-start)*t;return V(q.x,0.15+17.85*(t*t*(3-2*t)),q.z)}
        for i in 0..<segments {
            let a=point(Float(i)/Float(segments)),b=point(Float(i+1)/Float(segments))
            let t=simd_normalize(b-a),n=V(1,0,0),up=simd_normalize(simd_cross(t,n))
            orientedBox((a+b)/2-V(0,0.30,0),n,up,t,V(4.57,0.60,simd_distance(a,b)+0.04),p.plaster)
            for side:Float in [-1,1] {
                beam(a+V(side*2.25,1.12,0),b+V(side*2.25,1.12,0),0.055,0.055,p.metal)
                beam(a+V(side*2.17,0.45,0),b+V(side*2.17,0.45,0),0.035,0.035,p.metal)
                cylinder(a+V(side*2.2,0,0),a+V(side*2.2,1.12,0),0.025,p.metal,segments:6)
            }
            if i%8==0 && i>5 {museumLamp(a+V(2.0,0.86,0),toward:a+V(0,0.12,0),power:4,range:5,p:p)}
        }
        box(V(1110.8,17.70,-165.97),V(7.5,0.6,4.57),p.plaster)
        for t:Float in [0.39,0.73] {let q=point(t);cylinder(V(q.x,0,q.z),q-V(0,0.5,0),0.5,p.plaster,segments:16)}
    }

    private func museumCampus(_ p: MuseumPalette) {
        // Later wings frame the open McCormick courtyards; avoid a solid campus box.
        for (c,s) in [(V(1068,11,-120),V(44,22,14)),(V(1068,11,-40),V(44,22,14)),
                      (V(1132,11,-75),V(172,22,23)),(V(1189,13,5),V(72,26,76)),
                      (V(1217,10,-94),V(21,20,80))] {
            box(c,s,p.stone);box(c+V(0,s.y/2+0.18,0),V(s.x+0.4,0.36,s.z+0.4),p.trim)
            for x in stride(from:c.x-s.x/2+3,through:c.x+s.x/2-3,by:5) {
                box(V(x,c.y+3,c.z-s.z/2-0.015),V(2.2,4.5,0.03),p.darkGlass)
                box(V(x,c.y+3,c.z+s.z/2+0.015),V(2.2,4.5,0.03),p.darkGlass)
            }
        }
        for z:Float in [-159,9] {
            box(V(1012,0.12,z),V(54,0.24,52),p.floor)
            box(V(1012,0.29,z),V(38,0.25,35),grass)
            for x:Float in [991,1003,1015,1027] {
                cylinder(V(x,0,z-10),V(x,6.5,z-10),0.16,bark,segments:8)
                museumEllipsoid(V(x,7,z-10),V(3.2,3.7,3.0),leaf)
            }
        }
    }

    private func museumArchedNiche(_ c:V,normal n:V,tangent t:V,radius r:Float,lower:Float,depth:Float,open:Bool,p:MuseumPalette) {
        let spring=c.y
        if !open {
            let a=V(c.x,lower,c.z)-t*r-n*depth,b=a+t*r*2,d=V(c.x,spring,c.z)-t*r-n*depth
            quad(a,b,d+t*r*2,d,p.recess)
            for i in 0..<20 {
                let a=Float(i)*Float.pi/20,b=Float(i+1)*Float.pi/20
                tri(c-n*depth,c+t*(cos(a)*r)+V(0,sin(a)*r,0)-n*depth,c+t*(cos(b)*r)+V(0,sin(b)*r,0)-n*depth,p.recess)
            }
        }
        for side:Float in [-1,1] {
            orientedBox(c+t*(side*(r+0.18))+V(0,(lower-spring)/2,0),t,V(0,1,0),n,V(0.36,spring-lower,0.4),p.trim)
        }
        for i in 0..<24 {
            let a=Float(i)*Float.pi/24,b=Float(i+1)*Float.pi/24
            beam(c+t*(cos(a)*(r+0.18))+V(0,sin(a)*(r+0.18),0),c+t*(cos(b)*(r+0.18))+V(0,sin(b)*(r+0.18),0),0.34,0.46,p.trim,normal:n)
        }
        orientedBox(c+V(0,r+0.22,0)+n*0.08,t,V(0,1,0),n,V(0.55,0.60,0.58),p.trim)
        scene.detailCount += 1
    }

    private func museumLion(_ c:V,north:Bool,p:MuseumPalette) {
        // Anatomical volumes are authored: a muscular standing lion with a layered mane.
        museumEllipsoid(c+V(0.25,1.40,0),V(1.63,0.69,0.48),p.bronze)
        museumEllipsoid(c+V(-0.88,1.67,0),V(0.63,0.83,0.63),p.bronze)
        museumEllipsoid(c+V(-1.34,north ? 2.08:2.3,0),V(0.48,0.50,0.44),p.bronze)
        museumEllipsoid(c+V(-1.74,north ? 1.94:2.18,0),V(0.38,0.23,0.30),p.bronze)
        for side:Float in [-1,1] {
            museumEllipsoid(c+V(-1.20,2.64,side*0.33),V(0.15,0.20,0.12),p.bronze)
            for x:Float in [-0.91,1.24] {
                let offset:Float=north && side<0 ? -0.25:0
                museumEllipsoid(c+V(x+offset,0.80,side*0.34),V(0.23,0.85,0.22),p.bronze)
                museumEllipsoid(c+V(x-0.13+offset,0.16,side*0.34),V(0.40,0.18,0.26),p.bronze)
            }
            for k in 0..<10 {
                let a=Float(k)*Float.pi/9
                beam(c+V(-1.12+cos(a)*0.38,1.80+sin(a)*0.72,side*0.52),c+V(-0.61+cos(a)*0.44,1.37+sin(a)*0.7,side*0.49),0.07,0.06,p.bronze)
            }
        }
        let tail=[c+V(1.68,1.4,0.13),c+V(2.05,1.02,0.28),c+V(2.04,0.39,0.38),c+V(1.77,0.22,0.51)]
        for i in 1..<tail.count {cylinder(tail[i-1],tail[i],0.08,p.bronze,segments:10)}
        museumEllipsoid(tail.last!,V(0.16,0.2,0.15),p.bronze)
    }

    private func museumEllipsoid(_ c:V,_ s:V,_ material:UInt32) {
        let rings=10,segments=18
        func pt(_ a:Float,_ b:Float)->(V,V) {
            let n=V(sin(a)*cos(b),cos(a),sin(a)*sin(b))
            return(c+n*s,simd_normalize(n/s))
        }
        for j in 0..<rings {for i in 0..<segments {
            let a=Float(j)*Float.pi/Float(rings),b=Float(i)*2*Float.pi/Float(segments)
            let da=Float.pi/Float(rings),db=2*Float.pi/Float(segments)
            let u=pt(a,b),v=pt(a+da,b),w=pt(a+da,b+db),q=pt(a,b+db)
            if j>0 {smoothTri(u.0,v.0,q.0,u.1,v.1,q.1,material)}
            if j<rings-1 {smoothTri(v.0,w.0,q.0,v.1,w.1,q.1,material)}
        }}
    }

    private func museumArtwork(_ c:V,normal n:V,tangent t:V,width:Float,height:Float,variant:Int,p:MuseumPalette) {
        orientedBox(c,t,V(0,1,0),n,V(width,height,0.08),p.art[variant%p.art.count])
        for side:Float in [-1,1] {
            orientedBox(c+t*side*(width/2+0.045),t,V(0,1,0),n,V(0.09,height+0.18,0.14),p.wood)
            orientedBox(c+V(0,side*(height/2+0.045),0),t,V(0,1,0),n,V(width+0.18,0.09,0.14),p.wood)
            orientedBox(c+t*side*(width/2-0.022)+n*0.05,t,V(0,1,0),n,V(0.018,height,0.016),p.recess)
            orientedBox(c+V(0,side*(height/2-0.022),0)+n*0.05,t,V(0,1,0),n,V(width,0.018,0.016),p.recess)
        }
        // Original geometric compositions: no copied collection images or textures.
        for j in 0..<5 {
            let u=(Float(j)-2)*width*0.14,yy=sin(Float(j+variant)*1.8)*height*0.22
            orientedBox(c+t*u+V(0,yy,0)+n*0.047,t,V(0,1,0),n,V(width*0.11,height*(0.23+Float(j%3)*0.11),0.008),p.art[(j+variant+1)%p.art.count])
        }
        let label=c+t*(width/2+0.34)-V(0,height/2-0.11,0)
        orientedBox(label,t,V(0,1,0),n,V(0.40,0.22,0.012),p.plaster)
        for j in 0..<4 {
            orientedBox(label+V(0,0.062-Float(j)*0.036,0)+n*0.009,t,V(0,1,0),n,V(j == 0 ? 0.29:0.20,0.006,0.003),p.recess)
        }
        scene.detailCount += 1
    }

    private func museumLamp(_ c:V,toward:V,power:Float,range:Float,alwaysOn:Bool=false,p:MuseumPalette) {
        box(c,V(0.3,0.055,0.3),p.warm)
        let color=alwaysOn ? V(1,0.96,0.88):V(1,0.90,0.77)
        scene.lights.append(NightLighting.source(c,toward:toward,power:power,color:color,range:range,radius:0.23,outerDegrees:68,innerDegrees:35,alwaysOn:alwaysOn))
    }
}
