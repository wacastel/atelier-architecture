import Foundation
import simd

/// Offline ODbL corridor geometry in the existing Willis-origin metre world.
/// Footprint positions are mapped; untagged heights, facades and lamps are interpretations.
enum HydeParkContext {
    typealias Surface = LakefrontContext.Surface
    typealias Landmark = MuseumCampusContext.Landmark
    struct Building: Decodable {
        var id:Int64;var points:[[Float]];var triangles:[Int];var rings:[[[Float]]]
        var height:Float;var heightSource:String;var name:String;var material:String
        var buildingKind:String;var isPart:Bool
    }
    struct Path: Decodable {
        var id:Int64;var points:[[Float]];var width:Float;var kind:String;var name:String
        var bridge:String;var elevation:Float
        var sidewalkLeft:String;var sidewalkRight:String
    }
    struct RoadSurface: Decodable {
        var surface:Surface;var elevation:Float
    }
    struct Database: Decodable {
        var timestamp:String;var ground:Surface;var water:Surface;var inlandWaters:[Surface]
        var namedHarbors:[Surface];var authoredMask:Surface;var replacementBuildingIDs:[Int64]
        var buildings:[Building];var landmarks:[Landmark];var areas:[Surface];var paths:[Path]
        var roadSurfaces:[RoadSurface]
        var piers:[ChicagoContext.Path];var breakwaters:[ChicagoContext.Path];var rails:[ChicagoContext.Path]
        var trees:[LakefrontContext.Tree];var landcoverTrees:[LakefrontContext.Tree]
        var roads:[LakefrontContext.Road];var trafficLanes:[LakefrontContext.TrafficLane];var boats:[MuseumCampusContext.Boat]
        var sourceSHA256:[String:String];var previousResourceSHA256:[String:String]
    }
    static let database:Database = {
        var urls:[URL]=[]
        if let r=Bundle.main.resourceURL {
            urls.append(r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/HydePark/HydeParkContext.json"))
            urls.append(r.appendingPathComponent("Resources/HydePark/HydeParkContext.json"))
        }
        urls.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/HydePark/HydeParkContext.json"))
        for url in urls {if let data=try?Data(contentsOf:url),let value=try?JSONDecoder().decode(Database.self,from:data){return value}}
        #if SWIFT_PACKAGE
        let url=Bundle.module.bundleURL.appendingPathComponent("Resources/HydePark/HydeParkContext.json")
        if let data=try?Data(contentsOf:url),let value=try?JSONDecoder().decode(Database.self,from:data){return value}
        #endif
        fatalError("Bundled HydeParkContext.json is missing or invalid")
    }()
    private static let landmarksByID=Dictionary(database.landmarks.map{($0.id,$0)},uniquingKeysWith:{$1})
    static func landmark(_ id:Int64)->Landmark? {landmarksByID[id]}
    static func suppressesBuilding(_ id:Int64,_ x:Float,_ z:Float)->Bool {
        id == 125667497 || containsAuthoredSite(x,z)
    }
    static func containsAuthoredSite(_ x:Float,_ z:Float)->Bool {x>=3288 && x<=3339 && z>=9904 && z<=9928}
    static func detailDistance(_ x:Float,_ z:Float)->Float {
        func segment(_ a:SIMD2<Float>,_ b:SIMD2<Float>)->Float {
            let p=SIMD2(x,z),d=b-a,t=max(0,min(1,simd_dot(p-a,d)/simd_length_squared(d)))
            return simd_distance(p,a+d*t)
        }
        return min(segment(SIMD2(3300,9917),SIMD2(3275,9725)),segment(SIMD2(3275,9725),SIMD2(4630,9680)),simd_distance(SIMD2(x,z),SIMD2(4925,9240)))
    }
}

extension EiffelBuilder {
    func hydeParkEnvironment() {
        let d=HydeParkContext.database,p=LakefrontPalette(self),saved=randomState
        randomState=0x1909_1910_2026
        let masonry:[UInt32]=[V(0.38,0.20,0.13),V(0.52,0.34,0.23),V(0.62,0.52,0.37),V(0.35,0.31,0.27),V(0.68,0.63,0.50)].map{riverMaterial($0,roughness:0.78,pattern:19)}
        let windows:[UInt32]=[Float(0),0.055,0.08,0.11,0.14].map{riverMaterial(V(0.085,0.14,0.165),roughness:0.17,metallic:0.52,emission:$0,pattern:14)}
        let stone=riverMaterial(V(0.61,0.56,0.45),roughness:0.84,pattern:10)
        lakefrontSurface(d.ground,y:-0.065,material:pavement)
        lakefrontSurface(d.water,y:-5.7,material:p.water)
        for water in d.inlandWaters {lakefrontSurface(water,y:-0.65,material:p.water)}
        for area in d.areas {
            lakefrontSurface(area,y:area.kind == "garden" ? 0.012:area.kind == "pitch" ? 0.015:-0.035,material:area.kind == "sand" ? p.sand:grass)
        }
        for b in d.buildings {hydeParkBuilding(b,masonry:masonry,windows:windows,stone:stone,p:p)}
        // These offline polygons share their bend/junction boundaries. Drawing
        // independent segment rectangles here would reintroduce overlapping tiles.
        for road in d.roadSurfaces {
            lakefrontSurface(road.surface,y:road.elevation,material:road.surface.kind == "asphalt" ? p.asphalt:pavement)
            if road.surface.kind != "asphalt" {
                for ring in road.surface.rings {
                    guard ring.count>2 else {continue}
                    for i in ring.indices {
                        let q=ring[i],r=ring[(i+1)%ring.count]
                        let a=V(q[0],-0.065,q[1]),b=V(r[0],-0.065,r[1]),rise=V(0,road.elevation+0.065,0)
                        if simd_distance_squared(a,b)>0.000001 {quad(a,a+rise,b+rise,b,p.paving)}
                    }
                }
            }
        }
        for path in d.paths {hydeParkRoad(path,p:p)}
        for road in d.roads {lakefrontDrive(road,p:p,drawSurface:false)}
        hydeParkRailway(p:p)
        for pier in d.piers {lakefrontPier(pier,p:p)}
        for wall in d.breakwaters {hydeParkShore(wall,stone:stone,p:p)}
        for tree in d.trees+d.landcoverTrees {hydeParkTree(tree,p:p)}
        for boat in d.boats {
            let center=V(boat.point[0],-5.7,boat.point[1])
            lakefrontBoat(center,length:boat.length,angle:boat.angle,sailboat:boat.sailboat,detailed:boat.detailed,p:p)
            if boat.detailed && boat.id%5==0 {
                let light=center+V(0,1.6,0)
                scene.lights.append(NightLighting.source(light,toward:light+V(2,-1,0),power:6,color:V(1,0.80,0.56),range:11,radius:0.45,outerDegrees:91,innerDegrees:68))
            }
        }
        hydeParkHarborDetails(p:p,stone:stone)
        hydeParkPromontoryDetails(p:p,stone:stone)
        hydeParkStreetFurniture(p:p)
        scene.trafficLanes=d.trafficLanes.map{SceneTrafficLane(id:$0.id,points:$0.points.map{V($0[0],$0[1],$0[2])},speedMetresPerSecond:$0.speedMetresPerSecond,spawnFadeMetres:$0.spawnFadeMetres)}
        randomState=saved
    }

    private func hydeParkBuilding(_ b:HydeParkContext.Building,masonry:[UInt32],windows:[UInt32],stone:UInt32,p:LakefrontPalette) {
        guard !b.points.isEmpty,b.height>0 else{return}
        let points=b.points.map{V($0[0],0.10,$0[1])},center=points.reduce(V.zero,+)/Float(points.count)
        if HydeParkContext.suppressesBuilding(b.id,center.x,center.z) || NorthSideContext.suppressesPreviousLandmark(b.id,center.x,center.z) {return}
        let distance=HydeParkContext.detailDistance(center.x,center.z),near=distance<170,medium=distance<430
        let h=b.height,seed=UInt64(bitPattern:b.id)
        let modern=h>55 || b.material == "glass" || b.id==150456352
        let stoneBuilding=b.material == "stone" || b.buildingKind == "church" || b.id == 125502842
        let material=modern ? p.glass:stoneBuilding ? stone:masonry[Int(seed%UInt64(masonry.count))]
        for i in stride(from:0,to:b.triangles.count,by:3) {tri(points[b.triangles[i]]+V(0,h,0),points[b.triangles[i+2]]+V(0,h,0),points[b.triangles[i+1]]+V(0,h,0),roof)}
        let floors=max(1,min(near ? 24:medium ? 16:7,Int(h/(distance>1000 ? 7:3.5))))
        let story=h/Float(floors)
        for ring in b.rings {
            let pts=ring.map{V($0[0],0.10,$0[1])}
            for i in pts.indices {
                let a=pts[i],z=pts[(i+1)%pts.count],length=simd_distance(a,z)
                if length<0.15 {continue}
                let t=(z-a)/length,n=V(t.z,0,-t.x),mid=(a+z)/2
                quad(a,z,z+V(0,h,0),a+V(0,h,0),material)
                if near || medium {orientedBox(mid+V(0,h-0.12,0)+n*0.10,t,V(0,1,0),n,V(length+0.05,0.26,0.35),stone)}
                if length<2.4 || h<4 {continue}
                let bays=max(1,min(near ? 22:medium ? 13:5,Int(length/(near ? 3.2:medium ? 4.5:11)))),bay=length/Float(bays)
                for floor in 0..<floors {for j in 0..<bays {
                    let c=a+t*(Float(j)+0.5)*bay+n*0.035+V(0,(Float(floor)+0.56)*story,0)
                    let ww=min(bay*(modern ? 0.79:0.59),near ? 3.0:8),wh=min(story*(modern ? 0.76:0.58),3.5)
                    let hash=(seed &+ UInt64(floor*97+j*31+i*197))%17,m=windows[hash<4 ? Int(hash)+1:0]
                    quad(c-t*ww/2-V(0,wh/2,0),c+t*ww/2-V(0,wh/2,0),c+t*ww/2+V(0,wh/2,0),c-t*ww/2+V(0,wh/2,0),m)
                    if near {
                        for side:Float in [-1,1] {orientedBox(c+t*side*(ww/2+0.055),t,V(0,1,0),n,V(0.10,wh+0.20,0.16),stone)}
                        orientedBox(c-V(0,wh/2+0.09,0)+n*0.08,t,V(0,1,0),n,V(ww+0.30,0.18,0.34),stone)
                        orientedBox(c+V(0,wh/2+0.10,0),t,V(0,1,0),n,V(ww+0.24,0.18,0.20),stone)
                        beam(c-V(0,wh/2,0),c+V(0,wh/2,0),0.045,0.06,p.dark)
                        if stoneBuilding {beam(c-t*ww/2,c+t*ww/2,0.07,0.07,stone)}
                    }
                }}
                if near && length>7 && length<55 {
                    orientedBox(mid+V(0,0.35,0)+n*0.08,t,V(0,1,0),n,V(length,0.55,0.22),stone)
                    let shop=abs(center.z-9720)<100 && !stoneBuilding && h<30 && seed%3==0
                    if shop {
                        let frontage=mid+V(0,1.55,0)+n*0.065,width=min(8,length*0.72)
                        orientedBox(frontage,t,V(0,1,0),n,V(width,2.45,0.045),windows[Int(seed%4)+1])
                        for fraction:Float in [-0.5,0,0.5] {beam(frontage+t*width*fraction-V(0,1.22,0),frontage+t*width*fraction+V(0,1.22,0),0.09,0.08,p.dark)}
                        let awning=frontage+V(0,1.55,0),outer=awning+n*1.05-V(0,0.35,0)
                        quad(awning-t*width/2,awning+t*width/2,outer+t*width/2,outer-t*width/2,seed%2==0 ? p.hull:p.red)
                    }
                }
            }
        }
        // The landmark neighborhood retains skyline cues without a complete
        // second interior model: a stone chapel belfry and Harper's glass roof.
        if b.id==150457349 {
            let c=V(3218.4,0,10064.0)
            box(c+V(0,35,0),V(13,70,13),stone)
            for side:Float in [-1,1] {for offset:Float in [-3,0,3] {
                box(c+V(offset,57,side*6.55),V(1.4,12,0.08),p.dark)
                box(c+V(side*6.55,57,offset),V(0.08,12,1.4),p.dark)
            }}
            for xx:Float in [-5.8,5.8] {for zz:Float in [-5.8,5.8] {box(c+V(xx,70,zz),V(1.3,4,1.3),stone)}}
        }
        if b.id==150456352 {
            for x in stride(from:Float(3310),through:3378,by:17) {
                let c=V(x,21.2,10004)
                for s:Float in [-1,1] {quad(c+V(-7,0,s*10),c+V(7,0,s*10),c+V(7,5,0),c+V(-7,5,0),p.glass)}
                beam(c+V(-7,5,0),c+V(7,5,0),0.16,0.20,stone)
            }
        }
    }

    private func hydeParkRoad(_ path:HydeParkContext.Path,p:LakefrontPalette) {
        let ped=["footway","path","cycleway","pedestrian","steps"].contains(path.kind)
        for i in 1..<path.points.count {
            let a=V(path.points[i-1][0],path.elevation,path.points[i-1][1]),b=V(path.points[i][0],path.elevation,path.points[i][1]),length=simd_distance(a,b)
            if length<0.1 {continue};let t=(b-a)/length,n=V(-t.z,0,t.x),w=path.width/2,mid=(a+b)/2
            if path.elevation>1 {quad(a-n*w,a+n*w,b+n*w,b-n*w,ped ? pavement:p.asphalt)}
            if path.elevation>1 {
                orientedBox(mid-V(0,0.30,0),n,V(0,1,0),t,V(path.width,0.58,length),p.paving)
                for s:Float in [-1,1] {
                    beam(a+n*s*(w-0.10)+V(0,1.1,0),b+n*s*(w-0.10)+V(0,1.1,0),0.075,0.10,p.dark)
                    for d in stride(from:Float(1),to:length,by:3) {beam(a+t*d+n*s*(w-0.1),a+t*d+n*s*(w-0.1)+V(0,1.1,0),0.055,0.065,p.dark)}
                }
            }
            if !ped {
                if path.elevation>1 {
                    for s:Float in [-1,1] where (s>0 ? path.sidewalkRight:path.sidewalkLeft) == "generate" {
                        let aa=a+n*s*(w+0.10)+V(0,0.07,0),bb=b+n*s*(w+0.10)+V(0,0.07,0)
                        if s>0 {quad(aa,aa+n*2.5,bb+n*2.5,bb,pavement)}
                        else {quad(bb,bb-n*2.5,aa-n*2.5,aa,pavement)}
                        if HydeParkContext.detailDistance(mid.x,mid.z)<220 {beam(aa,bb,0.14,0.18,p.paving)}
                    }
                }
                if length>18 && HydeParkContext.detailDistance(mid.x,mid.z)<300 {
                    for d in stride(from:Float(3),to:length-3,by:9) {
                        let c=a+t*d+V(0,0.009,0)
                        quad(c-t*1.5-n*0.055,c-t*1.5+n*0.055,c+t*1.5+n*0.055,c+t*1.5-n*0.055,p.white)
                    }
                }
            }
        }
    }

    private func hydeParkTree(_ tree:LakefrontContext.Tree,p:LakefrontPalette) {
        let c=V(tree.point[0],0,tree.point[1]),h=tree.height,near=HydeParkContext.detailDistance(c.x,c.z)<180
        if HydeParkContext.containsAuthoredSite(c.x,c.z) {return}
        cylinder(c,c+V(0,h*0.66,0),near ? 0.20:0.14,bark,segments:near ? 8:5)
        for i in 0..<(near ? 3:1) {
            let angle=Float(i)*2.4+Float(tree.id%31),v=c+V(near ? cos(angle)*1.3:0,h*(0.70+Float(i%2)*0.08),near ? sin(angle)*1.3:0)
            if near {cylinder(c+V(0,h*0.40,0),v,0.065,bark,segments:5)}
            lakefrontSmoothCrown(v,V(near ? 2.3:h*0.29,h*0.27,near ? 2.3:h*0.29),i%3==0 ? leafLight:leaf,segments:near ? 10:7,rings:near ? 6:4)
        }
    }

    private func hydeParkRailway(p:LakefrontPalette) {
        let ballast=riverMaterial(V(0.20,0.20,0.18),roughness:0.96,pattern:10)
        for rail in HydeParkContext.database.rails {for i in 1..<rail.points.count {
            let a=V(rail.points[i-1][0],0.18,rail.points[i-1][1]),b=V(rail.points[i][0],0.18,rail.points[i][1]),length=simd_distance(a,b)
            if length<0.2 {continue};let t=(b-a)/length,n=V(-t.z,0,t.x)
            quad(a-n*2.0,a+n*2.0,b+n*2.0,b-n*2.0,ballast)
            for s:Float in [-1,1] {beam(a+n*s*0.7175+V(0,0.15,0),b+n*s*0.7175+V(0,0.15,0),0.065,0.12,p.dark)}
            for distance in stride(from:Float(1),to:length,by:2.5) {orientedBox(a+t*distance+V(0,0.045,0),n,V(0,1,0),t,V(2.3,0.09,0.22),p.dock)}
        }}
    }

    private func hydeParkShore(_ wall:ChicagoContext.Path,stone:UInt32,p:LakefrontPalette) {
        let promontory=wall.points.contains{$0[0]>4700 && $0[1]>9000 && $0[1]<9600}
        if !promontory {lakefrontSeawall(wall,p:p);return}
        for i in 1..<wall.points.count {
            let a=V(wall.points[i-1][0],0,wall.points[i-1][1]),b=V(wall.points[i][0],0,wall.points[i][1]),length=simd_distance(a,b)
            if length<0.1 {continue};let t=(b-a)/length,n=V(-t.z,0,t.x)
            let middle=(a+b)/2
            let outward:Float=simd_dot(n,middle-V(4880,0,9260))>0 ? 1:-1
            for step in 0..<5 {
                let y=Float(step)*(-1.12)-0.6,c=middle+n*outward*Float(step)*1.25+V(0,y,0)
                orientedBox(c,t,V(0,1,0),n,V(length+0.03,1.20,1.6),stone)
                for distance in stride(from:Float(step%2)*1.6,to:length,by:3.2) {
                    let q=a+t*distance+n*outward*Float(step)*1.25+V(0,y+0.61,0)
                    beam(q-n*0.78,q+n*0.78,0.025,0.025,p.dark)
                }
            }
        }
    }

    private func hydeParkHarborDetails(p:LakefrontPalette,stone:UInt32) {
        // Shore building is mapped layer=-1 because it sits under the green
        // park roof. Build its water-facing facade rather than a tall city shell.
        guard let b=HydeParkContext.landmark(1297166727) else{return}
        for ring in b.rings {for i in ring.indices {
            let a=V(ring[i][0],-5.1,ring[i][1]),z=V(ring[(i+1)%ring.count][0],-5.1,ring[(i+1)%ring.count][1]),length=simd_distance(a,z)
            if length<0.15 {continue};let t=(z-a)/length,n=V(t.z,0,-t.x),mid=(a+z)/2
            quad(a,z,z+V(0,4.8,0),a+V(0,4.8,0),stone)
            if length>4 {
                orientedBox(mid+V(0,2.2,0)+n*0.025,t,V(0,1,0),n,V(length*0.83,3.1,0.04),p.cabin)
                for distance in stride(from:Float(1),to:length,by:2.8) {beam(a+t*distance+V(0,0.6,0)+n*0.07,a+t*distance+V(0,4.1,0)+n*0.07,0.1,0.12,p.dark)}
            }
            orientedBox(mid+V(0,4.9,0),t,V(0,1,0),n,V(length+0.1,0.25,1.1),stone)
        }}
        // Warm white service-pedestal lamps match the operator's night dock photo.
        var lampCount=0
        for pier in HydeParkContext.database.piers where pier.points.count>1 {
            for i in 1..<pier.points.count {
                let q=pier.points[i-1],r=pier.points[i],a=V(q[0],-5.02,q[1]),z=V(r[0],-5.02,r[1]),length=simd_distance(a,z)
                if length<12 || a.z<4300 || a.z>5300 {continue}
                lampCount+=1
                if lampCount%3 != 0 {continue}
                let c=(a+z)/2
                box(c+V(0,0.64,0),V(0.32,1.28,0.30),p.white)
                box(c+V(0,1.31,0),V(0.42,0.09,0.40),p.light)
                scene.lights.append(NightLighting.source(c+V(0,1.28,0),toward:c-V(0,0.2,0),power:11,color:V(1,0.86,0.66),range:18,radius:0.36,outerDegrees:98,innerDegrees:68))
            }
        }
    }

    private func hydeParkPromontoryDetails(p:LakefrontPalette,stone:UInt32) {
        // A modest secondary model: mapped field-house footprint plus the
        // clearly visible square limestone tower and dark pyramidal roof.
        guard let b=HydeParkContext.landmark(125502842) else{return}
        let c=V(b.center[0]-4,0,b.center[1]-8),tower=V(5.8,14.5,5.8)
        box(c+V(0,tower.y/2,0),tower,stone)
        for side:Float in [-1,1] {for offset:Float in [-1.5,0,1.5] {
            box(c+V(offset,12.3,side*2.915),V(0.68,1.6,0.035),p.dark)
            box(c+V(side*2.915,12.3,offset),V(0.035,1.6,0.68),p.dark)
        }}
        let apex=c+V(0,19,0),roofMaterial=riverMaterial(V(0.23,0.16,0.13),roughness:0.85,pattern:10)
        for i in 0..<4 {
            let corners:[V]=[V(-3.5,14.7,-3.5),V(3.5,14.7,-3.5),V(3.5,14.7,3.5),V(-3.5,14.7,3.5)]
            tri(c+corners[i],c+corners[(i+1)%4],apex,roofMaterial)
        }
        for s:Float in [-1,1] {
            let light=c+V(s*6,0.4,6)
            scene.lights.append(NightLighting.source(light,toward:c+V(0,8,0),power:52,color:V(1,0.82,0.58),range:28,radius:0.5,outerDegrees:64,innerDegrees:38))
        }
    }

    private func hydeParkStreetFurniture(p:LakefrontPalette) {
        var seen=Set<SIMD2<Int>>()
        for path in HydeParkContext.database.paths where path.elevation<1 && path.points.count>1 {
            let ped=["footway","path","cycleway","pedestrian"].contains(path.kind)
            for i in 1..<path.points.count {
                let a=V(path.points[i-1][0],0,path.points[i-1][1]),b=V(path.points[i][0],0,path.points[i][1]),length=simd_distance(a,b),mid=(a+b)/2
                if length<35 {continue}
                let near=HydeParkContext.detailDistance(mid.x,mid.z)<190
                let lakefront=ped && mid.x>2150 && mid.z>4000 && mid.z<10000 && path.name.contains("Lakefront")
                if !near && !lakefront {continue}
                let t=(b-a)/length,n=V(-t.z,0,t.x),c=mid+n*(path.width/2+0.7)
                let cell=SIMD2(Int(c.x/24),Int(c.z/24));if !seen.insert(cell).inserted {continue}
                if HydeParkContext.containsAuthoredSite(c.x,c.z) {continue}
                let top=c+V(0,ped ? 4.2:6,0)
                cylinder(c,top,0.075,p.dark,segments:6)
                cylinder(top,top+V(0,0.12,0),0.24,p.light,segments:8)
                scene.lights.append(NightLighting.source(top,toward:c,power:ped ? 18:28,color:V(1,0.85,0.64),range:ped ? 19:26,radius:0.50,outerDegrees:91,innerDegrees:66))
                if near && ped {
                    let seat=c+t*2.8
                    orientedBox(seat+V(0,0.48,0),t,V(0,1,0),n,V(1.6,0.12,0.55),p.dock)
                    orientedBox(seat+V(0,0.82,0)+n*0.24,t,V(0,1,0),n,V(1.6,0.54,0.08),p.dock)
                    for s:Float in [-1,1] {beam(seat+t*s*0.6,seat+t*s*0.6+V(0,0.48,0),0.065,0.08,p.dark)}
                }
            }
        }
        // New highway segments and the previously unlit south connection.
        for road in MuseumCampusContext.database.roads+HydeParkContext.database.roads {
            for i in stride(from:0,to:road.points.count-1,by:19) {
                let q=road.points[i],r=road.points[i+1]
                if q[2]<3900 {continue}
                let a=V(q[0],q[1],q[2]),b=V(r[0],r[1],r[2]),t=simd_normalize(b-a),n=V(-t.z,0,t.x),c=a+n*8.4,top=c+V(0,10.5,0),lamp=top-n*3.6
                cylinder(c,top,0.13,p.dark,segments:6);beam(top,lamp,0.12,0.13,p.dark)
                orientedBox(lamp,n,V(0,1,0),t,V(0.9,0.13,0.42),p.light)
                scene.lights.append(NightLighting.source(lamp,toward:a,power:105,color:V(1,0.86,0.68),range:40,radius:0.75,outerDegrees:74,innerDegrees:44))
            }
        }
    }
}
