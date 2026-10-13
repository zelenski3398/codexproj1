"""Offline local grading; preserve supplied terrain outside editable footprints.
Dependencies: numpy scipy matplotlib shapely triangle trimesh. No runtime dependency.
The original user-supplied GLB is retained in assets/malta/source/terrain_original.glb.
"""
from pathlib import Path
import json,os
os.environ.setdefault('MPLCONFIGDIR','/tmp/malta-mpl-cache')
import numpy as np
import triangle,trimesh
import matplotlib.tri as mtri
from matplotlib import colormaps
from shapely.geometry import Polygon,box
from shapely.ops import unary_union
from shapely import contains_xy,distance,points
ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'assets/malta'
SETTINGS=json.loads((ASSET/'grading/settings.json').read_text())

def smooth(t):
 t=np.clip(t,0,1)
 return t*t*t*(t*(t*6-15)+10)

def field_axes(record):
 angle=np.deg2rad(record['heading'])
 # Godot's Basis(UP,-heading): local +X and +Z in world XZ.
 return np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])

def local_xz(v,record):
 return (v-np.array(record['position'])[ [0,2] ])@field_axes(record)

def world_xz(v,record):
 return v@field_axes(record).T+np.array(record['position'])[[0,2]]

def footprint(record):
 length=record['length'];width=record.get('width',54);centre=length*.31
 end=SETTINGS['runway_end_clearance_metres'];margin=SETTINGS['base_ground_margin_metres']
 return unary_union([box(-width/2,-length/2,width/2,length/2),box(-38,-length/2-end,38,length/2+end),box(13,centre-115,109,centre+115),box(22,centre-115-margin,109+margin,centre+115+margin)])

class GroundSampler:
 def __init__(self,mesh):
  v=mesh.vertices;f=mesh.faces
  self.top_mask=(np.cross(v[f[:,1]]-v[f[:,0]],v[f[:,2]]-v[f[:,0]])[:,1]>1e-6)&(v[f,1].min(axis=1)>-29.9)
  self.top_indices=np.unique(f[self.top_mask])
  mapping=np.full(len(v),-1,dtype=int);mapping[self.top_indices]=np.arange(len(self.top_indices))
  faces=mapping[f[self.top_mask]][:,::-1]
  vertices=v[self.top_indices]
  self.triangulation=mtri.Triangulation(vertices[:,0],vertices[:,2],faces)
  self.interpolate=mtri.LinearTriInterpolator(self.triangulation,vertices[:,1])
  edges=np.sort(np.vstack([faces[:,[0,1]],faces[:,[1,2]],faces[:,[2,0]]]),axis=1)
  self.edges=np.unique(edges,axis=0)
  boundary_edges=np.unique(edges,axis=0,return_counts=True)
  boundary=boundary_edges[0][boundary_edges[1]==1]
  # Boundary ring is used only for protecting the existing coastline.
  from shapely.geometry import MultiLineString
  self.coast=MultiLineString(vertices[boundary][:,:,[0,2]].tolist())
 def heights(self,xz):
  return np.asarray(self.interpolate(xz[:,0],xz[:,1]).filled(np.nan))

def fit_fields(records,sampler):
 report=[]
 for record in records:
  old=record['position'][1];length=record['length']
  local=np.array([(x,z) for z in np.linspace(-length/2,length/2,81) for x in [-27,0,27]])
  heights=sampler.heights(world_xz(local,record))
  assert np.isfinite(heights).all()
  # Least-squares cut/fill plane instead of previous highest-sample platform.
  coefficient=np.polyfit(local[:,1],heights,1)
  slope=float(np.clip(-coefficient[0],-SETTINGS['maximum_grade'],SETTINGS['maximum_grade']))
  elevation=float(np.mean(heights+slope*local[:,1]))
  record['position'][1]=elevation;record['slope']=slope;record['width']=54.0
  report.append(dict(id=record['id'],previous_elevation=old,elevation=elevation,grade=slope,runway_sample_min=float(heights.min()),runway_sample_max=float(heights.max())))
 return report

def field_weights(xz,records,sampler):
 weights=[];planes=[]
 for record in records:
  local=local_xz(xz,record)
  d=distance(points(local),footprint(record))
  weight=1-smooth(d/SETTINGS['transition_metres'])
  weights.append(weight)
  planes.append(record['position'][1]-record['slope']*local[:,1])
 weight=np.array(weights)
 coast_distance=distance(points(xz),sampler.coast)
 weight*=smooth(coast_distance/SETTINGS['coast_guard_metres'])[None,:]
 return weight,np.array(planes)

def grade_values(xz,original,records,sampler):
 weights,planes=field_weights(xz,records,sampler)
 result=original.copy()
 for w,plane in zip(weights,planes): result=result*(1-w)+plane*w
 return result,weights.max(axis=0)

def extra_points(records,sampler):
 extra=[];segments=[]
 for record in records:
  core=footprint(record);outer=core.buffer(SETTINGS['transition_metres'])
  minx,minz,maxx,maxz=outer.bounds
  for spacing,shape in [(SETTINGS['transition_grid_metres'],outer),(SETTINGS['core_grid_metres'],core.buffer(8))]:
   xx,zz=np.meshgrid(np.arange(minx,maxx,spacing),np.arange(minz,maxz,spacing))
   local=np.column_stack([xx.ravel(),zz.ravel()]);local=local[contains_xy(shape,local[:,0],local[:,1])]
   extra.extend(world_xz(local,record).tolist())
  # Force exact planar footprint boundaries into the triangulation.
  coords=np.asarray(core.exterior.coords)[:-1]
  for a,b in zip(coords,np.roll(coords,-1,axis=0)):
   n=max(1,int(np.ceil(np.linalg.norm(b-a)/8)))
   line=world_xz(np.linspace(a,b,n+1),record)
   segments.extend(zip(line[:-1],line[1:]))
   extra.extend(line.tolist())
 return np.asarray(extra),segments

def regenerate(roads=None):
 scene=trimesh.load(ASSET/'source/terrain_original.glb',force='scene',process=False)
 main=scene.geometry['Malta']
 sampler=GroundSampler(main)
 data=json.loads((ASSET/'source/world_data_original.json').read_text())
 records=data['airfields']
 report=fit_fields(records,sampler)
 original_top=main.vertices[sampler.top_indices][:,[0,2]]
 extra,core_segments=extra_points(records,sampler)
 # No roads in the first independent terrain/base commit.
 if roads is not None:
  raise NotImplementedError('Road corridor refinement added in road-network commit')
 valid=np.isfinite(sampler.heights(extra));extra=extra[valid]
 allpoints=np.vstack([original_top,extra])
 keys={tuple(np.round(p,5)):i for i,p in enumerate(original_top)}
 unique=list(original_top)
 for p in extra:
  key=tuple(np.round(p,5))
  if key not in keys: keys[key]=len(unique);unique.append(p)
 segments=list(sampler.edges)
 # Dense 8 m samples include the footprint boundaries; retain original
 # triangle-edge constraints without adding crossing PSLG segments.
 result=triangle.triangulate({'vertices':np.asarray(unique),'segments':np.asarray(segments)},'pQ')
 xz=result['vertices'];h=sampler.heights(xz)
 h[:len(original_top)]=main.vertices[sampler.top_indices,1]
 assert np.isfinite(h).all(),'Triangulation escaped original land domain'
 graded,w=grade_values(xz,h,records,sampler)
 # Original vertex positions retained; only local Y values change.
 v=main.vertices.copy();v[sampler.top_indices,1]=graded[:len(original_top)]
 new_top=np.column_stack([xz[len(original_top):,0],graded[len(original_top):],xz[len(original_top):,1]])
 v=np.vstack([v,new_top])
 mapping=np.r_[sampler.top_indices,np.arange(len(main.vertices),len(v))]
 faces=np.vstack([main.faces[~sampler.top_mask],mapping[result['triangles'][:,::-1]]])
 mesh=trimesh.Trimesh(v,faces,process=False)
 colors=np.asarray(main.visual.vertex_colors).copy()
 newcolors=(colormaps['terrain'](np.clip((new_top[:,1]+5)/300,0,1))*255).astype('uint8')
 colors=np.vstack([colors,newcolors])
 changed_original=sampler.top_indices[w[:len(original_top)]>0]
 colors[changed_original]=(colormaps['terrain'](np.clip((v[changed_original,1]+5)/300,0,1))*255).astype('uint8')
 mesh.visual=trimesh.visual.ColorVisuals(mesh=mesh,vertex_colors=colors)
 scene.geometry['Malta']=mesh
 scene.export(ASSET/'terrain.glb')
 data['placement_note']='Approximate historical sites and runway layouts. Elevations fitted to original terrain by localized cut/fill grading, with smoothly blended base grounds; island scale/coastline preserved.'
 (ASSET/'world_data.json').write_text(json.dumps(data,indent=2)+'\n')
 untouched=w[:len(original_top)]==0
 assert np.array_equal(v[sampler.top_indices[untouched]],main.vertices[sampler.top_indices[untouched]])
 assert np.array_equal(v[:len(main.vertices),[0,2]],main.vertices[:,[0,2]])
 summary=dict(airfields=report,settings=SETTINGS,original_triangles=len(main.faces),graded_triangles=len(faces),added_vertices=len(new_top),changed_original_vertices=int((~untouched).sum()),max_cut_fill=float(np.max(abs(graded-h))),unmodified_original_vertices=int(untouched.sum()),coastline_preserved=True,geometry_outside_local_footprints_preserved=True)
 (ASSET/'grading/report.json').write_text(json.dumps(summary,indent=2)+'\n')
 print(json.dumps(summary,indent=2))

if __name__=='__main__': regenerate()
