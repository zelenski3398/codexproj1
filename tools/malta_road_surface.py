"""Offline road grading/mask generation. The road IS the terrain, never a slab."""
import json,struct
import numpy as np
from scipy.spatial import cKDTree
from scipy.ndimage import gaussian_filter1d
from shapely.geometry import LineString,box
from shapely.ops import unary_union
from shapely import distance,points

class RoadSurface:
 def __init__(self,network,records,sampler,grade_values,local_xz,world_xz,smooth):
  self.network=network;self.blend=network['settings']['grading_blend_metres'];self.shoulder=network['settings']['shoulder_metres'];self.records=records;self.sampler=sampler;self.local_xz=local_xz;self.smooth=smooth
  samples=[];heights=[];widths=[];extra=[];constraints=[];self.paths=[]
  self.exclusions=[]
  for record in records:
   vertices=world_xz(np.array(box(-35,-record['length']/2-10,35,record['length']/2+10).exterior.coords),record)
   self.exclusions.append(__import__('shapely').geometry.Polygon(vertices))
  for path in network['paths']:
   p=np.array(path['points']);h=sampler.heights(p);valid=np.isfinite(h)&(h>1)
   # No invented bridge: mask/grading stops where reference line leaves dry land.
   segments=[];start=None
   for i,good in enumerate(np.r_[valid,False]):
    if good and start is None:start=i
    if not good and start is not None:
     if i-start>=2:segments.append((p[start:i],h[start:i]))
     start=None
   retained=0
   for line,source_h in segments:
    base,_=grade_values(line,source_h,records,sampler)
    profile=gaussian_filter1d(base,3.0,mode='nearest')
    # Bound cut/fill to 1.5 m, retain hills rather than flattening whole routes.
    profile=np.clip(profile,base-1.5,base+1.5)
    tangent=np.gradient(line,axis=0);tangent/=np.maximum(np.linalg.norm(tangent,axis=1)[:,None],1e-8)
    perpendicular=np.c_[-tangent[:,1],tangent[:,0]]
    half_width=path['width']/2
    for offset in [-half_width-self.blend,-half_width-2.75,-half_width,0,half_width,half_width+2.75,half_width+self.blend]:
     row=line+perpendicular*offset;extra.extend(row)
     if abs(offset)==half_width:constraints.extend(zip(row[:-1],row[1:]))
    samples.extend(line);heights.extend(profile);widths.extend([path['width']/2]*len(line));retained+=len(line)
   self.paths.append(dict(id=path['id'],samples=len(p),dry_land_samples=retained,runway_excluded_samples=int(sum(np.count_nonzero(distance(points(p),exclusion)<.01) for exclusion in self.exclusions)),inferred=path['inferred'],length_metres=float(LineString(p).length)))
  self.samples=np.array(samples);self.profiles=np.array(heights);self.widths=np.array(widths)
  self.tree=cKDTree(self.samples);self.extra=np.array(extra);self.constraints=constraints
  # Every explicit junction shares one local ground level; no stacked patches
  # or nearest-route profile discontinuities at a branch/access intersection.
  for junction in network.get('world_junctions',{}).values():
   j=np.array([junction]);source=sampler.heights(j)
   if not np.isfinite(source[0]):continue
   level,_=grade_values(j,source,records,sampler)
   d=np.linalg.norm(self.samples-j,axis=1)
   blend=1-smooth(d/12)
   self.profiles=self.profiles*(1-blend)+float(level[0])*blend

 def evaluate(self,xz,base):
  # Dense 4 m stations, interpolate projection between neighboring station pairs.
  _,nearest=self.tree.query(xz,k=1)
  candidates=np.column_stack([np.maximum(nearest-1,0),nearest,np.minimum(nearest+1,len(self.samples)-1)])
  best=np.full(len(xz),np.inf);height=np.zeros(len(xz));half=np.zeros(len(xz))
  for a,b in [(candidates[:,0],candidates[:,1]),(candidates[:,1],candidates[:,2])]:
   p=self.samples[a];segment=self.samples[b]-p
   squared=np.sum(segment*segment,axis=1)
   # Never interpolate between different paths (station gap > 4.1 m).
   good=squared<4.1**2
   t=np.clip(np.sum((xz-p)*segment,axis=1)/np.maximum(squared,1e-10),0,1)
   d=np.linalg.norm(xz-(p+segment*t[:,None]),axis=1);d[~good]=np.inf
   better=d<best;best[better]=d[better]
   height[better]=(self.profiles[a]*(1-t)+self.profiles[b]*t)[better]
   half[better]=self.widths[a[better]]
  coast=distance(points(xz),self.sampler.coast)
  permitted=coast>10
  for exclusion in self.exclusions:permitted &= distance(points(xz),exclusion)>0.01
  weight=(1-self.smooth((best-half)/self.blend))*permitted
  # Preserve the independently graded airfield core exactly.
  from grade_malta_terrain import footprint
  for record in self.records:
   local=self.local_xz(xz,record)
   core=distance(points(local),footprint(record))
   weight*=self.smooth(core/12)
  result=base+np.clip(height-base,-1.5,1.5)*weight
  mask=(1-self.smooth((best-half)/self.shoulder))*permitted
  return result,mask,weight

def add_uv_buffers(path,masks):
 raw=path.read_bytes();json_size=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+json_size]);binary_start=20+json_size+8
 data=bytearray(raw[binary_start:])
 for mesh in doc['meshes']:
  if mesh.get('name') not in masks:continue
  mask=masks[mesh['name']]
  for primitive in mesh['primitives']:
   count=doc['accessors'][primitive['attributes']['POSITION']]['count']
   assert count==len(mask),(mesh['name'],count,len(mask))
   uv=np.c_[mask,np.zeros(len(mask))].astype('<f4').tobytes()
   while len(data)%4:data.extend(b'\0')
   offset=len(data);data.extend(uv)
   view=len(doc['bufferViews']);doc['bufferViews'].append(dict(buffer=0,byteOffset=offset,byteLength=len(uv),target=34962))
   accessor=len(doc['accessors']);doc['accessors'].append(dict(bufferView=view,componentType=5126,count=count,type='VEC2'))
   primitive['attributes']['TEXCOORD_0']=accessor
 doc['buffers'][0]['byteLength']=len(data)
 encoded=json.dumps(doc,separators=(',',':')).encode()
 encoded+=b' '*((-len(encoded))%4)
 binary=bytes(data)+b'\0'*((-len(data))%4)
 total=12+8+len(encoded)+8+len(binary)
 path.write_bytes(struct.pack('<III',0x46546c67,2,total)+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary)

def split_terrain(scene,mesh,mask,chunk_metres=512):
 import trimesh
 # Only locally refined terrain patches are split, each face belongs to ONE mesh.
 affected=(mask[mesh.faces].max(axis=1)>0)
 centres=mesh.vertices[mesh.faces].mean(axis=1)[:,[0,2]]
 tiles=np.floor(centres/chunk_metres).astype(int)
 groups={}
 for i in np.flatnonzero(affected):groups.setdefault(tuple(tiles[i]),[]).append(i)
 keep=np.flatnonzero(~affected);uv={}
 def subset(indices,name,translation):
  faces=mesh.faces[indices];used,inverse=np.unique(faces,return_inverse=True)
  part=trimesh.Trimesh(mesh.vertices[used]-translation,inverse.reshape(-1,3),process=False)
  part.visual=trimesh.visual.ColorVisuals(mesh=part,vertex_colors=mesh.visual.vertex_colors[used])
  uv[name]=mask[used]
  return part
 scene.geometry['Malta']=subset(keep,'Malta',np.zeros(3))
 for tile,indices in groups.items():
  name='RoadGround_%d_%d'%tile
  translation=np.array([tile[0]*chunk_metres,0,tile[1]*chunk_metres],dtype=float)
  transform=np.eye(4);transform[:3,3]=translation
  scene.add_geometry(subset(indices,name,translation),node_name=name,geom_name=name,transform=transform)
 return uv,len(groups)
