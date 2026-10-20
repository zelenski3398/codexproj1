# 20 October 2026 — harbour boarding, balance, wreck fires and Bofors assist

Previous source boundary: [`8f01e46`](https://github.com/zelenski3398/codexproj1/commit/8f01e46f43ed77c33847f5bc0c2e6456a8333a14). Current source boundary: [`eb17dfe2b8e60c92d08386c33d84b83afe291743`](https://github.com/zelenski3398/codexproj1/commit/eb17dfe2b8e60c92d08386c33d84b83afe291743). The intervening `2d1866c` publication records the previous recovery work; it adds no further gameplay.

The range contains `ea659e7` (gameplay fix, current guides, native tests and browser fixture) and `da4530b` (browser fixture waits for the mission picker before selecting the final item). The latter changes test input timing, not game controls. `eb17dfe` adds lingering land-wreck fire, the Bofors option and normal harbour enemy balance, and corrects the popup test to focus the third menu item with three Down presses (the initial keyboard focus is empty).

## Verified changes

- [ChaseCamera._physics_process](../../scripts/chase_camera.gd) formerly cast its floor ray from 200 m above the eye. Inside a hangar this found the roof and lifted the eye above it, despite the separate aircraft-to-camera obstruction sweep. The ray now starts at the resolved eye and checks downwards. Existing wall/terrain sweep, following distance, smoothing and aircraft physics remain unchanged.
- [MaltaMission._ready](../../scripts/malta_mission.gd) overrides only the harbour mission's home roster with three Sea Gladiators. They use the first three existing separated hangar stands, engines stopped. Shared airfield records and the other bases' mixed fleets remain intact. Hope and Charity remain the existing separate AI wingmen with their original runway holds and radio behaviour; the additional hangar aircraft are boardable player replacements.
- [HarbourInterception._player_crashed](../../scripts/harbour_interception.gd) observes real crash signals from the player-available fleet. A crash in the currently occupied aircraft with `impact_effects.water` set latches mission failure, resolved through the existing deferred result path. It does not fake pilot death or alter splash/sinking physics. Unoccupied/friendly/enemy water losses do not trigger this player-specific rule. Retry constructs a new director with a clear latch. Survivable land losses and sea rescue in other modes retain their existing rules.
- [CI workflow](../../.github/workflows/web.yml) includes the new regression suite. The [mission guide](../harbour-interception.md) and [recovery guide](../pilot-survival-and-recovery.md) distinguish the explicit harbour sea-loss exception from independent pilot health.

## Further requested combat changes

- `HarbourDefinition` supplies separate normal escort error, dispersion, reaction and burst settings. `HarbourInterception._spawn_wave` applies these only to non-aces, and selects the existing Cadet human gunner profile for normal bombers. The ace branch and ordinary CR.42 projectile damage/rates remain unchanged.
- `BoforsAimAssist` finds a visible hostile near the mounted sight at a throttled interval, solves physical lead with `AAFireControl`, and gently adjusts the existing mouse target within exported limits. A saved pause-menu checkbox defaults off. It does not fire, bend shells or operate empty guns. Heavy guns/predictor stations retain manual controls.
- `AircraftImpact.start_ground_fire` and `WreckFire` add one terrain-supported, world-owned presentation per fueled land wreck, capped at four effects, 75 seconds and sixteen retained real mesh fragments per wreck. It survives enemy cleanup, fades and clears on retry; water and fuel-empty wrecks are excluded. No second damage, explosion or kill event is applied.

[Controls, tuning, native preview and manual procedure](../wreck-fire-and-bofors-assist.md).

## Validation

Five headless Godot 4.6.3 suites passed **188 assertions**:

| Suite | Passed | Coverage |
|---|---:|---|
| `harbour_hangar_checks.gd` | 24 | All three interior camera positions, useful view distance, boarding/dismount, fleet scope, real water impact, single result, retry |
| `flight_checks.gd` | 35 | Existing flight/landing/takeoff and recovery of a camera placed below terrain |
| `harbour_checks.gd` | 50 | Mission waves, combat, outcomes and teardown |
| `pilot_recovery_checks.gd` | 70 | Independent pilot life, land recovery and other modes' surviving sea recovery |
| `harbour_departure_checks.gd` | 9 | Normal boarding/engine input, taxi out of hangar, runway alignment, takeoff and first wave activation |

The boarding suite was also run with native Compatibility rendering and its interior view inspected. [Native boarded view](../previews/harbour-boarding-interior.png). The rendered run passed its then-current 18 camera/roster assertions; the expanded 24-assertion suite additionally covers water loss headlessly. Four existing llvmpipe texture-cleanup diagnostics occurred at native shutdown, after capture; they are not shader failures. The web export completed without script, shader or resource errors.

Five production-browser checks passed using real menu and E inputs: mission selection, serviceable hangar fleet, boarding, dismount and no JavaScript/WebGL/HTTP/resource errors. The [browser boarding screenshot](../previews/harbour-boarding-web.png) was inspected and remains inside the hangar. The final export after the battery-station guard also completed successfully. The browser test did not exercise assisted firing or a full combat sortie.

The expanded focused regression set passed **524 assertions across 13 suites**: the five suites above plus support/assist/balance (24), aircraft impact (20), universal damage (113), dive defence (47), flak damage (9), layered AA (55), battery command (36) and native mouse tracking (32). Final suite logs contain no script errors or failed assertions. The initial battery regression exposed a null assist helper on its predictor station; the shared mouse sampler now guards that optional helper, and the rerun passed without script errors. Native mouse tracking includes actual relative mouse events through a Stuka approach, dive and withdrawal for both gun types. New assist acquisition/lead/caps/friendlies/obstruction and physical shots are tested in the support suite; these are automated fixtures, not human combat evaluation. [Machine-readable results](validation/harbour-support-2026-10-20.json).

Two Mermaid diagrams in the current mission guide parsed successfully; updated guide links and `git diff --check` passed. This is focused regression validation, not a complete manual three-wave combat sortie or a hardware performance benchmark.

## Manual check

1. Select **Missions → Faith, Hope and Charity → Depart**. Confirm three Gladiators in the departure hangar and no parked Spitfire there.
2. Press **E** beside Faith. Look toward the doorway: the camera must remain under the roof. Exit and board either spare to repeat.
3. Start with **I**, taxi and take off normally. Hope/Charity should retain their takeoff and radio behaviour.
4. Crash the occupied aircraft into exposed sea. Expect one **MISSION FAILED** result. Retry must restore the three hangar Gladiators and clear the result, water-loss flag and waves.

The [original history](../WWII-Malta-Development-Complete.md) remains frozen at its original snapshot. Future updates start after the source boundary recorded above.
