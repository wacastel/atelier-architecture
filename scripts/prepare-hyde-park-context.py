#!/usr/bin/env python3
"""Offline, reproducible Hyde Park derivative; requires Shapely 2.1.2.
Preserves prior Chicago/Lakefront source files. No imagery is bundled.
"""
import json,math,re,hashlib,struct
from pathlib import Path
from collections import defaultdict
from shapely import Polygon,LineString,Point,box,make_valid,union_all,constrained_delaunay_triangles,set_precision,orient_polygons
from shapely.ops import linemerge,polygonize
from shapely.prepared import prep
ROOT=Path(__file__).resolve().parents[1]
LAT,LON=41.878876,-87.635918
RAW=ROOT/'scripts/data/chicago-hyde-park-osm-2026-09-08.json'
source=json.loads(RAW.read_text())
old=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Chicago/ChicagoContext.json').read_text())
lf=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/Lakefront/LakefrontContext.json').read_text())
WORLD=box(-4000,-11500,6000,10800)
TRANSPORT_WORLD=WORLD
DEST=ROOT/'Sources/ArchitectureEngine/Resources/HydePark/HydeParkContext.json'
PEDESTRIAN_KINDS={'footway','path','pedestrian','cycleway','steps'}
GROUND_ASPHALT=0.12
GROUND_WALK=0.19
SURFACE_GRID=0.01
SURFACE_MITRE_LIMIT=2.0
LOCAL_GRADE_IDS={1166004921,1166004940,1166004942,1166004944,1344476701,1344476703}
UNDERPASS_REFERENCE='https://www.chicagoparkdistrict.com/parks-facilities/57th-street-underpass-mural-artwork'
def project(q):return [round((q['lon']-LON)*111320*math.cos(math.radians(LAT)),3),round((LAT-q['lat'])*111320,3)]
def number(v,default=0):
    try:
        s=str(v);n=float(re.match(r'[-\d.]+',s).group());return n*.3048 if 'ft'in s or "'"in s else n
    except (ValueError,AttributeError):return default
def polygons(g):
    if g.is_empty:return []
    if g.geom_type=='Polygon':return [g]
    return [p for sub in getattr(g,'geoms',[])for p in polygons(sub)]
def clean(g):return set_precision(union_all(polygons(make_valid(g).intersection(WORLD))),.001)
def way_shape(e):
    g=e.get('geometry',[])
    if len(g)<4 or g[0]!=g[-1] or any(q is None for q in g):return Polygon()
    return clean(Polygon([project(q)for q in g]))
def relation_rings(e,role):
    lines=[]
    for m in e.get('members',[]):
        if m.get('role')!=role:continue
        chunk=[]
        for q in m.get('geometry',[])+[None]:
            if q is None:
                if len(chunk)>1:lines.append(LineString(chunk))
                chunk=[]
            else:chunk.append(project(q))
    if not lines:return []
    merged=linemerge(lines)
    return [list(g.coords)for g in ([merged]if merged.geom_type=='LineString'else merged.geoms)]
def relation_shape(e):
    outer=[Polygon(g)for g in relation_rings(e,'outer')if len(g)>3 and g[0]==g[-1]]
    inner=[Polygon(g)for g in relation_rings(e,'inner')if len(g)>3 and g[0]==g[-1]]
    return clean(union_all([make_valid(p)for p in outer]).difference(union_all([make_valid(p)for p in inner])))
def mesh(shape,ident,kind,name=''):
    points=[];lookup={};triangles=[];rings=[]
    for p in polygons(orient_polygons(shape,exterior_cw=False)):
        rings.append([[round(x,3),round(z,3)]for x,z in p.exterior.coords[:-1]])
        rings += [[[round(x,3),round(z,3)]for x,z in ring.coords[:-1]]for ring in p.interiors]
        for triangle in constrained_delaunay_triangles(p).geoms:
            coords=[(round(x,3),round(z,3))for x,z in list(triangle.exterior.coords)[:-1]]
            signed=sum(coords[i][0]*coords[(i+1)%3][1]-coords[(i+1)%3][0]*coords[i][1]for i in range(3))
            if abs(signed)<1e-8:continue
            if signed<0:coords.reverse()
            for q in coords:
                key=(round(q[0],3),round(q[1],3))
                if key not in lookup:lookup[key]=len(points);points.append(list(key))
                triangles.append(lookup[key])
    return dict(id=ident,points=points,triangles=triangles,rings=rings,kind=kind,name=name)

def surface_shape(s):
    g=Polygon()
    for ring in s['rings']:g=g.symmetric_difference(Polygon(ring))
    return make_valid(g)
def lines(g):
    if g.is_empty:return []
    if g.geom_type=='LineString':return [g]
    return [v for c in getattr(g,'geoms',[])for v in lines(c)]

def sidewalk_policy(tags,side):
    """Do not invent a parallel sidewalk where OSM maps one separately."""
    if tags['highway'] in PEDESTRIAN_KINDS or tags['highway'] in {'motorway','trunk','motorway_link','trunk_link','service','track'} or tags.get('motorroad')=='yes':
        return 'none'
    value=tags.get('sidewalk:'+side,tags.get('sidewalk:both',tags.get('sidewalk','')))
    if value=='separate':return 'mapped'
    if value in {'no','none'}:return 'none'
    if value in {'left','right'}:return 'generate' if value==side else 'none'
    return 'generate'

def transport_clean(g):
    # Centimetre precision exceeds the float32 coordinate ULP at the south end
    # of this world and removes subpixel overlay slivers before triangulation.
    return set_precision(union_all(polygons(make_valid(g).intersection(TRANSPORT_WORLD))),SURFACE_GRID)

def transport_stroke(points,width,single_side=False):
    return LineString(points).buffer(width if single_side else width/2,
        cap_style='flat',join_style='mitre',mitre_limit=SURFACE_MITRE_LIMIT,
        single_sided=single_side)

def ground_road_runs(road):
    chunks=[];chunk=[]
    for point in road['points']:
        if abs(point[1])<1:chunk.append((point[0],point[2]))
        else:
            if len(chunk)>1:chunks.append(chunk)
            chunk=[]
    if len(chunk)>1:chunks.append(chunk)
    return chunks

def f32(value):return struct.unpack('f',struct.pack('f',value))[0]

def transport_mesh(shape,ident,kind):
    result=mesh(shape,ident,kind,'Joined Hyde Park '+kind)
    triangles=[];omitted=0;omitted_area=0
    for i in range(0,len(result['triangles']),3):
        indices=result['triangles'][i:i+3]
        a,b,c=[[f32(v)for v in result['points'][j]]for j in indices]
        cross=f32(f32(f32(b[0]-a[0])*f32(c[1]-a[1]))-f32(f32(b[1]-a[1])*f32(c[0]-a[0])))
        if cross<=1e-6:
            omitted+=1
            aa,bb,cc=[result['points'][j]for j in indices]
            omitted_area+=abs((bb[0]-aa[0])*(cc[1]-aa[1])-(bb[1]-aa[1])*(cc[0]-aa[0]))/2
        else:triangles+=indices
    result['triangles']=triangles
    return result,omitted,omitted_area
elements={(e['type'],e['id']):e for e in source['elements']}
shape_cache={}
def shape(e):
    key=(e['type'],e['id'])
    if key not in shape_cache:shape_cache[key]=relation_shape(e)if e['type']=='relation'else way_shape(e)
    return shape_cache[key]

# The house model owns its complete terraces, entry, planting and lot.
AUTHORED=box(3288,9904,3339,9928)
prior_paths=[ROOT/f'Sources/ArchitectureEngine/Resources/{n}/{n}Context.json'for n in ['Chicago','Lakefront','MuseumCampus','NorthSide']]
prior=[json.loads(p.read_text())for p in prior_paths];mc=prior[2];ns=prior[3]
old_ids={b['id']for d in prior for b in d['buildings']}
old_path_ids={p['id']for d in prior for p in d['paths']+d.get('bridges',[])}
old_pier_ids={p['id']for d in prior for p in d.get('piers',[])}
old_wall_ids={p['id']for d in prior for p in d.get('breakwaters',[])}
old_tree_ids={p['id']for d in prior for p in d.get('trees',[])}
# One dated coastline, clipped to the new southern strip, never repaving old city.
shore_path=ROOT/'scripts/data/chicago-hyde-park-shoreline-2026-09-08.json'
shore=json.loads(shore_path.read_text());lake=next(e for e in shore['elements']if e['id']==1205149)
coast=max(relation_rings(lake,'outer'),key=lambda q:LineString(q).length)
if coast[0][1]>coast[-1][1]:coast.reverse()
water_shape=clean(Polygon(coast+[(6000,coast[-1][1]),(6000,coast[0][1])]))
# Preserve old lake polygons where they already exist, including harbor islands.
retained_water=union_all([surface_shape(lf['water']),surface_shape(mc['water']),surface_shape(ns['water'])])
water_shape=water_shape.difference(box(-4000,-11500,6000,7800)).union(retained_water)
named=[];inland=[]
for e in source['elements']:
 t=e.get('tags',{})
 if e['type']not in('way','relation')or not(t.get('natural')=='water' or 'water'in t):continue
 g=shape(e)
 if g.is_empty:continue
 ident=-e['id']if e['type']=='relation'else e['id']
 if t.get('water')=='harbour':
  named.append(mesh(g,ident,'water',t.get('name','')))
  # These true harbor polygons are already part of Lake Michigan. No top-level overlay.
 elif g.area>20 and not water_shape.buffer(1).intersects(g) and g.centroid.y>7800:
  inland.append(mesh(g,ident,'water',t.get('name','')))
land=WORLD.difference(water_shape).difference(union_all([surface_shape(w)for w in inland]))
strip=box(-2400,7800,6000,10800)
ground=mesh(land.intersection(strip),0,'ground');water=mesh(water_shape.intersection(strip),0,'water')
# Continue each already directed Lake Shore Drive road at its exact prior node.
raw_prev=json.loads((ROOT/'scripts/data/chicago-museum-campus-roads-2026-09-08.json').read_text())
main={e['id']:e for e in raw_prev['elements']+source['elements']if e['type']=='way'and 'Lake Shore Drive'in e.get('tags',{}).get('name','')and e['tags'].get('highway')in('motorway','trunk')}
starts=defaultdict(list);ends=defaultdict(list)
for e in main.values():starts[e['nodes'][0]].append(e);ends[e['nodes'][-1]].append(e)
roads=[];traffic=[];road_ids={i for d in prior for r in d.get('roads',[])for i in r['sourceIDs']}
for road in mc['roads']:
 chain=[main[i]for i in road['sourceIDs']];south_start=road['points'][0][2]>road['points'][-1][2]
 extension=[];edge=chain[0]if south_start else chain[-1];seen=set(road_ids)
 while True:
  choices=(ends[edge['nodes'][0]]if south_start else starts[edge['nodes'][-1]])
  choices=[e for e in choices if e['id']not in seen]
  if not choices:break
  assert len(choices)==1,'Ambiguous southward Lake Shore Drive continuation'
  edge=choices[0];seen.add(edge['id']);extension.append(edge)
 if south_start:extension.reverse()
 coords=[]
 for e in extension:
  q=[project(v)for v in e['geometry']]
  if coords:assert coords[-1]==q[0]
  coords+=q if not coords else q[1:]
 join=road['points'][0]if south_start else road['points'][-1]
 assert coords and coords[-1 if south_start else 0]==[join[0],join[2]]
 line=LineString(coords);steps=math.ceil(line.length/5)
 pts=[[round((q:=line.interpolate(line.length*i/steps)).x,3),.12,round(q.y,3)]for i in range(steps+1)]
 assert max(p[2]for p in pts)>10600
 roads.append(dict(id=road['id'],points=pts,width=road['width'],sourceIDs=[e['id']for e in extension],length=round(line.length,3)))
 road_ids.update(e['id']for e in extension)
 for lane in [l for l in ns['trafficLanes']if l['id']//10==road['id']]:
  offset=(lane['id']%10-1)*3.55;shifted=[]
  for i,p in enumerate(pts):
   a=pts[max(0,i-1)];b=pts[min(len(pts)-1,i+1)];dx=b[0]-a[0];dz=b[2]-a[2];distance=math.hypot(dx,dz)
   shifted.append([round(p[0]-dz/distance*offset,3),p[1],round(p[2]+dx/distance*offset,3)])
  shifted[-1 if south_start else 0]=lane['points'][0 if south_start else -1]
  traffic.append(dict(lane,points=shifted[:-1]+lane['points']if south_start else lane['points']+shifted[1:]))

buildings=[];landmarks=[];paths=[];piers=[];walls=[];trees=[];rails=[];area_candidates=[];wood=[];hard=[];building_shapes=[]
# Parent relation member ways must not become a second shell over courtyards.
relation_members={m['ref']for e in source['elements']if e['type']=='relation'and any(k in e.get('tags',{})for k in('building','building:part'))for m in e.get('members',[])if m.get('type')=='way'}
for e in source['elements']:
 t=e.get('tags',{});ident=-e['id']if e['type']=='relation'else e['id']
 if e['type']=='node':
  if t.get('natural')=='tree'and ident not in old_tree_ids:
   q=project(e)
   if land.covers(Point(q))and not AUTHORED.buffer(1).covers(Point(q)):trees.append(dict(id=ident,point=q,height=round(min(16,max(4,number(t.get('height'),7.2+(ident%31)*.12))),2)))
  continue
 if e['type']not in('way','relation'):continue
 g=shape(e)
 if any(k in t for k in('building','building:part')) and not g.is_empty:
  if ident not in old_ids and ident not in relation_members and ident!=125667497 and not AUTHORED.intersects(g):
   if t.get('location')!='underground'and number(t.get('layer'))>=0 and t.get('building')not in('roof','construction')and t.get('building:part')not in('roof','column','ramp','elevator'):
    h=number(t.get('height'));hs='height'if h else'levels'if t.get('building:levels')else'estimated'
    if not h:h=number(t.get('building:levels'))*3.5
    if h<1:
     if t.get('building')in('garage','garages','shed','outbuilding'):h=3.0
     elif t.get('building')in('house','detached','semidetached_house','terrace'):h=8.5
     elif t.get('building')in('school','university','public','church'):h=15
     else:h=4.5 if g.area<110 else 11.5+(ident%4)*3
    if ident==125502842:h=5.4;hs='reference-interpreted-field-house'
    if ident==150456352:h=20.5;hs='levels-with-reference-roofline'
    m=mesh(g,ident,'building',t.get('name',''));m.update(height=round(min(h,350),2),heightSource=hs,material=t.get('building:material',''),buildingKind=t.get('building:part',t.get('building','yes')),isPart='building:part'in t)
    buildings.append(m);building_shapes.append(g)
  if t.get('name') and g.centroid.y>3900:
   m=mesh(g,ident,'landmark',t['name']);m.update(tags=t,center=[round(g.centroid.x,3),round(g.centroid.y,3)],bounds=[round(v,3)for v in g.bounds]);landmarks.append(m)
 if not g.is_empty:
  kind='park'if t.get('leisure')=='park'else'garden'if t.get('leisure')=='garden'else'sand'if t.get('natural')in('sand','beach')else'pitch'if t.get('leisure')=='pitch'else'grass'if t.get('landuse')in('grass','forest','meadow','recreation_ground')or t.get('natural')in('wood','scrub','grassland')or t.get('landcover')=='grass'else None
  if kind:area_candidates.append((ident,kind,t.get('name',''),g))
  if t.get('natural')in('wood','scrub')or t.get('landuse')=='forest':wood.append((ident,g))
  if t.get('amenity')=='parking'and t.get('parking')!='underground' or t.get('surface')in('asphalt','concrete','paving_stones','rubber')or t.get('leisure')in('pitch','track'):hard.append(g)
 if e['type']!='way':continue
 raw=e.get('geometry',[])
 if len(raw)<2 or any(q is None for q in raw):continue
 points=[project(q)for q in raw];line=LineString(points)
 if t.get('man_made')in('pier','quay','breakwater'):
  k=t['man_made'];dest=piers if k=='pier'else walls
  if ident not in(old_pier_ids if k=='pier'else old_wall_ids):dest.append(dict(id=ident,points=points,width=number(t.get('width'),2.1 if k=='pier' else 3.5),kind=k,name=t.get('name',''),bridge=''))
 if t.get('railway')in('rail','light_rail')and number(t.get('layer'))>=0 and not t.get('tunnel'):
  # Older lakefront rail is authored north of this new corridor.
  for j,l in enumerate(lines(line.intersection(box(-2400,4000,6000,10800)))):
   if l.length>2:rails.append(dict(id=ident*10+j,points=[[round(x,3),round(z,3)]for x,z in l.coords],width=1.435,kind='rail',name=t.get('name',''),bridge=t.get('bridge','')))
 if 'highway'in t and ident not in old_path_ids and ident not in road_ids:
  k=t['highway'];ped=k in PEDESTRIAN_KINDS
  if t.get('indoor')=='yes'or number(t.get('layer'))<0 or t.get('tunnel')or k in('elevator','corridor','bus_stop','construction','proposed')or t.get('area')=='yes':continue
  width=round(min(28,number(t.get('width'),2.5 if ped else max(1,number(t.get('lanes'),2))*3.35+1)),2)
  width_source='osm_width'if number(t.get('width'))>0 else'osm_lanes'if not ped and number(t.get('lanes'))>0 else'estimated_pedestrian'if ped else'estimated_two_lanes'
  elevated=t.get('bridge')not in(None,'no') and ident not in LOCAL_GRADE_IDS
  elevation=7.0+max(0,number(t.get('layer'),1)-1)*4 if elevated else GROUND_WALK if ped else GROUND_ASPHALT
  grade_source='57th_street_surface_grade_override'if ident in LOCAL_GRADE_IDS else'osm_relative_layer_estimate'if elevated else'flat_world_surface_datum'
  source_tags={key:value for key,value in t.items()if key in {'highway','width','lanes','bridge','layer','tunnel','footway','foot','bicycle','motorroad'}or key.startswith('sidewalk')}
  for j,l in enumerate(lines(line.intersection(WORLD).difference(AUTHORED.buffer(.2)))):
   if l.length>.2:paths.append(dict(id=ident if j==0 else-ident*100-j,sourceID=ident,points=[[round(x,3),round(z,3)]for x,z in l.coords],width=width,widthSource=width_source,kind=k,name=t.get('name',''),bridge=t.get('bridge',''),sourceLayer=number(t.get('layer')),gradeSource=grade_source,elevation=elevation,sidewalkLeft=sidewalk_policy(t,'left'),sidewalkRight=sidewalk_policy(t,'right'),sourceTags=source_tags))

# Bake joined ground transport surfaces. The original centerlines remain for
# provenance, markings and traffic; they are not duplicate renderable strips.
# The official Park District reference describes two pedestrian underpasses at
# 57th Street. It does not publish elevations. In this existing flat world only
# the six short bridge-tagged surface spans are held at their approach grade;
# their source tags remain intact. Subsurface excavations are explicitly omitted.
print('Preparing joined transport surfaces',flush=True)
ground_paths=[p for p in paths if p['elevation']<1]
road_shapes=[transport_stroke(p['points'],p['width'])for p in ground_paths if p['kind']not in PEDESTRIAN_KINDS]
road_shapes += [transport_stroke([(q[0],q[2])for q in road['points']],road['width'])for road in roads]
# Retain the existing sampled highway tails beyond WORLD without extending the
# terrain or any generic path. Markings/traffic must not outlive their asphalt.
drive_bounds=union_all([LineString([(q[0],q[2])for q in road['points']])for road in roads]).bounds
TRANSPORT_WORLD=WORLD.union(box(*drive_bounds).buffer(max(road['width']for road in roads)/2+1,join_style='mitre'))
ped_shapes=[transport_stroke(p['points'],p['width'])for p in ground_paths if p['kind']in PEDESTRIAN_KINDS]
generated_sidewalks=[]
for p in ground_paths:
 if p['kind']in PEDESTRIAN_KINDS:continue
 # X points east and Z points south: positive Shapely-side is OSM right.
 for side,sign in [('left',-1),('right',1)]:
  if p['sidewalk'+side.title()]!='generate':continue
  outer=transport_stroke(p['points'],sign*(p['width']/2+2.5),True)
  inner=transport_stroke(p['points'],sign*(p['width']/2),True)
  generated_sidewalks.append(outer.difference(inner))
asphalt=transport_clean(union_all(road_shapes))
explicit_pedestrian=transport_clean(union_all(ped_shapes))
sidewalk=transport_clean(union_all(generated_sidewalks))
new_bounds=box(*union_all([asphalt,explicit_pedestrian,sidewalk]).bounds).buffer(30)
prior_carriageways=[];prior_pedestrian=[]
for previous in prior:
 for p in previous['paths']+previous.get('bridges',[]):
  if p.get('bridge')not in(None,'','no')or len(p['points'])<2:continue
  line=LineString(p['points'])
  if not line.intersects(new_bounds):continue
  dest=prior_pedestrian if p.get('kind')in PEDESTRIAN_KINDS else prior_carriageways
  dest.append(transport_stroke(p['points'],p['width']))
 for road in previous.get('roads',[]):
  for line in ground_road_runs(road):
   if LineString(line).intersects(new_bounds):prior_carriageways.append(transport_stroke(line,road['width']))
retained_asphalt=transport_clean(union_all(prior_carriageways))
retained_pedestrian=transport_clean(union_all(prior_pedestrian))
lot_cut=AUTHORED.buffer(.2)
all_asphalt=transport_clean(asphalt.union(retained_asphalt))
asphalt=transport_clean(asphalt.difference(retained_asphalt).difference(lot_cut))
pavement=transport_clean(explicit_pedestrian.difference(all_asphalt).difference(retained_pedestrian).difference(lot_cut))
sidewalk=transport_clean(sidewalk.difference(all_asphalt).difference(explicit_pedestrian).difference(retained_pedestrian).difference(lot_cut))
# Quantize the common difference boundaries one last time, then subtract again
# on that grid so material regions are disjoint after coordinate rounding.
pavement=transport_clean(pavement.difference(asphalt))
sidewalk=transport_clean(sidewalk.difference(asphalt).difference(pavement))
road_surfaces=[];sliver_count=0;sliver_area=0
networks={'asphalt':asphalt,'pavement':pavement,'sidewalk':sidewalk}
minx,minz,maxx,maxz=union_all(list(networks.values())).bounds
# All materials use a common noded planar arrangement within each bounded tile.
# A snapped T-junction vertex must split both neighboring boundaries, otherwise
# separately triangulated long edges can overlap even after polygon subtraction.
for x in range(math.floor(minx/512)*512,math.ceil(maxx/512)*512,512):
 for z in range(math.floor(minz/512)*512,math.ceil(maxz/512)*512,512):
  tile=box(x,z,x+512,z+512)
  pieces={kind:transport_clean(network.intersection(tile))for kind,network in networks.items()}
  active={kind:geometry for kind,geometry in pieces.items()if not geometry.is_empty}
  if not active:continue
  boundaries=union_all([geometry.boundary for geometry in active.values()],grid_size=SURFACE_GRID)
  prepared={kind:prep(geometry)for kind,geometry in active.items()}
  cells={kind:[]for kind in active}
  for face in polygonize(boundaries):
   sample=face.representative_point()
   for kind in ['asphalt','pavement','sidewalk']:
    if kind in prepared and prepared[kind].covers(sample):
     cells[kind].append(face);break
  for kind,faces in cells.items():
   if not faces:continue
   # No independent precision snapping after shared boundaries are established.
   surface,omitted,area=transport_mesh(union_all(faces),9200000000+len(road_surfaces),kind)
   sliver_count+=omitted;sliver_area+=area
   if surface['triangles']:road_surfaces.append(dict(surface=surface,elevation=GROUND_ASPHALT if kind=='asphalt'else GROUND_WALK))
road_surface_policy=dict(version=1,coordinatePrecisionMetres=SURFACE_GRID,bufferCap='flat',bufferJoin='mitre',mitreLimit=SURFACE_MITRE_LIMIT,tileSizeMetres=512,asphaltElevation=GROUND_ASPHALT,walkElevation=GROUND_WALK,generatedSidewalkWidthMetres=2.5,localGradeOverrideWayIDs=sorted(LOCAL_GRADE_IDS),gradeReferenceURL=UNDERPASS_REFERENCE,gradeInterpretation='OSM layer is relative ordering, not metres. Six short surface spans at 57th Street use their adjoining flat-world grade; genuine elevated paths elsewhere retain the previous estimate.',omittedUndergroundScope='The official reference confirms two pedestrian underpasses between the museum and 57th Street Beach. This fix does not excavate terrain or add surveyed tunnel profiles; below-road portions remain omitted/occluded by the continuous carriageway.',omittedTunnelOrNegativeLayerWayIDs=sorted(e['id']for e in source['elements']if e['type']=='way'and'highway'in e.get('tags',{})and(e['tags'].get('tunnel')or number(e['tags'].get('layer'))<0)),surfacePrecedence='Existing carriageways, new asphalt, explicit pedestrian pavement, generated sidewalks. Regions are subtracted before triangulation. Existing resources are unchanged.',discardedFloat32SliverTriangles=sliver_count,discardedSliverAreaSquareMetres=sliver_area)
road_surface_policy['surfaceTopology']='All material boundaries are noded together on the precision grid per tile, polygonized into shared faces and assigned in precedence order before triangulation. No separate boundary snapping follows planar face construction.'
print('Joined transport complete',len(road_surfaces),'tiles;',sliver_count,'Float32 slivers omitted;',sliver_area,'square metres',flush=True)
# Restore only new coverage of large pre-existing park polygons. Flat lawn never
# rises over new paths, buildings, pitches or rail ballast in the southern band.
print('Preparing landcover',len(buildings),len(paths),flush=True)
retained_areas=union_all([surface_shape(a)if 'rings'in a else Polygon(a['points'])for d in prior for a in d['areas'] if a['kind']!='water' and max((q[1]for q in a['points']),default=-99999)>3200]).intersection(box(-2400,3200,6000,10800))
building_mask=union_all(building_shapes).buffer(.3)
route_mask=union_all([union_all([asphalt,pavement,sidewalk]).buffer(.4)]+[LineString(p['points']).buffer(2.5)for p in rails])
clearance=union_all([AUTHORED.buffer(.4),building_mask,route_mask,*hard])
areas=[];emitted=Polygon()
for ident,kind,name,g in sorted(area_candidates,key=lambda a:({'garden':0,'sand':1,'pitch':2,'grass':3,'park':4}[a[1]],a[3].area)):
 clipped=g.intersection(land,grid_size=.001).difference(AUTHORED,grid_size=.001).difference(retained_areas,grid_size=.001).difference(emitted,grid_size=.001)
 if kind not in('sand','pitch'):clipped=clipped.difference(clearance,grid_size=.001)
 if clipped.area>3:
  areas.append(mesh(clipped,ident,kind,name));emitted=emitted.union(clipped,grid_size=.001)
print('Landcover complete',len(areas),flush=True)
# Mapped woodland gets a modest deterministic canopy sample. Positions are
# explicitly authored samples, not purported OSM individual tree measurements.
woodland=union_all([g for _,g in wood]).intersection(land).difference(clearance.buffer(3))
# Mature park canopy at Promontory is evident in satellite/reference aerials;
# apply only within actual mapped park grass, keeping the open central lawn.
prom=shape(elements[('relation',15772175)])
prom_border=prom.difference(prom.buffer(-32)).intersection(land).difference(clearance.buffer(3))
canopy=prep(woodland.union(prom_border));mapped_tree_clear=prep(union_all([Point(t['point']).buffer(5)for t in trees]))
landcover=[]
for x in range(600,5200,18):
 for z in range(4000,10700,18):
  seed=(x*73856093)^(z*19349663);q=Point(x+(seed%100)/12-4,z+((seed//100)%100)/12-4)
  if canopy.contains(q)and not mapped_tree_clear.contains(q):
   landcover.append(dict(id=-(9000000000+len(landcover)),point=[round(q.x,3),round(q.y,3)],height=round(6.0+(seed%47)*.12,2)))
# Add the previously unmodeled southern limestone shore, excluding mapped
# quay segments already rendered. The path remains the dated OSM lake outline.
coast_line=LineString(coast).intersection(box(-2400,7800,6000,10800))
existing_wall_mask=union_all([LineString(p['points']).buffer(4)for d in prior for p in d.get('breakwaters',[])]+[LineString(p['points']).buffer(4)for p in walls])
for i,line in enumerate(lines(coast_line.difference(existing_wall_mask))):
 if line.length>2:walls.append(dict(id=-(9120000000+i),points=[[round(x,3),round(z,3)]for x,z in line.coords],width=2.7,kind='quay',name='Mapped Lake Michigan shoreline',bridge=''))
# Pack modeled boats into real 31st Street Harbor finger docks. Every hull
# footprint clears water margins, docks and all previous accepted vessels.
harbor=shape(elements[('relation',17779015)])
all_piers=[p for d in prior for p in d.get('piers',[])]+piers
harbor_piers=[p for p in all_piers if harbor.buffer(2).intersects(LineString(p['points']))]
dockmask=union_all([LineString(p['points']).buffer(p['width']/2+.45)for p in harbor_piers])
occupied=[];boats=[]
spine=union_all([LineString(v["points"])for v in harbor_piers if v["name"]])
for p in sorted(harbor_piers,key=lambda q:q['id']):
 for i in range(1,len(p['points'])):
  line=LineString(p['points'][i-1:i+1]);length=line.length
  if length<7 or length>33:continue
  a=line.interpolate(.1);b=line.interpolate(length-.1);dx=b.x-a.x;dz=b.y-a.y;distance=math.hypot(dx,dz)
  dx/=distance;dz/=distance;n=(-dz,dx)
  for side in(-1,1):
   boat_length=min(18,max(8.2,length*.78));width=boat_length*.27
   # Move away from the intersecting main spine. At a shared branch node,
   # choose the midpoint with greater clearance from the dock network.
   options=[line.interpolate(length*.35),line.interpolate(length*.65)]
   c=max(options,key=lambda q:q.distance(spine))
   # Named main spines are not berths; finger legs end at a spine endpoint.
   x=c.x+n[0]*side*(p['width']/2+width*.5+1.05);z=c.y+n[1]*side*(p['width']/2+width*.5+1.05)
   footprint=Polygon([(x+dx*boat_length*.53*u+n[0]*width*.56*v,z+dz*boat_length*.53*u+n[1]*width*.56*v)for u,v in[(-1,-1),(1,-1),(1,1),(-1,1)]])
   if not harbor.buffer(-1).covers(footprint)or dockmask.intersects(footprint)or any(g.intersects(footprint)for g in occupied):continue
   occupied.append(footprint);boats.append(dict(id=p['id']*10000+i*2+(side==1),point=[round(x,3),round(z,3)],length=round(boat_length,2),angle=round(math.atan2(dx,dz),6),sailboat=p['id']%4!=0,detailed=abs(x-2670)<140 and abs(z-4720)<230))
result=dict(attribution='© OpenStreetMap contributors',license='ODbL 1.0',licenseURL='https://www.openstreetmap.org/copyright',timestamp=source['osm3s']['timestamp_osm_base'],origin=[LAT,LON],mapBounds=[41.782,-87.632,41.85,-87.573],worldBounds=[-4000,-11500,6000,10800],ground=ground,water=water,inlandWaters=inland,namedHarbors=named,authoredMask=mesh(AUTHORED,0,'exclusion'),replacementBuildingIDs=[125667497],buildings=buildings,landmarks=landmarks,areas=areas,paths=paths,roadSurfaces=road_surfaces,roadSurfacePolicy=road_surface_policy,piers=piers,breakwaters=walls,trees=trees,landcoverTrees=landcover,rails=rails,roads=roads,trafficLanes=traffic,boats=boats,sourceSHA256={RAW.name:hashlib.sha256(RAW.read_bytes()).hexdigest(),shore_path.name:hashlib.sha256(shore_path.read_bytes()).hexdigest()},previousResourceSHA256={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in prior_paths})
DEST.parent.mkdir(parents=True,exist_ok=True);DEST.write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
print(json.dumps({k:len(result[k])for k in ['buildings','landmarks','areas','paths','piers','breakwaters','trees','landcoverTrees','rails','roads','trafficLanes','boats']},indent=2));print('Resource bytes',DEST.stat().st_size)
