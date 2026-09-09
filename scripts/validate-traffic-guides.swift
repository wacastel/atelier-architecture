#!/usr/bin/env swift
// Tiny actual TLAS/BLAS scenes exercise the production primarySurfaceTraffic
// kernel. No app launch, whole-city geometry, path sampling or image filter.
import Foundation
import Metal
import simd
import CryptoKit

struct GuideVertex { var position,normal:SIMD4<Float> }
struct GuideMaterial { var albedo,properties:SIMD4<Float> }
struct GuideLight {var positionRadius,directionCone,colorPower,parameters:SIMD4<Float>}
struct GuideUniforms {var origin,right,up,forward,sunDirection,sunColor:SIMD4<Float>;var viewport:SIMD4<UInt32>;var settings,animation:SIMD4<Float>}
struct GuideGrid {var originCellSize:SIMD4<Float>;var dimensions,counts:SIMD4<UInt32>}
struct GuideMesh {
    var vertices:[GuideVertex]=[],materials:[UInt32]=[]
    mutating func quad(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ d:SIMD3<Float>,_ material:UInt32=0) {
        let n=simd_normalize(simd_cross(b-a,c-a))
        vertices += [a,b,c,a,c,d].map{GuideVertex(position:SIMD4($0,1),normal:SIMD4(n,0))};materials += [material,material]
    }
    mutating func horizontal(_ center:SIMD3<Float>,_ radius:Float,_ material:UInt32=0) {
        quad(center+SIMD3(-radius,0,-radius),center+SIMD3(-radius,0,radius),center+SIMD3(radius,0,radius),center+SIMD3(radius,0,-radius),material)
    }
    mutating func vertical(_ z:Float,_ material:UInt32=1,_ x:Float=0) {
        quad(SIMD3(x-1,0,z),SIMD3(x+1,0,z),SIMD3(x+1,2,z),SIMD3(x-1,2,z),material)
    }
}
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
let args=CommandLine.arguments
func argument(_ flag:String)->String? {guard let i=args.firstIndex(of:flag),i+1<args.count else{return nil};return args[i+1]}
let sourceURL=argument("--source").map{URL(fileURLWithPath:$0)} ?? root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal")
let source=try String(contentsOf:sourceURL,encoding:.utf8)
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {fatalError("A local Metal ray-tracing device is required")}
let compile=MTLCompileOptions();compile.languageVersion = .version3_1
let library=try device.makeLibrary(source:source,options:compile)
let pipeline=try device.makeComputePipelineState(function:library.makeFunction(name:"primarySurfaceTraffic")!)
func buffer<T>(_ values:[T])->MTLBuffer {values.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!}}
func commit(_ command:MTLCommandBuffer)throws {command.commit();command.waitUntilCompleted();if let error=command.error {throw error}}
let materialBuffer=buffer([
    GuideMaterial(albedo:SIMD4(0.6,0.6,0.6,0.6),properties:.zero),
    GuideMaterial(albedo:SIMD4(0.6,0.1,0.1,0.6),properties:.zero),
    GuideMaterial(albedo:SIMD4(0.9,0.9,0.9,0.022),properties:SIMD4(1,0,0,0)),
    GuideMaterial(albedo:SIMD4(0.95,0.95,0.95,0.065),properties:SIMD4(0,0,0,1))])
let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:1,height:1,mipmapped:false)
descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
let textures=(0..<3).map{_ in device.makeTexture(descriptor:descriptor)!}
let dummyRanges=buffer([SIMD2<UInt32>(0,0)]),dummyIndices=buffer([UInt32(0)])
let defaultLight=GuideLight(positionRadius:SIMD4(0,3,0,0.12),directionCone:SIMD4(0,-1,0,-1),colorPower:SIMD4(1,0.88,0.69,65),parameters:SIMD4(65,0.95,0,0))

func observe(staticMesh:GuideMesh,dynamicMesh:GuideMesh,eye:SIMD3<Float>=SIMD3(0,4,-5),target:SIMD3<Float> = .zero,night:Bool=false,moving:Bool=true,light:GuideLight=defaultLight,pipeline:MTLComputePipelineState=pipeline)throws->SIMD4<Float> {
    let vertices=buffer(staticMesh.vertices+dynamicMesh.vertices),ids=buffer(staticMesh.materials+dynamicMesh.materials)
    var bottoms:[MTLAccelerationStructure]=[]
    for (offset,count) in [(0,staticMesh.materials.count),(staticMesh.vertices.count*32,dynamicMesh.materials.count)] {
        let geometry=MTLAccelerationStructureTriangleGeometryDescriptor();geometry.vertexBuffer=vertices;geometry.vertexBufferOffset=offset;geometry.vertexStride=32;geometry.vertexFormat = .float3;geometry.triangleCount=count;geometry.opaque=true
        let desc=MTLPrimitiveAccelerationStructureDescriptor();desc.geometryDescriptors=[geometry]
        let sizes=device.accelerationStructureSizes(descriptor:desc),acceleration=device.makeAccelerationStructure(size:sizes.accelerationStructureSize)!,scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate)!
        let command=queue.makeCommandBuffer()!,encoder=command.makeAccelerationStructureCommandEncoder()!
        encoder.build(accelerationStructure:acceleration,descriptor:desc,scratchBuffer:scratch,scratchBufferOffset:0);encoder.endEncoding();try commit(command);bottoms.append(acceleration)
    }
    let instances=(0..<2).map {index -> MTLAccelerationStructureInstanceDescriptor in
        var instance=MTLAccelerationStructureInstanceDescriptor()
        instance.transformationMatrix.columns=(MTLPackedFloat3Make(1,0,0),MTLPackedFloat3Make(0,1,0),MTLPackedFloat3Make(0,0,1),MTLPackedFloat3Make(0,0,0));instance.options = .opaque;instance.mask=0xFF;instance.accelerationStructureIndex=UInt32(index);return instance
    }
    let desc=MTLInstanceAccelerationStructureDescriptor();desc.instancedAccelerationStructures=bottoms;desc.instanceDescriptorBuffer=buffer(instances);desc.instanceCount=2
    let sizes=device.accelerationStructureSizes(descriptor:desc),acceleration=device.makeAccelerationStructure(size:sizes.accelerationStructureSize)!,scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate)!
    let command=queue.makeCommandBuffer()!,builder=command.makeAccelerationStructureCommandEncoder()!
    builder.build(accelerationStructure:acceleration,descriptor:desc,scratchBuffer:scratch,scratchBufferOffset:0);builder.endEncoding()
    let forward=simd_normalize(target-eye),right=simd_normalize(simd_cross(forward,SIMD3<Float>(0,1,0))),up=simd_normalize(simd_cross(right,forward))
    var u=GuideUniforms(origin:SIMD4(eye,1),right:SIMD4(right*0.25,1),up:SIMD4(up*0.25,1),forward:SIMD4(forward,moving ? 1:0),sunDirection:SIMD4(simd_normalize(SIMD3<Float>(1,1,0)),0),sunColor:SIMD4(3,3,3,night ? 1:0),viewport:SIMD4(1,1,0,0),settings:SIMD4(1,3,0.009,1),animation:.zero)
    var traffic=SIMD4<UInt32>(UInt32(staticMesh.materials.count),UInt32(dynamicMesh.vertices.count),1,0)
    var grid=GuideGrid(originCellSize:SIMD4(0,0,0,1),dimensions:.zero,counts:.zero)
    let encoder=command.makeComputeCommandEncoder()!;encoder.setComputePipelineState(pipeline)
    for (i,t) in textures.enumerated(){encoder.setTexture(t,index:i)}
    encoder.setBytes(&u,length:MemoryLayout<GuideUniforms>.stride,index:0)
    encoder.setBuffer(vertices,offset:0,index:1);encoder.setBuffer(ids,offset:0,index:2);encoder.setBuffer(materialBuffer,offset:0,index:3);encoder.setAccelerationStructure(acceleration,bufferIndex:4)
    encoder.setBytes(&traffic,length:16,index:9);encoder.setBytes(&grid,length:MemoryLayout<GuideGrid>.stride,index:10);encoder.setBuffer(dummyRanges,offset:0,index:11);encoder.setBuffer(dummyIndices,offset:0,index:12);encoder.setBuffer(buffer([light]),offset:0,index:13)
    encoder.dispatchThreads(MTLSize(width:1,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:1,height:1,depth:1));encoder.endEncoding();try commit(command)
    var value=SIMD4<Float>.zero;textures[0].getBytes(&value,bytesPerRow:16,from:MTLRegionMake2D(0,0,1,1),mipmapLevel:0);return value
}
var floor=GuideMesh();floor.horizontal(.zero,20)
var distant=GuideMesh();distant.vertical(0,1,1000)
var cases=[[String:Any]](),failures=[String]()
func check(_ name:String,_ value:SIMD4<Float>,_ material:Float,_ flag:Float) {
    let expected=material+flag,passed=value.x.isFinite && value.y.isFinite && value.z.isFinite && abs(value.w-expected)<0.00001
    cases.append(["name":name,"expectedMaterialGuide":expected,"actualWorldGuide":[value.x,value.y,value.z,value.w],"passed":passed])
    if !passed {failures.append(name)}
}
check("daylight floor inside inactive 65m headlamp radius",try observe(staticMesh:floor,dynamicMesh:distant),0,0)
check("night visible moving lamp on stationary rough floor",try observe(staticMesh:floor,dynamicMesh:distant,night:true),0,0.25)
check("paused traffic lamp leaves ordinary guide",try observe(staticMesh:floor,dynamicMesh:distant,night:true,moving:false),0,0)
var away=defaultLight;away.directionCone=SIMD4(0,1,0,0.8);away.parameters.y=0.95
check("night lamp cone faces away",try observe(staticMesh:floor,dynamicMesh:distant,night:true,light:away),0,0)
var behind=defaultLight;behind.positionRadius.y = -3
check("night lamp is behind surface",try observe(staticMesh:floor,dynamicMesh:distant,night:true,light:behind),0,0)
var far=defaultLight;far.positionRadius.x=1000
check("night lamp outside finite radius",try observe(staticMesh:floor,dynamicMesh:distant,night:true,light:far),0,0)
var covered=floor;covered.horizontal(SIMD3(0,1,0),2)
check("opaque ceiling blocks moving lamp",try observe(staticMesh:covered,dynamicMesh:distant,eye:SIMD3(0,0.5,-4),night:true),0,0)
var glazed=floor;glazed.horizontal(SIMD3(0,1,0),2,3)
check("light transmitted through glass remains changing",try observe(staticMesh:glazed,dynamicMesh:distant,eye:SIMD3(0,0.5,-4),night:true),0,0.25)
var caster=GuideMesh();caster.horizontal(SIMD3(2,2,0),1,1)
check("actual moving sunlight shadow on rough floor",try observe(staticMesh:floor,dynamicMesh:caster),0,0.25)
var clearCaster=GuideMesh();clearCaster.horizontal(SIMD3(5,2,0),1,1)
check("departed sunlight shadow clears ordinary guide",try observe(staticMesh:floor,dynamicMesh:clearCaster),0,0)
var vehicle=GuideMesh();vehicle.vertical(0)
check("directly visible moving geometry",try observe(staticMesh:floor,dynamicMesh:vehicle,eye:SIMD3(0,1,-4),target:SIMD3(0,1,0)),1,0.875)
var mirror=GuideMesh();mirror.vertical(0,2)
var reflected=GuideMesh();reflected.vertical(-6)
check("moving vehicle inside polished reflection",try observe(staticMesh:mirror,dynamicMesh:reflected,eye:SIMD3(0,1,-4),target:SIMD3(0,1,0),light:far),2,0.875)
check("unaffected polished surface retains mirror guide",try observe(staticMesh:mirror,dynamicMesh:distant,eye:SIMD3(0,1,-4),target:SIMD3(0,1,0),light:far),2,0.125)
var negative:Any=NSNull()
if let baseline=argument("--baseline") {
    let text=try String(contentsOfFile:baseline,encoding:.utf8)
    let library=try device.makeLibrary(source:text,options:compile),control=try device.makeComputePipelineState(function:library.makeFunction(name:"primarySurfaceTraffic")!)
    let old=try observe(staticMesh:floor,dynamicMesh:distant,pipeline:control)
    let caught=abs(old.w-0.875)<0.00001
    if !caught {failures.append("baseline negative control did not reproduce daytime blanket rejection")}
    negative=["source":baseline,"sha256":SHA256.hash(data:Data(text.utf8)).map{String(format:"%02x",$0)}.joined(),"dayGuide":old.w,"reproducedBug":caught]
}
let report:[String:Any]=["passed":failures.isEmpty,"failures":failures,"device":device.name,"source":sourceURL.path,"sourceSHA256":SHA256.hash(data:Data(source.utf8)).map{String(format:"%02x",$0)}.joined(),"cases":cases,"negativeControl":negative,"scope":"Production primarySurfaceTraffic kernel against tiny actual two-instance TLAS scenes. Flags .25 and .875 both reject old lighting; .25 retains spatial filtering for stationary rough diffuse surfaces." ]
let json=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
if let output=argument("--output") {try json.write(to:URL(fileURLWithPath:output))}
print(String(data:json,encoding:.utf8)!)
if !failures.isEmpty {exit(1)}
