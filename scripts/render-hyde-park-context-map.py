#!/usr/bin/env python3
"""Render an original OSM derivative review map; requires matplotlib and Shapely."""
import json,math
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection,LineCollection
from matplotlib.patches import Polygon as PatchPolygon
ROOT=Path(__file__).resolve().parents[1]
d=json.loads((ROOT/'Sources/ArchitectureEngine/Resources/HydePark/HydeParkContext.json').read_text())
prior=[json.loads((ROOT/p).read_text())for p in d['previousResourceSHA256']]
fig,axes=plt.subplots(1,3,figsize=(15,9),gridspec_kw={'width_ratios':[1.0,1.25,1.25]});fig.patch.set_facecolor('#f7f3e9')
for ax in axes:ax.set_facecolor('#e5e1d5');ax.set_aspect('equal');ax.tick_params(labelsize=8)
def surface(ax,s,color):
 points=s['points'];triangles=s['triangles']
 ax.add_collection(PolyCollection([[points[i]for i in triangles[k:k+3]]for k in range(0,len(triangles),3)],facecolors=color,edgecolors='none',rasterized=True))
for ax in axes:
 for old in prior[1:]:
  for key in ['water','legacyWater']:
   if key in old:surface(ax,old[key],'#79bac9')
 for key in ['water']:surface(ax,d[key],'#79bac9')
 for old in prior:
  for area in old['areas']:
   if area.get('kind')!='water' and max((p[1]for p in area['points']),default=0)>3500:surface(ax,area,'#b5c69a')
 for area in d['areas']:surface(ax,area,'#d7c5a1'if area['kind']=='sand'else'#b5c69a')
 surface(ax,{'points':[[6000,-11500],[26000,-11500],[26000,18000],[6000,18000]],'triangles':[0,1,2,0,2,3]},'#79bac9')
 bounds=ax is axes[0]
 buildings=[b for old in prior for b in old['buildings']]+d['buildings']
 polys=[]
 for b in buildings:
  if max((p[1]for p in b['points']),default=0)<3300:continue
  pts=b['points'];idx=b['triangles'];polys.extend([[pts[i]for i in idx[j:j+3]]for j in range(0,len(idx),3)])
 ax.add_collection(PolyCollection(polys,facecolors='#9b9188',edgecolors='none',rasterized=True))
 roadlines=[p['points']for p in d['paths']if p['kind']not in('footway','path','cycleway','pedestrian','steps')]
 ax.add_collection(LineCollection(roadlines,colors='#f9f6ef',linewidths=.6,rasterized=True))
 ax.add_collection(LineCollection([p['points']for p in d['piers']],colors='#77716a',linewidths=.55,rasterized=True))
 ax.add_collection(LineCollection([[(p[0],p[2])for p in r['points']]for r in d['roads']+prior[2]['roads']],colors='#6e7377',linewidths=1.7))
 ax.add_collection(LineCollection([p['points']for p in d['rails']],colors='#584e43',linewidths=.35,rasterized=True))
 boats=[]
 for b in d['boats']:
  x,z=b['point'];f=(math.sin(b['angle']),math.cos(b['angle']));n=(-f[1],f[0]);l=b['length'];w=l*.27
  boats.append([(x+f[0]*l*.5*u+n[0]*w*.5*v,z+f[1]*l*.5*u+n[1]*w*.5*v)for u,v in[(-1,-1),(1,-1),(1,1),(-1,1)]])
 ax.add_collection(PolyCollection(boats,facecolors='#fffdf5',edgecolors='#7f8c9b',linewidths=.12,rasterized=True))
ax=axes[0];ax.set_xlim(1750,5500);ax.set_ylim(10400,2700);ax.set_title('Continuous southern connection',fontsize=12,pad=12)
route=[(2450,3250),(2880,4480),(2910,4850),(3590,6500),(4020,7490),(5110,9060),(4880,9610),(4270,9720),(3580,9730),(3275,9935),(3309,9917)]
ax.plot(*zip(*route),color='#bf5932',linewidth=2,label='Connecting flight keyframes')
for x,z,label in [(1950,3069,'McCormick'),(2662,4773,'31st Harbor'),(3408,6621,'Oakwood'),(3822,7356,'Burnham Park'),(4925,9237,'Promontory'),(3309,9917,'Robie House')]:
 ax.scatter(x,z,color='#8a3520',s=12);ax.annotate(label,(x,z),xytext=(4,-6),textcoords='offset points',fontsize=8)
ax.set_xlabel('Metres east of Willis');ax.set_ylabel('Metres south of Willis')
axes[1].set_xlim(2350,2920);axes[1].set_ylim(5200,4350);axes[1].set_title('31st Street Harbor · 963 cleared berths',fontsize=12,pad=12)
axes[2].set_xlim(3200,3430);axes[2].set_ylim(10090,9780);axes[2].set_title('Woodlawn approach · authored lot reserved',fontsize=12,pad=12)
axes[2].add_patch(PatchPolygon([[3288,9904],[3339,9904],[3339,9928],[3288,9928]],facecolor='#c4613f',edgecolor='#8a3520',alpha=.75))
axes[2].annotate('Robie House',(3310,9915),xytext=(6,9),textcoords='offset points',fontsize=8)
fig.suptitle('Atelier · Hyde Park map and flight review',fontsize=19,x=.05,ha='left',y=.98)
fig.text(.05,.026,'Original review map from bundled OSM-derived geometry. © OpenStreetMap contributors / ODbL 1.0. Snapshot 2026-09-08.\nBoat arrangement and flight are authored; building footprints and dock positions are mapped. Not satellite imagery.',fontsize=9,color='#55514a')
fig.subplots_adjust(left=.05,right=.98,top=.91,bottom=.11,wspace=.25)
output=ROOT/'output/v10-review/hyde-park-map-review.png';fig.savefig(output,dpi=150,facecolor=fig.get_facecolor());print(output)
