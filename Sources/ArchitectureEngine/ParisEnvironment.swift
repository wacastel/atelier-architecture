import Foundation
import simd

/// OpenStreetMap footprint database, projected into the tower's metre-scale frame.
/// Height tags are used when present; the facade articulation is authored Paris context.
enum ParisContext {
    struct Building: Decodable {
        var id: Int64
        var points: [[Float]]
        var triangles: [Int]
        var height: Float
        var heightSource: String
        var name: String
        var kind: String
        var material: String
    }
    struct Area: Decodable { var id: Int64; var points: [[Float]]; var triangles: [Int]; var kind: String; var name: String }
    struct Path: Decodable { var id: Int64; var points: [[Float]]; var width: Float; var kind: String; var name: String }
    struct Database: Decodable { var timestamp: String; var buildings: [Building]; var areas: [Area]; var paths: [Path] }
    static let database: Database = {
        var candidates: [URL] = []
        if let root = Bundle.main.resourceURL {
            candidates.append(root.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources/Paris/ParisContext.json"))
            candidates.append(root.appendingPathComponent("Resources/Paris/ParisContext.json"))
        }
        // Standalone geometry checks run from the repository; packaged builds use the bundle above.
        candidates.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources/Paris/ParisContext.json"))
        for url in candidates {
            if let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Database.self, from: data) { return value }
        }
        // Do not evaluate SwiftPM's generated absolute build-path fallback until
        // the app's self-contained Resources bundle has been tried successfully.
        #if SWIFT_PACKAGE
        let packageURL=Bundle.module.bundleURL.appendingPathComponent("Resources/Paris/ParisContext.json")
        if let data=try?Data(contentsOf:packageURL),let value=try?JSONDecoder().decode(Database.self,from:data) {return value}
        #endif
        fatalError("The bundled ParisContext.json map database is missing or invalid.")
    }()
}

extension EiffelBuilder {
    func parisEnvironment() {
        let mapped = ParisContext.database
        let gravel = UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.61,0.56,0.45),roughness:0.94,pattern:1))
        let asphalt = UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.115,0.12,0.118),roughness:0.74,pattern:1))
        let brick = UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.33,0.17,0.10),roughness:0.91,pattern:1))
        let pink = UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.46,0.12,0.23),roughness:0.88))
        let lavender = UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.32,0.22,0.40),roughness:0.9))
        let shrub = UInt32(scene.materials.count)
        scene.materials.append(SceneMaterial(V(0.07,0.16,0.055),roughness:0.96,pattern:4))
        // Leave the Seine open down to its bed. Bank positions agree with RiverEnvironment.
        box(V(0,-7,0),V(100_000,1.6,100_000),limestone)
        box(V(0,-3.13,24935),V(100_000,6.14,50130),limestone) // south land, z >= -130
        box(V(0,-3.13,-25155),V(100_000,6.14,49690),limestone) // north land, z <= -310
        // The mapped park masses sit under the detailed grass compartments and paths.
        for area in mapped.areas where area.kind == "park" { parisArea(area,y:0.01,material:grass) }
        for area in mapped.areas where area.kind == "grass" { parisArea(area,y:0.032,material:grass) }
        for path in mapped.paths { parisPath(path,gravel:gravel,asphalt:asphalt) }
        // A clear stone esplanade retains the four piers and the authored human-scale approach.
        box(V(0,0.035,0),V(139,0.13,139),pavement)
        for i in -6...6 {
            let q=Float(i)*10
            box(V(q,0.105,0),V(0.045,0.009,138),limestone)
            box(V(0,0.105,q),V(138,0.009,0.045),limestone)
        }
        for building in mapped.buildings { parisBuilding(building,brick:brick) }
        for area in mapped.areas where area.kind == "water" { parisPond(area) }
        parisPlanting(mapped,shrub:shrub,pink:pink,lavender:lavender)
        parisGardenFurniture()
        parisHistoricChimney(brick:brick)
        // Distant city remains cheap and interpretive; the nearby kilometre uses actual footprints.
        for ix in -43...43 { for iz in -43...43 {
            let x=Float(ix)*82,z=Float(iz)*82
            if simd_length(SIMD2(x,z))<1175 || (z > -325 && z < -117) { continue }
            if (ix*7+iz*11)%71==0 { box(V(x,0.035,z),V(68,0.08,69),grass); continue }
            distantBuilding(V(x+(rnd()-0.5)*8,0,z+(rnd()-0.5)*8),width:53+rnd()*19,depth:50+rnd()*22,height:14+rnd()*21)
        }}
    }

    private func parisArea(_ area: ParisContext.Area,y:Float,material:UInt32) {
        for i in stride(from:0,to:area.triangles.count,by:3) {
            let a=area.points[area.triangles[i]],b=area.points[area.triangles[i+1]],c=area.points[area.triangles[i+2]]
            if [a,b,c].contains(where:{$0[1] > -311 && $0[1] < -129}) { continue }
            tri(V(a[0],y,a[1]),V(c[0],y,c[1]),V(b[0],y,b[1]),material)
        }
    }

    private func parisPath(_ path: ParisContext.Path,gravel:UInt32,asphalt:UInt32) {
        let pedestrian = ["footway","path","pedestrian","cycleway"].contains(path.kind)
        for i in 1..<path.points.count {
            let a=V(path.points[i-1][0],0.046,path.points[i-1][1]),b=V(path.points[i][0],0.046,path.points[i][1])
            if min(a.z,b.z)<(-129) && max(a.z,b.z)>(-311) { continue }
            if simd_distance(a,b)<0.3 { continue }
            let tangent=simd_normalize(b-a),side=V(-tangent.z,0,tangent.x),w=path.width*0.5
            quad(a-side*w,a+side*w,b+side*w,b-side*w,pedestrian ? gravel:asphalt)
            if !pedestrian {
                for sign:Float in [-1,1] {
                    let c=(a+b)*0.5+side*(w+0.7)*sign+V(0,0.045,0)
                    orientedBox(c,side,V(0,1,0),tangent,V(1.4,0.15,simd_distance(a,b)),pavement)
                    beam(a+side*w*sign+V(0,0.10,0),b+side*w*sign+V(0,0.10,0),0.14,0.16,limestone)
                }
            }
        }
    }

    private func parisBuilding(_ building: ParisContext.Building,brick:UInt32) {
        let p=building.points.map { V($0[0],0,$0[1]) }
        let center=p.reduce(V.zero,+)/Float(p.count),distance=simd_length(center)
        let h=building.height, floorCount=max(1,Int((h-0.8)/3.15)), floorHeight=h/Float(floorCount)
        let palace=building.kind == "palace"
        let detailed=distance<440 && !palace, medium=distance<690 || palace
        let mat:UInt32=building.material == "brick" ? brick : building.id%4==0 ? facadeWarm:facade
        let inset:Float=palace ? 1.0 : h<7 ? 0.92:0.88, roofRise:Float=palace ? 0.35 : h<7 ? 1.0:3.5
        let roofPoints=p.map { center+($0-center)*inset+V(0,h+roofRise,0) }
        for i in stride(from:0,to:building.triangles.count,by:3) {
            let a=building.triangles[i],b=building.triangles[i+1],c=building.triangles[i+2]
            tri(roofPoints[a],roofPoints[c],roofPoints[b],roof)
        }
        for side in p.indices {
            let a=p[side],b=p[(side+1)%p.count],length=simd_distance(a,b)
            if length<0.35 { continue }
            let along=(b-a)/length,normal=V(along.z,0,-along.x),middle=(a+b)*0.5
            quad(a,a+V(0,h,0),b+V(0,h,0),b,mat)
            quad(a+V(0,h,0),b+V(0,h,0),roofPoints[(side+1)%p.count],roofPoints[side],roof)
            if !medium && length<3 { continue }
            // Shallow relief has actual silhouette, contact shadows and reflected light.
            for y:Float in (medium ? [0.24,h-0.32,h+0.02] : []) {
                orientedBox(middle+V(0,y,0)+normal*0.11,along,V(0,1,0),normal,V(length+0.06,y<1 ? 0.35:0.25,0.30),limestone)
            }
            let bays=max(1,min(32,Int(length/3.2))), spacing=length/Float(bays)
            guard spacing>1.5 else { continue }
            for story in 0..<min(floorCount,14) {
                let windowHeight:Float=story==0 ? min(2.65,floorHeight-0.45):min(2.0,floorHeight-0.55)
                let sy=Float(story)*floorHeight+floorHeight*0.51
                if detailed && (story==1 || story==floorCount-1) {
                    orientedBox(middle+V(0,Float(story)*floorHeight+0.08,0)+normal*0.11,along,V(0,1,0),normal,V(length,0.16,0.38),limestone)
                }
                for j in 0..<bays {
                    let c=a+along*(Float(j)+0.5)*spacing+V(0,sy,0)+normal*0.025
                    let width:Float=story==0 ? min(2.0,spacing*0.70):min(1.25,spacing*0.46)
                    if detailed { orientedBox(c,along,V(0,1,0),normal,V(width,windowHeight,0.04),cityWindow) } else {
                        let dx=along*width*0.5,dy=V(0,windowHeight*0.5,0)
                        quad(c-dx-dy,c-dx+dy,c+dx+dy,c+dx-dy,cityWindow)
                    }
                    if detailed {
                        for sx:Float in [-1,1] {
                            orientedBox(c+along*sx*(width*0.5+0.08)+normal*0.045,along,V(0,1,0),normal,V(0.14,windowHeight+0.28,0.16),limestone)
                        }
                        for dy:Float in [-1,1] {
                            orientedBox(c+V(0,dy*(windowHeight*0.5+0.08),0)+normal*0.06,along,V(0,1,0),normal,V(width+0.28,0.15,0.19),limestone)
                        }
                        orientedBox(c+normal*0.035,along,V(0,1,0),normal,V(0.048,windowHeight,0.055),ironDark)
                        orientedBox(c+V(0,windowHeight*0.17,0)+normal*0.035,along,V(0,1,0),normal,V(width,0.045,0.055),ironDark)
                        if story>0 && (story==1 || story==floorCount-1) && h>10 {
                            let railCenter=c-V(0,windowHeight*0.5+0.15,0)+normal*0.45
                            orientedBox(railCenter,along,V(0,1,0),normal,V(width+0.60,0.14,0.85),limestone)
                            for q in 0...6 {
                                let foot=railCenter+along*(Float(q)/6-0.5)*(width+0.44)+normal*0.35+V(0,0.08,0)
                                beam(foot,foot+V(0,0.85,0),0.027,0.032,ironDark)
                            }
                            beam(railCenter-along*(width*0.5+0.22)+normal*0.35+V(0,0.94,0),railCenter+along*(width*0.5+0.22)+normal*0.35+V(0,0.94,0),0.046,0.045,ironDark)
                        }
                    } else if medium {
                        orientedBox(c-V(0,windowHeight*0.5+0.07,0)+normal*0.08,along,V(0,1,0),normal,V(width+0.27,0.11,0.25),limestone)
                    }
                }
            }
            if palace && length>6 {
                for j in 0..<max(1,Int(length/4.5)) {
                    let c=a+(b-a)*(Float(j)+0.5)/Float(max(1,Int(length/4.5)))+normal*0.35+V(0,h*0.45,0)
                    orientedBox(c,along,V(0,1,0),normal,V(0.80,h*0.80,0.70),limestone)
                }
            }
            if medium && length>5 && h>10 && !palace {
                for j in 0..<min(10,max(1,bays/2)) {
                    let t=(Float(j)+0.5)/Float(min(10,max(1,bays/2)))
                    let lower=a+(b-a)*t+V(0,h+1.1,0)-normal*0.55
                    orientedBox(lower,along,V(0,1,0),normal,V(1.30,1.8,1.1),roof)
                    orientedBox(lower+normal*0.57,along,V(0,1,0),normal,V(0.81,1.23,0.035),cityWindow)
                    orientedBox(lower+V(0,0.98,0)+normal*0.15,along,V(0,1,0),normal,V(1.53,0.13,1.5),roof)
                }
            }
        }
        if h>9 && !palace {
            for i in 0..<(medium ? 3:1) {
                let q=roofPoints[(i*7+Int(building.id%7))%p.count]
                let c=q+(center+V(0,h+roofRise,0)-q)*0.25
                box(c+V(0,0.9,0),V(0.75,1.8,1.15),mat)
                box(c+V(0,1.85,0),V(0.90,0.16,1.3),limestone)
                if detailed { for s:Float in [-0.24,0.24] { cylinder(c+V(s,1.85,0),c+V(s,2.3,0),0.14,brick,segments:6) } }
            }
        }
    }

    private func parisPond(_ area:ParisContext.Area) {
        let center=area.points.reduce(SIMD2<Float>.zero){$0+SIMD2($1[0],$1[1])}/Float(area.points.count)
        guard simd_length(center)<660 else { return }
        parisArea(area,y:0.09,material:water)
        for i in area.points.indices {
            let a=area.points[i],b=area.points[(i+1)%area.points.count]
            let p=V(a[0],0.11,a[1]),q=V(b[0],0.11,b[1])
            if abs(center.x)<150 && center.y > -120 {
                let steps=max(1,Int(simd_distance(p,q)/1.25))
                for j in 0..<steps {
                    let r=p+(q-p)*(Float(j)+0.5)/Float(steps)
                    ellipsoid(r+V(0,0.12,0),V(0.58+rnd()*0.35,0.30+rnd()*0.3,0.55+rnd()*0.4),limestone,segments:7,rings:4)
                }
            } else { beam(p,q,0.38,0.38,limestone) }
        }
    }

    private func parisInside(_ p:SIMD2<Float>,_ polygon:[[Float]])->Bool {
        var inside=false,j=polygon.count-1
        for i in polygon.indices {
            let a=polygon[i],b=polygon[j]
            if (a[1]>p.y) != (b[1]>p.y), p.x<(b[0]-a[0])*(p.y-a[1])/(b[1]-a[1])+a[0] { inside.toggle() }
            j=i
        }
        return inside
    }

    private func parisPlanting(_ mapped:ParisContext.Database,shrub:UInt32,pink:UInt32,lavender:UInt32) {
        var occupied=Set<String>()
        let ponds=mapped.areas.filter{$0.kind == "water"}
        for area in mapped.areas where area.kind != "water" {
            let xs=area.points.map{$0[0]},zs=area.points.map{$0[1]}
            let minX=max(-600,xs.min()!),maxX=min(600,xs.max()!),minZ=max(-710,zs.min()!),maxZ=min(850,zs.max()!)
            guard maxX>minX,maxZ>minZ else { continue }
            for x in stride(from:minX+4,through:maxX,by:17.5) { for z in stride(from:minZ+4,through:maxZ,by:17.5) {
                let point=SIMD2(x+(rnd()-0.5)*7,z+(rnd()-0.5)*7)
                if abs(point.x)<81 && point.y > -115 && point.y<1000 { continue }
                if point.y > -314 && point.y < -128 { continue }
                guard parisInside(point,area.points) else { continue }
                if ponds.contains(where:{parisInside(point,$0.points)}) { continue }
                let key="\(Int(point.x/13)):\(Int(point.y/13))"
                guard occupied.insert(key).inserted else { continue }
                parisTree(V(point.x,0.06,point.y),height:9+rnd()*6)
            }}
        }
        // Clipped borders and topiary along the central lawns read against the organic groves.
        for side:Float in [-1,1] {
            for z in stride(from:Float(125),through:Float(680),by:45) {
                if z>295 && z<385 { continue }
                box(V(side*76,0.42,z),V(0.80,0.8,39),shrub)
                ellipsoid(V(side*76,1.25,z-19.5),V(0.85,1.55,0.85),shrub,segments:9,rings:6)
            }
            for z in stride(from:Float(-58),through:Float(91),by:23) {
                let p=V(side*(95+12*sin(z*0.05)),0.12,z)
                ellipsoid(p+V(0,0.32,0),V(4.1,0.45,2.3),shrub,segments:12,rings:5)
                for k in 0..<28 {
                    let angle=Float(k)*2.3999,r=sqrt(Float(k)/28)*3.5
                    let flower=p+V(cos(angle)*r,0.57+rnd()*0.22,sin(angle)*r*0.54)
                    ellipsoid(flower,V(0.13,0.17,0.13),k%2==0 ? pink:lavender,segments:5,rings:3)
                }
            }
        }
    }

    private func parisTree(_ p:V,height:Float) {
        cylinder(p,p+V(0,height*0.67,0),0.22+rnd()*0.10,bark,segments:9)
        for k in 0..<19 {
            let theta=Float(k)*2.3999,radius=sqrt(Float(k%7)/7)*height*0.22
            let c=p+V(cos(theta)*radius,height*(0.59+Float(k%4)*0.09),sin(theta)*radius)
            if k<8 { cylinder(p+V(0,height*0.35,0),c,0.10,bark,segments:6) }
            let clusterRadius=V(1.35+rnd()*1.1,1.4+rnd()*1.0,1.35+rnd()*1.1)
            parisFoliage(c,clusterRadius,k%4==0 ? leafLight:leaf)
            if simd_length(SIMD2(p.x,p.z))<200 {
                for q in 0..<16 {
                    let a=Float(q)*2.3999+Float(k), y=(Float(q)+0.5)/8-1
                    let n=V(cos(a)*sqrt(max(0,1-y*y)),y,sin(a)*sqrt(max(0,1-y*y)))
                    let point=c+n*clusterRadius*1.015, tangent=simd_normalize(simd_cross(n,V(0.1,1,0.15)))
                    let vertical=simd_normalize(simd_cross(n,tangent)), length:Float=0.18+rnd()*0.1
                    let v0=point-vertical*length,v1=point+tangent*length*0.48,v2=point+vertical*length,v3=point-tangent*length*0.48
                    tri(v0,v1+n*0.035,v2,leaf);tri(v0,v2,v3+n*0.035,q%3==0 ? leafLight:leaf)
                }
            }
        }
    }

    private func parisFoliage(_ c:V,_ radius:V,_ material:UInt32) {
        let near=simd_length(SIMD2(c.x,c.z))<200
        let segments=near ? 12:8,rings=near ? 8:5
        for j in 0..<rings {
            for i in 0..<segments {
                func vertex(_ x:Int,_ y:Int)->(V,V) {
                    let a=Float(x)*2*Float.pi/Float(segments),t = -Float.pi/2+Float(y)*Float.pi/Float(rings)
                    let n=V(cos(t)*cos(a),sin(t),cos(t)*sin(a))
                    let ripple=1+0.025*cos(t)*cos(t)*sin(3*a+5*t+c.x*0.13+c.z*0.27)
                    return (c+n*radius*ripple,simd_normalize(n/radius))
                }
                let a=vertex(i,j),b=vertex(i+1,j),d=vertex(i,j+1),e=vertex(i+1,j+1)
                smoothTri(a.0,d.0,e.0,a.1,d.1,e.1,material)
                smoothTri(a.0,e.0,b.0,a.1,e.1,b.1,material)
            }
        }
    }

    private func parisGardenFurniture() {
        for x:Float in [-82,82] {
            for z in stride(from:Float(102),through:Float(645),by:37) {
                if z>303 && z<372 { continue }
                bench(V(x,0.15,z),alongX:false)
                if Int(z)%2==0 { streetLamp(V(x+(x>0 ? 3:-3),0,z+9)) }
                cylinder(V(x+2,0,z+2),V(x+2,0.78,z+2),0.29,ironDark,segments:10)
                for s in 0..<8 {
                    let t=Float(s)*Float.pi/4
                    beam(V(x+2+cos(t)*0.295,0.08,z+2+sin(t)*0.295),V(x+2+cos(t)*0.295,0.72,z+2+sin(t)*0.295),0.018,0.024,ironLight)
                }
            }
            for z in stride(from:Float(-83),through:Float(74),by:31) { streetLamp(V(x,0,z)) }
        }
        for x in stride(from:Float(-120),through:Float(120),by:6) {
            if abs(x)<70 { continue }
            for z:Float in [-119,95] {
                cylinder(V(x,0,z),V(x,0.85,z),0.06,ironDark,segments:8)
                ellipsoid(V(x,0.87,z),V(0.085,0.085,0.085),ironDark,segments:6,rings:4)
            }
        }
    }

    private func parisHistoricChimney(brick:UInt32) {
        // Garden feature referenced by the official tower guide; dimensions are illustrative.
        let p=V(-95,0,44)
        cylinder(p,p+V(0,7.5,0),0.84,brick,segments:14)
        for y in stride(from:Float(0.20),through:Float(7.3),by:0.30) {
            cylinder(p+V(0,y,0),p+V(0,y+0.025,0),0.855,facadeWarm,segments:14)
        }
        cylinder(p+V(0,7.25,0),p+V(0,7.75,0),1.03,brick,segments:14)
        cylinder(p+V(0,7.77,0),p+V(0,7.80,0),0.66,ironDark,segments:14)
        for k in 0..<8 {
            let t=Float(k)*Float.pi/4
            box(p+V(cos(t)*0.80,8.07,sin(t)*0.80),V(0.39,0.57,0.39),brick)
        }
    }
}
