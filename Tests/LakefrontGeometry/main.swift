import Foundation
import simd
let b=EiffelBuilder(),start=Date();b.chicagoLakefront();let s=b.scene
precondition(s.vertices.count==s.materialIndices.count*3)
precondition(s.materialIndices.allSatisfy{Int($0)<s.materials.count})
var maximumNormalError:Float=0,degenerate=0
for i in stride(from:0,to:s.vertices.count,by:3) {
 for j in 0..<3 {
  let v=s.vertices[i+j]
  precondition(all(isfinite(v.position) .!= SIMD4<Int32>.zero) && all(isfinite(v.normal) .!= SIMD4<Int32>.zero))
  maximumNormalError=max(maximumNormalError,abs(simd_length(SIMD3(v.normal.x,v.normal.y,v.normal.z))-1))
 }
 let aa=s.vertices[i].position,bb=s.vertices[i+1].position,cc=s.vertices[i+2].position
 let a=SIMD3(aa.x,aa.y,aa.z),c=SIMD3(bb.x,bb.y,bb.z),d=SIMD3(cc.x,cc.y,cc.z)
 if simd_length_squared(simd_cross(c-a,d-a))<1e-12{degenerate+=1}
}
precondition(maximumNormalError<0.0001)
precondition(degenerate==0,"Collapsed lakefront mesh triangles")
precondition(s.trafficLanes.count==6)
for (lane,raw) in zip(s.trafficLanes,LakefrontContext.database.trafficLanes) {
 precondition(lane.id==raw.id && lane.points.count==raw.points.count)
 precondition(lane.points.first==SIMD3(raw.points.first![0],raw.points.first![1],raw.points.first![2]))
}
precondition(s.triangleCount>300000 && s.triangleCount<6000000)
// Sample the built mesh, not just its input polygons: the rail trench must remain
// open all the way to its ballast floor rather than being covered by old paving.
func upperSurface(_ x:Float,_ z:Float)->Float {
 var result:Float = -100
 for i in stride(from:0,to:s.vertices.count,by:3) {
  let a=s.vertices[i].position,c=s.vertices[i+1].position,d=s.vertices[i+2].position
  if x<min(a.x,c.x,d.x) || x>max(a.x,c.x,d.x) || z<min(a.z,c.z,d.z) || z>max(a.z,c.z,d.z){continue}
  let det=(c.z-d.z)*(a.x-d.x)+(d.x-c.x)*(a.z-d.z)
  if abs(det)<0.000001{continue}
  let u=((c.z-d.z)*(x-d.x)+(d.x-c.x)*(z-d.z))/det
  let v=((d.z-a.z)*(x-d.x)+(a.x-d.x)*(z-d.z))/det
  if u>=0 && v>=0 && u+v<=1 {result=max(result,u*a.y+v*c.y+(1-u-v)*d.y)}
 };return result
}
for q:SIMD2<Float> in [SIMD2(1100,300),SIMD2(1100,400)] {
 precondition(abs(upperSurface(q.x,q.y)+7.2)<0.015,"Railway floor is occluded by surface paving")
}
print("PASS: lakefront \(s.triangleCount) triangles, \(s.lights.count) lights, \(s.detailCount) boats/ornaments, six traffic lanes; build \(Date().timeIntervalSince(start))s")
print("PASS: finite positions/normals, valid materials, no collapsed triangles; maximum normal error \(maximumNormalError)")
