# 25 October 2026 — return and land before mission success

Source boundary: [`4f376d68bd90a2ad593301e453abe43bda756451`](https://github.com/zelenski3398/codexproj1/commit/4f376d68bd90a2ad593301e453abe43bda756451). Previous documented source: `827bd9c0341181b22e8603921425c43fe937aea9`. This range includes the previous documentation publication `20a4bb0` and the landing implementation. The original full-history snapshot is unchanged.

## Change and architecture

Previously, successful combat objectives immediately displayed results; Faith, Hope and Charity also queued its supplied congratulations recording immediately. [MissionReturn](../../scripts/mission_return.gd), owned by the existing MaltaMission, now holds success presentation while an airborne player returns and lands. The mission controllers retain their combat/outcome logic, but their success finalizers enter RETURNING instead of awarding results. Approval calls the original finalizer once after a safe landing. Failure and cancel paths invalidate the pending award.

Landing is physical and player controlled: no autopilot, teleport, repair, refill or scene reload is introduced. The same occupied, intact aircraft must settle on a friendly runway/apron with extended gear, at least two wheel contacts, speed at most 8 m/s, vertical speed at most 1.5 m/s and upright attitude for two continuous seconds. Pausing freezes settlement; renewed movement/contact loss resets it. Ground datum and footprint checks reject water, countryside and roofs. The home airfield is suggested, while another friendly airfield is accepted.

The shared HUD, navigation chart and gold world marker show the return destination and distance. Existing enemy next-stage confirmation is suppressed during return. The supplied harbour success recording and original results panel execute only after approval; no new speech is invented. Final Survival uses the same gate and now has a compact success panel. A pilot already safely grounded at a friendly duty station can finish immediately, so a ground AA victory does not force an artificial flight. Airborne AA fallback victories require landing. Free-roam repeat encounters remain unchanged.

Pilot/required-aircraft loss before landing fails the pending return. Existing harbour sea/fort-loss conditions still apply. Restart/menu exit frees the controller, clears radio/result latches and prevents an old deferred callback awarding a new mission. Existing combat timer, checkpoint, wave and aircraft controllers are preserved.

[Current guide, changed-system links, state diagram and manual test procedure](../mission-return-and-landing.md).

## Validation actually performed

Godot 4.6.3 Compatibility was used natively. The web fixture used Chromium ANGLE/SwiftShader and the actual supplied harbour congratulations recording.

| Native suite | Assertions passed |
|---|---:|
| New mission-return checks | 33 |
| Updated interception regression | 82 |
| Survival | 84 |
| Harbour mission | 50 |
| Dive defence | 47 |
| Minimal HUD/help | 61 |
| **Total** | **357** |

New checks verify unchanged aircraft state at activation, pending results/radio, guidance, duplicate callbacks, rejected fast/water/outside-base landings, pause, real suspension settlement, another friendly airfield, crash/death, retry, final Survival and ground/airborne AA outcomes. A disclosed short-final approach fixture uses ordinary elevator commands, aerodynamic forces, actual wheel touchdown and brakes to satisfy the return; no landed flag is set. The interception regression retains the real bomber approach and physical bomb/failure checks, and now requires landing in each successful airborne branch.

**Eight isolated browser checks passed:** success/radio remain pending in flight; tracker guides return; real suspension settles after the labelled landing-pose fixture; one result panel appears; the supplied congratulations recording starts; world identity persists; retry clears pending state; a subsequent return crash fails once without congratulations. The final assertion also checks no JavaScript/engine errors. This uses real production mission, flight, collision, radio and UI classes in a deliberately isolated harness; it does not claim the player fought all three formations in a production browser sortie.

Native and browser airborne/landed screenshots were inspected. The first rendered test teleport was overwritten by rigid-body synchronization, so the fixture was corrected to use the existing integration-safe pose/reset API. The native helper restores saved damage/fuel after setup and then waits for actual suspension/brakes; runtime return never invokes reset. The capture now asserts success before saving its landed image. The outdated browser fixture was stopped and rebuilt; its replacement passed 8/8.

[Browser return preview](../previews/mission-return-web-airborne.png) · [Browser landed results and congratulations](../previews/mission-return-web-landed.png).

Final production web export succeeded without shader/script/resource errors; tests and test buttons are excluded. One Mermaid diagram parsed, local Markdown targets and JSON were checked, and `git diff --check` passed. The final export includes two additional deferred-award safety checks after the browser fixture build; native checks passed with those checks in place.

[Machine-readable validation](validation/mission-return-2026-10-25.json).

## Limitations

No complete human combat-to-landing sortie, hardware performance benchmark or subjective speaker/audio-mix review was performed. The browser victory and landing positions are explicit fixtures, not automatic runtime gameplay. Native software rendering reported the known two texture allocations remaining at shutdown after successful screenshots. Live GitHub Pages deployment was not verified locally.
