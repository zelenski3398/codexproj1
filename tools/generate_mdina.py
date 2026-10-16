"""Original photo-inspired Mdina, additive to the existing Malta terrain.
Run with the project's geographic venv. Reads terrain/roads; never writes them.
Metres, EPSG:32633; X east, Y up, -Z north. No runtime dependencies.
"""
from pathlib import Path
import json, os, hashlib
os.environ.setdefault('MPLCONFIGDIR','/tmp/malta-mpl-cache')
import numpy as np
import trimesh
from pyproj import Transformer
from shapely.geometry import Polygon, Point, LineString, box
from shapely.ops import unary_union, split
from shapely import segmentize
from grade_malta_terrain import GroundSampler
ROOT=Path(__file__).resolve().parents[1]; ASSET=ROOT/'assets/malta'; OUT=ASSET/'mdina'
settings=json.loads((OUT/'settings.json').read_text());world_data=json.loads((ASSET/'world_data.json').read_text())
project=Transformer.from_crs(4326,world_data['crs'],always_xy=True)
projection_origin=np.array(project.transform(*world_data['origin_lon_lat']))
def geo(lonlat):
    p=np.array(project.transform(*lonlat))-projection_origin
    return np.array([p[0],-p[1]])
anchor=geo(settings['reference_lon_lat'])
def local_geo(p): return geo(p)-anchor
rng=np.random.default_rng(settings['seed'])
source=trimesh.load(ASSET/'terrain.glb',force='scene',process=False)
# Road patches have local vertices plus GLB node translations. Include their
# actual world transforms; sampling only the main Malta mesh would miss them.
pieces=[]
for node in source.graph.nodes_geometry:
    pose,geometry=source.graph[node];piece=source.geometry[geometry].copy();piece.apply_transform(pose)
    bb=piece.bounds
    if bb[0,0]<anchor[0]+400 and bb[1,0]>anchor[0]-400 and bb[0,2]<anchor[1]+400 and bb[1,2]>anchor[1]-400:pieces.append(piece)
mesh=trimesh.util.concatenate(pieces)
sampler=GroundSampler(source.geometry["Malta"])
# The main mesh intentionally omits separate road patches. Where its fast
# sampler has no surface, intersect the transformed ORIGINAL patch triangles
# directly, independent of winding; never invent a zero elevation.
tri=mesh.vertices[mesh.faces]
lo=tri[:,:,[0,2]].min(axis=1);hi=tri[:,:,[0,2]].max(axis=1)
keep=(lo[:,0]<anchor[0]+400)&(hi[:,0]>anchor[0]-400)&(lo[:,1]<anchor[1]+400)&(hi[:,1]>anchor[1]-400)&(tri[:,:,1].min(axis=1)>-20)
tri=tri[keep];lo=lo[keep];hi=hi[keep]
def heights(points):
    q=np.asarray(points)+anchor;result=sampler.heights(q)
    for index in np.flatnonzero(~np.isfinite(result)):
        x,z=q[index];candidates=tri[(lo[:,0]<=x+1e-6)&(hi[:,0]>=x-1e-6)&(lo[:,1]<=z+1e-6)&(hi[:,1]>=z-1e-6)]
        values=[]
        for face in candidates:
            a,b,c=face[:,[0,2]];den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(den)<1e-8:continue
            u=((b[1]-c[1])*(x-c[0])+(c[0]-b[0])*(z-c[1]))/den
            v=((c[1]-a[1])*(x-c[0])+(a[0]-c[0])*(z-c[1]))/den
            if u>=-1e-6 and v>=-1e-6 and u+v<=1+1e-6:values.append(u*face[0,1]+v*face[1,1]+(1-u-v)*face[2,1])
        if values:result[index]=max(values)
    return result
def h(p):return float(heights([p])[0])
city=Polygon([local_geo(p) for p in settings['outline_lon_lat']]);gate=local_geo(settings['gate_lon_lat'])
cathedral=local_geo(settings['cathedral_lon_lat'])
chunks={};buildings=[];wall_records=[];features=[];portal_records=[]
STONE=np.array([178,165,139,255]);TRIM=np.array([198,184,156,255]);ROOF=np.array([150,140,121,255]);DARK=np.array([47,52,49,255]);GREEN=np.array([66,77,65,255]);PAVING=np.array([139,133,116,255])

def parts(poly):
    if poly.is_empty:return []
    return [poly] if poly.geom_type=='Polygon' else [p for p in poly.geoms if p.geom_type=='Polygon']
def emit(mesh,colour,solid=True):
    assert np.isfinite(mesh.vertices).all(), "Non-finite city geometry"
    mesh.visual.face_colors=np.asarray(colour,dtype=np.uint8)
    centre=mesh.bounds.mean(axis=0);key=(int(np.floor(centre[0]/120)),int(np.floor(centre[2]/120)),solid)
    chunks.setdefault(key,[]).append(mesh)
def cube(x,z,sx,sz,bottom,height,colour=STONE,solid=True):
    if height<=0:return
    m=trimesh.creation.box(extents=[sx,height,sz]);m.apply_translation([x,bottom+height/2,z]);emit(m,colour,solid)
def prism(poly,bottom,top,colour=STONE,solid=True):
    for polygon in parts(poly):
        if polygon.area<.08 or top<=bottom:continue
        m=trimesh.creation.extrude_polygon(polygon,top-bottom,engine='triangle')
        m.vertices=m.vertices[:,[0,2,1]];m.invert();m.vertices[:,1]+=bottom;emit(m,colour,solid)
def profile(poly,bottom,top,top_poly,colour=STONE):
    # Closed battered prism with matching perimeter vertices on its two rings.
    p=np.asarray(poly.exterior.coords)[:-1];q=np.asarray(top_poly.exterior.coords)[:-1]
    assert len(p)==len(q)
    count=len(p);vertices=np.vstack([np.c_[p[:,0],np.full(count,bottom),p[:,1]],np.c_[q[:,0],np.full(count,top),q[:,1]]])
    faces=[]
    for i in range(count):
        j=(i+1)%count;faces.extend([[i,j,count+j],[i,count+j,count+i]])
    # Simple four-point wall wedges only; triangulate caps in consistent order.
    faces.extend([[0,2,1],[0,3,2],[count,count+1,count+2],[count,count+2,count+3]])
    m=trimesh.Trimesh(vertices,faces,process=False);m.fix_normals();emit(m,colour)
def round_mesh(x,z,radius,bottom,height,colour=STONE,top_radius=None,sections=20,solid=True):
    if top_radius is None:
        m=trimesh.creation.cylinder(radius,height,sections=sections);m.vertices[:,2]+=height/2
    else:
        angles=np.arange(sections)*2*np.pi/sections
        v=np.array([[np.cos(a)*r,np.sin(a)*r,y] for y,r in [(0,radius),(height,top_radius)] for a in angles]);f=[]
        for i in range(sections):
            j=(i+1)%sections;f.extend([[i,j,sections+j],[i,sections+j,sections+i]])
        for i in range(1,sections-1):f.extend([[0,i+1,i],[sections,sections+i,sections+i+1]])
        m=trimesh.Trimesh(v,f,process=False)
    m.vertices=m.vertices[:,[0,2,1]];m.invert();m.vertices[:,0]+=x;m.vertices[:,2]+=z;m.vertices[:,1]+=bottom;emit(m,colour,solid)
def dome(x,z,radius,bottom,height):
    # Original masonry dome: raised drum, elliptical hemisphere, ribs and lantern.
    rings=10;sectors=32;vertices=[];faces=[]
    for j in range(rings+1):
        theta=(j/rings)*(np.pi/2-.015)
        for i in range(sectors):
            a=i*2*np.pi/sectors;vertices.append([x+radius*np.cos(theta)*np.cos(a),bottom+height*np.sin(theta),z+radius*np.cos(theta)*np.sin(a)])
    for j in range(rings):
        for i in range(sectors):
            n=(i+1)%sectors;a=j*sectors+i;b=j*sectors+n;c=(j+1)*sectors+n;d=(j+1)*sectors+i
            faces.extend([[a,c,b],[a,d,c]])
    m=trimesh.Trimesh(vertices,faces,process=False);m.fix_normals();emit(m,np.array([167,155,131,255]))
    for i in range(8):
        a=i*np.pi/4
        for j in range(8):
            theta=(j+.5)*np.pi/16
            centre=np.array([x+radius*np.cos(theta)*np.cos(a),bottom+height*np.sin(theta),z+radius*np.cos(theta)*np.sin(a)])
            nxt=(j+1)*np.pi/16;prev=j*np.pi/16
            start=np.array([x+radius*np.cos(prev)*np.cos(a),bottom+height*np.sin(prev),z+radius*np.cos(prev)*np.sin(a)])
            end=np.array([x+radius*np.cos(nxt)*np.cos(a),bottom+height*np.sin(nxt),z+radius*np.cos(nxt)*np.sin(a)])
            rod(start,end,.18,TRIM,False)
    round_mesh(x,z,1.8,bottom+height-1,3,TRIM,sections=12)
    round_mesh(x,z,2.1,bottom+height+2,1.8,TRIM,top_radius=.2,sections=12)
    cube(x,z,.25,.25,bottom+height+3.5,2,TRIM,False);cube(x,z,.25,1.2,bottom+height+4.5,.22,TRIM,False)
def rod(start,end,radius,colour,solid=False):
    m=trimesh.creation.cylinder(radius=radius,segment=np.array([start,end]),sections=8);emit(m,colour,solid)
def panel(a,b,bottom,height,colour=DARK):
    v=[[a[0],bottom,a[1]],[b[0],bottom,b[1]],[b[0],bottom+height,b[1]],[a[0],bottom+height,a[1]]]
    # A thin opaque facade inset, double-sided for irregular polygon orientation.
    m=trimesh.Trimesh(v,[[0,1,2],[0,2,3],[2,1,0],[3,2,0]],process=False);emit(m,colour,False)

def terrain_ribbon(poly,colour=PAVING):
    for p in parts(poly):
        if p.area<.2:continue
        # Tessellation follows the preserved hill, never a large floating slab.
        minx,minz,maxx,maxz=p.bounds
        for x in np.arange(minx,maxx,7):
            for z in np.arange(minz,maxz,7):
                for piece in parts(p.intersection(box(x,z,x+7,z+7))):
                    if piece.area<.03:continue
                    v,f=trimesh.creation.triangulate_polygon(piece,engine='triangle')
                    hh=heights(v)
                    if not np.isfinite(hh).all():continue
                    m=trimesh.Trimesh(np.c_[v[:,0],hh+.10,v[:,1]],f,process=False)
                    if m.face_normals[0,1]<0:m.invert()
                    emit(m,colour,False)

# Preserve the entire existing road carriageway through and around the city.
network=json.loads((ASSET/'roads/world_paths.json').read_text());existing_lines=[]
for record in network['paths']:
    p=np.asarray(record['points'])-anchor
    if LineString(p).distance(city)<30:existing_lines.append((record['id'],float(record['width']),LineString(p)))
streets=[(r['id'],float(r['width_metres']),LineString([local_geo(p) for p in r['lon_lat']])) for r in settings['streets']]
# The old map road is a coarse manually registered trace. Keep it unchanged;
# authored wall passages and an internal street accommodate its exact geometry.
all_roads=streets+existing_lines
road_space=unary_union([line.buffer(width/2+1.2,cap_style=1,join_style=2) for _,width,line in all_roads])
cathedral_space=box(cathedral[0]-28,cathedral[1]-42,cathedral[0]+31,cathedral[1]+53)
main_gate_lane=LineString([gate+[0,26],gate,gate+[0,-35]])
road_space=unary_union([road_space,main_gate_lane.buffer(5)])
interior=city.buffer(-12).intersection(box(-220,-290,200,117))
blocks=interior.difference(road_space).difference(cathedral_space)

# Irregular street blocks subdivided into close-set palace/house lots. Local
# perpendicular cuts vary by block; there is no fantasy square castle grid.
def lots(poly,depth=0):
    if poly.area<80:return []
    if poly.area<470 or depth>6:return [poly]
    minx,minz,maxx,maxz=poly.bounds
    if maxx-minx>maxz-minz:
        x=(minx+maxx)/2+rng.uniform(-3,3);line=LineString([(x,minz-20),(x,maxz+20)])
    else:
        z=(minz+maxz)/2+rng.uniform(-3,3);line=LineString([(minx-20,z),(maxx+20,z)])
    result=[]
    for piece in split(poly,line).geoms:
        if piece.geom_type=='Polygon':result.extend(lots(piece,depth+1))
    return result
for block in parts(blocks):
    for lot in lots(block):
        poly=lot.buffer(-.28,join_style=2)
        if poly.is_empty or poly.geom_type!='Polygon' or poly.area<65:continue
        poly=poly.simplify(.45,preserve_topology=True)
        centre=np.array(poly.representative_point().coords[0]);sample=np.vstack([np.asarray(poly.exterior.coords)[:-1],centre])
        hh=heights(sample)
        if not np.isfinite(hh).all():continue
        bottom=float(hh.min()-.55);roof=float(hh.max()+rng.uniform(*settings['building_height_range_metres']))
        # Some larger buildings retain genuine open courts down to terrain.
        courtyard=None
        if poly.area>220 and rng.random()<.43:
            courtyard=Point(*centre).buffer(min(4.5,np.sqrt(poly.area)*.19),resolution=1)
            if poly.buffer(-2).covers(courtyard):poly=poly.difference(courtyard)
            else:courtyard=None
        colour=np.clip(STONE+rng.integers(-10,11)*np.array([1,1,1,0]),0,255)
        prism(poly,bottom,roof,colour)
        prism(poly,roof-.2,roof+.18,ROOF,False)
        rim=poly.difference(poly.buffer(-.32));prism(rim,roof+.18,roof+.95,TRIM,False)
        if rng.random()<.3:cube(centre[0],centre[1],1.6,2,roof,.95,colour,False)
        buildings.append(dict(centre_xz=(centre+anchor).tolist(),base=bottom,roof=roof,footprint_xz=(np.asarray(poly.exterior.coords)+anchor).tolist(),courtyard=bool(courtyard is not None)))
        # Visible openings/cornice along every street facade, with short timber
        # balconies and a dark entrance. Thin panes are cheap; walls stay solid.
        ring=np.asarray(poly.exterior.coords)
        for a,b in zip(ring[:-1],ring[1:]):
            length=np.linalg.norm(b-a)
            if length<3:continue
            direction=(b-a)/length;out=np.array([direction[1],-direction[0]])
            if poly.contains(Point(*((a+b)/2+out))):out=-out
            for offset in np.arange(1.7,length-1,3.8):
                mid=a+direction*offset+out*.035
                for floor in range(max(2,int((roof-hh.max())/3.3))):
                    panel(mid-direction*.5,mid+direction*.5,roof-3.2*(floor+1)+.6,1.5)
            middle=(a+b)/2+out*.04
            panel(middle-direction*.65,middle+direction*.65,float(hh.max()),2.3,GREEN)
            if length>8 and rng.random()<.15:
                balcony=LineString([middle-direction*.9,middle+direction*.9]).buffer(.42,cap_style=2)
                prism(balcony,float(hh.max()+3.2),float(hh.max()+4.3),GREEN,False)
for _,width,line in streets:terrain_ribbon(line.buffer(width/2,join_style=2).intersection(city))
terrain_ribbon(main_gate_lane.buffer(4))
terrain_ribbon(cathedral_space.intersection(city),np.array([160,151,131,255]))

# Main Baroque entrance has a real arched void; no collider spans the passage.
# A second set of open wall passages preserves existing roads. No crenellations.
wall_band=city.buffer(4,join_style=2).difference(city.buffer(-7,join_style=2))
portals=unary_union([main_gate_lane.buffer(5.5)]+[line.buffer(width/2+2) for _,width,line in existing_lines])
ring=np.asarray(city.exterior.coords)
for a,b in zip(ring[:-1],ring[1:]):
    direction=(b-a)/np.linalg.norm(b-a);normal=np.array([direction[1],-direction[0]])
    if city.contains(Point(*((a+b)/2+normal))):normal=-normal
    # Individual short wall sections follow hill elevation without flattening it.
    count=int(np.ceil(np.linalg.norm(b-a)/14))
    stations=np.linspace(a,b,count+1)
    for p,q in zip(stations[:-1],stations[1:]):
        segment=LineString([p,q])
        if segment.intersects(portals):continue
        hh=heights([p+normal*4,q+normal*4,p-normal*5,q-normal*5])
        if not np.isfinite(hh).all():continue
        low=float(hh.min()-.6);top=float(hh.max()+settings['wall_height_metres'])
        lower=Polygon([p+normal*4,q+normal*4,q-normal*6,p-normal*6])
        upper=Polygon([p+normal*.8,q+normal*.8,q-normal*5.5,p-normal*5.5])
        profile(lower,low,top,upper)
        # Walkway is the actual solid top; low parapets leave a clear 4 m walk.
        parapet=Polygon([p+normal*.8,q+normal*.8,q-normal*.2,p-normal*.2])
        prism(parapet,top,top+1.25,TRIM)
        wall_records.append(dict(start_xz=(p+anchor).tolist(),end_xz=(q+anchor).tolist(),bottom=low,top=top))
# Fill angular corner junctions/bastion shoulders, never opening a road collision.
for vertex in ring[:-1]:
    if portals.distance(Point(*vertex))<8:continue
    polygon=Point(*vertex).buffer(5,resolution=2).intersection(wall_band)
    hh=heights(np.array([vertex]));level=float(hh[0])
    prism(polygon,level-1,level+settings['wall_height_metres'])

# Bastion platforms follow the authored irregular wall footprint. Terraces are
# masonry additions above existing ground, not a replacement terrain plateau.
for name,poly in [('South projecting bastion',Polygon([[5,130],[20,170],[65,215],[115,150],[106,124]])),('North bastion',Polygon([[-125,-210],[-40,-270],[60,-270],[80,-230],[-10,-215]])),('Eastern bastion',Polygon([[126,95],[185,95],[180,145],[115,150]]))]:
    hh=heights(np.asarray(poly.exterior.coords)[:-1]);base=float(hh.min()-.5);deck=float(hh.max()+2)
    prism(poly,base,deck,STONE)
    perimeter=poly.difference(poly.buffer(-1.1));prism(perimeter,deck,deck+1.2,TRIM)
    features.append(dict(name=name,position=[*np.array(poly.centroid.coords[0])+anchor],height=deck))

# Raised counterscarp and the untouched ground between it and the main wall
# suggest the dry defensive ditch. We do not claim to excavate a surveyed ditch.
front=LineString([[-170,113],[-120,148],[-70,154],[-35,155],[0,155]])
for p in parts(front.buffer(1.3,cap_style=2).difference(portals)):
    hh=heights(np.asarray(p.exterior.coords)[:-1]);prism(p,float(hh.min()-.3),float(hh.max()+2.5),STONE)

# Portals: fill the masonry ABOVE a polygonal arch without blocking the floor.
def arch_gate(centre,width,depth,level,main=False):
    x,z=centre;opening=width/2;spring=4.4 if main else 5.2;radius=opening
    outer=Polygon([[-opening-3.8,0],[opening+3.8,0],[opening+3.8,13],[-opening-3.8,13]])
    arch=[[-opening,0],[opening,0],[opening,spring]]
    arch.extend([[radius*np.cos(a),spring+radius*np.sin(a)] for a in np.linspace(0,np.pi,17)])
    arch.append([-opening,0]);face=outer.difference(Polygon(arch))
    # Extrude facade XY into depth Z; height values are geometric Y in game.
    m=trimesh.creation.extrude_polygon(face,depth,engine='triangle');m.vertices[:,2]-=depth/2;m.vertices[:,0]+=x;m.vertices[:,1]+=level;m.vertices[:,2]+=z;emit(m,STONE)
    cube(x,z,2*(opening+4.4),depth+1,level+12.6,1.1,TRIM)
    if main:
        for dx in [-opening-2.5,opening+2.5]:
            cube(x+dx,z+depth/2+.25,1.1,.8,level+.4,11,TRIM,False)
        cube(x,z+depth/2+.15,4,.45,level+10,1.6,TRIM,False)
        # Original heraldic plaque geometry; no copyrighted reference texture.
        round_mesh(x,z+depth/2+.45,.8,level+10.7,.3,TRIM,sections=8,solid=False)
    portal_records.append(dict(name='Mdina Main Gate' if main else 'Existing road passage',position=[x+anchor[0],level,z+anchor[1]],width=width))
gate_h=h(gate);arch_gate(gate,9,5,gate_h-.05,True)
# Existing road crossings receive open passages and headroom. The small arch
# assemblies align to each crossing's tangent, not to arbitrary city axes.
for ident,width,line in existing_lines:
    cross=line.intersection(city.boundary)
    points=[]
    if cross.geom_type=='Point':points=[cross]
    elif hasattr(cross,'geoms'):points=[p for p in cross.geoms if p.geom_type=='Point']
    for point in points:
        centre=np.array(point.coords[0]);portal_records.append(dict(name=ident+' preserved road opening',position=[centre[0]+anchor[0],h(centre),centre[1]+anchor[1]],width=width+4))
        # Wall cuts themselves are the passage; do not add a misaligned arch
        # whose piers could collide with a diagonal legacy road.

# St Paul's Cathedral: original Baroque massing, twin bell towers, pilasters,
# stepped pediments, large dome on a drum and lantern. Skyline focal point.
x,z=cathedral;footprint=box(x-20,z-32,x+20,z+30);hh=heights(np.asarray(footprint.exterior.coords)[:-1]);base=float(hh.min()-.5);floor=float(hh.max());roof=floor+21
prism(footprint,base,roof)
cube(x,z,15,62,roof,4,ROOF)
cube(x,z+32,42,7,base,roof-base,STONE)
for dx in [-15,15]:
    cube(x+dx,z+24,9,11,roof-.1,10,STONE)
    for dz in [-5.55,5.55]:panel([x+dx-1.2,z+24+dz],[x+dx+1.2,z+24+dz],roof+3,4)
    cube(x+dx,z+24,10,12,roof+9.5,1.2,TRIM)
    round_mesh(x+dx,z+24,5.2,roof+10.7,3.2,ROOF,top_radius=2.0,sections=24)
    round_mesh(x+dx,z+24,2.4,roof+13.9,1.8,ROOF,top_radius=.3,sections=20)
    # Geometric clock face and hands on each front belfry, with framed openings.
    clock=trimesh.creation.cylinder(radius=1.15,height=.12,sections=24)
    clock.apply_translation([x+dx,roof+1.7,z+29.62]);emit(clock,DARK,False)
    rod(np.array([x+dx,roof+1.7,z+29.72]),np.array([x+dx,roof+2.5,z+29.72]),.07,TRIM)
    rod(np.array([x+dx,roof+1.7,z+29.72]),np.array([x+dx+.65,roof+1.7,z+29.72]),.07,TRIM)
    for side in [-1,1]:
        panel([x+dx-1.35,z+24+side*5.65],[x+dx+1.35,z+24+side*5.65],roof+4,3.7)
        for ox in [-2,2]:cube(x+dx+ox,z+24+side*5.7,.5,.45,roof+3.6,4.6,TRIM,False)
    cube(x+dx,z+24,.28,.28,roof+15.5,2,TRIM,False);cube(x+dx,z+24,1.3,.28,roof+16.7,.25,TRIM,False)
for dx in [-18,-10,10,18]:cube(x+dx,z+35.9,1.2,.75,floor,18,TRIM,False)
panel([x-2.6,z+36.05],[x+2.6,z+36.05],floor,7.5)
# Triangular central pediment as actual geometry, extruded in Z.
pediment=Polygon([[-11,0],[11,0],[0,6]])
m=trimesh.creation.extrude_polygon(pediment,1.4,engine='triangle');m.vertices[:,0]+=x;m.vertices[:,1]+=roof;m.vertices[:,2]+=z+34.5;emit(m,TRIM)
round_mesh(x,z-8,10.5,roof,6,STONE,sections=24)
for angle in np.arange(12)*np.pi/6:
    centre=np.array([x+10.55*np.cos(angle),z-8+10.55*np.sin(angle)]);tangent=np.array([-np.sin(angle),np.cos(angle)])
    panel(centre-tangent*.75,centre+tangent*.75,roof+1.5,3)
dome(x,z-8,10.6,roof+6,13)
features.append(dict(name="St Paul's Cathedral",position=[x+anchor[0],floor,z+anchor[1]],height=roof+24))
features.append(dict(name='Mdina Main Gate',position=[gate[0]+anchor[0],gate_h,gate[1]+anchor[1]],height=gate_h+14))

# A few restrained local trees in court/ditch areas, no modern parked cars or
# the photograph's watermark, lighting, background or contemporary furniture.
for tx,tz in [(-145,145),(-125,155),(-90,155),(35,165),(55,175),(74,165)]:
    if portals.distance(Point(tx,tz))<6:continue
    level=h([tx,tz]);round_mesh(tx,tz,.3,level,3.5,np.array([93,80,59,255]),sections=6,solid=False)
    m=trimesh.creation.icosphere(subdivisions=1,radius=3.2);m.apply_scale([1,1.2,1]);m.apply_translation([tx,level+5,tz]);emit(m,np.array([82,93,57,255]),False)

scene=trimesh.Scene();collision=trimesh.Scene();triangles=0;structure_count=0
for (cx,cz,solid),meshes in sorted(chunks.items()):
    m=trimesh.util.concatenate(meshes);name=f'Mdina_{cx+10}_{cz+10}_'+('Structure' if solid else 'Detail')
    scene.add_geometry(m,geom_name=name,node_name=name);triangles+=len(m.faces)
    if solid:collision.add_geometry(m,geom_name=name,node_name=name);structure_count+=1
(OUT/'city.glb').write_bytes(scene.export(file_type='glb'))
(OUT/'collision.glb').write_bytes(collision.export(file_type='glb'))
protected=['terrain.glb','world_data.json','roads/world_paths.json']
report=dict(version=1,units='metres',crs=world_data['crs'],projection_origin_lon_lat=world_data['origin_lon_lat'],reference_lon_lat=settings['reference_lon_lat'],origin_world=[anchor[0],0,anchor[1]],reference_terrain_height=h([0,0]),source_hashes={p:hashlib.sha256((ASSET/p).read_bytes()).hexdigest() for p in protected},building_count=len(buildings),buildings=buildings,wall_segments=len(wall_records),walls=wall_records,portals=portal_records,landmarks=features,outline_world_xz=(np.asarray(city.exterior.coords)+anchor).tolist(),bounds=scene.bounds.tolist(),triangles=triangles,structure_chunks=structure_count,render_chunks=len(chunks),road_ids=[r[0] for r in existing_lines],road_opening_clearance_metres=2.0,accuracy_note=settings['source_note'],ditch_note='Existing ground floor retained; raised counterscarp and escarp suggest the dry ditch. No terrain excavation or surveyed trench profile.')
(OUT/'layout.json').write_text(json.dumps(report,indent=2,allow_nan=False)+'\n')
print(json.dumps({k:v for k,v in report.items() if k not in ['buildings','walls','outline_world_xz']},indent=2))
