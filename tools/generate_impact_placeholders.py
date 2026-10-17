"""Original synthesized TEMPORARY water and metal-hit effects, not recordings.
Replace through audio_profiles/aircraft_impacts.tres. Requires ffmpeg to rebuild.
"""
import math
import random
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/impacts'
ROOT.mkdir(exist_ok=True)
RATE = 24000

def render(name, length, seed, water=False, heavy=False):
    rng = random.Random(seed)
    frames = bytearray()
    low = 0.0
    phase = rng.random()
    for i in range(int(RATE * length)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        low += (noise - low) * (0.06 if water else 0.18)
        attack = min(t / 0.003, 1)
        if water:
            # Impact crack, low plunging body, then modulated turbulent noise.
            crack = noise * math.exp(-t * 36) * 0.6
            plunge = math.sin(2 * math.pi * (90*t-10*t*t)) * math.exp(-t*5) * 0.45
            tail = low * (1-math.exp(-t*18)) * math.exp(-t*1.65) * (1+0.2*math.sin(t*19)) * 4
            signal = crack + plunge + tail
        else:
            frequencies = [320, 743, 1421, 2370] if heavy else [530+seed*17, 1270+seed*13, 2860, 4150]
            ring = sum(math.sin(2*math.pi*f*t+phase) * math.exp(-t*(9+j*7)) / (j+2) for j,f in enumerate(frequencies))
            signal = noise * math.exp(-t*95)*0.7 + ring*0.48 + low*math.exp(-t*22)*0.8
        sample = math.tanh(signal*attack)*0.8
        frames.extend(struct.pack('<h', round(sample*32767)))
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp)/'sample.wav'
        with wave.open(str(wav), 'wb') as output:
            output.setparams((1,2,RATE,0,'NONE','uncompressed'))
            output.writeframes(frames)
        subprocess.run(['ffmpeg','-loglevel','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(ROOT/name)],check=True)

for index in range(3):
    render(f'metal_hit_{index+1}_placeholder.ogg',0.48,index+1)
render('heavy_hit_placeholder.ogg',0.65,7,heavy=True)
render('sea_plunge_placeholder.ogg',3.2,1942,water=True)
