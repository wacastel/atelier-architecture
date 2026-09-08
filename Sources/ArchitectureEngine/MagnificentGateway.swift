import Foundation
import simd

/// Mapped silhouettes with bounded, photograph-informed architectural ornament.
/// Coordinates are the shared Chicago east/up/south metre grid.
enum MagnificentGatewayLayout {
    static let wrigleyClock=SIMD3<Float>(919.642,100.6,-1182.870)
    static let wrigleyHeight:Float=129.54 // owner:425ft
    static let tribune=SIMD3<Float>(1012.8,0,-1281.0)
    static let tribuneHeight:Float=141.7 // current CVU/CTBUH architectural height (465ft)
    static let clockFootprint:[[Float]]=[[921.166,-1174.426],[928.054,-1184.590],[918.116,-1191.313],[911.229,-1181.150]]
    static let tribuneShaft:[[Float]]=[[1001.746,-1296.388],[1018.845,-1296.811],[1023.578,-1296.689],[1027.772,-1293.594],[1027.946,-1269.605],[1023.528,-1265.831],[1002.832,-1265.074],[998.099,-1267.957],[997.818,-1293.216]]
}

private struct GatewayPalette {
    let terra:[UInt32], limestone:UInt32, trim:UInt32, recess:UInt32, bronze:UInt32, roof:UInt32
    let windows:[UInt32], clock:UInt32, black:UInt32, warm:UInt32
}

extension EiffelBuilder {
    func magnificentGateway() {
        func add(_ material:SceneMaterial)->UInt32 {let index=UInt32(scene.materials.count);scene.materials.append(material);return index}
        let terra=(0..<6).map {index -> UInt32 in
            let t=Float(index)/5
            return add(SceneMaterial(V(0.64+0.21*t,0.62+0.25*t,0.565+0.33*t),roughness:0.40,metallic:0.025,pattern:10))
        }
        let p=GatewayPalette(terra:terra,
            limestone:add(SceneMaterial(V(0.66,0.60,0.49),roughness:0.77,pattern:10)),
            trim:add(SceneMaterial(V(0.77,0.70,0.58),roughness:0.64)),
            recess:add(SceneMaterial(V(0.035,0.038,0.036),roughness:0.87)),
            bronze:add(SceneMaterial(V(0.16,0.125,0.075),roughness:0.39,metallic:0.69)),
            roof:add(SceneMaterial(V(0.24,0.265,0.25),roughness:0.76)),
            windows:[Float(0),0.05,0.075,0.11,0.15].map {add(SceneMaterial(V(0.075,0.102,0.116),roughness:0.14,metallic:0.66,emission:$0,pattern:14))},
            clock:add(SceneMaterial(V(0.90,0.91,0.89),roughness:0.48,emission:0.22,pattern:16)),
            black:add(SceneMaterial(V(0.008,0.011,0.012),roughness:0.51,metallic:0.08)),
            warm:add(SceneMaterial(V(1,0.87,0.68),roughness:0.33,emission:0.8,pattern:16)))
        let buildings=ChicagoContext.database.buildings
        guard let south=buildings.first(where:{$0.id == -174605391}),
              let north=buildings.first(where:{$0.id == -174605390}),
              let tribune=buildings.first(where:{$0.id == 150407241}) else {preconditionFailure("Mapped gateway footprints are missing")}
        gatewayFacade(south.points,from:0,to:67.5,floors:18,stone:p.terra,tribune:false,p:p)
        gatewayRoof(south.points,triangles:south.triangles,y:67.5,material:p.roof)
        gatewayFacade(north.points,from:0,to:89.6,floors:21,stone:p.terra,tribune:false,p:p)
        gatewayRoof(north.points,triangles:north.triangles,y:89.6,material:p.roof)
        wrigleyBridges(south:south.points,north:north.points,p:p)
        wrigleyClockCrown(p)
        gatewayFacade(tribune.points,from:0,to:22.5,floors:6,stone:[p.limestone],tribune:true,p:p)
        gatewayRoof(tribune.points,triangles:tribune.triangles,y:22.5,material:p.roof)
        gatewayFacade(MagnificentGatewayLayout.tribuneShaft,from:22.5,to:111,floors:24,stone:[p.limestone],tribune:true,p:p)
        gatewayPolygonCap(MagnificentGatewayLayout.tribuneShaft,y:111,material:p.roof)
        tribuneGothicCrown(p)
        tribuneEntry(p)
    }

    private func gatewayRoof(_ polygon:[[Float]],triangles:[Int],y:Float,material:UInt32) {
        for i in stride(from:0,to:triangles.count,by:3) {
            let a=polygon[triangles[i]],b=polygon[triangles[i+1]],c=polygon[triangles[i+2]]
            tri(V(a[0],y,a[1]),V(b[0],y,b[1]),V(c[0],y,c[1]),material)
        }
    }
    private func gatewayPolygonCap(_ polygon:[[Float]],y:Float,material:UInt32) {
        let center=polygon.reduce(V.zero){$0+V($1[0],y,$1[1])}/Float(polygon.count)
        for i in polygon.indices {let a=polygon[i],b=polygon[(i+1)%polygon.count];tri(center,V(a[0],y,a[1]),V(b[0],y,b[1]),material)}
    }
    private func gatewayFacade(_ polygon:[[Float]],from bottom:Float,to top:Float,floors:Int,stone:[UInt32],tribune:Bool,p:GatewayPalette) {
        var signed:Float=0
        for i in polygon.indices {let a=polygon[i],b=polygon[(i+1)%polygon.count];signed += a[0]*b[1]-b[0]*a[1]}
        let height=top-bottom,floorHeight=height/Float(floors)
        for side in polygon.indices {
            let aa=polygon[side],bb=polygon[(side+1)%polygon.count]
            let a=V(aa[0],0,aa[1]),b=V(bb[0],0,bb[1]),length=simd_distance(a,b)
            guard length>0.2 else {continue}
            let t=(b-a)/length,n=V(t.z,0,-t.x)*(signed>0 ? 1:-1)
            func point(_ u:Float,_ y:Float,_ outset:Float=0)->V {a+t*u+V(0,y,0)+n*outset}
            func part(_ u:Float,_ y:Float,_ outset:Float,_ size:V,_ material:UInt32) {orientedBox(point(u,y,outset),t,V(0,1,0),n,size,material)}
            if length<1.7 {quad(point(0,bottom),point(length,bottom),point(length,top),point(0,top),stone.last!);continue}
            let bays=max(1,Int(length/(tribune ? 2.85:3.1))),bay=length/Float(bays)
            quad(point(0,bottom,-0.08),point(length,bottom,-0.08),point(length,top,-0.08),point(0,top,-0.08),p.recess)
            // Continuous projecting piers, with finer paired vertical ribs on Tribune.
            for column in 0...bays {
                let u=Float(column)*bay
                for level in stone.indices {
                    let lo=bottom+height*Float(level)/Float(stone.count),hi=bottom+height*Float(level+1)/Float(stone.count)
                    part(u,(lo+hi)/2,tribune ? 0.24:0.14,V(bay*(tribune ? 0.26:0.25),hi-lo,tribune ? 0.66:0.38),stone[level])
                }
                if tribune {for offset:Float in [-0.23,0.23] {part(u+offset,bottom+height/2,0.63,V(0.09,height,0.10),p.trim)}}
            }
            for floor in 0..<floors {
                let y0=bottom+Float(floor)*floorHeight,y1=y0+floorHeight
                let material=stone[min(stone.count-1,Int(Float(floor)/Float(floors)*Float(stone.count)))]
                let lower:Float=floor==0 && bottom==0 ? 1.0:0.78
                part(length/2,y0+lower/2,0.07,V(length,lower,0.22),material)
                part(length/2,y1-0.12,0.12,V(length,0.24,0.28),material)
                for column in 0..<bays {
                    let u=(Float(column)+0.5)*bay,windowWidth=bay*0.72,windowHeight=floorHeight-lower-0.24
                    let occupancy=(floor*37+(column/2)*19+side*43)%100
                    let glass=p.windows[occupancy<74 ? 0:1+occupancy%4]
                    quad(point(u-windowWidth/2,y0+lower,0),point(u+windowWidth/2,y0+lower,0),point(u+windowWidth/2,y1-0.24,0),point(u-windowWidth/2,y1-0.24,0),glass)
                    part(u,y0+lower-0.025,0.25,V(windowWidth+0.23,0.13,0.40),tribune ? p.trim:material)
                    if floor<4 && bottom==0 {
                        part(u,y0+lower+windowHeight*0.54,0.042,V(windowWidth,0.065,0.09),p.bronze)
                        part(u,y0+lower+windowHeight/2,0.045,V(0.055,windowHeight,0.10),p.bronze)
                    } else {
                        // Thin upper glazing dividers retain their surface
                        // silhouette; close street-level dividers remain solids.
                        let yc=y0+lower+windowHeight*0.54
                        quad(point(u-windowWidth/2,yc-0.033,0.09),point(u+windowWidth/2,yc-0.033,0.09),point(u+windowWidth/2,yc+0.033,0.09),point(u-windowWidth/2,yc+0.033,0.09),p.bronze)
                        quad(point(u-0.028,y0+lower,0.10),point(u+0.028,y0+lower,0.10),point(u+0.028,y1-0.24,0.10),point(u-0.028,y1-0.24,0.10),p.bronze)
                    }
                    // Terracotta lintels, keystones and relief panels are real geometry.
                    if !tribune {
                        part(u,y1-0.21,0.29,V(windowWidth+0.12,0.16,0.35),material)
                        if floor<5 || floor>=floors-2 {
                            part(u,y0+0.35,0.225,V(windowWidth*0.70,0.33,0.12),material)
                            if floor<3 || floor==floors-1 {cylinder(point(u,y0+0.35,0.29),point(u,y0+0.35,0.36),0.10,material,segments:8)}
                        }
                    } else if floor<4 && bottom==0 {
                        part(u,y0+0.35,0.22,V(windowWidth*0.65,0.42,0.15),p.trim)
                    }
                }
            }
            // Layered cornices, parapets and individually modeled dentils.
            for (dy,depth,h) in [(Float(-1.35),Float(0.38),Float(0.32)),(-0.55,0.52,0.25),(0,0.62,0.30),(0.42,0.36,0.44)] {
                part(length/2,top+dy,0.19,V(length+0.14,h,depth),stone.last!)
            }
            for u in stride(from:Float(0.36),to:length,by:tribune ? 1.2:0.7) {part(u,top-0.82,0.41,V(0.24,0.29,0.32),stone.last!)}
            // Broad overlapping photometric groups approximate the documented
            // facade floodlighting. Intermediate banks prevent black mid-height
            // bands; these effective source positions are not an as-built survey.
            if length>6 {
                let columns=max(1,Int(ceil(length/13)))
                let rows=max(1,Int(ceil(height/16)))
                for row in 0..<rows {
                    let y=bottom+(Float(row)+0.5)*height/Float(rows)
                    for column in 0..<columns {
                        let u=(Float(column)+0.5)*length/Float(columns)
                        scene.lights.append(NightLighting.source(point(u,y,6.2),toward:point(u,y+2,0),power:tribune ? 118:165,color:tribune ? V(1,0.85,0.64):V(0.94,0.97,1),range:37,radius:1.0,outerDegrees:80,innerDegrees:62))
                    }
                }
                // Visible housings remain compact at the cornice. Interior
                // banks are represented by the effective broad sources above.
                for u in stride(from:Float(3.5),to:length,by:13) {part(u,top-0.73,0.68,V(0.48,0.18,0.35),p.bronze)}
            }

        }
    }

    private func wrigleyBridges(south:[[Float]],north:[[Float]],p:GatewayPalette) {
        func intersections(_ polygon:[[Float]],x:Float)->[Float] {
            var values:[Float]=[]
            for i in polygon.indices {let a=polygon[i],b=polygon[(i+1)%polygon.count];if (a[0]<=x && b[0]>x)||(b[0]<=x && a[0]>x) {values.append(a[1]+(b[1]-a[1])*(x-a[0])/(b[0]-a[0]))}}
            return values
        }
        let x:Float=913.4,zSouth=intersections(south,x:x).min()!,zNorth=intersections(north,x:x).max()!
        let z=(zSouth+zNorth)/2,length=zSouth-zNorth+0.50
        for bottom:Float in [9.6,49.2] {
            box(V(x,bottom,z),V(5.4,0.40,length),p.terra[3]);box(V(x,bottom+3.5,z),V(5.8,0.45,length+0.2),p.terra[4])
            for side:Float in [-1,1] {
                box(V(x+side*2.55,bottom+0.65,z),V(0.35,0.95,length),p.terra[3])
                box(V(x+side*2.48,bottom+2.08,z),V(0.06,1.86,length),p.windows[1])
                for zz in stride(from:zNorth,through:zSouth,by:2.15) {box(V(x+side*2.58,bottom+2.1,zz),V(0.36,2.2,0.25),p.terra[4])}
            }
        }
    }

    private func wrigleyClockCrown(_ p:GatewayPalette) {
        let center=MagnificentGatewayLayout.wrigleyClock
        let outline=MagnificentGatewayLayout.clockFootprint
        let ux=simd_normalize(V(outline[1][0]-outline[0][0],0,outline[1][1]-outline[0][1])),uz=V(-ux.z,0,ux.x)
        func at(_ x:Float,_ y:Float,_ z:Float)->V {V(center.x,y,center.z)+ux*x+uz*z}
        func block(_ x:Float,_ y:Float,_ z:Float,_ size:V,_ material:UInt32) {orientedBox(at(x,y,z),ux,V(0,1,0),uz,size,material)}
        gatewayFacade(outline,from:67.5,to:94.0,floors:7,stone:[p.terra[4],p.terra[5]],tribune:false,p:p)
        block(0,100.3,0,V(12.1,12.2,12.1),p.terra[5])
        for y:Float in [94.2,94.9,106.5,107.3] {block(0,y,0,V(y<100 ? 13.5:13.8,0.40,y<100 ? 13.5:13.8),p.terra[5])}
        for normal in [ux,uz,-ux,-uz] {
            let tangent=simd_cross(V(0,1,0),normal)
            let clock=V(center.x,100.6,center.z)+normal*6.16
            cylinder(clock-normal*0.04,clock+normal*0.12,3.20,p.terra[4],segments:80)
            cylinder(clock+normal*0.14,clock+normal*0.20,2.985,p.clock,segments:96)
            for tick in 0..<60 {
                let angle=Float(tick)*2*Float.pi/60,major=tick%5==0
                let radial=tangent*sin(angle)+V(0,cos(angle),0),cross=tangent*cos(angle)-V(0,sin(angle),0)
                orientedBox(clock+normal*0.24+radial*(major ? 2.62:2.74),cross,radial,normal,V(major ? 0.115:0.043,major ? 0.36:0.16,0.028),p.black)
            }
            for (angle,length,width) in [(Float(305),Float(1.73),Float(0.14)),(60,2.40,0.10)] {
                let radians=angle*Float.pi/180,direction=tangent*sin(radians)+V(0,cos(radians),0)
                beam(clock+normal*0.29-direction*0.28,clock+normal*0.29+direction*length,width,0.045,p.black,normal:normal)
            }
            cylinder(clock+normal*0.28,clock+normal*0.35,0.18,p.black,segments:24)
            // Upper open loggia is dark between the paired corner pilasters.
            orientedBox(V(center.x,111.5,center.z)+normal*5.0,tangent,V(0,1,0),normal,V(7.8,6.8,0.10),p.recess)
            for u:Float in [-4.5,-2.6,2.6,4.5] {
                cylinder(V(center.x,108.0,center.z)+normal*5.4+tangent*u,V(center.x,115.4,center.z)+normal*5.4+tangent*u,0.27,p.terra[5],segments:12)
                orientedBox(V(center.x,115.6,center.z)+normal*5.4+tangent*u,tangent,V(0,1,0),normal,V(0.85,0.40,0.78),p.terra[5])
            }
            // Round-headed loggia arches replace a rectangular dark slot.
            for segment in 0..<20 {
                let a=Float(segment)*Float.pi/20,b=Float(segment+1)*Float.pi/20
                let base=V(center.x,111.9,center.z)+normal*5.56
                let aa=base+tangent*(cos(a)*2.6)+V(0,sin(a)*2.6,0),bb=base+tangent*(cos(b)*2.6)+V(0,sin(b)*2.6,0)
                let cc=base+tangent*(cos(b)*2.96)+V(0,sin(b)*2.96,0),dd=base+tangent*(cos(a)*2.96)+V(0,sin(a)*2.96,0)
                quad(aa,bb,cc,dd,p.terra[5]);quad(aa+normal*0.26,dd+normal*0.26,cc+normal*0.26,bb+normal*0.26,p.terra[5])
                quad(aa,aa+normal*0.26,bb+normal*0.26,bb,p.terra[5])
            }
            for (y,targetY,power) in [(Float(100.5),Float(100.5),Float(130)),(112,113,180),(121,125,155)] {
                scene.lights.append(NightLighting.source(V(center.x,y,center.z)+normal*(y>120 ? 9.5:12),toward:V(center.x,targetY,center.z)+normal*(y>120 ? 2:5.7),power:power,color:V(0.94,0.97,1),range:27,radius:1.0,outerDegrees:80,innerDegrees:58))
            }
        }
        for y:Float in [108,115.8,116.4] {block(0,y,0,V(11.6,0.40,11.6),p.terra[5])}
        // Giralda-derived sequence: square loggia, octagonal lantern, shallow
        // dome, small cupola and final mast. Profiles are interpretive.
        gatewayTaper(at(0,116.5,0),0,5.25,4.4,4.6,8,p.terra[5])
        for i in 0..<8 {
            let angle=Float(i)*Float.pi/4,n=ux*cos(angle)+uz*sin(angle),t=simd_cross(V(0,1,0),n)
            orientedBox(at(0,119.0,0)+n*4.72,t,V(0,1,0),n,V(2.35,3.5,0.06),p.recess)
            for offset:Float in [-1.28,1.28] {cylinder(at(0,117.2,0)+n*4.72+t*offset,at(0,120.9,0)+n*4.72+t*offset,0.16,p.terra[5],segments:10)}
        }
        cylinder(at(0,121.0,0),at(0,121.5,0),5.05,p.terra[5],segments:48)
        gatewayDome(at(0,121.5,0),4.5,3.25,p.terra[5])
        cylinder(at(0,124.7,0),at(0,127.5,0),0.85,p.terra[5],segments:16)
        gatewayDome(at(0,127.5,0),1.12,0.85,p.terra[5])
        cylinder(at(0,128.25,0),at(0,129.54,0),0.09,p.bronze,segments:10)
        for x:Float in [-5.5,5.5] {for z:Float in [-5.5,5.5] {
            cylinder(at(x,108,z),at(x,111,z),0.34,p.terra[5],segments:12)
            ellipsoid(at(x,111.35,z),V(0.46,0.62,0.46),p.terra[5],segments:12,rings:6)
        }}
    }

    private func gatewayTaper(_ base:V,_ angle:Float,_ bottom:Float,_ top:Float,_ height:Float,_ sides:Int,_ material:UInt32) {
        for i in 0..<sides {
            let a=angle+Float(i)*2*Float.pi/Float(sides),b=angle+Float(i+1)*2*Float.pi/Float(sides)
            let aa=base+V(cos(a)*bottom,0,sin(a)*bottom),bb=base+V(cos(b)*bottom,0,sin(b)*bottom)
            let cc=base+V(cos(b)*top,height,sin(b)*top),dd=base+V(cos(a)*top,height,sin(a)*top)
            quad(aa,bb,cc,dd,material)
        }
    }
    private func gatewayDome(_ base:V,_ radius:Float,_ height:Float,_ material:UInt32) {
        for row in 0..<12 {
            let a=Float(row)*Float.pi/24,b=Float(row+1)*Float.pi/24
            for side in 0..<48 {
                let c=Float(side)*2*Float.pi/48,d=Float(side+1)*2*Float.pi/48
                func point(_ u:Float,_ v:Float)->V {base+V(cos(u)*radius*cos(v),sin(u)*height,cos(u)*radius*sin(v))}
                quad(point(a,c),point(a,d),point(b,d),point(b,c),material)
            }
        }
    }

    private func tribuneGothicCrown(_ p:GatewayPalette) {
        let c=MagnificentGatewayLayout.tribune
        func radial(_ angle:Float,_ radius:Float,_ y:Float)->V {c+V(cos(angle)*radius,y,sin(angle)*radius)}
        gatewayTaper(c+V(0,110.6,0),Float.pi/8,12.3,9.8,5.5,8,p.limestone)
        gatewayTaper(c+V(0,116.1,0),Float.pi/8,9.8,9.8,16.8,8,p.limestone)
        for i in 0..<8 {
            let angle=Float(i)*Float.pi/4,n=V(cos(angle),0,sin(angle)),t=V(-sin(angle),0,cos(angle))
            let face=radial(angle,9.08,123.5)
            orientedBox(face,t,V(0,1,0),n,V(4.4,12.2,0.10),p.recess)
            // Pointed lancet tracery with two narrow nested openings per face.
            for offset:Float in [-1.1,1.1] {
                let root=radial(angle,9.2,118.0)+t*offset
                for side:Float in [-1,1] {beam(root+t*side*0.68,root+t*side*0.68+V(0,8.0,0),0.15,0.20,p.trim,normal:n)}
                beam(root-t*0.68+V(0,8,0),root+V(0,10.5,0),0.19,0.23,p.trim,normal:n)
                beam(root+t*0.68+V(0,8,0),root+V(0,10.5,0),0.19,0.23,p.trim,normal:n)
            }
            // Eight open flying buttresses connect outer pinnacles to the
            // central lantern; paired curves leave visible Gothic openings.
            let outer=radial(angle,14.5,111)
            cylinder(outer,outer+V(0,15.3,0),0.66,p.limestone,segments:8)
            for level:Float in [111,116,121,126.0] {orientedBox(radial(angle,14.5,level),t,V(0,1,0),n,V(1.55,0.42,1.55),p.trim)}
            for lower in [false,true] {
                var previous=radial(angle,14.5,lower ? 113.5:116.5)
                for step in 1...12 {
                    let u=Float(step)/12
                    let radius:Float=14.5-5.5*u
                    let y:Float=(lower ? 113.5:116.5)+10.0*u+4*sin(u*Float.pi)
                    let next=radial(angle,radius,y)
                    beam(previous,next,lower ? 0.42:0.66,0.72,p.limestone,normal:t)
                    if !lower && step%3==0 {ellipsoid(next+n*0.27,V(0.25,0.32,0.25),p.trim,segments:8,rings:4)}
                    previous=next
                }
            }
            gatewayTaper(radial(angle,14.5,126.4),angle,0.90,0.35,6.4,4,p.trim)
            cylinder(radial(angle,14.5,132.8),radial(angle,14.5,135.5),0.13,p.trim,segments:8)
            for y:Float in [129,131.2] {for side:Float in [-1,1] {ellipsoid(radial(angle,14.5,y)+t*side*0.54,V(0.20,0.29,0.20),p.trim,segments:8,rings:4)}}
            // Inner parapet piers and upper crocketed pinnacles define the top.
            cylinder(radial(angle,9.65,130.5),radial(angle,9.65,136.8),0.46,p.limestone,segments:8)
            gatewayTaper(radial(angle,9.65,136.8),angle,0.64,0.04,4.9,4,p.trim)
            scene.lights.append(NightLighting.source(radial(angle,15.8,111.6),toward:radial(angle,9.3,127.5),power:420,color:V(1,0.86,0.65),range:44,radius:0.95,outerDegrees:78,innerDegrees:52))
        }
        for y:Float in [130.8,132.8,134.8] {gatewayTaper(c+V(0,y,0),Float.pi/8,10.15,10.15,0.35,8,p.trim)}
        gatewayTaper(c+V(0,135.1,0),Float.pi/8,9.7,6.8,2.8,8,p.limestone)
        gatewayTaper(c+V(0,137.9,0),Float.pi/8,6.8,0.10,1.15,8,p.roof)
    }

    private func tribuneEntry(_ p:GatewayPalette) {
        // A recessed Gothic portal on the mapped Michigan Avenue frontage.
        let center=V(997.5,0,-1282.5),n=V(-1,0,0),t=V(0,0,1)
        orientedBox(center+V(0,3.4,0),t,V(0,1,0),n,V(7.4,6.8,0.12),p.recess)
        for z:Float in [-3.9,-2.8,2.8,3.9] {
            orientedBox(center+t*z+V(0,4.2,0)+n*0.18,t,V(0,1,0),n,V(0.42,8.4,0.55),p.trim)
            beam(center+t*z+V(0,8.2,0),center+V(0,11.7-abs(z)*0.25,0),0.28,0.44,p.trim,normal:n)
        }
        for z:Float in [-2.2,-0.73,0.73,2.2] {
            orientedBox(center+t*z+V(0,2.2,0)+n*0.25,t,V(0,1,0),n,V(1.37,4.3,0.08),p.windows[0])
            cylinder(center+t*(z+0.45)+V(0,1.1,0)+n*0.33,center+t*(z+0.45)+V(0,1.9,0)+n*0.33,0.027,p.bronze,segments:8)
        }
        // Small inset fragments suggest the documented collection of embedded
        // historic stones, without inventing legible inscriptions or provenance.
        for side:Float in [-1,1] {for i in 0..<8 {
            let u:Float=side*(5.0+Float(i%3)*1.35)
            let y:Float=1.1+Float(i/3)*1.2
            let c=center+t*u+V(0,y,0)+n*0.13
            orientedBox(c,t,V(0,1,0),n,V(0.55+Float(i%2)*0.25,0.43+Float(i%3)*0.09,0.16),i%2==0 ? p.limestone:p.trim)
        }}
        scene.lights.append(NightLighting.source(center+n*1.4+V(0,9.4,0),toward:center+V(0,2,0),power:55,color:V(1,0.82,0.62),range:17,radius:0.22,outerDegrees:58,innerDegrees:32))
    }
}
