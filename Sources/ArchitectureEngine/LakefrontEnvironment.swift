import Foundation
import simd

/// Mapped Chicago lakefront geometry in the same metre coordinate system as Willis.
enum LakefrontContext {
    struct Surface:Decodable {var id:Int64;var points:[[Float]];var triangles:[Int];var rings:[[[Float]]];var kind:String;var name:String}
    struct Tree:Decodable {var id:Int64;var point:[Float];var height:Float}
    struct Road:Decodable {var id:Int64;var points:[[Float]];var width:Float;var sourceIDs:[Int64];var length:Float}
    struct TrafficLane:Decodable {var id:Int64;var points:[[Float]];var speedMetresPerSecond:Float;var spawnFadeMetres:Float}
    struct Database:Decodable {
        var timestamp:String;var ground:Surface;var water:Surface;var namedWaters:[Surface]
        var buildings:[ChicagoContext.Building];var areas:[Surface];var paths:[ChicagoContext.Path]
        var piers:[ChicagoContext.Path];var breakwaters:[ChicagoContext.Path];var trees:[Tree]
        var roads:[Road];var trafficLanes:[TrafficLane]
        var railFloor:Surface;var rails:[ChicagoContext.Path];var railCrossings:[ChicagoContext.Path];var railGuards:[ChicagoContext.Path];var legacyAreas:[ChicagoContext.Area]
    }
    static let fountain=SIMD3<Float>(1404.55,0,342.20)
    static func containsAuthoredCampus(_ x:Float,_ z:Float)->Bool {
        // Parent footprints can be omitted from older extracts while newly mapped
        // building:part children remain. Suppress by site as well as known IDs.
        (x >= -49 && x<=59 && z >= -39 && z<=78) ||
        (x>=995.3 && x<=1157.9 && z >= -2164 && z <= -2095.4) ||
        (x>=943.7 && x<=959.5 && z >= -2044.6 && z <= -2028.5) ||
        (x>=1021.1 && x<=1147.8 && z >= -2247.1 && z <= -2187.6) ||
        (x>=984.9 && x<=1014.4 && z >= -2060.8 && z <= -2012.2)
    }
    static let replacementBuildingIDs:Set<Int64>=[31064573,232905278,232905280,232905283,232906397,232914185,279951771,279951772,1282265474,232935981,1282265459,64627674,590824927,130147025,148560424,686197567,686197572,686197576,127107038,284776088,284776089,1283005798,1283005799,1283005800,1283005801,1283005802,1283005803,1283005804]
    static let database:Database = {
        var urls:[URL]=[]
        if let r=Bundle.main.resourceURL {
            urls.append(r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/Lakefront/LakefrontContext.json"))
            urls.append(r.appendingPathComponent("Resources/Lakefront/LakefrontContext.json"))
        }
        urls.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json"))
        for u in urls {if let d=try?Data(contentsOf:u),let value=try?JSONDecoder().decode(Database.self,from:d){return value}}
        #if SWIFT_PACKAGE
        let u=Bundle.module.bundleURL.appendingPathComponent("Resources/Lakefront/LakefrontContext.json")
        if let d=try?Data(contentsOf:u),let value=try?JSONDecoder().decode(Database.self,from:d){return value}
        #endif
        fatalError("Bundled LakefrontContext.json is missing or invalid")
    }()
    static func inside(_ q:SIMD2<Float>,rings:[[[Float]]])->Bool {
        var result=false
        for ring in rings where ring.count>2 {
            var j=ring.count-1
            for i in ring.indices {
                let a=ring[i],b=ring[j]
                if (a[1]>q.y) != (b[1]>q.y) && q.x<(b[0]-a[0])*(q.y-a[1])/(b[1]-a[1])+a[0] {result.toggle()}
                j=i
            }
        };return result
    }
}

extension EiffelBuilder {
    func chicagoLakefront() {
        let data=LakefrontContext.database,p=LakefrontPalette(self),saved=randomState
        randomState=0x1970_CAFE_2026
        lakefrontSurface(NorthSideContext.database.legacyGround,y:-0.065,material:pavingForLakefront)
        lakefrontSurface(NorthSideContext.database.legacyWater,y:-5.7,material:p.water)
        // Water continues beyond the bounded derivative into the lake horizon.
        quad(V(6000,-5.7,-18000),V(6000,-5.7,18000),V(26000,-5.7,18000),V(26000,-5.7,-18000),p.water)
        for a in NorthSideContext.database.legacyAreas where !NorthSideContext.replacedAreaIDs.contains(a.id) {
            let y:Float=a.kind == "garden" ? 0.025:a.kind == "pitch" ? 0.019:a.kind == "park" ? -0.040:a.kind == "sand" ? -0.006:-0.012
            lakefrontSurface(a,y:y,material:a.kind == "sand" ? p.sand:grass)
            if a.kind == "garden" {lakefrontGarden(a,p:p)}
        }
        for road in data.roads {lakefrontDrive(road,p:p)}
        for pier in data.piers {lakefrontPier(pier,p:p)}
        for wall in data.breakwaters where (wall.points.first?[0] ?? 0)>1200 {lakefrontSeawall(wall,p:p)}
        for tree in data.trees where !MuseumCampusContext.clearsApproach(tree.point[0],tree.point[1]) && !NorthSideContext.containsAuthoredSite(tree.point[0],tree.point[1]) {lakefrontTree(tree,p:p)}
        lakefrontRailway(p:p)
        buckinghamFountain(p:p)
        lakefrontBoats(p:p)
        lakefrontParkFurniture(p:p)
        scene.trafficLanes=data.trafficLanes.map {SceneTrafficLane(id:$0.id,points:$0.points.map{V($0[0],$0[1],$0[2])},speedMetresPerSecond:$0.speedMetresPerSecond,spawnFadeMetres:$0.spawnFadeMetres)}
        randomState=saved
    }
    private var pavingForLakefront:UInt32 {pavement}
    struct LakefrontPalette {
        var water:UInt32;var paving:UInt32;var sand:UInt32;var dark:UInt32;var white:UInt32;var stone:UInt32
        var bronze:UInt32;var foam:UInt32;var asphalt:UInt32;var light:UInt32;var glass:UInt32;var hull:UInt32;var red:UInt32;var dock:UInt32;var cabin:UInt32
        init(_ b:EiffelBuilder) {
            water=b.riverMaterial(V(0.016,0.064,0.073),roughness:0.09,pattern:9)
            paving=b.riverMaterial(V(0.63,0.58,0.49),roughness:0.73,pattern:1)
            sand=b.riverMaterial(V(0.67,0.57,0.39),roughness:0.94,pattern:10)
            dark=b.riverMaterial(V(0.055,0.061,0.062),roughness:0.43,metallic:0.58)
            white=b.riverMaterial(V(0.78,0.80,0.77),roughness:0.30)
            stone=b.riverMaterial(V(0.48,0.29,0.23),roughness:0.43,pattern:10)
            bronze=b.riverMaterial(V(0.11,0.27,0.22),roughness:0.50,metallic:0.65)
            foam=b.riverMaterial(V(0.76,0.84,0.83),roughness:0.26)
            asphalt=b.riverMaterial(V(0.055,0.06,0.064),roughness:0.88,pattern:11)
            light=b.riverMaterial(V(0.97,0.81,0.58),roughness:0.35,emission:0.15,pattern:14)
            glass=b.riverMaterial(V(0.08,0.15,0.18),roughness:0.10,metallic:0.72)
            hull=b.riverMaterial(V(0.028,0.075,0.15),roughness:0.22,metallic:0.20)
            red=b.riverMaterial(V(0.48,0.07,0.025),roughness:0.48)
            dock=b.riverMaterial(V(0.36,0.36,0.32),roughness:0.78,pattern:10)
            cabin=b.riverMaterial(V(0.11,0.18,0.20),roughness:0.13,metallic:0.6,emission:0.11,pattern:14)
        }
    }
    func lakefrontSurface(_ a:LakefrontContext.Surface,y:Float,material:UInt32) {
        for i in stride(from:0,to:a.triangles.count,by:3) {
            let q=a.points[a.triangles[i]],r=a.points[a.triangles[i+1]],s=a.points[a.triangles[i+2]]
            tri(V(q[0],y,q[1]),V(s[0],y,s[1]),V(r[0],y,r[1]),material)
        }
    }
    func lakefrontDrive(_ road:LakefrontContext.Road,p:LakefrontPalette,drawSurface:Bool = true) {
        let points=road.points.map{V($0[0],$0[1],$0[2])}
        for i in 1..<points.count {
            let a=points[i-1],b=points[i],d=b-a,len=simd_length(d)
            guard len>0.01 else {continue}
            let t=d/len,n=simd_normalize(V(-t.z,0,t.x)),half=road.width/2
            if drawSurface {quad(a-n*half,a+n*half,b+n*half,b-n*half,p.asphalt)}
            // The upper road has a visible deck; no invented road is connected across a gap.
            if a.y>0.3 {orientedBox((a+b)/2-V(0,0.35,0),n,V(0,1,0),t,V(road.width,0.65,len+0.015),p.dark)}
            for offset:Float in [-5.325,-1.775,1.775,5.325] {
                if abs(offset)>5 || i%2==0 {
                    let aa=a+n*offset+V(0,0.009,0),bb=b+n*offset+V(0,0.009,0)
                    quad(aa-n*0.06,aa+n*0.06,bb+n*0.06,bb-n*0.06,p.white)
                }
            }
            for side:Float in [-1,1] {
                beam(a+n*side*(half-0.12)+V(0,0.40,0),b+n*side*(half-0.12)+V(0,0.40,0),0.24,0.72,p.paving)
                if i%3==0 {beam(a+n*side*(half-0.12),a+n*side*(half-0.12)+V(0,0.85,0),0.09,0.09,p.dark)}
            }
            if i%14==0 && a.z > -3900 && a.z<1700 {
                let c=a+n*(half+0.7),top=c+V(0,11,0),lamp=top-n*3.7
                cylinder(c,top,0.14,p.dark,segments:8);beam(top,lamp,0.13,0.13,p.dark)
                orientedBox(lamp,n,V(0,1,0),t,V(1.0,0.14,0.42),p.light)
                scene.lights.append(NightLighting.source(lamp-V(0,0.12,0),toward:a-n*2,power:115,color:V(1,0.86,0.68),range:42,radius:0.7,outerDegrees:74,innerDegrees:43))
            }
            if i%16==0 && a.y>2 {box(a-V(0,(a.y+5.5)/2,0),V(1.7,a.y+5.5,3.2),p.paving)}
        }
    }
    func lakefrontPier(_ pier:ChicagoContext.Path,p:LakefrontPalette) {
        for i in 1..<pier.points.count {
            let q=pier.points[i-1],r=pier.points[i],a=V(q[0],-5.20,q[1]),b=V(r[0],-5.20,r[1]),len=simd_distance(a,b)
            guard len>0.05 else{continue};let t=(b-a)/len,n=V(-t.z,0,t.x),w=pier.width
            orientedBox((a+b)/2,n,V(0,1,0),t,V(w,0.34,len+0.02),p.dock)
            for side:Float in [-1,1] {beam(a+n*side*w/2-V(0,0.16,0),b+n*side*w/2-V(0,0.16,0),0.10,0.28,p.dark)}
            let near=a.z > -950 && a.z < -570
            for d in stride(from:Float(0.6),to:len,by:near ? 1.2:3) {
                let c=a+t*d+V(0,0.177,0)
                beam(c-n*w*0.49,c+n*w*0.49,0.014,0.012,p.dark)
            }
            if len>7 {
                let c=b-t*1.2
                cylinder(c-V(0,2.5,0),c+V(0,0.62,0),0.16,p.dark,segments:8)
                cylinder(c+V(0,0.62,0),c+V(0,0.7,0),0.21,p.white,segments:8)
                if near && pier.id%4==0 {
                    box(c+V(0,0.65,0)+n*0.50,V(0.23,1.25,0.24),p.white)
                    box(c+V(0,1.29,0)+n*0.50,V(0.25,0.07,0.26),p.light)
                    scene.lights.append(NightLighting.source(c+V(0,1.3,0)+n*0.5,toward:c+V(0,-1,0),power:22,color:V(1,0.85,0.69),range:16,radius:0.3,outerDegrees:88,innerDegrees:64))
                }
            }
        }
    }
    func lakefrontSeawall(_ wall:ChicagoContext.Path,p:LakefrontPalette) {
        for i in 1..<wall.points.count {
            let a=V(wall.points[i-1][0],-3.05,wall.points[i-1][1]),b=V(wall.points[i][0],-3.05,wall.points[i][1]),d=b-a,len=simd_length(d)
            guard len>0.1 else{continue};let t=d/len,n=V(-t.z,0,t.x)
            orientedBox((a+b)/2,n,V(0,1,0),t,V(wall.width,5.7,len),p.paving)
            beam(a+V(0,2.88,0),b+V(0,2.88,0),wall.width+0.12,0.24,p.paving)
            for d in stride(from:Float(1),to:len,by:8) {
                let c=a+t*d
                for s:Float in [-1,1] {orientedBox(c+n*s*(wall.width/2+0.4)-V(0,1.7,0),n,V(0,1,0),t,V(1.8,0.8,2.9),limestone)}
            }
        }
    }
    private func lakefrontTree(_ tree:LakefrontContext.Tree,p:LakefrontPalette) {
        let c=V(tree.point[0],0,tree.point[1]),h=tree.height
        let d=min(simd_distance(c,LakefrontContext.fountain),simd_distance(c,V(980,0,-2120)),simd_distance(c,V(1760,0,-580)))
        let near=d<260,medium=d<800
        cylinder(c,c+V(0,h*0.68,0),near ? 0.20:0.16,bark,segments:near ? 8:5)
        let crowns=near ? 5:medium ? 3:1
        for j in 0..<crowns {
            let th=Float(j)*2.39996+Float(tree.id%31),radius:Float=crowns==1 ? 0:1.4
            let v=c+V(cos(th)*radius,h*(0.68+Float(j%3)*0.055),sin(th)*radius)
            if near {cylinder(c+V(0,h*0.4,0),v,0.07,bark,segments:5)}
            lakefrontSmoothCrown(v,V(crowns==1 ? h*0.29:2.2,h*0.27,crowns==1 ? h*0.29:2.2),j%3==0 ? leafLight:leaf,segments:near ? 12:8,rings:near ? 7:4)
        }
    }
    private func lakefrontRailway(p:LakefrontPalette) {
        let data=LakefrontContext.database
        lakefrontSurface(data.railFloor,y:-7.2,material:p.dock)
        for ring in data.railFloor.rings {for i in ring.indices {
            let a=V(ring[i][0],-3.64,ring[i][1]),b=V(ring[(i+1)%ring.count][0],-3.64,ring[(i+1)%ring.count][1])
            beam(a,b,0.34,7.15,p.paving)
        }}
        for guardLine in data.railGuards {for i in 1..<guardLine.points.count {
            let a=V(guardLine.points[i-1][0],0,guardLine.points[i-1][1]),b=V(guardLine.points[i][0],0,guardLine.points[i][1])
            beam(a+V(0,0.98,0),b+V(0,0.98,0),0.045,0.06,p.dark)
            let len=simd_distance(a,b)
            if len>0.05 {
                let t=(b-a)/len
                for d in stride(from:Float(0),to:len,by:2.2) {let c=a+t*d;beam(c,c+V(0,1.0,0),0.05,0.05,p.dark)}
            }
        }}
        for track in data.rails {
            for i in 1..<track.points.count {
                let q=track.points[i-1],r=track.points[i],a=V(q[0],-7.0,q[1]),b=V(r[0],-7.0,r[1]),len=simd_distance(a,b)
                guard len>0.05 else{continue};let t=(b-a)/len,n=V(-t.z,0,t.x)
                for side:Float in [-1,1] {
                    beam(a+n*side*0.7175,b+n*side*0.7175,0.07,0.13,p.dark)
                    beam(a+n*side*0.7175+V(0,0.075,0),b+n*side*0.7175+V(0,0.075,0),0.062,0.018,p.white)
                }
                for d in stride(from:Float(0.3),to:len,by:0.72) {orientedBox(a+t*d-V(0,0.11,0),n,V(0,1,0),t,V(2.55,0.13,0.22),timber)}
                if len>35 && track.id%3==0 {
                    for d in stride(from:Float(20),to:len,by:45) {
                        let c=a+t*d+n*2.4,top=c+V(0,5.4,0)
                        cylinder(c,top,0.075,p.dark,segments:6)
                        beam(top,top-n*3.0,0.07,0.09,p.dark)
                    }
                }
                beam(a+V(0,5.15,0),b+V(0,5.15,0),0.012,0.012,p.dark)
            }
        }
        for crossing in data.railCrossings {for i in 1..<crossing.points.count {
            let q=crossing.points[i-1],r=crossing.points[i],a=V(q[0],-0.40,q[1]),b=V(r[0],-0.40,r[1]),len=simd_distance(a,b)
            guard len>0.05 else{continue};let t=(b-a)/len,n=V(-t.z,0,t.x)
            orientedBox((a+b)/2,n,V(0,1,0),t,V(crossing.width,0.83,len+1.2),p.paving)
        }}
    }
    func lakefrontSmoothCrown(_ c:V,_ r:V,_ material:UInt32,segments:Int,rings:Int) {
        func vertex(_ i:Int,_ j:Int)->(V,V) {
            let t=Float(i)*2 * .pi/Float(segments),f = -Float.pi/2+Float(j) * .pi/Float(rings)
            let n=V(cos(f)*cos(t),sin(f),cos(f)*sin(t))
            return(c+n*r,simd_normalize(n/r))
        }
        for j in 0..<rings {for i in 0..<segments {
            let a=vertex(i,j),b=vertex(i+1,j),c=vertex(i+1,j+1),d=vertex(i,j+1)
            if j>0 {smoothTri(a.0,d.0,b.0,a.1,d.1,b.1,material)}
            if j<rings-1 {smoothTri(b.0,d.0,c.0,b.1,d.1,c.1,material)}
        }}
    }
    private func lakefrontGarden(_ a:LakefrontContext.Surface,p:LakefrontPalette) {
        guard !a.points.isEmpty else{return}
        let c=a.points.reduce(SIMD2<Float>.zero){$0+SIMD2($1[0],$1[1])}/Float(a.points.count)
        guard simd_distance(c,SIMD2(1404.55,342.20))<260 else{return}
        for ring in a.rings {for i in ring.indices {
            let q=ring[i],r=ring[(i+1)%ring.count],a=V(q[0],0.14,q[1]),b=V(r[0],0.14,r[1])
            beam(a,b,0.18,0.20,p.paving)
        }}
        let x0=a.points.map{$0[0]}.min()!,x1=a.points.map{$0[0]}.max()!,z0=a.points.map{$0[1]}.min()!,z1=a.points.map{$0[1]}.max()!
        for x in stride(from:x0+1,to:x1,by:3) {for z in stride(from:z0+1,to:z1,by:3) {
            if !LakefrontContext.inside(SIMD2(x,z),rings:a.rings){continue}
            ellipsoid(V(x,0.26,z),V(0.85,0.3,0.85),leaf,segments:7,rings:4)
            for j in 0..<3 {let th=Float(j)*2.4;ellipsoid(V(x+cos(th)*0.45,0.55,z+sin(th)*0.45),V(0.12,0.13,0.12),a.id%2==0 ? p.red:p.white,segments:5,rings:3)}
        }}
    }
    private func lakefrontRing(_ c:V,r:Float,y:Float,width:Float,height:Float,material:UInt32,segments:Int=128) {
        for i in 0..<segments {
            let t=Float(i)*2 * .pi/Float(segments),u=Float(i+1)*2 * .pi/Float(segments)
            let a=c+V(cos(t)*r,y,sin(t)*r),b=c+V(cos(u)*r,y,sin(u)*r)
            beam(a,b,width,height,material)
        }
    }
    private func lakefrontJet(_ a:V,_ b:V,apex:Float,radius:Float,material:UInt32,steps:Int=24) {
        var last=a
        for i in 1...steps {let t=Float(i)/Float(steps),q=a+(b-a)*t+V(0,4*apex*t*(1-t),0);cylinder(last,q,radius*(1-0.35*t),material,segments:6);last=q}
    }
    private func buckinghamFountain(p:LakefrontPalette) {
        let c=LakefrontContext.fountain
        cylinder(c-V(0,0.05,0),c+V(0,0.045,0),59,p.paving,segments:192)
        cylinder(c+V(0,0.05,0),c+V(0,0.15,0),42.67,p.stone,segments:192)
        cylinder(c+V(0,0.16,0),c+V(0,0.23,0),41.8,p.water,segments:192)
        lakefrontRing(c,r:42.3,y:0.50,width:0.84,height:0.70,material:p.stone,segments:192)
        // Published basin diameters and top height; profiles interpret wet Georgia marble.
        for tier in [(Float(15.70),Float(2.2)),(Float(9.14),Float(4.75)),(Float(3.658),Float(7.62))] {
            let r=tier.0,y=tier.1
            cylinder(c+V(0,0.2,0),c+V(0,y-0.32,0),r*0.56,p.stone,segments:96)
            cylinder(c+V(0,y-0.35,0),c+V(0,y-0.15,0),r,p.stone,segments:128)
            cylinder(c+V(0,y-0.13,0),c+V(0,y-0.06,0),r*0.975,p.water,segments:128)
            lakefrontRing(c,r:r,y:y,width:0.46,height:0.37,material:p.stone)
            for j in 0..<32 {
                let a=Float(j)*2 * .pi/32,n=V(cos(a),0,sin(a)),t=V(-sin(a),0,cos(a))
                orientedBox(c+n*r*0.56+V(0,(y-0.35)/2,0),t,V(0,1,0),n,V(r*0.09,y-0.35,0.8),p.stone)
                let lower:Float=r>15 ? 0.26:r>9 ? 2.20:4.75
                for k in 0..<4 {
                    let angle=a+Float(k)*0.046,start=c+V(cos(angle)*r,y-0.04,sin(angle)*r),end=c+V(cos(angle)*(r+0.55),lower,sin(angle)*(r+0.55))
                    lakefrontJet(start,end,apex:0.15,radius:0.038,material:p.foam,steps:12)
                }
            }
        }
        // Four stylized cast-bronze sea-horse groups, connected curling tails and fins.
        for side in 0..<4 {
            let a=Float(side) * .pi/2,n=V(cos(a),0,sin(a)),t=V(-sin(a),0,cos(a)),base=c+n*22
            cylinder(base+V(0,0.25,0),base+V(0,0.7,0),3.1,p.stone,segments:48)
            for s:Float in [-1,1] {
                let body=base+t*s*1.2+V(0,1.5,0)
                ellipsoid(body,V(1.2,0.8,1.2),p.bronze,segments:16,rings:10)
                var last=body
                for k in 1...14 {
                    let f=Float(k)/14,q=body+n*(-1.2*f)+V(0,2.6*sin(f * .pi*0.55),0)
                    cylinder(last,q,0.48*(1-f*0.55),p.bronze,segments:10);last=q
                }
                ellipsoid(last+n*0.30,V(0.38,0.52,0.63),p.bronze,segments:16,rings:8)
                for k in 0..<9 {
                    let f=Float(k)*0.25,q=body+n*(1.6+cos(f)*0.85)+V(0,sin(f)*0.6-0.3,0)
                    if k>0 {cylinder(body+n*(1.6+cos(f-0.25)*0.85)+V(0,sin(f-0.25)*0.6-0.3,0),q,0.28-Float(k)*0.018,p.bronze,segments:8)}
                }
                for k in 0..<5 {let q=body+V(0,0.5,0)+n*Float(k-2)*0.22;tri(q-t*0.5,q+V(0,0.9,0),q+t*0.5,p.bronze)}
                lakefrontJet(last+n*0.35,base+n*12+t*s*1.2+V(0,0.24,0),apex:2.6,radius:0.085,material:p.foam)
            }
        }
        for j in 0..<48 {
            let a=Float(j)*2 * .pi/48,n=V(cos(a),0,sin(a))
            lakefrontJet(c+n*29+V(0,0.27,0),c+n*17+V(0,0.28,0),apex:3.9,radius:0.055,material:p.foam)
        }
        for j in 0..<20 {
            let a=Float(j)*2 * .pi/20,n=V(cos(a),0,sin(a))
            lakefrontJet(c+n*1.2+V(0,7.7,0),c+n*4.2+V(0,4.8,0),apex:5.5+Float(j%3)*0.4,radius:0.075,material:p.foam)
        }
        for j in 0..<20 {
            let a=Float(j)*2 * .pi/20,n=V(cos(a),0,sin(a)),pos=c+n*31+V(0,0.65,0)
            cylinder(pos-V(0,0.14,0),pos,0.30,p.dark,segments:12)
            scene.lights.append(NightLighting.source(pos,toward:c+V(0,5,0),power:600,color:V(1,0.76,0.51),range:55,radius:0.85,outerDegrees:62,innerDegrees:40))
        }
        scene.detailCount+=4
    }
    private func lakefrontBoats(p:LakefrontPalette) {
        let data=LakefrontContext.database
        // DuSable slips follow the mapped perpendicular fingers. Hulls are authored,
        // representative summer occupancy, never treated as surveyed boat positions.
        for pier in data.piers where pier.id>100_000_000 && pier.id%3 != 0 && pier.id != 1009745881 {
            guard let first=pier.points.first,let last=pier.points.last,first[1] > -925,first[1] < -590,first[0]>1925,first[0]<2080 else{continue}
            let dz=last[1]-first[1]
            guard abs(dz)>8,abs(dz)<35,abs(last[0]-first[0])<1 else{continue}
            // Three-node fingers straddle a transverse dock. Use just one arm,
            // keeping the hull outside the central walkway and its end clearance.
            let end=pier.points.count==3 ? pier.points[1]:last
            let length=min(abs(end[1]-first[1])-3.2,10.5+Float(pier.id%4)*0.65)
            guard length>6 else{continue}
            let c=V(first[0]+3.65,-5.7,(first[1]+end[1])/2)
            lakefrontBoat(c,length:length,angle:0,sailboat:pier.id%4 != 0,detailed:true,p:p)
        }
        if let monroe=data.namedWaters.first(where:{$0.id==17766901}) {
            for row in 0..<22 {for col in 0..<9 {
                let x:Float=1668+Float(col)*49+Float(row%2)*23,z:Float = -494+Float(row)*66
                if !LakefrontContext.inside(SIMD2(x,z),rings:monroe.rings){continue}
                let length:Float=9.2+Float((row*7+col*3)%7)*0.55,angle:Float=0.14+Float((row+col)%5)*0.06
                lakefrontBoat(V(x,-5.7,z),length:length,angle:angle,sailboat:(row+col)%7 != 0,detailed:z < -200,p:p)
                cylinder(V(x-1,-5.72,z-11),V(x-1,-5.32,z-11),0.34,p.white,segments:10)
                beam(V(x,-5.05,z-length/2),V(x-1,-5.35,z-11),0.025,0.025,timber)
            }}
        }
    }
    func lakefrontBoat(_ c:V,length:Float,angle:Float,sailboat:Bool,detailed:Bool,p:LakefrontPalette) {
        let forward=V(sin(angle),0,cos(angle)),right=V(cos(angle),0,-sin(angle)),up=V(0,1,0),w=length*0.285
        func at(_ x:Float,_ y:Float,_ z:Float)->V {c+right*x+up*y+forward*z}
        let stations=20,boatSeed=abs(Int(c.x*7+c.z*13)),hullMaterial=boatSeed%3==0 ? p.white:p.hull
        let windows=boatSeed%4==0 ? p.cabin:p.glass
        for j in 0..<stations {
            let s=Float(j)/Float(stations),t=Float(j+1)/Float(stations)
            func width(_ f:Float)->Float {w*0.5*pow(max(0.01,sin(f * .pi)),0.55)*(0.76+0.24*f)}
            for side:Float in [-1,1] {
                let a=at(side*width(s),0.76,(s-0.5)*length),b=at(side*width(t),0.76,(t-0.5)*length)
                quad(a,b,at(side*width(t)*0.45,-0.7,(t-0.5)*length),at(side*width(s)*0.45,-0.7,(s-0.5)*length),hullMaterial)
                quad(a,b,at(0,0.78,(t-0.5)*length),at(0,0.78,(s-0.5)*length),timber)
                beam(a+up*0.03,b+up*0.03,0.065,0.09,p.white)
            }
        }
        orientedBox(at(0,1.14,0),right,up,forward,V(w*0.72,0.76,length*0.36),p.white)
        orientedBox(at(0,1.55,-0.15),right,up,forward,V(w*0.61,0.06,length*0.30),p.white)
        for side:Float in [-1,1] {for j in 0..<3 {
            orientedBox(at(side*w*0.365,1.22,Float(j-1)*length*0.075),forward,up,right,V(length*0.065,0.30,0.028),windows)
        }}
        if sailboat {
            let mast=at(0,0.9,-length*0.14),top=mast+up*length*1.14
            cylinder(mast,top,0.055,p.white,segments:8)
            beam(mast+up*1.35,at(0,2.25,length*0.32),0.12,0.15,p.hull)
            // Moored yachts carry furled sails: visible booms and standing rigging.
            if detailed {
                for side:Float in [-1,1] {beam(top,at(side*w*0.4,0.75,0),0.014,0.014,p.dark)}
                beam(top,at(0,0.66,-length*0.49),0.014,0.014,p.dark)
                beam(top,at(0,0.66,length*0.48),0.014,0.014,p.dark)
                beam(top-up*length*0.4-right*w*0.38,top-up*length*0.4+right*w*0.38,0.028,0.028,p.white)
            }
        } else {
            orientedBox(at(0,1.65,0.2),right,up,forward,V(w*0.72,0.75,length*0.25),p.glass)
            orientedBox(at(0,2.08,0.2),right,up,forward,V(w*0.85,0.13,length*0.33),p.white)
            beam(at(0,2.1,0.6),at(0,3.6,0.6),0.025,0.025,p.white)
        }
        if detailed {
            for side:Float in [-1,1] {
                for j in 1..<8 {
                    let f=Float(j)/8,x=side*w*0.46*pow(sin(f * .pi),0.55),z=(f-0.5)*length
                    beam(at(x,0.65,z),at(x,1.22,z),0.024,0.024,p.white)
                    if j<7 {let g=Float(j+1)/8;beam(at(x,1.22,z),at(side*w*0.46*pow(sin(g * .pi),0.55),1.22,(g-0.5)*length),0.018,0.018,p.white)}
                }
                for j in 0..<3 {ellipsoid(at(side*w*0.49,0.22,Float(j-1)*1.7),V(0.15,0.40,0.15),p.white,segments:8,rings:5)}
            }
            orientedBox(at(0,1.18,length*0.37),right,up,forward,V(w*0.50,0.06,0.65),timber)
        }
        scene.detailCount+=1
    }
    private func lakefrontParkFurniture(p:LakefrontPalette) {
        let c=LakefrontContext.fountain
        for j in 0..<32 {
            let a=Float(j)*2 * .pi/32,n=V(cos(a),0,sin(a)),t=V(-sin(a),0,cos(a)),q=c+n*54
            if j%4==0 {continue}
            orientedBox(q+V(0,0.50,0),t,V(0,1,0),n,V(1.75,0.10,0.55),leaf)
            orientedBox(q+n*0.24+V(0,0.87,0),t,V(0,1,0),n,V(1.75,0.58,0.08),leaf)
            for s:Float in [-1,1] {box(q+t*s*0.67+V(0,0.26,0),V(0.08,0.5,0.48),p.dark)}
        }
        for row:Float in [-1,1] {for i in -4...4 {
            let q=c+V(Float(i)*32,0,row*103)
            cylinder(q,q+V(0,5.2,0),0.085,p.dark,segments:8)
            ellipsoid(q+V(0,5.45,0),V(0.25,0.32,0.25),p.light,segments:12,rings:8)
            scene.lights.append(NightLighting.source(q+V(0,5.4,0),toward:q,power:125,color:V(1,0.82,0.59),range:32,radius:0.45,outerDegrees:86,innerDegrees:56))
        }}
        for j in 0..<12 {
            let a=Float(j)*2 * .pi/12,q=c+V(cos(a)*70,0,sin(a)*70)
            cylinder(q,q+V(0,5.2,0),0.085,p.dark,segments:8)
            ellipsoid(q+V(0,5.45,0),V(0.25,0.32,0.25),p.light,segments:12,rings:8)
            scene.lights.append(NightLighting.source(q+V(0,5.4,0),toward:q,power:145,color:V(1,0.82,0.59),range:34,radius:0.5,outerDegrees:85,innerDegrees:52))
        }
        for x:Float in [1245,1512] {for z in stride(from:Float(15),through:705,by:46) {
            let q=V(x,0,z)
            cylinder(q,q+V(0,5.6,0),0.095,p.dark,segments:8)
            ellipsoid(q+V(0,5.84,0),V(0.23,0.28,0.23),p.light,segments:10,rings:6)
            scene.lights.append(NightLighting.source(q+V(0,5.8,0),toward:q,power:125,color:V(1,0.83,0.64),range:32,radius:0.45,outerDegrees:87,innerDegrees:59))
        }}
        // Broad floodlights on the marina perimeter, with visible poles and heads.
        for z in stride(from:Float(-615),through:-880,by:-53) {
            let q=V(1917,0,z),lamp=q+V(0,7.5,0)
            cylinder(q,lamp,0.12,p.dark,segments:8)
            box(lamp,V(0.45,0.18,0.60),p.light)
            scene.lights.append(NightLighting.source(lamp,toward:V(1970,-5,z),power:520,color:V(1,0.86,0.72),range:95,radius:0.85,outerDegrees:67,innerDegrees:42))
        }
    }
}
