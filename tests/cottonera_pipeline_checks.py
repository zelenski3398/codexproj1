"""Source-gated compiler checks. Synthetic features only ever write /tmp."""
import sys,json,tempfile
from pathlib import Path
import numpy as np,trimesh
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from build_cottonera import build
from cottonera.models import Models
from shapely.geometry import box
passed=0
def check(ok,label):
 global passed
 assert ok,label
 passed+=1;print('PASS:',label)
with tempfile.TemporaryDirectory() as temp:
 root=Path(temp);empty=root/'empty.geojson';empty.write_text(json.dumps(dict(type='FeatureCollection',features=[])))
 report=build(empty,root/'empty')
 check(report['status']=='awaiting_geodata' and not list((root/'empty').glob('*.glb')),'Missing geographic data produce no invented city geometry')
 source=json.loads((Path(__file__).resolve().parents[1]/'assets/malta/cottonera/alignment.json').read_text())
 check(all(r['chunks']==[] for r in report['regions']),'All placeholder regions remain empty and source anchored')
 building=dict(type='Feature',id='SYNTHETIC_TEST_ONLY',properties=dict(cottonera_city='bormla',cottonera_role='building',height=10),geometry=dict(type='Polygon',coordinates=[[[14.52755,35.88555],[14.5277,35.88555],[14.5277,35.8857],[14.52755,35.8857],[14.52755,35.88555]]]))
 f=root/'fixture.geojson';f.write_text(json.dumps(dict(type='FeatureCollection',metadata=dict(source='Synthetic test only',licence='Test fixture',synthetic=True),features=[building])))
 report=build(f,root/'compiled');regions=[r for r in report['regions'] if r['chunks']]
 check(len(regions)==1 and regions[0]['id']=='bormla','Compiler uses explicit city membership instead of inventing boundaries')
 levels={k for c in regions[0]['chunks'] for k in c}
 check(levels=={'mid','near','far','collision'},'Compiled source building has three visual tiers and persistent collision')
 check(report['status']=='partial_geodata' and 'cottonera_lines' in report['missing_roles'] and 'santa_margherita_lines' in report['missing_roles'],'Partial imports do not claim both defensive systems are complete')
 meshes=[trimesh.load(p,force='scene',process=False) for p in (root/'compiled').glob('*.glb')]
 check(bool(meshes) and all(np.isfinite(s.bounds).all() for s in meshes),'Compiled source geometry and heights are finite')
 try:build(f,Path(__file__).resolve().parents[1]/'assets/malta/cottonera');ok=False
 except ValueError:ok=True
 check(ok,'Synthetic test features cannot overwrite shipped geographic scenery')
 m=Models();m.house(box(0,0,14,24).difference(box(4,7,10,17)),0,11)
 check(bool(m.near) and bool(m.far) and bool(m.collision),'Reusable source-footprint houses provide architectural detail and collider meshes')
 m=Models();m.gate([0,0],0)
 check(all(np.isfinite(x.vertices).all() for x in m.collision),'Gate template produces finite collision geometry')
m=Models();m.dome(0,0,10,8,10)
dome=m.mid[0];normal=dome.face_normals[0];radial=dome.triangles_center[0]-np.array([0,10,0])
wall=Models();wall.battered_wall([0,0],[60,0],0,14)
check(float(np.dot(normal,radial))>0 and wall.mid[0].is_volume,'Dome and battered-wall normals face outwards for native/web culling and collision')
print(f'COTTONERA PIPELINE RESULT: {passed}/{passed} passed')
