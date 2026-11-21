# 20 November 2026 — Raid on St Elmo and Stuka bombing

The [source range](https://github.com/zelenski3398/codexproj1/compare/4bf92809747871d8582e424d13e437623a498218...b964ed125e57b93d944ea2bf54b6e5dc422d162c) starts at the Spitfire landing gear merge. It includes the [Spitfire and portable Windows documentation](2026-11-18-spitfire-gear-windows.md) and the new [raid implementation](https://github.com/zelenski3398/codexproj1/commit/b964ed125e57b93d944ea2bf54b6e5dc422d162c).

The mission and Malta departures now offer a player-controlled Ju 87 with an attached bomb, HUD ammunition state, a distinct positional whistle and a functioning rear gunner. The raid uses one bomb and an Allied Sea Gladiator with tunable approach and burst settings. Free roam replaces spent bombs after a 15-second cooldown while existing drops continue. The mission director waits for released ordnance before committing a single result.

The shared damage section now covers the raid’s storehouse, parapets, annexes and compatible airfield hangar shells. Target credit uses the designated roof sections and a direct hit on the storehouse. Dynamic debris expires, while rubble and updated collision persist until the session is rebuilt. Legacy imported masonry and city meshes still require segmented geometry.

The seven German lines were generated with eSpeak NG and filtered for radio playback. Existing mission-radio queuing shows the corresponding English captions, prioritises the final result, and ducks the music and flight effects while the commander speaks. The audio menu saves subtitle and voice-volume preferences.

## Verification

Godot 4.6.3 passed **28/28** raid checks. The suite exercises the normal mission and free-roam entry points, physical target and water impacts, both one-star event orders, two-star results with a live interceptor and after player loss, unreleased-bomb failure, rear-gunner traverse and bursts, collision replacement, reloading and reset. It uses controlled fixture positions for precise impact and pursuit checks.

Existing suites passed for rear gunnery (**46/46**), harbour radio (**13/13**), AI dive attacks (**7/7**), St Elmo (**43/43**), hangars (**89/89**), shared HUD (**64/64**), Malta encounters (**33/33**), and audio (**37/37**). The rear-gunner regression now damages the aircraft profile’s separate rear crew component. Godot’s release Web export succeeded. A Chromium smoke check opened the raid from the mission picker, confirmed the airborne start, and released the bomb with X. The browser run did not reach impact within its time limit. Physical impact and scoring were verified in native Godot. The existing interception departure suite reached formation activation with its flight checks passing before the time limit. A full manual playthrough and subjective audio balancing across hardware remain unverified.

[Player guide, controls, scoring and limitations](../st-elmo-raid.md).
