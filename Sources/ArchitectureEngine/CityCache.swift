import Foundation
import CryptoKit
import simd

struct CityCacheContext {
    let directory: URL
    let key: String
    let forceRebuild: Bool
    var sceneURL: URL { directory.appendingPathComponent("scene.bin") }
    var collisionURL: URL { directory.appendingPathComponent("collision.bin") }
}

/// Local, disposable caches are keyed by executable and geometry-resource bytes.
/// No source checkout or network access is needed by a relocated packaged app.
enum CityCache {
    private static let identityLock=NSLock()
    private static var identity: String?
    static func argument(_ flag: String) -> String? {
        let args=CommandLine.arguments
        guard let i=args.firstIndex(of:flag),i+1<args.count else { return nil }
        return args[i+1]
    }
    static var disabled: Bool { CommandLine.arguments.contains("--no-city-cache") }
    static var root: URL {
        if let path=argument("--cache-dir") ?? ProcessInfo.processInfo.environment["ATELIER_CACHE_DIR"] { return URL(fileURLWithPath:path,isDirectory:true) }
        return FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("local.atelier.architecture/City/v1",isDirectory:true)
    }
    static func resourceRoot() -> URL {
        if let r=Bundle.main.resourceURL {
            let candidate=r.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/Resources")
            if FileManager.default.fileExists(atPath:candidate.appendingPathComponent("Chicago/ChicagoContext.json").path) { return candidate }
        }
        #if SWIFT_PACKAGE
        return Bundle.module.bundleURL.appendingPathComponent("Resources")
        #else
        return URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/Resources")
        #endif
    }
    static func contentKey() throws -> String {
        identityLock.lock();defer { identityLock.unlock() }
        if let identity { return identity }
        var digest=SHA256()
        digest.update(data:Data("Atelier city cache v1 arm64\n".utf8))
        guard let executable=Bundle.main.executableURL else { throw CacheError.invalid("Missing executable identity") }
        digest.update(data:try Data(contentsOf:executable,options:.mappedIfSafe))
        let resources=resourceRoot()
        guard let enumerator=FileManager.default.enumerator(at:resources,includingPropertiesForKeys:nil) else { throw CacheError.invalid("Missing scene resources") }
        let files=enumerator.compactMap{$0 as? URL}.filter{$0.pathExtension=="json" && !$0.path.contains("/Music/")}.sorted{$0.path<$1.path}
        guard !files.isEmpty else { throw CacheError.invalid("Missing map resources") }
        for file in files {
            digest.update(data:Data(file.path.replacingOccurrences(of:resources.path,with:"").utf8))
            digest.update(data:try Data(contentsOf:file,options:.mappedIfSafe))
        }
        let result=digest.finalize().map{String(format:"%02x",$0)}.joined()
        identity=result;return result
    }
    static func context(world: String) throws -> CityCacheContext? {
        guard !disabled else { return nil }
        guard ["chicago","paris"].contains(world) else { throw CacheError.invalid("Unknown cache world") }
        let key=try contentKey()
        let directory=root.appendingPathComponent(key,isDirectory:true).appendingPathComponent(world,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        return CityCacheContext(directory:directory,key:key+":"+world,forceRebuild:CommandLine.arguments.contains("--force-rebuild-cache"))
    }
    enum CacheError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let message)=self { return message };return nil }
    }
    private struct Lane: Codable {
        let id: Int64
        let points: [[Float]]
        let speed: Float
        let fade: Float
    }
    private struct Header: Codable {
        let version: Int
        let key: String
        let strides: [Int]
        let vertices: Int
        let indices: Int
        let materials: Int
        let lights: Int
        let detailCount: Int
        let name: String
        let lanes: [Lane]
    }
    private static let magic=Data("ATLCITY1".utf8)
    private static let strides=[MemoryLayout<SceneVertex>.stride,MemoryLayout<UInt32>.stride,MemoryLayout<SceneMaterial>.stride,MemoryLayout<SceneLight>.stride]
    static func loadScene(from url: URL,key: String) -> SceneData? {
        do {
            let data=try Data(contentsOf:url,options:.mappedIfSafe)
            guard data.count>48,data.prefix(8)==magic else { return nil }
            let rawCount=data.withUnsafeBytes{UInt64(littleEndian:$0.loadUnaligned(fromByteOffset:8,as:UInt64.self))}
            guard rawCount>0,rawCount<32*1024*1024 else { return nil }
            let headerCount=Int(rawCount)
            guard headerCount<=data.count-48 else { return nil }
            let h=try JSONDecoder().decode(Header.self,from:data.subdata(in:16..<(16+headerCount)))
            guard h.version==1,h.key==key,h.strides==strides,h.vertices>0,h.vertices%3==0,h.indices==h.vertices/3,
                  h.vertices<=600_000_000,h.materials>0,h.materials<=65_536,h.lights>=0,h.lights<=1_000_000,
                  h.detailCount>=0,h.lanes.count<1_000_000 else { return nil }
            var offset=(16+headerCount+63)/64*64
            let counts=[h.vertices,h.indices,h.materials,h.lights]
            let payload=zip(counts,strides).reduce(0){$0+$1.0*$1.1}
            guard offset+payload+32==data.count else { return nil }
            let body=data.prefix(data.count-32)
            guard Data(SHA256.hash(data:body))==data.suffix(32) else { return nil }
            func array<T>(_ type:T.Type,_ count:Int) -> [T] {
                let length=count*MemoryLayout<T>.stride
                defer { offset+=length }
                return Array<T>(unsafeUninitializedCapacity:count) { buffer,initialized in
                    if length>0 { data.withUnsafeBytes { raw in UnsafeMutableRawPointer(buffer.baseAddress!).copyMemory(from:raw.baseAddress!.advanced(by:offset),byteCount:length) } }
                    initialized=count
                }
            }
            var scene=SceneData()
            scene.vertices=array(SceneVertex.self,h.vertices)
            scene.materialIndices=array(UInt32.self,h.indices)
            scene.materials=array(SceneMaterial.self,h.materials)
            scene.lights=array(SceneLight.self,h.lights)
            guard scene.materialIndices.allSatisfy({Int($0)<h.materials}) else { return nil }
            for lane in h.lanes {
                guard lane.points.count>=2,lane.points.count<=1_000_000,lane.speed.isFinite,lane.fade.isFinite,
                      lane.points.allSatisfy({$0.count==3 && $0.allSatisfy(\.isFinite)}) else { return nil }
                scene.trafficLanes.append(SceneTrafficLane(id:lane.id,points:lane.points.map{SIMD3($0[0],$0[1],$0[2])},speedMetresPerSecond:lane.speed,spawnFadeMetres:lane.fade))
            }
            scene.detailCount=h.detailCount;scene.name=h.name
            return scene
        } catch { return nil }
    }
    static func writeScene(_ scene:SceneData,to url:URL,key:String) throws {
        let header=Header(version:1,key:key,strides:strides,vertices:scene.vertices.count,indices:scene.materialIndices.count,materials:scene.materials.count,lights:scene.lights.count,detailCount:scene.detailCount,name:scene.name,lanes:scene.trafficLanes.map{Lane(id:$0.id,points:$0.points.map{[$0.x,$0.y,$0.z]},speed:$0.speedMetresPerSecond,fade:$0.spawnFadeMetres)})
        let metadata=try JSONEncoder().encode(header)
        guard metadata.count<32*1024*1024 else { throw CacheError.invalid("Scene cache metadata exceeds format limit") }
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        let temporary=url.deletingLastPathComponent().appendingPathComponent(".scene-\(UUID().uuidString).tmp")
        guard FileManager.default.createFile(atPath:temporary.path,contents:nil,attributes:[.posixPermissions:0o600]) else { throw CacheError.invalid("Cannot create scene cache") }
        defer { try? FileManager.default.removeItem(at:temporary) }
        let handle=try FileHandle(forWritingTo:temporary)
        defer { try? handle.close() }
        var digest=SHA256()
        func write(_ data:Data) throws { digest.update(data:data);try handle.write(contentsOf:data) }
        var prefix=magic,length=UInt64(metadata.count).littleEndian
        withUnsafeBytes(of:&length){prefix.append(contentsOf:$0)}
        prefix.append(metadata)
        prefix.append(Data(repeating:0,count:((prefix.count+63)/64*64)-prefix.count))
        try write(prefix)
        func writeArray<T>(_ values:[T]) throws {
            try values.withUnsafeBytes { raw in
                for start in stride(from:0,to:raw.count,by:8*1024*1024) {
                    let count=min(8*1024*1024,raw.count-start)
                    let chunk=Data(bytesNoCopy:UnsafeMutableRawPointer(mutating:raw.baseAddress!.advanced(by:start)),count:count,deallocator:.none)
                    try write(chunk)
                }
            }
        }
        try writeArray(scene.vertices);try writeArray(scene.materialIndices);try writeArray(scene.materials);try writeArray(scene.lights)
        try handle.write(contentsOf:Data(digest.finalize()));try handle.synchronize();try handle.close()
        guard rename(temporary.path,url.path)==0 else { throw POSIXError(POSIXErrorCode(rawValue:errno) ?? .EIO) }
    }
}
