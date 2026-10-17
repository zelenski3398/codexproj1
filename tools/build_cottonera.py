"""Compile imported, cited Cottonera features into static collision and 3 LODs.
Empty/missing datasets produce NO invented settlement. Uses existing terrain only.
"""
from pathlib import Path
import argparse,json,hashlib
import numpy as np
import trimesh
from shapely.geometry import shape,LineString,Point,box
from shapely.ops import unary_union
from cottonera.geography import Geography,ASSET
from cottonera.models import Models,polygons,STONE
from cottonera.landscape import Landscape,lines
REQUIRED={'fort_st_angelo','gardjola','st_lawrence','inquisitors_palace','victories_basilica','immaculate_conception','cottonera_lines','santa_margherita_lines','dry_dock','road','building'}
def number(value,default):
    try:return float(str(value).split()[0])
    except (ValueError,TypeError):return default

def build(features_path,output):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    data=json.loads(Path(features_path).read_text());alignment=json.loads((ASSET/'cottonera/alignment.json').read_text())
    if data.get('metadata',{}).get('synthetic') and output.resolve().is_relative_to(ASSET.resolve()):raise ValueError('Synthetic test features cannot become shipped geographic scenery')
    if not data.get('features'):
        report={**alignment,'status':'awaiting_geodata','missing_geometry':True,'missing_roles':sorted(REQUIRED),'regions':[{**r,'chunks':[]} for r in alignment['regions']]}
        (output/'region.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n');return report
    if not data.get('metadata',{}).get('source') or not data['metadata'].get('licence'):raise ValueError('Import with source/licence provenance before building')
    g=Geography();records=[];warnings=[];roles=set()
    for f in data['features']:
        p=f.get('properties',{});city=p.get('cottonera_city');role=p.get('cottonera_role')
        if city not in ['birgu','senglea','bormla','kalkara'] or not role:raise ValueError('Explicit reviewed city/role assignment required: '+str(f.get('id')))
        geometry=g.geometry(shape(f['geometry']))
        if geometry.is_empty or not geometry.is_valid:raise ValueError('Invalid imported geometry')
        records.append((f['id'],city,role,p,geometry));roles.add(role)
    landscape=Landscape(g,records) if not data.get("metadata",{}).get("synthetic") else None
    # Source roads plus existing protected roads are physical clearance corridors.
    roads=[]
    for _,_,role,p,geometry in records:
        if role in ['road','footway']:
            width=number(p.get('width'),1.5 if role=='footway' else 4.5)
            roads.append(geometry.buffer(max(.5,width)/2+.25,cap_style=1))
    for p in json.loads((ASSET/'roads/world_paths.json').read_text())['paths']:
        roads.append(LineString(p['points']).buffer(float(p['width'])/2+.5,cap_style=1))
    clearance=unary_union(roads)
    gates=unary_union([geom.buffer(number(p.get('opening_width'),7)/2+2) for _,_,role,p,geom in records if role=='gate'])
    assets={r['id']:[] for r in alignment['regions']};built_roles=set();buildings=0;fortifications=0
    for identifier,city,role,p,original in records:
        if landscape and not landscape.keep(identifier,role,original):continue
        # Preserve/render the complete outer alignment, formerly skipped after
        # AOI clipping converted it to a MultiLineString. Source remains intact.
        if landscape and identifier==landscape.rules["outer_wall_source"]:original=landscape.outer
        m=Models();geometry=original;is_polygon=geometry.geom_type in ['Polygon','MultiPolygon']
        if role not in ['dry_dock','crane']:
            if is_polygon:geometry=geometry.intersection(g.land.buffer(-.4))
            elif geometry.geom_type=='Point' and not g.land.covers(geometry):warnings.append(f'{identifier}: source point is not on existing land');continue
        if geometry.is_empty:warnings.append(f'{identifier}: source footprint outside supplied land');continue
        if role=='dry_dock':
            if not is_polygon or original.intersection(g.land).area>original.area*.02:warnings.append(f'{identifier}: dock would require terrain excavation; not fabricated');continue
            m.dry_dock(original,number(p.get('quay_height'),4))
        elif role in ['road','footway']:
            # Visual paving follows the ACTUAL ground. Collision remains the terrain.
            width=number(p.get('width'),1.5 if role=='footway' else 4.5)
            surface=geometry.buffer(width/2).intersection(g.land)
            for poly in polygons(surface):
                minx,minz,maxx,maxz=poly.bounds
                for x in np.arange(minx,maxx,8):
                    for z in np.arange(minz,maxz,8):
                        for part in polygons(poly.intersection(box(x,z,x+8,z+8))):
                            if part.area<.02:continue
                            v,f=trimesh.creation.triangulate_polygon(part,engine='triangle');hh=g.heights(v)
                            if not np.isfinite(hh).all():continue
                            mesh=trimesh.Trimesh(np.c_[v[:,0],hh+.09,v[:,1]],f,process=False)
                            if mesh.face_normals[0,1]<0:mesh.invert()
                            m.add(mesh,[135,131,114,255],False,True)
        elif role in ['cottonera_lines','santa_margherita_lines','fortification','birgu_landfront','senglea_waterfront']:
            if not is_polygon and geometry.geom_type not in ['LineString','MultiLineString']:warnings.append(f'{identifier}: wall alignment missing');continue
            wall_lines=[poly.exterior for poly in polygons(geometry)] if is_polygon else lines(geometry)
            for line in wall_lines:
                stations=np.array([line.interpolate(t).coords[0] for t in np.linspace(0,line.length,max(2,int(line.length/12)+1))])
                for a,b in zip(stations[:-1],stations[1:]):
                    segment=LineString([a,b]);width=number(p.get('thickness'),6)
                    if segment.buffer(width/2).intersects(clearance) or segment.intersects(gates):continue
                    hh=g.heights([a,b])
                    if not np.isfinite(hh).all():continue
                    m.battered_wall(a,b,float(hh.min()-.5),float(hh.max()+number(p.get('height'),11)),width)
            fortifications+=1
        elif role in ['crane','gardjola','gate'] and geometry.geom_type=='Point':
            point=np.array(geometry.coords[0]);hh=g.heights([point])
            if not np.isfinite(hh).all():warnings.append(f'{identifier}: terrain height unavailable');continue
            if role=='crane':m.crane(point,float(hh[0]),np.deg2rad(number(p.get('bearing'),0)))
            elif role=='gate':m.gate(point,float(hh[0]),number(p.get('opening_width'),7),bearing=np.deg2rad(number(p.get('bearing'),0)))
            else:m.gardjola(Point(*point).buffer(2.5,resolution=2),float(hh[0]))
        elif is_polygon:
            if role in ['building','warehouse','church','st_lawrence','victories_basilica','immaculate_conception','inquisitors_palace']:geometry=geometry.difference(clearance)
            if geometry.is_empty:continue
            source_polygons=polygons(geometry)
            if not source_polygons:warnings.append(f'{identifier}: no valid land polygon remains');continue
            coordinates=np.concatenate([np.asarray(poly.exterior.coords) for poly in source_polygons])
            hh=g.heights(coordinates)
            if not np.isfinite(hh).all():warnings.append(f'{identifier}: terrain has no surface');continue
            bottom=float(hh.min()-.5);top=float(hh.max());height=number(p.get('height'),number(p.get('building:levels'),3)*3.2)
            if height<=0 or (role=='building' and height>30):warnings.append(f'{identifier}: invalid or potentially modern building height requires review');continue
            if role=='fort_st_angelo':m.fort_st_angelo(geometry,bottom,top)
            elif role in ['bastion','st_michael','quay']:m.bastion(geometry,bottom,top+number(p.get('platform_height'),3))
            elif role=='warehouse':m.warehouse(geometry,bottom,top+height)
            elif role in ['church','st_lawrence','victories_basilica','immaculate_conception']:m.church(geometry,bottom,top+max(15,height),role!='victories_basilica')
            elif role=='inquisitors_palace':m.palace(geometry,bottom,top+height)
            elif role=='gardjola':m.gardjola(geometry,bottom)
            elif role=='building':m.house(geometry,bottom,top+height);buildings+=1
            else:warnings.append(f'{identifier}: no model inferred for role {role}');continue
        else:warnings.append(f'{identifier}: actual footprint required for {role}');continue
        if m.mid or m.near:assets[city].append((identifier,role,m));built_roles.add(role)
    field_report={}
    if landscape:
        field_assets,field_report=landscape.fields(clearance,gates)
        for identifier,city,role,m in field_assets:assets[city].append((identifier,role,m))
    # Separate coarse collision remains loaded across all visual LOD switches.
    regions=[];all_triangles=0;collision_count=0;generated=set()
    for region in alignment['regions']:
        anchor=np.array(region['position']);anchor[1]=0;chunks={}
        for identifier,role,m in assets[region['id']]:
            for level,meshes in [('mid',m.mid),('near',m.near),('far',m.far),('collision',m.collision)]:
                for mesh in meshes:
                    centre=mesh.bounds.mean(axis=0);key=(int(centre[0]//180),int(centre[2]//180),'fields' if role=='rubble_field_wall' else 'city',level)
                    chunks.setdefault(key,[]).append(mesh)
        entries={}
        for (x,z,kind,level),meshes in sorted(chunks.items()):
            mesh=trimesh.util.concatenate(meshes);mesh.apply_translation(-anchor)
            name=f'{region["id"]}_{x}_{z}_{"fields_" if kind=="fields" else ""}{level}.glb';generated.add(name);scene=trimesh.Scene(mesh);(output/name).write_bytes(scene.export(file_type='glb'))
            path='res://'+str((output/name).resolve().relative_to(ASSET.parent.parent)) if (output/name).resolve().is_relative_to(ASSET.parent.parent) else str(output/name)
            entry=entries.setdefault((x,z,kind),{});entry[level]=path
            if kind=="fields":entry["detail_type"]="fields"
            if level=='collision':collision_count+=1
            else:all_triangles+=len(mesh.faces)
        regions.append({**region,'status':'partial_geodata' if entries else 'awaiting_geodata','chunks':list(entries.values())})
    # Purge only stale generated chunk files, including orphaned import metadata.
    for region in alignment['regions']:
        for stale in output.glob(region['id']+'_*.glb'):
            if stale.name not in generated:
                stale.unlink()
                imported=Path(str(stale)+'.import')
                if imported.exists():imported.unlink()
    missing=sorted(REQUIRED-built_roles)
    missing_cities=[city for city in ['birgu','senglea','bormla'] if not assets[city]]
    report={**alignment,'regions':regions,'status':'partial_geodata' if missing or missing_cities else 'source_baseline_built','missing_geometry':bool(missing or missing_cities),'missing_cities':missing_cities,'missing_roles':missing,'building_count':buildings,'fortification_count':fortifications,'collision_chunks':collision_count,'source_triangles':all_triangles,'warnings':warnings,'source_metadata':data['metadata'],'source_geojson_sha256':hashlib.sha256(Path(features_path).read_bytes()).hexdigest()}
    if landscape:report['landscape']={**landscape.metadata(),'fields':field_report}
    (output/'region.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n');return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--features',type=Path,default=ASSET/'cottonera/features.geojson');p.add_argument('--output',type=Path,default=ASSET/'cottonera');a=p.parse_args()
    report=build(a.features,a.output);print(json.dumps({k:v for k,v in report.items() if k not in ['regions','source_hashes','landscape']},indent=2))
if __name__=='__main__':main()
