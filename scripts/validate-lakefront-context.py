#!/usr/bin/env python3
"""Validate the real map derivative, water complement and drivable lane topology.
Run with the Python environment in scripts/requirements-map.txt.
"""
import hashlib,json,math,subprocess,sys
from pathlib import Path
from shapely import Polygon,Point,LineString,box,union_all
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json'
before=path.read_bytes();d=json.loads(before)
assert d['origin']==[41.878876,-87.635918]
def surface(a):
    points=a['points'];indices=a['triangles'];assert len(indices)%3==0
    tris=[]
    for j in range(0,len(indices),3):
        assert all(0<=i<len(points)for i in indices[j:j+3])
        q,r,s=[points[i]for i in indices[j:j+3]]
        area=((r[0]-q[0])*(s[1]-q[1])-(r[1]-q[1])*(s[0]-q[0]))/2
        assert area>=-0.00002,(a['id'],area)
        tris.append(Polygon([q,r,s]))
    shape=union_all(tris)
    assert shape.is_valid
    assert abs(sum(t.area for t in tris)-shape.area)<.02,(a['id'],'overlapping triangles')
    return shape
for key in ['buildings','areas','paths','piers','breakwaters','trees','roads','trafficLanes']:
    ids=[a['id']for a in d[key]];assert len(ids)==len(set(ids)),key
    for a in d[key]:
        pts=a.get('points',[a['point']]if 'point'in a else[])
        assert all(math.isfinite(v)for q in pts for v in q),(key,a['id'])
ground=surface(d['ground']);water=surface(d['water']);rail=surface(d['railFloor']);world=box(*d['worldBounds'])
assert ground.intersection(water).area<.01
assert world.symmetric_difference(ground.union(water).union(rail)).area<.03
assert ground.intersection(rail).area<.01 and water.intersection(rail).area<.01
assert rail.area>70000 and rail.bounds[1]==58 and rail.bounds[3]==1350
assert rail.intersection(box(982,-200,1231,48)).area==0
assert sum(surface(a).intersection(rail).area for a in d['areas']+d['legacyAreas'])<.02
for q in [(1080,300),(1090,600),(1120,950)]:assert rail.covers(Point(q))and not ground.covers(Point(q))
for track in d['rails']:
    assert abs(track['width']-1.435)<.0001
    assert LineString(track['points']).difference(rail.buffer(.002)).length<.002
crossing_mask=union_all([LineString(p['points']).buffer(p['width']/2+.34)for p in d['railCrossings']])
for guard in d['railGuards']:assert LineString(guard['points']).intersection(crossing_mask).length<.002
for q in [(0,0),(1042.46,-424.15),(1404.55,342.20),(951.6,-2036.52),(1062.85,-2219.95)]:
    assert ground.covers(Point(q))and not water.covers(Point(q)),('expected land',q)
for q in [(-164,27),(2040,-640),(2050,-571),(1890,0),(4000,-1500),(4000,1000)]:
    assert water.covers(Point(q))and not ground.covers(Point(q)),('expected water',q)
park_surfaces=[]
for a in d['areas']:
    shape=surface(a)
    if a['kind']=='park':park_surfaces.append(shape)
park=union_all(park_surfaces)
assert any(a['id']==-19511979 and a['name']=='Grant Park'for a in d['areas'])
for q in [(1290,300),(1480,400),(1300,195),(1415,200)]:assert park.covers(Point(q)),('missing Grant Park lawn baseline',q)
# Check the authored berth envelopes against independently mapped dock solids.
# This caught real bow/dock intersections even though every mesh triangle was valid.
dock_shapes=[(r['id'],LineString(r['points']).buffer(r['width']/2,cap_style=2,join_style=2))for r in d['piers']]
berth_count=0
for r in d['piers']:
    first,last=r['points'][0],r['points'][-1]
    if not(r['id']>100000000 and r['id']%3!=0 and r['id']!=1009745881 and -925<first[1]<-590 and 1925<first[0]<2080 and 8<abs(last[1]-first[1])<35 and abs(last[0]-first[0])<1):continue
    end=r['points'][1]if len(r['points'])==3 else last
    length=min(abs(end[1]-first[1])-3.2,10.5+r['id']%4*.65)
    if length<=6:continue
    x,z=first[0]+3.65,(first[1]+end[1])/2;hull=[]
    for side in [-1,1]:
        for j in (range(21)if side==1 else range(20,-1,-1)):
            t=j/20;width=length*.285*.5*max(.01,math.sin(t*math.pi))**.55*(.76+.24*t)
            hull.append((x+side*width,z+(t-.5)*length))
    shape=Polygon(hull)
    assert water.covers(shape),('boat extends beyond harbor water',r['id'])
    for dock_id,dock in dock_shapes:assert shape.intersection(dock).area<.0001,('boat intersects dock',r['id'],dock_id)
    berth_count+=1
assert berth_count==66
assert len(d['roads'])==2 and len(d['trafficLanes'])==6
source=json.loads((ROOT/'scripts/data/chicago-lakefront-osm-2026-09-08.json').read_text())
ways={e['id']:e for e in source['elements']if e['type']=='way'}
lane_lengths=[];maximum_grade=0
for road in d['roads']:
    chain=[ways[i]for i in road['sourceIDs']]
    assert all(a['nodes'][-1]==b['nodes'][0]for a,b in zip(chain,chain[1:])), 'disconnected mapped road'
    assert road['length']>10000
    pts=road['points'];assert abs(pts[0][2]-pts[-1][2])>9500
    line=LineString([(p[0],p[2])for p in pts])
    for lane in [v for v in d['trafficLanes']if v['id']//10==road['id']]:
        assert len(lane['points'])==len(pts) and lane['spawnFadeMetres']==550
        assert 15<lane['speedMetresPerSecond']<22
        total=0
        for p,q in zip(lane['points'],pts):
            assert p[1]==q[1], 'traffic must use the pavement grade'
            assert math.hypot(p[0]-q[0],p[2]-q[2])<3.552
        for a,b in zip(lane['points'],lane['points'][1:]):
            length=math.dist(a,b);horizontal=math.hypot(b[0]-a[0],b[2]-a[2]);total+=length
            assert 3<length<7,'gap, duplicate or inverted resample'
            maximum_grade=max(maximum_grade,abs(b[1]-a[1])/horizontal)
        lane_lengths.append(round(total,3))
        # All endpoint fade zones are outside the entire curated road corridor.
        assert min(lane['points'][0][2],lane['points'][-1][2])< -5000
        assert max(lane['points'][0][2],lane['points'][-1][2])>3000
assert maximum_grade<.065
suppressed={31064573,232905278,232905280,232905283,232906397,232914185,279951771,279951772,1282265474,232935981,1282265459,64627674,590824927,130147025,148560424}
assert not suppressed.intersection(b['id']for b in d['buildings'])
subprocess.run([sys.executable,str(ROOT/'scripts/prepare-lakefront-context.py')],check=True)
assert before==path.read_bytes(),'non-deterministic derivative'
report=dict(passed=True,mapSHA256=hashlib.sha256(before).hexdigest(),snapshot=d['timestamp'],counts={k:len(d[k])for k in ['buildings','areas','paths','trees','piers','breakwaters','roads','trafficLanes','rails','railCrossings','railGuards']},checks=['unique IDs and finite coordinates','positive nonoverlapping area triangles','land/water/rail void cover bounded world','known landmark land and harbor water classification','Grant Park multipolygon and sampled grass coverage','66 detailed DuSable hull envelopes within water and clear of all mapped docks','real railway void cut from ground and all old/new landscape','museum exclusion, mapped rail gauge/coverage and crossing guard gaps','source OSM directed-chain connectivity','all six lane indices and road surface grades match','lane separation, continuity and remote spawn limits','authored landmark exclusions','byte-identical offline regeneration'],laneLengthsMetres=lane_lengths,maximumRoadGrade=maximum_grade,limits=['Road elevations near the upper-deck river crossing and railway floor depth are interpreted; OSM supplies plan geometry, not surveyed grades.','Representative boats and facade details are authored; boat occupancy is not a live harbor inventory.'])
out=ROOT/'output/v6-review/lakefront-map-validation.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
