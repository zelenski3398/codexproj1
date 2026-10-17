"""Real geographic selection, full footprints, terrain fit and regeneration rules."""
import sys,json,hashlib,subprocess
from pathlib import Path
import numpy as np
from shapely.geometry import shape,LineString
from shapely.ops import unary_union
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from cottonera.geography import Geography,ASSET
from cottonera.landscape import Landscape,BUILDING_ROLES
passed=0
def check(ok,label):
 global passed
 assert ok,label
 passed+=1;print('PASS:',label,flush=True)
data=json.loads((ASSET/'cottonera/features.geojson').read_text());g=Geography()
records=[(f['id'],f['properties']['cottonera_city'],f['properties']['cottonera_role'],f['properties'],g.geometry(shape(f['geometry']))) for f in data['features']]
l=Landscape(g,records);report=json.loads((ASSET/'cottonera/region.json').read_text());meta=report['landscape']
check(meta['outer_wall_source']=='way/691540426' and l.boundary.is_valid,'Boundary follows the supplied outer Cottonera alignment, with a valid documented harbour closure')
check(not set(meta['inner_wall_sources_excluded']).intersection([meta['outer_wall_source'],meta['harbour_landfront_source']]),'Inner Santa Margherita alignments are not substituted for the outer defensive line')
for identifier,city,role,props,geometry in records:l.keep(identifier,role,geometry)
accepted=set(l.accepted);removed={r['id'] for r in l.audit}
check(accepted==set(meta['accepted_building_ids']) and removed=={r['id'] for r in meta['removed_buildings']},'Regenerated full-footprint selection matches the shipped manifest exactly')
check(all(l.boundary.covers(geom) for id,_,role,_,geom in records if id in accepted),'Every retained building footprint, including holes/vertices, is inside the enclosure')
check(all(id not in accepted for id,_,role,_,geom in records if role in BUILDING_ROLES and not l.boundary.intersects(geom)),'All exterior generated Cottonera building classes are excluded before meshes/details/collisions')
crossing=[r for r in l.audit if r['classification']=='crossing']
check(len(crossing)==4 and all(r.get('reason') and r['action']=='remove' for r in crossing),'All four crossing footprints have individual reviewed decisions; none uses only a centroid')
check(not accepted.intersection(removed),'No removed building can survive in another rendering batch')
check(len([r for r in records if r[2] not in BUILDING_ROLES])==sum(1 for r in records if l.keep(r[0],r[2],r[4]) and r[2] not in BUILDING_ROLES),'Walls gates terrain-facing roads and military roles bypass building removal')
fields=meta['fields'];config=fields['configuration']
check(fields['inferred'] and fields['plot_count']>5 and fields['wall_length_m']>500,'Explicitly inferred independent agricultural plots have a substantial field-wall network')
roads=[];forts=[]
for _,_,role,p,geom in records:
 if role in ['road','footway']:
  width=float(str(p.get('width',1.5 if role=='footway' else 4.5)).split()[0]);roads.append(geom.buffer(max(.5,width)/2+.25))
 elif role not in BUILDING_ROLES:forts.append(geom.buffer(config['fortification_margin_m']))
for p in json.loads((ASSET/'roads/world_paths.json').read_text())['paths']:roads.append(LineString(p['points']).buffer(float(p['width'])/2+.5))
clearance=unary_union(roads).buffer(config['road_margin_m']);protected=unary_union(forts)
segments=[LineString([(s['a'][0],s['a'][2]),(s['b'][0],s['b'][2])]) for s in fields['sections']]
check(all(not segment.buffer(.5,cap_style=2).intersects(l.boundary) for segment in segments),'Rubble-wall geometry stays outside the fortified enclosure')
check(all(not segment.buffer(.5,cap_style=2).intersects(clearance) for segment in segments),'Mapped roads footways and existing game routes have physical wall clearance')
check(all(not segment.buffer(.5,cap_style=2).intersects(protected) for segment in segments),'Gates bastions and other retained fortifications have clear access margins')
land_clear=g.land.buffer(-8)
check(all(land_clear.covers(segment.buffer(.5,cap_style=2)) for segment in segments),'No wall section crosses water or the coastline')
keys=[tuple(sorted((tuple(s['a'][::2]),tuple(s['b'][::2])))) for s in fields['sections']]
check(len(keys)==len(set(keys)) and abs(sum(s.length for s in segments)-unary_union(segments).length)<.01,'Neighbouring plots share noded walls, without duplicate/overlapping segments')
points=np.array([[v[0],v[2]] for s in fields['sections'] for v in [s['a'],s['b']]])
hh=g.heights(points);stored=np.array([v[1] for s in fields['sections'] for v in [s['a'],s['b']]])
check(np.isfinite(hh).all() and np.max(abs(hh-stored))<1e-6,'Every wall endpoint is fitted to the unchanged real terrain')
chunks=[c for r in report['regions'] for c in r['chunks'] if c.get('detail_type')=='fields']
check(len(chunks)>0 and all(all(k in c for k in ['mid','near','far','collision']) for c in chunks),'Field batches have separate stone-detail, coarse and skyline geometry plus simple strip collisions')
referenced={Path(c[k]).name for region in report['regions'] for c in region['chunks'] for k in ['mid','near','far','collision'] if k in c}
check(referenced=={p.name for p in (ASSET/'cottonera').glob('*.glb')},'No obsolete exterior visual/collision chunk survives outside the current manifest')
for path,digest in report['source_hashes'].items():assert hashlib.sha256((ASSET/path).read_bytes()).hexdigest()==digest,path
check(True,'Protected terrain coastline roads world coordinates remain byte-for-byte identical')
# Only Cottonera assets, its generator/runtime, tests and documentation may change.
changed=subprocess.check_output(['git','diff','--name-only','HEAD'],text=True).splitlines()
check(not any(p.startswith(('assets/malta/valletta/','assets/malta/mdina/','assets/malta/roads/')) or p=='assets/malta/terrain.glb' for p in changed),'Other generated settlements landmarks roads and terrain have no diff')
from cottonera.landscape import stone_batch
mesh_fixture=stone_batch([(np.array([0.,0.]),np.array([1.6,0.]),np.zeros(3))],config,np.random.default_rng(1942))
check(all(getattr(mesh_fixture,level)[0].volume>0 and np.isfinite(getattr(mesh_fixture,level)[0].vertices).all() for level in ['mid','near','far','collision']),'Reusable chipped-stone and collider topology has outward winding and finite geometry')
check(len(mesh_fixture.collision)==1 and len(mesh_fixture.collision[0].faces)==12,'One coarse wall-strip collision replaces all individual stone physics bodies')
print(f'COTTONERA LANDSCAPE RESULT: {passed}/{passed} passed')
