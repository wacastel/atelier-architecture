import Foundation
import simd

/// Architectural interpretation of the current stadium inside its mapped historic shell.
enum SoldierFieldLayout {
    static let center=SIMD3<Float>(1590,0,1838)
    static func point(_ p:SIMD3<Float>)->SIMD3<Float> {
        let angle:Float = -0.025
        return center+SIMD3(p.x*cos(angle)-p.z*sin(angle),p.y,p.x*sin(angle)+p.z*cos(angle))
    }
    static let field=point(SIMD3(0,0.43,10))
    static let westPortico=point(SIMD3(-96,2.1,-112))
    static let northGate=point(SIMD3(0,2.1,-159))
    static let fieldCamera=point(SIMD3(0,2.3,-39))
}

extension EiffelBuilder {
    func soldierField() {
        let limestone=riverMaterial(V(0.66,0.63,0.55),roughness:0.68,pattern:10)
        let trim=riverMaterial(V(0.79,0.77,0.69),roughness:0.56,pattern:10)
        let shadowStone=riverMaterial(V(0.38,0.39,0.36),roughness:0.77)
        let aluminum=riverMaterial(V(0.47,0.52,0.54),roughness:0.32,metallic:0.75)
        let steel=riverMaterial(V(0.16,0.20,0.22),roughness:0.38,metallic:0.72)
        let glass=riverMaterial(V(0.10,0.16,0.20),roughness:0.13,metallic:0.68,emission:0.07,pattern:14)
        let navy=riverMaterial(V(0.021,0.047,0.075),roughness:0.48)
        let orange=riverMaterial(V(0.70,0.16,0.025),roughness:0.66)
        let turf=riverMaterial(V(0.075,0.23,0.047),roughness:0.91,pattern:4)
        let turfDark=riverMaterial(V(0.064,0.195,0.038),roughness:0.91,pattern:4)
        let white=riverMaterial(V(0.85,0.86,0.78),roughness:0.74)
        let black=riverMaterial(V(0.018,0.025,0.027),roughness:0.25)
        let lamp=riverMaterial(V(0.90,0.93,0.91),roughness:0.3,emission:0.19,pattern:14)
        func pt(_ p:V)->V{SoldierFieldLayout.point(p)}
        let xaxis=simd_normalize(pt(V(1,0,0))-pt(.zero)),zaxis=simd_normalize(pt(V(0,0,1))-pt(.zero))
        func block(_ c:V,_ size:V,_ material:UInt32){orientedBox(pt(c),xaxis,V(0,1,0),zaxis,size,material)}
        func panel(_ a:V,_ b:V,_ c:V,_ d:V,_ material:UInt32){quad(pt(a),pt(b),pt(c),pt(d),material)}
        // Broad historic plinth, perforated long porticos, stepped entablature.
        for side:Float in [-1,1] {
            block(V(side*96,0.42,-22),V(18,0.84,269),limestone)
            for level in 0..<4 {
                block(V(side*96,0.08+Float(level)*0.105,-22),V(20-Float(level)*0.65,0.11,272-Float(level)*0.65),trim)
            }
            for z in stride(from:Float(-158),through:Float(112),by:6.0) {
                for x:Float in [side*89.5,side*102.5] {
                    block(V(x,0.89,z),V(2.2,0.30,2.2),trim)
                    // Doric shaft with shallow geometric flutes and a modest taper.
                    let rings=16
                    for k in 0..<rings {
                        let a0=Float(k)*2*Float.pi/Float(rings),a1=Float(k+1)*2*Float.pi/Float(rings)
                        let r0:Float=k%2==0 ? 0.78:0.74,r1:Float=(k+1)%2==0 ? 0.78:0.74
                        panel(V(x+cos(a0)*r0,1.04,z+sin(a0)*r0),V(x+cos(a1)*r1,1.04,z+sin(a1)*r1),V(x+cos(a1)*r1*0.84,11.8,z+sin(a1)*r1*0.84),V(x+cos(a0)*r0*0.84,11.8,z+sin(a0)*r0*0.84),limestone)
                    }
                    cylinder(pt(V(x,11.8,z)),pt(V(x,12.16,z)),0.91,trim,segments:16)
                    block(V(x,12.38,z),V(2.2,0.42,2.2),trim)
                }
            }
            for (y,width,height) in [(Float(12.8),Float(16.9),Float(0.65)),(13.52,18.1,0.72),(14.08,19.0,0.35),(14.53,17.5,0.6)] {
                block(V(side*96,y,-22),V(width,height,277),trim)
            }
            // Open walkway remains between the column rows at x=±96.
            for z in stride(from:Float(-150),to:112,by:18) {
                block(V(side*96,13.04,z),V(3.0,0.10,0.75),lamp)
                scene.lights.append(NightLighting.source(pt(V(side*96,12.95,z)),toward:pt(V(side*96,0,z)),power:16,color:V(1,0.83,0.64),range:23,radius:0.7,outerDegrees:78,innerDegrees:48))
            }
        }
        // Retained south wall follows a flattened horseshoe, with repeated gates.
        for i in 0..<44 {
            let a=Float(i)/44*Float.pi,b=Float(i+1)/44*Float.pi
            let q=V(cos(a)*103,0,116+sin(a)*38),r=V(cos(b)*103,0,116+sin(b)*38)
            let middle=(q+r)/2,t=simd_normalize(r-q),n=V(-t.z,0,t.x)
            orientedBox(pt(middle+V(0,5.0,0)),xaxis*t.x+zaxis*t.z,V(0,1,0),xaxis*n.x+zaxis*n.z,V(simd_distance(q,r)+0.02,10.0,3.0),limestone)
            beam(pt(q+V(0,10.2,0)),pt(r+V(0,10.2,0)),1.1,3.9,trim)
            if i%3==0 {block(middle+V(0,3.2,-1.6),V(2.7,5.7,0.1),shadowStone)}
        }
        for side:Float in [-1,1] {
            block(V(side*69,5.5,-164),V(37,11,4),limestone)
            block(V(side*69,11.3,-164),V(39,0.7,5),trim)
            block(V(side*70,4.2,-166.1),V(12,7,0.1),shadowStone)
        }
        // Current NFL field: regulation 120 by 53 1/3 yards, including end zones.
        block(V(0,0.23,10),V(58,0.38,117),turf)
        for yard in 0..<12 {
            block(V(0,0.425,10-54.864+(Float(yard)+0.5)*9.144),V(48.768,0.025,9.144),yard%2==0 ? turf:turfDark)
        }
        for side:Float in [-1,1] {
            block(V(side*24.384,0.451,10),V(0.16,0.016,109.728),white)
            block(V(0,0.451,10+side*54.864),V(48.9,0.016,0.16),white)
            block(V(0,0.446,10+side*50.292),V(48.64,0.018,9.0),navy)
        }
        for line in 0...20 {
            let z=10-Float(50)*0.9144+Float(line)*4.572
            block(V(0,0.455,z),V(48.7,0.018,0.13),white)
        }
        for yard in 1..<100 {
            let z=10-45.72+Float(yard)*0.9144
            for x:Float in [-23.7,-2.82,2.82,23.7] {block(V(x,0.46,z),V(0.68,0.018,0.10),white)}
        }
        // Original abstract midfield mark, avoiding a licensed team-logo texture.
        for i in 0..<40 {
            let a=Float(i)/40*2*Float.pi,b=Float(i+1)/40*2*Float.pi
            panel(V(cos(a)*4.5,0.47,10+sin(a)*3),V(cos(a)*3.7,0.47,10+sin(a)*2.3),V(cos(b)*3.7,0.47,10+sin(b)*2.3),V(cos(b)*4.5,0.47,10+sin(b)*3),orange)
        }
        for side:Float in [-1,1] {
            let z=10+side*57.8
            cylinder(pt(V(0,0.5,z)),pt(V(0,3.55,z)),0.12,orange,segments:10)
            beam(pt(V(0,3.55,z)),pt(V(0,3.55,z-side*2.8)),0.14,0.14,orange)
            beam(pt(V(-2.8194,3.55,z-side*2.8)),pt(V(2.8194,3.55,z-side*2.8)),0.14,0.14,orange)
            for x:Float in [-2.8194,2.8194] {cylinder(pt(V(x,3.55,z-side*2.8)),pt(V(x,10.2,z-side*2.8)),0.075,orange,segments:8)}
        }
        // Lower continuous bowl, with radial aisle gaps and discrete seat backs.
        func ellipse(_ angle:Float,_ rx:Float,_ rz:Float,_ y:Float)->V {
            // Superellipse keeps the long stands straighter and the end curves broad.
            let c=cos(angle),s=sin(angle)
            return V(c>=0 ? pow(c,0.72)*rx : -pow(-c,0.72)*rx,y,10+(s>=0 ? pow(s,0.80)*rz : -pow(-s,0.80)*rz))
        }
        func seating(rows:Int,innerX:Float,innerZ:Float,y0:Float,rise:Float,startRow:Int,upper:Bool) {
            let sectors=128
            for row in 0..<rows {
                let f=Float(row),rx=innerX+f*0.78,rz=innerZ+f*0.80,y=y0+f*rise
                for sector in 0..<sectors {
                    let a=Float(sector)*2*Float.pi/Float(sectors),b=Float(sector+1)*2*Float.pi/Float(sectors)
                    // Tall steep western grandstand and lower east/south banks;
                    // upper north remains open as in the contemporary aerial.
                    if upper && (sin(a)<(-0.78) || (cos(a)>0.4 && row>19) || (sin(a)>0.8 && row>24)){continue}
                    let aa=ellipse(a,rx,rz,y),bb=ellipse(b,rx,rz,y),cc=ellipse(b,rx+0.80,rz+0.82,y),dd=ellipse(a,rx+0.80,rz+0.82,y)
                    panel(aa,bb,cc,dd,shadowStone)
                    panel(dd,cc,cc+V(0,rise,0),dd+V(0,rise,0),shadowStone)
                    if sector%8==0 {
                        panel(aa+V(0,0.015,0),bb+V(0,0.015,0),cc+V(0,0.015,0),dd+V(0,0.015,0),trim)
                        continue
                    }
                    let span=simd_distance(aa,bb),count=max(1,Int(span/0.77)),t=simd_normalize(bb-aa),n=V(t.z,0,-t.x)
                    for seat in 0..<count {
                        let c=simd_mix(aa,bb,V(repeating:(Float(seat)+0.5)/Float(count)))+n*0.34
                        orientedBox(pt(c+V(0,0.32,0)),xaxis*t.x+zaxis*t.z,V(0,1,0),xaxis*n.x+zaxis*n.z,V(0.57,0.075,0.45),navy)
                        orientedBox(pt(c+n*0.21+V(0,0.58,0)),xaxis*t.x+zaxis*t.z,V(0,1,0),xaxis*n.x+zaxis*n.z,V(0.57,0.44,0.065),navy)
                    }
                    if row==rows-1 && sector%2==0 {
                        beam(pt(dd+V(0,0.9,0)),pt(cc+V(0,0.9,0)),0.055,0.055,steel)
                        beam(pt(dd),pt(dd+V(0,0.9,0)),0.055,0.055,steel)
                    }
                }
            }
        }
        seating(rows:27,innerX:32,innerZ:66,y0:1.4,rise:0.54,startRow:0,upper:false)
        seating(rows:34,innerX:57,innerZ:91,y0:21,rise:0.96,startRow:27,upper:true)
        // Exposed understructure follows the banks instead of a solid oval plug.
        for i in 0..<72 {
            let a=Float(i)/72*2*Float.pi
            if sin(a)<(-0.77){continue}
            let east=cos(a)>0.4,south=sin(a)>0.8
            let rows:Float=east ? 19:south ? 24:33
            let end=ellipse(a,57+rows*0.78,91+rows*0.8,21+rows*0.96)
            let base=ellipse(a,70,106,0.9)
            beam(pt(base),pt(end),1.6,2.5,aluminum)
            beam(pt(base),pt(ellipse(a,57,91,20.5)),1.0,1.8,steel)
        }
        // Silver glass crescent of the east club/suite facade, finely layered.
        for i in 0..<48 {
            let a = -Float.pi*0.47+Float(i)*Float.pi*0.94/48,b = -Float.pi*0.47+Float(i+1)*Float.pi*0.94/48
            let aa=ellipse(a,85,121,18),bb=ellipse(b,85,121,18)
            panel(aa,bb,bb+V(0,24,0),aa+V(0,24,0),glass)
            for level in 0...12 {
                beam(pt(aa+V(0,Float(level)*2,0)),pt(bb+V(0,Float(level)*2,0)),0.24,0.34,aluminum)
            }
            beam(pt(aa),pt(aa+V(0,24,0)),0.16,0.26,aluminum)
        }
        // Open north and south scoreboards, with restrained architectural light.
        for side:Float in [-1,1] {
            let z=10+side*119
            block(V(0,30,z),V(35,12,1.3),steel)
            block(V(0,30,z-side*0.68),V(33.2,10.5,0.08),black)
            block(V(0,29,z-side*0.74),V(21,0.24,0.04),orange)
            for x:Float in [-13,13] {block(V(x,18,z),V(1.1,20,1.2),steel)}
        }
        for side:Float in [-1,1] {for z in stride(from:Float(-92),through:94,by:31) {
            let c=V(side*78,side<0 ? 58:48,z)
            cylinder(pt(c-V(0,6,0)),pt(c),0.18,steel,segments:8)
            block(c,V(3.4,0.72,0.7),steel)
            for x in -2...2 {block(c+V(Float(x)*0.58,-0.05,side<0 ? 0.38:-0.38),V(0.46,0.42,0.055),lamp)}
            scene.lights.append(NightLighting.source(pt(c),toward:pt(V(side*8,0.5,z*0.4)),power:480,color:V(0.91,0.95,1),range:155,radius:2.4,outerDegrees:49,innerDegrees:29))
        }}
    }
}
