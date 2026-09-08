#!/usr/bin/env swift
// Real GPU regression for thin-sheet Fresnel, transmitted shadow rays, primary
// visibility, and deterministic guides through glass. No app launch required.
import Foundation
import Metal
import simd
private struct Vertex { var p,n:SIMD4<Float> }
private struct Material { var c,p:SIMD4<Float> }
private struct Uniforms { var origin,right,up,forward,sunDirection,sunColor:SIMD4<Float>; var viewport:SIMD4<UInt32>; var settings:SIMD4<Float>; var animation:SIMD4<Float> = .zero }
private func require(_ b:Bool,_ message:String) { if !b { fatalError(message) } }
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { fatalError("Metal required") }
let source=try String(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal"),encoding:.utf8)+"""

kernel void checkGlass(device float4 *out [[buffer(0)]],
  const device SceneVertex *v [[buffer(1)]],const device uint *i [[buffer(2)]],
  const device SceneMaterial *m [[buffer(3)]],primitive_acceleration_structure scene [[buffer(4)]]) {
  ray r; r.origin=float3(0,0,5);r.direction=float3(0,0,-1);r.min_distance=.001f;r.max_distance=6;
  out[0]=float4(thinSheetReflectance(1),thinSheetReflectance(.5f),thinSheetReflectance(.1f),1);
  out[1]=float4(glassVisibility(r,scene,v,i,m),1);
  r.max_distance=10;
  out[2]=float4(glassVisibility(r,scene,v,i,m),1);
  r.origin=float3(0,0,-5);r.direction=float3(0,0,1);
  out[3]=float4(glassVisibility(r,scene,v,i,m),1);
  r.origin=float3(30,0,5);r.direction=float3(0,0,-1);
  out[4]=float4(glassVisibility(r,scene,v,i,m),1);
  r.origin=float3(0,0,5);r.max_distance=4;
  out[5]=float4(glassVisibility(r,scene,v,i,m),1);
}
"""
let compile=MTLCompileOptions();compile.languageVersion = .version3_1
let library=try device.makeLibrary(source:source,options:compile)
func pipeline(_ name:String)throws->MTLComputePipelineState { try device.makeComputePipelineState(function:library.makeFunction(name:name)!) }
let check=try pipeline("checkGlass"),trace=try pipeline("pathTrace"),guide=try pipeline("primarySurface")
private var vertices:[Vertex]=[]
for z:Float in [0,-2] {
    let n=SIMD4<Float>(0,0,1,0)
    for p in [SIMD4<Float>(-20,-20,z,1),SIMD4<Float>(20,-20,z,1),SIMD4<Float>(20,20,z,1),SIMD4<Float>(-20,-20,z,1),SIMD4<Float>(20,20,z,1),SIMD4<Float>(-20,20,z,1)] { vertices.append(Vertex(p:p,n:n)) }
}
func buffer<T>(_ a:[T])->MTLBuffer { a.withUnsafeBytes{ device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)! } }
let vb=buffer(vertices),ids=buffer([UInt32(0),0,1,1])
private var materials=[Material(c:SIMD4(0.9,0.98,0.95,0.065),p:SIMD4(0,0,0,1)),Material(c:SIMD4(0.95,0.015,0.01,1),p:SIMD4(0,1,0,0))]
let mb=buffer(materials),lights=buffer([SIMD4<Float>](repeating:.zero,count:4)),out=buffer([SIMD4<Float>](repeating:.zero,count:6))
let geometry=MTLAccelerationStructureTriangleGeometryDescriptor();geometry.vertexBuffer=vb;geometry.vertexStride=32;geometry.vertexFormat = .float3;geometry.triangleCount=4;geometry.opaque=true
let descriptor=MTLPrimitiveAccelerationStructureDescriptor();descriptor.geometryDescriptors=[geometry]
let sizes=device.accelerationStructureSizes(descriptor:descriptor),acceleration=device.makeAccelerationStructure(size:sizes.accelerationStructureSize)!,scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate)!
let build=queue.makeCommandBuffer()!,builder=build.makeAccelerationStructureCommandEncoder()!
builder.build(accelerationStructure:acceleration,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0);builder.endEncoding();build.commit();build.waitUntilCompleted();if let e=build.error{throw e}
func bind(_ encoder:MTLComputeCommandEncoder) {
    encoder.setBuffer(vb,offset:0,index:1);encoder.setBuffer(ids,offset:0,index:2);encoder.setBuffer(mb,offset:0,index:3);encoder.setAccelerationStructure(acceleration,bufferIndex:4);encoder.setBuffer(lights,offset:0,index:5)
}
func checkedCommit(_ c:MTLCommandBuffer)throws { c.commit();c.waitUntilCompleted();if let e=c.error{throw e} }
func opticalCheck()throws->[SIMD4<Float>] {
    let c=queue.makeCommandBuffer()!,e=c.makeComputeCommandEncoder()!;e.setComputePipelineState(check);e.setBuffer(out,offset:0,index:0);bind(e)
    e.dispatchThreads(MTLSize(width:1,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:1,height:1,depth:1));e.endEncoding();try checkedCommit(c)
    return Array(UnsafeBufferPointer(start:out.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:6))
}
let optics=try opticalCheck()
require(abs(optics[0].x-1.0/13)<0.00001,"Normal-incidence sheet reflectance must be 7.6923%")
require(optics[0].x<optics[0].y && optics[0].y<optics[0].z && optics[0].z<1,"Fresnel must rise toward grazing incidence")
for c in 0..<3 { require(abs(optics[1][c]-materials[0].c[c]*12/13)<0.00001,"Tinted transparent shadow attenuation is wrong") }
require(optics[2].x==0 && optics[2].y==0 && optics[2].z==0,"Opaque object behind glass must block a shadow ray")
require(optics[3].x==0 && optics[3].y==0 && optics[3].z==0,"Opaque object before glass must block the reverse shadow ray")
for i in [4,5] {for c in 0..<3 {require(optics[i][c]==1,"Unoccluded or finite-segment no-hit ray must retain full visibility")}}
// Change optical order without rebuilding the BVH: neither arbitrary any-hit
// order nor near/far placement may let a shadow pass an opaque blocker.
[UInt32(1),1,0,0].withUnsafeBytes {ids.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count)}
let reordered=try opticalCheck()
for i in [2,3] {for c in 0..<3 {require(reordered[i][c]==0,"Mixed-order transparent/opaque visibility must be zero")}}
[UInt32(0),0,1,1].withUnsafeBytes {ids.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count)}
private let savedBack=materials[1]
materials[1]=Material(c:SIMD4(0.8,0.9,0.7,0.065),p:SIMD4(0,0,0,0.75))
materials.withUnsafeBytes {mb.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count)}
let allGlass=try opticalCheck()
for c in 0..<3 {
    let expected=materials[0].c[c]*materials[1].c[c]*0.75*pow(Float(12)/13,2)
    require(abs(allGlass[2][c]-expected)<0.00001 && abs(allGlass[3][c]-expected)<0.00001,"All-glass forward/reverse rays must preserve both tint, transmission and Fresnel factors")
}
materials[1]=savedBack
materials.withUnsafeBytes {mb.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count)}
func texture()->MTLTexture { let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:32,height:32,mipmapped:false);d.storageMode = .shared;d.usage=[.shaderRead,.shaderWrite];return device.makeTexture(descriptor:d)! }
let color=texture(),world=texture(),normal=texture(),albedo=texture()
private var u=Uniforms(origin:SIMD4(0,0,5,1),right:SIMD4(0.15,0,0,1),up:SIMD4(0,0.15,0,0),forward:SIMD4(0,0,-1,0),sunDirection:SIMD4(0,1,1,0),sunColor:.zero,viewport:SIMD4(32,32,0,0),settings:SIMD4(1,1,0.004,0))
func pixels(_ texture:MTLTexture)->[SIMD4<Float>] { var a=[SIMD4<Float>](repeating:.zero,count:1024);texture.getBytes(&a,bytesPerRow:32*16,from:MTLRegionMake2D(0,0,32,32),mipmapLevel:0);return a }
func radiance()throws->SIMD3<Float> {
    for batch in 0..<8 {
        let c=queue.makeCommandBuffer()!
        for j in 0..<32 {
            let sample=batch*32+j;u.viewport.z=UInt32(sample);u.viewport.w=UInt32(sample+771)
            let e=c.makeComputeCommandEncoder()!;e.setComputePipelineState(trace);e.setTexture(color,index:0);e.setBytes(&u,length:144,index:0);bind(e)
            e.dispatchThreads(MTLSize(width:32,height:32,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
        };try checkedCommit(c)
    }
    var mean=SIMD3<Float>.zero
    for p in pixels(color) { require(p.x.isFinite && p.y.isFinite && p.z.isFinite,"Nonfinite glass radiance");mean += SIMD3(p.x,p.y,p.z)/1024 }
    return mean
}
let transmitted=try radiance()
require(transmitted.x>0.73 && transmitted.x<0.85 && transmitted.y<0.03,"Transmitted red emitter must be visible through the glass at one opaque bounce")
materials[1].p.y=0 // Non-emissive opaque background: retain the through-glass guide flag.
materials.withUnsafeBytes { mb.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count) }
let c=queue.makeCommandBuffer()!,e=c.makeComputeCommandEncoder()!;e.setComputePipelineState(guide);e.setBytes(&u,length:144,index:0);bind(e)
e.setTexture(world,index:0);e.setTexture(normal,index:1);e.setTexture(albedo,index:2);e.dispatchThreads(MTLSize(width:32,height:32,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding();try checkedCommit(c)
let gp=pixels(world)[528],gn=pixels(normal)[528]
require(abs(gp.z+2)<0.001 && abs(gp.w-1.75)<0.001 && gn.w>6.99 && gn.w<7.01,"Guides must follow opaque surface behind glass and flag current coverage")
materials[0].p.w=0
materials.withUnsafeBytes { mb.contents().copyMemory(from:$0.baseAddress!,byteCount:$0.count) }
let blocked=try opticalCheck(),opaque=try radiance()
require(blocked[1].x==0 && opaque.x<0.001,"Opaque control pane must block both visibility and background emission")
print("PASS: thin-sheet Fresnel normal/grazing values, tinted transparent shadows and opaque blockers")
print("PASS: mixed-order blockers, reversed rays, empty/short segments and all-glass multiplicative visibility")
print("PASS: actual red emitter through glass with one opaque bounce: \(transmitted); opaque control \(opaque)")
print("PASS: behind-glass world/depth guides and current-coverage flag on \(device.name)")
