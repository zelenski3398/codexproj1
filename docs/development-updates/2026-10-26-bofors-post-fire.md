# 26 October 2026 — direct Bofors battery fire and optional assist

Source: [`9542c5944ae863b43fc48030edce09cec06e2e2f`](https://github.com/zelenski3398/codexproj1/commit/9542c5944ae863b43fc48030edce09cec06e2e2f). Previous documented source: `9fc9a131afc6a532dd15c0dea5ad6e6b71545a03`; intervening `9fc1b43` published the AA HUD report.

## Observable change

Previously `BoforsCommandPost.fire_round()` always returned false and `drive_gun()` was a no-op. This was an observation-only design: LMB acquired a contact and the player then had to dismount and operate an individual gun. The user explicitly requested firing connected guns from the post and a switchable aim assist.

The occupied post now connects its existing `battery_guns` through the existing `command_station` relationship. Mouse optics supply manual sight laying; only the player's held trigger authorizes connected guns to shoot. Every gun rotates at its existing traverse/elevation speeds and fires through `BritishAAGun.fire_round(true)`, preserving real muzzle origins, gravity, swept collision, friendly obstruction, dispersion, effects, damage, unlimited ammunition and independent 0.5-second reload. No target damage is applied by the post.

**Default assist OFF:** each selected gun converges toward the player's sight ray, stopping at terrain or a configurable 1,500 m point. No enemy selection, velocity lead or drop compensation is inserted into this manual solution. Gun elevation limits and alignment tolerance still apply; aim into the sky before firing.

**B toggles assist ON:** Tab explicitly selects a currently visible enemy; Enter assigns it to the selected gun/battery. Connected barrels follow their own existing predictor solutions, using measured target position, estimated velocity, shell speed, gravity and flight time. Invalid, stale, out-of-range, unassigned or impossible solutions cannot authorize assisted fire. This deliberate post-level assistance is separate from the existing saved Manual/Assisted/Training sights for individually mounted Bofors.

LMB is now a continuous player fire command, replacing post-level LMB acquisition. Target selection remains Tab. G selects one gun or the battery. A mode/scope change cancels held authorization and requires release before firing again. Pause/Help, pointer-lock recovery, exit, player death, post destruction and mission end retain existing safety gates. Destroyed guns cannot participate; a destroyed post does not change surviving gun HP. Dismount disconnects gun drives and firing, while the observer may maintain the already assigned contact for individual sights. No unoccupied post selects targets or starts firing.

## Controls and modified files

- **F:** enter/exit nearby post; **E** also exits.
- **Mouse:** aim; **hold LMB:** fire connected guns; **RMB:** binocular zoom.
- **B:** battery aim assist on/off (off in a fresh session).
- **Tab:** select visible target; **Enter:** assign for assisted lead; **G:** gun/battery scope.
- **F1 / Pause → Controls & Help:** detailed controls; pauses simulation and blocks firing.

[Current guide and architecture diagram](../bofors-command-post.md).

| File | Change |
|---|---|
| [bofors_command_post.gd](../../scripts/bofors_command_post.gd) | Player trigger, manual convergence, optional measured lead, scope, safety gates and concise status |
| [gameplay_hud.gd](../../scripts/gameplay_hud.gd) | Contextual LMB/B actions and revised Help; existing shared minimal layout retained |
| [bofors_battery_fire_checks.gd](../../tests/bofors_battery_fire_checks.gd) | New battery-fire regression suite, plus Godot UID |
| [bofors_predictor_checks.gd](../../tests/bofors_predictor_checks.gd) | Replace obsolete observation-only assertion; check impossible solutions in assisted mode |
| [web.yml](../../.github/workflows/web.yml) | Run the new battery suite during publishing |
| [bofors_predictor_web_smoke.cjs](../../tools/bofors_predictor_web_smoke.cjs) | Use the current shared-HUD predictor entry text |

Tuning is exported on `BoforsCommandPost`: `manual_sight_range`, `battery_aim_assist`, inherited `firing_tolerance_degrees`, and existing observation range/interval, lost-track timeout, settling time and measurement error. Gun traverse/elevation, reload and dispersion remain in existing weapon resources. No meshes, audio or damage assets changed.

## Checks performed

Godot 4.6.3, headless suites:

| Suite | Assertions passed |
|---|---:|
| New battery firing | 22 |
| Bofors predictor | 59 |
| AA HUD context | 27 |
| Shared minimal HUD | 61 |
| Dive defence | 47 |
| Heavy battery command | 36 |
| **Total** | **252** |

The new suite exercises normal post entry, no unsolicited fire, actual two-gun projectile creation, existing reload rate, trigger release, individual scope, actual B input toggling, missing/assigned target gating, assisted firing, Help and held-trigger cancellation, dismount, gun/post destruction, mission end and retry. The headless backend cannot capture the mouse, so its existing common `fire` action exercises the same sampled trigger; a separate native-window Compatibility run passed the original **18/18 core cases** using `aa_fire` with pointer capture. That run used `--no-render-loop` to check controls without an expensive full-world render; it is not a visual combat playthrough. The expanded destruction/mission-end/retry cases are included in the 22-case headless run. Mesa reported texture-allocation leaks during native-process shutdown.

Web export succeeded without script/resource errors. The browser smoke helper's JavaScript syntax and the guide's Mermaid diagram were checked. This update does **not** claim a fresh interactive browser battery battle, human combat balancing, exhaustive field-of-fire testing at every post, or live Pages deployment verification. Existing St Elmo muzzle-clearance checks remain in force, so a gun behind masonry may correctly refuse a shot until laid clear of it.

[Machine-readable validation](validation/bofors-post-fire-2026-10-26.json).

## Manual acceptance test

1. Walk to a Bofors post and press F. Aim above the horizon. With assist OFF, hold LMB and confirm all selected operational barrels fire; release to stop.
2. Press G to isolate one gun and repeat. Watch its normal reload; the other guns must stay silent.
3. Press B, select an approaching aircraft with Tab and assign with Enter. Wait for a lead solution, hold LMB, then compare to assist OFF. Barrels must traverse smoothly rather than snap.
4. Open F1 while holding fire. Close it: no shot should occur until fire is released and pressed again.
5. Exit, destroy a connected gun, destroy the post, end the mission and retry. No stale firing orders should survive; individual surviving guns remain mountable.
