"""Original deterministic, mono damage SFX placeholders; no recorded samples.
FFmpeg is used only to encode the checked-in Ogg files. These are not authentic
WWII aircraft recordings. Tune/replace the event_sounds AudioStream slots.
"""
from pathlib import Path
import math, random, struct, subprocess, tempfile, wave
RATE = 24000
EVENTS = {
    'metal_tear': (0.7, 390, .9), 'fabric_tear': (0.48, 90, .6),
    'engine_misfire': (.22, 65, .7), 'engine_seizure': (.9, 250, .75),
    'fuel_ignition': (.65, 80, .8), 'structural_breakup': (1.2, 130, .85),
    'propeller_impact': (.55, 210, .8), 'hard_landing': (.7, 55, .8),
    'ground_crash': (1.5, 45, .85), 'secondary_impact': (.35, 70, .5),
}
def main():
    destination = Path(__file__).resolve().parents[1] / 'assets/audio/failures'
    destination.mkdir(parents=True, exist_ok=True)
    for index, (name, (duration, frequency, gain)) in enumerate(EVENTS.items()):
        rng = random.Random(1944 + index)
        samples = bytearray()
        low = 0.
        for i in range(int(duration*RATE)):
            t = i/RATE
            noise = rng.uniform(-1,1)
            low += (noise-low)*.12
            attack = min(1,t/.006)
            if name == 'fabric_tear':
                value = noise*.45*(.6+.4*math.sin(2*math.pi*32*t))
            elif name == 'engine_seizure':
                value = .4*math.sin(2*math.pi*(frequency*t-100*t*t))+.35*noise
            elif name == 'metal_tear':
                value = .25*math.sin(2*math.pi*frequency*t)+.25*math.sin(2*math.pi*frequency*1.713*t)+.45*noise
            else:
                value = .5*math.sin(2*math.pi*(frequency*t-12*t*t))+.8*low+.3*noise*math.exp(-t*12)
            value = math.tanh(value)*attack*math.exp(-t*4/duration)*gain
            samples += struct.pack('<h', round(max(-1,min(1,value))*32767))
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)/'sound.wav'
            with wave.open(str(path),'wb') as wav:
                wav.setparams((1,2,RATE,0,'NONE','not compressed'))
                wav.writeframes(samples)
            subprocess.run(['ffmpeg','-loglevel','error','-y','-i',str(path),'-c:a','libvorbis','-q:a','4',str(destination/(name+'_placeholder.ogg'))],check=True)
if __name__ == '__main__': main()
