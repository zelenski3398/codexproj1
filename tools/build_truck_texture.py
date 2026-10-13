"""Original stone camouflage inspired by the supplied vehicle photo; no photo pixels."""
from PIL import Image
from pathlib import Path
import random
rng=random.Random(1942)
size=256
sites=[(x*32+rng.uniform(-12,12),y*32+rng.uniform(-12,12)) for x in range(-1,10) for y in range(-1,10)]
colors=[(rng.randint(193,214),rng.randint(177,199),rng.randint(123,150)) for _ in sites]
image=Image.new('RGB',(size,size))
for y in range(size):
 for x in range(size):
  values=sorted(((x-px)**2+(y-py)**2,i) for i,(px,py) in enumerate(sites))[:2]
  color=(71,68,47) if values[1][0]-values[0][0]<42 else colors[values[0][1]]
  image.putpixel((x,y),color)
image.save(Path(__file__).resolve().parent.parent/'assets/vehicles/stone_camouflage.png')
