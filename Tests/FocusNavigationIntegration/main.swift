import Foundation
import simd

typealias V=SIMD3<Float>
let begin=Date(),catalog=LandmarkFocusCatalog(world:"chicago")
let bean=catalog.authored.first{$0.id=="chicago:cloud-gate"}!
let region=CollisionWorld.PickingRegion(minimum:bean.bounds.minimum,maximum:bean.bounds.maximum)
let scene=ChicagoWorld.build(),geometrySeconds=Date().timeIntervalSince(begin)
var expectedNavigation=0,expectedFine=0,beanTriangles=0,beanOutsideCatalog=0
// Compatibility count from the original navigation inclusion rule. No second city
// BVH is allocated; exact ordinary/dense nearest-hit behavior is covered by the unit fixture.
for i in stride(from:0,to:scene.vertices.count,by:3) {
    let a=scene.vertices[i].position.xyz,b=scene.vertices[i+1].position.xyz,c=scene.vertices[i+2].position.xyz
    if max(simd_length_squared(b-a),simd_length_squared(c-a))>0.16 { expectedNavigation+=1 }
    else {
        let lo=simd_min(a,simd_min(b,c)),hi=simd_max(a,simd_max(b,c))
        if lo.x<=region.maximum.x && hi.x>=region.minimum.x && lo.y<=region.maximum.y && hi.y>=region.minimum.y && lo.z<=region.maximum.z && hi.z>=region.minimum.z {expectedFine+=1}
    }
    let material=scene.materials[Int(scene.materialIndices[i/3])]
    // Cloud Gate's distinctive mirror material. Other polished ornaments must not
    // silently expand the requested region or be mistaken for this geometry check.
    if material.properties.x==1 && abs(material.albedo.w-0.022)<0.00001 {
        beanTriangles+=1
        if !bean.bounds.contains(a) || !bean.bounds.contains(b) || !bean.bounds.contains(c) {beanOutsideCatalog+=1}
    }
}
let collisionStart=Date(),world=CollisionWorld(scene:scene,detailedPickingRegions:[region])
let collisionSeconds=Date().timeIntervalSince(collisionStart)
var failures:[String]=[]
let probes:[(String,V,V)]=[
    ("chicago:adler-planetarium",V(2381,8,1393.247),V(2413.718,8,1393.247)),
    ("chicago:willis-tower",V(-80,100,0),V(-4,100,0)),
    ("chicago:cloud-gate",V(1027,8,-424.15),V(1042.46,8,-424.15)),
    ("chicago:robie-house",RobieHouseLayout.point(V(-23,5,0)),RobieHouseLayout.point(V(-10,5,0)))
]
var results:[[String:Any]]=[]
for (expected,position,target) in probes {
    let ray=FocusRay.make(normalized:SIMD2(0.5,0.5),aspect:16/9,pose:CameraPose(position:position,target:target))!
    let hit=catalog.pick(ray:ray,world:world)
    let ordinary=world.distance(origin:ray.origin,direction:ray.direction,maximum:50_000)
    let picking=world.pickingDistance(origin:ray.origin,direction:ray.direction,maximum:50_000)
    let passed=hit?.id==expected
    if !passed {failures.append("\(expected): got \(hit?.id ?? "nil")")}
    results.append(["expected":expected,"actual":hit?.id ?? "nil","passed":passed,"ordinaryDistance":ordinary.map { $0 as Any } ?? NSNull(),"pickingDistance":picking.map { $0 as Any } ?? NSNull()])
}
if world.triangles.count != expectedNavigation {failures.append("Original navigation triangle count changed")}
if world.detailedPickingTriangleCount != expectedFine {failures.append("Detail index exceeds exactly the omitted triangles in the requested region")}
if beanTriangles != 171_264 || beanOutsideCatalog != 0 {failures.append("Cloud Gate actual mirror shell lies outside focus bounds or material count differs")}
let sky=FocusRay(origin:V(2413.718,200,1393.247),direction:V(0,1,0))
if catalog.pick(ray:sky,world:world) != nil {failures.append("Actual city sky ray unexpectedly selects an object")}
let report:[String:Any]=[
    "passed":failures.isEmpty,"scope":"CPU actual shared Chicago geometry, four visible landmark picks including Robie House, sky miss, original navigation inclusion rule, and bounded optional dense picking index. No renderer/GPU/native UI operations.",
    "triangles":scene.triangleCount,"navigationTriangles":world.triangles.count,"expectedOriginalNavigationTriangles":expectedNavigation,
    "detailTriangles":world.detailedPickingTriangleCount,"expectedDetailTriangles":expectedFine,"detailNodes":world.detailedPickingNodeCount,
    "cloudGateTriangles":beanTriangles,"cloudGateTrianglesOutsideCatalogBounds":beanOutsideCatalog,
    "geometryAndMetadataSeconds":geometrySeconds,"collisionSeconds":collisionSeconds,"probes":results,"failures":failures]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]))
print("")
if !failures.isEmpty {exit(1)}
