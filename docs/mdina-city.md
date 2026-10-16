# Historic Mdina in the continuous Malta world

Mdina is an original photo-inspired exterior reconstruction, integrated alongside Valletta in every Malta environment and mode. It uses the supplied aerial photograph to guide compact limestone architecture, the irregular bastioned perimeter, southern defensive terrace and cathedral skyline. No photograph, watermark, stock-site geometry, modern cars or photographed lighting is baked into the asset. It is a historically inspired approximation, not a surveyed 1940 reconstruction.

## Geographic placement and ground

The existing map uses **EPSG:32633**, relative to **14.4° E / 35.93° N**, with one Godot unit per metre. For a geographic point transformed to UTM easting/northing `(E,N)` and the existing origin `(E0,N0)`:

```text
Godot X = E - E0
Godot Z = N0 - N
Godot Y = height sampled from the existing imported terrain
```

The supplied Mdina reference **35.8869° N, 14.4034° E** therefore maps to **X 277.514968 m, Z 4782.307970 m**. Its existing terrain height is **196.110954 m** above the map's sea level. The asset root uses `(277.514968, 0, 4782.307970)`; individual vertices retain their actual world elevations. No vertical exaggeration or city-wide flat platform is introduced. The city remains above the lower eastern countryside.

The generator samples the current terrain mesh triangles. Separately imported `RoadGround` meshes have local vertex coordinates and GLB node translations: those transforms are included when sampling ground beneath roads. Foundations embed below sampled corner elevations; walls step with the hill. No terrain, coastline, road path, grading mask, original airfield coordinate or mission target resource is rewritten. Source SHA-256 hashes are stored in `layout.json` and verified by the city tests.

The repository contains a coarse historical-road trace near Mdina, but no precise Mdina building/perimeter survey. The footprint and lanes in `settings.json` are authored geographic approximations informed by the supplied photograph. Their geographic coordinates use the same projection as the actual map. The existing `mdina_ta_qali` and `mdina_rabat_south` routes remain untouched. Their coarse alignment is accommodated with internal street clearance and openings through the perimeter; those accommodation passages are not claimed as surveyed historic gates.

## Architecture

- Irregular fortified enclosure, approximately 360 × 485 m, with 104 short terrain-aligned curtain-wall sections and angular projecting bastions.
- Thick limestone walls with sloping masonry faces, plain parapets, solid wall-top walkways and junctions. No generic fantasy battlements or crenellations.
- Southern projecting bastion and northern/eastern defensive terraces, retaining the natural surrounding hill.
- An original prominent main gate with pilasters, cornice, a small geometric plaque and a **real arched opening**, including collision clearance for the soldier and military truck.
- 242 low-rise buildings fitted to irregular street blocks, open courtyards, roof parapets, windows, entrances and occasional restrained timber balconies.
- Narrow, bent lanes and a cathedral forecourt; the old road carriageways remain physically unobstructed.
- An original St Paul's Cathedral approximation: Baroque nave/facade massing, twin bell towers with clock faces and framed openings, low stepped caps, pediment, raised drum, ribbed dome and lantern/cross. It dominates the skyline without adding unrelated castle towers.

The dry ditch is **suggested by the ground corridor between the raised escarp and counterscarp**. Its floor remains the existing terrain. It is not a newly excavated trench or a surveyed ditch profile; this compromise protects the supplied terrain and roads. There are no interiors, population, destructible city buildings or new mission mechanics.

## Integration and performance

`MdinaCity` and `VallettaCity` share `HistoricCity`, a small extraction of the existing Valletta rendering/collision code. Existing Valletta material, transforms, culling and geometry remain unchanged. `MaltaWorld` creates each city once. A full restart frees old visual and collision nodes; travel between cities and airfields never reloads the environment.

Mdina has **107,152 source triangles in 35 render chunks**. Imported mesh LODs and chunk frustum culling remain enabled; structures cull at 14 km, small facade/roof details at 1.4 km. Eighteen coarse static collision chunks retain roofs, walls, the cathedral and gate; small decorative panes and trim have no collision. The existing swept projectile collision system naturally hits these structures. No new firing, damage or AI implementation is introduced.

The explicit rough `StandardMaterial3D` uses bundled limestone vertex colours in both native Compatibility and browser exports. No custom city shader, external texture, runtime geographic library or network access is required. Rural vegetation skips city roofs. F4 hides both cities for terrain debugging while retaining physical collision. The normal game and navigation chart include one derived Mdina marker; the source world-data coordinates remain unchanged.

## Run and review

Choose Malta and depart from **RAF Ta' Qali**. Mdina is approximately **1.42 km southwest** of the field centre, marked on the navigation map (**M**). Fly over the hill at a safe altitude to see the wall circuit and cathedral. Existing roads connect toward Mdina; normal walking/driving/aircraft controls are preserved.

Native Compatibility captures from the actual world:

- [Aerial overview](previews/mdina-aerial.png)
- [Southern bastion and walls](previews/mdina-bastions.png)
- [Cathedral and dense street blocks](previews/mdina-cathedral.png)
- [Main gate passage](previews/mdina-gate.png)

Rebuild only the Mdina assets using the existing geographic development environment:

```sh
/tmp/malta-geo-venv/bin/python tools/generate_mdina.py
godot --headless --path . --editor --import --quit
```

The generator reads `assets/malta/mdina/settings.json` and writes only its `city.glb`, coarse `collision.glb` and `layout.json`. Its dependencies are NumPy, trimesh, Shapely, pyproj, matplotlib and triangle; these are development tools, not game dependencies. The generator rejects non-finite vertices/metadata rather than substituting guessed ground heights.

Checks and native previews:

```sh
godot --headless --path . --fixed-fps 120 --script res://tests/mdina_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/valletta_checks.gd
godot --path . --script res://tests/mdina_capture.gd
bash tools/build_web.sh
node tools/malta_terrain_web_smoke.cjs
```

The city checks exercise geographic placement, measured elevation, protected-source hashes, roof/wall collision, truck-sized clearance at 58 existing-road stations, actual soldier walking and military-truck driving through the gate, debug switching, navigation and clean restart. Native previews were rendered and inspected. Browser checks verify exported assets, projection/elevation, collision ownership, debug mode and retry alongside existing controls; they do not constitute a manual browser flyover of every street.

Completed validation: **24/24 Mdina**, **17/17 Valletta**, **30/30 terrain**, **35/35 Malta flight/landing/persistence**, **11/11 road integration**, **36/36 weapons**, **77/77 interception** and **47/47 AA defence**: **277 native checks passed**. The web export and **25/25 Chromium/ANGLE checks** passed without script, shader, resource or HTTP errors.

Remaining limits: approximate historic footprints/facades and ditch, coarse source terrain, no interiors or individual building damage. Fine facade detail and close-range shadow quality remain at prototype level. Every lane, wall-top route, vehicle turning space and low-altitude approach has not been manually explored. The supplied photograph shows present-day surroundings; modern parking/car details were deliberately omitted.
