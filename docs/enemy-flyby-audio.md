# Enemy flyby audio

Enemy aircraft share a positional engine treatment with distance-dependent
level/timbre, relative-motion Doppler, and a separate optional airflow loop.
Player flight, AI, damage, listener ownership and controls are unchanged.

## Assets and missing recording

The engine uses the existing mono idle/flight Ogg recordings selected by
`GameAudioMixer.engine_stream()`. The Spitfire loops remain the existing fallback
for the Stuka and Italian aircraft; these are not newly matched historical
engine recordings. The Sea Gladiator retains its radial-engine pair.

**A suitable airflow recording is missing.** The production airflow slot is
empty and silent. Supply a seamless mono rushing-air loop with a textured
“whoosh–shhhhh” character, without engine/siren/voice, and assign it to
`airflow_stream` in [the shared profile](../audio_profiles/enemy_flyby.tres).
The loop is duplicated/configured for looping at runtime. No Stuka siren, beep,
or synthetic placeholder is used as gameplay airflow. Therefore the requested
full rushing-air sound cannot yet be heard; the engine flyby works independently.

## Integration

[AircraftAudio](../scripts/aircraft_audio.gd) adds
[EnemyFlybyAudio](../scripts/enemy_flyby_audio.gd) only for `CombatTeams.ENEMY`.
It keeps the two original engine loops, RPM/throttle/power response and shutdown
handling. The component samples actual rigid-body velocity (including engine
mount angular motion), plus the active viewport listener, falling back to its
current camera. Walking, chase, truck, individual AA and battery cameras already
become current through the existing interaction system.

One bounded, smoothed classical Doppler ratio uses source and listener radial
velocity. Built-in source Doppler is disabled for these enemy sources, preventing
double shifts. Listener switches/teleports suppress motion transients briefly.
Godot still provides listener-relative spatial panning; manual attenuation avoids
multiplying two distance curves. At distance the idle drone dominates; proximity
restores the fuller flight layer without altering RPM.

Airflow has a continuous envelope using distance and **relative** speed, with
fast attack and longer release. It never restarts every frame. Matching world
speeds produce little airflow even at short range. Continuous looping needs no
one-shot cooldown; the exported attack/release settings govern the pass tail.
Failed engines fade out; gliding airflow may continue if a recording is supplied.
Destruction/crash/reset clears the layers; freeing the aircraft frees its voices.

All layers use the existing `Aircraft` bus, including volume, pause and radio
ducking. A conservative shared linear peak budget reduces concurrent enemy
voices without changing their relative distance/pan balance. This works with web
sample playback without depending on unsupported bus compressor effects. It
reserves headroom but cannot guarantee against clipping from arbitrary future
assets, user gain boosts or other simultaneous buses.

## Tuning

Open `audio_profiles/enemy_flyby.tres` in Godot's Inspector. Properties and default
values are declared in [AircraftFlybyProfile](../scripts/aircraft_flyby_profile.gd).

| Setting | Default | Purpose |
| --- | --- | --- |
| Engine volume / audible range | −7 dB / 4,500 m | Close loudness and distant fade |
| Reference distance / attenuation exponent | 120 m / 1.05 | Loudness falloff |
| Distant flight mix / full-engine range | 0.28 / 240 m | Drone-to-roar blend |
| Doppler strength / pitch limits / blend | 0.9 / 0.72–1.45 / 0.16 s | Shift intensity, safety, smoothing |
| Listener settle time | 0.35 s | Camera change protection |
| Airflow stream | Empty | Required mono seamless air-rush recording |
| Airflow volume / range | −9 dB / 260 m | Independent close-pass layer |
| Minimum / full relative speed | 30 / 110 m/s | Reject nearby formation flight |
| Airflow intensity / attack / release | 1 / 0.12 / 0.75 s | Build and lingering tail |
| Enemy peak budget | 0.5 linear | Shared enemy voice headroom |

The resource is shared read-only at runtime; envelopes and listener tracking are
per aircraft. Assign a different profile to `AircraftAudio.enemy_flyby_profile`
for a specific enemy variant. Existing menu Aircraft volume controls both layers.
`diagnostic_state()` exposes distance, relative/radial speed, gain, Doppler,
airflow envelope/starts, crowd gain and listener resets for debugging.

## Reproduction and validation

```sh
godot --headless --editor --import --quit
godot --headless --fixed-fps 120 --script res://tests/flyby_audio_checks.gd
python tools/build_flyby_web_fixture.py
node tools/flyby_web_smoke.cjs
bash tools/build_web.sh
node tools/audio_web_smoke.cjs
```

The isolated fixture freezes test aircraft and supplies disclosed acoustic motion
samples; it does not change production AI or claim an interactive dogfight.
The native suite captures actual engine samples, compares distant/close energy
and stereo panning, checks approach/recede pitch, matched-speed suppression,
listener changes, concurrent-voice budgeting, radio ducking, failure/destruction
and removal. A clearly labelled test-only sine verifies the optional looping
asset hookup; it is never assigned to the production profile.

For a listening test, spawn an enemy in Malta and compare a head-on pass, crossing
pass, distant pass and formation-speed flight. Switch between walking, truck,
aircraft and AA; pause, resume and listen during commander speech. Repeat with
several enemies. After supplying the missing airflow loop, verify that it builds
before closest approach, leaves a soft tail, and does not repeatedly burst when
flying alongside. Subjective listening, real hardware and Firefox/Safari remain
manual checks; automated output analysis does not establish perceived realism.

### Recorded results

Godot 4.6.3: flyby **32/32** (headless audio capture and repeated with a native
window), existing audio **37/37**, radio **22/22**. Chromium: isolated flyby
**11/11**, production audio regression **18/18**. Both exports completed without
script/resource errors. Captured browser near/far RMS was about **16×**, and
native three-enemy peak samples stayed below **0.18** in the initial capture.
These are fixture measurements, not universal loudness guarantees.
