import Foundation
import Metal
import simd

func require(_ condition:Bool,_ message:String) {if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}}
let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let sourceURL=CommandLine.arguments.count>1 ? URL(fileURLWithPath:CommandLine.arguments[1]):root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal")
guard let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {fatalError("Metal required")}
let options=MTLCompileOptions();options.languageVersion = .version3_1
let library=try device.makeLibrary(source:String(contentsOf:sourceURL,encoding:.utf8),options:options)
func pipeline(_ name:String)throws->MTLComputePipelineState {try device.makeComputePipelineState(function:library.makeFunction(name:name)!)}
let night=try pipeline("pathTraceNight"),nightIndexed=try pipeline("pathTraceNightIndexed")
let day=try pipeline("pathTraceDayInteriors"),dayIndexed=try pipeline("pathTraceDayInteriorsIndexed")
require(MemoryLayout<LightGrid.Header>.stride==48 && MemoryLayout<SIMD2<UInt32>>.stride==8,"Light grid GPU ABI mismatch")
func buffer<T>(_ values:[T])->MTLBuffer {values.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!}}
let normal=SIMD3<Float>(0,0,1)
let vertices=[SceneVertex(SIMD3(-500,-500,0),normal),SceneVertex(SIMD3(500,-500,0),normal),SceneVertex(SIMD3(500,500,0),normal),SceneVertex(SIMD3(-500,-500,0),normal),SceneVertex(SIMD3(500,500,0),normal),SceneVertex(SIMD3(-500,500,0),normal)]
let vb=buffer(vertices),ib=buffer([UInt32(0),0]),mb=buffer([SceneMaterial(SIMD3(0.65,0.7,0.75),roughness:0.35,metallic:0.1)])
let geometry=MTLAccelerationStructureTriangleGeometryDescriptor();geometry.vertexBuffer=vb;geometry.vertexStride=32;geometry.vertexFormat = .float3;geometry.triangleCount=2;geometry.opaque=true
let descriptor=MTLPrimitiveAccelerationStructureDescriptor();descriptor.geometryDescriptors=[geometry]
let sizes=device.accelerationStructureSizes(descriptor:descriptor),acceleration=device.makeAccelerationStructure(size:sizes.accelerationStructureSize)!,scratch=device.makeBuffer(length:sizes.buildScratchBufferSize,options:.storageModePrivate)!
let build=queue.makeCommandBuffer()!,builder=build.makeAccelerationStructureCommandEncoder()!
builder.build(accelerationStructure:acceleration,descriptor:descriptor,scratchBuffer:scratch,scratchBufferOffset:0);builder.endEncoding();build.commit();build.waitUntilCompleted();if let error=build.error {throw error}
let textureDescriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:32,height:32,mipmapped:false);textureDescriptor.storageMode = .shared;textureDescriptor.usage=[.shaderRead,.shaderWrite]
let texture=device.makeTexture(descriptor:textureDescriptor)!
func source(_ x:Float,_ y:Float,_ index:Int,range:Float=24)->SceneLight {
    SceneLight(positionRadius:SIMD4(x,y,3,0.12),directionCone:SIMD4(0,0,-1,-1),colorPower:SIMD4(0.3+Float(index%3)*0.3,0.3+Float(index%5)*0.12,0.7,8+Float(index%7)*2),parameters:SIMD4(range,0,index%3==0 ? 1:0,0))
}
var lights:[SceneLight]=[]
for x in -3...3 {for y in -2...2 {lights.append(source(Float(x)*64+16,Float(y)*64+10,lights.count))}}
for i in 0..<15 {lights.append(source(Float(i%5)-2,Float(i/5)-1,lights.count,range:20))}
for i in 0..<7 {lights.append(source(64+Float(i)-3,1,lights.count,range:20))}

func render(lights:[SceneLight],grid:LightGrid,indexed:Bool,nightMode:Bool,x:Float,sobol:Bool,activeCount:Int?=nil,reversed:Bool=false)throws->[SIMD4<Float>] {
    let lb=buffer(lights.isEmpty ? [source(0,0,0)]:lights),ranges=buffer(grid.ranges.isEmpty ? [SIMD2<UInt32>(0,0)]:grid.ranges)
    var ids=grid.indices
    if reversed {for r in grid.ranges where r.y>1 {ids.replaceSubrange(Int(r.x)..<Int(r.x+r.y),with:ids[Int(r.x)..<Int(r.x+r.y)].reversed())}}
    let indices=buffer(ids.isEmpty ? [UInt32(0)]:ids)
    var header=grid.header
    var u=FrameUniforms(origin:SIMD4(x,0,5,1),right:SIMD4(0.5,0,0,0),up:SIMD4(0,0.5,0,sobol ? 1:0),forward:SIMD4(0,0,-1,0),sunDirection:SIMD4(-0.4,0.8,1,Float(activeCount ?? lights.count)),sunColor:SIMD4(3.5,3.2,2.7,nightMode ? 1:0),viewport:SIMD4(32,32,0,0),settings:SIMD4(1,3,0.009,1))
    let c=queue.makeCommandBuffer()!
    for sample in 0..<32 {
        u.viewport.z=UInt32(sample);u.viewport.w=UInt32(128+sample)
        let e=c.makeComputeCommandEncoder()!;e.setComputePipelineState(nightMode ? (indexed ? nightIndexed:night):(indexed ? dayIndexed:day));e.setTexture(texture,index:0)
        e.setBytes(&u,length:128,index:0);e.setBuffer(vb,offset:0,index:1);e.setBuffer(ib,offset:0,index:2);e.setBuffer(mb,offset:0,index:3);e.setAccelerationStructure(acceleration,bufferIndex:4);e.setBuffer(lb,offset:0,index:5)
        if indexed {e.setBytes(&header,length:48,index:6);e.setBuffer(ranges,offset:0,index:7);e.setBuffer(indices,offset:0,index:8)}
        e.dispatchThreads(MTLSize(width:32,height:32,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
    }
    c.commit();c.waitUntilCompleted();if let error=c.error {throw error}
    var result=[SIMD4<Float>](repeating:.zero,count:1024)
    texture.getBytes(&result,bytesPerRow:32*16,from:MTLRegionMake2D(0,0,32,32),mipmapLevel:0)
    require(result.allSatisfy{$0.x.isFinite && $0.y.isFinite && $0.z.isFinite},"Nonfinite indexed lighting")
    return result
}
var comparisons=0,largestDifference:Float=0
for nightMode in [true,false] {
    let active=nightMode ? lights:lights.filter{$0.parameters.z>0.5}
    let grid=LightGrid(lights:active)
    require(grid.enabled,"Test grid unexpectedly disabled")
    let boundary=grid.origin.x+ceil(-grid.origin.x/grid.cellSize)*grid.cellSize
    for sobol in [false,true] {for x:Float in [0,boundary,boundary-2*grid.cellSize,320] {
        let a=try render(lights:active,grid:grid,indexed:false,nightMode:nightMode,x:x,sobol:sobol)
        let b=try render(lights:active,grid:grid,indexed:true,nightMode:nightMode,x:x,sobol:sobol)
        for (u,v) in zip(a,b) {largestDifference=max(largestDifference,simd_reduce_max(abs(u-v)))}
        require(a==b,"Indexed/linear light results differ at camera x=\(x), night=\(nightMode), Sobol=\(sobol)")
        comparisons += a.count
    }}
}
let grid=LightGrid(lights:lights)
let reference=try render(lights:lights,grid:grid,indexed:false,nightMode:true,x:0,sobol:true)
let reordered=try render(lights:lights,grid:grid,indexed:true,nightMode:true,x:0,sobol:true,reversed:true)
require(reference != reordered,"Negative control failed: reservoir fixture must detect changed candidate order")
let disabled=LightGrid(lights:lights,maxCellCount:0)
require(!disabled.enabled,"Disabled fallback fixture did not disable grid")
let fallback=try render(lights:lights,grid:disabled,indexed:true,nightMode:true,x:0,sobol:true)
require(reference==fallback,"Disabled grid did not retain exact linear lighting")
let prefix=try render(lights:lights,grid:grid,indexed:false,nightMode:true,x:0,sobol:true,activeCount:10)
let indexedPrefix=try render(lights:lights,grid:grid,indexed:true,nightMode:true,x:0,sobol:true,activeCount:10)
require(prefix==indexedPrefix,"Indexed light access ignored the active buffer count")
print("PASS: \(comparisons) actual day/night GPU pixels are bit-identical for indexed/linear lights, cell boundaries, outside-grid rays, and both samplers (maximum difference \(largestDifference))")
print("PASS: actual CPU grid helper + 48-byte GPU ABI, filtered interior grid, disabled fallback and active-count guard")
print("PASS: reversed-order negative control changes reservoir results and is detected")
