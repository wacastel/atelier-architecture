import Foundation
import simd

var count=0
func require(_ value:Bool,_ message:String) { count += 1; if !value {fputs("FAIL: \(message)\n",stderr);exit(1)} }
let b=EiffelBuilder();b.lincolnParkZoo();let scene=b.scene
require(scene.triangleCount>50000 && scene.triangleCount<1325397,"bounded detailed geometry \(scene.triangleCount)")
require(scene.lights.count>30 && scene.lights.count<200,"bounded light cost \(scene.lights.count)")
require(scene.materialIndices.count==scene.triangleCount,"one material per triangle")
for v in scene.vertices {
    require(v.position.x.isFinite && v.position.y.isFinite && v.position.z.isFinite,"finite vertices")
    require(v.normal.x.isFinite && v.normal.y.isFinite && v.normal.z.isFinite,"finite normals")
    require(abs(simd_length(SIMD3(v.normal.x,v.normal.y,v.normal.z))-1)<0.002,"unit normals")
}
for m in scene.materialIndices {require(m<scene.materials.count,"valid material IDs")}
for l in scene.lights {require(l.parameters.x>0 && l.parameters.x<45 && l.colorPower.w>=0,"bounded finite-support lights")}
for id in LincolnParkZooLayout.authoredBuildingIDs {require(LincolnParkZooMap.shapes.contains{$0.id==id},"mapped landmark \(id)")}
for s in LincolnParkZooMap.shapes {
    require(s.points.count>=3 && s.triangles.count%3==0,"valid mapped shape")
    require(s.triangles.allSatisfy{$0>=0 && $0<s.points.count},"indices in bounds")
    require(s.rings.allSatisfy{$0.count>=3},"mapped boundary rings")
}
// The actual leaf mesh must be closed at poles and the longitude seam. The
// historical radius ripple varied with longitude even at a pole; that produced
// disconnected triangle fans, visible as dark slivers in the close tree views.
let probe=EiffelBuilder()
probe.zooLeafMass(SIMD3(259.125,9,-4701),SIMD3(3,4,2.8),probe.leaf,seed:1.27)
struct Edge:Hashable {let a:SIMD3<Float>;let b:SIMD3<Float>}
func before(_ a:SIMD3<Float>,_ b:SIMD3<Float>)->Bool {a.x != b.x ? a.x<b.x:a.y != b.y ? a.y<b.y:a.z<b.z}
var edges:[Edge:Int]=[:]
for i in stride(from:0,to:probe.scene.vertices.count,by:3) {
    let points=(0..<3).map{probe.scene.vertices[i+$0].position.xyz}
    require(simd_length_squared(simd_cross(points[1]-points[0],points[2]-points[0]))>0.000001,"noncollapsed foliage triangle")
    for j in 0..<3 {let a=points[j],b=points[(j+1)%3],edge=before(a,b) ? Edge(a:a,b:b):Edge(a:b,b:a);edges[edge,default:0] += 1}
}
require(edges.values.allSatisfy{$0==2},"watertight actual foliage mesh: every undirected edge used twice")
let radius=SIMD3<Float>(3,4,2.8)
for pole:Float in [-Float.pi/2,Float.pi/2] {
    let first=LincolnParkZooLayout.foliagePoint(angle:0,latitude:pole,radius:radius,seed:1.27)
    var legacyMinimum:Float = .greatestFiniteMagnitude,legacyMaximum:Float = -.greatestFiniteMagnitude
    for i in 0..<48 {
        let a=Float(i)*2*Float.pi/48
        require(LincolnParkZooLayout.foliagePoint(angle:a,latitude:pole,radius:radius,seed:1.27)==first,"one exact pole for all longitudes")
        let oldRadius:Float=1+0.065*sin(a*5+1.27)*cos(pole*3)+0.045*cos(a*7-pole*4+1.27)
        let oldY=sin(pole)*radius.y*oldRadius
        legacyMinimum=min(legacyMinimum,oldY);legacyMaximum=max(legacyMaximum,oldY)
    }
    require(legacyMaximum-legacyMinimum>0.30,"legacy negative control reproduces separated pole heights")
}
require(LincolnParkZooMap.roads.contains{$0.id==757088063},"mapped Cannon Drive corridor included")
var roadProbes=0
for road in LincolnParkZooMap.roads {for i in 0..<road.points.count-1 {
    let a=road.points[i],b=road.points[i+1],center=(a+b)/2
    if center.x<0 || center.x>435 || center.z < -5230 || center.z > -4150 {continue}
    require(road.halfWidth>0 && road.halfWidth.isFinite,"positive production road width")
    require(probe.zooRoadClearance(center)<0,"mapped center is within road carriageway")
    require(!probe.zooPlantable(center,clearance:4),"vehicle carriageway rejects mature trees")
    require(!probe.zooPlantable(center,clearance:2.25),"vehicle carriageway rejects shrubs")
    roadProbes += 1
}}
require(roadProbes>40,"road exclusion covers the actual surrounding vehicle network")

// Rendered Fisher approaches must be broad graded DECKS. The original call
// passed a horizontal sideways reference to beam(), whose cross(axis,ref)
// basis rotated the 8.8 m width almost vertically. Route collision checks did
// not catch it because the boardwalk route did not walk on these approaches.
let fisherA=LincolnParkZooLayout.fisherBridgeStart,fisherB=LincolnParkZooLayout.fisherBridgeEnd
let fisherForward=simd_normalize(fisherB-fisherA),fisherSide=SIMD3<Float>(-fisherForward.z,0,fisherForward.x)
for (start,direction) in [(fisherA,-fisherForward),(fisherB,fisherForward)] {
    let end=start+direction*14-SIMD3<Float>(0,3.08,0)
    let ramp=EiffelBuilder();ramp.zooFisherApproachRamp(from:start,to:end,material:ramp.iron)
    require(ramp.scene.triangleCount==12,"approach is one closed six-face deck")
    let rampPoints=ramp.scene.vertices.map{$0.position.xyz}
    var minimumWidth:Float = .infinity,maximumWidth:Float = -.infinity
    for point in rampPoints {
        let delta=point-start,lateral=simd_dot(delta,fisherSide),run=simd_dot(delta,direction)
        minimumWidth=min(minimumWidth,lateral);maximumWidth=max(maximumWidth,lateral)
        let gradedCenterHeight=start.y-0.22-run*(3.08/14)
        require(abs(point.y-gradedCenterHeight)<0.23,"deck thickness follows grade instead of vertical 8.8 m width")
        require(point.y > -0.33 && point.y < 3.22,"approach stays within street-to-bridge grade envelope")
    }
    require(abs((maximumWidth-minimumWidth)-8.8)<0.003,"actual ramp width spans 8.8 m horizontally")
    let rampWorld=CollisionWorld(scene:ramp.scene)
    for progress:Float in [0.1,0.25,0.5,0.75,0.9] {for lateral:Float in [-4,0,4] {
        let surface=start+direction*(14*progress)+fisherSide*lateral-SIMD3<Float>(0,3.08*progress,0)
        let hit=rampWorld.distance(origin:surface+SIMD3(0,1,0),direction:SIMD3(0,-1,0),maximum:1.1)
        require(hit != nil && abs(hit!-1)<0.03,"downward ray reaches graded deck across full pedestrian width")
    }}
    for lateral:Float in [-4.7,4.7] {
        let outside=(start+end)/2+fisherSide*lateral+SIMD3(0,1,0)
        require(rampWorld.distance(origin:outside,direction:SIMD3(0,-1,0),maximum:10)==nil,"deck ends outside its intended width")
    }
    let legacy=EiffelBuilder()
    legacy.beam(start-SIMD3(0,0.22,0),end-SIMD3(0,0.22,0),8.8,0.44,legacy.iron,normal:fisherSide)
    let oldPoints=legacy.scene.vertices.map{$0.position.xyz},oldYs=oldPoints.map{$0.y}
    require(oldYs.max()!-oldYs.min()!>10.5,"legacy sideways-normal control reproduces tall wall")
    let oldWidth=oldPoints.map{simd_dot($0-start,fisherSide)}
    require(oldWidth.max()!-oldWidth.min()!<0.5,"legacy wall has only narrow horizontal thickness")
    let legacyWorld=CollisionWorld(scene:legacy.scene)
    let oldEdge=(start+end)/2+fisherSide*4+SIMD3(0,1,0)
    require(legacyWorld.distance(origin:oldEdge,direction:SIMD3(0,-1,0),maximum:10)==nil,"legacy negative control cannot support the deck's lateral walking surface")
}

let world=CollisionWorld(scene:scene)
for (name,points) in [("Nature Boardwalk",LincolnParkZooLayout.natureRoute),("Zoo public mall",LincolnParkZooLayout.zooRoute),("Conservatory",LincolnParkZooLayout.conservatoryRoute),("Lily Pool",LincolnParkZooLayout.lilyRoute)] {
    for i in 0..<points.count-1 {
        let a=points[i],z=points[i+1],steps=max(1,Int(simd_distance(a,z)/0.35))
        for j in 0...steps {
            let p=a+(z-a)*Float(j)/Float(steps)
            for d in [SIMD3<Float>(1,0,0),SIMD3<Float>(-1,0,0),SIMD3<Float>(0,0,1),SIMD3<Float>(0,0,-1)] { require(world.canMove(from:p,to:p+d*0.001),"\(name) clear at \(p)") }
        }
    }
}
print("PASS \(count) checks; \(scene.triangleCount) triangles; \(scene.lights.count) lights; exact mapped landmark and route fixtures")
