# First Sortie

A single-player 3D **Godot 4 / GDScript** flight prototype set at a fictional RAF
countryside airfield in 1940. Fly a procedural Spitfire Mk I placeholder, take
off, bank over the fields, return, land and brake. Eight wing guns, a practice
target and aircraft health/damage effects are included. No paid assets.

## Open and play

1. Install the standard **Godot 4.3 or newer** editor (not the .NET edition;
   tested with Godot 4.6.3).
2. Import `project.godot` from this folder in Godot's project manager.
3. Open the project and press **F5** (Run Project), then click inside the game
   view so it receives keyboard input. Hold **W**; throttle should rise by
   about 30 percentage points per second.

The aircraft starts stationary, with all three wheels down, near the south end
of the 1,800 m runway. The project uses the Compatibility renderer for broad PC
support. No package installation, asset download, login, or environment variables
are required. Alternatively, with Godot on your PATH:

```sh
godot --path . --editor
godot --path .
```

On Windows, use your Godot executable path if `godot` is not on PATH, for example:

```powershell
cd C:\firstcodexproj
& 'C:\Tools\Godot\Godot_v4.6.3-stable_win64.exe' --path . --editor
```

To update your Windows checkout, stop Godot and run `git pull origin main`
inside `C:\firstcodexproj`, then reopen the project. Adding Godot to PATH is
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

## Controls

| Key | Action |
| --- | --- |
| Up arrow | Pitch nose down |
| Down arrow | Pitch nose up |
| Left / right arrows | Roll left / right; gentle coordinated yaw helps turns |
| A / D | Manual rudder left / right; steering while taxiing |
| W / S | Increase / decrease throttle; setting holds when released |
| Ctrl (hold) | Fire all eight wing-mounted machine guns; release to stop |
| G | Toggle landing gear; retraction is blocked with weight on wheels |
| Space (hold) | Wheel brakes on the ground |
| H | **TEMPORARY DEBUG**: remove 10 player HP per press (key repeat ignored) |
| R | Reset at runway start: 100 HP, gear down, zero throttle, clean effects/bullets; also repair target |
| Escape | Pause / resume and display full controls |

The pause/crash panel also has clickable resume and reset buttons. The HUD
shows airspeed in km/h, fuselage-centre altitude above the collision surface in
metres, throttle, gear, heading, flight state, stall warning, a gun-convergence
aim marker and a numeric **HP: 100/100** health bar. At rest, altitude
is about 1 m because it measures the aircraft centre rather than wheel clearance.

## First circuit

* **Takeoff:** release brakes and hold W until the HUD reads 100%. Keep the
  aircraft straight. Around 160–180 km/h, briefly hold Down to raise the nose;
  use short inputs to maintain a shallow climb. The tail-down stance may let
  the aircraft lift off by itself near this speed. Retract gear after climbing.
* **Fly:** bank with short Left/Right inputs. Centre the controls and the bank
  largely holds; use opposite roll to level the wings. Add a little nose-up
  input in a turn to maintain height. A/D can adjust heading independently.
* **Stall:** low airspeed (below about 115 km/h) or angle of attack above 16°
  produces a warning and reduced lift. Lower the nose, level the wings and add
  power. Recover at altitude; stalls close to terrain can still cause a crash.
* **Land:** line up with the runway from either end. Extend gear, reduce power
  and approach around 155–180 km/h. Keep wings level and descent shallow. Just
  above the runway, gently raise the nose to reduce sink; aim below 3 m/s at
  contact. Lower power fully after touchdown, then hold Space to stop. Release
  brakes and raise throttle to take off again. All grass is also landable, but
  the level runway is much easier.
* **Crash:** hard contact, a wing/airframe strike, or a belly landing without
  gear shows a crash panel. Press R to try again. Wheel sink faster than
  5.5 m/s counts as a hard landing.

## Guns, target and damage

Hold Ctrl while flying to fire **four guns per wing** from visible ports on the
elliptical leading edges, following the requested eight-port Spitfire layout.
Rounds converge on a point 250 m ahead of the aircraft; the HUD aim marker
projects that point. Turning/banking changes the direction of newly fired rounds.
Existing rounds travel in world space. Throttle, arrows, rudder, gear, brakes,
reset and pause keep their existing bindings and work while Ctrl is held.

The large red/cream **PRACTICE TARGET** is beside the west side of the runway,
left/ahead of the initial aircraft: world position **(-75, 12, 440)**. It has
500 HP, a thin collision panel and a world-space HP label. Fly a shallow pass
along its south-facing side and align the aiming marker with the bullseye before
holding Ctrl. It does not shoot back. R repairs it. Projectiles also show impact
sparks on terrain/buildings. The automated target test initializes an approach
at (-75, 12, 620), facing -Z, then fires the actual guns at it.

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
There are no enemy aircraft, weapon audio, recoil, ammunition limits or reloads
in this milestone. Bullets use constant velocity (including inherited aircraft
velocity), without bullet gravity or wind; convergence is a visual/prototype
approximation rather than a historical ballistic model.

## How it works and tuning

Normal flight uses a `RigidBody3D`, engine force, aerodynamic forces, gravity
and control torques at **120 physics ticks per second**. The transform and
velocities are set directly only for reset or test scenario initialization.
Lift depends on forward airspeed and angle of attack, with a smooth stall
falloff. Drag includes parasite, induced, stall and landing-gear drag. A simple
fin force damps sideslip. Bank angle feeds a coordinated yaw torque; the banked
lift and fin forces turn the actual velocity. Angular damping makes keyboard
inputs manageable, but there is no altitude, heading or speed autopilot.

The main scripts are deliberately small separate components:

| Script | Responsibility / important tuning defaults |
| --- | --- |
| `scripts/aircraft.gd` | Flight forces, crash/reset; mass 3,000 kg, wing area 22.5 m², thrust 12,500 N, lift slope 4.6/radian, zero-alpha lift 0.62, stall angle 16°, stall warning speed 32 m/s; pitch/roll/rudder torque, angular response and coordinated-turn gain are exported |
| `scripts/pilot_input.gd` | Keyboard commands; throttle ramps 30 percentage points/second |
| `scripts/landing_gear.gd` | Two main wheels and a tailwheel; raycast springs/dampers, tyre friction, brakes and ground retraction lock; all handling parameters exported |
| `scripts/chase_camera.gd` | Smooth, horizon-level follow at 19 m distance / 6 m height; terrain/building raycasts keep the camera clear |
| `scripts/hud.gd` | Instrument cards, controls, pause and crash overlays |
| `scripts/spitfire_model.gd` | Original procedural silhouette, camouflage, canopy, RAF roundels, propeller and suspension-linked wheels |
| `scripts/airfield.gd` | Runway, terrain collision, rolling countryside, hangars, control tower, fields, trees and daylight |
| `scripts/main.gd` | Connects the scene components |
| `scripts/wing_guns.gd` | Eight-gun salvos: 12 rounds/sec **per gun**, 850 m/s bullet speed, 2 s lifetime, 4 damage/round, 250 m convergence, every fourth round a tracer; exported tuning values |
| `scripts/projectile_pool.gd` | 384 fixed bullet slots, swept ray collision from previous to next position, shooter RID exclusion, 32 recycled impact flashes; mask 7 includes terrain/aircraft/target layers |
| `scripts/health.gd` | Reusable HP, clamping, damage/heal/reset and one-shot depleted signal; player maximum 100, target maximum 500 |
| `scripts/damage_effects.gd` | 128 pooled CPU mesh particles; procedurally generated soft billboard smoke, flame spheres, intensity-driven emission, world-space lifetime; Compatibility/ANGLE-friendly, no GPU particles |
| `scripts/practice_target.gd` | Damageable thin target with HP label, hit receiver, destroyed appearance and reset |

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
```

`flight_checks.gd` runs the real scene, rigid body, collision terrain, suspension
and input commands. Its fixtures initialize approach/stall/crash situations;
flight thereafter is integrated entirely by the live simulation. A failing
assertion exits with code 1. The automated pilot used for takeoff/approach
checks is only in the test script, not in gameplay.

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
keyboard regressions, **95/95 checks pass on Godot 4.6.3**.

A rendered check can save runway, airborne, 50-HP/no-effects, firing/damaged,
pause, destroyed and reset screenshots:

```sh
godot --path . --audio-driver Dummy --fixed-fps 120 --script res://tests/visual_capture.gd -- /path/to/captures
```

It requires a graphical display; `--headless` cannot validate rendering.
The prototype was also launched with OpenGL Compatibility on a virtual X11
display using Mesa software rendering. All seven frames were captured and
inspected, including wing flashes/tracers, engine smoke/fire, the HP threshold,
health bar, target, destroyed/reset UI and unchanged flight instruments.
Automated physics checks do not replace interactive playtesting. Keyboard
handling feel, a player-flown full circuit, Windows hardware/performance and
exported-executable behavior remain unverified. Windows ANGLE and Godot 4.7
were not available for verification; the effects use only Compatibility-supported
CPU mesh/sprite rendering, but should be checked on that actual configuration.

For a sandbox that cannot write to the normal Linux user directories, set
`XDG_CACHE_HOME`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` to writable directories
before invoking Godot. This is only a sandbox accommodation, not a game runtime
requirement. Use the existing checkout in each isolated cloud task; no Git
worktree is required.

## Known limitations and next steps

* No enemy aircraft/AI, multiplayer, campaign, per-part damage or complex menus.
* Meshes, buildings and camouflage are simple original placeholders. No image
  reference was available in the cloud conversation, so the model uses the
  Spitfire's familiar elliptical-wing silhouette rather than matching a photo.
* No wind, engine audio, tyre audio, propwash, ground effect, flap controls,
  fuel, historical engine dynamics, wheel rotation, or gradual gear animation.
* Terrain is a finite 10 × 10 km patch with coarse rolling hills. Stay within
  the countryside; there is no world streaming or boundary recovery.
* Camera raycasts handle terrain/buildings, but crowded obstacle situations and
  extreme aerobatics still need interactive review.
* The suspension makes grass operations forgiving; the runway has the most
  predictable approach surface. Hard wing contact is intentionally fatal.

The aircraft's local **-Z** axis is forward, +Y up, +X right, leaving a clear
place for future enemy aircraft without coupling them to input, camera or HUD
code. The eight wing markers are now the authoritative gun origins.
