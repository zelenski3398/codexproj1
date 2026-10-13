"""Original RAF-style pilot, generated in Blender; no photographic textures.
Run: blender --background --python-exit-code 1 --python tools/build_raf_pilot.py
Exports a metre-scale skinned GLB with Idle, Walk and Seated actions.
"""
import bpy, math, pathlib
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
materials={}
def mat(name,color,rough=.85):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
    materials[name]=m;return m
cloth=mat('RAF blue grey wool',(.205,.264,.31));seams=mat('Raised seams',(.17,.218,.258))
shirt=mat('Light cotton shirt',(.70,.69,.60));skin=mat('Skin',(.57,.397,.29),.63)
hair=mat('Dark side parted hair',(.047,.034,.027),.95);lip=mat('Restrained facial detail',(.28,.14,.11),.65)
leather=mat('Dark leather boots and belt',(.033,.03,.025),.60);metal=mat('Dull buttons',(.34,.29,.19),.48)
white=mat('Embroidered wings',(.69,.69,.61));eyes=mat('Eyes',(.25,.24,.20),.5)
objects=[]
def finish(o,name,m,bone):
    o.name=name;o.data.materials.append(m)
    for p in o.data.polygons:p.use_smooth=True
    g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    objects.append(o);return o

def ell(name,pos,size,m,bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=10,location=pos)
    o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,bone)
def box(name,pos,size,m,bone,bevel=.008):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Soft garment edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,m,bone)
def poly(name,verts,faces,m,bone):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,name,m,bone)
def tube(name,rings,m,weights,sections=16):
    # Continuous garment tubes with blended weights across elbows/knees.
    verts=[];faces=[]
    for x,y,z,rx,ry in rings:
        for n in range(sections):
            a=n*math.tau/sections;verts.append((x+rx*math.cos(a),y+ry*math.sin(a),z))
    for r in range(len(rings)-1):
        for n in range(sections):
            a=r*sections+n;b=r*sections+(n+1)%sections
            faces.append((a,b,b+sections,a+sections))
    faces += [tuple(range(sections-1,-1,-1)),tuple((len(rings)-1)*sections+n for n in range(sections))]
    first=weights[0]
    initial=first[0] if isinstance(first[0],str) else first[0][0]
    o=poly(name,verts,faces,m,initial)
    for g in list(o.vertex_groups):o.vertex_groups.remove(g)
    for r,assignment in enumerate(weights):
        if isinstance(assignment[0],str):assignment=[assignment]
        for bone,w in assignment:
            g=o.vertex_groups.get(bone) or o.vertex_groups.new(name=bone)
            g.add(list(range(r*sections,(r+1)*sections)),w,'REPLACE')
    return o
# Rig: Blender Z up, +Y face forward. glTF converts to Godot Y up / -Z forward.
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='RAFPilotRig'
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
bones={}
def bone(name,a,b,parent=None):
    q=rig.data.edit_bones.new(name);q.head=a;q.tail=b
    if parent:q.parent=bones[parent]
    bones[name]=q
bone('Root',(0,0,0),(0,0,.2));bone('Pelvis',(0,0,.92),(0,0,1.04),'Root')
bone('Spine',(0,0,1.04),(0,0,1.23),'Pelvis');bone('Chest',(0,0,1.23),(0,0,1.46),'Spine')
bone('Neck',(0,0,1.46),(0,0,1.58),'Chest');bone('Head',(0,0,1.58),(0,0,1.8),'Neck')
for suffix,side in [('L',1),('R',-1)]:
    bone('UpperArm.'+suffix,(side*.205,0,1.43),(side*.25,0,1.11),'Chest')
    bone('Forearm.'+suffix,(side*.25,0,1.11),(side*.255,.01,.83),'UpperArm.'+suffix)
    bone('Hand.'+suffix,(side*.255,.01,.83),(side*.255,.02,.73),'Forearm.'+suffix)
    bone('Thigh.'+suffix,(side*.105,0,.94),(side*.11,0,.52),'Pelvis')
    bone('Shin.'+suffix,(side*.11,0,.52),(side*.11,0,.12),'Thigh.'+suffix)
    bone('Foot.'+suffix,(side*.11,0,.12),(side*.11,.17,.065),'Shin.'+suffix)
bpy.ops.object.mode_set(mode='OBJECT')
def jacket_surface(x,z):
    profile=[(.94,.177,.125),(.97,.19,.137),(1.06,.173,.121),(1.23,.211,.134),(1.36,.226,.124),(1.43,.19,.092)]
    z=max(profile[0][0],min(profile[-1][0],z))
    for a,b in zip(profile,profile[1:]):
        if a[0]<=z<=b[0]:
            t=(z-a[0])/(b[0]-a[0]);rx=a[1]*(1-t)+b[1]*t;ry=a[2]*(1-t)+b[2]*t
            return ry*math.sqrt(max(.02,1-(x/rx)**2))
    return .09
def fabric_patch(name,x,width,z,height,depth,m):
    verts=[];faces=[];cols=5
    for row in range(3):
        zz=z-height/2+row*height/2
        for col in range(cols):
            xx=x-width/2+col*width/(cols-1)
            verts.append((xx,jacket_surface(xx,zz)+depth,zz))
    for row in range(2):
        for col in range(cols-1):
            a=row*cols+col;faces.append((a,a+cols,a+cols+1,a+1))
    o=poly(name,verts,faces,m,'Chest')
    mod=o.modifiers.new('Fabric thickness','SOLIDIFY');mod.thickness=.003
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
# Shaped jacket, high waist and visible uniform construction.
tube('Jacket',[(0,0,.94,.177,.125),(0,0,.97,.19,.137),(0,0,1.06,.173,.121),(0,0,1.23,.211,.134),(0,0,1.36,.226,.124),(0,0,1.43,.19,.092)],cloth,
 [('Pelvis',1),('Pelvis',1),[('Pelvis',.25),('Spine',.75)],('Chest',1),('Chest',1),('Chest',1)],20)
box('High waistband',(0,0,.969),(.355,.256,.052),seams,'Pelvis',.012)
box('Belt front',(0,.136,.985),(.30,.012,.025),leather,'Pelvis',.003)
box('Buckle',(0,.146,.985),(.026,.009,.023),metal,'Pelvis',.003)
ell('Neck',(0,0,1.54),(.052,.049,.095),skin,'Neck')
poly('Shirt opening',[(-.067,.137,1.43),(.067,.137,1.43),(.028,.146,1.18),(-.028,.146,1.18)],[(0,1,2,3)],shirt,'Chest')
for side in [-1,1]:
    x=side*.108
    fabric_patch('Chest pocket',x,.114,1.244,.133,.004,cloth)
    fabric_patch('Pocket flap',x,.122,1.312,.039,.01,seams)
    fabric_patch('Pocket pleat',x,.014,1.245,.098,.008,seams)
    ell('Pocket button',(x,jacket_surface(x,1.3)+.013,1.3),(.007,.003,.007),metal,'Chest')
    poly('Open jacket lapel',[(side*.026,.159,1.17),(side*.155,.137,1.42),(side*.077,.163,1.486),(side*.033,.17,1.365)],[(0,1,2,3)],seams,'Chest')
    poly('Shirt collar',[(side*.012,.123,1.535),(side*.068,.12,1.53),(side*.128,.165,1.42),(side*.041,.173,1.447)],[(0,1,2,3)],shirt,'Chest')
    box('Epaulette',(side*.173,0,1.442),(.108,.105,.018),seams,'Chest',.005)
    ell('Shoulder button',(side*.13,.015,1.454),(.007,.007,.003),metal,'Chest')
for z in [1.075,1.126,1.177]:ell('Jacket button',(0,.147,z),(.008,.0035,.008),metal,'Spine')
# Small original stitched pilot-wing emblem on the LEFT breast.
ell('Badge centre',(.109,.17,1.36),(.01,.003,.013),white,'Chest')
for side in [-1,1]:
    for i in range(5):
        q=box('Wing badge feather',(.109+side*(.017+i*.008),.166,1.367-i*.002),(.015,.004,.005),white,'Chest',.001)
        q.rotation_euler[1]=side*.14
for suffix,side in [('L',1),('R',-1)]:
    up,fore,hand='UpperArm.'+suffix,'Forearm.'+suffix,'Hand.'+suffix
    tube('Sleeve.'+suffix,[(side*.2,0,1.435,.086,.087),(side*.225,0,1.32,.077,.078),(side*.249,0,1.16,.069,.067),(side*.25,0,1.11,.065,.065),(side*.251,.004,1.06,.061,.062),(side*.255,.009,.9,.051,.052),(side*.255,.01,.839,.05,.049)],cloth,
         [[('Chest',.35),(up,.65)],(up,1),[(up,.85),(fore,.15)],[(up,.5),(fore,.5)],[(up,.15),(fore,.85)],(fore,1),(fore,1)])
    box('Cuff.'+suffix,(side*.255,.011,.862),(.101,.1,.038),seams,fore,.006)
    ell('Hand.'+suffix,(side*.255,.016,.782),(.04,.025,.062),skin,hand)
    ell('Thumb.'+suffix,(side*.222,.032,.801),(.015,.021,.025),skin,hand)
    thigh,shin,foot='Thigh.'+suffix,'Shin.'+suffix,'Foot.'+suffix
    tube('Trouser leg.'+suffix,[(side*.1,0,.96,.10,.124),(side*.104,0,.83,.096,.115),(side*.11,0,.63,.085,.09),(side*.11,.008,.55,.081,.084),(side*.11,.012,.52,.079,.082),(side*.11,.007,.49,.078,.083),(side*.11,0,.35,.072,.075),(side*.11,0,.19,.068,.072),(side*.11,0,.14,.071,.072)],cloth,
         [('Pelvis',1),[('Pelvis',.35),(thigh,.65)],(thigh,1),[(thigh,.75),(shin,.25)],[(thigh,.5),(shin,.5)],[(thigh,.25),(shin,.75)],(shin,1),(shin,1),(shin,1)])
    # Raised crease strips and restrained ankle folds are geometry, not decals.
    box('Pressed thigh crease.'+suffix,(side*.108,.113,.79),(.004,.004,.17),seams,thigh,.001)
    for z in [.20,.23]:ell('Trouser ankle fold.'+suffix,(side*.11,.003,z),(.07,.074,.009),seams,shin)
    ell('Ankle boot.'+suffix,(side*.11,.007,.117),(.068,.076,.097),leather,foot)
    ell('Leather toe.'+suffix,(side*.11,.09,.055),(.071,.147,.049),leather,foot)
    box('Boot sole.'+suffix,(side*.11,.085,.019),(.145,.279,.025),leather,foot,.011)
# Generic restrained face: cheek/jaw silhouette, small eyes, nose and mouth.
tube('Face',[(0,.012,1.59,.062,.071),(0,.009,1.614,.093,.089),(0,.002,1.665,.112,.103),(0,0,1.727,.107,.1),(0,-.003,1.773,.086,.087),(0,-.007,1.8,.026,.034)],skin,[('Head',1)]*6,24)
for side in [-1,1]:
    ell('Ear',(side*.11,-.003,1.682),(.015,.023,.038),skin,'Head')
    ell('Ear fold',(side*.12,.013,1.683),(.006,.009,.023),lip,'Head')
    ell('Eye',(side*.043,.100,1.713),(.014,.003,.006),shirt,'Head')
    ell('Iris',(side*.042,.102,1.713),(.006,.002,.005),eyes,'Head')
    box('Eyebrow',(side*.043,.102,1.731),(.043,.006,.004),hair,'Head',.001)
poly('Nose',[(-.013,.092,1.727),(.013,.092,1.727),(-.018,.101,1.678),(.018,.101,1.678),(0,.143,1.69),(0,.117,1.678)],[(0,1,4),(1,3,4),(3,5,4),(5,2,4),(2,0,4)],skin,'Head')
ell('Lower lip',(0,.099,1.644),(.026,.007,.004),skin,'Head')
box('Closed mouth',(0,.104,1.649),(.044,.004,.0018),lip,'Head',.0005)
# Hair cap with asymmetrical front hairline, cropped nape and an actual side part.
verts=[];faces=[];N=32
for r in range(5):
    t=r/4
    for n in range(N):
        a=n*math.tau/N;front=math.sin(a)
        bottom=1.71+.036*front+.009*math.cos(a)
        z=bottom*(1-t)+1.819*t
        radius=math.sqrt(max(0,1-t*t))
        verts.append((.112*math.cos(a)*radius,.103*math.sin(a)*radius-.007,z))
for r in range(4):
    for n in range(N):faces.append((r*N+n,r*N+(n+1)%N,(r+1)*N+(n+1)%N,(r+1)*N+n))
poly('Short swept hair',verts,faces,hair,'Head')
for y,z in [(.064,1.8),(.035,1.813),(.005,1.818),(-.023,1.813)]:
    ell('Side part',(.037,y,z),(.0017,.016,.0017),lip,'Head')
for o in objects:
    if o.name.startswith(('Open jacket lapel','Shirt opening','Shirt collar')):
        for v in o.data.vertices:
            x,y,z=v.co
            v.co.y=(.058 if z>1.50 else jacket_surface(x,z)) + (.018 if o.name.startswith('Open jacket') else .004)
        mod=o.modifiers.new('Collar thickness','SOLIDIFY');mod.thickness=.002
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    if o.name.startswith(('Wing badge feather','Badge centre')):
        o.location.y=jacket_surface(o.location.x,o.location.z)+.007
# Creases share the trouser's hip blend so they never peel off when seated.
for o in objects:
    if o.name.startswith('Pressed thigh crease'):
        thigh=o.vertex_groups[0]
        pelvis=o.vertex_groups.new(name='Pelvis')
        for v in o.data.vertices:
            z=v.co.z+o.location.z
            weight=.35*(z-.63)/.20 if z<=.83 else .35+.65*(z-.83)/.13
            weight=max(0,min(1,weight))
            thigh.add([v.index],1-weight,'REPLACE');pelvis.add([v.index],weight,'REPLACE')
# Apply the armature to actual geometry. Keep all weights in source/export.
for o in objects:
    o.parent=rig
    mod=o.modifiers.new('Pilot skin','ARMATURE');mod.object=rig
# Combine compatible skinned pieces to keep draw calls modest.
groups={name:[o for o in objects if (o.vertex_groups.get('Head') is not None)==head] for name,head in [('PilotHead',True),('PilotBody',False)]}
for group_name,selected in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for o in selected:o.select_set(True)
    bpy.context.view_layer.objects.active=selected[0]
    bpy.ops.object.join();selected[0].name=group_name
# Export actions from NLA tracks, giving Godot one consistent Skeleton3D.
rig.animation_data_create();bpy.context.scene.render.fps=30
for name,length in [('Idle',60),('Walk',30),('Seated',30)]:
    action=bpy.data.actions.new(name);rig.animation_data.action=action
    for f in range(1,length+1):
        phase=(f-1)/max(length-1,1)*math.tau
        for p in rig.pose.bones:p.rotation_mode='XYZ';p.rotation_euler=(0,0,0);p.location=(0,0,0)
        if name=='Idle':
            rig.pose.bones['Chest'].rotation_euler.x=math.sin(phase)*.012
            rig.pose.bones['Head'].rotation_euler.z=math.sin(phase)*.01
        elif name=='Walk':
            for suffix,side in [('L',1),('R',-1)]:
                swing=math.sin(phase)*side
                rig.pose.bones['Thigh.'+suffix].rotation_euler.x=swing*.56
                rig.pose.bones['Shin.'+suffix].rotation_euler.x=-max(0,-swing)*.7
                rig.pose.bones['UpperArm.'+suffix].rotation_euler.x=-swing*.24
                rig.pose.bones['Forearm.'+suffix].rotation_euler.x=.13
            rig.pose.bones['Pelvis'].location.z=abs(math.sin(phase))*.014
        else:
            for suffix,side in [('L',1),('R',-1)]:
                rig.pose.bones['Thigh.'+suffix].rotation_euler.x=math.radians(82)
                rig.pose.bones['Shin.'+suffix].rotation_euler.x=math.radians(-82)
                rig.pose.bones['UpperArm.'+suffix].rotation_euler.x=math.radians(48)
                rig.pose.bones['UpperArm.'+suffix].rotation_euler.z=side*math.radians(12 if suffix=='L' else 40)
                rig.pose.bones['Forearm.'+suffix].rotation_euler.x=math.radians(35)
        for p in rig.pose.bones:
            p.keyframe_insert(data_path='rotation_euler',frame=f,group=p.name)
            p.keyframe_insert(data_path='location',frame=f,group=p.name)
    rig.animation_data.action=None
    track=rig.animation_data.nla_tracks.new();track.name=name
    strip=track.strips.new(name,1,action);strip.action_frame_start=1;strip.action_frame_end=length
    track.mute=True
# Muted source tracks still export explicitly as NLA actions.
for track in rig.animation_data.nla_tracks:track.mute=True
bpy.context.scene.frame_set(0)
for p in rig.pose.bones:p.rotation_euler=(0,0,0);p.location=(0,0,0)
bpy.context.view_layer.update()
# Save editable original source as well as runtime asset.
output=ROOT/'assets/characters';output.mkdir(parents=True,exist_ok=True)
source=output/'source';source.mkdir(exist_ok=True)
(source/'.gdignore').write_text('')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(source/'raf_pilot.blend'))
bpy.ops.export_scene.gltf(filepath=str(output/'raf_pilot.glb'),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_skins=True,export_yup=True,export_apply=False)
print('RAF PILOT:',len(objects),'mesh parts;',len(bones),'bones')
