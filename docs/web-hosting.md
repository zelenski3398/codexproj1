# Browser build and hosting

The game can run directly in a desktop browser using Godot 4.6.3's Compatibility
renderer/WebGL 2 and **single-threaded** export. No backend, account, paid hosting,
GDExtension, SharedArrayBuffer or COOP/COEP headers are needed. Desktop flight,
weapons, health and enemy AI are reused rather than ported to another engine.

## Activate GitHub Pages once

1. In this repository, open **Settings → Pages**.
2. Set **Build and deployment → Source** to **GitHub Actions**.
3. Go to **Actions → Publish browser game → Run workflow**, choose **main** and run.

The workflow imports the project, runs the complete 65-suite Godot publishing manifest and four check-runner self-tests,
exports the release web build, uploads a downloadable artifact, and deploys it
using the official Pages actions. It also runs on subsequent pushes to main.
Its deployment environment reports the public URL; normally this is
`https://zelenski3398.github.io/codexproj1/`.

If the first deploy failed because Pages was disabled, enable it and rerun the
workflow. There are no personal token/secrets to enter for this workflow; the
repository's scoped Actions token handles the deployment. Pages and Actions
must be allowed by the repository's organization/account policies.

The repository owner previously enabled Pages. Current live deployment status must be checked in Actions; a successful local export does not establish publication. Each main push runs the checks before exporting and uploading the game. The 6 November 2026 local export is approximately 379 MiB in total, including a 342 MiB PCK; raw GIS datasets stay out of the export.

The cloud proxy returns a 403
CONNECT denial for `api.github.com` and `zelenski3398.github.io`. Git read/push
and public Godot release downloads work. This prevented changing the Pages
setting directly or fetching the public site; it did not prevent a real local browser
build/test. Do not interpret a successful local test as a public deployment.

## Build locally

In Linux/cloud, use the included setup helper:

```sh
export XDG_CACHE_HOME=/tmp/godot-cache
export XDG_CONFIG_HOME=/tmp/godot-config
export XDG_DATA_HOME=/tmp/godot-data
bash tools/install_godot_web.sh
export PATH=/tmp/first-sortie-godot:$PATH
bash tools/build_web.sh
```

The setup helper pins Godot **4.6.3**, downloads official release assets,
verifies published SHA-512 checksums, installs matching web release/debug
templates and verifies retained templates on later runs. The official archive
is about 1.2 GB, but only the web templates are installed. It preserves a matching
system Godot executable. Optional locations: `GODOT_WEB_TOOLS`,
`GODOT_DOWNLOAD_CACHE` and standard `XDG_DATA_HOME`.

The build helper imports resources before exporting; it produces
`builds/web/index.html` plus JS, WASM, PCK, audio worklets and license notices.
Generated builds remain Git-ignored. The 6 November payload measured 397,106,717 bytes, including a 358,939,096-byte PCK. Compression and download size depend on hosting. Serve the **entire directory**
over HTTP(S); opening index.html as a local file will not run the game.

On Windows, open the project in Godot, install the web export templates matching
that installed editor, then use **Project → Export → Web → Export Project**.
The CI website build uses the pinned engine regardless of the Windows editor
version. Include the bundled license notices when hosting a manually exported
copy. The cloud helper packages notices automatically.

Any static host with HTTPS and a correct `application/wasm` MIME type can serve
the export. Keep all filenames together and use relative URLs for subpath hosting.
`variant/thread_support=false` and PWA disabled are deliberate: GitHub Pages
cannot supply custom isolation headers. No service worker hides old versions.

## Browser controls

The page loads the Godot intro/live poster. Its integrated Play button transitions to aircraft selection. Select a plane and Fly (or Enter), or choose Malta and an airfield. The canvas takes keyboard
focus automatically. Browser autoplay rules may keep sound silent until your
first click or key press inside the menu. Click the game again if focus was moved
to browser chrome. There is no separate HTML Play screen or repository link.

- Arrows: pitch/bank; A/D: rudder; W/S: persistent throttle.
- **F held: guns.** The original Ctrl binding still exists, but use F in a browser;
  Ctrl+W and other Ctrl combinations can be reserved by the browser.
- G: gear (Spitfire/Hurricane; Gladiator is fixed); Space: brakes; R: full session restart; Escape: pause.
- Malta: E board/leave, I engine, M navigation; WASD walks on foot.
- C: confirm the next encounter/Survival stage without pausing flight.
  Select Survival from the Malta departure chart; [details](survival.md).
- H: existing temporary −10 HP debug key; F3: component/gunnery inspector.
- F4: Malta elevation heatmap debug; terrain defaults to the Mediterranean landscape.

Touch/mobile flight controls are not implemented. The game loads automatically after a
reload; there is no campaign/save system. Use a recent desktop browser with
WebGL 2 and hardware acceleration. The loading indicator covers download/startup.

## Validation

The exported **release** build ran in Chromium using actual mouse and keyboard
events, WebAssembly and WebGL 2 through SwiftShader. **31/31 checks passed**:

- Automatic main-menu startup, feature detection, initialization without cross-origin isolation.
- Keyboard plane selection, mouse Fly, live fixed gear and visible health.
- W + F together, throttle hold, firing release and runway acceleration.
- Exact 50 HP threshold, smoke/fire below it, destruction and blocked firing.
- Full reset with restored health, cleared rounds/effects and exactly one enemy.
- Escape pause, F3 inspector, mouse aircraft switch and clean Spitfire startup.
- Spitfire firing, asset loading and absence of JS/Godot runtime errors.

Malta checks additionally cover map/airfield selection, loading the real GLB,
six stationed aircraft, on-foot departure, boarding, engine start, live chart,
persistent leave/reboard and a clean full mission restart. Both map screens
were visually inspected, including the moving heading marker and home ring.

The Malta change also passed **559/559 existing native regressions** (all nine
flight/combat/damage/AI suites), plus **35/35 Malta integration checks**.
The uninterrupted journey additionally passed **18/18 checks**. The focused
current-release Malta browser suite passed **10/10**, including on-foot pause.
The integration check has disclosed physics-position fixtures for isolated
landing/boarding scenarios; a separate continuous-flight test exercises the
full route using pilot commands. See [Malta validation](malta-world.md).

Reproduce browser checks after building:

```sh
node tools/web_smoke.cjs
```

This optional check needs Python 3, Node, Playwright and Chromium (preinstalled
in the cloud snapshot). Use `CHROME_BIN` for another executable path.
It starts an internal loopback server and cleans it up; it is not public hosting.
Results/screenshots go to `/tmp/first-sortie-web-checks`, configurable with
`WEB_TEST_OUTPUT`. `WEB_TEST_PORT` selects the internal port.

The test uses `?smoke=1` to enable opt-in **read-only** browser telemetry in
`WebSupport`. It never assigns aircraft transforms, velocities, HP or control
commands. Input, collision, damage and physics remain the normal runtime path.
Normal visits do not run telemetry. The template and support component add no
external analytics or player-data services.

Screenshots were inspected for both models, HUD, smoke and debug panels;
a bundled DejaVu fallback fixes the web template's missing arrow/math glyphs.
Full browser takeoff/landing/dogfight feel, Firefox/Edge/Safari behaviour and
the public GitHub Pages response remain unverified. GPU acceleration should
perform better than the cloud's software renderer; no hardware frame-rate claim
has been made.

## Recovering a missing Pages artifact

If deployment reports `No artifacts named "github-pages" were found`, start a
fresh **Publish browser game** run from **Actions → Run workflow → main**, or
choose **Re-run all jobs**. The build job must run to upload the game again;
re-running only deployment cannot restore a deleted or expired artifact.

The workflow explicitly uploads/deploys `github-pages`, retains that deployment
artifact for seven days (the previous action default was one day), checks the
exported HTML/JS/Wasm/PCK are present, and passes the upload ID to the deployment
job. The separate `first-sortie-web` download is not the Pages deployment artifact.
Configure Pages v6 and Deploy Pages v5 use Node.js 24; Upload Pages v5 uses the
current upload-artifact action. GitHub-hosted Ubuntu 24.04 runners are retained.

If the error is instead `Get Pages site failed ... Not Found`, first set
**Settings → Pages → Build and deployment → Source → GitHub Actions**. That site
enablement is a repository setting and cannot be performed using the ordinary
workflow token alone. A workflow change does not prove deployment has succeeded;
confirm the new run's **deploy** job is green before checking the site.

## Publishing checks and failure logs

[Publishing repair and validation](development-updates/2026-11-06-publishing-hud-checks.md).

The canonical command list is [tests/publishing_checks.json](../tests/publishing_checks.json). It retains all 65 original Godot invocations, including the three Xvfb display tests, in their original order. [run_godot_checks.py](../tools/run_godot_checks.py) runs every suite, retains a log per suite and returns failure if any suite fails. Export and deploy remain blocked by a failing check.

Linux/cloud reproduction after installing matching Godot and importing:

```sh
godot --headless --path . --editor --import --quit
python3 -m unittest discover -s tests -p test_publishing_runner.py
python3 tools/run_godot_checks.py
```

The default is serial, matching the publishing environment. Optional `--jobs 3` runs independent suites concurrently. For a targeted rerun, use script stems, for example `--only weapons_checks malta_encounter_checks`. Each suite has separate temporary Godot data/config/cache directories, so saved audio/AA preferences cannot leak between suites or alter the developer's normal user data. Settings persist normally within a suite.

After a failed check, open the Actions job summary or download **godot-check-logs**. It contains `summary.md`, `results.json`, and one `.log` per suite. Failures also receive a file-specific annotation. Logs are uploaded with `if: always()` even if the check step fails; interrupted runs can retain a partial report of completed suites. A failure before checks start may have no check artifact.

The runner rejects nonzero exits, explicit failed assertions, GDScript/parse errors, missing executables and timeouts. It additionally catches GDScript errors even if the engine exits zero. It preserves other engine diagnostics in the logs; existing resource-use-at-shutdown warnings are not asserted to be fixed. The four self-tests verify pass/failure propagation, zero-exit script errors, timeout reporting and isolated job-summary output.
