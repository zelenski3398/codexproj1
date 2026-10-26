"""Baked Mediterranean planting, fully masked in source world metres."""
import json
import numpy as np
from shapely.geometry import Point,LineString
from shapely.ops import unary_union
from shapely import STRtree
from cottonera.geography import ASSET

def place_vegetation(g,allowed,plots,tracks,sections,clusters,settings):
    cfg=settings['vegetation'];rng=np.random.default_rng(cfg['seed'])
    wall_lines=[LineString([a,b]) for a,b,_ in sections]
    barriers=unary_union(wall_lines).buffer(cfg['trunk_wall_clearance_m'])
    paths=unary_union(tracks).buffer(3)
    plot_geometries=[p['polygon'] for p in plots];plot_tree=STRtree(plot_geometries)
    by_cluster={c['id']:[] for c in clusters}
    for record in plots:by_cluster[record['cluster']].append(record['polygon'])
    trees=[];spatial={}
    models=json.loads((ASSET/'vegetation/models.json').read_text())
    def add(point,species,context):
        if len(trees)>=cfg['maximum_trees']:return
        variant=int(rng.integers(3));model=models['species'][species][variant]
        scale=float(rng.uniform(.86,1.14));radius=model['canopy_radius']*scale
        point=np.asarray(point);p=Point(*point)
        if not allowed.covers(p.buffer(radius+.6)) or barriers.intersects(p) or paths.intersects(p.buffer(2)):return
        gradient=g.gradient(point)
        if not np.isfinite(gradient).all() or np.linalg.norm(gradient)>(cfg['maximum_tree_slope'] if species=='aleppo_pine' else .23):return
        key=tuple(np.floor(point/16).astype(int))
        for x in range(key[0]-2,key[0]+3):
            for z in range(key[1]-2,key[1]+3):
                for previous in spatial.get((x,z),[]):
                    if np.linalg.norm(point-previous[0])<max(cfg['minimum_tree_spacing_m'],radius+previous[1]):return
        # Pines and scattered specimens remain off cultivated field interiors.
        if context in ['pine_group','scattered']:
            if any(plot_geometries[i].intersects(p.buffer(2)) for i in plot_tree.query(p.buffer(2))):return
        height=float(g.heights([point])[0])
        if not np.isfinite(height) or height<7:return
        trees.append(dict(species=species,variant=variant,position=[float(point[0]),height,float(point[1])],yaw=float(rng.uniform(0,2*np.pi)),scale=scale,context=context,canopy_radius=radius))
        spatial.setdefault(key,[]).append((point,radius))
    for cluster in clusters:
        polys=by_cluster[cluster['id']]
        if not polys:continue
        if rng.random()<cfg['grove_probability']:
            poly=max(polys,key=lambda p:p.area)
            if poly.area>4000:
                x0,z0,x1,z1=poly.bounds;spacing=rng.uniform(17,23)
                for x in np.arange(x0+8,x1-6,spacing):
                    for z in np.arange(z0+8,z1-6,spacing):
                        p=np.array([x,z])+rng.uniform(-3,3,2)
                        if poly.buffer(-5).contains(Point(*p)):add(p,'olive','olive_grove')
        if rng.random()<cfg['edge_group_probability']:
            for _ in range(int(rng.integers(5,11))):
                poly=polys[int(rng.integers(len(polys)))];edge=poly.exterior
                t=rng.uniform(0,edge.length);a=np.array(edge.interpolate(t).coords[0]);b=np.array(edge.interpolate(min(t+1,edge.length)).coords[0])
                direction=b-a
                if np.linalg.norm(direction)<.01:continue
                normal=np.array([-direction[1],direction[0]])/np.linalg.norm(direction)
                add(a+normal*rng.uniform(3,7),rng.choice(['carob','olive'],p=[.7,.3]),'field_edge')
        if rng.random()<cfg['pine_group_probability']:
            centre=np.array(cluster['centre'])[::2]+rng.uniform(-290,290,2)
            for _ in range(26):add(centre+rng.normal(0,32,2),'aleppo_pine','pine_group')
        # Sparse isolated carobs and pines in the uncultivated gaps.
        for _ in range(4):
            point=np.array(cluster['centre'])[::2]+rng.uniform(-330,330,2)
            add(point,rng.choice(['carob','olive','aleppo_pine'],p=[.5,.2,.3]),'scattered')
    shrubs=[]
    for point in json.loads((ASSET/'landscape/decoration.json').read_text())['scrub_centres']:
        p=Point(*point)
        if not allowed.covers(p.buffer(16)) or barriers.intersects(p.buffer(15)) or paths.intersects(p.buffer(15)):continue
        if any(plot_geometries[i].intersects(p.buffer(15)) for i in plot_tree.query(p.buffer(15))):continue
        shrubs.append(point)
    return dict(version=1,seed=cfg['seed'],settings=cfg,models='res://assets/malta/vegetation/models.json',inferred=True,note='Artistic WWII-inspired planting, not a historical tree survey; upright trunks, terrain-sampled roots.',trees=trees,shrub_centres=shrubs,species_counts={s:sum(t['species']==s for t in trees) for s in models['species']})
