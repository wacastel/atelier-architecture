import Foundation
import Metal
import simd
import Darwin
setbuf(stdout,nil)
let args=CommandLine.arguments
let shaderRoot=URL(fileURLWithPath:args[1]),folder=URL(fileURLWithPath:args[2])
extension Bundle { static var module:Bundle { Bundle(url:shaderRoot)! } }
let location=ArchitectureLocation(rawValue:args.count>3 ? args[3]:"culturalcenter")!,view=args.count>4 ? Int(args[4])!:2
let frames=args.count>5 ? Int(args[5])!:48,referenceSamples=args.count>6 ? Int(args[6])!:64
let width=args.count>7 ? Int(args[7])!:256,height=width*5/8
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
guard let device=MTLCreateSystemDefaultDevice() else { fatalError("No Metal device") }
let scene=location.build()
print("Built \(scene.triangleCount) triangles, \(scene.materials.count) materials, \(scene.trafficLanes.count) traffic lanes")
let renderer=try MetalRenderer(scene:scene,device:device),reference=try MetalRenderer(scene:scene,device:device)
let options=RenderOptions(),referenceOptions=RenderOptions(denoising:false)
var rawError=0.0,filteredError=0.0,rawFlicker=0.0,filteredFlicker=0.0,samples=0,flickerSamples=0
var oldRaw=[Float](),oldFiltered=[Float](),histogram=[String:Int](),historySummary=[[String:Any]](),gpuTimes=[Double]()
func read(_ texture:MTLTexture)->[SIMD4<Float>] {
 let bytesPerRow=width*16,buffer=device.makeBuffer(length:height*bytesPerRow,options:.storageModeShared)!
 let command=renderer.queue.makeCommandBuffer()!,blit=command.makeBlitCommandEncoder()!
 blit.copy(from:texture,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),to:buffer,destinationOffset:0,destinationBytesPerRow:bytesPerRow,destinationBytesPerImage:bytesPerRow*height)
 blit.endEncoding();command.commit();command.waitUntilCompleted()
 return Array(UnsafeBufferPointer(start:buffer.contents().assumingMemoryBound(to:SIMD4<Float>.self),count:width*height))
}
for frame in 0..<frames { try autoreleasepool {
 let time=Double(frame)/24,pose=location.idlePose(view:view,seconds:time)
 renderer.setSceneTime(time);reference.setSceneTime(time)
 let pair=try renderer.renderPreviewComparisonOffscreen(pose:pose,options:options,width:width,height:height,samples:4,resetHistory:frame==0)
 gpuTimes.append(renderer.lastGPUTime)
 let truth=try reference.renderOffscreen(pose:pose,options:referenceOptions,width:width,height:height,samples:referenceSamples)
 let a=[UInt8](pair.raw),b=[UInt8](pair.reconstructed),t=[UInt8](truth)
 var ra=[Float](),rb=[Float]()
 for i in stride(from:0,to:a.count,by:4) { for c in 0..<3 {
  let ea=Float(Int(a[i+c])-Int(t[i+c]))/255,eb=Float(Int(b[i+c])-Int(t[i+c]))/255
  let p=ra.count;ra.append(ea);rb.append(eb)
  if frame>=frames/2 {
   rawError += Double(ea*ea);filteredError += Double(eb*eb);samples += 1
   if !oldRaw.isEmpty {let da=ea-oldRaw[p],db=eb-oldFiltered[p];rawFlicker += Double(da*da);filteredFlicker += Double(db*db);flickerSamples += 1}
  }
 } }
 oldRaw=ra;oldFiltered=rb
 if frame==0 || frame==frames-1 {
  let worlds=read(renderer.worldGuides[renderer.historyIndex]),history=read(renderer.histories[renderer.historyIndex]),albedo=read(renderer.albedoGuide!)
  var flags=[String:Int](),materials=[String:Int](),counts=[String:Double](),roughness=[String:Double]()
  for i in worlds.indices {
   let flag=worlds[i].w<0 ? "sky":String(format:"%.3f",worlds[i].w-floor(worlds[i].w))
   flags[flag,default:0] += 1;counts[flag,default:0] += Double(history[i].w);roughness[flag,default:0] += Double(albedo[i].w)
   materials[String(Int(floor(worlds[i].w))),default:0] += 1
  }
  historySummary.append(["frame":frame,"guideTags":flags,"sumHistory":counts,"sumRoughness":roughness,"materials":materials])
  for (name,data) in [("raw",pair.raw),("reconstructed",pair.reconstructed),("reference",truth)] { try writePNG(data,width:width,height:height,to:folder.appendingPathComponent("frame-\(frame)-\(name).png")) }
  var guide=[UInt8](repeating:0,count:width*height*4)
  for i in worlds.indices {let flag=worlds[i].w<0 ? -1:worlds[i].w-floor(worlds[i].w);guide[i*4]=UInt8(clamping:Int(history[i].w*255/32));guide[i*4+1]=UInt8(clamping:Int(albedo[i].w*255));guide[i*4+2]=UInt8(clamping:Int(flag*255));guide[i*4+3]=255}
  try writePNG(Data(guide),width:width,height:height,to:folder.appendingPathComponent("frame-\(frame)-guides.png"))
 }
 if frame%8==0 {print("\(location.rawValue) \(view) \(frame)/\(frames)")}
} }
let report:[String:Any]=["location":location.rawValue,"view":view,"frames":frames,"samplesPerFrame":4,"referenceSamples":referenceSamples,"resolution":[width,height],"camera":"idlePose frame/24 seconds","rawRMSE":sqrt(rawError/Double(samples)),"reconstructedRMSE":sqrt(filteredError/Double(samples)),"rawTemporalResidualRMSE":sqrt(rawFlicker/Double(flickerSamples)),"reconstructedTemporalResidualRMSE":sqrt(filteredFlicker/Double(flickerSamples)),"meanPairedGPUms":gpuTimes.reduce(0,+)/Double(frames),"guides":historySummary]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("metrics.json"))
print("Completed: \(folder.path)")
