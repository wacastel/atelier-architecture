#!/usr/bin/env python3
"""Validate the offline Chicago database, its mesh coverage, and reproducibility."""
import json,math,hashlib,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
f=ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json'
d=json.loads(f.read_text())
for key in ['buildings','areas','rivers']:
    ids=[b['id']for b in d[key]];assert len(ids)==len(set(ids)),key
    for b in d[key]:
        g=b['points'];idx=b['triangles'];assert all(math.isfinite(v)for q in g for v in q)
        assert len(idx)%3==0
        area=sum(g[i][0]*g[(i+1)%len(g)][1]-g[(i+1)%len(g)][0]*g[i][1]for i in range(len(g)))/2
        triArea=0
        for i in range(0,len(idx),3):
            a,b0,c=[g[x]for x in idx[i:i+3]]
            a0=((b0[0]-a[0])*(c[1]-a[1])-(b0[1]-a[1])*(c[0]-a[0]))/2
            assert a0>=-1e-6,(key,b['id'],a0);triArea+=a0
        assert abs(triArea-area)<max(.02,area*.000001),(key,b['id'],triArea,area)
for b in d['buildings']:
    assert 0<b['height']<443
    assert b['id']!=380868216 # detailed Willis replaces this whole-block footprint
    center=[sum(q[i]for q in b['points'])/len(b['points'])for i in [0,1]]
    assert not (-51<center[0]<61 and -41<center[1]<80),b['id']
assert {230973582,746755321}<={b['id']for b in d['bridges']}
assert any(r['id']//10==13462125 for r in d['rivers'])
assert {203442440,686318733}<={b['id']for b in d['buildings']}
# The scanline decomposition leaves the entire mapped river open to the water level.
def area(g):return abs(sum(g[i][0]*g[(i+1)%len(g)][1]-g[(i+1)%len(g)][0]*g[i][1]for i in range(len(g)))/2)
land=sum(area(g)for g in d['ground']);water=sum(area(r['points'])for r in d['rivers'])
assert abs(land+water-4800**2)<4800**2*1e-6,(land,water)
before=f.read_bytes();subprocess.run(['python3',str(ROOT/'scripts/prepare-chicago-context.py')],check=True)
assert before==f.read_bytes()
print('PASS: unique IDs, finite coordinates, positive triangulation coverage, plausible heights, Willis exclusion, landmark/bridge/river IDs, river-ground area partition, deterministic regeneration.')
print('Derived database SHA256:',hashlib.sha256(before).hexdigest())
