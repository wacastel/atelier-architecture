#!/usr/bin/env python3
"""Reproducible ODbL Navy Pier approach derivative; requires Shapely 2.1.2.
Never rewrites older Chicago derivatives; imagery is reference-only, not bundled.
"""
import hashlib,json,math,re
from pathlib import Path
from shapely import Polygon,Point,LineString,box,make_valid,union_all,constrained_delaunay_triangles,orient_polygons,set_precision
from shapely.ops import linemerge
ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'scripts/data/chicago-navy-pier-osm-2026-09-09.json'
DEST=ROOT/'Sources/ArchitectureEngine/Resources/NavyPier/NavyPierContext.json'
LAT,LON=41.878876,-87.635918
SOURCE=json.loads(RAW.read_text()); ELEMENTS=SOURCE['elements']
PARK_IDS={273203457,509654675,211039469,211039472}
PIER=box(2165,-1620,3105,-1340)
def project(q):return [round((q['lon']-LON)*111320*math.cos(math.radians(LAT)),3),round((LAT-q['lat'])*111320,3)]
def number(v,default=0):
 try:
  s=str(v);n=float(re.match(r'[-\d.]+',s).group());return n*.3048 if 'ft'in s or "'"in s else n
 except (ValueError,AttributeError):return default

def polygons(g):
 if g.is_empty:return []
 if g.geom_type=='Polygon':return [g]
 return [p for c in getattr(g,'geoms',[])for p in polygons(c)]
def lines(g):
 if g.is_empty:return []
 if g.geom_type=='LineString':return [g]
 return [p for c in getattr(g,'geoms',[])for p in lines(c)]
def clean(g):return set_precision(union_all(polygons(make_valid(g))),.01)
def shape(e):
 if e['type']=='way':
  pts=[project(q)for q in e.get('geometry',[])if q]
  return clean(Polygon(pts))if len(pts)>3 and pts[0]==pts[-1] else Polygon()
 if e['type']=='relation':
  groups={}
  for role in ['outer','inner']:
   pieces=[LineString([project(q)for q in m['geometry']if q])for m in e.get('members',[])if m.get('role')==role and len(m.get('geometry',[]))>1]
   rings=lines(linemerge(pieces))if pieces else[]
   groups[role]=union_all([Polygon(r.coords)for r in rings if r.is_ring])
  return clean(groups['outer'].difference(groups['inner']))
 return Polygon()
def mesh(g,ident,kind,name=''):
 points=[];lookup={};triangles=[];rings=[]
 for p in polygons(orient_polygons(clean(g),exterior_cw=False)):
  rings.append([list(q)for q in list(p.exterior.coords)[:-1]])
  rings.extend([[list(q)for q in list(r.coords)[:-1]]for r in p.interiors])
  for t in constrained_delaunay_triangles(p).geoms:
   q=list(t.exterior.coords)[:-1]
   if sum(q[i][0]*q[(i+1)%3][1]-q[(i+1)%3][0]*q[i][1]for i in range(3))<0:q.reverse()
   for a in q:
    if a not in lookup:lookup[a]=len(points);points.append(list(a))
    triangles.append(lookup[a])
 return dict(id=ident,kind=kind,name=name,points=points,triangles=triangles,rings=rings)
SHAPES={(e['type'],e['id']):shape(e)for e in ELEMENTS if e['type']in('way','relation')}
parks=[(e,SHAPES[e['type'],e['id']])for e in ELEMENTS if e['id']in PARK_IDS]
MASK=clean(union_all([g for e,g in parks]).difference(PIER))
prior_paths=[ROOT/f'Sources/ArchitectureEngine/Resources/{n}/{n}Context.json'for n in ['Chicago','Lakefront','MuseumCampus','NorthSide','HydePark']]
prior=[json.loads(p.read_text())for p in prior_paths]
old_buildings={b['id']for d in prior for b in d['buildings']}
old_shapes=[make_valid(Polygon(b.get('rings',[b['points']])[0]))for d in prior for b in d['buildings']if len(b['points'])>2]
old_paths={p['id']:p for d in prior for p in d['paths']}
legacy_pier_area_ids={a['id']for d in prior for a in d.get('areas',[])+d.get('legacyAreas',[])if a['points']and PIER.covers(Point(sum(p[0]for p in a['points'])/len(a['points']),sum(p[1]for p in a['points'])/len(a['points'])))}
map_buildings=[];new_building_ids=[];building_shapes=[];paths=[];retained=[];asphalt=[];walk=[];gardens=[];fountains=[];trees=[];furniture=[];landmarks=[]
for e in ELEMENTS:
 t=e.get('tags',{});ident=-e['id']if e['type']=='relation'else e['id']
 if e['type']=='node':
  q=project(e)
  if MASK.covers(Point(q)):
   if t.get('natural')=='tree':trees.append(dict(id=ident,point=q,height=round(min(15,max(4,number(t.get('height'),7+(ident%23)*.14))),2)))
   if t.get('amenity')in('bench','drinking_water')or t.get('highway')=='street_lamp':furniture.append(dict(id=ident,point=q,kind=t.get('amenity',t.get('highway'))))
  continue
 g=SHAPES[e['type'],e['id']]
 if e['id']in PARK_IDS or t.get('name')in ['Centennial Wheel','Aon Grand Ballroom','Family Pavillion','Chicago Shakespeare Theater','Festival Hall']:
  if not g.is_empty:landmarks.append(dict(id=ident,name=t.get('name',''),point=[round(g.centroid.x,3),round(g.centroid.y,3)],bounds=[round(v,3)for v in g.bounds]))
 if ('building'in t or 'building:part'in t)and not g.is_empty and t.get('building')not in('no','construction')and t.get('location')!='underground':
  h=number(t.get('height'));hs='height'if h else'levels'if t.get('building:levels')else'estimated'
  if not h:h=number(t.get('building:levels'),2)*3.5
  if ident==751729625:h=5.4;hs='photo-estimated low pavilion' # Official exterior shows one storey, no OSM height tag.
  if ident==1308482808:h=5.4864;hs='builder-documented 18 feet' # Foundation Mechanics: 72 x 36 x 18 ft domed habitat.
  m=mesh(g,ident,'building',t.get('name',''));m.update(height=round(h,3),heightSource=hs,material=t.get('building:material',''),color=t.get('building:colour',''),isPart='building:part'in t,hasHoles=any(p.interiors for p in polygons(g)))
  map_buildings.append(m)
  if ident not in old_buildings and not g.intersects(PIER) and g.area>12 and MASK.buffer(250).covers(g) and t.get('building')!='roof' and not any(o.intersects(g)and o.intersection(g).area>g.area*.25 for o in old_shapes):new_building_ids.append(ident)
  if g.intersects(MASK):building_shapes.append(g.intersection(MASK))
 if not g.is_empty and g.intersects(MASK):
  if t.get('leisure')=='garden':gardens.append((ident,clean(g.intersection(MASK))))
  if t.get('amenity')=='fountain':fountains.append(mesh(g.intersection(MASK),ident,'fountain',t.get('name','Polk Bros Fountain')))
 if e['type']=='way'and 'highway'in t:
  q=[project(v)for v in e.get('geometry',[])if v]
  if len(q)<2:continue
  line=LineString(q)
  if not line.intersects(MASK):continue
  # The mapped elevated flyover retains its original grade and span ownership.
  if t.get('bridge')or number(t.get('layer'))>0 or t.get('tunnel'):continue
  ped=t['highway']in('footway','path','pedestrian','cycleway','steps')
  width=number(t.get('width'),4 if ped else 6 if t['highway']=='service'else 9)
  clipped=line.intersection(MASK)
  for i,l in enumerate(lines(clipped)):
   if l.length<.1:continue
   p=dict(id=ident*100+i,sourceID=ident,points=[list(x)for x in l.coords],width=round(width,2),kind=t['highway'],name=t.get('name',''),bridge='')
   paths.append(p)
   stroke=l.buffer(width/2,cap_style='flat',join_style='mitre',mitre_limit=2)
   (walk if ped else asphalt).append(stroke)
 # Retain outside fragments of replaced legacy lines, so no route is truncated.
for ident,p in old_paths.items():
 line=LineString(p['points'])
 replace=MASK.union(PIER)
 if not line.intersects(replace)or p.get('bridge'):continue
 parts=[]
 for l in lines(line.difference(replace)):
  if l.length>.1:parts.append(dict(p,points=[list(q)for q in l.coords]))
 retained.append(dict(id=ident,parts=parts))
blocked=union_all(building_shapes+[Polygon(r)for f in fountains for r in f['rings']])
asphalt_shape=clean(union_all(asphalt).intersection(MASK).difference(blocked));walk_shape=clean(union_all(walk).intersection(MASK).difference(blocked).difference(asphalt_shape.buffer(.03)))
garden_shape=clean(union_all([g for _,g in gardens]).difference(asphalt_shape.buffer(.03)).difference(walk_shape.buffer(.03)).difference(blocked))
areas=[];claimed=Polygon()
# A 3 cm separation absorbs source/grid rounding at shared edges; the existing
# ground remains underneath. Never stack overlapping lawn triangles.
for e,g in sorted(parks,key=lambda item:item[0]["tags"].get("natural")!="beach"):
 cover=clean(g.intersection(MASK).difference(asphalt_shape.buffer(.03)).difference(walk_shape.buffer(.03)).difference(blocked).difference(garden_shape.buffer(.03)).difference(claimed.buffer(.03)))
 claimed=claimed.union(cover)
 areas.append(mesh(cover,e['id'],'sand'if e['tags'].get('natural')=='beach'else'park',e['tags'].get('name','')))
areas.append(mesh(garden_shape,-99001,'garden','Mapped approach gardens'))
# Mapped tree nodes only: preserve the actual open lawn compositions, no forest fill.
trees=[t for t in trees if not blocked.buffer(1).covers(Point(t['point']))and not asphalt_shape.buffer(.6).covers(Point(t['point']))and not walk_shape.buffer(.5).covers(Point(t['point']))]
result=dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=SOURCE['osm3s']['timestamp_osm_base'],origin=[LAT,LON],mapBounds=[41.8878,-87.6195,41.8982,-87.5978],authoredPierMask=mesh(PIER,0,'exclusion'),approachMask=mesh(MASK,0,'exclusion'),buildings=sorted(map_buildings,key=lambda b:b['id']),newBuildingIDs=sorted(new_building_ids),replacementAreaIDs=sorted(PARK_IDS|{i for i,g in gardens}|legacy_pier_area_ids),areas=areas,paths=paths,roadSurfaces=[mesh(asphalt_shape,-99002,'asphalt'),mesh(walk_shape,-99003,'paving')],retainedPaths=sorted(retained,key=lambda p:p['id']),trees=trees,furniture=furniture,fountains=fountains,landmarks=landmarks,sourceSHA256={RAW.name:hashlib.sha256(RAW.read_bytes()).hexdigest()},previousResourceSHA256={p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in prior_paths})
DEST.parent.mkdir(parents=True,exist_ok=True);DEST.write_text(json.dumps(result,separators=(',',':'))+'\n')
print(json.dumps(dict(buildings=len(map_buildings),newBuildings=len(new_building_ids),areas=len(areas),paths=len(paths),mappedTrees=len(trees),furniture=len(furniture),fountains=len(fountains),retainedLegacyPaths=len(retained),surfaceTriangles=sum(len(a['triangles'])//3 for a in areas+result['roadSurfaces']),sha256=hashlib.sha256(DEST.read_bytes()).hexdigest()),indent=2))
