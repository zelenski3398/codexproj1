# Italian aircraft and the Ta’ Qali interception

Open **Missions → Defend Valletta — Ta’ Qali Interception** in the first game
menu. Choose a Spitfire or Sea Gladiator and depart. This mission uses the
existing continuous Malta environment; it does not change terrain, airfield
coordinates, parked aircraft or boarding/landing mechanics.

## Playing

1. At Ta’ Qali, press **E** to board the aircraft beside you.
2. Press **I** to start its engine. Use **W/S** for throttle and **A/D** for
   rudder; taxi from the parking apron onto the runway before full power.
3. Take off using the existing arrows. Fly toward the **gold checkpoint**,
   about 3 km east of the airfield at 450 m above sea level. **M** shows it on
   the navigation chart. Its generous 500 m radius permits a climbing approach.
4. Entering the airborne checkpoint spawns one SM.79 and one C.200, and starts
   **05:00**. Startup, taxi and takeoff time do not consume that countdown.
5. Destroy both before the deadline. Follow their labelled directional markers.
   Use **Ctrl** on desktop / **F** in browsers for the existing wing guns.
   Stopping the bomber first leaves the escort objective and original timer.
6. Results offer **Retry Mission** and **Return to Missions**. A result does
   not pause or reset your aircraft. **R** remains an explicit full restart.

This is a small fictional interception, not a historical mass bombing raid.
The Sea Gladiator can fly the mission but its lower speed makes interception
more challenging. The current project contains one supported Malta environment;
all three existing Malta departure sites remain available in the other modes.

## Aircraft definitions and shared systems

`aircraft_definitions/cr42.tres`, `c200.tres` and `sm79.tres` are editor-editable
resources. They configure the model script, damage profile, HP, mass/inertia,
wing area/span, contact dimensions, drag, thrust, stall/cruise speed, control
torques, bank limit, gear type and weapon ballistics. Their fitted eight-part
sensor resources live in `damage_profiles/`.

- **CR.42 Falco:** radial biplane, shorter lower wings, interplane struts,
  open cockpit, fixed spatted wheels; 55 m/s cruise and 62° tactical bank.
- **C.200 Saetta:** radial monoplane, open cockpit, retractable main wheels;
  75 m/s cruise and 50° tactical bank. Both fighters have two forward guns.
- **SM.79 Sparviero:** three radial engines/propellers, long fuselage, raised
  crew/cockpit hump, broad low wing and retractable main wheels. Its 65 m/s
  mission approach has dorsal and ventral defensive mounts. The route takes
  precedence over chasing the player; its forward hump gun stays disabled.

`ItalianAircraftModel` contains visuals only. `ItalianEnemy` extends the
existing `EnemyAircraft` lifecycle through small configuration/factory hooks.
`FlightAircraft` and `EnemyPilot`'s aerodynamic/controller code are unchanged.
All types retain the shared health, eight damage components, hit sparks,
world-space smoke/fire, teams, projectile pooling, swept collision and one-shot
falling-wreck destruction. Smoke retains the existing strict **below 50 HP**
threshold, and fuel fires remain the existing independent component hazard.

`RearGunner` now accepts a mechanical mount instead of requiring a Stuka
visual class. Default Stuka parameters are unchanged. Bomber mounts use the
existing delayed observation, imperfect human tracking, limited traverse,
burst corrections, dispersion and own-airframe/terrain obstruction checks.
They cannot damage a target by bypassing projectiles.

The spawning factory accepts `stuka`, `cr42`, `c200` and `sm79`. The encounter
director's `enemy_types` roster can be configured to cycle those types; its
**default remains `["stuka"]`**. Encounter and Survival counts and normal/ace
Stuka accuracy are preserved. For an isolated diagnostic spawn in code:

```gdscript
var foe := create_encounter_enemy(Vector3(0, 800, -2500), false, "cr42")
encounters.track_enemy(foe)
encounter_tracking_changed()
```

Use the director's safe-position planner in gameplay rather than arbitrary
positions. **F3** still displays component hitboxes, HP and flight penalties for
the player and focused enemy. In the mission the bomber is initially focused;
after its destruction the surviving escort becomes the focused enemy.

## Mission configuration and timing

Edit `mission_definitions/valletta.tres` with `InterceptionDefinition`:

| Setting | Default / purpose |
| --- | --- |
| `checkpoint`, `checkpoint_radius` | East of Ta’ Qali, 450 m MSL; 500 m capture radius |
| `minimum_checkpoint_agl` | 80 m; ground movement cannot activate it |
| `target_area` | Existing Valletta geographic landmark, ~42 m ground elevation |
| `bombing_point` | 700 m MSL release waypoint ~753 m up-course of the target |
| `approach_direction`, `approach_speed` | Southwest approach, 65 m/s |
| `deadline_seconds` | 300 seconds of simulation time; pausing pauses the timer |
| `arrival_radius` | 70 m; permits arrival approximately half a second before deadline |
| `escort_type` | `c200`; `cr42` is an available future variation |
| `escort_separation`, `spawn_clearance` | 230 m lateral separation; at least 300 m terrain clearance |
| `bomb_count`, `bomb_interval` | Eight bombs, separated by 0.7 seconds |

The spawn is a little over 19.5 km up-course of the release waypoint. Route
pacing estimates remaining distance/time and adjusts **ordinary throttle**;
normal pitch, bank, rudder, terrain avoidance and component-damage trim perform
all aircraft movement. Lost engines or lift can prevent timely arrival; pacing
cannot teleport, repair or impose velocity. The default uninterrupted approach
has been measured at about **299.47 seconds**. The release waypoint allows for
bombs inheriting aircraft velocity and falling under gravity, so the first
impact lands near the actual Valletta target rather than hundreds of metres
beyond it. Changing altitude/speed/route may require retuning that release lead.

After the level bombing sequence the bomber turns into a physical nearby orbit.
The escort initially follows formation, uses the existing pursuit/lead/fire
controller for threats, and returns if beyond its mission leash. If the bomber
is destroyed, it defends the last formation area instead of following an
imaginary bomber indefinitely. Threat distance, leash and formation speed are
configurable in `EscortPilot`; approach speed bounds/trim are in `BomberPilot`.

`VallettaInterception` owns checkpoint, countdown, objectives, bombs and results.
The existing encounter director tracks these external enemies and wrecks but
does not offer automatic/confirmed encounter replacements in this mission.
Destruction signals settle together before a deferred result resolution.
Pre-deadline simultaneous kills yield one success; kills **at** the deadline
cannot turn failure into a late success. Player destruction fails immediately.
A live bomber arriving starts its physical bomb sequence and bombing failure;
a timed-out run with only the escort alive says **Interception incomplete**.
A live bomber that has not reached the release point at timeout reports time
expiry rather than falsely claiming a bombing. Retry cancels old deferred
resolution before removing the mission and clearing its aircraft/effects.

## Validation and approximations

Run the standard Godot import before tests, then:

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script res://tests/italian_aircraft_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/interception_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/interception_combat_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/interception_departure_checks.gd
bash tools/build_web.sh
node tools/interception_web_smoke.cjs
```

The airframe checks fly all three types for 60 simulated seconds and test
actual swept rounds in both directions, fitted engine sensors, power loss,
50/49 HP effects and latched destruction. The mission checks run the actual
five-minute force-driven route, falling bombs/impacts and post-run turn, plus
checkpoint gating, both destruction orders, simultaneous/exact-deadline events,
player loss, clean retry and invalidation of old callbacks. Their isolated
checkpoint/outcome fixtures are explicit; they do not pretend to be manual
flights or dogfight kills. Separate departure checks use the existing test
pilot's ordinary controls for engine start, taxi, takeoff and checkpoint entry
with **no pose/velocity fixtures**. Combat checks use moving-aircraft fixtures
with production C.200 and human defensive gunner settings and record real hits.

Graphical captures inspect the menu, ground start and all three placeholders
under native Compatibility/OpenGL. Browser smoke checks run the real exported
WebAssembly/WebGL game through normal menu, boarding, engine, throttle, map,
health-debug, retry and return controls. They do not mutate gameplay through
JavaScript. Existing flight, keyboard, weapons, aircraft-choice, component,
Stuka AI/encounter/gunner, Survival, Malta terrain and audio checks also run.
Validation passed **94 new native checks** plus **744 existing native checks**
(including Survival). Release browser validation passed **74 checks**: 15 mission UI/lifecycle,
31 general gameplay, 10 Survival and 18 real WebAudio checks. The publishing
workflow includes all four new native suites.

No bomber reference image accompanied the text upload. This implementation is
explicitly an **SM.79** placeholder, not a claimed reproduction of an unseen
picture. Geometry, Italian insignia and performance are stylised approximations,
not museum-quality assets or validated historical flight envelopes. The bomber's
three engine sensors currently share the framework's single engine-integrity
component and overall thrust penalty; independent engine shutdowns, waist guns
and authentic Italian aircraft audio are not modelled. Existing supplied
Spitfire sound effects are reused. Bombing/impacts are cosmetic mission effects;
they do not invent unavoidable player damage or a city destruction simulation.

A complete manually flown interception victory on Windows or the deployed public
Pages site remains **unverified**. Automated native flight/combat tests and local
release browser UI checks cover the implementation; the cloud proxy prevents
opening the live Pages domain for visual testing.
