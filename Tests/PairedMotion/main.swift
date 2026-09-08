import Foundation
import Metal
import simd

let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
func require(_ value:Bool,_ message:String) { if !value { fputs("FAIL: \(message)\n",stderr);exit(1) } }
guard let device=MTLCreateSystemDefaultDevice() else { fatalError("Metal required") }
var scene=SceneData();scene.name="Paired reconstruction validation"
scene.materials=[SceneMaterial(SIMD3(0.4,0.42,0.44),roughness:0.4)]
let n=SIMD3<Float>(0,1,0)
scene.vertices=[SceneVertex(SIMD3(-200,0,-1500),n),SceneVertex(SIMD3(-200,0,1500),n),SceneVertex(SIMD3(200,0,1500),n),SceneVertex(SIMD3(-200,0,-1500),n),SceneVertex(SIMD3(200,0,1500),n),SceneVertex(SIMD3(200,0,-1500),n)]
scene.materialIndices=[0,0]
scene.trafficLanes=[SceneTrafficLane(id:42,points:[SIMD3(0,0,-1000),SIMD3(0,0,1000)],speedMetresPerSecond:16,spawnFadeMetres:24)]
let fleet=TrafficFleet(lanes:scene.trafficLanes),time=(1000-fleet.vehicles[0].phase)/16
let renderer=try MetalRenderer(scene:scene,device:device)
let camera=CameraPose(position:SIMD3(9,5,12),target:SIMD3(0,1,0),fov:48)
let width=96,height=64

func accumulationBytes()->[SIMD4<Float>] {
    let texture=renderer.accumulation!,bytesPerRow=width*16
    let buffer=device.makeBuffer(length:height*bytesPerRow,options:.storageModeShared)!
    let command=renderer.queue.makeCommandBuffer()!,blit=command.makeBlitCommandEncoder()!
    blit.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:bytesPerRow,destinationBytesPerImage:bytesPerRow*height)
    blit.endEncoding();command.commit();command.waitUntilCompleted()
    require(command.error==nil,"Accumulation readback failed")
    return Array(UnsafeBufferPointer(start:buffer.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:width*height))
}
func displayByte(_ radiance:Float,exposure:Float)->Int {
    let x=max(0,radiance*exposure)
    let filmic=min(1,max(0,(x*(2.51*x+0.03))/(x*(2.43*x+0.59)+0.14)))
    let srgb=filmic<=0.0031308 ? filmic*12.92:1.055*pow(filmic,1/2.4)-0.055
    return Int((srgb*255).rounded())
}
var tested=0,maximumByteError=0
for (index,spp) in [1,8,32].enumerated() {
    let sceneTime=time+Double(index)/24
    renderer.setSceneTime(sceneTime)
    let seed=renderer.frameSeed,updates=renderer.trafficUpdateCount
    let options=RenderOptions(exposure:0.8,lighting:2)
    let pair=try renderer.renderPreviewComparisonOffscreen(pose:camera,options:options,width:width,height:height,samples:spp,resetHistory:index==0)
    require(renderer.sampleCount==UInt32(spp) && renderer.frameSeed==seed+UInt32(spp),"Paired capture added trace samples")
    require(renderer.sceneTime==sceneTime && renderer.trafficUpdateCount==updates+1,"Paired capture advanced the scene clock or updated traffic more than once")
    let hdr=accumulationBytes(),raw=[UInt8](pair.raw)
    require(hdr.contains{$0.x>0.01} && hdr.contains{$0.x<0.005},"Fixture does not exercise varied scene radiance")
    for i in hdr.indices {
        for (channel,value) in [hdr[i].z,hdr[i].y,hdr[i].x].enumerated() {
            let error=abs(Int(raw[i*4+channel])-displayByte(value,exposure:options.exposure))
            maximumByteError=max(maximumByteError,error)
            require(error<=1,"Paired raw output is not the tone/sRGB presentation of the actual traced accumulation")
            tested += 1
        }
        require(raw[i*4+3]==255,"Paired presentation alpha changed")
    }
}
// With reconstruction disabled both render passes must read exactly the same
// accumulation, including moving geometry, and therefore match byte for byte.
var rawOptions=RenderOptions(lighting:2);rawOptions.denoising=false
let updates=renderer.trafficUpdateCount,seed=renderer.frameSeed
let rawPair=try renderer.renderPreviewComparisonOffscreen(pose:camera,options:rawOptions,width:width,height:height,samples:4)
require(rawPair.raw==rawPair.reconstructed,"Two unfiltered presentations of one accumulation differ")
require(renderer.trafficUpdateCount==updates && renderer.frameSeed==seed+4,"Paused paired capture moved traffic or added samples")
// The existing API remains a single normal presentation with the same budget.
let normalSeed=renderer.frameSeed
let normal=try renderer.renderPreviewOffscreen(pose:camera,options:rawOptions,width:width,height:height,samples:4)
require(normal.count==width*height*4 && renderer.frameSeed==normalSeed+4 && renderer.trafficUpdateCount==updates,"Normal preview API behavior changed")
print("PASS: \(tested) actual accumulation channels match paired raw presentation at 1/8/32 SPP (maximum quantization difference \(maximumByteError)); one trace budget and traffic update per frame; paused clock and normal preview preserved")
