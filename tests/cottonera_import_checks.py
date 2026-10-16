"""Synthetic import fixtures are tests only, never shipped city geography."""
import sys,json,tempfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from import_cottonera import import_features,from_osm
passed=0
def check(ok,label):
 global passed
 assert ok,label
 passed+=1;print('PASS:',label)
with tempfile.TemporaryDirectory() as temp:
 p=Path(temp)/'fixture.geojson'
 def feature(id,tags,geometry=None):return dict(type='Feature',id=id,properties=tags,geometry=geometry or dict(type='Polygon',coordinates=[[[14.52,35.88],[14.521,35.88],[14.521,35.881],[14.52,35.881],[14.52,35.88]]]))
 fixtures=[feature('house',{'building':'yes'}),feature('inner',{'name':'Santa Margherita Lines','historic':'citywalls'}),feature('outer',{'name':'Cottonera Lines','historic':'citywalls'}),feature('new',{'building':'yes','start_date':'2004'}),feature('marina',{'leisure':'marina'})]
 p.write_text(json.dumps(dict(type='FeatureCollection',features=fixtures)))
 d=import_features(p,'Synthetic test only','Test fixture','modern_baseline','bormla')
 check(len(d['features'])==3 and len(d['metadata']['skipped'])==2,'Modern buildings/marinas excluded without inventing replacements')
 check(d['features'][1]['properties']['cottonera_role']=='santa_margherita_lines' and d['features'][2]['properties']['cottonera_role']=='cottonera_lines','Defensive systems stay distinct')
 check(all(not f['properties']['historical_verified'] for f in d['features']),'Modern baseline never labelled historically verified')
 check(json.loads(json.dumps(d['features'][0]['geometry']))==fixtures[0]['geometry'],'Source footprint coordinates retained exactly')
 check(not import_features(p,'Test','Test','modern_baseline')['features'],'No guessed city assignment')
 for values,label in [(('', 'Test'), 'Missing source rejected'),(('Test',''), 'Missing licence rejected')]:
  try:import_features(p,*values,'modern_baseline','bormla');ok=False
  except ValueError:ok=True
  check(ok,label)
 p.write_text(json.dumps(dict(type='FeatureCollection',features=[feature('bad',{'building':'yes'},dict(type='Point',coordinates=[0,0]))])))
 try:import_features(p,'Test','Test','modern_baseline','birgu');ok=False
 except ValueError:ok=True
 check(ok,'Out-of-area or unprojected source rejected')
 p.write_text('<osm><node id="1" lon="14.52" lat="35.88"/><node id="2" lon="14.521" lat="35.88"/><node id="3" lon="14.521" lat="35.881"/><way id="4"><nd ref="1"/><nd ref="2"/><nd ref="3"/><nd ref="1"/><tag k="building" v="yes"/></way></osm>');p=p.rename(Path(temp)/'fixture.osm')
 check(len(import_features(p,'Synthetic','Test','modern_baseline','birgu')['features'])==1,'Local OSM XML resolves real node references')
 elements=[dict(type='way',id=1,tags={'building':'yes'},geometry=[dict(lon=14.52,lat=35.88),dict(lon=14.521,lat=35.88),dict(lon=14.521,lat=35.881),dict(lon=14.52,lat=35.88)])]
 check(len(from_osm(elements))==1,'Overpass inline geometries supported')
 outer=[[14.52,35.88],[14.523,35.88],[14.523,35.883],[14.52,35.883],[14.52,35.88]];inner=[[14.521,35.881],[14.522,35.881],[14.522,35.882],[14.521,35.882],[14.521,35.881]]
 relation=dict(type='relation',id=3,tags={'type':'multipolygon','building':'yes'},members=[dict(type='way',ref=1,role='outer',geometry=[dict(lon=x,lat=y) for x,y in outer]),dict(type='way',ref=2,role='inner',geometry=[dict(lon=x,lat=y) for x,y in inner])])
 check(len(from_osm([relation])[0]['geometry']['coordinates'])==2,'Multipolygon courtyard holes survive import')
print(f'COTTONERA IMPORT RESULT: {passed}/{passed} passed')
