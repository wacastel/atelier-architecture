import Foundation
import Metal
import simd

// Executes the actual temporal and three spatial GPU passes. The rough plane
// receives changing light, whereas its projection/reflection controls must keep
// exact current coverage. Reference values are analytic per-material radiance.
func validateAdlerReconstruction(device:MTLDevice,queue:MTLCommandQueue,root:URL)throws {
    let width=64,height=48,count=width*height,region=MTLRegionMake2D(0,0,width,height)
    let source=try String(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/Denoise.metal"),encoding:.utf8)
    let options=MTLCompileOptions();options.languageVersion = .version3_1
    let library=try device.makeLibrary(source:source,options:options)
    let newGuard=" || fract(materialGuide) == 0.25f"
    require(source.components(separatedBy:newGuard).count==2,"Diffuse-lighting temporal negative-control hook changed")
    let legacy=try device.makeLibrary(source:source.replacingOccurrences(of:newGuard,with:""),options:options)
    func pipelines(_ lib:MTLLibrary)throws->[MTLComputePipelineState] {
        try ["temporalResolve","spatialFilter"].map{try device.makeComputePipelineState(function:lib.makeFunction(name:$0)!)}
    }
    let currentPipes=try pipelines(library),legacyPipes=try pipelines(legacy)
    func texture(_ values:[SIMD4<Float>])->MTLTexture {
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        let result=device.makeTexture(descriptor:descriptor)!
        values.withUnsafeBytes{result.replace(region:region,mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:width*16)}
        return result
    }
    func read(_ texture:MTLTexture)->[SIMD4<Float>] {
        var values=[SIMD4<Float>](repeating:.zero,count:count)
        values.withUnsafeMutableBytes{texture.getBytes($0.baseAddress!,bytesPerRow:width*16,from:region,mipmapLevel:0)}
        return values
    }
    func random(_ value:UInt32)->Float {
        var x=value;x ^= x>>16;x = x &* 0x7feb352d;x ^= x>>15;x = x &* 0x846ca68b;x ^= x>>16
        return Float(x>>8)/16_777_216
    }
    typealias Result=(raw:[SIMD4<Float>],truth:[SIMD4<Float>],history:[SIMD4<Float>],filtered:[SIMD4<Float>])
    func render(flag:Float,frame:Int,pipes:[MTLComputePipelineState])throws->Result {
        var radiance=[SIMD4<Float>](repeating:.zero,count:count),world=radiance,normal=radiance,albedo=radiance,truth=radiance,old=radiance
        for y in 0..<height {for x in 0..<width {
            let i=y*width+x,right=x>=width/2
            let point=SIMD3<Float>((2*(Float(x)+0.5)/Float(width)-1)*5,(1-2*(Float(y)+0.5)/Float(height))*3.75,5)
            world[i]=SIMD4(point,flag<0 ? flag:Float(right ? 1:0)+flag)
            normal[i]=SIMD4(0,0,-1,simd_length(point))
            albedo[i]=SIMD4(SIMD3(repeating:right ? 0.7:0.1),0.8)
            let light:Float=(right ? 0.55:0.12)+Float(frame)*(right ? 0.017:0.012)
            let color=SIMD3<Float>(light,light*0.82,light*0.65)
            let perturbation=(random(UInt32(i+frame*197633))-0.5)*0.08
            truth[i]=SIMD4(color,1);radiance[i]=SIMD4(color+SIMD3(repeating:perturbation),normal[i].w)
            // Compatible stale lighting survives the original variance clamp,
            // so omitting the new temporal guard measurably blends old color.
            old[i]=SIMD4(color+SIMD3(0.012,0.006,-0.003),16)
        }}
        let raw=texture(radiance),worldTex=texture(world),normalTex=texture(normal),albedoTex=texture(albedo),previous=texture(old)
        let history=texture(truth),filters=[texture(truth),texture(truth)]
        var u=TemporalUniforms(previousOrigin:.zero,previousRight:SIMD4(1,0,0,0),previousUp:SIMD4(0,0.75,0,0),previousForward:SIMD4(0,0,1,0),currentOrigin:SIMD4(0,0,0,1),sizeFlags:SIMD4(UInt32(width),UInt32(height),1,1),settings:SIMD4(32,8,1,1.5/Float(height)))
        let command=queue.makeCommandBuffer()!
        func dispatch(_ pipe:MTLComputePipelineState,_ textures:[MTLTexture]) {
            let e=command.makeComputeCommandEncoder()!;e.setComputePipelineState(pipe)
            for (i,t) in textures.enumerated(){e.setTexture(t,index:i)}
            e.setBytes(&u,length:MemoryLayout<TemporalUniforms>.stride,index:0)
            e.dispatchThreads(MTLSize(width:width,height:height,depth:1),threadsPerThreadgroup:MTLSize(width:8,height:8,depth:1));e.endEncoding()
        }
        dispatch(pipes[0],[raw,worldTex,normalTex,albedoTex,previous,worldTex,normalTex,history])
        for (i,step) in [1,2,4].enumerated() {
            u.settings.z=Float(step)
            dispatch(pipes[1],[i==0 ? history:filters[(i-1)%2],worldTex,normalTex,albedoTex,filters[i%2]])
        }
        command.commit();command.waitUntilCompleted();if let error=command.error{throw error}
        return (radiance,truth,read(history),read(filters[0]))
    }
    func sameRGB(_ a:[SIMD4<Float>],_ b:[SIMD4<Float>])->Bool {zip(a,b).allSatisfy{$0.xyz==$1.xyz}}
    func rms(_ a:[SIMD4<Float>],_ b:[SIMD4<Float>])->Double {
        sqrt(zip(a,b).reduce(0.0){$0+Double(simd_length_squared($1.0.xyz-$1.1.xyz))}/Double(count*3))
    }
    let a=try render(flag:0.25,frame:0,pipes:currentPipes),b=try render(flag:0.25,frame:1,pipes:currentPipes)
    require(sameRGB(a.history,a.raw) && sameRGB(b.history,b.raw),"Changing diffuse illumination inherited stale color")
    let rawError=rms(a.raw,a.truth),filteredError=rms(a.filtered,a.truth)
    require(filteredError<rawError*0.65,"Diffuse spatial filtering failed to reduce sampling error: \(rawError) -> \(filteredError)")
    let rawResidual=zip(a.raw,b.raw).map{$1-$0},filteredResidual=zip(a.filtered,b.filtered).map{$1-$0},trueResidual=zip(a.truth,b.truth).map{$1-$0}
    let rawTemporal=rms(rawResidual,trueResidual),filteredTemporal=rms(filteredResidual,trueResidual)
    require(filteredTemporal<rawTemporal*0.65,"Diffuse spatial filtering failed to reduce temporal residual")
    for y in 0..<height {for x in [width/2-1,width/2] {
        let i=y*width+x
        require(a.filtered[i].xyz==a.raw[i].xyz,"Reactive spatial filtering changed contrasting material-edge coverage")
    }}
    for right in [false,true] {
        var sum=SIMD3<Float>.zero,n:Float=0
        // Measure bias added by filtering, separately from the finite raw
        // sample set's nonzero mean (already included in the truth RMSE).
        for y in 0..<height {for x in 0..<width where (x>=width/2)==right {let i=y*width+x;sum+=a.filtered[i].xyz-a.raw[i].xyz;n+=1}}
        require(simd_length(sum/n)<0.001,"Reactive spatial filtering biased panel illumination: \(sum/n)")
    }
    let stale=try render(flag:0.25,frame:0,pipes:legacyPipes)
    let staleError=rms(stale.history,a.raw)
    require(staleError>0.005,"Negative control did not expose stale temporal illumination: \(staleError)")
    // The old full reactive classification reproduces the actual no-benefit
    // failure. Direct projection and sharp reflections must retain this policy.
    let bypass=try render(flag:0.875,frame:0,pipes:currentPipes)
    require(sameRGB(bypass.history,bypass.raw) && sameRGB(bypass.filtered,bypass.raw),"Screen/reflection/traffic coverage was blurred")
    var oldComponents=0
    for flag:Float in [-1,0,0.125,0.5,0.75,0.875] {
        let now=try render(flag:flag,frame:0,pipes:currentPipes),before=try render(flag:flag,frame:0,pipes:legacyPipes)
        require(now.history==before.history && now.filtered==before.filtered,"Existing guide class changed under new diffuse policy: \(flag)")
        oldComponents+=count*8
    }
    print("PASS: GPU animated-diffuse spatial RMSE \(rawError) -> \(filteredError), temporal residual \(rawTemporal) -> \(filteredTemporal); exact current temporal color/material-edge coverage; missing-guard negative control \(staleError)")
    print("PASS: Strong reactive bypass remains exact; \(oldComponents) legacy guide RGBA components unchanged by diffuse policy")
}
