"""Original reference-inspired St Elmo geometry, in the existing Valletta grid.
No footprint survey/verified wartime emplacement locations are claimed.
"""
import numpy as np
from shapely.geometry import Polygon,box,LineString

def build(center,land,heights,h,world,prism,cube,emit,STONE,TRIM,ROOF,DARK):
 import trimesh
 x,z=center
 outline=Polygon(np.array([[-110,-80],[-50,-110],[48,-103],[104,-55],[119,12],[72,92],[-10,108],[-92,61],[-122,2]])+center).intersection(land.buffer(-10))
 values=heights(np.array(outline.exterior.coords));finite=values[np.isfinite(values)]
 deck=float(finite.max()+3);foundation=float(finite.min()-2)
 prism(outline,foundation,deck,STONE)
 gate=box(x-8,z-140,x+8,z-60)
 curtain=outline.difference(outline.buffer(-7,join_style=2)).difference(gate)
 prism(curtain,deck,deck+5,STONE)
 prism(outline.difference(outline.buffer(-1.3,join_style=2)).difference(gate),deck+5,deck+6.1,TRIM)
 inner=Polygon(np.array([[-58,-45],[0,-73],[59,-43],[78,8],[43,62],[-43,62],[-77,8]])*[.72,.8]+center+[-30,-8]).intersection(outline.buffer(-3,join_style=2))
 inner_gate=box(x-38,z-90,x-22,z-40)
 walls=inner.difference(inner.buffer(-7,join_style=2)).difference(inner_gate)
 prism(walls,deck,deck+9,STONE)
 prism(inner.difference(inner.buffer(-1.1,join_style=2)).difference(inner_gate),deck+9,deck+10.1,TRIM)
 # Courtyard buildings: U-shaped barracks, arcaded facades and pitched accents.
 for ox,oz,sx,sz in [(-26,-3,9,38),(26,-3,9,38),(0,22,52,10)]:
  px=x-30+ox;pz=z-8+oz
  footprint=box(px-sx/2,pz-sz/2,px+sx/2,pz+sz/2).intersection(outline.buffer(-3))
  if oz==22:
   # Real open ground-floor arcade beneath the upper storey, with rear rooms.
   prism(footprint.intersection(box(px-sx,pz-1.5,px+sx,pz+sz)),deck,deck+8,STONE)
   prism(footprint,deck+3.8,deck+8,STONE)
   for offset in range(-25,26,7):cube(px+offset,pz-3.2,.8,3.5,deck,3.8,STONE)
  else:prism(footprint,deck,deck+8,STONE)
  prism(footprint.buffer(.2).intersection(outline),deck+8,deck+8.65,ROOF,False)
  if oz==22:
   for offset in range(-21,22,7):
    cube(x-30+offset,pz-5.08,2,.08,deck+5,1.6,DARK,False)
  else:
   for offset in range(-14,15,7):cube(px+(4.54 if ox<0 else -4.54),pz+offset,.08,2,deck+4,2,DARK,False)
 # Solid ramps and step blocks: visual and collision share actual triangles.
 def ramp(a,b,width,low,high):
  a=np.array(a)+center;b=np.array(b)+center;n=np.array([-(b-a)[1],(b-a)[0]]);n=n/np.linalg.norm(n)*width/2
  v=[[*(a-n),low],[*(a+n),low],[*(b+n),high],[*(b-n),high]]
  v=np.array(v)[:,[0,2,1]];bottom=v.copy();bottom[:,1]=min(low,high)-1
  mesh=trimesh.Trimesh(np.vstack([bottom,v]),[[4,5,6],[4,6,7],[0,2,1],[0,3,2],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]],process=False);mesh.fix_normals();emit(mesh,TRIM)
 approach=float(h([x,z-150]))
 ramp([0,-150],[0,-100],12,approach+.12,deck+.08)
 pads=[[-92,-35],[20,-72],[-35,76]]
 for ox,oz in pads:
  assert outline.covers(box(x+ox-8,z+oz-8,x+ox+8,z+oz+8)), "Gun platform must stay fully on supported fort deck"
  cube(x+ox,z+oz,16,16,deck,3,TRIM)
  ramp([ox,oz-26],[ox,oz-8],6,deck+.08,deck+3)
 # Raised drill court, reached by real solid steps and a parallel ramp.
 cube(x-30,z-8,44,45,deck,1.2,TRIM)
 for i in range(8):cube(x-44,z-35.4+i*.55,4,.55,deck,.15*(i+1),TRIM)
 ramp([-36,-47],[-36,-31],4,deck,deck+1.2)
 return dict(deck=deck,center_world=world(center).tolist(),outline_grid=list(map(list,outline.exterior.coords)),
  gun_positions=[[*world(center+np.array(p)),deck+3] for p in pads],
  spawn_positions=[[*world(center+[-30,-8]),deck+1.2]]+[[*world(center+np.array(p)+[5,0]),deck+3] for p in pads],
  note='Reference-inspired approximate fort; gun positions authored for gameplay, not verified historical emplacements.')
