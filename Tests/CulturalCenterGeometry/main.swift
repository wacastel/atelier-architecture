import Foundation
import simd
import CryptoKit

typealias V=SIMD3<Float>
var checks=0,failures:[String]=[]
func check(_ condition: Bool,_ message: String) {checks+=1;if !condition {failures.append(message)}}
let begin=Date(),builder=EiffelBuilder()
let initialSeed=builder.randomState
builder.culturalCenter()
let scene=builder.scene
check(scene.triangleCount>50_000 && scene.triangleCount<500_000,"Bounded, detailed Cultural Center geometry")
check(scene.materialIndices.count*3==scene.vertices.count,"Triangle/material topology")
check(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count},"Valid material references")
check(builder.randomState==initialSeed,"Landmark does not reshuffle shared-world random details")
check(scene.vertices.allSatisfy{v in (0..<3).allSatisfy{v.position[$0].isFinite && v.normal[$0].isFinite}},"Finite positions and normals")
check(scene.vertices.allSatisfy{abs(simd_length($0.normal.xyz)-1)<0.003},"Unit normals")
var minimum=V(repeating:.greatestFiniteMagnitude),maximum = -minimum
var degenerate=0,artGlassTriangles=0
for index in stride(from:0,to:scene.vertices.count,by:3) {
    let a=scene.vertices[index].position.xyz,b=scene.vertices[index+1].position.xyz,c=scene.vertices[index+2].position.xyz
    if simd_length_squared(simd_cross(b-a,c-a))<1e-12 {degenerate+=1}
    for p in [a,b,c] {let local=CulturalCenterLayout.local(p);minimum=simd_min(minimum,local);maximum=simd_max(maximum,local)}
    let material=scene.materials[Int(scene.materialIndices[index/3])]
    if material.properties.y>0 && material.albedo.w>=0.65 {artGlassTriangles+=1}
}
check(degenerate==0,"No degenerate rendered triangles: \(degenerate)")
check(minimum.x >= -25 && maximum.x <= 25 && minimum.z >= -59 && maximum.z <= 59,"Geometry stays inside authored focus envelope")
check(maximum.y>=33.5 && maximum.y<33.7,"Cornice/skylight silhouette height")
check(artGlassTriangles>8_000,"Domes contain actual colored-glass tessellation")
let opalMaterials=scene.materials.filter{$0.properties.y>0 && $0.albedo.w>=0.65}
check(opalMaterials.count==5,"Both domes use five diffuse opal colors")
check(opalMaterials.allSatisfy{$0.properties.w==0 && $0.properties.y<=0.5},"Opal must avoid the perfect-sheet mirror branch and excessive emission")
check(scene.materials.contains{$0.properties.w==1 && $0.albedo.w<0.15},"Clear protective glazing is retained")
check(scene.lights.count>=40 && scene.lights.count<=90,"Bounded interior/exterior light count")
check(scene.lights.contains{$0.parameters.z==1} && scene.lights.contains{$0.parameters.z==0},"Daytime interior and nighttime exterior lighting are distinct")
for p in [V(-23.2,0,-54.8),V(0,11.8,29),V(14,13.55,-44)] {
    check(simd_distance(CulturalCenterLayout.local(CulturalCenterLayout.point(p)),p)<0.001,"Single local/world transform")
}
let world=CollisionWorld(scene:scene)
func ray(_ origin: V,_ direction: V,_ maximum: Float=70)->Float? {
    world.distance(origin:CulturalCenterLayout.point(origin),direction:CulturalCenterLayout.east*direction.x+V(0,direction.y,0)+CulturalCenterLayout.south*direction.z,maximum:maximum)
}
func support(_ point: V,_ label: String,expected: Float=1.75) {
    let distance=world.distance(origin:point,direction:V(0,-1,0),maximum:3)
    check(distance != nil && abs(distance!-expected)<0.25,"\(label): floor support \(String(describing:distance))")
}
check(ray(V(0,2.65,56.3),V(0,0,-1),3.8)==nil,"Washington entrance is genuinely open")
check(ray(V(0,13.55,-34),V(0,0,-1),5)==nil,"GAR-to-Memorial center doorway is open")
check(ray(V(0,13.55,24),V(0,0,1),10)==nil,"Tiffany room central walking aisle is open")
for p in [V(0,13.55,29),V(14,13.55,29),V(0,13.55,-29),V(-4,13.55,-44)] {support(CulturalCenterLayout.point(p),"Hall \(p)")}
// Direct upward probes away from pendants distinguish both physical domes
// from an accidentally opaque slab filling their entire circular aperture.
for (z,spring,rise): (Float,Float,Float) in [(29,22.2,3.0),(-29,21,3.2)] {
    let d=ray(V(1.55,14,z+0.4),V(0,1,0),25)
    check(d != nil && d!>spring-14-0.2 && d!<spring+rise-14+0.2,"Art glass dome is present above interior: \(z), \(String(describing:d))")
}
let court=ray(V(0,34,0),V(0,-1,0),40)
check(court != nil && abs(court!-33.1)<0.01,"Mapped courtyard remains open through roof and upper floor")
check(CulturalCenterLayout.washingtonEyePath.last! == CulturalCenterLayout.mosaicStairEyePath.first!,"Entrance/stair paths meet exactly")
var staircaseSamples=0
for (name,path) in [("Washington",CulturalCenterLayout.washingtonEyePath),("mosaic stair",CulturalCenterLayout.mosaicStairEyePath)] {
    for i in 1..<path.count {
        let a=path[i-1],b=path[i],count=max(2,Int(ceil(simd_distance(a,b)/0.1)))
        for j in 0..<count {
            let p=simd_mix(a,b,V(repeating:Float(j)/Float(count))),q=simd_mix(a,b,V(repeating:Float(j+1)/Float(count)))
            check(world.canMove(from:p,to:q),"\(name) forward clearance at segment\(i) sample\(j)")
            check(world.canMove(from:q,to:p),"\(name) reverse clearance at segment\(i) sample\(j)")
            // Outer sidewalk belongs to the shared city, not the house builder.
            if CulturalCenterLayout.local(p).z<58.3 {support(p,"\(name) step\(i).\(j)")}
            staircaseSamples+=1
        }
    }
}
for (a,b,name) in [(V(0,13.55,25.5),V(0,13.55,33.5),"Tiffany"),
                   (V(14,13.55,34),V(15,13.55,24),"Preston side aisle"),
                   (V(-2.5,13.55,-32),V(2.5,13.55,-26),"GAR rotunda"),
                   (V(-4,13.55,-47.5),V(17,13.55,-43),"Memorial Hall")] {
    for i in 0..<100 {
        let aa=CulturalCenterLayout.point(simd_mix(a,b,V(repeating:Float(i)/100))),bb=CulturalCenterLayout.point(simd_mix(a,b,V(repeating:Float(i+1)/100)))
        check(world.canMove(from:aa,to:bb) && world.canMove(from:bb,to:aa),"\(name) bidirectional clearance\(i)")
        support(aa,"\(name) floor\(i)")
    }
}
let source=try Data(contentsOf:URL(fileURLWithPath:"Sources/ArchitectureEngine/CulturalCenter.swift"))
var geometryHash=SHA256()
scene.vertices.withUnsafeBytes{geometryHash.update(data:Data($0))}
scene.materialIndices.withUnsafeBytes{geometryHash.update(data:Data($0))}
let report:[String:Any]=["passed":failures.isEmpty,"checks":checks,"failures":failures,"triangleCount":scene.triangleCount,
    "navigationTriangles":world.triangles.count,"navigationNodes":world.nodes.count,"materialCount":scene.materials.count,
    "lightCount":scene.lights.count,"detailCount":scene.detailCount,"artGlassTriangles":artGlassTriangles,"degenerateTriangles":degenerate,
    "localMinimum":[minimum.x,minimum.y,minimum.z],"localMaximum":[maximum.x,maximum.y,maximum.z],
    "staircaseSamples":staircaseSamples,"elapsedSeconds":Date().timeIntervalSince(begin),
    "sourceSHA256":SHA256.hash(data:source).map{String(format:"%02x",$0)}.joined(),
    "geometrySHA256":geometryHash.finalize().map{String(format:"%02x",$0)}.joined(),
    "scope":"Actual standalone Cultural Center mesh and navigation BVH, staircase support/clearance and separate hollow halls/domes. Exterior sidewalk support, full-city routes and rendered day/night fidelity require separate integration checks."]
print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
if !failures.isEmpty {exit(1)}
