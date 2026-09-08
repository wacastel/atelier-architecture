import Foundation
import simd
let b=EiffelBuilder(),start=Date()
b.wrigleyField()
let s=b.scene
var lo=SIMD3<Float>(repeating:Float.greatestFiniteMagnitude),hi = -lo,nonfinite=0,degenerate=0,normalError:Float=0
for v in s.vertices {
    let p=v.position.xyz,n=v.normal.xyz
    lo=simd_min(lo,p);hi=simd_max(hi,p)
    if !p.x.isFinite || !p.y.isFinite || !p.z.isFinite || !n.x.isFinite || !n.y.isFinite || !n.z.isFinite {nonfinite+=1}
    normalError=max(normalError,abs(simd_length(n)-1))
}
for i in stride(from:0,to:s.vertices.count,by:3) {
    let a=s.vertices[i].position.xyz,b=s.vertices[i+1].position.xyz,c=s.vertices[i+2].position.xyz
    if simd_length_squared(simd_cross(b-a,c-a))<1e-16 {degenerate+=1}
}
// Street support is an explicit fixture plane; the real park/context is validated in full-world playback.
var collisionScene=s
let ground=EiffelBuilder()
ground.quad(SIMD3(-1820,0,-7850),SIMD3(-1820,0,-7570),SIMD3(-1500,0,-7570),SIMD3(-1500,0,-7850),0)
collisionScene.vertices += ground.scene.vertices
collisionScene.materialIndices += ground.scene.materialIndices
let world=CollisionWorld(scene:collisionScene)
var issues:[String]=[],checks=0
var floodlightChecks=0
for light in s.lights where light.colorPower.w>1000 {
    let origin=light.positionRadius.xyz,direction=light.directionCone.xyz
    let groundDistance=(origin.y-0.17)/max(0.0001,-direction.y)
    floodlightChecks+=1
    if let obstacle=world.distance(origin:origin,direction:direction,maximum:groundDistance-0.5) {
        issues.append("Field floodlight hits structure at \(obstacle)m before its field target from \(origin)")
    }
}
let route=WrigleyFieldLayout.entranceRoute
for j in 1..<route.count {
    var previous=route[j-1]
    for k in 0...100 {
        let t=Float(k)/100,p=route[j-1]+(route[j]-route[j-1])*t
        checks+=1
        if !world.canMove(from:previous,to:p) {issues.append("entrance segment\(j) t\(t) blocked at\(p)")}
        if let floor=world.distance(origin:p,direction:SIMD3(0,-1,0),maximum:2.6) {
            if floor<1.44 || floor>2.1 {issues.append("entrance segment\(j) t\(t) floor\(floor)")}
        } else {issues.append("entrance segment\(j) t\(t) unsupported at\(p)")}
        previous=p
    }
}
let transformError=simd_distance(WrigleyFieldLayout.local(WrigleyFieldLayout.point(SIMD3(25,3,-75))),SIMD3(25,3,-75))
let dimensionsOK=abs(WrigleyFieldLayout.baseDistance-27.432)<0.0001 && abs(WrigleyFieldLayout.pitchingDistance-18.4404)<0.0001 && abs(WrigleyFieldLayout.scoreboardSize.x-22.86)<0.0001 && abs(WrigleyFieldLayout.scoreboardSize.y-8.2296)<0.0001
let passed=nonfinite==0 && degenerate==0 && normalError<0.001 && issues.isEmpty && transformError<0.001 && dimensionsOK && s.triangleCount<700_000 && s.lights.count<=90
let result:[String:Any]=["triangles":s.triangleCount,"lights":s.lights.count,"materials":s.materials.count,"nonfinite":nonfinite,"degenerate":degenerate,"normalError":normalError,"boundsMin":[lo.x,lo.y,lo.z],"boundsMax":[hi.x,hi.y,hi.z],"routeChecks":checks,"fieldFloodlightClearanceChecks":floodlightChecks,"routeAndLightIssues":issues,"localWorldRoundTripError":transformError,"publishedDimensionConstantsPassed":dimensionsOK,"generationSeconds":Date().timeIntervalSince(start),"passed":passed,"scope":"CPU-only authored geometry, canonical dimension constants, interpretive gate-to-field route, and unobstructed central field-light rays. Outside street grade is a fixture plane; all integrated routes/context require whole-world playback and actual image review."]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]))
precondition(s.materialIndices.allSatisfy{Int($0)<s.materials.count})
precondition(passed,"Wrigley geometry and supported route")
