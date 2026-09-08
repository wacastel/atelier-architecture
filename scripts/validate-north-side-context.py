#!/usr/bin/env python3
"""CPU-only topology, provenance, traffic and water-placement regression checks."""
import json,hashlib,math,argparse,importlib.util
from pathlib import Path
from shapely import Polygon,LineString,Point,box,make_valid,union_all
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--json',default='output/v8-review/north-side-map-validation.json');args=parser.parse_args()
resource=ROOT/'Sources/ArchitectureEngine/Resources/NorthSide/NorthSideContext.json';d=json.loads(resource.read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def shape(s):
    g=Polygon()
    for ring in s['rings']:g=g.symmetric_difference(Polygon(ring))
    return make_valid(g)
def area_check(s):
    points=s['points'];idx=s['triangles'];assert len(idx)%3==0
    assert all(math.isfinite(v)for q in points for v in q)
    assert all(0<=i<len(points)for i in idx)
    tris=[]
    for i in range(0,len(idx),3):
        q=[points[j]for j in idx[i:i+3]];p=Polygon(q)
        assert p.area>1e-9;tris.append(p)
    expected=shape(s);actual=union_all(tris)
    error=actual.symmetric_difference(expected).area
    assert error<max(.12,expected.area*3e-6),(s['id'],'triangulation coverage',error)
    assert abs(sum(p.area for p in tris)-actual.area)<max(.12,actual.area*3e-6),(s['id'],'overlapping triangles')
    return len(tris)
assert d['attribution']=='© OpenStreetMap contributors'and d['license']=='ODbL 1.0'
for name,h in d['sourceSHA256'].items():assert sha(ROOT/'scripts/data'/name)==h
for name,h in d['previousResourceSHA256'].items():assert sha(ROOT/name)==h,'Previous region resource changed'
surfaces=[d[k]for k in['ground','water','legacyGround','legacyWater','authoredMask']]+d['areas']+d['legacyAreas']+[w['surface']for w in d['inlandWaters']]+[b['surface']for b in d['beaches']]
surfaces += [a['surface']for a in d['landcoverRestoration']['plantingAreas']]
surface_triangles=sum(area_check(s)for s in surfaces)
land=union_all([shape(d['ground']),shape(d['legacyGround'])]);water=union_all([shape(d['water']),shape(d['legacyWater'])]+[shape(w['surface'])for w in d['inlandWaters']])
assert land.intersection(water).area<.12,'Opaque ground overlaps water'
assert shape(d['ground']).intersection(shape(d['legacyGround'])).area<.12,'Extension overlaps old terrain'
campus=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/MuseumCampus/MuseumCampusContext.json').read_text())
south=box(-2400,-3500,6000,4200)
assert shape(d['legacyGround']).intersection(south).symmetric_difference(shape(campus['legacyGround']).intersection(south)).area<.15,'Existing southern terrain changed'
assert shape(d['legacyWater']).intersection(south).symmetric_difference(shape(campus['legacyWater']).intersection(south)).area<.15,'Existing southern water changed'
for ident,y in[(-2514193,-.55),(116740882,-.25)]:
    w=next(w for w in d['inlandWaters']if w['surface']['id']==ident)
    assert w['elevation']==y
    pond=shape(w['surface']);assert all(shape(a).intersection(pond).area<.12 for a in d['areas']+d['legacyAreas']),'Grass covers pond'
for beach in d['beaches']:
    assert len(beach['elevations'])==len(beach['surface']['points'])
    assert all(-5.63<=y<=0 for y in beach['elevations'])
    assert land.intersection(shape(beach['surface'])).area<.12,'Ground covers sloping beach'
for k in['buildings','paths','areas','trees','piers','breakwaters']:
    ids=[q['id']for q in d[k]];assert len(ids)==len(set(ids)),(k,'duplicate IDs')
old_buildings=set()
for region in['Chicago','Lakefront','MuseumCampus']:
    prev=json.loads((ROOT/f'Sources/ArchitectureEngine/Resources/{region}/{region}Context.json').read_text());old_buildings.update(b['id']for b in prev['buildings'])
assert not old_buildings.intersection(b['id']for b in d['buildings'])
for b in d['buildings']:
    polygon=Polygon(b['points']);assert polygon.is_valid and polygon.area>0
    assert 0<b['height']<=450 and b['heightSource']in('height','levels','estimated')
    tri_area=sum(Polygon([b['points'][j]for j in b['triangles'][i:i+3]]).area for i in range(0,len(b['triangles']),3))
    assert abs(tri_area-polygon.area)<max(.05,polygon.area*1e-6),'Roof ordering/coverage'
for ident in[210315405,417380833,24826112,23986733,-17379974,1265774541,-17380054]:assert ident in d['replacementBuildingIDs']
assert all(p['id']!=758462743 for p in d['paths']),'Authored Fisher bridge duplicated'
assert len(d['trafficLanes'])==6
for lane in d['trafficLanes']:
    old=next(q for q in campus['trafficLanes']if q['id']==lane['id']);start=lane['points'].index(old['points'][0])
    assert lane['points'][start:start+len(old['points'])]==old['points'],'Original traffic samples changed'
    assert min(q[2]for q in lane['points'])<-10000 and max(q[2]for q in lane['points'])>6800
    assert all(math.dist(a,b)<8 and math.dist(a,b)>0 for a,b in zip(lane['points'],lane['points'][1:]))
for road in d['roads']:
    assert len(road['points'])>500 and road['length']>5000
    assert all(q[1]==.12 for q in road['points'])
harbors={s['id']:shape(s)for s in d['namedHarbors']};harbor=union_all([harbors[-17766292],harbors[-17766386]])
docks=union_all([LineString(p['points']).buffer(p['width']/2+.4)for p in d['piers']])
occupied=[];diversey_count=0
for boat in d['boats']:
    x,z=boat['point'];length=boat['length'];a=boat['angle'];dx,dz=math.sin(a),math.cos(a);n=(-dz,dx);width=length*.285
    hull=Polygon([(x+dx*length*.53*u+n[0]*width*.56*v,z+dz*length*.53*u+n[1]*width*.56*v)for u,v in[(-1,-1),(1,-1),(1,1),(-1,1)]])
    assert harbor.buffer(.01).covers(hull)and not docks.intersects(hull),'Boat outside harbor or through dock'
    assert not any(p.intersects(hull)for p in occupied);occupied.append(hull)
    if harbors[-17766292].covers(Point(x,z)):assert not boat['sailboat'];diversey_count+=1
assert len(d['boats'])>50 and diversey_count>0
# A larger snapshot of the same parent relation must restore missing coverage;
# source-ID deduplication alone once left 254 hectares of park as bare paving.
canonical=lambda value:hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
preserved={k:v for k,v in d.items()if k not in('areas','landcoverTrees','landcoverRestoration')}
assert canonical(preserved)=='aa6e3aa09330ee40d69569fc3dd994196e573e9e5af10e718d0922ba70e6fdc7','Landcover correction changed an earlier layer'
assert canonical(d['areas'][:-1])=='528d6b1f06c6ed9e1a8845b2ea107c4ddad36153c8ac4e0b2ffa03926861ed34','Earlier landscape surfaces changed'
restoration=d['landcoverRestoration'];restored=shape(d['areas'][-1])
assert d['areas'][-1]['id']==-11610689 and d['areas'][-1]['kind']=='park'
assert restored.bounds[3]<=-6200 and 1_800_000<restored.area<2_100_000
assert restored.intersection(water).area<.15
assert all(restored.intersection(shape(b['surface'])).area<.15 for b in d['beaches'])
legacy_parent=union_all([shape(a)for a in d['legacyAreas']if a['id']==-11610689])
assert restored.intersection(legacy_parent).area<.15,'Clipped parent was duplicated instead of extended'
spec=importlib.util.spec_from_file_location('north_source',ROOT/'scripts/prepare-north-side-context.py');raw=importlib.util.module_from_spec(spec);spec.loader.exec_module(raw)
parent=raw.shape(raw.elements[('relation',11610689)])
assert restored.difference(parent.buffer(.002)).area<.1,'Lawn extends outside actual mapped park'
for ident in restoration['excludedHardSurfaceIDs']:
    e=raw.elements[('relation'if ident<0 else'way',abs(ident))]
    assert restored.intersection(raw.shape(e).buffer(-.002)).area<.15,('Grass covers mapped hard surface',ident)
for path in d['paths']:
    corridor=LineString(path['points']).buffer(path['width']/2-.01,cap_style=2,join_style=2)
    if corridor.bounds[1]<-6200:assert restored.intersection(corridor).area<.15,('Grass covers path',path['id'])
for road in d['roads']:
    corridor=LineString([(q[0],q[2])for q in road['points']]).buffer(road['width']/2,cap_style=2,join_style=2)
    assert restored.intersection(corridor).area<.15,'Grass covers Lake Shore Drive'
positive_probes=[[0,-6300],[150,-6700],[-200,-7700],[-400,-8200]]
prior_green=union_all([shape(a)for a in d['areas'][:-1]+d['legacyAreas']])
for p in positive_probes:
    assert restored.covers(Point(p)),('Missing northern lawn',p)
    assert not prior_green.covers(Point(p)),('Probe does not reproduce original omission',p)
negative_ids=[-12791944,1295069087,1296126328,129582310,23921848,23989865]
negative_probes=[]
for ident in negative_ids:
    q=raw.shape(raw.elements[('relation'if ident<0 else'way',abs(ident))]).representative_point()
    assert not restored.covers(q),('Hard/beach negative probe became lawn',ident)
    negative_probes.append(dict(sourceID=ident,point=[round(q.x,3),round(q.y,3)]))
eligible={a['sourceAreaID']:shape(a['surface'])for a in restoration['plantingAreas']}
for ident,g in eligible.items():
    element=raw.elements[('relation'if ident<0 else'way',abs(ident))];tags=element['tags']
    assert tags.get('natural')in('wood','scrub')or tags.get('landuse')=='forest'
    assert g.difference(raw.shape(element).buffer(.002)).area<.1
    assert g.difference(restored.buffer(.002)).area<.1
landcover_ids=set();tagged=union_all([Point(t['point']).buffer(4.99)for t in d['trees']if t['point'][1]<-6200])
for tree in d['landcoverTrees']:
    assert tree['id']< -9_000_000_000_000 and tree['id']not in landcover_ids;landcover_ids.add(tree['id'])
    q=Point(tree['point']);assert eligible[tree['sourceAreaID']].buffer(.002).covers(q)
    assert restored.buffer(-3.88).covers(q),'Canopy would overhang excluded roads/water'
    assert not tagged.covers(q),'Authored canopy duplicates an unchanged tagged tree'
    assert 4.5<=tree['height']<=12.3
assert len(d['trees'])==restoration['taggedTreeCount']==3752
assert 150<len(d['landcoverTrees'])==restoration['authoredTreeCount']<2200
report=dict(passed=True,scope='CPU-only source/topology/placement checks; no renderer or visual claims',resourceSHA256=sha(resource),timestamp=d['timestamp'],counts={k:len(d[k])for k in['buildings','areas','paths','trees','landcoverTrees','piers','breakwaters','landmarks','boats','trafficLanes']},surfaceTriangles=surface_triangles,diverseyPowerboats=diversey_count,landcoverRestoration=dict(sourceParentID=-11610689,lawnSquareMetres=restored.area,taggedTreeCount=len(d['trees']),authoredCanopyCount=len(d['landcoverTrees']),plantingSourceAreaIDs=sorted(eligible),positiveLawnProbes=positive_probes,negativeSurfaceProbes=negative_probes,preservedLayersSHA256=canonical(preserved),preservedAreasSHA256=canonical(d['areas'][:-1])),checks=['ODbL metadata and raw hashes','previous resources unchanged','constrained triangulation coverage and nonoverlap','old southern terrain/water unchanged','new land/water/beach disjointness','shallow ponds not covered by grass','ordered building outlines and roof area','no duplicate old building IDs','authored landmark/boardwalk exclusions','six exact old lane sample sequences with remote north extensions','harbor hull/dock/boat clearance','Diversey powerboats only','all pre-landcover derivative layers and 1360 earlier surfaces unchanged','restored northern Lincoln Park remains inside raw parent and outside mapped hard surfaces/roads/water/beaches','four formerly missing lawn probes and six mapped hard/beach negatives','authored sparse canopy source polygons, crown clearances and separation from tagged tree nodes'])
out=ROOT/args.json;out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
