# Flaps, dive brakes and deceleration

Q toggles landing flaps; B toggles dedicated airbrakes where fitted. W/S still controls throttle; Space operates wheel brakes **only through tyre contact**. Aircraft guns use **F**, with Ctrl retained as an alternative on both native and web builds. F remains command-post interaction on foot and B remains AA assist while mounted: only the occupied aircraft accepts aircraft device commands. F1 / pause Controls & Help lists the bindings.

## Physics audit and implementation

[`FlightAircraft._integrate_forces`](../scripts/aircraft.gd) already used Newton forces on a kilogram/metre/second RigidBody3D: thrust was proportional to throttle, became zero at zero throttle, and never imposed a minimum flying speed. The existing stall-speed value is a warning threshold, not a velocity floor. There was no idle/windmilling propeller drag term; the existing damaged-propeller drag only addressed component failure. Gear drag was a literal coefficient. These observations do not establish a universal cause for every reported approach problem.

The repair adds configurable healthy-propeller drag, strongest at idle or engine-off, fading quadratically with throttle. It fades with component power integrity so the existing damaged-propeller penalty takes over instead of stacking two full propeller penalties. It also exposes the existing gear drag coefficient. Full-throttle thrust, mass, torques, suspension, weapons, component health, gear mechanics and mission rules are retained.

Air-relative velocity is `state.linear_velocity - wind_velocity` (default wind zero). Drag is applied once as `-air_direction * 0.5 * density * airspeed² * wing_area * total_Cd`. The total combines base, induced, stall, component, gear, device and propeller contributions. No flap/brake command sets body speed, position, altitude or acceleration directly. Godot integrates Newton forces; no extra timestep is multiplied into them.

Flaps add to the lift coefficient and its positive maximum, as well as adding profile drag. Lift still follows forward dynamic pressure, angle of attack, wing integrity and the existing post-stall fade. The stall warning threshold scales with maximum lift; full default flaps change a healthy Spitfire's warning threshold from 32 to about 28.62 m/s. They do not guarantee flight at that speed or remove the angle-of-attack stall. Retraction removes the additional lift gradually.

Airbrakes add drag with no added lift. The drag acts against actual air-relative motion, including a downward component in dives. Gravity remains active: a steep dive can accelerate despite brakes. A lower sink rate is not an altitude hold, and speed brakes do not guarantee a shallower glide angle.

[`FlightDevices`](../scripts/flight_devices.gd) owns targets, ratios, notices and visual hinges; only FlightAircraft owns flight forces. Ratios move toward targets using physics seconds. Overspeed flap-extension requests are rejected with **FLAPS OVERSPEED**; retraction is always allowed on a living aircraft. Already deployed flaps also show the warning above their operating limit; there is no new overspeed breakage simulation. Death/crash rejects commands and freezes hinges at their last deployment; reset restores retracted ratios, targets and warnings.

## Aircraft equipment and configuration

| Aircraft | Landing flaps | Dedicated airbrakes | Landing angle / request limit |
| --- | --- | --- | --- |
| Spitfire Mk I | Yes, split-flap-inspired panels | No | 85° / 70 m/s (252 km/h) |
| Hurricane Mk I | Yes | No | 80° / 67 m/s (241 km/h) |
| Sea Gladiator | No | No | N/A |
| Ju 87-inspired Stuka | Yes | Yes, slatted dive-brake panels | 40° / 60 m/s (216 km/h) |
| Fiat CR.42 | No | No | N/A |
| Macchi C.200 / C.202 | Yes | No | 40° / 65 m/s (234 km/h) |
| SM.79 | Yes | No | 40° / 65 m/s (234 km/h) |

These are suitable **gameplay presets for the existing procedural aircraft**, not certified flight-manual limits or a new identification of an exact Ju 87 subvariant. The equipment distinction avoids silently giving fighters Stuka dive brakes. Existing meshes are original simplified placeholders, not supplied rigged production models. Hinged underside panels extend existing wing edges; the Stuka and Hurricane use positions adjusted to their wing geometry. The original continuous wing meshes are not cut or re-skinned. Remaining close-up visual overlap and exact historical surface outlines need human art review.

For other aircraft, exported `gameplay_airbrake_assist` defaults **false**. Enabling it explicitly adds an ahistorical slatted brake panel and the same aerodynamic brake; the HUD labels it **(assist)**. Normal gameplay does not enable this option. The comparison fixture explicitly enables it to test both devices on one consistent airframe.

Shared exports in FlightAircraft, under **Landing devices and deceleration (SI units)**:

| Setting | Default | Meaning |
| --- | --- | --- |
| `flap_retracted_degrees` | 0 | Visual hinge at physical retraction |
| `flap_lift_coefficient` | 0.45 | Additional lift coefficient / maximum at full deployment |
| `flap_drag_coefficient` | 0.14 | Added full-deployment Cd |
| `flap_deploy_seconds` | 2.5 s | Full extension/retraction duration |
| `airbrake_drag_coefficient` | 0.50 | Added full-deployment Cd |
| `airbrake_deploy_seconds` | 1.2 s | Full extension/retraction duration |
| `gear_drag_coefficient` | 0.026 | Extended-gear Cd, preserving old default |
| `idle_propeller_drag` | 0.022 | Healthy idle/windmilling prop Cd |
| `ai_dive_brake_deploy_speed` | 80 m/s | Stuka AI deploy threshold |
| `ai_dive_brake_retract_speed` | 70 m/s | AI hysteresis threshold / energy reserve |
| `wind_velocity` | (0,0,0) m/s | Optional world-space air motion |

Equipment availability, angles and operating speeds are independently configurable. Hurricane settings live in [its scene](../aircraft/hurricane_mk_i.tscn). Italian settings, including independent lift/drag/deployment/gear/prop coefficients, live in [EnemyAircraftDefinition](../scripts/enemy_aircraft_definition.gd) and each [aircraft definition](../aircraft_definitions). The Gladiator and Stuka set their equipment presets alongside their existing subclass airframe tuning.

Enemy device decisions call the **same commands and ratios**: normal manoeuvres retract them; low, slow damaged emergency approaches can request available flaps; DiveAttackPilot's DIVE phase requests brakes only above the configurable speed thresholds and retracts for recovery. No new AI force or position correction is added. Initially braking throughout the dive caused a failed pullout in the regression test; retaining 70–80 m/s through hysteresis fixed that without altering elevator physics or masking the failure.

## HUD

The existing compact instrument line retains airspeed, AGL, throttle, gear and fuel and adds flap/airbrake deployment percentages or N/A. Health, component bars and stall warnings remain. Device notices use the shared transient notification; active flap overspeed has warning priority. Instructions are in the existing separate Controls & Help view, which pauses the tree and blocks device commands.

## Repeatable verification

1. Run `godot --headless --path . --fixed-fps 120 --script res://tests/flight_devices_checks.gd`. Repeat with `-- --hz60` for a 60 Hz physics timestep.
2. For a manual comparison, use the same altitude, mass, gear, heading and 65 m/s start; set idle and compare retracted, flaps, explicit assist airbrakes, then both. Keep attitude similar; do not compare a climb with a dive. Record actual speed over six seconds. Use a Stuka for equipped dive brakes.
3. Below operating speed press Q: observe gradual panels and percentages, slower approach and added lift. Retract at low speed: lift reduces; sufficiently low speed or high angle of attack still stalls. Above the limit, extension is refused with FLAPS OVERSPEED.
4. At idle in a dive, compare B retracted/deployed: physical drag reduces speed relative to the clean case. Start a sufficiently steep dive slowly: gravity can still accelerate it.
5. Hold Space while airborne: it must not change aerodynamic deceleration. Land with gear down and hold Space: tyre friction stops the plane. Take off again.
6. Open F1 while deploying: simulation pauses, Q/B do not issue commands; close and deployment resumes. Verify AA/post F/B bindings separately remain scoped to occupied equipment.
7. Destroy and reset: no new deployment commands on the wreck; reset returns all surfaces to zero. Confirm health, guns, gear and AI still operate.
8. Export with `bash tools/build_web.sh`; run `NODE_PATH=<Playwright module directory> node tools/flight_devices_web_smoke.cjs`. It uses actual browser menu/keyboard inputs and read-only telemetry.

Measured outcomes and the exact tested limitations are recorded in the [development update](development-updates/2026-11-06-flight-devices.md). Automated simulation is not a claim of a human-flown approach or a verified historical flight envelope.
