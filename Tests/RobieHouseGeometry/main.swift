import Foundation
import simd
import CryptoKit

typealias V = SIMD3<Float>
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() {fputs("FAIL: \(message)\n",stderr);exit(1)}
}
let start=Date()
let builder=EiffelBuilder()
builder.robieHouse()
let scene=builder.scene
fputs("Robie triangles: \(scene.triangleCount)\n",stderr)
check(scene.triangleCount>30_000,"Robie is structural geometry, not a shell proxy")
check(scene.triangleCount<500_000,"house detail remains within bounded triangle budget")
check(scene.materialIndices.count*3==scene.vertices.count,"triangle/material topology")
check(scene.materialIndices.allSatisfy{Int($0)<scene.materials.count},"valid material references")
check(scene.vertices.allSatisfy{v in (0..<3).allSatisfy{v.position[$0].isFinite && v.normal[$0].isFinite}},"finite positions and normals")
check(scene.vertices.allSatisfy{abs(simd_length($0.normal.xyz)-1)<0.001},"unit geometric normals")
let local=scene.vertices.map{RobieHouseLayout.local($0.position.xyz)}
let lo=local.reduce(V(repeating:.greatestFiniteMagnitude),simd_min),hi=local.reduce(V(repeating:-.greatestFiniteMagnitude),simd_max)
fputs("Robie local bounds: \(lo) to \(hi)\n",stderr)
check(lo.x >= -21 && hi.x <= 29,"house stays within mapped lot east-west")
check(lo.z >= -12.1 && hi.z <= 10.25,"house and sidewalk stay within authored site north-south")
check(hi.y>11 && hi.y<11.3,"chimney establishes correct low-rise silhouette")
check(abs(RobieHouseLayout.prow*2-26.4412)<0.001,"HABS/conservation measured 86ft9in span")
for p in [V(-15,3.2,4),V(0,0,0),V(25,10,-9)] {
    check(simd_distance(RobieHouseLayout.local(RobieHouseLayout.point(p)),p)<0.0015,"map frame roundtrip")
}
check(scene.materials.filter{$0.properties.w>0}.count>=3,"clear/amber/olive transmitting art glass")
check(scene.lights.count>=20 && scene.lights.count<=50,"bounded architectural practical lights")
check(scene.lights.allSatisfy{$0.colorPower.x >= $0.colorPower.y && $0.colorPower.y >= $0.colorPower.z},"warm restrained light palette")
check(scene.lights.contains{$0.parameters.z==1},"interior practical illumination survives daytime")
check(scene.lights.contains{$0.parameters.z==0},"exterior accent lights follow day/night")
let world=CollisionWorld(scene:scene)
// Hash only defined Float coordinates, not SIMD padding. Identical ordered
// triangle data preserves every navigation/camera clearance query exactly.
var navigationWords:[UInt32]=[]
navigationWords.reserveCapacity(world.triangles.count*9)
for triangle in world.triangles {for point in [triangle.a,triangle.b,triangle.c] {for axis in 0..<3 {navigationWords.append(point[axis].bitPattern.littleEndian)}}}
let navigationSHA256=navigationWords.withUnsafeBytes{SHA256.hash(data:Data($0)).map{String(format:"%02x",$0)}.joined()}
func ray(_ origin:V,_ direction:V,_ maximum:Float=80)->Float? {
    world.distance(origin:RobieHouseLayout.point(origin),direction:RobieHouseLayout.east*direction.x+V(0,direction.y,0)+RobieHouseLayout.south*direction.z,maximum:maximum)
}
func expectedHit(_ origin:V,_ direction:V,_ lower:Float,_ upper:Float,_ label:String) {
    let d=ray(origin,direction)
    check(d != nil && d! >= lower && d! <= upper,"\(label), hit \(String(describing:d))")
}
// Actual triangles, not duplicate layout arithmetic, establish the spatial tests.
expectedHit(V(-16,12,0),V(0,-1,0),4.0,6.0,"cantilever roof covers western outdoor room")
expectedHit(V(-8,4.85,1.55),V(0,-1,0),1.55,1.68,"living room has solid main floor")
expectedHit(V(8.4,4.85,1.55),V(0,-1,0),1.55,1.68,"dining room has solid main floor")
expectedHit(V(-8,4.85,4.25),V(0,-1,0),1.55,1.70,"south balcony has physical deck")
expectedHit(V(-8,4.85,4.25),V(0,0,-1),0.95,1.08,"art glass south facade is a physical surface")
expectedHit(V(-4,4.7,0),V(1,0,0),3.4,3.7,"central brick hearth divides living/dining")
check(ray(V(-3,6.04,0),V(1,0,0),6)==nil,"pierced hearth remains open above mantle")
expectedHit(V(-8,4.85,1.55),V(0,1,0),1.2,1.6,"living room is roofed without blocking standing height")
for (a,b,name) in [
    (V(-8,1.9,9.5),V(9,1.9,9.5),"street garden"),
    (V(-8,4.85,4.25),V(8,4.85,4.25),"south balcony"),
    (V(-9,4.85,1.9),V(-2.3,4.85,1.9),"living room"),
    (V(3.3,4.85,1.9),V(10,4.85,1.9),"dining room"),
    (V(-3,4.85,2.13),V(4,4.85,2.13),"continuous aisle around hearth")
] {
    for i in 0..<100 {
        let aa=simd_mix(a,b,V(repeating:Float(i)/100)),bb=simd_mix(a,b,V(repeating:Float(i+1)/100))
        check(world.canMove(from:RobieHouseLayout.point(aa),to:RobieHouseLayout.point(bb)),"\(name) forward clearance at \(i)")
        check(world.canMove(from:RobieHouseLayout.point(bb),to:RobieHouseLayout.point(aa)),"\(name) reverse clearance at \(i)")
    }
}
let report:[String:Any]=[
    "status":"PASS","checks":checks,"scope":"Actual standalone Robie House geometry and navigation; no GPU render claim",
    "triangleCount":scene.triangleCount,"detailCount":scene.detailCount,"materialCount":scene.materials.count,"lightCount":scene.lights.count,
    "navigationTriangles":world.triangles.count,"navigationNodes":world.nodes.count,
    "navigationSHA256":navigationSHA256,
    "boundsLocalMinimum":[lo.x,lo.y,lo.z],"boundsLocalMaximum":[hi.x,hi.y,hi.z],
    "elapsedSeconds":Date().timeIntervalSince(start),"source":"Sources/ArchitectureEngine/RobieHouse.swift",
    "walkingSegments":5,"bidirectionalStepsPerSegment":100
]
let json=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
print(String(data:json,encoding:.utf8)!)
