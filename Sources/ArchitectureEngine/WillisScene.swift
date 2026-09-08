import Foundation
import simd

/// Metre-scale bundled-tube reconstruction, with the current Catalog addition.
/// Published dimensions constrain the silhouette; authored interiors are documented in docs/WILLIS.md.
enum WillisScene {
    static let tube: Float = 22.86
    static let roofHeight: Float = 442.14
    static let skydeckHeight: Float = 412.3944
    static let terraceHeight: Float = 17
    static let stops: [TourStop] = [
        TourStop(id:0,title:"Chicago's great tower",subtitle:"442 METRES · NINE BUNDLED TUBES",detail:"The exact 75-foot tube grid and staggered setbacks rise above mapped Loop streets and the Chicago River. Black aluminum and bronze glazing define the landmark's silhouette.",pose:CameraPose(position:SIMD3(-470,310,600),target:SIMD3(-8,238,0),fov:49)),
        TourStop(id:1,title:"Welcome to Catalog",subtitle:"JACKSON BOULEVARD · STREET TO ATRIUM",detail:"Approach the contemporary podium and its light-filled entrance. Modeled curtain-wall frames, door handles, paving joints, planters and canopy lights establish human scale.",pose:CameraPose(position:SIMD3(0,1.85,81.5),target:SIMD3(0,10,50),fov:67)),
        TourStop(id:2,title:"Black aluminum, bronze glass",subtitle:"FAÇADE STUDY · PANEL BY PANEL",detail:"Inspect recessed bronze-tinted windows, aluminum columns, gaskets, mullions, cap plates and fine fasteners from the Catalog terrace. Every façade opening is individually modeled.",pose:CameraPose(position:SIMD3(-25,18.75,36.8),target:SIMD3(-23.4,21.2,34.29),fov:47)),
        TourStop(id:3,title:"A garden above the Loop",subtitle:"CATALOG TERRACE · CURVED GARDEN WALKS",detail:"Walk the planted roof beside the doubly curved skylight, sweeping stone benches, ornamental grasses and café seating. The garden is an interpretation of Gensler's contemporary renovation.",pose:CameraPose(position:SIMD3(29,18.75,63),target:SIMD3(5,20,47),fov:65)),
        TourStop(id:4,title:"Inside the Skydeck",subtitle:"103RD FLOOR · 1,353 FEET ABOVE CHICAGO",detail:"A walkable interpretation of the observation gallery at its published elevation. Transparent glazing reveals the mapped city beyond the structural columns and exhibit furniture.",pose:CameraPose(position:SIMD3(-31.1,414.1444,6.5),target:SIMD3(-60,406,-15),fov:72)),
        TourStop(id:5,title:"Out on the Ledge",subtitle:"GLASS BOXES · 4.3 FEET BEYOND THE FAÇADE",detail:"Step toward one of five west-facing glass boxes. Thin dielectric panels transmit the city below while reflecting the gallery; their steel retracting frames and glass edge fittings remain visible.",pose:CameraPose(position:SIMD3(-32.65,414.1444,0),target:SIMD3(-70,385,-8),fov:68)),
        TourStop(id:6,title:"Crown of the skyline",subtitle:"BROADCAST MASTS · ROOFTOP ENGINEERING",detail:"An aerial study of the twin antennae, setback roofs, maintenance rails, service equipment and Chicago's street grid. This camera is an architectural inspection, outside public visitor circulation.",pose:CameraPose(position:SIMD3(-92,468,100),target:SIMD3(-13,466,0),fov:58)),
        TourStop(id:7,title:"Along the Chicago River",subtitle:"SOUTH BRANCH · BRIDGES AND CITY LIGHT",detail:"Follow the South Branch past the riverfront and its steel bridge. Daylight reveals the urban layers; nighttime office lights and bridge lamps reflect on the water.",pose:CameraPose(position:SIMD3(-145,10,88),target:SIMD3(-180,5,-48),fov:82))
    ]
    // Setbacks are indexed geographically: z negative is north, x negative west.
    static func topFloor(x:Int,z:Int)->Int {
        if (x == -1 && z == -1) || (x == 1 && z == 1) { return 50 }
        if (x == 1 && z == -1) || (x == -1 && z == 1) { return 66 }
        return z == 0 && x <= 0 ? 110:90
    }
    static func elevation(_ floor:Int)->Float {
        // Intermediate mechanical-floor elevations are interpolated; the published
        // Skydeck and architectural roof elevations remain exact anchors.
        let keys:[(Int,Float)] = [(0,0),(50,200),(66,260),(90,355),(103,skydeckHeight),(108,435),(110,roofHeight)]
        for i in 1..<keys.count where floor <= keys[i].0 {
            let a=keys[i-1],b=keys[i],t=Float(floor-a.0)/Float(b.0-a.0)
            return a.1+(b.1-a.1)*t
        }
        return roofHeight
    }
    static func build()->SceneData {
        ChicagoWorld.build()
    }
}

private struct WillisPalette {
    let aluminum:UInt32, edge:UInt32, gasket:UInt32, glazing:UInt32, clear:UInt32
    let granite:UInt32, terrazzo:UInt32, stone:UInt32, ceiling:UInt32, wood:UInt32
    let stainless:UInt32, vegetation:UInt32, flower:UInt32, warmLight:UInt32, mast:UInt32, warning:UInt32
}

extension EiffelBuilder {
    func willisTower() {
        func material(_ value:SceneMaterial)->UInt32 { let index=UInt32(scene.materials.count);scene.materials.append(value);return index }
        let p=WillisPalette(
            aluminum:material(SceneMaterial(V(0.025,0.028,0.032),roughness:0.36,metallic:0.65,pattern:2)),
            edge:material(SceneMaterial(V(0.072,0.080,0.090),roughness:0.32,metallic:0.75)),
            gasket:material(SceneMaterial(V(0.009,0.010,0.010),roughness:0.88)),
            glazing:material(SceneMaterial(V(0.095,0.080,0.061),roughness:0.15,metallic:0.58,pattern:13)),
            clear:material(SceneMaterial(V(0.975,0.993,0.997),roughness:0.065,transmission:1)),
            granite:material(SceneMaterial(V(0.15,0.155,0.157),roughness:0.38,pattern:1)),
            terrazzo:material(SceneMaterial(V(0.53,0.52,0.48),roughness:0.46,pattern:1)),
            stone:material(SceneMaterial(V(0.62,0.60,0.54),roughness:0.7,pattern:1)),
            ceiling:material(SceneMaterial(V(0.72,0.71,0.68),roughness:0.80)),
            wood:material(SceneMaterial(V(0.33,0.21,0.115),roughness:0.51,pattern:3)),
            stainless:material(SceneMaterial(V(0.46,0.48,0.49),roughness:0.27,metallic:0.88)),
            vegetation:material(SceneMaterial(V(0.21,0.285,0.09),roughness:0.94,pattern:4)),
            flower:material(SceneMaterial(V(0.41,0.27,0.40),roughness:0.85)),
            warmLight:material(SceneMaterial(V(1,0.78,0.49),roughness:0.3,emission:1,pattern:8)),
            mast:material(SceneMaterial(V(0.68,0.73,0.78),roughness:0.38,metallic:0.2,emission:0.65,pattern:15)),
            warning:material(SceneMaterial(V(1,0.045,0.018),roughness:0.3,emission:1,pattern:8)))
        for z in -1...1 { for x in -1...1 {
            let top=WillisScene.topFloor(x:x,z:z),c=V(Float(x)*WillisScene.tube,0,Float(z)*WillisScene.tube)
            let h=WillisScene.elevation(top)
            for side in 0..<4 {
                let dx=[1,0,-1,0][side],dz=[0,1,0,-1][side]
                let neighbor = abs(x+dx)<=1 && abs(z+dz)<=1 ? WillisScene.topFloor(x:x+dx,z:z+dz):0
                guard neighbor<top else {continue}
                let n=V(Float(dx),0,Float(dz)),t=V(-n.z,0,n.x)
                willisFacade(c+n*WillisScene.tube/2,normal:n,tangent:t,from:neighbor,to:top,p:p)
            }
            // Actual horizontal slabs provide supports and prevent a hollow glowing shell.
            for floor in 0...top {
                let y=WillisScene.elevation(floor)
                box(c+V(0,y-0.18,0),V(WillisScene.tube,0.36,WillisScene.tube),floor==103 ? p.terrazzo:p.aluminum)
            }
            box(c+V(0,h+0.06,0),V(WillisScene.tube-0.38,0.12,WillisScene.tube-0.38),p.granite)
            // Setback parapets, drainage caps and roof service details.
            for side in 0..<4 {
                let n=[V(1,0,0),V(0,0,1),V(-1,0,0),V(0,0,-1)][side],t=V(-n.z,0,n.x)
                orientedBox(c+n*(WillisScene.tube/2-0.14)+V(0,h+0.36,0),t,V(0,1,0),n,V(WillisScene.tube,0.62,0.28),p.aluminum)
                orientedBox(c+n*(WillisScene.tube/2-0.14)+V(0,h+0.7,0),t,V(0,1,0),n,V(WillisScene.tube+0.05,0.07,0.35),p.edge)
            }
            if top<110 { willisRoofEquipment(c+V(0,h,0),p:p,large:false) }
        }}
        willisCatalog(p:p)
        willisSkydeck(p:p)
        willisCrown(p:p)
    }

    private func willisFacade(_ c:V,normal n:V,tangent t:V,from first:Int,to top:Int,p:WillisPalette) {
        let width=WillisScene.tube,step=width/15
        func ob(_ u:Float,_ y:Float,_ depth:Float,_ size:V,_ m:UInt32) {orientedBox(c+t*u+V(0,y,0)+n*depth,t,V(0,1,0),n,size,m)}
        for floor in first..<top {
            let bottom=WillisScene.elevation(floor),upper=WillisScene.elevation(floor+1),height=upper-bottom
            let mechanical=(29...31).contains(floor)||(64...65).contains(floor)||(88...89).contains(floor)||floor>=104
            let skydeck=floor==103
            // Ledge openings extend to the floor: a continuous sill would block entry.
            if skydeck && n.x < -0.5 && abs(c.x+34.29)<0.1 { continue }
            ob(0,bottom+0.40,0,V(width,0.8,0.21),p.aluminum)
            ob(0,upper-0.13,0.10,V(width,0.24,0.30),p.aluminum)
            for window in 0..<15 {
                let u = -width/2+(Float(window)+0.5)*step
                let center=c+t*u
                let columnWidth:Float = window%3==0 ? 0.36:0.075
                ob(u-step/2,bottom+height/2,0.13,V(columnWidth,height,0.4),p.aluminum)
                if mechanical {
                    ob(u,bottom+height/2,-0.02,V(step-0.085,height-0.4,0.06),p.gasket)
                    for j in 0..<13 { ob(u,bottom+0.46+Float(j)*(height-0.70)/13,0.06,V(step-0.10,0.055,0.12),p.edge) }
                } else {
                    // The Ledge apertures replace west-facing glass at the observation floor.
                    let ledge=skydeck && n.x < -0.5 && abs(center.x+34.29)<0.1
                    if !ledge {
                        let w=step-0.105,a=c+t*(u-w/2)+V(0,bottom+0.87,0)-n*0.035
                        let b=a+t*w,d=a+V(0,height-1.12,0)
                        quad(a,b,d+t*w,d,skydeck ? p.clear:p.glazing)
                    }
                    ob(u,bottom+0.84,0.03,V(step-0.03,0.08,0.17),p.edge)
                    ob(u,upper-0.245,0.02,V(step-0.03,0.055,0.17),p.gasket)
                    if bottom<28 {
                        // Close-range rebates, cap-strip seams and countersunk fixings.
                        ob(u-step/2+0.055,bottom+height/2,0.35,V(0.022,height-0.05,0.025),p.edge)
                        for y:Float in [bottom+1.02,upper-0.40] {
                            rivet(c+t*(u-step/2)+V(0,y,0)+n*0.342,n,0.018,p.stainless,segments:10,bands:3)
                        }
                    }
                }
                scene.detailCount += 1
            }
            ob(width/2,bottom+height/2,0.13,V(0.38,height,0.4),p.aluminum)
        }
    }

    private func willisCatalog(p:WillisPalette) {
        // South Jackson atrium and east amenity wing; the tower's footprint stays intact.
        box(V(3.5,-0.14,54),V(102,0.28,43),p.terrazzo)
        box(V(45,-0.14,0),V(20,0.28,69),p.terrazzo)
        box(V(-42,-0.14,0),V(15,0.28,69),p.terrazzo)
        for y:Float in [5.3,10.8,17] {
            box(V(-30,y-0.23,53.5),V(31,0.46,39),p.ceiling)
            box(V(32.5,y-0.23,53.5),V(40,0.46,39),p.ceiling)
            box(V(1.3,y-0.23,68),V(31.5,0.46,10),p.ceiling)
            box(V(45,y-0.23,0),V(20,0.46,69),p.ceiling)
        }
        // Front curtain wall. Leave a generous open entry aisle; glass is single-sheet.
        for x in stride(from:Float(-46),through:Float(54),by:3.4) {
            for y:Float in [2.6,8.0,13.85] {
                if y<5 && abs(x)<6 {continue}
                let h:Float=y>11 ? 5.5:5.05
                quad(V(x,y-h/2,73),V(x+3.24,y-h/2,73),V(x+3.24,y+h/2,73),V(x,y+h/2,73),p.clear)
                box(V(x-0.055,y,73.05),V(0.16,h+0.22,0.22),p.aluminum)
            }
        }
        for y:Float in [0.2,5.3,10.8,17] {box(V(4,y,73.12),V(102,0.24,0.25),p.aluminum)}
        for x:Float in [-45.5,-22.7,22.7,45.5] {box(V(x,8.5,53.5),V(0.55,17,0.55),p.stainless)}
        // Entry canopy and clear pivot door leaves, handles visible at human scale.
        box(V(0,4.2,75.1),V(18,0.26,5.2),p.aluminum)
        box(V(0,4.04,75.1),V(17.5,0.05,4.7),p.ceiling)
        for x:Float in [-5.8,5.8] {
            box(V(x,2,73),V(0.18,4,0.28),p.stainless)
            quad(V(x,0.15,73),V(x+(x<0 ? -1.5:1.5),0.15,72.55),V(x+(x<0 ? -1.5:1.5),3.65,72.55),V(x,3.65,73),p.clear)
            cylinder(V(x+(x<0 ? -1.3:1.3),0.95,72.53),V(x+(x<0 ? -1.3:1.3),1.65,72.53),0.025,p.stainless,segments:10)
        }
        for x:Float in [-7,-2.4,2.4,7] {willisDownlight(V(x,3.99,75),power:18,range:11,p:p)}
        // Interpret the central 75-foot square, doubly curved Jackson skylight.
        let center=V(0,17,49),half:Float=11.43,grid=16
        func point(_ i:Int,_ j:Int)->V {
            let x = -half+2*half*Float(i)/Float(grid),z = -half+2*half*Float(j)/Float(grid)
            let rise:Float=4.5*cos(x/half * .pi/2)*cos(z/half * .pi/2)
            return center+V(x,rise,z)
        }
        for i in 0..<grid {for j in 0..<grid {
            let a=point(i,j),b=point(i+1,j),c=point(i+1,j+1),d=point(i,j+1)
            quad(a,d,c,b,p.clear)
            beam(a,c,0.075,0.085,p.stainless)
            beam(b,d,0.075,0.085,p.stainless)
            if j==0 {beam(a,b,0.12,0.12,p.aluminum)}
            if i==0 {beam(a,d,0.12,0.12,p.aluminum)}
        }}
        // Close the flat roof around the precise skylight perimeter. The atrium
        // remains open below; only the glazed aperture opens through its roof.
        box(V(-12.965,16.77,48.5),V(3.07,0.46,29),p.ceiling)
        box(V(11.965,16.77,48.5),V(1.07,0.46,29),p.ceiling)
        box(V(0,16.77,35.785),V(22.86,0.46,3.57),p.ceiling)
        box(V(0,16.77,61.715),V(22.86,0.46,2.57),p.ceiling)
        for x:Float in [-9,9] {for z:Float in [40,58] {
            willisDownlight(V(x,16.8,z),power:72,range:23,p:p)
        }}
        // Roof garden ground is flush with its circulation paths.
        for x:Float in [-28,30] {
            box(V(x,17.035,50),V(24,0.07,23),grass)
            willisGardenArc(V(x,17.08,49),radius:10.5,p:p)
            for k in 0..<9 {
                let a=Float(k)*0.39+0.15,c=V(x+cos(a)*10,17,sin(a)*10+49)
                willisPlanter(c,radius:0.95,p:p)
            }
        }
        for x:Float in [-41,43] {for z:Float in [41,55,67] {willisSmallTree(V(x,17,z),p:p)}}
        // Café terrace south of the skylight: maintain the central walkthrough aisle.
        for x:Float in [-22,-15,16,24,35] {for z:Float in [65,70] {willisCafeTable(V(x,17,z),p:p)}}
        for x:Float in [-45,-12,13,52] {for z:Float in [38,61,71] {
            cylinder(V(x,17,z),V(x,20.8,z),0.075,p.aluminum,segments:10)
            box(V(x,20.85,z),V(0.34,0.13,0.55),p.aluminum)
            willisDownlight(V(x,20.77,z),power:20,range:12,p:p)
        }}
        // Discreet roof-level facade washers illuminate the near aluminum detail.
        // The upper tower retains its reference dark silhouette.
        for x:Float in [-29,-20,-8,8,22,30] {
            let q=V(x,17.18,35.9)
            box(q,V(0.42,0.17,0.34),p.aluminum)
            box(q+V(0,0.095,-0.055),V(0.30,0.025,0.21),p.warmLight)
            scene.lights.append(NightLighting.source(q+V(0,0.13,0),toward:V(x,22.8,34.29),power:37,color:V(1,0.79,0.54),range:13,radius:0.28,outerDegrees:70,innerDegrees:43))
        }
        for q in [V(43,17,61),V(28,17,41),V(-31,17,61)] {
            cylinder(q,q+V(0,3.8,0),0.065,p.aluminum,segments:10)
            willisDownlight(q+V(0,3.76,0),power:25,range:13,p:p)
        }
        let inspectionLamp=V(-25,20.7,40.2)
        cylinder(V(-25,17,40.2),inspectionLamp,0.065,p.aluminum,segments:10)
        box(inspectionLamp,V(0.30,0.18,0.35),p.aluminum)
        box(inspectionLamp+V(0,0,-0.19),V(0.24,0.12,0.02),p.warmLight)
        scene.lights.append(NightLighting.source(inspectionLamp+V(0,0,-0.24),toward:V(-23.4,21.2,34.29),power:110,color:V(0.86,0.9,1),range:14,radius:0.35,outerDegrees:75,innerDegrees:45))
        // Transparent roof balustrade with capped metal shoes and isolated posts.
        willisGlassRail(V(-46,17,73),V(54,17,73),p:p)
        willisGlassRail(V(54,17,73),V(54,17,-34),p:p)
        willisGlassRail(V(-46,17,73),V(-46,17,35),p:p)
        // Low retail furniture and warm ceiling rhythm visible through the podium.
        for x:Float in [-35,-24,24,37] {for z:Float in [42,56,67] {
            willisCafeTable(V(x,0,z),p:p)
            willisDownlight(V(x,5.0,z),power:18,range:10,p:p)
            willisDownlight(V(x,10.5,z),power:16,range:10,p:p)
        }}
        // Side-wall fins, bronze storefront frames and terracotta-toned seating.
        for z in stride(from:Float(-32),through:Float(70),by:3.4) {
            box(V(54,8.5,z),V(0.28,17,0.18),p.aluminum)
            for y:Float in [2.6,8,13.8] {quad(V(54,y-2.45,z),V(54,y-2.45,z+3.24),V(54,y+2.45,z+3.24),V(54,y+2.45,z),p.glazing)}
        }
        for x:Float in [-35,-22,22,36] {willisPlanter(V(x,0,76.7),radius:1.1,p:p)}
    }

    private func willisSkydeck(p:WillisPalette) {
        let y=WillisScene.skydeckHeight
        // The west-side public gallery remains a clear circulation zone.
        box(V(-3,y+1.65,0),V(13,3.3,12),p.ceiling)
        for z:Float in [-4,4] {
            box(V(-9.58,y+1.15,z),V(0.12,2.3,1.9),p.stainless)
            box(V(-9.66,y+1.15,z),V(0.06,2.22,0.025),p.gasket)
        }
        box(V(-11.43,y+3.36,0),V(45.72,0.15,22.86),p.ceiling)
        for x:Float in [-30,-22,-14,2] {for z:Float in [-7.8,0,7.8] {
            willisDownlight(V(x,y+3.26,z),power:3.8,range:6.2,p:p)
        }}
        for z:Float in [-9.3,9.3] {
            box(V(-20,y+0.30,z),V(6.4,0.30,0.75),p.aluminum)
            box(V(-20,y+0.48,z),V(6.7,0.12,0.82),p.wood)
            box(V(-20,y+0.10,z),V(5.7,0.20,0.40),p.stainless)
        }
        // Five west-facing Ledge boxes. Published projection 4.3 ft = 1.31064 m.
        let wall:Float = -34.29,front:Float = wall-1.31064,w:Float=3.048,h:Float=3.048
        let centers:[Float]=[-9.144,-4.572,0,4.572,9.144]
        for z in centers {
            let lo=z-w/2,hi=z+w/2
            quad(V(front,y,lo),V(wall,y,lo),V(wall,y,hi),V(front,y,hi),p.clear)
            quad(V(front,y,hi),V(wall,y,hi),V(wall,y+h,hi),V(front,y+h,hi),p.clear)
            quad(V(wall,y,lo),V(front,y,lo),V(front,y+h,lo),V(wall,y+h,lo),p.clear)
            quad(V(front,y,lo),V(front,y,hi),V(front,y+h,hi),V(front,y+h,lo),p.clear)
            quad(V(front,y+h,lo),V(front,y+h,hi),V(wall,y+h,hi),V(wall,y+h,lo),p.clear)
            // Retracting overhead tracks, perimeter seals and laminated floor edges.
            for zz:Float in [lo,hi] {
                beam(V(front,y-0.045,zz),V(wall,y-0.045,zz),0.048,0.07,p.stainless)
                beam(V(front,y+h+0.08,zz),V(wall+2.2,y+h+0.08,zz),0.13,0.15,p.stainless)
                beam(V(front,y,zz),V(front,y+h,zz),0.026,0.028,p.gasket)
                beam(V(wall,y,zz),V(wall,y+h,zz),0.11,0.11,p.aluminum)
                for yy:Float in [y+0.18,y+h-0.18] {rivet(V(front+0.01,yy,zz),V(-1,0,0),0.035,p.stainless,segments:12,bands:3)}
            }
            beam(V(front,y-0.060,lo),V(front,y-0.060,hi),0.075,0.13,p.stainless)
            // The real laminated floor has a visible bolted steel edge below the glass.
            for k in 0..<9 {
                let zz=lo+0.14+Float(k)*(w-0.28)/8
                rivet(V(front-0.041,y-0.058,zz),V(-1,0,0),0.025,p.stainless,segments:12,bands:3)
            }
            beam(V(front,y+h+0.03,lo),V(front,y+h+0.03,hi),0.07,0.09,p.stainless)
            box(V(wall+0.08,y+0.005,z),V(0.20,0.01,w),p.stainless)
        }
        // Infill between Ledge openings, with viewports above opaque sill height.
        var edges:[Float]=[-11.43]
        for z in centers {edges += [z-w/2,z+w/2]};edges.append(11.43)
        for i in stride(from:0,to:edges.count-1,by:2) {
            let a=edges[i],b=edges[i+1]
            quad(V(wall,y+0.84,a),V(wall,y+0.84,b),V(wall,y+3.2,b),V(wall,y+3.2,a),p.clear)
            box(V(wall,y+0.4,(a+b)/2),V(0.20,0.8,b-a),p.aluminum)
        }
        // Slim interpretive consoles face the glazing, away from the walking aisle.
        for z:Float in [-9.6,9.6] {
            box(V(-27.5,y+0.58,z),V(0.4,1.16,0.4),p.aluminum)
            orientedBox(V(-27.5,y+1.15,z),V(1,0,0),V(0,0.94,-0.342),V(0,0.342,0.94),V(2,0.07,0.62),p.edge)
        }
    }

    private func willisCrown(p:WillisPalette) {
        let y=WillisScene.roofHeight
        for x:Float in [-22.86,0] {
            let c=V(x,y,0)
            willisRoofEquipment(c+V(0,0,5.5),p:p,large:true)
            box(c+V(0,2,0),V(7.8,4,7.8),p.aluminum)
            box(c+V(0,4.12,0),V(8.3,0.24,8.3),p.edge)
            let tip:Float = x < -1 ? 527.3:520.6
            for band in 0..<17 {
                let lo=y+4+Float(band)*(tip-y-4)/17,hi=y+4+Float(band+1)*(tip-y-4)/17
                let radius:Float = band<6 ? 1.22:(band<12 ? 0.79:0.37)
                cylinder(V(x,lo,0),V(x,hi,0),radius,p.mast,segments:20)
                cylinder(V(x,lo,0),V(x,lo+0.16,0),radius+0.07,p.stainless,segments:20)
                for side in 0..<3 {
                    let a=Float(side)*2 * .pi/3
                    let offset=V(cos(a)*(radius+0.18),0,sin(a)*(radius+0.18))
                    cylinder(V(x,lo,0)+offset,V(x,hi,0)+offset,0.032,p.stainless,segments:6)
                }
            }
            // Maintenance ladders, rooftop aerials and dishes read at the crown viewpoint.
            for xx:Float in [-0.22,0.22] {beam(V(x+xx,y+4,1.45),V(x+xx,y+35,1.45),0.055,0.055,p.stainless)}
            for yy in stride(from:y+4,through:y+35,by:0.32) {beam(V(x-0.25,yy,1.45),V(x+0.25,yy,1.45),0.035,0.035,p.stainless)}
            for a:Float in [0,Float.pi/2,Float.pi,Float.pi*1.5] {
                let n=V(cos(a),0,sin(a))
                beam(c+n*3.6+V(0,1,0),c+n*1.2+V(0,24,0),0.18,0.18,p.stainless)
                scene.lights.append(NightLighting.source(c+n*2.5+V(0,5,0),toward:c+V(0,35,0),power:550,color:V(0.72,0.82,1),range:70,radius:0.3,outerDegrees:35,innerDegrees:18))
                scene.lights.append(NightLighting.source(c+n*1.5+V(0,45,0),toward:V(x,tip,0),power:185,color:V(0.91,0.95,1),range:49,radius:0.22,outerDegrees:32,innerDegrees:16))
            }
            for yy:Float in [y+8,y+45,tip] {ellipsoid(V(x,yy,0)+V(0,0,1.1),V(0.18,0.24,0.18),p.warning,segments:10,rings:6)}
        }
        for x:Float in [-31,8] {for z:Float in [-8.5,8.5] {
            cylinder(V(x,y,z),V(x,y+22,z),0.15,p.stainless,segments:12)
            for k in 0..<6 {cylinder(V(x,y+9+Float(k)*1.7,z),V(x+0.9,y+9+Float(k)*1.7,z),0.045,p.mast,segments:8)}
        }}
    }

    private func willisRoofEquipment(_ c:V,p:WillisPalette,large:Bool) {
        let scale:Float=large ? 1:0.72
        for i in 0..<3 {
            let q=c+V(-5+Float(i)*4.5,0.8,3)*scale
            box(q,V(3,1.6,3)*scale,p.edge)
            for k in 0..<13 {box(q+V(0,-0.58+Float(k)*0.095,1.51)*scale,V(2.8,0.035,0.08)*scale,p.aluminum)}
            cylinder(q+V(0,0.8,0)*scale,q+V(0,0.93,0)*scale,1.03*scale,p.gasket,segments:20)
            for k in 0..<9 {let a=Float(k) * .pi/9;beam(q+V(cos(a),0.95,sin(a))*scale,q+V(-cos(a),0.95,-sin(a))*scale,0.023,0.023,p.stainless)}
        }
        for x:Float in [-7,7] {
            cylinder(c+V(x,0.1,-4),c+V(x,2.2,-4),0.38,p.stainless,segments:12)
            cylinder(c+V(x,2.2,-4),c+V(x+1.1,2.2,-4),0.38,p.stainless,segments:12)
        }
    }

    private func willisDownlight(_ c:V,power:Float,range:Float,p:WillisPalette) {
        box(c+V(0,0.035,0),V(0.28,0.07,0.28),p.aluminum)
        box(c-V(0,0.008,0),V(0.22,0.015,0.22),p.warmLight)
        scene.lights.append(NightLighting.source(c-V(0,0.065,0),toward:c-V(0,3,0),power:power,color:V(1,0.78,0.49),range:range,radius:0.22,outerDegrees:78,innerDegrees:50))
    }

    private func willisGlassRail(_ a:V,_ b:V,p:WillisPalette) {
        let count=max(1,Int(simd_distance(a,b)/1.8)),d=(b-a)/Float(count)
        for i in 0..<count {
            let lo=a+d*Float(i),hi=lo+d
            quad(lo+V(0,0.14,0),hi+V(0,0.14,0),hi+V(0,1.16,0),lo+V(0,1.16,0),p.clear)
            cylinder(lo+V(0,0.06,0),lo+V(0,1.18,0),0.028,p.stainless,segments:8)
        }
        beam(a+V(0,0.09,0),b+V(0,0.09,0),0.11,0.12,p.aluminum)
        cylinder(a+V(0,1.18,0),b+V(0,1.18,0),0.035,p.stainless,segments:10)
    }

    private func willisGardenArc(_ c:V,radius:Float,p:WillisPalette) {
        let n=56
        for k in 0..<n {
            let a=Float(k) * .pi*1.8/Float(n)+0.1,b=Float(k+1) * .pi*1.8/Float(n)+0.1
            let u=V(cos(a),0,sin(a)),v=V(cos(b),0,sin(b))
            quad(c+u*(radius-1),c+v*(radius-1),c+v*(radius+0.4),c+u*(radius+0.4),p.stone)
            if k<35 {beam(c+u*(radius+0.8)+V(0,0.36,0),c+v*(radius+0.8)+V(0,0.36,0),0.65,0.38,p.stone)}
        }
    }

    private func willisPlanter(_ c:V,radius:Float,p:WillisPalette) {
        cylinder(c,c+V(0,0.42,0),radius,p.granite,segments:22)
        cylinder(c+V(0,0.43,0),c+V(0,0.45,0),radius-0.09,p.gasket,segments:22)
        for k in 0..<28 {
            let a=Float(k)*2.3999,r=sqrt(Float(k)/28)*(radius-0.13),q=c+V(cos(a)*r,0.45,sin(a)*r)
            let h:Float=0.25+rnd()*0.58
            for j in 0..<4 {let theta=a+Float(j)*1.4;let tip=q+V(cos(theta)*0.18,h,sin(theta)*0.18);tri(q-V(0.018,0,0),q+V(0.018,0,0),tip,p.vegetation)}
            if k%3==0 {ellipsoid(q+V(0,h,0),V(0.075,0.12,0.075),p.flower,segments:12,rings:6)}
        }
    }

    private func willisSmallTree(_ c:V,p:WillisPalette) {
        willisPlanter(c,radius:1.3,p:p)
        cylinder(c+V(0,0.4,0),c+V(0,4.8,0),0.10,bark,segments:10)
        for i in 0..<11 {
            let a=Float(i)*2.3999,q=c+V(cos(a)*1.1,3.2+Float(i%4)*0.45,sin(a)*1.1)
            cylinder(c+V(0,2.5,0),q,0.045,bark,segments:7)
            ellipsoid(q,V(1,1.0,0.85),i%3==0 ? leafLight:leaf,segments:12,rings:8)
        }
    }

    private func willisCafeTable(_ c:V,p:WillisPalette) {
        cylinder(c,c+V(0,0.69,0),0.06,p.aluminum,segments:10)
        cylinder(c+V(0,0.70,0),c+V(0,0.75,0),0.58,p.wood,segments:24)
        cylinder(c,c+V(0,0.05,0),0.32,p.aluminum,segments:12)
        for a:Float in [0,Float.pi*0.5,Float.pi,Float.pi*1.5] {
            let n=V(cos(a),0,sin(a)),t=V(-n.z,0,n.x),q=c+n*1.05
            for side:Float in [-1,1] {
                beam(q+t*side*0.20-n*0.19,q+t*side*0.20-n*0.19+V(0,0.45,0),0.032,0.032,p.aluminum)
                beam(q+t*side*0.20+n*0.19,q+t*side*0.20+n*0.19+V(0,0.86,0),0.032,0.032,p.aluminum)
            }
            orientedBox(q+V(0,0.46,0),t,V(0,1,0),n,V(0.49,0.035,0.45),p.wood)
            for j in 0..<4 {orientedBox(q+n*0.19+V(0,0.56+Float(j)*0.075,0),t,V(0,1,0),n,V(0.46,0.046,0.025),p.wood)}
        }
    }
}
