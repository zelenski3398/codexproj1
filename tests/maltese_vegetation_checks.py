"""Source-world clearance, species/LOD assets and deterministic tree modelling."""
from pathlib import Path
import sys,json,hashlib,struct
import numpy as np
import trimesh
from shapely.geometry import Point,LineString,shape
from shapely import STRtree
from shapely.ops import unary_union
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from generate_malta_countryside import RuralGeography,masks,OUT,ASSET
from generate_maltese_trees import create
passed=0
def check(ok,label):
 global passed
 assert ok,label
 passed+=1;print('PASS:',label,flush=True)
r=json.loads((OUT/'manifest.json').read_text());v=json.loads((OUT/'trees.json').read_text());models=json.loads((ASSET/'vegetation/models.json').read_text())
g=RuralGeography();allowed,excluded,routes=masks(g,r['settings'])
trees=v['trees'];points=np.array([t['position'] for t in trees])
check(2500<=len(trees)<=v['settings']['maximum_trees'],'Substantial sparse population respects the world tree budget')
check(set(v['species_counts'])=={'carob','olive','aleppo_pine'} and min(v['species_counts'].values())>500,'All three species have substantial placements')
check(all({t['variant'] for t in trees if t['species']==species}=={0,1,2} for species in models['species']),'Three visible geometry variants of each species are placed')
check(all(allowed.covers(Point(t['position'][0],t['position'][2]).buffer(t['canopy_radius']+.59)) for t in trees),'Whole tree crowns clear mapped roads, military bases, hangars, cities, structures and coast guards')
segments=[LineString([(s['a'][0],s['a'][2]),(s['b'][0],s['b'][2])]) for s in r['sections']]
barriers=unary_union(segments).buffer(v['settings']['trunk_wall_clearance_m']-.001)
check(all(not barriers.intersects(Point(p[0],p[2])) for p in points),'Tree trunks remain at least two metres from physical rubble walls')
paths=unary_union([shape(t) for t in r['tracks']]).buffer(3)
check(all(not paths.intersects(Point(p[0],p[2]).buffer(1.99)) for p in points),'Field access tracks and their openings remain clear of trees')
check(np.max(abs(g.heights(points[:,[0,2]])-points[:,1]))<1e-6,'Every tree root uses actual existing terrain elevation')
check(all(np.linalg.norm(g.gradient(p[[0,2]]))<=v['settings']['maximum_tree_slope']+1e-6 for p in points),'Tree placement rejects excessively steep slopes')
index=STRtree([Point(p[0],p[2]) for p in points]);spacing=True
for i,p in enumerate(points):
 for j in index.query(Point(p[0],p[2]).buffer(v['settings']['minimum_tree_spacing_m']),predicate='intersects'):
  if j>i and np.linalg.norm(p[[0,2]]-points[j,[0,2]])<v['settings']['minimum_tree_spacing_m']-1e-6:spacing=False
check(spacing,'No repeated or overlapping trunk positions; minimum spacing enforced')
check(set(t['context'] for t in trees)=={'olive_grove','field_edge','pine_group','scattered'},'Loose groves, edge groups, pine groups and isolated specimens all occur')
polys=[shape(p['footprint']) for p in r['plots']];plot_index=STRtree(polys)
check(all(not any(polys[i].intersects(Point(t['position'][0],t['position'][2]).buffer(2)) for i in plot_index.query(Point(t['position'][0],t['position'][2]).buffer(2))) for t in trees if t['context'] in ['pine_group','scattered']),'Pine groups and isolated trees leave cultivated interiors open')
check(sum(p.area for p in polys)/sum(np.pi*t['canopy_radius']**2 for t in trees)>60,'Farmland area substantially exceeds tree canopy area, preserving open country')
check(any(p[2]<-6500 for p in points) and any(p[2]>0 for p in points),'Trees occur across Gozo/Comino and Malta in the continuous coordinate system')
asset_ok=True;opaque=True;hashes={};silhouettes={}
for species,variants in models['species'].items():
 for record in variants:
  near=trimesh.load(ASSET.parent.parent/record['near'][6:],force='mesh',process=False)
  silhouettes[(species,record['variant'])]=(round(near.extents[1],2),round(max(near.extents[[0,2]]),2))
  check(record['far_triangles']<record['near_triangles']*.6 and record['near_triangles']<1800,'Practical near/far triangle counts: '+species+' '+str(record['variant']))
  for lod in ['near','far']:
   path=ASSET.parent.parent/record[lod][6:];raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+size])
   asset_ok &= all('NORMAL' in p['attributes'] and 'COLOR_0' in p['attributes'] for mesh in gltf['meshes'] for p in mesh['primitives'])
   mesh=create(species,record['variant'],lod);opaque &= (mesh.visual.vertex_colors[:,3]==255).all()
   generated=trimesh.Scene(mesh).export(file_type='glb');hashes[path.name]=hashlib.sha256(raw).hexdigest()
   assert generated==raw,path.name+' must regenerate byte-identically'
check(asset_ok and opaque,'All 18 meshes have normals and opaque foliage/bark colours, with no alpha cards')
check(len(set(silhouettes.values()))==9 and models['species']['aleppo_pine'][1]['height']>models['species']['carob'][1]['height']*1.4,'Nine genuinely different shapes; mature pine is substantially taller than carob')
check(True,'All 18 original tree GLBs regenerate byte-identically')
print('VEGETATION SOURCE RESULT: %d/%d passed'%(passed,passed))
