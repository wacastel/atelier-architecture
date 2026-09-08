import Foundation
import Metal
import simd

let root=URL(fileURLWithPath:#filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
extension Bundle { static var module:Bundle { Bundle(url:root.appendingPathComponent("Sources/ArchitectureEngine"))! } }
func require(_ value:Bool,_ message:String) {if !value {fputs("FAIL: \(message)\n",stderr);exit(1)}}
let builder=EiffelBuilder();builder.adlerPlanetarium()
let scene=builder.scene,c=AdlerLayout.center
require(scene.triangleCount>25000 && scene.triangleCount<180000,"Adler triangle budget \(scene.triangleCount)")
require(scene.materialIndices.count*3==scene.vertices.count && scene.materialIndices.allSatisfy{Int($0)<scene.materials.count},"Invalid triangle/material buffers")
require(MemoryLayout<FrameUniforms>.stride==144 && MemoryLayout<FrameUniforms>.offset(of:\.animation)==128,"Frame animation ABI mismatch")
var top:Float=0
for v in scene.vertices {
    require(v.position.x.isFinite && v.position.y.isFinite && v.position.z.isFinite,"Nonfinite geometry")
    require(abs(simd_length(v.normal.xyz)-1)<0.00001,"Nonunit geometry normal")
    require(v.position.x>2377 && v.position.x<2495 && v.position.z>1338 && v.position.z<1446,"Adler exceeded mapped neighborhood")
    top=max(top,v.position.y)
}
require(abs(top-28.708)<0.04,"Historic dome top changed: \(top)")
let show=scene.materials.firstIndex{$0.properties.z==17}!
for (index,material) in scene.materialIndices.enumerated() where material==show {
    for j in 0..<3 {
        let v=scene.vertices[index*3+j]
        require(abs(simd_distance(v.position.xyz,AdlerLayout.projectionCenter)-10.5)<0.001,"Projection shell differs from published21m diameter")
        require(simd_dot(v.normal.xyz,AdlerLayout.projectionCenter-v.position.xyz)>10.49,"Projection shell must face inward")
    }
}
let world=CollisionWorld(scene:scene)
let route=[AdlerLayout.entrance,c+SIMD3(-16,4.55,0),AdlerLayout.welcome,c+SIMD3(-14,4.55,-10),c+SIMD3(-5,4.55,-16),c+SIMD3(-14,4.55,-10),AdlerLayout.theaterDoor,c+SIMD3(-8,4.55,-4.4),c+SIMD3(-8,4.55,0),AdlerLayout.theaterCenter]
for (a,b) in zip(route,route.dropFirst()) {
    let count=Int(ceil(simd_distance(a,b)/0.10))
    for i in 0..<count {
        let p=simd_mix(a,b,SIMD3(repeating:Float(i)/Float(count))),q=simd_mix(a,b,SIMD3(repeating:Float(i+1)/Float(count)))
        require(world.canMove(from:p,to:q),"Blocked interior route at \(p-c) toward \(q-c)")
        require(world.distance(origin:p,direction:SIMD3(0,-1,0),maximum:2) != nil,"Unsupported route at \(p-c)")
    }
}
require(scene.lights.filter{$0.parameters.z>0.5}.count>=25,"Interior lights must remain active by day")
print("PASS: Adler \(scene.triangleCount) triangles, \(scene.lights.count) fixtures; mapped envelope, unit normals, published21m inward shell,144B uniform ABI, entrance/gallery/theater route")
if CommandLine.arguments.contains("--gpu") || CommandLine.arguments.contains("--render") {
    guard let device=MTLCreateSystemDefaultDevice() else {fatalError("Metal required")}
    let renderer=try MetalRenderer(scene:scene,device:device)
    let pose=CameraPose(position:AdlerLayout.theaterCenter,target:AdlerLayout.theaterLook,fov:88)
    let options=RenderOptions(lighting:2)
    renderer.frameSeed=0;renderer.setSceneTime(0)
    let zero=try renderer.renderOffscreen(pose:pose,options:options,width:192,height:128,samples:16)
    renderer.setSceneTime(35);require(renderer.sampleCount==0,"Changed show time did not invalidate stationary accumulation")
    renderer.frameSeed=0
    let later=try renderer.renderOffscreen(pose:pose,options:options,width:192,height:128,samples:16)
    require(zero != later,"Dome show did not advance")
    let count=renderer.sampleCount;renderer.setSceneTime(35)
    require(renderer.sampleCount==count,"Paused same-time call invalidated accumulation")
    renderer.setSceneTime(0);renderer.frameSeed=0
    let rewind=try renderer.renderOffscreen(pose:pose,options:options,width:192,height:128,samples:16)
    require(zero==rewind,"Dome rewind was not exact")
    renderer.setSceneTime(180);renderer.frameSeed=0
    let loop=try renderer.renderOffscreen(pose:pose,options:options,width:192,height:128,samples:16)
    require(zero==loop,"Dome180-second loop was not exact")
    renderer.setSceneTime(-145);require(renderer.uniforms(pose:pose,options:options).animation.x==35,"Negative show time not normalized")
    renderer.setSceneTime(1e200);require(renderer.uniforms(pose:pose,options:options).animation.x.isFinite,"Huge finite show time overflowed")
    print("PASS: Actual renderer scene-time advancement, stationary invalidation, exact pause/rewind/loop and bounded negative/huge clocks")
    // Actual center-ray guides: nearby relit seats/floor reject history only
    // while the show advances; a distant mirror catches the reflected screen.
    var probeScene=SceneData();probeScene.materials=[SceneMaterial(SIMD3(0.4,0.4,0.4)),SceneMaterial(SIMD3(1,1,1),roughness:0.022,metallic:1),scene.materials[show],SceneMaterial(SIMD3(0.4,0.4,0.4),roughness:0.8,metallic:1),SceneMaterial(SIMD3(0.4,0.4,0.4),emission:0.3),SceneMaterial(SIMD3(0.4,0.4,0.4),roughness:0.2),SceneMaterial(SIMD3(1,1,1),transmission:0.95)]
    func quad(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ d:SIMD3<Float>,_ e:SIMD3<Float>,_ n:SIMD3<Float>,_ m:UInt32) {
        probeScene.vertices += [SceneVertex(a,n),SceneVertex(b,n),SceneVertex(d,n),SceneVertex(a,n),SceneVertex(d,n),SceneVertex(e,n)]
        probeScene.materialIndices += [m,m]
    }
    quad(c+SIMD3(-200,2.8,-200),c+SIMD3(200,2.8,-200),c+SIMD3(200,2.8,200),c+SIMD3(-200,2.8,200),SIMD3(0,1,0),0)
    quad(c+SIMD3(-100,3,-10),c+SIMD3(-100,3,10),c+SIMD3(-100,12,10),c+SIMD3(-100,12,-10),SIMD3(1,0,0),1)
    quad(c+SIMD3(100,3,-10),c+SIMD3(100,3,10),c+SIMD3(100,12,10),c+SIMD3(100,12,-10),SIMD3(1,0,0),1)
    quad(c+SIMD3(-100,3,30),c+SIMD3(-100,3,40),c+SIMD3(-100,12,40),c+SIMD3(-100,12,30),SIMD3(1,0,0),1)
    quad(c+SIMD3(2,3,-8),c+SIMD3(2,3,8),c+SIMD3(2,12,8),c+SIMD3(2,12,-8),SIMD3(-1,0,0),2)
    for (x,m) in [(-7,3),(-3,4),(1,5),(5,6)] {
        let x=Float(x)
        quad(c+SIMD3(x-1,3.1,9),c+SIMD3(x+1,3.1,9),c+SIMD3(x+1,3.1,11),c+SIMD3(x-1,3.1,11),SIMD3(0,1,0),UInt32(m))
    }
    let probe=try MetalRenderer(scene:probeScene,device:device)
    try probe.resize(width:1,height:1)
    let source=try String(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Renderer.metal"),encoding:.utf8)
    let compile=MTLCompileOptions();compile.languageVersion = .version3_1
    let library=try device.makeLibrary(source:source,options:compile)
    // The closest retained polar star must have a circular angular footprint,
    // not narrow longitude wedges. Sample a small geodesic ring around the
    // actual hashed star using the production projection function on the GPU.
    func bits(_ input:UInt32)->UInt32 {var x=input;x ^= x>>16;x = x &* 0x7feb352d;x ^= x>>15;x = x &* 0x846ca68b;return x ^ (x>>16)}
    let starHash=bits(13+97*193+7717)
    let starLongitude=(Float(13)+Float((starHash>>8)&255)/255)*(2*Float.pi/96)-Float.pi
    let starY=(Float(47)+Float((starHash>>16)&255)/255)*(2/Float(48))-1
    let starHorizontal=sqrt(1-starY*starY)
    let starDirection=SIMD3(cos(starLongitude)*starHorizontal,starY,sin(starLongitude)*starHorizontal)
    let starRight=simd_normalize(simd_cross(starDirection,SIMD3(0,1,0))),starUp=simd_cross(starRight,starDirection)
    let starRing=(0..<128).map { i->SIMD4<Float> in
        let angle=Float(i)*2*Float.pi/128,offset:Float=0.0012
        return SIMD4(starDirection*cos(offset)+(starRight*cos(angle)+starUp*sin(angle))*sin(offset),0)
    }
    func polarVariation(_ shader:String)throws->Float {
        let code=shader+"""
        kernel void adlerPolarProbe(const device float4 *directions [[buffer(0)]],device float4 *values [[buffer(1)]],uint i [[thread_position_in_grid]]) {
            values[i]=float4(planetariumRadiance(adlerProjectionCenter+directions[i].xyz*10.5f,0.005f,0),1);
        }
        """
        let lib=try device.makeLibrary(source:code,options:compile)
        let pipe=try device.makeComputePipelineState(function:lib.makeFunction(name:"adlerPolarProbe")!)
        let input=device.makeBuffer(bytes:starRing,length:starRing.count*16,options:.storageModeShared)!,output=device.makeBuffer(length:starRing.count*16,options:.storageModeShared)!
        let command=probe.queue.makeCommandBuffer()!,e=command.makeComputeCommandEncoder()!
        e.setComputePipelineState(pipe);e.setBuffer(input,offset:0,index:0);e.setBuffer(output,offset:0,index:1)
        e.dispatchThreads(MTLSize(width:starRing.count,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:32,height:1,depth:1));e.endEncoding();command.commit();command.waitUntilCompleted();if let error=command.error{throw error}
        let values=output.contents().bindMemory(to:SIMD4<Float>.self,capacity:starRing.count)
        let luminances=(0..<starRing.count).map{simd_dot(values[$0].xyz-SIMD3(0.0025,0.004,0.014),SIMD3(0.2126,0.7152,0.0722))}
        require(luminances.allSatisfy{$0.isFinite && $0>=0},"Polar-star probe emitted invalid radiance")
        return (luminances.max()!-luminances.min()!)/(luminances.reduce(0,+)/Float(luminances.count))
    }
    let polar=try polarVariation(source)
    require(polar<0.10,"Polar star lost circular angular footprint: \(polar)")
    // Keep the legacy defect as a self-contained negative control, so normal
    // fixture runs do not depend on an untracked previous shader copy.
    let legacyStarLoop="""
        for(int dy=-1;dy<=1;++dy) {for(int dx=-1;dx<=1;++dx) {
            int2 k=cell+int2(dx,dy);k.x=(k.x%96+96)%96;
            uint h=hashBits(uint(k.x)+uint(k.y+50)*193u+7717u);
            if(k.y<0 || k.y>=48 || (h&1u)==0u)continue;
            float2 jitter=float2(float((h>>8)&255u),float((h>>16)&255u))/255.0f;
            float2 delta=float2(cell+int2(dx,dy))+jitter-uv;
            float2 radians=delta*float2(2*PI/96,(2.0f/48.0f)/max(0.12f,cos(latitude)));
            radians.x*=max(0.15f,cos(latitude));
            float magnitude=float((h>>24)&63u)/63.0f;
            float brightFraction=magnitude*magnitude*magnitude;
            float radius=0.00065f+brightFraction*0.0016f;
            float width=sqrt(radius*radius+angular*angular*0.32f);
            float star=exp(-dot(radians,radians)/(width*width))*radius*radius/(width*width);
            float brightness=0.32f+brightFraction*2.5f;
            color+=mix(float3(0.68f,0.79f,1),float3(1,0.86f,0.66f),float(h&63u)/63.0f)*star*brightness;
        }}
    """
    let polarStart=source.range(of:"    // A longitude/latitude tangent approximation")!.lowerBound
    let polarEnd=source.range(of:"    // Eight original line constellations")!.lowerBound
    var negative=source
    negative.replaceSubrange(polarStart..<polarEnd,with:legacyStarLoop+"\n")
    if let flag=CommandLine.arguments.firstIndex(of:"--polar-baseline"),flag+1<CommandLine.arguments.count {
        negative=try String(contentsOfFile:CommandLine.arguments[flag+1],encoding:.utf8)
    }
    let oldPolar=try polarVariation(negative)
    require(oldPolar>0.5,"Polar negative control failed to reproduce angular slivers: \(oldPolar)")
    print("PASS: GPU polar-star angular variation \(polar), legacy tangent-space negative control \(oldPolar)")
    let guidePipeline=try device.makeComputePipelineState(function:library.makeFunction(name:"primarySurface")!)
    func guide(_ camera:CameraPose,moving:Bool)throws->Float {
        let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:1,height:1,mipmapped:false);desc.storageMode = .shared;desc.usage=[.shaderRead,.shaderWrite]
        let textures=(0..<3).map{_ in device.makeTexture(descriptor:desc)!}
        var u=probe.uniforms(pose:camera,options:RenderOptions());u.viewport=SIMD4(1,1,0,0);u.animation=SIMD4(35,moving ? 1:0,0,0)
        let command=probe.queue.makeCommandBuffer()!,e=command.makeComputeCommandEncoder()!
        e.setComputePipelineState(guidePipeline);e.setBytes(&u,length:144,index:0)
        e.setBuffer(probe.vertexBuffer,offset:0,index:1);e.setBuffer(probe.indexBuffer,offset:0,index:2);e.setBuffer(probe.materialBuffer,offset:0,index:3);e.setAccelerationStructure(probe.accelerationStructure,bufferIndex:4)
        for (i,t) in textures.enumerated(){e.setTexture(t,index:i)}
        e.dispatchThreads(MTLSize(width:1,height:1,depth:1),threadsPerThreadgroup:MTLSize(width:1,height:1,depth:1));e.endEncoding();command.commit();command.waitUntilCompleted();if let error=command.error{throw error}
        var result=SIMD4<Float>.zero;textures[0].getBytes(&result,bytesPerRow:16,from:MTLRegionMake2D(0,0,1,1),mipmapLevel:0)
        return result.w-floor(result.w)
    }
    let mirror=CameraPose(position:c+SIMD3(-4,6,0),target:c+SIMD3(-100,6,0))
    let near=CameraPose(position:c+SIMD3(-4,6,0),target:c+SIMD3(-4,2.8,0))
    let far=CameraPose(position:c+SIMD3(100,8,30),target:c+SIMD3(100,2.8,30))
    let behind=CameraPose(position:c+SIMD3(104,6,0),target:c+SIMD3(100,6,0))
    let outside=CameraPose(position:c+SIMD3(-4,6,35),target:c+SIMD3(-100,6,35))
    require(try guide(mirror,moving:true)==0.875,"Distant reflected show retained stale history")
    require(try guide(mirror,moving:false)==0.125,"Paused mirror did not retain polished guide")
    require(try guide(near,moving:true)==0.25 && guide(near,moving:false)==0,"Local rough diffuse lighting must reject temporal history only while advancing")
    let directScreen=CameraPose(position:c+SIMD3(-4,6,0),target:c+SIMD3(2,6,0))
    require(try guide(directScreen,moving:true)==0.875,"Direct animated projection lost exact current coverage")
    for x:Float in [-7,-3,1,5] {
        let camera=CameraPose(position:c+SIMD3(x,7,10),target:c+SIMD3(x,3.1,10))
        require(try guide(camera,moving:true)==0.875,"Nearby rough metal/emitter/smooth dielectric/transmitted floor must retain full coverage bypass at x=\(x)")
    }
    require(try guide(far,moving:true)==0,"Unrelated distant surface lost history")
    require(try guide(behind,moving:true)==0.125 && guide(outside,moving:true)==0.125,"Mirror rays pointing away from or outside the projection bounds lost history")
    print("PASS: Actual local reactive guides for theater lighting and100m mirror reflection; unrelated, behind/outside bounds and paused surfaces retain their guides")
    try validateAdlerReconstruction(device:device,queue:probe.queue,root:root)
    if let flag=CommandLine.arguments.firstIndex(of:"--baseline"),flag+1<CommandLine.arguments.count {
        let old=try device.makeLibrary(source:String(contentsOfFile:CommandLine.arguments[flag+1],encoding:.utf8),options:compile)
        // Reuse exactly one AS/geometry/light stream and animation.zero. Compare
        // primary paths away from the new show, including old ground/sky math.
        let cameras=[CameraPose(position:c+SIMD3(100,8,30),target:c+SIMD3(100,2.8,30)),CameraPose(position:c+SIMD3(100,8,30),target:c+SIMD3(100,20,31))]
        var components=0
        func trace(_ lib:MTLLibrary,_ camera:CameraPose,_ night:Bool)throws->[SIMD4<Float>] {
            let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:24,height:16,mipmapped:false);desc.storageMode = .shared;desc.usage=[.shaderRead,.shaderWrite]
            let tex=device.makeTexture(descriptor:desc)!,pipe=try device.makeComputePipelineState(function:lib.makeFunction(name:night ? "pathTraceNight":"pathTrace")!)
            let command=probe.queue.makeCommandBuffer()!
            for sample in 0..<8 {
                var u=probe.uniforms(pose:camera,options:RenderOptions(lighting:night ? 2:0));u.viewport=SIMD4(24,16,UInt32(sample),UInt32(100+sample));u.animation = .zero
                let e=command.makeComputeCommandEncoder()!;e.setComputePipelineState(pipe);e.setBytes(&u,length:144,index:0)
                e.setBuffer(probe.vertexBuffer,offset:0,index:1);e.setBuffer(probe.indexBuffer,offset:0,index:2);e.setBuffer(probe.materialBuffer,offset:0,index:3);e.setAccelerationStructure(probe.accelerationStructure,bufferIndex:4);e.setBuffer(probe.lightBuffer,offset:0,index:5);e.setTexture(tex,index:0)
                e.dispatchThreads(MTLSize(width:24,height:16,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
            }
            command.commit();command.waitUntilCompleted();if let error=command.error{throw error}
            var pixels=[SIMD4<Float>](repeating:.zero,count:24*16);tex.getBytes(&pixels,bytesPerRow:24*16,from:MTLRegionMake2D(0,0,24,16),mipmapLevel:0);return pixels
        }
        for camera in cameras {for night in [false,true] {
            let a=try trace(library,camera,night),b=try trace(old,camera,night)
            require(a==b,"Animation.zero changed controlled legacy hit/miss trace")
            components+=a.count*4
        }}
        print("PASS: \(components) RGBA/depth values bit-identical to pre-Adler shader at animation.zero, day/night hit/miss paths")
    }
    if let flag=CommandLine.arguments.firstIndex(of:"--render"),flag+1<CommandLine.arguments.count {
        let folder=URL(fileURLWithPath:CommandLine.arguments[flag+1]);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let proofs:[(String,CameraPose,Double,Int)]=[
            ("exterior-day",CameraPose(position:c+SIMD3(-85,28,45),target:c+SIMD3(0,11,0),fov:58),0,0),
            ("exterior-night",CameraPose(position:c+SIMD3(-85,28,45),target:c+SIMD3(0,11,0),fov:58),0,2),
            ("welcome",CameraPose(position:AdlerLayout.entrance,target:AdlerLayout.welcome,fov:72),0,0),
            ("theater-0",pose,0,2),("theater-35",pose,35,2),("theater-90",pose,90,2)]
        for (name,p,t,lighting) in proofs {
            renderer.setSceneTime(t)
            let image=try renderer.renderOffscreen(pose:p,options:RenderOptions(lighting:lighting),width:1200,height:800,samples:64)
            try writePNG(image,width:1200,height:800,to:folder.appendingPathComponent(name+".png"))
        }
    }
}
