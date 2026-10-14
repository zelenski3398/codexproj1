"""Create a distinct low artillery placeholder from the original procedural AA report.
Not an authentic QF recording. Run tools/build_aa_sound.py first if its source is absent.
"""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parent.parent
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(root/'assets/audio/aa_cannon_shot.ogg'),'-af','asetrate=30000,aresample=44100,aecho=0.8:0.7:100|180:0.18|0.1,volume=0.8',str(root/'assets/audio/aa_heavy_shot.ogg')],check=True)
