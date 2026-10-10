"""Measured Malta terrain, exact input coastline and 80m interior mesh spacing.
Dependencies: numpy scipy shapely pyproj rasterio triangle trimesh mapbox-earcut matplotlib.
"""
from pathlib import Path
import json,shutil
import numpy as np
import rasterio
from pyproj import Transformer
from scipy.ndimage import distance_transform_edt,map_coordinates
from scipy.spatial import cKDTree
from shapely.geometry import shape
from shapely.ops import unary_union,polygonize_full,transform
from shapely import contains_xy
import triangle,trimesh
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LightSource
OUT=Path(__file__).resolve().parent
source=OUT/'Malta-Coastline.geojson'
if not source.exists():shutil.copyfile(OUT.parent/'upload/Malta-Coastline.geojson',source)
polys,cuts,dangles,bad=polygonize_full(unary_union([shape(f['geometry']) for f in json.loads(source.read_text())['features']]))
assert not len(cuts.geoms)+len(dangles.geoms)+len(bad.geoms)
polys=sorted(polys.geoms,key=lambda p:p.area,reverse=True)
with rasterio.open(OUT/'Malta-DTM-2012-32m.tif') as r:
 a=r.read(1);aff=r.transform;crs=r.crs;nodata=r.nodata
 valid=np.isfinite(a)&(a!=nodata)
 indices=distance_transform_edt(~valid,return_distances=False,return_indices=True)
 filled=a[tuple(indices)]
 rr,cc=np.where(valid);validxy=np.column_stack((aff.c+(cc+.5)*aff.a,aff.f+(rr+.5)*aff.e));tree=cKDTree(validxy)
 pr=Transformer.from_crs('EPSG:4326',crs,always_xy=True)
 origin_dtm=pr.transform(14.4,35.93)
 to_base=Transformer.from_crs(crs,'EPSG:32633',always_xy=True)
 base=Transformer.from_crs('EPSG:4326','EPSG:32633',always_xy=True).transform(14.4,35.93)
def xy_local(x,y,z=None):
 e,n=pr.transform(x,y);return np.asarray(e)-origin_dtm[0],np.asarray(n)-origin_dtm[1]
def heights(v):
 absolute=v+origin_dtm
 col=(absolute[:,0]-aff.c)/aff.a-.5;row=(absolute[:,1]-aff.f)/aff.e-.5
 h=map_coordinates(filled,[row,col],order=1,mode='nearest')
 d=tree.query(absolute)[0]
 return h,d
scene=trimesh.Scene();stats=[]
names=['Malta','Gozo','Comino','Manoel_Island','St_Pauls_Islands','Cominotto','Filfla']
for i,p in enumerate(polys):
 q=transform(xy_local,p);boundary=np.asarray(q.exterior.coords)[:-1];n=len(boundary)
 x0,y0,x1,y1=q.bounds
 gx,gy=np.meshgrid(np.arange(np.ceil(x0/80)*80,x1,80),np.arange(np.ceil(y0/80)*80,y1,80))
 keep=contains_xy(q.buffer(-2),gx.ravel(),gy.ravel())
 interior=np.column_stack((gx.ravel()[keep],gy.ravel()[keep]))
 vertices=np.vstack((boundary,interior))
 segments=np.column_stack((np.arange(n),np.roll(np.arange(n),-1)))
 result=triangle.triangulate({'vertices':vertices,'segments':segments},'pQ')
 v=result['vertices'];faces=result['triangles'].astype(int)
 assert len(v)==len(vertices),'Unexpected added points'
 assert abs(sum(abs(np.cross(v[f[1]]-v[f[0]],v[f[2]]-v[f[0]]))/2 for f in faces)-q.area)<q.area*1e-8
 # Positive XY winding = positive Y after mapping north to negative Z.
 cross=np.cross(np.column_stack((v[faces[:,1]]-v[faces[:,0]],np.zeros(len(faces)))),np.column_stack((v[faces[:,2]]-v[faces[:,0]],np.zeros(len(faces)))))[:,2]
 faces[cross<0]=faces[cross<0][:,::-1]
 h,d=heights(v)
 e,north=to_base.transform(v[:,0]+origin_dtm[0],v[:,1]+origin_dtm[1])
 top=np.column_stack((np.asarray(e)-base[0],h,-(np.asarray(north)-base[1])))
 # Boundary-only bottom cap, exact original ring.
 bv,bf=trimesh.creation.triangulate_polygon(q,engine='earcut')
 bh=np.full(len(bv),-30.0)
 be,bn=to_base.transform(bv[:,0]+origin_dtm[0],bv[:,1]+origin_dtm[1])
 bottom=np.column_stack((np.asarray(be)-base[0],bh,-(np.asarray(bn)-base[1])))
 bf=bf[:,::-1]
 # Earcut bottom orientation must face down.
 normals=np.cross(bottom[bf[:,1]]-bottom[bf[:,0]],bottom[bf[:,2]]-bottom[bf[:,0]])[:,1]
 bf[normals>0]=bf[normals>0][:,::-1]
 lookup={tuple(t):j+len(top) for j,t in enumerate(bv)}
 side=[]
 for j in range(len(boundary)):
  k=(j+1)%len(boundary);bj=lookup[tuple(boundary[j])];bk=lookup[tuple(boundary[k])]
  # Orient later via trimesh repair, preserving all coordinates.
  side.extend([[j,bj,bk],[j,bk,k]])
 mesh=trimesh.Trimesh(np.vstack((top,bottom)),np.vstack((faces,bf+len(top),np.asarray(side))),process=True)
 mesh.fix_normals(multibody=True)
 assert mesh.is_watertight and mesh.is_winding_consistent and mesh.volume>0
 # Terrain colour by height, plain material colours not satellite imagery.
 colors=plt.get_cmap('terrain')(np.clip((mesh.vertices[:,1]+5)/300,0,1))
 mesh.visual=trimesh.visual.ColorVisuals(mesh=mesh,vertex_colors=(colors*255).astype('uint8'))
 name=names[i] if i<len(names) else f'Coastal_islet_{i+1:02}'
 scene.add_geometry(mesh,node_name=name,geom_name=name)
 stats.append({'name':name,'triangles':len(mesh.faces),'min_height_m':float(h.min()),'max_height_m':float(h.max()),'max_distance_to_valid_dtm_sample_m':float(d.max()),'vertices_over_100m_from_valid_sample':int((d>100).sum())})
land_bounds=scene.bounds.copy();scene.export(str(OUT/'Malta-Elevated-Terrain.glb'))
loaded=trimesh.load(OUT/'Malta-Elevated-Terrain.glb',force='scene')
assert len(loaded.geometry)==36 and np.allclose(loaded.bounds,land_bounds,atol=.01)
for m in loaded.geometry.values():assert m.is_watertight and m.is_winding_consistent and np.isfinite(m.vertices).all()
sea=trimesh.creation.box([55000,2,48000]);sea.apply_translation([0,-1,0]);sea.visual.face_colors=[25,88,119,255];scene.add_geometry(sea,node_name='Sea_Base')
scene.export(str(OUT/'Malta-Elevated-With-Sea.glb'))
meta={'origin_lon_lat':[14.4,35.93],'export_crs':'EPSG:32633','DTM_crs':str(crs),'axes':{'x':'east','y':'up','z':'south'},'units':'metres','interior_mesh_spacing_m':80,'vertical_exaggeration':1,'dtm_pixel_spacing_m':[aff.a,-aff.e],'height_method':'bilinear on DTM raster; nodata filled from nearest valid pixel','coastline_vertices':'all retained; no simplification','source_dtm':'Planning Authority Digital Terrain Model 2012; 32x overview of 1m source','source_url':'https://malta.coverage.wetransform.eu/dtm_1m_2012/ows','triangles':sum(s['triangles'] for s in stats),'islands':stats}
(OUT/'Terrain-Metadata.json').write_text(json.dumps(meta,indent=2))
# Measured-data relief preview; upper plot north-up, lower an oblique true-height view.
fig=plt.figure(figsize=(14,8),facecolor='#eaf0f3');ax=fig.add_subplot(121);ax.set_facecolor('#195877')
fullrows,fullcols=np.mgrid[0:a.shape[0],0:a.shape[1]]
fullx=aff.c+(fullcols+.5)*aff.a-origin_dtm[0];fully=aff.f+(fullrows+.5)*aff.e-origin_dtm[1]
landmask=contains_xy(unary_union([transform(xy_local,p) for p in polys]),fullx,fully)
relief=LightSource(azdeg=315,altdeg=40).shade(filled,cmap=plt.get_cmap('terrain'),vert_exag=1,dx=aff.a,dy=-aff.e)
relief[~landmask]=[.098,.345,.467,1]
ax.imshow(relief,extent=[(aff.c-origin_dtm[0])/1000,(aff.c+a.shape[1]*aff.a-origin_dtm[0])/1000,(aff.f+a.shape[0]*aff.e-origin_dtm[1])/1000,(aff.f-origin_dtm[1])/1000])
ax.set_title('Measured relief • north up');ax.set_xlabel('East (km)');ax.set_ylabel('North (km)')
ax=fig.add_subplot(122,projection='3d')
# Raster decimation is only for this visual preview, not the GLB.
step=5; rows,cols=np.mgrid[0:a.shape[0]:step,0:a.shape[1]:step];z=np.where(landmask[::step,::step],filled[::step,::step],np.nan)/1000
x=(aff.c+(cols+.5)*aff.a-origin_dtm[0])/1000;y=(aff.f+(rows+.5)*aff.e-origin_dtm[1])/1000
ax.plot_surface(x,y,z,cmap='terrain',rcount=len(rows),ccount=cols.shape[1],linewidth=0,antialiased=False)
ax.set(xlim=(-22,18),ylim=(-18,18),zlim=(0,.3));ax.set_box_aspect((40,36,.3));ax.view_init(50,-65);ax.set_axis_off();ax.set_title('Natural vertical scale • no exaggeration')
fig.suptitle('Malta — measured elevation terrain',fontsize=22)
fig.text(.5,.03,'2012 LiDAR terrain • ~32m elevation raster • 80m interior mesh • modern coastline',ha='center',fontsize=12)
fig.savefig(OUT/'Elevation-Preview.png',dpi=140,bbox_inches='tight');plt.close(fig)
print(json.dumps({'triangles':meta['triangles'],'bounds':land_bounds.tolist(),'distant_vertices':sum(s['vertices_over_100m_from_valid_sample'] for s in stats),'maximum_fill_distance_m':max(s['max_distance_to_valid_dtm_sample_m'] for s in stats)}))
