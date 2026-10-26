"""Deterministic inferred rural plots draped over EXISTING island triangles.
Never modifies terrain/roads/cities. Produces batched scenery and strip collision.
"""
from pathlib import Path
import json,hashlib,argparse
import numpy as np
import trimesh
from scipy.spatial import cKDTree
from shapely.geometry import Polygon,Point,LineString,box,mapping,shape
from shapely.ops import unary_union,polygonize
from shapely.affinity import affine_transform
from rural_parcels import parcel_group
from shapely import STRtree,constrained_delaunay_triangles
from cottonera.geography import Geography,ASSET
from cottonera.landscape import stone_batch,lines
from cottonera.models import polygons
from grade_malta_terrain import GroundSampler
ROOT=ASSET.parent.parent
OUT=ASSET/'countryside'
SOILS=np.array([[129,104,77,255],[143,117,85,255],[120,106,78,255],[143,124,91,255],[128,118,85,255],[116,121,89,255]])
def numpy_scalar(value):
    if isinstance(value,np.generic):return value.item()
    raise TypeError('Unexpected manifest value: '+type(value).__name__)
class RuralGeography(Geography):
    def __init__(self):
        super().__init__()
        coast=json.loads((ASSET/'source/Malta-Coastline.geojson').read_text())
        self.land=self.geometry(unary_union(list(polygonize(unary_union([shape(f['geometry']) for f in coast['features']])))))
        scene=trimesh.load(ASSET/'terrain.glb',force='scene',process=False)
        self.samplers=[self.sampler]+[GroundSampler(scene.geometry[name]) for name in ['Gozo','Comino']]
        self.ground_polys=[]
        self.ground_slopes=[]
        for name,sampler in zip(["Malta","Gozo","Comino"],self.samplers):
            t=sampler.triangulation
            self.ground_polys.extend(Polygon(p) for p in np.c_[t.x,t.y][t.triangles])
            vertices=np.c_[t.x,scene.geometry[name].vertices[sampler.top_indices,1],t.y]
            triangle=vertices[t.triangles]
            normal=np.cross(triangle[:,1]-triangle[:,0],triangle[:,2]-triangle[:,0])
            self.ground_slopes.extend((np.linalg.norm(normal[:,[0,2]],axis=1)/np.maximum(abs(normal[:,1]),1e-8)).tolist())
        self.tree=STRtree(self.ground_polys)
    def heights(self,points):
        points=np.asarray(points,dtype=float)
        answer=self.sampler.heights(points)
        for sampler in self.samplers[1:]:
            missing=~np.isfinite(answer)
            if missing.any():answer[missing]=sampler.heights(points[missing])
        missing=~np.isfinite(answer)
        if missing.any():answer[missing]=super().heights(points[missing])
        return answer
    def gradient(self,p):
        p=np.asarray(p,dtype=float)
        h=self.heights(np.array([p+[8,0],p-[8,0],p+[0,8],p-[0,8]]))
        return np.array([(h[0]-h[1])/16,(h[2]-h[3])/16])
    def maximum_slope(self,poly):
        indices=self.tree.query(poly,predicate="intersects")
        return max((self.ground_slopes[i] for i in indices),default=float("inf"))
    def drape(self,poly,colour,offset=.045):
        vv=[];ff=[];count=0
        for index in self.tree.query(poly,predicate='intersects'):
            for part in polygons(poly.intersection(self.ground_polys[index])):
                if part.area<.005:continue
                part=part.simplify(1e-7,preserve_topology=True)
                triangles=list(constrained_delaunay_triangles(part).geoms)
                if not triangles:continue
                vertices=np.concatenate([np.asarray(t.exterior.coords)[:3] for t in triangles])
                faces=np.arange(len(vertices)).reshape(-1,3)
                h=self.heights(vertices)
                if not np.isfinite(h).all():continue
                vv.append(np.c_[vertices[:,0],h+offset,vertices[:,1]]);ff.append(faces+count);count+=len(vertices)
        if not vv:return None
        mesh=trimesh.Trimesh(np.concatenate(vv),np.concatenate(ff),process=False)
        if np.mean(mesh.face_normals[:,1])<0:mesh.invert()
        mesh.visual.vertex_colors=np.tile(colour,(len(mesh.vertices),1))
        return mesh

def masks(g,settings):
    protected=[];data=g.data
    for field in data['airfields']:
        # Covers runway, taxi area, parking, truck, six AA and director positions.
        p=np.array(field['position'])[[0,2]];angle=np.deg2rad(field['heading']);c,s=np.cos(angle),np.sin(angle)
        rotation=np.array([[c,-s],[s,c]])
        local=np.array([[-240,-field['length']/2-230],[240,-field['length']/2-230],[240,field['length']/2+230],[-240,field['length']/2+230]])
        protected.append(Polygon(local@rotation.T+p))
    for city in ['valletta','mdina']:
        layout=json.loads((ASSET/city/'layout.json').read_text());origin=np.array(layout['origin_world'])[[0,2]]
        bounds=np.array(layout.get('city_bounds',layout.get('bounds')))
        protected.append(box(*(bounds[0,[0,2]]+origin),*(bounds[1,[0,2]]+origin)).buffer(90))
    from prepare_supplied_cottonera import AOI
    protected.append(g.geometry(AOI).buffer(90)) # Includes its existing inferred fields.
    for lon,lat,radius,name in settings['urban_buffers_lon_lat_m']:protected.append(Point(*g.xz(lon,lat)).buffer(radius))
    routes=[]
    for record in json.loads((ASSET/'roads/world_paths.json').read_text())['paths']:
        line=LineString(record['points']);routes.append(line)
        protected.append(line.buffer(float(record['width'])/2+settings['road_field_margin_m']))
    # All supplied structures, including outside the Cottonera editorial AOI,
    # are exclusion evidence only, not extra scenery or municipal boundaries.
    for feature in json.loads((ASSET/'cottonera/source/supplied-cottonera.geojson').read_text())['features']:
        p=feature['properties']
        if p.get('building') or p.get('historic') in ['fort','citywalls'] or p.get('barrier')=='city_wall':
            geom=g.geometry(shape(feature['geometry']))
            protected.append(geom.buffer(16))
    exclusion=unary_union(protected)
    allowed=g.land.buffer(-settings['coast_guard_m']).difference(exclusion)
    return allowed,exclusion,routes

def build(output=OUT):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    settings=json.loads((OUT/'settings.json').read_text());rng=np.random.default_rng(settings['seed']);g=RuralGeography()
    allowed,excluded,routes=masks(g,settings)
    domain_allowed=allowed.buffer(-1.25)
    # Broad rural clusters across ALL safe countryside. Local roads/contours
    # orient plots; source painted parcels are not cadastral boundaries.
    samples=np.concatenate([np.array(line.coords)[::max(1,len(line.coords)//80)] for line in routes]);road_tree=cKDTree(samples)
    candidates=[];spacing=settings['cluster_spacing_m'];bounds=allowed.bounds
    for x in np.arange(bounds[0],bounds[2],spacing):
        for z in np.arange(bounds[1],bounds[3],spacing):
            p=np.array([x,z])+rng.uniform(-145,145,2)
            if not allowed.contains(Point(*p)) or rng.random()>settings['cluster_probability']:continue
            h=g.heights([p])[0];gradient=g.gradient(p)
            if not np.isfinite(h) or h<8 or not np.isfinite(gradient).all() or np.linalg.norm(gradient)>settings['maximum_cluster_slope']:continue
            distance,index=road_tree.query(p)
            # Remote countryside is valid too; road distance is an orientation
            # hint, never a requirement that leaves whole rural regions bare.
            if np.linalg.norm(gradient)>.055:direction=np.array([-gradient[1],gradient[0]]);basis='terrain contour'
            else:
                road=min(routes,key=lambda r:r.distance(Point(*p)))
                t=road.project(Point(*p));direction=np.array(road.interpolate(min(road.length,t+12)).coords[0])-np.array(road.interpolate(max(0,t-12)).coords[0]);basis='nearby road' if distance<1700 else 'regional road orientation, inferred'
            angle=np.arctan2(direction[1],direction[0])+rng.uniform(-.13,.13)
            candidates.append((p,float(h),gradient,float(angle),basis))
    eligible_centres=[candidate[0].copy() for candidate in candidates]
    rng.shuffle(candidates)
    dispersed=[]
    for candidate in candidates:
        if all(np.linalg.norm(candidate[0]-other[0])>settings.get('minimum_cluster_separation_m',440) for other in dispersed):dispersed.append(candidate)
        if len(dispersed)>=settings['maximum_clusters']:break
    candidates=dispersed
    plots=[];tracks=[];clusters=[];occupied_domains=[]
    for index,(centre,height,gradient,angle,basis) in enumerate(candidates):
        length=rng.uniform(*settings['cluster_size_m']);breadth=rng.uniform(*settings['cluster_size_m'])
        rotation=np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])
        cells=[affine_transform(p,[rotation[0,0],rotation[0,1],rotation[1,0],rotation[1,1],*centre]) for p in parcel_group(length,breadth,rng,settings)]
        # Clip against real roads/coast/protected areas, not merely centroids.
        domain=unary_union(cells).intersection(domain_allowed)
        nearby=[p for p in occupied_domains if p.intersects(domain)]
        if nearby:domain=domain.difference(unary_union(nearby))
        occupied_domains.append(domain.buffer(1.5))
        cluster_tint=rng.integers(-3,4,size=3)
        # A transverse dirt access lane with a spur to an existing rural road.
        end_a=centre+rotation@np.array([-length/2,0]);end_b=centre+rotation@np.array([length/2,0])
        road=min(routes,key=lambda r:r.distance(Point(*end_a)))
        connection=np.array(road.interpolate(road.project(Point(*end_a))).coords[0])
        track=LineString([end_b,centre,end_a])
        if np.linalg.norm(connection-end_a)<320:track=LineString([end_b,centre,end_a,connection])
        track_polys=track.buffer(settings["dirt_track_width_m"]/2,cap_style=2).intersection(allowed)
        for part in polygons(track_polys.buffer(-.01)):
            # Tiny inset makes strict exclusion robust after JSON round-trips.
            hh=g.heights(np.asarray(part.exterior.coords))
            if np.isfinite(hh).all() and g.maximum_slope(part)<.36:tracks.append(part)
        track_clear=track.buffer(3.8)
        count=0
        for poly in cells:
            if not poly.is_valid or poly.area<settings['minimum_plot_area_m2']:continue
            parts=[part for part in polygons(poly.intersection(domain).difference(track_clear))]
            for part in parts:
                part=part.simplify(1e-6,preserve_topology=True)
                if part.area<settings['minimum_plot_area_m2'] or len(part.exterior.coords)>18 or part.area/part.minimum_rotated_rectangle.area<.45:continue
                points=np.array(part.exterior.coords);hh=g.heights(points)
                if not np.isfinite(hh).all():continue
                grads=np.array([g.gradient(p) for p in points[:-1]])
                if not np.isfinite(grads).all() or np.max(np.linalg.norm(grads,axis=1))>settings['maximum_plot_slope'] or g.maximum_slope(part)>settings['maximum_plot_slope']:continue
                colour=SOILS[rng.choice(len(SOILS),p=[.25,.22,.18,.17,.1,.08])].copy();colour[:3]=np.clip(colour[:3]+cluster_tint+rng.integers(-3,4,size=3),0,255)
                plots.append(dict(cluster=index,polygon=part,colour=colour.tolist(),terraced=bool(np.linalg.norm(gradient)>.065),angle=angle));count+=1
        if count:clusters.append(dict(id=index,centre=[float(centre[0]),height,float(centre[1])],angle=angle,orientation_basis=basis,plots=count))
    # One shared edge graph, then selected walls and deliberate access gaps.
    edge_graph=unary_union([p['polygon'].boundary for p in plots]);edges=lines(edge_graph);rng.shuffle(edges)
    # Spend the wall budget throughout the islands, rather than exhausting it
    # on whichever region happens to occur first in the edge graph.
    regional_edges={}
    for edge in edges:
        key=tuple(np.floor(np.asarray(edge.centroid.coords[0])/2500).astype(int))
        regional_edges.setdefault(key,[]).append(edge)
    edges=[]
    while any(regional_edges.values()):
        for group in regional_edges.values():
            if group:edges.append(group.pop())
    region_lengths={}
    sections=[];wall_length=0.0;track_mask=unary_union(tracks).buffer(2.2)
    for edge in edges:
        region=tuple(np.floor(np.asarray(edge.centroid.coords[0])/2500).astype(int))
        if edge.length<5 or (region_lengths.get(region,0)>=20 and rng.random()>settings['wall_probability']):continue
        stations=np.linspace(0,edge.length,max(2,int(np.ceil(edge.length/settings['section_length_m']))+1))
        access_gap=rng.uniform(*settings['access_gap_m'])
        for a,b in zip(stations[:-1],stations[1:]):
            # Leave a 3.6 m opening in each substantial selected boundary.
            if abs((a+b)/2-edge.length*.53)<access_gap/2:continue
            p=np.array(edge.interpolate(a).coords[0]);q=np.array(edge.interpolate(b).coords[0]);length=np.linalg.norm(q-p)
            footprint=LineString([p,q]).buffer(1.1,cap_style=2)
            if not allowed.covers(footprint) or footprint.intersects(track_mask):continue
            h=g.heights([p,(p+q)/2,q])
            if not np.isfinite(h).all() or np.ptp(h)>.55 or abs(h[1]-(h[0]+h[2])/2)>.1:continue
            if wall_length+length>settings['maximum_wall_length_m']:break
            sections.append((p,q,h));wall_length+=length
            region_lengths[region]=region_lengths.get(region,0)+length
        if wall_length>=settings['maximum_wall_length_m']-2:break
    print('PARCELS',len(plots),'clusters',len(clusters),'median area',float(np.median([p['polygon'].area for p in plots])),flush=True)
    chunks={};chunk_size=settings.get('chunk_size_m',300)
    def chunk_at(point):
        key=tuple(np.floor(np.asarray(point)/chunk_size).astype(int));return chunks.setdefault(key,dict(soil=[],track=[],sections=[]))
    for record in plots:
        mesh=g.drape(record['polygon'],record['colour'])
        if mesh is not None:chunk_at(record['polygon'].centroid.coords[0])['soil'].append(mesh)
    for part in tracks:
        mesh=g.drape(part,[151,125,88,255],.065)
        if mesh is not None:chunk_at(part.centroid.coords[0])['track'].append(mesh)
    for a,b,h in sections:chunk_at((a+b)/2)['sections'].append((a,b,h))
    entries=[];generated=set();triangles={}
    for (x,z),chunk in sorted(chunks.items()):
        origin=np.array([x*chunk_size,0,z*chunk_size]);entry=dict(origin=origin.tolist(),centre=[(x+.5)*chunk_size,0,(z+.5)*chunk_size],files={})
        meshes={k:chunk[k] for k in ['soil','track']}
        if chunk['sections']:
            walls=stone_batch(chunk['sections'],settings['wall'],rng)
            meshes.update({k:getattr(walls,k) for k in ['near','mid','far','collision']})
        for kind,items in meshes.items():
            if not items:continue
            mesh=trimesh.util.concatenate(items)
            if kind in ['soil','mid']:entry['centre'][1]=float(mesh.bounds[:,1].mean())
            mesh.apply_translation(-origin)
            _=mesh.vertex_normals # GLB exporter otherwise omits NORMAL and stones render flat.
            name=f'farm_{x}_{z}_{kind}.glb';generated.add(name);(output/name).write_bytes(trimesh.Scene(mesh).export(file_type='glb'))
            entry['files'][kind]='res://assets/malta/countryside/'+name
            triangles[kind]=triangles.get(kind,0)+len(mesh.faces)
        entries.append(entry)
    for stale in output.glob('farm_*.glb'):
        if stale.name not in generated:
            stale.unlink();metadata=Path(str(stale)+'.import')
            if metadata.exists():metadata.unlink()
    protected_files=['terrain.glb','world_data.json','roads/world_paths.json','valletta/layout.json','mdina/layout.json','cottonera/region.json','landscape/landcover.png']
    coverage={}
    def coverage_at(point):
        key=tuple(np.floor(np.asarray(point)/2500).astype(int))
        return coverage.setdefault(key,dict(cell=list(key),eligible_centres=0,clusters=0,plots=0,wall_m=0.0))
    for point in eligible_centres:coverage_at(point)['eligible_centres']+=1
    for cluster in clusters:
        cell=coverage_at(cluster['centre'][::2]);cell['clusters']+=1;cell['plots']+=cluster['plots']
    for a,b,h in sections:coverage_at((a+b)/2)['wall_m']+=float(np.linalg.norm(b-a))
    from rural_vegetation import place_vegetation
    vegetation=place_vegetation(g,allowed,plots,tracks,sections,clusters,settings)
    (output/'trees.json').write_text(json.dumps(vegetation,indent=2,allow_nan=False,default=numpy_scalar)+'\n')
    report=dict(version=3,seed=settings['seed'],units='metres',inferred=True,note='Recursive unequal, road-clipped parcels. Plausible 1940-42 agricultural scenery, not mapped parcels. Contour strips suggest terraces; original ground elevation is unchanged.',settings=settings,vegetation=dict(count=len(vegetation['trees']),species_counts=vegetation['species_counts']),coverage_cells=list(coverage.values()),clusters=clusters,plots=[dict(cluster=p['cluster'],footprint=mapping(p['polygon']),colour=p['colour'],terraced=p['terraced'],angle=p['angle']) for p in plots],tracks=[mapping(p) for p in tracks],sections=[dict(a=[float(a[0]),float(h[0]),float(a[1])],b=[float(b[0]),float(h[2]),float(b[1])]) for a,b,h in sections],wall_length_m=float(wall_length),chunks=entries,triangles=triangles,source_hashes={p:hashlib.sha256((ASSET/p).read_bytes()).hexdigest() for p in protected_files})
    (output/'manifest.json').write_text(json.dumps(report,indent=2,allow_nan=False,default=numpy_scalar)+'\n')
    print(json.dumps(dict(clusters=len(clusters),plots=len(plots),tracks=len(tracks),wall_m=wall_length,chunks=len(entries),triangles=triangles)),flush=True)
    return report
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=OUT);build(parser.parse_args().output)
