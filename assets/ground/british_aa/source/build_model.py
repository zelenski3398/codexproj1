import trimesh as t, numpy as np, math, pathlib, json, zipfile
from trimesh.transformations import rotation_matrix, translation_matrix
P=pathlib.Path(__file__).parent
s=t.Scene(); mats={}
for name,col in [('olive',[86,91,60,255]),('edge',[65,70,49,255]),('steel',[48,51,49,255]),('sand',[168,148,108,255]),('sandlight',[186,167,126,255]),('earth',[127,112,82,255]),('wood',[98,81,48,255]),('brass',[156,124,62,255])]:
 mats[name]=t.visual.material.PBRMaterial(name=name,baseColorFactor=col,metallicFactor=.6 if name in ['steel','brass'] else .05,roughnessFactor=.86)
s.graph.update(frame_to='Emplacement',frame_from='world')
s.graph.update(frame_to='YawPivot',frame_from='Emplacement',matrix=translation_matrix([0,.55,0]))
s.graph.update(frame_to='ElevationPivot',frame_from='YawPivot',matrix=translation_matrix([0,.85,0])@rotation_matrix(math.radians(32),[1,0,0]))
idx=0
def add(mesh,name,mat='olive',parent='Emplacement',pos=None,rot=None):
 global idx
 idx+=1
 mesh.visual=t.visual.TextureVisuals(material=mats[mat]); M=np.eye(4)
 if rot is not None:M=rot
 if pos is not None:M=translation_matrix(pos)@M
 s.add_geometry(mesh,node_name=name+'_'+str(idx),geom_name=name+'_'+str(idx),parent_node_name=parent,transform=M)
def box(name,size,pos,mat='olive',parent='Emplacement',rot=None):add(t.creation.box(size),name,mat,parent,pos,rot)
def cyl(name,r,h,pos,mat='olive',parent='Emplacement',axis='y'):
 R=rotation_matrix(math.pi/2,[1,0,0]) if axis=='y' else rotation_matrix(math.pi/2,[0,1,0]) if axis=='x' else np.eye(4)
 add(t.creation.cylinder(r,h,sections=24),name,mat,parent,pos,R)
def rod(name,a,b,r,mat='olive',parent='Emplacement'):
 a=np.array(a);b=np.array(b);m=t.creation.cylinder(r,np.linalg.norm(b-a),sections=12);M=t.geometry.align_vectors([0,0,1],b-a);add(m,name,mat,parent,(a+b)/2,M)
# Low-profile removable earth pad and sandbag ring with entry gap.
cyl('GroundPad',3.7,.12,[0,-.06,0],'earth')
for row in range(4):
 for j in range(34):
  angle=2*math.pi*(j+.5*(row%2))/34
  if abs(math.atan2(math.sin(angle-math.pi/2),math.cos(angle-math.pi/2)))<.24:continue
  m=t.creation.icosphere(subdivisions=2);m.apply_scale([.33,.14,.22])
  add(m,'Sandbag','sandlight' if (j+row)%4==0 else 'sand',pos=[3.25*math.cos(angle),.14+row*.245,3.25*math.sin(angle)],rot=rotation_matrix(-angle-math.pi/2,[0,1,0]))
# Stabilised cruciform mount
for a in [0,math.pi/2,math.pi,3*math.pi/2]:
 R=rotation_matrix(a,[0,1,0]);box('Outrigger',[.22,.18,2.35],[math.sin(a)*.95,.2,math.cos(a)*.95],'olive',rot=R)
 cyl('LevellingFoot',.23,.09,[math.sin(a)*2,.045,math.cos(a)*2],'steel')
 cyl('Jack',.055,.38,[math.sin(a)*2,.25,math.cos(a)*2],'steel')
 box('JackHandle',[.42,.045,.045],[math.sin(a)*2,.46,math.cos(a)*2],'steel')
cyl('Pedestal',.39,.52,[0,.3,0]);cyl('TraverseRing',.56,.13,[0,.56,0],'steel')
box('RotatingPlatform',[1.75,.14,1.5],[0,.12,.15],'olive','YawPivot')
for x in [-.42,.42]:
 box('TrunnionSupport',[.16,.73,.44],[x,.48,0],'olive','YawPivot')
 cyl('Trunnion',.16,.20,[x,.85,0],'steel','YawPivot','x')
# Elevating assembly points along local -Z
box('Breech',[.49,.38,.85],[0,0,.19],'olive','ElevationPivot')
box('BreechCover',[.43,.10,.63],[0,.23,.20],'edge','ElevationPivot')
cyl('BarrelJacket',.115,.78,[0,0,-.61],'olive','ElevationPivot','z')
cyl('LongBarrel',.052,1.78,[0,0,-1.84],'steel','ElevationPivot','z')
for z in [-.38,-.92,-1.05]:cyl('BarrelCollar',.129,.055,[0,0,z],'edge','ElevationPivot','z')
# Open muzzle annulus, dark interior
add(t.creation.annulus(r_min=.032,r_max=.092,height=.18,sections=24),'Muzzle','steel','ElevationPivot',[0,0,-2.81])
s.graph.update(frame_to='Muzzle',frame_from='ElevationPivot',matrix=translation_matrix([0,0,-2.91]))
for x in [-.18,.18]:cyl('RecoilCylinder',.065,.8,[x,-.19,-.31],'edge','ElevationPivot','z')
box('FeedGuide',[.27,.32,.23],[0,.38,.12],'olive','ElevationPivot')
for x in [-.09,-.03,.03,.09]:cyl('DisplayAmmo',.024,.27,[x,.56,.12],'brass','ElevationPivot')
# Operator seats, controls and ring sights
for side in [-1,1]:
 x=side*.73
 box('Seat',[.39,.075,.40],[x,.43,.65],'edge','YawPivot')
 box('SeatBack',[.39,.30,.055],[x,.61,.86],'olive','YawPivot')
 rod('SeatPost',[x,.15,.65],[x,.41,.65],.045,parent='YawPivot')
 box('FootRest',[.32,.05,.37],[x,.20,-.22],'steel','YawPivot')
 rod('ControlColumn',[x,.2,-.06],[x,.67,-.06],.035,parent='YawPivot')
 ring=t.creation.annulus(.14,.165,.025,sections=24)
 add(ring,'Handwheel','steel','YawPivot',[x,.69,-.06],rotation_matrix(math.pi/2,[0,1,0]))
 rod('WheelSpoke',[x,.55,-.06],[x,.83,-.06],.012,'steel','YawPivot')
 rod('SightArm',[side*.24,.16,-.05],[side*.48,.59,-.2],.018,'steel','ElevationPivot')
 add(t.creation.annulus(.115,.124,.014,sections=32),'RingSight','steel','ElevationPivot',[side*.48,.63,-.2])
 rod('SightCross',[side*.48-.115,.63,-.2],[side*.48+.115,.63,-.2],.004,'steel','ElevationPivot')
 rod('SightCross',[side*.48,.515,-.2],[side*.48,.745,-.2],.004,'steel','ElevationPivot')
for x in [-.63,.63]:
 for z in [-.35,.5]:cyl('PlatformBolt',.033,.035,[x,.21,z],'steel','YawPivot')
for k,(x,z) in enumerate([(-2.1,1.3),(-2.1,.7),(2.0,1.3)]):
 box('AmmoCrate',[.70,.35,.42],[x,.19,z],'wood')
 for dx in [-.24,.24]:box('CrateBand',[.035,.37,.44],[x+dx,.19,z],'steel')
 box('CrateLid',[.73,.045,.45],[x,.39,z],'wood')
out=P/'British_AA_Emplacement.glb';s.export(out)
# Validate binary container and geometry
loaded=t.load(out,force='scene');assert len(loaded.geometry)>100
assert np.isfinite(loaded.bounds).all()
print(json.dumps({'meshes':len(loaded.geometry),'triangles':sum(len(g.faces) for g in loaded.geometry.values()),'bounds':loaded.bounds.tolist(),'bytes':out.stat().st_size}))
# Render actual mesh triangles for a review image.
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
fig=plt.figure(figsize=(12,9),facecolor='#e6e3db');ax=fig.add_subplot(111,projection='3d',computed_zorder=False);ax.set_facecolor('#e6e3db')
for node in s.graph.nodes_geometry:
 M,g=s.graph[node];mesh=s.geometry[g].copy();mesh.apply_transform(M)
 v=mesh.vertices[:,[0,2,1]]; col=np.array(mesh.visual.material.baseColorFactor[:3])/255
 normal=mesh.face_normals; light=np.array([-.4,.8,-.4]);shade=np.clip(.64+.36*(normal@light),.28,1)
 pc=Poly3DCollection(v[mesh.faces],facecolors=np.clip(col[None,:]*shade[:,None],0,1),linewidths=0,rasterized=True)
 ax.add_collection3d(pc)
ax.set_xlim(-3.8,3.8);ax.set_ylim(-3.8,3.8);ax.set_zlim(0,3.3);ax.set_box_aspect((7.6,7.6,3.3));ax.view_init(28,55);ax.set_axis_off()
fig.suptitle('BRITISH LIGHT AA EMPLACEMENT',fontsize=19,fontweight='bold',color='#343b30',y=.94)
fig.text(.5,.055,'Bofors-inspired game asset  /  articulated mount  /  metre scale',ha='center',color='#52594d',fontsize=11)
plt.savefig(P/'Preview.png',dpi=150,bbox_inches='tight');plt.close()
(P/'README.txt').write_text('''BRITISH LIGHT AA EMPLACEMENT — ORIGINAL GAME ASSET

Simplified Bofors-inspired British WWII static light AA position, not a measured historical replica. One gun emplacement; duplicate it to form a battery. No crew or firing/audio scripts.

Import British_AA_Emplacement.glb into Godot. Units are metres, Y up. Ground is Y=0. Footprint approximately 7.4 m across. Place root at the terrain surface; level the local terrain or remove the GroundPad mesh if needed.

Node structure: Emplacement > YawPivot > ElevationPivot > Muzzle.
Rotate YawPivot around local Y for traverse. ElevationPivot is initially elevated 32 degrees; set local rotation X to the desired elevation, rather than adding 32 degrees again. Gun forward is local -Z. Muzzle is an empty transform at the barrel exit for muzzle flashes/projectile spawning. Operator seats rotate with the mount; barrel, breech, ammunition and sights elevate together.

Materials are embedded PBR colours; no external textures required. No collisions are supplied: add simplified static collision for the emplacement and appropriate gun hitboxes in Godot. Sandbags are individually modelled; consider merging static pieces or generating LODs for many instances. This asset is visually checked but has not been tested inside your Godot project.

Preview.png is rendered from the actual mesh. build_model.py is the editable generator (Python with trimesh, numpy, matplotlib).

Historical context reference: https://film.iwmcollections.org.uk/record/23693 — British Bofors battery footage. Geometry is original and approximate, not copied from a museum asset.
''')
with zipfile.ZipFile(P/'British_AA_Emplacement_Pack.zip','w',zipfile.ZIP_DEFLATED) as z:
 for f in ['British_AA_Emplacement.glb','Preview.png','README.txt','build_model.py']:z.write(P/f,f)
