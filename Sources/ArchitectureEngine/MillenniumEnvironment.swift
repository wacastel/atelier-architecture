import Foundation
import simd

/// OSM park geometry shares the Willis Tower origin; nothing is relocated for the tour.
enum MillenniumContext {
    struct Area:Decodable {var id:Int64;var name:String;var kind:String;var points:[[Float]];var triangles:[Int]}
    struct Path:Decodable {var id:Int64;var name:String;var kind:String;var points:[[Float]];var width:Float}
    struct Tree:Decodable {var id:Int64;var point:[Float]}
    struct Landmark:Decodable {var id:Int64;var name:String;var points:[[Float]]}
    struct Database:Decodable {var timestamp:String;var areas:[Area];var paths:[Path];var trees:[Tree];var landmarks:[Landmark]}
    static let bean = SIMD3<Float>(1042.46,3,-424.15)
    static let pavilion = SIMD3<Float>(1162.7,0.15,-508)
    static let garden = SIMD3<Float>(1175,0.15,-283)
    static let replacementBuildingIDs:Set<Int64> = [137060274,126978545,126945440,126945441,231253695,764598206,764598207,764598208,764598209,126977943,126977944,234847961,234847963]
    static func suppressesGenericBuilding(_ id:Int64)->Bool {replacementBuildingIDs.contains(id)}
    static func containsPark(_ x:Float,_ z:Float)->Bool {x>969 && x<1256 && z < -227 && z > -606}
    static let database:Database = {
        var urls:[URL]=[]
        if let r=Bundle.main.resourceURL {
            urls.append(r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/Millennium/MillenniumContext.json"))
            urls.append(r.appendingPathComponent("Resources/Millennium/MillenniumContext.json"))
        }
        urls.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/Millennium/MillenniumContext.json"))
        for u in urls {if let d=try?Data(contentsOf:u),let result=try?JSONDecoder().decode(Database.self,from:d){return result}}
        #if SWIFT_PACKAGE
        let u=Bundle.module.bundleURL.appendingPathComponent("Resources/Millennium/MillenniumContext.json")
        if let d=try?Data(contentsOf:u),let result=try?JSONDecoder().decode(Database.self,from:d){return result}
        #endif
        fatalError("Bundled MillenniumContext.json is missing or invalid")
    }()
}

extension EiffelBuilder {
    func millenniumPark() {
        let savedRandom=randomState
        randomState=0x2004_C10D_6A7E
        let p=MillenniumPalette(builder:self),data=MillenniumContext.database
        // The park is built over railway infrastructure. These are surface elevations,
        // not a reconstruction of underground garages or the station.
        for a in data.areas where a.id == 23888253 {millenniumArea(a,y:0.06,material:p.paving)}
        for a in data.areas where a.id != 23888253 && a.kind != "hedge" {
            let y:Float=a.kind == "water" ? 0.12:a.kind == "paving" ? 0.11:0.10
            let m=a.kind == "water" ? p.water:a.kind == "boardwalk" ? timber:a.kind == "paving" ? p.paving:grass
            millenniumArea(a,y:y,material:m)
        }
        for path in data.paths {millenniumPath(path,material:p.paving)}
        for a in data.areas where a.kind == "hedge" {millenniumHedge(a,p:p)}
        for a in data.areas where a.kind == "planting" && a.id != 23888253 && a.id != 115914077 && a.id != 126945427 {
            millenniumFlowerBed(a,p:p)
        }
        for t in data.trees {
            let q=V(t.point[0],0.13,t.point[1])
            // Plaza additions in OSM include young perimeter trees; preserve the arch aisle.
            if q.x>1017 && q.x<1062 && q.z > -460 && q.z < -386 {continue}
            millenniumTree(q,height:6.5+Float(t.id%27)*0.105,p:p)
        }
        cloudGate(p:p)
        pritzkerPavilion(p:p)
        crownFountain(p:p)
        millenniumMonument(p:p)
        millenniumBPBridge(p:p)
        millenniumServicePavilions(p:p)
        millenniumFurniture(p:p)
        randomState=savedRandom
    }

    private struct MillenniumPalette {
        var mirror:UInt32;var steel:UInt32;var paving:UInt32;var dark:UInt32;var water:UInt32
        var light:UInt32;var block:UInt32;var hedge:UInt32;var purple:UInt32;var pink:UInt32;var yellow:UInt32;var seats:UInt32
        init(builder b:EiffelBuilder) {
            mirror=b.riverMaterial(V(0.955,0.968,0.982),roughness:0.022,metallic:1)
            steel=b.riverMaterial(V(0.57,0.61,0.64),roughness:0.26,metallic:0.92)
            paving=b.riverMaterial(V(0.51,0.48,0.42),roughness:0.60,pattern:1)
            dark=b.riverMaterial(V(0.033,0.035,0.037),roughness:0.38,metallic:0.46)
            water=b.riverMaterial(V(0.018,0.050,0.055),roughness:0.065,pattern:9)
            light=b.riverMaterial(V(0.94,0.80,0.54),roughness:0.3,emission:0.2,pattern:14)
            block=b.riverMaterial(V(0.33,0.51,0.52),roughness:0.22,metallic:0.3)
            hedge=b.riverMaterial(V(0.078,0.165,0.048),roughness:0.94,pattern:4)
            purple=b.riverMaterial(V(0.26,0.09,0.34),roughness:0.92)
            pink=b.riverMaterial(V(0.49,0.19,0.35),roughness:0.91)
            yellow=b.riverMaterial(V(0.67,0.43,0.08),roughness:0.9)
            seats=b.riverMaterial(V(0.38,0.11,0.085),roughness:0.65,metallic:0.15)
        }
    }
    private func millenniumArea(_ a:MillenniumContext.Area,y:Float,material:UInt32) {
        for i in stride(from:0,to:a.triangles.count,by:3) {
            let q=a.points[a.triangles[i]],r=a.points[a.triangles[i+1]],s=a.points[a.triangles[i+2]]
            tri(V(q[0],y,q[1]),V(s[0],y,s[1]),V(r[0],y,r[1]),material)
        }
    }
    private func millenniumInside(_ q:SIMD2<Float>,_ g:[[Float]])->Bool {
        var hit=false,j=g.count-1
        for i in g.indices {
            let a=g[i],b=g[j]
            if (a[1]>q.y) != (b[1]>q.y) && q.x<(b[0]-a[0])*(q.y-a[1])/(b[1]-a[1])+a[0] {hit.toggle()}
            j=i
        };return hit
    }
    private func millenniumPath(_ path:MillenniumContext.Path,material:UInt32) {
        for i in 1..<path.points.count {
            let q=path.points[i-1],r=path.points[i],a=V(q[0],0.125,q[1]),b=V(r[0],0.125,r[1]),d=b-a
            if simd_length_squared(d)<0.01{continue}
            let n=simd_normalize(V(-d.z,0,d.x))*path.width/2
            quad(a-n,a+n,b+n,b-n,material)
        }
    }
    private func millenniumHedge(_ a:MillenniumContext.Area,p:MillenniumPalette) {
        let h:Float=a.name.contains("shoulder") || a.name.contains("West Hedge") ? 4.1:1.1
        millenniumArea(a,y:h,material:p.hedge)
        for i in a.points.indices {
            let q=a.points[i],r=a.points[(i+1)%a.points.count],v=V(q[0],0.1,q[1]),w=V(r[0],0.1,r[1])
            quad(v,w,w+V(0,h,0),v+V(0,h,0),p.hedge)
            if h>3 {
                beam(v+V(0,h+0.8,0),w+V(0,h+0.8,0),0.13,0.15,p.dark)
                let len=simd_distance(v,w),t=(w-v)/max(0.01,len)
                for d in stride(from:Float(1),to:len,by:5) {let q=v+t*d;beam(q,q+V(0,h+0.8,0),0.15,0.15,p.dark)}
            }
        }
    }
    private func millenniumFlowerBed(_ a:MillenniumContext.Area,p:MillenniumPalette) {
        guard let f=a.points.first else{return}
        let x0=a.points.map{$0[0]}.min() ?? f[0],x1=a.points.map{$0[0]}.max() ?? f[0]
        let z0=a.points.map{$0[1]}.min() ?? f[1],z1=a.points.map{$0[1]}.max() ?? f[1]
        let lurie=x0>1120 && z0 > -341,spacing:Float=lurie ? 1.7:3.4
        for x in stride(from:x0+0.5,to:x1,by:spacing) {for z in stride(from:z0+0.5,to:z1,by:spacing) {
            let q=SIMD2(x+(rnd()-0.5)*0.6,z+(rnd()-0.5)*0.6)
            if !millenniumInside(q,a.points){continue}
            if q.x>1014 && q.x<1065 && q.y > -463 && q.y < -383{continue}
            let h:Float=0.4+rnd()*0.55,c=V(q.x,0.12,q.y),mat=Int((x+z)/9)%3 == 0 ? p.purple:p.pink
            for j in 0..<5 {
                let th=Float(j)*2.39996,v=V(cos(th)*0.32,h*(0.66+rnd()*0.3),sin(th)*0.32)
                beam(c,c+v,0.02,0.02,leaf)
                ellipsoid(c+v,V(0.085,0.18,0.085),lurie ? mat:p.yellow,segments:5,rings:3)
            }
        }}
    }
    private func millenniumTree(_ c:V,height:Float,p:MillenniumPalette) {
        cylinder(c,c+V(0,height*0.72,0),0.17,bark,segments:8)
        for j in 0..<5 {
            let th=Float(j)*2.39996,q=c+V(cos(th)*1.15,height*(0.64+Float(j%3)*0.06),sin(th)*1.15)
            cylinder(c+V(0,height*0.42,0),q,0.065,bark,segments:6)
            millenniumSmoothEllipsoid(q,V(1.85,2.2,1.85),j%3==0 ? leafLight:leaf,segments:12,rings:7)
        }
    }
    private func millenniumSmoothEllipsoid(_ c:V,_ r:V,_ material:UInt32,segments:Int=24,rings:Int=12) {
        func point(_ i:Int,_ j:Int)->(V,V) {
            let t=Float(i)*2 * .pi/Float(segments),f = -Float.pi/2+Float(j) * .pi/Float(rings)
            let n=V(cos(f)*cos(t),sin(f),cos(f)*sin(t))
            return(c+n*r,simd_normalize(n/r))
        }
        for j in 0..<rings {for i in 0..<segments {
            let a=point(i,j),b=point(i+1,j),c=point(i+1,j+1),d=point(i,j+1)
            if j>0{smoothTri(a.0,d.0,b.0,a.1,d.1,b.1,material)}
            if j<rings-1{smoothTri(b.0,d.0,c.0,b.1,d.1,c.1,material)}
        }}
    }

    /// Closed, smoothly shaded shell with a raised under-arch and concave omphalos.
    /// 10 × 20 × 12.8 m is Kapoor's published overall envelope. Surface is authored,
    /// not a laser scan. Reflects the actual Chicago BVH, never a painted skyline.
    private func cloudGate(p:MillenniumPalette) {
        let c=MillenniumContext.bean
        box(V(c.x,1.49,c.z),V(50,2.98,76),p.paving)
        // Precisely laid physical plaza joints are useful scale and reflection cues.
        for x in stride(from:c.x-25,through:c.x+25,by:2.5) {box(V(x,2.994,c.z),V(0.024,0.006,76),p.dark)}
        for z in stride(from:c.z-38,through:c.z+38,by:2.5) {box(V(c.x,2.995,z),V(50,0.006,0.024),p.dark)}
        // Broad staircase down towards McCormick Tribune Plaza, leaving the center
        // east-west arch aisle and its immediate landings completely unobstructed.
        for i in 0..<16 {
            let h=Float(i+1)*3/16,x=c.x-35+Float(i)*0.625
            box(V(x,h/2,c.z),V(0.63,h,27),p.paving)
        }
        for side:Float in [-1,1] {
            for i in 0..<12 {
                let h=Float(i+1)*0.25,z=c.z+side*(44-Float(i)*0.5)
                box(V(c.x,h/2,z),V(34,h,0.51),p.paving)
            }
        }
        func surface(_ t:Float,_ f:Float)->V {
            let r=cos(f),z=10*sin(f),x=6.4*r*cos(t),negative=max(0,-sin(t))
            let opening=exp(-pow(z/4.7,2))
            let omphalos=3.6+2.1*exp(-x*x/7.5)
            let foot=2.25*exp(-pow((abs(z)-6.8)/2.3,2))*pow(negative,3)
            let y=5+5*r*sin(t)+opening*omphalos*pow(negative,1.65)-foot
            return V(x,max(0.015,y),z)
        }
        let around=384,bands=224,e:Float=0.0003
        func vertex(_ i:Int,_ j:Int)->(V,V) {
            let t=Float(i)*2 * .pi/Float(around),f = -Float.pi/2+Float(j) * .pi/Float(bands)
            // Differentiate locally: subtracting ~1 km world positions first loses
            // small curvature changes to Float cancellation and makes mirrors sparkle.
            let q=c+surface(t,f)
            if j==0{return(q,V(0,0,-1))};if j==bands{return(q,V(0,0,1))}
            let dt=surface(t+e,f)-surface(t-e,f),df=surface(t,min(.pi/2,f+e))-surface(t,max(-.pi/2,f-e))
            let cross=simd_cross(dt,df)
            return(q,simd_length_squared(cross)>1e-12 ? simd_normalize(cross):V(0,-1,0))
        }
        var cache:[(V,V)]=[];cache.reserveCapacity((around+1)*(bands+1))
        for j in 0...bands {for i in 0...around{cache.append(vertex(i,j))}}
        for j in 0..<bands {for i in 0..<around {
            let a=cache[j*(around+1)+i],b=cache[j*(around+1)+i+1],d=cache[(j+1)*(around+1)+i],v=cache[(j+1)*(around+1)+i+1]
            if j>0{smoothTri(a.0,b.0,v.0,a.1,b.1,v.1,p.mirror)}
            if j<bands-1{smoothTri(a.0,v.0,d.0,a.1,v.1,d.1,p.mirror)}
        }}
        // Warm perimeter fixtures illuminate the plaza that is reflected in the shell.
        for side:Float in [-1,1] {for k:Float in [-1,0,1] {
            let q=c+V(side*23,0.12,k*30)
            box(q,V(0.42,0.16,0.30),p.dark)
            box(q+V(0,0.085,0),V(0.28,0.012,0.16),p.light)
            scene.lights.append(NightLighting.source(q+V(0,0.4,0),toward:c+V(0,3,0),power:130,color:V(1,0.80,0.57),range:36,radius:0.65,outerDegrees:90,innerDegrees:70))
        }}
        // Broad warm coverage comes from modeled perimeter floodlight poles. Raising
        // the sources gives the paving useful illumination across the entire plaza,
        // instead of grazing it with tiny intense ground pools.
        for sx:Float in [-1,1] {for sz:Float in [-1,1] {
            let base=c+V(sx*22,0,sz*34),head=base+V(0,9.2,0)
            cylinder(base,head,0.085,p.dark,segments:12)
            cylinder(base,base+V(0,0.35,0),0.23,p.dark,segments:16)
            for k:Float in [-1,1] {
                let light=head+V(k*0.55,0,0),target=c+V(k*10,0,sz*4)
                beam(head,light,0.10,0.10,p.dark)
                let n=simd_normalize(target-light),t=simd_normalize(simd_cross(n,V(0,1,0))),u=simd_cross(t,n)
                orientedBox(light,t,u,n,V(0.75,0.35,0.13),p.dark)
                orientedBox(light+n*0.075,t,u,n,V(0.59,0.24,0.025),p.light)
                scene.lights.append(NightLighting.source(light+n*0.16,toward:target,power:1150,color:V(1,0.79,0.52),range:66,radius:1.8,outerDegrees:56,innerDegrees:36))
            }
        }}
        scene.detailCount+=1
    }

    private func pritzkerPavilion(p:MillenniumPalette) {
        let c=MillenniumContext.pavilion
        box(c+V(0,0.65,1),V(37,1.3,20),timber)
        box(c+V(0,10,-9.7),V(37,20,0.6),p.dark)
        box(c+V(0,19.4,-0.8),V(37,0.55,18.5),timber)
        for x:Float in [-19,19] {box(c+V(x,10,0),V(0.7,20,20),timber)}
        for x in stride(from:Float(-17.5),through:17.5,by:1.25){box(c+V(x,11,-9.3),V(0.1,18,0.28),bronze)}
        for k in 0..<8 {box(c+V(0,0.95+Float(k)*0.23,-7+Float(k)*0.8),V(29,0.22,0.8),timber)}
        let controls:[[V]]=[
            [V(-47,8,1),V(-34,29,-9),V(-17,40,-15),V(2,33,-1)],
            [V(-12,31,-3),V(5,43,-18),V(37,31,-12),V(48,12,2)],
            [V(-39,10,7),V(-52,21,1),V(-33,28,-4),V(-20,17,4)],
            [V(20,17,5),V(37,30,-4),V(53,22,1),V(43,7,9)],
            [V(-33,16,-1),V(-16,23,12),V(9,27,9),V(27,18,0)],
            [V(-24,26,-8),V(-15,37,-22),V(15,35,-17),V(23,27,-6)]
        ]
        for (i,control) in controls.enumerated(){millenniumRibbon(control.map{c+V($0.x,$0.y*0.90,$0.z)},width:i<2 ? 13:9,material:p.steel)}
        // Two crossing families of tubular arcs make the characteristic acoustic trellis.
        for k in 0..<11 {
            let z:Float = -491+Float(k)*15.3,half:Float=50*sqrt(max(0.3,1-pow((z+411)/130,2)))
            var last=V(1163-half,3.6,z)
            for j in 1...48 {
                let t=Float(j)/48,q=V(1163-half+2*half*t,3.6+17*sin(t * .pi),z-4*sin(t * .pi))
                cylinder(last,q,0.27,p.steel,segments:10);last=q
            }
        }
        for k in 0..<7 {
            let x:Float=1118+Float(k)*15
            var last=V(x,6,-508)
            for j in 1...64 {
                let t=Float(j)/64,q=V(x+6*sin(t * .pi),6+15*sin(t * .pi),-508+t*191)
                cylinder(last,q,0.26,p.steel,segments:10);last=q
            }
        }
        for row in 0..<40 {for column in 0..<100 {
            if column%25==0{continue}
            let x=1131.2+Float(column)*0.63,z = -497+Float(row)*1.12
            box(V(x,0.57,z),V(0.48,0.13,0.48),p.seats)
            box(V(x,0.97,z+0.25),V(0.49,0.76,0.10),p.seats)
            for side:Float in [-1,1] {box(V(x+side*0.18,0.29,z),V(0.045,0.55,0.36),p.dark)}
        }}
        for x:Float in [-16,16] {
            for y in 0..<8 {box(c+V(x,11+Float(y)*0.6,2),V(1.2,0.55,0.7),p.dark)}
        }
        for z in stride(from:Float(-482),through:-342,by:28) {for x:Float in [1134,1164,1194] {
            cylinder(V(x,18,z),V(x,16.8,z),0.035,p.dark,segments:6)
            box(V(x,16.5,z),V(0.52,0.65,0.70),p.dark)
        }}
        for x:Float in [-35,-17,0,17,35] {
            scene.lights.append(NightLighting.source(c+V(x,2,14),toward:c+V(x*0.65,25,-4),power:900,color:x<0 ? V(0.51,0.42,1):V(0.86,0.58,1),range:50,radius:1.5,outerDegrees:75,innerDegrees:48))
        }
        scene.lights.append(NightLighting.source(c+V(0,15,3),toward:c+V(0,1,0),power:350,color:V(1,0.65,0.36),range:28,radius:2))
        for x:Float in [1134,1194] {for z:Float in [-463,-415,-367] {
            let q=V(x,16.0,z)
            box(q,V(0.50,0.16,0.64),p.dark)
            box(q-V(0,0.095,0),V(0.37,0.04,0.48),p.light)
            scene.lights.append(NightLighting.source(q-V(0,0.14,0),toward:V(1164,0,z),power:600,color:V(0.81,0.85,1),range:54,radius:2,outerDegrees:69,innerDegrees:44))
        }}
    }
    private func millenniumRibbon(_ p:[V],width:Float,material:UInt32) {
        let anchor=p[0],local=p.map{$0-anchor}
        func point(_ u:Float,_ v:Float)->V {
            let s:Float=1-u,c=local[0]*s*s*s+local[1]*(3*s*s*u)+local[2]*(3*s*u*u)+local[3]*u*u*u
            // Broad front-visible sheets curl through height and depth. Keeping width
            // only in Z turns the steel headdress into thin arcs when seen from lawn.
            let twist:Float=0.38+0.40*sin(u * .pi)
            return c+V(0,v*width*cos(twist),v*width*sin(twist)+v*v*width*0.6)
        }
        let n=72,m=14,e:Float=0.0005
        func sample(_ u:Float,_ v:Float)->(V,V) {
            let q=point(u,v),a=point(min(1,u+e),v)-point(max(0,u-e),v),b=point(u,v+e)-point(u,v-e)
            return(anchor+q,simd_normalize(simd_cross(a,b)))
        }
        for i in 0..<n {for j in 0..<m {
            let u=Float(i)/Float(n),v=Float(j)/Float(m)-0.5,u1=Float(i+1)/Float(n),v1=Float(j+1)/Float(m)-0.5
            let a=sample(u,v),b=sample(u1,v),c=sample(u1,v1),d=sample(u,v1)
            smoothTri(a.0,b.0,c.0,a.1,b.1,c.1,material);smoothTri(a.0,c.0,d.0,a.1,c.1,d.1,material)
        }}
        for i in stride(from:0,through:n,by:6) {
            let u=Float(i)/Float(n)
            for j in 0..<m {beam(anchor+point(u,Float(j)/Float(m)-0.5),anchor+point(u,Float(j+1)/Float(m)-0.5),0.015,0.018,ironDark)}
        }
    }

    private func crownFountain(p:MillenniumPalette) {
        let center=V(1008.41,0.15,-290.75)
        // OSM relation3154126 outer way126945426: 13.74 × 68.11 m.
        box(center-V(0,0.015,0),V(13.74,0.08,68.11),p.dark)
        quad(center+V(-6.87,0.031,-34.055),center+V(-6.87,0.031,34.055),center+V(6.87,0.031,34.055),center+V(6.87,0.031,-34.055),p.water)
        // Two opposing 50-foot towers, physical glass-block joints and cascades.
        // The LED display uses an original abstract water/sky color field; no person's
        // portrait or the artist's recorded video sequence is copied into this project.
        let display:[UInt32]=(0..<10).map {i in riverMaterial(V(0.20+Float(i)*0.022,0.33+Float(i)*0.022,0.45+Float(i)*0.014),roughness:0.20,metallic:0.25,emission:0.13+Float(i)*0.012,pattern:14)}
        for (c,direction):(V,Float) in [(V(1008.30,0.15,-316.18),1),(V(1009.75,0.15,-264.88),-1)] {
            box(c+V(0,7.62,0),V(6.75,15.24,4.6),p.block)
            for y in 0..<62 {for x in 0..<28 {
                let h=Float(y)*0.244+0.12,dx=Float(x)*0.24-3.255
                for side:Float in [-1,1] {
                    let front=side==direction,index=(x/5+y/9)%10
                    box(c+V(dx,h,side*2.31),V(0.225,0.228,0.09),front ? display[index]:p.block)
                }
            }}
            for side:Float in [-1,1] {for y in 0..<62 {for z in 0..<19 {
                box(c+V(side*3.39,Float(y)*0.244+0.12,Float(z)*0.24-2.16),V(0.09,0.228,0.225),p.block)
            }}}
            for side:Float in [-1,1] {
                let x=c.x+side*3.43
                for k in 0..<9 {let z=c.z+Float(k-4)*0.5;quad(V(x,0.25,z-0.13),V(x,15.30,z-0.13),V(x,15.30,z+0.13),V(x,0.25,z+0.13),p.water)}
            }
            // Static continuous stream and splash rings communicate the active fountain.
            var last=c+V(0,5,direction*2.38)
            for j in 1...22 {let t=Float(j)/22,q=c+V(0,5-4.85*t*t,direction*(2.38+t*3.4));cylinder(last,q,0.048,p.water,segments:8);last=q}
            scene.lights.append(NightLighting.source(c+V(0,4,direction*3),power:65,color:V(0.60,0.73,1),range:24,radius:1.8))
        }
    }
    private func millenniumMonument(p:MillenniumPalette) {
        let c=V(1002.6,0.14,-566.9)
        // 24 paired columns, 80-foot diameter and almost 40-foot overall height
        // documented by Chicago Public Library's original project archive.
        for radius:Float in [10.0,11.6] {for i in 0..<12 {
            let t=Float(i)*Float.pi/11,q=c+V(cos(t)*radius,0,-sin(t)*radius)
            cylinder(q,q+V(0,0.40,0),0.95,limestone,segments:24)
            cylinder(q+V(0,0.4,0),q+V(0,10.65,0),0.65,limestone,segments:24)
            cylinder(q+V(0,10.65,0),q+V(0,11.1,0),0.90,limestone,segments:24)
            for k in 0..<16 {let a=Float(k)*2 * .pi/16,n=V(cos(a)*0.66,0,sin(a)*0.66);cylinder(q+n+V(0,0.6,0),q+n+V(0,10.5,0),0.035,p.paving,segments:6)}
            if i<11 {
                let r=c+V(cos(Float(i+1)*Float.pi/11)*radius,11.35,-sin(Float(i+1)*Float.pi/11)*radius)
                beam(q+V(0,11.35,0),r,1.15,1.85,limestone)
            }
        }}
        cylinder(c+V(0,0.03,-0.3),c+V(0,0.15,-0.3),4.4,limestone,segments:64)
        cylinder(c+V(0,0.16,-0.3),c+V(0,0.17,-0.3),4.1,p.water,segments:64)
        cylinder(c+V(0,0.2,-0.3),c+V(0,2.2,-0.3),0.075,p.water,segments:12)
        for x:Float in [-10,0,10] {scene.lights.append(NightLighting.source(c+V(x,0.5,1.5),toward:c+V(x,6,-6),power:90,color:V(1,0.78,0.5),range:22,radius:0.8))}
    }
    private func millenniumBPBridge(p:MillenniumPalette) {
        // Mapped serpentine centerline, with a continuous accessible grade reaching
        // 4.6 m over Columbus Drive. Cross section/grade are reference interpretations.
        guard let bridge=MillenniumContext.database.landmarks.first(where:{$0.id==25026666}) else{return}
        let g=bridge.points
        guard g.count>3 else{return}
        var distances:[Float]=[0]
        for i in 1..<g.count {distances.append(distances[i-1]+simd_distance(SIMD2(g[i][0],g[i][1]),SIMD2(g[i-1][0],g[i-1][1])))}
        let total=distances.last ?? 1
        var points:[V]=[],normals:[V]=[]
        for i in g.indices {
            let t=distances[i]/total,h:Float=0.16+4.5*sin(t * .pi)
            points.append(V(g[i][0],h,g[i][1]))
            let a=g[max(0,i-1)],b=g[min(g.count-1,i+1)]
            normals.append(simd_normalize(V(a[1]-b[1],0,b[0]-a[0])))
        }
        for i in 1..<g.count {
            let a=points[i-1],b=points[i],u=normals[i-1],v=normals[i]
            quad(a-u*3.05,a+u*3.05,b+v*3.05,b-v*3.05,timber)
            for side:Float in [-1,1] {
                let q=a+u*side*3.18,r=b+v*side*3.18
                quad(q-V(0,0.26,0),r-V(0,0.26,0),r+V(0,1.18,0),q+V(0,1.18,0),p.steel)
                beam(q+V(0,1.18,0),r+V(0,1.18,0),0.11,0.14,p.steel)
                beam(q-V(0,0.26,0),r-V(0,0.26,0),0.25,0.17,p.steel)
            }
            let len=simd_distance(a,b)
            for d in stride(from:Float(0),to:len,by:0.36) {
                let t=d/max(len,0.01),c=a+(b-a)*t,n=simd_normalize(u+(v-u)*t)
                beam(c-n*3.02+V(0,0.004,0),c+n*3.02+V(0,0.004,0),0.018,0.015,p.dark)
            }
            if i%7==0 {
                scene.lights.append(NightLighting.source(a+u*2.9+V(0,0.8,0),power:15,color:V(1,0.81,0.62),range:12,radius:0.4))
            }
        }
    }
    private func millenniumFurniture(p:MillenniumPalette) {
        for x:Float in [1065,1095] {for z in stride(from:Float(-576),through:-246,by:27.5) {
            if z > -460 && z < -387{continue}
            let q=V(x,0.13,z)
            for leg:Float in [-0.85,0.85] {box(q+V(0,0.30,leg),V(0.58,0.60,0.12),p.dark)}
            for k in 0..<5 {box(q+V(Float(k-2)*0.105,0.55,0),V(0.09,0.075,2.2),timber)}
            box(q+V(-0.26,0.91,0),V(0.075,0.58,2.2),timber)
            streetLamp(q+V(1.8,0,3))
        }}
        // Globe lamps on Michigan Avenue and warm low garden paths, as in references.
        for z in stride(from:Float(-589),through:-236,by:28) {
            let c=V(977,0.1,z)
            cylinder(c,c+V(0,4.9,0),0.07,p.dark,segments:10)
            millenniumSmoothEllipsoid(c+V(0,5.1,0),V(0.33,0.4,0.33),p.light)
            scene.lights.append(NightLighting.source(c+V(0,5.0,0),power:90,color:V(1,0.79,0.58),range:32,radius:0.8))
        }
        for z in stride(from:Float(-324),through:-250,by:18) {
            let c=V(1118,0.18,z)
            box(c+V(0,0.55,0),V(0.2,1.1,0.2),p.dark)
            box(c+V(0,1.04,0),V(0.23,0.15,0.23),p.light)
            scene.lights.append(NightLighting.source(c+V(0,1.05,0),power:24,color:V(1,0.77,0.49),range:16,radius:0.5))
        }
        // Taller fixtures sit among the Dark Plate trees; the Shoulder Hedge's
        // steel armature carries path lighting, following the garden's design notes.
        for x:Float in [1188,1213] {for z:Float in [-309,-264] {
            let q=V(x,0.15,z),head=q+V(0,8.0,0)
            cylinder(q,head,0.055,p.dark,segments:10)
            box(head,V(0.70,0.18,0.42),p.dark)
            box(head-V(0,0.11,0),V(0.52,0.05,0.32),p.light)
            scene.lights.append(NightLighting.source(head-V(0,0.18,0),toward:V(1168,0.2,-284),power:560,color:V(1,0.84,0.63),range:62,radius:1.7,outerDegrees:72,innerDegrees:45))
        }}
    }

    private func millenniumServicePavilions(p:MillenniumPalette) {
        let solar=riverMaterial(V(0.027,0.05,0.065),roughness:0.16,metallic:0.73)
        let ids:Set<Int64>=[126977943,126977944,234847961,234847963]
        for b in MillenniumContext.database.landmarks where ids.contains(b.id) {
            guard let first=b.points.first else{continue}
            let x0=b.points.map{$0[0]}.min() ?? first[0],x1=b.points.map{$0[0]}.max() ?? first[0]
            let z0=b.points.map{$0[1]}.min() ?? first[1],z1=b.points.map{$0[1]}.max() ?? first[1]
            let north=b.id==234847961 || b.id==234847963,h:Float=b.id==234847963 ? 12:b.id==234847961 ? 8.2:4.0
            let center=V((x0+x1)/2,0.15,(z0+z1)/2)
            box(center+V(0,h/2,0),V(x1-x0,h,z1-z0),north ? solar:limestone)
            box(center+V(0,h+0.12,0),V(x1-x0+0.65,0.24,z1-z0+0.65),p.steel)
            for side:Float in [-1,1] {
                let z=center.z+side*(z1-z0)/2
                for x in stride(from:x0+0.6,to:x1-0.4,by:1.15) {
                    box(V(x,0.15+h/2,z+side*0.04),V(0.045,h,0.07),p.steel)
                }
                for y in stride(from:Float(1.2),to:h,by:1.4) {box(V(center.x,y,z+side*0.04),V(x1-x0,0.04,0.07),p.steel)}
            }
            box(center+V(0,1.45,(z1-z0)/2+0.06),V(3.0,2.8,0.1),solar)
            box(center+V(0,3.1,(z1-z0)/2+0.7),V(3.8,0.18,1.4),p.steel)
        }
    }
}
