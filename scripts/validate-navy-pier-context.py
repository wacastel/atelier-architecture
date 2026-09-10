#!/usr/bin/env python3
"""CPU map derivative validation; requires scripts/requirements-map.txt."""
import hashlib,json,math,subprocess,sys
from pathlib import Path
from shapely import Polygon,LineString,Point,union_all
ROOT=Path(__file__).resolve().parents[1];p=ROOT/'Sources/ArchitectureEngine/Resources/NavyPier/NavyPierContext.json';d=json.loads(p.read_text());before=p.read_bytes()
def shape(a):
 pts=a['points'];idx=a['triangles'];assert len(idx)%3==0
 tris=[]
 for i in range(0,len(idx),3):
  assert all(0<=j<len(pts)for j in idx[i:i+3])
  q,r,s=[pts[j]for j in idx[i:i+3]];signed=(r[0]-q[0])*(s[1]-q[1])-(r[1]-q[1])*(s[0]-q[0]);assert signed>0,(a['id'],signed)
  tris.append(Polygon([q,r,s]))
 result=union_all(tris);assert result.is_valid
 assert abs(sum(t.area for t in tris)-result.area)<.02
 return result
assert d['origin']==[41.878876,-87.635918]
for filename,sha in d['sourceSHA256'].items():assert hashlib.sha256((ROOT/'scripts/data'/filename).read_bytes()).hexdigest()==sha
mask=shape(d['approachMask']);pier=shape(d['authoredPierMask'])
assert mask.intersection(pier).area<.01
surfaces=[shape(a)for a in d['areas']+d['roadSurfaces']]
for i,g in enumerate(surfaces):
 assert g.difference(mask.buffer(.015)).area<.025
 for h in surfaces[i+1:]:assert g.intersection(h).area<.025
assert len(d['buildings'])==len({b['id']for b in d['buildings']})
for b in d['buildings']:shape(b)
for t in d['trees']:
 assert all(math.isfinite(v)for v in t['point'])
 assert mask.buffer(.002).covers(Point(t['point']))and 4<=t['height']<=15
for road in d['paths']:
 assert LineString(road['points']).difference(mask.buffer(.002)).length<.02
for replacement in d['retainedPaths']:
 for part in replacement['parts']:assert LineString(part['points']).intersection(mask.union(pier).buffer(-.002)).length<.02
# The authored detailed pier uses existing mapped land support and lake datum.
ns=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/NorthSide/NorthSideContext.json').read_text())
water=shape(ns['legacyWater']);land=shape(ns['legacyGround'])
for q in [(2357,-1428),(3000,-1444),(2100,-1420),(1925,-1520)]:assert land.covers(Point(q))and not water.covers(Point(q)),('mapped land',q)
for q in [(2450,-1570),(3050,-1650),(2750,-1300)]:assert water.covers(Point(q))and not land.covers(Point(q)),('mapped lake',q)
subprocess.run([sys.executable,str(ROOT/'scripts/prepare-navy-pier-context.py')],check=True,capture_output=True)
assert p.read_bytes()==before,'Offline preparation must be byte-reproducible'
print(json.dumps(dict(passed=True,sourceElements=len(json.loads((ROOT/'scripts/data/chicago-navy-pier-osm-2026-09-09.json').read_text())['elements']),mapFootprints=len(d['buildings']),newRenderedBuildings=len(d['newBuildingIDs']),mappedTrees=len(d['trees']),joinedPathCenterlines=len(d['paths']),retainedLegacyPaths=len(d['retainedPaths']),surfaceTriangles=sum(len(a['triangles'])//3 for a in d['areas']+d['roadSurfaces']),surfaceDisjointness=True,pierLandWaterSupport=True,reproducibleSHA256=hashlib.sha256(before).hexdigest()),indent=2))
