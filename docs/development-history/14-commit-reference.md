# 14 — Commit-by-commit reference

[Contents](README.md) · [Milestones](02-development-timeline.md) · [Complete path/status manifest](commit-evidence.json)

This index covers **every reachable commit** in oldest-first Git order, root `64406b082d49576bf5c0ec8c95367530dab9ab2c` through `588ac7b1b37b72014b73fe679871e790e5c79145`. Each entry retains the original subject and actual author date, inspected changed paths and a technical interpretation of the diff. Important files link to the snapshot; removed paths are labelled. Full file status lists, original author/committer timestamp strings, parent hashes and categories are preserved in the JSON manifest. Ambiguous “Create/Delete CNAME” and reporting/test changes are included rather than dropped.

There are no merge commits; no PR merge is counted again as implementation. Public merged-PR/issue/release listings added no further accessible historical records; API limitations are in [coverage](README.md#history-coverage-and-access-limits).

## Searchable index

| # | UTC date | Commit | Original subject | Category / outcome |
| --- | --- | --- | --- | --- |
| 01 | 2026-10-07 | [64406b0](#64406b0) | Build first playable Spitfire flight prototype | Flight / Feature |
| 02 | 2026-10-07 | [81703b4](#81703b4) | Fix keyboard input for embedded game views | Input / Fix |
| 03 | 2026-10-08 | [b0bdb4f](#b0bdb4f) | Add wing guns, aircraft health and damage effects | Weapons / health / Feature |
| 04 | 2026-10-08 | [83e6073](#83e6073) | Make weapon script types explicit for parser compatibility | Parser / weapons / Fix |
| 05 | 2026-10-08 | [236dbf0](#236dbf0) | Add a flying Stuka enemy with pursuit and return fire | Enemy aircraft / Feature / replacement |
| 06 | 2026-10-09 | [d3dea47](#d3dea47) | Add selectable Gloster Sea Gladiator with slower biplane flight | Player aircraft / Feature |
| 07 | 2026-10-10 | [fc44efa](#fc44efa) | Extend Stuka AI encounter with terrain avoidance and clean wreck lifecycle | AI / destruction / Feature / fix |
| 08 | 2026-10-10 | [f1b9d05](#f1b9d05) | Add shared aircraft component damage and hitbox diagnostics | Component damage / Feature |
| 09 | 2026-10-10 | [63d4277](#63d4277) | Add Stuka rear gunner and persistent tactical pursuit | Stuka gunner / tactics / Feature / fix |
| 10 | 2026-10-10 | [850e33c](#850e33c) | Rebalance Stuka gunner with human aiming and combat telemetry | Gunner balance / Feature / rebalance |
| 11 | 2026-10-10 | [bf0a11c](#bf0a11c) | Add tested browser export and GitHub Pages deployment | Web / CI / Feature |
| 12 | 2026-10-10 | [c7b1f6c](#c7b1f6c) | Record verified web build and deploy after Pages activation | Documentation / deployment / Maintenance |
| 13 | 2026-10-10 | [3f16951](#3f16951) | Create CNAME | Hosting configuration / Maintenance / later removed |
| 14 | 2026-10-10 | [b093bc2](#b093bc2) | Delete CNAME | Hosting configuration / Removal |
| 15 | 2026-10-10 | [1f83c99](#1f83c99) | Add continuous Malta world, airfield selection and persistent aircraft boarding | Continuous world / ground / Feature |
| 16 | 2026-10-10 | [f5d9e76](#f5d9e76) | Integrate supplied menu theme and spatial aircraft audio | Audio / Feature |
| 17 | 2026-10-10 | [4a716c0](#4a716c0) | fix(terrain): unify Malta terrain rendering across local and web | Terrain rendering / Fix |
| 18 | 2026-10-10 | [e2f8451](#e2f8451) | feat(terrain): add WWII-era Maltese landscape materials and details | Landscape / Feature |
| 19 | 2026-10-11 | [af88162](#af88162) | fix(web): open directly to the game menu | Web menu / Fix / removal |
| 20 | 2026-10-11 | [ab97726](#ab97726) | feat(combat): add confirmed encounters and Malta Survival stages | Encounter progression / Feature / refactor |
| 21 | 2026-10-11 | [ac7fbac](#ac7fbac) | feat(missions): add Italian aircraft and Valletta interception | Italian aircraft / mission / Feature |
| 22 | 2026-10-12 | [4a32579](#4a32579) | feat(missions): guide navigation to nearby Italian interception | Interception navigation / Feature / revision |
| 23 | 2026-10-12 | [90c99ef](#90c99ef) | fix(hud): clear enemy placeholder during mission navigation | Mission HUD / Fix |
| 24 | 2026-10-12 | [00351b1](#00351b1) | feat(audio): add commander interception radio call | Mission radio / Feature |
| 25 | 2026-10-12 | [7fe44a7](#7fe44a7) | test(audio): wait for radio completion cleanup | Audio test / Fix / maintenance |
| 26 | 2026-10-12 | [6729637](#6729637) | feat(mission): shorten interception to two checkpoints and 90 seconds | Interception route / results / Feature / revision |
| 27 | 2026-10-13 | [45a15f9](#45a15f9) | feat(character): replace pilot placeholder with rigged RAF model | Character / Feature / replacement |
| 28 | 2026-10-13 | [6a36276](#6a36276) | feat(defence): add friendly AA batteries to Malta airfields | Friendly AA / Feature |
| 29 | 2026-10-13 | [5bbf563](#5bbf563) | feat(airfield): add manual AA controls and drivable military truck | Manual AA / truck / Feature / replacement |
| 30 | 2026-10-13 | [71b5195](#71b5195) | fix(aa): retain enemy tags and add larger bursts with cannon reports | AA presentation / Fix / rebalance |
| 31 | 2026-10-13 | [8218544](#8218544) | feat(aa): add severe proximity blast damage and devastating direct hits | AA damage / Feature / rebalance |
| 32 | 2026-10-13 | [917c0da](#917c0da) | fix(terrain): integrate Malta airfields with smoothly graded ground | Airfield ground / Fix |
| 33 | 2026-10-13 | [451ad8b](#451ad8b) | feat(terrain): add editable Malta road network integrated into ground | Roads / terrain / Feature |
| 34 | 2026-10-14 | [88e17ba](#88e17ba) | feat(missions): add six-wave manual AA defence against Stuka dives | AA defence mission / Feature |
| 35 | 2026-10-14 | [b135cdc](#b135cdc) | feat(roads): connect Malta base entrances to parking and AA positions | Base access roads / Feature / fix |
| 36 | 2026-10-14 | [2157b72](#2157b72) | feat(aa): add four-gun heavy batteries and clip-fed Bofors defence | Layered AA / Feature / revision |
| 37 | 2026-10-15 | [e26e5ed](#e26e5ed) | feat(aa): add relative mouse aiming and sight zoom with unlimited ammunition | AA input / ammunition / Feature / removal |
| 38 | 2026-10-15 | [eb5db64](#eb5db64) | feat(aa): add player-directed battery command and supplied defence audio | Battery command / defence audio / Feature |
| 39 | 2026-10-15 | [6c0fbc9](#6c0fbc9) | fix(audio): loop air-raid siren throughout defence mission | Defence alarm / Fix / replacement |
| 40 | 2026-10-15 | [bf96f9a](#bf96f9a) | feat(malta): add original fortified Valletta city to continuous world | Valletta scenery / Feature / replacement |
| 41 | 2026-10-16 | [814e308](#814e308) | feat(malta): reconstruct georeferenced fortified Mdina hilltop city | Mdina / shared scenery / Feature / refactor |
| 42 | 2026-10-16 | [29dc713](#29dc713) | feat(cottonera): establish source-derived alignment and record missing geography | Cottonera alignment / Preparation |
| 43 | 2026-10-16 | [d3ca959](#d3ca959) | feat(cottonera): prepare footprint-driven Fort St Angelo template | Cottonera fort asset / Preparation |
| 44 | 2026-10-16 | [dd9049a](#dd9049a) | feat(cottonera): prepare Senglea housing and lookout assets without invented streets | Cottonera Senglea assets / Preparation |
| 45 | 2026-10-16 | [de2dd12](#de2dd12) | feat(cottonera): prepare separate defensive-line walls bastions and gates | Cottonera defensive assets / Preparation |
| 46 | 2026-10-16 | [170f758](#170f758) | feat(cottonera): prepare source-placeable wartime dockyard assets | Cottonera dockyard assets / Preparation |
| 47 | 2026-10-16 | [154a952](#154a952) | feat(cottonera): import sourced footprints roads and distinct defensive lines | Cottonera data import / Feature / preparation |
| 48 | 2026-10-16 | [a4bf624](#a4bf624) | feat(cottonera): prepare footprint-driven church and palace landmark assets | Cottonera landmarks / Preparation |
| 49 | 2026-10-16 | [410ef4b](#410ef4b) | feat(cottonera): integrate source-gated regions collision and review templates | Cottonera region pipeline / Feature / preparation |
| 50 | 2026-10-16 | [588ac7b](#588ac7b) | test(cottonera): validate safe fallback LODs native web and missing-data workflow | Cottonera validation / robustness / Fix / test / maintenance |

<a id="64406b0"></a>

## 01. 64406b0 — Build first playable Spitfire flight prototype

| Field | Evidence |
| --- | --- |
| Commit | [64406b0](https://github.com/zelenski3398/codexproj1/commit/64406b082d49576bf5c0ec8c95367530dab9ab2c) (`64406b082d49576bf5c0ec8c95367530dab9ab2c`) |
| Date | 2026-10-07 16:24:09 UTC |
| Description | Build first playable Spitfire flight prototype |
| Category | Flight |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/airfield.gd](../../scripts/airfield.gd), [scripts/chase_camera.gd](../../scripts/chase_camera.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/landing_gear.gd](../../scripts/landing_gear.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/mesh_kit.gd](../../scripts/mesh_kit.gd), [scripts/pilot_input.gd](../../scripts/pilot_input.gd); 26 changed paths including metadata |
| Change | Creates the initial force-driven Spitfire, procedural countryside airfield, three-ray landing gear, chase camera, HUD, pause/reset and flight/capture checks. The root already contains playable code; no preceding prototype history is present. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="81703b4"></a>

## 02. 81703b4 — Fix keyboard input for embedded game views

| Field | Evidence |
| --- | --- |
| Commit | [81703b4](https://github.com/zelenski3398/codexproj1/commit/81703b4933e0ca1391448c5c423ac28ae66b93f0) (`81703b4933e0ca1391448c5c423ac28ae66b93f0`) |
| Date | 2026-10-07 16:41:05 UTC |
| Description | Fix keyboard input for embedded game views |
| Category | Input |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/pilot_input.gd](../../scripts/pilot_input.gd), [README.md](../../README.md), [project.godot](../../project.godot), [tests/keyboard_checks.gd](../../tests/keyboard_checks.gd); 7 changed paths including metadata |
| Change | Stores physical and logical key bindings in project.godot, handles HUD shortcuts before GUI navigation, removes runtime-only binding construction and adds keycode-forwarding regression tests. |
| Outcome | Fix; implementation commit, no merge parent pair |

<a id="b0bdb4f"></a>

## 03. b0bdb4f — Add wing guns, aircraft health and damage effects

| Field | Evidence |
| --- | --- |
| Commit | [b0bdb4f](https://github.com/zelenski3398/codexproj1/commit/b0bdb4f02babf34094c9ee2e1ff58e011672c721) (`b0bdb4f02babf34094c9ee2e1ff58e011672c721`) |
| Date | 2026-10-08 06:04:11 UTC |
| Description | Add wing guns, aircraft health and damage effects |
| Category | Weapons / health |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/damage_effects.gd](../../scripts/damage_effects.gd), [scripts/health.gd](../../scripts/health.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/pilot_input.gd](../../scripts/pilot_input.gd), [scripts/practice_target.gd](../../scripts/practice_target.gd), [scripts/projectile_pool.gd](../../scripts/projectile_pool.gd); 20 changed paths including metadata |
| Change | Adds eight visible wing-port salvos, fixed bullet/tracer/spark pools with segment sweeps, health/depletion, world-space damage effects and an initially stationary practice target. Flight destruction gates thrust and gun input. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="83e6073"></a>

## 04. 83e6073 — Make weapon script types explicit for parser compatibility

| Field | Evidence |
| --- | --- |
| Commit | [83e6073](https://github.com/zelenski3398/codexproj1/commit/83e60738746ed2a2b4c2dcd75316e8c62f9c8579) (`83e60738746ed2a2b4c2dcd75316e8c62f9c8579`) |
| Date | 2026-10-08 16:09:11 UTC |
| Description | Make weapon script types explicit for parser compatibility |
| Category | Parser / weapons |
| Files | [scripts/wing_guns.gd](../../scripts/wing_guns.gd), [tests/weapons_checks.gd](../../tests/weapons_checks.gd); 2 changed paths including metadata |
| Change | Changes inferred locals to explicit StandardMaterial3D, MeshInstance3D, Vector3, int and bool types in wing_guns.gd and weapons checks; observable runtime firing logic is otherwise retained. |
| Outcome | Fix; implementation commit, no merge parent pair |

<a id="236dbf0"></a>

## 05. 236dbf0 — Add a flying Stuka enemy with pursuit and return fire

| Field | Evidence |
| --- | --- |
| Commit | [236dbf0](https://github.com/zelenski3398/codexproj1/commit/236dbf093e2ba78afd3742a4dbd52b9df0685a56) (`236dbf093e2ba78afd3742a4dbd52b9df0685a56`) |
| Date | 2026-10-08 16:59:38 UTC |
| Description | Add a flying Stuka enemy with pursuit and return fire |
| Category | Enemy aircraft |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/enemy_aircraft.gd](../../scripts/enemy_aircraft.gd), [scripts/enemy_pilot.gd](../../scripts/enemy_pilot.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/projectile_pool.gd](../../scripts/projectile_pool.gd), [scripts/stuka_model.gd](../../scripts/stuka_model.gd), [scripts/wing_guns.gd](../../scripts/wing_guns.gd); 18 changed paths including metadata |
| Change | Introduces procedural inverted-gull Stuka and command-driven enemy pursuit/return fire; main.gd replaces the stationary target with EnemyAircraft. The practice-target script is retained but no longer the active encounter. |
| Outcome | Feature / replacement; implementation commit, no merge parent pair |

<a id="d3dea47"></a>

## 06. d3dea47 — Add selectable Gloster Sea Gladiator with slower biplane flight

| Field | Evidence |
| --- | --- |
| Commit | [d3dea47](https://github.com/zelenski3398/codexproj1/commit/d3dea47a244651baacf17f334f4d14f2d8c3894a) (`d3dea47a244651baacf17f334f4d14f2d8c3894a`) |
| Date | 2026-10-09 09:58:07 UTC |
| Description | Add selectable Gloster Sea Gladiator with slower biplane flight |
| Category | Player aircraft |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/aircraft_selector.gd](../../scripts/aircraft_selector.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/landing_gear.gd](../../scripts/landing_gear.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/sea_gladiator.gd](../../scripts/sea_gladiator.gd), [scripts/sea_gladiator_model.gd](../../scripts/sea_gladiator_model.gd), [README.md](../../README.md); 19 changed paths including metadata |
| Change | Adds SeaGladiator/SeaGladiatorModel, fixed-gear rejection, slower biplane force tuning and startup selection. Main/HUD lifecycle supports choosing either player aircraft rather than a single hardwired Spitfire. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="fc44efa"></a>

## 07. fc44efa — Extend Stuka AI encounter with terrain avoidance and clean wreck lifecycle

| Field | Evidence |
| --- | --- |
| Commit | [fc44efa](https://github.com/zelenski3398/codexproj1/commit/fc44efa7a43f2066de9a2edbf2b472e8d2c6f7d6) (`fc44efa7a43f2066de9a2edbf2b472e8d2c6f7d6`) |
| Date | 2026-10-10 09:57:48 UTC |
| Description | Extend Stuka AI encounter with terrain avoidance and clean wreck lifecycle |
| Category | AI / destruction |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/combat_teams.gd](../../scripts/combat_teams.gd), [scripts/destruction_burst.gd](../../scripts/destruction_burst.gd), [scripts/enemy_aircraft.gd](../../scripts/enemy_aircraft.gd), [scripts/enemy_pilot.gd](../../scripts/enemy_pilot.gd), [scripts/health.gd](../../scripts/health.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/main.gd](../../scripts/main.gd); 17 changed paths including metadata |
| Change | Adds CombatTeams, terrain-corridor avoidance, bounded/slewed manoeuvres, grace/damage-evade handling, one-shot ground impact and delayed wreck removal. Session cleanup/HUD distinguish an enemy loss from the still-falling wreck. |
| Outcome | Feature / fix; implementation commit, no merge parent pair |

<a id="f1b9d05"></a>

## 08. f1b9d05 — Add shared aircraft component damage and hitbox diagnostics

| Field | Evidence |
| --- | --- |
| Commit | [f1b9d05](https://github.com/zelenski3398/codexproj1/commit/f1b9d0576c98425770df6809fdc7048f87ac04a0) (`f1b9d0576c98425770df6809fdc7048f87ac04a0`) |
| Date | 2026-10-10 10:49:50 UTC |
| Description | Add shared aircraft component damage and hitbox diagnostics |
| Category | Component damage |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/aircraft_component_definition.gd](../../scripts/aircraft_component_definition.gd), [scripts/aircraft_damage.gd](../../scripts/aircraft_damage.gd), [scripts/aircraft_damage_profile.gd](../../scripts/aircraft_damage_profile.gd), [scripts/aircraft_hitbox.gd](../../scripts/aircraft_hitbox.gd), [scripts/component_damage_debug.gd](../../scripts/component_damage_debug.gd), [scripts/damage_effects.gd](../../scripts/damage_effects.gd), [scripts/damage_hitbox_spec.gd](../../scripts/damage_hitbox_spec.gd); 30 changed paths including metadata |
| Change | Adds eight component definitions, hitbox areas, per-airframe profiles and integrity-driven lift/drag/torque/power/control factors. Pool skips coarse aircraft bodies for localized hits; F3 diagnostics and independent fuel hazards are integrated. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="63d4277"></a>

## 09. 63d4277 — Add Stuka rear gunner and persistent tactical pursuit

| Field | Evidence |
| --- | --- |
| Commit | [63d4277](https://github.com/zelenski3398/codexproj1/commit/63d427747d0709d756d36ae3f33c24cc11157894) (`63d427747d0709d756d36ae3f33c24cc11157894`) |
| Date | 2026-10-10 11:48:31 UTC |
| Description | Add Stuka rear gunner and persistent tactical pursuit |
| Category | Stuka gunner / tactics |
| Files | [scripts/enemy_aircraft.gd](../../scripts/enemy_aircraft.gd), [scripts/enemy_pilot.gd](../../scripts/enemy_pilot.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/rear_gunner.gd](../../scripts/rear_gunner.gd), [scripts/stuka_model.gd](../../scripts/stuka_model.gd), [scripts/wing_guns.gd](../../scripts/wing_guns.gd), [README.md](../../README.md); 15 changed paths including metadata |
| Change | Adds rear model pivots and RearGunner with shared WingGuns, self-clearance and firing arcs. Reworks airborne acquisition/persistent pursuit and uses break/scissors/yo-yo navigation targets rather than velocity changes. |
| Outcome | Feature / fix; implementation commit, no merge parent pair |

<a id="850e33c"></a>

## 10. 850e33c — Rebalance Stuka gunner with human aiming and combat telemetry

| Field | Evidence |
| --- | --- |
| Commit | [850e33c](https://github.com/zelenski3398/codexproj1/commit/850e33c953b3b3289dcacbbf40a34e2b94df8b35) (`850e33c953b3b3289dcacbbf40a34e2b94df8b35`) |
| Date | 2026-10-10 13:03:16 UTC |
| Description | Rebalance Stuka gunner with human aiming and combat telemetry |
| Category | Gunner balance |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/component_damage_debug.gd](../../scripts/component_damage_debug.gd), [scripts/gunner_debug_panel.gd](../../scripts/gunner_debug_panel.gd), [scripts/gunner_skill_profile.gd](../../scripts/gunner_skill_profile.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/projectile_pool.gd](../../scripts/projectile_pool.gd), [scripts/rear_gunner.gd](../../scripts/rear_gunner.gd), [scripts/weapon_statistics.gd](../../scripts/weapon_statistics.gd); 22 changed paths including metadata |
| Change | Adds Cadet/Pilot/Ace profiles, delayed observations and learned target velocity, reaction/tracking/range/lead/movement errors, burst corrections and self-geometry checks. Adds per-station range/component hit telemetry and reproducible balance fixtures. |
| Outcome | Feature / rebalance; implementation commit, no merge parent pair |

<a id="bf0a11c"></a>

## 11. bf0a11c — Add tested browser export and GitHub Pages deployment

| Field | Evidence |
| --- | --- |
| Commit | [bf0a11c](https://github.com/zelenski3398/codexproj1/commit/bf0a11c9be53bb888cd0052b3111e5f43df295e2) (`bf0a11c9be53bb888cd0052b3111e5f43df295e2`) |
| Date | 2026-10-10 13:41:10 UTC |
| Description | Add tested browser export and GitHub Pages deployment |
| Category | Web / CI |
| Files | [scripts/aircraft_selector.gd](../../scripts/aircraft_selector.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md), [assets/fonts/DejaVu-LICENSE.txt](../../assets/fonts/DejaVu-LICENSE.txt), [assets/fonts/DejaVuSans.ttf](../../assets/fonts/DejaVuSans.ttf); 18 changed paths including metadata |
| Change | Adds Web export preset, custom browser shell, matching checked Godot/templates installer, build helper, Pages workflow, browser telemetry and smoke runner. Adds browser-friendly weapon-key guidance and bundled font/notices. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="c7b1f6c"></a>

## 12. c7b1f6c — Record verified web build and deploy after Pages activation

| Field | Evidence |
| --- | --- |
| Commit | [c7b1f6c](https://github.com/zelenski3398/codexproj1/commit/c7b1f6cc7a9acc5d49b39472a31e411b00aa3534) (`c7b1f6cc7a9acc5d49b39472a31e411b00aa3534`) |
| Date | 2026-10-10 13:47:36 UTC |
| Description | Record verified web build and deploy after Pages activation |
| Category | Documentation / deployment |
| Files | [docs/web-hosting.md](../../docs/web-hosting.md); 1 changed paths including metadata |
| Change | Updates web-hosting notes with recorded build/artifact success, initial Pages-disabled deployment and owner activation. No gameplay or workflow implementation changes occur in this diff. |
| Outcome | Maintenance; implementation commit, no merge parent pair |

<a id="3f16951"></a>

## 13. 3f16951 — Create CNAME

| Field | Evidence |
| --- | --- |
| Commit | [3f16951](https://github.com/zelenski3398/codexproj1/commit/3f1695169907679e4e43bea42e452c346993cc4d) (`3f1695169907679e4e43bea42e452c346993cc4d`) |
| Date | 2026-10-10 14:35:04 UTC |
| Description | Create CNAME |
| Category | Hosting configuration |
| Files | `CNAME` (not present now); 1 changed paths including metadata |
| Change | Adds root CNAME custom-domain configuration. Its hostname is not necessary to explain gameplay architecture; the next commit deletes this file. |
| Outcome | Maintenance / later removed; implementation commit, no merge parent pair |

<a id="b093bc2"></a>

## 14. b093bc2 — Delete CNAME

| Field | Evidence |
| --- | --- |
| Commit | [b093bc2](https://github.com/zelenski3398/codexproj1/commit/b093bc28793648fd28ebb7ef963513086ada5055) (`b093bc28793648fd28ebb7ef963513086ada5055`) |
| Date | 2026-10-10 14:35:49 UTC |
| Description | Delete CNAME |
| Category | Hosting configuration |
| Files | `CNAME` (not present now); 1 changed paths including metadata |
| Change | Deletes the just-added CNAME. No root CNAME exists at the audited snapshot; custom-domain configuration is therefore a transient historical change. |
| Outcome | Removal; implementation commit, no merge parent pair |

<a id="1f83c99"></a>

## 15. 1f83c99 — Add continuous Malta world, airfield selection and persistent aircraft boarding

| Field | Evidence |
| --- | --- |
| Commit | [1f83c99](https://github.com/zelenski3398/codexproj1/commit/1f83c99653e2804b811dadc8905e88f94a72d208) (`1f83c99653e2804b811dadc8905e88f94a72d208`) |
| Date | 2026-10-10 15:14:37 UTC |
| Description | Add continuous Malta world, airfield selection and persistent aircraft boarding |
| Category | Continuous world / ground |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/aircraft_selector.gd](../../scripts/aircraft_selector.gd), [scripts/airfield_installation.gd](../../scripts/airfield_installation.gd), [scripts/enemy_pilot.gd](../../scripts/enemy_pilot.gd), [scripts/ground_pilot.gd](../../scripts/ground_pilot.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/malta_airfield.gd](../../scripts/malta_airfield.gd); 48 changed paths including metadata |
| Change | Imports supplied Malta terrain/source/chart data and creates all airfields in one projected metre-scale world. Adds on-foot pilot, persistent parked fleet, boarding/exit, manual engine start, fuel use, installations and navigation with explicit full restart. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="f5d9e76"></a>

## 16. f5d9e76 — Integrate supplied menu theme and spatial aircraft audio

| Field | Evidence |
| --- | --- |
| Commit | [f5d9e76](https://github.com/zelenski3398/codexproj1/commit/f5d9e76f94e652b336f05afc993af24f0fa23d48) (`f5d9e76f94e652b336f05afc993af24f0fa23d48`) |
| Date | 2026-10-10 15:49:17 UTC |
| Description | Integrate supplied menu theme and spatial aircraft audio |
| Category | Audio |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/aircraft_audio.gd](../../scripts/aircraft_audio.gd), [scripts/game_audio.gd](../../scripts/game_audio.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/weapon_audio.gd](../../scripts/weapon_audio.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [scripts/wing_guns.gd](../../scripts/wing_guns.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml); 37 changed paths including metadata |
| Change | Adds menu theme, aircraft idle/flight and weapon recordings, offline conversion, audio buses/settings autoload, aircraft/weapon lifecycle components and native/web sample paths. Playback is owned by live aircraft and menus rather than previews. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="4a716c0"></a>

## 17. 4a716c0 — fix(terrain): unify Malta terrain rendering across local and web

| Field | Evidence |
| --- | --- |
| Commit | [4a716c0](https://github.com/zelenski3398/codexproj1/commit/4a716c086b380b59ccfc68ad373ae6ee2045de87) (`4a716c086b380b59ccfc68ad373ae6ee2045de87`) |
| Date | 2026-10-10 16:28:52 UTC |
| Description | fix(terrain): unify Malta terrain rendering across local and web |
| Category | Terrain rendering |
| Files | [scripts/malta_terrain_appearance.gd](../../scripts/malta_terrain_appearance.gd), [scripts/malta_world.gd](../../scripts/malta_world.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md), [assets/malta/materials/elevation_heatmap.tres](../../assets/malta/materials/elevation_heatmap.tres), [assets/malta/materials/limestone.tres](../../assets/malta/materials/limestone.tres), [docs/malta-terrain-rendering.md](../../docs/malta-terrain-rendering.md); 17 changed paths including metadata |
| Change | Adds explicit neutral StandardMaterial terrain override and separate default-off F4 heatmap; records the material-less COLOR_0 source and the un-reproduced Windows white appearance. Geometry, coordinates and flight remain unchanged in this commit. |
| Outcome | Fix; implementation commit, no merge parent pair |

<a id="e2f8451"></a>

## 18. e2f8451 — feat(terrain): add WWII-era Maltese landscape materials and details

| Field | Evidence |
| --- | --- |
| Commit | [e2f8451](https://github.com/zelenski3398/codexproj1/commit/e2f84517d23337779a67f04d15ffc95e68a6e4bb) (`e2f84517d23337779a67f04d15ffc95e68a6e4bb`) |
| Date | 2026-10-10 17:24:32 UTC |
| Description | feat(terrain): add WWII-era Maltese landscape materials and details |
| Category | Landscape |
| Files | [scripts/malta_airfield.gd](../../scripts/malta_airfield.gd), [scripts/malta_landscape_details.gd](../../scripts/malta_landscape_details.gd), [scripts/malta_terrain_appearance.gd](../../scripts/malta_terrain_appearance.gd), [scripts/malta_world.gd](../../scripts/malta_world.gd), [README.md](../../README.md), [assets/malta/ATTRIBUTION.txt](../../assets/malta/ATTRIBUTION.txt), [assets/malta/landscape/README.md](../../assets/malta/landscape/README.md), [assets/malta/landscape/cliff_detail.png](../../assets/malta/landscape/cliff_detail.png); 36 changed paths including metadata |
| Change | Replaces normal beige with bundled Mediterranean landscape ShaderMaterial/detail maps, adds MultiMesh landscape details and an initial simplified Valletta blockout, preserving opt-in heatmap. No runtime GIS downloads or shader displacement are introduced. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="af88162"></a>

## 19. af88162 — fix(web): open directly to the game menu

| Field | Evidence |
| --- | --- |
| Commit | [af88162](https://github.com/zelenski3398/codexproj1/commit/af8816231ea8e7acba182be5ce0a3e29906ce6c5) (`af8816231ea8e7acba182be5ce0a3e29906ce6c5`) |
| Date | 2026-10-11 18:38:49 UTC |
| Description | fix(web): open directly to the game menu |
| Category | Web menu |
| Files | [README.md](../../README.md), [docs/audio.md](../../docs/audio.md), [docs/web-hosting.md](../../docs/web-hosting.md), [tools/audio_web_smoke.cjs](../../tools/audio_web_smoke.cjs), [tools/malta_terrain_web_smoke.cjs](../../tools/malta_terrain_web_smoke.cjs), [tools/malta_web_smoke.cjs](../../tools/malta_web_smoke.cjs), [tools/web_smoke.cjs](../../tools/web_smoke.cjs), [web/shell.html](../../web/shell.html); 8 changed paths including metadata |
| Change | Removes the promotional landing/Play wrapper and repository footer link from the exported HTML shell, starts loading the engine automatically and opens the actual Godot game menu after a minimal progress/error overlay. |
| Outcome | Fix / removal; implementation commit, no merge parent pair |

<a id="ab97726"></a>

## 20. ab97726 — feat(combat): add confirmed encounters and Malta Survival stages

| Field | Evidence |
| --- | --- |
| Commit | [ab97726](https://github.com/zelenski3398/codexproj1/commit/ab97726e08ff5e59691e28e8115cda4f152c04c3) (`ab97726e08ff5e59691e28e8115cda4f152c04c3`) |
| Date | 2026-10-11 19:03:44 UTC |
| Description | feat(combat): add confirmed encounters and Malta Survival stages |
| Category | Encounter progression |
| Files | [scripts/component_damage_debug.gd](../../scripts/component_damage_debug.gd), [scripts/enemy_aircraft.gd](../../scripts/enemy_aircraft.gd), [scripts/enemy_encounters.gd](../../scripts/enemy_encounters.gd), [scripts/hud.gd](../../scripts/hud.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/malta_chart.gd](../../scripts/malta_chart.gd), [scripts/malta_departure_menu.gd](../../scripts/malta_departure_menu.gd), [scripts/malta_mission.gd](../../scripts/malta_mission.gd); 18 changed paths including metadata |
| Change | Introduces EnemyEncounters active/wreck lists, safe batch spawn planning, latched/deferred confirmation and generation cancellation. Adds Malta Survival stages 1,2,2,3,3 and an ace while preserving live player/world state between confirmations. |
| Outcome | Feature / refactor; implementation commit, no merge parent pair |

<a id="ac7fbac"></a>

## 21. ac7fbac — feat(missions): add Italian aircraft and Valletta interception

| Field | Evidence |
| --- | --- |
| Commit | [ac7fbac](https://github.com/zelenski3398/codexproj1/commit/ac7fbace7a0950d7d59e4413577a83a864a83553) (`ac7fbace7a0950d7d59e4413577a83a864a83553`) |
| Date | 2026-10-11 21:30:46 UTC |
| Description | feat(missions): add Italian aircraft and Valletta interception |
| Category | Italian aircraft / mission |
| Files | [scripts/aircraft_selector.gd](../../scripts/aircraft_selector.gd), [scripts/bomber_pilot.gd](../../scripts/bomber_pilot.gd), [scripts/component_damage_debug.gd](../../scripts/component_damage_debug.gd), [scripts/damage_effects.gd](../../scripts/damage_effects.gd), [scripts/defensive_gun_mount.gd](../../scripts/defensive_gun_mount.gd), [scripts/enemy_aircraft.gd](../../scripts/enemy_aircraft.gd), [scripts/enemy_aircraft_definition.gd](../../scripts/enemy_aircraft_definition.gd), [scripts/enemy_encounters.gd](../../scripts/enemy_encounters.gd); 53 changed paths including metadata |
| Change | Adds resource-defined C.200, CR.42 and SM.79 visuals/flight/damage, bomber and escort pilots, defensive mounts, physical MissionBomb and the first Valletta interception director/menu with an initial single checkpoint and five-minute deadline. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="4a32579"></a>

## 22. 4a32579 — feat(missions): guide navigation to nearby Italian interception

| Field | Evidence |
| --- | --- |
| Commit | [4a32579](https://github.com/zelenski3398/codexproj1/commit/4a32579b9cf1bfbc087df9847494d3104cffe84a) (`4a32579b9cf1bfbc087df9847494d3104cffe84a`) |
| Date | 2026-10-12 07:08:01 UTC |
| Description | feat(missions): guide navigation to nearby Italian interception |
| Category | Interception navigation |
| Files | [scripts/bomber_pilot.gd](../../scripts/bomber_pilot.gd), [scripts/interception_definition.gd](../../scripts/interception_definition.gd), [scripts/malta_chart.gd](../../scripts/malta_chart.gd), [scripts/malta_mission.gd](../../scripts/malta_mission.gd), [scripts/valletta_interception.gd](../../scripts/valletta_interception.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [README.md](../../README.md), [docs/valletta-interception.md](../../docs/valletta-interception.md); 15 changed paths including metadata |
| Change | Replaces one trigger with five resource-defined sequential checkpoints, measured 2500 m player-to-formation insertion ahead, whole-run activation guards and bomber route pacing. Player state is not reset when the final checkpoint activates. |
| Outcome | Feature / revision; implementation commit, no merge parent pair |

<a id="90c99ef"></a>

## 23. 90c99ef — fix(hud): clear enemy placeholder during mission navigation

| Field | Evidence |
| --- | --- |
| Commit | [90c99ef](https://github.com/zelenski3398/codexproj1/commit/90c99ef06854b6220e8690bd68657f518a6d7d86) (`90c99ef06854b6220e8690bd68657f518a6d7d86`) |
| Date | 2026-10-12 07:18:06 UTC |
| Description | fix(hud): clear enemy placeholder during mission navigation |
| Category | Mission HUD |
| Files | [scripts/hud.gd](../../scripts/hud.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [docs/valletta-interception.md](../../docs/valletta-interception.md), [tools/interception_web_smoke.cjs](../../tools/interception_web_smoke.cjs); 4 changed paths including metadata |
| Change | Clears the old enemy-placeholder status when interception has no spawned enemy, so checkpoint navigation does not misleadingly show a waiting or destroyed Stuka. Adds observable telemetry/assertion coverage. |
| Outcome | Fix; implementation commit, no merge parent pair |

<a id="00351b1"></a>

## 24. 00351b1 — feat(audio): add commander interception radio call

| Field | Evidence |
| --- | --- |
| Commit | [00351b1](https://github.com/zelenski3398/codexproj1/commit/00351b1f3fee6623381b5ed19ce0c7e9bdc25339) (`00351b1f3fee6623381b5ed19ce0c7e9bdc25339`) |
| Date | 2026-10-12 13:11:07 UTC |
| Description | feat(audio): add commander interception radio call |
| Category | Mission radio |
| Files | [scripts/game_audio.gd](../../scripts/game_audio.gd), [scripts/interception_definition.gd](../../scripts/interception_definition.gd), [scripts/mission_radio.gd](../../scripts/mission_radio.gd), [scripts/valletta_interception.gd](../../scripts/valletta_interception.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md), [assets/audio/ATTRIBUTION.txt](../../assets/audio/ATTRIBUTION.txt); 23 changed paths including metadata |
| Change | Adds supplied processed commander voice, MissionRadio single-shot subtitle/channel/mix handling and offline radio preparation; formation activation uses a 30-degree right bearing. Mixer temporarily ducks Aircraft/Guns without replacing saved levels. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="7fe44a7"></a>

## 25. 7fe44a7 — test(audio): wait for radio completion cleanup

| Field | Evidence |
| --- | --- |
| Commit | [7fe44a7](https://github.com/zelenski3398/codexproj1/commit/7fe44a78a74e81c67426c6852a2dc8211ceee7a9) (`7fe44a78a74e81c67426c6852a2dc8211ceee7a9`) |
| Date | 2026-10-12 13:23:43 UTC |
| Description | test(audio): wait for radio completion cleanup |
| Category | Audio test |
| Files | [docs/audio.md](../../docs/audio.md), [tests/mission_radio_checks.gd](../../tests/mission_radio_checks.gd); 2 changed paths including metadata |
| Change | Waits until playing is false, subtitle hidden and radio channel released, accounting for the later finished callback. Documents the audio-thread/idle cleanup ordering; no speech or mission logic replacement. |
| Outcome | Fix / maintenance; implementation commit, no merge parent pair |

<a id="6729637"></a>

## 26. 6729637 — feat(mission): shorten interception to two checkpoints and 90 seconds

| Field | Evidence |
| --- | --- |
| Commit | [6729637](https://github.com/zelenski3398/codexproj1/commit/67296373d09e7f3768fed7eff69470fc96e3f1a9) (`67296373d09e7f3768fed7eff69470fc96e3f1a9`) |
| Date | 2026-10-12 14:18:27 UTC |
| Description | feat(mission): shorten interception to two checkpoints and 90 seconds |
| Category | Interception route / results |
| Files | [scripts/interception_definition.gd](../../scripts/interception_definition.gd), [scripts/missions_menu.gd](../../scripts/missions_menu.gd), [scripts/valletta_interception.gd](../../scripts/valletta_interception.gd), [README.md](../../README.md), [docs/valletta-interception.md](../../docs/valletta-interception.md), [mission_definitions/valletta.tres](../../mission_definitions/valletta.tres), [tests/interception_checks.gd](../../tests/interception_checks.gd), [tests/interception_departure_checks.gd](../../tests/interception_departure_checks.gd); 10 changed paths including metadata |
| Change | Shortens the actual route to two nearby checkpoints, changes formation separation to 1200 m and deadline to 90 s, adds automatic ballistic release lead, vertical practical-spawn guards and crash effects. Results wait for expiry except immediate player loss. |
| Outcome | Feature / revision; implementation commit, no merge parent pair |

<a id="45a15f9"></a>

## 27. 45a15f9 — feat(character): replace pilot placeholder with rigged RAF model

| Field | Evidence |
| --- | --- |
| Commit | [45a15f9](https://github.com/zelenski3398/codexproj1/commit/45a15f93a1c4ceee45a0c588f1c8c6e0aafe3265) (`45a15f93a1c4ceee45a0c588f1c8c6e0aafe3265`) |
| Date | 2026-10-13 08:22:58 UTC |
| Description | feat(character): replace pilot placeholder with rigged RAF model |
| Category | Character |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/ground_pilot.gd](../../scripts/ground_pilot.gd), [scripts/malta_mission.gd](../../scripts/malta_mission.gd), [scripts/raf_pilot_avatar.gd](../../scripts/raf_pilot_avatar.gd), [scripts/sea_gladiator_model.gd](../../scripts/sea_gladiator_model.gd), [scripts/spitfire_model.gd](../../scripts/spitfire_model.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md); 27 changed paths including metadata |
| Change | Replaces primitive pilot visuals with original skinned RAF GLB, generator and reusable avatar wrapper; integrates Idle/Walk/Seated and player cockpit stations while retaining ground collision and instant boarding/exit handoff. |
| Outcome | Feature / replacement; implementation commit, no merge parent pair |

<a id="6a36276"></a>

## 28. 6a36276 — feat(defence): add friendly AA batteries to Malta airfields

| Field | Evidence |
| --- | --- |
| Commit | [6a36276](https://github.com/zelenski3398/codexproj1/commit/6a362768d5065098bfce8f148181c382f6a93e6b) (`6a362768d5065098bfce8f148181c382f6a93e6b`) |
| Date | 2026-10-13 08:37:05 UTC |
| Description | feat(defence): add friendly AA batteries to Malta airfields |
| Category | Friendly AA |
| Files | [scripts/aircraft.gd](../../scripts/aircraft.gd), [scripts/airfield_aa_battery.gd](../../scripts/airfield_aa_battery.gd), [scripts/british_aa_gun.gd](../../scripts/british_aa_gun.gd), [scripts/flak_effect_pool.gd](../../scripts/flak_effect_pool.gd), [scripts/malta_world.gd](../../scripts/malta_world.gd), [scripts/mission_bomb.gd](../../scripts/mission_bomb.gd), [scripts/projectile_pool.gd](../../scripts/projectile_pool.gd), [scripts/web_support.gd](../../scripts/web_support.gd); 28 changed paths including metadata |
| Change | Adds supplied emplacement GLB integration, two autonomous guns per field, shared shell pool/FlakEffectPool, muzzle animation/audio and bomb-damage API. This initial autonomous control is later removed. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="5bbf563"></a>

## 29. 5bbf563 — feat(airfield): add manual AA controls and drivable military truck

| Field | Evidence |
| --- | --- |
| Commit | [5bbf563](https://github.com/zelenski3398/codexproj1/commit/5bbf563938cfd8544e40e205de8c645b51361525) (`5bbf563938cfd8544e40e205de8c645b51361525`) |
| Date | 2026-10-13 09:39:06 UTC |
| Description | feat(airfield): add manual AA controls and drivable military truck |
| Category | Manual AA / truck |
| Files | [scripts/aa_aim_reticle.gd](../../scripts/aa_aim_reticle.gd), [scripts/airfield_aa_battery.gd](../../scripts/airfield_aa_battery.gd), [scripts/airfield_interaction.gd](../../scripts/airfield_interaction.gd), [scripts/british_aa_gun.gd](../../scripts/british_aa_gun.gd), [scripts/flak_effect_pool.gd](../../scripts/flak_effect_pool.gd), [scripts/malta_mission.gd](../../scripts/malta_mission.gd), [scripts/malta_world.gd](../../scripts/malta_world.gd), [scripts/military_truck.gd](../../scripts/military_truck.gd); 32 changed paths including metadata |
| Change | Removes friendly autonomous target selection/aim/fire, adds per-gun mounting/camera/reticle and exclusive AirfieldInteraction. Adds reference-inspired kinematic military truck with wheels/steering, camera, grounded safe exits and parking brake. |
| Outcome | Feature / replacement; implementation commit, no merge parent pair |

<a id="71b5195"></a>

## 30. 71b5195 — fix(aa): retain enemy tags and add larger bursts with cannon reports

| Field | Evidence |
| --- | --- |
| Commit | [71b5195](https://github.com/zelenski3398/codexproj1/commit/71b5195c1f13751792fc75ddade4a8ca84409375) (`71b5195c1f13751792fc75ddade4a8ca84409375`) |
| Date | 2026-10-13 11:21:26 UTC |
| Description | fix(aa): retain enemy tags and add larger bursts with cannon reports |
| Category | AA presentation |
| Files | [scripts/airfield_aa_battery.gd](../../scripts/airfield_aa_battery.gd), [scripts/british_aa_gun.gd](../../scripts/british_aa_gun.gd), [scripts/enemy_encounters.gd](../../scripts/enemy_encounters.gd), [scripts/flak_effect_pool.gd](../../scripts/flak_effect_pool.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [assets/audio/ATTRIBUTION.txt](../../assets/audio/ATTRIBUTION.txt), [assets/audio/aa_cannon_shot.ogg](../../assets/audio/aa_cannon_shot.ogg), [assets/audio/aa_cannon_shot.ogg.import](../../assets/audio/aa_cannon_shot.ogg.import); 14 changed paths including metadata |
| Change | Keeps hostile labels when the flight HUD is hidden for ground/gunner cameras; enlarges flak visuals, caps report voices and adds cannon-like AA sound at a two-shots/s cadence instead of the earlier machine-gun-like report. |
| Outcome | Fix / rebalance; implementation commit, no merge parent pair |

<a id="8218544"></a>

## 31. 8218544 — feat(aa): add severe proximity blast damage and devastating direct hits

| Field | Evidence |
| --- | --- |
| Commit | [8218544](https://github.com/zelenski3398/codexproj1/commit/82185442419146017a250afd730d17ed1cc998cd) (`82185442419146017a250afd730d17ed1cc998cd`) |
| Date | 2026-10-13 11:45:37 UTC |
| Description | feat(aa): add severe proximity blast damage and devastating direct hits |
| Category | AA damage |
| Files | [scripts/airfield_aa_battery.gd](../../scripts/airfield_aa_battery.gd), [scripts/british_aa_gun.gd](../../scripts/british_aa_gun.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [docs/airfield-aa.md](../../docs/airfield-aa.md), [tests/aa_checks.gd](../../tests/aa_checks.gd), [tests/aa_presentation_checks.gd](../../tests/aa_presentation_checks.gd), [tests/flak_damage_checks.gd](../../tests/flak_damage_checks.gd); 7 changed paths including metadata |
| Change | Raises direct-hit damage and introduces strong interpolated distance-based fragmentation using nearest component geometry/terrain cover; excludes directly struck aircraft from duplicate blast damage. Adds dedicated flak-damage checks. |
| Outcome | Feature / rebalance; implementation commit, no merge parent pair |

<a id="917c0da"></a>

## 32. 917c0da — fix(terrain): integrate Malta airfields with smoothly graded ground

| Field | Evidence |
| --- | --- |
| Commit | [917c0da](https://github.com/zelenski3398/codexproj1/commit/917c0da15000ef138ba2b92eef85b4062c5fe34c) (`917c0da15000ef138ba2b92eef85b4062c5fe34c`) |
| Date | 2026-10-13 12:00:36 UTC |
| Description | fix(terrain): integrate Malta airfields with smoothly graded ground |
| Category | Airfield ground |
| Files | [scripts/malta_airfield.gd](../../scripts/malta_airfield.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md), [assets/malta/grading/report.json](../../assets/malta/grading/report.json), [assets/malta/grading/settings.json](../../assets/malta/grading/settings.json), [assets/malta/source/.gdignore](../../assets/malta/source/.gdignore), [assets/malta/source/terrain_original.glb](../../assets/malta/source/terrain_original.glb), [assets/malta/source/world_data_original.json](../../assets/malta/source/world_data_original.json); 21 changed paths including metadata |
| Change | Retains original source GLB but locally refines/grades runtime island mesh at airfield footprints with smooth transitions/coastal protection. Replaces raised slab floor collision with terrain-only support and millimetre-offset visual runway/apron surfaces. |
| Outcome | Fix; implementation commit, no merge parent pair |

<a id="451ad8b"></a>

## 33. 451ad8b — feat(terrain): add editable Malta road network integrated into ground

| Field | Evidence |
| --- | --- |
| Commit | [451ad8b](https://github.com/zelenski3398/codexproj1/commit/451ad8b77dcf4ac2482c34e90cc9781bf3534619) (`451ad8b77dcf4ac2482c34e90cc9781bf3534619`) |
| Date | 2026-10-13 12:31:47 UTC |
| Description | feat(terrain): add editable Malta road network integrated into ground |
| Category | Roads / terrain |
| Files | [scripts/malta_world.gd](../../scripts/malta_world.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [.gitignore](../../.gitignore), [README.md](../../README.md), [assets/malta/ATTRIBUTION.txt](../../assets/malta/ATTRIBUTION.txt), [assets/malta/grading/report.json](../../assets/malta/grading/report.json), [assets/malta/materials/landscape.gdshader](../../assets/malta/materials/landscape.gdshader), [assets/malta/roads/generation_report.json](../../assets/malta/roads/generation_report.json); 29 changed paths including metadata |
| Change | Adds editable historic-scan trace/control data, projected road paths, constrained terrain refinement and UV road masks; partitions road ground into cullable patches. Documents geographic fit uncertainty rather than claiming surveyed road alignment. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="88e17ba"></a>

## 34. 88e17ba — feat(missions): add six-wave manual AA defence against Stuka dives

| Field | Evidence |
| --- | --- |
| Commit | [88e17ba](https://github.com/zelenski3398/codexproj1/commit/88e17baa97591a6000022d116e846a640bc4d000) (`88e17baa97591a6000022d116e846a640bc4d000`) |
| Date | 2026-10-14 06:58:58 UTC |
| Description | feat(missions): add six-wave manual AA defence against Stuka dives |
| Category | AA defence mission |
| Files | [scripts/airfield_interaction.gd](../../scripts/airfield_interaction.gd), [scripts/dive_attack_pilot.gd](../../scripts/dive_attack_pilot.gd), [scripts/dive_defence_definition.gd](../../scripts/dive_defence_definition.gd), [scripts/dive_defence_mission.gd](../../scripts/dive_defence_mission.gd), [scripts/enemy_encounters.gd](../../scripts/enemy_encounters.gd), [scripts/ground_pilot.gd](../../scripts/ground_pilot.gd), [scripts/main.gd](../../scripts/main.gd), [scripts/malta_mission.gd](../../scripts/malta_mission.gd); 28 changed paths including metadata |
| Change | Adds six Stuka attack waves, state-driven bombing/strafe passes, vulnerable ground operator and mission-specific bomb cover damage. Tracks actual losses and retains live hostile ordnance through aircraft destruction before allowing next waves or success. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="b135cdc"></a>

## 35. b135cdc — feat(roads): connect Malta base entrances to parking and AA positions

| Field | Evidence |
| --- | --- |
| Commit | [b135cdc](https://github.com/zelenski3398/codexproj1/commit/b135cdcb627bae94092c2781ea17503ce7e12b91) (`b135cdcb627bae94092c2781ea17503ce7e12b91`) |
| Date | 2026-10-14 07:44:38 UTC |
| Description | feat(roads): connect Malta base entrances to parking and AA positions |
| Category | Base access roads |
| Files | [scripts/malta_airfield.gd](../../scripts/malta_airfield.gd), [scripts/malta_base_access.gd](../../scripts/malta_base_access.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md), [assets/malta/materials/airfield.gdshader](../../assets/malta/materials/airfield.gdshader), [assets/malta/materials/landscape.gdshader](../../assets/malta/materials/landscape.gdshader), [assets/malta/materials/landscape.tres](../../assets/malta/materials/landscape.tres); 21 changed paths including metadata |
| Change | Adds generated base-entry/parking/AA connectors and focused terrain/apron access masks, metadata and truck-route checks. Routes avoid fixed buildings/spawns and preserve field geographic centres and mission logic. |
| Outcome | Feature / fix; implementation commit, no merge parent pair |

<a id="2157b72"></a>

## 36. 2157b72 — feat(aa): add four-gun heavy batteries and clip-fed Bofors defence

| Field | Evidence |
| --- | --- |
| Commit | [2157b72](https://github.com/zelenski3398/codexproj1/commit/2157b7227fe912762e000829a001c15294d9f097) (`2157b7227fe912762e000829a001c15294d9f097`) |
| Date | 2026-10-14 12:08:33 UTC |
| Description | feat(aa): add four-gun heavy batteries and clip-fed Bofors defence |
| Category | Layered AA |
| Files | [scripts/aa_weapon_definition.gd](../../scripts/aa_weapon_definition.gd), [scripts/airfield_aa_battery.gd](../../scripts/airfield_aa_battery.gd), [scripts/airfield_interaction.gd](../../scripts/airfield_interaction.gd), [scripts/british_aa_gun.gd](../../scripts/british_aa_gun.gd), [scripts/dive_defence_mission.gd](../../scripts/dive_defence_mission.gd), [scripts/malta_mission.gd](../../scripts/malta_mission.gd), [scripts/projectile_pool.gd](../../scripts/projectile_pool.gd), [scripts/web_support.gd](../../scripts/web_support.gd); 33 changed paths including metadata |
| Change | Adds AAWeaponDefinition resources, four heavy and two Bofors per field, separate gravity pools, timed heavy versus impact light shells, location-specific damage and five-second heavy reload. Briefly adds finite stocks/four-round clips, later removed. |
| Outcome | Feature / revision; implementation commit, no merge parent pair |

<a id="e26e5ed"></a>

## 37. e26e5ed — feat(aa): add relative mouse aiming and sight zoom with unlimited ammunition

| Field | Evidence |
| --- | --- |
| Commit | [e26e5ed](https://github.com/zelenski3398/codexproj1/commit/e26e5edca54b0551bf27372109a26e8adfede36b) (`e26e5edca54b0551bf27372109a26e8adfede36b`) |
| Date | 2026-10-15 06:09:10 UTC |
| Description | feat(aa): add relative mouse aiming and sight zoom with unlimited ammunition |
| Category | AA input / ammunition |
| Files | [scripts/aa_mouse_controls.gd](../../scripts/aa_mouse_controls.gd), [scripts/aa_weapon_definition.gd](../../scripts/aa_weapon_definition.gd), [scripts/airfield_interaction.gd](../../scripts/airfield_interaction.gd), [scripts/british_aa_gun.gd](../../scripts/british_aa_gun.gd), [scripts/malta_mission.gd](../../scripts/malta_mission.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md); 19 changed paths including metadata |
| Change | Adds scoped relative mouse controls, rate-limited smoothing, sight zoom, user sensitivity persistence and pointer-lock recapture; increases heavy/light traverse independently. Removes finite ammunition/clip state, preserving automatic reload and heavy single-press/Bofors hold behaviour. |
| Outcome | Feature / removal; implementation commit, no merge parent pair |

<a id="eb5db64"></a>

## 38. eb5db64 — feat(aa): add player-directed battery command and supplied defence audio

| Field | Evidence |
| --- | --- |
| Commit | [eb5db64](https://github.com/zelenski3398/codexproj1/commit/eb5db645b24ac61e32de36e7aed320083e244c78) (`eb5db645b24ac61e32de36e7aed320083e244c78`) |
| Date | 2026-10-15 08:25:08 UTC |
| Description | feat(aa): add player-directed battery command and supplied defence audio |
| Category | Battery command / defence audio |
| Files | [scripts/aa_command_station.gd](../../scripts/aa_command_station.gd), [scripts/aa_fire_control.gd](../../scripts/aa_fire_control.gd), [scripts/aa_mouse_controls.gd](../../scripts/aa_mouse_controls.gd), [scripts/airfield_aa_battery.gd](../../scripts/airfield_aa_battery.gd), [scripts/airfield_interaction.gd](../../scripts/airfield_interaction.gd), [scripts/british_aa_gun.gd](../../scripts/british_aa_gun.gd), [scripts/dive_defence_audio.gd](../../scripts/dive_defence_audio.gd), [scripts/dive_defence_mission.gd](../../scripts/dive_defence_mission.gd); 40 changed paths including metadata |
| Change | Adds one player-operated command post per four-heavy-gun field battery, gravity interception solver, imperfect target/area designations and staggered orders to physical barrels. Integrates supplied briefing, air-raid alarm and descent-gated Jericho sounds. |
| Outcome | Feature; implementation commit, no merge parent pair |

<a id="6c0fbc9"></a>

## 39. 6c0fbc9 — fix(audio): loop air-raid siren throughout defence mission

| Field | Evidence |
| --- | --- |
| Commit | [6c0fbc9](https://github.com/zelenski3398/codexproj1/commit/6c0fbc90fdea1f0f46b5cca111c49c70e89d8ad9) (`6c0fbc90fdea1f0f46b5cca111c49c70e89d8ad9`) |
| Date | 2026-10-15 11:13:32 UTC |
| Description | fix(audio): loop air-raid siren throughout defence mission |
| Category | Defence alarm |
| Files | [scripts/dive_defence_audio.gd](../../scripts/dive_defence_audio.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [docs/battery-command-and-defence-audio.md](../../docs/battery-command-and-defence-audio.md), [tests/defence_sound_checks.gd](../../tests/defence_sound_checks.gd), [tools/battery_command_web_smoke.cjs](../../tools/battery_command_web_smoke.cjs); 5 changed paths including metadata |
| Change | Starts one looped air-raid siren at defence mission audio startup, keeps it through waiting/travel/waves and stops on outcome/cancel. Removes the previous per-wave/approach gating logic. |
| Outcome | Fix / replacement; implementation commit, no merge parent pair |

<a id="bf96f9a"></a>

## 40. bf96f9a — feat(malta): add original fortified Valletta city to continuous world

| Field | Evidence |
| --- | --- |
| Commit | [bf96f9a](https://github.com/zelenski3398/codexproj1/commit/bf96f9a7e54330fcd1f74815be220e6dfc27132c) (`bf96f9a7e54330fcd1f74815be220e6dfc27132c`) |
| Date | 2026-10-15 12:07:12 UTC |
| Description | feat(malta): add original fortified Valletta city to continuous world |
| Category | Valletta scenery |
| Files | [scripts/malta_landscape_details.gd](../../scripts/malta_landscape_details.gd), [scripts/malta_world.gd](../../scripts/malta_world.gd), [scripts/valletta_city.gd](../../scripts/valletta_city.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md), [assets/malta/valletta/city.glb](../../assets/malta/valletta/city.glb), [assets/malta/valletta/city.glb.import](../../assets/malta/valletta/city.glb.import); 24 changed paths including metadata |
| Change | Adds original terrain-fitted Valletta buildings/fortifications/landmarks, chunked visual GLB and separate persistent coarse collision. Replaces earlier cheap landscape blockout and records approximate, not surveyed, reconstruction limits. |
| Outcome | Feature / replacement; implementation commit, no merge parent pair |

<a id="814e308"></a>

## 41. 814e308 — feat(malta): reconstruct georeferenced fortified Mdina hilltop city

| Field | Evidence |
| --- | --- |
| Commit | [814e308](https://github.com/zelenski3398/codexproj1/commit/814e30850bea4f3dbe098787d9a1898d95a434ba) (`814e30850bea4f3dbe098787d9a1898d95a434ba`) |
| Date | 2026-10-16 06:17:09 UTC |
| Description | feat(malta): reconstruct georeferenced fortified Mdina hilltop city |
| Category | Mdina / shared scenery |
| Files | [scripts/historic_city.gd](../../scripts/historic_city.gd), [scripts/malta_geography.gd](../../scripts/malta_geography.gd), [scripts/malta_landscape_details.gd](../../scripts/malta_landscape_details.gd), [scripts/malta_world.gd](../../scripts/malta_world.gd), [scripts/mdina_city.gd](../../scripts/mdina_city.gd), [scripts/valletta_city.gd](../../scripts/valletta_city.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml); 30 changed paths including metadata |
| Change | Adds georeferenced fortified Mdina, hilltop sample, gate/road openings and city assets/tests. Extracts HistoricCity loader reused by Valletta/Mdina and adds projected Mdina chart marker without changing terrain. |
| Outcome | Feature / refactor; implementation commit, no merge parent pair |

<a id="29dc713"></a>

## 42. 29dc713 — feat(cottonera): establish source-derived alignment and record missing geography

| Field | Evidence |
| --- | --- |
| Commit | [29dc713](https://github.com/zelenski3398/codexproj1/commit/29dc7139900e16ab377fe263526e771f44aae3cf) (`29dc7139900e16ab377fe263526e771f44aae3cf`) |
| Date | 2026-10-16 06:37:29 UTC |
| Description | feat(cottonera): establish source-derived alignment and record missing geography |
| Category | Cottonera alignment |
| Files | [assets/malta/cottonera/alignment.json](../../assets/malta/cottonera/alignment.json), [assets/malta/cottonera/features.geojson](../../assets/malta/cottonera/features.geojson), [assets/malta/cottonera/region.json](../../assets/malta/cottonera/region.json), [assets/malta/cottonera/source/README.md](../../assets/malta/cottonera/source/README.md), [assets/malta/cottonera/source/access_report.json](../../assets/malta/cottonera/source/access_report.json), [assets/malta/cottonera/source/geonamescache-LICENSE.txt](../../assets/malta/cottonera/source/geonamescache-LICENSE.txt), [assets/malta/cottonera/source/places.json](../../assets/malta/cottonera/source/places.json), [tools/cottonera/geography.py](../../tools/cottonera/geography.py); 9 changed paths including metadata |
| Change | Adds projected, cited GeoNames regional anchors and source-hash/alignment metadata. Records inaccessible historical/footprint sources and missing geography; anchors do not fabricate city boundaries. |
| Outcome | Preparation; implementation commit, no merge parent pair |

<a id="d3ca959"></a>

## 43. d3ca959 — feat(cottonera): prepare footprint-driven Fort St Angelo template

| Field | Evidence |
| --- | --- |
| Commit | [d3ca959](https://github.com/zelenski3398/codexproj1/commit/d3ca95977463bf2bcdd81235fd60055584af58d9) (`d3ca95977463bf2bcdd81235fd60055584af58d9`) |
| Date | 2026-10-16 06:38:18 UTC |
| Description | feat(cottonera): prepare footprint-driven Fort St Angelo template |
| Category | Cottonera fort asset |
| Files | [tools/cottonera/models.py](../../tools/cottonera/models.py); 1 changed paths including metadata |
| Change | Adds footprint-driven Fort St Angelo architectural template construction to offline models module, awaiting an actual sourced outline; does not populate the fort at an invented world footprint. |
| Outcome | Preparation; implementation commit, no merge parent pair |

<a id="dd9049a"></a>

## 44. dd9049a — feat(cottonera): prepare Senglea housing and lookout assets without invented streets

| Field | Evidence |
| --- | --- |
| Commit | [dd9049a](https://github.com/zelenski3398/codexproj1/commit/dd9049a18c1896bb40ede5cd81781131da00ac08) (`dd9049a18c1896bb40ede5cd81781131da00ac08`) |
| Date | 2026-10-16 06:39:05 UTC |
| Description | feat(cottonera): prepare Senglea housing and lookout assets without invented streets |
| Category | Cottonera Senglea assets |
| Files | [tools/cottonera/models.py](../../tools/cottonera/models.py); 1 changed paths including metadata |
| Change | Adds original row-house and Gardjola-style lookout template geometry. Leaves actual Senglea streets/buildings absent pending source data rather than inferring a city from the image alone. |
| Outcome | Preparation; implementation commit, no merge parent pair |

<a id="de2dd12"></a>

## 45. de2dd12 — feat(cottonera): prepare separate defensive-line walls bastions and gates

| Field | Evidence |
| --- | --- |
| Commit | [de2dd12](https://github.com/zelenski3398/codexproj1/commit/de2dd12ef323399919ae3ed63edddcd757a23755) (`de2dd12ef323399919ae3ed63edddcd757a23755`) |
| Date | 2026-10-16 06:39:29 UTC |
| Description | feat(cottonera): prepare separate defensive-line walls bastions and gates |
| Category | Cottonera defensive assets |
| Files | [tools/cottonera/models.py](../../tools/cottonera/models.py); 1 changed paths including metadata |
| Change | Adds distinct curtain-wall, battered bastion and gate-opening model constructors for separate defensive systems. This is reusable template geometry, not a placed mapped perimeter. |
| Outcome | Preparation; implementation commit, no merge parent pair |

<a id="170f758"></a>

## 46. 170f758 — feat(cottonera): prepare source-placeable wartime dockyard assets

| Field | Evidence |
| --- | --- |
| Commit | [170f758](https://github.com/zelenski3398/codexproj1/commit/170f758220295caefde9890695b1e22718531253) (`170f758220295caefde9890695b1e22718531253`) |
| Date | 2026-10-16 06:40:24 UTC |
| Description | feat(cottonera): prepare source-placeable wartime dockyard assets |
| Category | Cottonera dockyard assets |
| Files | [tools/cottonera/models.py](../../tools/cottonera/models.py); 1 changed paths including metadata |
| Change | Adds source-placeable warehouse, crane and dry-dock templates. No modern marina/yachts or invented historical dock positions are inserted into the live world. |
| Outcome | Preparation; implementation commit, no merge parent pair |

<a id="154a952"></a>

## 47. 154a952 — feat(cottonera): import sourced footprints roads and distinct defensive lines

| Field | Evidence |
| --- | --- |
| Commit | [154a952](https://github.com/zelenski3398/codexproj1/commit/154a95239344d0190d4755be4e2834e7140f8d4f) (`154a95239344d0190d4755be4e2834e7140f8d4f`) |
| Date | 2026-10-16 06:42:20 UTC |
| Description | feat(cottonera): import sourced footprints roads and distinct defensive lines |
| Category | Cottonera data import |
| Files | [tests/cottonera_import_checks.py](../../tests/cottonera_import_checks.py), [tools/import_cottonera.py](../../tools/import_cottonera.py); 2 changed paths including metadata |
| Change | Adds local GeoJSON/OSM XML/Overpass importer requiring provenance, licence, epoch and explicit city assignment. Preserves polygons/holes, rejects incomplete geometry and distinguishes named defensive lines and modern exclusions. |
| Outcome | Feature / preparation; implementation commit, no merge parent pair |

<a id="a4bf624"></a>

## 48. a4bf624 — feat(cottonera): prepare footprint-driven church and palace landmark assets

| Field | Evidence |
| --- | --- |
| Commit | [a4bf624](https://github.com/zelenski3398/codexproj1/commit/a4bf624afbf2a2ef6ad56580363ae174fc7a9ed8) (`a4bf624afbf2a2ef6ad56580363ae174fc7a9ed8`) |
| Date | 2026-10-16 06:43:15 UTC |
| Description | feat(cottonera): prepare footprint-driven church and palace landmark assets |
| Category | Cottonera landmarks |
| Files | [tools/cottonera/models.py](../../tools/cottonera/models.py); 1 changed paths including metadata |
| Change | Adds footprint-driven church/palace constructors with distinct selectable landmark templates; schema/model availability does not establish the historical footprint or 1942 facade at runtime. |
| Outcome | Preparation; implementation commit, no merge parent pair |

<a id="410ef4b"></a>

## 49. 410ef4b — feat(cottonera): integrate source-gated regions collision and review templates

| Field | Evidence |
| --- | --- |
| Commit | [410ef4b](https://github.com/zelenski3398/codexproj1/commit/410ef4bb777e7efea0fe953cc6541ea2036f0b24) (`410ef4bb777e7efea0fe953cc6541ea2036f0b24`) |
| Date | 2026-10-16 06:49:09 UTC |
| Description | feat(cottonera): integrate source-gated regions collision and review templates |
| Category | Cottonera region pipeline |
| Files | [scripts/cottonera_asset_review.gd](../../scripts/cottonera_asset_review.gd), [scripts/cottonera_region.gd](../../scripts/cottonera_region.gd), [scripts/malta_geography.gd](../../scripts/malta_geography.gd), [scripts/malta_landscape_details.gd](../../scripts/malta_landscape_details.gd), [scripts/malta_world.gd](../../scripts/malta_world.gd), [scripts/web_support.gd](../../scripts/web_support.gd), [assets/malta/cottonera/region.json](../../assets/malta/cottonera/region.json), [assets/malta/cottonera/templates/architecture.glb](../../assets/malta/cottonera/templates/architecture.glb); 22 changed paths including metadata |
| Change | Adds source-gated regional compiler, collision/near-mid-far assets, runtime CottoneraRegion, continuous-world hook and standalone unplaced gallery. Empty source remains awaiting_geodata with no fabricated structures; review scene is not a gameplay city. |
| Outcome | Feature / preparation; implementation commit, no merge parent pair |

<a id="588ac7b"></a>

## 50. 588ac7b — test(cottonera): validate safe fallback LODs native web and missing-data workflow

| Field | Evidence |
| --- | --- |
| Commit | [588ac7b](https://github.com/zelenski3398/codexproj1/commit/588ac7b1b37b72014b73fe679871e790e5c79145) (`588ac7b1b37b72014b73fe679871e790e5c79145`) |
| Date | 2026-10-16 06:59:46 UTC |
| Description | test(cottonera): validate safe fallback LODs native web and missing-data workflow |
| Category | Cottonera validation / robustness |
| Files | [scripts/cottonera_asset_review.gd](../../scripts/cottonera_asset_review.gd), [.github/workflows/web.yml](../../.github/workflows/web.yml), [README.md](../../README.md), [assets/malta/cottonera/source/access_report.json](../../assets/malta/cottonera/source/access_report.json), [assets/malta/cottonera/templates/architecture.glb](../../assets/malta/cottonera/templates/architecture.glb), [docs/cottonera-region.md](../../docs/cottonera-region.md), [docs/previews/cottonera-unplaced-templates.png](../../docs/previews/cottonera-unplaced-templates.png), [tests/cottonera_import_checks.py](../../tests/cottonera_import_checks.py); 13 changed paths including metadata |
| Change | Adds importer/compiler/native/browser regression coverage and missing-data documentation; rejects incomplete source assemblies, corrects template dome normals, improves LOD/collision checks and gallery framing. Confirms safe empty fallback, not a completed populated Cottonera. |
| Outcome | Fix / test / maintenance; implementation commit, no merge parent pair |

## Appendix — Documentation, testing and maintenance changes

There are no formatting-only commits in this inspected range. The following narrow maintenance/reporting changes are listed here **in addition to**, not instead of, their entries above:

| Commit | Classification and observable effect |
| --- | --- |
| [83e6073](https://github.com/zelenski3398/codexproj1/commit/83e60738746ed2a2b4c2dcd75316e8c62f9c8579) | Changes inferred locals to explicit StandardMaterial3D, MeshInstance3D, Vector3, int and bool types in wing_guns.gd and weapons checks; observable runtime firing logic is otherwise retained. |
| [c7b1f6c](https://github.com/zelenski3398/codexproj1/commit/c7b1f6cc7a9acc5d49b39472a31e411b00aa3534) | Updates web-hosting notes with recorded build/artifact success, initial Pages-disabled deployment and owner activation. No gameplay or workflow implementation changes occur in this diff. |
| [3f16951](https://github.com/zelenski3398/codexproj1/commit/3f1695169907679e4e43bea42e452c346993cc4d) | Adds root CNAME custom-domain configuration. Its hostname is not necessary to explain gameplay architecture; the next commit deletes this file. |
| [b093bc2](https://github.com/zelenski3398/codexproj1/commit/b093bc28793648fd28ebb7ef963513086ada5055) | Deletes the just-added CNAME. No root CNAME exists at the audited snapshot; custom-domain configuration is therefore a transient historical change. |
| [90c99ef](https://github.com/zelenski3398/codexproj1/commit/90c99ef06854b6220e8690bd68657f518a6d7d86) | Clears the old enemy-placeholder status when interception has no spawned enemy, so checkpoint navigation does not misleadingly show a waiting or destroyed Stuka. Adds observable telemetry/assertion coverage. |
| [7fe44a7](https://github.com/zelenski3398/codexproj1/commit/7fe44a78a74e81c67426c6852a2dc8211ceee7a9) | Waits until playing is false, subtitle hidden and radio channel released, accounting for the later finished callback. Documents the audio-thread/idle cleanup ordering; no speech or mission logic replacement. |
| [588ac7b](https://github.com/zelenski3398/codexproj1/commit/588ac7b1b37b72014b73fe679871e790e5c79145) | Adds importer/compiler/native/browser regression coverage and missing-data documentation; rejects incomplete source assemblies, corrects template dome normals, improves LOD/collision checks and gallery framing. Confirms safe empty fallback, not a completed populated Cottonera. |

`588ac7b` also contains compiler/importer robustness corrections and asset review changes; its `test(...)` subject does not make it documentation-only. Likewise the parser and HUD fixes affect runtime paths. The full manifest retains every touched file for deeper review.
