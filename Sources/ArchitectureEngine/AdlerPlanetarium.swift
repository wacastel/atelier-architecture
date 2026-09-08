import Foundation
import simd

/// Metre-scale anchors from the mapped historic core/dome. Interior circulation
/// follows the public visitor map; exhibits and seat placement are interpretive.
enum AdlerLayout {
    static let center = SIMD3<Float>(2413.718, 0, 1393.247)
    static let floor: Float = 2.8
    static let radius: Float = 24.384
    static let projectionRadius: Float = 10.5
    static let projectionCenter = center + SIMD3<Float>(0,4,0)
    static let entrance = center + SIMD3<Float>(-24,4.55,1.5)
    static let welcome = center + SIMD3<Float>(-16,4.55,-7)
    static let gallery = center + SIMD3<Float>(-4,4.55,-17)
    static let theaterDoor = center + SIMD3<Float>(-10,4.55,-5.5)
    static let theaterCenter = center + SIMD3<Float>(-1.5,4.55,0)
    static let theaterLook = center + SIMD3<Float>(7,8,0)
    static let showPeriod: Double = 180
}

private struct AdlerPalette {
    let granite, pale, dark, bronze, copper, copperSeam, glass, frame: UInt32
    let carpet, seat, wood, white, blue, screen, orange: UInt32
}

extension EiffelBuilder {
    func adlerPlanetarium() {
        func material(_ color: V, _ roughness: Float = 0.6, metallic: Float = 0,
                      emission: Float = 0, pattern: Float = 0, transmission: Float = 0) -> UInt32 {
            let id=UInt32(scene.materials.count)
            scene.materials.append(SceneMaterial(color,roughness:roughness,metallic:metallic,emission:emission,pattern:pattern,transmission:transmission))
            return id
        }
        let p=AdlerPalette(
            granite:material(V(0.16,0.095,0.075),0.46,pattern:18),
            pale:material(V(0.57,0.52,0.44),0.64,pattern:1),
            dark:material(V(0.022,0.025,0.036),0.88),
            bronze:material(V(0.22,0.17,0.075),0.38,metallic:0.75),
            copper:material(V(0.49,0.22,0.10),0.42,metallic:0.76,pattern:2),
            copperSeam:material(V(0.24,0.10,0.046),0.5,metallic:0.75),
            glass:material(V(0.965,0.98,0.985),0.075,transmission:1),
            frame:material(V(0.14,0.19,0.20),0.38,metallic:0.7),
            carpet:material(V(0.018,0.026,0.047),0.96),
            seat:material(V(0.055,0.10,0.17),0.83),
            wood:material(V(0.30,0.18,0.09),0.5,pattern:3),
            white:material(V(0.68,0.73,0.79),0.58),
            blue:material(V(0.18,0.48,0.95),0.6,emission:0.55),
            screen:material(V(0.008,0.012,0.027),0.98,pattern:17),
            orange:material(V(0.90,0.37,0.11),0.65))
        adlerCore(p)
        adlerTheater(p)
        adlerPavilion(p)
        adlerExhibits(p)
        adlerObservatory(p)
    }

    private func adlerPoint(_ x:Float,_ y:Float,_ z:Float) -> V { AdlerLayout.center+V(x,y,z) }
    private func adlerRadial(_ r:Float,_ angle:Float,_ y:Float) -> V {
        adlerPoint(r*cos(angle),y,r*sin(angle))
    }
    private func adlerRing(_ inner:Float,_ outer:Float,_ y:Float,_ m:UInt32,segments:Int=96) {
        for i in 0..<segments {
            let a=Float(i)*2*Float.pi/Float(segments),b=Float(i+1)*2*Float.pi/Float(segments)
            quad(adlerRadial(inner,a,y),adlerRadial(inner,b,y),adlerRadial(outer,b,y),adlerRadial(outer,a,y),m)
        }
    }
    private func adlerCore(_ p:AdlerPalette) {
        let f=AdlerLayout.floor
        // The 160ft dodecagon remains hollow. The west doors and north/south
        // pavilion passages are real openings, not reflective facade decals.
        for i in 0..<12 {
            let a=(Float(i)*30+15)*Float.pi/180,b=a+Float.pi/6
            let u=V(cos(a),0,sin(a)),v=V(cos(b),0,sin(b))
            let edge=(v-u)*AdlerLayout.radius,length=simd_length(edge),t=edge/length
            let midpoint=(u+v)*AdlerLayout.radius/2,n=simd_normalize(midpoint)
            let west=midpoint.x < -22,northSouth=abs(midpoint.z)>22
            func wall(_ along:Float,_ width:Float,_ y:Float,_ height:Float) {
                orientedBox(AdlerLayout.center+midpoint+t*along+V(0,y,0),t,V(0,1,0),n,V(width,height,0.72),p.granite)
            }
            wall(0,length,f/2,f)
            if west || northSouth {
                let opening:Float=west ? 6.0:5.0
                wall(-(length+opening)/4,(length-opening)/2,(f+9.5)/2,9.5-f)
                wall((length+opening)/4,(length-opening)/2,(f+9.5)/2,9.5-f)
                wall(0,opening,8.1,2.8)
                for s:Float in [-1,1] {
                    orientedBox(AdlerLayout.center+midpoint+t*s*(opening/2+0.04)+V(0,4.8,0),t,V(0,1,0),n,V(0.16,4.0,0.96),p.bronze)
                }
                if west {
                    // Two bronze-framed leaves held open beside a wide passage.
                    for z:Float in [-2.7,2.7] {
                        box(adlerPoint(-22.6,4.8,z),V(1.75,3.8,0.10),p.glass)
                        for x:Float in [-23.4,-21.8] {box(adlerPoint(x,4.8,z),V(0.09,3.9,0.13),p.bronze)}
                    }
                }
            } else {wall(0,length,(f+9.5)/2,9.5-f)}
            // Lower and receding upper rings, cornice fluting and corner plaques.
            for (radius,low,high) in [(Float(21.0),Float(9.5),Float(12.1)),(Float(14.4),Float(12.1),Float(15.4))] {
                let c=AdlerLayout.center+(u+v)*radius/2+V(0,(low+high)/2,0)
                orientedBox(c,t,V(0,1,0),n,V(simd_length(v-u)*radius,high-low,0.5),p.granite)
            }
            for h:Float in [f+0.25,9.1,9.38] {
                orientedBox(AdlerLayout.center+midpoint+V(0,h,0),t,V(0,1,0),n,V(length+0.08,0.13,0.96),p.pale)
            }
            for j in -4...4 {
                let q=AdlerLayout.center+midpoint+t*Float(j)*0.20+n*0.39
                beam(q+V(0,8.45,0),q+V(0,8.95,0),0.035,0.035,p.bronze)
            }
            let q=AdlerLayout.center+u*(AdlerLayout.radius-0.08)+V(0,7.5,0)
            orientedBox(q,t,V(0,1,0),n,V(0.9,1.2,0.09),p.bronze)
            // Original constellation-like relief geometry; no copied plaque artwork.
            for j in 0..<5 {
                let o=t*(Float(j)-2)*0.14+V(0,sin(Float(j)*1.9+Float(i))*0.27,0)
                cylinder(q+o+n*0.08,q+o+n*0.12,0.035,p.pale,segments:8)
                if j<4 {beam(q+o+n*0.09,q+t*(Float(j)-1)*0.14+V(0,sin(Float(j+1)*1.9+Float(i))*0.27,0)+n*0.09,0.018,0.018,p.pale)}
            }
        }
        adlerRing(0,24.3,f,p.pale)
        adlerRing(14.4,24.45,9.52,p.pale)
        adlerRing(13.25,21.1,12.12,p.pale)
        adlerRing(13.25,14.7,15.41,p.pale)
        // The replaced copper roof is warm copper in the architect's current
        // photo, with many standing seams and circumferential sheet joints.
        let radius:Float=13.3,base:Float=15.408
        for band in 0..<32 {for slice in 0..<128 {
            let aa=Float(slice)*2*Float.pi/128,bb=Float(slice+1)*2*Float.pi/128
            let la=Float(band)*Float.pi/64,lb=Float(band+1)*Float.pi/64
            func point(_ a:Float,_ l:Float)->V {adlerPoint(radius*cos(l)*cos(a),base+radius*sin(l),radius*cos(l)*sin(a))}
            let a=point(aa,la),b=point(bb,la),c=point(bb,lb),d=point(aa,lb)
            let center=adlerPoint(0,base,0)
            smoothTri(a,b,c,simd_normalize(a-center),simd_normalize(b-center),simd_normalize(c-center),p.copper)
            if band<31 {smoothTri(a,c,d,simd_normalize(a-center),simd_normalize(c-center),simd_normalize(d-center),p.copper)}
            if slice%4==0 {beam(a,d,0.025,0.038,p.copperSeam)}
            if band%3==0 {beam(a,b,0.027,0.027,p.copperSeam)}
        }}
        // Broad west entrance flight rises from street grade to the upper level.
        for i in 0..<14 {
            let h=Float(i+1)*0.2,x:Float = -34+Float(i)*0.65
            box(adlerPoint(x,h/2,0),V(0.66,h,15),p.pale)
        }
        box(adlerPoint(-24.25,f/2,0),V(2.3,f,15),p.pale)
        for z:Float in [-7.1,0,7.1] {
            beam(adlerPoint(-34,0.9,z),adlerPoint(-25,3.7,z),0.055,0.055,p.bronze)
            for x in stride(from:Float(-33.5),through:-25.0,by:2.1) {
                let y=(x+34)/9*2.8
                cylinder(adlerPoint(x,y,z),adlerPoint(x,y+0.9,z),0.024,p.bronze,segments:8)
            }
        }
        // The firsthand evening entrance reference shows white practical light
        // on the doors and stair treads, with a much darker upper copper dome.
        // Two interpreted entry downlights keep that circulation legible.
        let entryLens=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.91,0.96,1),roughness:0.5,emission:0.8))
        for side:Float in [-1,1] {
            let fixture=adlerPoint(-24.12,6.58,side*2.35)
            box(fixture,V(0.22,0.20,0.48),p.bronze)
            box(fixture+V(-0.12,-0.04,0),V(0.025,0.11,0.38),entryLens)
            scene.lights.append(NightLighting.source(fixture+V(-0.25,-0.16,0),toward:adlerPoint(-30,1.4,side*3.1),power:22,color:V(0.91,0.96,1),range:19,radius:0.24,outerDegrees:85,innerDegrees:50))
        }
        for i in 0..<12 {
            let a=(Float(i)*30+30)*Float.pi/180,position=adlerRadial(26,a,3.15)
            scene.lights.append(NightLighting.source(position,toward:adlerRadial(20,a,11),power:130,color:V(1,0.81,0.61),range:30,outerDegrees:84,innerDegrees:48))
        }
        for i in 0..<8 {
            let a=Float(i)*Float.pi/4
            scene.lights.append(NightLighting.source(adlerRadial(14.4,a,15.9),toward:adlerRadial(8,a,23),power:90,color:V(1,0.68,0.39),range:22,outerDegrees:87,innerDegrees:48))
            // Interpreted low-profile roof-terrace floods avoid the occluded
            // path from ground lamps through the receding stone roof tiers.
            // Upper copper remains naturally dark above the grazing-light arc.
            let fixture=adlerRadial(19.8,a,12.9)
            box(fixture,V(0.6,0.25,0.45),p.dark)
            beam(adlerRadial(19.8,a,12.14),fixture,0.055,0.055,p.bronze)
            scene.lights.append(NightLighting.source(adlerRadial(19.8,a,13.1),toward:adlerRadial(5,a,25),power:300,color:V(0.88,0.83,0.72),range:40,radius:0.65,outerDegrees:85,innerDegrees:50))
        }
    }

    private func adlerTheater(_ p:AdlerPalette) {
        let center=AdlerLayout.projectionCenter,r:Float=10.5
        let doorAngle:Float = -.pi+0.50
        for j in 0..<48 {for i in 0..<128 {
            let a=Float(i)*2*Float.pi/128,b=Float(i+1)*2*Float.pi/128
            let low:Float = -5.5*Float.pi/180
            let l=low+(Float.pi/2-low)*Float(j)/48,h=low+(Float.pi/2-low)*Float(j+1)/48
            let signed=atan2(sin((a+b)/2-doorAngle),cos((a+b)/2-doorAngle))
            if abs(signed)<0.17 && center.y+r*sin(l)<6.1 {continue}
            func point(_ angle:Float,_ latitude:Float)->V {center+V(r*cos(latitude)*cos(angle),r*sin(latitude),r*cos(latitude)*sin(angle))}
            let aa=point(a,l),bb=point(b,l),cc=point(b,h),dd=point(a,h)
            smoothTri(aa,cc,bb,simd_normalize(center-aa),simd_normalize(center-cc),simd_normalize(center-bb),p.screen)
            if j<47 {smoothTri(aa,dd,cc,simd_normalize(center-aa),simd_normalize(center-dd),simd_normalize(center-cc),p.screen)}
            // The opaque rear shell prevents the interior projection from
            // appearing on the outside of the theater in the welcome gallery.
            let ao=center+(aa-center)*1.006,bo=center+(bb-center)*1.006,co=center+(cc-center)*1.006,do_=center+(dd-center)*1.006
            smoothTri(ao,bo,co,simd_normalize(ao-center),simd_normalize(bo-center),simd_normalize(co-center),p.dark)
            if j<47 {smoothTri(ao,co,do_,simd_normalize(ao-center),simd_normalize(co-center),simd_normalize(do_-center),p.dark)}
        }}
        adlerRing(0,10.55,AdlerLayout.floor+0.015,p.carpet)
        // All-forward seating in three blocks; the main cross aisle and two
        // longitudinal aisles are kept clear for the walkthrough.
        for row in 0..<12 {
            let x=Float(row)*1.10-6.7
            for col in -9...9 {
                let z=Float(col)*0.69
                if abs(z)<1.05 || simd_length(V(x,0,z))>8.75 {continue}
                let c=adlerPoint(x,AdlerLayout.floor,z)
                box(c+V(0,0.45,0),V(0.57,0.17,0.58),p.seat)
                let recline=V(-0.22,0.975,0)
                orientedBox(c+V(-0.33,0.91,0),V(0.975,0.22,0),recline,V(0,0,1),V(0.16,0.92,0.58),p.seat)
                for side:Float in [-1,1] {
                    box(c+V(0,0.62,side*0.32),V(0.54,0.08,0.06),p.dark)
                    cylinder(c+V(-0.2,0.1,side*0.23),c+V(-0.2,0.50,side*0.23),0.023,p.frame,segments:8)
                }
                scene.detailCount += 1
            }
        }
        for a:Float in [-2.6,-1.3,0,1.3,2.6] {
            let q=adlerRadial(9.5,a,3.03)
            box(q,V(0.24,0.05,0.09),p.blue)
            scene.lights.append(NightLighting.source(q+V(0,0.16,0),toward:q+V(0,-0.2,0),power:0.8,color:V(0.25,0.45,1),range:4,alwaysOn:true))
        }
        // Low, broad housekeeping illumination keeps the aisle/seat silhouettes
        // readable while the emission from the original show supplies color.
        scene.lights.append(NightLighting.source(adlerPoint(0,6.0,0),toward:adlerPoint(0,2.8,0),power:1.5,color:V(0.25,0.34,0.6),range:12,alwaysOn:true))
    }

    private func adlerPavilion(_ p:AdlerPalette) {
        // Mapped crescent: east reach~52m, north/south~52m. Its triangular
        // section has an inclined glazed roof, radial ribs and low outer eaves.
        for i in 0..<84 {
            let a = -Float.pi/2+Float(i)*Float.pi/84,b = -Float.pi/2+Float(i+1)*Float.pi/84
            let inner:Float=25,outer:Float=51.5
            let ia=adlerRadial(inner,a,8.8),ib=adlerRadial(inner,b,8.8)
            let oa=adlerRadial(outer,a,3.8),ob=adlerRadial(outer,b,3.8)
            quad(adlerRadial(inner,a,2.8),adlerRadial(inner,b,2.8),adlerRadial(outer,b,2.8),adlerRadial(outer,a,2.8),p.pale)
            quad(ia,ib,ob,oa,p.glass)
            quad(oa,ob,adlerRadial(outer,b,2.8),adlerRadial(outer,a,2.8),p.glass)
            quad(adlerRadial(outer,a,0),adlerRadial(outer,b,0),adlerRadial(outer,b,2.8),adlerRadial(outer,a,2.8),p.granite)
            // Pane subdivisions and the exposed triangular frame rhythm.
            if i%2==0 {
                beam(ia,oa,0.11,0.16,p.frame)
                cylinder(ia,adlerRadial(inner,a,2.8),0.065,p.frame,segments:8)
                beam(oa,adlerRadial(outer,a,2.8),0.10,0.12,p.frame)
            }
            for t:Float in [0,0.25,0.5,0.75,1] {beam(simd_mix(ia,oa,V(repeating:t)),simd_mix(ib,ob,V(repeating:t)),0.055,0.085,p.frame)}
            if i%10==0 {
                let q=adlerRadial(30,(a+b)/2,7.5)
                scene.lights.append(NightLighting.source(q,toward:adlerRadial(34,(a+b)/2,2.8),power:25,color:V(0.8,0.88,1),range:16,alwaysOn:true))
            }
        }
        // North/south connection bays connect the historic museum ring to the
        // crescent rather than sealing it behind a solid primitive.
        for z:Float in [-1,1] {
            box(adlerPoint(0,2.7,z*25),V(8,0.2,8),p.pale)
            box(adlerPoint(0,7.1,z*25),V(8,0.2,8),p.white)
            for x:Float in [-4,4] {box(adlerPoint(x,4.9,z*25),V(0.2,4.3,8),p.glass)}
        }
    }

    private func adlerExhibits(_ p:AdlerPalette) {
        // Welcome gallery: a restrained series of freestanding curved ribs,
        // inspired by the reference's portal without copying its installations.
        for i in 0..<7 {
            let angle = -Float.pi+0.25+Float(i)*0.10
            for j in 0..<18 {
                let a=Float(j)*Float.pi/18,b=Float(j+1)*Float.pi/18
                let c=adlerRadial(16,angle,2.8),t=V(cos(angle),0,sin(angle))
                beam(c+t*(cos(a)*2.3)+V(0,sin(a)*3.6,0),c+t*(cos(b)*2.3)+V(0,sin(b)*3.6,0),0.075,0.11,p.white)
            }
        }
        // Actual geometric instruments, orbit models and exhibit furniture in
        // the ring gallery. None of the historic museum's show assets are used.
        for (i,a) in [Float(-1.65),-1.12,0.6,1.18,1.70,2.15].enumerated() {
            let q=adlerRadial(18.3,a,2.8),t=V(-sin(a),0,cos(a)),n=V(cos(a),0,sin(a))
            orientedBox(q+V(0,0.47,0),t,V(0,1,0),n,V(2.9,0.94,1.15),p.dark)
            orientedBox(q+V(0,1.0,0),t,V(0,0.94,-0.34),n,V(2.7,0.13,0.90),p.blue)
            if i%2==0 {
                for j in 0..<48 {
                    let aa=Float(j)*2*Float.pi/48,bb=Float(j+1)*2*Float.pi/48
                    beam(q+V(cos(aa)*0.85,2.0,sin(aa)*0.85),q+V(cos(bb)*0.85,2.0,sin(bb)*0.85),0.025,0.025,p.bronze)
                }
                cylinder(q+V(0,1,0),q+V(0,2,0),0.025,p.bronze,segments:8)
                adlerBall(q+V(0,2,0),V(0.34,0.34,0.34),p.orange)
                adlerBall(q+V(0.83,2,0),V(0.12,0.12,0.12),p.blue)
            } else {
                let c=q+V(0,2.0,0)
                cylinder(c-n*0.9+V(0,0.2,0),c+n*0.7-V(0,0.2,0),0.19,p.bronze,segments:24)
                for s:Float in [-1,1] {beam(c,q+t*s*0.6+n*0.35,0.035,0.035,p.frame)}
                beam(c,q-n*0.60,0.035,0.035,p.frame)
            }
            scene.lights.append(NightLighting.source(q+V(0,4.0,0),toward:q+V(0,1.1,0),power:20,color:V(0.84,0.91,1),range:7,alwaysOn:true))
        }
        for i in 0..<12 {
            let a=Float(i)*Float.pi/6
            let q=adlerRadial(16,a,8.5)
            scene.lights.append(NightLighting.source(q,toward:adlerRadial(17,a,3),power:30,color:V(0.79,0.85,1),range:12,alwaysOn:true))
        }
    }
    private func adlerBall(_ center:V,_ size:V,_ m:UInt32) {
        for j in 0..<12 {for i in 0..<24 {
            func point(_ k:Int,_ l:Int)->V {
                let a=Float(k)*2*Float.pi/24,b = -Float.pi/2+Float(l)*Float.pi/12
                return center+V(cos(b)*cos(a),sin(b),cos(b)*sin(a))*size
            }
            let a=point(i,j),b=point(i+1,j),c=point(i+1,j+1),d=point(i,j+1)
            if j>0 {tri(a,b,c,m)};if j<11 {tri(a,c,d,m)}
        }}
    }
    private func adlerObservatory(_ p:AdlerPalette) {
        let c=V(2487.072,0,1391.801)
        cylinder(c,c+V(0,4.4,0),6.35,p.pale,segments:64)
        adlerBall(c+V(0,4.4,0),V(6.5,5.6,6.5),p.white)
        // Telescope slit follows the outer shell as a clearly modeled dark band.
        for j in 0..<24 {
            let a=Float(j)*Float.pi/48,b=Float(j+1)*Float.pi/48
            let aa=c+V(6.51*cos(a),4.4+5.62*sin(a),0),bb=c+V(6.51*cos(b),4.4+5.62*sin(b),0)
            beam(aa,bb,0.55,0.08,p.dark)
        }
        scene.detailCount += 1
    }
}
