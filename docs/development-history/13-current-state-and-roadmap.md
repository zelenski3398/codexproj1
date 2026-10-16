# 13 — Current state, technical debt and recommended next work

[Contents](README.md) · [Validation](validation.md)

**Snapshot:** [588ac7b](https://github.com/zelenski3398/codexproj1/commit/588ac7b1b37b72014b73fe679871e790e5c79145). “Verified in source” below means the code/resource and its active caller were inspected. It does not claim that every path was interactively exercised during this audit.

## Implementation classification

| System | Classification at snapshot | Evidence and boundary |
| --- | --- | --- |
| Shared aircraft lift/drag/thrust, gear and controls | Implemented, source verified; interactive regression still needed | `FlightAircraft`, `PilotInput`, `LandingGear`; original/current test suites exist |
| Spitfire/Sea Gladiator selection | Implemented, source verified | `AircraftSelector`, two runtime subclasses; not all enemy models selectable |
| Stuka / Italian aircraft and shared damage | Implemented, source verified | `EnemyAircraft`, `ItalianEnemy`, six component profiles |
| Human-limited rear gunner | Implemented, source verified; current balance needs playtesting | Observation/skill/motion/clearance code and telemetry |
| Malta continuous travel and fleet boarding | Implemented, source verified; historical journey tests reported | One `MaltaWorld`, all fields together, no travel reload |
| Saved campaign/world persistence | Not implemented | State is scene-owned during a run; only user audio/AA settings persist to config |
| Encounter replacements and Survival | Implemented, source verified | Explicit confirmation, active destruction events, stages 1/2/2/3/3 |
| Italian interception | Implemented, source verified | Two nearby checkpoints, 1,200 m, right 30°, 90 s; timer-end outcomes |
| Dive-defence mission | Implemented, source verified | Six waves/ten attackers, vulnerable operator, ordnance draining |
| Abstract mission base HP | Not found in the inspected directors | Individual guns/pilot/installations have HP; no general base-health pool wired to outcomes |
| Manual heavy AA / Bofors / post | Implemented, source verified; interaction/performance review remains | 18 guns, three posts, current infinite autoreload; physical shells |
| Autonomous friendly AA | Removed/replaced | Introduced `6a36276`, removed `5bbf563`; coordinated firing requires player orders |
| Bofors finite stock/clip state | Removed/replaced | Introduced `2157b72`, removed `e26e5ed`; no loader crew implemented |
| Military truck | Implemented, source verified | Kinematic driving/collision/exit; no HP/fuel simulation |
| RAF pilot | Implemented model/Idle/Walk/Seated; entry animation partial | Skinned asset and seating wired; no climb-in/out clips or active first-person flight view |
| Terrain materials/debug | Implemented, source verified | Bundled normal landscape override; F4 heatmap default off |
| Roads and runway terrain integration | Implemented mechanically, geography approximate | Local grading and road UV masks; historical scan alignment is uncertain |
| Valletta / Mdina | Implemented additive approximate scenery | Generated visual/structural GLBs and runtime `HistoricCity` callers; no verified survey reconstruction |
| Cottonera / Three Cities | **Partially implemented preparation, awaiting geodata** | Empty region manifest; templates/import/compiler exist; actual mapped streets/forts/docks absent |
| Audio/radio/sirens | Implemented hooks and assets, source verified | Current live references; engine placeholders and missing intro transcript disclosed |
| Web pipeline | Implemented, source/config verified | Pinned tools/workflow/shell; current live deployment/API history inaccessible |
| Streaming, origin rebasing, buoyancy, campaign, multiplayer | Not found as implemented systems | No configured managers/code paths for these features; not implied future commitments |

## Concrete technical debt and risks

1. **Stale presentation text.** `MissionsMenu._choose_mission()` still says “TWO MANUAL AA GUNS” and arrow controls, despite six local guns and mouse support. Some older Malta notes still promise byte-identical terrain and raised deck collision. This audit records the discrepancy; it does not change gameplay/UI files.
2. **Coordinator coupling.** `main.gd`, mission directors, HUD and interaction use direct mutable session references. The plural encounter list and singular focused enemy coexist. New simultaneous modes/controllers require careful ownership and callback cancellation.
3. **Generation reproducibility.** Source-to-current terrain requires grading/roads/base-access steps, not just initial `prepare_malta.py`. Existing source notes span different historical states. Regeneration can undo later geometry if the wrong command sequence is used.
4. **Geographic uncertainty.** Coarse/no-data DTM, approximate runways/roads/city outlines and missing Cottonera footprints constrain historical/geographic claims. Generated render detail does not improve input accuracy.
5. **Runtime scaling.** Every aircraft owns bullet/effect nodes; terrain/city collision remains loaded; broad world coordinates use no origin rebasing. No representative consumer-GPU or full populated-Cottonera benchmark is available.
6. **Test interpretation and CI gaps.** Disclosed fixture positioning, synthetic geography and software rendering are useful but must not be conflated with human gameplay, real historical geometry or hardware performance. Python/browser tools are not all run by CI.
7. **Prototype damage boundaries.** Wings lose force efficiency rather than detaching; cockpit integrity reduces controls rather than simulating crew anatomy; truck lacks health. Solid sea contact is not ditching.
8. **Audio fidelity.** Some engine recordings are placeholders; the Harrington introduction has no verified subtitle. Browser autoplay/pointer-lock constraints still require real-device review.

## Prioritized recommendations, not committed plans

| Priority | Suggested work | Dependency / success evidence |
| --- | --- | --- |
| 1 | Synchronize stale menu and topic documentation with actual counts, keys, ammo and terrain state | Small editorial follow-up; verify exact UI strings against current runtime |
| 1 | Write a reproducible offline asset build manifest/order with source hashes and fail-safe output locations | Needed before any terrain/city regeneration; test from retained originals without altering gameplay assets accidentally |
| 1 | Add missing Python import/compiler and selected release browser tests to CI | Builds on existing suites; distinguish native execution from a real exported build |
| 2 | Obtain/review local licensed Cottonera geometry and historical control points, then run the guarded pipeline | Required before claiming populated/walkable Three Cities; inspect collision/road openings and source epoch |
| 2 | Run documented end-to-end native and browser mission/transition acceptance on representative hardware | Confirm no duplicate cameras/controllers/spawns; measure actual timing and frame cost |
| 2 | Profile aircraft/effect allocations, collision setup and terrain/city visible cost | Optimize based on measurements; avoid replacing working physics speculatively |
| 3 | Introduce narrowly scoped session/interaction interfaces and typed mission states as new features demand | Preserve current reset/generation/ordnance guards with regression coverage |
| 3 | Improve character entry/exit animation, audio type matching and geographic fidelity | Original assets/source review required; keep these distinct from implemented mechanics |

No campaign, multiplayer, extensive city population or new aircraft commitment can be inferred from this audit. The recommendations follow present dependencies and concrete limitations, not an invented product schedule.

## Evidence insufficiency

Only the accessible 50-commit lineage can be reconstructed. No pre-root commits, merged PR design discussions, inaccessible/private issue histories or release history were recovered. The inaccessible original reference hosts limit Cottonera data, and older local Windows rendering could not be diagnosed beyond the recorded reproduction. Historical test reports were not all rerun; interactive flight/combat/audio/native-web acceptance remains explicitly outside this documentation audit's fresh checks.
