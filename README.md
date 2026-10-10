# First Sortie

A single-player 3D **Godot 4 / GDScript** flight prototype set at a fictional RAF
countryside airfield in 1940, or a continuous 1:1 Malta island world. Choose a **Spitfire Mk I** or **Gloster Sea
Gladiator**, take off, bank over the fields, return, land and brake. Both have
guns, component damage, health/damage effects, and a flying Ju 87-inspired opponent that shoots
back. All aircraft are original procedural mesh placeholders. No paid assets.

## Browser version and free hosting

A single-threaded Godot web export and branded Play page are now included.
The browser guide uses **F to fire** so W + firing cannot close the tab via
Ctrl+W. Desktop Ctrl firing and all existing flight/landing controls are preserved.
A bundled free font supplies arrows and aiming-marker glyphs in browsers.

Play at [zelenski3398.github.io/codexproj1/](https://zelenski3398.github.io/codexproj1/).
GitHub Pages deployment is enabled; pushes to `main` automatically rebuild it.
The cloud proxy blocks direct access to the public Pages domain, so browser
checks run against the actual release WebAssembly/WebGL build locally.

See [web build, deployment and validation details](docs/web-hosting.md).
The workflow also saves a downloadable **first-sortie-web** artifact.

## Music and aircraft audio

The supplied **Wings Over Malta** theme plays through both selection menus and
fades out on departure. Spitfire and Sea Gladiator use their supplied engine
and gun sounds, with throttle/damage-driven engine mixing and spatial playback.
Click **AUDIO** for saved music/engine/gun volumes and mute. In a browser, the
**Play in Browser** click enables sound. The Stuka temporarily uses the supplied
Spitfire audio. See [audio controls, tuning and checks](docs/audio.md).

## Select a map and depart in Malta

The startup screen keeps **Countryside** and adds **Choose Malta**. Malta
opens a chart to choose **Ta' Qali, Luqa or Ħal Far**, a Spitfire or Sea Gladiator,
and **Depart**. You spawn on foot beside the selected parked aircraft.

**E** boards/leaves; **I** starts/stops the engine; **M** opens the live map.
On foot, **WASD** walks and **Left/Right arrows** turn. Taxi from the apron onto
the runway before full power. To leave, stop, idle throttle and stop the engine.
All islands/airfields occupy one world; switching aircraft retains damage,
fuel, parked planes, installations and the enemy. **R** is an explicit full
mission restart. The original countryside controls and start remain intact.

See [Malta geography, controls, tuning and acceptance flight](docs/malta-world.md).
Malta terrain uses bundled limestone/soil detail, irregular dry and cultivated
fields, muted scrub, rocky slopes and Mediterranean water locally and in web exports.
**F4** deliberately toggles the original elevation heatmap and displays a debug
notice; every new mission starts in normal mode. See the
[landscape materials, provenance, tuning and checks](docs/malta-landscape.md).
The source terrain uses measured modern elevations/coastline; airfield sites
are approximate and runway layouts are playable prototypes, pending the
historical 2D reference. Terrain attribution is included in-game and in the web build.

Validation: **559/559 existing native checks**, **35/35 Malta integration checks**
**18/18 uninterrupted journey checks**, and **41/41 browser checks** passed. Full browser flight feel and
other browsers remain unverified.

## Open and play

1. Install the standard **Godot 4.3 or newer** editor (not the .NET edition;
   tested with Godot 4.6.3).
2. Import `project.godot` from this folder in Godot's project manager.
3. Press **F5** (Run Project), then click inside the game view. Choose an
   aircraft and click **Fly**, or use **Left/Right** (or **1/2**) to select and
   **Enter** to start.
4. Hold **W**; throttle should rise by about 30 percentage points per second.

The selected aircraft starts stationary, with all three wheels down, near the south end
of the 1,800 m runway. The project uses the Compatibility renderer for broad PC
support. No package installation, asset download, login, or environment variables
are required. Alternatively, with Godot on your PATH:

```sh
godot --path . --editor
godot --path .
```

On Windows, use your Godot executable path if `godot` is not on PATH, for example:

```powershell
cd C:\firstcodexproj-latest
& 'C:\Tools\Godot\Godot_v4.6.3-stable_win64.exe' --path . --editor
```

To update your Windows checkout, stop Godot and run `git pull origin main`
inside `C:\firstcodexproj-latest`, then reopen the project. Adding Godot to PATH is
optional and does not affect keyboard controls. Exporting a Windows executable
is optional: install Godot's matching export templates, add a Windows Desktop
preset in Project → Export, and export. No executable is included here.

### Keyboard input in Godot's embedded game

The controls are saved in Project → Project Settings → Input Map, with both
physical-key and logical-key bindings. This also accepts keycode-only events
forwarded by embedded/remote game views. Escape and R run before GUI navigation,
including while paused; returning from a menu releases keyboard focus.

After updating the project, stop the game and close/reopen the project to reload
`project.godot`, press F5 and click inside the running game. If the editor still
captures your keys, launch a separate game window (or `godot --path .`) and
focus that window. Never use the visual-capture test script to play: it enables
the automated pilot for screenshots. Use F5 / `main.tscn` for gameplay.

## Aircraft choice

The startup screen shows both fighters and a live model preview. No player
physics or enemy combat runs until you choose **Fly**. R resets the selected
aircraft; it does not revert to the Spitfire. To change aircraft without closing
the game, press Escape and click **Choose another aircraft**. This clears the
previous player, enemy, bullets and effects, then returns to the selector.

The Sea Gladiator follows the supplied images: rounded stacked wings with
crossed bracing wires and struts, an exposed radial engine inside a silver
cowling, three-blade propeller, framed cockpit, fixed main wheels/tailwheel,
camouflage, RAF roundels and fin flashes, plus a cosmetic naval hook. The
**FAITH** marking is reference-inspired; this is an approximate original mesh.
The Gloster Sea Gladiator was a late-1930s naval biplane used during WWII.

| Prototype characteristic | Spitfire Mk I | Gloster Sea Gladiator |
| --- | --- | --- |
| Measured full-throttle level speed | About 365 km/h | About 228 km/h |
| Measured climb in the comparison fixture | About 16.2 m/s | About 7.8 m/s |
| Mass / wing area | 3,000 kg / 22.5 m² | 2,200 kg / 30 m² |
| Engine thrust / parasite drag | 12,500 N / 0.034 | 8,500 N / 0.044 |
| Landing gear | Retractable; G toggles | Fixed; G displays a notice |
| Machine guns | Eight wing guns | Four: two fuselage + two lower-wing guns |
| Takeoff guidance | 160–180 km/h | 115–135 km/h |
| Landing approach guidance | 155–180 km/h | 115–135 km/h |
| Low-speed stall warning | Below about 115 km/h | Below about 86 km/h |
| Health / controls | 100 HP / existing flight keys | 100 HP / same flight keys |

These are **measured game-tuning values**, not historical aircraft performance.
The weaker engine and increased biplane/fixed-gear drag produce slower flight,
acceleration and climb through the shared aerodynamic forces. There is no
scripted speed cap. The biplane's larger wing area allows lower-speed flying.
Its roll/pitch torques are reduced as well. HUD takeoff/approach advice, aircraft
name, gun count and fixed/retractable gear state follow your selection.

## Controls

| Key | Action |
| --- | --- |
| Up arrow | Pitch nose down |
| Down arrow | Pitch nose up |
| Left / right arrows | Roll left / right; gentle coordinated yaw helps turns |
| A / D | Manual rudder left / right; steering while taxiing |
| W / S | Increase / decrease throttle; setting holds when released |
| Ctrl (hold) | Fire the selected aircraft's guns (eight Spitfire / four Gladiator); release to stop |
| G | Spitfire: toggle gear, blocked with weight on wheels; Gladiator: fixed-gear notice |
| Space (hold) | Wheel brakes on the ground |
| F3 | **TEMPORARY DEBUG**: toggle component hitboxes/health inspector; choose player/enemy and inject/repair component damage |
| F4 | Malta only: toggle elevation heatmap debug (off by default, also works paused) |
| H | **TEMPORARY DEBUG**: remove 10 player HP per press (key repeat ignored) |
| R | Reset at runway start: 100 HP, gear down, zero throttle, clean effects/bullets; spawn exactly one fresh enemy and restart its airborne patrol |
| E / I / M | Malta: board/leave a stopped plane; start/stop engine; navigation chart |
| Escape | Pause / resume and display full controls |

The pause/crash panel has clickable resume, reset and aircraft-choice buttons. The HUD
shows airspeed in km/h, fuselage-centre altitude above the collision surface in
metres, throttle, gear, heading, flight state, stall warning, a gun-convergence
aim marker and a numeric **HP: 100/100** health bar. An orange Stuka marker
locates the enemy, with an edge cue when it is out of view; its HP, bearing,
distance and AI state appear below your health bar. A second health bar floats
above the enemy within 800 m, only while it is in front of the camera and on
screen; it disappears during pause or after destruction. At rest, altitude
is about 1 m because it measures the aircraft centre rather than wheel clearance.

## First circuit

* **Takeoff:** release brakes and hold W until the HUD reads 100%. Keep the
  aircraft straight. Around 160–180 km/h in the Spitfire or 115–135 km/h in the
  Gladiator, briefly hold Down to raise the nose;
  use short inputs to maintain a shallow climb. The tail-down stance may let
  the aircraft lift off by itself near this speed. Retract Spitfire gear after
  climbing; Gladiator gear stays extended.
* **Fly:** bank with short Left/Right inputs. Centre the controls and the bank
  largely holds; use opposite roll to level the wings. Add a little nose-up
  input in a turn to maintain height. A/D can adjust heading independently.
* **Stall:** low airspeed (about 115 km/h Spitfire / 86 km/h Gladiator) or angle
  of attack above 16°
  produces a warning and reduced lift. Lower the nose, level the wings and add
  power. Recover at altitude; stalls close to terrain can still cause a crash.
* **Land:** line up with the runway from either end. Extend Spitfire gear, reduce
  power and approach around 155–180 km/h (115–135 in the Gladiator, whose wheels
  are fixed). Keep wings level and descent shallow. Just
  above the runway, gently raise the nose to reduce sink; aim below 3 m/s at
  contact. Lower power fully after touchdown, then hold Space to stop. Release
  brakes and raise throttle to take off again. All grass is also landable, but
  the level runway is much easier.
* **Crash:** hard contact, a wing/airframe strike, or a belly landing without
  gear shows a crash panel. Press R to try again. Wheel sink faster than
  5.5 m/s counts as a hard landing.

## Guns, enemy and damage

Hold Ctrl while flying to fire **four guns per wing in the Spitfire** from visible
ports on the elliptical leading edges. The **Gladiator fires four guns**: two
from ports beside the forward fuselage and two at the lower wings' leading edges,
reflecting its different armament layout. No bullets originate at the centre
of either aircraft's propeller.
Rounds converge on a point 250 m ahead of the aircraft; the HUD aim marker
projects that point. Turning/banking changes the direction of newly fired rounds.
Existing rounds travel in world space. Throttle, arrows, rudder, gear, brakes,
reset and pause keep their existing bindings and work while Ctrl is held.

The stationary practice board has been replaced by a **Ju 87-inspired Stuka**
with an original procedural model based on the supplied reference: inverted
gull wings, long framed canopy, fixed wheel fairings, yellow cowling/fin and
red spinner. It starts airborne at **(-450, 160, 0)** and circles the airfield.
Both planes have **100 HP**, use the same damage/health effects, and can be
shot down by the other's swept-collision bullets. The enemy has two forward
wing guns with orange tracers, 6 rounds/sec per gun, 650 m/s bullet speed and
2 damage/round. It fires 0.75-second bursts separated by 1.25-second rests.
A separate rear-cockpit MG 15-style gunner tracks a pursuer and fires short
bursts with human reaction, delayed observations, uncertain lead and finite
traverse. **Pilot** is the default; Cadet and Ace have separate configurable
skill profiles. There is no 500 m firing cutoff: accuracy falls with range,
angular movement and Stuka manoeuvres. Bullet damage/speed/lifetime are unchanged.
See [gunner balance and measurements](docs/gunner-balance.md) and
[rear gunner and tactics](docs/stuka-tactics.md).

Take off and stay above **12 m AGL for eight seconds**. The grace now unlocks
for that aircraft life, without an airspeed requirement; a brief altitude or
speed dip does not restart it. The enemy acquires within **3,200 m** and retains
an acquired airborne player out to **7,500 m**, instead of returning to patrol
at the old detection boundary. Its speed remains limited by real thrust/drag;
a healthy Spitfire can still outrun it. Front guns fire within 650 m when its nose is
within 6° of its predicted aim point. It does not attack while you are on the
ground or after your aircraft is lost. Follow the marker, bank behind it and
hold Ctrl with your aiming marker over the enemy. Bank to evade its return
fire. Terrain/buildings obstruct both bullets and the enemy's sight line. The
AI breaks away on close passes, damage and aimed tail threats. It holds forward
fire during evasions, while the rear gunner can still defend. You can outpace this slower aircraft or return to
land; it resumes patrol when you land. Teams prevent friendly damage, and each
bullet excludes its shooter's collision body. Terrain and friendly bodies stop
rounds instead of letting them pass through.

Rear tracking is limited to **±70° astern**, **−12° to +60° elevation** and
75°/s mechanical traverse (Pilot human tracking is 42°/s). It aims at the whole
aircraft using noisy delayed positions, not an engine hitbox or exact velocity.
Pilot bursts last 0.45 s with 1.4 s rests; it corrects between bursts.
Every dispersed round checks the Stuka's own fuselage, tail and wing hitboxes.
A close, steady tail approach remains dangerous. Complete cockpit failure
disables the gunner. The HUD warns **REAR GUNNER FIRING · BREAK AWAY**.
**F3** also shows player/front/rear shots, damaging aircraft hits, percentage,
latest firing range and components struck; use its skill selector to compare
Cadet/Pilot/Ace. Counter reset leaves aircraft damage unchanged. R restores a
fresh encounter and clears statistics while keeping selected difficulty.

Navigation predicts a flight intercept at long range, switches to ballistic
alignment nearby and adjusts throttle to close without endless overshoots.
Defensive breaks turn toward the attacking side; centred repeat threats
alternate direction. Shallow descending breaks and low/high yo-yos trade
height for speed or reduce excessive closure. These simplified tactics request
ordinary slewed pilot inputs and never directly move the airframe. The HUD
shows the current tactic; terrain/stall protection still takes priority.

The four AI states are **PATROL**, **ENGAGE**, **EVADE** and **DESTROYED**.
Pitch/roll/rudder commands ramp smoothly, with soft angular-rate limits and a
46° patrol/avoidance bank limit and 55° tactical bank limit. Every 0.15 s, downward probes sample actual terrain and
buildings along a corridor up to 450 m ahead, including the wings. Predicted
descent below 65 m clearance requests a climb; forward obstruction probes
choose a sideways route. The enemy also turns toward the airfield before
reaching the edge of the finite terrain. These are simple local avoidance
rules rather than a general path planner.

At 0 HP the Stuka stops AI control, thrust and firing once and falls under the
shared flight physics. The HUD displays **Enemy destroyed** and lets you keep
flying. Its first ground contact creates a short CPU-rendered flame/smoke burst,
stops engine effects and settles the wreck; the burst fades within 2.5 s and
the wreck is removed after 4 s. Further damage cannot repeat the explosion or
defeat message. **R** restores the chosen player aircraft and replaces the old
enemy with exactly one fresh airborne instance, clearing all bullet pools,
smoke/fire, wrecks, impact bursts and the defeat state. Difficulty settings carry
across resets; changing aircraft also clears the old encounter.

The AI flies using **pilot commands and the same real rigid-body flight forces**;
it never translates or rotates the aircraft directly during flight. It predicts
interception using relative velocity (bullets inherit shooter velocity), with
small aiming assistance limited to the 6° nose cone. Each burst receives up to
±0.18° error on each aiming axis, and each enemy round has ±0.08° spread, so its
aim is imperfect. Engagement requests up to 18 m/s extra desired speed at long
range, matching speed near the firing pass. Player guns retain their fixed aircraft-relative convergence and have
zero spread by default. This is a simple forgiving opponent, not authentic
Stuka tactics; there is no bombing, AI takeoff or AI landing.

Press H five times: the aircraft reaches **exactly 50 HP with no smoke/fire**.
One more press reaches 40 HP and starts cowling smoke and fire. Emission density
increases as HP decreases. Smoke trails behind the plane, slows and fades in
world space over 2.5 seconds. The strict activation condition is `hp < 50.0`.
Healing to 50 or more stops new smoke and fire; already emitted particles finish
their short lifetimes. Tests also explicitly cover 49 HP.

`aircraft.take_damage(amount)` delegates to the reusable health component;
player HP is clamped to 0–100. `aircraft.health.heal(amount)` is available for
future repair mechanics (no repair key is added). Negative/non-finite damage
is ignored. At 0 HP, a destroyed signal fires once per life: guns and thrust
stop and the existing rigid-body gravity/aerodynamics make the aircraft fall.
Controls are disabled until R resets the aircraft. Healing alone does not
resurrect an already destroyed life. A landing crash still uses the pre-existing
crash state; the new HP state is independent of that crash detection.

R immediately clears bullets, muzzle flashes, impact sparks and damage effects.
If Ctrl is still held, release it and press again to resume firing safely.
Weapon audio follows successful salvos; there is no recoil, ammunition limit or reload in this milestone. Bullets use constant velocity (including inherited aircraft
velocity), without bullet gravity or wind; convergence is a visual/prototype
approximation rather than a historical ballistic model.

## Component damage and testing

All three aircraft use the same `AircraftDamage` runtime component and eight
independent integrity values, alongside the existing **100-HP hull**. Projectile
rays hit model-local **Area3D sensors on layer 8** and apply the first component
hit. The existing rigid-body collision shapes still handle landing/crashes;
they are skipped by bullet rays so a coarse wing or fuselage collider cannot
mask a more specific component. Sweeps retain terrain obstruction, impact
sparks, owner-body/owner-sensor exclusion, teams and fixed projectile pooling.
The Gladiator's upper/lower wings share left/right integrity; the Stuka's boxes
follow its gull-wing angles. Boxes approximate the meshes rather than providing
triangle-level detection or armour penetration.

| Component | Maximum integrity | Local damage multiplier | Hull damage multiplier | Mechanical effect |
| --- | ---: | ---: | ---: | --- |
| Fuselage | 140 | 1.00 | 1.00 | Up to +0.035 parasite drag |
| Left wing | 80 | 1.25 | 0.65 | Lower left lift, extra drag, roll/yaw imbalance |
| Right wing | 80 | 1.25 | 0.65 | Lower right lift, extra drag, opposite imbalance |
| Engine | 80 | 1.60 | 1.00 | Available thrust scales with integrity ratio to power 1.3; zero integrity means zero thrust |
| Cockpit | 60 | 1.50 | 1.50 | Simplified pilot impairment: pitch/roll/rudder authority falls toward 45% |
| Rudder | 45 | 1.25 | 0.50 | Rudder, fin/sideslip damping and coordinated yaw fall toward 10% authority |
| Elevator | 55 | 1.25 | 0.60 | Pitch control/passive elevator stability fall toward 10% authority |
| Fuel tank | 60 | 1.20 | 0.80 | Per hit: 40% leak probability, 12% ignition probability; leakage/fire drain fuel |

Raw projectile damage is multiplied separately for local integrity and hull HP.
Mechanical failure can therefore occur while hull HP remains positive. Wing
integrity scales the existing central lift force, adds drag and computes the
moment of unequal half-wing lift/drag at fixed spanwise arms. The stall warning
speed rises as usable lift decreases. Healthy factors are exactly 1/0, retaining
undamaged flight tuning. No damage component changes body transforms or velocities.

Fuel leak rate defaults to **0.02 tank fraction/s at full tank damage**, scaled
by tank damage. Burning consumes another **0.03/s**, removes **2 hull HP/s** and
**4 tank integrity/s**. Empty fuel cuts engine power and ends fuel emission.
Normal undamaged flying has no added fuel consumption in this prototype.
Fuel ignition is independent of hull HP and can emit above 50 HP at the tank;
the existing **engine** smoke/fire still uses its strict **below 50 HP** rule.
Both sources reuse the same Compatibility-compatible, world-space CPU pool.
Hull healing stops HP-driven emission but does not repair components or stop
an active fuel fire. R restores all integrity, fuel and hazards and clears both
aircraft's effects; destruction still uses the existing one-shot hull lifecycle.

The Stuka integrates measured bank/height errors into bounded trim, increases
normal pitch/rudder commands for reduced authority and requests more throttle
for reduced engine power. Inputs retain their rate limits and go through the
same forces/torques as before. A failed engine requests a glide when altitude
allows; severe damage may remain unrecoverable. The AI cannot restore lost
power or lift, teleport, or override angular/linear velocity.

### Configure damage

Open `damage_profiles/spitfire.tres`, `sea_gladiator.tres` or `stuka.tres` in
Godot's Inspector. Expand **Components** to edit integrity, local/hull multipliers
and hitbox position/size/rotation. Keep the eight component IDs intact. The
profile also exposes lift loss (65% per fully damaged half-wing), drag gains,
spanwise arms, engine power curve, minimum control authority, fuel probabilities,
rates, fire damage and random seed. Each aircraft can override its exported
`damage_profile` with another profile. Restart the session after changing tuning.
Resources contain configuration only; per-aircraft health/fuel state is separate.

### Short manual test procedure

1. Start either fighter, take off, and reach a safe altitude. Press **F3** to
   show the hitboxes and inspection panel; **Esc** pauses without covering the
   aircraft while the inspector is open. Select **Player** or **Stuka** and a
   component. The selected component's boxes turn white. The list displays all
   eight integrity values, hull HP, flight modifiers, fuel, hazards and last hit.
2. Use **Apply 10 raw damage** one or more times, then resume and compare:

   | Select | Check |
   | --- | --- |
   | Left wing, then right wing | Neutral controls develop a roll toward the damaged side; lift declines and drag rises. Repeat on the opposite side after repair. |
   | Engine | The power percentage and acceleration/climb fall despite the same throttle; five clicks disable its thrust while hull HP remains positive. |
   | Rudder | A/D produces weaker yaw; banking/coordinated yaw and fin stability weaken too. |
   | Elevator | Up/Down produces weaker pitch response. |
   | Fuel tank | Fuel falls if leakage occurs. Enable **Force leak + fire for debug tank hits** for a deterministic visual test; flames/smoke and ongoing hull loss should appear, even above 50 HP. |
   | Fuselage | Extra drag rises and the same power produces slower flight. |
   | Cockpit | All three pilot rotation controls become less effective. |

3. Use **Repair this live aircraft** between trials, or **R** for a full session
   restart after destruction. Check that integrity, fuel, power and effects reset.
   Select **Stuka**, damage a wing/engine/control surface, resume, and observe its
   bounded compensating turns and throttle. Fire at its different visible
   regions and use **Last hit** to verify actual projectile classification.
   Repeat after choosing the Gladiator; hits on either wing level affect that
   side. F3 hides all visualization without disabling the sensors.

The debug override only affects that debug button, never real projectile hazard
probabilities. To verify probabilities themselves, set leak/fire to 0 or 1 in a
profile and restart, then shoot/damage the tank. The seeded RNG makes the same
hit sequence repeatable. Debug tools do not resurrect a destroyed aircraft;
use R. H retains its old hull-only 10-HP diagnostic behavior.

## How it works and tuning

Normal flight uses a `RigidBody3D`, engine force, aerodynamic forces, gravity
and control torques at **120 physics ticks per second**. The transform and
velocities are set directly only for reset or test scenario initialization.
Lift depends on forward airspeed and angle of attack, with a smooth stall
falloff. Drag includes parasite, induced, stall and landing-gear drag. A simple
fin force damps sideslip. Bank angle feeds a coordinated yaw torque; the banked
lift and fin forces turn the actual velocity. Angular damping makes keyboard
inputs manageable, but the player has no altitude, heading or speed autopilot. The enemy controller
sets its own pitch, roll, rudder and throttle commands.

The main scripts are deliberately small separate components:

| Script | Responsibility / important tuning defaults |
| --- | --- |
| `scripts/aircraft.gd` | Flight forces, crash/reset; mass 3,000 kg, wing area 22.5 m², thrust 12,500 N, lift slope 4.6/radian, zero-alpha lift 0.62, stall angle 16°, stall warning speed 32 m/s; pitch/roll/rudder torque, angular response and coordinated-turn gain are exported |
| `scripts/pilot_input.gd` | Keyboard commands; throttle ramps 30 percentage points/second |
| `scripts/landing_gear.gd` | Two main wheels and a tailwheel; raycast springs/dampers, tyre friction, brakes and ground retraction lock; all handling parameters exported |
| `scripts/chase_camera.gd` | Smooth, horizon-level follow at 19 m distance / 6 m height; terrain/building raycasts keep the camera clear |
| `scripts/hud.gd` | Instruments, controls, pause/crash overlays, overhead enemy HP and persistent defeat message; exported enemy health range 800 m |
| `scripts/spitfire_model.gd` | Original procedural silhouette, camouflage, canopy, RAF roundels, propeller and suspension-linked wheels |
| `scripts/airfield.gd` | Runway, terrain collision, rolling countryside, hangars, control tower, fields, trees and daylight |
| `scripts/main.gd` | Startup/aircraft-switch lifecycle, fresh-enemy restart, one-shot defeat notification and session-owned impact cleanup; configurable enemy spawn position |
| `scripts/aircraft_selector.gd` | Mouse/keyboard aircraft choice and live mesh preview, with no gameplay simulation until Fly |
| `scripts/sea_gladiator.gd` | Biplane flight variant: 2,200 kg, wing area 30 m², thrust 8,500 N, parasite drag 0.044, zero-alpha lift 0.60, stall speed 24 m/s; pitch/roll/rudder torque 13,000/14,000/10,000; fixed gear and upper-wing collider |
| `scripts/sea_gladiator_model.gd` | Original reference-inspired biplane, radial engine, bracing, canopy, RAF markings, fixed suspension-linked wheels and four gun ports |
| `scripts/wing_guns.gd` | Salvos from the selected model's gun ports: 12 rounds/sec **per gun**, 850 m/s bullet speed, 2 s lifetime, 4 damage/round, 250 m convergence, every fourth round a tracer, exported spread 0° for player / 0.08° enemy |
| `scripts/projectile_pool.gd` | 384 fixed bullet slots, swept ray collision from previous to next position, shooter body/sensor exclusion and team filtering, 32 recycled impact flashes; mask 15 includes terrain/player/enemy bodies and component sensors |
| `scripts/health.gd` | Reusable HP, clamping, damage/heal/reset and one-shot depleted signal; both aircraft maximum 100 |
| `scripts/damage_effects.gd` | 128 pooled CPU mesh particles; procedurally generated soft billboard smoke, flame spheres, intensity-driven emission, world-space lifetime; Compatibility/ANGLE-friendly, no GPU particles |
| `scripts/enemy_aircraft.gd` | Enemy configuration using shared flight, health, effects and weapons; 26 m² wing area, 11,500 N thrust, separate collision layer, airborne spawn, physical falling wreck, single impact event and exported 4 s wreck cleanup delay |
| `scripts/enemy_pilot.gd` | Patrol/engage/evade/destroyed states, predictive terrain/obstacle avoidance, intercept prediction, per-wing line of sight and short bursts; exports speed 58 m/s (up to +18 engage), patrol radius 450 m, minimum height 65 m, terrain horizon 5 s / margin 20 m, command slew 2.5/s, bank 46° patrol / 55° tactical, pitch/roll/yaw rate limits 0.45/0.7/0.3 rad/s, detection 3,200 m / retention 7,500 m, firing 650 m, cone 6°, grace 8 s, burst/rest 0.75/1.25 s, aim error 0.18°, evade 3 s |
| `scripts/rear_gunner.gd` | Human rear-cockpit aiming, delayed noisy observations, uncertain lead, finite traverse, burst correction and per-round own-geometry checks; unchanged MG 15-style ballistics and 128 slots; shared grace/cockpit failure |
| `gunner_profiles/*.tres` | Cadet/Pilot/Ace Resource profiles: reaction/delay, measurement/lead error, tracking, visibility, vibration, bank/motion error and burst/rest scales; optional Inspector override |
| `scripts/weapon_statistics.gd` / `scripts/gunner_debug_panel.gd` | Shared projectile counters, range buckets and component hit counts; F3 skill switch/reset and retained statistics after wreck removal |
| `scripts/combat_teams.gd` | Shared neutral/player/enemy team IDs and friendly-fire policy |
| `scripts/destruction_burst.gd` | Single session-owned cosmetic impact burst; 32 CPU mesh/sprite particles, 2.5 s lifetime, no area damage or GPU particles |
| `scripts/stuka_model.gd` | Original reference-inspired gull-wing/canopy/fixed-gear model and two leading-edge gun ports |
| `scripts/aircraft_damage.gd` | Shared component integrity, hull transfer, wing moments, power/control factors and fuel hazards |
| `scripts/aircraft_hitbox.gd` | Projectile-only component areas and optional colored/selected wire visualization; no terrain contact forces |
| `scripts/aircraft_damage_profile.gd`, `aircraft_component_definition.gd`, `damage_hitbox_spec.gd` | Inspector-editable per-aircraft resources in `damage_profiles/`: tuning and geometry, no runtime health |
| `scripts/component_damage_debug.gd` | F3 inspector, player/enemy/part selectors, raw damage, deterministic fuel override and live-aircraft repair |
| `scripts/practice_target.gd` | Thin stationary test fixture retained only for swept-collision regression checks |

Defaults and `@export` properties can be adjusted in the scripts. To expose
them directly in the Inspector, create a scene node with the relevant script
attached; the current main scene instantiates components in code. Suspension
spring values are N/m and damping values N/(m/s). Altering mass requires
retuning wheel stiffness/damping and possibly lift/thrust.

This is a forgiving approximation, not a historical flight simulator. In
particular, stall is a continuous lift reduction with a mild nose-down tendency,
coordinated yaw is assisted, and wheel friction acts at the centre of mass to
avoid taildragger nose-over when braking. Suspension forces act at the actual
three attachment points. Belly and wing collision shapes detect airframe
strikes. Retracted wheels stop providing suspension contact.

## Validation

From this project folder, import scripts once and run the integration suite:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script res://tests/flight_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/keyboard_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/weapons_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/enemy_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/aircraft_choice_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/encounter_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/component_damage_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/rear_gunner_checks.gd
godot --headless --path . --fixed-fps 120 --script res://tests/gunner_balance_checks.gd -- /path/to/gunner-results.json
```

`flight_checks.gd` runs the real scene, rigid body, collision terrain, suspension
and input commands. Its fixtures initialize approach/stall/crash situations;
flight thereafter is integrated entirely by the live simulation. A failing
assertion exits with code 1. The player autopilot used for takeoff/approach checks is only in the test
script; gameplay automation belongs solely to the enemy. Original regression
suites disable enemy combat to isolate flight/input/weapon behavior. The enemy
suite runs the live armed AI and both aircraft in the complete scene. Its
precision fixtures set aim error/spread to zero and disable damage evasion to
isolate damage/rate assertions; the new encounter suite exercises production
aim error, spread and damage evasion.

**Current result: 35/35 integration checks passed on Godot 4.6.3.** These cover
stable three-wheel parking, ground gear lock, takeoff/climb, held and adjusted
throttle, gear retraction, banking/heading/velocity turns, low-speed and
high-angle stalls, power/nose-down recovery, gentle gear-down landing, braking,
bounded touchdown bounce, another takeoff without reset, reset, input signs,
paused physics, hard-impact crashes, crash recovery and gear-up belly crashes.
Left and right banks both turn the actual heading/velocity, manual rudder
produces yaw, and fixture assertions confirm requested initial altitude/velocity.
The camera also corrects a deliberately initialized below-terrain position.

**Keyboard regression result: 24/24 passed.** These inject `InputEventKey`
events through Godot's input pipeline, exercising physical and keycode-only
events for throttle, both arrow/rudder directions, brakes, gear, reset and
pause/resume. They check held throttle, key releases, auto-repeat and shortcuts
with GUI focus. The previous physical-only bindings failed nine of these checks
for keycode-only input. Native OS-level W, S, Escape pause/resume and R were also
verified in a rendered X11 window (5/5 checks). Windows embedded input still
requires confirmation on the user's machine.

**Weapons/health result: 36/36 passed.** Live-scene checks cover wing-port
positions/convergence, firing rate, Ctrl press/release (including keycode-only
embedded events), simultaneous throttle/roll/rudder and physically banking
while firing, owner collision exclusion, target damage and impact effects,
a 30,000 m/s bullet crossing a 25 cm panel without tunnelling, exact configured
damage, bounded sustained-fire pooling, H press/repeat, 50 versus 49 HP,
increasing emission, world-space smoke, healing and fade-out, clamping,
one-shot destruction, thrust/gun lockout, physics-driven falling, destroyed HUD,
and complete reset followed by restored throttle/fire. Together with flight and
keyboard regressions, **95/95 original checks pass on Godot 4.6.3**. The thin
practice board is spawned only by the weapon test.

**Enemy result: 31/31 passed; the original four suites total 126/126 on Godot 4.6.3.**
The additional `enemy_checks.gd` suite verifies the reference-inspired model,
separate input/collision ownership, stable 90-second physics patrol, ground
protection, a 75-second engagement from patrol, live projectile damage in both directions,
airborne grace/rest/burst timing, owner exclusion, pause, shooting down either
plane, falling wrecks, enemy defeat HUD, reset of both lives/bullet pools/trails,
H/G/Ctrl isolation, obstacle line of sight, close-pass break-away and the actual
R key after hostile destruction.

**Aircraft choice / Gladiator result: 31/31 passed; all five suites total 157/157.**
This checks startup before simulation, physical and keycode-only menu navigation,
Enter start, focus release, four-gun firing while steering, fixed-gear G behavior,
aircraft-specific HUD, stable suspension, takeoff, banking, low-speed stall and
recovery, gentle landing, braking, a second takeoff, actual projectile damage in
both directions, exact 50-HP/no-effects threshold, smoke/fire, destruction,
selected-aircraft reset, pause-menu aircraft change, returning to the original
Spitfire, repeated-switch cleanup, and measured lower speed/acceleration/climb.
The performance fixture starts both planes at 40 m/s and 800 m altitude, holds
full throttle with the same altitude controller for 45 simulated seconds, then
holds the same nose-up attitude for a 20-second climb. The Spitfire retracts its
gear; the Gladiator's gear stays fixed. Controllers exist only in tests.

**Extended encounter result: 46/46 passed; all six suites total 203/203.**
`encounter_checks.gd` verifies one safe airborne spawn; team damage and owner
exclusion with 30,000 m/s swept rounds; cover stopping both teams' bullets;
production imperfect aiming hitting a moving target; damage-triggered evade;
physical recovery from predicted hill impact (minimum measured clearance 74 m);
limited rotation/movement and slewed commands; physical avoidance of a tall
obstacle; countryside boundary protection; enemy 50/49-HP smoke/fire, intensity,
world-space trail and healing; nearby numeric overhead HP, behind-camera/range
hiding; a fatal actual player projectile; single depletion/notification/impact;
engine-off physical falling; effect/wreck delay cleanup; continued player
control; actual R spawning a new instance, clearing active effects/rounds,
preserving difficulty, and avoiding duplicates on repeated reset input.

**Component damage result: 148/148 passed; all seven suites total 351/351.**
`component_damage_checks.gd` fires actual 30,000 m/s projectiles into every
component of all three models, checks exact local/hull multipliers, unrelated
component isolation, retained sparks, rotated sensor alignment, both Gladiator
wing levels, sensor-level self/friendly exclusion, and separate landing shapes.
Matched live flight trials verify opposite left/right wing roll, lift/drag loss,
engine acceleration/power failure, fuselage drag, actual reduced yaw/pitch/roll
responses and hull healing without mechanical repair. Fuel trials check 0/1
probabilities, leakage/burning above 50 hull HP, both effect types, depletion and
power cutoff, reset and rejection of post-destruction hits. A Stuka with wing,
engine, elevator and rudder damage flies for 30 s (minimum measured altitude
289 m from a 300 m fixture) with nonzero trim and increased throttle through
slewed controls. Physical/keycode-only F3, enemy/player inspection and damage,
paused hazards, debug repair, full R and aircraft-switch cleanup are verified.
The encounter regression now aims its exact-damage/fatal-hit fixtures at the
fuselage side, rather than a coarse centreline capsule that can hit tail parts.

**Rear gunner / tactics result: 46/46 passed; all eight suites total 397/397.**
The new suite checks separate rear/forward stations, parked and airborne grace,
real rear hits on static/moving aircraft, localized damage, self/friendly safety,
firing beyond 500 m, physical lifetime reach, arcs, banked tracking, own-tail/terrain cover,
a 30,000 m/s swept cover hit, traverse limits, bursts/rests, cockpit failure/repair,
destruction, pause, clean restart and retained gunner tuning. It also checks slow
player acquisition, pursuit retention and release, tail-threat breaks, alternating
break direction, real turning/altitude protection, slewed commands and high/low
yo-yo goals. The existing 75-second pursuit retains actual forward-gun hits;
its rear-approach assertion now expects the intentional defensive break.
The geometry/lifecycle suite uses a clearly documented, test-only precise profile
to isolate those checks; gameplay and the balance suite use the production skills.

**Human gunner balance: 162/162; all nine suites: 559/559 on Godot 4.6.3.**
The added suite samples both fighters, all three skills and 100/300/500/700 m,
three seeds per case and 20 simulated seconds per seed. It verifies delayed
reaction, burst corrections, actual shot dispersion and flight time, own-wing/
tail/fuselage obstruction, counters, live weaving and physical attacks.
Pilot Spitfire hit rates are 56.7% / 18.7% / 8.3% / 1.6% at those distances.
These are intact stationary silhouettes, not a claim about every dogfight.
Moving, normally controlled attacks defeated the Stuka with both fighters while
its rear gun fired. See [method, data and manual procedure](docs/gunner-balance.md).
Rendered native mouse/keyboard checks passed 16/16, including selecting Cadet
in the F3 dropdown and W/Ctrl afterwards. Windows 4.7/ANGLE and subjective
encounter balance remain unverified.

Rendered Compatibility close-ups were inspected for crew, swivel, muzzle flash,
tracers and the existing cockpit hitbox:

```sh
godot --path . --audio-driver Dummy --fixed-fps 120 --script res://tests/rear_gunner_visual_capture.gd -- /path/to/rear-captures
```

**Native mouse/keyboard result: 10/10 passed in a rendered X11 window.** These
use OS mouse/key events to select each plane, click Fly, start with Enter,
verify W and Ctrl after leaving the menu, check fixed-gear G behavior, H/R
damage/reset preserving the Gladiator, and click the paused aircraft-change
button before selecting/starting the Spitfire. These window-level checks are
separate from the reproducible Godot integration assertions.

**Extended native result: 14/14 passed.** The same window-level mouse/keyboard
trial also verifies F3, paused mouse damage/repair, restoration of the normal
pause panel when the inspector closes, and Escape resuming flight. New rendered
component captures were inspected for the Spitfire, Gladiator and Stuka, including
selected hitboxes, integrity/modifiers, tank fire above 50 HP and reset:

```sh
godot --path . --audio-driver Dummy --fixed-fps 120 --script res://tests/component_visual_capture.gd -- /path/to/component-captures sea_gladiator
```

A rendered check saves both selection screens, runway, airborne, enemy encounter,
player/enemy model close-ups, both 50-HP/no-effects thresholds, firing/damaged,
pause, enemy overhead HP, engine smoke/fire, ground impact, wreck cleanup and
fresh-session reset screenshots:

```sh
godot --path . --audio-driver Dummy --fixed-fps 120 --script res://tests/visual_capture.gd -- /path/to/captures sea_gladiator
```

The final argument selects the captured aircraft (omit it for Spitfire).
It requires a graphical display; `--headless` cannot validate rendering.
The prototype was also launched with OpenGL Compatibility on a virtual X11
display using Mesa software rendering. Rendered frames were captured and inspected, including both selection screens, the Gladiator/Spitfire/Stuka models,
selected-aircraft controls and gear state, enemy marker/overhead HP/state, impact
burst, cleanup notification, gun flashes/tracers, engine smoke/fire, the HP threshold,
player health bar, destroyed/reset UI and flight instruments.
Automated physics checks do not replace interactive playtesting. Windows embedded keyboard
handling and dogfight difficulty, a player-flown full circuit, Windows hardware/performance and
exported-executable behavior remain unverified. Windows ANGLE and Godot 4.7
were not available for verification; the effects use only Compatibility-supported
CPU mesh/sprite rendering, but should be checked on that actual configuration.

For a sandbox that cannot write to the normal Linux user directories, set
`XDG_CACHE_HOME`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` to writable directories
before invoking Godot. This is only a sandbox accommodation, not a game runtime
requirement. Use the existing checkout in each isolated cloud task; no Git
worktree is required.

## Known limitations and next steps

* One simple AI opponent; no multiplayer, campaign, AI landing,
  ammunition management, rear-gunner reloads or complex menus.
* Meshes, buildings and camouflage are simple original placeholders. The
  Spitfire uses its familiar elliptical-wing silhouette; the Stuka follows
  the supplied photograph with approximate proportions and detail. The Sea
  Gladiator follows the supplied biplane references; rigging, cockpit and
  engine detail remain simplified. The naval hook has no carrier interaction.
* Component boxes/wing force arms and cockpit impairment are approximations;
  no detached wings, armour penetration, spreading fire or pilot characters.
  Fuel leakage is modeled as a remaining tank fraction rather than a fuel-fluid
  system, and only damage consumes fuel.
* No wind, tyre audio, propwash, ground effect, flap controls,
  routine fuel consumption, historical engine dynamics, wheel rotation, or gradual gear animation.
* Terrain is a finite 10 × 10 km patch with coarse rolling hills. Stay within
  the countryside; the enemy turns back near the edge, but there is no world
  streaming or player boundary recovery.
* Camera raycasts handle terrain/buildings, but crowded obstacle situations and
  extreme aerobatics still need interactive review.
* The suspension makes grass operations forgiving; the runway has the most
  predictable approach surface. Hard wing contact is intentionally fatal.

The aircraft's local **-Z** axis is forward, +Y up, +X right, leaving a clear
shared coordinate convention for player and enemy physics and weapons. Each model's gun markers are the authoritative firing origins.
