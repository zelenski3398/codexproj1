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
    def scene(self,meshes):
        scene=trimesh.Scene()
        if meshes:scene.add_geometry(trimesh.util.concatenate(meshes))
        return scene
