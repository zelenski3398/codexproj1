"""Photograph-led St Elmo massing in the EXISTING Valletta geographic frame.
Grid +Z points NE along the peninsula, not north/up in the photograph.
Outer trace and hidden elevations are conservative authored approximations.
"""
import numpy as np
from shapely.geometry import Polygon, box, LineString
from shapely import affinity

# Metres relative to the unchanged geographic fort anchor. Landward is -Z.
OUTER = [(-190,-80),(-218,-25),(-194,25),(-150,70),(-114,91),
         (-92,122),(-58,144),(-20,140),(-3,113),(6,80),(-23,54),
         (-13,26),(22,28),(27,-24),(30,-50),(64,-72),(44,-88),
         (-4,-100),(-21,-127),(-75,-117),(-105,-91),(-145,-105)]
INNER = [(-150,-36),(-117,-64),(-85,-56),(-68,-80),(-37,-61),
         (-8,-58),(9,-29),(-16,-6),(-16,20),(-57,55),(-90,42),
         (-119,49),(-144,17),(-130,-9)]

def build(center, land, heights, h, world, prism, cube, emit, STONE, TRIM, ROOF, DARK):
    import trimesh
    from shapely.geometry import Point
    original_emit = emit
    def emit(mesh, colour, solid=True):
        original_emit(mesh, colour, solid)
        # Masonry is faceted, not a smoothed balloon. Recompute normals AFTER
        # the shared geographic reflection. Bent normals on broad terrace
        # triangles otherwise produce severe self-shadow bands in Compatibility.
        mesh.unmerge_vertices()
        mesh.vertex_normals = np.repeat(mesh.face_normals,3,axis=0)
    center = np.asarray(center)
    x,z = center
    stone = np.array([181,164,128,255])
    trim = np.array([211,193,153,255])
    shade = np.array([142,128,101,255])
    roof = np.array([164,151,124,255])
    outline = Polygon(np.asarray(OUTER)+center).intersection(land.buffer(-3,join_style=2)).simplify(.7,preserve_topology=True)
    assert outline.geom_type == 'Polygon' and outline.is_valid
    # Sample the INTERIOR too. A boundary-only sample can bury court surfaces
    # under the existing hilltop; no terrain vertices are changed to fix this.
    probes = [np.asarray(p)+center for p in INNER+OUTER]
    probes += [np.asarray([xx,zz])+center for xx in range(-200,50,12) for zz in range(-120,145,12)
               if outline.contains(Point(np.asarray([xx,zz])+center))]
    sample = heights(np.asarray(probes)); sample = sample[np.isfinite(sample)]
    deck = float(sample.max()+.8)
    foundation = float(sample.min()-2.5)
    inner_deck = deck+5.5

    def battered(poly, low, high, factor=.97):
        # Equal-vertex loft: top contracts inward, creating real sloping faces.
        mesh = trimesh.creation.extrude_polygon(poly,high-low,engine='triangle')
        upper = mesh.vertices[:,2] > (high-low)*.5
        centroid = np.asarray(poly.centroid.coords[0])
        mesh.vertices[upper,:2] = centroid+(mesh.vertices[upper,:2]-centroid)*factor
        mesh.vertices = mesh.vertices[:,[0,2,1]]
        mesh.invert();mesh.vertices[:,1]+=low
        emit(mesh,stone)
        return affinity.scale(poly,xfact=factor,yfact=factor,origin=poly.centroid)

    gate = box(x-83,z-145,x-67,z-95)
    terrace = battered(outline.difference(gate),foundation,deck)
    outer_opening = box(x-86,z-150,x-64,z-60)
    pads=[[-177,-12],[23,-75],[-55,111]]
    directions=[np.array([1.,0.]),np.array([-1.,0.]),np.array([0.,-1.])]
    gun_floor=deck+2.8
    # Continuous low defensive terrace, with projecting bastion platforms.
    # The lower open strip between this and the upper fort reads as a ditch.
    from shapely.ops import unary_union
    platforms=[box(x+p[0]-10,z+p[1]-10,x+p[0]+10,z+p[1]+10) for p in pads]
    outer_walk=unary_union([terrace.difference(terrace.buffer(-22,join_style=2))]+platforms).intersection(terrace)
    cuts=[]
    for p,direction in zip(pads,directions):
        pp=center+np.asarray(p)
        cuts.append(LineString([pp+direction*31,pp+direction*8]).buffer(3.1,cap_style=2))
    outer_walk=outer_walk.difference(unary_union(cuts+[outer_opening]))
    prism(outer_walk,deck,gun_floor,stone)
    outer_wall = terrace.difference(terrace.buffer(-2.2,join_style=2)).difference(outer_opening)
    prism(outer_wall,gun_floor,gun_floor+1.15,stone)
    prism(terrace.difference(terrace.buffer(-2.6,join_style=2)).difference(outer_opening),gun_floor+1.15,gun_floor+1.38,trim)
    # Continuous masonry, not fantasy merlons. Recessed horizontal courses
    # strengthen the battered escarp silhouette without adding noisy textures.
    for level in [foundation+2.5, deck-1.1]:
        fraction=(level-foundation)/(deck-foundation)
        trace=affinity.scale(outline,xfact=1-.03*fraction,yfact=1-.03*fraction,origin=outline.centroid)
        prism(trace.difference(trace.buffer(-.24,join_style=2)),level,level+.18,shade,False)

    inner = Polygon(np.asarray(INNER)+center).intersection(terrace.buffer(-4,join_style=2))
    inner_gate = box(x-83,z-95,x-67,z-40)
    inner_top = battered(inner.difference(inner_gate),deck,inner_deck,.955)
    # The notched inner foundation leaves a real graded gate passage.
    inner_opening = box(x-86,z-98,x-64,z-30)
    inner_wall = inner_top.difference(inner_top.buffer(-4.2,join_style=2)).difference(inner_opening)
    prism(inner_wall,inner_deck,inner_deck+4.8,stone)
    prism(inner_top.difference(inner_top.buffer(-1.2,join_style=2)).difference(inner_opening),inner_deck+4.8,inner_deck+5.35,trim)

    def ramp(a,b,width,low,high,collision_only=False):
        a=np.asarray(a)+center;b=np.asarray(b)+center
        normal=np.array([-(b-a)[1],(b-a)[0]])
        normal=normal/np.linalg.norm(normal)*width/2
        vertices=np.array([[*(a-normal),low],[*(a+normal),low],[*(b+normal),high],[*(b-normal),high]])[:,[0,2,1]]
        bottom=vertices.copy();bottom[:,1]=min(low,high)-1.2
        mesh=trimesh.Trimesh(np.vstack([bottom,vertices]),[[4,5,6],[4,6,7],[0,2,1],[0,3,2],[0,1,5],[0,5,4],[1,2,6],[1,6,5],[2,3,7],[2,7,6],[3,0,4],[3,4,7]],process=False)
        mesh.fix_normals();emit(mesh,trim)
        if collision_only:mesh.metadata["collision_only"]=True

    # Gate bridge, solid threshold and high-level access along the landward face.
    approach=float(h(center+[-64,-172]))
    ramp([-64,-172],[-75,-90],12,approach+.12,deck+.08)
    ramp([-75,-88],[-75,-42],9,deck+.08,inner_deck+.08)
    cube(x-75,z-38,9,8,inner_deck-.18,.26,trim)
    cube(x-75,z-88,18,4,deck-.1,.18,trim)
    # Entrance piers and lintel: genuine walk-through opening (clearance >3 m).
    for dx in [-8,8]:cube(x-75+dx,z-71,2.2,5,deck,6.5,stone)
    cube(x-75,z-71,18,5,inner_deck,1,trim)

    # Upper barracks wrap an open drill court. Real arcaded ground floor on
    # the city-facing range; upper rooms and unequal roof heights stay distinct.
    buildings=[]
    for ox,oz,sx,sz,height,arcade in [(-111,-3,10,47,7.4,False),(-75,-46,66,11,9,True),(-38,-8,11,38,6.5,False),(-78,31,46,9,4.8,False)]:
        px,pz=center+[ox,oz]
        footprint=box(px-sx/2,pz-sz/2,px+sx/2,pz+sz/2).intersection(inner_top.buffer(-2))
        if arcade:
            footprint=footprint.difference(box(x-81,z-58,x-69,z-34))
            prism(footprint.intersection(box(px-sx,pz-sz,px+sx,pz+1)),inner_deck,inner_deck+height,stone)
            prism(footprint,inner_deck+3.8,inner_deck+height,stone)
            for offset in np.arange(-29,30,5.8):
                if abs(offset)>7:cube(px+offset,pz+4.2,.8,2.5,inner_deck,3.8,trim)
        else:prism(footprint,inner_deck,inner_deck+height,stone)
        prism(footprint.buffer(.22),inner_deck+height,inner_deck+height+.35,roof,False)
        edge=footprint.difference(footprint.buffer(-.45,join_style=2))
        prism(edge,inner_deck+height+.3,inner_deck+height+.85,trim)
        if sx>sz:
            for offset in np.arange(-sx/2+4,sx/2-1,5.8):cube(px+offset,pz+sz/2+.04,1.1,.08,inner_deck+5,1.65,DARK,False)
        else:
            for offset in np.arange(-sz/2+4,sz/2-1,5.8):cube(px+(sx/2+.04 if ox<-75 else -sx/2-.04),pz+offset,.08,1.1,inner_deck+3.7,1.7,DARK,False)
        buildings.append(dict(center_grid=[ox,oz],height=height))

    # A visibly lower east-side service range and open terrace, not a second
    # full-height courtyard ring. No modern visitor installations are copied.
    service=box(x-3,z-28,x+10,z+4).intersection(terrace.buffer(-4))
    prism(service,deck,deck+4.5,shade)
    prism(service,deck+4.5,deck+4.8,roof,False)
    for offset in range(-21,0,6):cube(x-3.05,z+offset,.08,1.2,deck+1.2,1.7,DARK,False)
    # Raised court with real steps and an adjacent, traversable ramp.
    cube(x-75,z,44,36,inner_deck,1.2,trim)
    for i in range(8):cube(x-94,z-22.125+i*.55,3,.55,inner_deck,.15*(i+1),trim,False)
    # Existing soldier controller has no step-up solver. A baked smooth ramp
    # follows the tread envelope; visible steps are not eight blocking risers.
    ramp([-94,-23],[-94,-18],3,inner_deck+.02,inner_deck+1.2,collision_only=True)
    ramp([-82,-35],[-82,-18],4,inner_deck+.02,inner_deck+1.2)

    for (ox,oz),direction in zip(pads,directions):
        pad=box(x+ox-8,z+oz-8,x+ox+8,z+oz+8)
        assert terrace.buffer(-3).covers(pad),f'Unsupported gun pad: {ox,oz}'
        assert not pad.buffer(3).intersects(inner),f'Gun/crew clips inner fort: {ox,oz}'
        # Platform top already belongs to the shared defensive terrace.
        ramp(np.array([ox,oz])+direction*31,np.array([ox,oz])+direction*8,6,deck+.02,gun_floor)

    # A complete elevation record supports reproducible native/debug views and
    # physics tests without embedding layout constants in gameplay code.
    forward=(world(center+[0,1])-world(center));north=np.array([0.,-1.])
    view_center=world(np.asarray(outline.centroid.coords[0]))
    north_camera=view_center+north*340+np.array([65.,0.])
    target=view_center-forward*35
    def point(p,y):return [*world(center+np.asarray(p)),float(y)]
    return dict(version=2,deck=deck,inner_deck=inner_deck,foundation=foundation,
        center_world=world(center).tolist(),outline_grid=np.asarray(outline.exterior.coords).tolist(),
        inner_outline_grid=np.asarray(inner_top.exterior.coords).tolist(),
        gun_positions=[point(p,gun_floor) for p in pads],
        spawn_positions=[point([-75,0],inner_deck+1.2)]+[point(np.asarray(p)+[5,0],gun_floor) for p in pads],
        stair_collision="Baked smooth ramp beneath eight visual treads; existing soldier controller unchanged.",
        courtyard_steps=dict(start=point([-94,-24.5],inner_deck),end=point([-94,-16.5],inner_deck+1.2)),
        courtyard_ramp=dict(start=point([-82,-35],inner_deck),end=point([-82,-18],inner_deck+1.2)),
        approach_route=[point([-64,-172],approach+.12),point([-75,-90],deck+.08),point([-75,-88],deck+.08),point([-75,-36],inner_deck+.08),point([-82,-35],inner_deck+.02),point([-82,-18],inner_deck+1.2)],
        reference_camera=dict(position=[north_camera[0],deck+210,north_camera[1]],target=[target[0],deck+13,target[1]],fov=48,north_world=[0,0,-1]),
        gun_approaches=[dict(start=point(np.asarray(p)+d*31,deck),end=point(np.asarray(p)+d*6,gun_floor)) for p,d in zip(pads,directions)],
        building_masses=buildings,
        note='Northern-view photographic massing approximation. Existing UTM/world anchor and peninsula grid preserved; not a measured survey.',
        assumptions=['Hidden wall returns, wall batter, exact heights and service rooms inferred conservatively.', 'WWII building survival is not verified by the modern photograph; no speculative damage added.', 'Three Bofors positions are gameplay placements, not documented wartime sites.', 'Outer plan is clipped inside existing coastline; no coastline, terrain or geographic rotation changed.'])
