import Foundation
import simd
let b=EiffelBuilder(),start=Date()
b.museumBuildings()
let s=b.scene
var lo=SIMD3<Float>(repeating:Float.greatestFiniteMagnitude),hi = -lo,nonfinite=0,degenerate=0,normalError:Float=0
for v in s.vertices {let p=v.position.xyz,n=v.normal.xyz;lo=simd_min(lo,p);hi=simd_max(hi,p);if !p.x.isFinite || !p.y.isFinite || !p.z.isFinite || !n.x.isFinite || !n.y.isFinite || !n.z.isFinite {nonfinite+=1};normalError=max(normalError,abs(simd_length(n)-1))}
for i in stride(from:0,to:s.vertices.count,by:3) {let a=s.vertices[i].position.xyz,b=s.vertices[i+1].position.xyz,c=s.vertices[i+2].position.xyz;if simd_length_squared(simd_cross(b-a,c-a))<1e-16{degenerate+=1}}
// Context street grade for outdoor approach only. Museum support above grade is actual authored geometry.
var collisionScene=s
let ground=EiffelBuilder()
ground.quad(SIMD3(1400,0,1150),SIMD3(1400,0,1520),SIMD3(1950,0,1520),SIMD3(1950,0,1150),0)
collisionScene.vertices += ground.scene.vertices
collisionScene.materialIndices += ground.scene.materialIndices
let world=CollisionWorld(scene:collisionScene)
var issues:[String]=[],checks=0
for (name,route) in [("Field",MuseumBuildingsLayout.fieldRoute),("Shedd",MuseumBuildingsLayout.sheddRoute)] {
 for j in 1..<route.count {var previous=route[j-1];for k in 0...100 {let t=Float(k)/100,p=route[j-1]+(route[j]-route[j-1])*t;checks+=1
  if !world.canMove(from:previous,to:p) {issues.append("\(name) segment\(j) t\(t) blocked at\(p)")}
  if let floor=world.distance(origin:p,direction:SIMD3(0,-1,0),maximum:2.6) {if floor<1.45 || floor>2.1 {issues.append("\(name) segment\(j) t\(t) floor\(floor)")}}else {issues.append("\(name) segment\(j) t\(t) unsupported at\(p)")}
  previous=p
 }}
}
let result:[String:Any] = ["triangles":s.triangleCount,"lights":s.lights.count,"materials":s.materials.count,"nonfinite":nonfinite,"degenerate":degenerate,"normalError":normalError,"boundsMin":[lo.x,lo.y,lo.z],"boundsMax":[hi.x,hi.y,hi.z],"routeChecks":checks,"routeIssues":issues,"generationSeconds":Date().timeIntervalSince(start),"passed":nonfinite==0 && degenerate==0 && normalError<0.001 && issues.isEmpty,"scope":"Authored museum geometry and route keys; outdoor approach uses an explicit grade plane. Actual complete-world terrain/vegetation checked by integrated playback."]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]))
precondition(nonfinite==0 && degenerate==0 && normalError<0.001)
precondition(s.materialIndices.allSatisfy{Int($0)<s.materials.count})
precondition(s.triangleCount<400_000 && s.lights.count<=140)
precondition(issues.isEmpty,"Supported traversable museum routes")
