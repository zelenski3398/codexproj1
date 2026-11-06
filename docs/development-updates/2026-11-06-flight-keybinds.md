# 6 November 2026 — Restore F guns; Q landing flaps

Source: [`5dd8456c015a6d5b329841739b8c35d5ce015856`](https://github.com/zelenski3398/codexproj1/commit/5dd8456c015a6d5b329841739b8c35d5ce015856).

At the user's request, this supersedes the F-flaps / J-browser-guns mapping introduced in [the initial flight-device update](2026-11-06-flight-devices.md). **Q toggles landing flaps, F fires aircraft guns, B toggles fitted airbrakes.** Ctrl remains a firing alternative. Throttle W/S and ground wheel brakes Space remain unchanged.

Q had no existing project/script binding conflict. F and Ctrl now live in the shared `fire` input action for both local and browser builds. The redundant browser-only gun-key addition was removed. Aircraft still accept flap commands only while controlled; existing on-foot F command-post interaction and mounted B AA assistance remain scoped to their own controllers. The flight forces and aircraft equipment presets are unchanged.

Changed: [project.godot](../../project.godot), [HUD guide](../../scripts/hud.gd), [aircraft selection guide](../../scripts/aircraft_selector.gd), [browser support](../../scripts/web_support.gd), [device checks](../../tests/flight_devices_checks.gd), and the three browser smoke scripts for devices, combat and audio. README and [current device guide](../flight-devices.md) describe the corrected bindings. The initial dated report remains historical evidence of the mapping that was replaced.

Validation: four targeted Godot suites passed **145 assertions** (devices 24, keyboard 24, weapons 36, shared HUD 61). Matching Godot web export passed. The production-export Chromium device smoke check passed **7/7** with actual Q/F keyboard inputs; its final result is recorded in the accompanying [validation file](validation/flight-keybinds-2026-11-06.json). No human-flown session or full publishing-manifest rerun is claimed for this binding-only correction.
