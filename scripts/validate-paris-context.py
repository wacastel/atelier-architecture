#!/usr/bin/env python3
"""Validate geographic data provenance, polygon coverage, and rebuild determinism."""
import hashlib,json,math,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1]
path=root/'Sources/ArchitectureEngine/Resources/Paris/ParisContext.json'
raw=path.read_bytes();data=json.loads(raw)
assert data['attribution']=='© OpenStreetMap contributors'
assert data['license']=='ODbL 1.0'
assert data['origin']==[48.8582602,2.2944991]
assert len(data['buildings'])==2760
assert len(data['areas'])==234
assert len(data['paths'])==1179
ids=set();provenance={}
for b in data['buildings']:
    assert b['id'] not in ids;ids.add(b['id'])
    assert 2.5<=b['height']<=65
    provenance[b['heightSource']]=provenance.get(b['heightSource'],0)+1
    p=b['points'];idx=b['triangles']
    assert len(idx)==3*(len(p)-2)
    assert all(math.isfinite(v) for point in p for v in point)
    area=sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p)))/2
    triangles=0
    for i in range(0,len(idx),3):
        a,c,d=(p[j] for j in idx[i:i+3])
        ta=((c[0]-a[0])*(d[1]-a[1])-(c[1]-a[1])*(d[0]-a[0]))/2
        assert ta>0,(b['id'],ta)
        triangles+=ta
    assert abs(area-triangles)<.01,(b['id'],area,triangles)
chaillot=[b for b in data['buildings'] if b['name']=='Palais de Chaillot']
assert len(chaillot)==2 and all(b['relation']==6826569 and b['height']==30 for b in chaillot)
ponds={a['id']:a for a in data['areas'] if a['kind']=='water'}
assert 14850854 in ponds and 14850860 in ponds
centers=[sum(p[0] for p in ponds[i]['points'])/len(ponds[i]['points']) for i in [14850854,14850860]]
assert centers[0]>80 and centers[1]<-70 # The two official gardens flank the tower.
subprocess.run([sys.executable,str(root/'scripts/prepare-paris-context.py')],check=True,stdout=subprocess.DEVNULL)
assert path.read_bytes()==raw,'Regeneration changed the map database'
print('PASS: 2,760 unique, finite footprints; positive triangle areas cover polygons; real Chaillot relation; two garden ponds; deterministic regeneration.')
print('Height provenance:',provenance)
print('Derived database SHA-256:',hashlib.sha256(raw).hexdigest())
