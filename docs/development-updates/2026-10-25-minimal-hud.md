# 25 October 2026 — minimal HUD, contextual interaction and modal help

Source boundary: [`827bd9c0341181b22e8603921425c43fe937aea9`](https://github.com/zelenski3398/codexproj1/commit/827bd9c0341181b22e8603921425c43fe937aea9). Previous documented source: `5533313c0bab2d3f724657de828c85ca9148ca77`. The range includes documentation publication `5a3186a` and this UI implementation. The original history snapshot is unchanged.

## Evolution and implementation

The prior presentation combined a large flight masthead, pilot-notes paragraph, independent mission labels, recovery text and interaction instructions. [GameplayHUD](../../scripts/gameplay_hud.gd) now reads these existing systems into one anchored presentation: health upper left, objective tracker upper right, current contextual actions/instruments at the bottom and bounded temporary notifications. Free roam has no empty objective panel. All aircraft component-health colours remain available. Enemy widgets are moved clear of the objective panel.

The new F1 Controls & Help window has scrollable grouped bindings sourced from InputMap, a close button and Escape-first handling. It uses the existing SceneTree pause policy, restores the prior pause state and camera, and prevents gameplay shortcuts behind the overlay. Native gun capture is restored; web guns retain their existing click-to-recapture safety behaviour. F2 explicitly enables compact diagnostics. AA sensitivity and sight-mode settings remain in Pause.

Context actions derive from the existing occupied-object/nearest-interaction state each frame, without a cached old target. Mounting suppresses world entry hints; exiting reacquires a valid nearby object. Recovery keeps existing eligibility and shows pickup distance/bearing. T is offered only for an available harbour radio request. Right-click help distinguishes gun zoom, Bofors optics and heavy-command approximate area designation; no nonexistent aircraft action was added.

The [current guide](../minimal-hud-and-help.md) contains a changed-file table, controls, screenshots, a dependency diagram and a manual procedure. Old visual presenters remain hidden rather than rewriting their mission-state consumers. This is an explicit compatibility adapter and some duplicate hidden formatting remains technical debt. Reparented AA pause settings are freed with their owning mission.

## Three-minute interception deadline

The existing two checkpoints and final trigger are unchanged. `valletta.tres` and the resource default now set `deadline_seconds = 180`, with briefing/README updates and a 03:00 tracker countdown. Actual result resolution still uses the same deadline variable.

The old bomber route was paced by that same variable: simply doubling it would request an approach speed below its supported envelope and fail activation. The established 90-second physical approach is now separately named `approach_seconds`, preserving route, speed, release lead, spawn distance and bombing rules. **The bomber can still bomb before the three-minute result deadline if it is not stopped.** The extension gives more deadline time, including escort engagement; it does not postpone the existing bomber attack. This distinction is documented rather than describing the entire attack as a three-minute approach.

## Checks actually performed

Godot 4.6.3 Compatibility; production browser export using Chromium ANGLE/SwiftShader.

| Native suite | Assertions passed |
|---|---:|
| New minimal HUD/help | 61 |
| Interception | 78 |
| Pilot recovery | 70 |
| Airfield/vehicle controls | 61 |
| Dive defence | 47 |
| Harbour mission | 50 |
| Bofors predictor | 59 |
| Mission radio | 22 |
| Survival | 84 |
| **Total** | **532** |

- New checks cover free roam and every mission tracker, bounded supporting lines, checkpoint transitions, 03:00 activation, paused actual mission time, near/far/dead/mounted hints and F1/Escape transitions on foot, aboard aircraft, at a Bofors and in a truck. An explicitly positioned airborne fixture verifies that the aircraft transform is unchanged during Help. The Help test snapshots the hidden pilot after opening, because the existing survival controller synchronizes its position to the airborne cockpit. Invalid initial test-world/home combinations were corrected before the final clean run.
- Recovery and ground suites exercise the existing actual loss, sea rescue, replacement boarding, truck/gun transitions and running battle preservation. Interception checks retain real bomber flight, physical bombs, timer-expiry outcomes, deaths and retry.
- **Nine production browser checks:** no empty free-roam tracker/default diagnostics; real F1 help; correct help content; blocked boarding/spawn/engine/restart; Escape-first closure; boarding prompt clearing; visible close button after resize; restoring an already paused state; same world and no JavaScript/resource/engine errors. Browser flow includes real menu navigation, walking/aircraft states and 960×600 → 800×500 resizing. [Smoke tool](../../tools/minimal_hud_web_smoke.cjs).
- Native Compatibility captures were rendered and inspected at 1280×800 and a 960×600 viewport. This caught and corrected a clipped bottom health strip. Eight native/browser previews are linked from the guide or stored under `docs/previews/minimal-hud-*`.
- Final web export succeeded without script, shader or resource errors. One Mermaid diagram parsed; local Markdown targets, JSON and `git diff --check` were checked.

[Machine-readable validation](validation/minimal-hud-2026-10-25.json).

## Limits

No exhaustive human combat playthrough or test of every display resolution/remapped keyboard was performed. The browser flow covers walking and aircraft help; AA/truck modal behaviour was verified natively rather than claimed as browser-tested. Software native rendering reported texture allocations remaining at shutdown after image capture; the headless gameplay tests and production browser run had no script errors. Final export includes small subsequent presentation-only refinements; the full browser flow was not repeated for those. Live GitHub Pages deployment is not verified by a local export.
