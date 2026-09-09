#!/usr/bin/env python3
"""Validate the offline Hyde Park derivative; requires Shapely 2.1.2."""
import json,math,hashlib
from pathlib import Path
from shapely import Polygon,Point,LineString,union_all,make_valid
ROOT=Path(__file__).resolve().parents[1]
P=ROOT/'Sources/ArchitectureEngine/Resources/HydePark/HydeParkContext.json';d=json.loads(P.read_text())
def shape(surface):
 g=Polygon()
 for ring in surface['rings']:g=g.symmetric_difference(Polygon(ring))
 return make_valid(g)
checks=0
def check(value,message):
 global checks
 assert value,message;checks+=1
for path,digest in d['previousResourceSHA256'].items():check(hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,'Prior derivative changed')
for path,digest in d['sourceSHA256'].items():check(hashlib.sha256((ROOT/'scripts/data'/path).read_bytes()).hexdigest()==digest,'Dated raw source changed')
prior=[json.loads((ROOT/p).read_text())for p in d['previousResourceSHA256']]
ids={b['id']for old in prior for b in old['buildings']}
check(not ids.intersection(b['id']for b in d['buildings']),'Duplicate prior building ID')
lot=shape(d['authoredMask']);check(lot.bounds==(3288.0,9904.0,3339.0,9928.0),'Authored lot bounds changed')
check(125667497 in d['replacementBuildingIDs'],'Robie footprint must be replaced')
check(all(not shape(b).intersects(lot)for b in d['buildings']),'Context building enters Robie lot')
for b in d['buildings']:
 p=b['points'];idx=b['triangles'];area=0
 check(len(idx)%3==0 and all(0<=i<len(p)for i in idx),'Invalid roof indices')
 for i in range(0,len(idx),3):
  a,c,e=[p[k]for k in idx[i:i+3]];area+=abs((c[0]-a[0])*(e[1]-a[1])-(c[1]-a[1])*(e[0]-a[0]))/2
 check(abs(area-shape(b).area)<max(.02,area*1e-6),'Triangulation filled courtyard or changed footprint')
 check(1<=b['height']<=350 and b['heightSource'],'Missing building height provenance')
check(shape(d['ground']).intersection(shape(d['water'])).area<.001,'Land covers Lake Michigan')
check(all(7800<=p[1]<=10800 for kind in ['ground','water']for p in d[kind]['points']),'New base terrain changes previous area')
check(all(not lot.buffer(.1).contains(Point(t['point']))for t in d['trees']+d['landcoverTrees']),'Tree intersects house lot')
check(all(not LineString(p['points']).intersects(lot)for p in d['paths']),'Path intersects house lot')
ns=next(p for p in prior if 'landcoverTrees'in p)
for lane in d['trafficLanes']:
 old=next(l for l in ns['trafficLanes']if l['id']==lane['id']);offset=lane['points'].index(old['points'][0]);check(lane['points'][offset:offset+len(old['points'])]==old['points'],'Old lane modified')
 check(min(p[2]for p in lane['points'])< -11000 and max(p[2]for p in lane['points'])>10600,'Traffic fails north-south extent')
harbor=shape(next(w for w in d['namedHarbors']if w['id']==-17779015));piers=[p for old in prior for p in old.get('piers',[])]+d['piers']
dockmask=union_all([LineString(p['points']).buffer(p['width']/2+.44)for p in piers if harbor.buffer(2).intersects(LineString(p['points']))]);occupied=[]
for b in d['boats']:
 x,z=b['point'];f=(math.sin(b['angle']),math.cos(b['angle']));n=(-f[1],f[0]);length=b['length'];width=length*.27
 footprint=Polygon([(x+f[0]*length*.529*u+n[0]*width*.559*v,z+f[1]*length*.529*u+n[1]*width*.559*v)for u,v in[(-1,-1),(1,-1),(1,1),(-1,1)]])
 check(harbor.buffer(-.98).covers(footprint),'Boat exits water');check(not dockmask.intersects(footprint),'Boat intersects dock');check(not any(g.intersects(footprint)for g in occupied),'Boat overlaps another boat');occupied.append(footprint)
check(60<len(d['boats'])<1000,'Boat population outside budget')
result={'passed':True,'scope':'Offline OSM derivative topology, attribution hashes, Robie lot, building courtyards, harbor placement and lane continuity','checks':checks,'sourceTimestamp':d['timestamp'],'counts':{k:len(d[k])for k in ['buildings','landmarks','areas','paths','piers','breakwaters','trees','landcoverTrees','rails','roads','trafficLanes','boats']},'resourceBytes':P.stat().st_size,'sourceSHA256':d['sourceSHA256'],'previousResourcesUnchanged':True}
print(json.dumps(result,indent=2,sort_keys=True))
