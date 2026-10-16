"""Original synthetic impact thump, metal crack and decaying rumble (no samples).
Requires ffmpeg only when regenerating the checked-in Ogg asset.
"""
import math
import random
import struct
import subprocess
import tempfile
import wave
from pathlib import Path

rng = random.Random(1942)
rate = 24000
frames = bytearray()
low = 0.0
for i in range(int(rate * 1.8)):
    t = i / rate
    noise = rng.uniform(-1, 1)
    low += (noise - low) * 0.08
    attack = min(t / 0.004, 1)
    boom = math.sin(2 * math.pi * (64 * t - 12 * t * t)) * math.exp(-t * 4)
    crack = noise * math.exp(-t * 30)
    rumble = low * 3 * math.exp(-t * 2.5)
    sample = math.tanh((boom * 0.5 + crack * 0.6 + rumble) * attack) * 0.8
    frames.extend(struct.pack('<h', round(sample * 32767)))
with tempfile.TemporaryDirectory() as tmp:
    source = Path(tmp) / 'impact.wav'
    with wave.open(str(source), 'wb') as audio:
        audio.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        audio.writeframes(frames)
    output = Path(__file__).resolve().parents[1] / 'assets/audio/aircraft_crash.ogg'
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', str(source), '-c:a', 'libvorbis', '-q:a', '5', str(output)], check=True)
