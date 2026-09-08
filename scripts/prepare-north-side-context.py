#!/usr/bin/env python3
"""Offline, reproducible North Side derivative; requires Shapely 2.1.2.
Preserves prior Chicago/Lakefront source files. No imagery is bundled.
"""
import json,math,re,hashlib
from pathlib import Path
from collections import defaultdict
from shapely import Polygon,LineString,Point,box,make_valid,union_all,constrained_delaunay_triangles
from shapely.ops import linemerge
ROOT=Path(__file__).resolve().parents[1]
LAT,LON=41.878876,-87.635918
RAW=ROOT/'scripts/data/chicago-north-side-osm-2026-09-08.json'
source=json.loads(RAW.read_text())
old=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json').read_text())
lf=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json').read_text())
WORLD=box(-4000,-11500,6000,7800)
DEST=ROOT/'Sources/ArchitectureEngine/Resources/NorthSide/NorthSideContext.json'
def project(q):return [round((q['lon']-LON)*111320*math.cos(math.radians(LAT)),3),round((LAT-q['lat'])*111320,3)]
def number(v,default=0):
    try:
        s=str(v);n=float(re.match(r'[-\d.]+',s).group());return n*.3048 if 'ft'in s or "'"in s else n
    except (ValueError,AttributeError):return default
def polygons(g):
    if g.is_empty:return []
    if g.geom_type=='Polygon':return [g]
    return [p for sub in getattr(g,'geoms',[])for p in polygons(sub)]
def clean(g):return make_valid(g).intersection(WORLD)
def way_shape(e):
    g=e.get('geometry',[])
    if len(g)<4 or g[0]!=g[-1] or any(q is None for q in g):return Polygon()
    return clean(Polygon([project(q)for q in g]))
def relation_rings(e,role):
    lines=[]
    for m in e.get('members',[]):
        if m.get('role')!=role:continue
        chunk=[]
        for q in m.get('geometry',[])+[None]:
            if q is None:
                if len(chunk)>1:lines.append(LineString(chunk))
                chunk=[]
            else:chunk.append(project(q))
    if not lines:return []
    merged=linemerge(lines)
    return [list(g.coords)for g in ([merged]if merged.geom_type=='LineString'else merged.geoms)]
def relation_shape(e):
    outer=[Polygon(g)for g in relation_rings(e,'outer')if len(g)>3 and g[0]==g[-1]]
    inner=[Polygon(g)for g in relation_rings(e,'inner')if len(g)>3 and g[0]==g[-1]]
    return clean(union_all([make_valid(p)for p in outer]).difference(union_all([make_valid(p)for p in inner])))
def mesh(shape,ident,kind,name=''):
    points=[];lookup={};triangles=[];rings=[]
    for p in polygons(shape):
        rings.append([[round(x,3),round(z,3)]for x,z in p.exterior.coords[:-1]])
        rings += [[[round(x,3),round(z,3)]for x,z in ring.coords[:-1]]for ring in p.interiors]
        for triangle in constrained_delaunay_triangles(p).geoms:
            coords=[(round(x,3),round(z,3))for x,z in list(triangle.exterior.coords)[:-1]]
            signed=sum(coords[i][0]*coords[(i+1)%3][1]-coords[(i+1)%3][0]*coords[i][1]for i in range(3))
            if abs(signed)<1e-8:continue
            if signed<0:coords.reverse()
            for q in coords:
                key=(round(q[0],3),round(q[1],3))
                if key not in lookup:lookup[key]=len(points);points.append(list(key))
                triangles.append(lookup[key])
    return dict(id=ident,points=points,triangles=triangles,rings=rings,kind=kind,name=name)

def surface_shape(s):
    g=Polygon()
    for ring in s['rings']:g=g.symmetric_difference(Polygon(ring))
    return make_valid(g)
def lines(g):
    if g.is_empty:return []
    if g.geom_type=='LineString':return [g]
    return [v for c in getattr(g,'geoms',[])for v in lines(c)]
elements={(e['type'],e['id']):e for e in source['elements']}
shape_cache={}
def shape(e):
    key=(e['type'],e['id'])
    if key not in shape_cache:shape_cache[key]=relation_shape(e)if e['type']=='relation'else way_shape(e)
    return shape_cache[key]
# Landmarks remain source records, including non-building parent areas and holes.
def landmark_record(e):
    g=shape(e)
    if g.is_empty:return None
    ident=-e['id'] if e['type']=='relation' else e['id']
    m=mesh(g,ident,'landmark',e.get('tags',{}).get('name',''))
    m.update(tags=e.get('tags',{}),center=[round(g.centroid.x,3),round(g.centroid.y,3)],bounds=[round(v,3)for v in g.bounds])
    return m

def export_landmarks():
    selected=[]
    for e in source['elements']:
        if e['type'] not in ('way','relation'):continue
        t=e.get('tags',{})
        if not any(k in t for k in ('building','building:part','leisure','water','natural')):continue
        g=shape(e)
        if g.is_empty:continue
        # The full context keeps every building; this early architectural table
        # focuses on the selected northern landmark neighborhoods.
        x,z=g.centroid.x,g.centroid.y
        target=(x>-500 and x<1400 and z>-5900 and z<-3400) or (x>-2000 and x<-1350 and z>-8150 and z<-7350)
        if target:
            m=landmark_record(e)
            if m:selected.append(m)
    out=ROOT/'scripts/data/chicago-north-side-landmarks-2026-09-08.json'
    out.write_text(json.dumps(dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=source['osm3s']['timestamp_osm_base'],origin=[LAT,LON],landmarks=selected),separators=(',',':'))+'\n')
    print('Landmark table',out,len(selected))
    return selected

def northern_park_remainder(previous,areas,paths,roads,piers,walls,trees,water,beaches,authored):
    """Restore coverage, not IDs: the older Lincoln Park record ends at z=-6200.

    Keep every earlier surface unchanged. New lawn is the actual multipolygon's
    northern remainder, with mapped circulation and non-lawn surfaces cut out.
    Additional tree positions are authored samples of mapped woodland/scrub,
    deliberately separate from the unchanged natural=tree node collection.
    """
    from shapely.prepared import prep
    parent_id=-11610689
    boundary=box(-4000,-11500,6000,-6200)
    parent=shape(elements[('relation',abs(parent_id))])
    retained=union_all([surface_shape(a)if 'rings'in a else Polygon(a['points'])
        for d in previous for a in d['areas']if a['id']==parent_id])
    missing=parent.difference(retained).intersection(boundary)
    hard=[];hard_ids=[];wood=[];sports=[]
    hard_surfaces={'asphalt','concrete','paving_stones','sett','metal','wood','rubber','artificial_turf','clay','sand','fine_gravel','gravel','dirt','compacted'}
    for e in source['elements']:
        if e['type']not in('way','relation'):continue
        t=e.get('tags',{});g=shape(e)
        if g.is_empty or not missing.intersects(g):continue
        ident=-e['id']if e['type']=='relation'else e['id']
        athletics=t.get('leisure')in('pitch','track','golf_course','miniature_golf','sports_centre')
        if athletics:sports.append(g)
        if (t.get('surface')in hard_surfaces or t.get('amenity')=='parking'
            or t.get('natural')in('bare_rock','shingle') or t.get('leisure')in('pitch','track','miniature_golf')
            or (t.get('leisure')=='dog_park'and'Beach'in t.get('name',''))
            or (t.get('area')=='yes'and'highway'in t)
            or any(k in t for k in('building','building:part'))):
            hard.append(g);hard_ids.append(ident)
        if t.get('natural')in('wood','scrub')or t.get('landuse')=='forest':
            wood.append((ident,t.get('natural','forest'),g))
    # Match existing paved geometry plus the sidewalks used by the road builder.
    # These masks only cut the new lawn; they never modify a rendered road/path.
    circulation=[]
    allpaths=paths+[p for d in previous for p in d['paths']+d.get('bridges',[])]+piers+walls
    for p in allpaths:
        line=LineString(p['points'])
        if not missing.intersects(line.envelope.buffer(p['width']/2+3)):continue
        pedestrian=p['kind']in('footway','path','pedestrian','cycleway','steps','pier','quay','breakwater')
        circulation.append(line.buffer(p['width']/2+(0.35 if pedestrian else 2.85),cap_style=2,join_style=2))
    for road in roads+[r for d in previous for r in d.get('roads',[])]:
        line=LineString([(p[0],p[2])for p in road['points']])
        if missing.intersects(line.envelope.buffer(road['width']/2+3)):
            circulation.append(line.buffer(road['width']/2+2.85,cap_style=2,join_style=2))
    exclusions=union_all(hard+circulation+[water,beaches,authored])
    restored=missing.difference(exclusions)
    surface=mesh(restored,parent_id,'park','Lincoln (Abraham) Park — northern mapped remainder')
    # Fixed 12 m jittered lattice gives sparse, reproducible canopy belts. No
    # canopy is placed in open park lawn, athletic grounds or on tagged trees.
    sport_mask=union_all(sports)
    tagged=union_all([Point(t['point']).buffer(5)for t in trees if boundary.covers(Point(t['point']))])
    planting=[];placements=[];used=set()
    for ident,kind,g in sorted(wood):
        eligible=g.intersection(restored).difference(sport_mask).difference(tagged).buffer(-3.9)
        if eligible.area<25:continue
        planting.append(dict(sourceAreaID=ident,sourceKind=kind,surface=mesh(eligible,ident,kind)))
        inside=prep(eligible);xmin,zmin,xmax,zmax=eligible.bounds
        for ix in range(math.floor(xmin/12),math.ceil(xmax/12)+1):
            for iz in range(math.floor(zmin/12),math.ceil(zmax/12)+1):
                seed=((ix+10000)*73856093^(iz+10000)*19349663)&0xffffffff
                if (ix,iz)in used or seed%100 >= (52 if kind=='scrub'else 88):continue
                point=[round(ix*12+((seed>>8)%1000/999-.5)*3.6,3),round(iz*12+((seed>>18)%1000/999-.5)*3.6,3)]
                if not inside.covers(Point(point)):continue
                used.add((ix,iz))
                height=round((4.6+(seed%29)*.075)if kind=='scrub'else(8.5+(seed%31)*.125),3)
                placements.append(dict(id=-(9_000_000_000_000+(ix+10000)*100000+(iz+10000)),point=point,height=height,sourceAreaID=ident,sourceKind=kind))
    assert len(placements)<2200,'Sparse mapped canopy budget exceeded'
    metadata=dict(sourceParentID=parent_id,northernBoundaryZ=-6200,missingMappedAreaSquareMetres=round(missing.area,3),restoredLawnAreaSquareMetres=round(restored.area,3),
        excludedHardSurfaceIDs=sorted(set(hard_ids)),plantingAreas=planting,
        treePlacementSource='authored deterministic sparse samples inside mapped wood/forest/scrub polygons; not OSM tree nodes',
        treeSpacingMetres=12,minimumCrownBoundaryInsetMetres=3.9,taggedTreeCount=len(trees),authoredTreeCount=len(placements))
    return surface,placements,metadata

def prepare():
    from shapely.strtree import STRtree
    campus_path=ROOT/'Sources/ArchitectureEngine/Resources/MuseumCampus/MuseumCampusContext.json'
    campus=json.loads(campus_path.read_text())
    source_paths=[RAW,ROOT/'scripts/data/chicago-north-side-shoreline-2026-09-08.json',ROOT/'scripts/data/chicago-north-side-roads-2026-09-08.json']
    road_source=json.loads(source_paths[2].read_text())
    for e in road_source['elements']:elements[(e['type'],e['id'])]=e
    landmarks=export_landmarks()
    # The renderer replaces only the previously unvisited northern cap and a
    # western strip. Every existing surface south of this boundary is retained.
    repair=box(-2400,-6200,6000,-3500)
    extension=box(-4000,-11500,6000,-6200).union(box(-4000,-6200,-2400,-1500))
    active=repair.union(extension)
    shore=json.loads(source_paths[1].read_text())
    lake=next(e for e in shore['elements']if e['id']==1205149)
    coast=max(relation_rings(lake,'outer'),key=lambda q:LineString(q).length)
    if coast[0][1]>coast[-1][1]:coast.reverse()
    ocean=clean(Polygon(coast+[(6000,coast[-1][1]),(6000,coast[0][1])]))
    # Inland ponds are near their paths, not five metres below them like the
    # application's established lake datum. Relative levels are interpretations.
    water_records=[];water_shapes=[]
    for e in source['elements']:
        t=e.get('tags',{})
        if t.get('natural')!='water' and 'water'not in t:continue
        if e['type']not in('way','relation'):continue
        g=shape(e).intersection(active)
        if g.area<1:continue
        ident=-e['id']if e['type']=='relation'else e['id']
        kind=t.get('water','pond');y=-5.7 if kind in('harbour','river','canal','lake')else -0.5
        if ident==-2514193:y=-0.55
        if ident==116740882:y=-0.25
        if ident==1040139816:y=-5.7 # Turning basin connected to Chicago River.
        water_records.append(dict(surface=mesh(g,ident,kind,t.get('name','')),elevation=y,elevationSource='authored relative to street grade; not surveyed elevation'))
        water_shapes.append(g)
    mapped_water=union_all([ocean.intersection(active)]+water_shapes)
    land=active.difference(mapped_water)
    legacy_ground=mesh(surface_shape(campus['legacyGround']).difference(repair).union(repair.difference(mapped_water)),0,'ground')
    legacy_water=mesh(surface_shape(campus['legacyWater']).difference(repair),0,'water')
    ground=mesh(land.intersection(extension),0,'ground')
    # Lake and river surfaces remain one continuous datum; separate shallow
    # ponds are rendered once using the explicit elevations above.
    shallow=union_all([g for g,w in zip(water_shapes,water_records)if w['elevation']>-5])
    water=mesh(mapped_water.difference(shallow),0,'water')
    water_records=[w for w in water_records if w['elevation']>-5]
    authored_ids=[210315405,417380833,24826112,186667195,23986733,210686223,992815961,210686220,24826074,210685702,210686226,210686225,210686219,-17379974,1265774541,445947684,-17380054]
    authored_geometry=[]
    for ident in authored_ids:
        e=elements.get(('relation'if ident<0 else'way',abs(ident)))
        if e:authored_geometry +=[Polygon(p.exterior)for p in polygons(shape(e))]
    authored=union_all(authored_geometry).buffer(.12)
    replacement=[]
    for e in source['elements']:
        if e['type']not in('way','relation')or not any(k in e.get('tags',{})for k in('building','building:part')):continue
        g=shape(e)
        if not g.is_empty and authored.covers(g.representative_point()):replacement.append(-e['id']if e['type']=='relation'else e['id'])
    replacement=sorted(set(replacement+authored_ids))
    # Extend the existing carriageways north. Compact lane IDs and every old
    # lane sample are retained exactly, including the southern campus extension.
    oldraw=json.loads((ROOT/'scripts/data/chicago-lakefront-osm-2026-09-08.json').read_text())
    main={e['id']:e for e in oldraw['elements']+source['elements']+road_source['elements']if e['type']=='way'and'Lake Shore Drive'in e.get('tags',{}).get('name','')and e['tags'].get('highway')in('motorway','trunk')}
    starts=defaultdict(list);ends=defaultdict(list)
    for e in main.values():starts[e['nodes'][0]].append(e);ends[e['nodes'][-1]].append(e)
    roads=[];traffic=[];all_road_ids={i for r in lf['roads']+campus['roads']for i in r['sourceIDs']}
    for oldroad in lf['roads']:
        north_start=oldroad['points'][0][2]<oldroad['points'][-1][2]
        chain=[main[i]for i in oldroad['sourceIDs']];edge=chain[0]if north_start else chain[-1];seen=set(oldroad['sourceIDs']);extra=[]
        while True:
            choices=ends[edge['nodes'][0]]if north_start else starts[edge['nodes'][-1]]
            choices=[e for e in choices if e['id']not in seen]
            if not choices:break
            assert len(choices)==1,'Ambiguous north carriageway continuation'
            edge=choices[0];seen.add(edge['id']);extra.append(edge)
        if north_start:extra.reverse()
        coords=[]
        for e in extra:
            q=[project(v)for v in e['geometry']]
            if coords:assert coords[-1]==q[0]
            coords+=q if not coords else q[1:]
        assert coords,'Mapped northern extension missing'
        join=oldroad['points'][0]if north_start else oldroad['points'][-1]
        assert coords[-1 if north_start else 0]==[join[0],join[2]]
        line=LineString(coords);steps=math.ceil(line.length/5)
        pts=[[round((q:=line.interpolate(line.length*i/steps)).x,3),.12,round(q.y,3)]for i in range(steps+1)]
        assert min(p[2]for p in pts)<-10000,'Northern endpoints must lie outside curated views'
        roads.append(dict(id=oldroad['id'],points=pts,width=oldroad['width'],sourceIDs=[e['id']for e in extra],length=round(line.length,3)))
        all_road_ids.update(e['id']for e in extra)
        for lane in[v for v in campus['trafficLanes']if v['id']//10==oldroad['id']]:
            offset=(lane['id']%10-1)*3.55;shifted=[]
            for i,p in enumerate(pts):
                a=pts[max(0,i-1)];b=pts[min(len(pts)-1,i+1)];dx=b[0]-a[0];dz=b[2]-a[2];d=math.hypot(dx,dz)
                shifted.append([round(p[0]-dz/d*offset,3),p[1],round(p[2]+dx/d*offset,3)])
            shifted[-1 if north_start else 0]=lane['points'][0 if north_start else -1]
            points=shifted[:-1]+lane['points']if north_start else lane['points']+shifted[1:]
            traffic.append(dict(lane,points=points))
    previous=[old,lf,campus]
    old_buildings={b['id']for d in previous for b in d['buildings']}
    old_paths={p['id']for d in previous for p in d['paths']+d.get('bridges',[])}
    old_areas={a['id']for d in previous for a in d['areas']}
    old_piers={p['id']for d in[lf,campus]for p in d['piers']}
    old_walls={p['id']for d in[lf,campus]for p in d['breakwaters']}
    old_trees={p['id']for d in[lf,campus]for p in d['trees']}
    buildings=[];areas=[];paths=[];piers=[];walls=[];trees=[];beaches=[]
    replaced_area_ids=[-12788474]
    named_harbors=[]
    for e in source['elements']:
        t=e.get('tags',{});ident=-e['id']if e['type']=='relation'else e['id']
        if e['type']=='node':
            if t.get('natural')=='tree'and ident not in old_trees:
                q=project(e)
                if not authored.covers(Point(q))and not mapped_water.covers(Point(q)):
                    trees.append(dict(id=ident,point=q,height=round(min(16,max(4,number(t.get('height'),7+(ident%23)*.17))),2)))
            continue
        if e['type']not in('way','relation'):continue
        if t.get('water')=='harbour'and shape(e).centroid.y<-3500:named_harbors.append(mesh(shape(e),ident,'harbour',t.get('name','')))
        if any(k in t for k in('building','building:part'))and ident not in old_buildings and ident not in replacement:
            if t.get('location')!='underground'and number(t.get('layer'))>=0 and t.get('building')not in('no','roof','construction')and t.get('building:part')not in('roof','column','ramp','elevator'):
                for j,g in enumerate(polygons(shape(e))):
                    if g.area<18 or authored.covers(g.representative_point()):continue
                    outer=list(g.exterior.coords)[:-1]
                    if sum(outer[i][0]*outer[(i+1)%len(outer)][1]-outer[(i+1)%len(outer)][0]*outer[i][1]for i in range(len(outer)))<0:outer.reverse()
                    lookup={q:i for i,q in enumerate(outer)};idx=[]
                    for tr in constrained_delaunay_triangles(Polygon(outer)).geoms:
                        q=list(tr.exterior.coords)[:-1]
                        if sum(q[i][0]*q[(i+1)%3][1]-q[(i+1)%3][0]*q[i][1]for i in range(3))<0:q.reverse()
                        idx +=[lookup[v]for v in q]
                    h=number(t.get('height'));hs='height'if h else'levels'if t.get('building:levels')else'estimated'
                    if not h:h=number(t.get('building:levels'))*3.35
                    if h<1:h=4.5 if g.area<95 or t.get('building')in('garage','garages','shed','kiosk')else 6.2 if t.get('building')in('retail','service','public')else 10.2 if g.area<350 else 13.8
                    kind=t.get('building:part',t.get('building','yes'))
                    if t.get('amenity')in('restaurant','bar','pub','cafe','fast_food')and kind=='yes':kind='retail'
                    buildings.append(dict(id=ident if j==0 else-ident*10-j,points=[list(q)for q in outer],triangles=idx,height=round(min(h,450),2),heightSource=hs,name=t.get('name',''),kind=kind,material=t.get('building:material',''),color=t.get('building:colour',''),isPart='building:part'in t,hasHoles=bool(g.interiors)))
        kind='park'if t.get('leisure')=='park'else'garden'if t.get('leisure')=='garden'else'sand'if t.get('natural')in('sand','beach')else'pitch'if t.get('leisure')=='pitch'else'grass'if t.get('landuse')in('grass','forest','meadow','recreation_ground')or t.get('natural')in('wood','scrub','grassland')or t.get('landcover')=='grass'else None
        if kind and (ident not in old_areas or ident in replaced_area_ids):
            g=shape(e).difference(mapped_water).difference(authored)
            if kind=='sand':g=g.intersection(active)
            if g.area>3:
                surface=mesh(g,ident,kind,t.get('name',''))
                if kind=='sand':
                    elevations=[round(-5.62+5.62*min(1,Point(q).distance(ocean)/70),3)for q in surface['points']]
                    beaches.append(dict(surface=surface,elevations=elevations))
                else:areas.append(surface)
        if e['type']!='way':continue
        raw=e.get('geometry',[])
        if len(raw)<2 or any(q is None for q in raw):continue
        pts=[project(q)for q in raw];line=LineString(pts)
        if t.get('man_made')in('pier','quay','breakwater'):
            k=t['man_made'];dest=piers if k=='pier'else walls
            if ident not in(old_piers if k=='pier'else old_walls):dest.append(dict(id=ident,points=pts,width=number(t.get('width'),2.3 if k=='pier'else 3.5),kind=k,name=t.get('name',''),bridge=''))
        if 'highway'in t and ident not in old_paths and ident not in all_road_ids:
            if ident==758462743 or (t.get('bridge')=='boardwalk' and 130<line.centroid.x<430 and -4540<line.centroid.y<-4130):continue
            k=t['highway'];ped=k in('footway','path','pedestrian','cycleway','steps')
            if t.get('indoor')=='yes'or number(t.get('layer'))<0 or t.get('tunnel')or k in('elevator','corridor','bus_stop','construction')or t.get('area')=='yes':continue
            width=round(min(28,number(t.get('width'),2.5 if ped else max(2,number(t.get('lanes'),2))*3.35+1)),2)
            for j,l in enumerate(lines(line.difference(authored))):
                if l.length>.2:paths.append(dict(id=ident if j==0 else-ident*100-j,points=[[round(x,3),round(z,3)]for x,z in l.coords],width=width,kind=k,name=t.get('name',''),bridge=t.get('bridge','')))
    # Sloping sand must replace the underlying street-grade terrain, otherwise
    # the old opaque slab would cover every beach vertex below grade.
    beach_mask=union_all([surface_shape(b['surface'])for b in beaches])
    ground=mesh(surface_shape(ground).difference(beach_mask),0,'ground')
    legacy_ground=mesh(surface_shape(legacy_ground).difference(beach_mask),0,'ground')
    areas=[dict(a,**{k:v for k,v in mesh(surface_shape(a).difference(beach_mask),a['id'],a['kind'],a['name']).items()})for a in areas]
    legacy_areas=[mesh(surface_shape(a).difference(mapped_water).difference(beach_mask).difference(authored),a['id'],a['kind'],a['name'])for a in lf['areas']if a['id']not in replaced_area_ids]
    # Remove mapped trees from actual paved ribbons and building roofs.
    obstacle=[Polygon(b['points']) for b in buildings]+[LineString(p['points']).buffer(p['width']/2+.3)for p in paths]
    tree_index=STRtree(obstacle)
    trees=[t for t in trees if not any(obstacle[int(i)].covers(Point(t['point']))for i in tree_index.query(Point(t['point'])))]
    lily_furniture=box(126,-5144,141,-5124).union(Point(192,-5134).buffer(4.8))
    trees=[t for t in trees if not lily_furniture.covers(Point(t['point']))]
    restored_park,landcover_trees,landcover_metadata=northern_park_remainder(previous,areas,paths,roads,piers,walls,trees,mapped_water,beach_mask,authored)
    areas.append(restored_park)
    harbor=union_all([surface_shape(s)for s in named_harbors if s['id']in(-17766292,-17766386)])
    harbor_piers=[p for p in piers if harbor.buffer(10).intersects(LineString(p['points']))]
    dockmask=union_all([LineString(p['points']).buffer(p['width']/2+.45)for p in harbor_piers]);boats=[];occupied=[]
    for p in sorted(harbor_piers,key=lambda p:p['id']):
        for i in range(1,len(p['points'])):
            line=LineString(p['points'][i-1:i+1]);length=line.length
            if length<8 or length>33:continue
            a,b=line.coords[0],line.coords[-1];dx=(b[0]-a[0])/length;dz=(b[1]-a[1])/length;n=(-dz,dx)
            for side in[-1,1]:
                ident=p['id']*1000+i*2+(side==1)
                if ident%3==0:continue
                size=min(15,max(8.5,length*.82));width=size*.285;c=line.interpolate(length*.52)
                x=c.x+n[0]*side*(p['width']/2+width*.5+1.05);z=c.y+n[1]*side*(p['width']/2+width*.5+1.05)
                hull=Polygon([(x+dx*size*.53*u+n[0]*width*.56*v,z+dz*size*.53*u+n[1]*width*.56*v)for u,v in[(-1,-1),(1,-1),(1,1),(-1,1)]])
                if not harbor.buffer(-.7).covers(hull)or dockmask.intersects(hull)or any(g.intersects(hull)for g in occupied):continue
                diversey=any(s['id']==-17766292 and surface_shape(s).covers(Point(x,z))for s in named_harbors)
                occupied.append(hull);boats.append(dict(id=ident,point=[round(x,3),round(z,3)],length=round(size,2),angle=round(math.atan2(dx,dz),6),sailboat=(not diversey and ident%4!=0),detailed=(z>-7200 and x<500)))
    previous_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in[ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json',ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json',campus_path]}
    result=dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=source['osm3s']['timestamp_osm_base'],origin=[LAT,LON],mapBounds=[41.880,-87.670,41.962,-87.607],worldBounds=[-4000,-11500,6000,7800],ground=ground,water=water,legacyGround=legacy_ground,legacyWater=legacy_water,inlandWaters=water_records,beaches=beaches,replacedAreaIDs=replaced_area_ids,namedHarbors=named_harbors,landmarks=sorted(landmarks,key=lambda x:x['id']),replacementBuildingIDs=replacement,authoredMask=mesh(authored,0,'exclusion'),buildings=sorted(buildings,key=lambda x:x['id']),areas=areas,paths=paths,piers=piers,breakwaters=walls,trees=trees,roads=roads,trafficLanes=traffic,boats=boats,sourceSHA256={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in source_paths},previousResourceSHA256=previous_hashes)
    result['legacyAreas']=legacy_areas
    result['landcoverTrees']=landcover_trees
    result['landcoverRestoration']=landcover_metadata
    DEST.parent.mkdir(parents=True,exist_ok=True);DEST.write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
    print(json.dumps({k:len(result[k])for k in('buildings','areas','paths','trees','piers','breakwaters','landmarks','replacementBuildingIDs','boats','roads','trafficLanes')},indent=2));print('Resource bytes',DEST.stat().st_size)

if __name__=='__main__':
    import sys
    if '--landmarks-only'in sys.argv:export_landmarks()
    else:prepare()
