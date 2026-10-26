"""Full deterministic scenery rebuild into /tmp; never edits shipped assets."""
import sys,json,tempfile,hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from generate_malta_countryside import build,OUT,numpy_scalar
before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('farm_*.glb')}
with tempfile.TemporaryDirectory(prefix='malta-rural-',dir='/tmp') as directory:
 result=build(directory)
 after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in Path(directory).glob('farm_*.glb')}
 assert before==after,'Every rural mesh/collision file must regenerate identically'
 assert json.loads((OUT/'manifest.json').read_text())==json.loads(json.dumps(result,default=numpy_scalar)),'Plot geometry, tracks, wall sections and configuration must regenerate identically'
 assert json.loads((OUT/'trees.json').read_text())==json.loads((Path(directory)/'trees.json').read_text()),'Tree and scrub placement must regenerate identically'
 print('PASS: Full countryside regeneration matches',len(before),'GLBs and all manifest data',flush=True)
