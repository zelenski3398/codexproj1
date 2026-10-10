# Malta terrain rendering

## Diagnosis

The runtime world instantiates `assets/malta/terrain.glb`, then builds static
trimesh collision for its 36 island meshes. Import scale is 1, automatic LODs
are enabled, and the runtime LOD bias remains 0.6. The supplied GLB has
`POSITION` and normalized unsigned-byte `COLOR_0` attributes, but **no authored
materials, images or textures**. There is no terrain shader or runtime texture
download. Changing colour cannot change the elevations stored in `POSITION`.

The supplied `assets/malta/source/build_terrain.py` documents the model's
construction: the Planning Authority's 2012 DTM, sampled from its 32 m raster
overview using bilinear interpolation and nearest-valid filling for nodata;
OSM coastline coordinates are retained. Coordinates use metres, X east, Y up,
Z south, EPSG:32633 relative to 14.4° E / 35.93° N. The generator writes a
matplotlib `terrain` elevation ramp into vertex colours. It is a debugging
visualization, not a landscape texture. The generator and source data were
not modified or rerun for this fix.

Previously `malta_world.gd` left the importer-generated surface materials in
place. In a clean Godot 4.6.3 import those are `StandardMaterial3D` resources
with white albedo, **vertex colours used as albedo**, and no albedo texture.
This directly explains the rainbow terrain. The native baseline on this
machine also rendered that heatmap; the reported white Windows appearance
was **not reproduced**. There is no missing terrain texture to restore.
Import/version/cache differences are possible explanations for the white
appearance, but are not established causes without that installation's
imported material and logs. The confirmed problem is that normal gameplay
had no explicit terrain material and exposed the embedded debug colours.

Both project renderer settings already select **Compatibility**. The native
test used OpenGL 4.5 / Mesa llvmpipe; the real browser release used WebGL 2 /
Chromium ANGLE SwiftShader. Neither uses a separate authored terrain shader.
The fix keeps that renderer and the existing sky, sun, ambient light and fog.

The Web preset exports all runtime resources, excludes raw GIS/source files
but includes the runtime GLB, and the build helper imports before exporting.
The new release export includes both material resources and their remaps;
the browser reports the intended loaded material on all 36 meshes. No missing
terrain resource was observed. PWA/service-worker caching is disabled in the
existing export; Pages builds from main with matching Godot/templates. Stable
PCK/WASM filenames can still be cached by browsers. The proxy blocked fetching
the live Pages site, so its current contents and HTTP cache headers were not
verified. There is no demonstrated caching cause for the discrepancy, and
no deployment or cache workaround is included in this commit.

## Rendering contract

- `assets/malta/materials/limestone.tres`: default matte, nonmetallic limestone
  beige. `vertex_color_use_as_albedo = false`; no texture or custom shader.
  The albedo `(0.45, 0.38, 0.27)` was checked under the existing daylight;
  increasing it substantially can wash out the terrain. Light and fog still
  affect it normally, with no promise of identical pixels across GPUs.
- `assets/malta/materials/elevation_heatmap.tres`: original embedded elevation
  colours, explicitly enabled only for debug. `vertex_color_is_srgb = false`
  retains the previous imported colour interpretation. It uses the same
  standard shading path as normal mode.
- `scripts/malta_terrain_appearance.gd`: applies one shared material override
  to every island mesh, without editing imported resources. **F4** toggles
  modes, ignores key repeat and works while paused. Debug displays a clear
  elevation-heatmap notice; normal hides it. Each new world starts beige.
- `scripts/web_support.gd`: adds read-only active-material diagnostics to
  existing opt-in `?smoke=1` test telemetry. That query does not enable debug.

The GLB, import configuration, source data, world scale, geography, airfields,
terrain collision and LOD setup are unchanged. Aircraft, pilots, boarding,
engine, weapons, damage, AI and mission code remain unchanged. The only world
script addition registers its existing meshes with the appearance component.

## Verification

Run from the project root with Godot 4.6.3 and matching web templates:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script res://tests/malta_terrain_checks.gd
bash tools/build_web.sh
node tools/malta_terrain_web_smoke.cjs
```

The browser test needs Node, Playwright and Chromium (optional `CHROME_BIN`).
It serves the actual release build locally, uses real menu/key input and
saves screenshots/results to `/tmp/malta-terrain-review`. With a graphical
display, capture the native Luqa mission and an island overview:

```sh
godot --path . --audio-driver Dummy --resolution 960x600 \
  --script res://tests/malta_terrain_capture.gd -- /tmp/malta-terrain-review
```

The overview uses a review-only camera with a 10 m near plane to avoid depth
precision artefacts at a 100 km far plane. It does not change game cameras.
Native and browser capture fixtures are excluded from the release export.

Results for this change:

- **20/20 terrain checks:** all 36 active materials, beige default, explicit
  heatmap, physical/keycode F4, key repeat, paused toggling, clean new-world
  default, unchanged source vertex/index/colour buffers, transforms, bounds,
  collider faces/instances and all three airfield geography records.
- **132/132 existing regression checks:** keyboard 24, weapons 36, Malta 35,
  audio 37. Malta checks cover persistent boarding, engine state, landing
  contact and clean restart; these do not constitute a new manual flight.
- Actual native Godot render: Luqa normal/debug plus all-island overview
  normal/debug captured and visually reviewed. Native driver warned about
  unsupported VSync switching; no shader or resource errors.
- **14/14 release browser checks:** Luqa normal/debug captured and reviewed;
  active material paths and vertex-colour flags verified on all 36 meshes.
  The browser checks also cover pause, boarding, engine start, throttle,
  firing and full restart. No shader, resource, JS or HTTP errors.
- The matching Luqa captures have median terrain RGB `(170, 144, 96)` in both
  renderers. Across 4,436 horizon-terrain pixels identified by the normal/debug
  difference, native/browser mean absolute channel difference is 0.20/255.
  This compares this Linux/Chromium setup, not every GPU or editor version.
- Source GLB and geography SHA-256 checksums remain unchanged:
  `23b8508fd6c7de310b2dd67a32ba03497e2029ae21dfed0f703455dc06b71d7e`
  (`terrain.glb`),
  `27727d98b4c8834144f9bbc7c36c09a6de07284770f533e18a3fd37a1e7aedc0`
  (`world_data.json`).

The user's Windows/Godot 4.7 ANGLE setup, other browsers/GPUs, live Pages
deployment/cache headers and a fresh manual end-to-end flight are unverified.
This is an independent material fix; no realistic textures, vegetation or
new landscape detail have been added.

For a quick manual check, start Malta at any airfield: normal should be beige
with no debug notice. Press F4: the rainbow elevation colours and notice
should appear. Press F4 again: beige returns. Restart with R: beige must be
the default even if the previous world was left in debug mode. Repeat after
exporting/serving the web build, keeping all exported files together.
