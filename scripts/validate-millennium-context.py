#!/usr/bin/env python3
"""Check mapped landmark placement, triangle coverage and reproducible OSM conversion."""
import hashlib, json, math, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'Sources/ArchitectureEngine/Resources/Millennium/MillenniumContext.json'
before=path.read_bytes();data=json.loads(before)
assert data['origin']==[41.878876,-87.635918]
for key in ['areas','paths','trees','landmarks']:
    items=data[key];ids=[a['id'] for a in items];assert len(ids)==len(set(ids)),key
    for a in items:
        points=a.get('points',[a['point']] if 'point' in a else [])
        assert all(math.isfinite(v) for q in points for v in q)
for a in data['areas']:
    g=a['points'];tr=a['triangles'];assert len(tr)==(len(g)-2)*3
    polygon=sum(g[i][0]*g[(i+1)%len(g)][1]-g[(i+1)%len(g)][0]*g[i][1] for i in range(len(g)))/2
    total=0
    for i in range(0,len(tr),3):
        q,r,s=[g[k] for k in tr[i:i+3]]
        area=((r[0]-q[0])*(s[1]-q[1])-(r[1]-q[1])*(s[0]-q[0]))/2
        assert area>=-1e-7,(a['id'],area)
        total+=area
    assert abs(total-polygon)<.05,(a['id'],total,polygon)
landmarks={a['id']:a for a in data['landmarks']}
assert {137060274,126978545,126945440,126945441,231253695,90707301,524270341,25026666,126977943,126977944,234847961,234847963}==set(landmarks)
bean=landmarks[137060274]['points']
assert abs((min(q[0] for q in bean)+max(q[0] for q in bean))/2-1042.46)<.01
assert abs((min(q[1] for q in bean)+max(q[1] for q in bean))/2+424.15)<.02
assert len(data['trees'])==626
subprocess.run(['python3',str(ROOT/'scripts/prepare-millennium-context.py')],check=True)
assert before==path.read_bytes()
print('PASS: unique IDs; finite projected coordinates; positive and complete triangle coverage; landmark identities; Bean geolocation; mapped tree count; byte-identical regeneration.')
print('Derived SHA256:',hashlib.sha256(before).hexdigest())
