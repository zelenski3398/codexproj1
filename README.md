# First Sortie

A single-player 3D **Godot 4 / GDScript** flight prototype set at a fictional RAF
countryside airfield in 1940. Fly a procedural Spitfire Mk I placeholder, take
off, bank over the fields, return, land and brake. No combat or paid assets.

## Open and play

1. Install the standard **Godot 4.3 or newer** editor (not the .NET edition;
   tested with Godot 4.6.3).
2. Import `project.godot` from this folder in Godot's project manager.
3. Open the project and press **F5** (Run Project).

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

Source files created in the cloud must first be brought into your local checkout
(for example via a GitHub commit and pull). This project has not been pushed or
copied to `C:\firstcodexproj` automatically. Exporting a Windows executable is
optional: install Godot's matching export templates, add a Windows Desktop
preset in Project → Export, and export. No executable is included here.

## Controls

| Key | Action |
| --- | --- |
| Up arrow | Pitch nose down |
| Down arrow | Pitch nose up |
| Left / right arrows | Roll left / right; gentle coordinated yaw helps turns |
| A / D | Manual rudder left / right; steering while taxiing |
| W / S | Increase / decrease throttle; setting holds when released |
| G | Toggle landing gear; retraction is blocked with weight on wheels |
| Space (hold) | Wheel brakes on the ground |
| R | Reset safely at the runway start, with gear down and zero throttle |
| Escape | Pause / resume and display full controls |

The pause/crash panel also has clickable resume and reset buttons. The HUD
shows airspeed in km/h, fuselage-centre altitude above the collision surface in
metres, throttle, gear, heading, flight state and stall warning. At rest, altitude
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

A rendered smoke check can also save runway, airborne and pause screenshots:

```sh
godot --path . --audio-driver Dummy --fixed-fps 120 --script res://tests/visual_capture.gd -- /path/to/captures
```

It requires a graphical display; `--headless` cannot validate rendering.
The prototype was also launched with OpenGL Compatibility on a virtual X11
display using Mesa software rendering. Runway, airborne and paused frames were
captured and inspected for aircraft, terrain, camera and HUD visibility.
Automated physics checks do not replace interactive playtesting. Keyboard
handling feel, a player-flown full circuit, Windows hardware/performance and
exported-executable behavior remain unverified.

For a sandbox that cannot write to the normal Linux user directories, set
`XDG_CACHE_HOME`, `XDG_CONFIG_HOME` and `XDG_DATA_HOME` to writable directories
before invoking Godot. This is only a sandbox accommodation, not a game runtime
requirement. Use the existing checkout in each isolated cloud task; no Git
worktree is required.

## Known limitations and next steps

* No guns, enemy aircraft, damage model, multiplayer, campaign or complex menus.
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
place for future gun mounts and enemy aircraft without coupling them to input,
camera or HUD code.
