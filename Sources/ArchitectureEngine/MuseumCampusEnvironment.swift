import Foundation
import simd

/// Offline geometry uses the same Willis-origin coordinates as every Chicago destination.
enum MuseumCampusContext {
    typealias Surface = LakefrontContext.Surface
    struct Landmark:Decodable {
        var id:Int64;var name:String;var points:[[Float]];var triangles:[Int];var rings:[[[Float]]]
        var center:[Float];var bounds:[Float];var tags:[String:String]
    }
    struct Boat:Decodable {var id:Int64;var point:[Float];var length:Float;var angle:Float;var sailboat:Bool;var detailed:Bool}
    struct Database:Decodable {
        var timestamp:String;var ground:Surface;var water:Surface;var legacyGround:Surface;var legacyWater:Surface;var namedWaters:[Surface]
        var landmarks:[Landmark];var replacementBuildingIDs:[Int64];var authoredMask:Surface;var approaches:Surface
        var buildings:[ChicagoContext.Building];var areas:[Surface];var paths:[ChicagoContext.Path]
        var piers:[ChicagoContext.Path];var breakwaters:[ChicagoContext.Path];var trees:[LakefrontContext.Tree]
        var roads:[LakefrontContext.Road];var trafficLanes:[LakefrontContext.TrafficLane];var boats:[Boat]
        var sourceSHA256:String;var previousLakefrontSHA256:String
    }
    static let database:Database = {
        var urls:[URL]=[]
        if let r=Bundle.main.resourceURL {
            urls.append(r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/MuseumCampus/MuseumCampusContext.json"))
            urls.append(r.appendingPathComponent("Resources/MuseumCampus/MuseumCampusContext.json"))
        }
        urls.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/MuseumCampus/MuseumCampusContext.json"))
        for u in urls {if let d=try?Data(contentsOf:u),let value=try?JSONDecoder().decode(Database.self,from:d){return value}}
        #if SWIFT_PACKAGE
        let u=Bundle.module.bundleURL.appendingPathComponent("Resources/MuseumCampus/MuseumCampusContext.json")
        if let d=try?Data(contentsOf:u),let value=try?JSONDecoder().decode(Database.self,from:d){return value}
        #endif
        fatalError("Bundled MuseumCampusContext.json is missing or invalid")
    }()
    private static let byID=Dictionary(database.landmarks.map{($0.id,$0)},uniquingKeysWith:{$1})
    static func landmark(_ id:Int64)->Landmark? {byID[id]}
    private static let replacementIDs=Set(database.replacementBuildingIDs)
    static func suppressesBuilding(_ id:Int64,_ x:Float,_ z:Float)->Bool {
        id == -18999713 || id == 766375454 || replacementIDs.contains(id) || LakefrontContext.inside(SIMD2(x,z),rings:database.authoredMask.rings)
    }
    static func clearsApproach(_ x:Float,_ z:Float)->Bool {
        LakefrontContext.inside(SIMD2(x,z),rings:database.approaches.rings) || LakefrontContext.inside(SIMD2(x,z),rings:database.authoredMask.rings)
    }
    static func interpretedBuilding(_ building:ChicagoContext.Building)->ChicagoContext.Building {
        guard building.heightSource == "estimated",!building.points.isEmpty else{return building}
        if building.id == 445721198 {
            // Museum Campus Cafe is a low concession roof in the inspected
            // aerial, not the 34m city-block fallback. No mapped height exists.
            var result=building;result.height=4.5;result.heightSource="estimated-low-rise-campus-cafe"
            return result
        }
        let c=building.points.reduce(SIMD2<Float>.zero){$0+SIMD2($1[0],$1[1])}/Float(building.points.count)
        guard c.x>1800 && c.x<2350 && c.y>1400 && c.y<2660 else{return building}
        // Harbor offices, boathouses and the former airfield terminal are low
        // facilities in the inspected aerial, not randomly tall city blocks.
        // Preserve every measured/tagged height and retain the raw map estimate.
        var result=building
        result.height=building.kind == "grandstand" ? 8:building.kind == "tent" ? 6.4:building.name.contains("Visitor") ? 6.5:5.5
        result.heightSource="estimated-low-rise-harbor-facility"
        return result
    }
}

extension EiffelBuilder {
    func museumCampusEnvironment() {
        let d=MuseumCampusContext.database,p=LakefrontPalette(self),saved=randomState
        randomState=0xCA16_2026_ABCD
        // Adjacent southern strip only: the previous shoreline/ground remains intact.
        lakefrontSurface(d.ground,y:-0.065,material:pavement)
        lakefrontSurface(d.water,y:-5.7,material:p.water)
        for a in d.areas {
            let y:Float=a.kind == "garden" ? 0.025:a.kind == "pitch" ? 0.019:a.kind == "park" ? -0.04:a.kind == "sand" ? -0.006:-0.012
            lakefrontSurface(a,y:y,material:a.kind == "sand" ? p.sand:grass)
        }
        for road in d.roads {lakefrontDrive(road,p:p)}
        for pier in d.piers {lakefrontPier(pier,p:p)}
        for wall in d.breakwaters where (wall.points.first?[0] ?? 0)>1400 {lakefrontSeawall(wall,p:p)}
        for tree in d.trees {museumCampusTree(tree,p:p)}
        for (index,boat) in d.boats.enumerated() {
            lakefrontBoat(V(boat.point[0],-5.7,boat.point[1]),length:boat.length,angle:boat.angle,sailboat:boat.sailboat,detailed:boat.detailed,p:p)
            if boat.detailed && index%2==0 {
                let c=V(boat.point[0],-5.7,boat.point[1]),forward=V(sin(boat.angle),0,cos(boat.angle)),right=V(cos(boat.angle),0,-sin(boat.angle))
                for side:Float in [-1,1] {
                    let lamp=c+right*side*boat.length*0.103+V(0,1.24,0)
                    orientedBox(lamp,forward,V(0,1,0),right,V(boat.length*0.19,0.26,0.032),p.light)
                    scene.lights.append(NightLighting.source(lamp+right*side*0.05,toward:lamp+right*side*2-V(0,0.8,0),power:3.3,color:V(1,0.78,0.48),range:11,radius:0.22,outerDegrees:88,innerDegrees:56))
                }
            }
        }
        museumCampusTicketPavilion(p:p)
        museumCampusFurniture(p:p)
        scene.trafficLanes=d.trafficLanes.map{SceneTrafficLane(id:$0.id,points:$0.points.map{V($0[0],$0[1],$0[2])},speedMetresPerSecond:$0.speedMetresPerSecond,spawnFadeMetres:$0.spawnFadeMetres)}
        randomState=saved
    }
    private func museumCampusTicketPavilion(p:LakefrontPalette) {
        // OSM relation18999713 / outer766375454: the reference photograph shows
        // a single-storey curved glass ticket pavilion and broad cream canopy.
        guard let landmark=MuseumCampusContext.landmark(-18999713) else{return}
        let c=V(landmark.center[0],0,landmark.center[1])
        let canopy=riverMaterial(V(0.77,0.75,0.66),roughness:0.58)
        let glazing=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.94,0.97,0.97),roughness:0.07,transmission:0.82))
        func at(_ q:[Float],_ y:Float,_ scale:Float=1)->V {c+V((q[0]-c.x)*scale,y,(q[1]-c.z)*scale)}
        for i in stride(from:0,to:landmark.triangles.count,by:3) {
            let a=landmark.points[landmark.triangles[i]],b=landmark.points[landmark.triangles[i+1]],d=landmark.points[landmark.triangles[i+2]]
            tri(at(a,0.10),at(d,0.10),at(b,0.10),p.paving)
            tri(at(a,4.50),at(d,4.50),at(b,4.50),canopy)
            tri(at(a,4.17),at(b,4.17),at(d,4.17),canopy)
        }
        for ring in landmark.rings {for i in ring.indices {
            let q=ring[i],r=ring[(i+1)%ring.count],a=at(q,0.12,0.88),b=at(r,0.12,0.88),t=simd_normalize(b-a),n=V(-t.z,0,t.x),length=simd_distance(a,b)
            quad(at(q,4.17),at(r,4.17),at(r,4.50),at(q,4.50),canopy)
            quad(a,b,b+V(0,3.95,0),a+V(0,3.95,0),glazing)
            beam(a,b,0.10,0.09,p.dark)
            beam(a+V(0,3.94,0),b+V(0,3.94,0),0.10,0.10,p.dark)
            let bays=max(1,Int(ceil(length/1.5)))
            for bay in 0..<bays {
                let base=simd_mix(a,b,V(repeating:Float(bay)/Float(bays)))
                cylinder(base,base+V(0,3.95,0),0.045,p.dark,segments:8)
            }
            if i%4==0 {
                let lamp=(a+b)/2+V(0,4.03,0)+n*0.35
                orientedBox(lamp,t,V(0,1,0),n,V(min(2.0,length*0.7),0.04,0.10),p.light)
                scene.lights.append(NightLighting.source(lamp-V(0,0.05,0),toward:c+V(0,0.3,0),power:9,color:V(1,0.82,0.57),range:14,radius:0.35,outerDegrees:78,innerDegrees:48))
            }
        }}
        // A small row of ticket kiosks supplies visible interior scale; public
        // exhibit content is interpreted, not a reproduction of operational UI.
        for i in -1...1 {
            let q=c+V(Float(i)*1.8,0,0)
            box(q+V(0,0.84,0),V(0.62,1.48,0.40),p.white)
            box(q+V(0,1.18,-0.21),V(0.48,0.36,0.025),p.glass)
            box(q+V(0,0.77,-0.25),V(0.52,0.09,0.18),p.dark)
        }
    }
    private func museumCampusTree(_ tree:LakefrontContext.Tree,p:LakefrontPalette) {
        let c=V(tree.point[0],0,tree.point[1]),h=tree.height
        let near=min(simd_distance(c,V(1565,0,1320)),simd_distance(c,V(1840,0,2000)),simd_distance(c,V(2450,0,1360)),simd_distance(c,V(1910,0,2720)))<170
        cylinder(c,c+V(0,h*0.68,0),near ? 0.18:0.14,bark,segments:near ? 8:5)
        lakefrontSmoothCrown(c+V(0,h*0.71,0),V(h*0.28,h*0.35,h*0.27),near ? leaf:grass,segments:near ? 10:6,rings:near ? 7:4)
        if near {
            for side:Float in [-1,1] {
                let q=c+V(side*h*0.16,h*0.74,side*h*0.13)
                cylinder(c+V(0,h*0.42,0),q,0.09,bark,segments:5)
                lakefrontSmoothCrown(q,V(h*0.20,h*0.25,h*0.23),leaf,segments:8,rings:5)
            }
        }
    }
    private func museumCampusFurniture(p:LakefrontPalette) {
        // Low, warm promenade luminaires between museum grounds and the harbor.
        let routes:[[V]]=[
            [V(1760,0,1460),V(1774,0,1630),V(1790,0,1820),V(1805,0,2040),V(1822,0,2300),V(1840,0,2490)],
            [V(1860,0,1380),V(2060,0,1330),V(2250,0,1360),V(2362,0,1430)],
            [V(2240,0,1610),V(2250,0,1860),V(2230,0,2110),V(2215,0,2400)]]
        for route in routes {for i in 1..<route.count {
            let a=route[i-1],b=route[i],length=simd_distance(a,b),t=(b-a)/length
            for distance in stride(from:Float(13),to:length,by:44) {
                let c=a+t*distance
                // Authored approximate light positions must remain on actual land.
                if LakefrontContext.inside(SIMD2(c.x,c.z),rings:LakefrontContext.database.water.rings) || MuseumCampusContext.clearsApproach(c.x,c.z){continue}
                cylinder(c,c+V(0,4.5,0),0.085,p.dark,segments:8)
                cylinder(c+V(0,4.48,0),c+V(0,4.65,0),0.36,p.light,segments:12)
                scene.lights.append(NightLighting.source(c+V(0,4.42,0),toward:c,power:23,color:V(1,0.82,0.60),range:24,radius:0.38,outerDegrees:80,innerDegrees:48))
                box(c+V(2,0.48,0),V(1.65,0.13,0.52),bark)
                for xx:Float in [1.36,2.64] {box(V(c.x+xx,0.25,c.z),V(0.10,0.50,0.44),p.dark)}
            }
        }}
        // Extend highway illumination continuously south of the old lamp range.
        for road in LakefrontContext.database.roads+MuseumCampusContext.database.roads {
            let points=road.points
            for i in stride(from:0,to:points.count,by:16) where points[i][2]>=1700 && points[i][2]<3900 {
                let q=points[i],r=points[min(i+1,points.count-1)],a=V(q[0],q[1],q[2]),b=V(r[0],r[1],r[2])
                guard simd_distance(a,b)>0.01 else{continue}
                let t=simd_normalize(b-a),n=V(-t.z,0,t.x),c=a+n*8.5,top=c+V(0,11,0),lamp=top-n*3.7
                cylinder(c,top,0.14,p.dark,segments:8);beam(top,lamp,0.13,0.13,p.dark)
                box(lamp,V(0.85,0.14,0.45),p.light)
                scene.lights.append(NightLighting.source(lamp-V(0,0.12,0),toward:a,power:115,color:V(1,0.86,0.68),range:42,radius:0.7,outerDegrees:74,innerDegrees:43))
            }
        }
        // Power pedestals on mapped dock spines; emissive fixtures plus finite lights.
        for pier in LakefrontContext.database.piers+MuseumCampusContext.database.piers {
            guard pier.points.count>1 else{continue}
            let q=pier.points[0],r=pier.points[pier.points.count-1]
            guard q[0]>1810 && q[1]>1480 && q[1]<2690 else{continue}
            let a=V(q[0],-5.03,q[1]),b=V(r[0],-5.03,r[1]),length=simd_distance(a,b)
            guard length>45 else{continue};let t=(b-a)/length
            for f in stride(from:Float(14),to:length-7,by:35) {
                let c=a+t*f;box(c+V(0,0.44,0),V(0.32,0.88,0.28),p.white)
                box(c+V(0,0.85,0),V(0.35,0.09,0.31),p.light)
                for side:Float in [-1,1] {
                    scene.lights.append(NightLighting.source(c+V(side*0.20,1.0,0),toward:c+V(side*2,-0.2,0),power:6.0,color:V(1,0.85,0.63),range:18,radius:0.24,outerDegrees:87,innerDegrees:58))
                }
            }
        }
    }
}
