# 9 November 2026 — A short walk from Gladiator landing to Spitfire

Source: [`4f9e676be7a69a1f1b1f64493836b433fbbbdaf0`](https://github.com/zelenski3398/codexproj1/commit/4f9e676be7a69a1f1b1f64493836b433fbbbdaf0), `fix(tutorial): guide Gladiator return to a nearby Spitfire handover stand`. Previous documented source `8a68e0c`; intervening `3229b03` publishes its documentation.

## Problem and behaviour

The original tutorial accepted a stopped landing anywhere on Ta’ Qali's runway/apron, then immediately asked the pilot to exit. The assigned Spitfire remained inside the hangar, potentially leaving a long walk from the far runway end.

The return now guides the Gladiator into a **gold runway landing sector**, approached from the southeast toward the hangars. After landing, a new **TAXI_HANDOVER** phase guides the still-occupied aircraft to a **green parking circle outside the Spitfire's hangar**. Only grounded, settled parking there unlocks shutdown and exit. A safe landing elsewhere on the home strip still counts as the landing, but the pilot must taxi to the stand; the tutorial does not demand another takeoff or move either aircraft.

The target uses the actual Spitfire stand and existing airfield transform:

- Landing sector 240 m long / 46 m wide; centre 250 m before the Spitfire's local-Z position, allowing rollout toward the apron.
- Parking circle at airfield-local X=61 m, aligned with the Spitfire's local Z; radius 8 m.
- Existing Ta’ Qali stand measured at local `(61,0,418.494)`; landing centre approximately `(0,0,168.494)`.
- Stand centre to actual parked Spitfire: **32.037 m**.
- Parking requires at most 1.5 m/s, at least two grounded wheels/upright landing validation, circle occupancy and at most 45 m horizontal distance to the Spitfire, held for two seconds.
- Taxi markers use the central gap in the AA line at local Z=`runway_length * 0.31`; a direct runway-to-stand line would pass through an existing gun emplacement. The route crosses through the gap, then follows the apron to the stand, clear of the X=78 vehicle lane and hangar frontage.

The first-Gladiator exit check now refuses early runway dismount with a specific instruction to reach the green stand. It rechecks proximity in SHUTDOWN; drifting out resumes taxi guidance. An engine too damaged to taxi (power factor below 0.15) instead offers **FIRST_RECOVERY**, an explicit safe exit/V truck request using existing recovery. This prevents the new parking gate from trapping a surviving pilot in a disabled aircraft. The ordinary recovery eligibility rules, other modes and the second emergency-exit lesson are unchanged.

## Files

- [tutorial_definition.gd](../../scripts/tutorial_definition.gd): exported sector size/rollout, apron X, parking radius/speed/walk/power limits.
- [tutorial_mission.gd](../../scripts/tutorial_mission.gd): derived landing/parking positions, non-colliding unlit overlays, stage-specific map/3D labels, taxi waypoints, settled handover, safe-exit and disabled-engine recovery branches.
- [malta_mission.gd](../../scripts/malta_mission.gd): tutorial-scoped exit guard and current navigation label. Generic shutdown, safe dismount and ordinary mission behaviour remain intact.
- [tutorial_checks.gd](../../tests/tutorial_checks.gd): far-runway exit rejection even after engine shutdown, correct sector bounds, short stand distance, clear crossing, settled parking, actual pilot exit distance and disabled-engine pickup coverage; the remaining tutorial/retry sequence still runs.
- [Current lesson guide and diagram](../tutorial-flight-school.md), README, journal/state and this report document the changed return sequence. Terrain, airfield placement, aircraft spawning and physics are unchanged.

## Validation

Four targeted suites passed **160 assertions**: tutorial progression **53/53**, actual engine-out glide **1/1**, shared mission landing/return **33/33**, and pilot recovery **73/73**. The progression suite uses setup poses between flying stages; it does not claim to have flown the whole landing/taxi route. The actual safe-exit check confirms the pilot is within 55 m of the Spitfire after dismounting. The damaged second-aircraft glide still lands at Luqa and retains 45 HP / zero engine power.

Matching-template Godot 4.6.3 web export passed. A temporary Xvfb/llvmpipe Compatibility capture rendered both new marker phases and measured the placement above. [Native landing-sector capture](../previews/tutorial-handover-landing.png) is a debug view, not a screenshot of a human-flown landing. That capture exited successfully but printed two GL texture-leak diagnostics on shutdown; those diagnostics were not resolved in this change. No GDScript errors were observed in the targeted checks.

[Machine-readable results](validation/tutorial-handover-2026-11-09.json) retain the source boundary and measured scope. Documentation links and whitespace checks passed. A full human landing/taxi playthrough, browser flight validation of these new markers, and live deployment success remain unverified locally; no full 68-suite rerun is claimed.
