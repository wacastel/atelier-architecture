import Foundation
import simd

/// Authored landmark details on surveyed map footprints. Heights and ornament
/// are photograph-informed estimates, not an as-built architectural survey.
enum NorthSideLandmarksLayout {
    static let church = SIMD3<Float>(-404,0,-3740)
    static let churchTower = SIMD3<Float>(-400.8,0,-3767.5)
    static let beachHouse = SIMD3<Float>(972.045,0,-3852.612)
    static let beachAxis = simd_normalize(SIMD3<Float>(0.81,0,0.586))
    static let beachAcross = SIMD3<Float>(-beachAxis.z,0,beachAxis.x)
    static func beachPoint(_ local:SIMD3<Float>)->SIMD3<Float> {
        beachHouse+beachAxis*local.x+SIMD3(0,local.y,0)+beachAcross*local.z
    }
}

private struct NorthLandmarkPalette {
    let brick:UInt32, trim:UInt32, roof:UInt32, recess:UInt32, brass:UInt32
    let white:UInt32, blue:UInt32, red:UInt32, glass:UInt32, deck:UInt32
    let clock:UInt32, lamp:UInt32, black:UInt32
    let stained:[UInt32]
}

extension EiffelBuilder {
    func northSideLandmarks() {
        func add(_ m:SceneMaterial)->UInt32 { let id=UInt32(scene.materials.count);scene.materials.append(m);return id }
        let p=NorthLandmarkPalette(
            brick:add(SceneMaterial(V(0.40,0.14,0.075),roughness:0.85,pattern:19)),
            trim:add(SceneMaterial(V(0.76,0.68,0.53),roughness:0.75,pattern:10)),
            roof:add(SceneMaterial(V(0.08,0.125,0.115),roughness:0.54,metallic:0.18)),
            recess:add(SceneMaterial(V(0.034,0.031,0.027),roughness:0.85)),
            brass:add(SceneMaterial(V(0.64,0.43,0.12),roughness:0.35,metallic:0.75)),
            white:add(SceneMaterial(V(0.81,0.82,0.78),roughness:0.58)),
            blue:add(SceneMaterial(V(0.015,0.08,0.38),roughness:0.37,metallic:0.14)),
            red:add(SceneMaterial(V(0.63,0.037,0.024),roughness:0.52)),
            glass:add(SceneMaterial(V(0.07,0.15,0.18),roughness:0.16,metallic:0.64,emission:0.08,pattern:14)),
            deck:add(SceneMaterial(V(0.54,0.50,0.40),roughness:0.85,pattern:1)),
            clock:add(SceneMaterial(V(0.77,0.73,0.61),roughness:0.52,emission:0.18,pattern:16)),
            lamp:add(SceneMaterial(V(1,0.72,0.38),roughness:0.5,emission:0.8,pattern:16)),
            black:add(SceneMaterial(V(0.012,0.017,0.021),roughness:0.52)),
            stained:[V(0.28,0.10,0.045),V(0.04,0.13,0.32),V(0.35,0.035,0.04),V(0.07,0.22,0.13)].map {add(SceneMaterial($0,roughness:0.24,metallic:0.32,emission:0.30,pattern:16))})
        oldTownSaintMichael(p)
        northAvenueBeachHouse(p)
    }

    private func northMappedShell(_ id:Int64,top:Float,wall:UInt32,roof:UInt32) {
        guard let footprint=NorthSideContext.landmark(id) else {preconditionFailure("North Side landmark \(id) is missing")}
        for ring in footprint.rings {
            for i in ring.indices {
                let a=ring[i],b=ring[(i+1)%ring.count]
                quad(V(a[0],0.04,a[1]),V(b[0],0.04,b[1]),V(b[0],top,b[1]),V(a[0],top,a[1]),wall)
            }
        }
        for i in stride(from:0,to:footprint.triangles.count,by:3) {
            let a=footprint.points[footprint.triangles[i]],b=footprint.points[footprint.triangles[i+1]],c=footprint.points[footprint.triangles[i+2]]
            tri(V(a[0],top,a[1]),V(b[0],top,b[1]),V(c[0],top,c[1]),roof)
        }
    }

    private func northArch(_ base:V,tangent:V,normal:V,width:Float,straight:Float,trim:Float,material:UInt32,fill:UInt32) {
        let up=V(0,1,0),r=width/2,center=base+up*straight
        quad(base-tangent*r,base+tangent*r,center+tangent*r,center-tangent*r,fill)
        for i in 0..<24 {
            let a=Float(i)*Float.pi/24,b=Float(i+1)*Float.pi/24
            let na=tangent*cos(a)+up*sin(a),nb=tangent*cos(b)+up*sin(b)
            tri(center,center+nb*r,center+na*r,fill)
            let aa=center+na*r,bb=center+nb*r,cc=center+nb*(r+trim),dd=center+na*(r+trim)
            quad(aa+normal*0.08,bb+normal*0.08,cc+normal*0.08,dd+normal*0.08,material)
            quad(aa,aa+normal*0.08,bb+normal*0.08,bb,material)
        }
        for side:Float in [-1,1] {
            orientedBox(base+tangent*(side*(r+trim/2))+up*(straight/2)+normal*0.06,tangent,up,normal,V(trim,straight,0.16),material)
        }
        orientedBox(base+normal*0.11,tangent,up,normal,V(width+trim*2,0.20,0.32),material)
    }

    private func oldTownSaintMichael(_ p:NorthLandmarkPalette) {
        northMappedShell(210315405,top:8.5,wall:p.brick,roof:p.roof)
        let c=NorthSideLandmarksLayout.church
        // Main nave runs north–south. Lower service wings keep the mapped outline.
        box(c+V(0,12,0),V(25.4,24,62),p.brick)
        for side:Float in [-1,1] {
            let normal=V(side,0,0),tangent=V(0,0,1)
            for bay in 0..<7 {
                let z=c.z-25+Float(bay)*8.3
                northArch(V(c.x+side*12.78,7,z),tangent:tangent,normal:normal,width:2.8,straight:10.2,trim:0.30,material:p.trim,fill:p.stained[0])
                for row in 0..<7 {
                    for col in 0..<3 {
                        orientedBox(V(c.x+side*12.86,7.2+Float(row)*1.35,z+Float(col-1)*0.86),tangent,V(0,1,0),normal,V(0.79,1.20,0.025),p.stained[(row+col+bay)%4])
                    }
                }
                box(V(c.x+side*13.1,12.5,z+3.7),V(0.70,24.8,0.75),p.brick)
                box(V(c.x+side*13.2,3.1,z),V(0.7,0.45,6.6),p.trim)
                // Paired slender stained-glass divisions, visible during close passes.
                for offset:Float in [-0.50,0.50] {box(V(c.x+side*12.87,12.1,z+offset),V(0.08,10.1,0.05),p.trim)}
            }
            box(c+V(side*12.95,23.75,0),V(0.7,0.55,63),p.trim)
            for z in stride(from:c.z-30,to:c.z+31,by:1.25) {box(V(c.x+side*13.0,23.1,z),V(0.5,0.8,0.32),p.trim)}
        }
        // Pitched copper/slate roof and masonry gables.
        for side:Float in [-1,1] {
            quad(c+V(side*13.7,24,-32),c+V(side*13.7,24,32),c+V(0,34,32),c+V(0,34,-32),p.roof)
            for z in stride(from:Float(-31),through:31,by:2.8) {beam(c+V(side*13.6,24.1,z),c+V(0,34.1,z),0.065,0.065,p.roof)}
        }
        for z:Float in [-31,31] {tri(c+V(-12.7,24,z),c+V(12.7,24,z),c+V(0,34,z),p.brick)}
        // Northern portal is framed by brick pilasters and Romanesque arches.
        let front:Float = -3773.95
        let frontCenter:Float = -401.2
        box(V(frontCenter,12,front+1.8),V(35,24,3.6),p.brick)
        for side:Float in [-1,1] {
            box(V(frontCenter+side*15.2,16,front+1.4),V(3.2,32,3.4),p.brick)
            for y:Float in [6.8,21.5,31.8] {box(V(frontCenter+side*15.2,y,front+1.4),V(3.7,0.40,3.9),p.trim)}
            let top=V(frontCenter+side*15.2,35.7,front+1.4)
            let corners=[V(-2,32,-2),V(2,32,-2),V(2,32,2),V(-2,32,2)]
            for i in 0..<4 {tri(V(frontCenter+side*15.2,0,front+1.4)+corners[i],V(frontCenter+side*15.2,0,front+1.4)+corners[(i+1)%4],top,p.roof)}
        }
        for x:Float in [-10,0,10] {
            northArch(V(frontCenter+x,0.4,front-0.04),tangent:V(1,0,0),normal:V(0,0,-1),width:4.1,straight:4.5,trim:0.80,material:p.trim,fill:p.recess)
            northArch(V(frontCenter+x,10.4,front-0.04),tangent:V(1,0,0),normal:V(0,0,-1),width:x==0 ? 4.8:3.3,straight:7.3,trim:0.52,material:p.trim,fill:p.stained[x==0 ? 1:0])
            for row in 0..<5 {
                for col in 0..<3 {
                    box(V(frontCenter+x+Float(col-1)*0.85,10.65+Float(row)*1.32,front-0.10),V(0.78,1.16,0.035),p.stained[(row+col)%4])
                }
            }
            // Deep paired portal shafts, layered archivolts and wooden leaves.
            for side:Float in [-1,1] {
                for offset:Float in [0,0.27] {
                    let shaft=V(frontCenter+x+side*(2.45+offset),0.45,front-0.25-offset)
                    cylinder(shaft,shaft+V(0,4.45,0),0.14,p.trim,segments:12)
                    box(shaft+V(0,0.13,0),V(0.42,0.26,0.48),p.trim)
                    box(shaft+V(0,4.36,0),V(0.44,0.30,0.45),p.trim)
                }
                box(V(frontCenter+x+side*0.97,2.28,front-0.1),V(1.82,3.65,0.14),timber)
                for y:Float in [1.2,3.5] {box(V(frontCenter+x+side*0.97,y,front-0.20),V(1.54,0.075,0.07),p.black)}
            }
            for side:Float in [-1,1] {
                let yy:Float=21.0,xx=frontCenter+x+side*3.2
                box(V(xx,12.1,front-0.12),V(0.38,yy-3.0,0.34),p.trim)
            }
            box(V(frontCenter+x,2,front-0.14),V(0.09,3.3,0.15),p.brass)
        }
        for y:Float in [8.6,22.4,23.4] {box(V(frontCenter,y,front-0.28),V(35.6,0.38,0.75),p.trim)}
        for x in stride(from:frontCenter-17,to:frontCenter+17,by:0.85) {
            box(V(x,22.0,front-0.39),V(0.22,0.53,0.36),p.trim)
        }
        for side:Float in [-1,1] {
            for z in stride(from:c.z-24,to:c.z+28,by:10) {
                scene.lights.append(NightLighting.source(V(c.x+side*18,13,z),toward:V(c.x+side*12,12,z),power:70,color:V(1,0.77,0.48),range:23,radius:0.8,outerDegrees:77,innerDegrees:56))
            }
        }
        let tower=NorthSideLandmarksLayout.churchTower
        box(tower+V(0,26,0),V(11.4,52,11.4),p.brick)
        for y:Float in [2.4,23.5,35.0,51.7] {box(tower+V(0,y,0),V(12.1,0.58,12.1),p.trim)}
        for normal in [V(1,0,0),V(-1,0,0),V(0,0,1),V(0,0,-1)] {
            let tangent=simd_cross(V(0,1,0),normal)
            for level:Float in [8,25,37] {
                northArch(tower+normal*5.73+V(0,level,0),tangent:tangent,normal:normal,width:3.5,straight:level==37 ? 5.5:8,trim:0.42,material:p.trim,fill:p.recess)
                for y in stride(from:level+0.3,to:level+(level==37 ? 5.8:8.4),by:0.48) {orientedBox(tower+normal*5.78+V(0,y,0),tangent,V(0,1,0),normal,V(3.35,0.12,0.09),p.roof)}
            }
            let clock=tower+normal*5.79+V(0,48,0)
            cylinder(clock,clock+normal*0.13,2.38,p.trim,segments:64)
            cylinder(clock+normal*0.14,clock+normal*0.19,2.04,p.clock,segments:64)
            for i in 0..<12 {
                let a=Float(i)*Float.pi/6,r=tangent*sin(a)+V(0,cos(a),0)
                beam(clock+normal*0.24+r*1.65,clock+normal*0.24+r*1.91,0.10,0.035,p.black,normal:normal)
            }
            beam(clock+normal*0.28,clock+normal*0.28+tangent*1.48+V(0,0.25,0),0.12,0.04,p.black,normal:normal)
            beam(clock+normal*0.30,clock+normal*0.30-tangent*0.45+V(0,1.1,0),0.15,0.04,p.black,normal:normal)
            // Gabled spire base, then an eight-sided needle with gilt cross.
            tri(tower+normal*5.82-tangent*5.7+V(0,51.9,0),tower+normal*5.82+tangent*5.7+V(0,51.9,0),tower+normal*5.82+V(0,60,0),p.brick)
            for y:Float in [16,33,48,61] {
                scene.lights.append(NightLighting.source(tower+normal*13+V(0,y,0),toward:tower+V(0,y+1,0),power:105,color:V(1,0.76,0.46),range:29,radius:1,outerDegrees:72,innerDegrees:48))
            }
        }
        for i in 0..<8 {
            let a=Float(i)*Float.pi/4,b=Float(i+1)*Float.pi/4
            let pa=tower+V(cos(a)*6.1,55,sin(a)*6.1),pb=tower+V(cos(b)*6.1,55,sin(b)*6.1),tip=tower+V(0,80.8,0)
            tri(pa,pb,tip,p.roof);beam(pa,tip,0.07,0.07,p.brass)
        }
        cylinder(tower+V(0,80.5,0),tower+V(0,88.39,0),0.14,p.brass,segments:12)
        box(tower+V(0,85.8,0),V(2.75,0.24,0.23),p.brass)
    }

    private func northAvenueBeachHouse(_ p:NorthLandmarkPalette) {
        let at=NorthSideLandmarksLayout.beachPoint,u=NorthSideLandmarksLayout.beachAxis,n=NorthSideLandmarksLayout.beachAcross,up=V(0,1,0)
        func part(_ x:Float,_ y:Float,_ z:Float,_ size:V,_ material:UInt32) {orientedBox(at(V(x,y,z)),u,up,n,size,material)}
        northMappedShell(417380833,top:3.9,wall:p.white,roof:p.deck)
        guard let footprint=NorthSideContext.landmark(417380833) else {return}
        for ring in footprint.rings {
            var signed:Float=0
            for i in ring.indices {let a=ring[i],b=ring[(i+1)%ring.count];signed += a[0]*b[1]-b[0]*a[1]}
            for i in ring.indices {
                let aa=ring[i],bb=ring[(i+1)%ring.count],a=V(aa[0],0,aa[1]),b=V(bb[0],0,bb[1]),length=simd_distance(a,b)
                guard length>0.5 else {continue}
                let tangent=(b-a)/length,out=V(tangent.z,0,-tangent.x)*(signed>0 ? 1:-1)
                for y:Float in [0.18,3.6,3.94] {beam(a+V(0,y,0)+out*0.14,b+V(0,y,0)+out*0.14,y<1 ? 0.15:0.19,0.26,p.blue)}
                let count=max(1,Int(length/3.0))
                for j in 0..<count {
                    let center=a+tangent*((Float(j)+0.5)*length/Float(count))
                    let window=center+V(0,2,0)+out*0.06
                    cylinder(window,window+out*0.08,0.59,p.blue,segments:32)
                    cylinder(window+out*0.09,window+out*0.12,0.43,p.glass,segments:32)
                    cylinder(center+out*0.30+V(0,4.02,0),center+out*0.30+V(0,5.15,0),0.035,p.white,segments:6)
                }
                for y:Float in [4.42,4.78,5.16] {cylinder(a+out*0.3+V(0,y,0),b+out*0.3+V(0,y,0),0.031,p.white,segments:6)}
                if length>6 {
                    let lamp=(a+b)/2+out*0.35+V(0,3.28,0)
                    orientedBox(lamp,tangent,up,out,V(0.40,0.16,0.18),p.lamp)
                    scene.lights.append(NightLighting.source(lamp+out*0.3,toward:lamp+out*3-V(0,3,0),power:32,color:V(1,0.79,0.55),range:16,radius:0.3,outerDegrees:80,innerDegrees:55))
                }
            }
        }
        // Ocean-liner profile: raised bridge, wraparound glazing and red funnels.
        part(-7,5.6,0,V(30,3.25,10.6),p.white)
        part(-7,7.27,0,V(32,0.24,12),p.blue)
        for side:Float in [-1,1] {
            part(-7,6.17,side*5.36,V(28,1.32,0.08),p.glass)
            for x in stride(from:Float(-20),through:7,by:2.6) {part(x,6.18,side*5.46,V(0.085,1.43,0.13),p.white)}
        }
        for x:Float in [-17,10] {
            cylinder(at(V(x,7.4,0)),at(V(x,10.5,0)),1.7,p.red,segments:48)
            cylinder(at(V(x,9.7,0)),at(V(x,10.12,0)),1.72,p.black,segments:48)
        }
        cylinder(at(V(-31,4,0)),at(V(-31,15,0)),0.075,p.white,segments:12)
        beam(at(V(-34,12.2,0)),at(V(-28,12.2,0)),0.075,0.075,p.white)
        // Small flag cloth is static geometry; stable sampling keeps its stripes calm.
        for i in 0..<13 {
            let y=14.6-Float(i)*0.115
            quad(at(V(-31,y,0)),at(V(-28.5,y-0.15,0.15)),at(V(-28.5,y-0.265,0.15)),at(V(-31,y-0.115,0)),i%2==0 ? p.red:p.white)
        }
        quad(at(V(-31,14.61,-0.015)),at(V(-29.9,14.54,0.05)),at(V(-29.9,13.75,0.05)),at(V(-31,13.80,-0.015)),p.blue)
        // Deck tables and folded parasols stay clear of the central route.
        for x in stride(from:Float(-32),through:32,by:6) {
            for z:Float in [-7.3,7.3] {
                if abs(x)>20 && z<0 {continue}
                cylinder(at(V(x,4.0,z)),at(V(x,4.82,z)),0.055,p.blue,segments:8)
                cylinder(at(V(x,4.82,z)),at(V(x,4.89,z)),0.76,p.white,segments:20)
                for side:Float in [-1,1] {
                    part(x,4.46,z+side*1.05,V(0.53,0.08,0.55),p.blue)
                    part(x,4.90,z+side*1.32,V(0.53,0.73,0.07),p.white)
                }
            }
        }
        for x:Float in [-34,-9,20,40] {
            for side:Float in [-1,1] {
                let light=at(V(x,7.8,side*9))
                scene.lights.append(NightLighting.source(light,toward:at(V(x,3,side*1.8)),power:52,color:V(0.83,0.91,1),range:23,radius:0.85,outerDegrees:73,innerDegrees:50))
            }
        }
        for x:Float in [-17,10] {
            scene.lights.append(NightLighting.source(at(V(x,10,-5)),toward:at(V(x,9,0)),power:22,color:V(1,0.79,0.58),range:11,radius:0.5,outerDegrees:65,innerDegrees:40))
        }
        // Blue-white lifeguard stands and beach volleyball nets near the house.
        for x:Float in [-70,-35,0,35] {
            let z:Float = -45
            for side:Float in [-1,1] {cylinder(at(V(x+side*4.5,0,z)),at(V(x+side*4.5,2.55,z)),0.05,p.blue,segments:8)}
            for y in stride(from:Float(1.6),through:2.5,by:0.18) {beam(at(V(x-4.5,y,z)),at(V(x+4.5,y,z)),0.025,0.025,p.white)}
            for xx in stride(from:x-4.5,through:x+4.5,by:0.32) {beam(at(V(xx,1.6,z)),at(V(xx,2.5,z)),0.02,0.02,p.white)}
        }
    }
}
