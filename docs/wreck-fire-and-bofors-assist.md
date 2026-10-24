# Wreck fires and optional Bofors assistance

## Burning land wrecks

Fueled land-crash wrecks now leave orange flames and dark smoke among actual aircraft debris. The effect is world-owned through `AircraftImpactService`, so an enemy's normal twelve-second cleanup does not abruptly remove the fire. It retains at most sixteen nearby fragment meshes as charred visual remains; it adds no new collision bodies or repeated damage, explosions or kill events.

`AircraftImpact.start_ground_fire` is latched per aircraft and checks a real support ray. Water is excluded; aircraft with no meaningful fuel remaining do not create a new fuel fire. A controlled, non-burning healthy landing does not ignite merely because it touches the ground. Existing physical sea splashes and sinking remain unchanged.

`AircraftImpactProfile.wreck_fire_seconds` defaults to **75 seconds**, including five seconds to let emitted particles fade. `maximum_wreck_fires` defaults to **four globally**. Each effect uses 24 CPU smoke particles and 18 flame particles, with simple shared geometry and no shadow casting. These effects are compatible with the project's Compatibility renderer. Retry/menu teardown clears them through the existing session effect service. This lingering layer is visual presentation; it does not add a second fire-damage source.

![Native Compatibility wreck-fire preview](previews/lingering-wreck-fire.png)

## Bofors option and controls

As of 25 October, use the [Bofors predictor post](bofors-command-post.md): **F** enters optics, **LMB/Tab** acquire visible targets, **G** chooses gun/battery scope and **Enter** assigns. Exit and mount a Bofors using **E**. In **Esc** settings choose **Manual, Assisted or Training** beside sensitivity. Resume and click to recapture. **Mouse aims, LMB fires, RMB zooms**; arrows remain available.

Assisted and Training use the explicitly assigned observer track to display a gravity-compensated lead diamond. The player remains responsible for aiming and firing. This replaces the earlier automatic nudge; unoccupied guns remain idle, and no projectile is bent or damage applied without real collisions. Obscured or lost observations remove the solution.

Tune observation properties in `BoforsCommandPost` and `predictor_alignment_degrees` in `AAWeaponDefinition`. Heavy AA ignores the preference and retains its five-second single-shot reload. Bofors retain infinite ammunition, automatic reload and one physical round every 0.5 seconds while the player holds fire.

## Harbour enemy balance

In Faith, Hope and Charity only, normal CR.42 escorts now have 4× aim error, 1.6× dispersion, half-second bursts, two-second rests and three seconds of initial engagement grace. The normal SM.79 defensive gunners use the existing Cadet observation/tracking profile. Damage, projectile speed, weapon rates and aircraft physics remain unchanged.

Final-wave aces retain their previous 0.2× aim-error scale, 0.25× dispersion scale, burst/rest timing, immediate engagement grace and five-second navigation prediction. `HarbourDefinition` exposes all normal adjustments separately from the existing ace scales. Other modes retain their own difficulty.

## Verification procedure

1. In harbour interception, observe ordinary escorts' shorter bursts and gaps; compare the final two aces, which should remain substantially more accurate.
2. In the AA defence mission, shoot down a fueled Stuka over land. Inspect flames/smoke and debris after the original enemy is removed; wait for fade, then retry to check cleanup. A sea crash should produce no lingering land fire.
3. Assign a visible target at a predictor, then mount an assigned Bofors and select Assisted/Training. Manually put the actual reticle on the lead diamond. Neither aiming nor firing occurs automatically.
4. Place a friendly or building in the line of sight: assist must not acquire through it. Dismount and confirm no automatic aiming/firing.
5. Mount heavy AA: its aim and reload should be unaffected by the Bofors preference.

Automated validation and evidence boundaries are recorded in the [20 October update](development-updates/2026-10-20-harbour-hangar-camera.md). The preview is an isolated native capture fixture, not a complete manually flown combat session.
