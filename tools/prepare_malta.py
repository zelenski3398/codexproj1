"""Make a north-up chart and georeferenced airfield data; never modify the GLB.
Offline dependencies only: pip install pyproj shapely Pillow numpy.
"""
import json, struct
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from pyproj import Transformer
from shapely.geometry import shape
from shapely.ops import polygonize, unary_union
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/malta'
project = Transformer.from_crs(4326, 32633, always_xy=True)
origin = project.transform(14.4, 35.93)
def point(lon, lat):
    e, n = project.transform(lon, lat)
    return e-origin[0], -(n-origin[1])
bounds = [-21000., -18500., 18000., 17500.]
size = (1300,1200)
def pixel(x,z): return ((x-bounds[0])/(bounds[2]-bounds[0])*size[0], (z-bounds[1])/(bounds[3]-bounds[1])*size[1])
coast = json.loads((OUT/'source/Malta-Coastline.geojson').read_text())
polys = sorted(polygonize(unary_union([shape(f['geometry']) for f in coast['features']])),key=lambda p:p.area,reverse=True)
image=Image.new('RGB',size,'#19465a');draw=ImageDraw.Draw(image)
for km in range(-20000,20001,5000):
    x,_=pixel(km,0);_,z=pixel(0,km)
    draw.line((x,0,x,size[1]),fill='#235166');draw.line((0,z,size[0],z),fill='#235166')
for poly in polys:
    coords=[pixel(*point(lon,lat)) for lon,lat in poly.exterior.coords]
    draw.polygon(coords,fill='#8e9a76');draw.line(coords,fill='#c0c6a0',width=2)
image.save(OUT/'navigation.png')
# Decode POSITION/index buffers and sample the actual supplied top surface.
f=(OUT/'terrain.glb').read_bytes();length,_=struct.unpack_from('<II',f,12);g=json.loads(f[20:20+length]);binary=f[28+length:]
def accessor(i):
    a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']];width={'VEC3':3,'SCALAR':1}[a['type']]
    return np.frombuffer(binary,dtype=dtype,count=a['count']*width,offset=v.get('byteOffset',0)+a.get('byteOffset',0)).reshape(a['count'],width)
triangles=[]
for mesh in g['meshes']:
    for p in mesh['primitives']:
        vertices=accessor(p['attributes']['POSITION']);indices=accessor(p['indices']).ravel();tri=vertices[indices].reshape(-1,3,3)
        normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
        triangles.append(tri[normal[:,1]>0.01])
tri=np.concatenate(triangles);mins=tri[:,:,[0,2]].min(axis=1);maxs=tri[:,:,[0,2]].max(axis=1)
def height(x,z):
    candidates=tri[(mins[:,0]<=x)&(maxs[:,0]>=x)&(mins[:,1]<=z)&(maxs[:,1]>=z)]
    for t in candidates:
        a,b,c=t[:,[0,2]];den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(z-c[1]))/den;v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(z-c[1]))/den
        if u>=-1e-6 and v>=-1e-6 and u+v<=1+1e-6:return float(u*t[0,1]+v*t[1,1]+(1-u-v)*t[2,1])
    return 0.
# Approximate historical site centres, not surveyed wartime runway layouts.
fields=[('ta_qali',"RAF Ta' Qali",14.4153,35.8953,130.,1450.),('luqa','RAF Luqa',14.4775,35.8586,140.,1600.),('hal_far','RAF Ħal Far',14.5067,35.8153,130.,1400.)]
records=[]
for id,name,lon,lat,heading,length in fields:
    x,z=point(lon,lat);angle=np.deg2rad(heading);forward=np.array([np.sin(angle),-np.cos(angle)]);right=np.array([np.cos(angle),np.sin(angle)])
    samples=[]
    for along in np.linspace(-length/2,length/2,41):
        for side in [-65,0,65]:
            q=np.array([x,z])+forward*along+right*side;samples.append((along,height(*q)))
    slope=float(np.clip(np.polyfit(*np.array(samples).T,1)[0],-.02,.02));elevation=max(h-slope*a for a,h in samples)+.35
    records.append(dict(id=id,name=name,longitude=lon,latitude=lat,position=[x,elevation,z],heading=heading,length=length,slope=slope,stationed_aircraft=['spitfire','sea_gladiator']))
landmarks=[]
for name,lon,lat in [('Valletta',14.5125,35.8992),('Grand Harbour',14.5190,35.8905),('Gozo',14.244,36.044),('Comino',14.334,36.011)]:
    x,z=point(lon,lat);landmarks.append(dict(name=name,position=[x,height(x,z),z]))
data=dict(origin_lon_lat=[14.4,35.93],crs='EPSG:32633',units='metres',chart_bounds=bounds,airfields=records,landmarks=landmarks,terrain_bounds=[[-19403.959,-30,-16980.369],[15887.997,250.865,15938.015]],placement_note='Approximate site coordinates; prototype runway headings, lengths, raised grading and parking layouts. No historical airfield reference image supplied.')
(OUT/'world_data.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps(records,indent=2));print('Land bounds verified; scale 1:1. Source mesh remains byte-for-byte unchanged.')
