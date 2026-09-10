import Foundation
import simd

/// Willis-origin metres; OSM way 686996484 anchors the wheel and way 24800238
/// supplies the pier's 1.27-degree skew. Exterior heights/details are interpreted
/// from the owner's photographs; this is not an as-built engineering model.
enum NavyPierLayout {
    typealias V = SIMD3<Float>
    static let center = V(2357.4,0,-1427.7)
    static let east = simd_normalize(V(1,0,-0.0222))
    static let south = V(-east.z,0,east.x)
    static let deck: Float = 0.24, parkFloor: Float = 6.4
    static let wheelHubHeight: Float = parkFloor + 31.6992
    static let wheelRadius: Float = 27.8966
    static let wheelOverallHeight: Float = 59.7408
    static let wheelCabinCount = 42, wheelSpokeCount = 21
    static func point(_ p: V) -> V { center+east*p.x+V(0,p.y,0)+south*p.z }
    static func local(_ p: V) -> V { let d=p-center; return V(simd_dot(d,east),d.y,simd_dot(d,south)) }
    static let wheel = point(V(0,wheelHubHeight,0))
    static let familyPavilion = point(V(-150,10,-1.2))
    static let crystalGardens = point(V(-86.5,15,-1.8))
    static let shakespeare = point(V(142.4,14,45.8))
    static let sable = point(V(374,19,41))
    static let ballroom = point(V(669.8,14,-1.2))
    static let marina = point(V(270,-4.7,-107))
    /// Fresh OSM marina centerlines, 2026-09-10T00:34:18Z, projected into
    /// this local frame. The 2023 owner photos predate these angled fingers.
    static let marinaCenterlines: [(id: Int64, points: [V])] = [
        (1417040525,[V(74.939,-4.84,-65.057),V(77.617,-4.84,-65.042),V(106.985,-4.84,-64.824),V(108.892,-4.84,-64.837)]),
        (1417040528,[V(77.759,-4.84,-70.684),V(77.617,-4.84,-65.042)]),
        (1417040529,[V(79.378,-4.84,-72.663),V(93.421,-4.84,-86.448),V(110.989,-4.84,-86.481),V(111.120,-4.84,-69.965)]),
        (1417040530,[V(131.491,-4.84,-67.420),V(163.476,-4.84,-67.444),V(197.305,-4.84,-67.250),V(202.898,-4.84,-67.081),V(231.530,-4.84,-67.336),V(265.454,-4.84,-67.284),V(299.795,-4.84,-67.357),V(333.665,-4.84,-67.150),V(367.890,-4.84,-67.259),V(401.887,-4.84,-67.150),V(435.928,-4.84,-67.162),V(470.075,-4.84,-67.094)]),
        (1417040531,[V(539.858,-4.84,-66.814),V(539.792,-4.84,-68.686),V(539.784,-4.84,-108.293)]),
        (1417040532,[V(510.103,-4.84,-107.115),V(470.075,-4.84,-67.094)]),
        (1417040533,[V(475.891,-4.84,-107.251),V(435.928,-4.84,-67.162)]),
        (1417040534,[V(441.884,-4.84,-107.249),V(401.887,-4.84,-67.150)]),
        (1417040535,[V(407.820,-4.84,-107.326),V(367.890,-4.84,-67.259)]),
        (1417040536,[V(373.731,-4.84,-107.381),V(333.665,-4.84,-67.150)]),
        (1417040537,[V(339.558,-4.84,-107.394),V(299.795,-4.84,-67.357)]),
        (1417040538,[V(305.623,-4.84,-107.335),V(265.454,-4.84,-67.284)]),
        (1417040539,[V(271.415,-4.84,-107.616),V(231.530,-4.84,-67.336)]),
        (1417040540,[V(237.247,-4.84,-107.484),V(197.305,-4.84,-67.250)]),
        (1417040541,[V(203.205,-4.84,-107.438),V(163.476,-4.84,-67.444)]),
        (1417040542,[V(169.245,-4.84,-107.312),V(131.473,-4.84,-69.580)]),
        (1417040543,[V(111.120,-4.84,-69.965),V(131.473,-4.84,-69.580),V(131.491,-4.84,-67.420)]),
        (1417040544,[V(55.868,-4.84,-67.173),V(40.470,-4.84,-67.414),V(38.299,-4.84,-67.440),V(6.726,-4.84,-67.328),V(-27.704,-4.84,-67.336),V(-61.676,-4.84,-67.433),V(-95.545,-4.84,-67.339),V(-129.780,-4.84,-67.153)]),
        (1417040545,[V(-108.418,-4.84,-89.070),V(-129.780,-4.84,-67.153)]),
        (1417040546,[V(-74.270,-4.84,-89.081),V(-95.545,-4.84,-67.339)]),
        (1417040547,[V(-21.754,-4.84,-107.534),V(-61.676,-4.84,-67.433)]),
        (1417040548,[V(12.271,-4.84,-107.569),V(-27.704,-4.84,-67.336)]),
        (1417040549,[V(46.327,-4.84,-107.525),V(6.726,-4.84,-67.328)]),
        (1417040550,[V(80.302,-4.84,-107.584),V(40.470,-4.84,-67.414)]),
        (1417040551,[V(470.075,-4.84,-67.094),V(490.378,-4.84,-67.078),V(515.266,-4.84,-67.071)]),
        (1417040552,[V(-129.780,-4.84,-67.153),V(-185.565,-4.84,-67.256)]),
        (1417040554,[V(520.068,-4.84,-64.169),V(520.172,-4.84,-67.017),V(539.858,-4.84,-66.814)]),
    ]
}

private struct NavyPierPalette {
    let brick: UInt32, mortar: UInt32, cream: UInt32, paving: UInt32, seam: UInt32
    let white: UInt32, steel: UInt32, navy: UInt32, glass: UInt32, clear: UInt32
    let roof: UInt32, copper: UInt32, brass: UInt32, wood: UInt32, rubber: UInt32
    let warm: UInt32, blue: UInt32, cyan: UInt32, pink: UInt32, cabinLight: UInt32
    let window: UInt32, red: UInt32, sail: UInt32, flagBlue: UInt32
}

extension EiffelBuilder {
    func navyPier() {
        let previousRandom=randomState
        randomState=0x1916_2016_0743
        defer {randomState=previousRandom}
        func add(_ color: V,_ roughness: Float = 0.65,metal: Float = 0,emission: Float = 0,pattern: Float = 0,transmission: Float = 0) -> UInt32 {
            let i=UInt32(scene.materials.count)
            scene.materials.append(SceneMaterial(color,roughness:roughness,metallic:metal,emission:emission,pattern:pattern,transmission:transmission));return i
        }
        let p=NavyPierPalette(
            brick:add(V(0.38,0.145,0.068),0.91,pattern:10),mortar:add(V(0.53,0.44,0.32),0.93),
            cream:add(V(0.72,0.68,0.56),0.76),paving:add(V(0.50,0.49,0.44),0.89,pattern:1),seam:add(V(0.23,0.24,0.225),0.9),
            white:add(V(0.78,0.80,0.77),0.46,metal:0.22),steel:add(V(0.13,0.155,0.17),0.44,metal:0.65),
            navy:add(V(0.012,0.055,0.105),0.39,metal:0.28),glass:add(V(0.07,0.155,0.18),0.12,metal:0.56),
            clear:add(V(0.91,0.96,0.95),0.08,transmission:1),roof:add(V(0.59,0.62,0.58),0.67,metal:0.25),
            copper:add(V(0.17,0.37,0.30),0.58,metal:0.44),brass:add(V(0.63,0.40,0.13),0.35,metal:0.70),
            wood:add(V(0.28,0.18,0.095),0.65,pattern:3),rubber:add(V(0.025,0.031,0.028),0.95),
            warm:add(V(0.14,0.055,0.015),0.5,emission:2.0,pattern:8),blue:add(V(0.003,0.013,0.18),0.5,emission:3.1,pattern:8),
            cyan:add(V(0.004,0.085,0.15),0.5,emission:2.0,pattern:8),pink:add(V(0.11,0.009,0.065),0.5,emission:1.4,pattern:8),
            cabinLight:add(V(0.06,0.035,0.015),0.5,emission:0.38,pattern:8),
            window:add(V(0.10,0.17,0.16),0.15,metal:0.48,pattern:7),red:add(V(0.56,0.075,0.035),0.64),sail:add(V(0.79,0.76,0.65),0.90),flagBlue:add(V(0.12,0.47,0.64),0.84))
        navyPierDeck(p)
        navyPierGateway(p)
        navyPierWheel(p)
        navyPierPark(p)
        navyPierTheaters(p)
        navyPierHalls(p)
        navyPierBallroom(p)
        navyPierPromenade(p)
        navyPierBoatsAndMarina(p)
    }
    private func npBox(_ c:V,_ s:V,_ m:UInt32) {orientedBox(NavyPierLayout.point(c),NavyPierLayout.east,V(0,1,0),NavyPierLayout.south,s,m)}
    private func npQuad(_ a:V,_ b:V,_ c:V,_ d:V,_ m:UInt32) {quad(NavyPierLayout.point(a),NavyPierLayout.point(b),NavyPierLayout.point(c),NavyPierLayout.point(d),m)}
    private func npTri(_ a:V,_ b:V,_ c:V,_ m:UInt32) {tri(NavyPierLayout.point(a),NavyPierLayout.point(b),NavyPierLayout.point(c),m)}
    private func npBeam(_ a:V,_ b:V,_ w:Float,_ h:Float,_ m:UInt32) {beam(NavyPierLayout.point(a),NavyPierLayout.point(b),w,h,m)}
    private func npCylinder(_ a:V,_ b:V,_ r:Float,_ m:UInt32,segments:Int=12) {cylinder(NavyPierLayout.point(a),NavyPierLayout.point(b),r,m,segments:segments)}
    private func npLight(_ c:V,_ target:V,_ power:Float,_ color:V=V(1,0.73,0.43),range:Float=24) {
        scene.lights.append(NightLighting.source(NavyPierLayout.point(c),toward:NavyPierLayout.point(target),power:power,color:color,range:range,radius:0.45,outerDegrees:86,innerDegrees:58))
    }
    private func npRail(_ a:V,_ b:V,_ p:NavyPierPalette,height:Float=1.1,glass:Bool=false) {
        let delta=b-a,len=simd_length(delta);guard len>0.01 else{return};let t=delta/len
        for y:Float in [0.16,height] {npBeam(a+V(0,y,0),b+V(0,y,0),0.065,0.065,p.steel)}
        let n=max(1,Int(ceil(len/1.9)))
        for i in 0...n {let q=a+delta*(Float(i)/Float(n));npCylinder(q,q+V(0,height,0),0.032,p.steel,segments:6)}
        if glass {npQuad(a+V(0,0.18,0),b+V(0,0.18,0),b+V(0,height-0.1,0),a+V(0,height-0.1,0),p.clear)}
        else {
            for d in stride(from:Float(0.25),to:len,by:0.22) {let q=a+t*d;npBeam(q+V(0,0.17,0),q+V(0,height-0.04,0),0.024,0.027,p.steel)}
        }
    }
    private func npWindow(_ c:V,_ width:Float,_ height:Float,_ p:NavyPierPalette,side:Float=1,lit:Bool=false) {
        npBox(c,V(width,height,0.08),lit ? p.window:p.glass)
        for dx:Float in [-width/2,width/2] {npBox(c+V(dx,0,side*0.08),V(0.10,height+0.13,0.14),p.steel)}
        for dy:Float in [-height/2,height/2] {npBox(c+V(0,dy,side*0.08),V(width+0.13,0.11,0.14),p.steel)}
        npBox(c+V(0,0,side*0.09),V(0.055,height,0.14),p.steel)
    }
    private func npBench(_ c:V,_ p:NavyPierPalette) {
        for x:Float in [-1.1,1.1] {npBox(c+V(x,0.23,0),V(0.12,0.46,0.7),p.steel)}
        for z:Float in [-0.25,-0.08,0.09,0.26] {npBox(c+V(0,0.49,z),V(2.8,0.075,0.145),p.wood)}
        for y:Float in [0.73,0.92] {npBox(c+V(0,y,-0.31),V(2.8,0.14,0.065),p.wood)}
        for x:Float in [-1.1,1.1] {npBox(c+V(x,0.68,-0.32),V(0.055,0.69,0.07),p.steel)}
    }
    private func npBarrelRoof(_ x0:Float,_ x1:Float,_ z:Float,_ half:Float,_ spring:Float,_ rise:Float,_ p:NavyPierPalette,glazed:Bool=false,material:UInt32?=nil) {
        let roofMaterial=material ?? (glazed ? p.glass:p.roof)
        let n=32
        for j in 0..<n {
            let a=Float(j)*Float.pi/Float(n),b=Float(j+1)*Float.pi/Float(n)
            let z0=z+cos(a)*half,z1=z+cos(b)*half,y0=spring+sin(a)*rise,y1=spring+sin(b)*rise
            npQuad(V(x0,y0,z0),V(x1,y0,z0),V(x1,y1,z1),V(x0,y1,z1),roofMaterial)
            if j%2==0 {npBeam(V(x0,y0+0.055,z0),V(x1,y0+0.055,z0),0.10,0.12,p.white)}
            for x in stride(from:x0,through:x1+0.1,by:glazed ? 4:12) {npBeam(V(x,y0,z0),V(x,y1,z1),glazed ? 0.16:0.22,0.24,p.white)}
            for x:Float in [x0,x1] {npTri(V(x,spring,z),V(x,y0,z0),V(x,y1,z1),roofMaterial)}
        }
    }

    private func navyPierDeck(_ p:NavyPierPalette) {
        // The promenade is at the city's grade, 5.7 m above its lake datum.
        // Slight overhangs and fenders make the waterline legible from the boats.
        npBox(V(274,-2.82,0),V(925,6.04,134),p.cream)
        npBox(V(274,0.16,0),V(926,0.16,134.6),p.paving)
        for side:Float in [-1,1] {
            npBox(V(274,-1.1,side*67.1),V(926,0.22,0.19),p.cream)
            for x in stride(from:Float(-180),through:733,by:11.5) {
                npBox(V(x,-2.25,side*67.5),V(0.82,4.5,0.32),p.rubber)
                npCylinder(V(x,-5.6,side*67),V(x,-0.8,side*67),0.29,p.steel,segments:10)
            }
        }
        npBox(V(-25,3.30,0),V(66,6.20,91),p.cream)
        npBox(V(-25,6.36,0),V(66.4,0.08,91.4),p.paving)
        // The park's east apron reaches the Yard. South stairs provide a direct,
        // continuous route from the broad dock to this elevated public space.
        npBox(V(23,3.30,0),V(30,6.2,82),p.cream)
        for x in stride(from:Float(-184),through:734,by:3.6) {
            for side:Float in [-1,1] {npBox(V(x,0.245,side*60),V(0.018,0.010,14),p.seam)}
        }
        for side:Float in [-1,1] {for z in stride(from:Float(54),through:66,by:2.4) {npBox(V(274,0.246,side*z),V(925,0.01,0.018),p.seam)}}
    }

    private func navyPierGateway(_ p:NavyPierPalette) {
        // Red brick west headhouse with paired white lanterns, cornices,
        // individual bays and a clear central entry at the landward end.
        npBox(V(-150,9.0,-1.2),V(71,17.6,77),p.brick)
        for side:Float in [-1,1] {
            let z=side*38.8-1.2
            for x in stride(from:Float(-179),through:-120,by:6.6) {
                npWindow(V(x,5.4,z+side*0.12),4.65,5.4,p,side:side)
                npWindow(V(x,12.55,z+side*0.13),4.4,4.9,p,side:side)
                npBox(V(x-3.05,9,z+side*0.17),V(0.55,17.5,0.45),p.cream)
            }
            for y:Float in [0.85,8.5,16.2,17.9] {npBox(V(-150,y,z),V(74,0.35,0.8),p.cream)}
            npBox(V(-150,18.3,z),V(74,0.26,1.05),p.cream)
        }
        npBox(V(-150,18.05,-1.2),V(72,0.4,78),p.roof)
        for z:Float in [-28.9,26.3] {
            let c=V(-181.7,0,z)
            npBox(c+V(0,11.7,0),V(10.7,23.0,10.4),p.brick)
            for y:Float in [1.1,7,18.8,22.8] {npBox(c+V(0,y,0),V(11.2,0.42,11.0),p.cream)}
            for dx:Float in [-4.9,4.9] {npBox(c+V(dx,12,0),V(0.58,20.5,10.8),p.cream)}
            npCylinder(c+V(0,23.0,0),c+V(0,24.1,0),5.5,p.cream,segments:8)
            for j in 0..<8 {
                let a=Float(j)*Float.pi/4,cc=c+V(cos(a)*3.9,24,sin(a)*3.9)
                npCylinder(cc,cc+V(0,5.1,0),0.27,p.white,segments:8)
                let b=a+Float.pi/4
                npQuad(cc+V(0,0.3,0),c+V(cos(b)*3.9,24.3,sin(b)*3.9),c+V(cos(b)*3.9,28.8,sin(b)*3.9),cc+V(0,4.8,0),p.glass)
                npTri(c+V(cos(a)*5.0,29.3,sin(a)*5.0),c+V(cos(b)*5.0,29.3,sin(b)*5.0),c+V(0,33.5,0),p.cream)
            }
            npCylinder(c+V(0,29.0,0),c+V(0,29.4,0),5.1,p.cream,segments:8)
            npCylinder(c+V(0,33.3,0),c+V(0,36,0),0.07,p.brass,segments:8)
            npLight(c+V(-7,5,0),c+V(-4,16,0),90,range:28)
        }
        // Door glazing projects beyond the brick backing, with deep portal trim.
        npBox(V(-186.01,4.35,-1.2),V(0.12,7.9,34),p.glass)
        for z in stride(from:Float(-16),through:14,by:3.0) {npBox(V(-186.15,4.35,z),V(0.18,8.0,0.13),p.white)}
        npBox(V(-186.3,8.6,-1.2),V(0.40,0.5,35.5),p.cream)
        npLabel("NAVY PIER",V(-187.01,13.2,-1.2),V(0,0,1),V(-1,0,0),2.15,p.cream)
        // Crystal Gardens' twin barrel roofs and orthogonal fine glazing grid.
        npBox(V(-86.5,7.3,-1.8),V(53,14.2,66),p.glass)
        for side:Float in [-1,1] {
            for x in stride(from:Float(-112),through:-60,by:4) {npBox(V(x,9,side*33-1.8),V(0.14,17.2,0.16),p.white)}
            for y:Float in [3,6.4,9.8,13.3,16.5] {npBox(V(-86.5,y,side*33-1.8),V(53.2,0.13,0.18),p.white)}
        }
        npBarrelRoof(-113,-60,-18.3,16.5,16.5,8,p,glazed:true)
        npBarrelRoof(-113,-60,14.7,16.5,16.5,8,p,glazed:true)
        for z in stride(from:Float(-32),through:30,by:3.3) {npBox(V(-59.93,9,z),V(0.15,17.2,0.13),p.white)}
    }

    private func navyPierWheel(_ p:NavyPierPalette) {
        let hub=V(0,NavyPierLayout.wheelHubHeight,0),r=NavyPierLayout.wheelRadius
        // Two triangulated rim chords, 21 fully trussed radial spokes and six
        // angled supporting legs. The wheel rotates in the north/south plane.
        let sections=126
        for face:Float in [-1,1] {
            for k in 0..<sections {
                let a=Float(k)*2*Float.pi/Float(sections),b=Float(k+1)*2*Float.pi/Float(sections)
                func q(_ angle:Float,_ rad:Float)->V {hub+V(face*1.52,sin(angle)*rad,cos(angle)*rad)}
                npCylinder(q(a,r),q(b,r),0.145,p.white,segments:8)
                npBeam(q(a,r-1.1),q(b,r-1.1),0.07,0.085,p.white)
                npBeam(q(a,r),q(b,r-1.1),0.06,0.06,p.white)
                npBeam(q(a,r-1.1),q(b,r),0.06,0.06,p.white)
                npBeam(q(a,r)+V(face*0.30,0,0),q(b,r)+V(face*0.30,0,0),0.16,0.12,p.blue)
                if k%3==0 {npBeam(q(a,r),q(a,r)+V(-face*3.04,0,0),0.10,0.10,p.white)}
            }
            for k in 0..<NavyPierLayout.wheelSpokeCount {
                let a=Float(k)*2*Float.pi/Float(NavyPierLayout.wheelSpokeCount)
                let radial=V(0,sin(a),cos(a)),tan=V(0,cos(a),-sin(a))
                let a0=hub+V(face*1.2,0,0)+radial*2.5,b0=hub+V(face*1.52,0,0)+radial*r
                for sign:Float in [-1,1] {npCylinder(a0+tan*sign*0.30,b0+tan*sign*0.40,0.060,p.white,segments:6)}
                for j in 0..<12 {
                    let t0=Float(j)/12,t1=Float(j+1)/12
                    let aa=a0+(b0-a0)*t0,bb=a0+(b0-a0)*t1
                    npBeam(aa-tan*0.36,bb+tan*0.36,0.045,0.045,p.white)
                    npBeam(aa+tan*0.36,bb-tan*0.36,0.045,0.045,p.white)
                }
                npBeam(a0+V(face*0.24,0,0),b0+V(face*0.24,0,0),0.13,0.10,k%3==0 ? p.cyan:p.blue)
                let next=a+Float.pi/21
                npBeam(hub+radial*8+V(face*1.5,0,0),hub+V(face*1.5,sin(next)*r,cos(next)*r),0.025,0.025,p.steel)
            }
            for z:Float in [-18,0,18] {
                let foot=V(face*11.3,NavyPierLayout.parkFloor,z)
                npCylinder(foot,hub+V(face*1.7,0,0),0.49,p.white,segments:16)
                npBox(foot+V(0,0.13,0),V(2.1,0.26,2.1),p.steel)
                for dx:Float in [-0.7,0.7] {for dz:Float in [-0.7,0.7] {npCylinder(foot+V(dx,0.26,dz),foot+V(dx,0.36,dz),0.075,p.brass,segments:6)}}
            }
            npCylinder(hub+V(face*1.8,0,0),hub+V(face*2.0,0,0),3.25,p.white,segments:64)
            npCylinder(hub+V(face*2.01,0,0),hub+V(face*2.06,0,0),2.89,p.navy,segments:64)
            npLabel("NAVY",hub+V(face*2.12,0.7,0),V(0,0,-face),V(face,0,0),0.9,p.cyan)
            npLabel("PIER",hub+V(face*2.12,-0.55,0),V(0,0,-face),V(face,0,0),0.9,p.cyan)
        }
        npCylinder(hub-V(3,0,0),hub+V(3,0,0),0.73,p.steel,segments:24)
        for i in 0..<NavyPierLayout.wheelCabinCount {
            let a=Float(i)*2*Float.pi/Float(NavyPierLayout.wheelCabinCount)-Float.pi/2
            let pivot=hub+V(0,sin(a)*r,cos(a)*r),c=pivot-V(0,1.21,0)
            npCylinder(pivot-V(1.7,0,0),pivot+V(1.7,0,0),0.07,p.steel,segments:8)
            for face:Float in [-1,1] {npBeam(pivot+V(face*1.33,0,0),c+V(face*1.33,0.90,0),0.065,0.07,p.white)}
            npBox(c+V(0,-0.8,0),V(2.58,0.62,1.86),p.navy)
            npBox(c+V(0,0.15,0),V(2.54,1.27,1.78),p.glass)
            npBox(c+V(0,0.83,0),V(2.62,0.15,1.90),p.navy)
            for dx:Float in [-1.22,0,1.22] {for dz:Float in [-0.895,0.895] {npBox(c+V(dx,0.14,dz),V(0.055,1.4,0.055),p.steel)}}
            for dz:Float in [-0.905,0.905] {npBox(c+V(0,-0.43,dz),V(2.55,0.055,0.055),p.white)}
            for dx:Float in [-1.34,1.34] {
                npBox(c+V(dx,0.82,0),V(0.07,0.08,1.82),p.blue)
                npBox(c+V(dx,-0.72,0),V(0.07,0.07,1.82),p.blue)
                for dz:Float in [-0.88,0.88] {npBox(c+V(dx,0.02,dz),V(0.07,1.62,0.06),p.cyan)}
            }
            npBox(c+V(0,0.72,0),V(1.2,0.04,0.6),p.cabinLight)
            scene.detailCount += 1
        }
        npBox(V(-0.1,6.98,0),V(15,1.16,17),p.steel)
        for i in 0..<6 {let y:Float=6.4+Float(i+1)*0.19;npBox(V(-9.4+Float(i)*0.32,(6.4+y)/2,0),V(0.33,y-6.4,3.2),p.paving)}
        for z:Float in [-8.8,8.8] {npRail(V(-8,6.4,z),V(8,6.4,z),p)}
        // The ladder and fixed service platform are visible from the close view.
        npBeam(V(7.8,6.7,0),hub+V(2.5,-2.5,0),0.09,0.09,p.steel)
        npBeam(V(7.8,6.7,0.65),hub+V(2.5,-2.5,0.65),0.09,0.09,p.steel)
        for i in 0..<62 {let t=Float(i)/62;let q=V(7.8,6.7,0)+(hub+V(2.5,-2.5,0)-V(7.8,6.7,0))*t;npBeam(q,q+V(0,0,0.65),0.05,0.05,p.steel)}
        for x:Float in [-5.5,5.5] {npLight(V(x,9,0),hub,185,V(0.12,0.25,1),range:65)}
        for z:Float in [-20,20] {npLight(V(-4,7,z),V(0,33,z*0.55),95,V(0.26,0.15,1),range:44)}
        // Bounded fixture proxies light the white truss near the LED strips;
        // the visible strips themselves remain individual geometric emitters.
        for face:Float in [-1,1] {for i in 0..<6 {
            let a=Float(i)*Float.pi/3
            npLight(hub+V(face*5,sin(a)*20,cos(a)*20),hub+V(face*1.5,sin(a)*23,cos(a)*23),110,V(0.025,0.11,1),range:25)
        }}
    }

    private func navyPierPark(_ p:NavyPierPalette) {
        // Broad, bowed Wave Wall: actual individual treads, not a ramp texture.
        for step in 0..<32 {
            let y=0.24+Float(step+1)*(6.16/32),v=Float(step)/31
            for j in 0..<24 {
                let x0 = -23+Float(j)*2.2,x1=x0+2.2
                let curve0=sin((x0+23)/52.8*Float.pi)*4.6,curve1=sin((x1+23)/52.8*Float.pi)*4.6
                let z0=64-v*18-curve0,z1=64-v*18-curve1
                npQuad(V(x0,y,z0),V(x1,y,z1),V(x1,y,z1-0.65),V(x0,y,z0-0.65),p.cream)
                npQuad(V(x0,y,z0),V(x0,y-0.205,z0),V(x1,y-0.205,z1),V(x1,y,z1),p.cream)
                if step%4==0 {npBeam(V(x0,y+0.025,z0-0.06),V(x1,y+0.025,z1-0.06),0.025,0.025,p.warm)}
            }
        }
        for x:Float in [-25,32] {npRail(V(x,0.24,65),V(x,6.4,42),p)}
        for x:Float in [-8,12] {npLight(V(x,2.1,61),V(x,1.2,56),24,V(1,0.62,0.39),range:17)}
        // Carousel at the mapped south-west corner of the wheel: ribbed conical
        // canopy, poles, stylized horses and ornamental warm bulbs.
        let c=V(-34.8,6.4,30.7)
        npCylinder(c,c+V(0,0.35,0),6.6,p.cream,segments:48)
        npCylinder(c+V(0,0.35,0),c+V(0,5.1,0),1.0,p.red,segments:16)
        for i in 0..<24 {
            let a=Float(i)*Float.pi/12,b=Float(i+1)*Float.pi/12
            let aa=c+V(cos(a)*6.7,4.6,sin(a)*6.7),bb=c+V(cos(b)*6.7,4.6,sin(b)*6.7)
            npTri(aa,bb,c+V(0,7.1,0),i%2==0 ? p.cream:p.red)
            npBeam(aa,c+V(0,7.1,0),0.07,0.08,p.brass)
            npBeam(aa,bb,0.32,0.45,p.brass)
            npCylinder(aa,aa+V(0,0.11,0),0.09,p.warm,segments:6)
            if i%2==0 {
                let q=c+V(cos(a)*4.9,0.35,sin(a)*4.9)
                npCylinder(q,q+V(0,4.2,0),0.06,p.brass,segments:8)
                ellipsoid(NavyPierLayout.point(q+V(0,1.2,0)),V(0.62,0.24,0.22),p.cream,segments:10,rings:5)
                npBeam(q+V(0.5,1.1,0),q+V(0.62,1.85,0),0.21,0.24,p.cream)
                for dx:Float in [-0.42,0.42] {npBeam(q+V(dx,1.1,0),q+V(dx+0.12,0.63,0.1),0.09,0.09,p.cream)}
                npBox(q+V(0,1.43,0),V(0.48,0.12,0.41),p.red)
            }
        }
        npLight(c+V(0,4.3,0),c,35,range:13)
        for (x,z):(Float,Float) in [(-39,35),(-37,-4),(-14,-33),(21,27)] {
            npLight(V(x,11.2,z),V(x,6.4,z),38,V(1,0.65,0.35),range:18)
        }
        // Wave Swinger, teacups and a compact light tower give the mapped park
        // its real group of small attractions around the observation wheel.
        let swing=V(-34.4,6.4,-0.2)
        npCylinder(swing,swing+V(0,7.0,0),0.52,p.navy,segments:16)
        for i in 0..<20 {
            let a=Float(i)*Float.pi/10,b=Float(i+1)*Float.pi/10
            let aa=swing+V(cos(a)*5.7,6.2,sin(a)*5.7),bb=swing+V(cos(b)*5.7,6.2,sin(b)*5.7)
            npTri(aa,bb,swing+V(0,8.3,0),i%2==0 ? p.brass:p.red)
            let seat=swing+V(cos(a)*5.15,1.1,sin(a)*5.15)
            npBeam(aa,seat,0.025,0.025,p.steel);npBox(seat,V(0.48,0.12,0.48),p.red)
        }
        for i in 0..<8 {let a=Float(i)*Float.pi/4;let q=V(-29.4+cos(a)*2,6.6,13.6+sin(a)*2);npCylinder(q,q+V(0,0.65,0),0.56,i%2==0 ? p.red:p.cream,segments:12)}
        let lt=V(-30.8,6.4,-31.6)
        for x:Float in [-0.65,0.65] {for z:Float in [-0.65,0.65] {npBeam(lt+V(x,0,z),lt+V(x,16,z),0.15,0.15,p.white)}}
        for y in stride(from:Float(1),through:16,by:1) {npBox(lt+V(0,y,0),V(1.6,0.11,1.6),p.cyan)}
        // Native ornamental gardens, restrained so ride views stay open.
        for (x,z):(Float,Float) in [(-52,-29),(-52,23),(22,-32),(28,31),(38,38),(-14,-39)] {
            npBox(V(x,6.7,z),V(5.1,0.6,3.5),p.cream)
            npBox(V(x,7.02,z),V(4.7,0.07,3.1),grass)
            npTree(V(x,7.02,z),height:4.5)
        }
        npLabel("CENTENNIAL WHEEL",V(-14.1,7.7,19),V(0,0,1),V(-1,0,0),0.58,p.navy)
    }

    private func navyPierTheaters(_ p:NavyPierPalette) {
        // The Yard occupies the former Skyline Stage's tent-like volume.
        let c=V(62.1,6.4,-1.4)
        npBox(c+V(0,5.0,0),V(73,10,42),p.steel)
        for side:Float in [-1,1] {
            npBox(c+V(0,4.8,side*21.08),V(71,8.5,0.08),p.glass)
            for x in stride(from:Float(-35),through:35,by:3.5) {npBox(c+V(x,5.0,side*21.2),V(0.13,10,0.20),p.white)}
            for y:Float in [1.5,5,8.5] {npBox(c+V(0,y,side*21.2),V(73,0.15,0.20),p.white)}
            for x:Float in [-36.5,36.5] {
                npTri(c+V(x,10,side*21),c+V(x,10,0),c+V(x*0.30,16,0),p.white)
                npQuad(c+V(x,10,side*21),c+V(0,10,side*21),c+V(0,16,0),c+V(x*0.30,16,0),p.white)
            }
        }
        npCylinder(c+V(0,15.8,0),c+V(0,18.4,0),0.15,p.white,segments:10)
        npBox(V(74,10.25,29.3),V(55,7.7,17),p.glass)
        for x in stride(from:Float(47),through:101,by:3) {npBox(V(x,10.25,38),V(0.13,7.7,0.19),p.white)}
        npBox(V(74,14.3,29),V(55.8,0.35,18.2),p.roof)
        npLabel("THE YARD",V(65,12.7,38.2),V(1,0,0),V(0,0,1),0.88,p.white)
        // Long theater face and the transparent, round southeast stair tower.
        npBox(V(146,14.2,44.9),V(79,27.7,24),p.steel)
        for x in stride(from:Float(109),through:183,by:3.6) {npWindow(V(x,13.9,57.03),3.37,24.6,p,lit:true)}
        for y:Float in [1.4,7.7,14.2,20.4,27.7] {npBox(V(146,y,57.23),V(79.6,0.22,0.42),p.white)}
        npBox(V(146,28.1,44.9),V(80,0.45,25.1),p.roof)
        let tc=V(171,0.24,44.8),radius:Float=12.4
        for i in 0..<48 {
            let a=Float(i)*Float.pi/24,b=Float(i+1)*Float.pi/24
            let aa=tc+V(cos(a)*radius,0,sin(a)*radius),bb=tc+V(cos(b)*radius,0,sin(b)*radius)
            npQuad(aa,bb,bb+V(0,28.5,0),aa+V(0,28.5,0),p.glass)
            npBeam(aa,aa+V(0,28.8,0),0.13,0.14,p.white)
            for y:Float in [0.4,4.8,9.4,14,18.6,23.2,28.6] {npBeam(aa+V(0,y,0),bb+V(0,y,0),0.16,0.25,p.white)}
            npTri(tc+V(0,29,0),aa+V(0,29,0),bb+V(0,29,0),p.roof)
            if i%4==0 {npBeam(aa+V(0,29.1,0),bb+V(0,29.1,0),0.06,0.06,p.cyan)}
        }
        npLabel("CHICAGO SHAKESPEARE",V(132,5.7,57.65),V(1,0,0),V(0,0,1),0.80,p.white)
        for x:Float in [112,139,174] {npLight(V(x,4.0,62),V(x,16,55),65,V(0.33,0.67,1),range:29)}
    }

    private func navyPierHalls(_ p:NavyPierPalette) {
        // Four repeated structural bays, mapped terminal projections and service
        // elevations preserve the long industrial hall behind the modern hotel.
        npBox(V(367,7.1,-4),V(360,13.7,78),p.brick)
        for side:Float in [-1,1] {
            let z:Float=side<0 ? -43:35
            for x in stride(from:Float(192),through:542,by:6.8) {
                npWindow(V(x,6.8,z+side*0.12),4.7,8.1,p,side:side,lit:true)
                npBox(V(x-3.05,7.1,z+side*0.17),V(0.65,13.7,0.65),p.cream)
            }
            for y:Float in [1,3,11.3,13.6] {npBox(V(367,y,z),V(361,0.25,0.65),p.cream)}
        }
        for x:Float in [219,301,383,465] {npBarrelRoof(x-35,x+35,-4,37,14.2,6.4,p)}
        for x:Float in [260.5,342.6,424.9,507.4] {
            for side:Float in [-1,1] {
                npBox(V(x,8.4,side*39),V(11.2,16.3,13),p.brick)
                npBox(V(x,16.7,side*39),V(11.9,0.45,13.9),p.cream)
                npWindow(V(x,9.2,side*45.7),7.0,9.2,p,side:side)
                for dx:Float in [-4.9,4.9] {npBox(V(x+dx,8.4,side*45.7),V(0.5,16,0.35),p.cream)}
            }
        }
        // Sable's three dark, slender wings: modeled sawtooth window reveals
        // and five occupied registers over a taller glass public ground floor.
        for (index,range) in [(Float(0),Float(271)),(Float(1),Float(361)),(Float(2),Float(451))] {
            let x=range,length:Float=82,front:Float=47.0
            npBox(V(x,17.8,39.7),V(length,27.9,13.7),p.steel)
            npBox(V(x,4.15,40.2),V(length,7.8,13.8),p.glass)
            for j in 0..<20 {
                let xx=x-length/2+(Float(j)+0.5)*length/20
                // A slightly projecting angled bay frames each lake-facing room.
                let a=V(xx-1.82,0,front),b=V(xx+1.82,0,front+0.64)
                for floor in 0..<5 {
                    let y=9.9+Float(floor)*4.13
                    let m=(j+floor*3+Int(index))%5==0 ? p.window:p.glass
                    npQuad(a+V(0,y-1.81,0),b+V(0,y-1.81,0),b+V(0,y+1.81,0),a+V(0,y+1.81,0),m)
                    npBox(V(xx+1.95,y,front+0.18),V(0.31,4.06,1.13),p.cream)
                    npBeam(a+V(0,y,0),a+V(0,y+1.8,0),0.065,0.09,p.white)
                    npBeam(b+V(0,y-1.81,0),b+V(0,y+1.81,0),0.065,0.09,p.white)
                    npBox(V(xx-1.1,y,front-0.03),V(0.09,3.64,0.15),p.white)
                }
                npBox(V(xx,4.4,front),V(0.12,7.8,0.15),p.white)
                if j%4==0 {npCylinder(V(xx,0.24,front+0.6),V(xx,7.85,front+0.6),0.28,p.white,segments:12)}
            }
            for y:Float in [8.0,11.95,16.08,20.21,24.34,28.47,30.70] {npBox(V(x,y,front+0.24),V(length+0.3,0.40,1.05),p.steel)}
            npBox(V(x,31.1,39.7),V(length+0.5,0.45,14.2),p.steel)
            for y:Float in [12.0,20.2,28.5] {npBox(V(x-length/2-0.01,y,39.7),V(0.06,0.03,13.7),p.seam)}
            npLabel(index==0 ? "SABLE HOTEL":"SABLE",V(x,7.50,front+0.84),V(1,0,0),V(0,0,1),index==0 ? 0.84:0.72,p.warm)
            for d:Float in [-29,0,29] {npLight(V(x+d,7.0,front+0.8),V(x+d,1,front+4.5),43,range:18)}
        }
        // West Terminal and Lakeview Terrace at the eastern change in scale.
        for (x,l):(Float,Float) in [(545.5,19.5),(597.9,79.0)] {
            npBox(V(x,6.4,-1.8),V(l,12.3,64),p.brick)
            for side:Float in [-1,1] {
                for xx in stride(from:x-l/2+3.7,to:x+l/2,by:6.3) {npWindow(V(xx,6.8,side*32-1.8),4.3,8.4,p,side:side,lit:true)}
                for y:Float in [1.3,5.5,11.9,12.6] {npBox(V(x,y,side*32-1.8),V(l+0.6,0.27,0.65),p.cream)}
            }
            npBox(V(x,12.85,-1.8),V(l+0.9,0.35,65),p.cream)
            npRail(V(x-l/2,13.1,30),V(x+l/2,13.1,30),p,glass:true)
        }
        // Offshore's roof terrace has a light glazed pavilion and actual tables.
        npBox(V(584,16.0,-1.8),V(43.5,5.8,16),p.glass)
        npBox(V(584,19.1,-1.8),V(44.2,0.35,16.8),p.white)
        for x in stride(from:Float(563),through:605,by:3.8) {npBox(V(x,16,6.4),V(0.11,5.8,0.15),p.white)}
        for x in stride(from:Float(564),through:628,by:7.3) {for z:Float in [-23,20] {npTable(V(x,13.1,z),p)}}
        npLabel("OFFSHORE",V(586,17.7,6.8),V(1,0,0),V(0,0,1),1.0,p.white)
        npLabel("NAVY PIER",V(546,10.4,31),V(1,0,0),V(0,0,1),0.92,p.cream)
    }

    private func navyPierBallroom(_ p:NavyPierPalette) {
        let c=V(669.8,0,-1.2),rx:Float=31.5,rz:Float=29.5
        // East End's semicircular brick drum and west connecting block. The
        // masonry is assembled around individual windows instead of a sticker.
        npBox(c+V(-15,7.9,0),V(33,15.3,59),p.brick)
        let n=32
        for i in 0..<n {
            let a = -Float.pi/2+Float(i)*Float.pi/Float(n),b = -Float.pi/2+Float(i+1)*Float.pi/Float(n)
            func q(_ angle:Float,_ y:Float,_ inset:Float=0)->V {c+V(cos(angle)*(rx+inset),y,sin(angle)*(rz+inset))}
            for (lo,hi):(Float,Float) in [(0.24,1.3),(6.7,8.2),(13.2,15.7)] {npQuad(q(a,lo),q(b,lo),q(b,hi),q(a,hi),p.brick)}
            npQuad(q(a,1.3,-0.025),q(b,1.3,-0.025),q(b,6.7,-0.025),q(a,6.7,-0.025),p.window)
            npQuad(q(a,8.2,-0.025),q(b,8.2,-0.025),q(b,13.2,-0.025),q(a,13.2,-0.025),p.glass)
            for y:Float in [0.75,1.35,7.25,7.75,13.4,15.4,15.95] {npBeam(q(a,y,0.2),q(b,y,0.2),0.24,y>13 ? 0.44:0.24,p.cream)}
            npBeam(q(a,1.35,0.08),q(a,13.2,0.08),0.10,0.12,p.steel)
            for y:Float in [3.7,5.3,10.4] {npBeam(q(a,y,0.06),q(b,y,0.06),0.07,0.07,p.steel)}
            if i%2==0 {
                npBeam(q(a,0.25,0.25),q(a,13.5,0.25),0.72,0.84,p.cream)
                npBeam(q(a,13.5,0.25),q(a,15.5,0.25),0.46,0.51,p.brick)
            }
            // Copper dome: shallow curved slices with standing seam ribs.
            for ring in 0..<16 {
                let u0=Float(ring)/16*Float.pi/2,u1=Float(ring+1)/16*Float.pi/2
                func dome(_ angle:Float,_ u:Float)->V {c+V(cos(angle)*rx*cos(u),16.1+8.3*sin(u),sin(angle)*rz*cos(u))}
                npQuad(dome(a,u0),dome(b,u0),dome(b,u1),dome(a,u1),p.copper)
                if i%2==0 {npBeam(dome(a,u0)+V(0,0.045,0),dome(a,u1)+V(0,0.045,0),0.055,0.07,p.copper)}
            }
            if i%5==1 {let cc=q(a,1.1,3);npLight(cc,q(a,12),64,V(1,0.74,0.47),range:26)}
        }
        for a:Float in [-1.30,-0.43,0.43,1.30] {
            let rim=c+V(cos(a)*(rx+2.8),16.4,sin(a)*(rz+2.8))
            npLight(rim,c+V(cos(a)*rx*0.62,21,sin(a)*rz*0.62),185,V(1,0.78,0.56),range:36)
        }
        // The western half is a matching barrel vault, retaining the two high
        // square towers that distinguish the ballroom from a generic rotunda.
        npBarrelRoof(637,669.8,-1.2,29.5,16.1,8.3,p,material:p.copper)
        for side:Float in [-1,1] {
            let tc=V(645.2,0,-1.2+side*25)
            npBox(tc+V(0,14.3,0),V(9.5,28.1,9.4),p.brick)
            for dx:Float in [-4.42,4.42] {npBox(tc+V(dx,15.5,0),V(0.52,22.6,9.7),p.cream)}
            for dz:Float in [-4.43,4.43] {npBox(tc+V(0,15.5,dz),V(9.7,22.6,0.52),p.cream)}
            for y:Float in [2.1,16,27.3,28.3] {npBox(tc+V(0,y,0),V(10.2,0.44,10.1),p.cream)}
            for side2:Float in [-1,1] {
                npBox(tc+V(side2*4.76,18.1,0),V(0.07,15.8,2.65),p.cream)
                npBox(tc+V(0,18.1,side2*4.72),V(2.65,15.8,0.07),p.cream)
                for y in stride(from:Float(11),through:25.0,by:1.15) {
                    npBox(tc+V(side2*4.82,y,0),V(0.08,0.08,2.55),p.mortar)
                    npBox(tc+V(0,y,side2*4.81),V(2.55,0.08,0.08),p.mortar)
                }
            }
            npBox(tc+V(0,29.0,0),V(8.1,0.55,8.1),p.cream)
            for dx:Float in [-2.8,2.8] {for dz:Float in [-2.8,2.8] {npCylinder(tc+V(dx,29.1,dz),tc+V(dx,33.6,dz),0.30,p.cream,segments:10)}}
            npBox(tc+V(0,33.8,0),V(7.7,0.37,7.7),p.cream)
            for i in 0..<4 {
                let a=Float(i)*Float.pi/2+Float.pi/4,b=a+Float.pi/2
                npTri(tc+V(cos(a)*5.5,34.0,sin(a)*5.5),tc+V(cos(b)*5.5,34.0,sin(b)*5.5),tc+V(0,38.3,0),p.brass)
            }
            npCylinder(tc+V(0,38.1,0),tc+V(0,40.0,0),0.065,p.brass,segments:8)
            npBox(tc+V(0,31.2,0),V(1.1,2.5,1.1),p.cabinLight)
            npLight(tc+V(0,28.8,0),tc+V(0,35,0),45,range:16)
            npLight(tc+V(7,15,side*7),tc+V(3,23,side*3),155,V(1,0.76,0.51),range:28)
            npLight(tc+V(-7,4,side*3),tc+V(-4.5,22,0),82,range:30)
        }
        // The historic USS Chicago anchor is a sculptural iron landmark at the
        // east apron: stock, crown, curved arms and thick flukes, on a low plinth.
        let ac=V(722,0.24,-1.2)
        npBox(ac+V(0,0.25,0),V(6.2,0.5,4.8),p.cream)
        npBeam(ac+V(0,0.5,0),ac+V(0,5.1,0),0.5,0.52,p.steel)
        npBeam(ac+V(-2.2,3.8,0),ac+V(2.2,3.8,0),0.35,0.48,p.steel)
        for side:Float in [-1,1] {
            npBeam(ac+V(0,0.65,0),ac+V(side*1.4,1.05,0),0.46,0.48,p.steel)
            npBeam(ac+V(side*1.4,1.05,0),ac+V(side*2.1,2.0,0),0.40,0.48,p.steel)
            npTri(ac+V(side*1.3,1.7,0.25),ac+V(side*2.6,2.7,0.25),ac+V(side*2.4,0.8,0.25),p.steel)
        }
        for i in 0..<24 {let a=Float(i)*Float.pi/12,b=Float(i+1)*Float.pi/12;npCylinder(ac+V(cos(a)*0.40,5.35+sin(a)*0.40,0),ac+V(cos(b)*0.40,5.35+sin(b)*0.40,0),0.11,p.steel,segments:8)}
        npLabel("USS CHICAGO",ac+V(3.15,0.43,0),V(0,0,-1),V(1,0,0),0.30,p.steel)
        for z in stride(from:Float(-49),through:49,by:14) {
            let q=V(731,0.24,z);npCylinder(q,q+V(0,11.6,0),0.068,p.white,segments:10)
            // Chicago's white flag, two pale-blue stripes and red star accents.
            npQuad(q+V(0,8.9,0),q+V(-3.2,8.9,0.15),q+V(-3.2,10.7,0.15),q+V(0,10.7,0),p.white)
            for y:Float in [9.15,10.15] {npQuad(q+V(-0.1,y,0.025),q+V(-3.1,y,0.17),q+V(-3.1,y+0.25,0.17),q+V(-0.1,y+0.25,0.025),p.flagBlue)}
            for x:Float in [-0.55,-1.20,-1.85,-2.5] {npBox(q+V(x,9.8,0.15),V(0.19,0.19,0.05),p.red)}
        }
    }

    private func npTable(_ c:V,_ p:NavyPierPalette) {
        npCylinder(c,c+V(0,0.72,0),0.08,p.steel,segments:8)
        npCylinder(c+V(0,0.72,0),c+V(0,0.79,0),0.73,p.wood,segments:16)
        for side:Float in [-1,1] {
            npBox(c+V(0,0.45,side*1.02),V(0.50,0.07,0.50),p.wood)
            npBox(c+V(0,0.70,side*1.25),V(0.51,0.50,0.065),p.wood)
            for dx:Float in [-0.20,0.20] {npBeam(c+V(dx,0.02,side*1.02),c+V(dx,0.45,side*1.02),0.035,0.035,p.steel)}
        }
    }
    private func navyPierPromenade(_ p:NavyPierPalette) {
        for side:Float in [-1,1] {
            // Leave deliberate boarding breaks opposite the five excursion docks.
            for x in stride(from:Float(-185),to:731,by:18) {
                let gate = side>0 ? [-120,74,280,390,495].contains(where:{abs(Float($0)-x)<14}) : [77.6,202.8,520.1].contains(where:{$0>=x-1.5 && $0<=x+19.2})
                if !gate {npRail(V(x,0.24,side*66.1),V(min(x+17.7,735),0.24,side*66.1),p)}
            }
            for x in stride(from:Float(-180),through:725,by:24) {
                let q=V(x,0.24,side*64.8)
                npCylinder(q,q+V(0,0.68,0),0.17,p.steel,segments:10)
                npCylinder(q+V(0,0.57,0),q+V(0,0.68,0),0.25,p.steel,segments:10)
                let l=V(x,0.24,side*61.9)
                npCylinder(l,l+V(0,7.5,0),0.075,p.steel,segments:10)
                npBox(l+V(0,7.1,-side*0.45),V(0.24,0.16,1.1),p.white)
                npBox(l+V(0,7.0,-side*0.82),V(0.25,0.035,0.40),p.warm)
                npLight(l+V(0,6.95,-side*0.85),l+V(0,0,-side*4),49,range:21)
                if side>0 && (x < -30 || x>40) {
                    npBox(V(x+7,0.44,53),V(4.8,0.40,3.8),p.cream)
                    npBox(V(x+7,0.67,53),V(4.4,0.05,3.4),grass)
                    npTree(V(x+7,0.68,53),height:5.2)
                    npBench(V(x+12,0.24,54),p)
                }
            }
        }
        npRail(V(736,0.24,-66),V(736,0.24,66),p)
        // Lower dock's glazed restaurants and a slender line of string lights.
        for (x,l):(Float,Float) in [(-116,26),(88,25),(204,29)] {
            npBox(V(x,2.95,48.3),V(l,5.4,9.5),p.glass)
            npBox(V(x,5.80,48.3),V(l+0.5,0.25,10.1),p.steel)
            for xx in stride(from:x-l/2,through:x+l/2,by:2.8) {npBox(V(xx,2.9,53.1),V(0.09,5.4,0.14),p.white)}
            for xx in stride(from:x-l/2+3,to:x+l/2,by:4) {npTable(V(xx,0.24,57.9),p)}
            for xx in stride(from:x-l/2,to:x+l/2,by:1.2) {npCylinder(V(xx,5.0,59),V(xx,5.08,59),0.045,p.warm,segments:6)}
        }
        // Beer Garden: colonnaded entry, lattice canopy and picnic furniture.
        npLabel("NAVY PIER",V(581,6.2,49),V(1,0,0),V(0,0,1),1.3,p.white)
        for x:Float in [562,600] {npCylinder(V(x,0.24,48),V(x,7.4,48),0.16,p.navy,segments:12)}
        npBeam(V(562,7.4,48),V(600,7.4,48),0.20,0.28,p.navy)
        for x in stride(from:Float(557),through:629,by:9) {for z:Float in [38,45] {npTable(V(x,0.24,z),p)}}
    }

    private func navyPierBoatsAndMarina(_ p:NavyPierPalette) {
        // Fleet types and South Dock berths appear on the owner's 2023 map.
        // These are original, static excursion-vessel interpretations, not a
        // claim about today's exact charter schedule or registered hull designs.
        for (x,z,length,width,floors):(Float,Float,Float,Float,Int) in [(-120,85,36,8.5,2),(74,93,64,14,3),(280,85,57,13,3),(390,86,61,13.5,3),(495,85,53,12,3)] {
            npCruiseBoat(V(x,-5.45,z),length:length,width:width,decks:floors,p:p)
            npBox(V(x,-0.12,71.2),V(4,0.22,11),p.wood)
            npRail(V(x-2,0.0,65.8),V(x-2,0.0,76.5),p,height:0.95)
            npRail(V(x+2,0.0,65.8),V(x+2,0.0,76.5),p,height:0.95)
            for dx:Float in [-length*0.32,length*0.32] {
                npBeam(V(x+dx,0.70,65),V(x+dx,-3.1,z-width/2),0.055,0.055,p.wood)
            }
        }
        // Windy: the distinctive four-masted schooner, with furled cream canvas,
        // stays and rigging. Keeping canvas furled opens views across the dock.
        let c=V(190,-5.45,87),length:Float=43.8,width:Float=7.8
        npCruiseBoat(c,length:length,width:width,decks:0,p:p)
        for x:Float in [-14,-5,5,14] {
            let q=c+V(x,1.9,0),height:Float=x==14 ? 19:22
            npCylinder(q,q+V(0,height,0),0.13,p.wood,segments:10)
            npBeam(q+V(-5.0,3.5,0),q+V(5,3.5,0),0.15,0.17,p.wood)
            npCylinder(q+V(-4.9,3.67,0),q+V(4.9,3.67,0),0.22,p.sail,segments:8)
            for side:Float in [-1,1] {
                npBeam(c+V(x-3,2.0,side*3.5),q+V(0,height-1,0),0.021,0.021,p.steel)
                npBeam(c+V(x+3,2.0,side*3.5),q+V(0,height-1,0),0.021,0.021,p.steel)
            }
            npBeam(q+V(0,height-0.5,0),q+V(-6,3.5,0),0.025,0.025,p.steel)
        }
        npBeam(c+V(20,2.4,0),c+V(29,4.0,0),0.16,0.18,p.wood)
        npBeam(c+V(-14,23.0,0),c+V(29,4,0),0.025,0.025,p.steel)
        npLabel("WINDY",c+V(5,1.15,3.99),V(1,0,0),V(0,0,1),0.6,p.cream)
        // Fresh OSM centerlines retain the marina's distinctive angled fingers.
        for (id,points) in NavyPierLayout.marinaCenterlines {
            for i in 1..<points.count {
                let a=points[i-1],b=points[i],t=simd_normalize(b-a),n=V(-t.z,0,t.x)
                npBeam(a,b,2.3,0.34,p.wood)
                for side:Float in [-1,1] {npBeam(a+n*side*1.16,b+n*side*1.16,0.10,0.22,p.steel)}
                let length=simd_distance(a,b)
                for distance in stride(from:Float(1.0),to:length,by:4.0) {
                    let q=a+t*distance
                    npBeam(q-n*1.1+V(0,0.18,0),q+n*1.1+V(0,0.18,0),0.018,0.018,p.seam)
                }
            }
            let isFinger=(1417040532...1417040542).contains(id) || (1417040545...1417040550).contains(id)
            if isFinger,let a=points.first,let b=points.last {
                let t=simd_normalize(b-a),n=V(-t.z,0,t.x),length=simd_distance(a,b)
                for (index,distance) in [Float(8),min(28,length-7)].enumerated() {
                    let q=a+t*distance
                    npCylinder(q-V(0,1,0),q+V(0,0.60,0),0.095,p.steel,segments:8)
                    npBox(q+V(0,0.4,0.9),V(0.24,0.72,0.28),p.white)
                    npBox(q+V(0,0.79,0.9),V(0.25,0.04,0.29),p.warm)
                    npLight(q+V(0,1.25,0),q+n*(index==0 ? 4.0:-4.0)+V(0,-0.55,0),35,V(0.70,0.83,1),range:17)
                    let yacht=q+n*(index==0 ? 4.3:-4.3)
                    npSmallYacht(V(yacht.x,-5.45,yacht.z),length:11.4+Float(id%3)*1.5,width:3.8,sailing:id%4==0,p:p,angle:atan2(-t.x,t.z))
                }
            }
        }
        for x:Float in [77.6,202.8,520.1] {
            npQuad(V(x-1.1,0.24,-62.5),V(x+1.1,0.24,-62.5),V(x+1.1,-4.65,-69.4),V(x-1.1,-4.65,-69.4),p.wood)
            npRail(V(x-1.1,0.24,-62.5),V(x-1.1,-4.65,-69.4),p,height:0.95)
            npRail(V(x+1.1,0.24,-62.5),V(x+1.1,-4.65,-69.4),p,height:0.95)
        }
        // Small two-storey marina boathouse on the shoreline, mapped separately.
        npBox(V(98.7,3.3,-74.2),V(14.5,6.2,10.7),p.white)
        for side:Float in [-1,1] {for x:Float in [94,99,104] {npWindow(V(x,4.0,-74.2+side*5.40),3.8,3.7,p,side:side)}}
        npBox(V(98.7,6.6,-74.2),V(15.4,0.35,11.5),p.steel)
        npLabel("NAVY PIER MARINA",V(98.7,5.9,-79.8),V(-1,0,0),V(0,0,-1),0.53,p.navy)
    }
    private func npCruiseBoat(_ c:V,length:Float,width:Float,decks:Int,p:NavyPierPalette) {
        let plan:[SIMD2<Float>]=[SIMD2(-0.49,-0.31),SIMD2(-0.40,-0.49),SIMD2(0.32,-0.50),SIMD2(0.44,-0.35),SIMD2(0.52,0),SIMD2(0.44,0.35),SIMD2(0.32,0.50),SIMD2(-0.40,0.49),SIMD2(-0.49,0.31)]
        for i in plan.indices {
            let j=(i+1)%plan.count,a=plan[i],b=plan[j]
            let aa=c+V(a.x*length,1.82,a.y*width),bb=c+V(b.x*length,1.82,b.y*width)
            let lo0=c+V(a.x*length*0.92,-0.95,a.y*width*0.66),lo1=c+V(b.x*length*0.92,-0.95,b.y*width*0.66)
            npQuad(lo0,lo1,bb,aa,decks==0 ? p.navy:p.white)
            npTri(c+V(0,1.83,0),aa,bb,p.wood)
            npBeam(aa-V(0,0.42,0),bb-V(0,0.42,0),0.17,0.23,p.navy)
            npRail(aa,bb,p,height:0.85)
            if i%2==0 {npCylinder((aa+bb)/2+V(0,-0.8,0),(aa+bb)/2+V(0,-1.5,0),0.17,p.rubber,segments:10)}
        }
        if decks>0 {
            for level in 0..<decks {
                let l=length*(0.75-Float(level)*0.10),w=width*(0.84-Float(level)*0.06),y=3.12+Float(level)*2.65
                npBox(c+V(-length*0.04,y,0),V(l,2.45,w),p.white)
                for side:Float in [-1,1] {
                    let count=max(4,Int(l/2.5))
                    for j in 0..<count {let xx = -length*0.04-l/2+(Float(j)+0.5)*l/Float(count);npWindow(c+V(xx,y+0.10,side*(w/2+0.045)),l/Float(count)-0.18,1.35,p,side:side)}
                    npBeam(c+V(-length*0.04-l/2,y+1.34,side*(w/2+0.20)),c+V(-length*0.04+l/2,y+1.34,side*(w/2+0.20)),0.07,0.08,p.warm)
                }
                npBox(c+V(-length*0.04,y+1.32,0),V(l+1.1,0.18,w+0.7),p.white)
                if level==decks-1 {
                    for side:Float in [-1,1] {npRail(c+V(-length*0.04-l/2,y+1.44,side*(w/2+0.15)),c+V(-length*0.04+l/2,y+1.44,side*(w/2+0.15)),p,height:0.86)}
                    for xx in stride(from:-l*0.42,through:l*0.25,by:2.2) {for side:Float in [-1,1] {
                        npBox(c+V(xx,y+1.84,side*w*0.30),V(0.5,0.08,0.56),p.white)
                        npBox(c+V(xx-0.25,y+2.1,side*w*0.30),V(0.08,0.45,0.56),p.white)
                    }}
                }
            }
            let top=Float(decks)*2.65+3.2
            npBox(c+V(length*0.16,top,0),V(length*0.13,2.1,width*0.53),p.navy)
            npBox(c+V(length*0.16,top+0.1,0),V(length*0.135,1.1,width*0.54),p.glass)
            npBox(c+V(length*0.16,top+1.15,0),V(length*0.16,0.16,width*0.59),p.white)
            npCylinder(c+V(0,top,0),c+V(0,top+5.8,0),0.075,p.white,segments:10)
            for y:Float in [top+3.4,top+4.6] {npBeam(c+V(-1.25,y,0),c+V(1.25,y,0),0.07,0.07,p.white)}
            npBox(c+V(-length*0.25,top-1,0),V(1.8,2.4,width*0.25),p.navy)
            for side:Float in [-1,1] {npLight(c+V(0,5.0,side*width*0.42),c+V(0,-0.2,side*width),35,V(1,0.77,0.47),range:17)}
        }
    }
    private func npSmallYacht(_ c:V,length:Float,width:Float,sailing:Bool,p:NavyPierPalette,angle:Float=0) {
        let firstVertex=scene.vertices.count
        // Long axis north/south to fit the transverse marina slips.
        let plan:[SIMD2<Float>]=[SIMD2(-0.45,-0.45),SIMD2(0.45,-0.45),SIMD2(0.49,0.20),SIMD2(0.34,0.40),SIMD2(0,0.56),SIMD2(-0.34,0.40),SIMD2(-0.49,0.20)]
        for i in plan.indices {
            let a=plan[i],b=plan[(i+1)%plan.count]
            let aa=c+V(a.x*width,0.95,a.y*length),bb=c+V(b.x*width,0.95,b.y*length)
            npQuad(c+V(a.x*width*0.7,-0.8,a.y*length*0.94),c+V(b.x*width*0.7,-0.8,b.y*length*0.94),bb,aa,p.white)
            npTri(c+V(0,0.96,0),aa,bb,p.wood)
            npBeam(aa,bb,0.045,0.05,p.steel)
        }
        npBox(c+V(0,1.48,-length*0.10),V(width*0.72,1.07,length*0.36),p.white)
        npBox(c+V(0,1.58,-length*0.10),V(width*0.73,0.59,length*0.37),p.glass)
        npBox(c+V(0,2.08,-length*0.10),V(width*0.78,0.11,length*0.40),p.white)
        if sailing {
            let top=c+V(0,length*1.12,0)
            npCylinder(c+V(0,1.1,0),top,0.055,p.white,segments:8)
            npBeam(c+V(0,2.4,0),c+V(0,2.4,-length*0.34),0.06,0.08,p.white)
            npCylinder(c+V(0,2.54,0),c+V(0,2.54,-length*0.34),0.12,p.sail,segments:8)
            for x:Float in [-width*0.42,width*0.42] {npBeam(c+V(x,1.0,-length*0.2),top,0.013,0.013,p.steel)}
            npBeam(c+V(0,1.0,length*0.45),top,0.013,0.013,p.steel)
        }
        if angle != 0 {
            let origin=NavyPierLayout.point(c),co=cos(angle),si=sin(angle)
            for i in firstVertex..<scene.vertices.count {
                var vertex=scene.vertices[i]
                let d=V(vertex.position.x,vertex.position.y,vertex.position.z)-origin
                let n=V(vertex.normal.x,vertex.normal.y,vertex.normal.z)
                vertex.position=SIMD4(origin+V(co*d.x-si*d.z,d.y,si*d.x+co*d.z),1)
                vertex.normal=SIMD4(V(co*n.x-si*n.z,n.y,si*n.x+co*n.z),0)
                scene.vertices[i]=vertex
            }
        }
    }
    private func npTree(_ c:V,height:Float) {
        npCylinder(c,c+V(0,height*0.70,0),0.13,bark,segments:10)
        for k in 0..<3 {
            let theta=Float(k)*2.39996,offset=V(cos(theta)*0.52,height*(0.68+Float(k)*0.055),sin(theta)*0.52)
            npCylinder(c+V(0,height*0.40,0),c+offset,0.048,bark,segments:7)
            let center=NavyPierLayout.point(c+offset),radius=V(height*0.25,height*0.31,height*0.24),mat=k==0 ? leafLight:leaf
            let segments=18,rings=12
            for j in 0..<rings {
                let v0 = -Float.pi/2+Float(j)*Float.pi/Float(rings),v1 = -Float.pi/2+Float(j+1)*Float.pi/Float(rings)
                for i in 0..<segments {
                    let a0=Float(i)*Float.pi*2/Float(segments),a1=Float(i+1)*Float.pi*2/Float(segments)
                    let q0=V(cos(v0)*cos(a0),sin(v0),cos(v0)*sin(a0)),q1=V(cos(v0)*cos(a1),sin(v0),cos(v0)*sin(a1))
                    let q2=V(cos(v1)*cos(a1),sin(v1),cos(v1)*sin(a1)),q3=V(cos(v1)*cos(a0),sin(v1),cos(v1)*sin(a0))
                    let n0=simd_normalize(q0/radius),n1=simd_normalize(q1/radius),n2=simd_normalize(q2/radius),n3=simd_normalize(q3/radius)
                    if j>0 {smoothTri(center+q0*radius,center+q3*radius,center+q1*radius,n0,n3,n1,mat)}
                    if j<rings-1 {smoothTri(center+q1*radius,center+q3*radius,center+q2*radius,n1,n3,n2,mat)}
                }
            }
        }
    }
    private func npLabel(_ text:String,_ center:V,_ tangent:V,_ normal:V,_ height:Float,_ material:UInt32) {
        let glyphs:[Character:[String]]=[
            "A":["01110","10001","10001","11111","10001","10001","10001"],"B":["11110","10001","10001","11110","10001","10001","11110"],
            "C":["01111","10000","10000","10000","10000","10000","01111"],"D":["11110","10001","10001","10001","10001","10001","11110"],
            "E":["11111","10000","10000","11110","10000","10000","11111"],"F":["11111","10000","10000","11110","10000","10000","10000"],
            "G":["01111","10000","10000","10111","10001","10001","01110"],"H":["10001","10001","10001","11111","10001","10001","10001"],
            "I":["11111","00100","00100","00100","00100","00100","11111"],"K":["10001","10010","10100","11000","10100","10010","10001"],
            "L":["10000","10000","10000","10000","10000","10000","11111"],"M":["10001","11011","10101","10101","10001","10001","10001"],
            "N":["10001","11001","11001","10101","10011","10011","10001"],"O":["01110","10001","10001","10001","10001","10001","01110"],
            "P":["11110","10001","10001","11110","10000","10000","10000"],"R":["11110","10001","10001","11110","10100","10010","10001"],
            "S":["01111","10000","10000","01110","00001","00001","11110"],"T":["11111","00100","00100","00100","00100","00100","00100"],
            "U":["10001","10001","10001","10001","10001","10001","01110"],"V":["10001","10001","10001","10001","10001","01010","00100"],
            "W":["10001","10001","10001","10101","10101","11011","10001"],"Y":["10001","10001","01010","00100","00100","00100","00100"]]
        let pitch=height/7,width=Float(text.count)*pitch*6
        let t=NavyPierLayout.east*tangent.x+V(0,tangent.y,0)+NavyPierLayout.south*tangent.z
        let n=NavyPierLayout.east*normal.x+V(0,normal.y,0)+NavyPierLayout.south*normal.z
        for (letter,ch) in text.enumerated() {
            guard let rows=glyphs[ch] else{continue}
            for (row,bits) in rows.enumerated() {for (col,bit) in bits.enumerated() where bit=="1" {
                let x = -width/2+(Float(letter)*6+Float(col)+0.5)*pitch,y=height/2-(Float(row)+0.5)*pitch
                orientedBox(NavyPierLayout.point(center)+t*x+V(0,y,0),t,V(0,1,0),n,V(pitch*0.92,pitch*0.92,max(0.014,pitch*0.18)),material)
            }}
        }
    }
}
