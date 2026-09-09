import Foundation
import Metal
import simd
import CryptoKit

struct Failure: Error, CustomStringConvertible {let description:String;init(_ text:String){description=text}}
struct ProbeResult { var ids:SIMD4<UInt32>;var vertexDistance:SIMD4<Float>;var material:SIMD4<Float> }
let began=Date()
func require(_ value:Bool,_ message:String)throws {if !value{throw Failure(message)}}
func digest(_ url:URL)throws->String {SHA256.hash(data:try Data(contentsOf:url)).map{String(format:"%02x",$0)}.joined()}

let kernel = """
struct LargeGeometryProbeResult { uint4 ids;float4 vertexDistance;float4 material; };
template<typename AS>
LargeGeometryProbeResult largeGeometryProbe(float4 origin, AS acceleration,
 const device SceneVertex *vertices,const device uint *indices,const device SceneMaterial *materials,uint staticCount) {
    ray r;r.origin=origin.xyz;r.direction=float3(0,0,-1);r.min_distance=0.001f;r.max_distance=6.0f;
    auto hit=sceneIntersection(r,acceleration,false,staticCount);
    if(hit.type==intersection_type::none)return {uint4(0),float4(0),float4(0)};
    if(hit.primitive_id>staticCount)return {uint4(2,hit.primitive_id,0,hit.dynamic),float4(0),float4(0)};
    uint materialID=indices[hit.primitive_id];
    if(materialID>=16)return {uint4(3,hit.primitive_id,materialID,hit.dynamic),float4(0),float4(0)};
    ulong vertexID=ulong(hit.primitive_id)*3ul;
    SceneVertex a=vertices[vertexID];
    return {uint4(1,hit.primitive_id,materialID,hit.dynamic),float4(a.position.xyz,hit.distance),materials[materialID].albedo};
}
kernel void largeGeometryStatic(primitive_acceleration_structure acceleration [[buffer(0)]],
 const device SceneVertex *vertices [[buffer(1)]],const device uint *indices [[buffer(2)]],
 const device SceneMaterial *materials [[buffer(3)]],const device float4 *origins [[buffer(4)]],
 device LargeGeometryProbeResult *results [[buffer(5)]],constant uint &staticCount [[buffer(6)]],uint tid [[thread_position_in_grid]]) {
    if(tid<6)results[tid]=largeGeometryProbe(origins[tid],acceleration,vertices,indices,materials,staticCount);
}
kernel void largeGeometryInstances(instance_acceleration_structure acceleration [[buffer(0)]],
 const device SceneVertex *vertices [[buffer(1)]],const device uint *indices [[buffer(2)]],
 const device SceneMaterial *materials [[buffer(3)]],const device float4 *origins [[buffer(4)]],
 device LargeGeometryProbeResult *results [[buffer(5)]],constant uint &staticCount [[buffer(6)]],uint tid [[thread_position_in_grid]]) {
    if(tid<6)results[tid]=largeGeometryProbe(origins[tid],acceleration,vertices,indices,materials,staticCount);
}
"""

do {
    guard let device=MTLCreateSystemDefaultDevice(),device.supportsRaytracing,let queue=device.makeCommandQueue() else {throw Failure("Metal ray tracing device unavailable")}
    let stride=MemoryLayout<SceneVertex>.stride,bytesPerTriangle=stride*3,chunk=GeometryPartition.trianglesPerGeometry
    let fullField=CommandLine.arguments.contains("--full-field")
    let legacySparse=CommandLine.arguments.contains("--legacy-sparse")
    try require(!(fullField && legacySparse),"Choose only one diagnostic mode")
    let bounded = !fullField && !legacySparse
    let beyondFourGiB=(1 << 32)/bytesPerTriangle+6
    let staticCount=bounded ? 3*chunk+8:beyondFourGiB+1,totalCount=staticCount+1
    let globalIDs=bounded ? [0,chunk+1,2*chunk+2,3*chunk+3,staticCount]:[0,chunk-1,chunk+3,beyondFourGiB,staticCount]
    let byteLength=totalCount*bytesPerTriangle
    try require(byteLength>(1 << 32),"Fixture does not cross 4 GiB")
    try require(device.maxBufferLength>=byteLength,"GPU maxBufferLength is too small for the 4 GiB regression")
    guard let vertices=device.makeBuffer(length:byteLength,options:.storageModeShared),
          let indices=device.makeBuffer(length:totalCount*4,options:.storageModeShared) else {throw Failure("Large fixture buffer allocation failed")}
    vertices.label="Distributed triangle field and sentinels on both sides of 4 GiB"
    // The default probe restricts each production descriptor to eight triangles
    // while retaining its actual global buffer offset. Gaps are deliberately not
    // submitted to the AS. This tests wide addresses and mapping, not full-span
    // city coverage. The original failed synthetic modes remain reproducible.
    memset(vertices.contents(),0,byteLength)
    memset(indices.contents(),0,totalCount*4)
    let vp=vertices.contents().bindMemory(to:SceneVertex.self,capacity:totalCount*3)
    let ip=indices.contents().bindMemory(to:UInt32.self,capacity:totalCount)
    func filler(_ id:Int) {
        let x = -100-Float(id%4096),y = -100-Float(id/4096)
        vp[id*3]=SceneVertex(SIMD3(x,y,0),SIMD3(0,0,1))
        vp[id*3+1]=SceneVertex(SIMD3(x+0.25,y,0),SIMD3(0,0,1))
        vp[id*3+2]=SceneVertex(SIMD3(x,y+0.25,0),SIMD3(0,0,1))
    }
    if fullField {for id in 0..<totalCount{filler(id)}}
    if bounded {for section in 0..<4 {for local in 0..<8{filler(section*chunk+local)}}}
    for (i,id) in globalIDs.enumerated() {
        let x=Float(i)*4
        vp[id*3]=SceneVertex(SIMD3(x-0.4,-0.4,0),SIMD3(0,0,1))
        vp[id*3+1]=SceneVertex(SIMD3(x+0.4,-0.4,0),SIMD3(0,0,1))
        vp[id*3+2]=SceneVertex(SIMD3(x,0.4,0),SIMD3(0,0,1))
        ip[id]=UInt32(11+i)
    }
    func buffer<T>(_ values:[T])throws->MTLBuffer {
        guard let b=values.withUnsafeBytes({device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)}) else{throw Failure("Small GPU fixture buffer allocation failed")};return b
    }
    let palette=(0..<16).map{i in SceneMaterial(SIMD3(Float(i)/16,Float(16-i)/16,0.25),roughness:0.75)}
    let materials=try buffer(palette)
    var originValues:[SIMD4<Float>]=[]
    for i in 0..<6 {
        let x:Float=i==5 ? 500:Float(i)*4
        let id:UInt32=i<5 ? UInt32(globalIDs[i]):0
        originValues.append(SIMD4<Float>(x,0,3,Float(bitPattern:id)))
    }
    let origins=try buffer(originValues)
    let shaderURL=URL(fileURLWithPath:"Sources/ArchitectureEngine/Resources/Renderer.metal")
    let source=try String(contentsOf:shaderURL,encoding:.utf8)
    let options=MTLCompileOptions();options.languageVersion = .version3_1
    // Reuse the exact production sceneIntersection overloads and structs.
    let library=try device.makeLibrary(source:source+"\n"+kernel,options:options)
    func pipeline(_ name:String)throws->MTLComputePipelineState {
        guard let f=library.makeFunction(name:name) else{throw Failure("Missing regression kernel \(name)")}
        return try device.makeComputePipelineState(function:f)
    }
    let staticPipeline=try pipeline("largeGeometryStatic"),instancePipeline=try pipeline("largeGeometryInstances")
    func build(_ descriptor:MTLAccelerationStructureDescriptor,_ label:String)throws->MTLAccelerationStructure {
        let started=Date()
        fputs("Building \(label)\n",stderr)
        let size=device.accelerationStructureSizes(descriptor:descriptor)
        guard let acceleration=device.makeAccelerationStructure(size:size.accelerationStructureSize),
              let scratch=device.makeBuffer(length:max(1,size.buildScratchBufferSize),options:.storageModePrivate),
              let command=queue.makeCommandBuffer(),let encoder=command.makeAccelerationStructureCommandEncoder() else{throw Failure("Acceleration allocation failed for \(label)")}
        acceleration.label=label
        encoder.build(accelerationStructure:acceleration,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0)
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        if let error=command.error{throw error}
        fputs("Built \(label) in \(Date().timeIntervalSince(started)) seconds\n",stderr)
        return acceleration
    }
    func probe(_ acceleration:MTLAccelerationStructure,_ pipeline:MTLComputePipelineState,children:[MTLAccelerationStructure]=[])throws->[ProbeResult] {
        guard let results=device.makeBuffer(length:6*MemoryLayout<ProbeResult>.stride,options:.storageModeShared),
              let command=queue.makeCommandBuffer(),let encoder=command.makeComputeCommandEncoder() else{throw Failure("Probe dispatch allocation failed")}
        memset(results.contents(),0,results.length)
        encoder.setComputePipelineState(pipeline);encoder.setAccelerationStructure(acceleration,bufferIndex:0)
        encoder.setBuffer(vertices,offset:0,index:1);encoder.setBuffer(indices,offset:0,index:2)
        encoder.setBuffer(materials,offset:0,index:3);encoder.setBuffer(origins,offset:0,index:4);encoder.setBuffer(results,offset:0,index:5)
        var count=UInt32(staticCount);encoder.setBytes(&count,length:4,index:6)
        for child in children{encoder.useResource(child,usage:.read)}
        encoder.dispatchThreads(MTLSize(width:6,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:6,height:1,depth:1))
        encoder.endEncoding();command.commit();command.waitUntilCompleted()
        if let error=command.error{throw error}
        return Array(UnsafeBufferPointer(start:results.contents().assumingMemoryBound(to:ProbeResult.self),count:6))
    }
    var checks=0
    func validate(_ results:[ProbeResult],dynamic:Bool)throws {
        for i in 0..<6 {
            let result=results[i],expectedHit=i<4 || (dynamic && i==4)
            checks+=1;try require(result.ids.x==(expectedHit ? 1:0),"\(dynamic ? "TLAS":"Static") sentinel \(i) hit state \(result.ids.x)")
            if !expectedHit{continue}
            checks+=1;try require(result.ids.y==UInt32(globalIDs[i]),"Global primitive normalization failed at sentinel \(i)")
            checks+=1;try require(result.ids.z==UInt32(11+i),"Material lookup failed at sentinel \(i)")
            checks+=1;try require(result.ids.w==((dynamic && i==4) ? 1:0),"Dynamic/static identity failed at sentinel \(i)")
            checks+=1;try require(abs(result.vertexDistance.w-3)<0.001,"Ray hit distance failed at sentinel \(i)")
            checks+=1;try require(abs(result.vertexDistance.x-(Float(i)*4-0.4))<0.001 && abs(result.vertexDistance.y+0.4)<0.001 && abs(result.vertexDistance.z)<0.001,"Vertex lookup failed beyond buffer boundary at sentinel \(i)")
            checks+=1;try require(simd_length(result.material-palette[11+i].albedo)<0.00001,"Material value lookup failed at sentinel \(i)")
        }
    }
    let partitionDescriptor=MTLPrimitiveAccelerationStructureDescriptor()
    let sections=GeometryPartition.descriptors(vertexBuffer:vertices,triangleCount:staticCount)
    partitionDescriptor.geometryDescriptors=sections
    checks+=1;try require(sections.count==(bounded ? 4:3),"Unexpected production geometry descriptor count")
    checks+=1;try require(sections.allSatisfy{$0.triangleCount*bytesPerTriangle<(1 << 32)},"A partition has an oversized vertex span")
    for (i,section) in sections.enumerated() {
        checks+=1;try require(section.vertexBufferOffset==i*chunk*bytesPerTriangle,"Production section offset arithmetic failed")
        checks+=1;try require(section.triangleCount==min(chunk,staticCount-i*chunk),"Production section extent arithmetic failed")
    }
    if bounded {
        checks+=1;try require(sections[3].vertexBufferOffset>(1 << 32),"The fourth descriptor must start beyond 4 GiB")
        for section in sections {section.triangleCount=8}
    }
    let partitioned=try build(partitionDescriptor,"Partitioned >4 GiB fixture")
    let staticResults=try probe(partitioned,staticPipeline)
    for (i,result) in staticResults.enumerated() {fputs("Static raw probe \(i): ids=\(result.ids), vertexDistance=\(result.vertexDistance), material=\(result.material)\n",stderr)}
    try validate(staticResults,dynamic:false)
    let tailGeometry=MTLAccelerationStructureTriangleGeometryDescriptor()
    tailGeometry.vertexBuffer=vertices;tailGeometry.vertexBufferOffset=staticCount*bytesPerTriangle
    tailGeometry.vertexStride=stride;tailGeometry.vertexFormat = .float3;tailGeometry.triangleCount=1;tailGeometry.opaque=true
    let tailDescriptor=MTLPrimitiveAccelerationStructureDescriptor();tailDescriptor.geometryDescriptors=[tailGeometry]
    let tail=try build(tailDescriptor,"Traffic tail beyond 4 GiB")
    var instances:[MTLAccelerationStructureInstanceDescriptor]=[]
    for i in 0..<2 {
        var instance=MTLAccelerationStructureInstanceDescriptor()
        instance.transformationMatrix.columns=(MTLPackedFloat3Make(1,0,0),MTLPackedFloat3Make(0,1,0),MTLPackedFloat3Make(0,0,1),MTLPackedFloat3Make(0,0,0))
        instance.options = .opaque;instance.mask=0xFF;instance.accelerationStructureIndex=UInt32(i);instances.append(instance)
    }
    let topDescriptor=MTLInstanceAccelerationStructureDescriptor()
    topDescriptor.instancedAccelerationStructures=[partitioned,tail]
    topDescriptor.instanceDescriptorBuffer=try buffer(instances);topDescriptor.instanceCount=2
    let top=try build(topDescriptor,"Static and traffic identity instances")
    let instanceResults=try probe(top,instancePipeline,children:[partitioned,tail])
    for (i,result) in instanceResults.enumerated() {fputs("TLAS raw probe \(i): ids=\(result.ids), vertexDistance=\(result.vertexDistance), material=\(result.material)\n",stderr)}
    try validate(instanceResults,dynamic:true)
    func record(_ rows:[ProbeResult])->[[String:Any]] {
        rows.enumerated().map{i,r in ["probe":i,"hit":r.ids.x,"globalPrimitive":r.ids.y,"materialID":r.ids.z,"dynamic":r.ids.w,"firstVertexAndDistance":[r.vertexDistance.x,r.vertexDistance.y,r.vertexDistance.z,r.vertexDistance.w],"material":[r.material.x,r.material.y,r.material.z,r.material.w]]}
    }
    var negative:[String:Any]=[:]
    if !bounded {do {
        let monolithic=MTLAccelerationStructureTriangleGeometryDescriptor()
        monolithic.vertexBuffer=vertices;monolithic.vertexStride=stride;monolithic.vertexFormat = .float3
        monolithic.triangleCount=staticCount;monolithic.opaque=true
        let descriptor=MTLPrimitiveAccelerationStructureDescriptor();descriptor.geometryDescriptors=[monolithic];descriptor.usage = .preferFastBuild
        let acceleration=try build(descriptor,"Legacy unpartitioned negative control")
        let rows=try probe(acceleration,staticPipeline)
        negative=["completed":true,"farSentinelMissed":rows[3].ids.x==0,"rows":record(rows),"requiredToFail":false]
    } catch {negative=["completed":false,"error":String(describing:error),"requiredToFail":false]}}
    else {negative=["completed":false,"reason":"Default bounded probe omits the original full-span synthetic controls. See --legacy-sparse / --full-field and preserved investigation evidence.","requiredToFail":false]}
    let report:[String:Any]=[
        "status":"PASS","checks":checks,"device":device.name,"vertexBufferBytes":byteLength,"staticGlobalIndexExtent":staticCount,
        "mode":bounded ? "sparseDescriptorProbe":(fullField ? "fullFieldDiagnostic":"legacySparseDiagnostic"),
        "submittedStaticTriangles":sections.reduce(0){$0+$1.triangleCount},
        "submittedSections":sections.map{["vertexBufferOffset":$0.vertexBufferOffset,"triangleCount":$0.triangleCount]},
        "trianglesPerGeometry":chunk,"geometryCount":sections.count,"sentinelGlobalPrimitiveIDs":globalIDs,
        "staticResults":record(staticResults),"instanceResults":record(instanceResults),"legacyNegativeControl":negative,
        "sources":["Renderer.metal":try digest(shaderURL),"GeometryPartition.swift":try digest(URL(fileURLWithPath:"Sources/ArchitectureEngine/GeometryPartition.swift")),"SceneTypes.swift":try digest(URL(fileURLWithPath:"Sources/ArchitectureEngine/SceneTypes.swift")),"Tests/LargeGeometryGPU/main.swift":try digest(URL(fileURLWithPath:"Tests/LargeGeometryGPU/main.swift"))],
        "elapsedSeconds":Date().timeIntervalSince(began),
        "scope":bounded ? "Partial-section coverage: actual production descriptor offsets and shader mapping, with each AS section restricted to eight real triangles. Four static sentinel rays plus a traffic tail verify vertex/material lookups beyond 4 GiB. Full city render checks are separate; this does not claim every global primitive or descriptor end was traversed.":"Original full-span synthetic diagnostic; actual production geometry partition descriptors and sceneIntersection overloads, direct GPU rays, vertex/material reads, static BLAS and traffic TLAS"
    ]
    print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
} catch {
    fputs("FAIL: \(error)\n",stderr);exit(1)
}
