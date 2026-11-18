# 18 November 2026 — Spitfire landing gear and portable Windows build

The source review covers [`4f9e676..4bf9280`](https://github.com/zelenski3398/codexproj1/compare/4f9e676be7a69a1f1b1f64493836b433fbbbdaf0...4bf92809747871d8582e424d13e437623a498218). It includes the [previous tutorial documentation publication](2026-11-09-tutorial-handover.md) and the landing gear change merged through [pull request #1](https://github.com/zelenski3398/codexproj1/pull/1).

## Spitfire landing gear

Press **G** in flight to extend or retract the main gear. The Spitfire uses the Hurricane’s interpolation rate of 0.65 per second, so a full cycle in either direction takes about 1.54 seconds. Its main wheels move out and up into the wings. The struts pivot to follow the wheels, and the tailwheel stays extended. Fully deployed wheel positions still use the suspension travel and compression. The animation uses the existing gear command and physics state.

[SpitfireModel](../../scripts/spitfire_model.gd) holds the shared visual animation. [HurricaneModel](../../scripts/hurricane_model.gd) passes its own inward-folding geometry. [SeaGladiatorModel](../../scripts/sea_gladiator_model.gd) retains its fixed gear pose and suspension visuals.

Nine targeted headless Godot 4.6.3 assertions passed. They covered the gear command, intermediate and final positions, mirrored travel, strut alignment, tailwheel visibility and suspension compression. The [browser publishing workflow for the merge](https://github.com/zelenski3398/codexproj1/actions/runs/44334712230) also succeeded.

## Portable Windows build

The Windows ZIP contains one executable, `First-Sortie.exe`, with the Godot game data embedded. Extract the ZIP and run the executable on 64-bit Windows 10 or 11 with OpenGL 3.3 support. This unsigned build includes the Spitfire update at `4bf9280`.

The [Windows build branch](https://github.com/zelenski3398/codexproj1/tree/build/windows-4bf9280) adds a Windows Desktop export preset and an Actions workflow. The [build run](https://github.com/zelenski3398/codexproj1/actions/runs/44338157662) used matching Godot 4.6.3 export templates, verified the executable format and ZIP, and uploaded `First-Sortie-Windows-x64.zip` to the draft release. The extracted game data also started in a headless Godot release runtime. A native Windows launch and playthrough remain unverified.

To find the ZIP, sign in with repository write access and open **First Sortie for Windows (64-bit)** from [GitHub Releases](https://github.com/zelenski3398/codexproj1/releases). GitHub may return 404 for the draft URL if the signed-in account lacks access.
