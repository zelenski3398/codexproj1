# 24 October 2026 — staffed Bofors observation posts and manual predictor sights

Source boundary: [`5533313c0bab2d3f724657de828c85ca9148ca77`](https://github.com/zelenski3398/codexproj1/commit/5533313c0bab2d3f724657de828c85ca9148ca77). Previous documented source: `cebd3f7ffd61c870b7fef77cf29f2fc891ad2dd9`. This exclusive range contains the previous documentation publication `ac0ce90` and the new implementation. The original full-history report remains frozen.

## Observable change

Earlier Bofors assistance nudged the barrel toward a nearby target. It is replaced by read-only predictor guidance: the player must acquire and assign a visible aircraft at an observation post, then manually aim and fire the assigned gun. Four original sandbagged posts serve the three existing airfield Bofors pairs and Fort St Elmo's three-gun battery. The existing 21 guns and three separate heavy-AA command stations remain in place.

The [current guide](../bofors-command-post.md) lists controls, all changed runtime files, tuning, screenshots, the data-flow diagram and a manual verification procedure. New code is primarily [BoforsCommandPost](../../scripts/bofors_command_post.gd) and [BoforsObserverCrew](../../scripts/bofors_observer_crew.gd); existing gun, projectile, damage and interaction systems are reused.

Each post provides optics, visible-target selection, individual/battery assignment and estimated range, altitude and heading. Frustum/range/line-of-sight tests prevent discovering unseen contacts. Filtered observed positions estimate velocity; manoeuvres reduce confidence. Each assigned gun uses the existing numerical `AAFireControl.solve` with its own muzzle and the projectile pool's gravity. Manual/Assisted/Training settings change display only. The barrel reticle and gravity-compensated lead diamond remain distinct. Physical shells still cause damage only through the existing collision system.

Posts and observers are damageable. Post loss clears assistance without destroying guns or changing existing mission outcomes. A dead observer cannot maintain an unattended track. Existing Stuka attack selection can target the local post, including the third attacker in the actual three-plane wave. No autonomous aiming or firing is added. Heavy salvo operation, Bofors reload/dispersion, aircraft physics and terrain remain unchanged.

## Placement issue found and corrected

The first Fort placement ray sampled terrain below the fort deck. Native and browser traversal exposed the inaccessible placement. Placement now waits two physics frames for city collision registration, samples sky-facing supported surfaces at courtyard height, checks the whole footprint and casts a soldier capsule along the approach. The final native test walks from the original spawn to the post; the browser test does the same using actual keyboard controls. No fort geometry was changed.

## Checks actually performed

Godot 4.6.3 Compatibility was used for native checks; the production browser export used Chromium ANGLE/SwiftShader.

| Native suite | Passed assertions |
|---|---:|
| New Bofors predictor | 59 |
| Heavy battery command | 36 |
| Heavy battery engagement | 17 |
| Fort St Elmo | 43 |
| Airfield/vehicle controls | 61 |
| Dive-defence mission | 47 |
| Layered AA | 55 |
| Harbour support/balance | 24 |
| Countryside departure | 12 |
| Native mouse aiming/cadence | 32 |
| **Total** | **386** |

- Predictor checks cover observation and occlusion, moving/reversing targets, per-gun gravity solutions, invalid envelopes, explicit assignment, no automatic aiming/fire, a real shell hit, enemy bullets/bombs, operator death, manual fallback and clean retry. Existing tests were updated for four additional posts and the replacement of magnetic assist; other assertions remain.
- **Two rendered assertions** verify a separated lead diamond and manually aligned ON TARGET. Native screenshots were rendered and inspected, including exposed courtyard support and ground-level crew stance.
- **13 production browser checks** exercise the real poster/menu, walking to the fort post, pointer capture/zoom, acquiring a live randomly spawned Macchi C.200, assigning three guns, same-world travel, Training selection, visible lead guidance, physical firing and exit. [Browser smoke tool](../../tools/bofors_predictor_web_smoke.cjs). [Browser capture](../previews/bofors-predictor-web.png).
- CPU fixture: four known targets and nine gun solutions produced 450 per-gun solutions over 200 post refreshes in **11,488 microseconds total / 57.44 microseconds per post refresh** on this host. This measures solver work, not full-game frame rate.
- Final web export succeeded after the final targeting change, with no script/resource/shader errors. It required writable XDG cache/config/data directories in this sandbox; an initial invocation without them failed to find templates and was rerun correctly.
- Mermaid parsing, local Markdown target existence, JSON parsing and `git diff --check` were checked. Only AA implementation/UI, tests, workflow and documentation changed; geography and aircraft assets were untouched.

[Machine-readable validation](validation/bofors-predictor-2026-10-24.json).

## Remaining limitations

New observer voice recordings were not supplied. Period-style calls use labelled subtitle fallbacks and optional exact-value recording slots, without fabricated speech. The instrument is a simplified original WWII-inspired model, not a surveyed Kerrison reconstruction. Personnel reuse existing animations; dedicated hands-on-instrument animation is absent.

The native software-render capture reported two texture allocations remaining at shutdown after screenshots were saved; no shader or script error accompanied them. Automated native/browser interaction and controlled targets are not an exhaustive human combat playthrough, hardware frame-rate benchmark, mobile test or subjective audio evaluation. The final export was rebuilt after small text/target-priority refinements following the successful browser flow; that full browser flow was not repeated for those refinements. Live GitHub Pages deployment is not verified here.
