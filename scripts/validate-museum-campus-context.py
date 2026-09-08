#!/usr/bin/env python3
"""CPU map/topology/geometry-support checks; no application or GPU required."""
import json,math,hashlib
from pathlib import Path
from shapely import Polygon,LineString,Point,union_all
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'Sources/ArchitectureEngine/Resources/MuseumCampus/MuseumCampusContext.json'
d=json.loads(path.read_text());lf=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json').read_text());old=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json').read_text())
def shape(s):
    g=Polygon()
    for r in s['rings']:g=g.symmetric_difference(Polygon(r))
    return g
def meshcheck(s):
    p=s['points'];t=s['triangles'];assert len(t)%3==0
    assert all(len(q)==2 and all(math.isfinite(v)for v in q)for q in p)
    assert all(isinstance(i,int)and 0<=i<len(p)for i in t)
    area=0
    for i in range(0,len(t),3):
        a,b,c=[p[t[j]]for j in range(i,i+3)];signed=((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))/2
        assert signed>0,('Nonpositive triangulation',s['id']);area+=signed
    g=shape(s);assert g.is_valid
    assert abs(g.area-area)<max(.12,g.area*2e-6),(s['id'],g.area,area)
    return g
for s in [d['ground'],d['water'],d['legacyGround'],d['legacyWater'],d['authoredMask'],d['approaches']]+d['areas']+d['landmarks']+d['namedWaters']:meshcheck(s)
ground=shape(d['ground']);water=shape(d['water']);oldground=shape(lf['ground']);oldwater=shape(lf['water']);renderedOldGround=shape(d['legacyGround']);renderedOldWater=shape(d['legacyWater'])
north=Polygon([(-2400,-6200),(6000,-6200),(6000,3500),(-2400,3500)])
assert renderedOldGround.symmetric_difference(oldground).intersection(north).area<.1
assert renderedOldWater.symmetric_difference(oldwater).intersection(north).area<.1
for z in (3800,4000):
    assert not renderedOldGround.covers(Point(3000,z)) and renderedOldWater.covers(Point(3000,z)), 'Old coastline cap covers open lake'
assert renderedOldGround.intersection(renderedOldWater).area<.01
assert ground.intersection(water).area<.001
assert ground.intersection(oldground).area<.001 and water.intersection(oldwater).area<.001
assert ground.union(water).symmetric_difference(Polygon([(-2400,4200),(6000,4200),(6000,7800),(-2400,7800)])).area<.001
assert d['previousLakefrontSHA256']==hashlib.sha256((ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json').read_bytes()).hexdigest()
assert d['sourceSHA256']==hashlib.sha256((ROOT/'scripts/data/chicago-museum-campus-osm-2026-09-08.json').read_bytes()).hexdigest()
for kind,previous in [('buildings',old['buildings']+lf['buildings']),('paths',old['paths']+old['bridges']+lf['paths']),('areas',old['areas']+lf['areas']),('trees',lf['trees']),('piers',lf['piers']),('breakwaters',lf['breakwaters'])]:
    ids=[v['id']for v in d[kind]];assert len(ids)==len(set(ids)),('duplicate new',kind)
    assert not set(ids).intersection(v['id']for v in previous),('duplicate old',kind)
landmarks={s['id']:s for s in d['landmarks']}
for ident in [24825537,-17430414,24825591,766703208,686342956,91526195,-16699535,136340574,769452749,204886155,-17647196,561284192]:assert ident in landmarks
assert 147217805 not in d['replacementBuildingIDs'],'Separate Hilton Chicago hall must remain context'
assert 210537559 not in d['replacementBuildingIDs'],'Separate Donnelly Armory must remain context'
mask=shape(d['authoredMask'])
for ident in d['replacementBuildingIDs']:assert mask.covers(shape(landmarks[ident]).representative_point())
for building in d['buildings']:
    assert building['height']>0 and building['height']<=450 and math.isfinite(building['height'])
    assert not mask.covers(Polygon(building['points']).representative_point())
assert len(d['roads'])==2 and {v['id']for v in d['trafficLanes']}=={0,1,2,10,11,12}
for r in d['roads']:
    oldroad=next(v for v in lf['roads']if v['id']==r['id'])
    assert r['width']==oldroad['width']
    assert not set(r['sourceIDs']).intersection(oldroad['sourceIDs'])
    assert r['points'][-1]==oldroad['points'][0]or r['points'][0]==oldroad['points'][-1]
    line=LineString([(p[0],p[2])for p in r['points']]);assert abs(line.length-r['length'])<1
    assert all(0<math.dist(a,b)<5.02 for a,b in zip(r['points'],r['points'][1:]))
for lane in d['trafficLanes']:
    pts=lane['points'];prior=next(v for v in lf['trafficLanes']if v['id']==lane['id'])['points']
    start=pts.index(prior[0]);assert pts[start:start+len(prior)]==prior
    assert max(p[2]for p in pts)>6800 and min(p[2]for p in pts)<-5900
    assert all(len(p)==3 and all(math.isfinite(v)for v in p)for p in pts)
    assert all(0<math.dist(a,b)<5.8 for a,b in zip(pts,pts[1:])),lane['id']
    assert lane['spawnFadeMetres']==550 and lane['speedMetresPerSecond']==17.8816
# Check every representative moored hull against actual harbor water and piers.
burnham=union_all([shape(s)for s in lf['namedWaters']+d['namedWaters']if s['id']in(17767649,17772107)])
piers=[p for p in lf['piers']+d['piers']if 1400<LineString(p['points']).centroid.y<2740 and LineString(p['points']).centroid.x>1780]
dockmask=union_all([LineString(p['points']).buffer(p['width']/2+.5)for p in piers]);occupied=[]
for boat in d['boats']:
    x,z=boat['point'];length=boat['length'];width=length*.285;dx,dz=math.sin(boat['angle']),math.cos(boat['angle']);nx,nz=-dz,dx
    hull=Polygon([(x+dx*length*.52*u+nx*width*.55*v,z+dz*length*.52*u+nz*width*.55*v)for u,v in[(-1,-1),(1,-1),(1,1),(-1,1)]])
    assert burnham.covers(hull),('boat ashore',boat['id'])
    assert not dockmask.intersects(hull),('boat intersects dock',boat['id'])
    assert not any(q.intersects(hull)for q in occupied),('boats overlap',boat['id'])
    occupied.append(hull)
assert len(d['boats'])>100 and sum(b['detailed']for b in d['boats'])>30
result={'passed':True,'resourceSHA256':hashlib.sha256(path.read_bytes()).hexdigest(),'sourceSHA256':d['sourceSHA256'],'previousLakefrontSHA256':d['previousLakefrontSHA256'],'counts':{k:len(d[k])for k in('landmarks','replacementBuildingIDs','buildings','areas','paths','trees','piers','breakwaters','roads','trafficLanes','boats')},'checks':['positive constrained triangles and polygon area coverage','disjoint land/water and old/new southern seam','unchanged previous resource hash and northern terrain; repaired exposed old south shoreline cap','no repeated old/new feature IDs','authored museum/stadium/convention exclusions','exact original northern lane subsequences','continuous finite directed road/lane extension','151 hulls within mapped Burnham water, clear of piers and one another'],'limits':['Generic map heights remain tagged or explicitly estimated; no survey accuracy claimed.','Representative dock occupancy is deterministic, not a real-time berth inventory.','Tests verify map and mesh support, not final video or full-world camera clearance.']}
out=ROOT/'output/v7-review/museum-campus-map-validation.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
