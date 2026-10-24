# Mouse-operated AA controls

E mounts/exits the nearest gun. Mounted guns capture relative mouse movement: right moves traverse right, up raises the barrel. **LMB fires**, **hold RMB zooms** (58° to 30°), Space gives fine aim, W/S adjusts heavy shell fuze timing. Arrows and Ctrl/F remain alternatives. Mouse fire and zoom use separate `aa_fire`/`aa_zoom` actions; aircraft, foot and truck bindings are unchanged.

**Ammunition is unlimited.** Heavy guns require a fresh trigger press and automatically reload for five seconds. Bofors fire continuously every 0.5 seconds while held. There are no clips, ammunition limits, manual reloads or AI loaders. The previous finite ammunition/clip implementation was removed in accordance with the final request.

Escape pauses and releases the cursor. The pause panel has an **AA mouse sensitivity** slider (0.2–3×) and **Bofors Manual / Assisted / Training** selector, saved to `user://aa_controls.cfg`. Manual defaults on. Resume with Escape, then click the game to recapture. That first recapture click does not fire. Opening the navigation map or audio panel, losing focus, dismounting, destruction and mission completion release control. Menus suspend aiming and firing, discard pending motion, and require the fire control to be released before another shot. In browsers, a user click is required to reacquire pointer lock after menus.

`AAMouseControls` handles scoped input and smoothing; `BritishAAGun` retains the existing mounting, reload, health, recoil, camera and projectile logic. The camera remains parented to the muzzle and follows actual barrel rotation. Shots follow that barrel rather than the requested aim angle. Empty guns never aim or fire automatically.

The 25 October [Bofors predictor system](bofors-command-post.md) replaces the earlier aim nudge. Approach its observation post and press F, acquire a visible target, choose gun/battery scope and press Enter to assign. Assisted/Training display a lead diamond at an assigned gun. `BoforsAimAssist` is read-only sight data: the player must move the barrel and fire. Heavy guns ignore this preference. Tune observation properties in `BoforsCommandPost` and alignment tolerance in `AAWeaponDefinition`.

Configurable in `AAWeaponDefinition` and the heavy/Bofors resources:

| Setting | Heavy | Bofors |
|---|---:|---:|
| Maximum horizontal speed | 60°/s | 110°/s |
| Maximum elevation speed | 45°/s | 85°/s |
| Mouse sensitivity at 1× | 0.16°/pixel | 0.16°/pixel |
| Smoothing response | 24/s | 24/s |
| Elevation limits | 5–85° | 5–85° |
| Sight FOV | 58° / 30° zoom | 58° / 30° zoom |

These speeds are accessible gameplay tuning, not claimed historical traverse measurements. Sensitivity is scaled down with sight FOV and Space. Pending yaw error is bounded to 20° to avoid lengthy movement after an extreme mouse flick. Barrel speed remains limited regardless of input magnitude. `arrow_aim_enabled` optionally disables the keyboard alternative.

## Verification

`tests/aa_mouse_checks.gd` runs using X11/Xvfb and actual Godot mouse events (not the headless dummy mouse). It tests capture, relative motion, zoom, muzzle/camera alignment, projectile direction, fire cadence, pause, recapture, map release and dismount. It then tracks the same physics-driven Stuka approach, dive and pullout with each gun, using synthetic mouse events only. Bomb injury is disabled in this observation fixture so the complete manoeuvre can be inspected; ordinary bomb damage is unchanged and tested separately. The test driver is not shipped as gameplay aim assistance.

Run:

```sh
xvfb-run -a godot --path . --audio-driver Dummy --disable-render-loop --fixed-fps 120 --script res://tests/aa_mouse_checks.gd
```

The native test passed **32/32**. Mean angular error during approach/dive was about **0.03°/0.02°** for both guns. Pullout mean error was **5.10° heavy / 0.41° Bofors**, within the configured speed limits. Samples near the mechanical elevation stops and initial alignment were excluded. This is automated tracking, not a claim of human aiming accuracy.

Headless regression suites: layered AA 55, AA integration 114, presentation 14, ground controls 61, dive defence 47, keyboard 24, aircraft weapons 36 and radio 22 all passed (**373 checks**).

The release web build passed **21/21** checks in Chromium/ANGLE using actual pointer lock and mouse events, including mouse aiming, RMB zoom, LMB firing, pause/menu release, sensitivity adjustment and recapture. Full manual gameplay balance, high-DPI device feel and behaviour in browsers other than tested Chromium remain unverified. Native tracking covers the Stuka's full approach/dive/pullout; the browser smoke test checks live encounter controls rather than a complete human-flown defence mission.
