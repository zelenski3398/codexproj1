"""Original flight-scale Valletta reconstruction, not a downloaded Sketchfab model.
Offline: use the existing Malta geo venv (numpy, trimesh, shapely, pyproj,
matplotlib, triangle). No dependency/network access is needed by the game.
All geometry is additive; the terrain GLB and gameplay coordinates are read-only.
"""
from pathlib import Path
import json, hashlib, os
os.environ.setdefault('MPLCONFIGDIR','/tmp/malta-mpl-cache')
import numpy as np
import trimesh
from pyproj import Transformer
from shapely.geometry import Polygon, box, shape, LineString, Point
from shapely.ops import polygonize, unary_union, transform
from grade_malta_terrain import GroundSampler
ROOT=Path(__file__).resolve().parents[1]
ASSET=ROOT/'assets/malta'; OUT=ASSET/'valletta';OUT.mkdir(exist_ok=True)
rng=np.random.default_rng(1941)
projection=Transformer.from_crs(4326,32633,always_xy=True)
origin=projection.transform(14.4,35.93)
def geo(lon,lat):
    x,n=projection.transform(lon,lat);return np.array([x-origin[0],-(n-origin[1])])
gate=geo(14.5092,35.8951);tip=geo(14.5194,35.9020)
forward=(tip-gate)/np.linalg.norm(tip-gate);right=np.array([-forward[1],forward[0]])
axes=np.column_stack([right,forward])
anchor=np.array(json.loads((ASSET/'world_data.json').read_text())['landmarks'][0]['position'])[[0,2]]
def world(points):return np.asarray(points)@axes.T+gate
def local(points):return (np.asarray(points)-gate)@axes
coast=json.loads((ASSET/'source/Malta-Coastline.geojson').read_text())
land=max(polygonize(unary_union([shape(f['geometry']) for f in coast['features']])),key=lambda p:p.area)
def to_local(x,y,z=None):
    xx,nn=projection.transform(x,y);p=np.column_stack([np.atleast_1d(xx)-origin[0],-(np.atleast_1d(nn)-origin[1])]);q=local(p)
    return q[:,0],q[:,1]
land=transform(to_local,land)
# Chosen urban envelope follows the existing peninsula; the source coastline
# clips every lot. This is an authored period-inspired plan, not cadastral data.
envelope=Polygon([(-260,-75),(185,-75),(285,140),(310,480),(260,800),(160,1040),(100,1210),(-160,1200),(-290,990),(-335,650),(-330,250)])
city=land.buffer(-12).intersection(envelope)
terrain=trimesh.load(ASSET/'terrain.glb',force='scene',process=False)
sampler=GroundSampler(terrain.geometry['Malta'])
def heights(points):return sampler.heights(world(np.asarray(points)))
def h(point):return float(heights([point])[0])

chunks={};buildings=[];features=[]
STONE=np.array([178,163,131,255]);ROOF=np.array([155,144,121,255]);TRIM=np.array([200,186,151,255]);DARK=np.array([48,54,49,255]);GREEN=np.array([61,77,64,255]);STREET=np.array([124,119,102,255])
def emit(mesh,colour,solid=True):
    # Author in city/grid space, export in world-aligned metres relative to anchor.
    p=world(mesh.vertices[:,[0,2]])-anchor
    mesh.vertices[:,0]=p[:,0];mesh.vertices[:,2]=p[:,1]
    # Grid-forward is +Z while Godot north is -Z: the XZ transform reflects.
    # Reverse winding so visible surfaces and one-sided collision face out.
    mesh.invert()
    mesh.visual.face_colors=np.asarray(colour,dtype=np.uint8)
    centre=mesh.bounds.mean(axis=0);key=(int(np.floor(centre[0]/240)),int(np.floor(centre[2]/240)),solid)
    chunks.setdefault(key,[]).append(mesh)

def cube(x,z,sx,sz,bottom,height,colour=STONE,solid=True):
    if height<=0:return
    m=trimesh.creation.box(extents=[sx,height,sz]);m.apply_translation([x,bottom+height/2,z]);emit(m,colour,solid)

def prism(poly,bottom,top,colour=STONE,solid=True):
    if poly.is_empty or poly.area<1:return
    if poly.geom_type != "Polygon":
        for part in poly.geoms: prism(part,bottom,top,colour,solid)
        return
    m=trimesh.creation.extrude_polygon(poly,top-bottom,engine='triangle')
    # trimesh polygon XY extrusion Z -> game X,Y(height),Z(grid-forward).
    m.vertices=m.vertices[:,[0,2,1]];m.invert();m.vertices[:,1]+=bottom;emit(m,colour,solid)

def round_mesh(x,z,radius,bottom,height,colour=STONE,sections=16,top_radius=None,solid=True):
    if top_radius is None:
        m=trimesh.creation.cylinder(radius=radius,height=height,sections=sections)
        m.vertices[:,2]+=height/2
    else:
        angles=np.arange(sections)*2*np.pi/sections
        v=np.array([[np.cos(a)*r,np.sin(a)*r,y] for y,r in [(0,radius),(height,top_radius)] for a in angles])
        f=[]
        for i in range(sections):
            j=(i+1)%sections;f.extend([[i,j,sections+j],[i,sections+j,sections+i]])
        for i in range(1,sections-1):f.extend([[0,i+1,i],[sections,sections+i,sections+i+1]])
        m=trimesh.Trimesh(v,f,process=False)
    m.vertices=m.vertices[:,[0,2,1]];m.invert();m.vertices[:,1]+=bottom;m.vertices[:,0]+=x;m.vertices[:,2]+=z;emit(m,colour,solid)

def window(x,z,side,along_x,bottom):
    # Flat, recessed-coloured panes need only two triangles, not closed cubes.
    if along_x:
        v=[[x-.5,bottom,z],[x+.5,bottom,z],[x+.5,bottom+1.65,z],[x-.5,bottom+1.65,z]]
        normal=np.array([0,0,side])
    else:
        v=[[x,bottom,z-.5],[x,bottom,z+.5],[x,bottom+1.65,z+.5],[x,bottom+1.65,z-.5]]
        normal=np.array([side,0,0])
    m=trimesh.Trimesh(v,[[0,1,2],[0,2,3]],process=False)
    if np.dot(m.face_normals[0],normal)<0:m.invert()
    emit(m,DARK,False)

def building(x,z,sx,sz,height,ornate=False):
    footprint=box(x-sx/2,z-sz/2,x+sx/2,z+sz/2)
    if not city.covers(footprint):return False
    sample=np.array(footprint.exterior.coords)[:-1];hh=heights(np.vstack([sample,[x,z]]))
    if not np.isfinite(hh).all() or hh.min()<2:return False
    # Foundations embed into the existing slope. No flattening or floating slabs.
    base=float(hh.min()-.65);roof=float(hh.max()+height)
    colour=np.clip(STONE+rng.integers(-12,13)*np.array([1,1,1,0]),0,255)
    cube(x,z,sx,sz,base,roof-base,colour)
    buildings.append(dict(centre=world([x,z]).tolist(),size=[sx,sz],base=base,roof=roof))
    cube(x,z,sx+.25,sz+.25,roof-.35,.45,ROOF,False)
    for px,pz,wx,wz in [(x,z-sz/2,sx,.28),(x,z+sz/2,sx,.28),(x-sx/2,z,.28,sz),(x+sx/2,z,.28,sz)]:
        cube(px,pz,wx,wz,roof,.8,TRIM,False)
    if rng.random()<.30:cube(x+sx*.15,z,2.5,2.8,roof,1.6,colour,False)
    # Recess-coloured window geometry, cornice bands and occasional projecting
    # painted timber balconies. Detail mesh is separately distance-culled.
    floors=min(4,int(height/3.2))
    for side in [-1,1]:
        for offset in np.arange(-sx/2+2,sx/2-1,4.0):
            for floor in range(floors):
                yy=roof-height+1.1+floor*3.2
                window(x+offset,z+side*(sz/2+.035),side,True,yy)
                if floor==1 and rng.random()<.14:
                    cube(x+offset,z+side*(sz/2+.35),1.5,.7,yy-.25,1.35,GREEN,False)
        for offset in np.arange(-sz/2+2,sz/2-1,4.2):
            for floor in range(floors):
                window(x+side*(sx/2+.035),z+offset,side,False,roof-height+1.1+floor*3.2)
    return True

# Historical-style orthogonal blocks with open courtyards and 10–14 m streets.
# Republic Street is the wider central longitudinal avenue around grid X=0.
reserved=[]
landmark_specs=[('St Johns co-cathedral',14.5127,35.8978,45,68),('Grand Masters Palace',14.5144,35.8989,66,70),('St Pauls spire',14.5124,35.9000,35,46),('Royal Opera House',14.5103,35.8957,38,55)]
for name,lon,lat,sx,sz in landmark_specs:
    q=local(geo(lon,lat));reserved.append(box(q[0]-sx/2-10,q[1]-sz/2-10,q[0]+sx/2+10,q[1]+sz/2+10))
reserves=unary_union(reserved)
for ix in range(-5,5):
    x0=ix*64+7;x1=(ix+1)*64-7
    for iz in range(14):
        z0=iz*70+35;z1=z0+56
        if box(x0,z0,x1,z1).intersects(reserves):continue
        # Four strips form the courtyard perimeter; independently subdivided lots.
        for z in [z0+7,z1-7]:
            splits=3
            for n in range(splits):
                width=(x1-x0)/splits
                building(x0+(n+.5)*width,z,width-.5,14,rng.uniform(8,15))
        for x in [x0+7,x1-7]:
            for z in [z0+22,z0+35]:building(x,z,14,12.5,rng.uniform(8,15))

# Terrain-following road ribbons, sampled every 5 m, preserve original slopes.
road_count=0
for direction,coords in [('long',range(-5,6)),('cross',range(15))]:
    for index in coords:
        if direction=='long':a,b=np.array([index*64,15]),np.array([index*64,1020]);width=13 if index==0 else 9
        else:a,b=np.array([-325,index*70+28]),np.array([310,index*70+28]);width=9
        d=b-a;normal=np.array([-d[1],d[0]])/np.linalg.norm(d)*width/2
        steps=max(2,int(np.linalg.norm(d)/5))
        for start,end in zip(np.linspace(a,b,steps)[:-1],np.linspace(a,b,steps)[1:]):
            corners=np.array([start-normal,start+normal,end+normal,end-normal])
            if not city.covers(Polygon(corners)) or reserves.intersects(Polygon(corners)):continue
            hh=heights(corners)
            if not np.isfinite(hh).all() or hh.min()<1:continue
            m=trimesh.Trimesh(np.c_[corners[:,0],hh+.11,corners[:,1]],[[0,1,2],[0,2,3]],process=False)
            # Ensure upward face normals regardless of ribbon direction.
            if m.face_normals[0,1]<0:m.invert()
            emit(m,STREET,False);road_count+=1

# Landmark masses are original, simplified period silhouettes (no huge modern
# Carmelite dome: the present dome is post-war). The opera house is intact.
for name,lon,lat,sx,sz in landmark_specs:
    x,z=local(geo(lon,lat));level=h([x,z])
    if not np.isfinite(level):continue
    features.append(dict(name=name,position=[*world([x,z])],terrain_height=level))
    if 'Palace' in name:
        for ox,oz,wx,wz in [(0,-sz/2+8,sx,16),(0,sz/2-8,sx,16),(-sx/2+8,0,16,sz-32),(sx/2-8,0,16,sz-32)]:
            # Landmark dimensions explicitly fitted to one sampled foundation.
            cube(x+ox,z+oz,wx,wz,level-.5,17.5)
        cube(x,z-sz/2,18,5,level+17,3,TRIM)
    elif 'Johns' in name:
        cube(x,z,sx,sz,level-.5,20)
        cube(x,z,17,sz+1,level+19.5,5,ROOF)
        for dx in [-sx*.38,sx*.38]:
            cube(x+dx,z-sz*.40,9,10,level+19,15)
            for zz in [-2,2]:cube(x+dx,z-sz*.40+zz,3,.3,level+29,3,DARK,False)
            round_mesh(x+dx,z-sz*.40,5.5,level+34,4,TRIM,top_radius=1)
    elif 'spire' in name:
        cube(x,z,sx,sz,level-.5,17)
        cube(x+sx*.35,z-sz*.36,8,8,level+16,20)
        round_mesh(x+sx*.35,z-sz*.36,5.5,level+36,18,TRIM,top_radius=.25)
    else:
        cube(x,z,sx,sz,level-.5,17)
        cube(x,z,27,sz-8,level+16,7,ROOF)
        for dx in np.linspace(-sx*.4,sx*.4,7):round_mesh(x+dx,z-sz/2-3,1,level,14,TRIM,sections=8)
        cube(x,z-sz/2-3,sx+4,8,level+14,3,TRIM)

# Perimeter fortifications: low bastion platforms, battered limestone escarps
# and parapets. They sit INSIDE the supplied coast, never reshape the islands.
wall_segments=0
ring=city.exterior
samples=[np.array(ring.interpolate(d).coords[0]) for d in np.arange(0,ring.length,22)]
for a,b in zip(samples,samples[1:]+samples[:1]):
    mid=(a+b)/2
    if mid[1]>1040:continue # Fort St Elmo gets its own star-shaped enceinte.
    # Leave a real 20 m landward gate aligned with the principal street.
    if mid[1]<30 and abs(mid[0])<18:continue
    hh=heights([a,b,mid])
    if not np.isfinite(hh).all() or hh.min()<1:continue
    segment=LineString([a,b]).buffer(5.5,cap_style=2)
    low=float(hh.min()-2);top=float(hh.max()+8)
    prism(segment,low,top)
    prism(LineString([a,b]).buffer(6.3,cap_style=2),top,top+1.3,TRIM,False)
    wall_segments+=1
# Land front bastions are angular, not circular towers.
for x,z in [(-190,20),(155,65),(-230,420),(245,470),(-210,830)]:
    p=Polygon([(x-24,z-28),(x+20,z-28),(x+48,z),(x+20,z+29),(x-24,z+29),(x-40,z)])
    p=p.intersection(city.buffer(-2));level=h([x,z])
    if p.geom_type!='Polygon' or p.area<200 or not np.isfinite(level):continue
    prism(p,level-3,level+8)
    parapet=p.difference(p.buffer(-2))
    for part in ([parapet] if parapet.geom_type=='Polygon' else parapet.geoms):prism(part,level+8,level+10,TRIM,False)

# Fort St Elmo: angular outer enceinte, inner star fort and open drill court.
x,z=local(tip);fort_centre=np.array([x,z-5]);fort_level=h(fort_centre)
if np.isfinite(fort_level):
    features.append(dict(name='Fort St Elmo',position=world(fort_centre).tolist(),terrain_height=fort_level))
    outline=Point(*fort_centre).buffer(124,resolution=3).intersection(land.buffer(-10))
    if outline.geom_type=='Polygon':
        hh=heights(np.array(outline.exterior.coords)[:-1]);finite=hh[np.isfinite(hh)]
        foundation=float(finite.min()-2);deck=float(finite.max()+3)
        prism(outline,foundation,deck,STONE)
        rim=outline.difference(outline.buffer(-5))
        for part in ([rim] if rim.geom_type=='Polygon' else rim.geoms):prism(part,deck,deck+3,TRIM)
        star=[]
        for i in range(16):
            angle=i*np.pi/8;radius=76 if i%2==0 else 47;star.append(fort_centre+np.array([np.cos(angle),np.sin(angle)])*radius)
        star=Polygon(star).intersection(outline.buffer(-3));walls=star.difference(star.buffer(-12))
        prism(walls,deck,deck+10)
        parapet=star.difference(star.buffer(-2));prism(parapet,deck+10,deck+11.4,TRIM,False)
        for ox in [-34,34]:cube(x+ox,z-5,14,36,deck,7,ROOF)

scene=trimesh.Scene();collision_scene=trimesh.Scene();total_triangles=0
for (cx,cz,solid),meshes in sorted(chunks.items()):
    combined=trimesh.util.concatenate(meshes)
    name=f'City_{cx+10}_{cz+10}_'+('Structure' if solid else 'Detail')
    scene.add_geometry(combined,geom_name=name,node_name=name)
    if solid:collision_scene.add_geometry(combined,geom_name=name,node_name=name)
    total_triangles+=len(combined.faces)
(OUT/'city.glb').write_bytes(scene.export(file_type='glb'))
(OUT/'collision.glb').write_bytes(collision_scene.export(file_type='glb'))
report=dict(version=1,seed=1941,units='metres',origin_world=[anchor[0],0,anchor[1]],grid_gate_world=gate.tolist(),grid_forward_xz=forward.tolist(),terrain_sha256=hashlib.sha256((ASSET/'terrain.glb').read_bytes()).hexdigest(),building_count=len(buildings),wall_segments=wall_segments,road_segments=road_count,render_chunks=len(chunks),triangles=total_triangles,landmarks=features,buildings=buildings,city_bounds=scene.bounds.tolist(),note='Original reference-inspired, approximate 1940-era city; not a surveyed reconstruction or Sketchfab asset. Coastline/elevation and game coordinates unchanged.')
(OUT/'layout.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='buildings'},indent=2))
