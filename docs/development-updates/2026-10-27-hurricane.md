# 27 October 2026 — flyable Hawker Hurricane Mk I

Source boundary: [`e0e7ae069445eac65fc8c1c5ee5d59eb996d7dd9`](https://github.com/zelenski3398/codexproj1/commit/e0e7ae069445eac65fc8c1c5ee5d59eb996d7dd9). Previous documented source: `9542c5944ae863b43fc48030edce09cec06e2e2f`. Intervening `f669525` published the Bofors command report. The original complete-history snapshot remains unchanged.

## Implementation

The existing player kinds were selected with repeated Spitfire/Gladiator branches. The new `AlliedAircraft` factory centralizes validation, names, construction and identity. `HawkerHurricane` subclasses the existing `FlightAircraft`; its reusable scene sets exported force/handling parameters, while its class supplies only model/profile, mass/inertia, suspension/seat and gun defaults. The existing flight controller, projectiles, damage implementation, AI, mission rules, terrain, geography and hangars were not rewritten.

The entirely original `HurricaneModel` shares the visual interface and small roundel/seat helpers, with its own fuselage sections, broad tapered rounded-tip wings, aft stringers, framed cockpit, central radiator, exhausts, propeller, gear and separate animated control surfaces. Eight flush wing ports drive the existing eight-gun weapon. This is a Merlin III/eight-.303 Mk I configuration, not the supplied LF363 Mk IIc's cannon configuration. The finish is explicitly representative; no authenticated Malta serial, pilot or squadron scheme is claimed.

Free-roam and Survival Malta rosters add one Hurricane per base without editing geographic data. Existing hangar stands support nine total aircraft. The selected kind moves to the first home stand, with the pilot beside that exact aircraft and engine stopped. Boarding, exit and recovery preserve the same fleet; full retry restores it once. Authored mission formations and parked fleets retain their prior definitions. Existing countryside selections keep their original roster; selecting Hurricane for the retained test map explicitly adds it there.

[Current guide, previews, architecture, settings and measured performance](../hawker-hurricane.md).

## Created assets and changed integration files

| Files | Purpose |
|---|---|
| [aircraft/hurricane_mk_i.tscn](../../aircraft/hurricane_mk_i.tscn) | Reusable Allied aircraft definition and exported flight tuning |
| [hawker_hurricane.gd](../../scripts/hawker_hurricane.gd) | Small shared-controller subclass; mass/inertia, gear anchors, seat and guns |
| [hurricane_model.gd](../../scripts/hurricane_model.gd) | Original procedural 3D meshes, paint, surfaces, eight ports and animation |
| [hurricane_mk_i.tres](../../damage_profiles/hurricane_mk_i.tres) | Fitted component hitboxes and existing configurable failure rules |
| [allied_aircraft.gd](../../scripts/allied_aircraft.gd) | Shared factory, names, kind identity and free-roam roster extension |
| [aircraft_selector.gd](../../scripts/aircraft_selector.gd), [malta_departure_menu.gd](../../scripts/malta_departure_menu.gd) | Third aircraft, description, preview, key 3/arrow selection and departure options |
| [main.gd](../../scripts/main.gd), [malta_mission.gd](../../scripts/malta_mission.gd) | Factory-based launch, fleet spawning and retained Hurricane identity |
| [web_support.gd](../../scripts/web_support.gd) | Read-only smoke telemetry for third menu button and fleet kinds/ports |
| [hurricane_checks.gd](../../tests/hurricane_checks.gd), [hurricane_flight_checks.gd](../../tests/hurricane_flight_checks.gd), [hurricane_performance_checks.gd](../../tests/hurricane_performance_checks.gd), [hurricane_capture.gd](../../tests/hurricane_capture.gd) | Integration, normal forces/combat/crashes, comparison and native previews; matching Godot UID files |
| [hurricane_web_smoke.cjs](../../tools/hurricane_web_smoke.cjs) | Production-browser menu/entry/engine/weapon/Help checks |
| [web.yml](../../.github/workflows/web.yml) | Runs the three new assertion suites during publishing |

Existing aircraft-choice, Malta, harbour-hangar and St Elmo tests now expect the intentional third menu choice/nine-plane free-roam roster. Malta acceptance/journey fixtures select the intended destination Gladiator by type and airfield rather than a now-obsolete numeric fleet index. Existing general web, hangar, audio, recovery and terrain smoke helpers likewise expect nine free-roam aircraft. Only the new Hurricane browser smoke was run for this update; those other helpers were kept consistent but not all rerun.

## Historical evidence and approximations

The user-specified Malta Aviation Museum article and attempted official RAF/Museum endpoints returned network tunnel **403 Forbidden**. No content from them was read, and independent museum/RAF confirmation is **not claimed**. The Mk I identity/configuration and Malta role follow the supplied brief. Commonly cited span 12.19 m, length 9.84 m, area 23.92 m² and loaded mass 2,994 kg are provisional implementation baselines pending source verification. The supplied IIc photograph was used only for overall visual character.

Thrust, drag, torques, stall threshold and guidance are deliberate shared-game approximations. Guns keep existing player velocity, damage, convergence and conservative rate, not Mk IIc cannon power. The same-altitude controller measured Hurricane speed/acceleration/climb/coast performance between the Sea Gladiator and Spitfire; the guide includes exact conditions and values. No historical top-speed/climb calibration is asserted.

## Validation actually performed

Godot 4.6.3, fixed physics step 120 Hz:

| Suite | Passed |
|---|---:|
| Hurricane integration / fleet / recovery | 28 |
| Hurricane taxi, takeoff, combat, damage, landing, land/air/water impact | 15 |
| Three-fighter performance comparison | 4 |
| Existing aircraft choice | 32 |
| Malta | 39 |
| Harbour hangar / sea loss | 24 |
| Countryside departure | 12 |
| Minimal HUD | 61 |
| Pilot recovery | 73 |
| St Elmo | 43 |
| **Total** | **331** |

- Native integration checks normal menu Fly, three healthy grounded Hurricanes, three-wheel support at every base, visible mesh bounds inside hangar side/rear/door limits, eight ports, separate surfaces, normal I engine input, contextual text, health/pilot separation and actual support-truck request/entry/return. Fleet identity/count survives recovery and retry; harbour roster remains unchanged.
- Force-based test-airfield taxi/takeoff and a real suspension/braking landing pass. Eight muzzle projectiles hit a real enemy via existing collision. Engine damage reduces power; below-half health emits smoke/fire; forced tank hazards leak and burn. High-speed aircraft contact, severe land impact and a real water collider invoke existing destruction/breakup/splash/sinking.
- The tests use explicit initial-position fixtures for landing, weapons, impact and the open-ground recovery loss. They do not simulate a complete human takeoff-to-return mission. A reset-order fixture was corrected so the session's normal reset callback could not overwrite the positioned collision opponent. An obsolete numeric replacement index was corrected after the deliberate roster extension. Native rendering caught reversed fuselage face winding and disconnected gear-leg visuals; these were corrected before final captures.
- **9/9 production browser checks** in Chromium ANGLE/SwiftShader: real Hurricane-button selection, normal Malta launch, nine aircraft and all Hurricane port resources, boarding prompt removal, manual engine start, physical eight-gun salvo, F1 blocking, normal exit with unchanged entity IDs/world, and zero JavaScript/shader/resource/engine errors. Browser engine and firing checks stay parked in the hangar; no airborne browser flight is claimed.
- Final web export succeeds. Compatibility native front/side/planform/hangar images and a browser-menu image were rendered and inspected. Native software-renderer capture shutdown reports existing texture allocations; headless checks/browser runtime are clean.
- `git diff --check`, local documentation targets, JSON and one Mermaid diagram were validated. Geographic terrain, airfield coordinates and source world data were left unchanged.

[Machine-readable results](validation/hurricane-2026-10-27.json).

## Remaining limitations

Museum/RAF source verification, an authenticated Malta scheme, a single uninterrupted human Hurricane flight out of a Malta hangar through combat and landing, dedicated mobile/low-end FPS measurements, all cockpit sightlines and live Pages deployment verification remain outstanding. The 3D model is an original stylized reconstruction, not an exact historic-airframe replica. The asset definition supports Allied automated command input but no new Hurricane AI formation is spawned by this change.
