# Malta elevation survey and ground refit

The playable island uses the Malta Planning Authority’s 2012 bare-earth LiDAR terrain model, sampled from the bundled 32 m overview. The supplied heatmaps are north-up Web Mercator views using Leaflet, OpenStreetMap tiles and a TessaDEM overlay. The visible scale bars give roughly 16 m per display pixel at the captured zoom. Their visible legend spans about −1 to 252 m. The northern view reaches Ċirkewwa and Mellieħa, and the southern view extends past Luqa to Ħal Far and Marsaxlokk. In the screenshots, Mosta, Mdina, Valletta and Nadur agree to within a few display pixels after allowing for the roughly 260 px east and 382 px south shift in the first image. These visual controls check the relative layout of the two crops. They are approximate label centres and do not establish survey coordinates. [Reference map](https://en-gb.topographic-map.com/map-2rs8/Malta/) · [Survey source and attribution](../assets/malta/source/README.md)

The western plateau and cliffs, Mellieħa ridges, low Grand Harbour and the lower southeast align with the screenshots in a north-up comparison. The shaded basemap, road labels, coast-water colours and UI are excluded from height calibration. The game samples the DTM directly to avoid seam and colour-banding artefacts. The comparison uses the TessaDEM heights as an independent coarse check. [North-up and oblique review](development-updates/validation/malta-elevation-review.png)

## Calibration and measured samples

The existing world already used metres, up-positive elevation and a sea surface at Y=0. The rebuild keeps the original EPSG:32633 origin at 14.4° E, 35.93° N, the physical coastline and the artificial −30 m underside. The source raster is reprojected only for sampling. Its height datum is used directly and has not been independently tied to local benchmarks.

The mainland mesh adds 8,387 candidate detail points on a 40 m grid where the calibrated height differs from the previous ungraded mesh by at least 2 m. The detail grid is offset from the legacy edges, with a 0.25 m exclusion around source constraints to keep float32 terrain seams continuous. Height refinements taper within 100 m of the coastline and at survey gaps. This preserves the existing coast edge and its nearshore cliff profiles where the DTM is weak. Gozo, Comino and smaller islands retain their source meshes. The highest corrected mesh vertex is 251.88 m, up from 250.87 m. The GLB supplies both rendered terrain, including importer-generated LODs, and static collision. [Editable settings](../assets/malta/grading/elevation.json) · [Grading report](../assets/malta/grading/report.json)

| Location | Latitude, longitude | Previous playable Y | Corrected Y |
| --- | --- | ---: | ---: |
| Mellieħa slope | 35.95311, 14.36135 | 97.19 m | 85.73 m |
| Naxxar ridge shoulder | 35.92891, 14.44585 | 75.07 m | 89.62 m |
| Nadur ridge, sampled high point | 35.90218, 14.37184 | 236.47 m | 236.47 m |
| Mdina centre | 35.88690, 14.40340 | 196.11 m | 196.11 m |
| Dingli escarpment sample | 35.84839, 14.39674 | 232.53 m | 242.45 m |
| Ta’ Dmejrek vicinity, sampled high point | 35.84722, 14.39747 | 249.06 m | 250.54 m |
| Southern valley shoulder | 35.83677, 14.41698 | 85.45 m | 105.92 m |
| Fort St Elmo terrain | 35.90220, 14.51800 | 22.76 m | 22.76 m |

The map labels Nadur at about 238 m and Ta’ Dmejrek at 253 m. The latter is a point height, while the table reports the nearest high sample in a 65 m comparison grid. Local hills and small valleys are still limited by the survey overview, old terrain near survey gaps and the in-game triangulation.

## Objects and runways

- Regraded Ta’ Qali from 109.33 to 109.30 m, Luqa from 76.69 to 76.72 m, and Ħal Far from 62.66 to 62.66 m at the runway centres. The fitted runway elevations are in the same broad colour bands as the reference views. Lengths, widths, headings and site coordinates carry over. Runway surfaces, taxiways, hangars, parking slots, truck starts and landing checks share the rebaked terrain and field transforms.
- Refit the existing public road alignment, road grading and base links. The main road surface is the terrain itself. Bridge decks and uncertain crossings retain the original road coverage.
- Rebuilt the Valletta, Mdina and Cottonera meshes and collision against the new ground, retaining their site anchors and building counts. The St Elmo deck and guns were rebuilt from the same fort layout and land relationship. Mosta and the wartime villages place their buildings and foundations against the runtime terrain when loaded.
- Refit 4,800 recorded tree roots without moving their horizontal positions. The countryside refit reuses the field plans, track paths and wall alignments. It omits existing parcels and short wall sections that fail the original slope and foundation checks on the corrected ground.
- Existing terrain collision queries handle aircraft gear, recovery, AI clearance, bullets, bombs, wrecks and ground placements. Airfield-based starts inherit the revised transforms. The multiplayer offshore spawn and 480 m rendezvous remain fixed sea-level altitudes.

## Rebuild

Install the offline dependencies in `tools/requirements-rural.txt`. The shipped source data is read-only during regeneration. Refit the countryside from its committed placement manifest and tree list. To recover placements omitted by the slope checks, use the version of those input files from before the elevation refit.

```sh
python tools/grade_malta_terrain.py --roads
python tools/build_base_access.py
python tools/generate_valletta.py --refit
python tools/generate_mdina.py
python tools/prepare_cottonera.py
python tools/build_cottonera.py
python tools/generate_malta_countryside.py --refit
godot --headless --editor --import --quit
```

The result is a modern surveyed elevation baseline for the wartime scenery. Individual coast walls, bridges, cadastral grades and historical ground levels remain approximate.
