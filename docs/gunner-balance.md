# Rear gunner balance audit and tests

The default Stuka gunner is **Pilot**. Flight forces, enemy manoeuvre logic,
component multipliers, player guns, health, smoke, sparks and destruction rules
are preserved. Changes are observation/aiming limitations and shared telemetry.

## What caused the old behaviour

The previous gunner read the target's exact velocity and solved a quadratic
intercept each frame. It had finite 75°/s traverse and a 0.22° burst bias plus
0.15° individual dispersion, but no reaction time, perception delay, uncertain
speed/range estimate or motion-dependent tracking error. Its target was the
aircraft origin, **not the engine component**. A fighter aiming at the Stuka
presents its nose/engine first along that origin ray; the engine's existing
damage multiplier therefore made accurate defensive fire especially costly.

A pre-change live-projectile fixture, 30 simulated seconds per distance and
seed 1943, recorded Spitfire hit percentages of 94.0% at 100 m, 51.9% at 300 m
and 27.8% at 500 m. At 500 m, 19 of 37 hits struck the engine. This was a
diagnostic fixture, not historical evidence or a flight encounter.

## Human aiming model

`RearGunner` observes the whole aircraft's position with angular measurement
noise at a configurable sample interval. Observations arrive after a delay;
velocity is estimated from successive positions and filtered. It never reads
target velocity or component locations. Estimated range and approximate lead
have separate judgement errors. A view-plane silhouette offset avoids locking
every burst onto one centreline point without selecting a component.

At least two observations and sufficient visible reaction time precede firing.
During a burst, the gunner extrapolates its delayed position/speed estimate
without applying fresh sight corrections. Between bursts it partially corrects
a correlated angular bias and reassesses range/lead. There is no hit-result
feedback that secretly improves its aim.

Apparent silhouette size and Stuka bank affect visibility. Poorer visibility
increases observation/tracking error and delays recognition. Target line-of-sight
angular speed increases tracking error. Own bank, rotation, excess acceleration
and smoothly changing vibration add error/wobble; manoeuvre severity also adds
individual round dispersion. Mechanical and human traverse rates cap movement
of the actual visible barrel. Cockpit impairment still reduces traverse.

There is no maximum distance switch. Estimated flight time may exceed the
existing 1.15 s bullet lifetime and suppress impossible shots; a bad range
estimate can still launch a round that expires before reaching its target.
Relative motion and inherited shooter velocity affect actual reach. A 500 m
crossing shot requires about 0.65 s of flight at nominal muzzle speed, so lead
errors matter. A fixed angular error produces a larger miss at greater distance.

## Skill configuration

Edit `gunner_profiles/cadet.tres`, `pilot.tres` or `ace.tres`, or supply a
`GunnerSkillProfile` Resource through `EnemyStuka/RearGunner.skill_override`.
The F3 selector chooses a preset and requires reacquisition. R retains selected
skill/Inspector tuning. Skills do not alter bullet damage/speed/lifetime.

| Parameter | Cadet | Pilot | Ace |
| --- | ---: | ---: | ---: |
| Reaction time, s of clear visibility | 0.95 | 0.60 | 0.35 |
| Observation delay / interval, s | 0.35 / 0.20 | 0.22 / 0.15 | 0.12 / 0.09 |
| Base tracking / measurement error, degrees | 0.65 / 0.12 | 0.38 / 0.07 | 0.23 / 0.04 |
| Range / lead judgement error fractions | 0.20 / 0.25 | 0.12 / 0.14 | 0.06 / 0.07 |
| Human traverse, degrees/s | 30 | 42 | 60 |
| Between-burst correction fraction | 0.35 | 0.55 | 0.70 |
| Target angular-motion error, degrees per rad/s | 1.50 | 1.10 | 0.65 |
| Bank error at 90°, degrees | 0.30 | 0.20 | 0.12 |
| Manoeuvre error per rad/s or excess g, degrees | 0.45 | 0.30 | 0.20 |
| Burst duration / rest scales | 0.80 / 1.30 | 1.00 / 1.00 | 1.20 / 0.75 |

Profiles also expose velocity learning, silhouette offset, recognition angle,
vibration and reacquisition time. These are adjustable gameplay approximations,
not authenticated wartime crew performance. Existing mount arcs remain ±70°
astern and −12°/+60° elevation, with a 75°/s mechanical cap.

## Obstruction and consistent ballistics

The direct sight line and aimed barrel ray test terrain, buildings and aircraft.
Before spawning **each dispersed round**, a short ray checks all the Stuka's own
body and component sensors, including wings, fuselage, rudder and elevator.
A round aimed through them is rejected even though the shared projectile's owner
exclusion normally prevents self-hits. Foreign geometry is skipped only by this
short own-airframe check; the actual projectile still collides with it.

All guns use `WingGuns` and `ProjectilePool`: pooled straight projectiles,
inherited aircraft velocity, lifetime, swept previous-to-next-position collision,
the same teams, component sensors/multipliers and hit sparks. Individual angular
dispersion is applied around the actual shot direction, including the swivelling
rear mount.

| Weapon | Guns × rounds/s | Raw damage | Muzzle speed | Lifetime | Aim arrangement |
| --- | ---: | ---: | ---: | ---: | --- |
| Spitfire | 8 × 12 | 4 | 850 m/s | 2 s | Wing convergence at 250 m |
| Sea Gladiator | 4 × 12 | 4 | 850 m/s | 2 s | Existing gun ports/convergence |
| Stuka forward | 2 × 6 | 2 | 650 m/s | 2 s | Existing bounded AI assistance |
| Stuka rear | 1 × 16.67 | 1.5 | 765 m/s | 1.15 s | Human-estimated aim, 0.15° nominal round spread |

Player convergence makes 200–300 m aligned passes useful; both fighters have
considerably greater concentrated firepower than the single rear gun. Forward
AI's existing 650 m opening-fire rule is unchanged. Nominal rear ballistic
reach is approximately 880 m for equal aircraft velocities, not a guaranteed
effective range. Gravity drop, wind and cartridge-specific terminal ballistics
are absent for **all** guns. Changing those would be a separate shared upgrade.

## Measurements and checks

**559/559 checks passed across nine suites on Godot 4.6.3**, including
**162/162 gunner balance checks**. Import/run commands are in the README.
`tests/gunner_balance_checks.gd` writes [machine-readable results](gunner-balance-results.json).

Accuracy trials use actual dispersed swept bullets against frozen, intact
fighter silhouettes in a clear rear quarter at 200 m altitude. Hull and local
integrity are restored every tick to avoid wreck geometry or damage-induced
movement bias. Each case combines three seeds (1943, 7, 29), 20 simulated
seconds each: 72 trials across two fighters, three skills and four distances.
The older baseline used one seed and a different duration; it is indicative,
not a statistically matched controlled experiment.

| Pilot target / distance | 100 m | 300 m | 500 m | 700 m |
| --- | ---: | ---: | ---: | ---: |
| Spitfire aircraft hit percentage | 56.7% | 18.7% | 8.3% | 1.6% |
| Sea Gladiator aircraft hit percentage | 57.5% | 25.8% | 9.9% | 2.5% |

Close Spitfire percentages for Cadet/Pilot/Ace were 34.4% / 56.7% / 64.3%.
Long-range hits remained possible; individual seed/case variation means an Ace
does not necessarily have the highest percentage in every small sample.
At 500 m Pilot hit the Spitfire 21 times out of 252 shots; six struck its engine,
with other hits on cockpit, elevator and both wings. Engine hits remain
legitimate and dangerous rather than being filtered out.

Normal rigid-body moving trials retain production Pilot aiming. Three 12-second
Sea Gladiator runs per condition measured 12.0% hits when steady versus 7.2%
when weaving, with mean engagement distances 317/345 m and angular motion
0.25°/s versus 3.25°/s. Both geometry and range changed during the manoeuvre;
this is an encounter comparison, not an isolated angular-speed experiment.
A separately manoeuvring Stuka generated nonzero own-motion error and still fired.

Normally controlled, well-aligned moving attacks at an initial 180 m defeated
the Stuka with both fighters while its rear gun fired; the Spitfire ended at
100 HP and Gladiator at 97.1 HP in these seeded fixtures. Enemy navigation is
disabled in these attack fixtures to isolate weapon balance; existing live AI
pursuit/break/terrain tests also pass. Human dogfight difficulty is unverified.

Additional checks cover human reaction and burst correction, actual nonzero
shot dispersion, projectile travel time, every own wing/tail/fuselage safety ray,
terrain cover including a 30,000 m/s swept test, teams/self exclusion, destruction,
pause, cockpit failure/repair and clean R. The older geometry/lifecycle suite
explicitly uses a precise **test-only** profile; the new balance suite never
disables production human aiming errors.

## F3 and short playtest

F3 opens component visualization plus gunnery telemetry for player, Stuka front
and Stuka rear: accepted shots, damaging aircraft hits, percentage, last shot
range and hit counts per component. It also shows gunner state/skill, current
distance, visibility, target angular speed, aim error and last hit travel time.
Terrain/friendly/wreck impacts are not counted as damaging aircraft hits.
Reset Counters leaves health/components untouched; older airborne rounds are
excluded from the new denominator. Destruction retains counters for inspection,
even after wreck removal; full R starts fresh.

1. Choose Spitfire, take off and let the existing eight-second grace finish.
   Open F3, choose Pilot and reset counters. Make repeatable steady rear-quarter
   passes near 700, 500, 300 and 100 m. Long shots/hits remain possible; close
   tracking should be much more dangerous. Avoid prolonged tail following.
2. Repeat with weaving/banking passes. Watch angular speed/aim error rise.
   Observe the finite barrel swivel, pauses between bursts and reacquisition
   after leaving its view. Compare Cadet and Ace, resetting counters each time.
3. Cross its exact tail blind spot and low/side sectors, and place terrain or
   buildings between you. It must not shoot through its own visible body/tail/
   wings or damage you through cover. Existing rounds can arrive after trigger
   release and should still stop at newly introduced cover.
4. Use aligned 200–300 m passes with Ctrl, rather than holding a distant tail
   chase. Inspect player hit counts and Stuka component damage. Repeat using
   Sea Gladiator. Damage its cockpit to verify impaired tracking/crew failure.
5. Destroy either aircraft, inspect retained counters, then R. Verify exactly
   one fresh Stuka, restored health/components, cleared rounds/effects/statistics
   and renewed takeoff grace. Skill choice should persist.

Rendered Linux Compatibility close-ups were inspected for the visible crew,
barrel/flash and both F3 panels. Native mouse/keyboard checks passed 16/16,
including preset selection in the actual dropdown and W/Ctrl afterwards.
Manual encounter feel, Windows Godot 4.7/ANGLE,
and authentic historical mount/accuracy measurements remain unverified.
