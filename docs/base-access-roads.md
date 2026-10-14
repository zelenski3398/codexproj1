# Base access connections

All three Malta airfields have a continuous route from the existing public road to their apron, parking approach and both AA positions. Public-road paths, terrain geometry/elevation, coastlines, field positions and mission rules are unchanged. Connections remain labelled **inferred access**, not surveyed historical roads.

Full vehicle testing found that the earlier Ta' Qali and Luqa links intersected hangar corners. Their corrected links pass below the outer hangar with a 12 m rounding allowance at bends, then join the same existing public-road segment. Their lengths are approximately **189 m** and **224 m**. Ħal Far retains its working **563 m** route around the runway end. No unnecessary runway crossing, new settlement or extra floor collider was added.

The correction is deliberately local. The landscape material replaces only the two obsolete access masks inside small bounded areas; all other baked road masks remain intact. Terrain geometry/collision was not regenerated: its GLB is bit-for-bit unchanged. Existing ground grading already supports the revised corridors. New 4.5 m apron lanes are painted within the existing apron material, using the same dusty road colour and soft shoulders. Junctions use a single opaque coverage mask, so there are no overlapping road strips or flickering surfaces. Exterior corrections retain the existing public junction and repair its local coverage. Extra shader segment work is restricted to the two small correction bounds.

`assets/malta/roads/base_access.json` contains editable local lane endpoints, world-space entrance/public joins, parking approaches and navigation routes to each gun. `MaltaBaseAccess` applies the small per-apron material data. This is route metadata for manual travel/testing; it does not introduce vehicle AI or change interaction distances.

Regenerate **only these links/material parameters**, without rebuilding the terrain/public network:

```sh
python tools/build_base_access.py
```

The JSON is explicitly included in web exports. The original public network remains an approximate historic-map interpretation with the alignment limitations recorded in [the road documentation](malta-road-network.md).

Validation: **27/27 base-access checks passed**. The existing truck physically drove all six public-join → apron → gun routes using ordinary input, with parked aircraft and buildings present. Fixtures position the truck only at the starting public join; movement during each route uses its existing controller. Times were Ta' Qali **26.1 / 44.9 s**, Luqa **29.6 / 48.5 s**, and Ħal Far **85.4 / 66.6 s**. Measured maximum centreline grades were **6.06%, 1.60%, and 2.38%** respectively. All six destinations offered clear exits; parked aircraft remained undamaged, and the interception mission stayed in its pre-takeoff checkpoint phase.

Native previews: [Ta' Qali](previews/access-ta_qali.png), [Luqa](previews/access-luqa.png), [Ħal Far](previews/access-hal_far.png).

Full manual road driving during all six combat waves and performance on consumer hardware remain unverified. Automated live AA-mission travel separately verifies that the Stuka and wave state continue while changing from gun to truck; the mounted driver retains a damageable capsule with a collision exception only against its own truck.

Additional checks passed: **27/27 airfield-ground**, **30/30 terrain-material**, **11/11 road-network**, and **61/61 ground-control** assertions. Release browser validation passed **10/10 AA mission** and **16/16 terrain/access** checks, including bundled route data, all three apron lane sets, focused corrected links, heatmap switching, boarding, engine/gun input and reset, with no shader/resource/JavaScript errors. Desktop previews used Godot 4.6.3 Compatibility; browser checks used software ANGLE.
