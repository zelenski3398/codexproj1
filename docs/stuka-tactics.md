# Stuka rear gunner and pursuit

The gunner sits at the back of the tandem cockpit, not at the tail tip. Its gun
swivels independently and reuses `WingGuns`, swept `ProjectilePool` collisions,
teams, sparks and component damage. The aircraft flight controller is unchanged.

## Historical basis and research limitation

Early Ju 87 variants carried a flexible rear-facing **7.92 mm MG 15**; later
variants used a twin MG 81Z installation. This placeholder keeps a single
MG 15-style mount for its early-war appearance. Nominal 16.67 rounds/s (about
1,000 rounds/min) and 765 m/s are approximate reference values; short bursts
and long rests reduce game difficulty.

**500 m is a provisional practical game engagement cutoff.** It is not an
authenticated historical effective or maximum ballistic range. Airborne hit
probability depends on relative motion, deflection, visibility and training;
a generic machine-gun range does not establish a gunner's opening-fire distance.

Historical source requests in this task returned HTTP/proxy **403**, including
the RAF Museum, MG 15/Ju 87 reference entries and wartime-material archives.
The practical range and mount arcs could not be verified against a primary
manual here. These links are for follow-up verification, **not claimed as
consulted evidence**:

- [RAF Museum Ju 87 collection](https://www.rafmuseum.org.uk/research/collections/junkers-ju-87g-2/)
- [MG 15 reference entry](https://en.wikipedia.org/wiki/MG_15)
- [Ju 87 variants and armament](https://en.wikipedia.org/wiki/Junkers_Ju_87)
- [Basic fighter manoeuvres](https://en.wikipedia.org/wiki/Basic_fighter_maneuvers)
- [US Navy wartime fighter combat archive](https://www.ibiblio.org/hyperwar/USN/ref/FTC/index.html)

The tactics adapt general air-combat principles: break toward the attacking
side to force greater pursuit curvature, alternate breaks to change crossing
geometry, descend shallowly to build speed, and climb to shed excess closure.
These are simplified goals, not authentic Ju 87 doctrine. A slower dive bomber
cannot reliably out-turn or outrun a healthy Spitfire. There is no hidden engine
boost, teleportation or scripted aerobatics.

## Pursuit and defensive behaviour

Previously the AI required eight uninterrupted seconds above both 25 m and
35 m/s, then lost pursuit outside 1,800 m. Slow climbs or opening the distance
could leave it circling. Now eight airborne seconds above **12 m AGL** unlock
combat for that life, without a speed requirement. Grounded/destroyed players
remain protected. Acquisition is **3,200 m**, with acquired-target retention
until **7,500 m**. Terrain and countryside-boundary avoidance still take priority.

Navigation predicts a flight intercept at long range and switches to ballistic
nose alignment near a firing pass. Distance-dependent throttle closes at long
range and matches speed nearby to avoid endlessly overshooting. Tail attackers
within 650 m and a 55-degree cone trigger a bounded break when aimed at the
Stuka. A six-second defensive cooldown prevents continuous retriggering.
Centred repeated threats alternate break direction. Shallow descending breaks
and high/low yo-yos use normal pitch, roll, rudder and throttle, retaining
damage compensation, slew/rate limits and stall/terrain protection.

## Rear gun

The gunner independently tracks an eligible hostile player within **500 m**,
**±70 degrees astern**, **−12 to +60 degrees elevation**. Traverse is up to
75 degrees/s, reduced by cockpit impairment, with a 1.5-degree firing-alignment
limit. Direct-target, lead and barrel rays check terrain, aircraft and the
Stuka's own component hitboxes. The rudder/fuselage create a real centreline
blind spot. Bullets retain separate owner exclusions and team filtering.

Bursts last 0.45 s with 1.4 s rests, 0.22-degree burst aim error and 0.15-degree
shot spread. Bullets inherit aircraft velocity and lead target motion. Forward
guns hold during evasion; the rear gun can defend during a break. Complete
cockpit failure disables the gunner. Destruction, pause and reset share the
existing lifecycle; R clears all three pools and spawns one fresh enemy.

## Tuning and short test procedure

In the Remote Inspector, select `EnemyStuka/RearGunner` for range, arcs, traverse,
burst/rest, aim, bullet rate/speed/damage/lifetime. Select `EnemyStuka/EnemyPilot`
for acquisition/retention, grace, threat range, cooldown, tactical height,
prediction and bank limits. Exported difficulty persists across R in the current
session. Defaults are in the scripts. Pool capacities initialize at creation:
384 per forward station and 128 for the rear station.

1. Start either fighter and take off. The enemy stays harmless while parked
   and during the eight-second grace; its HUD then shows `INTERCEPT`.
2. Follow 250–450 m behind, slightly above or off the centreline to clear the
   tail. Observe the swivel, flashes/tracers, rear-gunner warning and HP loss.
   Move outside 500 m or the rear sector: new rear firing must stop. Existing
   rounds retain their lifetime.
3. Compare the blocked centreline with a rear-quarter approach. Put terrain
   or buildings between the planes: both stations must stop shooting.
4. Aim at its tail within 650 m. Expect a `BREAK LEFT/RIGHT` and physical bank,
   with a safe descent when altitude allows. Repeat after its cooldown. Excess
   close-range closure may produce `HIGH YO-YO`; turning pursuit of a faster
   target at safe altitude may request `LOW YO-YO`.
5. Use F3 to damage/repair its cockpit. Full cockpit failure disables the gunner
   before 0 hull HP. Destroy the enemy, then R: rear rounds/flashes, effects,
   damage and combat memory must clear.

Frozen fixtures isolate real projectile arcs/range/cover; moving trials verify
live hits and physical defensive turns. Rendered checks use Linux Compatibility.
Manual dogfight feel and Windows Godot 4.7/ANGLE remain unverified.
