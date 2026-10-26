"""Real-world rural geometry, visual principles, protected systems and shared walls."""
from pathlib import Path
import json,sys,hashlib,subprocess
import numpy as np
from shapely.geometry import shape,LineString
from shapely import STRtree
from shapely.ops import unary_union
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from generate_malta_countryside import RuralGeography,masks,OUT,ASSET
from cottonera.landscape import stone_batch
passed=0
def check(ok,label):
 global passed
 assert ok,label
 passed+=1;print('PASS:',label,flush=True)
r=json.loads((OUT/'manifest.json').read_text());g=RuralGeography();allowed,excluded,routes=masks(g,r['settings'])
plots=[shape(p['footprint']) for p in r['plots']]
check(r['inferred'] and len(plots)>500 and len(r['clusters'])>20,'Numerous inferred fields occur in separate rural clusters, not an island-wide painted grid')
check(len(r['clusters'])>=300 and 3000<=len(plots)<=12000 and r['wall_length_m']>=40000,'Broad coverage and wall budgets remain, while larger parcels reduce tiny-plot count')
check(all(c['clusters']>0 and c['wall_m']>0 for c in r['coverage_cells'] if c['eligible_centres']>=3),'Every substantial eligible 2.5 km countryside region contains fields and rubble walls')
check(all(p.is_valid and p.area>=r['settings']['minimum_plot_area_m2'] for p in plots),'All field polygons are valid and useful-sized')
check(all(allowed.covers(p) for p in plots),'No fields enter protected cities, mapped structures, fortifications, bases, roads, coast or sea')
check(sum(len(p.exterior.coords)==4 for p in plots)>40 and sum(len(p.exterior.coords)==5 for p in plots)>1000 and sum(len(p.exterior.coords)>5 for p in plots)>500,'Triangular, quadrilateral and irregular polygons all occur in the shared subdivision')
angles=np.array([p['angle'] for p in r['plots']]);check(len(set(np.round(angles,1)))>12,'Clusters use varied road/contour orientations rather than global-axis repetition')
areas=np.array([p.area for p in plots]);check(np.median(areas)>4000 and np.quantile(areas,.9)>9000 and np.mean(areas>2400)>.7,'Medium/large plots dominate; median area is over three times the former 1212 m²')
check(np.std(areas)/np.mean(areas)>.4,'Field sizes vary substantially instead of repeating identical squares')
lengths=[np.linalg.norm(np.diff(np.asarray(p.exterior.coords),axis=0),axis=1) for p in plots]
check(sum(np.max(v)/max(np.min(v),1)>.17+1 for v in lengths)/len(lengths)>.7,'Unequal side lengths and subdivisions break congruent-square patterns')
# Micrometre overlay precision avoids a GEOS false intersection outside both
# operand envelopes at a coincident shared edge; stored geometry is not snapped.
tree=STRtree(plots);overlaps=0
for i,p in enumerate(plots):
 for j in tree.query(p,predicate='intersects'):
  if j>i and p.intersection(plots[j],grid_size=1e-6).area>1e-5:overlaps+=1
check(overlaps==0,'Neighbouring fields and clusters do not overlap')
check(any(c['centre'][2]<-6500 for c in r['clusters']) and any(c['centre'][2]>0 for c in r['clusters']),'Continuous-world fields include both Gozo and Malta without moving either island')
check(any(p['terraced'] for p in r['plots']) and all(np.linalg.norm(g.gradient(p.centroid.coords[0]))<.35 for p in plots),'Contour strips occur on gentle hillsides while steep terrain is rejected')
check(all(g.maximum_slope(p)<=r['settings']['maximum_plot_slope']+1e-6 for p in plots),'Every actual terrain triangle beneath a field passes the slope guard, including interior ridges')
check(len(r['tracks'])>20 and all(allowed.covers(shape(p)) for p in r['tracks']),'Draped dirt access lanes remain inside permitted rural land')
segments=[LineString([(p['a'][0],p['a'][2]),(p['b'][0],p['b'][2])]) for p in r['sections']]
check(1000<r['wall_length_m']<=r['settings']['maximum_wall_length_m'] and len(segments)>500,'Actual 3D wall network obeys its global length budget')
check(all(allowed.covers(p.buffer(1.0,cap_style=2)) for p in segments),'Whole rubble-wall envelopes clear protected gameplay corridors and structures')
check(abs(sum(p.length for p in segments)-unary_union(segments).length)<.01,'Shared field boundaries produce no overlapping duplicate walls')
points=np.array([[v[0],v[2]] for s in r['sections'] for v in [s['a'],s['b']]]);stored=np.array([v[1] for s in r['sections'] for v in [s['a'],s['b']]])
check(np.max(abs(g.heights(points)-stored))<1e-6,'Every wall base follows the existing terrain heights')
for p,h in r['source_hashes'].items():assert hashlib.sha256((ASSET/p).read_bytes()).hexdigest()==h,p
check(True,'Terrain, coast-derived world, roads, city manifests, Cottonera and existing painted masks remain unchanged')
# The new optional rural style must not silently change already shipped Cottonera.
baseline_source=subprocess.check_output(['git','show','23042f9:tools/cottonera/landscape.py'],text=True)
baseline={'__name__':'cottonera.baseline','__package__':'cottonera'};exec(baseline_source,baseline)
fixture=[(np.array([0.,0.]),np.array([1.6,.1]),np.array([0.,.02,.04]))]
settings=json.loads((ASSET/'cottonera/landscape_rules.json').read_text())['fields']
a=stone_batch(fixture,settings,np.random.default_rng(1942));b=baseline['stone_batch'](fixture,settings,np.random.default_rng(1942))
check(all(np.array_equal(getattr(a,k)[0].vertices,getattr(b,k)[0].vertices) and np.array_equal(getattr(a,k)[0].visual.face_colors,getattr(b,k)[0].visual.face_colors) for k in ['near','mid','far','collision']),'Shared rubble library preserves the previous Cottonera style and deterministic geometry exactly')
rural=stone_batch(fixture,r['settings']['wall'],np.random.default_rng(1942))
check(all(getattr(rural,k)[0].volume>0 for k in ['near','mid','far','collision']),'Varied rural rock geometry and collisions have outward winding')
colours=rural.near[0].visual.face_colors[:,:3]
check(len(np.unique(colours,axis=0))>3 and (colours[:,0]>colours[:,2]).any(),'Individual rocks mix pale, warm and soil-stained tones')
check(all(Path(p.replace('res://',str(ASSET.parent.parent)+'/')).exists() for c in r['chunks'] for p in c['files'].values()),'Every generated visual/collision file referenced by the manifest exists')
import struct
normal_files=list(OUT.glob('farm_*_near.glb'))
normal_ok=True
for path in normal_files:
 raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0];gltf=json.loads(raw[20:20+size]);normal_ok=normal_ok and all('NORMAL' in primitive['attributes'] for mesh in gltf['meshes'] for primitive in mesh['primitives'])
check(normal_ok and len(normal_files)>0,'Detailed rocks export actual NORMAL buffers for convincing 3D lighting')
# Test actual exported skins as well as metadata, including protected corridors.
import trimesh
from shapely import contains_xy,prepare
prepare(allowed)
skins_clear=True;skins_draped=True;edge_samples=0;maximum_error=0.0
for chunk in r['chunks']:
 if 'soil' not in chunk['files']:continue
 mesh=trimesh.load(ASSET.parent.parent/chunk['files']['soil'][6:],force='mesh',process=False)
 vertices=mesh.vertices+np.array(chunk['origin'])
 skins_clear=skins_clear and bool(contains_xy(allowed,vertices[:,0],vertices[:,2]).all())
 heights=g.heights(vertices[:,[0,2]])
 errors=abs(heights+.045-vertices[:,1])
 missing=~np.isfinite(errors)
 if missing.any():
  # GLB float32 rounding can put a source-edge vertex just outside the exact
  # sampler. Require a matching adjacent source triangle within 2 mm instead
  # of accepting NaN or silently dropping the exported vertex from the check.
  edge_samples+=int(missing.sum());sample=vertices[missing];candidates=[]
  for offset in [[.002,0],[-.002,0],[0,.002],[0,-.002],[.002,.002],[-.002,-.002],[.002,-.002],[-.002,.002]]:
   candidates.append(abs(g.heights(sample[:,[0,2]]+offset)+.045-sample[:,1]))
  candidates=np.array(candidates);candidates[~np.isfinite(candidates)]=float('inf')
  errors[missing]=np.min(candidates,axis=0)
 maximum_error=max(maximum_error,float(np.max(errors)))
 skins_draped=skins_draped and bool(np.max(errors)<.005)
check(skins_clear,'Every exported field-skin vertex clears the actual protected-area mask')
check(skins_draped,'Exported soil skins follow actual terrain within five millimetres, including GLB float precision')
print('DRAPE CHECK: maximum error',maximum_error,'m; adjacent-triangle edge resamples',edge_samples)
print(f'COUNTRYSIDE SOURCE RESULT: {passed}/{passed} passed')
