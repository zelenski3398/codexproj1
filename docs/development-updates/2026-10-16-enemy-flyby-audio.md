# 16 October 2026 — Spatial enemy flyby audio

[Update index](README.md) · [Implementation and tuning](../enemy-flyby-audio.md)

Inspected exclusive range: `e13cef200ed63bc10efca04e0342e16efc3b1cbf..fbfab9dd1bf49bfdd61d893021a2e568f887c45d`.
The first commit in that range, `fae5faa`, published documentation only. The source
change is [fbfab9d](https://github.com/zelenski3398/codexproj1/commit/fbfab9dd1bf49bfdd61d893021a2e568f887c45d).

Previously enemy aircraft reused two generic 3D engine loops with a 12 m reference
size and 1,800 m maximum range. They enabled source Doppler but the active game
cameras did not enable matching listener motion tracking. This change adds the
shared `AircraftFlybyProfile` resource and per-enemy `EnemyFlybyAudio` component.
Distance attenuation and idle/flight timbre now work independently of RPM; a
single bounded relative-motion Doppler calculation replaces built-in enemy
Doppler. Active listener/camera changes get a brief motion-settling guard.

The independent continuous airflow envelope depends on proximity and relative
speed. No suitable airflow recording exists in the inspected assets, so its slot
remains null and silent. The shipped engine recordings are reused; no new
historically matched enemy recording or complete rushing-air sound is claimed.
Existing Aircraft-bus volume, radio ducking and pause routing remain intact.
A shared conservative enemy peak budget limits simultaneous voice contributions.
Player audio, flight, AI, mission and damage implementations were not rewritten.

## Validation evidence

- Native flyby checks: **32/32**, also repeated in a native graphical window.
  Actual near/far engine sample RMS differed by roughly 14× in the initial
  headless capture; native stereo energy followed source side. Three concurrent
  enemies remained audible below clipping in the captured test.
- Existing native audio checks: **37/37**. Radio checks: **22/22**.
- Isolated exported Chromium flyby fixture: **11/11**. Actual WebAudio output
  measured approximately 0.00377 RMS at 1,800 m and 0.06185 at 50 m; browser
  playback rate changed on approach, stereo panning followed source side, and
  shutdown silenced output.
- Full production web export and existing browser audio checks: **18/18**.
  No browser runtime errors; menu, input activation, guns, pause, boarding,
  engine stop and full restart remained operational.
- Original historical documentation validator: 50 frozen commit records,
  859 local/source links, no errors. Updated Markdown targets and Git whitespace
  checks passed. The original report was not silently expanded.

Tests use disclosed deterministic acoustic trajectories/frozen aircraft, actual
engine samples and native/WebAudio capture. A test-only diagnostic sine checks
the empty airflow slot's looping hookup; it is not a production sound. Manual
head-on/crossing dogfights, subjective speaker/headphone evaluation, audible
rushing air, and Firefox/Safari compatibility remain unverified. The native
suite waits for the audio thread to retire stopped streams before shutdown.

Future documentation should begin after the full source SHA above, including
the publication commit containing this addendum as documentation maintenance.
