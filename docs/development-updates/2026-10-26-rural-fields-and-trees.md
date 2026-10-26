# 26 October 2026 — larger agricultural parcels and Mediterranean trees

Source boundary: [`9ae7f845634149f5d6b54e79cf5b9e12de08a5d7`](https://github.com/zelenski3398/codexproj1/commit/9ae7f845634149f5d6b54e79cf5b9e12de08a5d7). Previous documented source: `4f376d68bd90a2ad593301e453abe43bda756451`. The range includes documentation publication `9b1264e`, implementation `2845b8a` and terrain-regression clarification `9ae7f84`. The original complete history remains frozen.

## Observable evolution

The former 17,977-field row/column pattern had a 1,212 m² median area. Weighted recursive straight divisions now create **9,703 parcels across 389 groups**, with a **4,711 m² median** and **10,666 m² 90th percentile**. Approximately 83% exceed 2,400 m². Total footprint increases from 30.06 to **54.55 km²**, despite fewer plots. Unequal quadrilaterals, trapezoids, 644 triangles and more complex clipped polygons share actual subdivision boundaries. Geometry is inferred, not historical cadastral evidence.

Groups follow existing contours/roads and clip to original geographic exclusions. The underlying terrain, coastline, road data, airfield/mission positions, historic cities, Cottonera and broad painted landcover are unchanged. Soil skins remain render-only over existing triangles. Muted colours replace bright contrast; the soil shader decodes vertex colour before applying its bundled detail texture.

The physical rubble style remains. Shared boundaries form one noded graph; the approximately 45 km budget now allocates by 2.5 km region before probabilistic selection. All 61 substantial eligible cells retain both fields and walls. Access gaps, draped terrain heights, slope guards, persistent coarse collision and bounded near-rock streaming remain.

## Reusable trees and placement

The new [model compiler](../../tools/generate_maltese_trees.py) creates nine original GLBs plus nine distant LODs: broad dense carobs; twisted, airy grey-green olives; young conical and mature asymmetric Aleppo pines. They have distinct geometry, metre scale, normal buffers and opaque vertex-coloured bark/foliage, with no alpha cards or external textures.

There are **1,439 carobs, 2,077 olives and 1,284 pines**. Placement seed 194226 produces loose olive groves, agricultural edge groups, pine groups on uncultivated ground and isolated trees. Crowns clear protected masks; trunks clear physical walls by at least two metres and keep access tracks open. Roots use original terrain heights, and all instance bases remain upright. The old bush system uses 62 vetted scrub centres outside the new cultivated areas.

[MalteseTrees](../../scripts/maltese_trees.gd), under the existing landscape owner, shares 18 meshes and one opaque material. Its 2,531 spatial groups have corresponding near/far nodes, culled at 380/2,200 m. Near meshes have 878–1,244 triangles, distant meshes 330–480. A spatial lookup activates simple cylinder trunks within 220 m, at most 192 bodies; branches/leaves have no collision. Tree shadows are disabled. Existing heatmap ownership hides visuals and retry removes the old population.

[Current guide, changed assets/scripts, tuning, previews and regeneration commands](../malta-countryside.md).

## Actual validation

| Check group | Passed |
|---|---:|
| Countryside GIS/source | 27 |
| Tree placement/model source | 25 |
| Native countryside | 10 |
| Native vegetation integration | 11 |
| Actual low-flight integration | 5 |
| Ground vehicles / AA interaction | 61 |
| Retained test-map departure | 12 |
| Terrain/material regression | 30 |
| Valletta / airfield preservation | 17 |
| Production browser smoke | 8 |

This is **52 source/GIS checks, 146 native assertions and eight browser checks**. Tests verify full-footprint exclusions, real exported skin vertices, shared-wall uniqueness, contour/terrain heights, field diversity, species variants, opaque materials, tree spacing/groves/open land, actual trunk collision/caps, original controls and restart.

The overlap checker uses micrometre-precision overlay at coincident shared edges to avoid a GEOS intersection result outside both operands' envelopes. Independently snapping stored parcels introduced real narrow wedges and was not shipped. Original continuous parcel coordinates remain. Exported soil vertices all clear the protected mask. The maximum height discrepancy was **2.87 mm** after excluding the intentional 45 mm render offset; 172 float32-rounded edge vertices required a matching adjacent source triangle within 2 mm. Missing samples were not silently accepted.

The existing triangle-library triangulation produced degenerate-intersection warnings during the first build. Terrain skins now use GEOS constrained triangulation, and the final full rebuild is clean. The default Cottonera stone output is checked byte-for-byte against its previous compiler behaviour.

**Full deterministic rebuild:** all **3,087** field/wall GLBs, the complete agricultural manifest and tree/scrub placements regenerated identically into a temporary directory. All **18** tree models independently reproduced byte-identical GLBs. Tested Python dependencies are pinned in `tools/requirements-rural.txt`.

Native Compatibility/llvmpipe renders were inspected at walking height, field altitude and regional altitude, plus three species lineups. The low-flight fixture positions a healthy aircraft initially and then uses only normal aerodynamic control inputs: it traversed **676 m**, retained 100 HP and a minimum AGL of **110 m**, without reloading the world. It is not a claimed human takeoff-to-landing sortie.

The production Chromium ANGLE/SwiftShader smoke uses actual menus, boarding, Help, resizing and dismounting. It verifies the real rural population, all 18 shared meshes, opaque material/LOD ranges, a clear protected airfield spawn, stable world identity and no JavaScript/shader/resource errors. It does not teleport the production player to a grove or claim a complete browser countryside flight. Read-only telemetry is opt-in through the existing smoke flag.

Final web export succeeds. JSON inclusion is explicit, and tree attribution ships with the build. Mermaid parsing, local links, protected hashes and `git diff --check` were checked.

[Machine-readable validation](validation/rural-fields-and-trees-2026-10-26.json).

## Performance and limits

Baked rural assets occupy about 315 MiB; tree assets add about 0.5 MiB. There are 936 rural spatial batches and 3,087 GLBs, versus 950 / 4,260 previously. The tested game pack is 358,883,176 bytes (about 342.3 MiB). Close-rock active/load limits remain six/two. Tree LOD nodes are spatially culled; all 5,062 nodes are not drawn together.

Native software-render scene counters across the captures ranged from 30 to 1,780 draw calls and about 232k–362k primitives. These include the existing world and are not a hardware FPS benchmark. No low-end/mobile hardware, exhaustive drive along every road, complete human mission or subjective foliage/LOD review at every distance was performed. Layouts and planting are artistic approximations; the original broader landcover remains outside the generated groups. Live GitHub Pages deployment is not verified by local export.
