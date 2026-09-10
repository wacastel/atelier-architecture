import Foundation
import simd

/// Dated OSM approach landscaping in the shared Willis-origin world.
/// Detailed pier architecture is authored separately in NavyPier.swift.
enum NavyPierContext {
    typealias Surface = LakefrontContext.Surface
    struct RetainedPath: Decodable { var id:Int64;var parts:[ChicagoContext.Path] }
    struct Furniture: Decodable { var id:Int64;var point:[Float];var kind:String }
    struct Landmark: Decodable { var id:Int64;var name:String;var point:[Float];var bounds:[Float] }
    struct Database: Decodable {
        var timestamp:String;var authoredPierMask:Surface;var approachMask:Surface
        var buildings:[ChicagoContext.Building];var newBuildingIDs:[Int64];var replacementAreaIDs:[Int64]
        var areas:[Surface];var paths:[ChicagoContext.Path];var roadSurfaces:[Surface]
        var retainedPaths:[RetainedPath];var trees:[LakefrontContext.Tree];var furniture:[Furniture]
        var fountains:[Surface];var landmarks:[Landmark];var sourceSHA256:[String:String]
    }
    static let database:Database = {
        var urls:[URL]=[]
        if let r=Bundle.main.resourceURL {
            urls.append(r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/NavyPier/NavyPierContext.json"))
            urls.append(r.appendingPathComponent("Resources/NavyPier/NavyPierContext.json"))
        }
        urls.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/NavyPier/NavyPierContext.json"))
        for u in urls {if let d=try?Data(contentsOf:u),let v=try?JSONDecoder().decode(Database.self,from:d){return v}}
        #if SWIFT_PACKAGE
        let u=Bundle.module.bundleURL.appendingPathComponent("Resources/NavyPier/NavyPierContext.json")
        if let d=try?Data(contentsOf:u),let v=try?JSONDecoder().decode(Database.self,from:d){return v}
        #endif
        fatalError("Bundled NavyPierContext.json is missing or invalid")
    }()
    static let replacementAreaIDs=Set(database.replacementAreaIDs)
    private static let pathParts=Dictionary(uniqueKeysWithValues:database.retainedPaths.map{($0.id,$0.parts)})
    static func containsPier(_ x:Float,_ z:Float)->Bool {x>=2165 && x<=3105 && z >= -1620 && z <= -1340}
    static func suppressesBuilding(_ id:Int64,_ x:Float,_ z:Float)->Bool {[751729625,1308482808].contains(id) || containsPier(x,z)}
    static func containsApproach(_ x:Float,_ z:Float)->Bool {
        guard x>1820 && x<2225 && z > -1940 && z < -1190 else{return false}
        return LakefrontContext.inside(SIMD2(x,z),rings:database.approachMask.rings)
    }
    static func retained(_ p:ChicagoContext.Path)->[ChicagoContext.Path] {
        // Old eastward paths end at the former extract boundary midway through
        // the pier. The new landmark owns its full unobstructed promenade.
        if !p.points.isEmpty && p.points.allSatisfy({containsPier($0[0],$0[1])}) {return []}
        return pathParts[p.id] ?? [p]
    }
}

extension EiffelBuilder {
    func navyPierEnvironment() {
        let data=NavyPierContext.database,p=LakefrontPalette(self),saved=randomState
        randomState=0x1916_2016_2026
        for area in data.areas {
            lakefrontSurface(area,y:area.kind == "garden" ? 0.035:-0.025,material:area.kind == "sand" ? p.sand:grass)
        }
        for surface in data.roadSurfaces {
            lakefrontSurface(surface,y:surface.kind == "asphalt" ? 0.027:0.080,material:surface.kind == "asphalt" ? p.asphalt:p.paving)
        }
        let newIDs=Set(data.newBuildingIDs)
        let windowMaterials:[UInt32]=[Float(0),0.065,0.095,0.135,0.19].map{riverMaterial(V(0.105,0.17,0.19),roughness:0.13,metallic:0.72,emission:$0,pattern:14)}
        for building in data.buildings where newIDs.contains(building.id) {
            chicagoBuilding(building,masonry:p.stone,granite:p.paving,pale:limestone,blue:p.glass,gray:p.dark,windows:windowMaterials)
        }
        navyWelcomePavilion(p:p)
        navyButterflyHouse(p:p)
        for tree in data.trees {
            let c=V(tree.point[0],0.07,tree.point[1]),h=tree.height
            cylinder(c,c+V(0,h*0.7,0),0.19,bark,segments:7)
            for j in 0..<3 {
                let a=Float(j)*2.39996+Float(tree.id%31),top=c+V(cos(a)*1.1,h*(0.68+Float(j)*0.055),sin(a)*1.1)
                cylinder(c+V(0,h*0.42,0),top,0.07,bark,segments:5)
                lakefrontSmoothCrown(top,V(h*0.26,h*0.27,h*0.26),j==0 ? leafLight:leaf,segments:10,rings:6)
            }
        }
        for item in data.furniture {
            let c=V(item.point[0],0.10,item.point[1])
            switch item.kind {
            case "bench": bench(c,alongX:item.id%2==0)
            case "street_lamp":
                // Limit shadow sources, preserving fixtures along the whole path.
                let top=c+V(0,4.5,0)
                cylinder(c,top,0.06,p.dark,segments:6)
                box(top,V(0.7,0.12,0.32),p.light)
                if item.id%3==0 {scene.lights.append(NightLighting.source(top-V(0,0.1,0),toward:c,power:34,color:V(1,0.84,0.63),range:18,radius:0.4,outerDegrees:82,innerDegrees:57))}
            default: box(c+V(0,0.48,0),V(0.40,0.96,0.35),p.dark)
            }
        }
        for fountain in data.fountains {
            // Mapped plaza footprint; nozzle layout and gentle jets are an
            // interpretation, rather than a survey of installed fountain heads.
            lakefrontSurface(fountain,y:0.089,material:p.dark)
            let all=fountain.points.map{SIMD2<Float>($0[0],$0[1])}
            guard !all.isEmpty else{continue}
            let minimum=all.reduce(all[0]){simd_min($0,$1)},maximum=all.reduce(all[0]){simd_max($0,$1)}
            for x in stride(from:minimum.x+3,to:maximum.x-2,by:5) {for z in stride(from:minimum.y+3,to:maximum.y-2,by:5) {
                guard LakefrontContext.inside(SIMD2(x,z),rings:fountain.rings)else{continue}
                let q=V(x,0.10,z),h:Float=0.5+Float(abs(Int(x*3+z*7))%6)*0.19
                cylinder(q,q+V(0,0.03,0),0.16,p.dark,segments:8)
                cylinder(q+V(0,0.03,0),q+V(0,h,0),0.035,p.foam,segments:6)
            }}
        }
        randomState=saved
    }

    /// The old generic height estimator made this one-storey pavilion 45.4 m
    /// tall. Its OSM outline is retained; photo-estimated glazing/roof heights
    /// follow the official exterior photograph and documented green roof.
    private func navyWelcomePavilion(p:LakefrontPalette) {
        guard let building=NavyPierContext.database.buildings.first(where:{$0.id==751729625}) else{return}
        let outer=building.points.map{V($0[0],0.12,$0[1])}
        let center=outer.reduce(V.zero,+)/Float(outer.count)
        let glazing=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.91,0.96,0.95),roughness:0.07,metallic:0.1,transmission:0.75))
        let roofGreen=riverMaterial(V(0.12,0.23,0.065),roughness:0.95,pattern:10)
        func top(_ point:V)->V {V(point.x,4.6+(point.z+1341)*0.027,point.z)}
        for i in stride(from:0,to:building.triangles.count,by:3) {
            let a=top(outer[building.triangles[i]]),b=top(outer[building.triangles[i+1]]),c=top(outer[building.triangles[i+2]])
            tri(a,c,b,roofGreen)
            tri(a-V(0,0.30,0),b-V(0,0.30,0),c-V(0,0.30,0),p.paving)
            tri(outer[building.triangles[i]],outer[building.triangles[i+2]],outer[building.triangles[i+1]],p.paving)
        }
        // Recess the glazed room behind the broad cantilevered roof edge.
        let inner=outer.map{center+($0-center)*V(0.76,1,0.76)}
        for i in outer.indices {
            let j=(i+1)%outer.count,oa=top(outer[i]),ob=top(outer[j])
            quad(oa,ob,ob-V(0,0.30,0),oa-V(0,0.30,0),p.paving)
            let a=inner[i],b=inner[j],ta=top(a)-V(0,0.31,0),tb=top(b)-V(0,0.31,0),length=simd_distance(a,b)
            guard length>0.15 else{continue}
            quad(a,b,tb,ta,glazing)
            let count=max(1,Int(length/1.65))
            for k in 0...count {
                let f=Float(k)/Float(count),q=a+(b-a)*f,t=ta+(tb-ta)*f
                beam(q,t,0.052,0.060,p.dark)
            }
            beam(a+V(0,2.25,0),b+V(0,2.25,0),0.045,0.055,p.dark)
            beam(a+V(0,0.10,0),b+V(0,0.10,0),0.055,0.065,p.dark)
        }
        for x:Float in [-5,0,5] {
            let c=center+V(x,0,2)
            box(c+V(0,0.40,0),V(2.1,0.70,0.8),timber)
            box(c+V(0,0.80,0),V(2.2,0.12,0.90),p.paving)
        }
        for x:Float in [-6,0,6] {
            let c=center+V(x,3.25,0)
            for side:Float in [-1,1] {beam(c+V(-0.45,side*0.18,0),c+V(0.45,side*0.18,0),0.025,0.025,p.light)}
            beam(c+V(0,-0.50,0),c+V(0,0.50,0),0.025,0.025,p.light)
        }
        scene.lights.append(NightLighting.source(center+V(0,3.8,0),toward:center,power:22,color:V(1,0.83,0.61),range:13,radius:1.1,outerDegrees:86,innerDegrees:62))
    }


    /// Foundation Mechanics documents a 72 x 36 x 18 ft steel-framed,
    /// open-air domed habitat; replace the legacy 37.8 m generic tower.
    private func navyButterflyHouse(p:LakefrontPalette) {
        let c=V(2092.1,0.12,-1504.7),halfLength:Float=10.9728,radius:Float=5.4864
        let cloth=UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.78,0.81,0.76),roughness:0.55,transmission:0.22))
        func q(_ x:Float,_ angle:Float)->V {c+V(x,sin(angle)*radius,cos(angle)*radius)}
        let segments=16
        for j in 0..<segments {
            let a=Float(j)*Float.pi/Float(segments),b=Float(j+1)*Float.pi/Float(segments)
            quad(q(-halfLength,a),q(halfLength,a),q(halfLength,b),q(-halfLength,b),cloth)
            for x:Float in [-halfLength,halfLength] {
                tri(c+V(x,0,0),q(x,a),q(x,b),cloth)
            }
        }
        for i in 0...9 {
            let x = -halfLength+Float(i)*halfLength*2/9
            for j in 0..<segments {
                let a=Float(j)*Float.pi/Float(segments),b=Float(j+1)*Float.pi/Float(segments)
                cylinder(q(x,a),q(x,b),0.036,p.white,segments:6)
            }
            for side:Float in [-1,1] {box(c+V(x,0.13,side*radius),V(0.30,0.25,0.5),timber)}
        }
        for angle:Float in [0.25,0.70,1.10,1.57,2.03,2.44,2.89] {
            beam(q(-halfLength,angle),q(halfLength,angle),0.04,0.04,p.white)
        }
        box(c-V(0,0.03,0),V(halfLength*2,0.10,radius*2),grass)
        // A modest entry vestibule fits inside the mapped eastern apron.
        box(c+V(halfLength+1.2,1.35,0),V(2.4,2.7,3.1),p.white)
        box(c+V(halfLength+2.41,1.3,0),V(0.035,2.3,1.5),p.glass)
        for i in 0..<7 {
            let center=c+V(Float(i-3)*2.4,0.85,i%2==0 ? 2.6:-2.6)
            lakefrontSmoothCrown(center,V(0.70,0.9,0.65),leafLight,segments:8,rings:5)
        }
    }

}
