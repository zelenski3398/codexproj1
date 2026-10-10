# Supplied music and aircraft sound

The complete 83-second **Wings Over Malta** theme plays on the aircraft menu
and continues through Malta airfield selection. It fades out on departure,
stays off during gameplay/pause, and returns when choosing another aircraft.
Only one theme player exists, independently of the loaded world.

Spitfire and Sea Gladiator each use the corresponding supplied idle-engine,
flight-engine and gun recordings. Engine layers blend with throttle, RPM
pitch rises smoothly, and engine component damage/fuel exhaustion reduce
power and sound. Stopped engines, parked aircraft and menu previews are
silent. Destroyed/crashed aircraft stop their engine and gun sounds. Reset
clears firing audio and restores the normal engine state. Malta boarding and
leaving retain the aircraft's engine, damage and fuel states.

Gun sound is triggered by successfully emitted salvos. It stops promptly
after release or between AI bursts. Obstructed rear-gunner shots and exhausted
projectile pools do not trigger sound. One looping voice per gun battery
handles sustained fire; eight wing guns do not allocate eight sounds per tick.
Forward/rear enemy guns use the same audio component and their actual mounts.

Engine and gun audio are spatial: aircraft position, distance and stereo
panning matter, with Doppler enabled. These are exterior chase-camera sounds;
there is no separate interior cockpit mix or terrain sound occlusion yet.
There are no supplied touchdown, tyre, impact or explosion clips, so those
visual effects retain their existing behaviour without invented recordings.
No Stuka-specific recordings were supplied: its inline engine and guns use
the Spitfire sounds as temporary placeholders, including the rear MG 15.

## Volume and browser playback

Click **AUDIO** on the right of the game to adjust **Master, Music, Aircraft
and Guns** volumes or mute everything. Settings persist in `user://audio.cfg`
(the browser's local project storage on web). The controls also work while
paused and do not capture the flight keyboard. Pause silences both gameplay
buses while retaining their settings.

In a browser, click **Play in Browser** to activate audio through a user gesture.
If the browser/site or tab is muted, unmute it as well as the in-game mixer.
Desktop uses Ogg streaming; web uses browser-native sample playback so audio
continues smoothly even when a software-rendered frame is slow. Live pitch,
volume, spatial panning, looping and bus controls are preserved on both paths.

The supplied WAV files were converted to about **1.7 MB** of Ogg assets.
The engine recordings needed short end/start crossfades to remove abrupt
loop discontinuities. Gun samples were trimmed to their active section and
crossfaded for sustained firing. Spatial clips are mono; music remains stereo
and retains its original duration. The source uploads remain untouched.
Conversion hashes/settings and attribution are in `assets/audio/`.
`tools/prepare_audio.py` reproduces the conversion with numpy and ffmpeg;
neither tool is needed to open/play/export the game.

## Components and tuning

| Component | Responsibilities and exposed tuning |
| --- | --- |
| `scripts/game_audio.gd` | Autoload mixer/theme/settings UI; `menu_fade_seconds`; default bus volumes in `volumes` |
| `default_bus_layout.tres` | Stable Master/Music/Aircraft/Guns routing; avoids runtime bus insertion issues in the Godot 4.6.3 web sample mixer |
| `scripts/aircraft_audio.gd` | Shared aircraft engine mix; `engine_volume_db`, `audible_distance`, `blend_seconds`, minimum/maximum pitch |
| `scripts/weapon_audio.gd` | Actual-salvo sound; `gun_volume_db`, `audible_distance`, `fade_seconds` |
| `scripts/wing_guns.gd` | `salvo_fired(rounds)` only when projectiles were emitted; `cleared` on reset/destruction |

Audio never changes flight forces, projectile ballistics, AI aim or damage.
The supplied gun recording is a sustained-firing texture, so its individual
recorded reports are not synthesized to match every configured bullet's exact
timestamp. The trigger/burst envelope follows real salvos and weapon state.

## Verification

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 120 --script tests/audio_checks.gd
bash tools/build_web.sh
node tools/audio_web_smoke.cjs
```

The dedicated native checks opt into Dummy-driver playback. Ordinary headless
gameplay checks skip starting sound voices, since they have no audible device.
Validation passed **37/37 native audio checks** and **18/18 release-browser
audio checks**, including nonzero native mixer captures and WebAudio output,
plus the existing keyboard, weapons, Malta and rear-gunner balance checks.
The browser checks observe actual WebAudio samples and exercise user
activation, theme transitions, mute, aircraft engine/guns, pause, departure,
boarding, engine shutdown and full reset. They require Playwright/Chromium as
documented in the web hosting guide.

For a listening check: choose both aircraft in turn; compare idle with W/S
throttle changes; hold/release Ctrl (F in browser); pause/resume; destroy with
H and reset with R. In Malta, board with E, start/stop with I, then exit and
board again. Check that no old engine/gun persists after returning to the menu.
Listen to a close enemy pass for positional sound/Doppler. Automated output
checks do not verify perceived mix quality on real speakers/headphones or
audio behaviour in Firefox/Safari.
