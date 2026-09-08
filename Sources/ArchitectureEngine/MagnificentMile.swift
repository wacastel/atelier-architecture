import Foundation
import simd

/// Mapped anchors use the same east/up/south metre grid as the rest of Chicago.
/// Footprints: OSM September 8 2026. Architectural heights: SOM and CTBUH.
enum MagnificentMileLayout {
    static let hancock = SIMD3<Float>(1062.85,0,-2219.95)
    static let hancockRoof:Float = 343.7
    static let hancockTip:Float = 457.2
    static let waterTowerPlace = SIMD3<Float>(1123.96,0,-2112.35)
    static let waterTowerPlaceRoof:Float = 261.9
    static let waterTowerPlacePodium:Float = 55 // mapped outer podium
    static let waterTowerPlaceInset:Float = 60 // mapped hotel plinth
    static let historicWaterTower = SIMD3<Float>(951.60,0,-2036.52)
    static let historicWaterTowerHeight:Float = 55.626
    static let historicObservationFloor:Float = 46.1772 // HABS 151′6″
    static let historicCupolaBase:Float = 50.4444 // HABS 165′6″
    static let pumpingStation = SIMD3<Float>(1003.30,0,-2036.50)
}

private struct MileFrame {
    let center:SIMD3<Float>, angle:Float
    var x:SIMD3<Float> { SIMD3(cos(angle),0,sin(angle)) }
    var z:SIMD3<Float> { SIMD3(-sin(angle),0,cos(angle)) }
    func point(_ p:SIMD3<Float>)->SIMD3<Float> { center+x*p.x+SIMD3(0,p.y,0)+z*p.z }
}
private struct MilePalette {
    let black:UInt32, edge:UInt32, recess:UInt32, marble:UInt32, marbleEdge:UInt32
    let limestone:UInt32, trim:UInt32, roof:UInt32, glass:UInt32, clear:UInt32
    let granite:UInt32, paving:UInt32, steel:UInt32, wood:UInt32, warm:UInt32, mast:UInt32, red:UInt32
    let windows:[UInt32]
}

extension EiffelBuilder {
    func magnificentMile() {
        func add(_ m:SceneMaterial)->UInt32 { let i=UInt32(scene.materials.count);scene.materials.append(m);return i }
        let p=MilePalette(
            black:add(SceneMaterial(V(0.036,0.034,0.031),roughness:0.38,metallic:0.67,pattern:2)),
            edge:add(SceneMaterial(V(0.073,0.073,0.067),roughness:0.32,metallic:0.7)),
            recess:add(SceneMaterial(V(0.015,0.019,0.020),roughness:0.75)),
            marble:add(SceneMaterial(V(0.59,0.59,0.565),roughness:0.53,pattern:1)),
            marbleEdge:add(SceneMaterial(V(0.70,0.70,0.66),roughness:0.47)),
            limestone:add(SceneMaterial(V(0.65,0.57,0.43),roughness:0.82,pattern:10)),
            trim:add(SceneMaterial(V(0.77,0.70,0.56),roughness:0.76)),
            roof:add(SceneMaterial(V(0.20,0.225,0.22),roughness:0.66)),
            glass:add(SceneMaterial(V(0.11,0.15,0.16),roughness:0.15,metallic:0.70)),
            clear:add(SceneMaterial(V(0.98,0.99,0.99),roughness:0.07,transmission:1)),
            granite:add(SceneMaterial(V(0.16,0.16,0.15),roughness:0.48,pattern:1)),
            paving:add(SceneMaterial(V(0.48,0.465,0.425),roughness:0.65,pattern:1)),
            steel:add(SceneMaterial(V(0.53,0.56,0.56),roughness:0.30,metallic:0.86)),
            wood:add(SceneMaterial(V(0.29,0.19,0.10),roughness:0.57,pattern:3)),
            warm:add(SceneMaterial(V(1,0.82,0.57),roughness:0.3,emission:1,pattern:8)),
            mast:add(SceneMaterial(V(0.66,0.68,0.67),roughness:0.40,metallic:0.25,emission:0.44,pattern:15)),
            red:add(SceneMaterial(V(1,0.035,0.008),roughness:0.3,emission:1,pattern:8)),
            windows:[Float(0),0.065,0.095,0.135,0.19].map { add(SceneMaterial(V(0.105,0.118,0.123),roughness:0.13,metallic:0.72,emission:$0,pattern:14)) })
        hancockLandmark(p)
        waterTowerPlaceLandmark(p)
        historicWaterTowerLandmark(p)
        pumpingStationLandmark(p)
    }

    private func mileBox(_ f:MileFrame,_ c:V,_ size:V,_ m:UInt32) {
        orientedBox(f.point(c),f.x,V(0,1,0),f.z,size,m)
    }
    private func mileWindow(_ p:MilePalette,_ floor:Int,_ bay:Int,_ side:Int)->UInt32 {
        // Stable room groups, not a moving world-space pattern. Most rooms stay dark.
        let seed=(floor*71+(bay/2)*43+side*107+floor*(bay/2)*7)%100
        return p.windows[seed<68 ? 0:1+(seed%4)]
    }

    private func hancockLandmark(_ p:MilePalette) {
        let f=MileFrame(center:MagnificentMileLayout.hancock,angle:-0.01745)
        let height:Float=337
        func extent(_ y:Float)->V { let t=max(0,min(1,y/height));return V(82.3-32.9*t,y,52.6-21.1*t) }
        func at(_ side:Int,_ u:Float,_ y:Float,_ outset:Float=0)->V {
            let e=extent(y),n=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side]
            let t=V(-n.z,0,n.x),half=abs(n.x)>0.5 ? e.x/2:e.z/2
            let width=abs(n.x)>0.5 ? e.z:e.x
            return f.point(n*(half+outset)+t*(u*width/2)+V(0,y,0))
        }
        func elev(_ floor:Int)->Float { floor==0 ? 0:6.8+Float(floor-1)*(height-6.8)/99 }
        // Each face is genuinely tapered; panes, spandrels and braces follow it.
        for side in 0..<4 {
            let localN=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side]
            let n=f.x*localN.x+f.z*localN.z,bays=side%2==0 ? 24:38
            quad(at(side,-1,0,-0.28),at(side,1,0,-0.28),at(side,1,height,-0.28),at(side,-1,height,-0.28),p.recess)
            for floor in 0..<100 {
                let y0=elev(floor),y1=elev(floor+1)
                let mechanical=(42...43).contains(floor)||(96...99).contains(floor)
                quad(at(side,-1,y0,0),at(side,1,y0,0),at(side,1,y0+0.66,0),at(side,-1,y0+0.66,0),p.black)
                beam(at(side,-1,y1,0.10),at(side,1,y1,0.10),0.12,0.25,p.edge,normal:n)
                for bay in 0..<bays {
                    let u0 = -1+2*Float(bay)/Float(bays),u1 = -1+2*Float(bay+1)/Float(bays)
                    let inset:Float=0.0018
                    if mechanical {
                        quad(at(side,u0+inset,y0+0.68,0.015),at(side,u1-inset,y0+0.68,0.015),at(side,u1-inset,y1-0.13,0.015),at(side,u0+inset,y1-0.13,0.015),p.black)
                    } else {
                        quad(at(side,u0+inset,y0+0.68,-0.025),at(side,u1-inset,y0+0.68,-0.025),at(side,u1-inset,y1-0.13,-0.025),at(side,u0+inset,y1-0.13,-0.025),mileWindow(p,floor,bay,side))
                    }
                }
                if mechanical {
                    for k in 1..<9 { let y=y0+Float(k)*(y1-y0)/9;beam(at(side,-1,y,0.08),at(side,1,y,0.08),0.06,0.16,p.edge,normal:n) }
                }
            }
            // Linear taper keeps each mullion collinear across all floors. One
            // continuous member avoids hidden end caps at every spandrel.
            for bay in 0...bays {
                let u = -1+2*Float(bay)/Float(bays)
                beam(at(side,u,0,0.075),at(side,u,height,0.075),bay%4==0 ? 0.25:0.072,0.22,p.black,normal:n)
            }
            // Five approximately twenty-storey X panels expose Khan's tube structure.
            for section in 0..<5 {
                let y0=elev(section*20)+0.45,y1=elev((section+1)*20)-0.25
                for direction:Float in [-1,1] {
                    let a=at(side,-direction,y0,0.36),b=at(side,direction,y1,0.36)
                    beam(a,b,1.45,0.78,p.black,normal:n)
                    let tangent=simd_normalize(simd_cross(b-a,n))
                    for edge:Float in [-1,1] {beam(a+tangent*edge*0.69+n*0.40,b+tangent*edge*0.69+n*0.40,0.055,0.055,p.edge,normal:n)}
                }
                let mid=(y0+y1)/2,c=at(side,0,mid,0.86)
                let tangent=simd_normalize(simd_cross(V(0,1,0),n))
                orientedBox(c,tangent,V(0,1,0),n,V(2.15,3.1,0.08),p.black)
                // Close-range seam plates and bolts; upper panels keep the silhouette budget low.
                if section<2 {
                    for u:Float in [-0.75,0.75] {for y:Float in [-1.05,-0.55,0,0.55,1.05] {rivet(c+tangent*u+V(0,y,0)+n*0.045,n,0.041,p.edge,segments:6,bands:2)}}
                }
                beam(at(side,-1,y1,0.38),at(side,1,y1,0.38),1.0,0.78,p.black,normal:n)
            }
            for u:Float in [-1,0,1] {beam(at(side,u,0,0.27),at(side,u,height,0.27),u==0 ? 0.95:1.45,0.70,p.black,normal:n)}
            // Restrained white Crown of Lights at the 99th storey, divided by mullions.
            for bay in 0..<bays {
                let a = -1+2*Float(bay)/Float(bays)+0.003,b = -1+2*Float(bay+1)/Float(bays)-0.003
                quad(at(side,a,331.2,0.09),at(side,b,331.2,0.09),at(side,b,333.8,0.09),at(side,a,333.8,0.09),p.mast)
            }
        }
        mileBox(f,V(0,337.1,0),V(49.4,0.20,31.5),p.roof)
        mileBox(f,V(-3.3,340.45,0.3),V(37.3,6.5,19.0),p.black)
        for z:Float in [-12,12] { for x in stride(from:Float(-19),through:19,by:7.6) {
            mileBox(f,V(x,337.9,z),V(4.5,1.5,3.3),p.edge)
            for k in 0..<8 {mileBox(f,V(x,338.7,z-1.2+Float(k)*0.34),V(4.1,0.06,0.06),p.black)}
        }}
        for x:Float in [-15.7,15.45] {
            let base=f.point(V(x,343.7,0)),top=f.point(V(x,457.2,0))
            cylinder(base,base+V(0,48,0),1.0,p.edge,segments:16)
            cylinder(base+V(0,48,0),base+V(0,91,0),0.66,p.mast,segments:16)
            cylinder(base+V(0,91,0),top,0.34,p.mast,segments:12)
            for y in stride(from:Float(350),through:450,by:8) {
                cylinder(f.point(V(x,y,0)),f.point(V(x,y+0.22,0)),1.08-(y-350)*0.006,p.steel,segments:16)
            }
            for y:Float in [388,420,456.9] {ellipsoid(f.point(V(x,y,0)),V(repeating:0.30),p.red,segments:10,rings:5)}
            for z:Float in [-2,2] {beam(f.point(V(x+z,343.7,z)),f.point(V(x,367,0)),0.16,0.16,p.black)}
        }
        hancockPlaza(f,p)
    }

    private func hancockPlaza(_ f:MileFrame,_ p:MilePalette) {
        // The public forecourt occupies the actual west setback. Terraced edges
        // suggest the sunken plaza while keeping the shared street plane intact.
        mileBox(f,V(-54.5,0.11,0),V(25,0.22,79),p.paving)
        for z:Float in [-36,36] {
            for i in 0..<5 {mileBox(f,V(-54.5,Float(i)*0.18+0.11,z+(z<0 ? -1:1)*Float(i)*0.5),V(23,0.18,0.52),p.granite)}
            for x:Float in [-62,-49] {
                mileBox(f,V(x,1.08,z+0.5),V(3.2,0.7,3),p.granite)
                tree(f.point(V(x,1.43,z+0.5)),height:5.6)
            }
        }
        // A low retail pavilion to the southwest, glazing and lit soffit.
        mileBox(f,V(-54.3,3.7,21.4),V(11.4,0.35,17.5),p.black)
        mileBox(f,V(-54.3,0.25,21.4),V(11.4,0.2,17.5),p.granite)
        for z in stride(from:Float(13.5),through:29.3,by:2.6) {
            mileBox(f,V(-59.8,1.9,z),V(0.09,3.2,2.5),p.glass)
            mileBox(f,V(-59.9,1.9,z-1.3),V(0.16,3.3,0.10),p.black)
        }
        for z:Float in [-27,-13,1,13,29] {
            let c=f.point(V(-43.2,3.4,z))
            scene.lights.append(NightLighting.source(c,toward:c+V(-7,-3,0),power:20,color:V(1,0.83,0.64),range:18,radius:0.22,outerDegrees:67,innerDegrees:38))
            mileBox(f,V(-42.9,3.5,z),V(0.35,0.2,0.8),p.warm)
        }
        for z:Float in [-21,-7,8] {
            for x:Float in [-64,-48] {
                mileBox(f,V(x,0.43,z),V(0.60,0.62,2.6),p.granite)
                for k in 0..<5 {mileBox(f,V(x,0.77,z-1.1+Float(k)*0.54),V(0.62,0.07,0.44),p.wood)}
            }
        }
        // Pedestrian-scale canopy and portal hardware on the Michigan façade.
        mileBox(f,V(-42.2,5.2,0),V(3.4,0.32,23),p.black)
        for z:Float in [-9,-6,-3,3,6,9] {
            mileBox(f,V(-41.9,2.2,z),V(0.08,4.0,2.7),p.glass)
            mileBox(f,V(-42.05,2.2,z+1.3),V(0.18,4.2,0.09),p.steel)
            cylinder(f.point(V(-42.16,1.05,z+1.05)),f.point(V(-42.16,1.85,z+1.05)),0.025,p.steel)
        }
        mileLabel("875 N MICHIGAN",f.point(V(-43.98,4.15,0)),f.z,-f.x,0.31,p.steel)
        for z:Float in [-30,-19,19,30] {cylinder(f.point(V(-66,0.16,z)),f.point(V(-66,0.95,z)),0.075,p.black)}
    }

    private func waterTowerPlaceLandmark(_ p:MilePalette) {
        let f=MileFrame(center:V(1076.58,0,-2129.72),angle:-0.021)
        // The mall occupies only part of a twelve-storey podium. The upper
        // hotel/meeting levels and inset roof follow the mapped 55/60m parts.
        let podium=MagnificentMileLayout.waterTowerPlacePodium
        let inset=MagnificentMileLayout.waterTowerPlaceInset
        mileBox(f,V(0,podium/2,0),V(161.2,podium,65.2),p.marble)
        mileBox(f,V(0,podium-0.13,0),V(161.8,0.26,65.8),p.marbleEdge)
        mileBox(f,V(0,podium-0.06,0),V(160.7,0.12,64.7),p.roof)
        for side in 0..<4 {
            let n=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side],t=V(-n.z,0,n.x)
            let width:Float=side%2==0 ? 65.2:161.2,depth:Float=side%2==0 ? 80.6:32.6
            let wn=f.x*n.x+f.z*n.z,wt=f.x*t.x+f.z*t.z
            func ob(_ u:Float,_ y:Float,_ d:Float,_ size:V,_ m:UInt32) {orientedBox(f.point(n*(depth+d)+t*u+V(0,y,0)),wt,V(0,1,0),wn,size,m)}
            let count=Int(width/3.0)
            // Actual joint relief and restrained vertical panel rhythm above the shops.
            for j in 0...count {
                let u = -width/2+Float(j)*width/Float(count)
                ob(u,31.3,0.035,V(0.045,45.2,0.065),p.recess)
            }
            for y in stride(from:Float(9),through:54,by:3) {ob(0,y,0.045,V(width,0.043,0.07),p.recess)}
            for y:Float in [43.1,47.5,51.9] {
                for j in 0..<count {
                    let u = -width/2+(Float(j)+0.5)*width/Float(count)
                    ob(u,y,0.085,V(width/Float(count)-0.22,2.80,0.07),mileWindow(p,Int(y),j,side+8))
                    ob(u,y-1.425,0.13,V(width/Float(count)-0.10,0.11,0.15),p.marbleEdge)
                }
            }
            ob(0,8.0,0.08,V(width,0.38,0.32),p.marbleEdge)
            for bay in 0..<Int(width/4.6) {
                let u = -width/2+2.4+Float(bay)*4.6
                ob(u,3.8,0.06,V(4.35,6.6,0.12),p.glass)
                ob(u-2.22,3.8,0.23,V(0.18,7,0.24),p.steel)
                ob(u,0.52,0.25,V(4.4,0.4,0.40),p.granite)
                ob(u,6.75,0.27,V(4.4,0.16,0.35),p.steel)
                // Recessed display panels add depth behind the shopfront mullions.
                if bay % ((side==1 || side==2) ? 2:3)==0 {
                    ob(u,3.75,0.145,V(2.7,3.4,0.035),p.windows[(side==1 || side==2) ? 3:1])
                }
                if side==1 || side==2 {ob(u,6.66,0.38,V(3.8,0.05,0.14),p.windows[3])}
            }
            if side==2 {
                mileLabel("WATER TOWER PLACE",f.point(n*(depth+0.15)+t*12.0+V(0,54.0,0)),wt,wn,1.08,p.black)
            }
            if side==1 || side==2 {
                // Effective canopy/display banks illuminate the public Michigan
                // and Pearson shopfronts without floodlighting the tall podium.
                let lamps=side==2 ? 4:6
                for lamp in 0..<lamps {
                    let u = -width/2+(Float(lamp)+0.5)*width/Float(lamps)
                    let c=f.point(n*(depth+3.2)+t*u+V(0,5.8,0))
                    let target=f.point(n*(depth+0.08)+t*u+V(0,3.5,0))
                    scene.lights.append(NightLighting.source(c,toward:target,power:24,color:V(1,0.86,0.69),range:23,radius:0.85,outerDegrees:75,innerDegrees:48))
                }
            }
        }
        // Michigan Avenue's curved glass entrance volume, with vertical metal ribs.
        let c=V(-80.35,0,-29.1),r:Float=3.4
        for j in 0..<18 {
            let a = -Float.pi/2+Float(j)*Float.pi/18,b = -Float.pi/2+Float(j+1)*Float.pi/18
            func point(_ theta:Float,_ y:Float)->V {f.point(c+V(-cos(theta)*r,y,sin(theta)*r))}
            quad(point(a,0.32),point(b,0.32),point(b,14.65),point(a,14.65),p.glass)
            beam(point(a,0.2),point(a,14.9),0.10,0.10,p.steel)
            for y:Float in [3.2,7.4,10.7,14.7] {beam(point(a,y),point(b,y),0.13,0.16,p.steel)}
            tri(f.point(c+V(0,14.9,0)),point(a,14.9),point(b,14.9),p.glass)
        }
        // The smaller hotel volume creates the rooftop setback seen in the
        // map and in the official Ritz-Carlton 12th-floor plan. Its footprint
        // is the actual inset OSM part284776088, rotated with the rest of the site.
        let hotel=MileFrame(center:V(1076.17,0,-2129.66),angle:-0.021)
        mileBox(hotel,V(0,(podium+inset)/2,0),V(142.14,inset-podium,46.95),p.marble)
        for side in 0..<4 {
            let n=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side],t=V(-n.z,0,n.x)
            let width:Float=side%2==0 ? 46.95:142.14,depth:Float=side%2==0 ? 71.07:23.475
            let wn=hotel.x*n.x+hotel.z*n.z,wt=hotel.x*t.x+hotel.z*t.z
            let count=Int(width/3.3),step=width/Float(count)
            for bay in 0..<count {
                let u = -width/2+(Float(bay)+0.5)*step
                let c=hotel.point(n*(depth+0.04)+t*u+V(0,57.5,0))
                orientedBox(c,wt,V(0,1,0),wn,V(step-0.25,3.40,0.07),mileWindow(p,12,bay,side+12))
                orientedBox(c+wt*step/2,wt,V(0,1,0),wn,V(0.16,4.7,0.24),p.marbleEdge)
            }
        }
        mileBox(hotel,V(0,inset-0.13,0),V(142.5,0.26,47.3),p.marbleEdge)
        mileBox(hotel,V(0,inset-0.04,0),V(141.9,0.08,46.7),p.roof)
        // The full tower footprint is supported down to the outer podium,
        // including the south/east strip beyond the inset hotel's footprint.
        let tower=MileFrame(center:MagnificentMileLayout.waterTowerPlace,angle:-0.021)
        let base=inset,top=MagnificentMileLayout.waterTowerPlaceRoof
        mileBox(tower,V(0,(podium+top)/2,0),V(66.95,top-podium,28.22),p.marble)
        for side in 0..<4 {
            let n=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side],t=V(-n.z,0,n.x)
            let width:Float=side%2==0 ? 28.22:66.95,depth:Float=side%2==0 ? 33.475:14.11
            let count=side%2==0 ? 10:25,step=width/Float(count)
            let wn=tower.x*n.x+tower.z*n.z,wt=tower.x*t.x+tower.z*t.z
            for floor in 11..<74 {
                let y0=floor==11 ? podium:base+Float(floor-12)*(top-base)/62
                let y1=floor==11 ? base:base+Float(floor-11)*(top-base)/62
                for bay in 0..<count {
                    let u = -width/2+(Float(bay)+0.5)*step
                    let c=tower.point(n*(depth+0.027)+t*u+V(0,(y0+y1)/2,0))
                    let edge=bay==0||bay==count-1
                    orientedBox(c,wt,V(0,1,0),wn,V(edge ? step*0.46:step*0.73,y1-y0-0.77,0.06),mileWindow(p,floor+11,bay,side+4))
                    orientedBox(c+V(0,-(y1-y0-0.71)/2,0)+wn*0.06,wt,V(0,1,0),wn,V(step*0.76,0.08,0.13),p.marbleEdge)
                }
            }
            for bay in 0...count {
                let u = -width/2+Float(bay)*step
                let c=tower.point(n*(depth+0.025)+t*u+V(0,(podium+top)/2,0))
                orientedBox(c,wt,V(0,1,0),wn,V(0.035,top-podium,0.04),p.granite)
            }
        }
        mileBox(tower,V(0,top-0.23,0),V(67.35,0.46,28.62),p.marbleEdge)
        mileBox(tower,V(0,top-0.04,0),V(66.4,0.10,27.7),p.roof)
        for x:Float in [-25,-14,-3,8,19] {
            mileBox(tower,V(x,top-1.0,0),V(6,1.8,7),p.roof)
            for j in 0..<5 {mileBox(tower,V(x,top-0.05,-2.4+Float(j)*1.2),V(5.4,0.08,0.08),p.edge)}
        }
        for x:Float in [-63,-43,-23,-3] {
            mileBox(hotel,V(x,60.5,16),V(6,1,5),p.roof)
            mileBox(hotel,V(x,60.55,-18),V(5,1.1,3),p.roof)
        }
        // Street terrace and entry furniture leave the public sidewalk at x980 clear.
        mileBox(f,V(-84,0.08,0),V(6.1,0.16,65),p.paving)
        for z:Float in [-27,-16,16,28] {
            mileBox(f,V(-84.8,0.62,z),V(1.1,1.1,1.1),p.granite)
            ellipsoid(f.point(V(-84.8,1.30,z)),V(0.65,0.45,0.65),leaf,segments:10,rings:5)
        }
    }

    private func historicWaterTowerLandmark(_ p:MilePalette) {
        let f=MileFrame(center:MagnificentMileLayout.historicWaterTower,angle:-0.026)
        mileBox(f,V(0,0.15,0),V(16.2,0.30,16.2),p.trim)
        mileBox(f,V(0,5.20,0),V(13.1,10.4,13.3),p.limestone)
        mileBox(f,V(0,14.1,0),V(6.4,14.0,6.4),p.limestone)
        for side in 0..<4 {
            let n=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side],t=V(-n.z,0,n.x)
            let wn=f.x*n.x+f.z*n.z,wt=f.x*t.x+f.z*t.z
            func ob(_ u:Float,_ y:Float,_ d:Float,_ s:V,_ m:UInt32) {orientedBox(f.point(n*d+t*u+V(0,y,0)),wt,V(0,1,0),wn,s,m)}
            for y:Float in [0.40,1.05,6.8,9.8,10.4] {ob(0,y,6.68,V(13.4,0.20,0.36),p.trim)}
            // Paired windows and the tall gabled entrance are carved as recessed
            // dark apertures, framed by individual arch voussoirs and jambs.
            for u:Float in [-4.35,4.35] {
                mileArch(f.point(n*6.73+t*u+V(0,1.25,0)),wt,wn,width:2.0,spring:3.35,rise:1.0,pointed:true,p:p)
                ob(u,2.6,6.92,V(0.16,2.5,0.18),p.trim)
                ob(u,1.1,6.88,V(2.55,0.26,0.46),p.trim)
            }
            // Central gabled porch on each axis (Michigan's east door is the main face).
            ob(0,4.6,6.84,V(3.85,8.6,0.52),p.limestone)
            mileArch(f.point(n*7.15+V(0,0.35,0)),wt,wn,width:2.15,spring:3.4,rise:1.25,pointed:true,p:p)
            let a=f.point(n*7.17-t*2.20+V(0,6.1,0)),b=f.point(n*7.17+V(0,8.45,0)),c=f.point(n*7.17+t*2.2+V(0,6.1,0))
            tri(a,b,c,p.limestone);beam(a,b,0.28,0.38,p.trim,normal:wn);beam(b,c,0.28,0.38,p.trim,normal:wn)
            // Upper central pavilion: narrow paired lancets below a second gable.
            mileArch(f.point(n*3.25+V(0,12.0,0)),wt,wn,width:1.6,spring:3.3,rise:0.9,pointed:true,p:p)
            ob(0,13.55,3.43,V(0.14,2.9,0.18),p.trim)
            let ga=f.point(n*3.46-t*2.6+V(0,16.1,0)),gb=f.point(n*3.46+V(0,19.25,0)),gc=f.point(n*3.46+t*2.6+V(0,16.1,0))
            tri(ga,gb,gc,p.limestone);beam(ga,gb,0.22,0.26,p.trim,normal:wn);beam(gb,gc,0.22,0.26,p.trim,normal:wn)
            mileArch(f.point(n*3.47+V(0,16.7,0)),wt,wn,width:0.80,spring:0.45,rise:0.60,pointed:true,p:p)
            for u:Float in [-2.9,2.9] {
                ob(u,14.0,3.45,V(0.35,12.0,0.42),p.trim)
                ob(u,9.6,3.48,V(0.55,0.4,0.60),p.trim)
            }
            for k in 0..<12 {
                let u = -6.12+Float(k)*1.11
                ob(u,10.8,6.63,V(0.54,1.1,0.48),p.trim)
                ob(u,9.38,6.69,V(0.23,0.52,0.32),p.trim)
            }
            for k in 0..<6 {let u = -2.85+Float(k)*1.14;ob(u,21.25,3.28,V(0.57,1.0,0.48),p.trim);ob(u,19.72,3.35,V(0.23,0.55,0.31),p.trim)}
            ob(0,20.35,3.32,V(6.9,0.35,0.58),p.trim)
            for y:Float in [26.2,37.3,42.7] {
                let shaftDepth:Float=(2.44-(y-21.6)*0.01286)*cos(Float.pi/8)+0.032
                mileArch(f.point(n*(shaftDepth+0.03)+V(0,y,0)),wt,wn,width:y>42 ? 0.68:0.54,spring:y>42 ? 1.2:2.3,rise:0.46,pointed:true,p:p)
            }
        }
        // HABS sheet 3 gives the observation floor at 151′6″ and the cupola
        // base at 165′6″. These explicit levels constrain the upper stages.
        let observation=MagnificentMileLayout.historicObservationFloor
        let cupola=MagnificentMileLayout.historicCupolaBase
        mileOctagonal(f,V.zero,[(20.5,2.76),(21.15,2.76),(21.6,2.44),
            (45.7,2.13),(45.94,2.48),(observation,2.48)],p.limestone)
        for y in stride(from:Float(22),through:45.4,by:0.70) {
            let r=2.44-(y-21.6)*0.01286
            mileOctagonal(f,V.zero,[(y,r+0.014),(y+0.026,r+0.014)],p.trim)
        }
        mileOctagonal(f,V.zero,[(observation,2.05),(cupola-0.25,2.05),(cupola,2.18)],p.limestone)
        for i in 0..<8 {
            let theta=Float(i)*Float.pi/4
            let n=V(cos(theta),0,sin(theta)),t=V(-n.z,0,n.x)
            let wn=f.x*n.x+f.z*n.z,wt=f.x*t.x+f.z*t.z
            mileArch(f.point(n*1.98+V(0,observation+0.38,0)),wt,wn,
                width:0.92,spring:2.76,rise:0.47,pointed:false,p:p)
        }
        // The cupola has a curved, ribbed metal profile. Its approximately
        // 12′2″ rise is interpreted from the drawing; the final spire is exact.
        let domeTop:Float=54.1528
        mileOctagonal(f,V.zero,[(cupola,2.25),(cupola+0.22,2.28),
            (cupola+0.55,2.22),(cupola+1.00,2.04),(cupola+1.53,1.74),
            (cupola+2.07,1.35),(cupola+2.61,0.90),(cupola+3.08,0.46),
            (domeTop,0.14)],p.roof)
        cylinder(f.point(V(0,domeTop-0.06,0)),
            f.point(V(0,MagnificentMileLayout.historicWaterTowerHeight,0)),0.095,p.black,segments:10)
        ellipsoid(f.point(V(0,54.87,0)),V(0.23,0.22,0.23),p.black,segments:12,rings:6)
        // Eight faces need eight azimuths. Broad overlapping photometric banks
        // represent the combined spread of the cornice-mounted projectors; the
        // effective stand-off positions are not an as-built fixture survey.
        // Intermediate banks prevent a dark middle shaft and cover the diagonal
        // faces that four cardinal spotlights leave in shadow.
        for face in 0..<8 {
            let theta=Float(face)*Float.pi/4,n=V(cos(theta),0,sin(theta))
            for (y,power):(Float,Float) in [(27,26),(37,34),(47,26)] {
                scene.lights.append(NightLighting.source(f.point(n*7.2+V(0,y,0)),
                    toward:f.point(n*2.15+V(0,y+1.5,0)),power:power,color:V(1,0.84,0.62),
                    range:28,radius:1.0,outerDegrees:80,innerDegrees:60))
            }
            // Compact visible housings stay on the actual lower/upper ledges.
            for (y,r):(Float,Float) in [(21.70,3.40),(46.26,2.60)] {
                mileBox(f,n*r+V(0,y,0),V(0.22,0.14,0.22),p.black)
            }
        }
        for n in [V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)] {
            // Gentle fill keeps the low stonework readable beneath its cornices.
            let middle=n*5.4+V(0,11.35,0)
            scene.lights.append(NightLighting.source(f.point(middle),
                toward:f.point(n*3.2+V(0,16.1,0)),power:6,color:V(1,0.84,0.64),
                range:19,radius:0.30,outerDegrees:40,innerDegrees:22))
            mileBox(f,middle-V(0,0.12,0),V(0.28,0.16,0.28),p.black)
            let lower=n*9.5+V(0,0.55,0)
            scene.lights.append(NightLighting.source(f.point(lower),
                toward:f.point(n*6.5+V(0,6.7,0)),power:6,color:V(1,0.84,0.64),
                range:23,radius:0.38,outerDegrees:55,innerDegrees:35))
            mileBox(f,lower-V(0,0.20,0),V(0.38,0.3,0.38),p.black)
        }
        for x:Float in [-6.55,6.55] {for z:Float in [-6.65,6.65] {mileTurret(f,V(x,0,z),radius:0.90,height:12.3,p:p)}}
        for x:Float in [-3.2,3.2] {for z:Float in [-3.2,3.2] {mileTurret(f,V(x,9.6,z),radius:0.57,height:10.8,p:p)}}
        // Jane Byrne Park: low paving, four planting corners and iron perimeter.
        mileBox(f,V(0,0.035,0),V(26,0.07,29),p.paving)
        for x:Float in [-10.3,10.3] {for z:Float in [-11.8,11.8] {
            mileBox(f,V(x,0.21,z),V(3.5,0.3,3.4),p.trim)
            mileBox(f,V(x,0.38,z),V(3.18,0.05,3.08),grass)
            for k in 0..<8 {
                let theta=Float(k)*Float.pi/4
                ellipsoid(f.point(V(x+cos(theta),0.65,z+sin(theta))),V(0.40,0.38,0.4),leaf,segments:7,rings:4)
            }
        }}
        for x:Float in [-10.3,10.3] {for z:Float in [-5,5] {
            mileBox(f,V(x,0.45,z),V(0.72,0.15,2.3),p.wood)
            for dz:Float in [-0.9,0.9] {mileBox(f,V(x,0.23,z+dz),V(0.55,0.44,0.12),p.black)}
        }}
        for x:Float in [-8.7,8.7] {for z:Float in [-8.8,8.8] {
            let pos=f.point(V(x,0.55,z)),target=f.point(V(x*0.28,22,z*0.28))
            scene.lights.append(NightLighting.source(pos,toward:target,power:65,color:V(1,0.83,0.62),range:65,radius:0.45,outerDegrees:45,innerDegrees:27))
            mileBox(f,V(x,0.25,z),V(0.5,0.5,0.5),p.black)
        }}
    }

    private func pumpingStationLandmark(_ p:MilePalette) {
        let f=MileFrame(center:MagnificentMileLayout.pumpingStation,angle:-0.026)
        mileBox(f,V(0,5.1,0),V(19.8,10.2,45.0),p.limestone)
        mileBox(f,V(-13.3,5.3,0),V(7.0,10.6,18.4),p.limestone)
        // Long steep roofs and the projecting Michigan-facing entrance gable.
        mileGable(f,V(0,10.1,0),width:20.4,length:45.5,rise:6.3,p:p)
        mileGable(f,V(-12.8,10.5,0),width:7.9,length:19.3,rise:4.1,p:p)
        for side in 0..<4 {
            let n=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side],t=V(-n.z,0,n.x)
            let width:Float=side%2==0 ? 45:19.8,d:Float=side%2==0 ? 9.9:22.5
            let wn=f.x*n.x+f.z*n.z,wt=f.x*t.x+f.z*t.z
            for u in stride(from:-width/2+2.5,through:width/2-2,by:4.7) {
                if side==2 && abs(u)<10 {continue}
                mileArch(f.point(n*(d+0.04)+t*u+V(0,1.4,0)),wt,wn,width:2.0,spring:3.8,rise:1.0,pointed:true,p:p)
                orientedBox(f.point(n*(d+0.20)+t*u+V(0,3.2,0)),wt,V(0,1,0),wn,V(0.13,3.4,0.18),p.trim)
            }
            for y:Float in [0.5,1.2,7.1,9.6,10.3] {orientedBox(f.point(n*(d+0.05)+V(0,y,0)),wt,V(0,1,0),wn,V(width+0.3,0.21,0.35),p.trim)}
            for u in stride(from:-width/2+0.5,through:width/2-0.4,by:1.0) {orientedBox(f.point(n*(d+0.08)+t*u+V(0,10.7,0)),wt,V(0,1,0),wn,V(0.47,0.80,0.40),p.trim)}
        }
        for x:Float in [-9.9,9.9] {for z:Float in [-22.5,22.5] {mileTurret(f,V(x,0,z),radius:1.12,height:13.5,p:p)}}
        for z:Float in [-9.25,9.25] {mileTurret(f,V(-16.8,0,z),radius:0.90,height:13.2,p:p)}
        let n = -f.x,t=f.z
        for z:Float in [-5.5,0,5.5] {
            mileArch(f.point(V(-16.87,0.45,z)),t,n,width:z==0 ? 2.45:2.05,spring:4.0,rise:1.1,pointed:true,p:p)
            if z != 0 {mileBox(f,V(-17.1,2.4,z),V(0.20,3.6,0.14),p.trim)}
        }
        for z:Float in [-7.4,7.4] {mileTurret(f,V(-16.8,8,z),radius:0.43,height:5.6,p:p)}
        mileLabel("CHICAGO WATER WORKS",f.point(V(-17.13,7.65,0)),f.z,-f.x,0.21,p.black)
        for z:Float in [-17,0,17] {
            let pos=f.point(V(-20.6,0.65,z))
            scene.lights.append(NightLighting.source(pos,toward:f.point(V(-11,12,z)),power:94,color:V(1,0.85,0.65),range:35,radius:0.35,outerDegrees:46,innerDegrees:26))
        }
    }

    private func mileGable(_ f:MileFrame,_ c:V,width:Float,length:Float,rise:Float,p:MilePalette) {
        let a=f.point(c+V(-width/2,0,-length/2)),b=f.point(c+V(width/2,0,-length/2)),v=f.point(c+V(0,rise,-length/2))
        let offset=f.z*length
        tri(a,b,v,p.limestone);tri(a+offset,v+offset,b+offset,p.limestone)
        quad(a,v,v+offset,a+offset,p.roof);quad(v,b,b+offset,v+offset,p.roof)
        for shift in [V.zero,offset] {beam(a+shift,v+shift,0.30,0.37,p.trim);beam(v+shift,b+shift,0.30,0.37,p.trim)}
        beam(v,v+offset,0.18,0.23,p.trim)
    }
    private func mileOctagonal(_ f:MileFrame,_ c:V,_ profile:[(Float,Float)],_ m:UInt32) {
        guard profile.count>1 else{return}
        for j in 1..<profile.count {
            let a=profile[j-1],b=profile[j]
            for i in 0..<8 {
                let t0=(Float(i)+0.5)*Float.pi/4,t1=(Float(i)+1.5)*Float.pi/4
                quad(f.point(c+V(cos(t0)*a.1,a.0,sin(t0)*a.1)),f.point(c+V(cos(t1)*a.1,a.0,sin(t1)*a.1)),f.point(c+V(cos(t1)*b.1,b.0,sin(t1)*b.1)),f.point(c+V(cos(t0)*b.1,b.0,sin(t0)*b.1)),m)
            }
        }
        if let last=profile.last {for i in 0..<8 {let a=(Float(i)+0.5)*Float.pi/4,b=(Float(i)+1.5)*Float.pi/4;tri(f.point(c+V(0,last.0,0)),f.point(c+V(cos(a)*last.1,last.0,sin(a)*last.1)),f.point(c+V(cos(b)*last.1,last.0,sin(b)*last.1)),m)}}
    }
    private func mileTurret(_ f:MileFrame,_ c:V,radius r:Float,height h:Float,p:MilePalette) {
        mileOctagonal(f,c,[(0,r*1.09),(0.35,r*1.09),(0.55,r),(h*0.57,r),(h*0.60,r*1.19),(h*0.64,r*1.19),(h*0.68,r),(h-1.45,r),(h-1.10,r*1.22),(h-0.70,r*1.22)],p.limestone)
        for y in stride(from:Float(1.0),to:h-1,by:0.65) {mileOctagonal(f,c,[(y,r*1.025),(y+0.06,r*1.025)],p.trim)}
        for i in 0..<8 {
            let theta=Float(i)*Float.pi/4,n=V(cos(theta),0,sin(theta)),t=V(-n.z,0,n.x)
            let wn=f.x*n.x+f.z*n.z,wt=f.x*t.x+f.z*t.z
            orientedBox(f.point(c+n*r*1.02+V(0,h-0.3,0)),wt,V(0,1,0),wn,V(r*0.58,0.60,r*0.45),p.trim)
        }
    }
    private func mileArch(_ bottom:V,_ tangent:V,_ normal:V,width:Float,spring:Float,rise:Float,pointed:Bool,p:MilePalette) {
        let w=width/2,up=V(0,1,0),edge:Float=0.19
        orientedBox(bottom+up*spring/2,tangent,up,normal,V(width,spring,0.025),p.recess)
        for side:Float in [-1,1] {orientedBox(bottom+tangent*side*(w+edge/2)+up*spring/2+normal*0.04,tangent,up,normal,V(edge,spring+0.2,0.30),p.trim)}
        let samples=16
        func a(_ j:Int)->V {
            let u=Float(j)/Float(samples),x = -w+u*width
            let y=pointed ? rise*pow(max(0,1-abs(x/w)),0.72):rise*sqrt(max(0,1-x*x/(w*w)))
            return bottom+tangent*x+up*(spring+y)
        }
        for j in 0..<samples {
            let a0=a(j),a1=a(j+1)
            tri(bottom+up*spring,a0,a1,p.recess)
            beam(a0+normal*0.05,a1+normal*0.05,edge,0.29,p.trim,normal:normal)
        }
        orientedBox(bottom-up*0.06+normal*0.08,tangent,up,normal,V(width+0.5,0.19,0.42),p.trim)
    }
    /// Small extruded block-letter signs, authored geometry without image textures.
    private func mileLabel(_ text:String,_ center:V,_ tangent:V,_ normal:V,_ height:Float,_ material:UInt32) {
        let glyphs:[Character:[String]]=[
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
