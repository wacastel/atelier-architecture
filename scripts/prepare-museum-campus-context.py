#!/usr/bin/env python3
"""Offline, reproducible Museum Campus derivative; requires Shapely 2.1.2.
Preserves prior Chicago/Lakefront source files. No imagery is bundled.
"""
import json,math,re,hashlib
from pathlib import Path
from collections import defaultdict
from shapely import Polygon,LineString,Point,box,make_valid,union_all,constrained_delaunay_triangles
from shapely.ops import linemerge
ROOT=Path(__file__).resolve().parents[1]
LAT,LON=41.878876,-87.635918
RAW=ROOT/'scripts/data/chicago-museum-campus-osm-2026-09-08.json'
source=json.loads(RAW.read_text())
old=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json').read_text())
lf=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json').read_text())
WORLD=box(-2400,-6200,6000,7800)
DEST=ROOT/'Sources/ArchitectureEngine/Resources/MuseumCampus/MuseumCampusContext.json'
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
# Exclude complete authored campus footprints, including unnamed part children.
authored=[('way',24825537),('relation',17430414),('way',766396221),('way',24825591),('way',91526195),('relation',16699535),('way',24587933),('way',136340574),('way',769452749),('way',204886155),('relation',17647196),('way',769724044),('way',769427391),('way',769452753),('way',769452748),('way',769452758),('way',313782023),('way',381265570),('way',561284192),('way',156520409)]
# Generic replacement includes interior courtyards/bowls: their holes are open
# space inside authored architecture, never places for a second generic shell.
authored_shape=union_all([Polygon(g.exterior)for k in authored if k in elements for g in polygons(shape(elements[k]))]).buffer(.15)
approaches=union_all([box(1543,1321,1585,1343),box(1545,1476,1587,1498),box(1745,1241,1767,1269),LineString([(1738.2742,1371.0419),(1777.7,1340.25),(1785.01,1307.10),(1800,1305.8)]).buffer(3.2)])
landmarks=[];replacement_ids=[]
for e in source['elements']:
    t=e.get('tags',{})
    if not any(k in t for k in ('building','building:part'))and (e['type'],e['id'])not in [('way',24587933),('relation',17767650)]:continue
    if e['type']not in ('way','relation'):continue
    g=shape(e)
    if g.is_empty:continue
    ident=-e['id']if e['type']=='relation'else e['id']
    m=mesh(g,ident,'landmark',t.get('name',''));m.update(tags=t,center=[round(g.centroid.x,3),round(g.centroid.y,3)],bounds=[round(v,3)for v in g.bounds]);landmarks.append(m)
    if authored_shape.covers(g.representative_point()):replacement_ids.append(ident)
# Existing northern land/water is retained; only a non-overlapping southern strip is added.
shore=json.loads((ROOT/'scripts/data/chicago-museum-campus-shoreline-2026-09-08.json').read_text())
lake=next(e for e in shore['elements']if e['id']==1205149)
coast=max(relation_rings(lake,'outer'),key=lambda q:LineString(q).length)
if coast[0][1]>coast[-1][1]:coast.reverse()
water_shape=clean(Polygon(coast+[(6000,coast[-1][1]),(6000,coast[0][1])]))
waters=[surface_shape(lf['water']),water_shape];named=[]
for e in source['elements']:
    if e.get('tags',{}).get('water')not in('harbour','river','lagoon'):continue
    g=shape(e)
    if not g.is_empty:waters.append(g);named.append(mesh(g,e['id'],'water',e.get('tags',{}).get('name','')))
water_shape=union_all(waters);land=WORLD.difference(water_shape);extension=box(-2400,4200,6000,7800)
ground=mesh(land.intersection(extension),0,'ground');water=mesh(water_shape.intersection(extension),0,'water')
# The old extract's coastline stopped at z3783 and closed the remaining south
# cap as land. Replace only that newly visible southern band with current coast.
repair=box(-2400,3500,6000,4200)
legacy_ground=mesh(surface_shape(lf['ground']).difference(repair).union(repair.difference(water_shape)),0,'ground')
legacy_water=mesh(surface_shape(lf['water']).difference(repair).union(repair.intersection(water_shape)),0,'water')
# Extend the exact directed main-road chains. Existing sampled road/lane points are preserved.
extra_source=json.loads((ROOT/'scripts/data/chicago-museum-campus-roads-2026-09-08.json').read_text())
oldraw=json.loads((ROOT/'scripts/data/chicago-lakefront-osm-2026-09-08.json').read_text())
main={e['id']:e for e in oldraw['elements']+source['elements']+extra_source['elements']if e['type']=='way'and 'Lake Shore Drive'in e.get('tags',{}).get('name','')and e['tags'].get('highway')in('motorway','trunk')}
starts=defaultdict(list);ends=defaultdict(list)
for e in main.values():starts[e['nodes'][0]].append(e);ends[e['nodes'][-1]].append(e)
roads=[];traffic=[];allRoadIDs=set()
for road in lf['roads']:
    chain=[main[i]for i in road['sourceIDs']];allRoadIDs.update(road['sourceIDs'])
    south_at_start=road['points'][0][2]>road['points'][-1][2]
    extension_chain=[];edge=chain[0]if south_at_start else chain[-1];seen=set(road['sourceIDs'])
    while True:
        choices=(ends[edge['nodes'][0]]if south_at_start else starts[edge['nodes'][-1]])
        choices=[e for e in choices if e['id']not in seen]
        if not choices:break
        assert len(choices)==1,'Ambiguous southern carriageway continuation'
        edge=choices[0];seen.add(edge['id']);extension_chain.append(edge)
    if south_at_start:extension_chain.reverse()
    coords=[]
    for e in extension_chain:
        q=[project(v)for v in e['geometry']]
        if coords:assert coords[-1]==q[0]
        coords+=q if not coords else q[1:]
    assert coords,'Expected a mapped southward extension'
    join=road['points'][0]if south_at_start else road['points'][-1]
    assert coords[-1 if south_at_start else 0]==[join[0],join[2]],'Source chain does not meet old pavement'
    line=LineString(coords);steps=math.ceil(line.length/5)
    pts=[[round((q:=line.interpolate(line.length*i/steps)).x,3),.12,round(q.y,3)]for i in range(steps+1)]
    assert max(p[2]for p in pts)>6800,'Traffic endpoint not remote enough'
    roads.append(dict(id=road['id'],points=pts,width=road['width'],sourceIDs=[e['id']for e in extension_chain],length=round(line.length,3)))
    allRoadIDs.update(e['id']for e in extension_chain)
    for lane in [v for v in lf['trafficLanes']if v['id']//10==road['id']]:
        offset=(lane['id']%10-1)*3.55;shifted=[]
        for i,p in enumerate(pts):
            a=pts[max(0,i-1)];b=pts[min(len(pts)-1,i+1)];dx=b[0]-a[0];dz=b[2]-a[2];d=math.hypot(dx,dz)
            shifted.append([round(p[0]-dz/d*offset,3),p[1],round(p[2]+dx/d*offset,3)])
        # Exact original lane endpoint, avoiding a sub-mm tangent-rounding gap.
        shifted[-1 if south_at_start else 0]=lane['points'][0 if south_at_start else -1]
        points=shifted[:-1]+lane['points']if south_at_start else lane['points']+shifted[1:]
        traffic.append(dict(lane,points=points))
old_ids={b['id']for b in old['buildings']+lf['buildings']};old_paths={p['id']for p in old['paths']+old['bridges']+lf['paths']};old_areas={a['id']for a in old['areas']+lf['areas']}
old_piers={p['id']for p in lf['piers']};old_walls={p['id']for p in lf['breakwaters']};old_trees={p['id']for p in lf['trees']}
buildings=[];areas=[];paths=[];piers=[];breakwaters=[];trees=[]
for e in source['elements']:
    t=e.get('tags',{});ident=-e['id']if e['type']=='relation'else e['id']
    if e['type']=='node':
        if t.get('natural')=='tree'and ident not in old_trees:
            q=project(e)
            if land.covers(Point(q))and not authored_shape.union(approaches).covers(Point(q)):
                trees.append(dict(id=ident,point=q,height=round(min(16,max(4,number(t.get('height'),7.5+(ident%31)*.12))),2)))
        continue
    if e['type']not in('way','relation'):continue
    if any(k in t for k in('building','building:part'))and ident not in old_ids and ident not in replacement_ids:
        if t.get('location')!='underground'and number(t.get('layer'))>=0 and t.get('building')not in('roof','construction')and t.get('building:part')not in('roof','column','ramp','elevator'):
            for j,g in enumerate(polygons(shape(e))):
                if g.area<16:continue
                outer=list(g.exterior.coords)[:-1]
                if sum(outer[i][0]*outer[(i+1)%len(outer)][1]-outer[(i+1)%len(outer)][0]*outer[i][1]for i in range(len(outer)))<0:outer.reverse()
                lookup={q:i for i,q in enumerate(outer)};idx=[]
                for tr in constrained_delaunay_triangles(Polygon(outer)).geoms:
                    q=list(tr.exterior.coords)[:-1]
                    if sum(q[i][0]*q[(i+1)%3][1]-q[(i+1)%3][0]*q[i][1]for i in range(3))<0:q.reverse()
                    idx +=[lookup[v]for v in q]
                h=number(t.get('height'));hs='height'if h else'levels'if t.get('building:levels')else'estimated'
                if not h:h=number(t.get('building:levels'))*3.75
                if h<1:h=4.5 if g.area<110 else 13.5+(ident%7)*3.8
                buildings.append(dict(id=ident if j==0 else-ident*10-j,points=[list(q)for q in outer],triangles=idx,height=round(min(h,450),2),heightSource=hs,name=t.get('name',''),kind=t.get('building:part',t.get('building','yes')),material=t.get('building:material',''),color=t.get('building:colour',''),isPart='building:part'in t,hasHoles=bool(g.interiors)))
    kind='park'if t.get('leisure')=='park'else'garden'if t.get('leisure')=='garden'else'sand'if t.get('natural')in('sand','beach')else'pitch'if t.get('leisure')=='pitch'else'grass'if t.get('landuse')in('grass','forest','meadow','recreation_ground')or t.get('natural')in('wood','scrub','grassland')or t.get('landcover')=='grass'else None
    if kind and ident not in old_areas:
        g=shape(e).intersection(land).difference(authored_shape).difference(approaches)
        if g.area>3:areas.append(mesh(g,ident,kind,t.get('name','')))
    if e['type']!='way':continue
    raw=e.get('geometry',[])
    if len(raw)<2 or any(q is None for q in raw):continue
    points=[project(q)for q in raw];line=LineString(points)
    if t.get('man_made')in('pier','quay','breakwater'):
        k=t['man_made'];dest=piers if k=='pier'else breakwaters
        if ident not in(old_piers if k=='pier'else old_walls):dest.append(dict(id=ident,points=points,width=number(t.get('width'),2.3 if k=='pier' else 3.5),kind=k,name=t.get('name',''),bridge=''))
    if 'highway'in t and ident not in old_paths and ident not in allRoadIDs:
        k=t['highway'];ped=k in('footway','path','pedestrian','cycleway','steps')
        if t.get('indoor')=='yes'or number(t.get('layer'))<0 or t.get('tunnel')or k in('elevator','corridor','bus_stop','construction')or t.get('area')=='yes':continue
        width=round(min(28,number(t.get('width'),2.5 if ped else max(2,number(t.get('lanes'),2))*3.35+1)),2)
        for j,l in enumerate(lines(line.difference(authored_shape).difference(approaches))):
            if l.length>.2:paths.append(dict(id=ident if j==0 else-ident*100-j,points=[[round(x,3),round(z,3)]for x,z in l.coords],width=width,kind=k,name=t.get('name',''),bridge=t.get('bridge','')))
# Boat positions follow mapped Burnham finger docks, with hull footprints tested
# against water, shore, every pier and already occupied slips. Not a live inventory.
burnham=union_all([surface_shape(s)for s in lf['namedWaters']+named if s['id']in(17767649,17772107)])
allpiers=[p for p in lf['piers']+piers if 1400<LineString(p['points']).centroid.y<2740 and LineString(p['points']).centroid.x>1780]
dockmask=union_all([LineString(p['points']).buffer(p['width']/2+.5)for p in allpiers]);occupied=[];boats=[]
segments=[]
for p in allpiers:
    for i in range(1,len(p['points'])):
        segments.append(dict(p,id=p['id']*100+i,points=p['points'][i-1:i+1]))
for p in sorted(segments,key=lambda p:p['id']):
    line=LineString(p['points'])
    if line.length<7 or line.length>36:continue
    a=line.interpolate(.1);b=line.interpolate(line.length-.1);dx=b.x-a.x;dz=b.y-a.y;d=math.hypot(dx,dz)
    if d<3:continue
    dx/=d;dz/=d;n=(-dz,dx)
    for side in(-1,1):
        length=min(17,max(9.5,line.length*.84));width=length*.285
        c=line.interpolate(line.length*.52);x=c.x+n[0]*side*(p['width']/2+width*.5+1.1);z=c.y+n[1]*side*(p['width']/2+width*.5+1.1)
        footprint=Polygon([(x+dx*length*.53*u+n[0]*width*.56*v,z+dz*length*.53*u+n[1]*width*.56*v)for u,v in[(-1,-1),(1,-1),(1,1),(-1,1)]])
        if not burnham.buffer(-1).covers(footprint)or dockmask.intersects(footprint)or any(g.intersects(footprint)for g in occupied):continue
        occupied.append(footprint);boats.append(dict(id=p['id']*2+(side==1),point=[round(x,3),round(z,3)],length=round(length,2),angle=round(math.atan2(dx,dz),6),sailboat=p['id']%4!=0,detailed=(1850<x<2120 and 1650<z<2300)))
result=dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=source['osm3s']['timestamp_osm_base'],origin=[LAT,LON],mapBounds=[41.839,-87.638,41.872,-87.594],worldBounds=[-2400,-6200,6000,7800],ground=ground,water=water,legacyGround=legacy_ground,legacyWater=legacy_water,namedWaters=named,landmarks=sorted(landmarks,key=lambda x:x['id']),replacementBuildingIDs=sorted(replacement_ids),authoredMask=mesh(authored_shape,0,'exclusion'),approaches=mesh(approaches,0,'approach'),buildings=sorted(buildings,key=lambda x:x['id']),areas=sorted(areas,key=lambda x:x['id']),paths=paths,piers=piers,breakwaters=breakwaters,trees=trees,roads=roads,trafficLanes=traffic,boats=boats,sourceSHA256=hashlib.sha256(RAW.read_bytes()).hexdigest(),previousLakefrontSHA256=hashlib.sha256((ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json').read_bytes()).hexdigest())
DEST.parent.mkdir(parents=True,exist_ok=True);DEST.write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
print(json.dumps({k:len(result[k])for k in('landmarks','replacementBuildingIDs','buildings','areas','paths','piers','breakwaters','trees','roads','trafficLanes','boats')},indent=2));print('Additional road metres:',[r['length']for r in roads]);print('Resource bytes',DEST.stat().st_size)
