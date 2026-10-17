import hashlib,json,sys,tempfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from build_cottonera import build
base=Path('assets/malta/cottonera');before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in base.glob('*.glb')}
with tempfile.TemporaryDirectory(prefix='cottonera-regen-',dir='/tmp') as directory:
 report=build(base/'features.geojson',directory)
 after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in Path(directory).glob('*.glb')}
 assert before==after,'Regeneration must preserve every shipped mesh/collision byte'
 current=json.loads((base/'region.json').read_text())
 assert current['landscape']==json.loads(json.dumps(report['landscape'])),'Regeneration selection, probes, plots and sections must remain identical'
 print('PASS: deterministic full regeneration:',len(before),'visual/collision GLBs and all landscape metadata match',flush=True)
