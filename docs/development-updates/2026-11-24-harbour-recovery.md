# 24 November 2026 — Harbour recovery and loading cinematic

In Faith, Hope and Charity, a living pilot can call the shared recovery vehicle after a land crash or ditching. Use **E** to leave the wreck, **V** to call transport, then **E** at the pickup. Returned pilots can board one of Ħal Far’s remaining Sea Gladiators. The active wave and wingmen persist during rescue. Survivors who lose their aircraft during the final return can satisfy the pending return by reaching base. Pilot death, fort loss and bomber release still resolve mission failure. [Mission guide](../harbour-interception.md) · [Recovery source](https://github.com/zelenski3398/codexproj1/commit/35b35000dcc1a2548dc7d1e5fcf6f007069702c7)

The browser now uses the supplied cinematic while Godot loads. The 110-second widescreen source was encoded as a 14 MB fast-start H.264 file. Muted playback loops only if the game is still loading, and the progress display appears if playback fails. The animated poster opens directly at handoff. [Startup guide](../startup-poster.md) · [Video asset commit](https://github.com/zelenski3398/codexproj1/commit/2b7becfd6bdbe36e4281cfe4cc531d151d7f6950)

The native harbour mission, hangar, mission-return and shared pilot-recovery suites passed. The hangar regression performed a water impact during an active formation, used the shared pickup and boarded a replacement in the same mission. The mission-return suite verified that a crash survivor can still return and that a subsequent fatal injury fails the pending mission.

Chromium played the supplied video during a real web export. The progress bar stayed hidden during playback. Once Godot was ready, the shell stopped the movie and focused the canvas.
