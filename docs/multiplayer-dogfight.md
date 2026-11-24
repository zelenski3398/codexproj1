# Multiplayer 1v1 Dogfight

Open **Multiplayer → 1v1 Dogfight** from the main menu. Both players must use the same server address. Create a guest, press **Find a Duel**, then challenge the other guest. Display names may repeat. The short tag distinguishes guests. Your browser remembers the server-issued profile credential for that server address. Clearing site storage, switching browsers or using a private window can lose access to the guest.

Choose opposing sides and a fighter, then both press **Ready**. The Allied fighter starts at Ta’ Qali with the engine running and landing gear down. The Axis fighter starts over the sea. The shared three-minute preparation count starts when both clients finish loading. Reach the marked rendezvous at roughly 480 m above sea level. After reaching it, stay nearby and watch for **Fight!**. Press **R** to reset after a preparation crash. This clears your arrival while the original deadline keeps running. If either player misses the deadline, both return to selection.

Use the existing pitch, bank, rudder, throttle, gear and brake bindings, and **F** for guns. Use **Esc** for the controls and leave panel. Opening this panel leaves the battle running. The gold ring marks the combat boundary. Returning inside in time clears the out-of-bounds warning. Both players must accept a rematch to select aircraft again.

Career totals distinguish kills, wins, losses, draws and forfeits. Kills are grouped by side, nation and aircraft. A kill event records the defeated airframe. A recent confirmed hit can credit a subsequent crash. Two aircraft lost within the resolution window produce a draw. The server stores results and updates career totals together.

## Run locally

Use Godot **4.6.3**, matching web release templates, and two independent browser profiles or contexts. The existing `tools/install_godot_web.sh` script can install the matching Linux editor and templates. The server is part of this repository and runs the same GDScript aircraft, component damage, tracked ammunition, and swept projectile pools used by the game.

```sh
godot --headless --path . --editor --import --quit
mkdir -p builds/duel
DUEL_BIND=127.0.0.1 DUEL_PORT=9074 DUEL_STORE="$PWD/builds/duel/profiles.json" \
  godot --headless --path . --script tools/multiplayer/server.gd
```

In another terminal:

```sh
bash tools/build_web.sh
python3 tools/multiplayer/serve.py
```

Visit `http://127.0.0.1:8765` in both browsers and let the lobby connect to `ws://127.0.0.1:8765/duel`. The local web server forwards the same-origin connection to Godot on port 9074. Use two independent guest profiles. A second tab signed into an already connected guest is rejected by the server. Stop both processes when done.

## Host for friends over the internet

Host the static web export and run one long-lived Godot headless process on a VM. Give the server a persistent writable volume for its JSON store and back it up privately. The store holds credential hashes and career results. Serve assets and proxy WebSocket upgrades through HTTPS. Use `wss://your-domain/duel` as the lobby endpoint. The [Caddy configuration example](../tools/multiplayer/Caddyfile.example) assumes the game and socket share the same HTTPS origin. Replace the example host and web root, point DNS to the VM, expose HTTPS, and keep the Godot listener on loopback. Set `window.WINGS_DUEL_URL` in the deployed `duel-config.js` to let the lobby connect automatically. The default game address can also be entered in the lobby. GitHub Pages cannot run the authority process.

The Godot process accepts numeric configuration via `DUEL_PREP_SECONDS`, `DUEL_LOAD_SECONDS`, `DUEL_COMBAT_SECONDS`, `DUEL_BOUNDARY_SECONDS`, `DUEL_RECONNECT_SECONDS`, `DUEL_CREDIT_SECONDS`, `DUEL_MUTUAL_SECONDS`, `DUEL_WAYPOINT_RADIUS`, `DUEL_WAYPOINT_ALTITUDE`, and `DUEL_INVITE_SECONDS`. Defaults are 180, 60, 300, 12, 12, 12, 2, 600 metres, 130 metres either side of rendezvous altitude, and 25 seconds respectively. The combat ring is 7.2 km in radius.

One server process handles up to two independent matches, with separate physics worlds. Server restart ends live rounds. Completed results survive restart if the store remains intact. Browser or connection loss during preparation cancels the round. During combat, the server retains both aircraft and gives the disconnected guest a short reconnect period.

## Scenery, weapons and replication

The duel arena uses Malta’s existing terrain, sea and graded airfields. It omits village and city dressing, transport, ground defences and unrelated AI from both simulation and presentation. Allied and German fighters use their existing player implementations. The existing CR.42, C.200 and C.202 use their shared flight models with AI disabled and player commands supplied by the authority. Weapon batteries retain their configured rates and ammunition. Batteries configured with unlimited ammunition in single-player use a 350-round-per-port duel limit.

The server accepts sequenced input commands and sends authoritative snapshots at up to 20 Hz. Clients interpolate the opposing aircraft. Local flight uses the shared flight model with snapshot correction. There is no historical lag compensation or frame-by-frame deterministic input replay. Impacts and physics are resolved on the authority. Snapshot visuals include aircraft movement, gear, flap position, available animated controls, tracers, hull and component damage, smoke and breakup. The appearance and motion of loose debris is rendered locally.

## Checks

```sh
godot --headless --path . --fixed-fps 120 --script tests/duel_round_checks.gd
```

The command-line network smoke scripts use a disposable store. For their shortened test rounds, start the server with `DUEL_PORT=19074 DUEL_INVITE_SECONDS=3 DUEL_COMBAT_SECONDS=15 DUEL_WAYPOINT_RADIUS=24000 DUEL_WAYPOINT_ALTITUDE=1400` and run `node tools/multiplayer/smoke.mjs` with Node 22 or later. For the Chromium test, build the browser export, start a server with the same wide test rendezvous and `DUEL_COMBAT_SECONDS=80 DUEL_BOUNDARY_SECONDS=60`, then run `DUEL_TEST_SERVER_PORT=19074 node tools/multiplayer/browser_smoke.cjs` using Playwright and Chromium. Set `DUEL_TEST_NO_RENDER=1` to exercise the browser UI and network with rendering disabled on constrained runners. The ordinary rendezvous, timeout, weapons gating, mutual damage and boundary logic are separately checked in native Godot. No public server or GitHub Pages deployment is included with this branch.
