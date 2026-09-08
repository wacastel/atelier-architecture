import Foundation
import simd
let start=Date(),b=EiffelBuilder(),originalRandom=b.randomState
b.northSideEnvironment()
let scene=b.scene,data=NorthSideContext.database
FileHandle.standardOutput.write(Data("Built north context: \(scene.triangleCount) triangles, \(scene.lights.count) lights\n".utf8))
precondition(b.randomState==originalRandom,"Builder leaked deterministic random state")
precondition(scene.triangleCount>1_000_000 && scene.triangleCount<11_000_000,"North side exceeds the bounded context budget")
precondition(scene.vertices.count==scene.materialIndices.count*3)
precondition(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count})
var normalError:Float=0,minY:Float = .infinity,maxY:Float = -.infinity
for (index,v) in scene.vertices.enumerated() {
 if !(all(isfinite(v.position) .!= SIMD4<Int32>.zero) && all(isfinite(v.normal) .!= SIMD4<Int32>.zero)) {
  FileHandle.standardOutput.write(Data("Nonfinite vertex \(index): \(v.position) \(v.normal)\n".utf8));exit(1)
 }
 normalError=max(normalError,abs(simd_length(SIMD3(v.normal.x,v.normal.y,v.normal.z))-1));minY=min(minY,v.position.y);maxY=max(maxY,v.position.y)
}
precondition(normalError<0.0001)
FileHandle.standardOutput.write(Data("Finite vertices; max normal error \(normalError)\n".utf8))
// Previously these raw-parent park positions hit only the pale base slab.
// Test the actual assembled triangles/materials, not just JSON membership.
let lawnProbes:[SIMD2<Float>]=[SIMD2(0,-6300),SIMD2(150,-6700),SIMD2(-200,-7700),SIMD2(-400,-8200)]
var lawnHitY=[Float](repeating:-.infinity,count:lawnProbes.count)
var lawnHitMaterial=[Int](repeating:-1,count:lawnProbes.count)
var lawnHitNormalY=[Float](repeating:0,count:lawnProbes.count)
for i in stride(from:0,to:scene.vertices.count,by:3) {
 let a=scene.vertices[i].position,b=scene.vertices[i+1].position,c=scene.vertices[i+2].position
 if simd_length_squared(simd_cross(SIMD3(b.x-a.x,b.y-a.y,b.z-a.z),SIMD3(c.x-a.x,c.y-a.y,c.z-a.z)))<=1e-12 {
  FileHandle.standardOutput.write(Data("Collapsed triangle \(i/3) material \(scene.materialIndices[i/3]): \(a) \(b) \(c)\n".utf8));exit(1)
 }
 if min(a.y,b.y,c.y)>0.2 || max(a.y,b.y,c.y) < -0.07 {continue}
 let denominator=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
 if abs(denominator)<0.000001 {continue}
 for (j,p) in lawnProbes.enumerated() {
  if p.x<min(a.x,b.x,c.x) || p.x>max(a.x,b.x,c.x) || p.y<min(a.z,b.z,c.z) || p.y>max(a.z,b.z,c.z) {continue}
  let u=((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.y-c.z))/denominator
  let v=((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.y-c.z))/denominator,w=1-u-v
  if min(u,v,w) < -0.00001 {continue}
  let y=u*a.y+v*b.y+w*c.y
  if y<=0.2 && y>lawnHitY[j] {
   lawnHitY[j]=y;lawnHitMaterial[j]=Int(scene.materialIndices[i/3]);lawnHitNormalY[j]=scene.vertices[i].normal.y
  }
 }
}
for j in lawnProbes.indices {
 precondition(abs(lawnHitY[j]+0.04)<0.00001,"Mapped northern park must sit above pale base terrain")
 precondition(lawnHitMaterial[j]>=0 && scene.materials[lawnHitMaterial[j]].properties.z==4,"Northern lawn must use actual grass material")
 precondition(lawnHitNormalY[j]>0.999,"Restored lawn must face upward")
}
precondition(data.trees.count==3752,"Mapped tree nodes must remain unchanged")
precondition(data.landcoverTrees.count>150 && data.landcoverTrees.count<2200)
precondition(Set(data.landcoverTrees.map{$0.id}).count==data.landcoverTrees.count)
precondition(data.landcoverTrees.allSatisfy{$0.id < -9_000_000_000_000 && $0.point[1] < -6200 && $0.height<=12.3})
FileHandle.standardOutput.write(Data("Four actual-mesh northern grass-height/material probes passed; \(data.trees.count) tagged + \(data.landcoverTrees.count) authored canopy trees\n".utf8))
FileHandle.standardOutput.write(Data("Noncollapsed triangles; checking lanes/landmarks\n".utf8))
precondition(scene.trafficLanes.count==6 && data.boats.count>50)
for lane in scene.trafficLanes {
 let old=MuseumCampusContext.database.trafficLanes.first{$0.id==lane.id}!
 let first=SIMD3(old.points[0][0],old.points[0][1],old.points[0][2]),offset=lane.points.firstIndex(of:first)!
 for i in old.points.indices {precondition(lane.points[offset+i]==SIMD3(old.points[i][0],old.points[i][1],old.points[i][2]))}
 precondition(lane.points.map{$0.z}.min()! < -10000)
}
FileHandle.standardOutput.write(Data("Exact prior lane sequences passed\n".utf8))
for id:Int64 in[210315405,417380833,24826112,23986733,-17379974,1265774541,445947684] {
 let landmark=NorthSideContext.landmark(id)!
 precondition(NorthSideContext.suppressesBuilding(id,landmark.center[0],landmark.center[1]))
}
// The building relation has outline/part roles instead of a polygon outer ring;
// its member way above supplies the geometry, while the relation is masked by ID.
precondition(NorthSideContext.replacementBuildingIDs.contains(-17380054))
for id:Int64 in [-1870546,765296571] {
 let building=data.buildings.first{$0.id==id}!
 let c=building.points.reduce(SIMD2<Float>.zero){$0+SIMD2($1[0],$1[1])}/Float(building.points.count)
 precondition(NorthSideContext.suppressesPreviousLandmark(id,c.x,c.y),"Broader map must not close the Modern Wing entrance")
}
precondition(NorthSideContext.suppressesPreviousLandmark(31064573,1080,-2210))
precondition(!NorthSideContext.suppressesPreviousLandmark(0,100,-3700))
precondition(NorthSideContext.clearsWrigleyEntrance(-1698,-7627))
precondition(!NorthSideContext.clearsWrigleyEntrance(-1715,-7627))
FileHandle.standardOutput.write(Data("Authored masks passed; Wells \(NorthSideContext.detailDistance(100,-3700)); pond levels \(data.inlandWaters.first{$0.surface.id == -2514193}!.elevation),\(data.inlandWaters.first{$0.surface.id == 116740882}!.elevation)\n".utf8))
precondition(NorthSideContext.detailDistance(100,-3700)<20,"Wells Street detail must follow its actual east-positive axis")
precondition(data.inlandWaters.first{$0.surface.id == -2514193}!.elevation == -0.55)
precondition(data.inlandWaters.first{$0.surface.id == 116740882}!.elevation == -0.25)
let wells=EiffelBuilder();wells.northSideWellsStreetDetails()
precondition(wells.scene.triangleCount>5_000 && wells.scene.triangleCount<150_000 && wells.scene.lights.count<25,"Wells overlay must stay bounded")
for vertex in wells.scene.vertices {
 let v=vertex.position
 precondition(v.y<5 && v.z > -4110 && v.z < -3240,"Wells layer must remain at street level within its corridor")
 precondition(abs(v.x-NorthSideContext.wellsStreetX(v.z))>4.5,"Wells carriageway and camera corridor must remain empty")
}
let record:[String:Any]=["passed":true,"scope":"CPU-only North Side context mesh; does not include authored zoo, Wrigley, St Michael or beach-house geometry","triangles":scene.triangleCount,"lights":scene.lights.count,"materials":scene.materials.count,"buildings":data.buildings.count,"boats":data.boats.count,"trafficLanes":scene.trafficLanes.count,"taggedTreeCount":data.trees.count,"authoredCanopyTreeCount":data.landcoverTrees.count,"lawnMeshProbes":lawnProbes.map{[$0.x,$0.y]},"lawnMeshHitHeights":lawnHitY,"maximumNormalError":normalError,"minimumY":minY,"maximumY":maxY,"wellsAdditionalTriangles":wells.scene.triangleCount,"wellsAdditionalLights":wells.scene.lights.count,"seconds":Date().timeIntervalSince(start)]
print(String(data:try!JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
