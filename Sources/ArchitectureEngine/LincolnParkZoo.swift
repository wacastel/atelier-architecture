import Foundation
import simd

/// Shared metre-scale anchors: X east, Z south. OSM positions are measured;
/// facade heights, planting and seasonal lighting are photographic interpretations.
enum LincolnParkZooLayout {
    static let pavilionCenter = SIMD3<Float>(294.357,0.12,-4336.954)
    static let pavilionForward = SIMD3<Float>(-0.330,0,-0.944)
    static let cafeCenter = SIMD3<Float>(167.304,0,-4479.127)
    static let lionHouse = SIMD3<Float>(214.395,0,-4726.105)
    static let conservatory = SIMD3<Float>(70.958,0,-5065.526)
    static let lilyPool = SIMD3<Float>(156.906,-0.25,-5131.423)
    static let fisherBridgeStart = SIMD3<Float>(210.070,3.2,-4368.765)
    static let fisherBridgeEnd = SIMD3<Float>(255.913,3.2,-4390.439)
    static let natureStart = SIMD3<Float>(298.65,1.92,-4324.68)
    static let zooStart = SIMD3<Float>(258,1.8,-4641.5)
    static let conservatoryStart = SIMD3<Float>(46,1.8,-4987)
    static let lilyStart = SIMD3<Float>(184,1.8,-5114)
    static let natureRoute: [SIMD3<Float>] = [natureStart,SIMD3(294.357,1.92,-4336.954),SIMD3(290.77,1.92,-4345.43),SIMD3(288.39,1.92,-4352.67),SIMD3(286.57,1.92,-4362.56),SIMD3(281.68,1.92,-4372.71),SIMD3(268.34,1.92,-4367.82),SIMD3(263.42,1.92,-4364.37),SIMD3(273.11,1.92,-4338.91),SIMD3(282.24,1.92,-4313.43),SIMD3(293.21,1.92,-4308.52)]
    static let zooRoute: [SIMD3<Float>] = [zooStart,SIMD3(258.6,1.8,-4667.7),SIMD3(259.3,1.8,-4703.8),SIMD3(261.1,1.8,-4731.1),SIMD3(260.4,1.8,-4771.5)]
    static let conservatoryRoute: [SIMD3<Float>] = [conservatoryStart,SIMD3(45,1.8,-5000),SIMD3(27,1.8,-5010),SIMD3(19,1.8,-5042),SIMD3(20,1.8,-5070)]
    static let lilyRoute: [SIMD3<Float>] = [lilyStart,SIMD3(184,1.8,-5140),SIMD3(179,1.8,-5160),SIMD3(171,1.8,-5182),SIMD3(157,1.8,-5190)]
    /// The angular perturbation vanishes at both poles, yielding one shared
    /// pole vertex rather than a stack of disconnected sharp triangle fans.
    static func foliagePoint(angle a:Float,latitude v:Float,radius r:SIMD3<Float>,seed:Float)->SIMD3<Float> {
        let horizontal=cos(v)
        if abs(horizontal)<0.000001 {return SIMD3(0,v>0 ? r.y:-r.y,0)}
        let ripple=(0.065*sin(a*5+seed)*cos(v*3)+0.045*cos(a*7-v*4+seed))*horizontal*horizontal
        return SIMD3(horizontal*cos(a),sin(v),horizontal*sin(a))*r*(1+ripple)
    }
    static let authoredBuildingIDs: Set<Int64> = [24826112,186667195,23986733,210686223,992815961,210686220,24826074,210685702,210686226,210686225,210686219]
}

private struct ZooPalette {
    let brick,stone,mortar,roof,roofSeam,wood,paleWood,iron,glass,window,leaf,flower,reed,rock,sand,white:UInt32
    let warmLens:UInt32
    let colors:[SIMD3<Float>]
    let lenses:[UInt32]
}

extension EiffelBuilder {
    func lincolnParkZoo() {
        func mat(_ c:V,_ r:Float=0.7,_ metal:Float=0,_ pattern:Float=0,_ emission:Float=0,_ transmission:Float=0)->UInt32 {
            let i=UInt32(scene.materials.count)
            scene.materials.append(SceneMaterial(c,roughness:r,metallic:metal,emission:emission,pattern:pattern,transmission:transmission));return i
        }
        let colors:[V]=[V(0.12,0.32,1),V(0.75,0.08,0.9),V(0.12,1,0.38),V(1,0.10,0.055),V(1,0.68,0.12)]
        let p=ZooPalette(brick:mat(V(0.32,0.105,0.054),0.81,0,19),stone:mat(V(0.59,0.52,0.39),0.86,0,1),mortar:mat(V(0.34,0.29,0.22),0.9),roof:mat(V(0.095,0.20,0.14),0.55,0.35,5),roofSeam:mat(V(0.045,0.095,0.072),0.52,0.4),wood:mat(V(0.32,0.19,0.085),0.63,0,3),paleWood:mat(V(0.65,0.38,0.17),0.48,0,3),iron:mat(V(0.035,0.07,0.065),0.41,0.65),glass:mat(V(0.98,0.992,0.98),0.045,0,0,0,1),window:mat(V(0.075,0.12,0.10),0.15,0.35,7),leaf:mat(V(0.105,0.23,0.065),0.95,0,4),flower:mat(V(0.58,0.21,0.46),0.94),reed:mat(V(0.37,0.36,0.11),0.95),rock:mat(V(0.37,0.38,0.33),0.96,0,1),sand:mat(V(0.45,0.37,0.22),0.98),white:mat(V(0.71,0.75,0.66),0.68),warmLens:mat(V(1,0.79,0.46),0.4,0,16,0.45),colors:colors,lenses:colors.map{mat($0,0.5,0,16,0.9)})
        zooCafe(p)
        zooNatureBoardwalk(p)
        zooHistoricBuildings(p)
        zooConservatory(p)
        zooLilyPool(p)
        zooHabitats(p)
        zooSeasonalLights(p)
        zooPlanting(p)
    }

    private func zooSurface(_ shape:LincolnParkZooMap.Shape,_ y:Float,_ m:UInt32) {
        for i in stride(from:0,to:shape.triangles.count,by:3) {
            let a=shape.points[shape.triangles[i]],b=shape.points[shape.triangles[i+1]],c=shape.points[shape.triangles[i+2]]
            tri(V(a.x,y,a.y),V(c.x,y,c.y),V(b.x,y,b.y),m)
        }
    }
    private func zooShell(_ id:Int64,height:Float,_ p:ZooPalette,_ wall:UInt32?=nil) {
        let shape=LincolnParkZooMap.shape(id),m=wall ?? p.brick
        zooSurface(shape,0.05,p.stone);zooSurface(shape,height,p.roof)
        for ring in shape.rings {for i in ring.indices {
            let aa=ring[i],bb=ring[(i+1)%ring.count],a=V(aa.x,0,aa.y),b=V(bb.x,0,bb.y),len=simd_distance(a,b)
            guard len>0.05 else {continue}
            let t=(b-a)/len,n=V(-t.z,0,t.x)
            quad(a,b,b+V(0,height,0),a+V(0,height,0),m)
            for y:Float in [0.32,height-0.55,height-0.15] {beam(a+V(0,y,0),b+V(0,y,0),0.19,0.27,p.stone)}
            let count=Int(len/3.4)
            if count>0 {for j in 0..<count {
                let q=a+t*(Float(j)+0.5)*len/Float(count)+V(0,height*0.51,0)
                // Both sides of the exact mapped boundary are represented,
                // independent of source ring winding.
                for s:Float in [-1,1] {
                    orientedBox(q+n*s*0.025,t,V(0,1,0),n,V(min(1.7,len/Float(count)*0.58),height*0.44,0.04),p.window)
                    for dy:Float in [-height*0.22,0,height*0.22] {beam(q+n*s*0.055-t*0.91+V(0,dy,0),q+n*s*0.055+t*0.91+V(0,dy,0),0.065,0.08,p.iron)}
                }
                beam(a+t*Float(j)*len/Float(count)+V(0,0.5,0),a+t*Float(j)*len/Float(count)+V(0,height-0.3,0),0.22,0.24,p.stone)
            }}
            // Explicit brick courses on long public facades, kept at a useful
            // close-view spacing and bounded by the footprint segments.
            if len>5 {for y in stride(from:Float(0.7),through:height-0.8,by:0.32) {beam(a+V(0,y,0),b+V(0,y,0),0.012,0.018,p.mortar)}}
        }}
    }
    private func zooHip(_ c:V,_ x:V,_ z:V,_ w:Float,_ d:Float,_ rise:Float,_ p:ZooPalette) {
        let a=c-x*w/2-z*d/2,b=c+x*w/2-z*d/2,cc=c+x*w/2+z*d/2,e=c-x*w/2+z*d/2
        let inset=min(w,d)*0.30,ra=c-z*max(0,d/2-inset)+V(0,rise,0),rb=c+z*max(0,d/2-inset)+V(0,rise,0)
        tri(a,ra,b,p.roof);quad(b,ra,rb,cc,p.roof);tri(cc,rb,e,p.roof);quad(e,rb,ra,a,p.roof)
        beam(ra,rb,0.12,0.12,p.roofSeam)
        for (u,v) in [(a,ra),(b,ra),(cc,rb),(e,rb)] {beam(u,v,0.10,0.10,p.roofSeam)}
        for i in 1..<Int(d/1.1) {
            let f=Float(i)/Float(Int(d/1.1)),a0=c+z*(f-0.5)*d
            let h=rise*min(1,min(f,1-f)*d/inset)
            for s:Float in [-1,1] {beam(a0+x*s*w/2,a0+V(0,h,0),0.035,0.045,p.roofSeam)}
        }
    }
    private func zooArch(_ c:V,_ tangent:V,_ normal:V,width:Float,height:Float,_ p:ZooPalette) {
        let radius=width/2,spring=height-radius
        for s:Float in [-1,1] {beam(c+tangent*s*(radius+0.16),c+tangent*s*(radius+0.16)+V(0,spring,0),0.32,0.38,p.stone)}
        for i in 0..<24 {
            let a=Float(i)*Float.pi/24,b=Float(i+1)*Float.pi/24
            let aa=c+tangent*cos(a)*(radius+0.16)+V(0,spring+sin(a)*(radius+0.16),0)
            let bb=c+tangent*cos(b)*(radius+0.16)+V(0,spring+sin(b)*(radius+0.16),0)
            beam(aa,bb,0.30,0.38,p.stone,normal:normal)
        }
    }
    private func zooCafe(_ p:ZooPalette) {
        let c=LincolnParkZooLayout.cafeCenter,x=V(0.970,0,0.243),z=V(-0.243,0,0.970)
        zooShell(24826112,height:5.5,p)
        // Raised Great Hall and the two open Prairie-style loggias use a
        // roof-axis measured from the mapped east wall, within the source hull.
        orientedBox(c+V(0,8,0),x,V(0,1,0),z,V(24,5,27),p.brick)
        zooHip(c+V(0,10.8,0),x,z,27,31,5,p)
        for side:Float in [-1,1] {
            let wing=c+z*side*22+V(0,5.5,0)
            zooHip(wing+V(0,3.3,0),x,z,24,16,3.2,p)
            for xx:Float in [-10.5,10.5] {for zz:Float in [-6.5,-2.2,2.2,6.5] {
                let q=wing+x*xx+z*zz
                orientedBox(q+V(0,1.65,0),x,V(0,1,0),z,V(0.55,3.3,0.55),p.brick)
                orientedBox(q+V(0,2.9,0),x,V(0,1,0),z,V(0.9,0.24,0.9),p.stone)
            }}
            for xx:Float in [-10,0,10] {zooLamp(wing+x*xx+V(0,2.9,0),p,power:14,range:12)}
        }
        for side:Float in [-1,1] {for dz:Float in [-8,-4,0,4,8] {
            let q=c+x*side*12.04+z*dz+V(0,7.8,0)
            orientedBox(q,x,V(0,1,0),z,V(0.06,3.3,2.4),p.window)
            for h:Float in [-1.65,0,1.65] {beam(q-z*1.35+V(0,h,0),q+z*1.35+V(0,h,0),0.1,0.12,p.stone)}
            for zz:Float in [-1.25,0,1.25] {beam(q+z*zz+V(0,-1.6,0),q+z*zz+V(0,1.6,0),0.09,0.1,p.white)}
        }}
        // Low eastern waterside terrace, furniture, balustrade, broad facade wash.
        let terrace=c+x*18+V(0,0.1,0)
        orientedBox(terrace,x,V(0,1,0),z,V(7,0.2,31),p.stone)
        for dz:Float in [-12,-6,0,6,12] {
            let q=terrace+z*dz
            cylinder(q+V(0,0.2,0),q+V(0,0.8,0),0.045,p.iron)
            cylinder(q+V(0,0.78,0),q+V(0,0.84,0),0.65,p.wood,segments:16)
            for s:Float in [-1,1] {box(q+x*s*1.1+V(0,0.48,0),V(0.5,0.09,0.5),p.wood)}
        }
        for dz:Float in [-22,-8,8,22] {
            let q=c+x*24+z*dz+V(0,0.4,0)
            scene.lights.append(NightLighting.source(q,toward:c+z*dz+V(0,7,0),power:155,color:V(1,0.79,0.55),range:36,radius:0.6,outerDegrees:87,innerDegrees:54))
        }
    }
    private func zooLamp(_ q:V,_ p:ZooPalette,power:Float=20,range:Float=18) {
        box(q,V(0.26,0.13,0.26),p.iron);box(q+V(0,-0.085,0),V(0.20,0.045,0.20),p.warmLens)
        scene.lights.append(NightLighting.source(q+V(0,-0.14,0),power:power,color:V(1,0.79,0.49),range:range,radius:0.22))
    }
    func zooFisherApproachRamp(from start:V,to end:V,material:UInt32) {
        // Beam width is cross(segment, reference). Its default world-up
        // reference keeps the broad deck horizontal across the graded ramp;
        // a sideways reference would turn the 8.8 m width into a tall wall.
        beam(start-V(0,0.22,0),end-V(0,0.22,0),8.8,0.44,material)
    }
    private func zooNatureBoardwalk(_ p:ZooPalette) {
        for path in LincolnParkZooMap.boardwalks {for i in 0..<path.points.count-1 {
            let a=path.points[i],b=path.points[i+1],len=simd_distance(a,b),t=(b-a)/len,n=V(-t.z,0,t.x)
            orientedBox((a+b)/2-V(0,0.07,0),n,V(0,1,0),t,V(2.6,0.14,len+0.06),p.wood)
            let count=max(1,Int(len/0.30))
            for j in 0...count {
                let q=a+t*Float(j)*len/Float(count)
                beam(q-n*1.3+V(0,0.003,0),q+n*1.3+V(0,0.003,0),0.012,0.013,p.roofSeam)
                if j%12==0 {for s:Float in [-1,1] {
                    cylinder(q+n*s*1.21-V(0,0.8,0),q+n*s*1.21+V(0,1.06,0),0.045,p.iron,segments:6)
                }}
            }
            for s:Float in [-1,1] {for y:Float in [0.35,0.70,1.05] {beam(a+n*s*1.21+V(0,y,0),b+n*s*1.21+V(0,y,0),y==1.05 ? 0.065:0.012,y==1.05 ? 0.065:0.012,p.iron)}}
        }}
        // Fisher Bridge is separate from the lower wood boardwalk, with clear
        // underpass headroom where their OSM paths intersect.
        let a=LincolnParkZooLayout.fisherBridgeStart,b=LincolnParkZooLayout.fisherBridgeEnd,t=simd_normalize(b-a),n=V(-t.z,0,t.x),len=simd_distance(a,b)
        orientedBox((a+b)/2-V(0,0.25,0),n,V(0,1,0),t,V(8.8,0.5,len),p.stone)
        for s:Float in [-1,1] {
            beam(a+n*s*4.15+V(0,1.1,0),b+n*s*4.15+V(0,1.1,0),0.16,0.16,p.stone)
            for j in 0...30 {let q=a+t*Float(j)*len/30+n*s*4.15;box(q+V(0,0.55,0),V(0.14,1.1,0.14),p.stone)}
        }
        for f:Float in [0,0.5,1] {let q=a+(b-a)*f;orientedBox(q-V(0,2.05,0),n,V(0,1,0),t,V(7,3.5,1.2),p.stone)}
        // Approach ramps reach the mapped street paths; lower boardwalks pass
        // beneath the central span rather than colliding with a solid abutment.
        for (q,out) in [(a,-t),(b,t)] {let end=q+out*14-V(0,3.08,0);zooFisherApproachRamp(from:q,to:end,material:p.stone)}
        let c=LincolnParkZooLayout.pavilionCenter,z=LincolnParkZooLayout.pavilionForward,x=V(-z.z,0,z.x)
        orientedBox(c-V(0,0.06,0),x,V(0,1,0),z,V(9.2,0.12,15.2),p.wood)
        // Woven glu-lam strips: sinusoidal offsets create the diamond openings
        // observed in Studio Gang's underside photo, with an open walk axis.
        for row in 0..<9 {for sign:Float in [-1,1] {
            let longitudinal=(Float(row)-4)*1.72
            for i in 0..<40 {
                func point(_ k:Int)->V {let a=Float(k)*Float.pi/40;let ripple=sin(a*4+Float(row) * .pi)*0.47;return c+x*cos(a)*(4.25+ripple)+V(0,0.05+sin(a)*5.55,0)+z*(longitudinal+sign*1.30*cos(a*3))}
                beam(point(i),point(i+1),0.19,0.24,p.paleWood)
            }
        }}
        for row in 0..<8 {for col in 0..<5 {
            let a=(Float(col)+0.5)*Float.pi/5,z0=(Float(row)-3.5)*1.72
            let q=c+x*cos(a)*4.35+V(0,sin(a)*5.65,0)+z*z0
            // Small cream fiberglass shells sit above the timber cells.
            let normal=simd_normalize(x*cos(a)+V(0,sin(a),0)),u=simd_normalize(simd_cross(z,normal))
            for j in 0..<12 {
                let aa=Float(j)*2*Float.pi/12,bb=Float(j+1)*2*Float.pi/12
                tri(q+normal*0.16,q+u*cos(aa)*0.56+z*sin(aa)*0.70,q+u*cos(bb)*0.56+z*sin(bb)*0.70,p.white)
            }
        }}
        for side:Float in [-1,1] {for dz:Float in [-5,0,5] {zooLamp(c+x*side*3.4+z*dz+V(0,2.65,0),p,power:9,range:8)}}
        // Shoreline plants use the exact pond ring; no random reeds in paths.
        let pond=LincolnParkZooMap.shape(-2514193)
        for ring in pond.rings {for i in stride(from:0,to:ring.count,by:2) {
            let a=ring[i],q=V(a.x,-0.38,a.y)
            for j in 0..<5 {let angle=Float(j)*2.399;let d=V(cos(angle),0,sin(angle))*0.30
                beam(q+d,q+d*2+V(0,0.7+Float(j%3)*0.24,0),0.023,0.035,p.reed)
            }
        }}
        for q in [V(280,0,-4370),V(281,0,-4326),V(332,0,-4188),V(243,0,-4434)] {zooPathLamp(q,p)}
        for i in 0..<7 {zooDuck(V(266+Float(i)*2.3,-0.48,-4270+sin(Float(i))*3),p)}
    }
    private func zooPathLamp(_ q:V,_ p:ZooPalette) {
        cylinder(q,q+V(0,3.5,0),0.045,p.iron,segments:8)
        zooLamp(q+V(0,3.5,0),p,power:23,range:24)
    }
    private func zooHistoricBuildings(_ p:ZooPalette) {
        for (id,h):(Int64,Float) in [(210686223,8.3),(210686220,7.4),(24826074,8.0),(210685702,7.0),(210686226,9.0),(210686225,6.0),(210686219,5.5)] {zooShell(id,height:h,p)}
        // The expanded habitat is open to the sky and visible through clear
        // viewing glass; avoid an opaque generic roof hiding the animal area.
        let habitat=LincolnParkZooMap.shape(992815961)
        zooSurface(habitat,0.06,p.sand)
        for ring in habitat.rings {for i in ring.indices {
            let av=ring[i],bv=ring[(i+1)%ring.count],a=V(av.x,0,av.y),b=V(bv.x,0,bv.y)
            quad(a+V(0,0.30,0),b+V(0,0.30,0),b+V(0,3.3,0),a+V(0,3.3,0),p.glass)
            beam(a+V(0,0.15,0),b+V(0,0.15,0),0.3,0.3,p.stone)
            let count=max(1,Int(simd_distance(a,b)/3.5))
            for j in 0...count {let q=a+(b-a)*Float(j)/Float(count);beam(q,q+V(0,3.35,0),0.08,0.09,p.iron)}
        }}
        zooHip(V(214.4,8.4,-4726),V(0,0,1),V(1,0,0),20,64,3.2,p)
        zooHip(V(283,7.5,-4667),V(0.999,0,-0.028),V(0.028,0,0.999),28,54,3.1,p)
        zooHip(V(220,8.1,-4892),V(1,0,0),V(0,0,1),35,52,4.2,p)
        for side:Float in [-1,1] {
            let q=V(214.4+side*33.3,0.1,-4728.6)
            zooArch(q,V(0,0,1),V(side,0,0),width:6.5,height:7.4,p)
            box(q+V(side*0.12,3.1,0),V(0.12,5.8,5.7),p.window)
            for dz:Float in [-2.85,0,2.85] {beam(q+V(side*0.22,0.2,dz),q+V(side*0.22,5.9,dz),0.10,0.11,p.iron)}
            scene.lights.append(NightLighting.source(q+V(side*7,0.45,0),toward:q+V(0,5,0),power:130,color:V(1,0.79,0.55),range:23,radius:0.45,outerDegrees:82,innerDegrees:48))
        }
        for x:Float in [188,201,214,227,240] {
            let q=V(x,0.4,-4708)
            scene.lights.append(NightLighting.source(q,toward:V(x,7,-4717),power:62,color:V(1,0.81,0.63),range:23,radius:0.35,outerDegrees:87,innerDegrees:54))
        }
        for z in stride(from:Float(-4643),through:-4777,by:-24) {zooPathLamp(V(253.7,0,z),p)}
        // Entry landscape and benches stay beside the mapped 6m public mall.
        for z:Float in [-4648,-4685,-4750] {for x:Float in [251.5,266.5] {
            box(V(x,0.5,z),V(1,0.13,2.6),p.wood);box(V(x+0.45,0.9,z),V(0.12,0.8,2.6),p.wood)
            for dz:Float in [-0.9,0.9] {box(V(x,0.24,z+dz),V(0.65,0.45,0.08),p.iron)}
        }}
    }
    private func zooConservatory(_ p:ZooPalette) {
        // Four connected display houses retain the measured irregular ground
        // perimeter. Roof bay dimensions follow the primary south-view photo;
        // the smaller northern service propagating houses remain restrained.
        let shape=LincolnParkZooMap.shape(23986733)
        zooSurface(shape,0.05,p.stone)
        for ring in shape.rings {for i in ring.indices {
            let a=ring[i],b=ring[(i+1)%ring.count]
            let aa=V(a.x,0,a.y),bb=V(b.x,0,b.y)
            quad(aa,bb,bb+V(0,0.8,0),aa+V(0,0.8,0),p.brick)
            quad(aa+V(0,0.8,0),bb+V(0,0.8,0),bb+V(0,3.7,0),aa+V(0,3.7,0),p.glass)
            beam(aa+V(0,3.7,0),bb+V(0,3.7,0),0.10,0.12,p.white)
            let len=simd_distance(aa,bb),count=max(1,Int(len/1.4))
            for j in 0...count {let q=aa+(bb-aa)*Float(j)/Float(count);beam(q+V(0,0.8,0),q+V(0,3.7,0),0.08,0.09,p.white)}
        }}
        let z=simd_normalize(V(-0.18,0,-1)),x=V(-z.z,0,z.x)
        // Front Palm House, Fern/Orchid side houses, rear Show House.
        let houses:[(V,Float,Float,Float)]=[(V(53,3.7,-5026),29,39,10.2),(V(43,3.7,-5069),20,43,5.0),(V(91,3.7,-5059),24,58,5.8),(V(78,3.7,-5104),27,39,5.4)]
        for (c,w,d,rise) in houses {
            zooGlassRoof(c,x,z,w,d,rise,p)
            // Visible planting is concentrated in side beds, leaving a real
            // open central aisle rather than filling the glass with solid green.
            for row in 0..<Int(d/5) {for side:Float in [-1,1] {
                let q=c+z*(Float(row)*5-d/2+3)+x*side*(w*0.30)-V(0,3.6,0)
                orientedBox(q+V(0,0.25,0),x,V(0,1,0),z,V(w*0.25,0.5,4.4),p.stone)
                if rise>8 && row%2==0 {zooPalm(q,height:6.0+Float(row%3)*0.7,p)}
                else {for j in 0..<3 {let q2=q+x*(Float(j)-1)*1.4;ellipsoid(q2+V(0,0.9,0),V(0.9,1.2,0.8),p.leaf,segments:8,rings:5)}}
            }}
            for side:Float in [-1,1] {for f:Float in [-0.3,0.3] {
                let q=c+x*side*w*0.35+z*d*f+V(0,1.6,0)
                zooLamp(q,p,power:21,range:17)
            }}
        }
        // South-facing formal flower beds and fountain; laid out as four
        // quadrants around a clear central approach, as in the CPD photograph.
        for side:Float in [-1,1] {for z0:Float in [-4980,-4963] {
            let q=V(51+side*13,0.06,z0)
            box(q,V(13,0.12,13),p.stone)
            for i in 0..<8 {for j in 0..<8 {
                let v=q+V((Float(i)-3.5)*1.45,0.22,(Float(j)-3.5)*1.45)
                ellipsoid(v,V(0.53,0.30,0.53),p.leaf,segments:6,rings:3)
                if (i+j)%2==0 {ellipsoid(v+V(0,0.31,0),V(0.27,0.20,0.27),p.flower,segments:6,rings:3)}
            }}
        }}
        let f=V(51,0,-4990)
        for i in 0..<64 {let a=Float(i)*2*Float.pi/64,b=Float(i+1)*2*Float.pi/64;beam(f+V(cos(a)*3.5,0.35,sin(a)*3.5),f+V(cos(b)*3.5,0.35,sin(b)*3.5),0.30,0.60,p.stone)}
        cylinder(f+V(0,0.04,0),f+V(0,0.06,0),3.3,water,segments:64)
        cylinder(f+V(0,0.08,0),f+V(0,2.6,0),0.07,p.glass,segments:8)
        for i in 0..<12 {let a=Float(i)*2*Float.pi/12;var prev=f+V(0,2.6,0)
            for j in 1...10 {let t=Float(j)/10,q=f+V(cos(a)*t*1.8,2.6*(1-t*t),sin(a)*t*1.8);beam(prev,q,0.024,0.026,p.glass);prev=q}
        }
        for q in [V(21,0,-5000),V(83,0,-5000),V(17,0,-5063)] {zooPathLamp(q,p)}
    }
    private func zooGlassRoof(_ c:V,_ x:V,_ z:V,_ w:Float,_ d:Float,_ rise:Float,_ p:ZooPalette) {
        let bays=max(4,Int(d/1.3)),slices=24
        func point(_ a:Float,_ along:Float)->V {c+x*cos(a)*w/2+V(0,sin(a)*rise,0)+z*along}
        for bay in 0..<bays {for i in 0..<slices {
            let a=Float(i)*Float.pi/Float(slices),b=Float(i+1)*Float.pi/Float(slices),lo=(Float(bay)/Float(bays)-0.5)*d,hi=(Float(bay+1)/Float(bays)-0.5)*d
            quad(point(a,lo),point(b,lo),point(b,hi),point(a,hi),p.glass)
            beam(point(a,lo),point(b,lo),0.065,0.065,p.white)
            if i%3==0 {beam(point(a,lo),point(a,hi),0.07,0.08,p.white)}
        }}
        for side:Float in [-1,1] {for i in 0..<slices {
            let a=Float(i)*Float.pi/Float(slices),b=Float(i+1)*Float.pi/Float(slices),q=c+z*side*d/2
            tri(q,point(a,side*d/2),point(b,side*d/2),p.glass)
            beam(point(a,side*d/2),point(b,side*d/2),0.11,0.11,p.white)
            if i%2==0 {beam(q+x*cos(a)*w/2,point(a,side*d/2),0.065,0.075,p.white)}
        }}
        // Narrow raised ridge ventilator gives the characteristic tiered
        // silhouette and very fine mullion reflections on approaching views.
        orientedBox(c+V(0,rise+0.35,0),x,V(0,1,0),z,V(3.6,0.7,d*0.65),p.glass)
        for i in 0...Int(d*0.65) {let q=c+z*(Float(i)-d*0.325)+V(0,rise+0.72,0);beam(q-x*1.9,q+x*1.9,0.055,0.06,p.white)}
    }
    private func zooPalm(_ q:V,height:Float,_ p:ZooPalette) {
        cylinder(q,q+V(0,height,0),0.16,p.wood,segments:8)
        for j in 0..<9 {let a=Float(j)*2*Float.pi/9,d=V(cos(a),0,sin(a)),n=V(-d.z,0,d.x),base=q+V(0,height,0)
            for k in 0..<8 {let t=Float(k)/8,tt=Float(k+1)/8,a0=base+d*t*3.2+V(0,sin(t * .pi)*0.75-t*1.0,0),b0=base+d*tt*3.2+V(0,sin(tt * .pi)*0.75-tt,0),width=sin(t * .pi)*0.34
                quad(a0-n*width,a0+n*width,b0+n*sin(tt * .pi)*0.34,b0-n*sin(tt * .pi)*0.34,p.leaf)
                beam(a0,b0,0.025,0.035,p.reed)
            }
        }
    }
    private func zooLilyPool(_ p:ZooPalette) {
        let waterShape=LincolnParkZooMap.shape(116740882)
        for ring in waterShape.rings {for i in ring.indices {
            let a=ring[i],b=ring[(i+1)%ring.count],aa=V(a.x,0,a.y),bb=V(b.x,0,b.y),len=simd_distance(aa,bb)
            guard len>0.1 else {continue}
            let t=(bb-aa)/len,n=V(-t.z,0,t.x)
            for layer in 0..<3 {
                let y=Float(layer)*0.11-0.2,width=0.6+Float(layer%2)*0.25
                orientedBox((aa+bb)/2+V(0,y,0),n,V(0,1,0),t,V(width,0.12,len+0.1),p.stone)
            }
        }}
        // Two low white-oak pavilions joined on the west edge; layered stone
        // terraces and outward-spreading roof beams follow the landmark report.
        let centers=[V(133,0.13,-5139),V(134,0.13,-5129)]
        for c in centers {
            box(c,V(11,0.18,8),p.stone)
            for side:Float in [-1,1] {box(c+V(side*4.5,0.6,0),V(0.8,1.2,5.8),p.stone)}
            for x:Float in [-3.5,3.5] {for z:Float in [-2.2,2.2] {box(c+V(x,1.42,z),V(0.24,2.8,0.24),p.wood)}}
            for x in stride(from:Float(-5.5),through:5.5,by:0.7) {beam(c+V(x,2.8,-4.3),c+V(x,3.12,4.3),0.17,0.24,p.wood)}
            for z:Float in [-2.5,2.5] {beam(c+V(-6.2,2.72,z),c+V(6.2,2.72,z),0.21,0.32,p.wood)}
            quad(c+V(-5.8,2.99,-4.1),c+V(5.8,2.99,-4.1),c+V(5.8,3.28,4.1),c+V(-5.8,3.28,4.1),p.roof)
        }
        beam(V(129.5,2.72,-5143),V(129.5,2.72,-5125),0.30,0.34,p.wood)
        // Council ring lies on the east bank, outside the walking corridor.
        let ring=V(192,0.2,-5134)
        for i in 0..<40 {
            let a=Float(i)*2*Float.pi/40,b=Float(i+1)*2*Float.pi/40
            if i>16 && i<21 {continue}
            beam(ring+V(cos(a)*4,0.22,sin(a)*4),ring+V(cos(b)*4,0.22,sin(b)*4),0.7,0.45,p.stone)
        }
        // Small north waterfall over stratified limestone; no animated opacity.
        for k in 0..<6 {let q=V(155,Float(k)*0.18-0.1,-5180-Float(k)*0.7);box(q,V(5.5-Float(k)*0.3,0.18,1.1),p.stone)
            quad(q+V(-1.4,0.11,0.56),q+V(1.4,0.11,0.56),q+V(1.4,-0.12,0.75),q+V(-1.4,-0.12,0.75),p.glass)
        }
        for i in 0..<90 {
            let z:Float = -5089-Float(i%18)*4.5,x:Float=151+sin(Float(i)*2.399)*6.0
            // Restrict the pads to the actual water polygon.
            if zooInside(SIMD2(x,z),waterShape.rings[0]) {
                let q=V(x,-0.235,z),r:Float=0.22+Float(i%4)*0.06
                for j in 1..<12 {let a=Float(j)*2*Float.pi/12,b=Float(j+1)*2*Float.pi/12;tri(q,q+V(cos(a)*r,0.003,sin(a)*r),q+V(cos(b)*r,0.003,sin(b)*r),p.leaf)}
                if i%9==0 {ellipsoid(q+V(0,0.09,0),V(0.11,0.09,0.11),p.flower,segments:8,rings:4)}
            }
        }
        let gate=V(151,0,-5197)
        for s:Float in [-1,1] {box(gate+V(s*3.5,0.9,0),V(3.3,1.8,1),p.stone);box(gate+V(s*2.0,1.0,1.3),V(0.16,2,2.6),p.wood)}
        beam(gate+V(-5.5,2,0),gate+V(5.5,2,0),0.22,0.25,p.wood)
        // Reference-supported gate fixture only: this tranquil landscape is
        // not covered by the zoo's interpreted seasonal RGB installation.
        zooLamp(gate+V(0,2.25,0),p,power:8,range:11)
        for q in [V(182,0,-5155),V(181,0,-5102)] {box(q+V(0,0.6,0),V(0.15,1.2,0.15),p.iron);zooLamp(q+V(0,1.2,0),p,power:3,range:9)}
    }
    private func zooInside(_ p:SIMD2<Float>,_ ring:[SIMD2<Float>])->Bool {
        var inside=false,j=ring.count-1
        for i in ring.indices {let a=ring[i],b=ring[j]
            if (a.y>p.y) != (b.y>p.y) && p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x {inside.toggle()};j=i
        };return inside
    }
    private func zooHabitats(_ p:ZooPalette) {
        // Representative procedural animals are static interpretive figures,
        // not a claim about a current animal inventory or husbandry layout.
        let lion=UInt32(scene.materials.count);scene.materials.append(SceneMaterial(V(0.55,0.32,0.13),roughness:0.96))
        let mane=UInt32(scene.materials.count);scene.materials.append(SceneMaterial(V(0.22,0.12,0.045),roughness:0.99))
        // North of the historic Lion House, inside the expanded habitat.
        for q in [V(201,0,-4749),V(221,0,-4756)] {
            ellipsoid(q+V(0,0.9,0),V(1.1,0.62,0.45),lion,segments:16,rings:9)
            for x:Float in [-0.7,0.7] {for z:Float in [-0.3,0.3] {cylinder(q+V(x,0.1,z),q+V(x,0.86,z),0.12,lion,segments:8)}}
            ellipsoid(q+V(1.0,1.05,0),V(0.53,0.59,0.49),mane,segments:16,rings:9)
            ellipsoid(q+V(1.24,1.16,0),V(0.32,0.32,0.29),lion,segments:12,rings:8)
            for s:Float in [-1,1] {ellipsoid(q+V(1.24,1.47,s*0.21),V(0.1,0.12,0.075),lion,segments:8,rings:5);ellipsoid(q+V(1.49,1.25,s*0.15),V(0.025,0.025,0.018),p.iron,segments:6,rings:4)}
            beam(q+V(-0.9,0.9,0),q+V(-1.8,0.45,0.3),0.06,0.06,lion)
            ellipsoid(q+V(-1.8,0.45,0.3),V(0.13,0.12,0.13),mane,segments:8,rings:5)
        }
        for i in 0..<13 {let q=V(194+Float(i%5)*5,0,-4755-Float(i/5)*2);ellipsoid(q+V(0,0.4,0),V(1.1,0.7,0.85),p.rock,segments:8,rings:5)}
        for x:Float in [198,209,220] {beam(V(x,0,-4753),V(x+4,2.5,-4753),0.33,0.38,p.wood)}
        // A low-glare boundary distinguishes the animal area from public paths.
        for (a,b) in [(V(194,0,-4765),V(226,0,-4765)),(V(226,0,-4765),V(226,0,-4738))] {
            quad(a+V(0,0.25,0),b+V(0,0.25,0),b+V(0,3,0),a+V(0,3,0),p.glass)
            let n=max(1,Int(simd_distance(a,b)/3));for i in 0...n {let q=a+(b-a)*Float(i)/Float(n);beam(q,q+V(0,3.1,0),0.08,0.08,p.iron)}
        }
        // Giraffes in the mapped African Journey northern outdoor vicinity.
        for q in [V(204,0,-4978),V(213,0,-4980)] {zooGiraffe(q,p)}
        let corners=[V(196,0,-4990),V(225,0,-4990),V(225,0,-4963),V(196,0,-4963)]
        for i in 0..<4 {let a=corners[i],b=corners[(i+1)%4]
            for y:Float in [0.5,1,1.5] {beam(a+V(0,y,0),b+V(0,y,0),0.035,0.035,p.iron)}
            let n=max(1,Int(simd_distance(a,b)/3));for j in 0...n {let q=a+(b-a)*Float(j)/Float(n);beam(q,q+V(0,1.65,0),0.1,0.12,p.wood)}
        }
        for i in 0..<5 {zooDuck(V(153+Float(i)*1.9,-0.20,-5165+Float(i%2)),p)}
    }
    private func zooDuck(_ q:V,_ p:ZooPalette) {
        ellipsoid(q+V(0,0.14,0),V(0.32,0.20,0.19),p.wood,segments:10,rings:6)
        ellipsoid(q+V(0.25,0.32,0),V(0.12,0.13,0.11),p.leaf,segments:10,rings:6)
        box(q+V(0.38,0.30,0),V(0.13,0.04,0.07),p.reed)
        ellipsoid(q+V(-0.05,0.21,0.14),V(0.25,0.1,0.05),p.white,segments:8,rings:5)
    }
    private func zooGiraffe(_ q:V,_ p:ZooPalette) {
        ellipsoid(q+V(0,2.2,0),V(1.0,0.70,0.45),p.reed,segments:12,rings:7)
        for x:Float in [-0.7,0.7] {for z:Float in [-0.3,0.3] {cylinder(q+V(x,0.05,z),q+V(x,2.1,z),0.08,p.reed,segments:8)}}
        beam(q+V(0.75,2.4,0),q+V(1.35,4.8,0),0.32,0.34,p.reed)
        ellipsoid(q+V(1.55,4.9,0),V(0.43,0.24,0.21),p.reed,segments:12,rings:7)
        for s:Float in [-1,1] {beam(q+V(1.4,5,s*0.14),q+V(1.4,5.3,s*0.16),0.045,0.045,p.wood)}
        for i in 0..<15 {let x=Float(i%5)*0.35-0.7,y=Float(i/5)*0.3+1.9;for s:Float in [-1,1] {ellipsoid(q+V(x,y,s*0.43),V(0.12,0.11,0.02),p.wood,segments:6,rings:4)}}
        for i in 0..<6 {let f=Float(i)/6;ellipsoid(q+V(0.85+f*0.6,2.7+f*2,0.18),V(0.11,0.14,0.03),p.wood,segments:6,rings:4)}
    }
    private func zooPathDistance(_ q:V)->Float {
        let p=SIMD2(q.x,q.z)
        var best:Float = .greatestFiniteMagnitude
        func segment(_ a:SIMD2<Float>,_ b:SIMD2<Float>) {
            let d=b-a,l=simd_length_squared(d)
            let t=l>0 ? max(0,min(1,simd_dot(p-a,d)/l)):0
            best=min(best,simd_distance(p,a+d*t))
        }
        for path in LincolnParkZooMap.publicPaths {for i in 0..<path.points.count-1 {
            let a=path.points[i],b=path.points[i+1];segment(SIMD2(a.x,a.z),SIMD2(b.x,b.z))
        }}
        for points in [LincolnParkZooLayout.natureRoute,LincolnParkZooLayout.zooRoute,LincolnParkZooLayout.conservatoryRoute,LincolnParkZooLayout.lilyRoute] {for i in 0..<points.count-1 {
            let a=points[i],b=points[i+1];segment(SIMD2(a.x,a.z),SIMD2(b.x,b.z))
        }}
        return best
    }
    func zooRoadClearance(_ q:V)->Float {
        let p=SIMD2(q.x,q.z)
        var best:Float = .greatestFiniteMagnitude
        for road in LincolnParkZooMap.roads {for i in 0..<road.points.count-1 {
            let a=SIMD2(road.points[i].x,road.points[i].z),b=SIMD2(road.points[i+1].x,road.points[i+1].z),d=b-a,l=simd_length_squared(d)
            let t=l>0 ? max(0,min(1,simd_dot(p-a,d)/l)):0
            best=min(best,simd_distance(p,a+d*t)-road.halfWidth)
        }}
        return best
    }
    func zooPlantable(_ q:V,clearance:Float)->Bool {
        guard zooPathDistance(q)>clearance, zooRoadClearance(q)>(clearance>3 ? 1.8:1.2) else {return false}
        let p=SIMD2(q.x,q.z)
        func nearRing(_ ring:[SIMD2<Float>],margin:Float)->Bool {
            if zooInside(p,ring) {return true}
            for i in ring.indices {let a=ring[i],b=ring[(i+1)%ring.count],d=b-a,l=simd_length_squared(d)
                let t=l>0 ? max(0,min(1,simd_dot(p-a,d)/l)):0
                if simd_distance(p,a+d*t)<margin {return true}
            };return false
        }
        for ring in LincolnParkZooMap.allBuildingRings {if nearRing(ring,margin:max(0.7,clearance-1.5)) {return false}}
        for id:Int64 in [-2514193,116740882] {for ring in LincolnParkZooMap.shape(id).rings {if nearRing(ring,margin:clearance>3 ? 3.0:0.8) {return false}}}
        // Low historic pavilions and council ring are deliberately kept open.
        if q.x>125 && q.x<142 && q.z > -5145 && q.z < -5123 {return false}
        if simd_distance(p,SIMD2<Float>(192,-5134))<6 {return false}
        if simd_distance(p,SIMD2<Float>(51,-4990))<5.3 {return false}
        return true
    }
    func zooLeafMass(_ c:V,_ r:V,_ m:UInt32,seed:Float) {
        let bands=7,slices=12
        func local(_ a:Float,_ v:Float)->V {
            LincolnParkZooLayout.foliagePoint(angle:a,latitude:v,radius:r,seed:seed)
        }
        func normal(_ p:V)->V {simd_normalize(p/(r*r))}
        for j in 0..<bands {for i in 0..<slices {
            let a=Float(i)*2*Float.pi/Float(slices),b=Float((i+1)%slices)*2*Float.pi/Float(slices)
            let l = -Float.pi/2+Float(j)*Float.pi/Float(bands),h = -Float.pi/2+Float(j+1)*Float.pi/Float(bands)
            let aa=local(a,l),bb=local(b,l),cc=local(b,h),dd=local(a,h)
            if j>0 {smoothTri(c+aa,c+cc,c+bb,normal(aa),normal(cc),normal(bb),m)}
            if j<bands-1 {smoothTri(c+aa,c+dd,c+cc,normal(aa),normal(dd),normal(cc),m)}
        }}
    }
    private func zooMatureTree(_ q:V,height:Float,seed:Float,leaves:[UInt32],_ p:ZooPalette) {
        let lean=V(sin(seed)*0.6,0,cos(seed*1.7)*0.4)
        for i in 0..<5 {
            let f=Float(i)/5,g=Float(i+1)/5
            cylinder(q+V(0,height*f*0.72,0)+lean*f,q+V(0,height*g*0.72,0)+lean*g,0.27*(1-f*0.55),p.wood,segments:10)
        }
        for branch in 0..<8 {
            let angle=Float(branch)*2.399+seed,radius:Float=2.4+Float(branch%3)*0.48
            let base=q+V(0,height*(0.30+Float(branch%3)*0.075),0)
            let crown=q+V(cos(angle)*radius,height*(0.62+Float(branch%3)*0.075),sin(angle)*radius)+lean
            let middle=(base+crown)/2+V(0,0.4,0)
            cylinder(base,middle,0.11,p.wood,segments:8);cylinder(middle,crown,0.065,p.wood,segments:7)
            for twig in 0..<3 {let a=angle+Float(twig-1)*0.7;let tip=crown+V(cos(a)*1.1,1.0+Float(twig)*0.18,sin(a)*1.1);cylinder(crown,tip,0.029,p.wood,segments:6)}
            let r=V(radius*0.85,height*0.20,radius*0.80)
            zooLeafMass(crown,r,leaves[branch%leaves.count],seed:seed+Float(branch))
        }
        zooLeafMass(q+V(0,height*0.87,0)+lean,V(2.6,height*0.17,2.6),leaves[2%leaves.count],seed:seed+12)
    }
    private func zooPlanting(_ p:ZooPalette) {
        let colors:[V]=[V(0.09,0.22,0.055),V(0.14,0.29,0.075),V(0.21,0.32,0.10),V(0.115,0.25,0.115),V(0.28,0.34,0.105)]
        let leaves:[UInt32]=colors.map {c in let i=UInt32(scene.materials.count);scene.materials.append(SceneMaterial(c,roughness:0.94,pattern:4));return i}
        var trees:[V]=[]
        let regions:[(Float,Float,Float,Float)]=[(138,407,-4515,-4170),(92,350,-5020,-4532),(14,222,-5203,-4991)]
        for (xmin,xmax,zmin,zmax) in regions {
            for z in stride(from:zmin,through:zmax,by:16.0) {
                for x in stride(from:xmin,through:xmax,by:16.0) {
                    let seed=x*0.17+z*0.031,q=V(x+sin(seed*3)*4.8,0,z+cos(seed*5)*4.8)
                    if sin(seed*11) < -0.64 || !zooPlantable(q,clearance:4.0) {continue}
                    if trees.contains(where:{simd_distance($0,q)<11}) {continue}
                    trees.append(q)
                    zooMatureTree(q,height:10.8+2.7*(0.5+0.5*sin(seed)),seed:seed,leaves:leaves,p)
                }
            }
        }
        // Dense native understory along the paths: rounded shrubs, flowering
        // stems, and upright prairie grasses, outside every mapped path buffer.
        var shrubs=0
        for (xmin,xmax,zmin,zmax) in regions {for z in stride(from:zmin,through:zmax,by:7.5) {for x in stride(from:xmin,through:xmax,by:7.5) {
            let seed=x*0.213+z*0.073,q=V(x+sin(seed)*1.6,0,z+cos(seed*2)*1.6),distance=zooPathDistance(q)
            if distance>10 || !zooPlantable(q,clearance:2.25) {continue}
            if shrubs>=650 {continue};shrubs += 1
            zooLeafMass(q+V(0,0.60,0),V(1.1,0.70,0.95),leaves[shrubs%leaves.count],seed:seed)
            for j in 0..<6 {
                let angle=Float(j)*2.399+seed,d=V(cos(angle),0,sin(angle))
                let stem=q+d*0.9,h:Float=0.8+Float(j%3)*0.13
                beam(stem,stem+V(0,h,0),0.018,0.024,p.reed)
                if shrubs%3==0 {
                    let top=stem+V(0,h,0)
                    for k in 0..<5 {let a=Float(k)*2*Float.pi/5;ellipsoid(top+V(cos(a)*0.09,0,sin(a)*0.09),V(0.09,0.04,0.065),p.flower,segments:5,rings:3)}
                } else {beam(stem+V(0,0.4,0),stem+d*0.34+V(0,0.8,0),0.055,0.014,leaves[j%leaves.count])}
            }
        }}}
        // Modest warm-white illumination on selected mature trees and native
        // planting, from concealed finite-range fixtures rather than emissive leaves.
        var lit=0
        for (i,q) in trees.enumerated() where i%11==0 || (q.z < -4985 && i%5==0) {
            if lit>=26 {break};lit += 1
            let source=q+V(1.6,0.35,1.1)
            box(source-V(0,0.07,0),V(0.24,0.13,0.22),p.iron)
            scene.lights.append(NightLighting.source(source,toward:q+V(0,7,0),power:100,color:V(1,0.86,0.64),range:22,radius:0.40,outerDegrees:86,innerDegrees:50))
        }
        // Broad interior fixtures reveal the planted glass volume; separate
        // downward garden sources make flower beds and the fountain readable.
        let z=simd_normalize(V(-0.18,0,-1)),x=V(-z.z,0,z.x)
        for (c,w,d,h):(V,Float,Float,Float) in [(V(53,0,-5026),29,39,8),(V(43,0,-5069),20,43,6),(V(91,0,-5059),24,58,6),(V(78,0,-5104),27,39,6)] {
            for side:Float in [-1,1] {for f:Float in [-0.28,0.28] {
                let source=c+x*side*w*0.26+z*d*f+V(0,h,0)
                box(source,V(0.4,0.13,0.4),p.white)
                scene.lights.append(NightLighting.source(source-V(0,0.12,0),toward:source-V(0,h-1,0),power:125,color:V(0.94,1,0.86),range:24,radius:0.65,outerDegrees:88,innerDegrees:62))
            }}
        }
        for source in [V(30,0.5,-4997),V(70,0.5,-4997),V(14,0.5,-5031)] {
            scene.lights.append(NightLighting.source(source,toward:V(51,8,-5018),power:340,color:V(1,0.88,0.69),range:43,radius:0.65,outerDegrees:87,innerDegrees:54))
        }
        for q in [V(32,3.4,-4972),V(70,3.4,-4972),V(34,3.4,-4992),V(72,3.4,-4992)] {
            cylinder(q-V(0,3.4,0),q,0.045,p.iron,segments:8)
            zooLamp(q,p,power:75,range:25)
        }
        for x:Float in [46,56] {scene.lights.append(NightLighting.source(V(x,0.35,-4987),toward:V(51,1.8,-4990),power:28,color:V(1,0.9,0.71),range:12,radius:0.35,outerDegrees:84,innerDegrees:46))}
        scene.detailCount += trees.count+shrubs
    }

    private func zooSeasonalLights(_ p:ZooPalette) {
        // Authored seasonal event composition, inspired by LPZ's 2025 photos:
        // colored tree/arch strings plus warm-white entries. Not a current or
        // year-round replica, and no logos/sponsor artwork are reproduced.
        for i in 0..<7 {
            let c=V(259.5,0,-4654-Float(i)*9.2),m=p.lenses[i%p.lenses.count]
            for j in 0..<40 {
                let a=Float(j)*Float.pi/40,b=Float(j+1)*Float.pi/40
                let aa=c+V(cos(a)*3.8,1.1+sin(a)*4.7,0),bb=c+V(cos(b)*3.8,1.1+sin(b)*4.7,0)
                beam(aa,bb,0.035,0.035,p.iron)
                cylinder(aa-V(0,0,0.035),aa+V(0,0,0.035),0.045,m,segments:6)
            }
            for side:Float in [-1,1] {beam(c+V(side*3.8,0,0),c+V(side*3.8,1.1,0),0.055,0.055,p.iron)}
            scene.lights.append(NightLighting.source(c+V(0,4.8,0),power:13,color:p.colors[i%p.colors.count],range:13,radius:0.45))
        }
        for i in 0..<14 {
            let c=V(i%2==0 ? 251:269,0,-4640-Float(i/2)*21),color=p.colors[(i+2)%p.colors.count],m=p.lenses[(i+2)%p.lenses.count]
            // The event strings have their own slender ornamental tree, with
            // restrained branches rather than copying a real tree survey.
            cylinder(c,c+V(0,5.2,0),0.13,p.wood,segments:8)
            for branch in 0..<4 {let a=Float(branch)*2.399;let tip=c+V(cos(a)*1.8,4+Float(branch)*0.5,sin(a)*1.8)
                beam(c+V(0,2.7,0),tip,0.06,0.08,p.wood)
                for j in 0..<12 {let q=c+V(0,2.7,0)+(tip-c-V(0,2.7,0))*Float(j)/12;ellipsoid(q,V(0.045,0.045,0.045),m,segments:6,rings:3)}
            }
            for j in 0..<70 {let a=Float(j)*0.91,q=c+V(cos(a)*0.16,Float(j)*0.065+0.15,sin(a)*0.16);ellipsoid(q,V(0.035,0.035,0.035),m,segments:6,rings:3)}
            scene.lights.append(NightLighting.source(c+V(0,2.1,0),power:12,color:color,range:13,radius:0.5))
        }
    }
}
