# 21 November 2026 — Downloadable Windows build

The previous Windows archive was attached to a draft release, which explains the empty public Releases page and the 404 from the download link. The current portable package includes the Bf 109 fighters, St Elmo raid, Mosta and the wartime villages. Extract the ZIP and open **First-Sortie.exe** on 64-bit Windows 10 or 11 with OpenGL 3.3. The executable is unsigned. [Windows release and checksum](https://github.com/zelenski3398/codexproj1/releases/tag/windows-141a378)

The Windows Desktop preset includes the generated Malta registries in the embedded game data. The manual **Publish Windows build** workflow takes a full commit SHA from main, verifies the official Godot 4.6.3 downloads, exports the executable, checks the ZIP and publishes it with a SHA-256 checksum. [Export source](https://github.com/zelenski3398/codexproj1/commit/141a378074c64b21fbe7e836ed6fdb8d192e84e8) · [Publication workflow](https://github.com/zelenski3398/codexproj1/actions/runs/44933974523)

The local build produced a Windows x86-64 executable, passed ZIP integrity checks and booted its embedded game data using Godot on Linux. A native Windows playthrough remains unverified.
