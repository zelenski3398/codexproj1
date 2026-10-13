"""Editable historical-map interpretation; no external modern road network."""
import json
import numpy as np
from scipy.interpolate import RBFInterpolator,CubicSpline
from pyproj import Transformer
from shapely.geometry import LineString,Point,box
from shapely.ops import nearest_points
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'assets/malta'

def trace_network():
 trace=json.loads((ASSET/'roads/reference_trace.json').read_text())
 data=json.loads((ASSET/'world_data.json').read_text())
 projection=Transformer.from_crs(4326,32633,always_xy=True)
 origin=projection.transform(*data['origin_lon_lat'])
 fields={f['id']:f for f in data['airfields']}
 pixels=[];targets=[]
 for anchor in trace['anchors']:
  pixels.append(anchor['pixel'])
  if 'airfield' in anchor:
   f=fields[anchor['airfield']];targets.append([f['position'][0],f['position'][2]])
  else:
   x,n=projection.transform(*anchor['lon_lat']);targets.append([x-origin[0],-(n-origin[1])])
 pixels=np.asarray(pixels,dtype=float);targets=np.asarray(targets)
 warp=RBFInterpolator(pixels/500,targets,kernel='thin_plate_spline',smoothing=0)
 affine=np.linalg.lstsq(np.c_[pixels,np.ones(len(pixels))],targets,rcond=None)[0]
 affine_error=np.linalg.norm(np.c_[pixels,np.ones(len(pixels))]@affine-targets,axis=1)
 loo=[]
 for i in range(len(pixels)):
  keep=np.arange(len(pixels))!=i
  model=RBFInterpolator(pixels[keep]/500,targets[keep],kernel='thin_plate_spline')
  loo.append(float(np.linalg.norm(model(pixels[i:i+1]/500)[0]-targets[i])))
 paths=[]
 for path in trace['paths']:
  px=np.array(path['pixels'],dtype=float)
  # Smoothed at source-map scale; all explicit junction endpoints retained.
  chord=np.r_[0,np.cumsum(np.linalg.norm(np.diff(px,axis=0),axis=1))]
  interpolation=CubicSpline(chord,px,axis=0,bc_type='natural')
  fine_px=interpolation(np.linspace(0,chord[-1],max(2,int(chord[-1]*2))))
  world=warp(fine_px/500)
  line=LineString(world)
  distances=np.arange(0,line.length,trace['settings']['sample_metres'])
  vertices=np.array([line.interpolate(t).coords[0] for t in np.r_[distances,line.length]])
  paths.append(dict(id=path['id'],from_node=path['from'],to_node=path['to'],width=trace['settings']['default_width_metres'],points=vertices.tolist(),inferred=False,confidence=path['confidence']))
 # Access links are explicitly inferred and kept off runway strips.
 from grade_malta_terrain import field_axes,world_xz
 for field in fields.values():
  centre=field['length']*.31
  entrances=[[78,centre+115],[78,centre-115],[118,centre+90]]
  candidates=[]
  for entrance_local in entrances:
   entrance=world_xz(np.array([entrance_local]),field)[0]
   for path in paths:
    if path['inferred']:continue
    line=LineString(path['points']);end=np.array(nearest_points(line,Point(entrance))[0].coords[0])
    d=np.linalg.norm(end-entrance)
    candidates.append((d,end,path['id'],entrance,entrance_local))
  d,end,source,entrance,entrance_local=min(candidates,key=lambda p:p[0])
  if d <= trace['settings']['maximum_initial_gap_metres']:
   inward=np.array(entrance_local,dtype=float)
   inward[1] += -13 if entrance_local[1]>centre else 13
   lane=world_xz(np.array([inward]),field)[0]
   vertices=np.array([lane,entrance,end])
   # Route the inferred access around a runway end, never across the strip.
   from grade_malta_terrain import local_xz
   local=local_xz(vertices,field)
   runway=box(-35,-field['length']/2-10,35,field['length']/2+10)
   if LineString(local).intersects(runway):
    end_z=(field['length']/2+80) if local[-1,1]>=0 else (-field['length']/2-80)
    bend=world_xz(np.array([[78,end_z],[local[-1,0],end_z]]),field)
    vertices=np.vstack([lane,entrance,bend,end])
   line=LineString(vertices)
   assert not LineString(local_xz(vertices,field)).intersects(runway)
   samples=np.array([line.interpolate(t).coords[0] for t in np.r_[np.arange(0,line.length,4),line.length]])
   paths.append(dict(id='access_'+field['id'],from_node='entrance_'+field['id'],to_node='join_'+source,width=4.5,points=samples.tolist(),join_world=end.tolist(),inferred=True,confidence='short inferred base access',length=float(line.length)))
 trace['world_junctions']={key:warp(np.array([value])/500)[0].tolist() for key,value in trace['junctions'].items()}
 for path in paths:
  if path['inferred']:
   trace['world_junctions'][path['from_node']]=path['points'][0]
   trace['world_junctions'][path['to_node']]=path['join_world']
 registration=dict(affine_rms_metres=float(np.sqrt(np.mean(affine_error**2))),control_fit_max_metres=float(np.max(np.linalg.norm(warp(pixels/500)-targets,axis=1))),leave_one_out_max_metres=max(loo),leave_one_out_rms_metres=float(np.sqrt(np.mean(np.array(loo)**2))),north_image_direction=np.linalg.inv(affine[:2].T)@np.array([0,-1]))
 registration['north_image_direction']=registration['north_image_direction'].tolist()
 return trace,paths,registration

if __name__=='__main__':
 trace,paths,registration=trace_network()
 output=dict(paths=paths,registration=registration,settings=trace['settings'],junctions=trace['junctions'],world_junctions=trace['world_junctions'],uncertainties=trace['omitted_uncertain_sections'])
 (ASSET/'roads/world_paths.json').write_text(json.dumps(output,indent=2)+'\n')
 print(json.dumps(registration,indent=2));print('Routes:',len(paths),'inferred:',[p['id'] for p in paths if p['inferred']])
