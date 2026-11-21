# Wartime Mosta

Mosta is part of the continuous Malta world and appears on its navigation chart. The Rotunda is centred at **35.91008646240458° N, 14.425960588733876° E** in WGS84. The generator projects that point into the game’s established EPSG:32633 frame and subtracts the existing origin, yielding **X 2328.888 m, Z 2222.788 m**. North remains −Z. The generator independently checks the three existing airfield coordinates before using the frame. At runtime the church samples the original ground collision for altitude, and its foundation reaches the lower parts of the drum perimeter. No terrain vertices or elevation datum were changed.

## Reference alignment

The supplied map and two aerial photographs were used as wartime references. Their dates and original editions remain unverified. The hand trace interprets the map’s building groups, roads and gaps, excluding its labels, controls, grid lines and orange annotation. The photos inform the roof heights, yards, limestone palette, church proportions and the town-to-field transition.

The fit pins the user’s Rotunda coordinate and estimates a uniform scale and rotation from three neighbouring features. No independent stretching is applied. At **4.069 metres per pixel** and **1.36° clockwise** in image X/Z coordinates, the approximate residuals are **30 m** at Speranza Bridge, **152 m** at Mosta Bridge, and **90 m** at Naxxar Parish Church. These reflect uncertainty in identifying exact features in the cropped map. The result is a registered village-scale interpretation, with scale and rotation overrides exposed in the trace. [Speranza Bridge](https://mapcarta.com/es/17470464) · [Mosta Bridge](https://www.geonames.org/2562703/mosta-bridge.html) · [Naxxar Parish Church](https://mapcarta.com/W33684532)

The portico faces **164.67° clockwise from projected north**, derived from the mapped front façade and consistent with its documented southerly aspect. The parish gives a 56.2 m exterior diameter and 39.6 m interior diameter. A published architectural account gives 54.8 m for the dome at the drum and about 74 m overall from rear to portico. The model uses the larger exterior diameter for the cornice and narrows the dome spring. Tower heights, steps and roof profiles are adjustable estimates from the photographs. The church is intact, with a stepped dome, lantern, cylindrical drum, paired bell towers and six-column portico. [Parish dimensions](https://mostachurch.com/?lang=en) · [Architectural account](https://www.um.edu.mt/library/oar/bitstream/123456789/71933/1/Morana_Martin_The%20building%20of%20the%20Mosta%20Rotunda_The%20Sunday%20Times%20of%20Malta_2019_10_20.pdf) · [Mapped church footprint](https://www.openstreetmap.org/way/542093526)

## Streets, terrain and buildings

Seventeen projected street lines include two ties into the existing Ta’ Qali and Birkirkara roads. A small terrain-material mask adjusts the paved and earthen surfaces and suppresses conflicting road paint locally. The recovery truck samples the corrected streets for pickup candidates. The underlying terrain, its road grading, the shape of the valley and the island network outside the site stay in place.

The built-up boundary and branching street frontage determine the placement of narrow limestone houses. Deterministic variation adds mostly one- and two-storey buildings with flat roofs, parapets, roof rooms, sill and lintel detail, and occasional timber-coloured balconies. Individual plots and façades are inferred. Enclosed gardens, farmyards, rubble walls and field colours preserve the open spaces in the trace. Each house samples the ground at its centre and four corners. Foundations follow slopes, and plots with excessive relief are skipped.

The vegetation exclusions and countryside masks remove overlapping plants and wall visuals. The corresponding original rural wall triangles are removed locally from collision. Building shells and close architectural details use spatially grouped MultiMeshes, with façades culled at distance and simplified compound collision for most houses. Up to 40 houses near the square and at farm sites use individually named damage sections. The landmark and remaining houses use static collision and have stable part or plot identifiers.

## Captures

- [North-up historical trace and in-engine overhead comparison](previews/mosta-overhead-comparison.jpg)
- [Southeast oblique](previews/mosta-oblique-southeast.jpg)
- [Southwest oblique](previews/mosta-oblique-southwest.jpg)
- [Forecourt and portico](previews/mosta-forecourt.jpg)

The comparison panel shows the traced boundary and streets in the same projected frame as the overhead capture. It represents the interpreted map geometry. The obliques follow the general viewing directions of the supplied photographs. Exact photo camera poses remain unknown.

## Rebuilding and checks

The [source trace](../assets/malta/mosta/reference_trace.json) holds map controls, paths, boundaries and landmark dimensions. Run `python3 tools/generate_mosta.py` with NumPy, pyproj, Shapely and Pillow to regenerate the deterministic layout and material masks. Run `godot --headless --fixed-fps 120 --script tests/mosta_checks.gd` for site checks. Run `tests/mosta_capture.gd` through Godot with a graphics renderer and set `MOSTA_CAPTURE_DIR` to choose the capture folder.

[Development entry and validation](development-updates/2026-11-21-wartime-mosta.md)
