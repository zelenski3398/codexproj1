"""Read-only projection, coastline and imported-terrain sampling for Cottonera."""
from pathlib import Path
import json
import numpy as np
import trimesh
from pyproj import Transformer
from shapely.geometry import shape
from shapely.ops import unary_union,polygonize,transform
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from grade_malta_terrain import GroundSampler
ROOT=Path(__file__).resolve().parents[2]
ASSET=ROOT/'assets/malta'
class Geography:
    def __init__(self):
        self.data=json.loads((ASSET/'world_data.json').read_text())
        self.project=Transformer.from_crs(4326,self.data['crs'],always_xy=True)
        self.origin=np.array(self.project.transform(*self.data['origin_lon_lat']))
        self.inverse=Transformer.from_crs(self.data['crs'],4326,always_xy=True)
        coast=json.loads((ASSET/'source/Malta-Coastline.geojson').read_text())
        mainland=max(polygonize(unary_union([shape(f['geometry']) for f in coast['features']])),key=lambda p:p.area)
        self.land=transform(self._project_coords,mainland)
        scene=trimesh.load(ASSET/'terrain.glb',force='scene',process=False)
        self.sampler=GroundSampler(scene.geometry['Malta'])
        self.patch_triangles=[]
        for node in scene.graph.nodes_geometry:
            pose,name=scene.graph[node]
            if not name.startswith('RoadGround'):continue
            m=scene.geometry[name].copy();m.apply_transform(pose)
            tri=m.vertices[m.faces]
            tri=tri[np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])[:,1]>1e-7]
            self.patch_triangles.append((tri,tri[:,:,[0,2]].min(axis=1),tri[:,:,[0,2]].max(axis=1)))
    def _project_coords(self,x,y,z=None):
        e,n=self.project.transform(x,y)
        return np.asarray(e)-self.origin[0],self.origin[1]-np.asarray(n)
    def xz(self,lon,lat):
        x,z=self._project_coords(lon,lat)
        return np.array([float(x),float(z)])
    def lon_lat(self,x,z):return list(self.inverse.transform(x+self.origin[0],self.origin[1]-z))
    def geometry(self,geometry):return transform(self._project_coords,geometry)
    def heights(self,points):
        points=np.asarray(points,dtype=float);answer=self.sampler.heights(points)
        for i in np.flatnonzero(~np.isfinite(answer)):
            x,z=points[i];values=[]
            for tri,lo,hi in self.patch_triangles:
                candidates=tri[(lo[:,0]<=x+1e-6)&(hi[:,0]>=x-1e-6)&(lo[:,1]<=z+1e-6)&(hi[:,1]>=z-1e-6)]
                for face in candidates:
                    a,b,c=face[:,[0,2]];den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
                    if abs(den)<1e-8:continue
                    u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(z-c[1]))/den
                    v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(z-c[1]))/den
                    if u>=-1e-6 and v>=-1e-6 and u+v<=1+1e-6:values.append(u*face[0,1]+v*face[1,1]+(1-u-v)*face[2,1])
            if values:answer[i]=max(values)
        return answer
