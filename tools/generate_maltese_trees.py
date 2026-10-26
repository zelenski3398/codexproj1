"""Original reusable low-poly Mediterranean trees, metres, Y-up.
Opaque vertex-coloured bark/foliage, shared runtime material; no alpha cards.
"""
from pathlib import Path
import json
import numpy as np
import trimesh
OUT=Path(__file__).resolve().parents[1]/'assets/malta/vegetation'

def limb(points,radii,colour,segments=7):
    vertices=[];faces=[];points=np.array(points,float)
    for i,(point,radius) in enumerate(zip(points,radii)):
        tangent=points[min(i+1,len(points)-1)]-points[max(i-1,0)]
        tangent/=np.linalg.norm(tangent)
        side=np.cross(tangent,[0,0,1]);side/=np.linalg.norm(side);other=np.cross(tangent,side)
        for j in range(segments):vertices.append(point+radius*(side*np.cos(j*np.pi*2/segments)+other*np.sin(j*np.pi*2/segments)))
        if i:
            for j in range(segments):
                a=(i-1)*segments+j;b=(i-1)*segments+(j+1)%segments;c=i*segments+j;d=i*segments+(j+1)%segments
                faces.extend([[a,c,b],[b,c,d]])
    mesh=trimesh.Trimesh(vertices,faces,process=False)
    mesh.visual.vertex_colors=np.tile([*colour,255],(len(vertices),1))
    mesh.fix_normals();return mesh

def ellipsoid(centre,scale,colour,detail,rng):
    rng=np.random.default_rng(int(sum(abs(float(v))*1009 for v in centre)+sum(scale)*97))
    mesh=trimesh.creation.icosphere(subdivisions=detail)
    mesh.vertices*=np.array(scale)*(1+rng.uniform(-.055,.055,(len(mesh.vertices),1)))
    mesh.apply_translation(centre)
    tones=np.array(colour)[None,:]+rng.integers(-5,6,(len(mesh.vertices),1))
    mesh.visual.vertex_colors=np.c_[np.clip(tones,0,255),np.full(len(mesh.vertices),255)]
    return mesh

def create(species,variant,lod):
    rng=np.random.default_rng(194200+variant+{'carob':0,'olive':10,'aleppo_pine':20}[species])
    parts=[];bark={'carob':[91,83,65],'olive':[125,119,100],'aleppo_pine':[116,104,86]}[species]
    leaf={'carob':[51,77,43],'olive':[122,136,116],'aleppo_pine':[68,95,62]}[species]
    segments=7 if lod=='near' else 5;detail=1 if lod=='near' else 0
    if species=='carob':
        h=[5.8,6.7,5.3][variant];spread=[4.1,4.7,4.4][variant]
        trunk=[[0,0,0],[.12,.9,.08],[-.18,1.8,.05],[.2,2.6,-.15]]
        parts.append(limb(trunk,[.48,.39,.33,.22],bark,segments))
        centres=[]
        for i in range(7):
            a=i*np.pi*2/7+.2*variant;r=spread*(.25 if i==0 else .58)
            centre=np.array([np.cos(a)*r,h*.65+rng.uniform(-.3,.35),np.sin(a)*r])
            centres.append(centre)
            parts.append(limb([trunk[2],centre*[.5,.85,.5],centre],[.26,.13,.035],bark,segments))
            parts.append(ellipsoid(centre,[spread*.57,h*.29,spread*.54],np.array(leaf)+rng.integers(-4,5),detail,rng))
        parts.append(ellipsoid([0,h*.78,0],[spread*.58,h*.27,spread*.58],leaf,detail,rng))
    elif species=='olive':
        h=[5.4,6.4,5.9][variant];spread=[3.7,4.3,3.8][variant]
        trunk=[[0,0,0],[.2,.65,.1],[-.12,1.25,.18],[.25,2.05,-.12],[.02,2.7,-.28]]
        parts.append(limb(trunk,[.43,.38,.31,.24,.12],bark,segments))
        for i in range(9 if variant!=1 else 11):
            a=i*2.399+variant*.7;r=spread*rng.uniform(.35,.85)
            centre=np.array([np.cos(a)*r,h*rng.uniform(.57,.89),np.sin(a)*r])
            fork=np.array([centre[0]*.4,2.1+rng.uniform(0,.8),centre[2]*.4])
            parts.append(limb([trunk[2],fork,centre],[.18,.10,.025],bark,segments))
            parts.append(ellipsoid(centre,[spread*rng.uniform(.22,.32),h*.14,spread*.25],np.array(leaf)+rng.integers(-11,12),detail,rng))
    else:
        h=[8.4,11.8,10.4][variant]
        trunk=[[0,0,0],[.1,h*.28,-.08],[.32,h*.53,.1],[.48 if variant==1 else -.15,h*.77,.15],[.55 if variant==1 else -.25,h*.95,.2]]
        parts.append(limb(trunk,[.25,.20,.15,.09,.025],bark,segments))
        if variant==0:
            # Young pine: an uneven conical crown with separated branch whorls.
            for tier in range(4):
                y=h*(.43+tier*.145);radius=2.7-tier*.59
                for j in range(3):
                    a=j*2*np.pi/3+tier*.85
                    centre=[np.cos(a)*radius*.5,y,np.sin(a)*radius*.5]
                    parts.append(limb([[.1,y-.5,0],centre],[.065,.02],bark,segments))
                    parts.append(ellipsoid(centre,[radius*.66,.9,radius*.60],leaf,detail,rng))
        else:
            # Mature pines: raised, asymmetric umbrella/needle clusters.
            for i in range(9):
                a=i*2.399+variant;r=rng.uniform(1.4,3.2)
                centre=np.array([np.cos(a)*r+(.8 if variant==1 else -.5),h*rng.uniform(.65,.91),np.sin(a)*r])
                parts.append(limb([trunk[2],[centre[0]*.55,centre[1]-.8,centre[2]*.55],centre],[.10,.055,.015],bark,segments))
                parts.append(ellipsoid(centre,[1.5,.72,1.28],np.array(leaf)+rng.integers(-5,6),detail,rng))
    mesh=trimesh.util.concatenate(parts);_=mesh.vertex_normals
    return mesh

def build():
    OUT.mkdir(parents=True,exist_ok=True);report={'units':'metres','original':True,'species':{}}
    for species in ['carob','olive','aleppo_pine']:
        report['species'][species]=[]
        for variant in range(3):
            record={'variant':variant,'trunk_radius':.45 if species!='aleppo_pine' else .25,'trunk_collision_height':2.8 if species!='aleppo_pine' else 4.0}
            for lod in ['near','far']:
                mesh=create(species,variant,lod);name=f'{species}_{variant}_{lod}.glb'
                (OUT/name).write_bytes(trimesh.Scene(mesh).export(file_type='glb'))
                record[lod]='res://assets/malta/vegetation/'+name;record[lod+'_triangles']=len(mesh.faces)
                if lod=='near':
                    record['height']=float(mesh.bounds[1,1]);record['canopy_radius']=float(max(np.linalg.norm(mesh.vertices[:,[0,2]],axis=1)))
            report['species'][species].append(record)
    (OUT/'models.json').write_text(json.dumps(report,indent=2)+'\n')
    (OUT/'ATTRIBUTION.txt').write_text('Original procedurally modelled carob, olive and Aleppo pine assets for Wings Over Malta. Generated by tools/generate_maltese_trees.py. No external tree meshes, photographs or alpha foliage textures. Artistic species silhouettes, not botanical scans.\n')
    print(json.dumps(report),flush=True)
if __name__=='__main__':build()
