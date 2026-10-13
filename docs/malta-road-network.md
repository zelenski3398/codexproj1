# Malta road network and reference limits

The road network is baked into the continuous island mesh: 4.5 m-wide dusty lanes, softly blended shoulders, modest local grading and shared terrain collision. There are no elevated strips, junction overlays, extra floor colliders, bridges or scene transitions. Runway strips and a 10 m coastal guard exclude road coverage. Existing airfield coordinates, headings, aircraft and mission logic are unchanged.

`assets/malta/roads/reference_trace.json` contains editable image-pixel paths, explicit junction identifiers, anchor coordinates, widths and uncertainty notes. `world_paths.json` contains their generated world-space paths and junctions. Short inferred access links are labelled separately; Ħal Far's 563 m connector detours around the runway end (Ta' Qali 163 m; Luqa 197 m). No modern road dataset was used and no settlement/building geometry was added.

## Important alignment limitation

This is an **approximate main-route interpretation**, not a surveyed reconstruction or a complete trace of every line. The provided 721 × 674 historic scan contains folds, cropped areas, small labels and an inset. Distributed landmark/airfield anchors determine orientation and a thin-plate warp; north-up is not assumed. However, the affine fit has about **559 m RMS residual** and leave-one-anchor-out validation about **1,234 m RMS / 2,524 m maximum**. The exact control-point fit of the warp does NOT establish positional accuracy. Some route positions between anchors can therefore be substantially wrong and need review against a clearer/georeferenced reference before claiming geographic fidelity.

Northern minor roads, cropped Gozo routes, Comino, ambiguous Dingli-side connections and dense urban/farm tracks are omitted rather than extrapolated. Paths intersecting water or the prototype runway footprint are masked out; these gaps are not bridges. The editable data retains the coarse source interpretation so it can be corrected without changing mission logic. These limitations mean the supplied request's full, faithful historical-road-network criterion is not yet verified.

## Surface and performance

Road centre profiles sample the actual source terrain after base grading. They retain hills/valleys, use restrained smoothing and cap local road cut/fill to ±1.5 m. The full road width and shoulder blend are refined offline at approximately 4 m stations. Original triangle edges and road edges are noded before constrained triangulation, retaining the supplied island domain and coastline.

Opaque coverage is stored in bundled GLB UV buffers, read by the existing Compatibility/WebGL 2 landscape shader. Heatmap mode ignores road coverage. Road-affected faces are partitioned into 512 m patches for frustum culling; narrow road patches retain high detail to avoid mask/boundary damage during simplification, while the other island meshes retain imported distance LOD. The remaining mainland shares patch boundaries and likewise retains detail to prevent seams. Each triangle belongs to one patch or the remaining terrain, with matching collision; none unload or disappear by distance. All resources are offline/bundled, with no GIS, Python or texture-download requirement at runtime.

To edit/regenerate, install `numpy scipy matplotlib shapely triangle trimesh pyproj` in a Python environment and run:

```sh
python tools/grade_malta_terrain.py --roads
```

Running the same tool without `--roads` regenerates only the independent base-grading result. The original supplied terrain is retained under `assets/malta/source/` and excluded from exports.

## Review and testing

Native Godot previews:

- [Island overview](previews/road-overhead.png)
- [Closer road-network view](previews/road-network-close.png)
- [Ta' Qali access](previews/road-access_ta_qali.png)
- [Luqa access](previews/road-access_luqa.png)
- [Ħal Far access](previews/road-access_hal_far.png)

Run `tests/malta_roads_checks.gd` for imported coverage, chunk/collider integration, metre widths, access metadata, land support, fixed airfield geography and actual truck traversal at each access. `airfield_ground_checks.gd` checks all three bases' runway/apron support and transitions. Existing flight/interception, manual gun/truck and flak checks protect gameplay. Native and browser screenshots are genuine rendered captures, not reference-map composites.

A complete manual taxi/takeoff/landing tour of every field, sustained road-network driving, exact map alignment and performance on consumer hardware remain unverified. Software-renderer timings are not representative performance benchmarks.

Validation for this change: **785/785 native assertions across 20 groups passed**, including **11/11 road checks** and **27/27 base-ground checks**. The release WebGL 2 browser terrain check passed **14/14**, with all imported patches using the same material, explicit heatmap switching, engine/weapons input and clean restart. The actual ground-departure interception fixture measured **89.44 s** bomber travel, preserving the 90-second mission rule. Source comparison confirmed all 35 other island geometries unchanged, original coastal/bottom vertices identical, fixed field XZ/headings/lengths, and all three inferred connectors avoiding runway footprints. Native previews were rendered with Godot 4.6.3 Compatibility/OpenGL; browser checks used software ANGLE, not a consumer-GPU performance test.
