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
let report:[String:Any]=["passed":true,"checks":checks,"scope":"CPU north-up map projection, pan and optical/map pinch inversion, gesture subdivision and invalid-input limits; landmark sphere framing/roof clearance; existing ground pan and equal flight distance at 3–120 FPS. Native event dispatch is a separate validation."]
print(String(data:try!JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
