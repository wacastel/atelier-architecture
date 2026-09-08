#!/usr/bin/env python3
"""Offline park geometry derived from the separately bundled ODbL OSM extract."""
import json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'scripts/data/millennium-osm-2026-09-08.json'
DEST=ROOT/'Sources/ArchitectureEngine/Resources/Millennium/MillenniumContext.json'
LAT,LON=41.878876,-87.635918
def project(q): return [round((q['lon']-LON)*111320*math.cos(math.radians(LAT)),3),round((LAT-q['lat'])*111320,3)]
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def area(g):return sum(a[0]*g[(i+1)%len(g)][1]-g[(i+1)%len(g)][0]*a[1] for i,a in enumerate(g))/2
def clean(g):
    if len(g)>1 and g[0]==g[-1]:g=g[:-1]
    g=[q for i,q in enumerate(g) if i==0 or math.dist(q,g[i-1])>.03]
    changed=True
    while changed and len(g)>3:
        changed=False
        for i in range(len(g)):
            if abs(cross(g[i-1],g[i],g[(i+1)%len(g)]))<.002:g.pop(i);changed=True;break
    if area(g)<0:g.reverse()
    return g
def triangulate(g):
    ids=list(range(len(g)));out=[]
    while len(ids)>3:
        for i in range(len(ids)):
            ia,ib,ic=ids[i-1],ids[i],ids[(i+1)%len(ids)];a,b,c=g[ia],g[ib],g[ic]
            if cross(a,b,c)<=1e-8:continue
            if any(cross(a,b,g[j])>=-1e-8 and cross(b,c,g[j])>=-1e-8 and cross(c,a,g[j])>=-1e-8 for j in ids if j not in (ia,ib,ic)):continue
            out.extend([ia,ib,ic]);ids.pop(i);break
        else:raise ValueError('Cannot triangulate polygon')
    return out+ids
def in_bounds(q):return 969<q[0]<1256 and -606<q[1]<-227
data=json.loads(SOURCE.read_text());areas=[];paths=[];trees=[];landmarks=[]
for e in data['elements']:
    t=e.get('tags',{});g=[project(q) for q in e.get('geometry',[])]
    if t.get('location')=='underground' or t.get('tunnel')=='yes' or t.get('indoor') or t.get('layer','0').startswith('-'):continue
    if e['type']=='node' and t.get('natural')=='tree':
        q=project(e)
        if in_bounds(q):trees.append({'id':e['id'],'point':q})
    if len(g)<2:continue
    center=[sum(q[i] for q in g)/len(g) for i in [0,1]]
    if e['id'] in [137060274,126978545,126945440,126945441,231253695,90707301,524270341,25026666,126977943,126977944,234847961,234847963]:
        landmarks.append({'id':e['id'],'name':t.get('name',''),'points':g})
    if not in_bounds(center):continue
    kind=''
    if t.get('landuse') in ['grass','meadow'] or t.get('leisure') in ['garden','park']:kind='planting'
    if t.get('barrier')=='hedge' and t.get('area')=='yes':kind='hedge'
    if t.get('natural')=='water':kind='water'
    if t.get('area')=='yes' and t.get('highway')=='pedestrian':kind='paving'
    if t.get('leisure')=='ice_rink':kind='paving'
    if t.get('surface')=='wood' and kind:kind='boardwalk'
    if kind and len(g)>3 and g[0]==g[-1]:
        g=clean(g)
        if len(g)<3:continue
        tr=triangulate(g)
        assert abs(sum(cross(g[tr[i]],g[tr[i+1]],g[tr[i+2]])/2 for i in range(0,len(tr),3))-area(g))<.05
        areas.append({'id':e['id'],'name':t.get('name',''),'kind':kind,'points':g,'triangles':tr})
    elif t.get('highway') in ['footway','pedestrian','path','steps'] and t.get('bridge') not in ['yes','boardwalk']:
        if t.get('access')=='private':continue
        paths.append({'id':e['id'],'name':t.get('name',''),'kind':t['highway'],'points':g,'width':float(t.get('width','3.2').split()[0]) if t.get('width','3.2').split()[0].replace('.','',1).isdigit() else 3.2})
result={'timestamp':data['osm3s']['timestamp_osm_base'],'origin':[LAT,LON],'areas':areas,'paths':paths,'trees':trees,'landmarks':landmarks}
DEST.parent.mkdir(parents=True,exist_ok=True)
DEST.write_text(json.dumps(result,separators=(',',':'))+'\n')
print(f'{len(areas)} mapped areas, {len(paths)} paths, {len(trees)} trees, {len(landmarks)} landmarks; {DEST.stat().st_size:,} bytes')
