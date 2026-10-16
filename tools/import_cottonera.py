"""Import LOCAL WGS84 GeoJSON, OSM XML or Overpass JSON with explicit provenance.
No network requests, guessed footprints, automatic city boundaries or terrain edits.
"""
import argparse,json,re,unicodedata,xml.etree.ElementTree as ET
from pathlib import Path
from shapely.geometry import shape,mapping,Polygon,LineString,Point,MultiPolygon
from shapely.ops import polygonize,unary_union
CITIES={'birgu':'birgu','vittoriosa':'birgu','senglea':'senglea','isla':'senglea','bormla':'bormla','cospicua':'bormla','kalkara':'kalkara'}
ROLES={'building','road','footway','fort_st_angelo','gardjola','st_michael','birgu_landfront','senglea_waterfront','bastion','gate','church','st_lawrence','inquisitors_palace','victories_basilica','immaculate_conception','cottonera_lines','santa_margherita_lines','dry_dock','quay','warehouse','crane','context','fortification'}
def text(v):return ''.join(c for c in unicodedata.normalize('NFKD',str(v)).lower() if not unicodedata.combining(c))
def classify(tags):
    explicit=tags.get('cottonera_role')
    if explicit:
        if explicit not in ROLES:raise ValueError('Unknown cottonera_role: '+explicit)
        return explicit
    name=text(tags.get('name',''))
    for phrase,role in [('st angelo','fort_st_angelo'),('saint angelo','fort_st_angelo'),('gardjola','gardjola'),('santa margherita','santa_margherita_lines'),('saint margaret','santa_margherita_lines'),('cottonera lines','cottonera_lines'),('inquisitor','inquisitors_palace'),('st lawrence','st_lawrence'),('saint lawrence','st_lawrence'),('our lady of victories','victories_basilica'),('immaculate conception','immaculate_conception')]:
        if phrase in name:return role
    if tags.get('waterway')=='dock' or tags.get('dock')=='drydock' or tags.get('man_made')=='dry_dock':return 'dry_dock'
    if tags.get('man_made')=='crane':return 'crane'
    if tags.get('man_made')=='quay':return 'quay'
    if tags.get('historic') in ['citywalls','fort','castle'] or tags.get('barrier')=='city_wall':return 'fortification'
    if tags.get('barrier')=='gate' or tags.get('historic')=='city_gate':return 'gate'
    if tags.get('highway'):return 'footway' if tags['highway'] in ['footway','pedestrian','steps','path'] else 'road'
    if tags.get('building') in ['church','cathedral','chapel']:return 'church'
    if tags.get('building') in ['warehouse','industrial']:return 'warehouse'
    if tags.get('building'):return 'building'
    return 'context'
def from_osm(elements):
    nodes={e['id']:(e['lon'],e['lat']) for e in elements if e['type']=='node' and 'lon' in e}
    ways={};features=[]
    for e in elements:
        if e['type']!='way':continue
        coords=[(p['lon'],p['lat']) for p in e.get('geometry',[]) if p]
        if not coords:coords=[nodes[n] for n in e.get('nodes',[]) if n in nodes]
        if len(coords)<2:continue
        ways[e['id']]=coords
    used=set()
    for e in elements:
        if e['type']!='relation' or e.get('tags',{}).get('type')!='multipolygon':continue
        rings={'outer':[],'inner':[]}
        for member in e.get('members',[]):
            if member.get('type')!='way':continue
            coords=[(p['lon'],p['lat']) for p in member.get('geometry',[]) if p] or ways.get(member['ref'],[])
            if len(coords)<2:raise ValueError('Unresolved multipolygon member: '+str(member['ref']))
            rings['inner' if member.get('role')=='inner' else 'outer'].append(LineString(coords));used.add(member['ref'])
        shells=list(polygonize(unary_union(rings['outer'])))
        holes=list(polygonize(unary_union(rings['inner']))) if rings['inner'] else []
        if not shells:raise ValueError('Unclosed multipolygon relation: '+str(e['id']))
        geom=unary_union(shells).difference(unary_union(holes))
        features.append(dict(type='Feature',id='relation/'+str(e['id']),properties=e.get('tags',{}),geometry=mapping(geom)))
    for e in elements:
        tags=e.get('tags',{})
        if not tags:continue
        if e['type']=='node' and e['id'] in nodes:geom=Point(nodes[e['id']])
        elif e['type']=='way' and e['id'] in ways and e['id'] not in used:
            coords=ways[e['id']];closed=len(coords)>3 and coords[0]==coords[-1]
            geom=Polygon(coords) if closed and ('building' in tags or tags.get('area')=='yes' or tags.get('historic') in ['fort','castle'] or tags.get('waterway')=='dock') else LineString(coords)
        else:continue
        features.append(dict(type='Feature',id=e['type']+'/'+str(e['id']),properties=tags,geometry=mapping(geom)))
    return features

def read(path):
    if path.suffix.lower() in ['.osm','.xml']:
        root=ET.parse(path).getroot();elements=[]
        for child in root:
            if child.tag not in ['node','way','relation']:continue
            e=dict(type=child.tag,id=int(child.attrib['id']),tags={t.attrib['k']:t.attrib['v'] for t in child.findall('tag')})
            if child.tag=='node':e.update(lon=float(child.attrib['lon']),lat=float(child.attrib['lat']))
            if child.tag=='way':e['nodes']=[int(n.attrib['ref']) for n in child.findall('nd')]
            if child.tag=='relation':e['members']=[dict(type=m.attrib['type'],ref=int(m.attrib['ref']),role=m.attrib.get('role','')) for m in child.findall('member')]
            elements.append(e)
        return from_osm(elements)
    data=json.loads(path.read_text())
    if 'elements' in data:return from_osm(data['elements'])
    if data.get('type')!='FeatureCollection':raise ValueError('Expected GeoJSON FeatureCollection, OSM XML or Overpass JSON')
    if data.get('crs') and '4326' not in str(data['crs']) and 'CRS84' not in str(data['crs']):raise ValueError('Convert source to WGS84 / EPSG:4326 before import')
    return data['features']

def import_features(path,source,licence,epoch,city=None,review=None):
    if not source.strip() or not licence.strip():raise ValueError('Source citation and data licence are required')
    if epoch not in ['modern_baseline','historical_1940_1942']:raise ValueError('Explicit source epoch is required')
    review=review or {};output=[];skipped=[];seen=set()
    for index,feature in enumerate(read(Path(path))):
        identifier=str(feature.get('id',index))
        if identifier in seen:raise ValueError('Duplicate source feature ID: '+identifier)
        seen.add(identifier);props=dict(feature.get('properties') or {});props.update(review.get(identifier,{}))
        geom=shape(feature['geometry'])
        if geom.is_empty or not geom.is_valid:raise ValueError('Invalid/empty source geometry: '+identifier)
        minx,miny,maxx,maxy=geom.bounds
        if not all(__import__('math').isfinite(x) for x in geom.bounds) or minx<14.49 or maxx>14.56 or miny<35.86 or maxy>35.90:raise ValueError('Feature outside Cottonera study area or not WGS84: '+identifier)
        # Never mistake modern yacht marinas/new construction for wartime docks.
        date=re.search(r'\b(1[0-9]{3}|20[0-9]{2})\b',str(props.get('start_date','')))
        if props.get('leisure')=='marina' or props.get('building') in ['construction'] or (date and int(date.group())>1942 and not props.get('historical_override')):
            skipped.append(dict(id=identifier,reason='modern feature excluded'));continue
        assigned=CITIES.get(text(props.get('cottonera_city',props.get('addr:city',city or ''))))
        if assigned is None:skipped.append(dict(id=identifier,reason='city assignment requires source/review mapping'));continue
        role=classify(props)
        if role=='context':skipped.append(dict(id=identifier,reason='context only; no construction inferred'));continue
        # Unknown fortification names remain unclassified; never combine the two lines.
        props.update(cottonera_city=assigned,cottonera_role=role,source=source,licence=licence,source_epoch=epoch,historical_verified=epoch=='historical_1940_1942')
        output.append(dict(type='Feature',id=identifier,properties=props,geometry=mapping(geom)))
    return dict(type='FeatureCollection',features=output,metadata=dict(source=source,licence=licence,source_epoch=epoch,notice='Modern baseline is not proof of 1942 geometry',skipped=skipped))

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('input',type=Path);p.add_argument('--output',type=Path,required=True);p.add_argument('--source',required=True);p.add_argument('--licence',required=True);p.add_argument('--epoch',choices=['modern_baseline','historical_1940_1942'],required=True);p.add_argument('--city',choices=list(CITIES));p.add_argument('--review',type=Path)
    a=p.parse_args();data=import_features(a.input,a.source,a.licence,a.epoch,a.city,json.loads(a.review.read_text()) if a.review else None)
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(data,indent=2,allow_nan=False)+'\n');print('Imported',len(data['features']),'source features; skipped',len(data['metadata']['skipped']))
if __name__=='__main__':main()
