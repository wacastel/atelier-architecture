import Foundation
import simd

var checks = 0
func expect(_ value: Bool, _ message: String) {
    checks += 1
    precondition(value,message)
}
func project(_ p: SIMD3<Float>, pose: CameraPose, viewport: SIMD2<Float>) -> SIMD2<Float> {
    let f=simd_normalize(pose.target-pose.position),r=simd_normalize(simd_cross(f,SIMD3<Float>(0,1,0))),u=simd_cross(r,f)
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
let report:[String:Any]=["passed":true,"checks":checks,"scope":"CPU ground-pan reprojection across aspect ratios, sky fallback, safe overhead placement and equal flight distance at3–120FPS; native event dispatch verified separately."]
print(String(data:try!JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
