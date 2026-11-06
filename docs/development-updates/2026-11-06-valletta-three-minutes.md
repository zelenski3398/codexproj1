# 6 November 2026 — three full minutes before Valletta bombing

Source: [`ee9a0af5bac0183a9ba647738217cc9561db651d`](https://github.com/zelenski3398/codexproj1/commit/ee9a0af5bac0183a9ba647738217cc9561db651d). Previous documented source: `e0e7ae069445eac65fc8c1c5ee5d59eb996d7dd9`; intervening `3afecf0` published the Hurricane documentation. The original complete-history snapshot remains unchanged.

## Problem and final change

The visible countdown already used `deadline_seconds = 180`, but the independently configured bomber approach still used `approach_seconds = 90`. The user confirmed that the desired change was **three minutes before bombing**, rather than another change to the displayed timer alone.

Both the resource and definition default now use a **180-second approach**. The two navigation checkpoints move to `(400,330,3400)` and `(-600,430,2500)` in the existing metre-based world. They remain near Ta’ Qali, on its western/northwestern side. This positions the activation area far enough from Valletta for the original bomber controller to cover a longer straight approach within its existing 48–80 m/s pacing envelope. Simply doubling the duration at the old insertion location would request an unsupported low approach speed and fail activation.

The final implementation does **not** modify `BomberPilot`, aircraft physics, terrain, geography, airfield positions, weapons or damage. The player still starts on foot, starts the engine manually and follows two terrain-checked airborne checkpoints. Activation still spawns exactly one SM.79 and one C.200, approximately 1,200 m away at one o’clock, with the existing one-shot warning/radio and player state preserved.

`VallettaInterception._resolve()` additionally requires `elapsed >= approach_seconds` before beginning bombing. Arriving slightly early in the generous release corridor therefore cannot shorten the player's three-minute window. The aircraft continues flying under its normal controller; it is not frozen or teleported. Existing deadline outcomes, enemy loss tracking, pilot death/crash handling, retry and return-and-land success presentation remain in place.

## Measured checks

Godot 4.6.3, 120 Hz fixed physics:

| Check suite | Passed |
|---|---:|
| Interception outcomes, real bomber flight and physical bombs | 83 |
| Uninterrupted Spitfire ground departure and bomber approach | 19 |
| Shared minimal HUD/help | 61 |
| Harbour mission regression | 50 |
| **Total** | **213** |

The ordered-checkpoint fixture measured:

- Player-to-bomber activation separation: **1,200.0 m**.
- Bomber release route: **10,727.29 m**.
- Actual release-corridor arrival: **179.408 s**.
- First physical bomb release: **180.000 s on the mission clock**.
- First bomb impact: **37.88 m** from Valletta's target.
- Minimum bomber terrain clearance: **386.75 m**.

The separate uninterrupted departure test uses ordinary engine, taxi, takeoff and flight controls, without pose/velocity resets between the hangar and checkpoint capture. It measured **77.45 s** and **4,746.72 m** from sustained liftoff to contact, **1,199.9999 m** activation separation, **59.88 m** formation height difference, a **10,454.73 m** bomber route and **179.392 s** bomber travel. The actual westbound navigation flight is longer than the former departure's approximately 42-second contact, while remaining within the existing two-minute/six-kilometre departure acceptance bounds. Ground/startup time remains untimed.

Explicit fixtures isolate player-state preservation, out-of-order checkpoints, outcomes, damage and crashes in the main suite. Enemy combat is disabled in the continuous-departure run solely to isolate navigation/timing. The tests verify no bombing before three minutes, no premature results after early kills, exact-deadline rejection, successful landing presentation, real falling bomb impacts, one-shot crash effects and a complete retry reset.

The bearing test now samples the player and bomber positions in the activation signal itself, so subsequent physical movement cannot distort the 30° assertion. Its strict bearing tolerance remains unchanged.

## Files

| File | Change |
|---|---|
| [valletta.tres](../../mission_definitions/valletta.tres) | Western checkpoint coordinates and 180-second bomber approach; deadline remains 180 |
| [interception_definition.gd](../../scripts/interception_definition.gd) | Matching exported approach default |
| [valletta_interception.gd](../../scripts/valletta_interception.gd) | No bombing before the full approach interval |
| [interception_checks.gd](../../tests/interception_checks.gd) | Actual timing/first-bomb assertions, early-arrival guard and event-time bearing snapshot |
| [interception_departure_checks.gd](../../tests/interception_departure_checks.gd) | Three-minute real-flight observation window and timing assertion |
| [minimal_hud_checks.gd](../../tests/minimal_hud_checks.gd) | Verify 180-second physical approach alongside the displayed 03:00 |
| [Current mission guide](../valletta-interception.md), [HUD guide](../minimal-hud-and-help.md), [README](../../README.md) | Current timings, route, evidence and source boundary |

[Machine-readable validation](validation/valletta-three-minutes-2026-11-06.json).

## Limits

No new human or browser playthrough, graphical screenshot or live Pages deployment verification was performed. Local web export was attempted but blocked before export because the installed Godot 4.6.3 lacks `web_nothreads_debug.zip` and `web_nothreads_release.zip` in its export-template directory. The existing publishing workflow installs matching templates; no workflow changes or successful deployment are claimed here. Historical 01:30 screenshots/reports remain explicitly historical.
