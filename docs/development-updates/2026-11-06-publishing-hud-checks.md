# 6 November 2026 — publishing blockers and complete-suite diagnostics

Source boundary: [`52a5e685f3bd5e8ec22e2fac234133b473726c31`](https://github.com/zelenski3398/codexproj1/commit/52a5e685f3bd5e8ec22e2fac234133b473726c31). Previous documented source: `ee9a0af5bac0183a9ba647738217cc9561db651d`; intervening `cb2cc25` published the three-minute interception report. The original complete-history snapshot remains unchanged.

## Reproduced cause

Two old assertions contradicted the shared minimal HUD:

1. `weapons_checks.gd` expected `FlightHUD.overlay` to be visible and titled DESTROYED. `GameplayHUD.suppress_legacy()` intentionally hides that old overlay. The baseline suite failed **35/36** at “Destruction displays 0 HP, destroyed message and reset controls.”
2. `malta_encounter_checks.gd` expected the old `EnemyEncounters.confirm_button` to be visible. The shared HUD intentionally hides it and provides its own button. The baseline failed **32/33** at “Visible spawn button explains the C alternative.”

Git trees for all seven screenshot commits — `20a4bb0`, `9b1264e`, `8355e4b`, `9fc1b43`, `f669525`, `3afecf0`, `cb2cc25` — were inspected and contain both obsolete assertions and the corresponding shared-HUD suppression. These are reproducible publishing blockers across that source range. **Individual remote run logs were not readable:** GitHub's Actions API returned Forbidden. This report does not claim to have read or confirmed the exact failing step in each remote run.

The previous workflow stopped at its first failing check, before export/artifact creation. Later pushes could therefore contain valid features without publishing them to the website.

## Final fix

- Weapons validation now checks the **visible shared** health/status/action controls, including zero HP, Destroyed, and the bound restart action, while verifying the retired overlay stays hidden. The standalone retained flight mode regains a concise Destroyed/Crashed status and Restart flight hint. Malta's independent living-pilot/recovery behaviour is unchanged.
- Encounter validation checks the visible shared confirmation button, its enabled state and current input binding, while the retired button remains hidden. The first confirmation is explicitly labelled **Spawn random enemy**; later confirmations retain **Spawn next enemy**.
- All **65 original Godot commands and flags** move unchanged, in order, to a canonical manifest. No test suite, assertion outcome rule, native display requirement or export/deploy dependency was removed.
- The publishing runner executes every suite and reports all failures. It saves per-suite logs, JSON results, a Markdown summary and file-specific GitHub annotations, with a failing exit status if any suite fails. Runtime GDScript errors also fail the runner when Godot exits zero.
- Each suite receives isolated temporary data/config/cache directories, preventing cross-suite preferences from contaminating results. The default execution remains serial. A timeout kills the suite's process group and remains a failure, not a skip.
- The workflow uploads `godot-check-logs` even when the check step fails. Its existing browser export, payload verification and Pages artifact/deployment dependency remain intact. A failed check still blocks publication.

## Files modified

| File | Purpose |
|---|---|
| [gameplay_hud.gd](../../scripts/gameplay_hud.gd) | Concise standalone loss/restart context and accurate initial spawn label |
| [weapons_checks.gd](../../tests/weapons_checks.gd) | Validate active shared loss UI |
| [malta_encounter_checks.gd](../../tests/malta_encounter_checks.gd) | Validate active shared spawn UI |
| [publishing_checks.json](../../tests/publishing_checks.json) | All 65 original commands, unchanged flags/order |
| [run_godot_checks.py](../../tools/run_godot_checks.py) | Isolated execution, failure propagation, timeouts, summaries and logs |
| [test_publishing_runner.py](../../tests/test_publishing_runner.py) | Four pass/error/timeout/reporting self-tests using isolated fake engines |
| [web.yml](../../.github/workflows/web.yml) | Run the manifest/self-tests and retain diagnostics on failure |
| [Hosting guide](../web-hosting.md), [mission guide](../valletta-interception.md), [README](../../README.md) | Current reproduction commands, payload size and validation/source boundary |

No aircraft physics, terrain, damage, gunner aiming, mission objectives, enemy spawning or three-minute interception timing changed in this repair.

## Complete validation

Godot **4.6.3**:

- **62/62 headless suites** passed using the new runner with three local workers and isolated settings.
- **3/3 native display suites** passed serially with Xvfb/Mesa Compatibility: intro playback **9/9**, AA mouse controls **32/32**, heavy command UI **8/8**. A matching Debian Xvfb package was extracted locally under `/tmp` for these checks; no project/runtime dependency was added. The existing GitHub native invocation flags were preserved.
- **4/4 Python runner self-tests** passed: a successful suite stays green, nonzero failures stay red, zero-exit GDScript errors stay red, and timeouts preserve a failed report. Synthetic tests write only their own temporary summary; they cannot pollute GitHub's real job summary.
- The manifest was compared against the pre-change workflow: **all 65 commands and argument lists match in order**.
- Official Godot export templates were downloaded and checked using the existing SHA-512-verifying installer. The complete production web export passed, with nonempty `index.html`, JS, WASM and PCK payloads. Total output measured **397,106,717 bytes**; PCK **358,939,096 bytes**.
- **9/9 production Chromium ANGLE/SwiftShader shared-HUD checks** passed: real menu/departure, F1 help, blocked gameplay shortcuts, Escape-first handling, boarding context, resized close button, restored pause state, preserved world and no JavaScript/resource/engine errors during that browser run.
- Python syntax/self-tests, JSON parsing, Markdown local targets and `git diff --check` were checked.

The [machine-readable validation](validation/publishing-hud-checks-2026-11-06.json) lists every executed Godot suite and result. [Current hosting/check instructions](../web-hosting.md#publishing-checks-and-failure-logs).

## Limits

The seven remote runs and live Pages deployment could not be inspected through the Forbidden Actions API. Local success is not a claim of successful remote deployment. The current fix must pass the new publishing run before the website updates. Existing native/headless resource-use-at-exit diagnostics remain in retained logs; this repair does not claim to resolve Godot shutdown resource warnings. No new manually flown combat session or full browser combat flight was performed.
