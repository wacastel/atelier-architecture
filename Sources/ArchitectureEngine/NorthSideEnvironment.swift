import Foundation
import simd

/// Offline ODbL neighborhood geometry in the existing Willis-origin world.
enum NorthSideContext {
    typealias Surface = LakefrontContext.Surface
    typealias Landmark = MuseumCampusContext.Landmark
    struct InlandWater: Decodable { var surface:Surface;var elevation:Float;var elevationSource:String }
    struct Beach: Decodable { var surface:Surface;var elevations:[Float] }
    /// Representative canopy positions sampled inside OSM woodland polygons;
    /// these are authored placements, separate from mapped natural=tree nodes.
    struct LandcoverTree: Decodable {
        var id:Int64;var point:[Float];var height:Float;var sourceAreaID:Int64;var sourceKind:String
    }
    struct Database: Decodable {
        var timestamp:String;var ground:Surface;var water:Surface;var legacyGround:Surface;var legacyWater:Surface
        var inlandWaters:[InlandWater];var beaches:[Beach];var replacedAreaIDs:[Int64];var namedHarbors:[Surface]
        var landmarks:[Landmark];var replacementBuildingIDs:[Int64];var authoredMask:Surface
        var buildings:[ChicagoContext.Building];var areas:[Surface];var legacyAreas:[Surface];var paths:[ChicagoContext.Path]
        var piers:[ChicagoContext.Path];var breakwaters:[ChicagoContext.Path];var trees:[LakefrontContext.Tree]
        var landcoverTrees:[LandcoverTree]
        var roads:[LakefrontContext.Road];var trafficLanes:[LakefrontContext.TrafficLane];var boats:[MuseumCampusContext.Boat]
        var sourceSHA256:[String:String];var previousResourceSHA256:[String:String]
    }
    static let database:Database = {
        var urls:[URL]=[]
        if let r=Bundle.main.resourceURL {
            urls.append(r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/NorthSide/NorthSideContext.json"))
            urls.append(r.appendingPathComponent("Resources/NorthSide/NorthSideContext.json"))
        }
        urls.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/NorthSide/NorthSideContext.json"))
        for url in urls {if let data=try?Data(contentsOf:url),let value=try?JSONDecoder().decode(Database.self,from:data){return value}}
        #if SWIFT_PACKAGE
        let url=Bundle.module.bundleURL.appendingPathComponent("Resources/NorthSide/NorthSideContext.json")
        if let data=try?Data(contentsOf:url),let value=try?JSONDecoder().decode(Database.self,from:data){return value}
        #endif
        fatalError("Bundled NorthSideContext.json is missing or invalid")
    }()
    private static let byID=Dictionary(database.landmarks.map{($0.id,$0)},uniquingKeysWith:{$1})
    static func landmark(_ id:Int64)->Landmark? {byID[id]}
    static let replacementBuildingIDs=Set(database.replacementBuildingIDs)
    static let replacedAreaIDs=Set(database.replacedAreaIDs)
    static func suppressesBuilding(_ id:Int64,_ x:Float,_ z:Float)->Bool {
        replacementBuildingIDs.contains(id) || LakefrontContext.inside(SIMD2(x,z),rings:database.authoredMask.rings)
    }
    static func containsAuthoredSite(_ x:Float,_ z:Float)->Bool {
        LakefrontContext.inside(SIMD2(x,z),rings:database.authoredMask.rings)
    }
    /// Reuse earlier authored-site masks: a larger extract can contain parents
    /// deliberately absent from a previous derivative, including museum shells.
    static func suppressesPreviousLandmark(_ id:Int64,_ x:Float,_ z:Float)->Bool {
        MillenniumContext.suppressesGenericBuilding(id) ||
        LakefrontContext.replacementBuildingIDs.contains(id) ||
        [-174605391,-174605390,150407241,-17460539,-158994370,-15899437].contains(id) ||
        LakefrontContext.containsAuthoredCampus(x,z) ||
        MuseumCampusContext.suppressesBuilding(id,x,z) ||
        (x>=982 && x<=1231 && z >= -200 && z<=48)
    }
    /// Keep the interpreted ground-level marquee passage free of added props.
    /// Endpoints are Wrigley local (0,81) and (0,69), in this shared georeference.
    static func clearsWrigleyEntrance(_ x:Float,_ z:Float)->Bool {
        let a=SIMD2<Float>(-1701.824,-7622.598),b=SIMD2<Float>(-1694.190,-7631.858)
        let p=SIMD2(x,z),d=b-a,t=max(0,min(1,simd_dot(p-a,d)/simd_length_squared(d)))
        return simd_distance(p,a+d*t)<4
    }
    static func wellsStreetX(_ z:Float)->Float {
        if z >= -3599.866 {return 119.710+(101.177-119.710)*(z+2780.929)/(-3599.866+2780.929)}
        return 101.177+(88.628-101.177)*(z+3599.866)/(-4074.679+3599.866)
    }
    /// Facade detail follows walking neighborhoods rather than distance to Willis.
    static func detailDistance(_ x:Float,_ z:Float)->Float {
        func segment(_ ax:Float,_ az:Float,_ bx:Float,_ bz:Float)->Float {
            let p=SIMD2(x,z),a=SIMD2(ax,az),b=SIMD2(bx,bz),d=b-a
            let t=max(0,min(1,simd_dot(p-a,d)/simd_length_squared(d)))
            return simd_distance(p,a+d*t)
        }
        return min(segment(110,-3200,89,-4075),segment(-420,-3600,-280,-4250),segment(90,-4175,-660,-5770),segment(-1510,-7150,-1810,-8050))
    }
}

extension EiffelBuilder {
    func northSideEnvironment() {
        let data=NorthSideContext.database,p=LakefrontPalette(self),saved=randomState
        randomState=0x1977_1984_2026
        let sand=riverMaterial(V(0.63,0.53,0.36),roughness:0.94)
        let brick:[UInt32]=[V(0.34,0.19,0.13),V(0.48,0.29,0.18),V(0.58,0.45,0.29),V(0.34,0.31,0.28),V(0.65,0.59,0.47)].map{riverMaterial($0,roughness:0.78,pattern:19)}
        let windows:[UInt32]=[Float(0),0.055,0.085,0.12,0.16].map{riverMaterial(V(0.09,0.145,0.17),roughness:0.16,metallic:0.58,emission:$0,pattern:14)}
        let awnings:[UInt32]=[V(0.09,0.19,0.16),V(0.29,0.07,0.045),V(0.055,0.09,0.13),V(0.46,0.35,0.21)].map{riverMaterial($0,roughness:0.8)}
        lakefrontSurface(data.ground,y:-0.065,material:pavement)
        lakefrontSurface(data.water,y:-5.7,material:p.water)
        for water in data.inlandWaters {
            lakefrontSurface(water.surface,y:water.elevation,material:p.water)
            // Shallow earth/stone margins meet the exact mapped pool outline.
            for ring in water.surface.rings {for i in ring.indices {
                let a=V(ring[i][0],0,ring[i][1]),b=V(ring[(i+1)%ring.count][0],0,ring[(i+1)%ring.count][1])
                if simd_distance(a,b)>0.03 {quad(a,b,b+V(0,water.elevation-0.1,0),a+V(0,water.elevation-0.1,0),p.stone)}
            }}
        }
        for area in data.areas {
            let y:Float=area.kind == "garden" ? 0.025:area.kind == "pitch" ? 0.019:area.kind == "park" ? -0.04:-0.012
            lakefrontSurface(area,y:y,material:grass)
        }
        for beach in data.beaches {
            let a=beach.surface
            for i in stride(from:0,to:a.triangles.count,by:3) {
                let ids=[a.triangles[i],a.triangles[i+2],a.triangles[i+1]]
                let v=ids.map{V(a.points[$0][0],beach.elevations[$0]+0.004,a.points[$0][1])}
                tri(v[0],v[1],v[2],sand)
            }
        }
        for path in data.paths {northSideRoad(path,p:p)}
        for building in data.buildings {northSideBuilding(building,brick:brick,windows:windows,awnings:awnings,p:p)}
        for road in data.roads {
            lakefrontDrive(road,p:p)
            let pts=road.points.map{V($0[0],$0[1],$0[2])}
            for i in stride(from:10,to:pts.count,by:24) {
                let a=pts[i],b=pts[min(i+1,pts.count-1)],delta=b-a
                if simd_length(delta)<0.01{continue}
                let t=simd_normalize(delta),n=V(-t.z,0,t.x),c=a+n*(road.width/2+0.8),top=c+V(0,10,0),lamp=top-n*3.2
                cylinder(c,top,0.12,p.dark,segments:6);beam(top,lamp,0.12,0.12,p.dark)
                box(lamp,V(0.7,0.12,0.4),p.light)
                scene.lights.append(NightLighting.source(lamp,toward:a,power:92,color:V(1,0.87,0.72),range:38,radius:0.7,outerDegrees:73,innerDegrees:43))
            }
        }
        for pier in data.piers {lakefrontPier(pier,p:p)}
        for wall in data.breakwaters {lakefrontSeawall(wall,p:p)}
        for tree in data.trees {northSideTree(tree,p:p)}
        for tree in data.landcoverTrees {
            northSideTree(LakefrontContext.Tree(id:tree.id,point:tree.point,height:tree.height),p:p)
        }
        for boat in data.boats {
            let c=V(boat.point[0],-5.7,boat.point[1])
            lakefrontBoat(c,length:boat.length,angle:boat.angle,sailboat:boat.sailboat,detailed:boat.detailed,p:p)
            if boat.detailed && boat.id%4==0 {
                let forward=V(sin(boat.angle),0,cos(boat.angle)),right=V(cos(boat.angle),0,-sin(boat.angle))
                let at=c+V(0,1.45,0)-forward*boat.length*0.06
                orientedBox(at,right,V(0,1,0),forward,V(boat.length*0.17,0.06,boat.length*0.23),p.cabin)
                scene.lights.append(NightLighting.source(at,toward:at+right*2-V(0,1,0),power:8,color:V(1,0.80,0.55),range:11,radius:0.45,outerDegrees:98,innerDegrees:70))
            }
        }
        northSideStreetLife(p:p,cloth:awnings)
        northSideWellsStreetDetails()
        scene.trafficLanes=data.trafficLanes.map{SceneTrafficLane(id:$0.id,points:$0.points.map{V($0[0],$0[1],$0[2])},speedMetresPerSecond:$0.speedMetresPerSecond,spawnFadeMetres:$0.spawnFadeMetres)}
        randomState=saved
    }

    private func northSideBuilding(_ b:ChicagoContext.Building,brick:[UInt32],windows:[UInt32],awnings:[UInt32],p:LakefrontPalette) {
        guard b.points.count>2,b.height>0 else{return}
        let points=b.points.map{V($0[0],0.12,$0[1])},center=points.reduce(V.zero,+)/Float(points.count),h=b.height
        // Earlier derivatives deliberately omit authored parents; their IDs can
        // therefore reappear in a larger raw extract without being ID duplicates.
        if NorthSideContext.suppressesPreviousLandmark(b.id,center.x,center.z) {return}
        let distance=NorthSideContext.detailDistance(center.x,center.z),near=distance<150,medium=distance<360
        let seed=UInt64(bitPattern:b.id),stone=brick[Int(seed%UInt64(brick.count))],modern=h>58 || b.material == "glass" || b.material == "steel"
        let wall=modern ? p.glass:stone
        for i in stride(from:0,to:b.triangles.count,by:3) {
            tri(points[b.triangles[i]]+V(0,h,0),points[b.triangles[i+2]]+V(0,h,0),points[b.triangles[i+1]]+V(0,h,0),roof)
        }
        let floors=max(1,min(near ? 24:medium ? 16:8,Int(h/(distance>800 ? 7:3.5))))
        let story=h/Float(floors)
        for i in points.indices {
            let a=points[i],bpt=points[(i+1)%points.count],delta=bpt-a,len=simd_length(delta)
            if len<0.2{continue};let t=delta/len,n=V(t.z,0,-t.x),mid=(a+bpt)/2
            quad(a,bpt,bpt+V(0,h,0),a+V(0,h,0),wall)
            let bays=max(1,min(near ? 18:medium ? 12:6,Int(len/(near ? 3.4:medium ? 5:10))));let bay=len/Float(bays)
            if len>2.3 && h>3 {
                for floor in 0..<floors {
                    for j in 0..<bays {
                        let c=a+t*(Float(j)+0.5)*bay+n*0.022+V(0,(Float(floor)+0.55)*story,0)
                        let windowW=min(bay*0.60,near ? 2.8:8),windowH=min(story*0.54,3.4)
                        let lit=(seed&+UInt64(floor*31+(j/2)*17+i*43))%13
                        let m=windows[lit<4 ? Int(lit)+1:0]
                        quad(c-t*windowW/2-V(0,windowH/2,0),c+t*windowW/2-V(0,windowH/2,0),c+t*windowW/2+V(0,windowH/2,0),c-t*windowW/2+V(0,windowH/2,0),m)
                        if near {
                            for side:Float in[-1,1] {beam(c+t*side*(windowW/2+0.04)-V(0,windowH/2+0.07,0),c+t*side*(windowW/2+0.04)+V(0,windowH/2+0.07,0),0.10,0.12,p.paving)}
                            orientedBox(c+V(0,windowH/2+0.08,0),t,V(0,1,0),n,V(windowW+0.25,0.16,0.18),p.paving)
                            orientedBox(c-V(0,windowH/2+0.10,0)+n*0.07,t,V(0,1,0),n,V(windowW+0.28,0.16,0.32),p.paving)
                            beam(c-V(0,windowH/2,0),c+V(0,windowH/2,0),0.045,0.06,p.dark)
                            beam(c-t*windowW/2,c+t*windowW/2,0.045,0.06,p.dark)
                        }
                    }
                }
            }
            if near || medium {
                orientedBox(mid+V(0,h-0.12,0)+n*0.13,t,V(0,1,0),n,V(len+0.12,0.28,0.46),p.paving)
                if near {orientedBox(mid+V(0,0.32,0)+n*0.06,t,V(0,1,0),n,V(len,0.6,0.2),p.paving)}
            }
            let commercialBand=(center.x>25 && center.x<170 && center.z < -3150 && center.z > -4100) || (center.z < -7350 && center.z > -7900)
            let shop=near && len>5 && len<65 && h<38 && ((commercialBand && seed%3 != 0) || b.kind == "retail" || b.kind == "commercial")
            if shop {
                let front=mid+n*0.06+V(0,1.55,0),width=min(10,len*0.72)
                orientedBox(front,t,V(0,1,0),n,V(width,2.3,0.045),windows[Int(seed%4)+1])
                let door=front-t*width*0.24
                orientedBox(door,t,V(0,1,0),n,V(1.05,2.35,0.075),p.glass)
                for offset:Float in[-0.5,0,0.5] {beam(front+t*width*offset-V(0,1.2,0),front+t*width*offset+V(0,1.2,0),0.09,0.11,p.dark)}
                orientedBox(front+V(0,1.6,0)+n*0.10,t,V(0,1,0),n,V(width+0.4,0.55,0.22),awnings[Int(seed%4)])
                // Shallow fabric awnings stay inside the sidewalk's building edge.
                let upper=front+V(0,1.48,0),outer=upper+n*0.9-V(0,0.3,0)
                quad(upper-t*(width/2+0.15),upper+t*(width/2+0.15),outer+t*(width/2+0.15),outer-t*(width/2+0.15),awnings[Int(seed%4)])
                if i==0 && seed%3==0 {
                    let sign=front-t*width*0.44+V(0,2.0,0)+n*0.85
                    beam(sign-n*0.85+V(0,0.38,0),sign+n*0.32+V(0,0.38,0),0.065,0.08,p.dark)
                    orientedBox(sign,n,V(0,1,0),t,V(0.9,0.65,0.08),awnings[Int(seed%4)])
                    let planter=front+t*(width/2+0.1)-V(0,1.12,0)+n*0.45
                    orientedBox(planter,t,V(0,1,0),n,V(0.65,0.75,0.65),p.paving)
                    ellipsoid(planter+V(0,0.85,0),V(0.33,0.65,0.33),leaf,segments:8,rings:6)
                }
                if i==0 && seed%5==0 {
                    let light=front+V(0,1.3,0)+n*0.5
                    box(light,V(0.18,0.12,0.18),p.light)
                    scene.lights.append(NightLighting.source(light,toward:front+n*2-V(0,1,0),power:10,color:V(1,0.80,0.59),range:12,radius:0.45,outerDegrees:95,innerDegrees:64))
                }
            }
            if near && !shop && len>6 && len<24 && h<18 && i==0 {
                let door=mid+n*0.04+V(0,1.28,0)
                orientedBox(door,t,V(0,1,0),n,V(1.1,2.4,0.08),p.dark)
                for step in 0..<3 {orientedBox(mid+n*(0.5+Float(step)*0.25)+V(0,0.26-Float(step)*0.075,0),t,V(0,1,0),n,V(1.6,0.14,0.5),p.paving)}
            }
        }
        if near && h>4 && !b.hasHoles && seed%3==0 && LakefrontContext.inside(SIMD2(center.x,center.z),rings:[b.points]) {
            box(center+V(0,h+0.65,0),V(min(2.2,sqrt(Float(points.count))),1.1,1.4),p.dark)
        }
    }

    private func northSideRoad(_ path:ChicagoContext.Path,p:LakefrontPalette) {
        let ped=["footway","path","pedestrian","cycleway","steps"].contains(path.kind)
        for i in 1..<path.points.count {
            let a=V(path.points[i-1][0],0.027,path.points[i-1][1]),b=V(path.points[i][0],0.027,path.points[i][1]),delta=b-a,len=simd_length(delta)
            if len<0.05{continue};let t=delta/len,n=V(-t.z,0,t.x),w=path.width/2,mid=(a+b)/2
            quad(a-n*w,a+n*w,b+n*w,b-n*w,ped ? pavement:p.asphalt)
            if !path.bridge.isEmpty {orientedBox(mid-V(0,0.25,0),n,V(0,1,0),t,V(path.width,0.48,len),p.paving)}
            if !ped {
                let near=NorthSideContext.detailDistance(mid.x,mid.z)<230
                for side:Float in[-1,1] {
                    let aa=a+n*side*(w+0.08)+V(0,0.075,0),bb=b+n*side*(w+0.08)+V(0,0.075,0)
                    quad(aa,aa+n*side*2.5,bb+n*side*2.5,bb,pavement)
                    if near {beam(aa,bb,0.15,0.19,p.paving)}
                }
                if near && len>12 {
                    for d in stride(from:Float(2),to:len-2,by:8) {
                        let c=a+t*d+V(0,0.009,0)
                        quad(c-t*1.4-n*0.055,c-t*1.4+n*0.055,c+t*1.4+n*0.055,c+t*1.4-n*0.055,p.white)
                    }
                }
            }
        }
    }

    private func northSideTree(_ tree:LakefrontContext.Tree,p:LakefrontPalette) {
        if NorthSideContext.clearsWrigleyEntrance(tree.point[0],tree.point[1]) {return}
        let c=V(tree.point[0],0,tree.point[1]),h=tree.height,near=NorthSideContext.detailDistance(c.x,c.z)<160
        cylinder(c,c+V(0,h*0.70,0),near ? 0.20:0.15,bark,segments:near ? 8:5)
        let count=near ? 4:1
        for i in 0..<count {
            let theta=Float(i)*2.4+Float(tree.id%29),v=c+V(cos(theta)*(near ? 1.3:0),h*(0.71+Float(i%2)*0.07),sin(theta)*(near ? 1.3:0))
            if near {cylinder(c+V(0,h*0.42,0),v,0.065,bark,segments:5)}
            lakefrontSmoothCrown(v,V(near ? 2.1:h*0.29,h*0.25,near ? 2.1:h*0.29),i%3==0 ? leafLight:leaf,segments:near ? 12:8,rings:near ? 7:4)
        }
    }

    private func northSideStreetLife(p:LakefrontPalette,cloth:[UInt32]) {
        var count=0
        let streetPaths=ChicagoContext.database.paths+LakefrontContext.database.paths+NorthSideContext.database.paths
        for path in streetPaths where ["residential","tertiary","secondary","primary"].contains(path.kind) {
            for i in 1..<path.points.count {
                let a=V(path.points[i-1][0],0,path.points[i-1][1]),b=V(path.points[i][0],0,path.points[i][1]),len=simd_distance(a,b),mid=(a+b)/2
                if len<30 || mid.z > -3200 || NorthSideContext.detailDistance(mid.x,mid.z)>110 {continue}
                let t=(b-a)/len,n=V(-t.z,0,t.x),side:Float=(path.id%2==0 ? 1:-1),c=mid+n*side*(path.width/2+1.95)
                if NorthSideContext.containsAuthoredSite(c.x,c.z) || NorthSideContext.clearsWrigleyEntrance(c.x,c.z) || NorthSideContext.clearsWrigleyEntrance(c.x+t.x*2.5,c.z+t.z*2.5) || NorthSideContext.clearsWrigleyEntrance(c.x-t.x*2.2,c.z-t.z*2.2){continue}
                count+=1
                let top=c+V(0,5.5,0)
                cylinder(c,top,0.065,p.dark,segments:6)
                cylinder(top-V(0,0.2,0),top+V(0,0.1,0),0.20,p.light,segments:8)
                scene.lights.append(NightLighting.source(top,toward:c,power:21,color:V(1,0.85,0.67),range:20,radius:0.55,outerDegrees:91,innerDegrees:68))
                if count%2==0 {
                    let seat=c+t*2.5
                    orientedBox(seat+V(0,0.53,0),t,V(0,1,0),n,V(1.5,0.10,0.5),p.dock)
                    orientedBox(seat+n*0.22+V(0,0.88,0),t,V(0,1,0),n,V(1.5,0.60,0.07),p.dock)
                    for s:Float in[-1,1] {beam(seat+t*s*0.55,seat+t*s*0.55+V(0,0.5,0),0.065,0.08,p.dark)}
                }
                if count%3==0 {
                    let person=c-t*2.2
                    for s:Float in[-1,1] {cylinder(person+t*s*0.12+V(0,0.10,0),person+t*s*0.12+V(0,0.88,0),0.075,p.dark,segments:6)}
                    ellipsoid(person+V(0,1.12,0),V(0.23,0.36,0.15),cloth[count%cloth.count],segments:8,rings:5)
                    ellipsoid(person+V(0,1.63,0),V(0.14,0.18,0.14),limestone,segments:8,rings:5)
                    for s:Float in[-1,1] {cylinder(person+t*s*0.27+V(0,0.86,0),person+t*s*0.22+V(0,1.31,0),0.06,cloth[count%cloth.count],segments:6)}
                }
            }
        }
    }

    /// Additional ground-floor treatments for older mapped shells. The original
    /// walls, upper facades and roofs remain intact, and no business is identified.
    func northSideWellsStreetDetails() {
        let p=LakefrontPalette(self),up=V(0,1,0)
        let painted=[V(0.045,0.13,0.11),V(0.29,0.065,0.043),V(0.06,0.10,0.15),V(0.29,0.20,0.12)].map{riverMaterial($0,roughness:0.66)}
        let glass=riverMaterial(V(0.09,0.16,0.17),roughness:0.13,metallic:0.48,emission:0.055,pattern:14)
        let cream=riverMaterial(V(0.70,0.62,0.45),roughness:0.73)
        let old=ChicagoContext.database.buildings+LakefrontContext.database.buildings
        struct Shop {var c,t,n:V;var width,height,distance:Float;var id:Int64;var edge:Int}
        var candidates:[Shop]=[]
        for building in old where building.height>3.2 && building.points.count>2 {
            let pts=building.points.map{V($0[0],0,$0[1])},center=pts.reduce(V.zero,+)/Float(pts.count)
            if center.z < -4160 || center.z > -3190 || abs(center.x-NorthSideContext.wellsStreetX(center.z))>65 {continue}
            if NorthSideContext.suppressesPreviousLandmark(building.id,center.x,center.z) || NorthSideContext.suppressesBuilding(building.id,center.x,center.z) {continue}
            for i in pts.indices {
                let a=pts[i],b=pts[(i+1)%pts.count],delta=b-a,length=simd_length(delta)
                if length<5 || length>100 {continue}
                let t=delta/length,n=V(t.z,0,-t.x),mid=(a+b)/2
                let toward=NorthSideContext.wellsStreetX(mid.z)-mid.x
                if abs(n.x)<0.84 || n.x*toward<=0 {continue}
                let bays=max(1,Int(length/9)),spacing=length/Float(bays)
                for j in 0..<bays {
                    let c=a+t*(Float(j)+0.5)*spacing,distance=abs(c.x-NorthSideContext.wellsStreetX(c.z))
                    if c.z < -4100 || c.z > -3250 || distance<9.5 || distance>28 {continue}
                    candidates.append(Shop(c:c,t:t,n:n,width:min(8.3,spacing-0.65),height:min(3.25,building.height-0.3),distance:distance,id:building.id,edge:i*101+j))
                }
            }
        }
        // Only the foremost mapped frontage at a given street interval receives
        // a shop; parent/part records and recessed courtyards cannot stack signs.
        candidates.sort { $0.distance == $1.distance ? ($0.id == $1.id ? $0.edge<$1.edge:$0.id<$1.id):$0.distance<$1.distance }
        var selected:[Shop]=[]
        for shop in candidates {
            if selected.contains(where:{$0.n.x*shop.n.x>0 && abs($0.c.z-shop.c.z)<($0.width+shop.width)*0.50+0.4}) {continue}
            selected.append(shop)
        }
        selected.sort{$0.c.z == $1.c.z ? $0.c.x<$1.c.x:$0.c.z<$1.c.z}
        var lampCount=0
        for (index,s) in selected.enumerated() {
            let t=s.t,n=s.n,w=s.width,h=s.height,c=s.c+n*0.34+up*0.12
            let paint=painted[Int(UInt64(bitPattern:s.id)%4)]
            // A shallow joinery frame overlays only the first storey. Its rear
            // is beyond existing 0.28m facade piers to avoid coplanar flicker.
            orientedBox(c+up*h/2,t,up,n,V(w,h,0.10),paint)
            let paneH=h-0.73,paneW=w-0.52,pane=c+up*(0.49+paneH/2)+n*0.075
            orientedBox(pane,t,up,n,V(paneW,paneH,0.045),glass)
            for fraction:Float in[-0.5,-0.18,0.18,0.5] {
                orientedBox(pane+t*paneW*fraction+n*0.035,t,up,n,V(0.085,paneH+0.10,0.11),paint)
            }
            orientedBox(pane+up*(paneH*0.23)+n*0.04,t,up,n,V(paneW,0.07,0.10),paint)
            for y:Float in[0.23,h-0.11] {orientedBox(c+up*y+n*0.10,t,up,n,V(w+0.12,0.18,0.23),paint)}
            let door=c+t*(paneW*0.33)+up*1.35+n*0.16
            orientedBox(door,t,up,n,V(min(1.0,w*0.16),2.30,0.10),glass)
            for side:Float in[-1,1] {beam(door+t*side*0.52-up*1.16,door+t*side*0.52+up*1.16,0.075,0.10,paint)}
            cylinder(door-t*0.34+n*0.10-up*0.16,door-t*0.34+n*0.10+up*0.14,0.025,p.bronze,segments:6)
            let fascia=c+up*(h+0.25)+n*0.11
            orientedBox(fascia,t,up,n,V(w+0.10,0.43,0.19),paint)
            // Abstract small inset bars supply sign rhythm without invented names.
            for j in -1...1 {orientedBox(fascia+t*Float(j)*w*0.20+n*0.105,t,up,n,V(w*0.11,0.035,0.02),cream)}
            if index%3 != 1 {
                let upper=c+up*(h+0.45),outer=upper+n*1.12-up*0.36
                quad(upper-t*w/2,upper+t*w/2,outer+t*w/2,outer-t*w/2,paint)
                orientedBox(outer-up*0.09,t,up,n,V(w,0.18,0.045),paint)
                for side:Float in[-1,1] {beam(c+t*side*(w/2-0.16)+up*(h-0.45),outer+t*side*(w/2-0.16),0.055,0.06,p.dark)}
            }
            if index%4==0 {
                let sign=c-t*(w/2-0.50)+up*(h+0.22)+n*1.08
                beam(sign-n*1.05+up*0.42,sign+n*0.38+up*0.42,0.055,0.065,p.dark)
                orientedBox(sign,n,up,t,V(0.86,0.66,0.08),paint)
                for side:Float in[-1,1] {orientedBox(sign+t*side*0.046,n,up,t,V(0.51,0.045,0.012),cream)}
            }
            if index%3==0 {
                let planter=c+t*(w/2-0.34)+n*0.74+up*0.29
                orientedBox(planter,t,up,n,V(0.62,0.57,0.67),paint)
                ellipsoid(planter+up*0.74,V(0.29,0.63,0.30),leaf,segments:10,rings:6)
            }
            if index%7==0 && lampCount<12 {
                let at=c-t*(w/2-0.38)+n*0.45+up*(h-0.04)
                cylinder(at-up*0.18,at+up*0.15,0.12,p.light,segments:8)
                scene.lights.append(NightLighting.source(at,toward:at+n*1.8-up*1.6,power:12,color:V(1,0.80,0.54),range:13,radius:0.48,outerDegrees:94,innerDegrees:64));lampCount+=1
            }
        }
        // Sampling by geographic distance also works when OSM divides the road
        // into many short segments. Cross-street carriageways remain empty.
        let paths=ChicagoContext.database.paths+LakefrontContext.database.paths+NorthSideContext.database.paths
        let crossStreets=paths.filter{["residential","tertiary","secondary","primary","service"].contains($0.kind) && !$0.name.contains("Wells") && $0.points.contains{q in q[0]>65 && q[0]<150 && q[1] < -3200 && q[1] > -4150}}
        let nearbyBuildings=old+NorthSideContext.database.buildings
        func freeSidewalk(_ point:V)->Bool {
            for path in crossStreets {for i in 1..<path.points.count {
                let a=V(path.points[i-1][0],0,path.points[i-1][1]),b=V(path.points[i][0],0,path.points[i][1]),d=b-a
                if simd_length_squared(d)<0.001 {continue}
                let t=max(0,min(1,simd_dot(point-a,d)/simd_length_squared(d)))
                if simd_distance(point,a+d*t)<path.width/2+2.1 {return false}
            }}
            return !nearbyBuildings.contains{b in b.points.contains{abs($0[0]-point.x)<5 && abs($0[1]-point.z)<8} && LakefrontContext.inside(SIMD2(point.x,point.z),rings:[b.points])}
        }
        for index in 0..<29 {
            let z:Float = -3265-Float(index)*28,side:Float=index%2==0 ? 1:-1,c=V(NorthSideContext.wellsStreetX(z)+side*6.15,0,z)
            if !freeSidewalk(c) {continue}
            let t=V(0,0,1),n=V(side,0,0)
            if index%3==0 {
                let seat=c+n*0.12
                orientedBox(seat+up*0.49,t,up,n,V(1.65,0.10,0.49),p.dock)
                orientedBox(seat+n*0.24+up*0.81,t,up,n,V(1.65,0.56,0.08),p.dock)
                for s:Float in[-1,1] {beam(seat+t*s*0.59,seat+t*s*0.59+up*0.49,0.065,0.08,p.dark)}
            } else {
                let paint=painted[index%4]
                for s:Float in[-1,1] {cylinder(c+t*s*0.11+up*0.12,c+t*s*0.11+up*0.88,0.07,p.dark,segments:6)}
                ellipsoid(c+up*1.14,V(0.22,0.34,0.15),paint,segments:8,rings:5)
                ellipsoid(c+up*1.63,V(0.135,0.18,0.135),limestone,segments:8,rings:5)
                for s:Float in[-1,1] {cylinder(c+t*s*0.27+up*0.90,c+t*s*0.21+up*1.33,0.055,paint,segments:6)}
            }
        }
    }
}
