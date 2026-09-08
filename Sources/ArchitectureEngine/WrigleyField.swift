import Foundation
import simd

/// Mapped architectural reconstruction, not a seat or building survey.
enum WrigleyFieldLayout {
    typealias V=SIMD3<Float>
    static let homePlate=V(-1650.3,0.12,-7685.1)
    static let angle:Float=0.689405 // Diamond points ~39.5° east of north.
    static let baseDistance:Float=27.432
    static let pitchingDistance:Float=18.4404
    static let scoreboardSize=SIMD2<Float>(22.86,8.2296)
    static func point(_ p:V)->V {
        homePlate+V(p.x*cos(angle)-p.z*sin(angle),p.y,p.x*sin(angle)+p.z*cos(angle))
    }
    static func local(_ p:V)->V {
        let d=p-homePlate
        return V(d.x*cos(angle)+d.z*sin(angle),d.y,-d.x*sin(angle)+d.z*cos(angle))
    }
    static let center=V(-1626,0,-7717.6)
    static let marquee=point(V(0,9.3,68.8))
    static let marqueeCamera=point(V(0,1.8,88))
    static let fieldCamera=point(V(8,1.8,-9))
    static let ivyCamera=V(-1584,1.92,-7774)
    static let gallagherCamera=V(-1744,1.92,-7679)
    // Interpretive field-access passage. This is not a claim of public field access.
    static let entranceRoute:[V]=[V(0,1.8,81),V(0,1.8,69),V(0,1.8,52),V(0,1.8,31),V(0,1.8,12),V(8,1.8,-9),V(14,1.8,-46)].map(point)
}

private struct WrigleyPalette {
    var brick,cream,concrete,steel,seat,roof,glass,grass,dirt,ivy,ivyLight,red,white,black,blue,lamp,letter:UInt32
}

extension EiffelBuilder {
    func wrigleyField() {
        func mat(_ c:V,_ roughness:Float=0.65,_ metallic:Float=0,_ emission:Float=0,_ pattern:Float=0)->UInt32 {
            let i=UInt32(scene.materials.count)
            scene.materials.append(SceneMaterial(c,roughness:roughness,metallic:metallic,emission:emission,pattern:pattern));return i
        }
        let p=WrigleyPalette(brick:mat(V(0.34,0.135,0.074),0.85,0,0,19),cream:mat(V(0.73,0.69,0.56),0.64),concrete:mat(V(0.40,0.43,0.39),0.78),steel:mat(V(0.035,0.095,0.067),0.39,0.55),seat:mat(V(0.046,0.15,0.089),0.45),roof:mat(V(0.23,0.26,0.25),0.51,0.38),glass:mat(V(0.13,0.19,0.18),0.13,0.55,0.035,14),grass:mat(V(0.065,0.205,0.036),0.94,0,0,4),dirt:mat(V(0.39,0.205,0.13),0.96),ivy:mat(V(0.029,0.102,0.026),0.83),ivyLight:mat(V(0.066,0.17,0.036),0.82),red:mat(V(0.63,0.018,0.022),0.34,0.32,0.16,16),white:mat(V(0.84,0.84,0.74),0.67),black:mat(V(0.008,0.013,0.012),0.63),blue:mat(V(0.014,0.045,0.24),0.52,0.1,0.06,16),lamp:mat(V(0.87,0.94,1),0.22,0,0.95,16),letter:mat(V(1,0.81,0.54),0.4,0,0.8,16))
        wfPlayingField(p)
        wfGrandstands(p)
        wfOutfield(p)
        wfMarquee(p)
        wfGallagherWay(p)
    }

    private func wfBlock(_ c:V,_ size:V,_ m:UInt32) {
        let a=WrigleyFieldLayout.angle
        orientedBox(WrigleyFieldLayout.point(c),V(cos(a),0,sin(a)),V(0,1,0),V(-sin(a),0,cos(a)),size,m)
    }
    private func wfPanel(_ a:V,_ b:V,_ c:V,_ d:V,_ m:UInt32) {
        quad(WrigleyFieldLayout.point(a),WrigleyFieldLayout.point(b),WrigleyFieldLayout.point(c),WrigleyFieldLayout.point(d),m)
    }
    private func wfMappedSurface(_ record:WrigleyMappedShape,_ y:Float,_ m:UInt32) {
        for i in stride(from:0,to:record.triangles.count,by:3) {
            let a=record.points[record.triangles[i]],b=record.points[record.triangles[i+1]],c=record.points[record.triangles[i+2]]
            let aa=V(a.x,y,a.y),bb=V(b.x,y,b.y),cc=V(c.x,y,c.y)
            if simd_cross(bb-aa,cc-aa).y>0 {tri(aa,bb,cc,m)}else{tri(aa,cc,bb,m)}
        }
    }

    private func wfOutfield(_ p:WrigleyPalette) {
        let ring=WrigleyMap.pitch.ring
        // The map preserves the bent, nearly rectangular outfield and rounded center-field corner.
        let start=ring.firstIndex{abs($0.x+1544.704)<0.02 && abs($0.y+7698.390)<0.02}!
        let finish=ring.firstIndex{abs($0.x+1663.212)<0.02 && abs($0.y+7793.213)<0.02}!
        func point(_ q:SIMD2<Float>,_ y:Float)->V {V(q.x,y,q.y)}
        for i in start..<finish {
            let a=point(ring[i],0.12),b=point(ring[i+1],0.12),length=simd_distance(a,b),t=simd_normalize(b-a)
            let n=simd_normalize(V(WrigleyFieldLayout.homePlate.x-(a.x+b.x)*0.5,0,WrigleyFieldLayout.homePlate.z-(a.z+b.z)*0.5))
            let height:Float=(i==start || i==finish-1) ? 4.572:3.5052
            orientedBox((a+b)/2+V(0,height/2,0),t,V(0,1,0),V(-t.z,0,t.x),V(length+0.035,height,0.42),p.brick)
            beam(a+V(0,height+0.04,0),b+V(0,height+0.04,0),0.18,0.50,p.steel)
            // Individually folded ivy leaves remain geometry in close ray-traced views.
            let columns=max(1,Int(length/0.20))
            for x in 0..<columns {for y in 0..<15 {
                let seed=Float((x*17+y*31+i*43)%101)/101
                let q=a+(b-a)*(Float(x)+0.35+seed*0.4)/Float(columns)+V(0,0.18+Float(y)*0.222+seed*0.1,0)+n*(0.26+seed*0.10)
                let width:Float=0.09+seed*0.057,up=V(0,0.145+seed*0.025,0),out=n*0.035
                tri(q-t*width,q+up+out,q+t*width,y%4==0 ? p.ivyLight:p.ivy)
                tri(q-t*width,q+t*width,q-up*0.78+out,y%4==0 ? p.ivyLight:p.ivy)
            }}
            // The projecting safety basket is represented by fine frame wires.
            let count=max(1,Int(length/1.15))
            beam(a+n*0.62+V(0,height+0.02,0),b+n*0.62+V(0,height+0.02,0),0.025,0.025,p.steel)
            for k in 0...count {
                let q=a+(b-a)*Float(k)/Float(count)+V(0,height,0)
                beam(q,q+n*0.62+V(0,-0.25,0),0.018,0.018,p.steel)
            }
            for row in 0..<15 {
                let y=height+0.45+Float(row)*0.36,r0=0.6+Float(row)*0.80,r1=r0+0.80
                let aa=a-n*r0+V(0,y,0),bb=b-n*r0+V(0,y,0),cc=b-n*r1+V(0,y,0),dd=a-n*r1+V(0,y,0)
                quad(aa,dd,cc,bb,p.concrete)
                quad(aa,bb,bb-V(0,0.36,0),aa-V(0,0.36,0),p.concrete)
                let sections=max(1,Int(length/7.5))
                for k in 0..<sections {
                    let q=(aa+bb)/2+t*((Float(k)+0.5)/Float(sections)-0.5)*length-n*0.39+V(0,0.43,0)
                    orientedBox(q,t,V(0,1,0),V(-t.z,0,t.x),V(length/Float(sections)-0.68,0.075,0.43),p.seat)
                }
                if row==14 {beam(dd+V(0,1.0,0),cc+V(0,1.0,0),0.045,0.045,p.steel)}
            }
        }
        // Yellow foul poles anchor the two very different corner geometries.
        let yellow=UInt32(scene.materials.count);scene.materials.append(SceneMaterial(V(0.92,0.57,0.018),roughness:0.46,metallic:0.30))
        for index in [start,finish] {
            let q=point(ring[index],0.12)
            cylinder(q,q+V(0,16.8,0),0.105,yellow,segments:10)
            for y in stride(from:Float(5),through:16.5,by:1.2) {beam(q+V(0,y,0),q+V(0.65,y,0),0.025,0.025,yellow)}
            beam(q+V(0.65,5,0),q+V(0.65,16.7,0),0.028,0.028,yellow)
        }
        wfScoreboard(p)
        // Two contemporary screens are present, with original architectural-demo content.
        // These are emissive LED faces, separate from the painted blue flags and trims.
        let screenFace=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.025,0.075,0.23),roughness:0.48,emission:0.72,pattern:16))
        let screenLetters=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.86,0.89,0.92),roughness:0.55,emission:0.80,pattern:16))
        for (c,width,height,n): (V,Float,Float,V) in [(V(-1606.9,18.6,-7802),29.4,15.0,V(0,0,1)),(V(-1536.5,17.8,-7711.5),21.0,11.7,V(-1,0,0))] {
            let t=V(n.z,0,-n.x)
            orientedBox(c,t,V(0,1,0),n,V(width+0.8,height+0.8,0.75),p.steel)
            quad(c-t*width/2-V(0,height/2,0)+n*0.39,c+t*width/2-V(0,height/2,0)+n*0.39,c+t*width/2+V(0,height/2,0)+n*0.39,c-t*width/2+V(0,height/2,0)+n*0.39,screenFace)
            wfLabel("WRIGLEY",c+n*0.41+V(0,1.1,0),right:t,up:V(0,1,0),height:2.0,material:screenLetters)
            wfLabel("FIELD",c+n*0.41-V(0,1.7,0),right:t,up:V(0,1,0),height:1.4,material:screenLetters)
            for side:Float in [-1,1] {beam(c+t*side*width*0.4-V(0,height/2,0),c+t*side*width*0.4-V(0,height/2+6,0),0.38,0.45,p.steel)}
            scene.lights.append(NightLighting.source(c+n*1.8-V(0,height*0.28,0),toward:c+n*8-V(0,height*0.6,0),power:35,color:V(0.72,0.85,1),range:26,radius:1.6,outerDegrees:64,innerDegrees:40))
        }
    }

    private func wfScoreboard(_ p:WrigleyPalette) {
        let c=V(-1550.2,18.0,-7791.2),n=simd_normalize(V(-100,0,106)),t=V(n.z,0,-n.x),up=V(0,1,0)
        let w=WrigleyFieldLayout.scoreboardSize.x,h=WrigleyFieldLayout.scoreboardSize.y
        orientedBox(c,t,up,n,V(w,h,1.7),p.steel)
        let face=c+n*0.866
        for row in 0..<12 {
            let y=3.05-Float(row)*0.49
            for x in 0..<20 {
                let q=face+t*(-10.6+Float(x)*1.09)+up*y
                orientedBox(q,t,up,n,V(0.96,0.41,0.025),p.black)
                // Blank/off-season rows use the manual-board typography without inventing a live game.
                if x>4 && row%3==0 {wfLabel("0",q+n*0.02,right:t,up:up,height:0.29,material:p.white)}
            }
        }
        wfLabel("NATIONAL",face-t*6.8+up*3.77,right:t,up:up,height:0.32,material:p.white)
        wfLabel("AMERICAN",face+t*6.4+up*3.77,right:t,up:up,height:0.32,material:p.white)
        for side:Float in [-1,1] {for j in 0..<3 {
            wfLabel(j==0 ? "CHICAGO":"BASEBALL",face+t*side*6.5+up*(2.55-Float(j)*1.47),right:t,up:up,height:0.23,material:p.white)
        }}
        // Round analogue clock and open supporting steelwork.
        let clock=c+up*5.4+n*0.12
        cylinder(clock-n*0.25,clock+n*0.25,1.48,p.steel,segments:40)
        cylinder(clock+n*0.26,clock+n*0.29,1.30,p.cream,segments:40)
        for i in 0..<12 {
            let a=Float(i)*2*Float.pi/12,q=clock+t*cos(a)*1.10+up*sin(a)*1.10+n*0.31
            beam(q,q+(t*cos(a)+up*sin(a))*0.13,0.055,0.05,p.black)
        }
        beam(clock+n*0.33,clock+n*0.33+t*0.65+up*0.44,0.09,0.06,p.black)
        beam(clock+n*0.34,clock+n*0.34-up*0.93,0.07,0.055,p.black)
        for side:Float in [-1,1] {
            let q=c+t*side*8.7
            beam(q-up*4.1,q-up*11.2,0.25,0.3,p.steel)
            beam(q-up*4.4,q-t*side*17.4-up*10.5,0.13,0.17,p.steel)
        }
        for x:Float in [-10.5,-7,-3.5,0,3.5,7,10.5] {
            let q=c+t*x+up*4.1
            cylinder(q,q+up*4.8,0.031,p.cream,segments:6)
            if abs(x)>0.1 {quad(q+up*4.5,q+t*1.15+up*4.4+n*0.09,q+t*1.10+up*3.72,q+up*3.78,p.blue)}
        }
        let flag=c+up*8.7
        quad(flag-t*0.05,flag+t*2.5+up*0.12,flag+t*2.45-up*1.4,flag-t*0.05-up*1.45,p.white)
        wfLabel("W",flag+t*1.2-up*0.69+n*0.025,right:t,up:up,height:0.92,material:p.blue)
        for x:Float in [-8,-3,3,8] {
            scene.lights.append(NightLighting.source(c+t*x+up*4.9+n*4.8,toward:c+t*x,power:95,color:V(1,0.94,0.83),range:18,radius:0.90,outerDegrees:58,innerDegrees:38))
        }
    }

    private func wfMarquee(_ p:WrigleyPalette) {
        let center=V(0,9.5,69.2)
        // Cascading shoulders recreate the three-part red Art Deco sign silhouette.
        for (width,height,y): (Float,Float,Float) in [(17.8,4.8,0),(20.5,0.46,-2.25),(22.3,0.22,-2.65)] {
            wfBlock(center+V(0,y,0),V(width,height,0.55),p.red)
            for side:Float in [-1,1] {
                wfBlock(center+V(side*(width/2-0.15),y,0.31),V(0.065,height,0.06),p.letter)
            }
        }
        wfBlock(center+V(0,-4.05,0),V(20.5,2.5,0.42),p.black)
        let a=WrigleyFieldLayout.angle,t=V(cos(a),0,sin(a)),up=V(0,1,0)
        func sign(_ text:String,_ y:Float,_ h:Float,_ m:UInt32) {wfLabel(text,WrigleyFieldLayout.point(center+V(0,y,0.33)),right:t,up:up,height:h,material:m)}
        sign("WRIGLEY FIELD",1.40,1.20,p.letter)
        sign("HOME OF",0.04,0.60,p.letter)
        sign("CHICAGO CUBS",-1.22,1.12,p.letter)
        sign("THE FRIENDLY CONFINES",-3.42,0.48,p.white)
        sign("ARCHITECTURAL WALKTHROUGH",-4.24,0.34,p.white)
        for side:Float in [-1,1] {
            wfBlock(V(side*7.4,1.9,67.8),V(3.0,3.8,0.22),p.steel)
            for i in 0..<12 {wfBlock(V(side*7.4+(Float(i)-5.5)*0.23,1.9,68.0),V(0.035,3.8,0.04),p.cream)}
            for z:Float in [61,67] {
                scene.lights.append(NightLighting.source(WrigleyFieldLayout.point(V(side*10,13.1,z+3)),toward:WrigleyFieldLayout.point(V(side*10,8,z)),power:40,color:side<0 ? V(0.16,0.28,1):V(1,0.18,0.12),range:18,radius:0.6))
            }
        }
        for x:Float in [-7,0,7] {
            scene.lights.append(NightLighting.source(WrigleyFieldLayout.point(center+V(x,-2.8,1.3)),toward:WrigleyFieldLayout.point(center+V(x,0,0.2)),power:19,color:V(1,0.29,0.16),range:12,radius:0.45))
        }
        // Terracotta awning under the historic marquee and adjacent cream gate façade.
        for side:Float in [-1,1] {
            wfBlock(V(side*11,3.95,68.0),V(13,0.18,3.2),p.brick)
            for x in stride(from:side*11-6,through:side*11+6,by:0.34) {
                cylinder(WrigleyFieldLayout.point(V(x,4.03,66.5)),WrigleyFieldLayout.point(V(x,4.03,69.5)),0.11,p.brick,segments:6)
            }
        }
    }

    private func wfGallagherWay(_ p:WrigleyPalette) {
        wfMappedSurface(WrigleyMap.gallagher,0.09,p.cream)
        box(V(-1743,0.14,-7713),V(25,0.08,39),p.grass)
        // Western ballpark edge is an open green steel concourse, as seen from the plaza.
        for z in stride(from:Float(-7741),through:-7685,by:7.5) {
            for y:Float in [4.5,10.1,14.0] {
                box(V(-1722.5,y,z),V(0.24,0.22,7.5),p.steel)
                box(V(-1722.5,y+1.0,z),V(0.08,0.065,7.5),p.steel)
            }
            box(V(-1722.5,7.0,z),V(0.24,14,0.24),p.steel)
            beam(V(-1722.5,4.5,z),V(-1722.5,10.0,z+7.5),0.12,0.14,p.steel)
        }
        // Mapped Gallagher office footprint, with terraced upper storeys and plaza-facing glass.
        for (c,size): (V,V) in [(V(-1761.5,10.4,-7771.0),V(63,20.8,41)),(V(-1757,22.9,-7772),V(54,4.2,34))] {
            box(c,size,p.brick)
        }
        for y in stride(from:Float(3.6),through:23.6,by:3.7) {
            for x in stride(from:Float(-1788),through:-1731,by:2.3) {
                box(V(x,y,-7750.42),V(1.89,2.6,0.06),p.glass)
                box(V(x,y-1.45,-7750.3),V(2.31,0.22,0.16),p.cream)
            }
        }
        wfLabel("GALLAGHER WAY",V(-1743,4.2,-7683),right:V(1,0,0),up:V(0,1,0),height:0.65,material:p.white)
        box(V(-1743,4.2,-7683.2),V(10.4,1.1,0.28),p.steel)
        for (x,z): (Float,Float) in [(-1761,-7740),(-1762,-7725),(-1761,-7706),(-1758,-7689),(-1727,-7740),(-1727,-7723),(-1727,-7705)] {
            box(V(x,0.33,z),V(2.8,0.6,2.8),p.brick)
            cylinder(V(x,0.5,z),V(x,4.8,z),0.14,p.brick,segments:7)
            for k in 0..<4 {let a=Float(k)*1.57;ellipsoid(V(x+cos(a)*0.52,4.7+Float(k%2)*0.4,z+sin(a)*0.5),V(1.25,2.1,1.15),k%2==0 ? p.ivy:p.ivyLight,segments:8,rings:5)}
            box(V(x+2.3,0.63,z),V(0.63,0.11,3.0),p.seat)
        }
        for z in stride(from:Float(-7744),through:-7682,by:12.0) {
            for x:Float in [-1766,-1728] {
                cylinder(V(x,0.15,z),V(x,5.4,z),0.063,p.steel,segments:7)
                box(V(x,5.48,z),V(0.42,0.2,0.42),p.lamp)
                scene.lights.append(NightLighting.source(V(x,5.25,z),power:20,color:V(1,0.82,0.59),range:19,radius:0.36))
            }
        }
        for x in stride(from:Float(-1785),through:-1732,by:9.5) {
            scene.lights.append(NightLighting.source(V(x,5.4,-7748.8),toward:V(x,0,-7743),power:18,color:V(1,0.78,0.53),range:17,radius:0.4))
        }
        // Low plaza furniture and café umbrellas sit around the lawn, leaving its center clear.
        for z:Float in [-7738,-7691] {for x:Float in [-1752,-1739,-1730] {
            cylinder(V(x,0.15,z),V(x,0.91,z),0.07,p.steel,segments:6)
            cylinder(V(x,0.91,z),V(x,0.98,z),0.72,p.cream,segments:12)
            cylinder(V(x,0.95,z),V(x,2.95,z),0.035,p.steel,segments:6)
            for k in 0..<8 {
                let a=Float(k)*Float.pi/4,b=Float(k+1)*Float.pi/4
                tri(V(x,3.12,z),V(x+cos(b)*1.55,2.64,z+sin(b)*1.55),V(x+cos(a)*1.55,2.64,z+sin(a)*1.55),p.cream)
            }
        }}
    }

    private func wfLabel(_ text:String,_ center:V,right:V,up:V,height:Float,material:UInt32) {
        let font:[Character:[String]]=[
            "A":["01110","10001","10001","11111","10001","10001","10001"],"B":["11110","10001","10001","11110","10001","10001","11110"],
            "C":["01111","10000","10000","10000","10000","10000","01111"],"D":["11110","10001","10001","10001","10001","10001","11110"],
            "E":["11111","10000","10000","11110","10000","10000","11111"],"F":["11111","10000","10000","11110","10000","10000","10000"],
            "G":["01111","10000","10000","10111","10001","10001","01111"],"H":["10001","10001","10001","11111","10001","10001","10001"],
            "I":["11111","00100","00100","00100","00100","00100","11111"],"J":["00111","00010","00010","00010","10010","10010","01100"],
            "K":["10001","10010","10100","11000","10100","10010","10001"],"L":["10000","10000","10000","10000","10000","10000","11111"],
            "M":["10001","11011","10101","10101","10001","10001","10001"],"N":["10001","11001","11001","10101","10011","10011","10001"],
            "O":["01110","10001","10001","10001","10001","10001","01110"],"P":["11110","10001","10001","11110","10000","10000","10000"],
            "Q":["01110","10001","10001","10001","10101","10010","01101"],"R":["11110","10001","10001","11110","10100","10010","10001"],
            "S":["01111","10000","10000","01110","00001","00001","11110"],"T":["11111","00100","00100","00100","00100","00100","00100"],
            "U":["10001","10001","10001","10001","10001","10001","01110"],"V":["10001","10001","10001","10001","10001","01010","00100"],
            "W":["10001","10001","10001","10101","10101","11011","10001"],"X":["10001","10001","01010","00100","01010","10001","10001"],
            "Y":["10001","10001","01010","00100","00100","00100","00100"],"Z":["11111","00001","00010","00100","01000","10000","11111"],
            "0":["01110","10001","10011","10101","11001","10001","01110"],"4":["10010","10010","10010","11111","00010","00010","00010"]]
        let pixel=height/7,width=Float(text.count*6-1)*pixel
        for (i,ch) in text.uppercased().enumerated() {
            guard let glyph=font[ch] else {continue}
            for (r,line) in glyph.enumerated() {for (c,v) in line.enumerated() where v=="1" {
                let q=center+right*(Float(i*6+c)*pixel-width/2)+up*(height/2-Float(r)*pixel)
                quad(q,q+right*pixel*0.94,q+right*pixel*0.94-up*pixel*0.94,q-up*pixel*0.94,material)
            }}
        }
    }
}

private struct WrigleyMappedShape {
    let points:[SIMD2<Float>]
    let triangles:[Int]
    let ring:[SIMD2<Float>]
}

// Bounded OpenStreetMap extract, 2026-09-08. ODbL; attribution in docs/WRIGLEY-FIELD.md.
private enum WrigleyMap {
    static let stadium=WrigleyMappedShape(
        points:[SIMD2(-1724.322,-7726.22),SIMD2(-1723.883,-7736.54),SIMD2(-1716.158,-7736.261),SIMD2(-1724.289,-7711.749),SIMD2(-1724.372,-7719.107),SIMD2(-1717.062,-7701.129),SIMD2(-1723.526,-7701.029),SIMD2(-1711.343,-7654.508),SIMD2(-1713.821,-7661.811),SIMD2(-1692.105,-7629.828),SIMD2(-1684.612,-7625.086),SIMD2(-1653.199,-7618.318),SIMD2(-1712.702,-7658.115),SIMD2(-1707.953,-7646.96),SIMD2(-1709.875,-7650.656),SIMD2(-1703.817,-7640.816),SIMD2(-1706.187,-7643.877),SIMD2(-1694.923,-7631.799),SIMD2(-1699.722,-7636.352),SIMD2(-1688.856,-7627.568),SIMD2(-1714.699,-7665.573),SIMD2(-1668.292,-7619.219),SIMD2(-1672.055,-7620.088),SIMD2(-1657.634,-7618.195),SIMD2(-1664.48,-7618.585),SIMD2(-1660.634,-7618.206),SIMD2(-1622.565,-7619.765),SIMD2(-1715.934,-7679.087),SIMD2(-1604.753,-7625.186),SIMD2(-1615.827,-7621.067),SIMD2(-1540.452,-7649.643),SIMD2(-1545.69,-7647.562),SIMD2(-1542.416,-7654.575),SIMD2(-1531.401,-7679.933),SIMD2(-1531.268,-7658.894),SIMD2(-1533.001,-7658.271),SIMD2(-1531.791,-7691.8),SIMD2(-1531.442,-7686.457),SIMD2(-1533.689,-7691.767),SIMD2(-1533.954,-7698.858),SIMD2(-1533.796,-7695.318),SIMD2(-1531.185,-7698.913),SIMD2(-1532.288,-7698.891),SIMD2(-1531.31,-7704.902),SIMD2(-1533.813,-7786.099),SIMD2(-1532.835,-7779.665),SIMD2(-1535.404,-7789.728),SIMD2(-1532.901,-7782.826),SIMD2(-1534.161,-7787.379),SIMD2(-1536.333,-7791.287),SIMD2(-1535.645,-7790.185),SIMD2(-1538.164,-7793.992),SIMD2(-1537.062,-7792.445),SIMD2(-1539.971,-7796.73),SIMD2(-1539.209,-7795.784),SIMD2(-1542.698,-7799.691),SIMD2(-1541.811,-7798.89),SIMD2(-1540.817,-7797.643),SIMD2(-1544.886,-7801.64),SIMD2(-1543.345,-7800.27),SIMD2(-1551.036,-7805.636),SIMD2(-1548.989,-7804.545),SIMD2(-1546.66,-7803.154),SIMD2(-1552.139,-7806.181),SIMD2(-1560.129,-7808.697),SIMD2(-1556.706,-7808.219),SIMD2(-1554.824,-7807.528),SIMD2(-1621.96,-7807.239),SIMD2(-1532.338,-7755.108),SIMD2(-1667.215,-7805.013),SIMD2(-1662.424,-7806.549),SIMD2(-1639.813,-7806.849),SIMD2(-1713.846,-7771.939),SIMD2(-1672.395,-7803.365),SIMD2(-1715.263,-7749.386),SIMD2(-1700.12,-7802.664),SIMD2(-1690.953,-7802.897),SIMD2(-1706.941,-7792.634),SIMD2(-1706.485,-7797.999),SIMD2(-1706.129,-7802.508),SIMD2(-1706.726,-7795.205),SIMD2(-1712.967,-7792.856),SIMD2(-1719.018,-7792.778),SIMD2(-1718.703,-7771.795),SIMD2(-1679.374,-7622.57),SIMD2(-1675.76,-7621.212),SIMD2(-1715.329,-7669.38),SIMD2(-1537.866,-7656.367),SIMD2(-1670.025,-7804.122),SIMD2(-1687.372,-7802.987),SIMD2(-1711.235,-7792.89),SIMD2(-1532.503,-7763.512)],
        triangles:[0, 1, 2, 3, 4, 5, 5, 6, 3, 7, 8, 9, 10, 9, 11, 7, 12, 8, 13, 14, 7, 15, 16, 13, 17, 18, 9, 19, 9, 10, 20, 11, 8, 21, 22, 23, 24, 21, 23, 23, 25, 24, 5, 26, 27, 28, 29, 26, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 28, 41, 42, 43, 44, 45, 46, 44, 47, 45, 46, 48, 44, 49, 50, 46, 51, 52, 45, 53, 54, 51, 55, 56, 57, 58, 59, 60, 61, 62, 58, 63, 60, 64, 65, 66, 64, 39, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 75, 77, 80, 75, 81, 72, 82, 83, 82, 72, 0, 2, 4, 8, 11, 9, 13, 7, 18, 15, 13, 18, 84, 10, 85, 85, 23, 22, 27, 11, 86, 31, 28, 32, 33, 35, 87, 33, 38, 37, 39, 43, 42, 49, 45, 52, 49, 46, 45, 57, 53, 51, 55, 57, 59, 61, 58, 60, 63, 64, 66, 69, 71, 88, 89, 77, 76, 78, 75, 80, 90, 72, 81, 2, 5, 4, 23, 10, 11, 9, 18, 7, 23, 85, 10, 32, 28, 38, 33, 87, 32, 68, 43, 39, 51, 64, 60, 57, 51, 59, 59, 51, 60, 73, 88, 74, 77, 89, 72, 77, 72, 90, 5, 2, 67, 86, 11, 20, 28, 26, 5, 38, 33, 32, 45, 64, 51, 91, 64, 45, 71, 74, 88, 73, 72, 89, 5, 67, 28, 11, 27, 26, 40, 38, 28, 64, 91, 67, 74, 71, 2, 67, 2, 71, 68, 67, 91, 67, 39, 28],
        ring:[SIMD2(-1716.158,-7736.261),SIMD2(-1723.883,-7736.54),SIMD2(-1724.322,-7726.22),SIMD2(-1724.372,-7719.107),SIMD2(-1724.289,-7711.749),SIMD2(-1723.526,-7701.029),SIMD2(-1717.062,-7701.129),SIMD2(-1715.934,-7679.087),SIMD2(-1715.329,-7669.38),SIMD2(-1714.699,-7665.573),SIMD2(-1713.821,-7661.811),SIMD2(-1712.702,-7658.115),SIMD2(-1711.343,-7654.508),SIMD2(-1709.875,-7650.656),SIMD2(-1707.953,-7646.96),SIMD2(-1706.187,-7643.877),SIMD2(-1703.817,-7640.816),SIMD2(-1699.722,-7636.352),SIMD2(-1694.923,-7631.799),SIMD2(-1692.105,-7629.828),SIMD2(-1688.856,-7627.568),SIMD2(-1684.612,-7625.086),SIMD2(-1679.374,-7622.57),SIMD2(-1675.76,-7621.212),SIMD2(-1672.055,-7620.088),SIMD2(-1668.292,-7619.219),SIMD2(-1664.48,-7618.585),SIMD2(-1660.634,-7618.206),SIMD2(-1657.634,-7618.195),SIMD2(-1653.199,-7618.318),SIMD2(-1622.565,-7619.765),SIMD2(-1615.827,-7621.067),SIMD2(-1604.753,-7625.186),SIMD2(-1545.69,-7647.562),SIMD2(-1540.452,-7649.643),SIMD2(-1542.416,-7654.575),SIMD2(-1537.866,-7656.367),SIMD2(-1533.001,-7658.271),SIMD2(-1531.268,-7658.894),SIMD2(-1531.401,-7679.933),SIMD2(-1531.442,-7686.457),SIMD2(-1531.791,-7691.8),SIMD2(-1533.689,-7691.767),SIMD2(-1533.796,-7695.318),SIMD2(-1533.954,-7698.858),SIMD2(-1532.288,-7698.891),SIMD2(-1531.185,-7698.913),SIMD2(-1531.31,-7704.902),SIMD2(-1532.338,-7755.108),SIMD2(-1532.503,-7763.512),SIMD2(-1532.835,-7779.665),SIMD2(-1532.901,-7782.826),SIMD2(-1533.813,-7786.099),SIMD2(-1534.161,-7787.379),SIMD2(-1535.404,-7789.728),SIMD2(-1535.645,-7790.185),SIMD2(-1536.333,-7791.287),SIMD2(-1537.062,-7792.445),SIMD2(-1538.164,-7793.992),SIMD2(-1539.209,-7795.784),SIMD2(-1539.971,-7796.73),SIMD2(-1540.817,-7797.643),SIMD2(-1541.811,-7798.89),SIMD2(-1542.698,-7799.691),SIMD2(-1543.345,-7800.27),SIMD2(-1544.886,-7801.64),SIMD2(-1546.66,-7803.154),SIMD2(-1548.989,-7804.545),SIMD2(-1551.036,-7805.636),SIMD2(-1552.139,-7806.181),SIMD2(-1554.824,-7807.528),SIMD2(-1556.706,-7808.219),SIMD2(-1560.129,-7808.697),SIMD2(-1621.96,-7807.239),SIMD2(-1639.813,-7806.849),SIMD2(-1662.424,-7806.549),SIMD2(-1667.215,-7805.013),SIMD2(-1670.025,-7804.122),SIMD2(-1672.395,-7803.365),SIMD2(-1687.372,-7802.987),SIMD2(-1690.953,-7802.897),SIMD2(-1700.12,-7802.664),SIMD2(-1706.129,-7802.508),SIMD2(-1706.485,-7797.999),SIMD2(-1706.726,-7795.205),SIMD2(-1706.941,-7792.634),SIMD2(-1711.235,-7792.89),SIMD2(-1712.967,-7792.856),SIMD2(-1719.018,-7792.778),SIMD2(-1718.703,-7771.795),SIMD2(-1713.846,-7771.939),SIMD2(-1715.263,-7749.386)]) // OSM -17379974
    static let pitch=WrigleyMappedShape(
        points:[SIMD2(-1629.809,-7673.455),SIMD2(-1633.44,-7673.354),SIMD2(-1628.102,-7674.123),SIMD2(-1615.222,-7679.132),SIMD2(-1616.772,-7678.52),SIMD2(-1662.888,-7707.296),SIMD2(-1544.729,-7704.802),SIMD2(-1544.704,-7698.39),SIMD2(-1574.302,-7694.995),SIMD2(-1545.259,-7720.855),SIMD2(-1544.795,-7719.029),SIMD2(-1546.494,-7721.845),SIMD2(-1548.218,-7722.513),SIMD2(-1554.451,-7756.588),SIMD2(-1554.078,-7754.34),SIMD2(-1554.973,-7758.804),SIMD2(-1558.454,-7767.197),SIMD2(-1555.636,-7760.985),SIMD2(-1563.991,-7774.4),SIMD2(-1557.377,-7765.193),SIMD2(-1556.432,-7763.112),SIMD2(-1559.656,-7769.134),SIMD2(-1562.433,-7772.741),SIMD2(-1560.982,-7770.982),SIMD2(-1565.649,-7775.958),SIMD2(-1567.414,-7777.405),SIMD2(-1569.271,-7778.73),SIMD2(-1573.216,-7781.012),SIMD2(-1571.202,-7779.932),SIMD2(-1579.432,-7783.94),SIMD2(-1577.253,-7783.06),SIMD2(-1583.858,-7784.997),SIMD2(-1581.795,-7784.741),SIMD2(-1634.177,-7793.257),SIMD2(-1633.556,-7792.678),SIMD2(-1634.99,-7793.524),SIMD2(-1663.212,-7793.213),SIMD2(-1633.042,-7791.866),SIMD2(-1662.681,-7725.385),SIMD2(-1610.721,-7680.88),SIMD2(-1662.83,-7723.682),SIMD2(-1663.104,-7720.432),SIMD2(-1662.598,-7702.643),SIMD2(-1662.797,-7705.47),SIMD2(-1659.15,-7672.898),SIMD2(-1661.844,-7676.037),SIMD2(-1575.255,-7782.047),SIMD2(-1549.437,-7723.27),SIMD2(-1660.095,-7755.041),SIMD2(-1630.97,-7790.886),SIMD2(-1632.221,-7791.298),SIMD2(-1662.209,-7730.918),SIMD2(-1550.207,-7725.252)],
        triangles:[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 11, 10, 13, 14, 15, 16, 17, 18, 19, 20, 17, 21, 16, 22, 22, 23, 21, 24, 18, 25, 26, 25, 18, 27, 28, 14, 29, 30, 31, 32, 29, 31, 33, 34, 35, 36, 35, 37, 38, 39, 40, 5, 41, 3, 42, 43, 4, 44, 45, 1, 2, 1, 42, 10, 6, 12, 15, 18, 17, 19, 17, 16, 18, 22, 16, 26, 14, 28, 46, 31, 30, 37, 35, 34, 3, 41, 39, 5, 4, 43, 45, 42, 1, 12, 6, 47, 14, 26, 15, 26, 18, 15, 31, 46, 14, 36, 37, 48, 40, 39, 41, 2, 42, 4, 8, 47, 6, 27, 14, 46, 49, 31, 48, 50, 48, 37, 51, 39, 38, 47, 8, 52, 48, 31, 51, 49, 48, 50, 39, 51, 8, 8, 51, 31, 14, 8, 31, 52, 8, 14],
        ring:[SIMD2(-1659.15,-7672.898),SIMD2(-1633.44,-7673.354),SIMD2(-1629.809,-7673.455),SIMD2(-1628.102,-7674.123),SIMD2(-1616.772,-7678.52),SIMD2(-1615.222,-7679.132),SIMD2(-1610.721,-7680.88),SIMD2(-1574.302,-7694.995),SIMD2(-1544.704,-7698.39),SIMD2(-1544.729,-7704.802),SIMD2(-1544.795,-7719.029),SIMD2(-1545.259,-7720.855),SIMD2(-1546.494,-7721.845),SIMD2(-1548.218,-7722.513),SIMD2(-1549.437,-7723.27),SIMD2(-1550.207,-7725.252),SIMD2(-1554.078,-7754.34),SIMD2(-1554.451,-7756.588),SIMD2(-1554.973,-7758.804),SIMD2(-1555.636,-7760.985),SIMD2(-1556.432,-7763.112),SIMD2(-1557.377,-7765.193),SIMD2(-1558.454,-7767.197),SIMD2(-1559.656,-7769.134),SIMD2(-1560.982,-7770.982),SIMD2(-1562.433,-7772.741),SIMD2(-1563.991,-7774.4),SIMD2(-1565.649,-7775.958),SIMD2(-1567.414,-7777.405),SIMD2(-1569.271,-7778.73),SIMD2(-1571.202,-7779.932),SIMD2(-1573.216,-7781.012),SIMD2(-1575.255,-7782.047),SIMD2(-1577.253,-7783.06),SIMD2(-1579.432,-7783.94),SIMD2(-1581.795,-7784.741),SIMD2(-1583.858,-7784.997),SIMD2(-1630.97,-7790.886),SIMD2(-1632.221,-7791.298),SIMD2(-1633.042,-7791.866),SIMD2(-1633.556,-7792.678),SIMD2(-1634.177,-7793.257),SIMD2(-1634.99,-7793.524),SIMD2(-1663.212,-7793.213),SIMD2(-1660.095,-7755.041),SIMD2(-1662.209,-7730.918),SIMD2(-1662.681,-7725.385),SIMD2(-1662.83,-7723.682),SIMD2(-1663.104,-7720.432),SIMD2(-1662.888,-7707.296),SIMD2(-1662.797,-7705.47),SIMD2(-1662.598,-7702.643),SIMD2(-1661.844,-7676.037)]) // OSM -2083717
    static let sand=WrigleyMappedShape(
        points:[SIMD2(-1628.102,-7674.123),SIMD2(-1629.809,-7673.455),SIMD2(-1630.895,-7677.017),SIMD2(-1615.222,-7679.132),SIMD2(-1616.772,-7678.52),SIMD2(-1544.729,-7704.802),SIMD2(-1544.704,-7698.39),SIMD2(-1552.934,-7703.678),SIMD2(-1545.259,-7720.855),SIMD2(-1544.795,-7719.029),SIMD2(-1546.494,-7721.845),SIMD2(-1548.218,-7722.513),SIMD2(-1554.973,-7758.804),SIMD2(-1554.451,-7756.588),SIMD2(-1560.568,-7753.861),SIMD2(-1555.636,-7760.985),SIMD2(-1562.764,-7760.017),SIMD2(-1556.432,-7763.112),SIMD2(-1557.377,-7765.193),SIMD2(-1559.656,-7769.134),SIMD2(-1558.454,-7767.197),SIMD2(-1566.801,-7767.197),SIMD2(-1562.433,-7772.741),SIMD2(-1560.982,-7770.982),SIMD2(-1567.414,-7777.405),SIMD2(-1565.649,-7775.958),SIMD2(-1572.594,-7772.763),SIMD2(-1569.271,-7778.73),SIMD2(-1573.216,-7781.012),SIMD2(-1571.202,-7779.932),SIMD2(-1579.432,-7783.94),SIMD2(-1579.341,-7776.715),SIMD2(-1581.795,-7784.741),SIMD2(-1583.858,-7784.997),SIMD2(-1586.743,-7778.919),SIMD2(-1634.177,-7793.257),SIMD2(-1633.556,-7792.678),SIMD2(-1634.99,-7793.524),SIMD2(-1663.212,-7793.213),SIMD2(-1653.042,-7786.834),SIMD2(-1662.681,-7725.385),SIMD2(-1659.051,-7721.779),SIMD2(-1662.83,-7723.682),SIMD2(-1662.888,-7707.296),SIMD2(-1663.104,-7720.432),SIMD2(-1658.835,-7707.93),SIMD2(-1662.598,-7702.643),SIMD2(-1662.797,-7705.47),SIMD2(-1659.15,-7672.898),SIMD2(-1661.844,-7676.037),SIMD2(-1655.827,-7678.041),SIMD2(-1657.294,-7778.841),SIMD2(-1655.827,-7762.8),SIMD2(-1660.095,-7755.041),SIMD2(-1595.47,-7780.166),SIMD2(-1630.746,-7783.828),SIMD2(-1630.97,-7790.886),SIMD2(-1553.747,-7716.435),SIMD2(-1573.175,-7699.503),SIMD2(-1610.721,-7680.88),SIMD2(-1563.991,-7774.4),SIMD2(-1577.253,-7783.06),SIMD2(-1633.042,-7791.866),SIMD2(-1658.545,-7682.516),SIMD2(-1657.368,-7781.925),SIMD2(-1633.755,-7786.678),SIMD2(-1633.44,-7673.354),SIMD2(-1549.437,-7723.27),SIMD2(-1575.255,-7782.047),SIMD2(-1634.857,-7786.901),SIMD2(-1662.209,-7730.918),SIMD2(-1657.808,-7680.022),SIMD2(-1550.207,-7725.252),SIMD2(-1556.167,-7721.411),SIMD2(-1632.221,-7791.298),SIMD2(-1654.144,-7676.872),SIMD2(-1656.49,-7784.04),SIMD2(-1651.865,-7676.583),SIMD2(-1654.874,-7785.955),SIMD2(-1574.302,-7694.995),SIMD2(-1554.111,-7702.075),SIMD2(-1552.495,-7705.515),SIMD2(-1554.078,-7754.34)],
        triangles:[0, 1, 2, 3, 4, 2, 5, 6, 7, 8, 9, 10, 11, 10, 9, 12, 13, 14, 15, 16, 17, 18, 17, 16, 19, 20, 21, 22, 23, 21, 24, 25, 26, 27, 24, 26, 28, 29, 26, 30, 31, 32, 33, 32, 34, 35, 36, 37, 38, 37, 39, 40, 41, 42, 43, 44, 45, 46, 47, 45, 48, 49, 50, 51, 52, 53, 54, 55, 56, 5, 57, 9, 2, 58, 59, 41, 45, 44, 4, 0, 2, 11, 9, 57, 12, 16, 15, 20, 18, 16, 60, 22, 21, 27, 26, 29, 61, 31, 30, 62, 37, 36, 42, 41, 44, 47, 43, 45, 46, 63, 49, 64, 51, 38, 65, 56, 55, 45, 63, 46, 66, 2, 1, 67, 11, 57, 16, 12, 14, 25, 60, 26, 68, 31, 61, 39, 37, 69, 70, 41, 40, 53, 52, 70, 34, 54, 33, 63, 71, 49, 72, 67, 73, 28, 31, 68, 62, 69, 37, 41, 70, 52, 71, 50, 49, 74, 69, 62, 53, 38, 51, 48, 50, 75, 76, 64, 38, 48, 75, 77, 78, 76, 38, 48, 77, 66, 39, 78, 38, 2, 66, 77, 69, 74, 65, 59, 3, 2, 56, 65, 74, 79, 59, 58, 33, 54, 56, 80, 79, 58, 31, 34, 32, 79, 80, 6, 31, 28, 26, 80, 7, 6, 21, 26, 60, 5, 7, 81, 19, 21, 23, 5, 81, 57, 16, 21, 20, 73, 67, 57, 82, 14, 13, 14, 72, 73, 72, 14, 82],
        ring:[SIMD2(-1633.44,-7673.354),SIMD2(-1629.809,-7673.455),SIMD2(-1628.102,-7674.123),SIMD2(-1616.772,-7678.52),SIMD2(-1615.222,-7679.132),SIMD2(-1610.721,-7680.88),SIMD2(-1574.302,-7694.995),SIMD2(-1544.704,-7698.39),SIMD2(-1544.729,-7704.802),SIMD2(-1544.795,-7719.029),SIMD2(-1545.259,-7720.855),SIMD2(-1546.494,-7721.845),SIMD2(-1548.218,-7722.513),SIMD2(-1549.437,-7723.27),SIMD2(-1550.207,-7725.252),SIMD2(-1554.078,-7754.34),SIMD2(-1554.451,-7756.588),SIMD2(-1554.973,-7758.804),SIMD2(-1555.636,-7760.985),SIMD2(-1556.432,-7763.112),SIMD2(-1557.377,-7765.193),SIMD2(-1558.454,-7767.197),SIMD2(-1559.656,-7769.134),SIMD2(-1560.982,-7770.982),SIMD2(-1562.433,-7772.741),SIMD2(-1563.991,-7774.4),SIMD2(-1565.649,-7775.958),SIMD2(-1567.414,-7777.405),SIMD2(-1569.271,-7778.73),SIMD2(-1571.202,-7779.932),SIMD2(-1573.216,-7781.012),SIMD2(-1575.255,-7782.047),SIMD2(-1577.253,-7783.06),SIMD2(-1579.432,-7783.94),SIMD2(-1581.795,-7784.741),SIMD2(-1583.858,-7784.997),SIMD2(-1630.97,-7790.886),SIMD2(-1632.221,-7791.298),SIMD2(-1633.042,-7791.866),SIMD2(-1633.556,-7792.678),SIMD2(-1634.177,-7793.257),SIMD2(-1634.99,-7793.524),SIMD2(-1663.212,-7793.213),SIMD2(-1660.095,-7755.041),SIMD2(-1662.209,-7730.918),SIMD2(-1662.681,-7725.385),SIMD2(-1662.83,-7723.682),SIMD2(-1663.104,-7720.432),SIMD2(-1662.888,-7707.296),SIMD2(-1662.797,-7705.47),SIMD2(-1662.598,-7702.643),SIMD2(-1661.844,-7676.037),SIMD2(-1659.15,-7672.898)]) // OSM -17380286
    static let gallagher=WrigleyMappedShape(
        points:[SIMD2(-1717.062,-7701.129),SIMD2(-1715.934,-7679.087),SIMD2(-1723.526,-7701.029),SIMD2(-1715.263,-7749.386),SIMD2(-1716.158,-7736.261),SIMD2(-1723.883,-7736.54),SIMD2(-1734.674,-7750.165),SIMD2(-1728.516,-7749.92),SIMD2(-1754.16,-7748.763),SIMD2(-1750.547,-7749.542),SIMD2(-1759.838,-7714.064),SIMD2(-1771.284,-7733.111),SIMD2(-1761.778,-7746.458),SIMD2(-1772.768,-7739.868),SIMD2(-1768.723,-7743.686),SIMD2(-1774.119,-7737.33),SIMD2(-1734.434,-7676.794),SIMD2(-1740.269,-7681.18),SIMD2(-1729.469,-7679.032),SIMD2(-1736.879,-7675.436),SIMD2(-1738.91,-7678.765),SIMD2(-1725.35,-7679.054),SIMD2(-1742.399,-7684.676),SIMD2(-1742.275,-7750.21),SIMD2(-1724.322,-7726.22),SIMD2(-1755.271,-7706.327),SIMD2(-1724.372,-7719.107),SIMD2(-1724.289,-7711.749)],
        triangles:[0, 1, 2, 3, 4, 5, 6, 7, 5, 8, 9, 10, 11, 12, 10, 13, 14, 11, 11, 15, 13, 16, 17, 18, 19, 20, 16, 21, 2, 1, 3, 5, 7, 8, 10, 12, 12, 11, 14, 22, 18, 17, 17, 16, 20, 18, 2, 21, 6, 5, 23, 10, 9, 24, 25, 2, 22, 2, 18, 22, 24, 23, 5, 10, 26, 25, 2, 25, 27, 23, 24, 9, 27, 25, 26, 26, 10, 24],
        ring:[SIMD2(-1734.434,-7676.794),SIMD2(-1729.469,-7679.032),SIMD2(-1725.35,-7679.054),SIMD2(-1715.934,-7679.087),SIMD2(-1717.062,-7701.129),SIMD2(-1723.526,-7701.029),SIMD2(-1724.289,-7711.749),SIMD2(-1724.372,-7719.107),SIMD2(-1724.322,-7726.22),SIMD2(-1723.883,-7736.54),SIMD2(-1716.158,-7736.261),SIMD2(-1715.263,-7749.386),SIMD2(-1728.516,-7749.92),SIMD2(-1734.674,-7750.165),SIMD2(-1742.275,-7750.21),SIMD2(-1750.547,-7749.542),SIMD2(-1754.16,-7748.763),SIMD2(-1761.778,-7746.458),SIMD2(-1768.723,-7743.686),SIMD2(-1772.768,-7739.868),SIMD2(-1774.119,-7737.33),SIMD2(-1771.284,-7733.111),SIMD2(-1759.838,-7714.064),SIMD2(-1755.271,-7706.327),SIMD2(-1742.399,-7684.676),SIMD2(-1740.269,-7681.18),SIMD2(-1738.91,-7678.765),SIMD2(-1736.879,-7675.436)]) // OSM 1265774541
}
extension EiffelBuilder {
    private func wfPlayingField(_ p:WrigleyPalette) {
        wfMappedSurface(WrigleyMap.pitch,0.12,p.grass)
        wfMappedSurface(WrigleyMap.sand,0.133,p.dirt)
        // Local regulation diamond supplements the mapped warning-track/infield outline.
        let base=WrigleyFieldLayout.baseDistance/sqrt(2.0)
        for q in [V(-base,0.041,-base),V(base,0.041,-base),V(0,0.041,-base*2)] {
            wfBlock(q,V(0.4572,0.055,0.4572),p.white)
        }
        let plate=[V(-0.216,0.027,-0.432),V(0.216,0.027,-0.432),V(0.216,0.027,-0.216),V(0,0.027,0),V(-0.216,0.027,-0.216)]
        for i in 1..<plate.count-1 {tri(WrigleyFieldLayout.point(plate[0]),WrigleyFieldLayout.point(plate[i+1]),WrigleyFieldLayout.point(plate[i]),p.white)}
        for side:Float in [-1,1] {
            let end=side<0 ? V(-1663.212,0.148,-7793.213):V(-1544.704,0.148,-7698.390)
            let a=WrigleyFieldLayout.point(V(0,0.028,0)),b=end
            beam(a,b,0.10,0.016,p.white)
            for x:Float in [side*0.91-0.305,side*0.91+0.305] {wfBlock(V(x,0.025,-0.66),V(0.025,0.015,1.83),p.white)}
            for z:Float in [-1.575,0.255] {wfBlock(V(side*0.91,0.025,z),V(0.635,0.015,0.026),p.white)}
        }
        let mound=V(0,0,-WrigleyFieldLayout.pitchingDistance)
        for i in 0..<48 {
            let a=Float(i)*2*Float.pi/48,b=Float(i+1)*2*Float.pi/48
            tri(WrigleyFieldLayout.point(mound+V(0,0.254,0)),WrigleyFieldLayout.point(mound+V(cos(b)*2.7432,0.018,sin(b)*2.7432)),WrigleyFieldLayout.point(mound+V(cos(a)*2.7432,0.018,sin(a)*2.7432)),p.dirt)
        }
        wfBlock(mound+V(0,0.265,0),V(0.6096,0.025,0.1524),p.white)
        // Both dugouts sit in the mapped foul-territory locations, with open field fronts.
        for (c,angle): (V,Float) in [(V(-1665.62,0,-7718.5),0.02),(V(-1619.33,0,-7674.88),-0.36)] {
            let t=V(sin(angle),0,cos(angle)),n=V(cos(angle),0,-sin(angle))
            orientedBox(c+V(0,0.18,0),t,V(0,1,0),n,V(22,0.32,3.8),p.concrete)
            orientedBox(c+V(0,2.75,0),t,V(0,1,0),n,V(23,0.18,4.1),p.steel)
            for d:Float in [-9,-3,3,9] {cylinder(c+t*d+V(0,0.2,0)-n*1.65,c+t*d+V(0,2.7,0)-n*1.65,0.065,p.steel,segments:6)}
            orientedBox(c+n*1.2+V(0,0.66,0),t,V(0,1,0),n,V(20,0.14,0.6),p.seat)
        }
    }

    private func wfGrandstands(_ p:WrigleyPalette) {
        let inner=WrigleyMap.pitch.ring.map{WrigleyFieldLayout.local(V($0.x,0,$0.y))}
        let outer=WrigleyMap.stadium.ring.map{WrigleyFieldLayout.local(V($0.x,0,$0.y))}
        func ray(_ a:Float,_ polygon:[V])->Float {
            let d=V(sin(a),0,-cos(a));var nearest:Float=1000
            for j in polygon.indices {
                let u=polygon[j],v=polygon[(j+1)%polygon.count],e=v-u
                let cross=d.x*e.z-d.z*e.x
                if abs(cross)<0.00001 {continue}
                let t=(u.x*e.z-u.z*e.x)/cross,s=(u.x*d.z-u.z*d.x)/cross
                if t>0 && s>=0 && s<=1 {nearest=min(nearest,t)}
            }
            return nearest
        }
        let sectors=184,start:Float = -47*Float.pi/180,end:Float = -313*Float.pi/180
        func at(_ sector:Int,_ t:Float,_ y:Float)->V {
            let a=start+(end-start)*Float(sector)/Float(sectors),ri=ray(a,inner)+0.7,ro=ray(a,outer)-1.15
            let r=ri+(ro-ri)*t
            return V(sin(a)*r,y,-cos(a)*r)
        }
        func seat(_ c:V,_ tangent:V,_ outward:V,_ material:UInt32) {
            let world=WrigleyFieldLayout.point(c),t=simd_normalize(WrigleyFieldLayout.point(tangent)-WrigleyFieldLayout.point(.zero)),n=simd_normalize(WrigleyFieldLayout.point(outward)-WrigleyFieldLayout.point(.zero)),up=V(0,1,0)
            // Three-dimensional bent seat shell: thin pan and back, no thousands of hidden boxes.
            quad(world-t*0.225-n*0.22,world-t*0.225+n*0.19,world+t*0.225+n*0.19,world+t*0.225-n*0.22,material)
            quad(world-t*0.225+n*0.20,world-t*0.225+n*0.26+up*0.43,world+t*0.225+n*0.26+up*0.43,world+t*0.225+n*0.20,material)
            if Int(abs(c.x*7+c.z*3))%5==0 {
                beam(world-t*0.245+up*0.10,world-t*0.245+up*0.22+n*0.18,0.025,0.028,p.steel)
            }
        }
        for deck in 0..<2 {
            let rows=deck==0 ? 34:24
            let ta:Float=deck==0 ? 0:0.49,tb:Float=deck==0 ? 0.77:0.985
            let y0:Float=deck==0 ? 0.5:12.8, rise:Float=deck==0 ? 0.285:0.415
            for row in 0..<rows {
                let t0=ta+(tb-ta)*Float(row)/Float(rows),t1=ta+(tb-ta)*Float(row+1)/Float(rows),y=y0+Float(row)*rise
                for i in 0..<sectors {
                    let a=at(i,t0,y),b=at(i+1,t0,y),c=at(i+1,t1,y),d=at(i,t1,y),mid=(a+b+c+d)/4
                    if deck==0 && abs(mid.x)<3.8 && mid.z>0 {continue}
                    wfPanel(a,d,c,b,p.concrete)
                    wfPanel(a,b,b-V(0,rise,0),a-V(0,rise,0),p.concrete)
                    // Radial stairs/aisles are gaps in the chair array, not invisible collision paths.
                    if i%13==0 || i%13==1 {continue}
                    let left=(a+d)/2,right=(b+c)/2,length=simd_distance(left,right),count=max(1,Int(length/0.54))
                    let tangent=simd_normalize(right-left),n=simd_normalize(V(mid.x,0,mid.z))
                    for s in 0..<count {let cc=left+(right-left)*(Float(s)+0.5)/Float(count)+V(0,0.43,0);seat(cc,tangent,n,p.seat)}
                }
            }
        }
        // Roof and balcony structure follows the actual non-circular exterior boundary.
        for i in 0..<sectors {
            let a=at(i,0.45,24.8),b=at(i+1,0.45,24.8),c=at(i+1,1.015,25.9),d=at(i,1.015,25.9)
            wfPanel(a,d,c,b,p.roof)
            wfPanel(d,c,c-V(0,0.36,0),d-V(0,0.36,0),p.cream)
            if i%5==0 {
                beam(WrigleyFieldLayout.point(a-V(0,0.18,0)),WrigleyFieldLayout.point(d-V(0,0.18,0)),0.18,0.33,p.steel,iSection:true)
            }
            if i%13==0 {
                let q=at(i,0.69,0)
                if abs(q.x)<4.0 && q.z>0 {continue}
                cylinder(WrigleyFieldLayout.point(q),WrigleyFieldLayout.point(q+V(0,24.4,0)),0.14,p.steel,segments:8)
                let outside=at(i,0.98,0)
                cylinder(WrigleyFieldLayout.point(outside),WrigleyFieldLayout.point(outside+V(0,25.6,0)),0.18,p.steel,segments:8)
                beam(WrigleyFieldLayout.point(q+V(0,18,0)),WrigleyFieldLayout.point(outside+V(0,25.2,0)),0.15,0.22,p.steel)
            }
            let u=at(i,1.007,0),v=at(i+1,1.007,0),mid=(u+v)/2
            // Open steel-framed perimeter above a brick/stucco gate storey.
            if abs(mid.x)>6.5 || mid.z<0 {
                wfPanel(u,v,v+V(0,4.2,0),u+V(0,4.2,0),p.brick)
                wfPanel(u+V(0,4.2,0),v+V(0,4.2,0),v+V(0,9.6,0),u+V(0,9.6,0),p.cream)
            }
            for y:Float in [4.1,10,13.8,23.1] {beam(WrigleyFieldLayout.point(u+V(0,y,0)),WrigleyFieldLayout.point(v+V(0,y,0)),0.30,0.38,p.steel)}
            if i%3==0 && (abs(mid.x)>7 || mid.z<0) {
                let t=simd_normalize(v-u),n=simd_normalize(V(mid.x,0,mid.z)),cc=mid+n*0.03+V(0,6.8,0)
                wfPanel(cc-t*0.63-V(0,1.35,0),cc+t*0.63-V(0,1.35,0),cc+t*0.63+V(0,1.35,0),cc-t*0.63+V(0,1.35,0),p.glass)
            }
        }
        // Empty gate-to-field access lane has a physically present floor and a high ceiling.
        wfBlock(V(0,-0.10,43),V(7.4,0.20,75),p.concrete)
        for side:Float in [-1,1] {wfBlock(V(side*4.05,1.75,45),V(0.35,3.5,50),p.brick)}
        wfBlock(V(0,4.0,49),V(8.4,0.24,39),p.concrete)
        for z:Float in [36,47,58,66] {
            wfBlock(V(0,3.83,z),V(1.6,0.08,0.35),p.lamp)
            scene.lights.append(NightLighting.source(WrigleyFieldLayout.point(V(0,3.65,z)),power:9,color:V(1,0.91,0.77),range:11,radius:0.4,alwaysOn:true))
        }
        // Six retained steel lighting frames, approximately 33 feet above the roof.
        for i in [18,47,76,109,138,167] {
            let c=at(i,0.50,26),a=start+(end-start)*Float(i)/Float(sectors),t=V(cos(a),0,sin(a)),n=V(sin(a),0,-cos(a))
            for side:Float in [-1,1] {
                let q=c+t*side*6.4
                beam(WrigleyFieldLayout.point(q),WrigleyFieldLayout.point(q+V(0,9.9,0)),0.15,0.19,p.cream)
                beam(WrigleyFieldLayout.point(q),WrigleyFieldLayout.point(q-t*side*12.8+V(0,9.9,0)),0.08,0.10,p.cream)
            }
            for row in 0..<3 {for j in 0..<8 {
                let q=c+t*(Float(j)-3.5)*1.65+V(0,7.0+Float(row)*1.0,0)
                orientedBox(WrigleyFieldLayout.point(q),WrigleyFieldLayout.point(t)-WrigleyFieldLayout.point(.zero),V(0,1,0),WrigleyFieldLayout.point(n)-WrigleyFieldLayout.point(.zero),V(1.18,0.66,0.23),p.lamp)
            }}
            for j in 0..<3 {
                let position=WrigleyFieldLayout.point(c+t*(Float(j)-1)*3+V(0,8.0,0)-n*3.2)
                let target=WrigleyFieldLayout.point(V(Float(j-1)*31,0,j==1 ? -22:-68))
                scene.lights.append(NightLighting.source(position,toward:target,power:1900,color:V(0.96,0.985,1),range:170,radius:1.8,outerDegrees:42,innerDegrees:25))
            }
            scene.lights.append(NightLighting.source(WrigleyFieldLayout.point(c+n*1.5+V(0,0.5,0)),toward:WrigleyFieldLayout.point(c+V(0,5.5,0)),power:28,color:V(0.72,0.85,1),range:15,radius:0.5))
            let facade=at(i,1.007,0)
            scene.lights.append(NightLighting.source(WrigleyFieldLayout.point(facade+n*3.0+V(0,4.8,0)),toward:WrigleyFieldLayout.point(facade+V(0,9,0)),power:38,color:V(1,0.91,0.75),range:19,radius:0.55,outerDegrees:55,innerDegrees:30))
        }
    }

}
