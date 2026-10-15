# Valletta city scenery

The Malta maps now share one original, flight-scale fortified city on the existing Valletta peninsula. The supplied screenshot guides the dense street-block silhouette, courtyards and angular fortifications; no Sketchfab mesh, photograph texture or external runtime service is used. This is an approximate period-inspired reconstruction, not a surveyed copy of every building in the reference.

The city contains 880 low-rise limestone buildings, open courtyards, a principal avenue and cross streets, rooftop parapets, small roof structures, facade windows and occasional green timber balconies. It includes simplified St John's co-cathedral, Grand Master's Palace, St Paul's spire, the intact Royal Opera House and Fort St Elmo. The present large Carmelite dome is deliberately absent because it is post-war. Landmark positions are approximate geographic anchors, not verified historic footprints.

The procedural model uses the project's existing EPSG:32633 transform relative to 14.4° E / 35.93° N, at one unit per metre. The city grid runs from the approximate City Gate location (14.5092, 35.8951) toward Fort St Elmo (14.5194, 35.9020). Lots are clipped to the supplied coastline and fitted to the current terrain's actual triangle heights. Embedded foundations accommodate slopes without flattening or changing the islands. No terrain vertices, coastlines, airfield records, mission targets, aircraft, controls or spawn positions are changed.

## Integration and performance

- `scripts/valletta_city.gd` is world-owned scenery, created once by `MaltaWorld` for every Malta environment/mode; restarting frees the old city. No travel loading or new scene transition is introduced.
- `assets/malta/valletta/city.glb` contains 162,816 source triangles in 42 render chunks, with importer-generated mesh LODs. Main structures remain visible out to 14 km; windows, balconies and trim cull at 1.6 km. Chunk frustum/distance culling is independent of collision.
- `collision.glb` contains only main structures, roofs and fortifications. Its 21 static collision chunks block aircraft, on-foot movement and existing swept gunfire. Small cosmetic details are omitted from collision. Buildings do not have new destruction/damage logic.
- An explicit rough `StandardMaterial3D` uses the authored sRGB limestone palette. There are no custom city shaders, downloaded textures, GPU particles or renderer-specific features. This city palette is independent of terrain heatmap colours.
- F4 hides the city for terrain inspection and restores it on return to normal rendering; collision remains stable. The old 32 scattered town blocks are removed. Existing rural vegetation remains independent.

Rebuild with the already-installed geographic tool environment:

```sh
/tmp/malta-geo-venv/bin/python tools/generate_valletta.py
godot --headless --path . --editor --import --quit
```

The generator reads current terrain and supplied coastline files, writes only the `valletta` asset directory, and records source terrain SHA-256, dimensions, lot records, budgets and landmarks in `layout.json`. Dependencies are NumPy, trimesh, Shapely, pyproj, matplotlib and triangle; none are runtime game dependencies. Coastline-derived placement retains the existing OpenStreetMap attribution in `assets/malta/source/README.md`.

## Review

Select any Malta environment and fly toward the existing **Valletta** navigation landmark, northeast of Luqa and east of Ta' Qali. Approach at roughly 200–600 m above ground to see the city blocks and waterfront defences. Fly toward the peninsula's northeast tip for Fort St Elmo. Streets and courtyards remain open rather than becoming one solid city collider.

Native Compatibility-renderer captures of the actual playable world:

- [City and harbour overview](previews/valletta-aerial.png)
- [Fort St Elmo and peninsula](previews/valletta-fort.png)
- [Street blocks and rooftops](previews/valletta-streets.png)

Regenerate previews with a graphical display using `godot --path . --script res://tests/valletta_capture.gd`. That fixture creates review-only cameras and does not relocate players in normal gameplay.

Validation commands:

```sh
godot --headless --path . --fixed-fps 120 --script res://tests/valletta_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/malta_terrain_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/interception_checks.gd
bash tools/build_web.sh
node tools/malta_terrain_web_smoke.cjs
```

Completed checks: **17/17 city**, **30/30 terrain**, **35/35 Malta flight/landing/persistence**, **77/77 interception**, **47/47 AA defence**, and **20/20 defence audio** (226 native checks total). The release web export and **20/20 Chromium/ANGLE browser checks** passed, including bundled city geometry/collision, heatmap switching, engine/weapons controls and retry. Native Compatibility screenshots above were rendered and inspected; no script, shader or resource errors were reported.

The city is intentionally an exterior flight asset: no interiors, civilians, separately damageable buildings or exact historic facade survey. Source terrain resolution still limits detailed waterfront steps and streets on steep slopes; no claim is made of a complete walkable historic city. Full manual low-level flight and every street/vehicle traversal remain unverified. Automated native ray tests sample roofs and facades, while browser checks validate loading, world ownership, debug switching and restart; they are not a browser flyover of every building.
