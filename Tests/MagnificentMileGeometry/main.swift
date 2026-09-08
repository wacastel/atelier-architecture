import Foundation
import simd

let builder=EiffelBuilder(),start=Date()
builder.magnificentMile()
let scene=builder.scene
precondition(scene.vertices.count==scene.materialIndices.count*3)
precondition(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count})
var lo=SIMD3<Float>(repeating:Float.greatestFiniteMagnitude),hi = -lo
var hancockTop:Float=0,placeTop:Float=0,waterTop:Float=0,normalError:Float=0
var nonFinite=0,degenerate=0,observationRingVertices=0,cupolaBaseVertices=0
var podiumBoundaryVertices=0,hotelRoofVertices=0
for v in scene.vertices {
    let p=SIMD3(v.position.x,v.position.y,v.position.z),n=SIMD3(v.normal.x,v.normal.y,v.normal.z)
    if !(p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite && n.z.isFinite) {nonFinite+=1}
    lo=simd_min(lo,p);hi=simd_max(hi,p);normalError=max(normalError,abs(simd_length(n)-1))
    if p.x>1010 && p.x<1115 && p.z < -2180 && p.z > -2260 {hancockTop=max(hancockTop,p.y)}
    if p.x>1080 && p.x<1170 && p.z < -2085 && p.z > -2140 {placeTop=max(placeTop,p.y)}
    if p.x>994 && p.x<1159 && p.z > -2166 && p.z < -2094 {
        if abs(p.y-55)<0.0001 {podiumBoundaryVertices+=1}
        if abs(p.y-60)<0.0001 {hotelRoofVertices+=1}
    }
    if abs(p.x-951.6)<10 && abs(p.z+2036.52)<10 {
        waterTop=max(waterTop,p.y)
        if abs(p.y-46.1772)<0.0001 {observationRingVertices+=1}
        if abs(p.y-50.4444)<0.0001 {cupolaBaseVertices+=1}
    }
}
func position(_ i:Int)->SIMD3<Float> {let p=scene.vertices[i].position;return SIMD3(p.x,p.y,p.z)}
for i in stride(from:0,to:scene.vertices.count,by:3) {
    if simd_length_squared(simd_cross(position(i+1)-position(i),position(i+2)-position(i)))<1e-16 {degenerate+=1}
}
precondition(nonFinite==0,"Nonfinite geometry")
precondition(degenerate==0,"Degenerate triangles")
precondition(normalError<0.001,"Nonunit normals")
precondition(abs(hancockTop-MagnificentMileLayout.hancockTip)<0.03,"Hancock antenna elevation")
precondition(abs(placeTop-MagnificentMileLayout.waterTowerPlaceRoof)<0.12,"Water Tower Place roof elevation")
precondition(abs(waterTop-MagnificentMileLayout.historicWaterTowerHeight)<0.03,"Historic Water Tower elevation")
precondition(observationRingVertices>=24 && cupolaBaseVertices>=24,"HABS upper stage anchors")
precondition(podiumBoundaryVertices>=24 && hotelRoofVertices>=24,"Mapped twelve-storey WTP podium anchors")
precondition(scene.triangleCount<250_000,"Landmark geometry budget")
precondition(scene.lights.count<=64,"Landmark light budget")
let result:[String:Any]=[
    "passed":true,"triangles":scene.triangleCount,"materials":scene.materials.count,"lights":scene.lights.count,
    "generationSeconds":Date().timeIntervalSince(start),"observationFloor":46.1772,"cupolaBase":50.4444,
    "waterTowerPlacePodium":55,"waterTowerPlaceHotelPlinth":60,"podiumBoundaryVertices":podiumBoundaryVertices,"hotelRoofVertices":hotelRoofVertices,
    "observationRingVertices":observationRingVertices,"cupolaBaseVertices":cupolaBaseVertices,"nonfiniteVertices":nonFinite,"normalMaxError":normalError,
    "degenerateTriangles":degenerate,"hancockTip":hancockTop,"waterTowerPlaceRoof":placeTop,"historicWaterTowerHeight":waterTop,
    "boundsMin":[lo.x,lo.y,lo.z],"boundsMax":[hi.x,hi.y,hi.z],
    "scope":"CPU geometry only; elevations, finite normalized vertices, valid materials, and triangle/light budget. No degenerate triangles. Integrated camera/visual review is separate."
]
let data=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
print(String(decoding:data,as:UTF8.self))
