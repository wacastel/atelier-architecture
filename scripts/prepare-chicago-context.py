#!/usr/bin/env python3
"""Derive offline Chicago geometry from the bundled ODbL OpenStreetMap snapshot.
No external packages. Coordinates are metres east / south of Willis Tower.
"""
import json, math, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'scripts/data/chicago-osm-2026-09-07.json'
DEST=ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json'
LAT,LON=41.878876,-87.635918
p=json.loads(SOURCE.read_text())
def project(q):return [round((q['lon']-LON)*111320*math.cos(math.radians(LAT)),2),round((LAT-q['lat'])*111320,2)]
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def area(g):return sum(g[i][0]*g[(i+1)%len(g)][1]-g[(i+1)%len(g)][0]*g[i][1] for i in range(len(g)))/2

def polygon(g,tolerance=.15):
    if len(g)>1 and g[0]==g[-1]:g=g[:-1]
    g=[q for i,q in enumerate(g) if i==0 or math.dist(q,g[i-1])>.10]
    change=True
    while change and len(g)>3:
        change=False
        for i in range(len(g)):
            a,b,c=g[i-1],g[i],g[(i+1)%len(g)]
            if abs(cross(a,b,c))/max(math.dist(a,c),.01)<tolerance:g.pop(i);change=True;break
    if area(g)<0:g.reverse()
    return g

def triangulate(g):
    ids=list(range(len(g)));out=[]
    while len(ids)>3:
        found=False
        for i in range(len(ids)):
            ia,ib,ic=ids[i-1],ids[i],ids[(i+1)%len(ids)];a,b,c=g[ia],g[ib],g[ic]
            if cross(a,b,c)<1e-6:continue
            if any(cross(a,b,g[j])>=-1e-6 and cross(b,c,g[j])>=-1e-6 and cross(c,a,g[j])>=-1e-6 for j in ids if j not in (ia,ib,ic)):continue
            out.extend([ia,ib,ic]);ids.pop(i);found=True;break
        if not found:return []
    if len(ids)==3:out.extend(ids)
    return out

def inside(q,g):
    flag=False;j=len(g)-1
    for i,a in enumerate(g):
        b=g[j]
        if (a[1]>q[1])!=(b[1]>q[1]) and q[0]<(b[0]-a[0])*(q[1]-a[1])/(b[1]-a[1])+a[0]:flag=not flag
        j=i
    return flag

def clip(g,lo=-2400,hi=2400):
    for dim,bound,sign in [(0,lo,1),(0,hi,-1),(1,lo,1),(1,hi,-1)]:
        out=[]
        if not g:break
        a=g[-1]
        for b in g:
            ia=(a[dim]-bound)*sign>=0;ib=(b[dim]-bound)*sign>=0
            if ia!=ib:
                t=(bound-a[dim])/(b[dim]-a[dim]);out.append([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t])
            if ib:out.append(b)
            a=b
        g=out
    return polygon([[round(v,2)for v in q]for q in g])
def num(v,default=0):
    try:
        s=str(v);n=float(re.match(r'[\d.]+',s).group());return n*.3048 if 'ft'in s or "'"in s else n
    except:return default

def join_members(e):
    chains=[list(m['geometry'])for m in e.get('members',[])if m.get('role')=='outer'and m.get('geometry')]
    out=[]
    while chains:
        g=chains.pop(0);changed=True
        while g[0]!=g[-1] and changed:
            changed=False
            for i,h in enumerate(chains):
                if g[-1]==h[0]:g+=h[1:]
                elif g[-1]==h[-1]:g+=list(reversed(h))[1:]
                elif g[0]==h[-1]:g=h[:-1]+g
                elif g[0]==h[0]:g=list(reversed(h))[:-1]+g
                else:continue
                chains.pop(i);changed=True;break
        if g[0]==g[-1]:out.append(g)
    return out

els=[e for e in p['elements']if e['type']=='way'];ids={e['id']for e in els}
for e in p['elements']:
    if e['type']!='relation' or 'building'not in e.get('tags',{}):continue
    if e['tags'].get('location')=='underground':continue
    for j,g in enumerate(join_members(e)):
        # Courtyard provenance is retained; the current simple-polygon renderer fills inner holes.
        els.append(dict(id=-e['id']*10-j,type='way',tags=e['tags'],geometry=g,relation=e['id'],hasHoles=any(m.get('role')=='inner'for m in e['members'])))
parts=[]
for e in els:
    t=e.get('tags',{});g=e.get('geometry',[])
    if 'building:part'not in t or len(g)<4 or not (t.get('height')or t.get('building:levels')):continue
    if t.get('building:part')in ('roof','column','ramp','elevator'):continue
    points=polygon([project(q)for q in g]);c=[sum(v[i]for v in points)/len(points)for i in [0,1]]
    if -51<c[0]<61 and -41<c[1]<80:continue
    if math.hypot(*c)>810:continue
    parts.append((e,points,c))

buildings=[];areas=[];paths=[];bridges=[];rivers=[]
for e in p['elements']:
    if e['type']=='relation' and e['id']in [3485552,13462125,13730103]:
        for j,g in enumerate(join_members(e)):
            points=clip([project(q)for q in g]);idx=triangulate(points)
            if idx:rivers.append(dict(id=e['id']*10+j,points=points,triangles=idx,kind='river',name='Chicago River'))
# A documented distant Lake Michigan plane meets the approximate lakefront, outside close model.
for e in els:
    t=e.get('tags',{});raw=e.get('geometry',[])
    if len(raw)<2:continue
    g=[project(q)for q in raw];c=[sum(v[i]for v in g)/len(g)for i in [0,1]];dist=math.hypot(*c);ident=e['id']
    if 'building'in t or any(v[0]['id']==ident for v in parts):
        if ('building:part'in t and not any(v[0]['id']==ident for v in parts))or dist>1680:continue
        if t.get('location')=='underground'or num(t.get('layer'))<0 or t.get('building')in ('roof','construction')or t.get('wall')=='no':continue
        if ident==380868216 or (-51<c[0]<61 and -41<c[1]<80):continue
        if 'Bridgehouse'in t.get('name',''):continue # authored bridgehouse modules replace footprints
        g=polygon(g);idx=triangulate(g)
        if not idx or area(g)<15:continue
        h=num(t.get('height'));source='height' if h else 'levels' if t.get('building:levels')else 'estimated'
        if not h:h=num(t.get('building:levels'))*3.75
        if h<1:h=4.5 if area(g)<110 else 15+(ident%9)*3.8
        kind=t.get('building:part',t.get('building','yes'))
        contained=[v for v in parts if inside(v[2],g)]if 'building'in t and 'building:part'not in t else []
        if contained:h=4.0;source='base-under-mapped-parts'
        name=t.get('name','')
        # The tall 311 component includes its 32m crown; authored crown starts at260.9m.
        if ident==686318733:h=260.9;name='311 South Wacker Drive';source='height-minus-authored-crown'
        if ident in [686318734,147350208]:h=11.25;name='311 South Wacker podium'
        buildings.append(dict(id=ident,points=g,triangles=idx,height=round(min(h,410),2),heightSource=source,name=name,kind=kind,material=t.get('building:material',''),color=t.get('building:colour',''),isPart='building:part'in t,relation=e.get('relation'),hasHoles=e.get('hasHoles',False)))
    elif t.get('natural')=='water' or t.get('leisure')=='park' or t.get('landuse')=='grass':
        if dist>1650 or len(g)<4 or raw[0]!=raw[-1]:continue
        g=polygon(g);idx=triangulate(g)
        if idx:areas.append(dict(id=ident,points=g,triangles=idx,kind='water'if t.get('natural')=='water'else'park'if t.get('leisure')=='park'else'grass',name=t.get('name','')))
    elif 'highway'in t:
        if dist>1020 or t.get('area')=='yes' or t['highway']in ('elevator','steps','bus_stop','corridor','construction'):continue
        if t.get('indoor')=='yes'or num(t.get('layer'))<0 or t.get('tunnel'):continue
        if all(-51<q[0]<61 and -41<q[1]<80 for q in g):continue
        kind=t['highway'];ped=kind in ['footway','path','pedestrian','cycleway']
        width=num(t.get('width'),2.2 if ped else num(t.get('lanes'),2)*3.3+1.5)
        if kind in ['motorway','motorway_link']:width=max(width,12)
        obj=dict(id=ident,points=g,width=round(min(width,32),2),kind=kind,name=t.get('name',''),bridge=t.get('bridge',''))
        if t.get('bridge')=='movable' and not ped:bridges.append(obj)
        elif not t.get('bridge') or (not ped and -600<c[0]<0):paths.append(obj)
# Exact ground complement of the mapped river polygons using trapezoidal decomposition.
polys=[r['points']for r in rivers];zs=sorted(set([-2400.,2400.]+[q[1]for g in polys for q in g]));ground=[]
for z0,z1 in zip(zs,zs[1:]):
    if z1-z0<1e-4:continue
    zm=(z0+z1)/2;edges=[]
    for g in polys:
        for a,b in zip(g,g[1:]+g[:1]):
            if min(a[1],b[1])<=zm<max(a[1],b[1]):
                def at(z):return a[0]+(b[0]-a[0])*(z-a[1])/(b[1]-a[1])
                edges.append((at(zm),at(z0),at(z1)))
    edges.sort();bounds=[(-2400.,-2400.)]+[(e[1],e[2])for e in edges]+[(2400.,2400.)]
    for i in range(0,len(bounds)-1,2):
        a,b=bounds[i],bounds[i+1]
        ground.append([[round(a[0],2),z0],[round(b[0],2),z0],[round(b[1],2),z1],[round(a[1],2),z1]])
result=dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=p['osm3s']['timestamp_osm_base'],origin=[LAT,LON],xBearing=90,zBearing=180,buildings=sorted(buildings,key=lambda x:x['id']),areas=areas,paths=paths,bridges=bridges,rivers=rivers,ground=ground)
DEST.parent.mkdir(parents=True,exist_ok=True);DEST.write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False))
from collections import Counter
print(len(buildings),'buildings',len(areas),'areas',len(paths),'paths',len(bridges),'movable bridges',len(rivers),'river polygons',len(ground),'ground strips')
print(Counter(b['heightSource']for b in buildings));print(DEST.stat().st_size,'bytes')
