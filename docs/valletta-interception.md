# Italian aircraft and the Ta’ Qali interception

**6 November 2026 timing update:** both the countdown and physical bomber approach now use three minutes. The nearby checkpoints move west to provide a normal-speed straight run to Valletta. No bombs begin before 180 seconds. [Changes and measured checks](development-updates/2026-11-06-valletta-three-minutes.md).

**24 October audio update:** the supplied air-raid siren loops from departure through the interception and fades out on the mission result. It uses the existing Aircraft volume control and radio ducking. Retry restarts one alarm; returning to the menu stops it. AA defence keeps its existing positional siren without a duplicate.

**20 October update:** available player aircraft now depart from hangar stands. Pilot health is independent from hull HP; a surviving pilot can exit a wreck and use **V → E truck entry** recovery without resetting this mission. Aircraft loss alone no longer fails the attempt. [Current survival/recovery rules](pilot-survival-and-recovery.md).

Open **Missions → Defend Valletta — Ta’ Qali Interception** in the first game
menu. Choose a Spitfire or Sea Gladiator and depart. This mission uses the
existing continuous Malta environment; it does not change terrain, airfield
coordinates, parked aircraft or boarding/landing mechanics.

## Playing

1. At Ta’ Qali, press **E** to board the aircraft beside you.
2. Press **I** to start its engine. Use **W/S** for throttle and **A/D** for
   rudder; taxi from the parking apron onto the runway before full power.
3. Take off using the existing arrows. Follow **two nearby gold navigation checkpoints**
   toward the western interception area after takeoff. Only the
   current checkpoint is shown, numbered **1/2** then **2/2**, with its distance
   and altitude. **M** shows the same current point on the navigation chart.
   Their generous **350 m radii** permit ordinary climbing/turning approaches.
4. Passing checkpoint **2/2** spawns one SM.79 and one C.200 approximately
   **1,200 m away, 30° right of your aircraft’s forward heading (one o’clock)**,
   displays and radios **Italian formation detected, one o’clock — intercept!**,
   and starts **03:00**. All startup, taxi, takeoff and
   checkpoint-navigation time is excluded from the countdown.
5. Destroy both before the deadline. Follow their labelled directional markers.
   Use **Ctrl** on desktop / **F** in browsers for the existing wing guns.
   Stopping the bomber first leaves the escort objective and original timer.
   Even when both enemies are lost, keep flying until the timer expires.
   Fatal player crashes/pilot death fail immediately; enemy crashes count as losses.
   A bombing run already begun cannot be undone by a late shootdown.
6. On success, land at a friendly airfield before the existing completion presentation. Results offer **Retry Mission** and **Return to Missions**. A result does
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
  crew/cockpit hump, broad low wing and retractable main wheels. Its level
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

| Parameter | Default / meaning |
| --- | --- |
| `checkpoint_positions` | `(400,330,3400)` and `(-600,430,2500)` in the existing metre-based world |
| `checkpoint_radius`, `checkpoint_vertical_tolerance` | 350 m spherical radius; within 100 m of the checkpoint's MSL altitude |
| `minimum_checkpoint_agl` | 80 m; runway/taxi cannot activate a checkpoint |
| `formation_spawn_distance`, `formation_bearing_degrees` | 1,200 m in 3D, 30° clockwise from the player's horizontal nose heading |
| `formation_height_offset`, `maximum_formation_height_difference` | Prefer 60 m above the player; never more than 150 m difference |
| `spawn_clearance`, `escort_separation` | At least 300 m terrain clearance; 230 m lateral separation plus stagger/height |
| `deadline_seconds` | 180 seconds of simulation time; pause suspends the countdown |
| `approach_seconds` | 180 seconds; bombing is gated until this interval has elapsed |
| `target_area` | Unchanged Valletta geographic target `(10131.404,42.149,3472.677)` |
| `bombing_point.y`, `automatic_release_lead` | 500 m MSL bombing altitude; derive an up-course release point for each actual spawn |
| `arrival_radius` | 70 m arrival corridor; physical bombing cannot start before 180 s |
| `commander_voice`, `commander_volume_db`, `radio_duck_db` | Existing supplied recording, 0 dB gain, temporary -4 dB engine/gun attenuation |
| `detection_notice_seconds` | Eight seconds of initial warning, followed by normal objectives |
| `escort_type` | `c200`; `cr42` remains a supported variation |
| `bomb_count`, `bomb_interval` | Eight falling bombs, separated by 0.7 s |

The two checkpoint centres lie roughly 1.1 km and 2.4 km from Ta’ Qali's centre, at 330 m and 430 m MSL. They guide the player west/northwest after takeoff. Both are above measured terrain; only the current checkpoint appears. No formation or countdown exists before checkpoint 2.

At activation the formation remains at one o'clock, with vertical separation included in the exact 1,200 m distance. Terrain rays and collision spheres check both aircraft, their mutual separation and clearance from the player. The bomber immediately faces its Valletta release point and uses the original straight-route physical controller. Player pose, velocity, health, fuel, engine/throttle, components and active bullets are preserved.

**Player-to-enemy distance is separate from the bomber's route.** An automated, normal-control Spitfire departure measured **1,200.0 m** separation and a **10,454.73 m** bomber route. Contact occurred **77.45 seconds after sustained liftoff**, after **4,746.72 m** flown; the bomber reached its release corridor after **179.39 seconds**. The separate ordered-checkpoint fixture produced a **10,727.29 m** route, **179.41-second** arrival and first physical bomb release at **180.00 seconds**; the first bomb landed **37.88 m** from the Valletta target. These are automated physics flights, not a human playthrough. Startup/taxi remain untimed.

The release lead is calculated from actual spawn-to-Valletta distance, bombing
height, gravity and the 180-second approach. If `T` is ballistic fall time,
`D` target distance and `r` arrival radius, initial speed is
`(D - r/2) / (180 + T)`, and the release point lies `speed*T` before Valletta.
This keeps the first bomb near the target after falling, instead of keeping
an obsolete release point on the opposite side of Valletta. Set
`automatic_release_lead=false` to use a manually configured release point.

The normal bomber controller paces route distance/time using ordinary throttle,
pitch, bank and rudder within its existing **48–80 m/s** range. It cannot repair,
teleport or impose velocity. Lost engines/lift can prevent arrival. The default
interception is at normal speed; the timer has not been shortened while keeping
the old distant enemy route. Bombs fall for roughly another ten seconds after
release; reported approach timing is to the release waypoint, not impact time.

The mission records enemy destruction events, including fatal terrain crashes,
and removes those aircraft from active tracking. It **waits until timer expiry**
to display success/failure even after both enemies are lost or bombing begins.
An already-started bombing run takes precedence over late enemy losses. Both
losses must be before the deadline for success. Player crash/destruction fails
immediately in navigation or combat; it never waits for the timer.

Enemy ground impacts retain the existing single destruction burst and delayed
wreck removal. Player crashes use the same Compatibility-friendly burst, once;
a player destroyed in flight falls normally and bursts only on ground contact.
Duplicate contacts cannot repeat explosions or results. Retry cancels deferred
callbacks, stops radio playback/ducking, and clears checkpoints, enemies, wrecks,
bombs, crash effects and the timer before starting a fresh ground departure.
Existing encounter/Survival modes and shared aircraft controllers remain intact.

## Validation

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script res://tests/interception_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/interception_departure_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/interception_departure_checks.gd -- sea_gladiator
godot --headless --path . --fixed-fps 120 --script res://tests/interception_combat_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/mission_radio_checks.gd
bash tools/build_web.sh
node tools/interception_web_smoke.cjs
```

Mission tests cover ordered/out-of-order checkpoint captures, stopped timer,
one-shot formation/radio, preserved player state, real bomber flight and falling
bombs, early and simultaneous enemy losses waiting for expiry, player loss,
actual enemy/player terrain crashes with one-shot effects, and clean retry.
Explicit pose fixtures isolate outcomes/crashes; the separate departure tests
start parked and taxi, take off and follow both checkpoints through **ordinary
controls**, with no pose/velocity resets. Enemy combat is disabled in those
runs only to isolate route timing. Dedicated combat tests use real swept rounds
and production escort/defensive gunner controls.

Browser smoke tests run the actual exported game through menu, boarding, engine
start, throttle, map, failure, retry and return controls. They observe state only.
Earlier native graphical captures show the former 01:30 revision, nearby enemy markers and the existing radio subtitle; they were not regenerated for this timing update. A complete manually flown Windows/browser interception
victory and live-site visual/listening checks remain **unverified**.

The Italian models and flight envelopes remain stylised prototypes, not validated
historical assets. Their shared engine/damage implementation and existing supplied
engine/gun audio are unchanged. Bombs and explosions remain cosmetic effects;
this change does not add unavoidable player damage or city destruction logic.

The original 90-second revision's native/browser checks remain recorded in its historical reports. For the current three-minute route, see the [6 November report](development-updates/2026-11-06-valletta-three-minutes.md). That timing-only run could not export because matching web templates were absent. The subsequent [publishing repair](development-updates/2026-11-06-publishing-hud-checks.md) installed verified templates and passed export plus shared-HUD browser checks; it did not add a full browser interception flight or verify live deployment.
