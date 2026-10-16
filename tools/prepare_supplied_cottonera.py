"""Select supplied OSM features for Cottonera; grouping is rendering, not borders."""
import argparse, hashlib, json
from pathlib import Path
from shapely.geometry import Polygon, shape, mapping
from import_cottonera import import_features

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/malta/cottonera'
# Editorial area-of-interest only, NOT asserted municipal or historical borders.
# Excludes Valletta across Grand Harbour and distant Paola/Zabbar development.
AOI=Polygon([(14.510,35.880),(14.522,35.876),(14.535,35.878),
             (14.539,35.887),(14.537,35.895),(14.528,35.897),
             (14.518,35.895),(14.510,35.891)])
ALIASES={'way/54896162':'fort_st_angelo',
         'way/136730135':'st_lawrence',
         'way/139164475':'immaculate_conception',
         'way/404197034':'gardjola'}

def prepare(path):
    raw=json.loads(path.read_text())
    if raw.get('generator')!='overpass-turbo' or 'openstreetmap.org' not in raw.get('copyright',''):
        raise ValueError('Review provenance before importing a different source')
    anchors=json.loads((OUT/'source/places.json').read_text())['places']
    selected=[]; excluded=[]
    for f in raw['features']:
        geometry=shape(f['geometry']); props=dict(f['properties'])
        if not AOI.covers(geometry.representative_point()):
            excluded.append(f['id']); continue
        # Complete building polygons retain all source vertices/holes. Clip only
        # long road alignments at the editorial extent, never move footprints.
        if geometry.geom_type in ['LineString','MultiLineString']:
            geometry=geometry.intersection(AOI)
        point=geometry.representative_point()
        anchor=min(anchors,key=lambda a:((point.x-a['longitude'])*.81)**2+(point.y-a['latitude'])**2)
        props.update(cottonera_city=anchor['id'],cottonera_group_basis='nearest source anchor for rendering ONLY; not municipal attribution')
        if f['id'] in ALIASES:props['cottonera_role']=ALIASES[f['id']]
        # Classify only mapped named defensive lines. Unknown mapped walls stay
        # generic fortifications, not an invented defensive-system assignment.
        selected.append(dict(type='Feature',id=f['id'],properties=props,geometry=mapping(geometry)))
    staged=OUT/'source/selected.geojson'
    staged.write_text(json.dumps(dict(type='FeatureCollection',features=selected),separators=(',',':'))+'\n')
    result=import_features(staged,'User-supplied Overpass Turbo OSM extract; source timestamp '+raw['timestamp'],
        'ODbL 1.0; © OpenStreetMap contributors','modern_baseline')
    staged.unlink()
    result['metadata'].update(input_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),input_features=len(raw['features']),
        excluded_outside_editorial_extent=len(excluded),selection_extent=mapping(AOI),
        grouping_notice='Nearest gazetteer anchors are batching labels only, not city boundaries or reviewed historical assignments.')
    (OUT/'features.geojson').write_text(json.dumps(result,separators=(',',':'),ensure_ascii=False)+'\n')
    print('Selected',len(selected),'Imported',len(result['features']),'Skipped',len(result['metadata']['skipped']))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('input',type=Path);prepare(parser.parse_args().input)
