"""Prepare verified place anchors only; never invent missing city footprints."""
import json,hashlib
from cottonera.geography import Geography,ASSET
from shapely.geometry import Point
out=ASSET/'cottonera';g=Geography();places=json.loads((out/'source/places.json').read_text())
names={'birgu':'Birgu (Vittoriosa)','senglea':'Isla (Senglea)','bormla':'Bormla (Cospicua)','kalkara':'Kalkara'}
regions=[]
for place in places['places']:
    xz=g.xz(place['longitude'],place['latitude']);height=float(g.heights([xz])[0])
    # Preserve the source point rather than silently moving a coarse gazetteer
    # coordinate onto a guessed historic centre or landmark.
    regions.append(dict(id=place['id'],name=names[place['id']],geonameid=place['geonameid'],lon_lat=[place['longitude'],place['latitude']],position=[xz[0],height if height==height else 0,xz[1]],on_land=g.land.covers(Point(*xz)),status='awaiting_geodata',chunks=[]))
paths=['terrain.glb','world_data.json','roads/world_paths.json','source/Malta-Coastline.geojson']
manifest=dict(version=1,status='awaiting_geodata',crs=g.data['crs'],projection_origin_lon_lat=g.data['origin_lon_lat'],units='metres',regions=regions,source_hashes={p:hashlib.sha256((ASSET/p).read_bytes()).hexdigest() for p in paths},building_count=0,fortification_count=0,collision_chunks=0,lod_levels=3,missing_geometry=True)
(out/'alignment.json').write_text(json.dumps(manifest,indent=2,allow_nan=False)+'\n')
if not (out/'region.json').exists():(out/'region.json').write_text(json.dumps(manifest,indent=2,allow_nan=False)+'\n')
if not (out/'features.geojson').exists():(out/'features.geojson').write_text(json.dumps(dict(type='FeatureCollection',features=[],metadata=dict(status='awaiting_geodata',notice='Intentionally empty. No invented city, building, fortification or dock outlines.')),indent=2)+'\n')
print(json.dumps(regions,indent=2))
