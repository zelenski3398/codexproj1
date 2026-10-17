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
from shapely import STRtree
from cottonera.geography import Geography,ASSET
from cottonera.landscape import stone_batch,lines
from cottonera.models import polygons
from grade_malta_terrain import GroundSampler
ROOT=ASSET.parent.parent
OUT=ASSET/'countryside'
SOILS=np.array([[121,77,53,255],[143,86,57,255],[110,73,52,255],[156,106,70,255],[133,112,69,255],[117,121,74,255]])
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
                vertices,faces=trimesh.creation.triangulate_polygon(part,engine='triangle')
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

def split_axis(length,rng,settings,narrow=False):
    positions=[-length/2]
    while positions[-1]<length/2:
        kind=rng.choice(['small','medium','large'],p=[.3,.65,.05] if narrow else [.16,.67,.17])
        width=rng.uniform(*settings[kind+'_width_m'])
        if positions[-1]+width>length/2:
            if length/2-positions[-1]<12:positions[-1]=length/2;break
            width=length/2-positions[-1]
        positions.append(positions[-1]+width)
    return positions

def build(output=OUT):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    settings=json.loads((OUT/'settings.json').read_text());rng=np.random.default_rng(settings['seed']);g=RuralGeography()
    allowed,excluded,routes=masks(g,settings)
    # Broad rural clusters, separated by open country. Local roads/contours
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
            gozo=p[1]<-6500
            if distance>1700 and not gozo:continue
            if np.linalg.norm(gradient)>.055:direction=np.array([-gradient[1],gradient[0]]);basis='terrain contour'
            else:
                road=min(routes,key=lambda r:r.distance(Point(*p)))
                t=road.project(Point(*p));direction=np.array(road.interpolate(min(road.length,t+12)).coords[0])-np.array(road.interpolate(max(0,t-12)).coords[0]);basis='nearby road' if distance<1700 else 'regional road orientation, inferred'
            angle=np.arctan2(direction[1],direction[0])+rng.uniform(-.13,.13)
            candidates.append((p,float(h),gradient,float(angle),basis))
    rng.shuffle(candidates)
    dispersed=[]
    for candidate in candidates:
        if all(np.linalg.norm(candidate[0]-other[0])>440 for other in dispersed):dispersed.append(candidate)
        if len(dispersed)>=settings['maximum_clusters']:break
    candidates=dispersed
    plots=[];tracks=[];clusters=[]
    for index,(centre,height,gradient,angle,basis) in enumerate(candidates):
        length=rng.uniform(*settings['cluster_size_m']);breadth=rng.uniform(*settings['cluster_size_m'])
        rotation=np.array([[np.cos(angle),-np.sin(angle)],[np.sin(angle),np.cos(angle)]])
        xs=split_axis(length,rng,settings);zs=split_axis(breadth,rng,settings,np.linalg.norm(gradient)>.065)
        nodes=np.array([[[x,z] for z in zs] for x in xs],dtype=float)
        # Shared nodes remain watertight, but rows/columns drift coherently and
        # outer edges are uneven rather than a rectangular checkerboard tile.
        nodes[:,:,0]+=rng.uniform(-6,6,(1,len(zs)))
        nodes[:,:,1]+=rng.uniform(-4,4,(len(xs),1))
        nodes+=rng.uniform(-2.0,2.0,nodes.shape)
        nodes=nodes@rotation.T+centre
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
        cells=[]
        for i in range(len(xs)-1):
            j=0
            while j<len(zs)-1:
                poly=Polygon([nodes[i,j],nodes[i+1,j],nodes[i+1,j+1],nodes[i,j+1]])
                if j<len(zs)-2 and rng.random()<.22:
                    neighbour=Polygon([nodes[i,j+1],nodes[i+1,j+1],nodes[i+1,j+2],nodes[i,j+2]])
                    poly=poly.union(neighbour);j+=1
                cells.append(poly);j+=1
        for poly in cells:
            if not poly.is_valid or poly.area<settings['minimum_plot_area_m2'] or not allowed.covers(poly.buffer(1.2)):continue
            # Field access breaks follow the lane without inventing complex
            # polygons: the remaining convex pieces retain quadrilateral form.
            raw_parts=[poly]
            if len(poly.exterior.coords)==5 and rng.random()<.32 and poly.area>700:
                corners=np.array(poly.exterior.coords)[:4];ratio=rng.uniform(.35,.65)
                if np.linalg.norm(corners[1]-corners[0])<np.linalg.norm(corners[2]-corners[1]):corners=np.roll(corners,-1,axis=0)
                p=corners[0]+(corners[1]-corners[0])*ratio;q=corners[3]+(corners[2]-corners[3])*ratio
                raw_parts=[Polygon([corners[0],p,q,corners[3]]),Polygon([p,corners[1],corners[2],q])]
            parts=[part for raw_part in raw_parts for part in polygons(raw_part.difference(track_clear))]
            for part in parts:
                if part.area<settings['minimum_plot_area_m2'] or len(part.exterior.coords)>7:continue
                points=np.array(part.exterior.coords);hh=g.heights(points)
                if not np.isfinite(hh).all():continue
                grads=np.array([g.gradient(p) for p in points[:-1]])
                if not np.isfinite(grads).all() or np.max(np.linalg.norm(grads,axis=1))>settings['maximum_plot_slope'] or g.maximum_slope(part)>settings['maximum_plot_slope']:continue
                colour=SOILS[rng.choice(len(SOILS),p=[.25,.22,.18,.17,.1,.08])].copy();colour[:3]=np.clip(colour[:3]+rng.integers(-5,6),0,255)
                plots.append(dict(cluster=index,polygon=part,colour=colour.tolist(),terraced=bool(np.linalg.norm(gradient)>.065),angle=angle));count+=1
        if count:clusters.append(dict(id=index,centre=[float(centre[0]),height,float(centre[1])],angle=angle,orientation_basis=basis,plots=count))
    # One shared edge graph, then selected walls and deliberate access gaps.
    edge_graph=unary_union([p['polygon'].boundary for p in plots]);edges=lines(edge_graph);rng.shuffle(edges)
    sections=[];wall_length=0.0;track_mask=unary_union(tracks).buffer(2.2)
    for edge in edges:
        if edge.length<5 or rng.random()>settings['wall_probability']:continue
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
        if wall_length>=settings['maximum_wall_length_m']-2:break
    chunks={}
    def chunk_at(point):
        key=tuple(np.floor(np.asarray(point)/300).astype(int));return chunks.setdefault(key,dict(soil=[],track=[],sections=[]))
    for record in plots:
        mesh=g.drape(record['polygon'],record['colour'])
        if mesh is not None:chunk_at(record['polygon'].centroid.coords[0])['soil'].append(mesh)
    for part in tracks:
        mesh=g.drape(part,[151,125,88,255],.065)
        if mesh is not None:chunk_at(part.centroid.coords[0])['track'].append(mesh)
    for a,b,h in sections:chunk_at((a+b)/2)['sections'].append((a,b,h))
    entries=[];generated=set();triangles={}
    for (x,z),chunk in sorted(chunks.items()):
        origin=np.array([x*300,0,z*300]);entry=dict(origin=origin.tolist(),centre=[x*300+150,0,z*300+150],files={})
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
    report=dict(version=1,seed=settings['seed'],units='metres',inferred=True,note='Plausible 1940-42 agricultural scenery, not mapped parcels. Contour strips suggest terraces; original ground elevation is unchanged.',settings=settings,clusters=clusters,plots=[dict(cluster=p['cluster'],footprint=mapping(p['polygon']),colour=p['colour'],terraced=p['terraced'],angle=p['angle']) for p in plots],tracks=[mapping(p) for p in tracks],sections=[dict(a=[float(a[0]),float(h[0]),float(a[1])],b=[float(b[0]),float(h[2]),float(b[1])]) for a,b,h in sections],wall_length_m=float(wall_length),chunks=entries,triangles=triangles,source_hashes={p:hashlib.sha256((ASSET/p).read_bytes()).hexdigest() for p in protected_files})
    (output/'manifest.json').write_text(json.dumps(report,indent=2,allow_nan=False,default=numpy_scalar)+'\n')
    print(json.dumps(dict(clusters=len(clusters),plots=len(plots),tracks=len(tracks),wall_m=wall_length,chunks=len(entries),triangles=triangles)),flush=True)
    return report
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,default=OUT);build(parser.parse_args().output)
