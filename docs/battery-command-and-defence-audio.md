# Player-directed heavy AA battery and supplied defence audio

Each Malta airfield retains four heavy guns and two independently mountable Bofors. A separate, damageable predictor post stands beside the first heavy emplacement at local X47, apron-centre Z−80, away from the runway, parking and driving lane. Its desk, tripod and optical predictor are original procedural placeholders. No terrain, road geometry, aircraft physics or ammunition rules were replaced.

## Controls

Walk to the labelled post and press **F**. Move the mouse to look; **RMB** designates the hostile aircraft nearest the centre of the sight, or designates airspace/terrain if no hostile is visible. Holding RMB also zooms. **LMB** issues one salvo to ready, operational heavy guns. **F or E** exits. Escape pauses and releases capture; mouse sensitivity uses the existing AA pause slider. Individual AA guns remain available through E. Bofors are never included in coordinated heavy salvos. Ammunition stays unlimited and loading stays automatic.

F remains the existing alternative fire key in individual guns and aircraft. At a command post, F explicitly enters/exits; its keypress cannot accidentally issue a salvo. One controller and camera remain active. The command-post view shows selected target/distance, a projected predicted-intercept marker, operational/ready counts, valid/approximate solution status, pending orders and all four individual reload timers.

## Fire control and balance

`AAFireControl.solve()` finds the earliest ballistic intercept of a constant-velocity target with a gravity-affected shell. It brackets and bisects the low-time solution within the shell's existing lifetime. Every gun uses its actual muzzle position, 790 m/s shell speed and 9.81 m/s² gravity. Timed fuzes come from that gun's estimated travel time. The solver never creates an explosion or applies damage.

Only a player firing decision creates orders. Guns slew to the designated solution at their existing limited traverse/elevation speeds, then release their own pooled swept-collision shells. Each gun starts its own five-second reload. A ready gun can be ordered even when only an approximate ballistic solution exists, provided elevation is physically attainable. Unreachable directions are rejected. Orders expire rather than accumulating indefinitely. Designating another target, dismounting, opening a menu, losing focus, death or mission completion cancels pending orders. A gun lost mid-salvo cannot leave a stale order blocking later salvos. Unoccupied posts and uncommanded guns never search for targets or initiate fire.

`AACommandStation` exports the main balance settings:

| Setting | Default |
|---|---:|
| Salvo stagger | 0.3 seconds |
| Order lifetime | 6 seconds |
| Tracking/prediction refresh | 0.1 seconds |
| Common prediction position error | 8 m standard deviation per axis |
| Estimated velocity error | 2 m/s per axis |
| Manoeuvre uncertainty multiplier | 0.35 |
| Tracking-time offset | 0.15 seconds |
| Independent gun difference | 4 m per axis |
| Firing alignment tolerance | 0.35° |
| Post health | 150 HP |

The gun's existing dispersion is additional. Tracking assumes constant velocity; real manoeuvres, stale estimates, correlated battery error and independent trajectory differences can cause misses. This is an accessible gameplay predictor, not a claim of exact wartime fire-control performance. The existing catastrophic direct-hit and nearest-component fragmentation damage are retained, including direct/blast exclusion to prevent double damage.

The post has its own collision and damage receiver. Existing enemy bullets and bombs can destroy it. In the dive-defence mission, Stukas may target the occupied post through their normal dive controller, and the mounted soldier retains a live damage capsule. Post destruction ejects a surviving operator, cancels coordination and leaves surviving guns usable individually. Operator death still fails the mission immediately; losing only the post does not count as losing all six emplacements.

## Supplied recordings

- **Harrington radio:** complete supplied approximately 30.2-second recording, played once on mission start through the non-spatial player radio. Engine, weapons and siren audio are temporarily ducked by 8 dB. No verified transcript was provided, so no dialogue was invented or subtitled.
- **Air-raid siren:** complete supplied 18-second recording, looped spatially at the home airfield from mission start, including on foot, preparation and inter-wave intervals. It stops on mission completion, failure or leaving; retry starts one fresh loop. Waves never stack or restart the alarm.
- **Jericho trumpet:** supplied eight-second recording looped on each attacking Stuka only while its real downward velocity, nose-down attitude and speed support a dive. It fades out during recovery and stops on destruction or mission exit. Gain is distance attenuated and pitch varies slightly with airspeed.

All three clips were converted to mono 44.1 kHz Vorbis with consistent loudness and headroom. Original filenames, hashes and settings are in `assets/audio/defence/sources.json`; reproduce with `tools/prepare_defence_audio.py --source-dir <folder>`. No replacement voice, beep or synthetic siren was generated. The filenames do not establish historical authenticity. Retry resets all sound latches and stops old voices, sirens and dive loops. Existing Italian-interception speech is unchanged.

## Changed systems

- New command post and ballistic solver: `aa_command_station.gd`, `aa_fire_control.gd`.
- Existing gun, battery and soldier interaction extended for command authority, placement, F entry and physical firing.
- Existing defence director and bombs extended for post targeting, independent damage, operator injury and cleanup.
- Mission-owned audio: `dive_defence_audio.gd`, `stuka_dive_audio.gd`, supplied Ogg assets; `mission_radio.gd` gains optional subtitle text.
- Read-only web diagnostics, CI checks, native/physical engagement tests and browser smoke test added.

## Validation and limitations

New automated tests: command logic **36/36**, physical aircraft engagements **17/17**, audio lifecycle **20/20**, desktop mouse/camera interface **8/8**. The engagement fixtures use actual force-driven SM.79 level flight, a banking C.200 and a descending Stuka. An observation run damaged the bomber and Stuka while the manoeuvring fighter escaped damage; this is one sample, not a statistical hit-rate claim. Bomb injuries are disabled only in the engagement observation fixture; ordinary destructive bomb/post/operator behaviour is tested separately.

Regressions passed for defence waves, existing radio, ground controls, physical road access, individual AA, component damage, weapons, keyboard controls and heavy fragmentation. The existing desktop AA mouse suite passed **32/32**. The release web export passed **11/11** Chromium/ANGLE checks, including real walking/F mounting, explicit RMB designation, one four-shell LMB salvo, continuous mission-start siren, actual diving-aircraft Jericho playback and clean dismount. No script, shader, resource or audio errors were reported. Native command UI was rendered and inspected in Compatibility mode: [preview](previews/aa-battery-command.png).

Full human mission balance, subjective listening/mixing, long statistical accuracy trials, high-DPI devices and browsers other than tested Chromium remain unverified. The post has no animated predictor crew. Ballistics retain the project's gravity-only artillery model, without wind, shell drag or historical fragmentation simulation.
