# Italian aircraft and the Ta’ Qali interception

Open **Missions → Defend Valletta — Ta’ Qali Interception** in the first game
menu. Choose a Spitfire or Sea Gladiator and depart. This mission uses the
existing continuous Malta environment; it does not change terrain, airfield
coordinates, parked aircraft or boarding/landing mechanics.

## Playing

1. At Ta’ Qali, press **E** to board the aircraft beside you.
2. Press **I** to start its engine. Use **W/S** for throttle and **A/D** for
   rudder; taxi from the parking apron onto the runway before full power.
3. Take off using the existing arrows. Follow **five gold navigation checkpoints**
   from Ta’ Qali toward the northeast offshore interception area. Only the
   current checkpoint is shown, numbered **1/5** through **5/5**, with its distance
   and altitude. **M** shows the same current point on the navigation chart.
   Their generous **650 m radii** permit ordinary climbing/turning approaches.
4. Passing checkpoint **5/5** spawns one SM.79 and one C.200 approximately
   **2,500 m away, 30° right of your aircraft’s forward heading (one o’clock)**,
   displays and radios **Italian formation detected, one o’clock — intercept!**,
   and starts **05:00**. All startup, taxi, takeoff and
   checkpoint-navigation time is excluded from the countdown.
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
| `checkpoint_positions`, `checkpoint_radius` | Five ordered world positions in `valletta.tres`; 650 m capture radius |
| `formation_spawn_distance` | 2,500 m measured in 3D world coordinates |
| `formation_bearing_degrees` | 30° right of the player's horizontal forward heading |
| `commander_voice`, `commander_volume_db`, `radio_duck_db` | Supplied commander clip, 0 dB radio gain and -4 dB temporary engine/gun attenuation |
| `detection_notice_seconds` | Eight seconds of formation-detected guidance, followed by normal objectives |
| `minimum_checkpoint_agl` | 80 m; ground movement cannot activate it |
| `target_area` | Existing Valletta geographic landmark, ~42 m ground elevation |
| `bombing_point` | 700 m MSL release waypoint ~753 m up-course of the target |
| Approach heading/speed | Derived from actual spawn → release waypoint and the 300-second duration |
| `deadline_seconds` | 300 seconds of simulation time; pausing pauses the timer |
| `arrival_radius` | 70 m; permits arrival approximately half a second before deadline |
| `escort_type` | `c200`; `cr42` is an available future variation |
| `escort_separation`, `spawn_clearance` | 230 m lateral separation; at least 300 m terrain clearance |
| `bomb_count`, `bomb_interval` | Eight bombs, separated by 0.7 seconds |

The configurable navigation route starts near Ta’ Qali, crosses northeast Malta,
and finishes offshore at **(24700, 700, -8200)**. It is about **26.5 km** of untimed
navigation. The player-to-bomber separation and bomber-to-Valletta route length
are deliberately separate: a normal continuous departure measured **2,500.0 m**
at activation and a **19,365.44 m** bomber route, followed by an actual
**299.458-second** uninterrupted bomber journey. Positioning the final waypoint
near Ta’ Qali instead would leave too little direct bomber travel for a realistic
five-minute approach. The encounter is now immediately practical once the timer
starts, rather than beginning roughly twenty kilometres from the player.

The formation uses the player's horizontal nose heading and offsets its bearing
30° to the right, matching the commander's one-o'clock call. Velocity is only a
fallback if the aircraft is pointed vertically. Vertical separation is
included when calculating the exact 2,500 m spawn distance. The bomber's initial
orientation and velocity face the existing Valletta release waypoint; it does not
turn instantly after spawning. The escort keeps its existing safe offset. Actual
terrain/body collision probes validate both spawn positions before insertion.

Initial cruise speed is calculated from the actual remaining route and deadline.
The existing bomber controller paces remaining distance/time through **ordinary
throttle**; normal pitch, bank, rudder, terrain avoidance and component-damage
trim perform all movement. Lost engines or lift can prevent timely arrival;
pacing cannot teleport, repair or impose velocity. Checkpoint configuration must
leave a bomber journey within its existing 48–80 m/s pacing envelope. The default
final area tolerates capture at different sides of the 650 m checkpoint sphere.

The release waypoint allows for bombs inheriting aircraft velocity and falling
under gravity. Changing spawn heading or cruise speed changes the ballistic
landing offset slightly; the standard approach still lands in the Valletta target
area. Changing route/altitude substantially may require retuning release lead.

After the level bombing sequence the bomber turns into a physical nearby orbit.
The escort initially follows formation, uses the existing pursuit/lead/fire
controller for threats, and returns if beyond its mission leash. If the bomber
is destroyed, it defends the last formation area instead of following an
imaginary bomber indefinitely. Threat distance, leash and formation speed are
configurable in `EscortPilot`; approach speed bounds/trim are in `BomberPilot`.

`VallettaInterception` owns ordered checkpoint progress, countdown, objectives,
bombs and results. Deferred checkpoint callbacks carry their expected index, so
old entries cannot advance a later point. The final activation is latched once.
Only enemy references/markers change; player transform, velocity, angular motion,
HP, engine/throttle, fuel, component integrity and weapon state remain intact.
The current prototype has unlimited ammunition; fired-round counters and active
projectiles are preserved. Retry resets progress to **1/5** and clears old enemies,
effects, timer and pending progression/resolution callbacks.
`MissionRadio` subscribes to the same one-shot formation activation signal. It
plays the supplied recording, displays its subtitle, and temporarily ducks
engine/gun buses. Retry creates a fresh trigger; cancellation/exit stop playback
and restore the user's mix. See [radio processing and lifecycle checks](audio.md#commander-radio).
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
ordered and out-of-order checkpoint entries, duplicate protection, measured
terrain clearance, exact before/after activation state, 2,500 m spawn geometry, both destruction orders, simultaneous/exact-deadline events,
player loss, clean retry and invalidation of old callbacks. Their isolated
checkpoint/outcome fixtures are explicit; they do not pretend to be manual
flights or dogfight kills. Separate departure checks use the existing test
pilot's ordinary controls for engine start, taxi, takeoff and **all five navigation
checkpoints**, followed by the uninterrupted bomber journey, with **no pose/velocity
fixtures**. Enemy combat is disabled only for that timing measurement so the
player continues flying offshore and the bomber approach is undisturbed. Combat checks use moving-aircraft fixtures
with production C.200 and human defensive gunner settings and record real hits.

Graphical captures inspect the menu, ground start and all three placeholders
under native Compatibility/OpenGL. Browser smoke checks run the real exported
WebAssembly/WebGL game through normal menu, boarding, engine, throttle, map,
health-debug, retry and return controls. They do not mutate gameplay through
JavaScript. Existing flight, keyboard, weapons, aircraft-choice, component,
Stuka AI/encounter/gunner, Survival, Malta terrain and audio checks also run.
The original Italian-aircraft milestone passed 838 native and 74 browser checks.
Checkpoint-route validation is recorded below; the publishing workflow continues
to include mission, departure, combat, aircraft, Survival, Malta and input checks.

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


### Checkpoint-route validation

The updated mission passed **70 mission checks**, **26 continuous departure and
bomber-journey checks**, and **7 combat checks**. An additional **208 checks**
cover Survival, Malta, terrain, keyboard and weapons. Release export and its
**16 browser UI/lifecycle checks** verify the new 1/5 guidance, navigation map,
manual engine/boarding flow and retry resetting checkpoint progress.

Measured in the normal taxi/takeoff/navigation run: **2,500.0 m** player-to-bomber
separation, **19,365.44 m** bomber-to-release route, and **299.458 seconds** of
uninterrupted bomber travel. The player continued flying under normal controls
through this measurement. Full manual browser combat remains unverified.

### Commander-call validation

The supplied commander recording plays at final activation, with measured
**30° right** bearing and **2,500 m** separation. Native radio checks passed
**22/22** and the isolated Chromium radio export passed **15/15**, including
actual decoded audio, exact subtitle text, one-shot/overlap guards, restoration
of user volumes, retry and exit. The same normal-control departure measured
a **19,365.44 m** bomber route and **299.458-second** arrival after the bearing
change. Existing mission/departure/combat checks still passed **103/103**;
the actual exported mission UI passed **16/16**. Native Compatibility rendering
also displayed the warning and subtitle together during real playback.
