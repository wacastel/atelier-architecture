import Foundation
import simd

typealias V = SIMD3<Float>
let begin=Date(),scene=EiffelScene.build(),world=CollisionWorld(scene:scene)
print("Scene: \(scene.triangleCount) triangles; navigation: \(world.triangles.count) triangles, \(world.nodes.count) BVH nodes; built \(Date().timeIntervalSince(begin))s")
let directions:[(String,V)] = [("+X",V(1,0,0)),("-X",V(-1,0,0)),("+Z",V(0,0,1)),("-Z",V(0,0,-1))]
var failures:[String]=[]
func supported(_ p:V)->V? {
    guard let distance=world.distance(origin:p+V(0,0.45,0),direction:V(0,-1,0),maximum:2.8) else{return nil}
    return V(p.x,p.y+0.45-distance+1.75,p.z)
}
func step(_ p:V,_ delta:V)->V? {
    guard let destination=supported(p+delta),world.canMove(from:p,to:destination) else{return nil}
    return destination
}
for id in [1,3,4,5,6] {
    let stop=EiffelScene.stops[id],p=stop.pose.position
    let support=supported(p)
    let floor=support.map{$0.y-1.75}
    let pass=directions.filter{step(p,$0.1*0.2) != nil}.map{$0.0}
    print("STOP \(id) \(stop.title): position=\(p), floor=\(floor.map{String($0)} ?? "NONE"), passable 0.2m steps=\(pass)")
    if support==nil || pass.isEmpty{failures.append("Stop \(id) unsupported or trapped")}
}
func path(_ label:String,from:V,to:V,shouldReach:Bool=true) {
    var current=from
    let length=simd_distance(from,to),count=max(1,Int(ceil(length/0.1))),delta=(to-from)/Float(count)
    var reached=true
    for i in 0..<count {
        if let next=step(current,delta){current=next}
        else{print("PATH \(label): blocked after \(i) / \(count) steps at \(current)");reached=false;break}
    }
    if reached{print("PATH \(label): reached \(current), length \(length)m")}
    if reached != shouldReach{failures.append("Path \(label) expected reached=\(shouldReach), got \(reached)")}
}
path("ground beneath arches",from:V(0,1.85,77),to:V(0,1.85,0))
path("first terrace lateral",from:V(3.5,58.75,28),to:V(17,58.75,28))
path("east pavilion south doorway",from:V(26,58.8,15),to:V(26,58.8,9))
path("east pavilion full central aisle + north doorway",from:V(26,58.8,9),to:V(26,58.8,-15))
path("west pavilion mirrored central aisle",from:V(-26,58.8,15),to:V(-26,58.8,-15))
path("second terrace lateral",from:V(3,116.75,17.5),to:V(-4,116.75,17.5))
path("summit gallery lateral",from:V(0,277.75,6.6),to:V(4.0,277.75,6.6))
// Negative cases must stop before the central void or outside railings.
path("first terrace central void safety",from:V(0,58.75,17),to:V(0,58.75,9),shouldReach:false)
path("first terrace outer edge safety",from:V(0,58.75,35),to:V(0,58.75,40),shouldReach:false)
path("second terrace central void safety",from:V(0,116.75,10),to:V(0,116.75,4),shouldReach:false)
path("summit outer edge safety",from:V(0,277.75,6.6),to:V(0,277.75,11),shouldReach:false)
for (label,p) in [("first void",V(0,58.75,0)),("second void",V(0,116.75,0)),("outside first deck",V(0,58.75,40))] {
    let found=supported(p) != nil; print("SUPPORT \(label): \(found)")
    if found{failures.append("Unexpected support at \(label)")}
}
// The Chicago visitor areas have actual supporting slabs and transparent glass
// collision surfaces. Check that the Ledge allows entry but prevents an exit
// through its outer pane or unsupported space beyond the box.
let chicago=WillisScene.build(),chicagoWorld=CollisionWorld(scene:chicago)
let cy=WillisScene.skydeckHeight+1.75
func chicagoSupport(_ p:V)->Bool {
    chicagoWorld.distance(origin:p+V(0,0.45,0),direction:V(0,-1,0),maximum:2.8) != nil
}
for id in [1,2,3,4,5] {
    let p=WillisScene.stops[id].pose.position
    if !chicagoSupport(p) {failures.append("Chicago view \(id+1) lacks floor support")}
}
let ledgeInside=V(-35.0,cy,0),ledgeOutside=V(-36.5,cy,0)
if !chicagoSupport(ledgeInside) {failures.append("Transparent Ledge floor does not support navigation")}
if chicagoSupport(ledgeOutside) {failures.append("Unsupported space beyond Ledge incorrectly supplies floor")}
if chicagoWorld.canMove(from:ledgeInside,to:ledgeOutside) {failures.append("Ledge outer glass did not block movement")}
if !chicagoWorld.canMove(from:V(-32.65,cy,0),to:V(-34.7,cy,0)) {failures.append("Ledge entry aperture obstructed")}
if !chicagoWorld.canMove(from:V(0,1.85,76),to:V(0,1.85,68)) {failures.append("Catalog entrance aisle obstructed")}
print("CHICAGO: supported visitor views; glass Ledge floor, entry, outer barrier and void; Catalog entrance")
for (name,p) in [("Cloud Gate west landing",V(1029,4.75,-424.15)),("Cloud Gate arch",V(1042.46,4.75,-424.15)),("Cloud Gate east landing",V(1056,4.75,-424.15)),("Griffin Court",V(1146,2,-184)),("museum gallery",V(1175,2,-178))] {
    if !chicagoSupport(p) { failures.append("\(name) lacks a supporting floor") }
}
for (name,a,b) in [("Bean arch",V(1029,4.75,-424.15),V(1056,4.75,-424.15)),("Modern Wing entrance",V(1146,2,-211),V(1146,2,-184)),("gallery opening",V(1146,2,-178),V(1175,2,-178))] {
    if !chicagoWorld.canMove(from:a,to:b) { failures.append("\(name) blocks its intended passage") }
}
print("MILLENNIUM: raised plaza and Bean arch support/clearance; Modern Wing entrance, Griffin Court and gallery")
print("FAILURES: \(failures)")
if !failures.isEmpty{exit(1)}
