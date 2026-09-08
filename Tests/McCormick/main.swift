import Foundation
import simd
func require(_ value:@autoclosure()->Bool,_ message:String) {if !value(){fputs("FAIL: \(message)\n",stderr);exit(1)}}
let started=Date(),builder=EiffelBuilder();builder.mccormickPlace();let scene=builder.scene
require(scene.triangleCount>30000 && scene.triangleCount<650000,"Bounded McCormick geometry: \(scene.triangleCount)")
require(scene.vertices.count==scene.materialIndices.count*3,"Triangle buffer packing")
require(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count},"Material indices")
var top:Float=0,normalError:Float=0,collapsed=0
for vertex in scene.vertices {
    let p=vertex.position,n=vertex.normal
    require(p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite && n.z.isFinite,"Finite geometry")
    require(p.x>1000 && p.x<2160 && p.z>2500 && p.z<3420,"McCormick geometry leaves its mapped neighborhood: \(p)")
    top=max(top,p.y);normalError=max(normalError,abs(simd_length(SIMD3(n.x,n.y,n.z))-1))
}
for i in stride(from:0,to:scene.vertices.count,by:3) {
    let a=scene.vertices[i].position,b=scene.vertices[i+1].position,c=scene.vertices[i+2].position
    if simd_length_squared(simd_cross(SIMD3(b.x-a.x,b.y-a.y,b.z-a.z),SIMD3(c.x-a.x,c.y-a.y,c.z-a.z)))<1e-12 {collapsed+=1}
}
require(normalError<0.00001 && collapsed==0,"Unit normals and nondegenerate geometry")
require(abs(top-McCormickLayout.marriottHeight)<0.5,"Marriott's verified architectural height is the campus maximum: \(top)")
let world=CollisionWorld(scene:scene)
for (id,y) in [(Int64(136340574),Float(30)),(769452749,29),(204886155,27),(-17647196,30)] {
    let shape=MuseumCampusContext.landmark(id)!
    var hits=0
    for i in stride(from:0,to:shape.triangles.count,by:3) {
        let a=shape.points[shape.triangles[i]],b=shape.points[shape.triangles[i+1]],c=shape.points[shape.triangles[i+2]]
        let q=SIMD3<Float>((a[0]+b[0]+c[0])/3,y+0.06,(a[1]+b[1]+c[1])/3)
        if let hit=world.distance(origin:q,direction:SIMD3(0,-1,0),maximum:0.1),abs(hit-0.06)<0.006 {hits+=1}
    }
    require(hits>0,"Mapped roof triangles missing for \(id)")
}
// This route crosses the whole campus, so test the actual head/torso/leg camera sweeps
// against this component before the combined-world route regression.
var previous=MuseumCampusWalkthrough.pose(view:7,seconds:0).position
for tick in 1...1800 {
    let p=MuseumCampusWalkthrough.pose(view:7,seconds:Double(tick)/10).position
    require(world.canMove(from:previous,to:p),"McCormick route obstructed at \(Double(tick)/10)s: \(p)")
    previous=p
}
print("PASS: McCormick \(scene.triangleCount) triangles, \(scene.lights.count) lights; four mapped roofs, finite/unit geometry, published Marriott height,1800 clear flight steps; \(Date().timeIntervalSince(started))s")
