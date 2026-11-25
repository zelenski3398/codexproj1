# 25 November 2026 — Multiplayer client on main and Pages

The multiplayer branch was integrated with the current loading cinematic and soundtrack. The Pages build includes the 1v1 client and its endpoint configuration file. To play on the HTTPS site, both pilots must enter the same secure WebSocket server URL. The public site has no duel server configured. [Hosting and local play](../multiplayer-dogfight.md) · [Integration source](https://github.com/zelenski3398/codexproj1/commit/4722e0f45c969da39359005acdb804491d3de63f)

Godot passed all 21 duel checks after integration. The web export built successfully. The browser smoke test now skips the loading cinematic before opening the multiplayer lobby.
