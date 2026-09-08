import Foundation
import simd

let builder=EiffelBuilder(),start=Date()
builder.northSideLandmarks()
let scene=builder.scene
var minimum=SIMD3<Float>(repeating:Float.greatestFiniteMagnitude),maximum = -minimum
var nonfinite=0,degenerate=0,normalError:Float=0
for vertex in scene.vertices {
    let p=vertex.position.xyz,n=vertex.normal.xyz
    minimum=simd_min(minimum,p);maximum=simd_max(maximum,p)
    if !p.x.isFinite || !p.y.isFinite || !p.z.isFinite || !n.x.isFinite || !n.y.isFinite || !n.z.isFinite {nonfinite+=1}
    normalError=max(normalError,abs(simd_length(n)-1))
}
for i in stride(from:0,to:scene.vertices.count,by:3) {
    let a=scene.vertices[i].position.xyz,b=scene.vertices[i+1].position.xyz,c=scene.vertices[i+2].position.xyz
    if simd_length_squared(simd_cross(b-a,c-a))<1e-16 {degenerate+=1}
}
let collision=CollisionWorld(scene:scene)
let church=NorthSideLandmarksLayout.church,beach=NorthSideLandmarksLayout.beachHouse
// Architectural massing probes, independent of the tessellation details.
let naveRoof=collision.distance(origin:church+SIMD3(0,45,0),direction:SIMD3(0,-1,0),maximum:45)
let beachDeck=collision.distance(origin:beach+SIMD3(32,20,21),direction:SIMD3(0,-1,0),maximum:21)
let sailCross=abs(maximum.y-88.51)<0.25
let idsOK=scene.materialIndices.allSatisfy{Int($0)<scene.materials.count}
let lightOK=scene.lights.allSatisfy{$0.positionRadius.x.isFinite && $0.colorPower.w>0 && $0.parameters.x>0}
let passed=nonfinite==0 && degenerate==0 && normalError<0.001 && idsOK && lightOK && sailCross && naveRoof != nil && beachDeck != nil && scene.triangleCount<150_000
let report:[String:Any] = ["passed":passed,"triangles":scene.triangleCount,"lights":scene.lights.count,"nonfinite":nonfinite,"degenerate":degenerate,"normalError":normalError,"naveRoofDistance":naveRoof as Any? ?? NSNull(),"beachDeckDistance":beachDeck as Any? ?? NSNull(),"highestPointMetres":maximum.y,"generationSeconds":Date().timeIntervalSince(start),"scope":"Authored Old Town and beach-house geometry, massing probes and finite materials/lights. Complete-world route clearance is checked by validate-playback.sh."]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]))
if !passed {exit(1)}
