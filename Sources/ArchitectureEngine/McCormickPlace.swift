import Foundation
import simd

/// Current four-building campus. Footprints come from the frozen OSM extract;
/// roof systems and façade rhythms are interpreted from owner/architect photos.
enum McCormickLayout {
    static let mainBuildingIDs: [Int64] = [136340574,769452749,204886155,-17647196]
    static let marriottHeight: Float = 135.2 // CVU architectural height, 40 occupied storeys.
    static let northPylonCount = 12
    static let lakesideRoof: Float = 30 // Reject OSM part heights of 100m: inconsistent with owner photos.
    static let stop = CameraPose(position: SIMD3(2370,165,2780), target: SIMD3(1740,30,3000), fov: 67)
}

private struct McCormickPalette {
    let concrete: UInt32, white: UInt32, steel: UInt32, dark: UInt32, roof: UInt32
    let glass: [UInt32], warm: UInt32, red: UInt32, blue: UInt32, brick: UInt32, garden: UInt32
}

extension EiffelBuilder {
    func mccormickPlace() {
        func add(_ m: SceneMaterial) -> UInt32 { let i=UInt32(scene.materials.count);scene.materials.append(m);return i }
        let p=McCormickPalette(
            concrete:add(SceneMaterial(V(0.56,0.56,0.53),roughness:0.79,pattern:10)),
            white:add(SceneMaterial(V(0.79,0.81,0.79),roughness:0.55,metallic:0.07)),
            steel:add(SceneMaterial(V(0.34,0.37,0.39),roughness:0.39,metallic:0.72)),
            dark:add(SceneMaterial(V(0.035,0.043,0.045),roughness:0.48,metallic:0.42)),
            roof:add(SceneMaterial(V(0.48,0.51,0.51),roughness:0.83,pattern:5)),
            glass:[Float(0),0.035,0.07,0.12].map {add(SceneMaterial(V(0.13,0.21,0.26),roughness:0.15,metallic:0.61,emission:$0,pattern:14))},
            warm:add(SceneMaterial(V(1,0.79,0.48),roughness:0.44,emission:0.6,pattern:16)),
            red:add(SceneMaterial(V(0.61,0.055,0.035),roughness:0.62)),
            blue:add(SceneMaterial(V(0.10,0.39,0.60),roughness:0.65)),
            brick:add(SceneMaterial(V(0.35,0.19,0.10),roughness:0.83,pattern:10)),
            garden:add(SceneMaterial(V(0.20,0.30,0.095),roughness:0.96,pattern:4)))
        for id in McCormickLayout.mainBuildingIDs { precondition(MuseumCampusContext.landmark(id) != nil,"Missing McCormick footprint \(id)") }
        mccormickLakeside(p)
        mccormickNorth(p)
        mccormickHall(-17647196,base:0.25,height:30,p:p)
        mccormickHall(204886155,base:4,height:27,p:p)
        mccormickWestDetails(p)
        mccormickSouthDetails(p)
        // The concourse is a separate raised volume joining North and South;
        // the east bridge spans the expressway to Lakeside above live traffic.
        mccormickBridge(769724044,bottom:12,top:31,p:p)
        mccormickBridge(769427391,bottom:11.5,top:19.5,p:p)
        mccormickHotels(p)
        mccormickArena(p)
    }

    private func mcRoof(_ id:Int64,y:Float,material:UInt32) {
        guard let shape=MuseumCampusContext.landmark(id) else {return}
        for j in stride(from:0,to:shape.triangles.count,by:3) {
            let a=shape.points[shape.triangles[j]],b=shape.points[shape.triangles[j+1]],c=shape.points[shape.triangles[j+2]]
            tri(V(a[0],y,a[1]),V(b[0],y,b[1]),V(c[0],y,c[1]),material)
        }
    }

    private func mcFacade(_ id:Int64,bottom:Float,top:Float,floors:Int,p:McCormickPalette,stone:UInt32?=nil,glassRatio:Float=0.80) {
        guard let shape=MuseumCampusContext.landmark(id) else {return}
        for ring in shape.rings {
            var signed:Float=0
            for i in ring.indices {let a=ring[i],b=ring[(i+1)%ring.count];signed += a[0]*b[1]-b[0]*a[1]}
            for i in ring.indices {
                let aa=ring[i],bb=ring[(i+1)%ring.count],a=V(aa[0],0,aa[1]),b=V(bb[0],0,bb[1]),length=simd_distance(a,b)
                guard length>0.05 else {continue}
                let tangent=(b-a)/length,normal=V(tangent.z,0,-tangent.x)*(signed>0 ? 1:-1)
                func point(_ u:Float,_ y:Float,_ out:Float=0)->V {a+tangent*u+V(0,y,0)+normal*out}
                func part(_ u:Float,_ y:Float,_ out:Float,_ size:V,_ m:UInt32) {orientedBox(point(u,y,out),tangent,V(0,1,0),normal,size,m)}
                let bays=max(1,Int(ceil(length/3.3))),bay=length/Float(bays),fh=(top-bottom)/Float(max(1,floors))
                // Recessed backing, real reveals and low-frequency mullions retain
                // readable detail in motion without subpixel window textures.
                quad(point(0,bottom,-0.22),point(length,bottom,-0.22),point(length,top,-0.22),point(0,top,-0.22),p.dark)
                for floor in 0..<max(1,floors) {
                    let y=bottom+Float(floor)*fh
                    part(length/2,y+fh*(1-glassRatio)/2,0,V(length,fh*(1-glassRatio),0.38),stone ?? p.white)
                    for col in 0..<bays {
                        let u=(Float(col)+0.5)*bay,wm=p.glass[(floor*13+col*7+i*3)%17<12 ? 0:1+(floor+col)%3]
                        part(u,y+fh*(1-glassRatio/2),-0.12,V(bay-0.20,fh*glassRatio-0.16,0.035),wm)
                        if floors<=8 {part(u,y+fh*0.60,0.015,V(bay,0.10,0.12),p.steel)}
                    }
                }
                for col in 0...bays {part(Float(col)*bay,(bottom+top)/2,0.035,V(stone == nil ? 0.16:0.46,top-bottom,0.31),stone ?? p.steel)}
                part(length/2,top,0.10,V(length,0.55,0.75),stone ?? p.white)
                if length>20 && top<50 {
                    for u in stride(from:Float(12),to:length,by:32) {
                        part(u,bottom+4.2,0.4,V(1.8,0.15,0.30),p.warm)
                        scene.lights.append(NightLighting.source(point(u,bottom+7,1.5),toward:point(u,bottom,9),power:90,color:V(1,0.81,0.60),range:32,radius:0.7,outerDegrees:72,innerDegrees:54))
                    }
                }
            }
        }
    }

    private func mccormickHall(_ id:Int64,base:Float,height:Float,p:McCormickPalette,glazing:Float=0.70,wall:UInt32?=nil) {
        mcRoof(id,y:base,material:p.concrete)
        mcFacade(id,bottom:base,top:height,floors:3,p:p,stone:wall,glassRatio:glazing)
        mcRoof(id,y:height,material:p.roof)
        guard let s=MuseumCampusContext.landmark(id) else{return}
        // Rooftop plant is concentrated in interior service zones; hall ceilings
        // remain flat wide spans, not enormous extrusions of unreliable parts.
        let x=(s.bounds[0]+s.bounds[2])/2,z=(s.bounds[1]+s.bounds[3])/2
        for dz:Float in [-65,0,65] {for dx:Float in [-38,38] {
            box(V(x+dx,height+2.2,z+dz),V(16,4.4,23),p.white)
            for offset:Float in [-5,5] {cylinder(V(x+dx+offset,height+4.4,z+dz),V(x+dx+offset,height+5.0,z+dz),3.1,p.dark,segments:12)}
        }}
    }

    private func mccormickLakeside(_ p:McCormickPalette) {
        let id:Int64=136340574
        mcRoof(id,y:5.1,material:p.concrete)
        mcFacade(id,bottom:0.15,top:5.1,floors:1,p:p,stone:p.concrete,glassRatio:0.48)
        mcFacade(id,bottom:5.1,top:27.7,floors:2,p:p,stone:p.dark,glassRatio:0.93)
        mcRoof(id,y:30,material:p.roof)
        let u=simd_normalize(V(1989.228-1813.083,0,2645.887-2697.952)),v=V(-u.z,0,u.x)
        let origin=V(1813.083,0,2697.952),width:Float=183.68,length:Float=414.1
        func point(_ x:Float,_ y:Float,_ z:Float)->V {origin+u*x+v*z+V(0,y,0)}
        orientedBox(point(width/2,29.1,length/2),u,V(0,1,0),v,V(width+11,1.8,length+11),p.dark)
        // Monumental black steel entablature and regularly spaced exterior bents.
        for z in stride(from:Float(0),through:length,by:23) {
            for x:Float in [0,width] {
                beam(point(x,5.2,z),point(x,29,z),0.75,0.75,p.dark,iSection:true)
                beam(point(x-4,27,z),point(x+4,29,z),0.38,0.52,p.dark)
            }
            beam(point(-5,29,z),point(width+5,29,z),0.42,1.25,p.dark,iSection:true)
        }
        for x in stride(from:Float(9),to:width,by:18) {beam(point(x,30.06,0),point(x,30.06,length),0.09,0.09,p.steel)}
        for z:Float in [85,170,255,340] {orientedBox(point(width/2,31.2,z),u,V(0,1,0),v,V(25,2.4,34),p.dark)}
        // East-facing Arie Crown/lake promenade is a raised, open terrace.
        orientedBox(point(width+17,1.25,length*0.57),u,V(0,1,0),v,V(32,2.5,length*0.8),p.concrete)
        // Broad access steps tie the terrace to the public lake path.
        for i in 0..<12 {
            let h=Float(i+1)*2.5/12
            orientedBox(point(width+33+Float(11-i)*0.43,h/2,length*0.57),u,V(0,1,0),v,V(0.46,h,20),p.concrete)
        }
        for z in stride(from:Float(55),to:length-25,by:28) {
            cylinder(point(width+27,2.6,z),point(width+27,7.2,z),0.11,p.steel,segments:8)
            ellipsoid(point(width+27,7.3,z),V(0.42,0.22,0.42),p.warm,segments:8,rings:4)
            scene.lights.append(NightLighting.source(point(width+26,7.2,z),toward:point(width+16,2,z),power:56,color:V(1,0.86,0.68),range:25,radius:0.4))
        }
    }

    private func mccormickNorth(_ p:McCormickPalette) {
        mccormickHall(769452749,base:5,height:29,p:p,glazing:0.14,wall:p.concrete)
        // SOM's 1986 roof hangs from twelve pylons: six paired stations.
        // Their exact engineering sections are an architectural interpretation.
        for index in 0..<6 {
            let z:Float=2610+Float(index)*67
            for x:Float in [1510,1732] {
                let tip=V(x,56,z)
                // Deep vertical slots and separate cable sockets are visible
                // in SOM's close roof photograph.
                for side:Float in [-1,1] {box(V(x+side*0.76,31,z),V(0.82,50,2.25),p.white)}
                box(V(x,31,z),V(0.82,50,1.25),p.concrete)
                for dz:Float in [-31,31] {for dx:Float in [-39,39] {
                    for level:Float in [0,-7] {
                        let anchor=tip+V(0,level,0),landing=V(x+dx*(level==0 ? 1:0.55),29.7,z+dz)
                        cylinder(anchor,landing,0.14,p.steel,segments:8)
                        ellipsoid(anchor,V(0.28,0.43,0.28),p.dark,segments:8,rings:4)
                        box(landing,V(0.8,0.65,1.3),p.dark)
                    }
                }}
                scene.lights.append(NightLighting.source(V(x+5,35,z),toward:V(x,50,z),power:100,color:V(0.82,0.90,1),range:30,radius:0.6))
            }
        }
    }

    private func mccormickWestDetails(_ p:McCormickPalette) {
        // West Gate 41: deep silver canopy, open loggia and projecting beacons.
        box(V(1150,29.4,3161),V(28,1.5,290),p.white)
        for z in stride(from:Float(3030),through:3280,by:25) {
            box(V(1144,15,z),V(1.5,28.6,1.5),p.white)
            box(V(1159,34,z),V(7,16,6),p.glass[2])
            box(V(1159,42.4,z),V(8,0.7,7),p.white)
        }
        // Roof-garden terraces remain a modest portion of the overall roof.
        for z:Float in [3110,3180,3250] {
            box(V(1374,30.25,z),V(56,0.4,45),p.concrete)
            for dx:Float in [-18,0,18] {
                box(V(1374+dx,30.7,z),V(12,0.65,37),p.garden)
                for dz:Float in [-12,0,12] {ellipsoid(V(1374+dx,31.6,z+dz),V(3.5,1,3.5),leaf,segments:8,rings:4)}
            }
        }
        for z in stride(from:Float(3040),through:3300,by:52) {
            cylinder(V(1125,0.3,z),V(1125,16,z),0.09,p.steel,segments:8)
            quad(V(1125,15,z),V(1125,12,z),V(1125,12,z+4.8),V(1125,15,z+4.8),p.blue)
        }
    }

    private func mccormickSouthDetails(_ p:McCormickPalette) {
        // A long curved south-east frontage follows the mapped plan; these
        // broad ribs give the silver roof its photographed scale.
        guard let s=MuseumCampusContext.landmark(204886155) else{return}
        for ring in s.rings {for i in ring.indices {
            let aa=ring[i],bb=ring[(i+1)%ring.count],a=V(aa[0],27.6,aa[1]),b=V(bb[0],27.6,bb[1])
            beam(a,b,0.55,0.70,p.white)
        }}
        for x in stride(from:Float(1495),through:1760,by:25) {
            box(V(x,27.15,3220),V(0.12,0.12,242),p.white)
        }
        box(V(1490,27.6,3200),V(27,1.5,290),p.white)
        for z in stride(from:Float(3080),through:3310,by:23) {box(V(1476,14,z),V(1.6,26,1.6),p.white)}
    }

    private func mccormickBridge(_ id:Int64,bottom:Float,top:Float,p:McCormickPalette) {
        mcRoof(id,y:bottom,material:p.concrete)
        mcFacade(id,bottom:bottom,top:top,floors:1,p:p,glassRatio:0.93)
        mcRoof(id,y:top,material:p.white)
        guard let shape=MuseumCampusContext.landmark(id) else{return}
        for ring in shape.rings {for i in ring.indices {
            let aa=ring[i],bb=ring[(i+1)%ring.count],a=V(aa[0],bottom-1,aa[1]),b=V(bb[0],bottom-1,bb[1]),length=simd_distance(a,b)
            guard length>0.1 else {continue}
            let n=max(1,Int(length/9))
            beam(a,b,0.65,1.1,p.steel)
            for j in 0..<n {
                let u=Float(j)/Float(n),v=Float(j+1)/Float(n)
                beam(a+(b-a)*u,a+(b-a)*v+V(0,2.4,0),0.16,0.18,p.steel)
            }
        }}
    }

    private func mccormickHotels(_ p:McCormickPalette) {
        for (id,top,floors) in [(Int64(769452753),Float(11),3),(769452748,24,4),(769452758,20,5),(313782023,12,3),(561284192,12,3)] {
            mcFacade(id,bottom:0.3,top:top,floors:floors,p:p,glassRatio:0.67);mcRoof(id,y:top,material:p.roof)
        }
        // Hotel tower footprints are separate from the broad convention podiums.
        // South Hyatt 33-storey height is interpreted at 3.5m/storey + crown;
        // the 50m OSM tag conflicts with those storeys and is not propagated.
        for (id,bottom,top,floors) in [(Int64(204866683),Float(11),Float(119),30),(769452754,11,61,14)] {
            mcFacade(id,bottom:bottom,top:top,floors:floors,p:p,stone:p.concrete,glassRatio:0.79);mcRoof(id,y:top,material:p.white)
        }
        for (id,bottom,top,floors) in [(Int64(1417233327),Float(12),Float(66),16),(1417233328,66,70,1),(1417233329,70,73.5,1),(1417233330,73.5,81,2)] {
            mcFacade(id,bottom:bottom,top:top,floors:floors,p:p,glassRatio:0.78);mcRoof(id,y:top,material:p.white)
        }
        if let hilton=MuseumCampusContext.landmark(1417233327) {
            let x=hilton.bounds[0]-0.35,z=hilton.center[1]
            box(V(x,40,z),V(0.3,51,5.5),p.red)
        }
        // Marriott's mapped narrow north/south blade, with a sloped parapet
        // rising to the independently verified 135.2m architectural top.
        let blade:Int64=1417224521
        mcFacade(blade,bottom:12,top:125,floors:34,p:p,glassRatio:0.94)
        if let shape=MuseumCampusContext.landmark(blade) {
            func top(_ point:[Float])->V {
                let t=max(0,min(1,(point[1]-shape.bounds[1])/(shape.bounds[3]-shape.bounds[1])))
                return V(point[0],McCormickLayout.marriottHeight-t*9.7,point[1])
            }
            for ring in shape.rings {for i in ring.indices {
                let a=ring[i],b=ring[(i+1)%ring.count]
                quad(V(a[0],125,a[1]),V(b[0],125,b[1]),top(b),top(a),p.glass[0])
                beam(top(a),top(b),0.3,0.4,p.steel)
            }}
            for j in stride(from:0,to:shape.triangles.count,by:3) {tri(top(shape.points[shape.triangles[j]]),top(shape.points[shape.triangles[j+1]]),top(shape.points[shape.triangles[j+2]]),p.roof)}
        }
        for (id,top) in [(Int64(1417224517),Float(23)),(1417224519,30),(1417224520,34),(1417224516,20)] {
            mcFacade(id,bottom:12,top:top,floors:max(1,Int((top-12)/4)),p:p,glassRatio:0.65);mcRoof(id,y:top,material:p.roof)
        }
        // Historic R.R. Donnelley printing works, with masonry piers and crown.
        let historic:Int64=156520409
        mcFacade(historic,bottom:0.3,top:57,floors:14,p:p,stone:p.brick,glassRatio:0.62)
        mcRoof(historic,y:57,material:p.roof)
        if let s=MuseumCampusContext.landmark(historic) {for ring in s.rings {for i in ring.indices {
            let a=V(ring[i][0],58,ring[i][1]),q=ring[(i+1)%ring.count],b=V(q[0],58,q[1])
            beam(a,b,1.4,1.4,p.concrete)
        }}}
        // Pedestrian bridges visible in the owner's campus plan.
        for (a,b) in [(V(1267,9,2835),V(1250,9,2835)),(V(1308,9,2870),V(1308,9,2935)),(V(1400,12,3057),V(1483,12,3057))] {
            let axis=simd_normalize(b-a),normal=V(axis.z,0,-axis.x),c=(a+b)/2,length=simd_distance(a,b)
            orientedBox(c,axis,V(0,1,0),normal,V(length,0.45,5),p.white)
            orientedBox(c+V(0,4,0),axis,V(0,1,0),normal,V(length,0.4,5.5),p.white)
            for side:Float in [-1,1] {
                orientedBox(c+V(0,2,0)+normal*side*2.4,axis,V(0,1,0),normal,V(length,3.5,0.06),p.glass[2])
                for t in stride(from:Float(0),through:length,by:2.7) {beam(a+axis*t+normal*side*2.5,a+axis*t+normal*side*2.5+V(0,4,0),0.15,0.15,p.steel)}
            }
        }
    }

    private func mccormickArena(_ p:McCormickPalette) {
        let id:Int64=381265570
        mcFacade(id,bottom:0.3,top:26,floors:3,p:p,glassRatio:0.68)
        mcRoof(id,y:26.2,material:p.white)
        guard let s=MuseumCampusContext.landmark(id) else{return}
        let x=s.center[0],z=s.center[1]
        // Chicago flag roof markings, visible in the operator's actual aerial.
        for dz:Float in [-29,29] {
            for i in 0..<24 {
                let x0=x-40+Float(i)*80/24,x1=x-40+Float(i+1)*80/24
                let z0=z+dz+3*sin(Float(i)*Float.pi/24),z1=z+dz+3*sin(Float(i+1)*Float.pi/24)
                quad(V(x0,26.24,z0-6),V(x1,26.24,z1-6),V(x1,26.24,z1+6),V(x0,26.24,z0+6),p.blue)
            }
        }
        for offset:Float in [-29,-10,10,29] {
            let center=V(x+offset,26.27,z)
            for i in 0..<12 {
                let a=Float(i)*Float.pi/6,b=Float(i+1)*Float.pi/6,r0:Float=i%2==0 ? 7:3,r1:Float=i%2==0 ? 3:7
                tri(center,center+V(cos(a)*r0,0,sin(a)*r0),center+V(cos(b)*r1,0,sin(b)*r1),p.red)
            }
        }
        for dz:Float in [-42,0,42] {box(V(s.bounds[0]+3,17,z+dz),V(10,8,26),p.white)}
    }
}
