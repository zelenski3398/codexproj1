# Flight school tutorial and visible aircraft controls

Source: [`8a68e0c8d9cc1290d7f19f83763b07573f6dd1eb`](https://github.com/zelenski3398/codexproj1/commit/8a68e0c8d9cc1290d7f19f83763b07573f6dd1eb), committed **8 November 2026**, `feat(tutorial): add continuous Malta flight school and visible aircraft controls`. Previous documented source `4d304da234829ebc8ec69dae8a26e41c11433675`; `eb6382b` publishes the preceding poster/music documentation.

## Scope and implementation

The user requested visible basic aircraft controls at the upper left in every mission/free roam, plus a tutorial accessible from the live poster covering boarding, flight, combat over Valletta, landing, another aircraft, heavy damage/emergency landing, vehicle recovery and manual AA combat.

[GameplayHUD](../../scripts/gameplay_hud.gd) now displays a compact aircraft reference below health, reading InputMap bindings. It is explicitly labelled **while aboard**, retains current equipment/health/instruments, hides behind modal help/pause, and moves notifications/diagnostics and narrow-screen objectives below it. F/Ctrl firing, Q flaps, B fitted brakes, W/S throttle, Space ground braking and existing movement/interaction shortcuts remain. Ordinary missions retain their objectives, waves, timers and damage. The tutorial adds current lesson instructions, bearing, distance, a 3D marker and navigation-map target.

[GameIntro](../../scripts/game_intro.gd) adds an integrated Tutorial button above Play, including Tab/Enter keyboard navigation and the existing fade. Choosing training keeps the transition dark rather than flashing the selector/menu music before world creation. Normal Play remains unchanged. [main.gd](../../scripts/main.gd) creates/cancels the tutorial director with the existing Malta session lifecycle, and retry restarts that mode cleanly.

[TutorialMission](../../scripts/tutorial_mission.gd) and its [definition resource](../../mission_definitions/tutorial.tres) implement one continuous Malta lesson sequence:

1. On foot at Ta’ Qali, board a Sea Gladiator, start the engine, taxi out and align before takeoff.
2. Fly three airborne checkpoints toward Valletta while practising pitch, roll, rudder, power reduction and M navigation.
3. Fight one Stuka over Valletta; return and make a settled runway/apron landing at Ta’ Qali.
4. Shut down, exit and board the other assigned aircraft, a Spitfire. Learn retractable gear and actual flap deployment/retraction after another takeoff.
5. Navigate to the northwest Luqa approach. One explicitly scripted training failure uses shared component damage: engine fully failed, both wings lose 20% maximum integrity, elevator 15%, hull HP reduced to at most 45. There is no random fuel ignition, fake projectile, velocity assignment or aircraft repair.
6. Glide and land at the existing Luqa runway/apron. This is a designated clear alternate, not a new rural landing strip. Stop, shut down, exit, call V recovery and enter the actual arriving truck.
7. Existing recovery transfers the pilot home, preserving the world, both aircraft, damage and fuel. This reuses the existing short approach plus fade/transfer; it is not a newly simulated cross-island AI drive.
8. Mount a home gun. A second Stuka uses the existing DiveAttackPilot, one finite physical bomb, real strafing projectiles and positional dive audio. No friendly gun aims or fires autonomously. Destroy the aircraft and survive until unresolved bombs clear to finish.

The original aircraft/pilot models, flight forces, weapons and AA systems are reused. Instructions are text; no tutorial speech asset was supplied or generated. [Full lesson guide and state diagram](../tutorial-flight-school.md) describes controls and tuning, with actual browser captures.

## Integration details and fixes

- [MaltaMission](../../scripts/malta_mission.gd) uses a tutorial-only Gladiator/Spitfire home roster, rejects boarding an out-of-lesson plane and supplies the tutorial map marker. Normal mode rosters are unchanged.
- Active training disables on-foot map teleport so it cannot bypass the emergency recovery sequence. It does not disable the navigation map.
- [TransportRecovery](../../scripts/transport_recovery.gd) gains a tutorial-specific eligibility exception after the confirmed emergency landing, because ordinary recovery is unavailable inside an operational alternate airfield. Safe truck placement and explicit nearby E entry remain unchanged.
- The failed-engine exercise exposed an existing interaction trap: I rejected every command when power integrity was zero, so a running-but-failed engine could never be switched off and safe aircraft exit stayed blocked. I now rejects an unserviceable **start**, while still allowing shutdown.
- [AirfieldInteraction](../../scripts/airfield_interaction.gd) honours tutorial terminal state. Occupied guns eject safely, required-aircraft loss or pilot death fails training, and the tutorial suppresses the duplicate generic death panel in favour of one result view.
- Progress is latched by phase, one-time damage flag, actual destruction callbacks and a result-transition guard. Repeated spawn/failure/retry calls cannot produce duplicate encounters or full-world restarts.
- Tutorial enemy accuracy is local (2.5° forward aim error, longer burst rests, 15-second grace, Cadet rear gunner). [Difficulty memory](../../scripts/main.gd) excludes tutorial tuning; normal pilots/aces retain their existing settings.
- [Publishing manifest](../../tests/publishing_checks.json) grows from 66 to **68** suites with the two tutorial checks. No existing publishing checks are removed or bypassed.

## Verified results

Godot 4.6.3 import and matching-template web export passed. Ten targeted Godot suites passed **443 assertions** across their latest successful executions:

| Suite | Result |
| --- | --- |
| Tutorial progression / lifecycle | 44/44 |
| Actual engine-out tutorial glide | 1/1 |
| Shared HUD, including Survival/harbour/AA controls reference | 64/64 |
| AA contextual HUD | 27/27 |
| Ground aircraft/vehicle/AA interactions | 61/61 |
| Existing pilot recovery | 73/73 |
| Mission return-and-landing rules | 33/33 |
| Actual flak damage | 9/9 |
| Intro transitions / layout | 20/20 |
| Native actual poster playback | 11/11 |

The 44-case progression suite uses setup poses between flying stages. It exercises normal boarding/shutdown/exit, real component damage, actual enemy destruction events, truck request/placement/entry/return, gun mounting/projectile creation, bomb draining, persistent world/aircraft damage, one restart from duplicate Retry presses, and pilot-death cleanup. **It is not an end-to-end flown tutorial.**

The separate engine-out test starts at the configured exercise entry, applies the real training damage once and flies the whole descent with normal pilot commands, no thrust and no body position/velocity assignments after setup. It reaches Luqa, touches down, brakes to rest, retains **45 HP and zero engine power**, and advances to EXIT_DAMAGED. Early approach tests with excessive early flap deployment or a high setup ended in hard landings/overshooting. The final mission uses a 450 m terrain-clearance setup, and the test preserves energy, delays flaps and flares progressively. Flight physics and damage authority were not weakened to pass.

Production-export Chromium ANGLE/SwiftShader checks passed **9/9** using actual inputs: poster Tutorial click, peaceful on-foot start, top-left bindings, E boarding the Gladiator, F1 pause/help input suppression, I engine progression, 800×600 resize and world identity, and no script/resource/JavaScript errors. Browser screenshots are committed with the guide. Native playback retains the existing continuous poster and soundtrack tests.

[Machine-readable results](validation/tutorial-flight-school.json) record the source, per-suite outcomes and scopes. Markdown file links and `git diff --check` passed.

## Limits and follow-up testing

No human flew the complete tutorial or fought both aircraft in one continuous native/browser session. Browser verification covers entry, boarding, help, engine controls and layout, not every flight leg. Physical emergency landing was verified in headless simulation with a test-only pilot. Subjective teaching pace, novice difficulty and hardware frame rates need interactive review. Software rendering was used for browser/native captures. No full 68-suite publishing run or live Pages deployment success is claimed locally. No new voiced instructor recording, fully simulated cross-island recovery drive or rural-strip terrain modification is claimed.
