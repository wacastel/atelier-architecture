import Foundation
import simd

var checks = 0
func expect(_ value: Bool, _ message: String) {
    checks += 1
    precondition(value,message)
}
func project(_ p: SIMD3<Float>, pose: CameraPose, viewport: SIMD2<Float>) -> SIMD2<Float> {
    let f=simd_normalize(pose.target-pose.position)
    var r=simd_cross(f,SIMD3<Float>(0,1,0))
    if simd_length_squared(r) < 0.0001 { r=SIMD3(1,0,0) }
    r=simd_normalize(r)
    let u=simd_cross(r,f)
    let d=p-pose.position,depth=simd_dot(d,f),t=tan(pose.fov * .pi/360)
    return SIMD2((simd_dot(d,r)/(depth*t*viewport.x/viewport.y)+1)*viewport.x/2,
                 (1-simd_dot(d,u)/(depth*t))*viewport.y/2)
}
for rate in [3, 4, 15, 30, 60, 120] {
    for speed in ManualCityNavigation.flySpeeds {
        for boost in [false,true] {
            var position=SIMD3<Float>.zero
            for _ in 0..<rate {
                position += ManualCityNavigation.displacement(direction:SIMD3(1,0,-1),speed:speed,
                    seconds:ManualCityNavigation.frameSeconds(1/Double(rate)),boosted:boost)
            }
            expect(abs(simd_length(position)-speed*(boost ? 3:1)) < 0.015,"Flight distance depends on rendering FPS")
        }
    }
}
expect(ManualCityNavigation.frameSeconds(100)==0.5,"Suspended app must not teleport across100seconds")
expect(ManualCityNavigation.frameSeconds(.nan)==0,"Invalid frame clock")
expect(ManualCityNavigation.displacement(direction:.zero,speed:80,seconds:0.2,boosted:false) == .zero,"Stationary input moved")
expect(ManualCityNavigation.steppedSpeed(80,direction:1)==180,"Faster flight preset")
expect(ManualCityNavigation.steppedSpeed(80,direction:-1)==30,"Slower flight preset")
expect(ManualCityNavigation.steppedSpeed(800,direction:1)==800,"Flight maximum")
expect(ManualCityNavigation.steppedSpeed(8,direction:-1)==8,"Flight minimum")

expect(ManualCityNavigation.defaultFlySpeed == 400, "Default flight must cross city distances promptly")
expect(ManualCityNavigation.nearestSpeed(63) == 80, "Arbitrary speed must resolve to a dropdown choice")
expect(ManualCityNavigation.nearestSpeed(.nan) == 400, "Invalid speed fallback")
for speed: Float in [-100,0,8,22,63,123,201,399,900] {
    expect(ManualCityNavigation.flySpeeds.contains(ManualCityNavigation.nearestSpeed(speed)), "Non-preset flight speed escaped")
}
expect(ManualCityNavigation.verticalDirection(keys:[12]) == 1, "Q must ascend")
expect(ManualCityNavigation.verticalDirection(keys:[14]) == -1, "E must descend")
expect(ManualCityNavigation.verticalDirection(keys:[12,14]) == 0, "Opposing vertical keys must cancel")
// Keyboard W/S use the same compass direction and full speed at every pitch.
// Exact vertical views reuse the last nonvertical compass direction.
for yaw: Float in [-3,-1.2,0,0.7,2.8] {
    let compass=SIMD3<Float>(sin(yaw),0,-cos(yaw))
    for pitch: Float in [-89.99,-70,-20,0,20,70,89.99] {
        let angle=pitch * .pi/180
        let forward=compass*cos(angle)+SIMD3(0,sin(angle),0)
        for scale: Float in [0.00000001,1,10000,1e30] {
            let flat=ManualCityNavigation.horizontalHeading(forward:forward*scale,fallback:SIMD3(1,0,0))
            expect(flat.y==0 && simd_distance(flat,compass)<0.000001,"Camera pitch changes keyboard travel direction or altitude")
            let movement=ManualCityNavigation.displacement(direction:flat,speed:400,seconds:0.1,boosted:false)
            let reverse=ManualCityNavigation.displacement(direction:-flat,speed:400,seconds:0.1,boosted:false)
            expect(movement.y==0 && abs(simd_length(movement)-40)<0.00001,"Looking up/down reduces forward travel speed")
            expect(simd_length(movement+reverse)<0.00001,"Forward and backward headings fail to cancel")
        }
    }
    for forward in [SIMD3<Float>(0,1,0),SIMD3(0,-1,0),SIMD3(1e-8,1,-1e-8),.zero,SIMD3(.nan,0,0)] {
        let flat=ManualCityNavigation.horizontalHeading(forward:forward,fallback:compass)
        expect(simd_distance(flat,compass)<0.000001 && flat.y==0,"Vertical/invalid heading loses the stored compass direction")
        let right=simd_cross(flat,SIMD3<Float>(0,1,0))
        expect(abs(simd_length(right)-1)<0.000001,"Exact vertical camera produces undefined strafe direction")
    }
}
expect(ManualCityNavigation.horizontalHeading(forward:SIMD3(0,-1,0),fallback:SIMD3(.nan,0,0))==SIMD3(0,0,-1),"Invalid fallback must resolve to stable north")
let extremeFlat=ManualCityNavigation.horizontalHeading(forward:SIMD3(Float.greatestFiniteMagnitude,Float.greatestFiniteMagnitude,-Float.greatestFiniteMagnitude))
expect(extremeFlat.x.isFinite && extremeFlat.y==0 && abs(simd_length(extremeFlat)-1)<0.000001,"Large finite heading overflows normalization")
let subnormal=Float.leastNonzeroMagnitude*1024
let tinyFlat=ManualCityNavigation.horizontalHeading(forward:SIMD3(subnormal,0,-subnormal))
expect(abs(tinyFlat.x-Float(1/sqrt(2.0)))<0.000001,"Very small horizontal vector loses its compass direction")

for fov: Float in [1.5,9,50,100] {
    let normal=CameraPose(position:SIMD3(300,200,-100),target:SIMD3(100,90,-900),fov:fov)
    let down=ManualCityNavigation.topDown(pose:normal,roof:{_,_ in 10})!
    expect(down.position==normal.position && down.target==SIMD3(300,10,-100) && down.fov==fov,"Normal straight-down command changes horizontal location, altitude or lens unnecessarily")
    expect(down.target.x==down.position.x && down.target.z==down.position.z && down.target.y<down.position.y,"Normal camera is not exactly vertical")
    let again=ManualCityNavigation.topDown(pose:down,roof:{_,_ in 10})!
    expect(again.position==down.position && again.target==down.target && again.fov==down.fov,"Repeated top-down command moves the camera")
    let focused=ManualCityNavigation.topDown(pose:normal,center:SIMD3(40,205,20),roof:{_,_ in 528})!
    expect(focused.target==SIMD3(40,205,20) && focused.position==SIMD3(40,568,20),"Focused top-down does not center the object above its highest surface")
    expect(focused.fov==fov && down.position.y<ManualCityNavigation.minimumMapAltitude,"Normal top-down incorrectly adopts fixed Map-mode altitude/lens")
}
let neighboringRoof=ManualCityNavigation.topDown(pose:CameraPose(position:SIMD3(0,30,0),target:SIMD3(0,0,-20)),roof:{x,z in x>10 && z>10 ? 400:5})!
expect(neighboringRoof.position.y==440 && neighboringRoof.target==SIMD3(0,5,0),"Straight-down clearance ignores a nearby roof")
expect(ManualCityNavigation.topDown(pose:CameraPose(position:SIMD3(0,5,0),target:.zero),roof:{_,_ in -5.7})!.position.y>34,"Top-down over water lacks a positive viewing distance")
for invalid: Float in [.nan,.infinity,-.infinity] {
    expect(ManualCityNavigation.topDown(pose:CameraPose(position:SIMD3(invalid,30,0),target:.zero),roof:{_,_ in 0})==nil,"Nonfinite top-down camera accepted")
    expect(ManualCityNavigation.topDown(pose:CameraPose(position:SIMD3(0,30,0),target:.zero),center:SIMD3(0,invalid,0),roof:{_,_ in 0})==nil,"Nonfinite top-down focus accepted")
    expect(ManualCityNavigation.topDown(pose:CameraPose(position:SIMD3(0,30,0),target:.zero),roof:{_,_ in invalid})==nil,"Nonfinite top-down surface accepted")
}
expect(ManualCityNavigation.topDown(pose:CameraPose(position:SIMD3(0,30,0),target:.zero,fov:180),roof:{_,_ in 0})==nil,"Degenerate top-down lens accepted")
for camera in [SIMD2<Float>(0,0),SIMD2(-3999,-11499),SIMD2(5999,10999)] {
    for request in [SIMD2<Float>(42,-17),SIMD2(-20_000,40_000),SIMD2(400,-700)] {
        let delta=ManualCityNavigation.mapTranslation(camera:camera,requested:request)
        let actual=camera+delta
        expect(actual.x >= -4000 && actual.x <= 6000 && actual.y >= -11500 && actual.y <= 11000, "Map drag left modeled city")
        if camera == .zero && abs(request.x) < 1000 && abs(request.y) < 1000 {
            expect(delta == request, "Map drag did not preserve exact incremental displacement")
        }
    }
}
expect(ManualCityNavigation.mapTranslation(camera:.zero,requested:SIMD2(.nan,0)) == .zero, "Nonfinite map delta propagated")

for camera in [SIMD2<Float>(7000,12000),SIMD2(-5000,-12500)] {
    for request in [SIMD2<Float>(10,10),SIMD2(-10,-10),SIMD2(500,-2000)] {
        let actual=ManualCityNavigation.mapTranslation(camera:camera,requested:request)
        for axis in 0..<2 {
            expect(actual[axis]*request[axis] >= 0, "Outside-city drag reversed direction")
            expect(abs(actual[axis]) <= abs(request[axis]), "Outside-city drag snapped farther than requested")
        }
    }
}

let poses=[CameraPose(position:SIMD3(0,100,150),target:.zero,fov:60),
           CameraPose(position:SIMD3(4500,500,9800),target:SIMD3(4400,0,9400),fov:66),
           CameraPose(position:SIMD3(-20,10,25),target:.zero,fov:52)]
for pose in poses {
    for viewport in [SIMD2<Float>(960,680),SIMD2(1440,960),SIMD2(1000,1600)] {
        for world in [pose.target,pose.target+SIMD3(5,0,5),pose.target-SIMD3(5,0,5)] {
            let before=project(world,pose:pose,viewport:viewport)
            for pixels in [SIMD2<Float>(32,18),SIMD2(-22,31),SIMD2(0,-14)] {
                let after=before+pixels
                guard let delta=ManualCityNavigation.pan(pose:pose,from:before,to:after,viewport:viewport) else { fatalError("Ground pan failed") }
                let moved=CameraPose(position:pose.position+delta,target:pose.target+delta,fov:pose.fov)
                expect(simd_distance(project(world,pose:moved,viewport:viewport),after)<0.1,"Grabbed point slipped under cursor")
                expect(delta.y==0,"Ground pan changed camera altitude")
                expect(simd_distance(moved.target-moved.position,pose.target-pose.position)<0.01,"Pan changed camera orientation")
            }
        }
    }
}
for target in [SIMD3<Float>(0,100,-100),SIMD3(0,200,-100),SIMD3(0,0,0)] {
    let sky=CameraPose(position:SIMD3(0,100,0),target:target,fov:60)
    let delta=ManualCityNavigation.pan(pose:sky,from:SIMD2(500,100),to:SIMD2(520,110),viewport:SIMD2(1000,800))!
    expect(delta.x.isFinite && delta.z.isFinite && delta.y==0 && simd_length(delta)<2000,"Sky/vertical pan became unbounded")
}
expect(ManualCityNavigation.pan(pose:poses[0],from:SIMD2(.nan,0),to:.zero,viewport:SIMD2(100,100))==nil,"Invalid input entered pan")
expect(ManualCityNavigation.pan(pose:poses[0],from:.zero,to:.zero,viewport:.zero)==nil,"Zero viewport entered pan")

let overview=ManualCityNavigation.overview(point:.zero,heading:SIMD3(0,0,-1),roof:{ _,z in z>150 ? 510:0 })!
expect(overview.position.y>=550,"Map destination entered a neighboring tower")
expect(overview.target.x==0 && overview.target.z==0,"Map click target moved")
let water=ManualCityNavigation.overview(point:SIMD2(5100,9100),heading:.zero,roof:{_,_ in -5.7})!
expect(water.position.y>100 && water.position.y.isFinite,"Lake destination was unsafe")
expect(ManualCityNavigation.overview(point:SIMD2(0,20000),heading:.zero,roof:{_,_ in 0})==nil,"Outside map click accepted")
expect(ManualCityNavigation.overview(point:.zero,heading:.zero,roof:{_,_ in .nan})==nil,"Invalid map height accepted")
// Independently project map landmarks into screen coordinates. These checks
// establish north-up orientation and actual grab behavior, not just constants.
for span: Float in [50,1800,24000] {
    let north = ManualCityNavigation.mapKeyboardPan(keys:[13],span:span,seconds:0.2)
    let east = ManualCityNavigation.mapKeyboardPan(keys:[2],span:span,seconds:0.2)
    let diagonal = ManualCityNavigation.mapKeyboardPan(keys:[13,2],span:span,seconds:0.2)
    expect(north.x == 0 && north.y < 0 && east.x > 0 && east.y == 0,"Map WASD did not follow fixed compass directions")
    expect(abs(simd_length(diagonal)-simd_length(north)) < 0.001,"Map diagonal keys move faster than a cardinal key")
    for shift: UInt16 in [56,60] {
        let boosted=ManualCityNavigation.mapKeyboardPan(keys:[13,shift],span:span,seconds:0.2)
        expect(simd_distance(boosted,north*3)<0.001,"Either Shift key must triple Map pan speed")
    }
    let frames=(0..<5).reduce(SIMD2<Float>.zero) { sum,_ in
        sum+ManualCityNavigation.mapKeyboardPan(keys:[13],span:span,seconds:0.04)
    }
    expect(simd_distance(frames,north)<0.001,"Map key travel changes with frame partitioning")
    for keys: Set<UInt16> in [[],[13,1],[0,2],[13,1,0,2],[12],[14],[56]] {
        expect(ManualCityNavigation.mapKeyboardPan(keys:keys,span:span,seconds:0.2) == .zero,"Opposing keys, altitude keys or Shift alone move fixed Map")
    }
    for viewport in [SIMD2<Float>(1000,800),SIMD2(800,1400)] {
        let start=ManualCityNavigation.mapPose(center:.zero,span:span)!
        let moved=ManualCityNavigation.mapPose(center:north,span:span)!
        let screen=project(start.target,pose:moved,viewport:viewport)
        expect(abs(screen.x-viewport.x/2)<0.01 && screen.y>viewport.y/2,"North key moved map content in the wrong screen direction")
        let fraction=(screen.y-viewport.y/2)/viewport.y
        expect(abs(fraction-0.07)<0.00001,"Map key pan is not consistent with visible coverage at different zoom/aspect")
    }
}
for invalid: Float in [.nan,.infinity,-.infinity,0,-1] {
    expect(ManualCityNavigation.mapKeyboardPan(keys:[13],span:invalid,seconds:0.2) == .zero,"Invalid Map span produced keyboard displacement")
    expect(ManualCityNavigation.mapKeyboardPan(keys:[13],span:1800,seconds:invalid) == .zero,"Invalid Map timestep produced keyboard displacement")
}
expect(ManualCityNavigation.mapKeyboardPan(keys:[13],span:.greatestFiniteMagnitude,seconds:.greatestFiniteMagnitude)
       == ManualCityNavigation.mapKeyboardPan(keys:[13],span:24000,seconds:0.5),"Extreme finite Map input escaped span/timestep bounds")

for center in [SIMD2<Float>(0,0),SIMD2(3313,9915),SIMD2(-13569.5,-1135.8)] {
    for span: Float in [50,100,750,1000,6000,24000] {
        let pose=ManualCityNavigation.mapPose(center:center,span:span)!
        expect(pose.position.x==center.x && pose.position.z==center.y && pose.target==SIMD3(center.x,0,center.y),"Map camera drifted from its exact center")
        expect(pose.position.y>=650 && pose.fov>0 && pose.fov<=60,"Map lens/altitude could enter existing city roofs")
        let actualSpan=2*Double(pose.position.y)*tan(Double(pose.fov)*Double.pi/360)
        expect(abs(actualSpan-Double(span))<Double(span)*0.000001,"Map's ground coverage does not match span")
        for viewport in [SIMD2<Float>(960,680),SIMD2(1800,800),SIMD2(800,1600)] {
            let north=project(pose.target+SIMD3(0,0,-span/4),pose:pose,viewport:viewport)
            let east=project(pose.target+SIMD3(span*viewport.x/viewport.y/4,0,0),pose:pose,viewport:viewport)
            expect(simd_distance(north,SIMD2(viewport.x/2,viewport.y/4))<0.04,"Map is not north-up")
            expect(simd_distance(east,SIMD2(viewport.x*0.75,viewport.y/2))<0.04,"Map east is not screen-right")
            for pixels in [SIMD2<Float>(32,18),SIMD2(-22,31)] {
                let movement=ManualCityNavigation.mapPan(delta:pixels,viewport:viewport,span:span)!
                let moved=ManualCityNavigation.mapPose(center:center+movement,span:span)!
                expect(simd_distance(project(pose.target,pose:moved,viewport:viewport),viewport/2+pixels)<0.04,"Top-down grabbed ground point slipped")
                expect(moved.position.y==pose.position.y && moved.fov==pose.fov,"Map pan changed altitude/lens")
                expect(simd_length(movement+ManualCityNavigation.mapPan(delta:-pixels,viewport:viewport,span:span)!)<0.001,"Map pan is not invertible")
            }
        }
    }
}
let transition: Float=2*650*tan(.pi/6)
let below=ManualCityNavigation.mapPose(center:.zero,span:transition-0.01)!
let above=ManualCityNavigation.mapPose(center:.zero,span:transition+0.01)!
expect(abs(above.position.y-below.position.y)<0.02 && abs(above.fov-below.fov)<0.002,"Map altitude/lens transition jumps")
for span: Float in [1,50,24000,Float.greatestFiniteMagnitude] {
    let pose=ManualCityNavigation.mapPose(center:.zero,span:span)!
    let coverage=2*pose.position.y*tan(pose.fov * .pi/360)
    expect(abs(coverage-min(24000,max(50,span)))<0.01,"Map coverage clamp failed")
}
for count in [1,3,30,120] {
    var total=SIMD2<Float>.zero
    for _ in 0..<count {
        total += ManualCityNavigation.mapPan(delta:SIMD2(130,-210)/Float(count),viewport:SIMD2(1440,960),span:6000)!
    }
    expect(simd_distance(total,SIMD2(-812.5,1312.5))<0.01,"Map pan depends on event subdivision")
}

// A physical pinch is a multiplicative magnification. Its inverse and event
// subdivision must agree in both optical FOV and map ground coverage.
for initial: Float in [5,50,80] {
    for delta in [0.0,0.25,-0.2] {
        let result=ManualCityNavigation.pinchFOV(initial,magnification:delta)!
        let actualRatio=tan(Double(initial)*Double.pi/360)/tan(Double(result)*Double.pi/360)
        expect(abs(actualRatio-(1+delta))<0.000001,"Pinch used linear FOV degrees instead of optical magnification")
        let reversed=ManualCityNavigation.pinchFOV(result,magnification:1/(1+delta)-1)!
        expect(abs(reversed-initial)<0.00002,"Optical pinch inverse failed")
    }
}
for count in [1,3,30,120] {
    let delta=pow(1.8,1/Double(count))-1
    var fov: Float=60,span: Float=6000,logScale: Float=0
    for _ in 0..<count {
        fov=ManualCityNavigation.pinchFOV(fov,magnification:delta)!
        span=ManualCityNavigation.pinchMapSpan(span,magnification:delta)!
        logScale += ManualCityNavigation.pinchLogScale(magnification:delta)!
    }
    let expectedFOV=Float(atan(tan(Double.pi/6)/1.8)*360/Double.pi)
    expect(abs(fov-expectedFOV)<0.0001,"Optical pinch depends on event subdivision")
    expect(abs(span-Float(6000/1.8))<0.05,"Map pinch depends on event subdivision")
    expect(abs(logScale-Float(log(1.8)))<0.000002,"Focused dolly log depends on event subdivision")
}
for delta in [0.25,-0.2] {
    let zoom=ManualCityNavigation.pinchMapSpan(6000,magnification:delta)!
    expect(abs(zoom-Float(6000/(1+delta)))<0.001,"Map pinch factor is reversed")
    expect(abs(ManualCityNavigation.pinchMapSpan(zoom,magnification:1/(1+delta)-1)!-6000)<0.001,"Map pinch inverse failed")
}
expect(ManualCityNavigation.pinchFOV(1.5,magnification:1)==1.5,"Optical minimum escaped")
expect(ManualCityNavigation.pinchFOV(100,magnification:-0.5)==100,"Optical maximum escaped")
expect(ManualCityNavigation.pinchMapSpan(50,magnification:1)==50,"Map minimum escaped")
expect(ManualCityNavigation.pinchMapSpan(24000,magnification:-0.5)==24000,"Map maximum escaped")
expect(abs(ManualCityNavigation.pinchLogScale(magnification:Double.greatestFiniteMagnitude)!-Float(log(2.0)))<0.000001,"Pathological positive pinch is unbounded")
expect(abs(ManualCityNavigation.pinchLogScale(magnification:-0.999999999)!+Float(log(2.0)))<0.000001,"Pathological negative pinch is unbounded")
for value in [Double.nan,Double.infinity,-Double.infinity,-1,-2] {
    expect(ManualCityNavigation.pinchLogScale(magnification:value)==nil,"Invalid pinch factor accepted")
    expect(ManualCityNavigation.pinchFOV(60,magnification:value)==nil,"Invalid pinch entered FOV")
    expect(ManualCityNavigation.pinchMapSpan(6000,magnification:value)==nil,"Invalid pinch entered map coverage")
}
for value: Float in [.nan,.infinity,-.infinity,0,-1] {
    expect(ManualCityNavigation.mapPose(center:.zero,span:value)==nil,"Invalid map span accepted")
    expect(ManualCityNavigation.pinchMapSpan(value,magnification:0.2)==nil,"Invalid map span entered pinch")
    expect(ManualCityNavigation.pinchFOV(value,magnification:0.2)==nil,"Invalid optical FOV accepted")
}
expect(ManualCityNavigation.pinchFOV(180,magnification:0.2)==nil,"Degenerate lens accepted")
expect(ManualCityNavigation.mapPose(center:SIMD2(.nan,0),span:1000)==nil,"Nonfinite map center accepted")
for viewport in [SIMD2<Float>.zero,SIMD2(-1,100),SIMD2(100,.nan)] {
    expect(ManualCityNavigation.mapPan(delta:SIMD2(1,1),viewport:viewport,span:1000)==nil,"Invalid map viewport accepted")
}
expect(ManualCityNavigation.mapPan(delta:SIMD2(.infinity,0),viewport:SIMD2(100,100),span:1000)==nil,"Nonfinite map drag accepted")

// Sample an enclosing sphere, rather than only the center/radius formula, to
// establish actual projection margins in portrait and landscape viewports.
let landmarkTarget=SIMD3<Float>(1250,220,-900)
for aspect: Float in [0.5,1,1.5,2.4] {
    for radius: Float in [5,100,350] {
        for heading in [SIMD3<Float>(0,0,-1),SIMD3(1,0,1),.zero] {
            let pose=ManualCityNavigation.landmarkOverview(target:landmarkTarget,radius:radius,heading:heading,aspect:aspect,roof:{_,_ in 0})!
            let viewport=SIMD2<Float>(1000*aspect,1000)
            expect(pose.target==landmarkTarget && pose.fov==50,"Landmark overview did not preserve exact center/reset lens")
            expect(simd_distance(project(landmarkTarget,pose:pose,viewport:viewport),viewport/2)<0.01,"Selected landmark is not centered")
            expect(pose.position.y>landmarkTarget.y,"Landmark overview is not elevated")
            for latitude in -4...4 {
                for longitude in 0..<16 {
                    let phi=Float(latitude)*Float.pi/8,theta=Float(longitude)*Float.pi/8
                    let point=landmarkTarget+radius*SIMD3(cos(phi)*cos(theta),sin(phi),cos(phi)*sin(theta))
                    let pixel=project(point,pose:pose,viewport:viewport)/viewport
                    expect(pixel.x>=0.075 && pixel.x<=0.925 && pixel.y>=0.075 && pixel.y<=0.925,"Enclosing landmark sphere escapes projection margin")
                }
            }
        }
    }
}
var roofProbes=[SIMD2<Float>]()
let lifted=ManualCityNavigation.landmarkOverview(target:landmarkTarget,radius:100,heading:.zero,roof:{ x,z in
    roofProbes.append(SIMD2(x,z)); return roofProbes.count==5 ? 810:0
})!
expect(roofProbes.count==5 && lifted.position.y>=850,"Landmark overview missed neighboring roof clearance")
expect(lifted.target==landmarkTarget,"Roof clearance changed the selected target")
expect(Set(roofProbes.map{ "\($0.x),\($0.y)" }).count==5,"Roof clearance repeated one probe")
for invalid: Float in [.nan,.infinity,0,-1] {
    expect(ManualCityNavigation.landmarkOverview(target:landmarkTarget,radius:invalid,heading:.zero,roof:{_,_ in 0})==nil,"Invalid landmark radius accepted")
    expect(ManualCityNavigation.landmarkOverview(target:landmarkTarget,radius:100,heading:.zero,aspect:invalid,roof:{_,_ in 0})==nil,"Invalid landmark aspect accepted")
}
expect(ManualCityNavigation.landmarkOverview(target:SIMD3(.nan,0,0),radius:100,heading:.zero,roof:{_,_ in 0})==nil,"Invalid landmark target accepted")
expect(ManualCityNavigation.landmarkOverview(target:landmarkTarget,radius:100,heading:SIMD3(0,.infinity,0),roof:{_,_ in 0})==nil,"Invalid landmark heading accepted")
expect(ManualCityNavigation.landmarkOverview(target:landmarkTarget,radius:100,heading:.zero,roof:{_,_ in .nan})==nil,"Invalid roof accepted")
let report:[String:Any]=["passed":true,"checks":checks,"scope":"CPU pitch-independent horizontal heading and stable vertical fallback, normal straight-down focus/roof clearance/unchanged lens, north-up map projection, cardinal span-scaled WASD panning with normalized diagonals and Shift boost, pan and optical/map pinch inversion, gesture subdivision and invalid-input limits; landmark sphere framing/roof clearance; existing ground pan and equal flight distance at 3–120 FPS. Native event dispatch is a separate validation."]
print(String(data:try!JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
