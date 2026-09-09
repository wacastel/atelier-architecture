import Foundation
import simd

typealias V=SIMD3<Float>
var checks=0, failures:[String]=[]
func check(_ condition:Bool,_ label:String) { checks+=1; if !condition {failures.append(label)} }
func near(_ a:V,_ b:V,_ epsilon:Float=0.0001)->Bool { simd_distance(a,b)<epsilon }
func finite(_ p:V)->Bool {p.x.isFinite && p.y.isFinite && p.z.isFinite}
func ray(_ p:SIMD2<Float>,_ aspect:Float,_ camera:CameraPose)->FocusRay {FocusRay.make(normalized:p,aspect:aspect,pose:camera)!}
let camera=CameraPose(position:V(0,3,0),target:V(0,3,-10),fov:90)
check(near(ray(SIMD2(0.5,0.5),1,camera).direction,V(0,0,-1)),"center ray follows forward")
check(near(ray(SIMD2(1,0.5),2,camera).direction,simd_normalize(V(2,0,-1))),"landscape right edge uses vertical FOV times aspect")
check(near(ray(SIMD2(0,0.5),0.5,camera).direction,simd_normalize(V(-0.5,0,-1))),"portrait left edge remains narrow")
check(near(ray(SIMD2(0.5,0),0.5,camera).direction,simd_normalize(V(0,1,-1))),"top edge is positive camera up")
check(near(ray(SIMD2(0.5,1),2,camera).direction,simd_normalize(V(0,-1,-1))),"bottom edge is negative camera up")
let east=CameraPose(position:V(7,2,-3),target:V(17,2,-3),fov:60)
check(ray(SIMD2(1,0.5),1,east).direction.z>0,"world-rotated right axis agrees with Metal cross(forward,up)")
// Independent forward projection of off-axis samples tests round-trip signs,
// pixel-center normalization, portrait aspect and a camera with both yaw/pitch.
let angled=CameraPose(position:V(11,19,-37),target:V(-17,4,23),fov:67)
let forward=simd_normalize(angled.target-angled.position), right=simd_normalize(simd_cross(forward,V(0,1,0)))
let up=simd_normalize(simd_cross(right,forward)),tangent=tan(angled.fov * .pi/360)
for (w,h) in [(1920,1080),(700,1400),(1,1)] {
    for (x,y) in [(0,0),(w/2,h/2),(w-1,h-1)] {
        let pixel=SIMD2((Float(x)+0.5)/Float(w),(Float(y)+0.5)/Float(h))
        let d=ray(pixel,Float(w)/Float(h),angled).direction, z=simd_dot(d,forward)
        let projected=SIMD2((simd_dot(d,right)/(z*tangent*Float(w)/Float(h))+1)/2,(1-simd_dot(d,up)/(z*tangent))/2)
        check(simd_distance(projected,pixel)<0.000001,"pixel-center Metal projection round trip \(w)x\(h) at \(x),\(y)")
    }
}
for target in [V(0,1,0),V(0,-1,0),V(0.00001,1,0)] {
    let pole=CameraPose(position:.zero,target:target,fov:70)
    check(finite(ray(SIMD2(0.2,0.1),0.6,pole).direction),"finite pole screen ray \(target)")
}
for invalid in [SIMD2<Float>(-.infinity,0.5),SIMD2(.nan,0.5),SIMD2(-0.01,0.5),SIMD2(0.5,1.01)] {
    check(FocusRay.make(normalized:invalid,aspect:1,pose:camera)==nil,"invalid/outside view coordinate rejected")
}
check(FocusRay.make(normalized:SIMD2(0.5,0.5),aspect:0,pose:camera)==nil,"zero aspect rejected")
check(FocusRay.make(normalized:SIMD2(0.5,0.5),aspect:.infinity,pose:camera)==nil,"infinite aspect rejected")
check(FocusRay.make(normalized:SIMD2(0.5,0.5),aspect:1,pose:CameraPose(position:.zero,target:.zero))==nil,"zero view direction rejected")

func target(_ id:String,_ center:V,_ extent:V)->LandmarkFocus {
    LandmarkFocus(id:id,name:id,volumes:[FocusVolume(minimum:center-extent/2,maximum:center+extent/2)],center:center)
}
let building=target("building",V(0,3,-12),V(8,6,4)),other=target("other",V(20,4,-10),V(4,8,4))
let catalog=LandmarkFocusCatalog(authored:[building,other])
func wall(_ a:V,_ b:V,_ c:V,_ d:V,_ scene:inout SceneData) {
    for p in [a,b,c,a,c,d] { scene.vertices.append(SceneVertex(p,V(0,0,1))) }
    scene.materialIndices += [0,0]
}
var scene=SceneData()
wall(V(-4,0,-10),V(4,0,-10),V(4,6,-10),V(-4,6,-10),&scene)
let visibleWorld=CollisionWorld(scene:scene),centerRay=ray(SIMD2(0.5,0.5),1,camera)
check(catalog.pick(ray:centerRay,world:visibleWorld)?.id==building.id,"visible nearest building surface selects")
wall(V(-6,0,-5),V(6,0,-5),V(6,9,-5),V(-6,9,-5),&scene)
let blockedWorld=CollisionWorld(scene:scene)
check(catalog.pick(ray:centerRay,world:blockedWorld)==nil,"foreground unnamed wall blocks landmark behind it")
let foreground=target("foreground",V(0,4.5,-5.05),V(12,9,0.2))
check(LandmarkFocusCatalog(authored:[building,foreground]).pick(ray:centerRay,world:blockedWorld)?.id==foreground.id,"different named foreground wins by actual first hit")
check(catalog.pick(ray:FocusRay(origin:V(0,20,0),direction:V(0,1,0)),world:visibleWorld)==nil,"sky misses clear focus instead of selecting projected bounds")
check(catalog.identify(hitPoint:V(0,3,-7))==nil,"point in front of volume is not classified")
check(catalog.pick(ray:centerRay,world:visibleWorld,maximum:5)==nil,"pick maximum distance respected")

// Dense picking detail is optional and never enters navigation triangles/nodes.
var denseScene=SceneData()
wall(V(-4,0,-10),V(4,0,-10),V(4,6,-10),V(-4,6,-10),&denseScene)
wall(V(-0.1,2.9,-5),V(0.1,2.9,-5),V(0.1,3.1,-5),V(-0.1,3.1,-5),&denseScene)
wall(V(4.9,2.9,-5),V(5.1,2.9,-5),V(5.1,3.1,-5),V(4.9,3.1,-5),&denseScene)
let detailRegion=CollisionWorld.PickingRegion(minimum:V(-0.2,2.8,-5.2),maximum:V(0.2,3.2,-4.8))
let ordinaryDenseWorld=CollisionWorld(scene:denseScene)
let detailedWorld=CollisionWorld(scene:denseScene,detailedPickingRegions:[detailRegion,detailRegion])
check(detailedWorld.triangles.count==ordinaryDenseWorld.triangles.count && detailedWorld.nodes.count==ordinaryDenseWorld.nodes.count,"detail retention leaves navigation counts unchanged")
check(zip(detailedWorld.triangles,ordinaryDenseWorld.triangles).allSatisfy{$0.a==$1.a && $0.b==$1.b && $0.c==$1.c},"detail retention leaves original navigation triangle order/positions unchanged")
check(detailedWorld.detailedPickingTriangleCount==2,"only omitted triangles in requested region retained, overlapping regions do not duplicate")
check(detailedWorld.distance(origin:camera.position,direction:centerRay.direction,maximum:20)==10,"navigation continues through omitted small mesh")
check(detailedWorld.pickingDistance(origin:camera.position,direction:centerRay.direction,maximum:20)==5,"picking sees requested small mesh")
check(detailedWorld.canMove(from:camera.position,to:V(0,3,-7))==ordinaryDenseWorld.canMove(from:camera.position,to:V(0,3,-7)),"detail retention leaves canMove unchanged")
check(catalog.pick(ray:centerRay,world:detailedWorld)==nil,"dense unnamed foreground blocks named building behind")
let fineFocus=target("fine",V(0,3,-5),V(0.3,0.3,0.1))
check(LandmarkFocusCatalog(authored:[building,fineFocus]).pick(ray:centerRay,world:detailedWorld)?.id==fineFocus.id,"dense visible object is selectable")
wall(V(-2,0,-3),V(2,0,-3),V(2,6,-3),V(-2,6,-3),&denseScene)
let ordinaryForeground=CollisionWorld(scene:denseScene,detailedPickingRegions:[detailRegion])
check(ordinaryForeground.pickingDistance(origin:camera.position,direction:centerRay.direction,maximum:20)==3,"ordinary foreground occludes dense mesh")
let outsideRay=FocusRay(origin:V(5,3,0),direction:V(0,0,-1))
check(detailedWorld.pickingDistance(origin:outsideRay.origin,direction:outsideRay.direction,maximum:8)==nil,"unrequested small mesh remains omitted")
check(ordinaryDenseWorld.detailedPickingTriangleCount==0,"default constructor builds no picking detail BVH")

let chicago=LandmarkFocusCatalog(world:"chicago",includeMapped:false),paris=LandmarkFocusCatalog(world:"paris",includeMapped:false)
let adler=chicago.authored.first{$0.id=="chicago:adler-planetarium"}!
check(adler.name=="Adler Planetarium","Adler has explicit named identity")
check(chicago.identify(hitPoint:V(2389.5,8,1393.247))?.id==adler.id,"Adler west granite facade identified")
check(chicago.identify(hitPoint:V(2413.718,28.7,1393.247))?.id==adler.id,"Adler copper dome crown identified")
check(chicago.identify(hitPoint:V(1042.46,8,-434.15))?.name=="Cloud Gate","Cloud Gate long north/south axis identified")
check(chicago.identify(hitPoint:V(1052,8,-424.15))==nil,"Cloud Gate short east/west axis excludes adjacent plaza")
check(chicago.identify(hitPoint:V(2464.9,3.7,1393.247))?.id==adler.id,"Adler east glass pavilion identified")
check(chicago.identify(hitPoint:V(2450,9,1440))==nil,"outside Adler crescent does not claim surrounding park")
var adlerScene=SceneData()
wall(V(2389.5,2,1388),V(2389.5,2,1398),V(2389.5,10,1398),V(2389.5,10,1388),&adlerScene)
let adlerRay=ray(SIMD2(0.5,0.5),16/9,CameraPose(position:V(2330,8,1393),target:V(2413,8,1393)))
check(chicago.pick(ray:adlerRay,world:CollisionWorld(scene:adlerScene))?.id==adler.id,"Adler direct click uses production BVH")
wall(V(2350,0,1380),V(2350,0,1410),V(2350,14,1410),V(2350,14,1380),&adlerScene)
check(chicago.pick(ray:adlerRay,world:CollisionWorld(scene:adlerScene))==nil,"Adler cannot be selected through foreground geometry")
check(paris.identify(hitPoint:V(0,320,0))?.name=="Eiffel Tower","Paris Eiffel summit identified")
check(paris.identify(hitPoint:V(45,280,0))==nil,"Eiffel base footprint is not extruded through the summit")
check(chicago.identify(hitPoint:V(-23,210,-23))==nil,"Willis upper setback does not select air")

var selection=FocusSelection()
let selected=selection.toggle(building,pose:camera)
check(selected.position==camera.position,"selection exactly preserves camera position")
check(selected.target==building.center,"selection retargets to focus center")
check(selection.orbit?.focus.id==building.id,"selection stores focus")
let cleared=selection.toggle(building,pose:selected)
check(selection.orbit==nil && cleared.position==selected.position && cleared.target==selected.target,"same object toggles off without changing camera")
_ = selection.toggle(building,pose:camera)
let changed=selection.toggle(other,pose:selected)
check(selection.orbit?.focus.id==other.id && changed.position==selected.position && changed.target==other.center,"different object replaces focus without moving camera")
let sky=selection.toggle(nil,pose:changed)
check(selection.orbit==nil && sky.position==changed.position && sky.target==changed.target,"sky clears focus without changing camera")

for object in [building,adler,chicago.authored.first{$0.id=="chicago:willis-tower"}!,target("tiny",V(0,1.1,0),V(0.2,0.2,0.2))] {
    let start=CameraPose(position:object.center+V(40,10,60),target:object.center,fov:55)
    var orbit=FocusOrbit(focus:object,pose:start)!
    let initialRadius=orbit.radius
    orbit.rotate(yawDelta:0.3,pitchDelta:0.05)
    check(finite(orbit.pose.position) && near(orbit.pose.target,object.center),"orbit stays finite and aims at \(object.id)")
    check(abs(orbit.radius-initialRadius)<0.001 || orbit.radius>initialRadius,"rotation preserves radius unless clearance requires increasing it")
    for scale:Float in [-100,100,Float.greatestFiniteMagnitude,-Float.greatestFiniteMagnitude] {
        orbit.dolly(logScale:scale)
        check(orbit.radius.isFinite && orbit.radius>=1 && orbit.radius<=orbit.maximumRadius,"finite radius clamped for \(object.id), scale \(scale)")
        check(!object.bounds.contains(orbit.pose.position),"dolly cannot enter focus bounds for \(object.id)")
        check(orbit.pose.position.y>=0.59,"dolly stays above grade for \(object.id)")
    }
    for turn in 0..<180 {
        orbit.rotate(yawDelta:0.17,pitchDelta:turn%2==0 ? -0.05:0.04)
        check(finite(orbit.pose.position) && !object.bounds.contains(orbit.pose.position),"successive orbit \(turn) stays outside \(object.id)")
        check(orbit.pose.position.y>=0.59 && abs(orbit.elevation)<=FocusOrbit.elevationLimit+0.00001,"orbit elevation/grade bounded \(object.id)")
    }
    let before=orbit.pose
    orbit.rotate(yawDelta:.nan,pitchDelta:0);orbit.dolly(logScale:.infinity)
    check(orbit.pose.position==before.position,"non-finite control input ignored")
}
for p in [building.center,building.center+V(0.2,0.1,0.1),building.center+V(0,20,0),building.center-V(0,20,0)] {
    let original=CameraPose(position:p,target:p+V(1,0,0))
    var orbit=FocusOrbit(focus:building,pose:original)!
    check(orbit.pose.position==p && finite(orbit.pose.target) && simd_distance(orbit.pose.target,p)>0,"interior/pole selection retains position with finite look")
    orbit.rotate(yawDelta:0,pitchDelta:0)
    check(finite(orbit.pose.position) && !building.bounds.contains(orbit.pose.position) && orbit.pose.position.y>=0.59,"first manipulation exits an interior focus envelope safely")
}
check(FocusOrbit(focus:building,pose:CameraPose(position:V(.nan,0,0),target:.zero))==nil,"invalid camera cannot create orbit")

// A western skyline selection starts well outside the usual tower-relative
// radius. The first small manipulation must not jump several kilometres inward.
let distantWillis=chicago.authored.first{$0.id=="chicago:willis-tower"}!
let westernCameras=[V(-13569.5,55,-1135.8),V(-18000,100,-950),V(-20000,150,-500)]
for position in westernCameras {
    let original=CameraPose(position:position,target:V(350,210,-900),fov:5.2)
    let entered=simd_distance(position,distantWillis.center)
    var orbit=FocusOrbit(focus:distantWillis,pose:original)!
    check(orbit.pose.position==position && abs(orbit.maximumRadius-entered)<0.01,"distant selection retains entry pose and outward limit")
    orbit.rotate(yawDelta:0,pitchDelta:0)
    check(near(orbit.pose.position,position,0.01),"zero orbit input must not clamp distant selection inward")
    orbit.rotate(yawDelta:0.0001,pitchDelta:0)
    check(abs(orbit.radius-entered)<0.01 && simd_distance(orbit.pose.position,position)<entered*0.00011,
          "first small orbit changes angle without a kilometre-scale radial jump")
    orbit.dolly(logScale:-0.01)
    check(abs(orbit.radius-entered*exp(-0.01))<0.01,"first inward scroll follows requested gradual logarithmic distance")
    for _ in 0..<20 {orbit.dolly(logScale:-0.01)}
    check(abs(orbit.radius-entered*exp(-0.21))<0.04,"successive inward scrolls remain continuous outside the old radius cap")
    orbit.dolly(logScale:0.01)
    check(abs(orbit.radius-entered*exp(-0.20))<0.04,"reversing a scroll does not snap to the entry limit")
    orbit.dolly(logScale:20)
    check(abs(orbit.radius-entered)<0.01,"distant dolly-out cannot exceed the entry radius")
}
// Near-object limits are intentionally unchanged, including small and tall targets.
for object in [building,adler,distantWillis] {
    let ordinaryLimit=min(Float(50_000),max(Float(300),simd_length(object.bounds.extent)*12))
    let offset=V(ordinaryLimit*0.2,ordinaryLimit*0.1,ordinaryLimit*0.15)
    var orbit=FocusOrbit(focus:object,pose:CameraPose(position:object.center+offset,target:object.center))!
    check(orbit.maximumRadius==ordinaryLimit,"near-object orbit maximum retains original envelope-dependent behavior")
    orbit.dolly(logScale:20)
    check(abs(orbit.radius-ordinaryLimit)<0.01,"near-object maximum still clamps large outward input")
}

// A mapped concave building and a triangulated hole reject adjacent courtyards.
let concave=FocusVolume(points:[[0,0],[10,0],[10,3],[3,3],[3,10],[0,10]],bottom:0.25,top:10)!
check(concave.contains(V(1,5,8)) && !concave.contains(V(8,5,8)),"concave footprint classification")
let hole=FocusVolume(points:[[0,0],[10,0],[10,10],[0,10],[3,3],[7,3],[7,7],[3,7]],triangles:[0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7],bottom:0.25,top:10)!
check(hole.contains(V(1,4,5)) && !hole.contains(V(5,4,5)),"triangulated mapped courtyard stays unselectable")
let degenerate=FocusVolume(points:[[0,0],[10,0],[10,10],[0,10],[3,3],[7,3],[7,7],[3,7]],triangles:[0,0,0,0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7],bottom:0.25,top:10)!
check(!degenerate.contains(V(5,4,5)),"degenerate mapped triangle cannot fill a courtyard")
let boundary=LandmarkFocus(id:"boundary",name:"boundary",volumes:[FocusVolume(points:[[190,0],[199.95,0],[199.95,10],[190,10]],top:10)!])
check(LandmarkFocusCatalog(authored:[],mapped:[boundary]).identify(hitPoint:V(200.05,4,5))?.id=="boundary","grid indexes boundary tolerance across a cell edge")
let mappedFocus=LandmarkFocus(id:"chicago:osm:way/42",name:"Mapped test building",volumes:[concave])
let testMap=LandmarkFocusCatalog(authored:[],mapped:[mappedFocus])
check(testMap.identify(hitPoint:V(1,5,8))?.id==mappedFocus.id,"mapped building identity uses stable OSM ID")
check(testMap.identify(hitPoint:V(8,5,8))==nil,"mapped bounds do not fill footprint concavity")

let start=Date(),fullCatalog=LandmarkFocusCatalog(world:"chicago")
let loadSeconds=Date().timeIntervalSince(start)
check(fullCatalog.mapped.count>10_000,"offline Chicago building metadata loaded without constructing scene")
let probes=fullCatalog.mapped.prefix(2_000),queryStart=Date()
var largestCandidateCount=0
for building in probes {
    let p=building.bounds.center
    largestCandidateCount=max(largestCandidateCount,fullCatalog.mappedCandidateCount(at:p))
    _ = fullCatalog.identify(hitPoint:p)
}
let querySeconds=Date().timeIntervalSince(queryStart)
check(largestCandidateCount<500,"mapped classification uses a bounded local grid, not all city buildings")
let fullParis=LandmarkFocusCatalog(world:"paris")
check(fullParis.mapped.count>1_000,"offline Paris building metadata loaded")
print("Focus navigation: \(checks) checks; authored Chicago \(fullCatalog.authored.count), mapped Chicago \(fullCatalog.mapped.count), Paris \(fullParis.mapped.count).")
print("CPU metadata load \(String(format:"%.3f",loadSeconds))s; 2000 queries \(String(format:"%.3f",querySeconds))s; maximum local candidates \(largestCandidateCount). No city geometry or GPU dispatch.")
for failure in failures {print("FAIL: \(failure)")}
print(failures.isEmpty ? "PASS":"FAIL \(failures.count)")
if !failures.isEmpty {exit(1)}
