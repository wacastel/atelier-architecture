#!/usr/bin/env python3
"""Offline OSM lakefront derivative; run with scripts/requirements-map.txt.
Uses polygon boolean operations and constrained triangulation, preserving the
actual lake/harbor/river shore instead of laying a ground rectangle over water.
"""
import json, math, re
from pathlib import Path
from collections import defaultdict
from shapely import Polygon, LineString, Point, box, make_valid, union_all, constrained_delaunay_triangles
from shapely.ops import linemerge
ROOT=Path(__file__).resolve().parents[1]
LAT,LON=41.878876,-87.635918
RAW=ROOT/'scripts/data/chicago-lakefront-osm-2026-09-08.json'
WATER=ROOT/'scripts/data/chicago-lakefront-water-2026-09-08.json'
SHORE=ROOT/'scripts/data/chicago-lakefront-shoreline-2026-09-08.json'
DEST=ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json'
source=json.loads(RAW.read_text());water_source=json.loads(WATER.read_text())
landscape_source=json.loads((ROOT/'scripts/data/chicago-lakefront-landscape-2026-09-08.json').read_text())
old=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json').read_text())
WORLD=box(-2400,-6200,6000,4200)
PARK_EXCLUSION=union_all([box(969,-606,1256,-227),box(982,-200,1231,48)])
LANDMARK_IDS={31064573,232905278,232905280,232905283,232906397,232914185,279951771,279951772,1282265474,232935981,1282265459,64627674,590824927,130147025,148560424}
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

# Lake Michigan's bounded outer chain includes the breakwater boundary. Closed
# harbor polygons fill the enclosed water west of it; river polygons join them.
lake=next(e for e in json.loads(SHORE.read_text())['elements']if e['id']==1205149)
coast=max(relation_rings(lake,'outer'),key=lambda q:LineString(q).length)
if coast[0][1]>coast[-1][1]:coast.reverse()
lake_shape=clean(Polygon(coast+[(6000,coast[-1][1]),(6000,coast[0][1])]))
water_shapes=[lake_shape]
named_waters=[]
for e in water_source['elements']:
    if e['id']==1205149:continue
    if e.get('tags',{}).get('water')not in ('river','harbour','lagoon'):continue
    g=relation_shape(e)
    if g.is_empty:continue
    water_shapes.append(g);named_waters.append(mesh(g,e['id'],'water',e.get('tags',{}).get('name','Chicago River')))
for a in old['rivers']:water_shapes.append(Polygon(a['points']))
for e in source['elements']:
    if e.get('tags',{}).get('water')=='harbour':
        g=way_shape(e)
        if not g.is_empty:water_shapes.append(g);named_waters.append(mesh(g,e['id'],'water',e['tags'].get('name','')))
water=clean(union_all(water_shapes));land=WORLD.difference(water)
# Existing open-air Metra corridor, bounded away from museum/covered station.
# Its land-use polygon supplies retaining edges; individual tracks supply gauge
# alignment. This is a real ground void, not rails painted over park paving.
rail_source=json.loads((ROOT/'scripts/data/chicago-lakefront-rail-2026-09-08.json').read_text())
rail_site=next(e for e in source['elements']if e['type']=='way'and e['id']==95473933)
rail_cut=way_shape(rail_site).intersection(box(1000,58,1340,1350)).intersection(land)
rail_floor=mesh(rail_cut,95473933,'railway','Open-air Metra corridor')
rails=[]
def lines(g):
    if g.is_empty:return []
    if g.geom_type=='LineString':return [g]
    return [q for part in getattr(g,'geoms',[])for q in lines(part)]
for e in rail_source['elements']:
    if e.get('tags',{}).get('tunnel')or not e.get('geometry'):continue
    line=LineString([project(q)for q in e['geometry']]).intersection(rail_cut)
    for j,g in enumerate(lines(line)):
        if g.length<1:continue
        rails.append(dict(id=e['id']*10+j,points=[[round(x,3),round(z,3)]for x,z in g.coords],width=1.435,kind='rail',name=e.get('tags',{}).get('name',''),bridge=''))
land=land.difference(rail_cut)
ground=mesh(land,0,'ground');water_mesh=mesh(water,0,'water')

# Main outer carriageways form exactly two directed OSM chains. Inner/Lower
# Lake Shore Drive and ramps are excluded from through-traffic routes.
main=[e for e in source['elements']if e['type']=='way'and 'Lake Shore Drive'in e.get('tags',{}).get('name','')and e['tags'].get('highway')in('motorway','trunk')]
starts=defaultdict(list);ends=defaultdict(list)
for e in main:starts[e['nodes'][0]].append(e);ends[e['nodes'][-1]].append(e)
chains=[]
for first in main:
    if ends[first['nodes'][0]]:continue
    chain=[];visited=set();e=first
    while e['id']not in visited:
        visited.add(e['id']);chain.append(e);nexts=starts[e['nodes'][-1]]
        if not nexts:break
        assert len(nexts)==1,'Ambiguous main carriageway topology'
        e=nexts[0]
    chains.append(chain)
assert len(chains)==2 and sum(map(len,chains))==len(main),'Incomplete Lake Shore Drive topology'
def grade(x,z):
    # Interpreted upper-deck elevation around the river, smoothly connected to
    # grade at Grand/Randolph. Both static pavement and traffic share this Y.
    if -1550<z< -590:
        north=min(1,max(0,(-z-590)/210));south=min(1,max(0,(1550+z)/170))
        smooth=lambda t:t*t*(3-2*t)
        return round(.12+6.6*min(smooth(north),smooth(south)),3)
    return .12
roads=[];traffic=[]
for chain_id,chain in enumerate(sorted(chains,key=lambda c:c[0]['geometry'][0]['lat'])):
    coords=[]
    for e in chain:
        q=[project(v)for v in e['geometry']]
        if coords:assert coords[-1]==q[0],'Main carriageway gap'
        coords+=q if not coords else q[1:]
    line=LineString(coords);points=[]
    steps=math.ceil(line.length/5)
    for i in range(steps+1):
        q=line.interpolate(line.length*i/steps);points.append([round(q.x,3),grade(q.x,q.y),round(q.y,3)])
    roads.append(dict(id=chain_id,points=points,width=15.6,sourceIDs=[e['id']for e in chain],length=round(line.length,3)))
    for lane in range(3):
        shifted=[]
        for i,p in enumerate(points):
            a=points[max(0,i-1)];b=points[min(len(points)-1,i+1)];dx=b[0]-a[0];dz=b[2]-a[2];length=math.hypot(dx,dz)
            offset=(lane-1)*3.55
            shifted.append([round(p[0]-dz/length*offset,3),p[1],round(p[2]+dx/length*offset,3)])
        traffic.append(dict(id=chain_id*10+lane,points=shifted,speedMetresPerSecond=17.8816,spawnFadeMetres=550))

old_ids={b['id']for b in old['buildings']};old_paths={p['id']for p in old['paths']+old['bridges']};old_areas={a['id']for a in old['areas']}
old_shapes=[Polygon(b['points'])for b in old['buildings']if not b['isPart']]
way_elements=[e for e in source['elements']if e['type']=='way']
parts=[]
for e in way_elements:
    t=e.get('tags',{});g=way_shape(e)if 'building:part'in t else Polygon()
    if g.is_empty or t.get('building:part')in('roof','column','ramp','elevator')or not(t.get('height')or t.get('building:levels')):continue
    if e['id']in LANDMARK_IDS:continue
    if any(s.covers(g.representative_point())for s in old_shapes):continue
    parts.append((e,g))
buildings=[];areas=[];paths=[];piers=[];breakwaters=[];trees=[];landmarks=[]
part_ids={e['id']for e,g in parts}
for e in way_elements:
    t=e.get('tags',{});ident=e['id'];raw=e.get('geometry',[])
    if not raw or any(q is None for q in raw):continue
    points=[project(q)for q in raw];line=LineString(points)
    if ident in LANDMARK_IDS or ident==561821879:
        landmarks.append(dict(id=ident,name=t.get('name',''),points=points,tags=t))
    if 'building'in t or ident in part_ids:
        if ident in old_ids or ident in LANDMARK_IDS:continue
        if 'building:part'in t and ident not in part_ids:continue
        if t.get('location')=='underground'or number(t.get('layer'))<0 or t.get('building')in('roof','construction')or t.get('wall')=='no':continue
        g=way_shape(e)
        if g.is_empty or g.area<16 or PARK_EXCLUSION.covers(g.representative_point()):continue
        for j,poly in enumerate(polygons(g)):
            outer=list(poly.exterior.coords)[:-1]
            # Renderers expect perimeter points, not a roof's flattened mesh.
            if sum(outer[i][0]*outer[(i+1)%len(outer)][1]-outer[(i+1)%len(outer)][0]*outer[i][1]for i in range(len(outer)))<0:outer.reverse()
            lookup={q:i for i,q in enumerate(outer)};idx=[]
            for tr in constrained_delaunay_triangles(Polygon(outer)).geoms:
                q=list(tr.exterior.coords)[:-1]
                if sum(q[i][0]*q[(i+1)%3][1]-q[(i+1)%3][0]*q[i][1]for i in range(3))<0:q.reverse()
                idx += [lookup[v]for v in q]
            h=number(t.get('height'));hs='height'if h else'levels'if t.get('building:levels')else'estimated'
            if not h:h=number(t.get('building:levels'))*3.75
            if h<1:h=4.5 if poly.area<110 else 15+(ident%9)*3.8
            if 'building:part'not in t and any(poly.covers(part.representative_point())for pe,part in parts if pe['id']!=ident):h=4;hs='base-under-mapped-parts'
            buildings.append(dict(id=ident if j==0 else-ident*10-j,points=[list(q)for q in outer],triangles=idx,height=round(min(h,450),2),heightSource=hs,name=t.get('name',''),kind=t.get('building:part',t.get('building','yes')),material=t.get('building:material',''),color=t.get('building:colour',''),isPart='building:part'in t,hasHoles=bool(poly.interiors)))
    if t.get('man_made')in('pier','breakwater','quay'):
        if t['man_made']=='pier'and min(q[0]for q in points)>1500:
            piers.append(dict(id=ident,points=points,width=number(t.get('width'),2.3),kind='pier',name=t.get('name',''),bridge=''))
        elif t['man_made']in('breakwater','quay'):
            breakwaters.append(dict(id=ident,points=points,width=number(t.get('width'),3.5),kind=t['man_made'],name=t.get('name',''),bridge=''))
    if 'highway'in t and ident not in old_paths and ident not in {v['id']for v in main}:
        kind=t['highway'];ped=kind in('footway','path','pedestrian','cycleway','steps')
        if t.get('indoor')=='yes'or number(t.get('layer'))<0 or t.get('tunnel') or kind in('elevator','corridor','bus_stop','construction'):continue
        if 'Lower'in t.get('name','')or t.get('area')=='yes':continue
        if PARK_EXCLUSION.covers(line.centroid):continue
        if line.centroid.x<400 and line.centroid.y> -1100:continue
        paths.append(dict(id=ident,points=points,width=round(min(28,number(t.get('width'),2.5 if ped else max(2,number(t.get('lanes'),2))*3.35+1)),2),kind=kind,name=t.get('name',''),bridge=t.get('bridge','')))
    kind='sand'if t.get('natural')in('sand','beach')else'garden'if t.get('leisure')=='garden'else'pitch'if t.get('leisure')in('pitch','track')else'grass'if t.get('landuse')in('grass','forest')or t.get('natural')in('wood','scrub','grassland')or t.get('leisure')in('park','common')else None
    if kind and ident not in old_areas:
        g=way_shape(e).intersection(land).difference(PARK_EXCLUSION)
        if g.area>3:areas.append(mesh(g,ident,kind,t.get('name','')))
for e in source['elements']:
    if e['type']=='node'and e.get('tags',{}).get('natural')=='tree':
        q=project(e)
        if PARK_EXCLUSION.covers(Point(q))or not land.covers(Point(q))or(q[0]<600 and q[1]>-1100):continue
        trees.append(dict(id=e['id'],point=q,height=round(min(18,max(4,number(e.get('tags',{}).get('height'),7.5+(e['id']%50)*.09))),2)))
for e in source['elements']:
    if e['type']=='relation'and e.get('tags',{}).get('leisure')=='marina':
        shape=relation_shape(e)
        if not shape.is_empty:landmarks.append(mesh(shape,e['id'],'harbor',e['tags'].get('name','')))
existing_area_ids={a['id']for a in areas}
for e in landscape_source['elements']:
    t=e.get('tags',{});ident=-e['id']if e['type']=='relation'else e['id']
    if ident in existing_area_ids:continue
    kind='park'if t.get('leisure')=='park'else'garden'if t.get('leisure')=='garden'else'sand'if t.get('natural')in('sand','beach')else'pitch'if t.get('leisure')=='pitch'else'grass'if t.get('landuse')in('grass','forest','meadow','recreation_ground')or t.get('natural')in('wood','scrub','grassland')or t.get('landcover')=='grass'else None
    if kind is None:continue
    g=(relation_shape(e)if e['type']=='relation'else way_shape(e)).intersection(land).difference(PARK_EXCLUSION)
    if g.area>3:areas.append(mesh(g,ident,kind,t.get('name','')))
legacy_areas=[]
for a in old['areas']:
    shape=make_valid(Polygon(a['points'])).difference(rail_cut)
    legacy_areas.append(mesh(shape,a['id'],a['kind'],a['name']))
rail_crossings=[]
for p in old['paths']+old['bridges']+paths:
    g=LineString(p['points']).intersection(rail_cut)
    for j,line in enumerate(lines(g)):
        if line.length<.2:continue
        ped=p['kind']in('footway','path','pedestrian','cycleway','steps')
        rail_crossings.append(dict(id=p['id']*10+j,points=[[round(x,3),round(z,3)]for x,z in line.coords],width=p['width']+(0 if ped else 5.8),kind=p['kind'],name=p['name'],bridge='yes'))
crossing_mask=union_all([LineString(p['points']).buffer(p['width']/2+0.35)for p in rail_crossings])
rail_guards=[dict(id=i,points=[[round(x,3),round(z,3)]for x,z in line.coords],width=.05,kind='guard',name='',bridge='')for i,line in enumerate(lines(rail_cut.boundary.difference(crossing_mask)))if line.length>.1]
result=dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=source['osm3s']['timestamp_osm_base'],origin=[LAT,LON],mapBounds=[41.865,-87.64,41.913,-87.607],worldBounds=[-2400,-6200,6000,4200],ground=ground,water=water_mesh,namedWaters=named_waters,railFloor=rail_floor,rails=rails,railCrossings=rail_crossings,railGuards=rail_guards,legacyAreas=legacy_areas,buildings=sorted(buildings,key=lambda b:b['id']),areas=sorted(areas,key=lambda a:a['id']),paths=sorted(paths,key=lambda p:p['id']),piers=piers,breakwaters=breakwaters,trees=trees,landmarks=landmarks,roads=roads,trafficLanes=traffic)
DEST.parent.mkdir(parents=True,exist_ok=True);DEST.write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
print('Lakefront:',len(buildings),'additional buildings,',len(areas),'areas,',len(paths),'paths,',len(trees),'trees,',len(piers),'piers,',len(traffic),'traffic lanes')
print('Main carriageways metres:',[r['length']for r in roads]);print('ground/water triangles',len(ground['triangles'])//3,len(water_mesh['triangles'])//3,'bytes',DEST.stat().st_size)
