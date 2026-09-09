import Foundation
import simd
let start=Date(),builder=EiffelBuilder(),initialRandom=builder.randomState
builder.hydeParkEnvironment()
let scene=builder.scene,data=HydeParkContext.database
FileHandle.standardError.write(Data("Built: \(scene.triangleCount) triangles, \(scene.lights.count) lights\n".utf8))
precondition(builder.randomState==initialRandom,"Hyde Park changed shared random state")
precondition(scene.triangleCount>500_000 && scene.triangleCount<7_000_000,"Corridor geometry must remain within its budget")
precondition(scene.vertices.count==scene.materialIndices.count*3)
precondition(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count})
var maximumNormalError:Float=0
for v in scene.vertices {
 precondition(all(isfinite(v.position) .!= SIMD4<Int32>.zero) && all(isfinite(v.normal) .!= SIMD4<Int32>.zero),"Nonfinite vertex")
 maximumNormalError=max(maximumNormalError,abs(simd_length(SIMD3(v.normal.x,v.normal.y,v.normal.z))-1))
}
precondition(maximumNormalError<0.0001)
var collapsed=0
for i in stride(from:0,to:scene.vertices.count,by:3) {
 let a=scene.vertices[i].position,b=scene.vertices[i+1].position,c=scene.vertices[i+2].position
 if simd_length_squared(simd_cross(SIMD3(b.x-a.x,b.y-a.y,b.z-a.z),SIMD3(c.x-a.x,c.y-a.y,c.z-a.z)))<=1e-12 {collapsed+=1}
}
FileHandle.standardError.write(Data("Normal error \(maximumNormalError); collapsed \(collapsed); boats \(data.boats.count)\n".utf8))
precondition(collapsed==0,"Collapsed triangles in expanded corridor")
precondition(data.buildings.count>10000 && data.buildings.count<18000)
precondition(!data.buildings.contains{$0.id==125667497},"Generic shell must not close Robie interiors")
precondition(data.buildings.allSatisfy{b in !b.points.contains{HydeParkContext.containsAuthoredSite($0[0],$0[1])}})
precondition(data.boats.count>60 && data.boats.count<1000)
precondition(data.trafficLanes.count==6)
for lane in data.trafficLanes {
 let old=NorthSideContext.database.trafficLanes.first{$0.id==lane.id}!
 let index=lane.points.firstIndex(of:old.points[0])!
 precondition(Array(lane.points[index..<(index+old.points.count)])==old.points,"Existing lane sequence must remain exactly preserved")
 precondition(lane.points.map{$0[2]}.min()! < -11000 && lane.points.map{$0[2]}.max()!>10600)
}
precondition(data.ground.points.allSatisfy{$0[1]>=7800 && $0[1]<=10800})
precondition(data.water.points.allSatisfy{$0[1]>=7800 && $0[1]<=10800})
precondition(HydeParkContext.containsAuthoredSite(3310,9917))
let r:[String:Any]=["passed":true,"scope":"CPU-only Hyde Park connecting environment, excluding authored Robie House","triangles":scene.triangleCount,"lights":scene.lights.count,"materials":scene.materials.count,"buildings":data.buildings.count,"boats":data.boats.count,"mappedTrees":data.trees.count,"authoredCanopySamples":data.landcoverTrees.count,"maximumNormalError":maximumNormalError,"collapsedTriangles":collapsed,"trafficLaneCount":6,"existingLaneSequencesPreserved":true,"seconds":Date().timeIntervalSince(start)]
print(String(data:try!JSONSerialization.data(withJSONObject:r,options:[.sortedKeys,.prettyPrinted]),encoding:.utf8)!)
