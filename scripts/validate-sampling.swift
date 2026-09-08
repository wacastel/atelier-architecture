#!/usr/bin/env swift
// Validates the production low-discrepancy sampler and real GGX ray paths.
// No app launch or reconstruction: reduced variance must originate in sampling.
import Foundation
import Metal
import simd

private struct Vertex { var p,n:SIMD4<Float> }
private struct Material { var c,p:SIMD4<Float> }
private struct Uniforms { var origin,right,up,forward,sunDirection,sunColor:SIMD4<Float>; var viewport:SIMD4<UInt32>; var settings:SIMD4<Float>; var animation:SIMD4<Float> = .zero }
private func require(_ b:Bool,_ message:String) { if !b { fputs("FAIL: \(message)\n",stderr); exit(1) } }
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else { fatalError("Metal required") }
// An optional source path supports a negative control without changing the
// checked-in shader or the installed app's resources.
let sourceURL=CommandLine.arguments.count>1 ? URL(fileURLWithPath:CommandLine.arguments[1]) : root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal")
let source=try String(contentsOf:sourceURL,encoding:.utf8)+"""

kernel void samplingFixture(device float4 *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
    uint pixel=tid/64,index=tid%64,seed=hashBits(pixel);
    uint rng=seed ^ hashBits(index+67u);
    float2 independent=float2(randomFloat(rng),randomFloat(rng));
    out[tid*2]=float4(pathSample2D(index,0,seed),independent);
    out[tid*2+1]=float4(pathSample2D(index,4,seed),pathSample(index,6,seed),pathSample(index,7,seed));
}
kernel void ggxBoundaryFixture(device float4 *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
    constexpr float roughness[4]={.02f,.022f,.065f,.12f};
    float noH[9]={-1.0f,-0.0000001f,0.0f,0.5f,as_type<float>(0x3f7fffffu),1.0f,as_type<float>(0x3f800001u),as_type<float>(0x3f800002u),1.01f};
    float a=roughness[tid/9]*roughness[tid/9],x=noH[tid%9];
    out[tid]=float4(ggxDistribution(x,a),ggxDistribution(clamp(x,0.0f,1.0f),a),ggxDistribution(1,a),x);
}
kernel void polishedFixture(device float4 *out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
    constexpr float roughness[4]={.02f,.022f,.065f,.12f};
    uint test=tid/4096,index=tid%4096;
    float noV=(test&1) ? .25f:1.0f;
    float3 v=float3(sqrt(1-noV*noV),0,noV);
    SceneMaterial m;m.albedo=float4(.92f,.93f,.94f,roughness[test/2]);m.properties=float4(1,0,0,0);
    Surface s=surfaceAt(m,float3(0),float3(0,0,1),.001f,false);
    float pdf,otherPDF;
    float2 xi=pathSample2D(index,4,hashBits(test+313u));
    float3 l=sampleBRDF(s,v,xi,.99f,pdf),other=sampleBRDF(s,v,xi,.01f,otherPDF);
    float3 weight=l.z>0 ? brdf(s,v,l)*l.z/pdf:float3(0);
    float3 h=normalize(v+l);float a=s.roughness*s.roughness;
    float expectedPDF=ggxDistribution(max(h.z,0.0f),a)*smithG1(noV,a)/(4*noV);
    out[tid*2]=float4(weight,s.roughness);
    out[tid*2+1]=float4(ggxDistribution(1,a),pdf/expectedPDF,distance(l,other),abs(pdf-otherPDF)/max(pdf,1e-8f));
}
"""
let compile=MTLCompileOptions();compile.languageVersion = .version3_1
let library=try device.makeLibrary(source:source,options:compile)
let trace=try device.makeComputePipelineState(function:library.makeFunction(name:"pathTrace")!)
let sampling=try device.makeComputePipelineState(function:library.makeFunction(name:"samplingFixture")!)
let polished=try device.makeComputePipelineState(function:library.makeFunction(name:"polishedFixture")!)
let ggxBoundary=try device.makeComputePipelineState(function:library.makeFunction(name:"ggxBoundaryFixture")!)
func buffer<T>(_ a:[T])->MTLBuffer { a.withUnsafeBytes {device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!} }
func checkedCommit(_ c:MTLCommandBuffer)throws {c.commit();c.waitUntilCompleted();if let e=c.error {throw e}}
let pixelCount=2048,sampleCount=64
let output=buffer([SIMD4<Float>](repeating:.zero,count:pixelCount*sampleCount*2))
let command=queue.makeCommandBuffer()!,encoder=command.makeComputeCommandEncoder()!
encoder.setComputePipelineState(sampling);encoder.setBuffer(output,offset:0,index:0)
encoder.dispatchThreads(MTLSize(width:pixelCount*sampleCount,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:64,height:1,depth:1));encoder.endEncoding();try checkedCommit(command)
let values=Array(UnsafeBufferPointer(start:output.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:pixelCount*sampleCount*2))
var whiteError=0.0,sobolError=0.0,whiteTemporal=0.0,sobolTemporal=0.0
for pixel in 0..<pixelCount {
    var previousWhite:Double?,previousSobol:Double?
    for block in 0..<16 {
        var quadrants=[Int](repeating:0,count:4),white=0.0,sobol=0.0
        // Subpixel rectangle coverage with analytic area, varying across pixels.
        let edgeX=Float(pixel%71+1)/73,edgeY=Float(pixel%37+1)/39
        for index in 0..<4 {
            let v=values[(pixel*64+block*4+index)*2]
            require(v.x>=0 && v.x<1 && v.y>=0 && v.y<1,"Samples must remain inside the unit square")
            quadrants[Int(v.x*2)+2*Int(v.y*2)] += 1
            sobol += v.x<edgeX && v.y<edgeY ? 0.25:0
            white += v.z<edgeX && v.w<edgeY ? 0.25:0
        }
        require(quadrants.allSatisfy{$0==1},"Every aligned four-sample camera block must cover all four quadrants")
        let truth=Double(edgeX*edgeY),a=white-truth,b=sobol-truth
        whiteError += a*a;sobolError += b*b
        if let pa=previousWhite,let pb=previousSobol {whiteTemporal += pow(a-pa,2);sobolTemporal += pow(b-pb,2)}
        previousWhite=a;previousSobol=b
    }
    for dimension in 0..<4 {
        for block in 0..<4 {
            var strata=[Int](repeating:0,count:16)
            for index in 0..<16 {
                let v=values[(pixel*64+block*16+index)*2+1][dimension]
                require(v>=0 && v<1,"Path-domain samples must remain inside the unit interval")
                strata[Int(v*16)] += 1
            }
            require(strata.allSatisfy{$0==1},"Each first-bounce BRDF dimension must stratify aligned sixteen-sample blocks")
        }
    }
}
require(sobolError<whiteError*0.6 && sobolTemporal<whiteTemporal*0.7,"Low-SPP unresolved coverage should reduce image and temporal sampling error")
print(String(format:"PASS: GPU stratification; 4-SPP subpixel coverage RMS reduction %.1f%%, temporal residual reduction %.1f%%",100*(1-sqrt(sobolError/whiteError)),100*(1-sqrt(sobolTemporal/whiteTemporal))))

let boundaryOutput=buffer([SIMD4<Float>](repeating:.zero,count:36))
let bc=queue.makeCommandBuffer()!,be=bc.makeComputeCommandEncoder()!
be.setComputePipelineState(ggxBoundary);be.setBuffer(boundaryOutput,offset:0,index:0)
be.dispatchThreads(MTLSize(width:36,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:64,height:1,depth:1));be.endEncoding();try checkedCommit(bc)
let boundaryValues=Array(UnsafeBufferPointer(start:boundaryOutput.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:36))
for (i,v) in boundaryValues.enumerated() {
    require(v.x.isFinite && v.x>=0 && v.x<=v.z*1.00001,"Rounded NoH exceeded the physical GGX peak at boundary case \(i)")
    // First check the physical peak for all inputs, before endpoint equality.
}
for (i,v) in boundaryValues.enumerated() {
    require(v.x==v.y,"GGX must clamp normalized-dot rounding outside [0,1]")
    if i%9>=5 {require(v.x==v.z,"NoH one ULP above one must equal the normal-incidence peak")}
    if i%9>0 && i%9<=5 {require(v.x>=boundaryValues[i-1].x,"GGX boundary response must remain monotonic")}
}
print("PASS: polished GGX stays finite and bounded at negative inputs, nextDown(1), 1, nextUp(1), two ULPs above 1 and 1.01")

let polishedOutput=buffer([SIMD4<Float>](repeating:.zero,count:8*4096*2))
let pc=queue.makeCommandBuffer()!,pe=pc.makeComputeCommandEncoder()!
pe.setComputePipelineState(polished);pe.setBuffer(polishedOutput,offset:0,index:0)
pe.dispatchThreads(MTLSize(width:8*4096,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:64,height:1,depth:1));pe.endEncoding();try checkedCommit(pc)
let polishedValues=Array(UnsafeBufferPointer(start:polishedOutput.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:8*4096*2))
for test in 0..<8 {
    let r:Float=[0.02,0.022,0.065,0.12][test/2],noV:Float=test%2==0 ? 1:0.25
    let expectedPeak=1/(Double.pi*pow(Double(r),4))
    var energy=SIMD3<Float>.zero
    for i in 0..<4096 {
        let v=polishedValues[(test*4096+i)*2],data=polishedValues[(test*4096+i)*2+1]
        require(abs(v.w-r)<0.000001,"Authored polished-steel roughness was clamped away")
        require(abs(Double(data.x)/expectedPeak-1)<0.00001,"GGX normal peak lost energy to a numerical denominator floor")
        require(abs(data.y-1)<0.00001 && data.z<0.000001 && data.w<0.00001,"A pure conductor must always sample its GGX lobe with the exact PDF test=\(test), index=\(i), data=\(data)")
        for c in 0..<3 {require(v[c].isFinite && v[c]>=0 && v[c]<=1.0001,"Sampled conductor throughput violates the unit-energy bound")}
        energy += SIMD3(v.x,v.y,v.z)/4096
    }
    if r<=0.022 {
        let f0=SIMD3<Float>(0.92,0.93,0.94),expected=f0+(1-f0)*pow(1-noV,5)
        require(simd_reduce_max(abs(energy-expected))<0.005,"Near-mirror hemispherical energy failed the Fresnel limit")
    }
}
print("PASS: 32,768 polished-conductor samples retain .02/.022 roughness, stable GGX peaks/PDFs, bounded throughput and Fresnel-limit energy")
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
private func render(_ scene:Scene,enabled:Bool,bounces:Float,samples:Int=32,sun:SIMD3<Float>=SIMD3(0.5,0.4,1),sky:Float=1,sunScale:Float=1,lowDiscrepancy:Bool=false,seedBase:Int=0,pipeline:MTLComputePipelineState=trace)throws->[SIMD4<Float>] {
    var u=Uniforms(origin:SIMD4(0,0,5,enabled ? 1:0),right:SIMD4(0.08,0,0,1),up:SIMD4(0,0.08,0,lowDiscrepancy ? 1:0),forward:SIMD4(0,0,-1,0),sunDirection:SIMD4(sun,0),sunColor:SIMD4(3.8*sunScale,3.5*sunScale,3.1*sunScale,0),viewport:SIMD4(UInt32(side),UInt32(side),0,0),settings:SIMD4(1,bounces,0.004,sky))
    for batch in stride(from:0,to:samples,by:32) {
        let c=queue.makeCommandBuffer()!
        for sample in batch..<min(samples,batch+32) {
            u.viewport.z=UInt32(sample);u.viewport.w=UInt32(sample+seedBase)
            let e=c.makeComputeCommandEncoder()!;e.setComputePipelineState(pipeline);e.setTexture(color,index:0);e.setBytes(&u,length:144,index:0)
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
private let secondary=try scene([Plane(z:0,extent:0.8,material:diffuse),Plane(z:8,extent:100,material:glossy)])
func error(_ a:[SIMD4<Float>],_ b:[SIMD4<Float>])->Double {
    zip(a,b).reduce(0) {let d=SIMD3<Double>(Double($1.0.x-$1.1.x),Double($1.0.y-$1.1.y),Double($1.0.z-$1.1.z));return $0+simd_length_squared(d)}/Double(a.count*3)
}
for (label,fixture,sun,sky,sunScale) in [("primary mirror",primary,SIMD3<Float>(0.5,0.4,1),Float(1),Float(1)),("secondary glossy",secondary,SIMD3<Float>(0.5,0.4,-1),Float(0),Float(0.1))] {
    let truth=try render(fixture,enabled:true,bounces:2,samples:1024,sun:sun,sky:sky,sunScale:sunScale,lowDiscrepancy:true,seedBase:16384)
    var whiteError=0.0,sobolError=0.0
    for block in 0..<16 {
        let white=try render(fixture,enabled:true,bounces:2,samples:4,sun:sun,sky:sky,sunScale:sunScale,lowDiscrepancy:false,seedBase:block*4)
        let sobol=try render(fixture,enabled:true,bounces:2,samples:4,sun:sun,sky:sky,sunScale:sunScale,lowDiscrepancy:true,seedBase:block*4)
        whiteError += error(white,truth);sobolError += error(sobol,truth)
    }
    print(String(format:"GPU %@: 4-SPP RMS %.6f → %.6f (%.1f%% reduction)",label,sqrt(whiteError/16),sqrt(sobolError/16),100*(1-sqrt(sobolError/whiteError))))
    require(sobolError<whiteError,"Actual glossy-path sampling must improve matched white-noise error")
}
print("PASS: production sampler reduces noise before denoising; reflection geometry and radiance are not blurred")
