#!/usr/bin/env swift
// Actual production Metal haze/background checks. Negative control restores both
// legacy camera lookups while keeping the environment function untouched.
import Foundation
import Metal
import simd
private struct Vertex { var p,n:SIMD4<Float> }
private struct Material { var c,p:SIMD4<Float> }
private struct Light { var p,d,c,r:SIMD4<Float> }
private struct Uniforms { var origin,right,up,forward,sunDirection,sunColor:SIMD4<Float>;var viewport:SIMD4<UInt32>;var settings:SIMD4<Float>; var animation:SIMD4<Float> = .zero }
func require(_ condition:Bool,_ message:String) { if !condition { fputs("FAIL: \(message)\n",stderr);exit(1) } }
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
let source=try String(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal"),encoding:.utf8)
let replacement="float3 scattering = IsNight ? skyRadiance(primaryDirection, u, false)\n                                    : daylightAerialPerspective(primaryDirection, u);"
require(source.components(separatedBy:replacement).count==2,"Atmosphere observation point changed")
let backgroundReplacement="""
float3 background = (!IsNight && branch == 0 && interaction == 0)
                ? daylightCameraBackground(path.direction, u)
                : skyRadiance(path.direction, u, bounce == 0);
            radiance += throughput * background;
"""
require(source.components(separatedBy:backgroundReplacement).count==2,"Primary-background observation point changed")
let legacy=CommandLine.arguments.count>1 ? try String(contentsOfFile:CommandLine.arguments[1],encoding:.utf8):source.replacingOccurrences(of:replacement,with:"float3 scattering = skyRadiance(primaryDirection, u, false);").replacingOccurrences(of:backgroundReplacement,with:"radiance += throughput * skyRadiance(path.direction, u, bounce == 0);")
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {fatalError("Metal required")}
let compile=MTLCompileOptions();compile.languageVersion = .version3_1
func extra(_ corrected:Bool)->String { """

kernel void checkAtmosphere(device float4 *out [[buffer(0)]],constant FrameUniforms &u [[buffer(1)]],uint tid [[thread_position_in_grid]]) {
    float azimuth=float(tid/2)*6.28318530718f/16.0f;
    float y=(tid&1) ? 0.000001f:-0.000001f;
    float3 d=normalize(float3(cos(azimuth),y,sin(azimuth)));
    out[tid*2]=float4(\(corrected ? "daylightAerialPerspective(d,u)":"skyRadiance(d,u,false)"),1);
    out[tid*2+1]=float4(skyRadiance(d,u,false),1);
}
kernel void checkCameraBackground(device float4 *out [[buffer(0)]],constant FrameUniforms &u [[buffer(1)]],uint tid [[thread_position_in_grid]]) {
    float azimuth=float(tid/2)*6.28318530718f/16.0f;
    float y=(tid&1) ? 0.000001f:-0.000001f;
    float3 d=normalize(float3(cos(azimuth),y,sin(azimuth)));
    out[tid*2]=float4(\(corrected ? "daylightCameraBackground(d,u)":"skyRadiance(d,u,true)"),1);
    float3 sun=normalize(u.sunDirection.xyz);
    out[tid*2+1]=float4(\(corrected ? "daylightCameraBackground(sun,u)-daylightAerialPerspective(sun,u)*0.8f":"skyRadiance(sun,u,true)-skyRadiance(sun,u,false)"),1);
}
""" }
let libraries=try [device.makeLibrary(source:source+extra(true),options:compile),device.makeLibrary(source:legacy+extra(false),options:compile)]
func buffer<T>(_ values:[T])->MTLBuffer {values.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!}}
func commit(_ command:MTLCommandBuffer)throws {command.commit();command.waitUntilCompleted();if let error=command.error {throw error}}
private var u=Uniforms(origin:SIMD4(0,0,0,1),right:SIMD4(0.3,0,0,0),up:SIMD4(0,0.2,0,1),forward:SIMD4(0,0,-1,0),sunDirection:SIMD4(-0.4,0.8,1,1),sunColor:SIMD4(3.5,3.2,2.7,0),viewport:SIMD4(32,32,0,0),settings:SIMD4(1,3,0.00465,0.85))
func atmosphere(_ library:MTLLibrary,night:Bool,kernel:String="checkAtmosphere")throws->[SIMD4<Float>] {
    let out=buffer([SIMD4<Float>](repeating:.zero,count:64)),pipeline=try device.makeComputePipelineState(function:library.makeFunction(name:kernel)!)
    var frame=u;frame.sunColor.w=night ? 1:0
    let command=queue.makeCommandBuffer()!,encoder=command.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(pipeline);encoder.setBuffer(out,offset:0,index:0);encoder.setBytes(&frame,length:144,index:1)
    encoder.dispatchThreads(MTLSize(width:32,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:32,height:1,depth:1));encoder.endEncoding();try commit(command)
    return Array(UnsafeBufferPointer(start:out.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:64))
}
let sky=try atmosphere(libraries[0],night:false),oldSky=try atmosphere(libraries[1],night:false)
var correctedJump:Float=0,legacyJump:Float=0
for pair in 0..<16 {for c in 0..<3 {
    correctedJump=max(correctedJump,abs(sky[pair*4][c]-sky[pair*4+2][c]))
    legacyJump=max(legacyJump,abs(oldSky[pair*4][c]-oldSky[pair*4+2][c]))
}}
require(correctedJump<0.002,"Daylight atmospheric radiance is discontinuous at the horizon")
require(legacyJump>0.25,"Legacy negative control did not expose the horizon discontinuity")
for night in [false,true] {
    let a=try atmosphere(libraries[0],night:night),b=try atmosphere(libraries[1],night:night)
    for i in stride(from:1,to:64,by:2) {require(a[i]==b[i],"Ground/sky environment lighting changed")}
}
let cameraSky=try atmosphere(libraries[0],night:false,kernel:"checkCameraBackground"),oldCameraSky=try atmosphere(libraries[1],night:false,kernel:"checkCameraBackground")
var backgroundJump:Float=0,oldBackgroundJump:Float=0
for pair in 0..<16 {for c in 0..<3 {
    backgroundJump=max(backgroundJump,abs(cameraSky[pair*4][c]-cameraSky[pair*4+2][c]))
    oldBackgroundJump=max(oldBackgroundJump,abs(oldCameraSky[pair*4][c]-oldCameraSky[pair*4+2][c]))
    require(abs(cameraSky[pair*4][c]-sky[pair*4][c]*0.8)<0.00001,"Primary background does not match the surface-haze asymptote")
    require(abs(cameraSky[pair*4+1][c]-oldCameraSky[pair*4+1][c])<0.00001,"Visible solar-disc radiance changed")
}}
require(backgroundJump<0.002 && oldBackgroundJump>0.25,"Primary background failed the horizon continuity/negative-control criterion")

// The distant plane crosses the viewing horizon, so actual path tracing must
// exercise a substantial haze weight on both upper and lower camera rays.
private let vertices=[Vertex(p:SIMD4(-3000,-3000,-1200,1),n:SIMD4(0,0,1,0)),Vertex(p:SIMD4(3000,-3000,-1200,1),n:SIMD4(0,0,1,0)),Vertex(p:SIMD4(3000,3000,-1200,1),n:SIMD4(0,0,1,0)),Vertex(p:SIMD4(-3000,-3000,-1200,1),n:SIMD4(0,0,1,0)),Vertex(p:SIMD4(3000,3000,-1200,1),n:SIMD4(0,0,1,0)),Vertex(p:SIMD4(-3000,3000,-1200,1),n:SIMD4(0,0,1,0))]
let vb=buffer(vertices),ids=buffer([UInt32(0),0]),mb=buffer([Material(c:SIMD4(0.4,0.25,0.1,0.3),p:SIMD4(0.6,0,0,0))])
let lights=buffer([Light(p:SIMD4(0,100,-1100,0.2),d:SIMD4(0,0,0,-1),c:SIMD4(1,0.4,0.2,10000),r:SIMD4(600,0,0,0))])
let dynamicLights=buffer([Light(p:SIMD4(100,0,-1150,0.2),d:SIMD4(0,0,0,-1),c:SIMD4(0.3,0.6,1,5000),r:SIMD4(600,0,0,0))])
let geometry=MTLAccelerationStructureTriangleGeometryDescriptor();geometry.vertexBuffer=vb;geometry.vertexStride=32;geometry.vertexFormat = .float3;geometry.triangleCount=2;geometry.opaque=true
let descriptor=MTLPrimitiveAccelerationStructureDescriptor();descriptor.geometryDescriptors=[geometry]
let sizes=device.accelerationStructureSizes(descriptor:descriptor),acceleration=device.makeAccelerationStructure(size:sizes.accelerationStructureSize)!,scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate)!
let command=queue.makeCommandBuffer()!,builder=command.makeAccelerationStructureCommandEncoder()!
builder.build(accelerationStructure:acceleration,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0);builder.endEncoding();try commit(command)
var instance=MTLAccelerationStructureInstanceDescriptor();instance.transformationMatrix.columns=(MTLPackedFloat3Make(1,0,0),MTLPackedFloat3Make(0,1,0),MTLPackedFloat3Make(0,0,1),MTLPackedFloat3Make(0,0,0));instance.options = .opaque;instance.mask=255
let topDescriptor=MTLInstanceAccelerationStructureDescriptor();topDescriptor.instancedAccelerationStructures=[acceleration];topDescriptor.instanceDescriptorBuffer=buffer([instance]);topDescriptor.instanceCount=1
let topSizes=device.accelerationStructureSizes(descriptor:topDescriptor),top=device.makeAccelerationStructure(size:topSizes.accelerationStructureSize)!,topScratch=device.makeBuffer(length:topSizes.buildScratchBufferSize,options:.storageModePrivate)!
let topCommand=queue.makeCommandBuffer()!,topBuilder=topCommand.makeAccelerationStructureCommandEncoder()!
topBuilder.build(accelerationStructure:top,descriptor:topDescriptor,scratchBuffer:topScratch,scratchBufferOffset:0);topBuilder.endEncoding();try commit(topCommand)
// Enabled single-cell lists exercise indexed kernels as well as their linear variants.
var grid=[SIMD4<Float>(-5000,-5000,-5000,10000)]
let gridBuffer=device.makeBuffer(length:48,options:.storageModeShared)!
grid.withUnsafeBytes{gridBuffer.contents().copyMemory(from:$0.baseAddress!,byteCount:16)}
[SIMD4<UInt32>(1,1,1,1),SIMD4<UInt32>(1,1,1,0)].withUnsafeBytes{gridBuffer.contents().advanced(by:16).copyMemory(from:$0.baseAddress!,byteCount:32)}
let ranges=buffer([SIMD2<UInt32>(0,1)]),indices=buffer([UInt32(0)])
func trace(_ library:MTLLibrary,kernel:String,spp:Int,nearHorizon:Bool=false,missScene:Bool=false)throws->[SIMD4<Float>] {
    let width=32,height=nearHorizon ? 2:32
    let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:width,height:height,mipmapped:false);d.storageMode = .shared;d.usage=[.shaderRead,.shaderWrite]
    let output=device.makeTexture(descriptor:d)!,pipeline=try device.makeComputePipelineState(function:library.makeFunction(name:kernel)!)
    let night=kernel.contains("Night"),traffic=kernel.contains("Traffic"),indexed=kernel.contains("Indexed")
    let c=queue.makeCommandBuffer()!
    for sample in 0..<spp {
        var frame=u;frame.sunColor.w=night ? 1:0;frame.viewport=SIMD4(UInt32(width),UInt32(height),UInt32(sample),UInt32(sample+411));frame.settings.y=nearHorizon ? 1:3
        if nearHorizon {frame.right=SIMD4(0.05,0,0,0);frame.up=SIMD4(0,0.000002,0,1)}
        if missScene {frame.forward=SIMD4(0,0,1,0)}
        var trafficCounts=SIMD4<UInt32>(2,0,1,0)
        let e=c.makeComputeCommandEncoder()!;e.setComputePipelineState(pipeline);e.setTexture(output,index:0);e.setBytes(&frame,length:144,index:0)
        e.setBuffer(vb,offset:0,index:1);e.setBuffer(ids,offset:0,index:2);e.setBuffer(mb,offset:0,index:3);e.setAccelerationStructure(traffic ? top:acceleration,bufferIndex:4);e.setBuffer(lights,offset:0,index:5)
        if indexed {e.setBuffer(gridBuffer,offset:0,index:6);e.setBuffer(ranges,offset:0,index:7);e.setBuffer(indices,offset:0,index:8)}
        if traffic {e.setBytes(&trafficCounts,length:16,index:9);e.setBuffer(gridBuffer,offset:0,index:10);e.setBuffer(ranges,offset:0,index:11);e.setBuffer(indices,offset:0,index:12);e.setBuffer(dynamicLights,offset:0,index:13)}
        e.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
    };try commit(c)
    var pixels=[SIMD4<Float>](repeating:.zero,count:width*height);output.getBytes(&pixels,bytesPerRow:width*16,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0);return pixels
}
let day=try trace(libraries[0],kernel:"pathTrace",spp:32,nearHorizon:true),oldDay=try trace(libraries[1],kernel:"pathTrace",spp:32,nearHorizon:true)
func rowJump(_ pixels:[SIMD4<Float>])->Float {
    var a=SIMD3<Float>.zero,b=a
    for x in 0..<32 {a += SIMD3(pixels[x].x,pixels[x].y,pixels[x].z)/32;b += SIMD3(pixels[x+32].x,pixels[x+32].y,pixels[x+32].z)/32}
    return max(abs(a.x-b.x),max(abs(a.y-b.y),abs(a.z-b.z)))
}
require(rowJump(day)<0.003 && rowJump(oldDay)>0.05,"Actual distant-plane trace did not distinguish continuous haze from the legacy band")
let misses=try trace(libraries[0],kernel:"pathTrace",spp:32,nearHorizon:true,missScene:true),oldMisses=try trace(libraries[1],kernel:"pathTrace",spp:32,nearHorizon:true,missScene:true)
require(misses.allSatisfy{$0.w==60000},"Missing-ray fixture unexpectedly hit geometry")
require(rowJump(misses)<0.003 && rowJump(oldMisses)>0.25,"Actual daylight miss path retained the ground-hemisphere band")
var nightComponents=0
for name in ["pathTraceNight","pathTraceNightIndexed","pathTraceTrafficNight","pathTraceTrafficNightIndexed"] {for spp in [1,8] {for miss in [false,true] {
    let a=try trace(libraries[0],kernel:name,spp:spp,missScene:miss),b=try trace(libraries[1],kernel:name,spp:spp,missScene:miss)
    require(a==b,"Night path changed in \(name) at \(spp) SPP (miss=\(miss))")
    require(a.allSatisfy{$0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w>1100},"Night fixture failed to exercise finite distant-surface haze")
    if miss {require(a.allSatisfy{$0.w==60000},"Night miss fixture unexpectedly hit geometry")}
    nightComponents += a.count*4
}}}
print("PASS: GPU horizon jump \(correctedJump) versus legacy \(legacyJump); actual traced facade row jump \(rowJump(day)) versus legacy \(rowJump(oldDay))")
print("PASS: primary-background horizon jump \(backgroundJump) versus legacy \(oldBackgroundJump); actual missing-ray row jump \(rowJump(misses)) versus legacy \(rowJump(oldMisses)); haze-asymptote and visible solar-disc checks pass")
print("PASS: environment lighting unchanged; \(nightComponents) RGBA/depth components exactly equal across four night kernels at1/8SPP, including hits/misses and indexed/dynamic local lights")
