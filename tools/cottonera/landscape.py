"""Reviewed outer-line enclosure and explicitly inferred dry-stone field layout.
Only the Cottonera compiler consumes these rules; source geography is read-only.
"""
import json
import numpy as np
import trimesh
from shapely import voronoi_polygons
from shapely.geometry import shape, Polygon, LineString, MultiPoint, box, mapping
from shapely.ops import unary_union
from .geography import ASSET
from .models import Models, polygons
BUILDING_ROLES={'building','warehouse','church','st_lawrence','victories_basilica','immaculate_conception','inquisitors_palace'}

def lines(geometry):
    if geometry.is_empty:return []
    if geometry.geom_type in ('LineString','LinearRing'):return [LineString(geometry.coords)]
    if hasattr(geometry,'geoms'):return [line for part in geometry.geoms for line in lines(part)]
    return []

class Landscape:
    def __init__(self,g,records):
        self.g=g
        self.rules=json.loads((ASSET/'cottonera/landscape_rules.json').read_text())
        source=json.loads((ASSET/'cottonera/source/supplied-cottonera.geojson').read_text())
        lookup={f['id']:f for f in source['features']}
        self.outer=g.geometry(shape(lookup[self.rules['outer_wall_source']]['geometry']))
        a=lookup[self.rules['outer_wall_source']]['geometry']['coordinates']
        b=lookup[self.rules['harbour_landfront_source']]['geometry']['coordinates'][:self.rules['harbour_landfront_end_vertex']+1]
        self.boundary=g.geometry(Polygon(a+b+self.rules['closure_lon_lat']+[a[0]]))
        assert self.boundary.is_valid,'Reviewed enclosure must be simple and unmirrored'
        self.audit=[];self.accepted=[];self.removed_probes=[]
        self.records=records
    def keep(self,identifier,role,geometry):
        if role not in BUILDING_ROLES:return True
        if self.boundary.covers(geometry):
            self.accepted.append(identifier);return True
        overlap=geometry.intersection(self.boundary).area
        if overlap>1e-5:
            review=self.rules['crossing_reviews'].get(identifier)
            if not review:raise ValueError('Footprint crosses Cottonera enclosure and needs individual review: '+identifier)
            assert review['action']=='remove','Only whole-building removal is currently reviewed'
            self.audit.append(dict(id=identifier,classification='crossing',inside_area_m2=overlap,footprint_area_m2=geometry.area,**review))
        else:
            self.audit.append(dict(id=identifier,classification='outside',action='remove'))
            point=np.asarray(geometry.representative_point().coords[0]);height=self.g.heights([point])[0]
            if np.isfinite(height):self.removed_probes.append(dict(id=identifier,position=[float(point[0]),float(height),float(point[1])]))
        return False
    def metadata(self):
        boundary=[]
        points=np.asarray(self.boundary.exterior.coords)
        heights=self.g.heights(points)
        for (x,z),y in zip(points,heights):boundary.append([float(x),float(y+2 if np.isfinite(y) else 4),float(z)])
        return dict(outer_wall_source=self.rules['outer_wall_source'],harbour_landfront_source=self.rules['harbour_landfront_source'],
                    inner_wall_sources_excluded=self.rules['inner_wall_sources_excluded_from_boundary'],closure_note=self.rules['closure_note'],
                    boundary_xz=mapping(self.boundary),debug_points=boundary,accepted_building_ids=self.accepted,removed_buildings=self.audit,removed_building_probes=self.removed_probes)
    def fields(self,road_clearance,gates):
        config=self.rules['fields'];rng=np.random.default_rng(config['seed'])
        from prepare_supplied_cottonera import AOI
        extent=self.g.geometry(AOI)
        preserved=[]
        for _,_,role,p,geometry in self.records:
            if role not in BUILDING_ROLES and role not in ('road','footway'):
                preserved.append(geometry.buffer(config['fortification_margin_m']))
            elif role in BUILDING_ROLES and self.boundary.covers(geometry):preserved.append(geometry.buffer(4))
        exclusions=unary_union([road_clearance.buffer(config['road_margin_m']),gates.buffer(14),*preserved])
        domain=extent.intersection(self.g.land.buffer(-config['coast_margin_m'])).intersection(self.outer.buffer(config['outer_wall_distance_m'])).difference(self.boundary.buffer(16)).difference(exclusions)
        minx,minz,maxx,maxz=extent.bounds;spacing=config['spacing_m'];seeds=[]
        for x in np.arange(minx-spacing,maxx+spacing,spacing):
            for z in np.arange(minz-spacing,maxz+spacing,spacing):seeds.append([x+rng.uniform(-spacing*.28,spacing*.28),z+rng.uniform(-spacing*.28,spacing*.28)])
        cells=voronoi_polygons(MultiPoint(seeds),extend_to=extent.envelope)
        plots=[]
        for cell in cells.geoms:
            plots.extend(p for p in polygons(cell.intersection(domain)) if p.area>=config['minimum_plot_area_m2'])
        # Union nodes shared edges ONCE; do not derive fields from house footprints.
        edges=unary_union([p.boundary for p in plots]) if plots else LineString()
        # Remove short road/obstacle-facing scraps; periodic 4 m access gaps are
        # retained even for an isolated field without a mapped access path.
        sections=[]
        land_clear=self.g.land.buffer(-8)
        for line in lines(edges):
            if line.length<8:continue
            stations=np.linspace(0,line.length,max(2,int(np.ceil(line.length/config['section_length_m']))+1))
            gap=(line.length/2 if line.length<80 else 38)
            for t,u in zip(stations[:-1],stations[1:]):
                middle=(t+u)/2
                if abs(middle-gap)<2.1 or (line.length>100 and int(middle)%95<4):continue
                a=np.array(line.interpolate(t).coords[0]);b=np.array(line.interpolate(u).coords[0])
                # Buffered core/detail/collider all remain clear, not just centre.
                footprint=LineString([a,b]).buffer(.5,cap_style=2)
                if not land_clear.covers(footprint) or footprint.intersects(exclusions) or footprint.intersects(self.boundary):continue
                heights=self.g.heights([a,(a+b)/2,b])
                if not np.isfinite(heights).all() or np.ptp(heights)>.8:continue
                sections.append((a,b,heights))
        grouped={};section_data=[]
        for a,b,hh in sections:
            key=tuple(np.floor((a+b)/2/180).astype(int));grouped.setdefault(key,[]).append((a,b,hh))
            section_data.append(dict(a=[float(a[0]),float(hh[0]),float(a[1])],b=[float(b[0]),float(hh[2]),float(b[1])]))
        assets=[]
        for key,values in sorted(grouped.items()):assets.append((f'inferred_fields_{key[0]}_{key[1]}','bormla','rubble_field_wall',stone_batch(values,config,rng)))
        return assets,dict(inferred=True,notice='Editorial irregular Voronoi plots, not mapped/historical cadastral boundaries; independent of removed building footprints.',seed=config['seed'],plot_count=len(plots),wall_section_count=len(sections),wall_length_m=sum(np.linalg.norm(b-a) for a,b,_ in sections),plots_xz=[mapping(p) for p in plots],sections=section_data,configuration=config)

# Reused eight-vertex tapered/rugged stone topology. One merged mesh per 180 m
# batch/LOD and coarse static wall strips: never individual stone physics bodies.
FACES=np.array([[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]])[:, ::-1]
ROCK=trimesh.creation.icosphere(subdivisions=0)
ROCK_VERTICES=ROCK.vertices/np.max(np.abs(ROCK.vertices),axis=0)/2
ROCK_FACES=ROCK.faces[:, ::-1] # Local along-wall/up/normal basis reverses handedness.
def stone_batch(sections,config,rng):
    arrays={level:[[],[],[]] for level in ('mid','near','far','collision')}
    colours=np.array([[184,177,156,255],[164,161,146,255],[198,188,161,255],[176,169,147,255],[190,184,164,255]])
    def add(level,a,b,ya,yb,base,top,width0,width1,rough=False):
        direction=b-a;length=np.linalg.norm(direction)
        if length<.02:return
        normal=np.array([direction[1],-direction[0]])/length
        lower=np.array([a+normal*width0/2,b+normal*width0/2,b-normal*width0/2,a-normal*width0/2])
        upper=np.array([a+normal*width1/2,b+normal*width1/2,b-normal*width1/2,a-normal*width1/2])
        if level=='near':
            # Twelve-vertex irregular rock, with broken/sloping faces instead of
            # a cut rectangular front. Shared reusable topology is only 20 tris.
            template=ROCK_VERTICES
            t=template[:,0]+.5
            rise=template[:,1]+.5
            width=width0+(width1-width0)*rise
            points=a[None,:]+t[:,None]*(b-a)[None,:]+template[:,2,None]*normal[None,:]*width[:,None]
            vertices=np.c_[points[:,0],ya+(yb-ya)*t+base+(top-base)*rise,points[:,1]]
            faces=ROCK_FACES
        else:
            vertices=np.vstack([np.c_[lower[:,0],[ya+base,yb+base,yb+base,ya+base],lower[:,1]],np.c_[upper[:,0],[ya+top,yb+top,yb+top,ya+top],upper[:,1]]])
            faces=FACES
        if rough:vertices+=rng.uniform(-.025,.025,vertices.shape)
        v,f,c=arrays[level];offset=len(v)*(12 if level=='near' else 8)
        v.append(vertices);f.append(faces+offset);c.append(np.tile(colours[rng.integers(len(colours))],(len(faces),1)))
    for a,b,hh in sections:
        height=rng.uniform(config['height_min_m'],config['height_max_m'])
        w0=config['base_width_m'];w1=config['top_width_m']
        add('collision',a,b,hh[0],hh[2],-.16,height,w0,w1)
        add('far',a,b,hh[0],hh[2],-.12,height,w0,w1,True)
        # Mid-distance silhouette has three irregular wider-base courses.
        for row in range(3):
            t=row/3;add('mid',a,b,hh[0],hh[2],-.1+t*height,(row+1)/3*height,w0+(w1-w0)*t,w0+(w1-w0)*(t+1/3),True)
        # Close tessellation is a replacement for the mid core, not thousands of
        # nodes. Unequal broken joints/top stones avoid uniform brick courses.
        courses=[0,rng.uniform(.23,.36),rng.uniform(.59,.73),1]
        for row in range(3):
            t=courses[row];positions=[0.0]
            while positions[-1]<1:positions.append(min(1,positions[-1]+rng.uniform(.2,.48)))
            for left,right in zip(positions[:-1],positions[1:]):
                start=a+(b-a)*left;end=a+(b-a)*right
                ya=hh[0]+(hh[2]-hh[0])*left;yb=hh[0]+(hh[2]-hh[0])*right
                add('near',start,end,ya,yb,-.1+t*height,courses[row+1]*height,w0+(w1-w0)*t,w0+(w1-w0)*courses[row+1],True)
    model=Models()
    for level,(vertices,faces,colours_array) in arrays.items():
        if not vertices:continue
        mesh=trimesh.Trimesh(np.concatenate(vertices),np.concatenate(faces),process=False)
        assert mesh.volume>0, 'Stone/collision faces must point outwards'
        mesh.visual.face_colors=np.concatenate(colours_array)
        if level=="mid":mesh.unmerge_vertices() # Flat coarse faces; close rocks retain shared vertices for memory and rounded shading.
        getattr(model,level).append(mesh)
    return model
