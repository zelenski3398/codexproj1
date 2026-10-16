"""UNPLACED asset review gallery. Coordinates below are display cells, not Malta.
This intentionally does not create or modify Cottonera city geography.
"""
import json
from pathlib import Path
import numpy as np,trimesh
from shapely.geometry import Polygon,box
from cottonera.models import Models
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/malta/cottonera/templates';OUT.mkdir(exist_ok=True)
specs=[('FortStAngeloTemplate',[0,0],'fort'),('GardjolaTemplate',[170,0],'lookout'),('HouseTemplate',[205,0],'house'),('CottoneraLineTemplate',[0,205],'outer'),('SantaMargheritaLineTemplate',[0,245],'inner'),('GateTemplate',[210,120],'gate'),('NavalDockTemplate',[-80,-170],'dock'),('WarehouseTemplate',[0,-170],'warehouse'),('CraneTemplate',[50,-130],'crane'),('StLawrenceTemplate',[180,-120],'church'),('VictoriesTemplate',[250,-120],'basilica'),('ImmaculateConceptionTemplate',[320,-120],'church'),('PalaceTemplate',[300,10],'palace')]
scene=trimesh.Scene();records=[]
for name,offset,role in specs:
 m=Models()
 if role=='fort':m.fort_st_angelo(Polygon([(0,0),(95,0),(115,35),(100,140),(30,160),(-15,90)]),0,4)
 elif role=='lookout':m.gardjola(box(0,0,6,6),0)
 elif role=='house':m.house(box(0,0,18,26).difference(box(5,8,12,18)),0,11)
 elif role in ['outer','inner']:m.battered_wall([0,0],[95,0],0,14 if role=='outer' else 10);m.bastion(Polygon([(95,-12),(120,-12),(145,12),(120,30),(95,18)]),0,7)
 elif role=='gate':m.gate([0,0],0)
 elif role=='dock':m.dry_dock(box(0,0,28,135))
 elif role=='warehouse':m.warehouse(box(0,0,35,55),0,10)
 elif role=='crane':m.crane([0,0],0)
 elif role in ['church','basilica']:m.church(box(0,0,30,50),0,18,role=='church')
 else:m.palace(box(0,0,35,45).difference(box(10,12,24,32)),0,13)
 for level,meshes in [('Mid',m.mid),('Near',m.near)]:
  if not meshes:continue
  merged=trimesh.util.concatenate(meshes);merged.apply_translation([offset[0],0,offset[1]])
  scene.add_geometry(merged,node_name=name+'_'+level,geom_name=name+'_'+level)
 if role=='gate':
  gate=trimesh.Scene(trimesh.util.concatenate(m.collision));(OUT/'gate_collision.glb').write_bytes(gate.export(file_type='glb'))
 records.append(dict(name=name,display_xz=offset,not_a_geographic_location=True))
(OUT/'architecture.glb').write_bytes(scene.export(file_type='glb'))
(OUT/'gallery.json').write_text(json.dumps(dict(status='unplaced_templates_only',notice='Schematic asset review, not a mapped or surveyed Cottonera reconstruction',templates=records),indent=2)+'\n')
print('Generated',len(records),'UNPLACED original templates')
