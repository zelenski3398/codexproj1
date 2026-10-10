# Malta measured-elevation terrain for Godot / Blender

This model combines the user's 2026 OpenStreetMap coastline extract with the
Planning Authority Digital Terrain Model 2012. The public catalogue describes
terrain-only 1 m LiDAR data from 17 February 2012. This starter uses its published
32x overview (~32 m pixel spacing), downloaded as GeoTIFF via WCS.

Files:
- Malta-Elevated-Terrain.glb: land only, 36 closed meshes, 152,000 triangles.
- Malta-Elevated-With-Sea.glb: same terrain plus a separate sea display base.
- Malta-DTM-2012-32m.tif: downloaded elevation overview (not full 1 m dataset).
- Malta-Coastline.geojson: original user coastline extract.
- Terrain-Metadata.json: origin, projection, heights, gap and mesh statistics.
- build_terrain.py: reproducible generator.
- Elevation-Preview.png: relief preview generated from the elevation raster.

Import at scale (1,1,1). One unit = one metre; X east, Y up, negative Z north.
Origin longitude 14.4 / latitude 35.93, EPSG:32633 local coordinates, exactly the
same origin and orientation as Malta-Land-Blockout.glb. Replace that flat model
with this one rather than overlaying both. Elevation data is transformed from
EPSG:25833 into the original model's coordinate system.

Interior mesh spacing is 80 m, with all input coastline vertices retained.
Heights are bilinear samples of the ~32 m DTM; vertical scale is 1:1.
Highest sampled mesh vertex is about 250.87 m. The bottom cap is at Y=-30 m,
which is artificial model thickness. Sea top is at Y=0 in the sea version.
Some supplied heights are below zero and have been retained rather than clamped.
The service's vertical datum has not been independently verified against local
survey benchmarks; its source elevation values are used directly.

Limitations:
The elevation overview contains missing pixels, including inland survey gaps.
These are filled with the nearest valid DTM pixel before bilinear sampling.
5,486 terrain sample locations are over 100 m from a valid source pixel; maximum
nearest valid sample distance is about 333 m. These heights are approximations,
not fresh measurements. Per-island statistics are provided in Terrain-Metadata.
This is a terrain foundation for flight gameplay, not surveyed cliff or harbour
geometry. Coarse heights and an 80 m interior mesh soften cliffs and small valleys.
Modern coastlines and 2012 terrain do not reconstruct a verified 1940-42 landscape.
Elevation colouring is decorative; no satellite or historical textures, buildings,
roads, or fortifications are included. Coastlines are not altered to fit the DTM.
No physics collision, camera, viewer project or gameplay is included. Add static
concave mesh collision for terrain in your game; use suitable camera far range
(e.g. 100000 m). No live Godot editor test was performed.

Validation: polygon closure, top triangulation area, closed watertight positive-
volume meshes, consistent winding; exported GLB reloaded to check geometry count,
finite coordinates and bounds. Meshes preserve all original coastline points.

Data attribution:
Elevation: Planning Authority, Digital Terrain Model 2012, accessed 10 October 2026.
Catalogue: https://portal.data.gov.mt/dataset/digital-terrain-model-2012
Resource licence: Creative Commons Attribution 4.0.
https://portal.data.gov.mt/dataset/digital-terrain-model-2012/resource/ff26314d-4e0e-48d3-952c-2b70e8432a71
https://creativecommons.org/licenses/by/4.0/
Service: https://malta.coverage.wetransform.eu/dtm_1m_2012/ows
Changes: coarse overview, gap filling, projection, triangulation, extrusion and colours.

Coastline: © 2026 OpenStreetMap contributors, Open Database License (ODbL).
https://osmdata.openstreetmap.de/data/coastlines.html
https://www.openstreetmap.org/copyright
https://opendatacommons.org/licenses/odbl/1-0/
Retain attribution when using or sharing the data-derived model. Source datasets
and transformation script accompany the mesh.
