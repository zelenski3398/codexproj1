"""Coherent unequal parcels: recursive straight land divisions, not a grid.
All coordinates are local metres; neighbours share the exact same cut geometry.
"""
import numpy as np
from shapely.geometry import Polygon,LineString
from shapely.ops import split

def parcel_group(length,breadth,rng,settings):
    # Slightly tapered perimeter, not a randomly jagged Voronoi patchwork.
    hull=Polygon([(-.5*length,-.44*breadth),(-.2*length,-.51*breadth),(.48*length,-.45*breadth),(.52*length,.26*breadth),(.34*length,.49*breadth),(-.48*length,.45*breadth)])
    leaves=[]
    def divide(poly,depth):
        target=rng.uniform(*settings['plot_area_classes_m2'][rng.choice(['small','medium','large'],p=settings['plot_area_weights'])])
        if poly.area<target*1.5 or depth>=9:
            leaves.append(poly);return
        a,b,c,d=poly.bounds
        along_x=(c-a)>(d-b)*rng.uniform(.8,1.2)
        fraction=rng.uniform(.36,.64)
        origin=np.array([a+(c-a)*fraction,b+(d-b)*fraction])
        angle=(np.pi/2 if along_x else 0)+rng.uniform(-.23,.23)
        axis=np.array([np.cos(angle),np.sin(angle)])*max(length,breadth)*3
        parts=list(split(poly,LineString([origin-axis,origin+axis])).geoms)
        if len(parts)!=2 or min(p.area for p in parts)<settings['minimum_plot_area_m2']:
            leaves.append(poly);return
        for part in parts:divide(part,depth+1)
    divide(hull,0)
    answer=[]
    for poly in leaves:
        if len(poly.exterior.coords)==5 and poly.area>6500 and rng.random()<settings['triangle_probability']:
            corners=list(poly.exterior.coords)[:4]
            answer.extend([Polygon(corners[:3]),Polygon([corners[0],corners[2],corners[3]])])
        else:answer.append(poly)
    return answer
