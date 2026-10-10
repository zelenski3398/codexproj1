# Wings Over Malta: one continuous mission

Choose **MAP: COUNTRYSIDE · CHOOSE MALTA** on the startup aircraft screen.
The original countryside still uses **Fly** and its original immediate-flight
controls. Malta opens a north-up chart with **RAF Ta' Qali**, **RAF Luqa**, and
**RAF Ħal Far**. Click a field, choose a stationed aircraft, then **Depart**.
You appear beside that aircraft. All fields, islands and aircraft coexist;
travelling or switching aircraft never calls scene loading or mission reset.

## Board, fly and change aircraft

- On foot: **WASD** walks, **Left/Right arrows** turn, **E** boards the nearest
  serviceable stopped aircraft within 8 m.
- In the cockpit: **I** starts/stops the engine. **W/S**, arrows, **A/D**, **G**,
  **Space**, guns, damage effects and combat use the existing flight systems.
  Hold **Ctrl** to fire on desktop, **F** in the browser.
- Taxi left from the dispersal apron onto the runway using A/D, straighten
  before full power, then take off normally. Spitfire: 160–180 km/h; Sea
  Gladiator: 115–135 km/h. The graded strips can slope up to 2%.
- **M** opens/closes navigation without pausing flight. White arrow: your
  position and heading; gold ring: home field; red dot: a nearby enemy contact
  inside its detection range. Airfield markers are fixed in the same chart.
- After landing, brake below 1.5 m/s, reduce throttle to zero with S and stop
  the engine with I. **E** exits if there is clear ground beside the aircraft.
  Taxi near the destination's dispersal apron, walk to its other aircraft and
  press E. Neither aircraft is repaired or replaced by boarding.
- **Escape** pauses/resumes, including on foot. **R** explicitly restarts the
  whole Malta mission at the original home field with the original departure
  aircraft. This clears the fleet, enemy, bullets, wrecks, effects and damaged
  installations. The pause menu's **End mission / choose map** returns to
  countryside/aircraft selection. An aircraft change in Malta uses E, not this
  end-mission button.

## Geography and airfield placement

The supplied `terrain.glb` is copied byte-for-byte. Its bounds are approximately
X -19,404…15,888 m, Z -16,980…15,938 m, Y -30…250.865 m. This verifies a land
span of 35.292 × 32.918 km at **1 Godot unit = 1 metre**, without vertical
exaggeration. The artificial -30 m bottom cap is from the supplied model.
All 36 imported meshes, including Malta, Gozo, Comino and smaller islands,
retain their coordinates. X is east, Y up and -Z north; the origin is
longitude 14.4°, latitude 35.93° in EPSG:32633.

Terrain appearance uses an explicit shared Mediterranean landscape material on every
imported mesh, in both native and web builds, with all texture data bundled.
Embedded elevation colours are
retained as a deliberate **F4 debug mode**, labelled on screen and off at every
mission start. Material switching leaves vertices, elevation, transforms,
automatic LODs and collision intact. See the [landscape notes](malta-landscape.md)
and the [Commit 1 rendering diagnosis](malta-terrain-rendering.md).

The attachments contain a relief preview, not a historical airfield reference
map. The interactive chart is generated from the supplied OSM coastline with
that same projection. Initial locations are approximate site centres:

| Field | Longitude | Latitude | Prototype strip |
| --- | --- | --- | --- |
| RAF Ta' Qali | 14.4153 | 35.8953 | 1,450 m / 130° |
| RAF Luqa | 14.4775 | 35.8586 | 1,600 m / 140° |
| RAF Ħal Far | 14.5067 | 35.8153 | 1,400 m / 130° |

These are **not surveyed WWII runway coordinates, lengths, headings or
layouts**. External historical pages could not be accessed through the cloud
proxy. A supplied historical map can refine the configurable markers/layouts
without changing the coordinate system or creating additional terrain scenes.
Runway/apron decks are independently graded above sampled source heights so
landing gear cannot intersect the coarse terrain. They do not flatten or
alter the island mesh. This can create visible raised edges; it is a prototype
solution, not a reconstruction of wartime earthworks.

`MaltaGeography.chart_uv()` / `chart_to_world()` are the only chart transform.
Map bounds are [-21,000, -18,500]…[18,000, 17,500] in world X/Z. The full chart
shows aircraft outside the land coastline too; it does not restrict flight.
The sea display follows camera X/Z, with an infinite static water collision
plane. Water is currently a solid prototype collision surface; there is no dedicated
water impact, buoyancy or ditching system.

## Architecture, persistence and tuning

- `malta_world.gd`: one terrain instance, sea, light, landmarks and all fields.
  Imported automatic mesh LODs use bias 0.6; islands have individual bounds and
  per-island static concave collision BVHs built once. No collider unloading
  or streaming pauses. Terrain shadows are disabled; aircraft shadows remain.
  Chase/ground cameras have a 100 km far plane. The original coarse mesh is
  already 152k triangles; there is no full-detail city/building population.
- `malta_airfield.gd`: graded collision strips/aprons, parking poses, pilot
  spawn and damageable hangars. Labels cull at 700 m; hangars at 4.5 km.
- `malta_mission.gd`: persistent fleet, safe boarding/exiting, navigation and
  explicit restart. Aircraft always keep their original health, component
  damage, fuel hazards, engine setting, bullets and physics state. Unoccupied
  planes use zero throttle, disabled player input and wheel brakes. They still
  have physics and can receive damage. Destroyed planes cannot be boarded and
  never respawn automatically. Hangar destruction leaves colliding ruins.
- `ground_pilot.gd`: collision-driven walking and a collision-aware camera.
- `malta_departure_menu.gd` / `malta_chart.gd`: shared airfield/chart UI.
- Minimal additions to `aircraft.gd`: input routing, engine-on thrust gate and
  configurable normal fuel consumption. Aerodynamic and landing equations
  are retained. Countryside and Stuka retain engine-on/default-zero-normal-
  consumption behaviour; Malta's fleet consumes one full tank in two hours at
  full throttle, plus existing component leakage/burning. Fuel is normalized,
  not litres; there is no refuelling/repair service or mission save file.
- Enemy AI retains its existing physical pilot and guns. Malta uses real
  terrain ray heights, safe airborne spawn, local patrol centre and no 5 km
  countryside boundary. Established pursuit can extend across the island
  world. While the pilot is on foot it patrols with no active player target;
  boarding updates the target without respawning/resetting the enemy.

Edit `assets/malta/world_data.json` for field coordinates, strip lengths,
headings, slopes, elevations and stationed aircraft (`spitfire`,
`sea_gladiator`). Every stationed slot receives a parking pose. If you change
geometry or headings, rerun `tools/prepare_malta.py` and inspect grading.
The optional offline chart/data generator uses pyproj, shapely, Pillow and
numpy; these are not runtime/game dependencies. The original DTM, coastline,
metadata and generator remain under `assets/malta/source/` for attribution
and reproducibility. See `assets/malta/ATTRIBUTION.txt`.

## Validation

Run:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script tests/malta_checks.gd
godot --headless --path . --fixed-fps 120 --script tests/malta_journey_checks.gd
bash tools/build_web.sh
node tools/web_smoke.cjs
node tools/malta_web_smoke.cjs
```

**559/559 existing native regressions**, **35/35 Malta integration checks**,
**18/18 uninterrupted journey checks**, **31/31 complete Chromium release checks** and **10/10 focused current-release
Malta browser checks** passed without Godot/JavaScript runtime errors.

The integration test exercises real menu events, parked gear contacts,
walking/boarding, engine and throttle keys, chart alignment, takeoff,
slope landing/brakes, persistent aircraft changes, destruction and clean
restart. It uses disclosed takeoff/landing/walk-position fixtures for individual
scenarios. The separate journey test uses normal pilot commands for taxi,
takeoff, flight over Valletta/Grand Harbour, approach, landing, dispersal,
walking to a replacement and second takeoff, with **no pose/velocity fixtures,
teleports, resets or environment replacement** after the initial spawn.
The full ten-step acceptance sequence passed, including physical taxi, walking,
boarding the replacement Sea Gladiator and a second takeoff in the same world.
Its scripted autopilot disables enemy combat to isolate route/landing safety;
combat is checked independently by the existing suites.

For a manual acceptance flight: depart Ta' Qali beside a Spitfire, E board,
I start, taxi and take off. Use M to head east to Valletta/Grand Harbour, then
south to Ħal Far. Land, taxi to dispersal, stop/throttle idle/engine off, E exit,
walk to the Sea Gladiator, E board, I start, taxi and take off. Damage the first
plane using H/F3 before leaving; reboarding it should show that damage. Check
that the home marker stays Ta' Qali while the position arrow moves.

Manual flight feel, a full keyboard-flown ten-step journey, browsers other
than Chromium and representative consumer-GPU frame rates remain unverified.
The map is geographically continuous, but distant urban scenery, historical
1940–42 terrain, detailed harbour structures, seamless object streaming,
refuelling and saved persistence across game restarts are not implemented.
