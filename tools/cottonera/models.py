"""Original unplaced architecture templates, parameterised by SOURCE geometry.
These models are schematic wartime assets, not surveyed historic reconstructions.
No function supplies a geographic location or fabricates a street/fort outline.
"""
import numpy as np
import trimesh
from shapely.geometry import Polygon,Point,LineString,box
STONE=[179,165,136,255];TRIM=[196,183,153,255];ROOF=[145,137,120,255];DARK=[45,52,48,255];GREEN=[65,78,65,255];METAL=[72,79,76,255]
def polygons(shape):
    if shape.is_empty:return []
    if shape.geom_type=='Polygon':return [shape]
    if hasattr(shape,'geoms'):return [p for part in shape.geoms for p in polygons(part)]
    return []
class Models:
    def __init__(self):self.mid=[];self.near=[];self.far=[];self.collision=[]
    def add(self,mesh,colour=STONE,solid=True,detail=False,skyline=False):
        assert np.isfinite(mesh.vertices).all()
        mesh.visual.face_colors=np.array(colour,dtype=np.uint8)
        (self.near if detail else self.mid).append(mesh)
        if solid:self.collision.append(mesh.copy())
        if skyline:self.far.append(mesh.copy())
        return mesh
    def prism(self,shape,bottom,top,colour=STONE,solid=True,detail=False,skyline=False):
        if top<=bottom:return
        for poly in polygons(shape):
            if poly.area<.01:continue
            mesh=trimesh.creation.extrude_polygon(poly,top-bottom,engine='triangle')
            mesh.vertices=mesh.vertices[:,[0,2,1]];mesh.invert();mesh.vertices[:,1]+=bottom
            self.add(mesh,colour,solid,detail,skyline)
    def cube(self,x,z,sx,sz,bottom,height,colour=STONE,solid=True,detail=False,skyline=False):
        mesh=trimesh.creation.box(extents=[sx,height,sz]);mesh.apply_translation([x,bottom+height/2,z])
        return self.add(mesh,colour,solid,detail,skyline)
    def rod(self,a,b,radius,colour=METAL,solid=False):
        self.add(trimesh.creation.cylinder(radius=radius,segment=np.array([a,b]),sections=8),colour,solid,True)
    def pane(self,a,b,bottom,height,colour=DARK):
        mesh=trimesh.Trimesh([[a[0],bottom,a[1]],[b[0],bottom,b[1]],[b[0],bottom+height,b[1]],[a[0],bottom+height,a[1]]],[[0,1,2],[0,2,3],[2,1,0],[3,2,0]],process=False)
        self.add(mesh,colour,False,True)
    def fort_st_angelo(self,outline,base,ground_top):
        # Harbour fortress asset: broad irregular platform, raised battery ring,
        # casemated inner enclosure and keep terraces. No fantasy round towers.
        self.prism(outline,base,ground_top+1,STONE,True,skyline=True)
        for inset,rise in [(1.5,6),(12,12),(25,17)]:
            tier=outline.buffer(-inset,join_style=2)
            for poly in polygons(tier):
                if poly.area<80:continue
                ring=poly.difference(poly.buffer(-5,join_style=2))
                self.prism(ring,ground_top,ground_top+rise,STONE,True,skyline=True)
                self.prism(poly.difference(poly.buffer(-.9)),ground_top+rise,ground_top+rise+1.1,TRIM,True,True)
        for poly in polygons(outline.buffer(-28)):
            # Inner keep mass and roof remain inside the supplied outline.
            inner=poly.intersection(box(*poly.bounds))
            self.prism(inner,ground_top,ground_top+9,ROOF,True,skyline=True)
            break
    def house(self,outline,base,roof):
        # Retain the source courtyard holes; never randomly replace its footprint.
        self.prism(outline,base,roof,STONE,True,skyline=True)
        self.prism(outline,roof+.02,roof+.16,ROOF,False,True)
        self.prism(outline.difference(outline.buffer(-.3)),roof+.16,roof+.9,TRIM,False,True)
        for poly in polygons(outline):
            ring=np.asarray(poly.exterior.coords)
            for a,b in zip(ring[:-1],ring[1:]):
                length=np.linalg.norm(b-a)
                if length<3:continue
                direction=(b-a)/length;normal=np.array([direction[1],-direction[0]])
                if poly.contains(Point(*((a+b)/2+normal))):normal=-normal
                for station in np.arange(1.8,length-1,4):
                    mid=a+direction*station+normal*.04
                    for floor in range(max(1,min(4,int((roof-base)/3.3)))):
                        self.pane(mid-direction*.5,mid+direction*.5,roof-3.2*(floor+1)+.7,1.5)
                mid=(a+b)/2+normal*.05
                self.pane(mid-direction*.6,mid+direction*.6,base+.2,2.2,GREEN)
                if length>9:
                    balcony=LineString([mid-direction*.8,mid+direction*.8]).buffer(.4,cap_style=2)
                    self.prism(balcony,base+3.3,base+4.5,GREEN,False,True)
    def gardjola(self,footprint,base):
        # Unplaced sentry/lookout asset, only sited from a supplied feature.
        self.prism(footprint,base,base+1.3,STONE,True,skyline=True)
        centre=np.array(footprint.centroid.coords[0]);radius=max(.8,min(2.5,np.sqrt(footprint.area)/2.2))
        hut=Point(*centre).buffer(radius,resolution=2)
        walls=hut.difference(hut.buffer(-.45))
        self.prism(walls,base+1.3,base+4.2,STONE,True,skyline=True)
        self.prism(hut.buffer(.2),base+4.2,base+4.7,TRIM,True,skyline=True)
        for x,z in np.asarray(hut.exterior.coords)[:-1]:
            direction=np.array([x,z])-centre;direction/=np.linalg.norm(direction)
            mid=np.array([x,z])+direction*.04;tangent=np.array([-direction[1],direction[0]])
            self.pane(mid-tangent*.3,mid+tangent*.3,base+2.3,1.1)
    def battered_wall(self,a,b,bottom,top,width=6):
        a=np.asarray(a,dtype=float);b=np.asarray(b,dtype=float);d=b-a;d/=np.linalg.norm(d);n=np.array([d[1],-d[0]])
        lower=np.array([a+n*width/2,b+n*width/2,b-n*width/2,a-n*width/2])
        upper=np.array([a+n*(width/2-1),b+n*(width/2-1),b-n*(width/2-1),a-n*(width/2-1)])
        v=np.vstack([np.c_[lower[:,0],np.full(4,bottom),lower[:,1]],np.c_[upper[:,0],np.full(4,top),upper[:,1]]])
        faces=[[0,2,1],[0,3,2],[4,5,6],[4,6,7]]
        for j in range(4):k=(j+1)%4;faces.extend([[j,k,4+k],[j,4+k,4+j]])
        mesh=trimesh.Trimesh(v,faces,process=False);mesh.fix_normals();self.add(mesh,STONE,True,skyline=True)
        walk=Polygon(upper);self.prism(walk.difference(walk.buffer(-.7)),top,top+1.1,TRIM,True,True)
    def bastion(self,outline,base,top):
        # Only mapped angular polygons; no circle/regular-star fallback.
        self.prism(outline,base,top,STONE,True,skyline=True)
        self.prism(outline.difference(outline.buffer(-1)),top,top+1.2,TRIM,True,True)
    def gate(self,centre,bottom,width=7,depth=5,bearing=0):
        opening=width/2;spring=4.5
        outside=box(-opening-3,0,opening+3,12)
        arch=[[-opening,0],[opening,0],[opening,spring]]
        arch.extend([[opening*np.cos(t),spring+opening*np.sin(t)] for t in np.linspace(0,np.pi,20)])
        arch.append([-opening,0]);face=outside.difference(Polygon(arch))
        mesh=trimesh.creation.extrude_polygon(face,depth,engine='triangle');mesh.vertices[:,2]-=depth/2
        # Rotate the real gate void to the source-specified passage bearing.
        mesh.apply_transform(trimesh.transformations.rotation_matrix(bearing,[0,1,0]));mesh.apply_translation([centre[0],bottom,centre[1]])
        self.add(mesh,STONE,True,skyline=True)
        cap=trimesh.creation.box(extents=[width+7,1,depth+1]);cap.apply_translation([0,12,0]);cap.apply_transform(trimesh.transformations.rotation_matrix(bearing,[0,1,0]));cap.apply_translation([centre[0],bottom,centre[1]])
        self.add(cap,TRIM,True)
    def warehouse(self,outline,base,roof):
        self.prism(outline,base,roof,[131,132,120,255],True,skyline=True)
        self.prism(outline,roof+.05,roof+.45,METAL,False,True)
        for poly in polygons(outline):
            a,b=np.asarray(poly.exterior.coords)[:2];direction=(b-a)/np.linalg.norm(b-a);mid=(a+b)/2
            self.pane(mid-direction*1.7,mid+direction*1.7,base+.1,min(4,roof-base-1),DARK)
    def crane(self,point,base,bearing=0):
        x,z=point;self.cube(x,z,3.5,3.5,base,1.4,METAL)
        self.cube(x,z,1.5,1.5,base+1.4,16,METAL,True,skyline=True)
        self.cube(x,z,4,3,base+14.5,3,METAL,True)
        direction=np.array([np.sin(bearing),np.cos(bearing)])
        start=np.array([x,base+17,z]);end=np.array([x+direction[0]*19,base+22,z+direction[1]*19])
        self.rod(start,end,.4);self.rod(start+[0,4,0],end,.15)
        self.rod(end,end-[0,12,0],.07)
        # Cheap far boom; it is still geometry, not an explosion/marker sprite.
        boom=trimesh.creation.cylinder(radius=.45,segment=np.array([start,end]),sections=6);self.add(boom,METAL,False,skyline=True)
    def dry_dock(self,outline,quay_top=4):
        # Compiler permits this only over a supplied existing WATER footprint.
        # Floor above the unchanged sea prevents water bleeding into the dock;
        # depth is deliberately schematic until historical section data exist.
        self.prism(outline,.06,.18,[106,110,105,255],True,skyline=True)
        ring=outline.difference(outline.buffer(-1.1,join_style=2))
        self.prism(ring,.18,quay_top,STONE,True,skyline=True)
        for inset in [1.2,2.0]:
            edge=outline.buffer(-inset).difference(outline.buffer(-inset-.35))
            self.prism(edge,quay_top-1,quay_top-.7,TRIM,False,True)
    def dome(self,x,z,bottom,radius,height):
        sectors=24;rings=8;v=[];faces=[]
        for row in range(rings+1):
            t=row/rings*(np.pi/2-.01)
            for col in range(sectors):
                a=col/sectors*2*np.pi;v.append([x+radius*np.cos(t)*np.cos(a),bottom+height*np.sin(t),z+radius*np.cos(t)*np.sin(a)])
        for row in range(rings):
            for col in range(sectors):
                a=row*sectors+col;b=row*sectors+(col+1)%sectors;c=(row+1)*sectors+(col+1)%sectors;d=(row+1)*sectors+col;faces.extend([[a,b,c],[a,c,d]])
        mesh=trimesh.Trimesh(v,faces,process=False);mesh.fix_normals();self.add(mesh,STONE,True,skyline=True)
        self.cube(x,z,1,1,bottom+height,2,TRIM,False,True)
        self.rod([x,bottom+height+2,z],[x,bottom+height+3,z],.1,TRIM)
        self.rod([x-.4,bottom+height+2.65,z],[x+.4,bottom+height+2.65,z],.1,TRIM)
    def church(self,outline,base,roof,twin=True):
        self.prism(outline,base,roof,STONE,True,skyline=True)
        poly=max(polygons(outline),key=lambda p:p.area);minx,minz,maxx,maxz=poly.bounds;cx,cz=np.array(poly.representative_point().coords[0])
        # Keep all added masses within the actual supplied building footprint.
        for tx in ([minx+(maxx-minx)*.2,maxx-(maxx-minx)*.2] if twin else [minx+(maxx-minx)*.2]):
            tower=box(tx-3,minz+2,tx+3,minz+9).intersection(poly)
            self.prism(tower,roof,roof+9,STONE,True,skyline=True)
            self.prism(tower.buffer(.2).intersection(poly),roof+9,roof+10,TRIM,True)
        radius=min(8,poly.boundary.distance(Point(cx,cz))*.65)
        if radius>2:self.dome(cx,cz,roof,radius,radius*1.15)
        # Geometry-only window/door panels and stone framing, no photo texture.
        a=np.array([minx,minz]);b=np.array([maxx,minz]);middle=(a+b)/2
        self.pane(middle+[-2,-.05],middle+[2,-.05],base+.1,5.5)
        for x in np.linspace(minx+1,maxx-1,5):self.cube(x,minz-.1,.55,.5,base,roof-base,TRIM,False,True)
    def palace(self,outline,base,roof):
        self.house(outline,base,roof)
        self.prism(outline.difference(outline.buffer(-.45)),roof,roof+1.2,TRIM,False,True)
    def scene(self,meshes):
        scene=trimesh.Scene()
        if meshes:scene.add_geometry(trimesh.util.concatenate(meshes))
        return scene
