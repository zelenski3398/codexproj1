"""Original cannon-like single-shot effect; illustrative sound, not a historical recording."""
from pathlib import Path
import numpy as np
import wave,subprocess,tempfile
rate=44100
t=np.arange(round(.43*rate))/rate
rng=np.random.default_rng(1940)
noise=rng.normal(0,1,len(t))
low=np.convolve(noise,np.ones(25)/25,mode='same')
phase=np.cumsum(55+90*np.exp(-t/0.025))*2*np.pi/rate
attack=1-np.exp(-t/.0007)
body=.65*np.sin(phase)*np.exp(-t/.105)
crack=.26*noise*np.exp(-t/.014)
rumble=.8*low*np.exp(-t/.12)
signal=attack*(body+crack+rumble)
for delay,gain in [(.058,.14),(.11,.07)]:
 offset=int(delay*rate)
 signal[offset:]+=signal[:-offset]*gain
signal*=np.minimum(1,(.43-t)/.035).clip(0,1)
signal=signal/max(abs(signal))*.85
output=Path(__file__).resolve().parent.parent/'assets/audio/aa_cannon_shot.ogg'
with tempfile.TemporaryDirectory() as folder:
 pcm=Path(folder)/'shot.wav'
 with wave.open(str(pcm),'wb') as wav:
  wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate)
  wav.writeframes((signal*32767).astype('<i2').tobytes())
 subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(pcm),'-c:a','libvorbis','-q:a','5',str(output)],check=True)
print('Generated non-looping 0.43-second cannon shot:',output)
