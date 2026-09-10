import Foundation
import simd

/// A non-jittered screen ray. Coordinates are top-left normalized view coordinates,
/// and aspect is drawable width / height, exactly as MetalRenderer.uniforms uses it.
struct FocusRay {
    let origin: SIMD3<Float>
    let direction: SIMD3<Float>

    static func make(normalized p: SIMD2<Float>, aspect: Float, pose: CameraPose) -> FocusRay? {
        guard p.x.isFinite, p.y.isFinite, (0...1).contains(p.x), (0...1).contains(p.y),
              aspect.isFinite, aspect > 0, pose.position.focusFinite, pose.target.focusFinite,
              pose.fov.isFinite, pose.fov > 0, pose.fov < 179 else { return nil }
        let delta = pose.target - pose.position
        guard simd_length_squared(delta) > 1e-12 else { return nil }
        let forward = simd_normalize(delta)
        var right = simd_cross(forward, SIMD3<Float>(0,1,0))
        if simd_length_squared(right) < 0.0001 { right = SIMD3(1,0,0) }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(right,forward))
        let tangent = tan(pose.fov * .pi / 360)
        let d = forward + right * ((p.x*2-1)*tangent*aspect) - up * ((p.y*2-1)*tangent)
        guard d.focusFinite, simd_length_squared(d) > 1e-12 else { return nil }
        return FocusRay(origin:pose.position,direction:simd_normalize(d))
    }
}

struct FocusBounds {
    let minimum: SIMD3<Float>
    let maximum: SIMD3<Float>
    var center: SIMD3<Float> { (minimum+maximum)/2 }
    var extent: SIMD3<Float> { maximum-minimum }
    func contains(_ p: SIMD3<Float>, tolerance: Float = 0) -> Bool {
        p.x >= minimum.x-tolerance && p.x <= maximum.x+tolerance &&
        p.y >= minimum.y-tolerance && p.y <= maximum.y+tolerance &&
        p.z >= minimum.z-tolerance && p.z <= maximum.z+tolerance
    }
    func union(_ b: FocusBounds) -> FocusBounds {
        FocusBounds(minimum:simd_min(minimum,b.minimum),maximum:simd_max(maximum,b.maximum))
    }
}

/// Named components are compact selection volumes, not a second triangle BVH.
/// A footprint's triangle indices preserve courtyards/holes in the map resource.
struct FocusVolume {
    let bounds: FocusBounds
    let points: [SIMD2<Float>]
    let triangles: [Int]
    init(minimum: SIMD3<Float>, maximum: SIMD3<Float>) {
        bounds = FocusBounds(minimum:minimum,maximum:maximum)
        points = []; triangles = []
    }
    init?(points: [[Float]], triangles: [Int] = [], bottom: Float = 0.25, top: Float) {
        guard points.count >= 3, points.allSatisfy({ $0.count >= 2 && $0[0].isFinite && $0[1].isFinite }),
              bottom.isFinite, top.isFinite, top > bottom else { return nil }
        self.points = points.map { SIMD2($0[0],$0[1]) }
        self.triangles = triangles.count % 3 == 0 && triangles.allSatisfy({ points.indices.contains($0) }) ? triangles : []
        let xs = points.map{$0[0]}, zs = points.map{$0[1]}
        bounds = FocusBounds(minimum:SIMD3(xs.min()!,bottom,zs.min()!),maximum:SIMD3(xs.max()!,top,zs.max()!))
    }
    func contains(_ p: SIMD3<Float>, tolerance: Float = 0.18) -> Bool {
        guard bounds.contains(p,tolerance:tolerance) else { return false }
        if points.isEmpty { return true }
        let q = SIMD2(p.x,p.z)
        func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float { a.x*b.y-a.y*b.x }
        func nearSegment(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
            let d=b-a, length=simd_length_squared(d)
            let t=length > 1e-10 ? max(0,min(1,simd_dot(q-a,d)/length)) : 0
            return simd_distance_squared(q,a+d*t) <= tolerance*tolerance
        }
        if !triangles.isEmpty {
            for i in stride(from:0,to:triangles.count,by:3) {
                let a=points[triangles[i]],b=points[triangles[i+1]],c=points[triangles[i+2]]
                if abs(cross(b-a,c-a)) < 1e-7 { continue }
                let ab=cross(b-a,q-a),bc=cross(c-b,q-b),ca=cross(a-c,q-c)
                if (ab>=0 && bc>=0 && ca>=0) || (ab<=0 && bc<=0 && ca<=0) { return true }
                if nearSegment(a,b) || nearSegment(b,c) || nearSegment(c,a) { return true }
            }
            return false
        }
        var inside=false
        for i in points.indices {
            let a=points[i],b=points[(i+1)%points.count]
            if nearSegment(a,b) { return true }
            if (a.y > q.y) != (b.y > q.y), q.x < (b.x-a.x)*(q.y-a.y)/(b.y-a.y)+a.x { inside.toggle() }
        }
        return inside
    }
}

struct LandmarkFocus: Identifiable {
    let id: String
    let name: String
    let center: SIMD3<Float>
    let volumes: [FocusVolume]
    var bounds: FocusBounds { volumes.dropFirst().reduce(volumes[0].bounds) { $0.union($1.bounds) } }
    init(id: String, name: String, volumes: [FocusVolume], center: SIMD3<Float>? = nil) {
        precondition(!volumes.isEmpty)
        self.id=id; self.name=name; self.volumes=volumes
        self.center=center ?? volumes.dropFirst().reduce(volumes[0].bounds) { $0.union($1.bounds) }.center
    }
    func contains(_ point: SIMD3<Float>) -> Bool { volumes.contains { $0.contains(point) } }
}

/// Construct once per physical world and retain across Chicago destination changes.
/// Only map metadata is decoded: no city geometry, renderer, or second BVH is built.
struct LandmarkFocusCatalog {
    let authored: [LandmarkFocus]
    let mapped: [LandmarkFocus]
    private let cells: [SIMD2<Int>: [Int]]
    private let identities: [String: LandmarkFocus]
    private static let cellSize: Float = 100

    init(authored: [LandmarkFocus], mapped: [LandmarkFocus] = []) {
        self.authored=authored; self.mapped=mapped
        // Authored envelopes win if a malformed resource repeats an identity.
        var identities: [String: LandmarkFocus] = [:]
        for item in mapped { if identities[item.id] == nil { identities[item.id] = item } }
        for item in authored { identities[item.id] = item }
        self.identities = identities
        var index: [SIMD2<Int>: [Int]] = [:]
        for (i,item) in mapped.enumerated() {
            let b=item.bounds
            let lo=Self.cell(b.minimum-SIMD3(repeating:0.2)),hi=Self.cell(b.maximum+SIMD3(repeating:0.2))
            // Resource-derived footprints are bounded. Reject malformed continent-size
            // records instead of allocating an unbounded index for them.
            guard hi.x >= lo.x, hi.y >= lo.y, hi.x-lo.x < 200, hi.y-lo.y < 200 else { continue }
            for x in lo.x...hi.x { for y in lo.y...hi.y { index[SIMD2(x,y),default:[]].append(i) } }
        }
        cells=index
    }
    init(world: String, includeMapped: Bool = true) {
        let key=world == "paris" ? "paris":"chicago"
        let named=Self.authoredLandmarks(world:key)
        self.init(authored:named,mapped:includeMapped ? Self.loadMapped(world:key,authored:named):[])
    }
    /// Semantic map navigation resolves identity directly; it must not guess an
    /// object by shooting a ground ray through a neighboring building.
    func lookup(id: String) -> LandmarkFocus? { identities[id] }

    /// A district framing proxy for semantic map selections that have no authored
    /// object. This is not inserted into the physical picking catalog. Radius is
    /// horizontal; a broad park/campus must not become a fictitious tall tower.
    static func semanticTarget(center: SIMD3<Float>, radius: Float, name: String, id: String) -> LandmarkFocus? {
        guard center.focusFinite, radius.isFinite, radius > 0, radius <= 50_000,
              !id.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return nil }
        let bottom = min(Float(0),center.y), top = max(Float(2),center.y*2)
        let minimum = SIMD3(center.x-radius,bottom,center.z-radius)
        let maximum = SIMD3(center.x+radius,top,center.z+radius)
        guard minimum.focusFinite, maximum.focusFinite, maximum.x > minimum.x,
              maximum.y > minimum.y, maximum.z > minimum.z else { return nil }
        return LandmarkFocus(id:id,name:name,volumes:[FocusVolume(minimum:minimum,maximum:maximum)],center:center)
    }
    private static func cell(_ p: SIMD3<Float>) -> SIMD2<Int> {
        SIMD2(Int(floor(p.x/cellSize)),Int(floor(p.z/cellSize)))
    }
    /// Exposed for a bounded CPU cost check: no linear scan of the 40k building list.
    func mappedCandidateCount(at point: SIMD3<Float>) -> Int {
        guard point.focusFinite, abs(point.x)<1e7, abs(point.z)<1e7 else { return 0 }
        return cells[Self.cell(point)]?.count ?? 0
    }
    func identify(hitPoint point: SIMD3<Float>) -> LandmarkFocus? {
        guard point.focusFinite, abs(point.x)<1e7, abs(point.z)<1e7 else { return nil }
        if let named=authored.first(where:{$0.contains(point)}) { return named }
        // Smaller component wins over a co-located parent footprint, deterministically.
        return (cells[Self.cell(point)] ?? []).compactMap { mapped[$0].contains(point) ? mapped[$0]:nil }
            .min { a,b in
                let ea=a.bounds.extent,eb=b.bounds.extent
                let va=ea.x*ea.y*ea.z,vb=eb.x*eb.y*eb.z
                return va == vb ? a.id < b.id:va < vb
            }
    }
    func pick(ray: FocusRay, world: CollisionWorld, maximum: Float = 50_000) -> LandmarkFocus? {
        guard ray.origin.focusFinite,ray.direction.focusFinite,maximum.isFinite,maximum>0,
              simd_length_squared(ray.direction)>1e-12 else { return nil }
        let direction=simd_normalize(ray.direction)
        guard let distance=world.pickingDistance(origin:ray.origin,direction:direction,maximum:maximum) else { return nil }
        // Never intersect named bounds independently: the first physical occluder wins.
        // CollisionWorld adds only explicitly requested dense picking regions. Other
        // tiny decoration, moving traffic and optical transmission are not GPU-ID picks.
        return identify(hitPoint:ray.origin+direction*distance)
    }
}

/// Orbit orientation uses radians; positive logScale dollies away from the focus.
/// Selecting preserves position. An initial interior/envelope-overlap position is
/// permitted until the first manipulation, which moves outside the focus envelope.
struct FocusOrbit {
    let focus: LandmarkFocus
    private(set) var pose: CameraPose
    private(set) var radius: Float
    private(set) var azimuth: Float
    private(set) var elevation: Float
    // A distant skyline selection may begin beyond the normal object-relative
    // orbit range. Preserve that entry distance, allowing a gradual approach
    // while preventing dolly-out beyond the entry radius. Nearby selections
    // retain their existing object-relative limit.
    let maximumRadius: Float
    static let elevationLimit: Float = 85 * .pi / 180

    init?(focus: LandmarkFocus, pose: CameraPose) {
        guard pose.position.focusFinite,focus.center.focusFinite,pose.target.focusFinite,
              pose.fov.isFinite,pose.fov > 0,pose.fov < 179 else { return nil }
        self.focus=focus
        let offset=pose.position-focus.center, distance=simd_length(offset)
        guard distance.isFinite else { return nil }
        maximumRadius=max(distance,min(50_000,max(300,simd_length(focus.bounds.extent)*12)))
        let fallback=pose.position-pose.target
        let direction=distance>1e-6 ? offset/distance : (simd_length_squared(fallback)>1e-8 ? simd_normalize(fallback):SIMD3(0,0,1))
        radius=distance
        azimuth=atan2(direction.x,direction.z)
        elevation=asin(max(-1,min(1,direction.y)))
        // When camera and center coincide, looking at that exact center has no
        // direction. Retain a finite look direction without moving the camera.
        self.pose=CameraPose(position:pose.position,target:distance>1e-6 ? focus.center:focus.center-direction,fov:pose.fov)
    }
    mutating func rotate(yawDelta: Float, pitchDelta: Float) {
        guard yawDelta.isFinite,pitchDelta.isFinite else { return }
        azimuth=(azimuth+yawDelta.truncatingRemainder(dividingBy:2 * .pi)).truncatingRemainder(dividingBy:2 * .pi)
        elevation=max(-Self.elevationLimit,min(Self.elevationLimit,elevation+max(-Float.pi,min(Float.pi,pitchDelta))))
        update(requestedRadius:radius)
    }
    mutating func dolly(logScale: Float) {
        guard logScale.isFinite else { return }
        update(requestedRadius:max(1,radius)*exp(max(-20,min(20,logScale))))
    }
    func minimumRadius(direction: SIMD3<Float>) -> Float {
        let b=focus.bounds,center=focus.center,clearance=max(0.8,min(4,simd_length(b.extent)*0.006))
        // Exit through either side or the top; never choose the box's underside,
        // since that could put a ground-level camera beneath the city.
        var exit=Float.greatestFiniteMagnitude
        for axis in [0,2] where abs(direction[axis])>1e-7 {
            let edge=direction[axis]>0 ? b.maximum[axis]+clearance:b.minimum[axis]-clearance
            exit=min(exit,max(0,(edge-center[axis])/direction[axis]))
        }
        if direction.y>1e-7 { exit=min(exit,max(0,(b.maximum.y+clearance-center.y)/direction.y)) }
        return max(1,min(maximumRadius,exit.isFinite ? exit:maximumRadius))
    }
    private mutating func update(requestedRadius: Float) {
        // Dolly preserves a normal-camera top-down view. Only rotate() imposes
        // the 85-degree orbit limit after an explicit look/drag input.
        elevation=max(-Float.pi/2,min(Float.pi/2,elevation))
        func orbitDirection(at angle: Float) -> SIMD3<Float> {
            // cos(Float.pi/2) is slightly nonzero; an exact pole must not drift
            // sideways during repeated pinch/wheel zooms.
            if abs(angle) >= Float.pi/2 { return SIMD3(0,angle >= 0 ? 1:-1,0) }
            return SIMD3(sin(azimuth)*cos(angle),sin(angle),cos(azimuth)*cos(angle))
        }
        let direction=orbitDirection(at:elevation)
        radius=max(minimumRadius(direction:direction),min(maximumRadius,requestedRadius.isFinite ? requestedRadius:maximumRadius))
        // Clamping above grade makes the direction more horizontal, preserving
        // the side/top envelope exit already chosen above.
        let ground: Float = 0.6
        if focus.center.y + sin(elevation)*radius < ground {
            elevation=max(-Self.elevationLimit,min(Self.elevationLimit,asin(max(-1,min(1,(ground-focus.center.y)/radius)))))
        }
        let adjusted=orbitDirection(at:elevation)
        pose=CameraPose(position:focus.center+adjusted*radius,target:focus.center,fov:pose.fov)
    }
}

struct FocusSelection {
    var orbit: FocusOrbit?
    /// A viewport click selects only when focus is empty. Clicking the same
    /// object retains its current orbit; blank space or another object clears
    /// focus without immediately selecting a replacement or changing the pose.
    @discardableResult mutating func tap(_ hit: LandmarkFocus?, pose: CameraPose) -> CameraPose {
        if let current = orbit {
            if hit?.id != current.focus.id { orbit = nil }
            return pose
        }
        guard let hit else { return pose }
        return choose(hit,pose:pose)
    }
    /// An explicit semantic destination (e.g. Places) deliberately chooses or
    /// replaces focus in one action. Invalid input leaves the old selection intact.
    @discardableResult mutating func choose(_ hit: LandmarkFocus, pose: CameraPose) -> CameraPose {
        guard let selected = FocusOrbit(focus:hit,pose:pose) else { return pose }
        orbit = selected
        return selected.pose
    }
    mutating func clear() { orbit=nil }
}

private extension SIMD3 where Scalar == Float {
    var focusFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
}

private extension LandmarkFocusCatalog {
    /// Bounds follow authored geometry anchors, not large district/tour envelopes.
    /// Keep these values in sync when a landmark's actual model dimensions change.
    static func authoredLandmarks(world: String) -> [LandmarkFocus] {
        typealias V=SIMD3<Float>
        func box(_ a:V,_ b:V)->FocusVolume { FocusVolume(minimum:a,maximum:b) }
        func named(_ id:String,_ name:String,_ a:V,_ b:V,_ center:V?=nil)->LandmarkFocus {
            LandmarkFocus(id:world+":"+id,name:name,volumes:[box(a,b)],center:center)
        }
        func disk(_ c:V,_ radius:Float,_ bottom:Float,_ top:Float,_ halfEast:Bool=false)->FocusVolume {
            var ring:[[Float]]=[]
            for i in 0..<64 {
                let angle=halfEast ? -Float.pi/2+Float(i)*Float.pi/63 : Float(i)*2*Float.pi/64
                ring.append([c.x+cos(angle)*radius,c.z+sin(angle)*radius])
            }
            return FocusVolume(points:ring,bottom:bottom,top:top)!
        }
        if world == "paris" {
            // Successive envelopes avoid claiming the whole wide base at summit height.
            let tower=[box(V(-64,0.4,-64),V(64,58,64)),box(V(-38,58,-38),V(38,117,38)),
                       box(V(-21,117,-21),V(21,200,21)),box(V(-12,200,-12),V(12,278,12)),
                       box(V(-9,278,-9),V(9,304,9)),box(V(-2.5,304,-2.5),V(2.5,331,2.5))]
            return [LandmarkFocus(id:"paris:eiffel-tower",name:"Eiffel Tower",volumes:tower,center:V(0,150,0)),
                    named("pont-iena","Pont d’Iéna",V(-19,-5.5,-311),V(19,4,-129)),
                    named("seine-cruiser","Seine sightseeing cruiser",V(54,-5.5,-212),V(118,2,-198))]
        }
        var willis:[FocusVolume]=[]
        for x in -1...1 {for z in -1...1 {
            let height:Float=(x == -1 && z == -1) || (x == 1 && z == 1) ? 200 :
                ((x == 1 && z == -1) || (x == -1 && z == 1) ? 260 : (z == 0 && x <= 0 ? 443:356))
            let c=V(Float(x)*22.86,0,Float(z)*22.86)
            willis.append(box(c+V(-11.8,0.25,-11.8),c+V(11.8,height,11.8)))
        }}
        willis.append(box(V(-49,0.25,-35),V(59,22,74)))
        willis.append(box(V(-37,412,-15),V(-33,417,15))) // five glass Ledge boxes
        for x:Float in [-22.86,0] {willis.append(box(V(x-1.2,442,-1.2),V(x+1.2,528,1.2)))}
        let adler=V(2413.718,0,1393.247)
        // Robie House uses the mapped east/south basis from HABS/OSM modeling.
        // Separate wings retain the recessed garden and irregular building edge.
        func robie(_ x0:Float,_ z0:Float,_ x1:Float,_ z1:Float,_ bottom:Float,_ top:Float)->FocusVolume {
            let east=simd_normalize(V(1,0,-0.02)),south=simd_normalize(V(0.02,0,1)),center=V(3309.7,0,9917.1)
            let corners=[SIMD2(x0,z0),SIMD2(x1,z0),SIMD2(x1,z1),SIMD2(x0,z1)].map { p -> [Float] in
                let q=center+east*p.x+south*p.y;return [q.x,q.z]
            }
            return FocusVolume(points:corners,bottom:bottom,top:top)!
        }
        // NavyPierLayout's mapped wheel origin and pier basis. Kept as POD
        // coordinates here so focus tests do not construct the landmark mesh.
        func pier(_ x0:Float,_ z0:Float,_ x1:Float,_ z1:Float,_ bottom:Float,_ top:Float)->FocusVolume {
            let east=simd_normalize(V(1,0,-0.0222)),south=V(-east.z,0,east.x),origin=V(2357.4,0,-1427.7)
            let corners=[SIMD2(x0,z0),SIMD2(x1,z0),SIMD2(x1,z1),SIMD2(x0,z1)].map { p -> [Float] in
                let q=origin+east*p.x+south*p.y;return [q.x,q.z]
            }
            return FocusVolume(points:corners,bottom:bottom,top:top)!
        }
        let wheelVolumes=[pier(-25,-24,25,24,6.4,40),pier(-7,-31,7,31,9,67)]
        let ballroomVolumes=[pier(638,-30,703,30,0.25,43)]
        let hotelVolumes=[pier(229,32,493,49,0.25,32)]
        let theaterVolumes=[pier(106,25,187,66,0.25,30),pier(25,-23,100,39,6.4,25)]
        var result:[LandmarkFocus]=[
            LandmarkFocus(id:"chicago:centennial-wheel",name:"Centennial Wheel",volumes:wheelVolumes,center:V(2357.4,37,-1427.7)),
            LandmarkFocus(id:"chicago:navy-pier-ballroom",name:"Navy Pier Grand Ballroom",volumes:ballroomVolumes,center:V(3027,18,-1444)),
            LandmarkFocus(id:"chicago:sable-hotel",name:"Sable at Navy Pier",volumes:hotelVolumes,center:V(2727.3,19,-1392.9)),
            LandmarkFocus(id:"chicago:chicago-shakespeare",name:"Chicago Shakespeare Theater",volumes:theaterVolumes,center:V(2500.8,18,-1385.1)),
            LandmarkFocus(id:"chicago:navy-pier",name:"Navy Pier",volumes:
                [pier(-188,-63,739,67,-5.7,0.25),pier(-185,-57,-65,47,0.25,30),pier(-66,-52,608,30,0.25,25)]
                + wheelVolumes + ballroomVolumes + hotelVolumes + theaterVolumes,center:V(2620,18,-1433)),
            LandmarkFocus(id:"chicago:cultural-center",name:"Chicago Cultural Center",volumes:[
                FocusVolume(points:[[-25.0,-59.0],[25.0,-59.0],[25.0,59.0],[-25.0,59.0]].map { p in
                    let east=simd_normalize(V(1,0,-0.014)),south=simd_normalize(V(0.014,0,1))
                    let q=V(906.15,0,-557.02)+east*Float(p[0])+south*Float(p[1]);return [q.x,q.z]
                },bottom:0.08,top:33.6)!
            ],center:V(906.15,16.8,-557.02)),
            LandmarkFocus(id:"chicago:robie-house",name:"Frank Lloyd Wright’s Robie House",volumes:[
                robie(-19.4,-4.8,15.3,5.8,0.25,7.5),robie(-7.2,-10.9,26.3,-2.7,0.25,7.3),
                robie(-7.1,-9.1,9.2,3.8,6.3,11.3),robie(6.9,-9.7,8.4,-8.5,0.25,10.7),
                robie(-16,7.6,13.8,9,0.25,2.5),robie(13,7.4,25.9,8.3,0.25,3.3),
                robie(25,-7.1,26,8.3,0.25,3.3)],center:V(3309.7,4.8,9917.1)),
            LandmarkFocus(id:"chicago:adler-planetarium",name:"Adler Planetarium",volumes:[
                disk(adler,24.9,0.25,12.2),disk(adler,15,12.2,29.2),disk(adler,52,0.25,9.2,true),
                box(adler+V(-34,0.3,-7.7),adler+V(-22,4,7.7)),
                box(adler+V(-4.3,2.6,-29),adler+V(4.3,7.4,29))],center:adler+V(8,11,0)),
            LandmarkFocus(id:"chicago:willis-tower",name:"Willis Tower",volumes:willis,center:V(-4,205,10)),
            named("cloud-gate","Cloud Gate",V(1035.9,3,-434.3),V(1049,13.2,-414),V(1042.46,7.8,-424.15)),
            LandmarkFocus(id:"chicago:crown-fountain",name:"Crown Fountain",volumes:[box(V(1004.4,0.3,-319),V(1012.2,15.6,-313.4)),box(V(1005.9,0.3,-267.6),V(1013.6,15.6,-262.2))]),
            named("pritzker-pavilion","Jay Pritzker Pavilion",V(1100,0.3,-542),V(1225,38,-492)),
            named("art-institute","Art Institute of Chicago",V(979,0.25,-201),V(1232,27,48),V(1090,12,-77)),
            named("nichols-bridgeway","Nichols Bridgeway",V(1100,0.3,-340),V(1118,20,-201)),
            LandmarkFocus(id:"chicago:hancock-center",name:"875 North Michigan · John Hancock Center",volumes:[
                box(V(1020,0.25,-2248),V(1106,175,-2191)),box(V(1028,175,-2243),V(1098,345,-2197)),
                box(V(1045,345,-2224),V(1076,458,-2215))],center:V(1062.85,190,-2219.95)),
            LandmarkFocus(id:"chicago:water-tower-place",name:"Water Tower Place",volumes:[
                box(V(994,0.25,-2165),V(1159,61,-2094)),box(V(1089,61,-2129),V(1159,263,-2096))],center:V(1118,110,-2120)),
            LandmarkFocus(id:"chicago:historic-water-tower",name:"Chicago Water Tower",volumes:[
                box(V(942.7,0.25,-2045.3),V(960.5,15,-2027.7)),box(V(947.4,15,-2040.7),V(955.8,56,-2032.3))],center:V(951.6,27,-2036.52)),
            named("pumping-station","Chicago Avenue Pumping Station",V(984,0.25,-2062),V(1016,27,-2011)),
            LandmarkFocus(id:"chicago:wrigley-building",name:"Wrigley Building",volumes:[box(V(888,0.25,-1198),V(937,69,-1158)),box(V(887,0.25,-1243),V(957,91,-1202)),box(V(910,68,-1192),V(929,130,-1173))]),
            LandmarkFocus(id:"chicago:tribune-tower",name:"Tribune Tower",volumes:[box(V(996,0.25,-1335),V(1091,24,-1264)),box(V(995,24,-1299),V(1031,143,-1262))],center:V(1013,68,-1281)),
            named("field-museum","Field Museum",V(1455,0.25,1340),V(1698,30,1480),V(1565,15,1409.6)),
            named("shedd-aquarium","Shedd Aquarium",V(1761,0.25,1182),V(1925,27.5,1325),V(1842,11,1254.6)),
            named("soldier-field","Soldier Field",V(1475,0.25,1640),V(1707,56,2013),V(1590,23,1838)),
            LandmarkFocus(id:"chicago:buckingham-fountain",name:"Buckingham Fountain",volumes:[disk(V(1404.55,0,342.2),43,0.1,14)],center:V(1404.55,6,342.2)),
            named("mccormick-lakeside","McCormick Place · Lakeside Center",V(1811,0.25,2644),V(2109,32,3096)),
            named("mccormick-north","McCormick Place · North Building",V(1473,0.25,2573),V(1774,57,3063)),
            named("mccormick-south","McCormick Place · South Building",V(1461,0.25,3015),V(1840,34,3405)),
            named("mccormick-west","McCormick Place · West Building",V(1144,0.25,2934),V(1440,34,3371)),
            LandmarkFocus(id:"chicago:saint-michael",name:"St. Michael Church · Old Town",volumes:[box(V(-420,0.25,-3775),V(-378,35,-3685)),box(V(-408,35,-3775),V(-393,89,-3760))],center:V(-404,37,-3740)),
            named("north-avenue-beach-house","North Avenue Beach House",V(928,0.25,-3885),V(1017,14,-3820)),
            named("cafe-brauer","Café Brauer",V(145,0.25,-4513),V(191,25,-4441)),
            named("nature-boardwalk-pavilion","People’s Gas Education Pavilion",V(286.8,0.15,-4346),V(302,6,-4328)),
            named("zoo-lion-house","Lincoln Park Zoo · Lion House",V(180,0.25,-4767),V(249,15,-4700)),
            named("lincoln-park-conservatory","Lincoln Park Conservatory",V(26,0.25,-5133),V(119,20,-5002)),
            named("wrigley-field","Wrigley Field",V(-1726,0.08,-7811),V(-1529,44,-7616),V(-1626,15,-7717.6))
        ]
        // Stable named targets are deliberately not whole park districts: a lawn,
        // shore, tree, or sky outside these model components does not select one.
        result.sort { $0.id < $1.id }
        return result
    }

    struct MapBuilding: Decodable {
        let id: Int64
        let name: String
        let points: [[Float]]
        let triangles: [Int]
        let height: Float
    }
    struct MapArchive: Decodable {
        let buildings: [MapBuilding]
        let replacementBuildingIDs: [Int64]
        enum CodingKeys: String,CodingKey { case buildings,replacementBuildingIDs }
        init(from decoder: Decoder) throws {
            let c=try decoder.container(keyedBy:CodingKeys.self)
            buildings=try c.decodeIfPresent([MapBuilding].self,forKey:.buildings) ?? []
            replacementBuildingIDs=try c.decodeIfPresent([Int64].self,forKey:.replacementBuildingIDs) ?? []
        }
    }
    static func loadMapped(world: String, authored: [LandmarkFocus]) -> [LandmarkFocus] {
        let folders=world == "paris" ? ["Paris"]:["Chicago","Lakefront","MuseumCampus","NorthSide","HydePark","NavyPier"]
        var records: [Int64:MapBuilding]=[:], omitted=Set<Int64>()
        for folder in folders {
            let path="Resources/\(folder)/\(folder)Context.json"
            var candidates:[URL]=[]
            if let root=Bundle.main.resourceURL {
                candidates.append(root.appendingPathComponent("ArchitectureEngine_ArchitectureEngine.bundle/"+path))
                candidates.append(root.appendingPathComponent(path))
            }
            candidates.append(URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Sources/ArchitectureEngine/"+path))
            var archive: MapArchive?
            for url in candidates {
                guard let data=try? Data(contentsOf:url),let value=try? JSONDecoder().decode(MapArchive.self,from:data) else { continue }
                archive=value; break
            }
            // A relocated standalone app must resolve its copied bundle before
            // touching SwiftPM's generated absolute build-directory fallback.
            #if SWIFT_PACKAGE
            if archive == nil, let data=try? Data(contentsOf:Bundle.module.bundleURL.appendingPathComponent(path)) {
                archive=try? JSONDecoder().decode(MapArchive.self,from:data)
            }
            #endif
            if let archive=archive {
                omitted.formUnion(archive.replacementBuildingIDs)
                for b in archive.buildings { records[b.id]=b }
            }
        }
        return records.values.sorted{$0.id < $1.id}.compactMap { b in
            guard !omitted.contains(b.id),b.height>0,b.height<2_000,
                  let volume=FocusVolume(points:b.points,triangles:b.triangles,bottom:0.25,top:b.height+1.5) else { return nil }
            // A replaced parent must not give an interior/courtyard a stale OSM
            // identity. Named geometry supplies its own detailed component volumes.
            let center=volume.bounds.center
            if authored.contains(where: { item in
                item.volumes.contains { $0.contains(SIMD3(center.x,$0.bounds.center.y,center.z),tolerance:0) }
            }) { return nil }
            let osm=b.id<0 ? "relation/\(-b.id)":"way/\(b.id)"
            let name=b.name.trimmingCharacters(in:.whitespacesAndNewlines)
            return LandmarkFocus(id:world+":osm:"+osm,name:name.isEmpty ? "Mapped building · OSM \(osm)":name,volumes:[volume])
        }
    }
}
