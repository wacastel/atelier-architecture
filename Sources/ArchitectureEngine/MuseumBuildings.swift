import Foundation
import simd

/// Mapped exterior anchors; selected interiors are walkable architectural interpretations.
enum MuseumBuildingsLayout {
    typealias V = SIMD3<Float>
    static let fieldCenter=V(1565,0,1409.6),fieldAngle:Float = -0.0217
    static let fieldFloor:Float=4.5,fieldHallLength:Float=91.44,fieldHallWidth:Float=21.336
    static let fieldCeiling:Float=27.6648 // main floor + the owner's 76-foot ceiling
    static let sheddCenter=V(1810.96,0,1254.565),sheddAngle:Float = -0.020
    static let sheddFloor:Float=3.2
    static func fieldPoint(_ p:V)->V {point(p,center:fieldCenter,angle:fieldAngle)}
    static func sheddPoint(_ p:V)->V {point(p,center:sheddCenter,angle:sheddAngle)}
    private static func point(_ p:V,center:V,angle:Float)->V {center+V(cos(angle)*p.x-sin(angle)*p.z,p.y,sin(angle)*p.x+cos(angle)*p.z)}
    static let fieldRoute:[V]=[V(0,1.8,-86.2),V(0,6.3,-67.72),V(0,6.3,-53),V(7.1,6.3,-36),V(7.1,6.3,8),V(7.1,6.3,30),V(6.3,6.3,40)].map(fieldPoint)
    // Current south ground entry; interpretive ramp to main-level rotunda and lake pavilion.
    static let sheddRoute:[V]=[V(-80,1.8,75),V(-35,1.8,85),V(-27,1.8,52),V(-12,2.0,51),V(-12,2.0,45),V(-12,5.0,15),V(-16,5.0,12),V(-16,5.0,0),V(0,5.0,0),V(20,5.0,0),V(49,5.0,0),V(66,5.0,0)].map(sheddPoint)
}
private struct CMFrame {
    let center:SIMD3<Float>,angle:Float
    var x:SIMD3<Float>{SIMD3(cos(angle),0,sin(angle))}
    var z:SIMD3<Float>{SIMD3(-sin(angle),0,cos(angle))}
    func point(_ p:SIMD3<Float>)->SIMD3<Float>{center+x*p.x+SIMD3(0,p.y,0)+z*p.z}
    func vector(_ p:SIMD3<Float>)->SIMD3<Float>{x*p.x+SIMD3(0,p.y,0)+z*p.z}
}
private struct CMPalette {
    let marble:UInt32,trim:UInt32,plaster:UInt32,floor:UInt32,bronze:UInt32,black:UInt32
    let clear:UInt32,glass:UInt32,roof:UInt32,bone:UInt32,rock:UInt32,sand:UInt32,water:UInt32
    let lamp:UInt32,wood:UInt32,blue:UInt32,elephant:UInt32,coral:[UInt32],fish:[UInt32]
}
extension EiffelBuilder {
    func museumBuildings() {
        func add(_ m:SceneMaterial)->UInt32{let i=UInt32(scene.materials.count);scene.materials.append(m);return i}
        let p=CMPalette(
            marble:add(SceneMaterial(V(0.70,0.685,0.635),roughness:0.70,pattern:10)),
            trim:add(SceneMaterial(V(0.79,0.775,0.72),roughness:0.60)),
            plaster:add(SceneMaterial(V(0.79,0.78,0.735),roughness:0.85)),
            floor:add(SceneMaterial(V(0.49,0.48,0.445),roughness:0.36,pattern:1)),
            bronze:add(SceneMaterial(V(0.25,0.19,0.10),roughness:0.32,metallic:0.75)),
            black:add(SceneMaterial(V(0.018,0.023,0.025),roughness:0.47,metallic:0.2)),
            clear:add(SceneMaterial(V(0.975,0.995,0.992),roughness:0.065,transmission:1)),
            glass:add(SceneMaterial(V(0.07,0.11,0.12),roughness:0.16,metallic:0.52)),
            roof:add(SceneMaterial(V(0.31,0.34,0.32),roughness:0.75)),
            bone:add(SceneMaterial(V(0.39,0.265,0.14),roughness:0.74,pattern:10)),
            rock:add(SceneMaterial(V(0.19,0.23,0.20),roughness:0.90,pattern:10)),
            sand:add(SceneMaterial(V(0.55,0.49,0.31),roughness:0.94,pattern:10)),
            water:add(SceneMaterial(V(0.024,0.20,0.245),roughness:0.095,pattern:9)),
            lamp:add(SceneMaterial(V(0.93,0.94,0.91),roughness:0.6,emission:0.65)),
            wood:add(SceneMaterial(V(0.30,0.19,0.10),roughness:0.57,pattern:3)),
            blue:add(SceneMaterial(V(0.012,0.09,0.14),roughness:0.72)),
            elephant:add(SceneMaterial(V(0.24,0.255,0.24),roughness:0.93,pattern:10)),
            coral:[V(0.71,0.25,0.17),V(0.40,0.15,0.57),V(0.62,0.41,0.19),V(0.18,0.43,0.29)].map{add(SceneMaterial($0,roughness:0.78))},
            fish:[V(0.89,0.56,0.06),V(0.14,0.36,0.70),V(0.68,0.18,0.075),V(0.65,0.70,0.62)].map{add(SceneMaterial($0,roughness:0.24,metallic:0.17))})
        campusFieldMuseum(p)
        campusSheddAquarium(p)
    }
    private func cmBox(_ f:CMFrame,_ c:V,_ size:V,_ m:UInt32){orientedBox(f.point(c),f.x,V(0,1,0),f.z,size,m)}
    private func cmQuad(_ f:CMFrame,_ a:V,_ b:V,_ c:V,_ d:V,_ m:UInt32){quad(f.point(a),f.point(b),f.point(c),f.point(d),m)}
    private func cmLight(_ f:CMFrame,_ c:V,_ target:V,_ power:Float,_ color:V=V(0.98,0.98,0.93),range:Float=28,always:Bool=false){scene.lights.append(NightLighting.source(f.point(c),toward:f.point(target),power:power,color:color,range:range,radius:0.65,outerDegrees:80,innerDegrees:57,alwaysOn:always))}

    private func campusFieldMuseum(_ p:CMPalette) {
        let f=CMFrame(center:MuseumBuildingsLayout.fieldCenter,angle:MuseumBuildingsLayout.fieldAngle),floor=MuseumBuildingsLayout.fieldFloor
        // The 214.9m original block, projected entrance pavilions and east atrium
        // match the map separately; the great hall remains completely hollow.
        cmBox(f,V(0,floor/2,0),V(214.9,floor,98.0),p.marble)
        for s:Float in [-1,1] {
            cmBox(f,V(0,floor/2,s*57.7),V(58,floor,20),p.marble)
            cmBox(f,V(s*61.8,22.15,0),V(92.7,0.60,98.0),p.roof)
            cmBox(f,V(s*107.15,13.5,0),V(0.6,18,98),p.marble)
            for z:Float in [-48.7,48.7] {
                cmBox(f,V(s*68.1,13.5,z),V(78.7,18,0.65),p.marble)
                for j in 0..<13 {
                    let x=s*(31.5+Float(j)*6)
                    cmBox(f,V(x,7.6,z-s*0),V(2.4,4.3,0.85),p.glass)
                    cmBox(f,V(x,15.5,z),V(2.5,5.9,0.86),p.glass)
                    cmBox(f,V(x-2.65,13.4,z),V(0.7,17.9,1.1),p.trim)
                    for y:Float in [5.2,10.1,12.25,18.65] {cmBox(f,V(x,y,z),V(3.05,0.19,1.08),p.trim)}
                }
            }
            for z in stride(from:Float(-43),through:43,by:6.2) {
                cmBox(f,V(s*107.52,7.6,z),V(0.10,4.3,2.3),p.glass)
                cmBox(f,V(s*107.53,15.4,z),V(0.11,5.7,2.3),p.glass)
                cmBox(f,V(s*107.75,13.4,z-2.65),V(0.7,17.9,0.72),p.trim)
            }
            for y:Float in [4.6,11.7,20.35,21.3,22.35] {
                cmBox(f,V(0,y,s*49.0),V(215.7,0.22,y>20 ? 1.1:0.65),p.trim)
                cmBox(f,V(s*107.6,y,0),V(0.9,0.22,98.8),p.trim)
            }
            // Grand Ionic porticos. The centre bay is an unobstructed entrance.
            for z:Float in [58.0,65.7] {
                for x:Float in [-10.35,-3.45,3.45,10.35] {cmColumn(f,V(x,floor,s*z),height:15.7,radius:1.0,ionic:true,p:p)}
            }
            for x:Float in [-22.4,22.4] {
                cmBox(f,V(x,12.9,s*65.6),V(13.0,16.8,0.95),p.marble)
                for dx:Float in [-6.0,6.0] {cmBox(f,V(x+dx,12.9,s*66.2),V(0.8,16.8,0.6),p.trim)}
            }
            // Four Ionic shafts between the broad antae are visible in the owner's frontal photo.
            for x:Float in [-27.9,27.9] {cmBox(f,V(x,12.9,s*58.0),V(1.0,16.8,19.2),p.marble)}
            for x:Float in [-19,19] {cmBox(f,V(x,12.9,s*50.7),V(14.0,16.8,0.95),p.marble)}
            cmBox(f,V(0,17.1,s*50.7),V(24,8.4,0.95),p.marble)
            cmBox(f,V(0,21.3,s*59.0),V(58.0,2.15,19.9),p.marble)
            for z:Float in [s*49.0,s*69.2] {tri(f.point(V(-29,22.8,z)),f.point(V(29,22.8,z)),f.point(V(0,28.1,z)),p.marble)}
            for side:Float in [-1,1] {cmQuad(f,V(side*29.2,22.9,s*48.8),V(side*29.2,22.9,s*69.4),V(0,28.3,s*69.4),V(0,28.3,s*48.8),p.trim)}
            for y:Float in [20.2,20.65,22.2,22.75] {cmBox(f,V(0,y,s*59.0),V(59.0,0.22,20.8),p.trim)}
            for x in stride(from:Float(-28.5),through:28.5,by:0.56){cmBox(f,V(x,20.75,s*69.1),V(0.20,0.36,0.35),p.trim)}
            for x:Float in [-6.5,6.5] {
                cmBox(f,V(x,8.6,s*50.0),V(0.16,8.0,0.15),p.bronze)
                cmBox(f,V(x,8.5,s*49.3),V(0.08,7.8,1.3),p.glass)
            }
            cmBox(f,V(0,12.65,s*50.0),V(13.2,0.24,0.26),p.bronze)
            // Twenty-four shallow treads follow the same linear profile as the route.
            for step in 0..<24 {
                let h=Float(step+1)*floor/24,z=67.72+Float(23-step)*0.77+0.385
                cmBox(f,V(0,h/2,s*z),V(36.0,h,0.78),p.trim)
            }
            for x:Float in [-18.8,18.8] {
                cmBox(f,V(x,2.25,s*76.4),V(1.5,4.5,18.9),p.marble)
                cmBox(f,V(x,4.58,s*69),V(1.65,0.18,4.7),p.trim)
            }
            for x:Float in [-23,-12,0,12,23] {cmLight(f,V(x,12,s*74),V(x,15,s*65),125,V(1,0.88,0.70),range:34)}
            for x:Float in [-84,-54,54,84] {cmLight(f,V(x,12,s*55.7),V(x,13,s*48.5),95,V(1,0.89,0.75),range:34)}
        }
        // East atrium/pavilion follows its distinct mapped projection.
        cmBox(f,V(119.0,2.25,-0.3),V(24.7,4.5,24.2),p.marble)
        for z:Float in [-12.2,11.8] {cmBox(f,V(119,10.0,z),V(24.7,11.0,0.8),p.marble)}
        cmBox(f,V(131.0,10.0,-0.2),V(0.8,11,24.5),p.marble)
        cmBox(f,V(119,15.75,-0.2),V(25.2,0.6,25.2),p.roof)
        for side:Float in [-1,1] {
            cmLabel("FIELD MUSEUM",f.point(V(0,21.4,side*69.03)),side<0 ? -f.x:f.x,side<0 ? -f.z:f.z,0.84,p.bronze)
            for x:Float in [-37,37] {
                cmBox(f,V(x,9.9,side*52.1),V(7.2,0.40,3.3),p.trim)
                for dx:Float in [-2.6,2.6] {
                    let c=V(x+dx,6.4,side*52.7)
                    cylinder(f.point(c),f.point(c+V(0,2.4,0)),0.32,p.marble,segments:14)
                    ellipsoid(f.point(c+V(0,2.7,0)),V(0.28,0.35,0.28),p.trim,segments:14,rings:8)
                    cmBox(f,c+V(0,3.18,0),V(0.72,0.30,0.75),p.trim)
                    for q in 0..<7 {let a=Float(q)*Float.pi*2/7;beam(f.point(c+V(cos(a)*0.28,0.15,sin(a)*0.28)),f.point(c+V(cos(a)*0.21,2.3,sin(a)*0.21)),0.05,0.06,p.trim)}
                }
                tri(f.point(V(x-3.7,10.1,side*53.8)),f.point(V(x+3.7,10.1,side*53.8)),f.point(V(x,11.5,side*53.8)),p.trim)
            }
        }
        campusFieldHall(f,p)
        campusFieldGallery(f,p)
    }
    private func campusFieldHall(_ f:CMFrame,_ p:CMPalette) {
        let y=MuseumBuildingsLayout.fieldFloor
        for z:Float in [-27,-8,14,32] {cmLight(f,V(0,20,z),V(0,7,z),90,range:30,always:true)}
        cmBox(f,V(0,y+0.045,0),V(21.336,0.09,91.44),p.floor)
        // Two storeys of open arcades frame the central nave and its balcony.
        for side:Float in [-1,1] {
            cmBox(f,V(side*12.6,12.25,0),V(4.0,0.45,91.44),p.trim)
            for j in 0...12 {
                let z = -45.72+Float(j)*7.62
                cmColumn(f,V(side*11.65,y,z),height:7.50,radius:0.42,ionic:true,p:p)
                cmBox(f,V(side*11.5,17.1,z),V(1.10,9.4,1.42),p.plaster)
                if j<12 {
                    let cz=z+3.81
                    cmArch(f,origin:V(side*11.5,13.0,cz),tangent:V(0,0,1),normal:V(side,0,0),width:6.0,spring:3.1,rise:3.0,depth:1.10,material:p.trim)
                    // Bronze balcony rails leave the vault and side galleries readable.
                    beam(f.point(V(side*10.64,13.20,z+0.6)),f.point(V(side*10.64,13.20,z+7.0)),0.075,0.075,p.bronze)
                    for k in 0..<9 {let zz=z+0.6+Float(k)*0.8;beam(f.point(V(side*10.64,12.42,zz)),f.point(V(side*10.64,13.20,zz)),0.038,0.04,p.bronze)}
                }
            }
            // Gallery walls have a real passage into the selected east exhibit room.
            for (z,length):(Float,Float) in [(-15.6,60.2),(38.4,14.6)] {cmBox(f,V(side*14.0,8.35,z),V(0.50,7.7,length),p.plaster)}
            for z in stride(from:Float(-38.1),through:38.1,by:15.24) {
                cmLight(f,V(side*8.8,16.0,z),V(side*4.8,5.0,z),70,range:29,always:true)
                cmLight(f,V(side*8.0,21.5,z),V(side*11.3,17.4,z),25,range:21,always:true)
            }
        }
        // A faceted vaulted skylight with modeled transverse ribs and individual
        // clear panes replaces an opaque cap across Stanley Field Hall.
        let profile:[(Float,Float)]=[(-11.0,21.7),(-8.5,25.1),(-5.6,27.05),(0,27.6648),(5.6,27.05),(8.5,25.1),(11,21.7)]
        for j in 0..<12 {
            let z0:Float = -45.72+Float(j)*7.62,z1=z0+7.62
            for k in 0..<profile.count-1 {
                let a=profile[k],b=profile[k+1]
                cmQuad(f,V(a.0,a.1,z0),V(a.0,a.1,z1),V(b.0,b.1,z1),V(b.0,b.1,z0),p.clear)
                beam(f.point(V(a.0,a.1,z0)),f.point(V(b.0,b.1,z0)),0.24,0.28,p.trim)
                beam(f.point(V(a.0,a.1,z0)),f.point(V(a.0,a.1,z1)),0.10,0.13,p.bronze)
                for v:Float in [0.25,0.5,0.75] {
                    let x=a.0+(b.0-a.0)*v,h=a.1+(b.1-a.1)*v
                    beam(f.point(V(x,h,z0)),f.point(V(x,h,z1)),0.045,0.07,p.bronze)
                }
                for v:Float in [0.25,0.5,0.75] {let z=z0+7.62*v;beam(f.point(V(a.0,a.1,z)),f.point(V(b.0,b.1,z)),0.06,0.07,p.bronze)}
            }
        }
        for side:Float in [-1,1] {
            cmBox(f,V(0,23.1,side*45.9),V(23.0,9.0,0.60),p.plaster)
            cmArch(f,origin:V(0,12.5,side*44.9),tangent:V(1,0,0),normal:V(0,0,side),width:16.5,spring:3.5,rise:8.2,depth:0.65,material:p.trim)
        }
        cmBox(f,V(-0.7,y+0.12,-7),V(8.4,0.24,37),p.black)
        cmSauropod(f,V(-0.7,y+0.25,-7),p)
        cmBox(f,V(4.0,y+0.85,-18),V(0.15,0.65,3.8),p.black)
        cmLabel("PATAGONIAN GIANT",f.point(V(4.10,y+0.86,-18)),-f.z,f.x,0.18,p.trim)
        cmBox(f,V(-0.4,y+0.14,29),V(8.4,0.28,9.2),p.black)
        cmElephant(f,V(-1.9,y+0.3,29),0.18,p)
        cmElephant(f,V(1.85,y+0.3,30.2),-0.40,p)
        for z:Float in [-18,16] {
            for side:Float in [-1,1] {
                let c=V(side*6.7,21.4,z)
                ellipsoid(f.point(c),V(2.6,0.38,1.45),p.black,segments:18,rings:8)
                for j in 0..<22 {let a=Float(j)*2.399;ellipsoid(f.point(c+V(sin(a)*1.9,-0.25+Float(j%3)*0.18,cos(a)*1.0)),V(0.64,0.37,0.42),j%2==0 ? leaf:leafLight,segments:8,rings:5)}
                beam(f.point(c),f.point(c+V(0,4.0,0)),0.035,0.035,p.bronze)
            }
        }
        for z:Float in [-20,13] {cmPterosaur(f,V(-2,19.0,z),p)}
    }
    private func campusFieldGallery(_ f:CMFrame,_ p:CMPalette) {
        let y=MuseumBuildingsLayout.fieldFloor
        cmBox(f,V(33,11.70,22.4),V(37.5,0.35,19.8),p.plaster)
        for z:Float in [12.6,32.2] {cmBox(f,V(33,8.0,z),V(37.5,7.0,0.45),p.plaster)}
        cmBox(f,V(51.4,8.0,22.4),V(0.50,7.0,19.8),p.plaster)
        for x:Float in [23,41] {for z:Float in [17.5,27.2] {cmLight(f,V(x,11.2,z),V(x,y,z),28,range:17,always:true);cmBox(f,V(x,11.4,z),V(1.6,0.07,0.45),p.lamp)}}
        for j in 0..<4 {
            let z=16.2+Float(j)*4.1
            cmBox(f,V(48.0,y+0.4,z),V(4.8,0.8,3.3),p.wood)
            cmBox(f,V(50.2,y+2.2,z),V(0.2,3.6,3.3),p.blue)
            cmQuad(f,V(45.57,y+0.8,z-1.65),V(45.57,y+0.8,z+1.65),V(45.57,y+3.65,z+1.65),V(45.57,y+3.65,z-1.65),p.clear)
            for k in 0..<12 {
                let c=V(47.6+Float(k%3)*0.65,y+1.0,z-1.1+Float(k/3)*0.66)
                cmCrystal(f,c,radius:0.22+Float(k%4)*0.07,height:0.35+Float((j+k)%5)*0.13,material:p.coral[(j+k)%p.coral.count])
            }
            cmLight(f,V(47.0,y+3.3,z),V(48.0,y+1.1,z),9,range:7,always:true)
        }
        for x:Float in [23,34] {
            cmBox(f,V(x,y+0.44,28.7),V(5.0,0.88,2.3),p.wood)
            for j in 0..<5 {cmCrystal(f,V(x-1.7+Float(j)*0.82,y+0.90,28.7),radius:0.25,height:0.55+Float(j%3)*0.3,material:p.bone)}
        }
    }

    private func campusSheddAquarium(_ p:CMPalette) {
        let f=CMFrame(center:MuseumBuildingsLayout.sheddCenter,angle:MuseumBuildingsLayout.sheddAngle),y=MuseumBuildingsLayout.sheddFloor
        let outline:[V]=[V(-45,0,-25),V(-25,0,-45),V(25,0,-45),V(45,0,-25),V(45,0,25),V(25,0,45),V(-25,0,45),V(-45,0,25)]
        cmPolygon(f,outline,at:0.2,material:p.floor)
        // Main level deliberately leaves an open south entrance/ramp slot.
        cmBox(f,V(0,y-0.18,-5),V(89,0.36,40),p.floor)
        cmBox(f,V(0,y-0.18,-35),V(49,0.36,20),p.floor)
        for s:Float in [-1,1] {cmQuad(f,V(s*24.5,y,-45),V(s*44.5,y,-25),V(s*24.5,y,-25),V(s*24.49,y,-44.99),p.floor)}
        cmBox(f,V(-30.2,y-0.18,24.7),V(28.5,0.36,19.4),p.floor)
        cmBox(f,V(18.3,y-0.18,24.7),V(52.5,0.36,19.4),p.floor)
        cmBox(f,V(-20.3,y-0.18,40),V(9.4,0.36,10),p.floor)
        cmBox(f,V(8.3,y-0.18,40),V(32.5,0.36,10),p.floor)
        cmQuad(f,V(-16,0.2,45),V(-8,0.2,45),V(-8,y,15),V(-16,y,15),p.floor)
        cmBox(f,V(-12,0.1,48.5),V(8,0.2,7),p.floor)
        // Original octagonal body and four projecting classical arms, Georgia marble.
        for j in 0..<8 {
            let a=outline[j],b=outline[(j+1)%8],d=b-a,length=simd_length(d),t=d/length,n=V(t.z,0,-t.x),c=(a+b)/2
            let openings:[(Float,Float)]
            if j==3 {openings=[(-5.5,5.5)]} // east, toward the Oceanarium
            else if j==7 {openings=[(-5.5,5.5)]} // west historic doorway
            else if j==5 {openings=[(8,16)]} // south ground-level entrance: x -16..-8
            else {openings=[]}
            var cursor = -length/2
            for gap in openings {
                let l=max(cursor,gap.0),r=min(length/2,gap.1)
                if l>cursor {orientedBox(f.point(c+t*((cursor+l)/2)+V(0,7.8,0)),f.vector(t),V(0,1,0),f.vector(n),V(l-cursor,15.2,0.8),p.marble)}
                orientedBox(f.point(c+t*((l+r)/2)+V(0,11.7,0)),f.vector(t),V(0,1,0),f.vector(n),V(r-l,7.4,0.8),p.marble)
                cursor=r
            }
            if cursor<length/2 {orientedBox(f.point(c+t*((cursor+length/2)/2)+V(0,7.8,0)),f.vector(t),V(0,1,0),f.vector(n),V(length/2-cursor,15.2,0.8),p.marble)}
            for h:Float in [0.4,3.2,12.9,14.7,15.7] {
                if h<4 && !openings.isEmpty {
                    var u = -length/2
                    for gap in openings {if gap.0>u {beam(f.point(c+t*u+V(0,h,0)),f.point(c+t*gap.0+V(0,h,0)),0.9,0.25,p.trim)};u=gap.1}
                    if u<length/2 {beam(f.point(c+t*u+V(0,h,0)),f.point(b+V(0,h,0)),0.9,0.25,p.trim)}
                } else {beam(f.point(a+V(0,h,0)),f.point(b+V(0,h,0)),0.9,0.25,p.trim)}
            }
            for k in 0..<Int(length/3.4) {
                let u = -length/2+1.7+Float(k)*3.4,c0=c+t*u
                if openings.contains(where:{u>$0.0-1.5 && u<$0.1+1.5}) {continue}
                orientedBox(f.point(c0+n*0.46+V(0,7.0,0)),f.vector(t),V(0,1,0),f.vector(n),V(1.25,4.5,0.13),p.glass)
                orientedBox(f.point(c0+n*0.57+V(0,9.5,0)),f.vector(t),V(0,1,0),f.vector(n),V(1.65,0.23,0.25),p.trim)
            }
            // Roof ring stops at the raised rotunda, leaving its skylight unobstructed.
            let aa=simd_normalize(a)*13.4,bb=simd_normalize(b)*13.4
            cmQuad(f,a+V(0,15.45,0),b+V(0,15.45,0),bb+V(0,15.45,0),aa+V(0,15.45,0),p.roof)
        }
        // West Doric portico, including its small pediment and shallow public stair.
        for x:Float in [-46.7,-41.7] {for k in 0..<6 {cmColumn(f,V(x,y,-10+Float(k)*4),height:9.7,radius:0.56,ionic:false,p:p)}}
        cmBox(f,V(-44,13.6,0),V(8.4,1.5,25.8),p.marble)
        for x:Float in [-48.35,-39.65] {tri(f.point(V(x,14.35,-12.9)),f.point(V(x,14.35,12.9)),f.point(V(x,17.1,0)),p.marble)}
        cmQuad(f,V(-48.5,14.35,-13.0),V(-39.5,14.35,-13.0),V(-39.5,17.2,0),V(-48.5,17.2,0),p.trim)
        cmQuad(f,V(-48.5,17.2,0),V(-39.5,17.2,0),V(-39.5,14.35,13.0),V(-48.5,14.35,13.0),p.trim)
        for k in 0..<20 {let h=Float(k+1)*y/20,x = -65.9+Float(k)*0.88;cmBox(f,V(x,h/2,0),V(0.9,h,24),p.trim)}
        for z:Float in [-11.8,11.8] {cmLight(f,V(-52,1.2,z),V(-43,10,z*0.7),68,V(1,0.88,0.70),range:26)}
        for s:Float in [-1,1] {for x:Float in [-25,0,25] {cmLight(f,V(x,0.5,s*49),V(x,9,s*44),60,V(1,0.88,0.72),range:26)}}
        // South approach remains at grade; broad interior ramp connects main-level galleries.
        for x:Float in [-16.2,-7.8] {beam(f.point(V(x,1.2,44)),f.point(V(x,4.2,15)),0.07,0.07,p.bronze)}
        for x:Float in [-16.3,-7.7] {cmBox(f,V(x,4.5,30),V(0.5,8.6,30),p.plaster)}
        cmBox(f,V(-12,7.65,30),V(8.1,0.2,30),p.plaster)
        for z:Float in [41,31,21] {cmLight(f,V(-12,7.35,z),V(-12,2,z),22,range:16,always:true);cmBox(f,V(-12,7.5,z),V(1.2,0.08,0.45),p.lamp)}
        cmLight(f,V(-12,5.4,46),V(-12,1.0,50),13,V(1,0.94,0.82),range:12,always:true)
        cmBox(f,V(-12,5.6,44.6),V(8.8,0.3,1.0),p.bronze)
        // Central octagonal rotunda: four cardinal passages and four corner piers.
        for j in 0..<8 {
            let a=Float(j)*Float.pi/4,radial=V(cos(a),0,sin(a)),t=V(-sin(a),0,cos(a)),c=radial*12.1
            if j%2==1 {orientedBox(f.point(c+V(0,10.0,0)),f.vector(t),V(0,1,0),f.vector(radial),V(3.7,13.6,1.0),p.marble)}
            else {cmArch(f,origin:c+V(0,y,0),tangent:t,normal:radial,width:8.4,spring:7.0,rise:3.2,depth:1.0,material:p.trim)}
            let a0=a-Float.pi/8,a1=a+Float.pi/8
            for h:Float in [16.0,16.5,19.0] {cmCurve(f,(0...8).map{let q=a0+(a1-a0)*Float($0)/8;return V(cos(q)*12.8,h,sin(q)*12.8)},radius:0.16,material:p.trim,segments:8)}
            cmLight(f,c*0.84+V(0,15.3,0),V(0,y,0),32,range:25,always:true)
        }
        for k in 0..<64 {
            let a=Float(k)*2*Float.pi/64,b=Float(k+1)*2*Float.pi/64
            func pt(_ q:Float,_ h:Float)->V {V(cos(q)*12.98,h,sin(q)*12.98)}
            cmQuad(f,pt(a,15.45),pt(b,15.45),pt(b,16.2),pt(a,16.2),p.plaster)
            cmQuad(f,pt(a,18.5),pt(b,18.5),pt(b,19.12),pt(a,19.12),p.trim)
            cmQuad(f,pt(a,16.2),pt(b,16.2),pt(b,18.5),pt(a,18.5),k%8==0 || k%8==7 ? p.trim:p.clear)
        }
        let dome=[V(13.0,19,0),V(12.0,21.7,0),V(9.2,24.25,0),V(5.1,26.2,0),V(0.9,27,0)]
        for j in 1..<dome.count {for k in 0..<64 {
            let a=Float(k)*2*Float.pi/64,b=Float(k+1)*2*Float.pi/64
            func pt(_ q:Float,_ r:Int)->V {V(cos(q)*dome[r].x,dome[r].y,sin(q)*dome[r].x)}
            cmQuad(f,pt(a,j-1),pt(a,j),pt(b,j),pt(b,j-1),p.clear)
            if k%4==0 {beam(f.point(pt(a,j-1)),f.point(pt(a,j)),0.085,0.085,p.bronze)}
            if k%2==0 {beam(f.point(pt(a,j-1)),f.point(pt(b,j)),0.035,0.035,p.bronze)}
        }}
        cylinder(f.point(V(0,26.98,0)),f.point(V(0,27.20,0)),0.95,p.bronze,segments:32)
        for s:Float in [-1,1] {cmHabitat(f,V(0,y,s*5.25),side:s,p:p)}
        cmBox(f,V(0,8.0,0),V(1.8,0.75,6.0),p.bronze)
        cmBox(f,V(0,7.60,0),V(1.7,0.07,5.9),p.lamp)
        // Representative gallery tanks off the east connecting gallery.
        for s:Float in [-1,1] {for j in 0..<3 {
            let x=19.0+Float(j)*8.0,c=V(x,y,s*7.5)
            cmBox(f,c+V(0,0.35,0),V(6.1,0.7,4.8),p.black)
            cmBox(f,c+V(0,2.25,s*2.25),V(6.1,3.8,0.3),p.blue)
            cmQuad(f,c+V(-3.0,0.7,-s*2.45),c+V(3,0.7,-s*2.45),c+V(3,4.1,-s*2.45),c+V(-3,4.1,-s*2.45),p.clear)
            cmBox(f,c+V(0,4.3,0),V(6.3,0.35,5.1),p.black)
            for k in 0..<7 {cmFish(f,c+V(-2.2+Float(k%4)*1.3,1.2+Float(k%3)*0.70,Float(k%2)*1.2-0.6),angle:Float(k),size:0.34,material:p.fish[(j+k)%4],p:p)}
            cmLight(f,c+V(0,3.8,0),c+V(0,1.1,0),16,V(0.76,0.91,1),range:8,always:true)
        }}
        for x:Float in [22,38] {cmLight(f,V(x,11.8,0),V(x,y,0),27,range:18,always:true)}
        campusOceanarium(f,p)
        campusSheddAnnexes(p)
        for z:Float in [-10,-6,-2,2,6,10] {cmLight(f,V(-49.6,6,z),V(-46.8,10,z),20,V(1,0.91,0.78),range:19)}
        cmLabel("JOHN G SHEDD AQUARIUM",f.point(V(-48.42,13.50,0)),f.z,V(-f.x.x,0,-f.x.z),0.62,p.bronze)
        cmLabel("WONDER OF WATER",f.point(V(-12.67,11.9,0)),f.z,-f.x,0.44,p.bronze)
        for side:Float in [-1,1] {cmLabel(side>0 ? "FRESH WATER":"CORAL REEF",f.point(V(0,y+0.28,side*3.30)),side>0 ? -f.x:f.x,side>0 ? -f.z:f.z,0.17,p.trim)}
    }
    private func cmPolygon(_ f:CMFrame,_ points:[V],at y:Float,material:UInt32) {
        let c=points.reduce(V.zero,+)/Float(points.count)
        for j in points.indices {let a=points[j],b=points[(j+1)%points.count];tri(f.point(V(c.x,y,c.z)),f.point(V(a.x,y,a.z)),f.point(V(b.x,y,b.z)),material)}
    }
    private func cmHabitat(_ f:CMFrame,_ c:V,side:Float,p:CMPalette) {
        let count=64,h:Float=3.3528
        let gold=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.72,0.46,0.12),roughness:0.32,metallic:0.62,emission:0.22))
        func pt(_ k:Int,_ y:Float,_ scale:Float=1)->V {let a=Float(k)*2*Float.pi/Float(count);return c+V(cos(a)*5.3*scale,y,(sin(a)*1.91+side*0.45*cos(a)*cos(a))*scale)}
        let outline=(0..<count).map{pt($0,0)}
        cmPolygon(f,outline,at:c.y+0.55,material:p.sand)
        for k in 0..<count {
            cmQuad(f,pt(k,0.20),pt(k+1,0.20),pt(k+1,0.55),pt(k,0.55),p.black)
            cmQuad(f,pt(k,0.55),pt(k+1,0.55),pt(k+1,0.55+h),pt(k,0.55+h),p.clear)
            cmQuad(f,pt(k,0.55+h,1.03),pt(k+1,0.55+h,1.03),pt(k+1,5.4,1.03),pt(k,5.4,1.03),gold)
            if k%2==0 {
                for row in 0..<3 {let base:Float=4.0+Float(row)*0.44;cmCurve(f,[pt(k,base,1.045),pt(k,base+0.19,1.07),pt(k+1,base+0.40,1.045),pt(k+2,base+0.19,1.07),pt(k+2,base,1.045)],radius:0.035,material:p.bronze,segments:8)}
            }
        }
        // Fish/coral/plant forms are original procedural exhibit content.
        for k in 0..<35 {
            let a=Float(k)*2.399,c0=c+V(cos(a)*(1+Float(k%4)*0.8),0.64,sin(a)*1.25)
            if side>0 {
                for j in 0..<4 {let d=Float(j)*1.57;cmCurve(f,[c0,c0+V(cos(d)*0.18,0.5+Float(k%3)*0.24,sin(d)*0.2),c0+V(cos(d)*0.30,1.15+Float(k%4)*0.16,sin(d)*0.3)],radius:0.035,material:p.coral[3],segments:6)}
            } else {
                ellipsoid(f.point(c0),V(0.43,0.22,0.31),p.rock,segments:10,rings:6)
                for j in 0..<3 {let d=Float(j)*2.1;cmCurve(f,[c0,c0+V(0,0.4,0),c0+V(cos(d)*0.25,0.8,sin(d)*0.25)],radius:0.055,material:p.coral[k%3],segments:7)}
            }
        }
        for k in 0..<33 {let a=Float(k)*2.399;cmFish(f,c+V(cos(a)*(1+Float(k%4)),1.0+Float(k%5)*0.5,sin(a)*1.1),angle:a,size:0.22+Float(k%3)*0.085,material:p.fish[k%4],p:p)}
        for x:Float in [-3,0,3] {cmLight(f,c+V(x,3.65,0),c+V(x,0.7,0),14,side>0 ? V(0.83,1,0.82):V(0.76,0.9,1),range:8,always:true)}
    }
    private func cmFish(_ parent:CMFrame,_ c:V,angle:Float,size s:Float,material:UInt32,p:CMPalette) {
        let f=CMFrame(center:parent.point(c),angle:parent.angle+angle)
        ellipsoid(f.point(V.zero),V(s,s*0.45,s*0.23),material,segments:14,rings:8)
        tri(f.point(V(-s*0.7,0,0)),f.point(V(-s*1.65,s*0.55,0)),f.point(V(-s*1.65,-s*0.55,0)),material)
        tri(f.point(V(-s*0.4,s*0.25,0)),f.point(V(0,s*0.95,0)),f.point(V(s*0.35,s*0.32,0)),material)
        for side:Float in [-1,1] {ellipsoid(f.point(V(s*0.67,s*0.12,side*s*0.18)),V(s*0.09,s*0.09,s*0.065),p.black,segments:8,rings:5)}
    }
    private func campusOceanarium(_ f:CMFrame,_ p:CMPalette) {
        // Map-derived eastern crescent; 1991 lake window, stepped amphitheater and pools.
        let arcCenter=V(48,0,0),radius:Float=64.0,y=MuseumBuildingsLayout.sheddFloor
        let calmWater=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.035,0.20,0.23),roughness:0.115))
        func outer(_ a:Float,_ h:Float)->V {arcCenter+V(cos(a)*radius,h,sin(a)*radius)}
        let angle:Float=1.13
        let outline=[V(43,0,-37),V(72,0,-62)]+(0...40).map{outer(-angle+Float($0)*2*angle/40,0)}+[V(72,0,62),V(43,0,37)]
        cmPolygon(f,outline,at:0.10,material:p.floor)
        cmBox(f,V(49,y-0.25,0),V(12,0.5,73),p.floor)
        cmBox(f,V(61.5,y-0.25,0),V(13,0.5,4.4),p.floor)
        for j in 0..<40 {
            let a = -angle+Float(j)*2*angle/40,b = -angle+Float(j+1)*2*angle/40
            cmQuad(f,outer(a,0.15),outer(b,0.15),outer(b,13),outer(a,13),p.clear)
            beam(f.point(outer(a,0.1)),f.point(outer(a,13.1)),0.22,0.22,p.bronze)
            for h:Float in [4.2,8.5,12.9] {beam(f.point(outer(a,h)),f.point(outer(b,h)),0.10,0.10,p.bronze)}
            cmQuad(f,V(50,15.0,sin(a)*45),outer(a,13.2),outer(b,13.2),V(50,15.0,sin(b)*45),p.roof)
            cmQuad(f,V(50,14.90,sin(a)*45),outer(a,13.1),outer(b,13.1),V(50,14.90,sin(b)*45),p.plaster)
        }
        for s:Float in [-1,1] {
            cmQuad(f,V(43,0.2,s*37),V(72,0.2,s*62),V(72,13.2,s*62),V(43,15,s*37),p.marble)
            // Ten seating terraces, interrupted by the safe central aisle.
            for row in 0..<10 {
                let x=55.8+Float(row)*1.12,h=y-Float(row)*0.22
                cmBox(f,V(x,h-0.23,s*18),V(1.15,0.46,30.4),p.marble)
                cmBox(f,V(x,h+0.10,s*18),V(0.55,0.20,29.8),p.wood)
            }
            for x:Float in [50,64,78] {cmLight(f,V(x,11.7,s*26),V(x,1.2,s*24),36,V(0.92,0.97,1),range:30,always:true)}
        }
        let pool=V(88,0.85,0)
        let shape=(0..<72).map{k -> V in let a=Float(k)*2*Float.pi/72;return pool+V(cos(a)*18.5,0,sin(a)*45)}
        cmPolygon(f,shape,at:0.85,material:calmWater)
        for j in 0..<72 {let a=shape[j],b=shape[(j+1)%72];beam(f.point(a+V(0,0.1,0)),f.point(b+V(0,0.1,0)),0.4,0.5,p.rock)}
        // Dry naturalistic shore islands preserve a continuous central pool.
        for s:Float in [-1,1] {for j in 0..<18 {let a=Float(j)*2.399,c=V(84+cos(a)*6,0.8+Float(j%3)*0.25,s*(40+sin(a)*3));ellipsoid(f.point(c),V(2.0,0.85,1.6),p.rock,segments:12,rings:7)}}
        for s:Float in [-1,1] {cmBox(f,V(61.5,y+0.9,s*2.3),V(13,0.08,0.08),p.bronze);for x:Float in [55,61,67.5] {cmBox(f,V(x,y+0.45,s*2.3),V(0.06,0.9,0.06),p.bronze)}}
        cmBox(f,V(68.1,y+0.55,0),V(0.08,1.1,4.6),p.clear)
        for x:Float in [52,66,81,96] {
            for h:Float in [12.2,12.9] {beam(f.point(V(x,h,-43)),f.point(V(x,h,43)),0.14,0.18,p.trim)}
            for z in stride(from:Float(-42),through:39,by:3) {beam(f.point(V(x,12.2,z)),f.point(V(x,12.9,z+3)),0.08,0.09,p.trim)}
        }
        for z:Float in [-30,-15,0,15,30] {beam(f.point(V(50,12.5,z)),f.point(V(102,12.5,z)),0.20,0.28,p.trim)}
        for x:Float in [59,77,95] {for z:Float in [-15,15] {cmLight(f,V(x,12.0,z),V(x,2.5,z),42,range:25,always:true);cmBox(f,V(x,12.15,z),V(0.7,0.12,0.7),p.lamp)}}
    }

    private func campusSheddAnnexes(_ p:CMPalette) {
        let f=CMFrame(center:V.zero,angle:0)
        // Mapped OSM766396221; height is an architectural estimate.
        do {let points:[V]=[V(1798.023,0,1309.279),V(1825.283,0,1308.834),V(1825.797,0,1321.09),V(1798.346,0,1321.602)]
            cmPolygon(f,points,at:6.0,material:p.roof)
            for j in points.indices {let a=points[j],b=points[(j+1)%points.count];cmQuad(f,a,b,b+V(0,6.0,0),a+V(0,6.0,0),p.marble);beam(a+V(0,6.0,0),b+V(0,6.0,0),0.5,0.2,p.trim)}
        }
        // Mapped OSM766511381; height is an architectural estimate.
        do {let points:[V]=[V(1849.27,0,1305.116),V(1849.701,0,1304.737),V(1857.26,0,1297.913),V(1862.399,0,1291.935),V(1884.09,0,1307.954),V(1878.561,0,1315.123),V(1872.453,0,1321.246),V(1869.038,0,1323.628),V(1863.526,0,1316.904),V(1861.918,0,1317.995),V(1856.597,0,1311.272),V(1855.238,0,1312.429),V(1854.832,0,1312.774)]
            cmPolygon(f,points,at:12.8,material:p.roof)
            for j in points.indices {let a=points[j],b=points[(j+1)%points.count];cmQuad(f,a,b,b+V(0,12.8,0),a+V(0,12.8,0),p.marble);beam(a+V(0,12.8,0),b+V(0,12.8,0),0.5,0.2,p.trim)}
        }
        // Mapped OSM17430414; height is an architectural estimate.
        do {let points:[V]=[V(1843.51,0,1209.169),V(1847.082,0,1202.479),V(1855.13,0,1194.987),V(1866.626,0,1183.309),V(1874.558,0,1190.612),V(1881.752,0,1198.994),V(1861.263,0,1216.193),V(1855.718,0,1228.928)]
            cmPolygon(f,points,at:12.8,material:p.roof)
            for j in points.indices {let a=points[j],b=points[(j+1)%points.count];cmQuad(f,a,b,b+V(0,12.8,0),a+V(0,12.8,0),p.marble);beam(a+V(0,12.8,0),b+V(0,12.8,0),0.5,0.2,p.trim)}
        }
    }
    private func cmColumn(_ f:CMFrame,_ c:V,height:Float,radius:Float,ionic:Bool,p:CMPalette) {
        let profile:[(Float,Float)]=[(0,radius*1.30),(0.18,radius*1.30),(0.29,radius*1.10),(0.48,radius),(height*0.35,radius*0.97),(height*0.72,radius*0.90),(height-0.65,radius*0.84),(height-0.46,radius*1.04),(height-0.30,radius*1.24),(height,radius*1.24)]
        let steps=48
        for j in 1..<profile.count {for k in 0..<steps {
            let a=Float(k)*2*Float.pi/Float(steps),b=Float(k+1)*2*Float.pi/Float(steps)
            func pt(_ theta:Float,_ row:Int)->V {let h=profile[row].0,r=profile[row].1*(row>2 && row<7 ? 1-0.038*cos(theta*24):1);return c+V(cos(theta)*r,h,sin(theta)*r)}
            cmQuad(f,pt(a,j-1),pt(a,j),pt(b,j),pt(b,j-1),p.trim)
        }}
        cmBox(f,c+V(0,height+0.06,0),V(radius*2.8,0.12,radius*2.8),p.trim)
        if ionic {for side:Float in [-1,1] {
            let v=c+V(side*radius*1.0,height-0.27,0)
            cylinder(f.point(v-V(0,0,radius*0.95)),f.point(v+V(0,0,radius*0.95)),radius*0.32,p.trim,segments:20)
            for z:Float in [-1,1] {cylinder(f.point(v+V(0,0,z*radius*0.98)),f.point(v+V(0,0,z*radius*1.02)),radius*0.15,p.marble,segments:16)}
        }}
    }
    private func cmArch(_ f:CMFrame,origin c:V,tangent t:V,normal n:V,width:Float,spring:Float,rise:Float,depth:Float,material:UInt32) {
        let r=width/2,up=V(0,1,0),thickness:Float=0.32
        for side:Float in [-1,1] {orientedBox(f.point(c+t*(side*(r+thickness/2))+up*spring/2),f.vector(t),up,f.vector(n),V(thickness,spring,depth),material)}
        for j in 0..<24 {
            let a=Float(j)*Float.pi/24,b=Float(j+1)*Float.pi/24
            let p0=c+t*(cos(a)*r)+up*(spring+sin(a)*rise),p1=c+t*(cos(b)*r)+up*(spring+sin(b)*rise)
            let q0=c+t*(cos(a)*(r+thickness))+up*(spring+sin(a)*(rise+thickness)),q1=c+t*(cos(b)*(r+thickness))+up*(spring+sin(b)*(rise+thickness))
            cmQuad(f,p0+n*depth/2,p1+n*depth/2,q1+n*depth/2,q0+n*depth/2,material)
            cmQuad(f,p1-n*depth/2,p0-n*depth/2,q0-n*depth/2,q1-n*depth/2,material)
            cmQuad(f,p0-n*depth/2,p1-n*depth/2,p1+n*depth/2,p0+n*depth/2,material)
            cmQuad(f,q0+n*depth/2,q1+n*depth/2,q1-n*depth/2,q0-n*depth/2,material)
        }
    }
    private func cmCurve(_ f:CMFrame,_ points:[V],radius:Float,material:UInt32,segments:Int=10){for j in 1..<points.count{cylinder(f.point(points[j-1]),f.point(points[j]),radius,material,segments:segments)}}
    private func cmCrystal(_ f:CMFrame,_ c:V,radius:Float,height:Float,material:UInt32){for j in 0..<6{let a=Float(j)*Float.pi/3,b=Float(j+1)*Float.pi/3;let p0=c+V(cos(a)*radius,0,sin(a)*radius),p1=c+V(cos(b)*radius,0,sin(b)*radius);cmQuad(f,p0,p1,p1+V(0,height*0.72,0),p0+V(0,height*0.72,0),material);tri(f.point(p0+V(0,height*0.72,0)),f.point(p1+V(0,height*0.72,0)),f.point(c+V(0,height,0)),material)}}
    private func cmSauropod(_ f:CMFrame,_ c:V,_ p:CMPalette) {
        let spine:(Float)->V={t in
            if t<0.34 {let u=t/0.34;return c+V(sin(u*2)*0.4,12.5-6.0*u,-18+14*u)}
            if t<0.64 {let u=(t-0.34)/0.30;return c+V(0,6.5-0.5*u,-4+9*u)}
            let u=(t-0.64)/0.36;return c+V(sin(u*2)*0.6,6-4*u,5+14*u)
        }
        let pts=(0...60).map{spine(Float($0)/60)}
        cmCurve(f,pts,radius:0.13,material:p.bone,segments:12)
        for j in 0...60 {
            let t=Float(j)/60,v=spine(t),r:Float=t<0.64 ? 0.20:0.18*(1-(t-0.64)/0.40)
            ellipsoid(f.point(v),V(r*1.3,r,r*1.55),p.bone,segments:10,rings:6)
            if t>0.32 && t<0.66 {beam(f.point(v),f.point(v+V(0,0.75,0)),0.10,0.10,p.bone)}
        }
        for j in 0..<11 {
            let z = -3.7+Float(j)*0.74,height:Float=6.45-Float(j)*0.025,r:Float=1.55+sin(Float(j)*Float.pi/10)*0.65
            for side:Float in [-1,1] {let rib=(0...12).map{k -> V in let a=Float(k)*Float.pi/15;return c+V(side*sin(a)*r,height-(1-cos(a))*1.4,z)};cmCurve(f,rib,radius:0.085,material:p.bone,segments:8)}
        }
        for z:Float in [-3.4,3.7] {for side:Float in [-1,1] {
            let hip=c+V(side*1.1,6.2,z),knee=c+V(side*1.95,3.3,z+0.65),ankle=c+V(side*2.1,0.5,z+0.4)
            cmCurve(f,[hip,knee,ankle],radius:0.24,material:p.bone,segments:14)
            for v in [hip,knee,ankle] {ellipsoid(f.point(v),V(0.36,0.32,0.36),p.bone,segments:12,rings:7)}
            for toe in 0..<4 {let x=side*2.1-0.36+Float(toe)*0.24;cmCurve(f,[c+V(x,0.44,z+0.4),c+V(x,0.20,z-0.2)],radius:0.11,material:p.bone,segments:8)}
            cmCurve(f,[c+V(side*1.3,0.2,z),c+V(side*1.3,5.9,z)],radius:0.032,material:p.black,segments:8)
        }}
        let head=spine(0)+V(0,0,-0.55)
        ellipsoid(f.point(head),V(0.51,0.55,1.02),p.bone,segments:18,rings:10)
        for s:Float in [-1,1] {ellipsoid(f.point(head+V(s*0.43,0.13,-0.1)),V(0.085,0.17,0.23),p.black,segments:12,rings:7)}
        cmCurve(f,[head+V(-0.38,-0.39,0.52),head+V(-0.32,-0.47,-0.75),head+V(0.32,-0.47,-0.75),head+V(0.38,-0.39,0.52)],radius:0.09,material:p.bone)
    }
    private func cmElephant(_ frame:CMFrame,_ c:V,_ angle:Float,_ p:CMPalette) {
        let f=CMFrame(center:frame.point(c),angle:frame.angle+angle)
        ellipsoid(f.point(V(0,2.35,0)),V(1.10,1.65,2.0),p.elephant,segments:24,rings:14)
        ellipsoid(f.point(V(0,3.0,-1.8)),V(0.80,1.0,0.85),p.elephant,segments:20,rings:12)
        for x:Float in [-0.72,0.72] {for z:Float in [-1.10,1.16] {cylinder(f.point(V(x,0.15,z)),f.point(V(x,2.6,z)),0.33,p.elephant,segments:16);ellipsoid(f.point(V(x,0.23,z)),V(0.39,0.26,0.46),p.elephant,segments:14,rings:8)}}
        for s:Float in [-1,1] {
            ellipsoid(f.point(V(s*0.93,3.0,-1.38)),V(0.54,1.1,0.18),p.elephant,segments:18,rings:10)
            ellipsoid(f.point(V(s*0.61,3.22,-2.24)),V(0.08,0.065,0.075),p.black,segments:10,rings:6)
            cmCurve(f,[V(s*0.46,2.6,-2.38),V(s*0.52,2.31,-2.90),V(s*0.62,2.48,-3.55)],radius:0.11,material:p.trim,segments:12)
        }
        cmCurve(f,[V(0,2.92,-2.37),V(0,2.2,-2.75),V(0.13,1.1,-2.95),V(0.28,0.48,-2.8)],radius:0.22,material:p.elephant,segments:16)
        cmCurve(f,[V(0,2.9,1.8),V(0.12,1.9,2.2),V(0.24,1.3,2.3)],radius:0.06,material:p.elephant)
    }
    private func cmPterosaur(_ f:CMFrame,_ c:V,_ p:CMPalette) {
        ellipsoid(f.point(c),V(0.20,0.22,0.7),p.bone,segments:12,rings:8)
        for s:Float in [-1,1] {let a=c+V(0,0,-0.2),b=c+V(s*3.4,0.5,0.2),d=c+V(s*0.55,-0.25,1.6);tri(f.point(a),f.point(b),f.point(d),p.bone);cmCurve(f,[a,c+V(s*1.4,0.45,0),b],radius:0.045,material:p.bone,segments:8)}
        cmCurve(f,[c,c+V(0,0.55,-1),c+V(0,0.65,-1.6)],radius:0.075,material:p.bone)
        beam(f.point(c),f.point(c+V(0,7.0,0)),0.01,0.01,p.bronze)
    }
    /// Small extruded block-letter signs, authored geometry without image textures.
    private func cmLabel(_ text:String,_ center:V,_ tangent:V,_ normal:V,_ height:Float,_ material:UInt32) {
        let glyphs:[Character:[String]]=[
            "B":["11110","10001","10001","11110","10001","10001","11110"],"D":["11110","10001","10001","10001","10001","10001","11110"],"F":["11111","10000","10000","11110","10000","10000","10000"],"Q":["01110","10001","10001","10001","10101","10010","01101"],"U":["10001","10001","10001","10001","10001","10001","01110"],"Y":["10001","10001","01010","00100","00100","00100","00100"],
            "A":["01110","10001","10001","11111","10001","10001","10001"],"C":["01111","10000","10000","10000","10000","10000","01111"],
            "E":["11111","10000","10000","11110","10000","10000","11111"],"G":["01111","10000","10000","10111","10001","10001","01110"],
            "H":["10001","10001","10001","11111","10001","10001","10001"],"I":["11111","00100","00100","00100","00100","00100","11111"],
            "K":["10001","10010","10100","11000","10100","10010","10001"],"L":["10000","10000","10000","10000","10000","10000","11111"],
            "M":["10001","11011","10101","10101","10001","10001","10001"],"N":["10001","11001","11001","10101","10011","10011","10001"],
            "O":["01110","10001","10001","10001","10001","10001","01110"],"P":["11110","10001","10001","11110","10000","10000","10000"],
            "R":["11110","10001","10001","11110","10100","10010","10001"],"S":["01111","10000","10000","01110","00001","00001","11110"],
            "T":["11111","00100","00100","00100","00100","00100","00100"],"W":["10001","10001","10001","10101","10101","11011","10001"],
            "8":["01110","10001","10001","01110","10001","10001","01110"],"7":["11111","00001","00010","00100","01000","01000","01000"],
            "5":["11111","10000","10000","11110","00001","00001","11110"]]
        let pitch=height/7,width=Float(text.count)*pitch*6
        for (letter,ch) in text.enumerated() {
            guard let glyph=glyphs[ch] else {continue}
            for (row,bits) in glyph.enumerated() {
                for (col,bit) in bits.enumerated() where bit=="1" {
                    let u = -width/2+(Float(letter)*6+Float(col)+0.5)*pitch,y=height/2-(Float(row)+0.5)*pitch
                    orientedBox(center+tangent*u+V(0,y,0),tangent,V(0,1,0),normal,V(pitch*0.92,pitch*0.92,pitch*0.38),material)
                }
            }
        }
    }
}
