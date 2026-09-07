#!/usr/bin/env swift
// Compiles the production Metal tracer and tests both GGX math and actual
// ray paths. No app launch, denoising, presentation filter, or scene build.
import Foundation
import Metal
import simd

private struct Vertex { var p,n:SIMD4<Float> }
private struct Material { var c,p:SIMD4<Float> }
private struct Uniforms { var origin,right,up,forward,sunDirection,sunColor:SIMD4<Float>; var viewport:SIMD4<UInt32>; var settings:SIMD4<Float> }
private func require(_ b:Bool,_ message:String) { if !b { fputs("FAIL: \(message)\n",stderr); exit(1) } }
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { fatalError("Metal required") }
// An optional source path supports a negative control without changing the
// checked-in shader or the installed app's resources.
let sourceURL=CommandLine.arguments.count>1 ? URL(fileURLWithPath:CommandLine.arguments[1]) : root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal")
let source=try String(contentsOf:sourceURL,encoding:.utf8)+"""

kernel void checkRegularization(device float4 *out [[buffer(0)]],
                               const device float *roughness [[buffer(1)]],
                               uint tid [[thread_position_in_grid]]) {
    Surface original;
    original.color=float3(0.45f,0.62f,0.81f);original.roughness=roughness[tid/2];
    original.metallic=0.7f;original.emission=0;original.dielectricF0=0.04f;
    original.normal=float3(0,0,1);
    Surface surface=regularizeSurface(original,(tid&1)!=0);
    float3 v=normalize(float3(0.3f,0.1f,1)),l;
    float pdf;
    l=sampleBRDF(surface,v,float2(0.37f,0.68f),0.1f,pdf);
    out[tid*5]=float4(surface.roughness,brdf(surface,float3(0,0,1),float3(0,0,1)));
    out[tid*5+1]=float4(l,pdf);
    out[tid*5+2]=float4(brdf(surface,v,l),dot(surface.normal,l));
    SceneLight light;
    light.positionRadius=float4(l*10,0);light.directionCone=float4(0,0,0,-1);
    light.colorPower=float4(1,1,1,100);light.parameters=float4(100,0,0,0);
    out[tid*5+3]=float4(evaluateLight(light,surface,float3(0),v,surface.normal).value,0);
    float unmodifiedPDF;
    float3 unmodifiedDirection=sampleBRDF(original,v,float2(0.37f,0.68f),0.1f,unmodifiedPDF);
    out[tid*5+4]=float4(unmodifiedDirection,unmodifiedPDF);
}
"""
let compile=MTLCompileOptions();compile.languageVersion = .version3_1
let library=try device.makeLibrary(source:source,options:compile)
let trace=try device.makeComputePipelineState(function:library.makeFunction(name:"pathTrace")!)
let check=try device.makeComputePipelineState(function:library.makeFunction(name:"checkRegularization")!)
// Observe the adjusted surface at the saved branch's first opaque hit. This
// keeps production traversal/state intact but avoids conflating a state reset
// with random-number consumption by the already completed transmitted branch.
let surfaceLine="surface = regularizeSurface(surface, hasNonDeltaScatter && u.origin.w > 0.5f);"
require(source.components(separatedBy:surfaceLine).count==2,"Production regularization observation point must be unique")
let observedSource=source.replacingOccurrences(of:surfaceLine,with:surfaceLine+"\nif (branch==1) { radiance+=throughput*surface.roughness; break; }")
let observedLibrary=try device.makeLibrary(source:observedSource,options:compile)
let observedTrace=try device.makeComputePipelineState(function:observedLibrary.makeFunction(name:"pathTrace")!)
func buffer<T>(_ a:[T])->MTLBuffer { a.withUnsafeBytes {device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!} }
func checkedCommit(_ c:MTLCommandBuffer)throws {c.commit();c.waitUntilCompleted();if let e=c.error {throw e}}
let roughness:[Float]=[0.065,0.115,0.13,0.25,0.4,0.54,0.55,0.8,1]
let inputs=buffer(roughness),outputs=buffer([SIMD4<Float>](repeating:.zero,count:roughness.count*10))
let command=queue.makeCommandBuffer()!,encoder=command.makeComputeCommandEncoder()!
encoder.setComputePipelineState(check);encoder.setBuffer(outputs,offset:0,index:0);encoder.setBuffer(inputs,offset:0,index:1)
encoder.dispatchThreads(MTLSize(width:roughness.count*2,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:16,height:1,depth:1))
encoder.endEncoding();try checkedCommit(command)
let values=Array(UnsafeBufferPointer(start:outputs.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:roughness.count*10))
let v=simd_normalize(SIMD3<Float>(0.3,0.1,1))
func ggx(_ h:Float,_ a:Float)->Float {let d=h*h*(a*a-1)+1;return a*a/max(Float.pi*d*d,1e-8)}
func smith(_ n:Float,_ a:Float)->Float {2*n/max(n+sqrt(a*a+(1-a*a)*n*n),1e-6)}
for i in roughness.indices {
    for enabled in 0...1 {
        let base=(i*2+enabled)*5,r=roughness[i],alpha=r*r
        let expected=enabled==1 && alpha<0.3 ? sqrt(min(0.3,max(0.1,2*alpha))) : r
        let actual=values[base].x
        require(abs(actual-expected)<1e-6,"GPU regularization must operate on GGX alpha, not perceptual roughness")
        let direction=SIMD3(values[base+1].x,values[base+1].y,values[base+1].z)
        let h=simd_normalize(v+direction),a=expected*expected
        let probability:Float=(expected<0.2 ? 0.65:0.25)*0.3 + 0.9*0.7
        let expectedPDF=(1-probability)*max(direction.z,0)/Float.pi+probability*ggx(max(h.z,0),a)*smith(v.z,a)/(4*v.z)
        require(abs(values[base+1].w-expectedPDF)<max(1e-5,expectedPDF*2e-4),"BRDF sample PDF must use the regularized distribution")
        // A zero-radius point light evaluates the same BRDF and cosine as the
        // sampled path direction; only inverse-square/range attenuation differs.
        let rangeFalloff=pow(Float(1)-pow(Float(10)/100,4),2)
        for c in 0..<3 {
            let expectedLight=values[base+2][c]*max(direction.z,0)*rangeFalloff
            require(abs(values[base+3][c]-expectedLight)<max(2e-5,abs(expectedLight)*1e-3),"Direct light and sampled path must share the adjusted surface r=\(r), enabled=\(enabled), channel=\(c), actual=\(values[base+3][c]), expected=\(expectedLight)")
        }
        if enabled==0 || alpha>=0.3 {
            require(values[base+1]==values[base+4],"Unregularized first/perfect-sheet surfaces must preserve sample directions and PDFs exactly")
        }
    }
    if roughness[i]<0.2 {require(values[i*10+5].y<values[i*10].y*0.04,"A secondary narrow GGX peak must broaden substantially")}
}
print("PASS: GPU alpha rule, unchanged primary/rough lobes, GGX mixture PDF and direct-light BRDF agreement")

private struct Scene {
    let vertices,ids,materials:MTLBuffer
    let acceleration:MTLAccelerationStructure
}
private struct Plane { var z,extent:Float;var material:Material }
private func scene(_ planes:[Plane])throws->Scene {
    var vertices:[Vertex]=[],ids:[UInt32]=[],materials:[Material]=[]
    for plane in planes {
        let r=plane.extent,z=plane.z,n=SIMD4<Float>(0,0,1,0)
        for p in [SIMD4<Float>(-r,-r,z,1),SIMD4<Float>(r,-r,z,1),SIMD4<Float>(r,r,z,1),SIMD4<Float>(-r,-r,z,1),SIMD4<Float>(r,r,z,1),SIMD4<Float>(-r,r,z,1)] {vertices.append(Vertex(p:p,n:n))}
        ids += [UInt32(materials.count),UInt32(materials.count)];materials.append(plane.material)
    }
    let vb=buffer(vertices),ib=buffer(ids),mb=buffer(materials)
    let geometry=MTLAccelerationStructureTriangleGeometryDescriptor();geometry.vertexBuffer=vb;geometry.vertexStride=32;geometry.vertexFormat = .float3;geometry.triangleCount=ids.count;geometry.opaque=true
    let descriptor=MTLPrimitiveAccelerationStructureDescriptor();descriptor.geometryDescriptors=[geometry]
    let sizes=device.accelerationStructureSizes(descriptor:descriptor),acceleration=device.makeAccelerationStructure(size:sizes.accelerationStructureSize)!,scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate)!
    let c=queue.makeCommandBuffer()!,e=c.makeAccelerationStructureCommandEncoder()!
    e.build(accelerationStructure:acceleration,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0);e.endEncoding();try checkedCommit(c)
    return Scene(vertices:vb,ids:ib,materials:mb,acceleration:acceleration)
}
let side=64
let textureDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:side,height:side,mipmapped:false)
textureDescriptor.storageMode = .shared;textureDescriptor.usage=[.shaderRead,.shaderWrite]
let color=device.makeTexture(descriptor:textureDescriptor)!,lights=buffer([SIMD4<Float>](repeating:.zero,count:4))
private func render(_ scene:Scene,enabled:Bool,bounces:Float,samples:Int=32,sun:SIMD3<Float>=SIMD3(0.5,0.4,1),sky:Float=1,sunScale:Float=1,pipeline:MTLComputePipelineState=trace)throws->[SIMD4<Float>] {
    var u=Uniforms(origin:SIMD4(0,0,5,enabled ? 1:0),right:SIMD4(0.08,0,0,1),up:SIMD4(0,0.08,0,0),forward:SIMD4(0,0,-1,0),sunDirection:SIMD4(sun,0),sunColor:SIMD4(3.8*sunScale,3.5*sunScale,3.1*sunScale,0),viewport:SIMD4(UInt32(side),UInt32(side),0,0),settings:SIMD4(1,bounces,0.004,sky))
    for batch in stride(from:0,to:samples,by:32) {
        let c=queue.makeCommandBuffer()!
        for sample in batch..<min(samples,batch+32) {
            u.viewport.z=UInt32(sample);u.viewport.w=UInt32(sample+771)
            let e=c.makeComputeCommandEncoder()!;e.setComputePipelineState(pipeline);e.setTexture(color,index:0);e.setBytes(&u,length:128,index:0)
            e.setBuffer(scene.vertices,offset:0,index:1);e.setBuffer(scene.ids,offset:0,index:2);e.setBuffer(scene.materials,offset:0,index:3);e.setAccelerationStructure(scene.acceleration,bufferIndex:4);e.setBuffer(lights,offset:0,index:5)
            e.dispatchThreads(MTLSize(width:side,height:side,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
        };try checkedCommit(c)
    }
    var pixels=[SIMD4<Float>](repeating:.zero,count:side*side)
    color.getBytes(&pixels,bytesPerRow:side*16,from:MTLRegionMake2D(0,0,side,side),mipmapLevel:0)
    for p in pixels {require(p.x.isFinite && p.y.isFinite && p.z.isFinite,"Nonfinite traced radiance")}
    return pixels
}
private let glossy=Material(c:SIMD4(0.45,0.62,0.81,0.115),p:SIMD4(0.7,0,0,0))
private let diffuse=Material(c:SIMD4(0.65,0.65,0.65,1),p:SIMD4(0,0,0,0))
private let glass=Material(c:SIMD4(0.9,0.98,0.95,0.065),p:SIMD4(0,0,0,1))
private let blackGlass=Material(c:SIMD4(0,0,0,0.065),p:SIMD4(0,0,0,1))
private let primary=try scene([Plane(z:0,extent:20,material:glossy)])
let primaryOff=try render(primary,enabled:false,bounces:3),primaryOn=try render(primary,enabled:true,bounces:3)
require(primaryOff==primaryOn,"Directly viewed glossy surface radiance must remain bit-identical")
private let transmitted=try scene([Plane(z:0,extent:2,material:glass),Plane(z:-1,extent:2,material:glass),Plane(z:-2,extent:20,material:glossy)])
let transmittedOff=try render(transmitted,enabled:false,bounces:1),transmittedOn=try render(transmitted,enabled:true,bounces:1)
require(transmittedOff==transmittedOn,"First opaque surface through multiple perfect sheets must remain bit-identical")
private let reflected=try scene([Plane(z:0,extent:1,material:glass),Plane(z:8,extent:20,material:glossy)])
let reflectedOff=try render(reflected,enabled:false,bounces:2,sun:SIMD3(0.5,0.4,-1)),reflectedOn=try render(reflected,enabled:true,bounces:2,sun:SIMD3(0.5,0.4,-1))
require(reflectedOff==reflectedOn,"First opaque camera-glass reflection must retain original radiance and independent path state")
require(reflectedOff.contains{$0.x>0.003},"Reflection preservation fixture must contain visible reflected illumination")
print("PASS: 4,096 pixels each preserve exact first-surface, two-sheet transmission and saved camera-reflection radiance")
// Zero tint keeps the transmitted branch's contribution exactly zero while it
// still samples an ordinary BSDF. Observe that the saved reflection starts with
// the original roughness despite the preceding scatter and bounce == 1.
private let branches=try scene([Plane(z:0,extent:1,material:blackGlass),Plane(z:-2,extent:20,material:diffuse),Plane(z:8,extent:20,material:glossy)])
let branchesOff=try render(branches,enabled:false,bounces:2,pipeline:observedTrace),branchesOn=try render(branches,enabled:true,bounces:2,pipeline:observedTrace)
require(branchesOff==branchesOn,"Saved camera reflection must reset non-delta state after the transmitted branch scatters")
print("PASS: actual saved-branch surface observation preserves roughness after the other branch's non-delta scatter")
// A small diffuse patch sends broadly sampled rays to a glossy wall. Solar
// highlights at that second vertex reproduce the troublesome low-SPP path.
private let secondary=try scene([Plane(z:0,extent:0.8,material:diffuse),Plane(z:8,extent:100,material:glossy)])
let secondaryOff=try render(secondary,enabled:false,bounces:2,samples:64,sun:SIMD3(0.5,0.4,-1),sky:0,sunScale:0.1)
let secondaryOn=try render(secondary,enabled:true,bounces:2,samples:64,sun:SIMD3(0.5,0.4,-1),sky:0,sunScale:0.1)
func statistics(_ pixels:[SIMD4<Float>])->(mean:Double,variance:Double,peak:Double) {
    let y=pixels.map{Double($0.x*0.2126+$0.y*0.7152+$0.z*0.0722)},mean=y.reduce(0,+)/Double(y.count)
    return(mean,y.map{pow($0-mean,2)}.reduce(0,+)/Double(y.count),y.max()!)
}
let before=statistics(secondaryOff),after=statistics(secondaryOn)
require(before.mean>0.001 && after.mean>0.001,"Secondary glossy fixture must receive real indirect sunlight")
require(before.variance>after.variance*3 && before.peak>after.peak*2,"Secondary narrow glossy sunlight paths should lose isolated radiance spikes")
print(String(format:"PASS: secondary glossy fixture variance %.7f → %.7f, peak %.5f → %.5f, mean %.5f → %.5f",before.variance,after.variance,before.peak,after.peak,before.mean,after.mean))

print("PASS: production regularization option and real ray-path tests on \(device.name)")
