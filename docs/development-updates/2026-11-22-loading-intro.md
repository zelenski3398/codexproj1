# 22 November 2026 — Startup presentation

Desktop and browser builds now open directly on the interactive poster. The separate date card has been removed. The browser shell can show a muted, full-window video during loading and hand off to the game as soon as Godot starts. The uploaded video exceeded the workspace transfer limit, so the browser continues to show the fallback progress display until the clip is added. [Source commit](https://github.com/zelenski3398/codexproj1/commit/30aadc967c8b2a10c62ee6f8f2751fcb74855a5f) · [Startup guide](../startup-poster.md)

All 19 native intro checks passed. A Chromium check with a temporary clip and simulated engine startup verified video playback, the hidden progress display during playback, canvas focus at handoff, the fallback display and retry.

The portable Windows release packages this update. GitHub Actions verified the ZIP, published its SHA-256 checksum and exposed the ZIP at a public URL that returned HTTP 200. A native Windows playthrough remains unverified. [Windows release](https://github.com/zelenski3398/codexproj1/releases/tag/windows-f6c1b49) · [Build verification](https://github.com/zelenski3398/codexproj1/actions/runs/45042749835)
