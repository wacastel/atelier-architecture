import Foundation
import simd
let builder=EiffelBuilder(),start=Date()
builder.museumCampusEnvironment();let environmentTriangles=builder.scene.triangleCount
builder.soldierField();let scene=builder.scene
precondition(scene.vertices.count==scene.materialIndices.count*3)
precondition(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count})
var maxNormalError:Float=0
for v in scene.vertices {
    precondition(all(isfinite(v.position) .!= SIMD4<Int32>.zero) && all(isfinite(v.normal) .!= SIMD4<Int32>.zero))
    maxNormalError=max(maxNormalError,abs(simd_length(SIMD3(v.normal.x,v.normal.y,v.normal.z))-1))
}
precondition(maxNormalError<0.0001)
for i in stride(from:0,to:scene.vertices.count,by:3) {
    let a=scene.vertices[i].position,b=scene.vertices[i+1].position,c=scene.vertices[i+2].position
    precondition(simd_length_squared(simd_cross(SIMD3(b.x-a.x,b.y-a.y,b.z-a.z),SIMD3(c.x-a.x,c.y-a.y,c.z-a.z)))>1e-12,"Collapsed campus triangle")
}
precondition(scene.trafficLanes.count==6)
for lane in scene.trafficLanes {
    precondition(lane.points.map{$0.z}.max()!>6800)
    let old=LakefrontContext.database.trafficLanes.first{$0.id==lane.id}!
    let start=lane.points.firstIndex(of:SIMD3(old.points[0][0],old.points[0][1],old.points[0][2]))!
    for i in old.points.indices {precondition(lane.points[start+i]==SIMD3(old.points[i][0],old.points[i][1],old.points[i][2]),"Original traffic lane changed")}
}
precondition(MuseumCampusContext.database.boats.count>100)
precondition(MuseumCampusContext.suppressesBuilding(-2305649,1590,1838),"Generic stadium bowl slab must be suppressed")
let sailing=LakefrontContext.database.buildings.first{$0.id==210966308}!
precondition(sailing.height==45.4 && MuseumCampusContext.interpretedBuilding(sailing).height==5.5,"Untyped harbor buildings need a low-rise estimate")
var measured=sailing;measured.heightSource="height";measured.height=12.25
precondition(MuseumCampusContext.interpretedBuilding(measured).height==12.25,"Never override a tagged height")
let cafe=LakefrontContext.database.buildings.first{$0.id==445721198}!
precondition(cafe.height==34 && MuseumCampusContext.interpretedBuilding(cafe).height==4.5,"Campus Cafe must not inherit a tall city-block estimate")
precondition(MuseumCampusContext.suppressesBuilding(-18999713,1750,1317),"Generic multi-storey ticket pavilion must be replaced")
var taggedCafe=cafe;taggedCafe.height=7.25;taggedCafe.heightSource="height"
precondition(MuseumCampusContext.interpretedBuilding(taggedCafe).height==7.25,"Preserve future measured cafe heights")
let pavilionCenter=MuseumCampusContext.landmark(-18999713)!.center
var pavilionTop:Float = -.infinity
for i in stride(from:0,to:scene.vertices.count,by:3) {
 let a=scene.vertices[i].position,b=scene.vertices[i+1].position,c=scene.vertices[i+2].position,x=pavilionCenter[0],z=pavilionCenter[1]
 if x<min(a.x,b.x,c.x) || x>max(a.x,b.x,c.x) || z<min(a.z,b.z,c.z) || z>max(a.z,b.z,c.z){continue}
 let det=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
 if abs(det)<0.00001{continue}
 let u=((b.z-c.z)*(x-c.x)+(c.x-b.x)*(z-c.z))/det,v=((c.z-a.z)*(x-c.x)+(a.x-c.x)*(z-c.z))/det
 if u>=0 && v>=0 && u+v<=1 {pavilionTop=max(pavilionTop,u*a.y+v*b.y+(1-u-v)*c.y)}
}
precondition(pavilionTop>=4 && pavilionTop<=5,"Ticket pavilion must have a modeled single-storey canopy, not a missing roof or tall extrusion")
for p:SIMD2<Float> in [SIMD2(1563,1329),SIMD2(1565,1490),SIMD2(1750,1255),SIMD2(1738.2742,1371.0419),SIMD2(1777.7,1340.25),SIMD2(1785.01,1307.10),SIMD2(1800,1305.8)] {precondition(MuseumCampusContext.clearsApproach(p.x,p.y))}
// Thin-ray clearance inside the authored historic walkway and above the field.
func collision(_ p:SIMD3<Float>,_ radius:Float)->Bool {
 for i in stride(from:0,to:scene.vertices.count,by:3) {
  let v=[scene.vertices[i].position,scene.vertices[i+1].position,scene.vertices[i+2].position]
  if v.allSatisfy({$0.x<p.x-radius}) || v.allSatisfy({$0.x>p.x+radius}) || v.allSatisfy({$0.y<p.y-radius}) || v.allSatisfy({$0.y>p.y+radius}) || v.allSatisfy({$0.z<p.z-radius}) || v.allSatisfy({$0.z>p.z+radius}) {continue}
  // Conservative triangle AABB sufficient for these intentionally broad aisles.
  return true
 };return false
}
for z in stride(from:Float(-148),through:100,by:8) {precondition(!collision(SoldierFieldLayout.point(SIMD3(-96,2.1,z)),0.25),"Historic portico aisle obstructed")}
precondition(!collision(SoldierFieldLayout.fieldCamera,0.30),"Field camera obstructed")
// The two finite-width walkway segments must share a corner instead of leaving
// an exposed triangular grass wedge. Inspect the built pavement triangles.
let pathBuilder=EiffelBuilder()
let bentPath=ChicagoContext.Path(id:1,points:[[1740,1350],[1748,1350],[1748,1342]],width:4,kind:"footway",name:"Campus path junction fixture",bridge:"")
pathBuilder.chicagoRoad(bentPath,asphalt:0,concrete:0,white:0)
func pavementCoverage(_ q:SIMD2<Float>)->Int {
 var count=0
 for i in stride(from:0,to:pathBuilder.scene.vertices.count,by:3) {
  let aa=pathBuilder.scene.vertices[i].position,bb=pathBuilder.scene.vertices[i+1].position,cc=pathBuilder.scene.vertices[i+2].position
  let a=SIMD2(aa.x,aa.z),b=SIMD2(bb.x,bb.z),c=SIMD2(cc.x,cc.z)
  let det=(b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
  guard abs(det)>0.00001 else{continue}
  let u=((b.y-c.y)*(q.x-c.x)+(c.x-b.x)*(q.y-c.y))/det,v=((c.y-a.y)*(q.x-c.x)+(a.x-c.x)*(q.y-c.y))/det
  if u>0.00001 && v>0.00001 && u+v<0.99999 {count+=1}
 }
 return count
}
for q:SIMD2<Float> in [SIMD2(1748.8,1351.2),SIMD2(1749.2,1350.8),SIMD2(1746.7,1349.1)] {precondition(pavementCoverage(q)==1,"Campus path corner has a hole or overlapping coplanar paving")}
print("PASS: Museum Campus environment \(environmentTriangles) triangles, Soldier Field \(scene.triangleCount-environmentTriangles), total \(scene.triangleCount), \(scene.lights.count) lights, \(MuseumCampusContext.database.boats.count) boats, six extended lanes")
print("PASS: finite geometry, unit normals (maximum error \(maxNormalError)), noncollapsed triangles, unchanged northern lane samples, approach masks, open portico/field cameras; \(Date().timeIntervalSince(start))s")
