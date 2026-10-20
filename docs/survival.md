# Confirmed encounters and Malta Survival

**20 October update:** available player aircraft now depart from hangar stands. Pilot health is independent from hull HP; a surviving pilot can exit a wreck and use **V → E truck entry** recovery without resetting this mission. Aircraft loss alone no longer fails the attempt. [Current survival/recovery rules](pilot-survival-and-recovery.md).

Malta free roam now waits for its first **C / Spawn Random Enemy** request and
uses Stuka/CR.42/C.200/C.202 opponents. **Survival is unchanged**: stage 1 begins
immediately and subsequent stages still require confirmation. See the
[current encounter update](development-updates/2026-10-16-random-encounters.md).


The original countryside encounter and all three Malta departure locations
remain available. Malta is still one continuous environment. Its departure
chart now has an **Encounters / Survival** dropdown; the mode is independent of
the selected airfield and aircraft. There are no separate terrain scenes.

## Play

In Encounters, destroy the Stuka and press **C** or click **Confirm / Spawn Next
Enemy**. In Survival, destroy every enemy in the current stage, then press C or
click **Confirm / Start Next Stage**. Neither action pauses the aircraft or
captures keyboard focus. Hold normal flight controls while confirming.

Survival batches are:

| Stage | Normal Stukas | Ace Stukas | Total |
| --- | ---: | ---: | ---: |
| 1 | 1 | 0 | 1 |
| 2 | 2 | 0 | 2 |
| 3 | 2 | 0 | 2 |
| 4 | 3 | 0 | 3 |
| 5 | 2 | 1 | 3 |

The stage counter and remaining enemies appear at the top of the screen. Each
live enemy has a directional/nearby health marker; the ace says **ACE STUKA**.
The navigation chart shows detected enemies, with an explicitly labelled gold
ACE marker. Destruction, rather than smoke, range or screen visibility, clears
enemies from the active count. The final kill displays **Survival Complete**.
No sixth stage is scheduled. Player destruction or crash blocks confirmation.

Confirmation retains the world, parked fleet, pilot, player aircraft, velocity,
engine, throttle, fuel, health, component damage and existing projectiles. It
does not heal or reset any player system. Switching aircraft still uses the
existing boarding flow and retargets all live enemies. **R remains a deliberate
full mission restart**; it retains the chosen mode and returns Survival to
stage one with a fresh fleet. Choosing another map ends the current mission.

## Architecture and tuning

`scripts/enemy_encounters.gd` owns progression, active enemies, falling wrecks,
confirmation and supplemental markers. `main.gd` supplies the existing Stuka
factory, difficulty settings, legacy focused-enemy HUD/debug reference, and
impact effects. That focused reference can point at a destroyed wreck for
inspection; it is **not** the active-enemy list.

Each actual aircraft `destroyed` signal removes its instance from `active`
once. A cleared batch unlocks confirmation. The confirmation latch closes
synchronously, before a deferred spawn, and a generation token rejects queued
callbacks from previous runs. Player destruction closes the same latch. Wrecks
continue their original physics/impact/removal lifecycle while replacement
encounters may begin. Full restart/menu exit removes both active enemies and
wrecks and clears the session effects.

All enemy positions are planned before adding the batch. Downward terrain-layer
rays account for the islands, sea and buildings. An 18 m clearance sphere checks
terrain and aircraft bodies, and explicit separation checks cover planned batch
members and falling wrecks. If 32 candidates cannot provide clearance, the run
stops instead of spawning a partial or intersecting stage.

Exported parameters on `EnemyEncounters`:

| Parameter | Default | Purpose |
| --- | ---: | --- |
| `minimum_spawn_distance` | 650 m | Player separation |
| `spawn_distance` | 1,400 m | Preferred spawn ring |
| `spawn_clearance` | 160 m | Minimum clearance above sampled surface |
| `spawn_separation` | 180 m | Separation from batch members and wrecks |
| `ace_aim_error_scale` | 0.20 | Multiply normal forward burst aiming error |
| `ace_dispersion_scale` | 0.25 | Multiply normal forward gun dispersion |

Default forward burst error is 0.18° for normals and 0.036° for the ace; gun
spread is 0.08° versus 0.02°. Existing ballistic target leading is reused.
Neither pilot receives direct damage or guaranteed hits. Their range, fire
rate, speed, lifetime, damage, collision checks and damage multipliers remain
identical. Defensive rear gunner settings remain unchanged, including the
human aiming limitations and obstruction checks. Ace overrides are never
remembered as normal-pilot difficulty settings.

The shared aircraft controller, aerodynamics, AI manoeuvres, projectile pool,
health, component damage, hit sparks, smoke, engine sounds and guns remain the
working systems. A stage change only creates its enemy instances.

## Verification

Run the lifecycle suite with matching Godot:

```sh
godot --headless --path . --fixed-fps 120 --script res://tests/survival_checks.gd
```

The native checks passed **83/83**, plus **661/661 existing regression checks**
covering flight/input, weapons, enemy encounters/AI, aircraft choice, component
damage, rear gunners/balance, Malta, terrain and audio. The exported browser
suite passed **10/10** with no runtime errors. The departure menu and cleared /
active stage HUD screenshots were visually reviewed.

The suite exercises the real scene, menu mode choices at all three airfields,
boarding, real damage/destruction signals, keyboard confirmation and deferred
batch creation. An explicitly disclosed airborne pose fixture isolates state
preservation; it does not represent eleven player gun kills. It checks health,
components, fuel, gear, throttle, engine, motion, projectiles and world identity;
exact batches and ace settings; partial/simultaneous kills; completion; player
death before a queued spawn; and stale confirmations across full restarts.

After `bash tools/build_web.sh`, run:

```sh
node tools/survival_web_smoke.cjs
```

This optional Playwright/Chromium check uses real browser mouse/keyboard input,
WebAssembly and Compatibility/WebGL 2. It selects Survival, boards, applies
existing F3 component-debug damage to the stage-one enemy, confirms stage two,
checks state preservation and normal engine/gun input, then ends the player
run using the existing H debug key. Browser telemetry is opt-in (`?smoke=1`)
and read-only. Results and screenshots go to `/tmp/survival-web-checks`.

For a manual combat check:

1. Choose Malta, a departure airfield, aircraft, and Encounters. Board/start/take
   off, shoot down the enemy, keep steering and confirm with C. Verify the same
   health, fuel and flight state and exactly one replacement.
2. Start a separate Malta Survival run. Verify batches 1/2/2/3/3, waiting after
   each complete batch, and no progression after a partial kill. Damage your
   aircraft with H if needed to make the lack of inter-stage repair obvious.
3. In stage five, locate the labelled ACE. Its forward fire should be more
   accurate without extra bullet damage. Destroy all three for Survival Complete.
4. Restart, destroy the player with H, and verify C cannot advance the run.

Manual airborne confirmation feel, a human-flown five-stage victory, and
hardware performance with three combatants remain interactive validation tasks.
