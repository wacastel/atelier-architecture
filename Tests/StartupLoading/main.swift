import Foundation
import CryptoKit
import Darwin
import simd

typealias V = SIMD3<Float>
var checks = 0
var failures: [String] = []
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures.append(message) }
}
func sameFloat(_ a: Float, _ b: Float) -> Bool {
    a.bitPattern == b.bitPattern
}
func same(_ a: V, _ b: V) -> Bool {
    sameFloat(a.x,b.x) && sameFloat(a.y,b.y) && sameFloat(a.z,b.z)
}
func same(_ a: LandmarkFocus, _ b: LandmarkFocus) -> Bool {
    a.id == b.id && a.name == b.name && same(a.center,b.center) && a.volumes.count == b.volumes.count &&
    zip(a.volumes,b.volumes).allSatisfy { x,y in
        same(x.bounds.minimum,y.bounds.minimum) && same(x.bounds.maximum,y.bounds.maximum) &&
        x.triangles == y.triangles && x.points.count == y.points.count && zip(x.points,y.points).allSatisfy {
            sameFloat($0.x,$1.x) && sameFloat($0.y,$1.y)
        }
    }
}
func verifyCatalog(_ original: LandmarkFocusCatalog, _ cached: LandmarkFocusCatalog, label: String) {
    expect(original.authored.count == cached.authored.count, "\(label): authored count")
    expect(original.mapped.count == cached.mapped.count, "\(label): mapped count")
    for (a,b) in zip(original.authored+original.mapped,cached.authored+cached.mapped) {
        expect(same(a,b), "\(label): exact identity, label, center, bounds, polygon and triangles for \(a.id)")
        expect(original.lookup(id:a.id).map { before in cached.lookup(id:a.id).map { same(before,$0) } ?? false } ?? false,
               "\(label): identity lookup for \(a.id)")
    }
}
let directory = FileManager.default.temporaryDirectory.appendingPathComponent("atelier-startup-loading-\(UUID().uuidString)")
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
defer { try? FileManager.default.removeItem(at:directory) }
let url = directory.appendingPathComponent("nested/focus.bin")
let damagedURL = directory.appendingPathComponent("damaged.bin")
let key = String(repeating:"d",count:64)+":chicago"
func box(_ id: String, _ a: V, _ b: V, name: String? = nil) -> LandmarkFocus {
    LandmarkFocus(id:id,name:name ?? id,volumes:[FocusVolume(minimum:a,maximum:b)])
}
// Include overlapping parent/components, an authored replacement, negative grid
// cells, a concave polygon and a triangulated courtyard with an actual hole.
let courtyard = FocusVolume(points:[[200,200],[240,200],[240,240],[200,240],[210,210],[230,210],[230,230],[210,230]],
    triangles:[0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7],bottom:0.25,top:30)!
let concave = FocusVolume(points:[[-150,-150],[-120,-150],[-120,-140],[-140,-140],[-140,-120],[-150,-120]],top:25)!
let authored = [LandmarkFocus(id:"chicago:icon",name:"École · house & garden 🏙",volumes:[
    FocusVolume(minimum:V(-10,-0.0,-10),maximum:V(10,20,10)),
    FocusVolume(minimum:V(-2,20,-2),maximum:V(2,45,2))],center:V(-0.0,12.125,Float.leastNonzeroMagnitude))]
let mapped = [box("mapped:parent",V(90,0.25,90),V(140,30,140)),
              box("mapped:z-component",V(98,0.25,98),V(102,8,102)),
              box("mapped:a-component",V(98,0.25,98),V(102,8,102)),
              box("chicago:icon",V(-20,0.25,-20),V(20,10,20),name:"Superseded mapped label"),
              LandmarkFocus(id:"mapped:hole",name:"A courtyard",volumes:[courtyard]),
              LandmarkFocus(id:"mapped:concave",name:"An L-shaped footprint",volumes:[concave]),
              box("mapped:duplicate",V(300,0,300),V(310,10,310),name:"First duplicate wins lookup"),
              box("mapped:duplicate",V(400,0,400),V(410,10,410),name:"Second duplicate still has geometry")]
let catalog = LandmarkFocusCatalog(authored:authored,mapped:mapped)
try catalog.writeCache(to:url,key:key)
let original = try Data(contentsOf:url)
let restored = LandmarkFocusCatalog.loadCache(from:url,key:key)
expect(restored != nil,"Matching catalog cache loads")
if let restored {
    verifyCatalog(catalog,restored,label:"Fixture")
    expect(restored.lookup(id:"chicago:icon")?.name == authored[0].name,"Authored identity overrides mapped identity")
    expect(restored.lookup(id:"mapped:duplicate")?.name == mapped[6].name,"First mapped duplicate retains identity precedence")
    expect(restored.identify(hitPoint:V(100,3,100))?.id == "mapped:a-component","Smallest containing component wins; lexical identity breaks ties")
    expect(restored.identify(hitPoint:V(220,3,220)) == nil,"Triangulated courtyard hole remains unselectable")
    expect(restored.identify(hitPoint:V(205,3,220))?.id == "mapped:hole","Courtyard perimeter remains selectable")
    expect(restored.identify(hitPoint:V(-130,3,-130)) == nil,"Concave missing quadrant remains unselectable")
    expect(restored.identify(hitPoint:V(-145,3,-130))?.id == "mapped:concave","Concave occupied wing remains selectable")
    var queryPoints: [V] = [V(.nan,0,0),V(0,.infinity,0),V(1e8,0,0),V(0,0,-1e8)]
    for item in authored+mapped {
        let b=item.bounds
        for x in [b.minimum.x-0.19,b.minimum.x-0.17,b.minimum.x,b.center.x,b.maximum.x,b.maximum.x+0.17,b.maximum.x+0.19] {
            for z in [b.minimum.z-0.19,b.minimum.z,b.center.z,b.maximum.z,b.maximum.z+0.19] {
                for y in [b.minimum.y-0.19,b.center.y,b.maximum.y+0.19] { queryPoints.append(V(x,y,z)) }
            }
        }
    }
    for (i,p) in queryPoints.enumerated() {
        expect(catalog.identify(hitPoint:p)?.id == restored.identify(hitPoint:p)?.id,"Fixture query \(i) retains hit identity")
        expect(catalog.mappedCandidateCount(at:p) == restored.mappedCandidateCount(at:p),"Fixture query \(i) retains spatial candidates")
    }
}
expect(LandmarkFocusCatalog.loadCache(from:directory.appendingPathComponent("absent.bin"),key:key) == nil,"Missing cache safely misses")
expect(LandmarkFocusCatalog.loadCache(from:url,key:"changed-executable:chicago") == nil,"Executable identity change invalidates metadata")
expect(LandmarkFocusCatalog.loadCache(from:url,key:String(repeating:"d",count:64)+":paris") == nil,"World identity change invalidates metadata")
func sign(_ body: Data) -> Data {
    var signed=body;signed.append(contentsOf:SHA256.hash(data:body));return signed
}
let headerLength=original.withUnsafeBytes { Int(UInt64(littleEndian:$0.loadUnaligned(fromByteOffset:8,as:UInt64.self))) }
let payloadStart=(16+headerLength+15)/16*16
let originalHeader=try JSONSerialization.jsonObject(with:original.subdata(in:16..<(16+headerLength))) as! [String:Any]
let itemStride=32,volumeStride=48
let volumeStart=payloadStart+(authored.count+mapped.count)*itemStride
let pointStart=volumeStart+(originalHeader["volumes"] as! Int)*volumeStride
let triangleStart=pointStart+(originalHeader["points"] as! Int)*8
expect(original.prefix(8) == Data("ATLFCS02".utf8),"Compact binary metadata has the current format magic")
expect(originalHeader["strides"] as? [Int] == [32,48,8,4],"POD cache has documented item/volume/point/index strides")
expect(payloadStart%16 == 0,"POD payload starts on a 16-byte boundary")
func mutate(_ transform: (inout [String:Any]) -> Void) throws -> Data {
    var header=originalHeader;transform(&header)
    let metadata=try JSONSerialization.data(withJSONObject:header,options:[.sortedKeys])
    var body=Data(original.prefix(8)),length=UInt64(metadata.count).littleEndian
    withUnsafeBytes(of:&length){body.append(contentsOf:$0)}
    body.append(metadata);body.append(Data(repeating:0,count:((body.count+15)/16*16)-body.count))
    body.append(original[payloadStart..<(original.count-32)])
    return sign(body)
}
func mutateName(_ transform: (inout [String:Any]) -> Void) throws -> Data {
    try mutate { body in
        var items=body["names"] as! [[String:Any]]
        transform(&items[0]);body["names"]=items
    }
}
func replace<T>(_ value: T, at offset: Int) -> Data {
    var body=Data(original.dropLast(32)),copy=value
    withUnsafeBytes(of:&copy){body.replaceSubrange(offset..<(offset+$0.count),with:$0)}
    return sign(body)
}
func rejects(_ bytes: Data, _ message: String) throws {
    try bytes.write(to:damagedURL)
    expect(LandmarkFocusCatalog.loadCache(from:damagedURL,key:key) == nil,message)
}
for length in [0,1,8,15,16,31,32,33,16+headerLength-1,payloadStart,original.count/2,original.count-33,original.count-1] {
    try rejects(Data(original.prefix(length)),"Truncation at \(length) bytes safely misses")
}
var corrupt=original;corrupt[original.count/2] ^= 1
try rejects(corrupt,"Corrupted payload is rejected")
corrupt=original;corrupt[original.count-1] ^= 1
try rejects(corrupt,"Corrupted digest is rejected")
try rejects(sign(Data("not a prepared catalog".utf8)),"Malformed signed payload is rejected")
try rejects(try mutate { $0["version"]=3 },"Unsupported version is rejected with valid digest")
try rejects(try mutate { $0.removeValue(forKey:"key") },"Missing required metadata is rejected")
try rejects(try mutate { $0["authoredCount"]=1000 },"Excessive authored count is rejected")
try rejects(try mutate { $0["authoredCount"] = -1 },"Negative authored count is rejected")
try rejects(try mutate { $0["authoredCount"]=100 },"Authored count exceeding all identities is rejected")
try rejects(try mutate { $0["byteOrder"]="other" },"Wrong endianness is rejected")
try rejects(try mutate { $0["strides"]=[32,64,8,4] },"Mismatched native ABI is rejected")
for field in ["volumes","points","triangles"] {
    for value in [NSNumber(value:-1),NSNumber(value:Int.max),NSNumber(value:UInt64.max)] {
        try rejects(try mutate { $0[field]=value },"Invalid \(field) count \(value) cannot overflow allocation arithmetic")
    }
}
try rejects(replace(UInt64.max,at:8),"Maximum UInt64 header size cannot overflow bounds")
try rejects(try mutateName { $0["id"]="" },"Empty identity is rejected")
try rejects(try mutateName { $0["name"]=String(repeating:"x",count:2048) },"Unbounded label is rejected")
try rejects(replace(UInt32(0),at:payloadStart+20),"Empty volume list is rejected before bounds access")
try rejects(replace(UInt32.max,at:payloadStart+16),"Out-of-bounds item volume range is rejected")
try rejects(replace(UInt32.max,at:payloadStart+20),"Maximum item volume count is rejected without overflowing")
try rejects(replace(Float.nan,at:payloadStart),"Non-finite center is rejected")
try rejects(replace(UInt32(1),at:payloadStart+24),"Nonzero reserved item field is rejected")
try rejects(replace(UInt32(0),at:payloadStart+itemStride+16),"Aliased volume range is rejected")
try rejects(replace(Float(20),at:volumeStart),"Inverted bounds are rejected")
try rejects(replace(Float(1e8),at:volumeStart+16),"Unbounded coordinates are rejected")
try rejects(replace(Float.infinity,at:volumeStart+16),"Non-finite bounds are rejected")
try rejects(replace(Float(1),at:volumeStart+12),"Nonzero reserved volume field is rejected")
let polygonVolume=volumeStart+6*volumeStride
try rejects(replace(UInt32(2),at:polygonVolume+36),"Two-point polygon is rejected")
try rejects(replace(UInt32.max,at:polygonVolume+36),"Maximum polygon count is rejected")
try rejects(replace(UInt32(1),at:polygonVolume+32),"Noncanonical point range is rejected")
try rejects(replace(Float.nan,at:pointStart),"Non-finite polygon is rejected")
try rejects(replace(Float(10000),at:pointStart),"Polygon point outside its bounds is rejected")
try rejects(replace(UInt32(2),at:polygonVolume+44),"Incomplete triangle is rejected")
try rejects(replace(UInt32.max,at:polygonVolume+44),"Maximum triangle count is rejected safely")
try rejects(replace(UInt32(1),at:polygonVolume+40),"Noncanonical triangle range is rejected")
try rejects(replace(UInt32(8),at:triangleStart),"Out-of-range triangle index is rejected")
try rejects(replace(UInt32.max,at:triangleStart),"Maximum or negative-bit-pattern triangle index is rejected")
var trailing=original;trailing.append(0)
try rejects(trailing,"Trailing data is rejected")
// The old plist cache is an ordinary miss, so a legacy artifact cannot silently
// bypass the new layout/identity validation.
let oldPlist=try PropertyListSerialization.data(fromPropertyList:["version":1,"key":key,"authored":[],"mapped":[]],format:.binary,options:0)
try rejects(sign(oldPlist),"Legacy recursive plist format is rejected")
let emptyURL=directory.appendingPathComponent("empty.bin")
try LandmarkFocusCatalog(authored:[]).writeCache(to:emptyURL,key:key)
let empty=LandmarkFocusCatalog.loadCache(from:emptyURL,key:key)
expect(empty != nil && empty!.authored.isEmpty && empty!.mapped.isEmpty,"Empty metadata catalog safely round trips")
try catalog.writeCache(to:url,key:key)
expect(LandmarkFocusCatalog.loadCache(from:url,key:key) != nil,"Atomic replacement remains readable")
let beforeInvalidWrite=try Data(contentsOf:url)
let invalid=LandmarkFocusCatalog(authored:[LandmarkFocus(id:"invalid",name:"Invalid center",volumes:authored[0].volumes,center:V(.nan,0,0))])
do { try invalid.writeCache(to:url,key:key);expect(false,"Invalid metadata must fail before replacing a cache") }
catch { expect(true,"Invalid metadata reports a write error") }
let afterInvalidWrite=try Data(contentsOf:url)
expect(beforeInvalidWrite == afterInvalidWrite,"Rejected invalid metadata preserves the previous complete file")
// Make the parent unwritable so the atomic temporary file cannot be created.
// This exercises failure at the same valid cache destination, not another path.
let protected=directory.appendingPathComponent("protected")
try FileManager.default.createDirectory(at:protected,withIntermediateDirectories:true)
let protectedURL=protected.appendingPathComponent("focus.bin")
try catalog.writeCache(to:protectedURL,key:key)
let beforeFailure=try Data(contentsOf:protectedURL)
if getuid() != 0 {
    expect(chmod(protected.path,0o555) == 0,"Fixture parent becomes read-only")
    do {
        defer { chmod(protected.path,0o755) }
        do { try LandmarkFocusCatalog(authored:[]).writeCache(to:protectedURL,key:"replacement");expect(false,"Read-only parent must cause write failure") }
        catch { expect(true,"Read-only parent reports write failure") }
        let afterFailure=try Data(contentsOf:protectedURL)
        expect(afterFailure == beforeFailure,"Failed atomic write preserves the exact previous cache")
        expect(LandmarkFocusCatalog.loadCache(from:protectedURL,key:key) != nil,"Previous cache still loads after failed replacement")
    }
}
do { try catalog.writeCache(to:protected,key:key);expect(false,"Writing onto a directory must fail") }
catch { expect(true,"Directory destination reports a write error") }

// Decode real map metadata, but never construct city triangles or initialize a GPU.
var worldReports:[[String:Any]]=[]
for world in ["chicago","paris"] {
    let buildStarted=ProcessInfo.processInfo.systemUptime
    let fresh=LandmarkFocusCatalog(world:world)
    let buildSeconds=ProcessInfo.processInfo.systemUptime-buildStarted
    expect(!fresh.authored.isEmpty && !fresh.mapped.isEmpty,"\(world): actual bundled metadata is available")
    let worldURL=directory.appendingPathComponent("\(world)-focus.bin")
    let writeStarted=ProcessInfo.processInfo.systemUptime
    try fresh.writeCache(to:worldURL,key:key+world)
    let writeSeconds=ProcessInfo.processInfo.systemUptime-writeStarted
    let readStarted=ProcessInfo.processInfo.systemUptime
    let loaded=LandmarkFocusCatalog.loadCache(from:worldURL,key:key+world)
    let readSeconds=ProcessInfo.processInfo.systemUptime-readStarted
    expect(loaded != nil,"\(world): actual catalog loads from cache")
    if let loaded {
        verifyCatalog(fresh,loaded,label:world)
        // Sample all authored landmarks plus deterministic mapped records. Exact
        // metadata above covers every record; queries cover rebuilt index behavior.
        let sampled=fresh.authored+fresh.mapped.enumerated().compactMap { $0.offset%97 == 0 ? $0.element:nil }
        for item in sampled {
            for p in [item.center,item.bounds.minimum,item.bounds.maximum,item.bounds.center+V(0,10000,0)] {
                expect(fresh.identify(hitPoint:p)?.id == loaded.identify(hitPoint:p)?.id,"\(world): cached point query for \(item.id)")
                expect(fresh.mappedCandidateCount(at:p) == loaded.mappedCandidateCount(at:p),"\(world): cached cell for \(item.id)")
            }
        }
    }
    worldReports.append(["world":world,"authored":fresh.authored.count,"mapped":fresh.mapped.count,"bytes":try Data(contentsOf:worldURL).count,
                         "metadataBuildSeconds":buildSeconds,"cacheWriteSeconds":writeSeconds,"cacheLoadSeconds":readSeconds])
}

func close(_ a: Double,_ b: Double) -> Bool { abs(a-b)<1e-9 }
let preparation=CityLoadingProgress.definitions.map{$0.0}.filter{$0 != "presentation"}
expect(close(CityLoadingProgress.definitions.reduce(0){$0+$1.2},1),"Phase weights sum to one")
// Navigation can finish while geometry is active or after GPU preparation. Both
// timelines must report completed work rather than infer elapsed-time progress.
for (index,order) in [preparation, ["identity","navigation","geometry","shaders","buffers","lighting","traffic","raster"],
                      ["identity","geometry","shaders","buffers","lighting","traffic","raster","navigation"]].enumerated() {
    var model=CityLoadingProgress(started:100)
    expect(model.snapshot.progress == 0 && model.snapshot.elapsed == 0,"Timeline \(index): initial empty progress")
    expect(model.snapshot.steps.allSatisfy{$0.state == .pending && $0.duration == nil},"Timeline \(index): phases start pending")
    model.begin("navigation",at:100.25)
    model.begin("geometry",at:100.5)
    model.begin("navigation",at:101)
    var previous=0.0
    for (offset,id) in order.enumerated() {
        let finish=102+Double(offset)
        if id != "navigation" && id != "geometry" { model.begin(id,at:finish-0.5) }
        model.complete(id,at:finish)
        expect(model.snapshot.progress >= previous,"Timeline \(index): completion progress is monotonic at \(id)")
        expect(model.snapshot.progress <= 0.95,"Timeline \(index): preparation cannot complete the last presentation fraction")
        let expectedDuration=id == "navigation" ? finish-100.25 : id == "geometry" ? finish-100.5 : 0.5
        expect(close(model.snapshot.steps.first{$0.id==id}!.duration!,expectedDuration),"Timeline \(index): \(id) duration includes actual parallel interval")
        previous=model.snapshot.progress
        model.complete(id,at:finish+0.25)
        expect(close(model.snapshot.steps.first{$0.id==id}!.duration!,expectedDuration),"Timeline \(index): duplicate completion retains original duration")
    }
    expect(close(model.snapshot.progress,0.95),"Timeline \(index): completed preparation holds at 95 percent")
    model.tick(at:200)
    expect(close(model.snapshot.progress,0.95) && close(model.snapshot.elapsed,100),"Timeline \(index): waiting grows elapsed, never invents progress")
    model.begin("presentation",at:200)
    model.presented(at:202.25)
    expect(model.snapshot.progress == 1 && model.snapshot.steps.allSatisfy{$0.state == .completed},"Timeline \(index): actual presentation completes all work")
    expect(close(model.snapshot.elapsed,102.25),"Timeline \(index): displayed total uses actual presentation time")
    expect(close(model.snapshot.steps.first{$0.id=="presentation"}!.duration!,2.25),"Timeline \(index): presentation interval measured")
    model.tick(at:400)
    expect(close(model.snapshot.elapsed,102.25),"Timeline \(index): elapsed clock freezes after presentation")
    model.presented(at:500)
    expect(close(model.snapshot.elapsed,102.25),"Timeline \(index): duplicate presented callback cannot change first-frame elapsed")
}
var reserved=CityLoadingProgress(started:0)
reserved.presented(at:0.25)
expect(reserved.snapshot.progress == 0 && reserved.snapshot.elapsed == 0,"Premature presentation cannot complete unfinished preparation")
for id in preparation { reserved.complete(id,at:1) }
reserved.presented(at:.nan)
expect(reserved.snapshot.progress < 1 && reserved.snapshot.elapsed.isFinite,"Invalid presentation timestamp cannot finish preparation")
reserved.complete("presentation",at:2)
expect(reserved.snapshot.progress < 1 && reserved.snapshot.steps.last!.state != .completed,
       "Generic phase completion cannot impersonate real presentation")
reserved.presented(at:3)
expect(reserved.snapshot.progress == 1 && reserved.snapshot.elapsed == 3,"Real presentation can finish reserved final phase")
var unknown=CityLoadingProgress(started:50)
unknown.begin("unrecognized",at:500);unknown.complete("unrecognized",at:500)
expect(unknown.snapshot.progress == 0 && unknown.snapshot.elapsed == 0,"Unknown phases cannot alter state")
unknown.tick(at:49)
expect(unknown.snapshot.elapsed == 0,"Elapsed time never becomes negative")
var paris=CityLoadingProgress(world:"paris",started:0)
for id in preparation { paris.complete(id,at:1) }
paris.presented(at:2)
expect(paris.snapshot.title == "Loading the City of Light" && paris.snapshot.currentStep == "Paris is ready to explore","Paris presentation uses Paris labels")

let report:[String:Any]=["passed":failures.isEmpty,"checks":checks,"failures":failures,"worlds":worldReports,
    "scope":"CPU-only compact metadata cache round trips, every authored/mapped record, exact Float bits including signed zeros, rebuilt index queries, signed malformed data, stale/corrupt/truncated cache rejection and atomic-write failure; measured loading phases, parallel ordering and first-presentation completion. Metadata build/read/write timings are isolated CLI measurements, not application startup. No city geometry or GPU initialization."]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]));print("")
if !failures.isEmpty { exit(1) }
