"""Validate the supplied real dataset separately from synthetic compiler fixtures."""
import hashlib,json
from pathlib import Path
from shapely.geometry import shape
ROOT=Path(__file__).resolve().parents[1]
base=ROOT/'assets/malta/cottonera'
raw=json.loads((base/'source/supplied-cottonera.geojson').read_text())
features=json.loads((base/'features.geojson').read_text())
original={f['id']:f for f in raw['features']}
assert features['metadata']['input_sha256']==hashlib.sha256((base/'source/supplied-cottonera.geojson').read_bytes()).hexdigest()
assert len(features['features'])>3000
assert all(f['id'] in original for f in features['features'])
assert all(shape(f['geometry']).equals_exact(shape(original[f['id']]['geometry']),1e-12) for f in features['features'] if 'Polygon' in f['geometry']['type'])
assert all(not f['properties']['historical_verified'] for f in features['features'])
assert all('not municipal attribution' in f['properties']['cottonera_group_basis'] for f in features['features'])
assert not any('Valletta' in f['properties'].get('addr:city','') for f in features['features'])
fort=next(f for f in features['features'] if f['id']=='way/54896162')
assert fort['properties']['cottonera_role']=='fort_st_angelo'
report=json.loads((base/'region.json').read_text())
assert report['building_count']>2000 and report['collision_chunks']>30
assert all(r['chunks'] for r in report['regions'])
assert report['source_geojson_sha256']==hashlib.sha256((base/'features.geojson').read_bytes()).hexdigest()
for path,digest in report['source_hashes'].items():
 assert hashlib.sha256((ROOT/'assets/malta'/path).read_bytes()).hexdigest()==digest,path
print('COTTONERA SOURCE RESULT: 15 assertions passed (source identity, footprints, provenance, scope, real model/collision and protected-world hashes)')
