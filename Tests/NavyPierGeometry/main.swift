import Foundation
import simd

let begin=Date(),builder=EiffelBuilder(),seed=EiffelBuilder().randomState
builder.navyPier()
let scene=builder.scene
var failures=[String](),checks=0
func check(_ okay:Bool,_ name:String) {checks+=1;if !okay {failures.append(name)}}
check(scene.triangleCount>100_000 && scene.triangleCount<900_000,"Navy Pier stays inside additional geometry budget")
check(scene.vertices.count==scene.materialIndices.count*3,"One material per triangle")
check(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count},"Material indices in bounds")
check(builder.randomState==seed,"Landmark preserves shared-world random sequence")
var minimum=SIMD3<Float>(repeating:.greatestFiniteMagnitude),maximum = -minimum
var collapsed=0,nonfinite=0,normalError:Float=0
for i in stride(from:0,to:scene.vertices.count,by:3) {
    let aa=scene.vertices[i].position,bb=scene.vertices[i+1].position,cc=scene.vertices[i+2].position
    let a=SIMD3(aa.x,aa.y,aa.z),b=SIMD3(bb.x,bb.y,bb.z),c=SIMD3(cc.x,cc.y,cc.z)
    if simd_length_squared(simd_cross(b-a,c-a))<=1e-12 {collapsed+=1}
    for j in i..<i+3 {
        let v=scene.vertices[j]
        if (0..<3).contains(where:{!v.position[$0].isFinite || !v.normal[$0].isFinite}) {nonfinite+=1}
        normalError=max(normalError,abs(simd_length(SIMD3(v.normal.x,v.normal.y,v.normal.z))-1))
        let local=NavyPierLayout.local(SIMD3(v.position.x,v.position.y,v.position.z))
        minimum=simd_min(minimum,local);maximum=simd_max(maximum,local)
    }
}
check(collapsed==0,"No collapsed final triangles after global placement")
check(nonfinite==0,"Finite positions and normals")
check(normalError<0.001,"Unit vertex normals")
check(minimum.x > -190 && maximum.x < 740 && minimum.z > -132 && maximum.z < 110,"Bounded authored pier envelope")
check(maximum.y>66.0 && maximum.y<66.3,"Published wheel silhouette height plus park grade")
check(scene.lights.count>50 && scene.lights.count<180,"Bounded local light count")
check(scene.lights.allSatisfy{$0.parameters.x>0 && $0.parameters.x<=65 && $0.parameters.z==0},"Finite local ranges and nighttime gating")
check(NavyPierLayout.wheelCabinCount==42 && NavyPierLayout.wheelSpokeCount==21,"Owner-published wheel arrangement")
check(scene.materials.filter{$0.properties.y>0}.allSatisfy{$0.properties.z==7 || $0.properties.z==8},"Pier luminous materials obey existing lighting controls")
check(NavyPierLayout.marinaCenterlines.count>=25,"Current marina has mapped centerline geometry")
for q in [SIMD3<Float>(0,38,0),SIMD3<Float>(670,24,-1.2),SIMD3<Float>(-180,1,64)] {
    check(simd_distance(NavyPierLayout.local(NavyPierLayout.point(q)),q)<0.001,"Stable world/local transform")
}
let result:[String:Any]=["passed":failures.isEmpty,"checks":checks,"failures":failures,"triangles":scene.triangleCount,"materials":scene.materials.count,"lights":scene.lights.count,"collapsedTriangles":collapsed,"nonfiniteVertices":nonfinite,"maximumNormalError":normalError,"localMinimum":[minimum.x,minimum.y,minimum.z],"localMaximum":[maximum.x,maximum.y,maximum.z],"mappedMarinaWays":NavyPierLayout.marinaCenterlines.count,"seconds":Date().timeIntervalSince(begin)]
print(String(data:try!JSONSerialization.data(withJSONObject:result,options:[.sortedKeys,.prettyPrinted]),encoding:.utf8)!)
if !failures.isEmpty {exit(1)}
