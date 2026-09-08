import Foundation
import simd
func check(_ value:@autoclosure()->Bool,_ message:String="Geometry assertion",line:Int = #line) {if !value(){fputs("FAIL at line \(line): \(message)\n",stderr);exit(1)}}
let builder=EiffelBuilder(),started=Date()
builder.magnificentGateway()
let scene=builder.scene
print("Gateway checkpoint: \(scene.triangleCount) triangles, \(scene.lights.count) lights");fflush(stdout)
check(scene.vertices.count==scene.materialIndices.count*3)
check(scene.triangleCount>50000 && scene.triangleCount<220000,"Gateway triangle budget changed: \(scene.triangleCount)")
check(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count})
var wrigleyTop:Float=0,tribuneTop:Float=0,normalError:Float=0
for vertex in scene.vertices {
    let p=vertex.position,n=vertex.normal
    check(p.x.isFinite && p.y.isFinite && p.z.isFinite && n.x.isFinite && n.y.isFinite && n.z.isFinite)
    normalError=max(normalError,abs(simd_length(SIMD3(n.x,n.y,n.z))-1))
    if p.x<975 {wrigleyTop=max(wrigleyTop,p.y)} else {tribuneTop=max(tribuneTop,p.y)}
    check(p.x>880 && p.x<1095 && p.z>(-1340) && p.z<(-1153),"Gateway geometry exceeds mapped landmark neighborhood")
}
check(normalError<0.00001)
check(abs(wrigleyTop-129.54)<0.001 && abs(tribuneTop-141.7)<0.001,"Published landmark top heights changed")
let clockMaterial=scene.materials.firstIndex{abs($0.properties.y-0.22)<0.00001 && $0.properties.z==16}!
let blackMaterial=scene.materials.firstIndex{$0.albedo.x<0.01 && $0.properties.x>0.07}!
let clock=MagnificentGatewayLayout.wrigleyClock,outline=MagnificentGatewayLayout.clockFootprint
let ux=simd_normalize(SIMD3<Float>(outline[1][0]-outline[0][0],0,outline[1][1]-outline[0][1])),uz=SIMD3<Float>(-ux.z,0,ux.x)
for direction in [ux,uz,-ux,-uz] {
    let front=clock+direction*6.36
    let faceVertices=scene.materialIndices.enumerated().filter{Int($0.element)==clockMaterial}.flatMap{index,_ in [scene.vertices[index*3].position.xyz,scene.vertices[index*3+1].position.xyz,scene.vertices[index*3+2].position.xyz]}.filter{simd_distance($0,front)<3.0}
    check(faceVertices.count>500,"Missing clock face")
    let minY=faceVertices.map{$0.y}.min()!,maxY=faceVertices.map{$0.y}.max()!
    check(abs(maxY-minY-5.97)<0.003,"Clock face diameter changed")
}
check(scene.materialIndices.filter{Int($0)==blackMaterial}.count>=2900,"Clock hands/ticks lack actual geometry")
check(scene.lights.count>=100 && scene.lights.allSatisfy{$0.positionRadius.x.isFinite && $0.colorPower.w>0 && $0.parameters.x>0})
// Both connecting levels cross the mapped open courtyard rather than changing
// the two footprint polygons into a single solid extruded block.
let world=CollisionWorld(scene:scene)
for y:Float in [9.6,49.2] {
    let hit=world.distance(origin:SIMD3(913.4,y+3,-1200),direction:SIMD3(0,-1,0),maximum:4)
    check(hit != nil && abs(hit!-2.8)<0.02,"Missing actual bridge floor across courtyard")
}
check(world.distance(origin:SIMD3(913.4,1,-1200),direction:SIMD3(0,1,0),maximum:8)==nil,"Mapped courtyard filled by a generic solid block")

print("PASS: Gateway \(scene.triangleCount) triangles, \(scene.materials.count) materials, \(scene.lights.count) lights; CPU build \(Date().timeIntervalSince(started))s")
print("PASS: Wrigley129.54m, Tribune141.7m, mapped neighborhood bounds, finite/unit normals, four5.97m clocks with modeled hands/ticks, both connecting bridges")
