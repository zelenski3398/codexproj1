# Malta landscape: Commit 2

Normal mode now shows limestone, reddish/brown dry soil, muted cultivated
fields, sparse scrub and rocky slopes using one explicit shared material on
all 36 island meshes. **F4** still deliberately switches to the original
elevation heatmap. Debug is labelled, off by default and reset on a fresh
mission; optional decorative vegetation/town instances hide in debug mode.
Commit 1's material assignment and neutral troubleshooting resource are retained.

## Materials and geography

`landscape.tres` / `landscape.gdshader` combine a baked world-coordinate parcel
mask with seamless packed microdetail and side-projected rock strata. Slope
controls exposed cliffs, parcel classes control agriculture/scrub, and low
shore elevation adds damp neutral rock. Colour is not an elevation heatmap.
The source GLB has no normal vectors: the shader derives existing triangle
normals with fragment derivatives for both slope and lighting. These are core
WebGL 2/Compatibility operations; no normal buffers or vertices are generated.

Parcels use seeded random Voronoi regions, anisotropic spacing, coordinate
warping and per-parcel variation, avoiding a repeating square grid. Rubble
boundaries and subtle contour-following terrace accents are colour detail;
they are not new physical terraces, walls or surveyed farm boundaries.
The cropped land masks come from the supplied mesh, with colour-only cleared
areas around the existing three runways and the Valletta marker.

The four bundled PNGs contain original procedural detail, not downloaded
photographs: two island-scale masks (2048² and 1024²), and two periodic 512²
textures. Mipmaps and world-space tiling keep the detail stable in flight.
Data-channel textures use lossless import with alpha repair/automatic 3D
compression disabled, so desktop and web interpret the same channel values.
See [asset layout and regeneration](../assets/malta/landscape/README.md).

`sea.tres` / `sea.gdshader` use one coast-distance sample and two low-amplitude
sine ripples for opaque Mediterranean blue water and a subdued shallow-water
tint. There are no reflections, screen/depth textures, foam, transparency,
wave displacement or physics changes. Sea level is still **0 m**, with the
same 240 km box and infinite collision plane. Shore tint is approximate at
mask resolution; the original coastline itself is not moved or replaced.

`airfield.tres` / `airfield.gdshader` give the existing graded strips and aprons
a rough packed-earth/limestone appearance. The exact deck dimensions,
headings, parking positions, collision and existing prototype markings stay
unchanged. This is not a claim that all three wartime airfields shared an
identical surveyed surface/layout, and no modern airport has been added.

## Vegetation and landmark coverage

`malta_landscape_details.gd` terrain-aligns a capped 96 scrub clusters (up to
four low-poly bushes each) using static collision rays once at startup. It
groups them into regional MultiMeshes, disables their shadows and culls them
at distance. Valletta gets up to 32 flat-roof stone blocks as one low-rise
silhouette, anchored to the **existing Valletta marker**, aligned by rays and
rejecting water/steep slopes. All new objects are decorative: no collision,
damage, AI obstacles, spawning or mission-state ownership.

| Reference | This commit |
| --- | --- |
| Valletta peninsula | Original geographic silhouette; provisional low-rise town mass at the existing marker |
| Grand Harbour | Original harbour/inlet geometry and marker; updated surrounding water/coastal colours |
| Fort St Elmo / Fort St Angelo | Documented placement/asset gaps; no invented fort coordinates or structures |
| Mdina | Pending verified placement and a period silhouette; not placed arbitrarily |
| Dingli Cliffs | Actual steep terrain receives limestone rock shading; named landmark placement remains pending |
| RAF Luqa / Ta' Qali / Ħal Far | Original operational positions and buildings retained; updated ground materials/blending |

Requests to historical/location pages for the forts, Mdina and Dingli were
blocked by the cloud proxy. The supplied metadata contains none of those
four sites. Their verified coordinates and 1940–1942 reference assets are
still needed. The Valletta blocks are an explicitly provisional silhouette,
not real building footprints, a cathedral, a fortress or a verified city
reconstruction. Its surrounding harbour is already defined by the supplied
coastline. No modern high-rises or new airport layouts were introduced.

## Tuning and performance

Material parameters are editable on the `.tres` shader resources in Godot:

| Parameter | Default | Purpose |
| --- | --- | --- |
| `limestone_color`, `soil_color`, `cultivated_color`, `scrub_color`, `wall_color` | Muted palettes in the shader | Maintain restrained daylight colour; avoid overbright rock |
| `detail_metres` | 14 m | Repetition size for rock/earth/furrow microdetail |
| `detail_fade_start` / `detail_fade_end` | 400 / 1800 m | Reduce fine detail/terrace contrast in the distance |
| `cliff_slope_start` / `cliff_slope_end` | 0.12 / 0.5 | Slope measure `1 - abs(normal.y)` for rock exposure |
| `wall_strength` / `terrace_strength` | 0.55 / 0.08 | Visual boundary/contour accents only |
| Sea `ripple_strength` | 0.025 | Subtle colour ripples without geometry movement |
| Airfield `ground_color` | Muted packed-ground palette | Strip/apron appearance, independent of collision |

The existing automatic terrain LODs, 0.6 bias, island bounds/culling and static
terrain BVHs are unchanged. The terrain shader has four texture lookups and
no procedural noise loops, parallax, displacement or extra terrain passes.
The expensive parcel/noise generation is offline, never per frame. Fine
detail fades with distance; mipmaps filter far parcels/rock. Bushes cull at
1700 m; the town silhouette at 9 km. The tested mission contained **408
decorative instances in 53 batches**, including 32 town blocks (the hard
maximum is 416), not thousands of independent simulated objects.

Bundled PNGs total approximately **1.6 MiB** compressed; their decoded mipmapped
texture budget is approximately **28 MiB**. The tested web PCK is 8,561,908 bytes
and the full uncompressed export approximately 44.6 MiB. Headless/native and
SwiftShader validation do not establish a guaranteed frame rate on consumer
hardware; representative Windows/browsers still need performance profiling
before increasing formations or landscape object counts.

## Validation performed

Godot **4.6.3**, matching export templates, Compatibility rendering:

- **30/30 terrain checks:** explicit landscape on all meshes, loaded texture
  paths/resolutions/mipmaps, multiple parcel classes, original geometry/colour/
  index buffers/transforms/bounds and collision unchanged; original geography
  records; F4, pause, key repeat, fresh-world normal default; bounded collision-
  free decoration; original sea dimensions/level.
- **132/132 existing checks:** keyboard 24, weapons 36, Malta integration 35,
  audio 37. Airfield contact, boarding, engines and combat remain functional.
- **20/20 Luqa journey checks:** engine input, taxi, takeoff, Ta' Qali, Valletta,
  Grand Harbour, Ħal Far approach/landing, taxi/exit/walk, board the stationed
  Sea Gladiator and take off again, keeping the same world. The test autopilot
  submits ordinary pitch/bank/rudder/throttle commands; it never assigns a
  transform/velocity after initial mission spawning. Enemy combat is disabled
  in this journey to isolate navigation. The existing Ta' Qali route test was
  parameterized; taxi time allowance and journey distance check now account
  for Luqa's different departure distance, without changing aircraft code.
- **14/14 actual release browser checks:** real menu/key input, correct shared
  material/textures on all 36 meshes, heatmap/default/reset, pause, boarding,
  engine/throttle/firing and no shader/resource/JS/HTTP errors.
- Native OpenGL/Mesa llvmpipe renders were captured and visually reviewed:
  Luqa normal/debug, full-island normal/debug, an agricultural aerial view and
  Valletta/Grand Harbour. The latter use review-only camera poses in the same
  world, not a claim of manual flight. Driver VSync-switch warning only.
- Chromium ANGLE SwiftShader/WebGL 2 release rendered Luqa normal/debug and
  was visually reviewed. Across 4,428 visible horizon-terrain pixels, both
  renderers had median RGB `(172, 147, 102)`; mean absolute channel difference
  was 0.41/255. This does not promise identical pixels on every GPU.
- SHA-256 comparison against Commit 1 confirms the source GLB, import settings,
  geography/source datasets and aircraft/pilot/mission/combat/audio scripts
  are unchanged. Airfield changes are material assignment only; world changes
  assign sea/decorative appearance only.

Reproduce from the project root:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script res://tests/malta_terrain_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/malta_journey_checks.gd -- luqa
bash tools/build_web.sh
node tools/malta_terrain_web_smoke.cjs
godot --path . --audio-driver Dummy --resolution 960x600 \
  --script res://tests/malta_terrain_capture.gd -- /tmp/malta-landscape-review
```

Browser checks require Node/Playwright/Chromium; capture requires a graphical
display. Tests/tools/docs/raw GIS remain excluded from the playable Web export;
the decoration JSON is explicitly included with the runtime texture resources.

Unverified: a manual full flight, Windows Godot 4.7/ANGLE, other browsers/GPUs,
and the live Pages deployment of Commit 2. This commit was not deployed.
The coarse supplied terrain, raised prototype airfield decks, illustrative
land-use patterns, painted rubble/terraces and provisional town mass limit
historical fidelity. Real period land-use masks, landmark positions/models
and licensed photographed ground assets remain future work.
