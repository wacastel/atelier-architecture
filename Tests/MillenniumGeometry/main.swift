import Foundation
import simd
let b=EiffelBuilder(),start=Date();b.millenniumPark()
let s=b.scene
precondition(s.vertices.count==s.materialIndices.count*3)
precondition(s.vertices.allSatisfy{all(isfinite($0.position) .!= SIMD4<Int32>.zero) && all(isfinite($0.normal) .!= SIMD4<Int32>.zero)})
precondition(s.materialIndices.allSatisfy{Int($0)<s.materials.count})
let mirror:UInt32=19
var lo=SIMD3<Float>(repeating:Float.greatestFiniteMagnitude),hi = -lo
var normalError:Float=0, mirrorTriangles=0,degenerate=0
var volume:Double=0
func v3(_ v:SIMD4<Float>)->SIMD3<Float>{SIMD3(v.x,v.y,v.z)}
for (i,m) in s.materialIndices.enumerated() where m==mirror {
 let a=v3(s.vertices[i*3].position),c=v3(s.vertices[i*3+1].position),d=v3(s.vertices[i*3+2].position)
 let cross=simd_cross(c-a,d-a)
 if simd_length_squared(cross)<1e-12{degenerate+=1}
 volume += Double(simd_dot(a-MillenniumContext.bean,simd_cross(c-MillenniumContext.bean,d-MillenniumContext.bean)))/6
 for j in 0..<3{let v=s.vertices[i*3+j];lo=simd_min(lo,v3(v.position));hi=simd_max(hi,v3(v.position));normalError=max(normalError,abs(simd_length(v3(v.normal))-1))}
 mirrorTriangles+=1
}
precondition(degenerate==0,"Degenerate Bean triangles")
precondition(normalError<0.00001)
precondition(volume>500 && volume<2000)
precondition(abs((hi-lo).x-12.8)<0.01 && abs((hi-lo).z-20)<0.01 && abs((hi-lo).y-10)<0.03)
func hit(_ origin:SIMD3<Float>,_ dir:SIMD3<Float>,_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>)->Float? {
 let e1=b-a,e2=c-a,p=simd_cross(dir,e2),det=simd_dot(e1,p);if abs(det)<0.0000001{return nil}
 let inv=1/det,t=origin-a,u=simd_dot(t,p)*inv;if u<0 || u>1{return nil}
 let q=simd_cross(t,e1),v=simd_dot(dir,q)*inv;if v<0 || u+v>1{return nil}
 let distance=simd_dot(e2,q)*inv;return distance>0 ? distance:nil
}
var minHeadroom:Float=100
for x in stride(from:Float(1035),through:1049,by:0.5) {
 let o=SIMD3<Float>(x,4.75,-424.15);var nearest:Float=100
 for (i,m) in s.materialIndices.enumerated() where m==mirror {
  if let d=hit(o,SIMD3(0,1,0),v3(s.vertices[i*3].position),v3(s.vertices[i*3+1].position),v3(s.vertices[i*3+2].position)){nearest=min(nearest,d)}
 }
 minHeadroom=min(minHeadroom,nearest)
}
precondition(minHeadroom>1.4,"Bean arch walking route lacks headroom")
print("PASS: Millennium triangles \(s.triangleCount); materials \(s.materials.count); lights \(s.lights.count); build \(Date().timeIntervalSince(start)) s")
print("PASS: all positions/normals finite, all material IDs valid; Cloud Gate \(mirrorTriangles) triangles, no degenerate faces; max normal length error \(normalError)")
print("Cloud Gate bounds \(lo)...\(hi); volume \(volume) m³; minimum upward headroom from y4.75 along center route \(minHeadroom) m")
