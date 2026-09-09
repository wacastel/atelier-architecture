import Foundation
import Metal
import AppKit
import CryptoKit
import simd

let root=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let output=URL(fileURLWithPath:ProcessInfo.processInfo.environment["ATELIER_DIRECT_PRESENTATION_OUTPUT"] ?? "output/direct-presentation-validation",relativeTo:root).standardizedFileURL
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
func hash(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
let names=["Renderer.metal","Denoise.metal","Raster.metal","DirectRay.metal"]
func inventory()throws->[String:String] {try Dictionary(uniqueKeysWithValues:names.map{($0,hash(try Data(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/\($0)"))))})}
let before=try inventory()
guard CommandLine.arguments.count==2,let device=MTLCreateSystemDefaultDevice(),let queue=device.makeCommandQueue() else {fatalError("Expected legacy source path and Metal device")}
let legacySource=try String(contentsOfFile:CommandLine.arguments[1],encoding:.utf8)
let source=try names.map{try String(contentsOf:root.appendingPathComponent("Sources/ArchitectureEngine/Resources/\($0)"),encoding:.utf8)}.joined(separator:"\n")
let options=MTLCompileOptions();options.languageVersion = .version3_1
let library=try device.makeLibrary(source:source,options:options)
let legacy=try device.makeLibrary(source:legacySource,options:options)
func pipeline(_ name:String,_ library:MTLLibrary)throws->MTLRenderPipelineState {
    let desc=MTLRenderPipelineDescriptor();desc.vertexFunction=library.makeFunction(name:"fullscreenVertex")
    desc.fragmentFunction=library.makeFunction(name:name);desc.colorAttachments[0].pixelFormat = .bgra8Unorm
    return try device.makeRenderPipelineState(descriptor:desc)
}
let plain=try pipeline("presentFragment",library),oldPlain=try pipeline("presentFragment",legacy)
let focused=try pipeline("focusedPresentFragment",library),oldFocused=try pipeline("focusedPresentFragment",legacy)
let direct=try pipeline("directPresentFragment",library),directFocused=try pipeline("directFocusedPresentFragment",library)
let width=192,height=128
var frame=FrameUniforms(origin:.zero,right:SIMD4(1,0,0,0),up:SIMD4(0,1,0,0),forward:SIMD4(0,0,1,0),sunDirection:.zero,sunColor:.zero,
                        viewport:SIMD4(UInt32(width),UInt32(height),0,0),settings:SIMD4(1,3,0,0))
var checks=0,failures=[String](),results=[[String:Any]]()
func check(_ value:Bool,_ message:String) {checks+=1;if !value {failures.append(message);fputs("FAIL: \(message)\n",stderr)}}
func texture(_ pixels:[SIMD4<Float>])throws->MTLTexture {
    let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba32Float,width:width,height:height,mipmapped:false)
    desc.storageMode = .shared;desc.usage = [.shaderRead]
    guard let result=device.makeTexture(descriptor:desc) else {fatalError("Input texture unavailable")}
    pixels.withUnsafeBytes {result.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:width*16)}
    return result
}
let volumes:[SIMD4<Float>]=[SIMD4(1,0,0,0),SIMD4(0,-100,5,0),SIMD4(100,100,100,0)]
let volumeBuffer=volumes.withUnsafeBytes{device.makeBuffer(bytes:$0.baseAddress!,length:$0.count,options:.storageModeShared)!}
func render(_ input:MTLTexture,_ state:MTLRenderPipelineState,_ selected:Bool=false)throws->Data {
    let desc=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm,width:width,height:height,mipmapped:false)
    desc.storageMode = .shared;desc.usage = [.renderTarget]
    guard let target=device.makeTexture(descriptor:desc),let command=queue.makeCommandBuffer() else {fatalError("Output unavailable")}
    let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=target;pass.colorAttachments[0].loadAction = .dontCare;pass.colorAttachments[0].storeAction = .store
    guard let encoder=command.makeRenderCommandEncoder(descriptor:pass) else {fatalError("Presentation encoder unavailable")}
    encoder.setRenderPipelineState(state);encoder.setFragmentTexture(input,index:0)
    encoder.setFragmentBytes(&frame,length:MemoryLayout<FrameUniforms>.stride,index:0)
    if selected {encoder.setFragmentTexture(input,index:1);encoder.setFragmentBuffer(volumeBuffer,offset:0,index:1)}
    encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:3);encoder.endEncoding();command.commit();command.waitUntilCompleted()
    if let error=command.error {throw error}
    var data=Data(count:width*height*4)
    data.withUnsafeMutableBytes{target.getBytes($0.baseAddress!,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
    return data
}
func save(_ data:Data,_ name:String)throws {
    guard let image=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32),let ptr=image.bitmapData else {fatalError("PNG allocation")}
    let bytes=[UInt8](data)
    for i in stride(from:0,to:bytes.count,by:4) {ptr[i]=bytes[i+2];ptr[i+1]=bytes[i+1];ptr[i+2]=bytes[i];ptr[i+3]=255}
    try image.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
}
func display(_ x:Double)->Double {
    let f=min(1,max(0,x*(2.51*x+0.03)/(x*(2.43*x+0.59)+0.14)))
    return f<=0.0031308 ? 12.92*f:1.055*pow(f,1/2.4)-0.055
}
for (caseIndex,slope) in [0.1875,0.4375,1.375,-0.625].enumerated() {
    let intercept=Double(height)*0.5-slope*Double(width)*0.5+0.21
    func inside(_ x:Double,_ y:Double)->Bool {y>slope*x+intercept}
    let dark=0.002,bright=16.0,low=display(dark),high=display(bright)
    var pixels=[SIMD4<Float>](),reference=[Double]()
    for y in 0..<height {for x in 0..<width {
        let value:Float=inside(Double(x)+0.5,Double(y)+0.5) ? Float(bright):Float(dark)
        pixels.append(SIMD4(value,value,value,10))
        var coverage=0
        // Independent area-coverage oracle, not the filtering implementation.
        for sy in 0..<32 {for sx in 0..<32 {if inside(Double(x)+(Double(sx)+0.5)/32,Double(y)+(Double(sy)+0.5)/32) {coverage+=1}}}
        reference.append(low+(high-low)*Double(coverage)/1024)
    }}
    let input=try texture(pixels),raw=try render(input,plain),smooth=try render(input,direct)
    check(try render(input,oldPlain)==raw,"Case \(caseIndex): Path/Raster original presentation stays byte-identical to committed baseline")
    check(try render(input,focused,true)==render(input,oldFocused,true),"Case \(caseIndex): original focused Path/Raster presentation stays byte-identical")
    check(try render(input,direct)==smooth,"Case \(caseIndex): Direct edge result is deterministic")
    let r=[UInt8](raw),s=[UInt8](smooth)
    var rawError=0.0,smoothError=0.0,flatChanged=0,pixelCount=0
    for y in 5..<(height-5) {for x in 5..<(width-5) {
        let p=y*width+x,actual=Double(s[p*4])/255,original=Double(r[p*4])/255
        rawError+=pow(original-reference[p],2);smoothError+=pow(actual-reference[p],2);pixelCount+=1
        if abs(Double(y)+0.5-slope*(Double(x)+0.5)-intercept)>6 && r[p*4] != s[p*4] {flatChanged+=1}
    }}
    check(smoothError<rawError*0.85,"Case \(caseIndex): filtering reduces independent slanted-edge squared error by at least15%")
    check(flatChanged==0,"Case \(caseIndex): flat regions away from edges remain exact")
    results.append(["slope":slope,"rawRMSE":sqrt(rawError/Double(pixelCount)),"filteredRMSE":sqrt(smoothError/Double(pixelCount)),"flatChangedPixels":flatChanged])
    try save(raw,"edge-\(caseIndex)-original");try save(smooth,"edge-\(caseIndex)-filtered")
}
// Thin bright and dark rails must survive the bounded blend. This adversarial
// detail case is separate from the slanted half-plane coverage oracle.
for brightRail in [true,false] {
    var pixels=[SIMD4<Float>](),railIndices=[Int]()
    for y in 0..<height {for x in 0..<width {
        let rail=x==width/3 || y==height/2 || x==(y*3/5+width/2)
        let value:Float=(rail==brightRail) ? 16:0.002
        pixels.append(SIMD4(value,value,value,10));if rail {railIndices.append(y*width+x)}
    }}
    let input=try texture(pixels),raw=[UInt8](try render(input,plain)),smooth=[UInt8](try render(input,direct))
    let retained=railIndices.allSatisfy {i in brightRail ? Float(smooth[i*4])>=Float(raw[i*4])*0.39 : Float(255-smooth[i*4])>=Float(255-raw[i*4])*0.39}
    check(retained,"Every one-pixel \(brightRail ? "bright":"dark") rail retains at least39% center contrast")
    check(smooth != raw,"Thin \(brightRail ? "bright":"dark") detail actually exercises spatial blending")
    try save(Data(smooth),brightRail ? "thin-bright-filtered":"thin-dark-filtered")
}
var selectionPixels=(0..<(width*height)).map{i in SIMD4<Float>(Float(i%width)/30,0.2,0.05,10)}
for y in 0..<height {for x in 0..<width {if y<height/4 {selectionPixels[y*width+x].w=60000} else if y>height*3/4 {selectionPixels[y*width+x].w=2}}}
let selectionTexture=try texture(selectionPixels)
let selected=[UInt8](try render(selectionTexture,directFocused,true)),unselected=[UInt8](try render(selectionTexture,direct))
var invalidHighlights=0,missingHighlights=0
for y in 0..<height {for x in 0..<width {
    let p=y*width+x,d=selectionPixels[p].w
    let direction=simd_normalize(SIMD3<Float>((Float(x)+0.5)/Float(width)*2-1,1-(Float(y)+0.5)/Float(height)*2,1))
    let world=direction*d
    let expected=d<59999 && world.x>=(-0.2) && world.x<=100.2 && world.y>=(-100.2) && world.y<=100.2 && world.z>=4.8 && world.z<=100.2
    let changed=(0..<3).contains{selected[p*4+$0] != unselected[p*4+$0]}
    if changed && !expected {invalidHighlights+=1};if expected && !changed {missingHighlights+=1}
}}
check(invalidHighlights==0 && missingHighlights==0,"Direct filtered color preserves exact center-depth selection; sky and foreground remain unselected")
check(try render(selectionTexture,focused,true)==render(selectionTexture,oldFocused,true),"Legacy focused depth behavior remains exact across sky/foreground/landmark")
try save(Data(selected),"selection-filtered")
let after=try inventory();check(before==after,"Rendering resources remain unchanged during oracle")
let report:[String:Any]=["passed":failures.isEmpty,"checks":checks,"failures":failures,"edgeCases":results,"sourceSHA256":before,"inputsStable":before==after,
    "legacyRendererSHA256":hash(Data(legacySource.utf8)),"fixtureSHA256":hash(try Data(contentsOf:URL(fileURLWithPath:#filePath))),
    "device":device.name,"width":width,"height":height,"invalidHighlights":invalidHighlights,"missingHighlights":missingHighlights,
    "scope":"Actual production presentation fragments, four synthetic HDR slanted edges against independent32x32 LDR area coverage, one-pixel bright/dark rail survival, deterministic repeats, exact flat regions, original Path/Raster plain/focused byte equality against committed legacy source, and analytic center-depth focus/foreground/sky classification. No city ray tracing, performance benchmark or native input." ]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("validation.json"))
print("\(failures.isEmpty ? "PASS":"FAIL"): \(checks) checks; \(output.path)/validation.json")
exit(failures.isEmpty ? 0:1)
