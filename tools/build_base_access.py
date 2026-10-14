"""Focused base links only: public roads and terrain geometry remain unchanged."""
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'assets/malta'
def length(p):return sum(math.dist(a,b) for a,b in zip(p,p[1:]))
def resample(p,step=4):
 result=[p[0]]
 for a,b in zip(p,p[1:]):
  n=max(1,math.ceil(math.dist(a,b)/step))
  result.extend([[a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n] for i in range(1,n+1)])
 return result
def rounded(p):
 out=[p[0]]
 for a,b,c in zip(p,p[1:],p[2:]):
  before=math.dist(a,b);after=math.dist(b,c);d=min(12,before*.3,after*.3)
  start=[b[k]+(a[k]-b[k])*d/before for k in range(2)]
  end=[b[k]+(c[k]-b[k])*d/after for k in range(2)]
  out.append(start)
  # Tangent-continuous quadratic bend; do not swing outside the safe corridor.
  for i in range(1,5):
   t=i/4
   out.append([(1-t)**2*start[k]+2*(1-t)*t*b[k]+t*t*end[k] for k in range(2)])
 out.append(p[-1]);return out
def packed(p):return 'PackedVector2Array('+', '.join(format(x,'.8f') for v in p for x in v)+')'
def build():
 data=json.loads((ASSET/'world_data.json').read_text())
 network=json.loads((ASSET/'roads/world_paths.json').read_text())
 output={'note':'Existing public network/terrain geometry unchanged. Two obstructed access links rerouted around hangars; internal lanes share graded apron/collision. Public historic alignment remains approximate.','bases':{}}
 new_segments=[];old_segments=[];repairs=[];mins=[];maxs=[]
 for field in data['airfields']:
  source=next(p for p in network['paths'] if p['id']=='access_'+field['id'])
  c=field['length']*.31
  angle=math.radians(field['heading']);co=math.cos(angle);si=math.sin(angle);grade=math.atan(field['slope'])
  def world(p):
   x,z=p;z*=math.cos(grade)
   return [field['position'][0]+co*x-si*z,field['position'][2]+si*x+co*z]
  def local(p):
   dx=p[0]-field['position'][0];dz=p[1]-field['position'][2]
   return [co*dx+si*dz,(-si*dx+co*dz)/math.cos(grade)]
  if field['id']!='hal_far':
   end=local(source['points'][-1])
   control=[local(source['points'][0]),[78,c-170],[125,c-170],end]
   corners=[world(p) for p in rounded(control)]
   exterior=resample(corners)
   new_segments.extend(zip(corners,corners[1:]))
   # The previous trace was two straight segments: inside → edge → public join.
   old=[world([78,c-102]),world([78,c-115]),source['points'][-1]]
   old_segments.extend(zip(old,old[1:]))
   public=next(p for p in network['paths'] if p['id']==source['to_node'].removeprefix('join_'))
   j=source['points'][-1]
   nearest=min(range(len(public['points'])),key=lambda i:math.dist(public['points'][i],j))
   a=public['points'][max(0,nearest-3)];b=public['points'][min(len(public['points'])-1,nearest+3)]
   d=math.dist(a,b);t=[(b[k]-a[k])/d for k in range(2)]
   repairs.append(([j[k]-t[k]*20 for k in range(2)],[j[k]+t[k]*20 for k in range(2)]))
   zone=old+corners
   mins.append([min(p[k] for p in zone)-15 for k in range(2)])
   maxs.append([max(p[k] for p in zone)+15 for k in range(2)])
  else:exterior=source['points']
  entry=local(exterior[0])
  lanes=[{'from':[78,c-115],'to':[78,c+115]},{'from':[78,c-90],'to':[47,c-90]},{'from':[78,c+90],'to':[47,c+90]},{'from':[78,c+24],'to':[69,c+24]}]
  routes={}
  for sign in [-1,1]:
   inside=[entry,[78,c+sign*90],[47,c+sign*90]]
   routes['gun_'+str(sign)]=list(reversed(exterior))+[world(p) for p in inside[1:]]
  output['bases'][field['id']]={'width':source['width'],'public_route':source['to_node'].removeprefix('join_'),'public_join':source['points'][-1],'exterior_path':source['id'],'entrance_side':'north-apron' if entry[1]<c else 'south-apron','lanes':lanes,'routes':routes,'exterior_points':exterior,'exterior_length_metres':length(exterior),'previous_exterior_length_metres':source['length'],'parking_approach':world([69,c+24]),'collision':'Existing gentle graded terrain; no extra floor colliders','inferred':True}
 (ASSET/'roads/base_access.json').write_text(json.dumps(output,indent=2)+'\n')
 parameters={'access_zone_count':len(mins),'new_access_count':len(new_segments),'old_access_count':len(old_segments),'access_repair_count':len(repairs)}
 arrays={'access_zone_min':(mins,2),'access_zone_max':(maxs,2)}
 for prefix,segments,capacity in [('new_access',new_segments,32),('old_access',old_segments,8),('access_repair',repairs,4)]:
  assert len(segments)<=capacity
  arrays[prefix+'_start']=([list(a) for a,b in segments],capacity)
  arrays[prefix+'_end']=([list(b) for a,b in segments],capacity)
 path=ASSET/'materials/landscape.tres';text=path.read_text()
 # Replace only our generated uniform section; retain all landscape resources.
 text=text.split('shader_parameter/access_zone_count')[0].rstrip()+'\n'
 for key,value in parameters.items():text+='shader_parameter/'+key+' = '+str(value)+'\n'
 for key,(values,capacity) in arrays.items():
  values=values+[[0,0]]*(capacity-len(values))
  text+='shader_parameter/'+key+' = '+packed(values)+'\n'
 path.write_text(text)
 print('Base-only links:',{k:round(v['exterior_length_metres'],1) for k,v in output['bases'].items()},'new segments',len(new_segments))
if __name__=='__main__':build()
