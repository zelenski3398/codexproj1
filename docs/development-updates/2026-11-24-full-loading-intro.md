# 24 November 2026 — Complete browser loading cinematic

The exported intro contains the full 110-second clip. The old handoff hid the video as soon as Godot was ready, so a fast load could cut off the later scenes. The browser now downloads the game alongside the video and opens the poster after both are ready. **Skip intro** lets the player go straight to the game once loading completes. If the video finishes or is skipped first, the progress display shows the remaining load. [Startup guide](../startup-poster.md) · [Source commit](https://github.com/zelenski3398/codexproj1/commit/355b3f58bab7d397d97e916d9a4c49a61d32af8b)

The Godot web export built successfully. Chromium played the exported MP4 through its natural end at accelerated speed with simulated engine readiness, verified that the loading overlay stayed visible until the clip ended, and checked the skip and sound controls.
