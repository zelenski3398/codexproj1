# Cottonera: data-gated integration and unplaced asset templates

**Status: the Three Cities reconstruction is NOT complete or populated in the playable map.** The requested source pages and geographic services were blocked by the environment's HTTPS proxy. The task explicitly says not to invent geographic geometry and to provide an importer/placeholders when data are missing. This implementation follows that fallback. It does not claim that Fort St Angelo, the two defensive lines or a historic street/dock layout have been reconstructed at verified positions.

## What is available, and what is missing

The supplied terrain package contains the existing OSM coastline, elevation raster/mesh and metadata. There are no Cottonera building, street, fortification or dockyard footprints in that package or elsewhere in the workspace.

The following requested/reference services returned `Tunnel connection failed: 403 Forbidden` on 2026-10-16:

- [Commons fortification plan](https://commons.wikimedia.org/wiki/File:Santa_Margherita_%26_Cottonera_Lines_map.png)
- [Kottonera history](https://www.kottonera.mt/history/)
- OpenStreetMap map API, the main Overpass endpoint and a separate Overpass endpoint.
- A Commons metadata endpoint, the Commons image CDN, a Wikipedia Cottonera reference page, and the official GeoFabrik Malta PBF download.

These pages were **not read**. Their contents, map alignments and image licensing were not assumed. `assets/malta/cottonera/source/access_report.json` records the attempted destinations and missing inputs.

A public `geonamescache` package download was available through the Python package index. Four **GeoNames named-place points** were extracted, with source IDs, package checksum and attribution. These coarse gazetteer points locate names, not historic city centres, boundaries, building footprints or landmark entrances. They are not used to invent any missing outlines.

| Named point | GeoNames ID | Latitude | Longitude | Existing world X / Z (m) | Sampled height (m) |
| --- | --- | --- | --- | --- | --- |
| Vittoriosa / Birgu | 2562966 | 35.89157 | 14.51765 | 10591.98 / 4321.26 | 0.69 |
| Senglea / Isla | 2562792 | 35.88777 | 14.51588 | 10430.15 / 4741.94 | 1.62 |
| Cospicua / Bormla | 2563181 | 35.88556 | 14.52750 | 11477.74 / 4992.19 | 31.49 |
| Kalkara | 2562830 | 35.88917 | 14.53278 | 11956.22 / 4594.08 | 32.20 |

The conversion is the existing EPSG:32633 projection relative to `(14.4 E, 35.93 N)`: **X = E−E0; Z = N0−N; Y = existing terrain height**. Road patches are sampled with their imported node transforms. No world scale, coastline, terrain vertex, road path or original airfield/mission coordinate is changed. Hashes of the protected files are recorded and checked.

## Completed preparation

`CottoneraRegion` is loaded once within the same `MaltaWorld`, with distinct Birgu, Senglea, Bormla and Kalkara nodes. Its current manifest is explicitly `awaiting_geodata`, with zero urban visual/collision chunks. The names appear as geographic navigation labels; no guessed city or fort is spawned underneath them. Debug placeholder labels are disabled by default. Retry frees/recreates one region, and F4 preserves existing debug behaviour.

The original, **unplaced** template library contains:

- A tiered harbour-fortress / Fort St Angelo template with angular terraces, raised batteries and inner enclosure; no fantasy circular towers.
- Maltese source-footprint houses with flat roofs, windows, wooden balconies, doors and retained source courtyard holes.
- A Gardjola-style lookout template.
- Separate selectable curtain-wall/bastion assets for the outer Cottonera and inner Santa Margherita systems, with battered faces and true open arch/gate collision.
- Three selectable church templates and a palace template; their schematic architecture is not a claim about each landmark's actual 1942 facade or footprint.
- Original naval warehouse, crane and dry-dock templates. No yachts, marina pontoons or modern redevelopment are added.

Review these by opening **`scenes/cottonera_asset_review.tscn` and pressing F6**. Its layout is a clearly labelled asset display stand, **not Malta coordinates or a city reconstruction**. The gallery is never instantiated in the playable world.

[Native Compatibility screenshot of the unplaced templates](previews/cottonera-unplaced-templates.png).

## Import real geographic data

`tools/import_cottonera.py` accepts **WGS84 GeoJSON, OSM XML or Overpass JSON** from local files. It requires a source citation, licence and source epoch. It resolves OSM node references and multipolygon holes, preserves source coordinates and tags, rejects invalid/out-of-area geometry and duplicate source IDs, and keeps the two defensive systems distinct. Identifiable post-1942 construction and yacht marinas are excluded rather than replaced with invented historic buildings.

Modern footprints remain labelled `modern_baseline`, not verified 1942 geometry. Historic plans and photographs need human review and georeferencing before they establish a wartime alignment. The supplied PNG is not automatically traced or projected without control points. No unverified air-raid shelters or blanket destruction are generated.

Every constructed feature needs an explicit source/review city assignment, using `cottonera_city`: `birgu`, `senglea`, `bormla` or `kalkara`. `addr:city` may supply a recognized town name, or a per-feature review JSON may add the assignment. The importer does **not** draw city boundaries or assign all features to the nearest coarse gazetteer point. For a single-city extract, `--city birgu` is an explicit user assignment; do not use it for an entire Three Cities extract.

Optional `cottonera_role` overrides distinguish:

- `building`, `road`, `footway`, `warehouse`, `quay`, `crane`, `dry_dock`;
- `fort_st_angelo`, `gardjola`, `st_michael`, `birgu_landfront`, `senglea_waterfront`, `bastion`, `gate`;
- `cottonera_lines` and `santa_margherita_lines`;
- `st_lawrence`, `inquisitors_palace`, `victories_basilica`, `immaculate_conception`, `church`.

Recognized source names/tags can classify roles, but unknown fortifications remain unclassified instead of silently becoming one of the two defensive lines. Building/fort/dock roles need actual polygons; point labels are not expanded into invented footprints. Point locations are sufficient only for schematic engineering assets such as a crane, gate or sentry hut. Gate `bearing` and `opening_width` should be reviewed against the mapped passage. Native source holes remain courtyards.

Example workflow after obtaining the files:

```sh
/tmp/malta-geo-venv/bin/python tools/import_cottonera.py /path/to/cottonera.osm \
  --output assets/malta/cottonera/features.geojson \
  --source 'OpenStreetMap extract, retrieval date and area' \
  --licence 'ODbL 1.0; OpenStreetMap contributors' \
  --epoch modern_baseline --review /path/to/feature-review.json
/tmp/malta-geo-venv/bin/python tools/build_cottonera.py
godot --headless --path . --editor --import --quit
```

A review file maps source IDs such as `way/123` to reviewed properties (`cottonera_city`, `cottonera_role`, a justified `historical_override`, etc.). The quoted source/citation above is a placeholder to replace with the actual dataset provenance. Preserve licence/attribution for every supplied source. Source gazetteer and coastline notices are in `assets/malta/cottonera/source/README.md` and `assets/malta/source/README.md`.

GeoPackage/SHP must first be exported to EPSG:4326 GeoJSON in a GIS tool. PBF must be converted to OSM XML or GeoJSON; direct PBF/GPKG/SHP parsing is not claimed. No network or GIS/Python dependency is added to the running game.

## Geometry, collision and LOD pipeline

`tools/build_cottonera.py` constructs **only imported source features**. It clips buildings to the existing dry-land polygon and reserves both source streets and the protected game roads. Street widths are taken from source tags or conservative defaults; narrow pedestrian routes are not widened for trucks. Paving samples the original terrain; it is not a second overlapping terrain mesh. Source-less features and unavailable terrain are reported instead of assigned fake positions/heights.

The two defensive systems are generated separately from their mapped alignments, with source gate/road openings. There is no generic circular enclosing wall. The dock template is allowed only where its supplied footprint is compatible with the existing water; a dock requiring excavation is reported/skipped. Its schematic dry floor sits just above the unchanged sea to prevent water bleeding through it. It is not an exact historic dock cross-section. Terrain excavation and verified ditch profiles are not implemented in the fallback.

Static batches are split into 180 m regional chunks with shared materials. Three visible levels are explicit:

1. **LOD 0:** structure meshes plus facade/roof detail, 0–700 m.
2. **LOD 1:** structure/landmark meshes, 700 m–5 km.
3. **LOD 2:** low-cost skyline/roof masses, 5–16 km.

Importer-generated mesh LODs and frustum culling are also enabled. Coarse collision is separate and remains loaded as visuals switch; fast existing projectiles use the same physical walls. These assets do not add autonomous AI, weapon or mission rules. Synthetic test features cannot overwrite the shipped geographic dataset. Empty inputs produce no fabricated GLBs and retain `awaiting_geodata`; partial data report missing roles/cities rather than claiming the complete environment.

## What remains blocked

To finish the requested **mapped, walkable WWII Three Cities**, provide:

- A local OSM/GeoJSON extract covering buildings, roads, pedestrian routes, harbour/dock features and fortifications, with provenance/licence.
- The Commons plan image/file and usable historical landmark/control-point information, plus historic dockyard references.
- Review/assignments for the two fortification lines, named landmarks and modern-vs-wartime waterfront changes.

Alternatively, make the reference/data hosts accessible in environment settings (`commons.wikimedia.org`, `upload.wikimedia.org`, `www.kottonera.mt`, `api.openstreetmap.org`, `overpass-api.de`, `download.geofabrik.de`). The existing network allowlist was unavailable, so no unknown configuration was replaced.

Continuous Birgu–Bormla–Senglea walking/driving, Fort St Angelo access, real dock/fortification alignment, full populated-region frame rate and a true browser flyover **cannot be verified without those datasets and placed geometry**. The current asset gallery and synthetic compiler fixtures do not satisfy those acceptance criteria. The existing playable world remains operational while this data-gated preparation is in place.

## Validation and staged commits

Completed checks:

| Check | Result |
| --- | --- |
| Local GeoJSON / OSM / Overpass importer, provenance, incomplete-geometry rejection | 14/14 |
| Source-gated compiler, missing-data behaviour, synthetic-data guard, three tiers, outward dome normals | 10/10 |
| Godot source-gated region, anchors, debug/retry, LOD ranges and actual gate collision | 14/14 |
| Existing Mdina walking/driving/roads/placement | 24/24 |
| Existing Valletta city | 17/17 |
| Terrain / rendering / source geometry | 30/30 |
| Malta takeoff, landing, boarding and persistence | 35/35 |
| Interception mission and outcomes | 77/77 |
| AA-defence mission and outcomes | 47/47 |
| Release Chromium/ANGLE web checks, including pending region, no phantom geometry and retry | 28/28 |

That is **24 Python data-pipeline checks, 244 native checks and 28 browser checks**. The web export completed without script/shader/resource errors. The unplaced template review was actually rendered in native Compatibility mode. These results validate the preparation and preservation of the existing game; they are **not** evidence of a populated Cottonera environment, street traversal or full-region performance.

The work is split into nine reviewable preparation commits, matching the requested order as far as the missing inputs permit:

1. Source-derived geographic anchors and blocked/missing-data record.
2. Footprint-driven Fort St Angelo template, awaiting real fort outline.
3. Senglea house/lookout templates, awaiting actual streets and footprints.
4. Distinct defensive-line wall, bastion and gate templates, awaiting alignments.
5. Source-placeable naval dockyard templates, awaiting historic dock plans.
6. Local geographic-data importer with explicit source, licence, epoch and city review.
7. Individually selectable church/palace templates, awaiting landmark footprints.
8. Conditional continuous-world region, collision/three-level pipeline and explicit unplaced review scene.
9. Native/web validation, robustness corrections, provenance and outstanding-data documentation.

No successful mapped reconstruction stage is claimed for a feature whose geometry is still unavailable.
