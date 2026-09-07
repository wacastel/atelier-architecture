#!/usr/bin/env python3
"""Preprocess the included ODbL OpenStreetMap snapshot into metre-scale render data.
No third-party modules; preserves source way IDs, tagged height provenance, and geometry.
Fetch original: see docs/PARIS.md. Derived database remains ODbL 1.0.
"""
import json, math, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'scripts/data/paris-osm-2026-09-07.json'
DEST=ROOT/'Sources/ArchitectureEngine/Resources/Paris/ParisContext.json'
p=json.loads(SOURCE.read_text())

def project(q):
    east=(q['lon']-2.2944991)*111320*math.cos(math.radians(48.8582602))
    north=(q['lat']-48.8582602)*111320
    return [round(east*math.sin(math.radians(47))+north*math.cos(math.radians(47)),2),round(east*math.sin(math.radians(137))+north*math.cos(math.radians(137)),2)]
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def polygon(g):
    if len(g)>1 and g[0]==g[-1]:g=g[:-1]
    g=[q for i,q in enumerate(g) if i==0 or math.dist(q,g[i-1])>0.12]
    change=True
    while change and len(g)>3:
        change=False
        for i in range(len(g)):
            a,b,c=g[i-1],g[i],g[(i+1)%len(g)]
            if abs(cross(a,b,c))/max(math.dist(a,c),.01)<.20:
                g.pop(i);change=True;break
    if sum(g[i][0]*g[(i+1)%len(g)][1]-g[(i+1)%len(g)][0]*g[i][1] for i in range(len(g)))<0:g.reverse()
    return g

def triangulate(g):
    ids=list(range(len(g)));out=[]
    while len(ids)>3:
        found=False
        for i in range(len(ids)):
            ia,ib,ic=ids[i-1],ids[i],ids[(i+1)%len(ids)];a,b,c=g[ia],g[ib],g[ic]
            if cross(a,b,c)<1e-5:continue
            if any(cross(a,b,g[j])>=-1e-5 and cross(b,c,g[j])>=-1e-5 and cross(c,a,g[j])>=-1e-5 for j in ids if j not in (ia,ib,ic)):continue
            out.extend([ia,ib,ic]);ids.pop(i);found=True;break
        if not found:return []
    if len(ids)==3:out.extend(ids)
    return out

def num(v,default):
    try:return float(re.match(r'[\d.]+',str(v)).group())
    except:return default
buildings=[];areas=[];paths=[]
# Closed, hole-free relation outers include the two curved Palais de Chaillot wings.
# Courtyard relations remain in the source snapshot but are not filled as solid roofs.
relations=json.loads((ROOT/'scripts/data/paris-osm-relations-2026-09-07.json').read_text())
elements=list(p['elements'])
way_ids={e['id'] for e in elements}
for relation in relations['elements']:
    if any(m.get('role')=='inner' for m in relation['members']):continue
    for m in relation['members']:
        if m['type']!='way' or m.get('role')!='outer' or m['ref'] in way_ids:continue
        geom=m.get('geometry',[])
        if len(geom)<4 or geom[0]!=geom[-1]:continue
        elements.append(dict(id=m['ref'],type='way',tags=relation['tags'],geometry=geom,relation=relation['id']))
for e in elements:
    t=e.get('tags',{});g=[project(q) for q in e.get('geometry',[])];ident=e['id']
    if len(g)<3:continue
    cx=sum(v[0] for v in g)/len(g);cz=sum(v[1] for v in g)/len(g);dist=math.hypot(cx,cz)
    if 'building' in t:
        if dist>1075 or dist<76 or ident==5013364 or t.get('building') in ('roof','construction') or t.get('wall')=='no':continue
        if -320<cz<-127:continue # Published-width Seine corridor is represented by the river module.
        g=polygon(g);idx=triangulate(g)
        if not idx:continue
        area=abs(sum(g[i][0]*g[(i+1)%len(g)][1]-g[(i+1)%len(g)][0]*g[i][1] for i in range(len(g))))/2
        if area<12:continue
        height=num(t.get('height'),0)
        provenance='height' if height else 'levels' if t.get('building:levels') else 'estimated'
        if not height:height=num(t.get('building:levels'),0)*3.15+0.8
        if height<1:height=(3.8 if dist<170 or area<80 else 17+(ident%5)*2.3)
        height=max(2.5,min(height,65))
        buildings.append(dict(id=ident,points=g,triangles=idx,height=round(height,2),heightSource=provenance,relation=e.get('relation'),name=t.get('name',''),kind=t.get('building','yes'),material=t.get('building:material','')))
    elif t.get('natural')=='water' or t.get('landuse')=='grass' or t.get('leisure')=='park':
        if dist>1050:continue
        g=polygon(g);idx=triangulate(g)
        if idx:areas.append(dict(id=ident,points=g,triangles=idx,kind='water' if t.get('natural')=='water' else 'park' if t.get('leisure')=='park' else 'grass',name=t.get('name','')))
    elif 'highway' in t:
        if dist>670 or t.get('bridge') or num(t.get('layer'),0)!=0 or t['highway'] in ('elevator','steps','bus_stop'):continue
        if all(abs(q[0])<70 and abs(q[1])<70 for q in g):continue
        if t.get('area')=='yes':continue
        kind=t['highway']
        width=num(t.get('width'), {'footway':2.3,'path':2.4,'pedestrian':5,'cycleway':2.3,'service':4,'residential':8,'tertiary':12,'secondary':15,'primary':18}.get(kind,5))
        paths.append(dict(id=ident,points=g,width=min(width,25),kind=kind,name=t.get('name','')))
result=dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=p['osm3s']['timestamp_osm_base'],origin=[48.8582602,2.2944991],xBearing=47,zBearing=137,buildings=sorted(buildings,key=lambda x:x['id']),areas=areas,paths=paths)
DEST.parent.mkdir(parents=True,exist_ok=True)
DEST.write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False))
print(f'{len(buildings)} building footprints, {len(areas)} green/water areas, {len(paths)} paths/roads -> {DEST} ({DEST.stat().st_size:,} bytes)')
