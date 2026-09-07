import Foundation
import simd

/// Offline ODbL map geometry in metres east / south of Willis Tower.
/// The mapped outlines/heights are distinct from the authored facade interpretation.
enum ChicagoContext {
    struct Building:Decodable {
        var id:Int64;var points:[[Float]];var triangles:[Int];var height:Float
        var heightSource:String;var name:String;var kind:String;var material:String;var color:String
        var isPart:Bool;var hasHoles:Bool
    }
    struct Area:Decodable {var id:Int64;var points:[[Float]];var triangles:[Int];var kind:String;var name:String}
    struct Path:Decodable {var id:Int64;var points:[[Float]];var width:Float;var kind:String;var name:String;var bridge:String}
    struct Database:Decodable {var timestamp:String;var buildings:[Building];var areas:[Area];var paths:[Path];var bridges:[Path];var rivers:[Area];var ground:[[[Float]]]}
    static let database:Database = {
        var urls:[URL]=[]
        if let r=Bundle.main.resourceURL {
            urls.append(r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/Chicago/ChicagoContext.json"))
            urls.append(r.appendingPathComponent("Resources/Chicago/ChicagoContext.json"))
        }
        urls.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json"))
        for u in urls {if let d=try?Data(contentsOf:u),let value=try?JSONDecoder().decode(Database.self,from:d){return value}}
        // Do not evaluate SwiftPM's generated absolute build-path fallback until
        // the app's self-contained Resources bundle has been tried successfully.
        #if SWIFT_PACKAGE
        let packageURL=Bundle.module.bundleURL.appendingPathComponent("Resources/Chicago/ChicagoContext.json")
        if let data=try?Data(contentsOf:packageURL),let value=try?JSONDecoder().decode(Database.self,from:data) {return value}
        #endif
        fatalError("The bundled ChicagoContext.json database is missing or invalid.")
    }()
}

extension EiffelBuilder {
    func chicagoEnvironment() {
        let data=ChicagoContext.database
        let asphalt=riverMaterial(V(0.070,0.076,0.080),roughness:0.91,pattern:11)
        let concrete=riverMaterial(V(0.48,0.48,0.445),roughness:0.81,pattern:10)
        let masonry=riverMaterial(V(0.49,0.37,0.31),roughness:0.84,pattern:10)
        let granite=riverMaterial(V(0.39,0.35,0.33),roughness:0.68,pattern:1)
        let pale=riverMaterial(V(0.65,0.64,0.58),roughness:0.8,pattern:10)
        let blue=riverMaterial(V(0.105,0.17,0.19),roughness:0.19,metallic:0.6,pattern:7)
        let gray=riverMaterial(V(0.22,0.24,0.245),roughness:0.55,metallic:0.32)
        let windows: [UInt32] = [0,0.065,0.095,0.135,0.19].map { riverMaterial(V(0.105,0.17,0.19),roughness:0.13,metallic:0.72,emission:Float($0),pattern:14) }
        let white=riverMaterial(V(0.78,0.78,0.68),roughness:0.8)
        let river=riverMaterial(V(0.021,0.076,0.065),roughness:0.115,pattern:9)
        // Ground follows the complement of the actual river, never spanning its surface.
        box(V(0,-9,0),V(100_000,1,100_000),concrete)
        for strip in data.ground {let q=strip.map{V(min($0[0],1819),-0.06,$0[1])};quad(q[0],q[3],q[2],q[1],pavement)}
        for s:Float in [-1,1] {
            if s<0 {box(V(s*26200,-0.13,0),V(47600,0.15,4800),pavement)}
            box(V(-24091,-0.13,s*26200),V(51820,0.15,47600),pavement)
        }
        for area in data.areas where area.kind != "water" {chicagoArea(area,y:area.kind == "park" ? -0.015:0.008,material:grass)}
        for p in data.paths {chicagoRoad(p,asphalt:asphalt,concrete:concrete,white:white)}
        for b in data.buildings {chicagoBuilding(b,masonry:masonry,granite:granite,pale:pale,blue:blue,gray:gray,windows:windows)}
        for r in data.rivers {
            chicagoArea(r,y:-5.7,material:river)
            chicagoQuays(r,concrete:concrete)
        }
        for a in data.areas where a.kind == "water" {
            let c=a.points.reduce(SIMD2<Float>.zero){$0+SIMD2($1[0],$1[1])}/Float(a.points.count)
            if simd_length(c)<1250 {chicagoArea(a,y:0.05,material:river)}
        }
        for bridge in data.bridges {chicagoBasculeBridge(bridge,asphalt:asphalt,stone:pale,steel:gray)}
        chicagoPlanting(data)
        chicagoStreetFurniture(data,gray:gray,white:white)
        chicagoWackerCrown(stone:granite,glass:blue)
        chicagoUnionStation(stone:pale)
        chicagoRiverBoat(center:V(-164,-5.7,27),white:white,steel:gray,glass:blue)
        // Sparse, low-cost distant context is expressly interpretive beyond mapped radius.
        for ix in -25...19 {for iz in -25...25 {
            let x=Float(ix)*118,z=Float(iz)*118,d=simd_length(SIMD2(x,z))
            if d<1800 || abs(x+180)<180 || x>1650 {continue}
            let h:Float = 12+Float(abs(ix*29+iz*11)%19)*2.5
            box(V(x,h/2,z),V(60,h,73),ix%3==0 ? masonry:concrete)
            for yy in stride(from:Float(5),through:h-2,by:5){
                box(V(x,yy,z-36.51),V(54,2,0.025),cityWindow)
                box(V(x,yy,z+36.51),V(54,2,0.025),cityWindow)
            }
        }}
        // Lake Michigan is a distant horizon surface, not a surveyed lakefront model.
        quad(V(1820,-5.7,-14000),V(1820,-5.7,14000),V(22000,-5.7,14000),V(22000,-5.7,-14000),river)
    }

    private func chicagoArea(_ a:ChicagoContext.Area,y:Float,material:UInt32) {
        for i in stride(from:0,to:a.triangles.count,by:3) {
            let p=a.points[a.triangles[i]],q=a.points[a.triangles[i+1]],r=a.points[a.triangles[i+2]]
            tri(V(p[0],y,p[1]),V(r[0],y,r[1]),V(q[0],y,q[1]),material)
        }
    }
    private func chicagoRoad(_ p:ChicagoContext.Path,asphalt:UInt32,concrete:UInt32,white:UInt32) {
        let ped=["footway","path","pedestrian","cycleway"].contains(p.kind)
        for i in 1..<p.points.count {
            let a=V(p.points[i-1][0],0.027,p.points[i-1][1]),b=V(p.points[i][0],0.027,p.points[i][1]),len=simd_distance(a,b)
            if len<0.2{continue};let t=(b-a)/len,n=V(-t.z,0,t.x),w=p.width/2
            if !p.bridge.isEmpty {
                // Secondary fixed access spans carry their own thin slab above water.
                orientedBox((a+b)/2-V(0,0.42,0),n,V(0,1,0),t,V(p.width,0.8,len),concrete)
            }
            quad(a-n*w,a+n*w,b+n*w,b-n*w,ped ? pavement:asphalt)
            if !ped {
                for side:Float in [-1,1] {
                    let c=(a+b)/2+n*side*(w+1.45)
                    orientedBox(c+V(0,0.07,0),n,V(0,1,0),t,V(2.9,0.14,len),pavement)
                    beam(a+n*w*side+V(0,0.16,0),b+n*w*side+V(0,0.16,0),0.14,0.19,concrete)
                }
                if len>16 && simd_length((a+b)/2)<750 {
                    for d in stride(from:Float(3),through:len-3,by:8) {
                        let c=a+t*d+V(0,0.006,0),dx=t*1.55,dz=n*0.065
                        quad(c-dx-dz,c-dx+dz,c+dx+dz,c+dx-dz,white)
                    }
                }
            }
        }
    }
    private func chicagoBuilding(_ b:ChicagoContext.Building,masonry:UInt32,granite:UInt32,pale:UInt32,blue:UInt32,gray:UInt32,windows:[UInt32]) {
        let p=b.points.map{V($0[0],0.12,$0[1])},c=p.reduce(V.zero,+)/Float(p.count),d=simd_length(c),h=b.height
        let modern=b.material == "glass" || b.material == "steel" || (h>105 && b.material != "stone" && b.material != "brick" && b.material != "masonry")
        let near=d<440,medium=d<950,stone=b.id == 686318733 ? granite : b.material == "brick" ? masonry : b.id%4==0 ? pale:facade
        let material=modern ? gray:stone
        for i in stride(from:0,to:b.triangles.count,by:3) {
            let a=b.triangles[i],j=b.triangles[i+1],k=b.triangles[i+2]
            tri(p[a]+V(0,h,0),p[k]+V(0,h,0),p[j]+V(0,h,0),roof)
        }
        let stories=max(1,min(90,Int(h/3.8))),floorHeight=h/Float(stories)
        for i in p.indices {
            let a=p[i],z=p[(i+1)%p.count],len=simd_distance(a,z)
            if len<0.35{continue};let t=(z-a)/len,n=V(t.z,0,-t.x),middle=(a+z)/2
            quad(a,a+V(0,h,0),z+V(0,h,0),z,material)
            if near && h>8 {
                for y:Float in [0.45,h-0.24,h+0.09] {
                    orientedBox(middle+V(0,y,0)+n*0.12,t,V(0,1,0),n,V(len+0.07,0.28,0.34),modern ? gray:pale)
                }
            }
            guard len>1.8,h>4.5 else {continue}
            let bays=max(1,min(54,Int(len/(modern ? 2.2:3.15)))),spacing=len/Float(bays)
            for story in 0..<stories {
                let wh=modern ? floorHeight*0.78:min(floorHeight*0.66,2.7),ww=spacing*(modern ? 0.88:0.62)
                for j in 0..<bays {
                    let center=a+t*(Float(j)+0.5)*spacing+V(0,(Float(story)+0.5)*floorHeight,0)+n*0.025
                    let dx=t*ww*0.5,dy=V(0,wh/2,0)
                    let roomSeed=(UInt64(bitPattern:b.id) &* 6364136223846793005) &+ (UInt64(story) &* 1442695040888963407) &+ (UInt64(j/2) &* 2862933555777941757) &+ UInt64(i)*1013904223
                    let roomHash=(roomSeed ^ (roomSeed >> 27)) &* 3202034522624059733
                    let roomMaterial=roomHash % 100 < 27 ? windows[1+Int((roomHash/100)%4)]:windows[0]
                    quad(center-dx-dy,center-dx+dy,center+dx+dy,center+dx-dy,roomMaterial)
                    if near {
                        if !modern && story<8 {
                            for s:Float in [-1,1] {orientedBox(center+t*s*(ww/2+0.05)+n*0.045,t,V(0,1,0),n,V(0.10,wh+0.22,0.14),pale)}
                            orientedBox(center-V(0,wh/2+0.075,0)+n*0.065,t,V(0,1,0),n,V(ww+0.22,0.15,0.27),pale)
                        }
                        if (modern && story<14) || story<8 {
                            orientedBox(center+n*0.028,t,V(0,1,0),n,V(0.045,wh,0.065),gray)
                            orientedBox(center+V(0,wh*0.16,0)+n*0.028,t,V(0,1,0),n,V(ww,0.055,0.055),gray)
                        }
                    }
                }
                if medium && modern {orientedBox(middle+V(0,Float(story)*floorHeight,0)+n*0.06,t,V(0,1,0),n,V(len,0.20,0.14),gray)}
            }
            if near && len>10 && h>10 {
                // Physical vertical piers and ground-floor canopy articulate nearby streets.
                for j in 0...min(30,max(1,Int(len/4.6))) {
                    let q=a+t*Float(j)*len/Float(min(30,max(1,Int(len/4.6))))
                    orientedBox(q+V(0,h/2,0)+n*0.07,t,V(0,1,0),n,V(modern ? 0.15:0.3,h,modern ? 0.18:0.28),material)
                }
                if h>20 && len<90 {orientedBox(middle+V(0,3.4,0)+n*1.1,t,V(0,1,0),n,V(min(7,len*0.4),0.23,2.5),gray)}
            }
        }
        if medium && h>10 {
            let top=c+V(0,h,0)
            box(top+V(0,1.5,0),V(7,3,9),gray)
            for s:Float in [-1,1] {
                let q=top+V(s*2.2,3.05,0)
                cylinder(q,q+V(0,0.5,0),1.30,ironDark,segments:12)
                for f in 0..<7 {box(q+V(0,0.54,Float(f-3)*0.32),V(2.0,0.025,0.035),gray)}
            }
            scene.detailCount+=2
        }
    }
    private func chicagoQuays(_ r:ChicagoContext.Area,concrete:UInt32) {
        for i in r.points.indices {
            let v=r.points[i],w=r.points[(i+1)%r.points.count],a=V(v[0],-5.7,v[1]),b=V(w[0],-5.7,w[1]),len=simd_distance(a,b)
            let center=(a+b)/2
            if len<0.35 || simd_length(center)>1550 || len>180 {continue}
            quad(a,b,b+V(0,5.8,0),a+V(0,5.8,0),concrete)
            beam(a+V(0,5.82,0),b+V(0,5.82,0),0.42,0.34,limestone)
            if simd_length(center)<550 {
                let t=(b-a)/len,n=V(t.z,0,-t.x)
                for d in stride(from:Float(0.75),through:len,by:2.2) {
                    let q=a+t*d+V(0,5.9,0)
                    cylinder(q,q+V(0,1.12,0),0.034,ironDark,segments:6)
                }
                for y:Float in [6.22,7.02] {beam(a+V(0,y,0),b+V(0,y,0),0.045,0.045,ironDark)}
                if len>12 {let c=center+V(0,6,0)-n*1.7;streetLamp(c)}
            }
        }
    }
    private func chicagoBasculeBridge(_ p:ChicagoContext.Path,asphalt:UInt32,stone:UInt32,steel:UInt32) {
        guard let f=p.points.first,let l=p.points.last else{return}
        let a=V(f[0],0.05,f[1]),b=V(l[0],0.05,l[1]),len=simd_distance(a,b),t=(b-a)/len,n=V(-t.z,0,t.x),c=(a+b)/2
        let close=simd_length(c)<360,w:Float=p.name.contains("Jackson") ? 23:25
        orientedBox(c-V(0,0.45,0),t,V(0,1,0),n,V(len,0.85,w),steel)
        orientedBox(c+V(0,0.02,0),t,V(0,1,0),n,V(len,w<24 ? 0.10:0.09,w-7),asphalt)
        for side:Float in [-1,1] {
            orientedBox(c+n*side*(w/2-1.65)+V(0,0.14,0),t,V(0,1,0),n,V(len,0.18,3.3),pavement)
            for y:Float in [0.37,1.35] {beam(a+n*side*(w/2-0.22)+V(0,y,0),b+n*side*(w/2-0.22)+V(0,y,0),0.15,0.16,stone)}
            for d in stride(from:Float(0),through:len,by:close ? 0.62:1.5) {
                let q=a+t*d+n*side*(w/2-0.23)+V(0,0.35,0)
                beam(q,q+V(0,0.94,0),0.065,0.065,steel)
            }
            // Deck trusses sit below the roadway, matching Adams/Jackson open parapets.
            for level:Float in [-0.9,-3.0] {beam(a+n*side*(w/2-3.9)+V(0,level,0),b+n*side*(w/2-3.9)+V(0,level,0),0.28,0.32,steel)}
            let bays=max(4,Int(len/5.8))
            for i in 0..<bays {
                let q=a+t*Float(i)*len/Float(bays)+n*side*(w/2-3.9),v=a+t*Float(i+1)*len/Float(bays)+n*side*(w/2-3.9)
                beam(q-V(0,0.9,0),v-V(0,3,0),0.16,0.21,steel)
                beam(q-V(0,3,0),v-V(0,0.9,0),0.16,0.21,steel)
            }
            for k in 0...2 {let q=a+t*Float(k)*len/2+n*side*(w/2-1.7)+V(0,0.22,0);streetLamp(q)}
            if close {
                // Twin classic bridge tender houses, diagonal ends, faceted copper roofs.
                let end=side<0 ? a:b,q=end+n*side*(w/2+2.25)
                box(q+V(0,2.8,0),V(5.3,5.6,5.3),stone)
                for face in 0..<4 {
                    let normal=face==0 ? V(1,0,0):face==1 ? V(-1,0,0):face==2 ? V(0,0,1):V(0,0,-1)
                    let tangent=V(-normal.z,0,normal.x)
                    orientedBox(q+normal*2.67+V(0,3.85,0),tangent,V(0,1,0),normal,V(3.65,1.9,0.05),cityWindow)
                    for k:Float in [-1,0,1] {orientedBox(q+normal*2.73+tangent*k*1.25+V(0,3.85,0),tangent,V(0,1,0),normal,V(0.12,2.1,0.10),stone)}
                    let e0=q+normal*3+tangent*3+V(0,5.65,0),e1=q+normal*3-tangent*3+V(0,5.65,0)
                    tri(e0,q+V(0,7.4,0),e1,roof)
                }
                box(q+V(0,5.56,0),V(6.1,0.28,6.1),stone)
                scene.lights.append(NightLighting.source(q+V(0,4.8,0),power:35,color:V(1,0.72,0.44),range:17,radius:0.5))
            }
        }
        // Central leaf joint and end expansion joints; no fictitious center river pier.
        for t0:Float in [0,0.5,1] {orientedBox(a+(b-a)*t0+V(0,0.083,0),t,V(0,1,0),n,V(0.13,0.025,w-7),ironDark)}
    }
    private func chicagoInside(_ p:SIMD2<Float>,_ g:[[Float]])->Bool {
        var value=false,j=g.count-1
        for i in g.indices {
            let a=g[i],b=g[j]
            if (a[1]>p.y) != (b[1]>p.y),p.x<(b[0]-a[0])*(p.y-a[1])/(b[1]-a[1])+a[0]{value.toggle()};j=i
        };return value
    }
    private func chicagoPlanting(_ data:ChicagoContext.Database) {
        var planted=Set<String>()
        for a in data.areas where a.kind != "water" {
            let center=a.points.reduce(SIMD2<Float>.zero){$0+SIMD2($1[0],$1[1])}/Float(a.points.count)
            if simd_length(center)>1000{continue}
            let minX=a.points.map{$0[0]}.min()!,maxX=a.points.map{$0[0]}.max()!,minZ=a.points.map{$0[1]}.min()!,maxZ=a.points.map{$0[1]}.max()!
            for x in stride(from:minX+4,through:maxX-3,by:13) {for z in stride(from:minZ+4,through:maxZ-3,by:13) {
                let q=SIMD2(x+(rnd()-0.5)*4,z+(rnd()-0.5)*4)
                if !chicagoInside(q,a.points) || (abs(q.x)<70 && q.y > -50 && q.y<90){continue}
                let key="\(Int(q.x/8)),\(Int(q.y/8))";if !planted.insert(key).inserted{continue}
                chicagoTree(V(q.x,0.12,q.y),height:7+rnd()*4)
            }}
        }
        // Street tree pits are authored positions along mapped nearby sidewalks.
        for p in data.paths where ["secondary","primary","tertiary"].contains(p.kind) && p.bridge.isEmpty {
            for i in 1..<p.points.count {
                let a=V(p.points[i-1][0],0.14,p.points[i-1][1]),b=V(p.points[i][0],0.14,p.points[i][1]),len=simd_distance(a,b)
                if len<24 || simd_length((a+b)/2)>460{continue};let t=(b-a)/len,n=V(-t.z,0,t.x)
                for d in stride(from:Float(12),through:len-8,by:28) {
                    let q=a+t*d+n*(p.width/2+1.5)
                    if q.x > -60 && q.x<65 && q.z > -47 && q.z<85{continue}
                    let key="\(Int(q.x/8)),\(Int(q.z/8))";if !planted.insert(key).inserted{continue}
                    box(q-V(0,0.02,0),V(2.5,0.10,2.5),bark)
                    for s:Float in [-1,1]{box(q+V(s*1.3,0.06,0),V(0.12,0.18,2.7),limestone);box(q+V(0,0.06,s*1.3),V(2.7,0.18,0.12),limestone)}
                    chicagoTree(q,height:7.5+rnd()*2)
                }
            }
        }
    }
    private func chicagoTree(_ p:V,height:Float) {
        cylinder(p,p+V(0,height*0.72,0),0.18,bark,segments:9)
        for j in 0..<7 {
            let theta=Float(j)*2.39996,offset=V(cos(theta)*(1.2+rnd()),height*(0.59+rnd()*0.22),sin(theta)*(1.2+rnd()))
            cylinder(p+V(0,height*0.40,0),p+offset,0.07,bark,segments:6)
            let c=p+offset,r=V(1.9+rnd(),2.1+rnd(),1.9+rnd())
            // Smooth leaf masses retain coherent silhouettes under temporal reconstruction.
            let segments=10,rings=6
            for v in 0..<rings {for k in 0..<segments {
                func point(_ vv:Int,_ kk:Int)->(V,V) {
                    let lat = -Float.pi/2+Float(vv)*Float.pi/Float(rings),lon=Float(kk)*2*Float.pi/Float(segments)
                    let n=V(cos(lat)*cos(lon),sin(lat),cos(lat)*sin(lon))
                    return(c+n*r,simd_normalize(n/r))
                }
                let a=point(v,k),b=point(v,k+1),d=point(v+1,k),e=point(v+1,k+1),m=j%3==0 ? leafLight:leaf
                if v>0{smoothTri(a.0,d.0,b.0,a.1,d.1,b.1,m)}
                if v<rings-1{smoothTri(b.0,d.0,e.0,b.1,d.1,e.1,m)}
            }}
        };scene.detailCount+=1
    }
    private func chicagoStreetFurniture(_ data:ChicagoContext.Database,gray:UInt32,white:UInt32) {
        var lamps=Set<String>()
        for p in data.paths where ["secondary","primary","tertiary","residential"].contains(p.kind) && p.bridge.isEmpty {
            for i in 1..<p.points.count {
                let a=V(p.points[i-1][0],0.18,p.points[i-1][1]),b=V(p.points[i][0],0.18,p.points[i][1]),len=simd_distance(a,b)
                if len<18 || simd_length((a+b)/2)>730{continue};let t=(b-a)/len,n=V(-t.z,0,t.x)
                for d in stride(from:Float(5),through:len-4,by:38) {
                    let q=a+t*d-n*(p.width/2+1.0),key="\(Int(q.x/16)),\(Int(q.z/16))"
                    if !lamps.insert(key).inserted{continue}
                    cylinder(q,q+V(0,8.1,0),0.075,gray,segments:8)
                    cylinder(q,q+V(0,0.5,0),0.22,gray,segments:10)
                    beam(q+V(0,7.4,0),q+V(0,8.0,0)+n*2.0,0.085,0.085,gray)
                    box(q+V(0,7.94,0)+n*2.0,V(0.95,0.13,0.42),lamp)
                    scene.lights.append(NightLighting.source(q+V(0,7.82,0)+n*2.0,toward:q+n*2,power:180,color:V(1,0.78,0.54),range:37,radius:0.6,outerDegrees:88,innerDegrees:60))
                    if simd_length(q)<340 {
                        // Bins, bollards and slatted benches offer close-scale street furniture.
                        cylinder(q+t*1.9,q+t*1.9+V(0,0.91,0),0.31,ironDark,segments:12)
                        cylinder(q+t*1.9+V(0,0.91,0),q+t*1.9+V(0,0.96,0),0.35,gray,segments:12)
                        let c=q+t*5-n*0.15
                        for slat in 0..<5 {orientedBox(c+n*Float(slat-2)*0.11+V(0,0.48,0),t,V(0,1,0),n,V(2.2,0.06,0.095),timber)}
                        for s:Float in [-1,1] {orientedBox(c+t*s*0.80+V(0,0.26,0),t,V(0,1,0),n,V(0.09,0.45,0.49),gray)}
                        for j in 0..<3 {orientedBox(c-n*0.27+V(0,0.74+Float(j)*0.10,0),t,V(0,1,0),n,V(2.2,0.08,0.06),timber)}
                    }
                }
            }
        }
        // A few ordinary sedans at authored positions on the real road alignments.
        for c:V in [V(-69,0.20,-120),V(-65,0.20,117),V(81,0.20,90),V(160,0.20,-52),V(-250,0.20,91)] {
            box(c+V(0,0.53,0),V(1.86,0.69,4.45),gray)
            box(c+V(0,1.02,-0.18),V(1.70,0.58,2.25),glass)
            for x:Float in [-0.90,0.90] {for z:Float in [-1.40,1.40]{cylinder(c+V(x-0.09,0.34,z),c+V(x+0.09,0.34,z),0.34,ironDark,segments:12)}}
            for x:Float in [-0.60,0.60] {box(c+V(x,0.62,-2.24),V(0.39,0.16,0.03),white)}
        }
    }
    private func chicagoWackerCrown(stone:UInt32,glass:UInt32) {
        // 311 S Wacker's five-cylinder crown is an authored silhouette on its mapped footprint.
        let c=V(26,260.9,157),whiteCrown=riverMaterial(V(0.70,0.72,0.68),roughness:0.3,emission:0.18,pattern:14)
        for (offset,radius,height):(V,Float,Float) in [(V.zero,11.7,32),(V(16,0,0),5.6,25),(V(-16,0,0),5.6,25),(V(0,0,16),5.6,25),(V(0,0,-16),5.6,25)] {
            let p=c+offset
            cylinder(p,p+V(0,height,0),radius,whiteCrown,segments:48)
            for y in stride(from:Float(1),through:height,by:2.7){cylinder(p+V(0,y,0),p+V(0,y+0.13,0),radius+0.05,stone,segments:48)}
            for j in 0..<24 {let a=Float(j)*2*Float.pi/24,v=V(cos(a)*radius,0,sin(a)*radius);beam(p+v,p+v+V(0,height,0),0.11,0.11,stone)}
            cylinder(p+V(0,height-0.05,0),p+V(0,height+0.35,0),radius+0.3,stone,segments:48)
        }
    }
    private func chicagoUnionStation(stone:UInt32) {
        guard let b=ChicagoContext.database.buildings.first(where:{$0.id==203442440})else{return}
        let xs=b.points.map{$0[0]},zs=b.points.map{$0[1]},x=xs.max()!+0.7,z=(zs.min()!+zs.max()!)/2,length=zs.max()!-zs.min()!
        // The east Canal Street colonnade and barrel skylight identify the real headhouse.
        for i in 0..<20 {
            let q=V(x,3.2,z+(Float(i)/19-0.5)*(length-13))
            cylinder(q,q+V(0,18.4,0),0.95,stone,segments:16)
            cylinder(q-V(0,0.3,0),q+V(0,0.3,0),1.18,stone,segments:16)
            cylinder(q+V(0,17.9,0),q+V(0,18.6,0),1.30,stone,segments:16)
            box(q+V(0,18.85,0),V(2.8,0.35,2.8),stone)
        }
        box(V(x,23.0,z),V(3.3,2.7,length-7),stone)
        box(V(x,24.58,z),V(3.8,0.45,length-5),stone)
        let center=V((xs.min()!+xs.max()!)/2,b.height+0.15,z),halfLength:Float=33.4,radius:Float=10.5
        for j in 0..<24 {
            let a=Float(j)*Float.pi/24,v=Float(j+1)*Float.pi/24
            let p0=center+V(radius*cos(a),radius*sin(a),-halfLength),p1=center+V(radius*cos(v),radius*sin(v),-halfLength)
            quad(p0,p1,p1+V(0,0,halfLength*2),p0+V(0,0,halfLength*2),glass)
            beam(p0,p0+V(0,0,halfLength*2),0.15,0.15,ironDark)
        }
        for s in stride(from:-halfLength,through:halfLength,by:4.18) {
            for j in 0..<24 {let a=Float(j)*Float.pi/24,v=Float(j+1)*Float.pi/24;beam(center+V(radius*cos(a),radius*sin(a),s),center+V(radius*cos(v),radius*sin(v),s),0.18,0.18,stone)}
        }
    }
    private func chicagoRiverBoat(center c:V,white:UInt32,steel:UInt32,glass:UInt32) {
        // Original compact Chicago river-tour craft, longitudinal axis aligned with the river.
        let navy=riverMaterial(V(0.035,0.080,0.13),roughness:0.32,metallic:0.3),orange=riverMaterial(V(0.95,0.18,0.035),roughness:0.55)
        let stations:[(Float,Float)]=[(-17,0.1),(-15,2.2),(-11,3.25),(10,3.25),(15,2.9),(17,2.3)]
        for i in 0..<stations.count-1 {
            let a=stations[i],b=stations[i+1]
            for side:Float in [-1,1] {
                quad(c+V(side*a.1*0.78,-0.8,a.0),c+V(side*b.1*0.78,-0.8,b.0),c+V(side*b.1,1.35,b.0),c+V(side*a.1,1.35,a.0),navy)
                beam(c+V(side*a.1,1.1,a.0),c+V(side*b.1,1.1,b.0),0.22,0.16,white)
                beam(c+V(side*a.1,2.2,a.0),c+V(side*b.1,2.2,b.0),0.05,0.05,white)
                for j in 0..<max(1,Int((b.0-a.0)/1.5)) {let t=Float(j)/Float(max(1,Int((b.0-a.0)/1.5))),z=a.0+(b.0-a.0)*t,w=a.1+(b.1-a.1)*t;beam(c+V(side*w,1.35,z),c+V(side*w,2.2,z),0.04,0.04,steel)}
            }
            quad(c+V(-a.1,1.36,a.0),c+V(-b.1,1.36,b.0),c+V(b.1,1.36,b.0),c+V(a.1,1.36,a.0),timber)
        }
        box(c+V(0,2.48,1),V(5.55,2.2,21),white)
        for side:Float in [-1,1] {for i in 0..<10 {let z=Float(i)*1.95-8;box(c+V(side*2.79,2.7,z),V(0.04,1.15,1.65),glass)}}
        box(c+V(0,3.65,1),V(6.2,0.18,22.2),white)
        for side:Float in [-1,1] {
            for y:Float in [3.87,4.7] {beam(c+V(side*2.9,y,-10),c+V(side*2.9,y,12),0.05,0.05,steel)}
            for z in stride(from:Float(-10),through:Float(12),by:1.5) {beam(c+V(side*2.9,3.75,z),c+V(side*2.9,4.7,z),0.036,0.036,steel)}
            for z:Float in [-7,0,7] {
                ellipsoid(c+V(side*3.3,0.9,z),V(0.22,0.57,0.22),ironDark,segments:8,rings:5)
                box(c+V(side*2.86,3.5,z),V(0.07,0.10,1.35),lamp)
                scene.lights.append(NightLighting.source(c+V(side*2.98,3.45,z),power:11,color:V(1,0.74,0.44),range:12,radius:0.3))
            }
        }
        box(c+V(0,4.6,-8),V(4.0,1.8,3.8),white)
        box(c+V(0,4.8,-9.92),V(3.65,1.1,0.035),glass)
        cylinder(c+V(0,5.55,-8),c+V(0,7.5,-8),0.055,steel,segments:8)
        box(c+V(0,6.8,-8),V(1.7,0.20,0.28),white)
        for row in 0..<7 {for side:Float in [-1,1] {for seat in 0..<2 {
            let p=c+V(side*(0.75+Float(seat)*1.0),3.78,Float(row)*2.0-3)
            box(p+V(0,0.42,0),V(0.70,0.10,0.70),navy);box(p+V(0,0.79,0.34),V(0.70,0.70,0.09),navy)
            for x:Float in [-0.27,0.27] {beam(p+V(x,0,-0.2),p+V(x,0.42,0.2),0.04,0.04,steel)}
        }}}
        for side:Float in [-1,1] {ellipsoid(c+V(side*2.92,2.1,11),V(0.08,0.46,0.46),orange,segments:12,rings:7)}
        let port=riverMaterial(V(1,0.018,0.006),emission:1.4,pattern:8),starboard=riverMaterial(V(0.015,0.8,0.11),emission:1.4,pattern:8)
        // Facing -z (north), port is west / -x and starboard east / +x.
        box(c+V(-2.5,5,-8),V(0.13,0.12,0.15),port);box(c+V(2.5,5,-8),V(0.13,0.12,0.15),starboard)
        scene.detailCount+=80
    }
}
