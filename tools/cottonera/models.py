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
    def scene(self,meshes):
        scene=trimesh.Scene()
        if meshes:scene.add_geometry(trimesh.util.concatenate(meshes))
        return scene
