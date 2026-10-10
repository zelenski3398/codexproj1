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

There is now **no arbitrary maximum rear-gun firing range**. Bullet lifetime
and relative motion limit ballistic reach; apparent target size, reaction,
tracking error and uncertain lead reduce effective accuracy at distance.
Human skill parameters are prototype tuning values, not measured wartime hit
probabilities. See [the balance audit and trials](gunner-balance.md).

Historical source requests in this task returned HTTP/proxy **403**, including
the RAF Museum, MG 15/Ju 87 reference entries and wartime-material archives.
The mount arcs and historical practical accuracy could not be verified against
a primary manual here. These links are for follow-up verification, **not claimed as
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

The gunner independently watches an eligible hostile player within its
**±70 degrees astern**, **−12 to +60 degrees elevation** sector.
Traverse has a 75 degrees/s mechanical limit; Cadet/Pilot/Ace human limits
are 30/42/60 degrees/s, further reduced by cockpit impairment.
It observes noisy whole-aircraft positions after a perception delay and
estimates velocity from successive observations. It does not read the player's
exact velocity or component positions. Range and lead judgement remain imperfect;
sight corrections occur between bursts. Smaller apparent silhouettes and banking
reduce visibility, while target angular motion, own acceleration/rotation,
banking and vibration increase aiming errors.

Pilot bursts last 0.45 s with 1.4 s rests. Raw damage remains 1.5,
speed 765 m/s, lifetime 1.15 s, nominal dispersion 0.15 degrees.
Dispersed projectiles inherit Stuka velocity and sweep their entire physical
step through the same terrain/component/team collision system as player rounds.
**Each actual dispersed shot** checks all the Stuka's collision bodies and
component sensors before spawning; owner exclusions cannot permit shooting
through its own tail, wings or fuselage. Target and barrel sight rays check
terrain/buildings. The centreline blind spot remains.

Forward guns hold during evasion; the rear gun can defend during a break.
Complete cockpit failure disables it. Destruction, pause and reset share the
existing lifecycle; R clears all pools/effects and spawns one fresh enemy.
Close stationary tail following remains dangerous; deflection, break passes
and leaving the mount's sector are safer than relying on a distance switch.

## Tuning and short test procedure

In the Remote Inspector, select `EnemyStuka/RearGunner` for skill/Resource override, arcs,
traverse, burst/rest, bullet rate/speed/damage/lifetime. Select `EnemyStuka/EnemyPilot`
for acquisition/retention, grace, threat range, cooldown, tactical height,
prediction and bank limits. Exported difficulty persists across R in the current
session. Defaults are in the scripts. Pool capacities initialize at creation:
384 per forward station and 128 for the rear station.

1. Start either fighter and take off. The enemy stays harmless while parked
   and during the eight-second grace; its HUD then shows `INTERCEPT`.
2. Follow 250–450 m behind, slightly above or off the centreline to clear the
   tail. Observe the swivel, flashes/tracers, rear-gunner warning and HP loss.
   Compare 100, 300, 500 and 700 m: hits become less frequent, but there is no
   500 m switch. Outside the rear sector, new firing must stop; existing rounds
   retain their lifetime. F3 shows actual hits, range and struck components.
3. Compare the blocked centreline with a rear-quarter approach. Put terrain
   or buildings between the planes: both stations must stop shooting.
4. Aim at its tail within 650 m. Expect a `BREAK LEFT/RIGHT` and physical bank,
   with a safe descent when altitude allows. Repeat after its cooldown. Excess
   close-range closure may produce `HIGH YO-YO`; turning pursuit of a faster
   target at safe altitude may request `LOW YO-YO`.
5. Use F3 to damage/repair its cockpit. Full cockpit failure disables the gunner
   before 0 hull HP. Destroy the enemy, then R: rear rounds/flashes, effects,
   damage and combat memory must clear.

Frozen fixtures isolate real projectile arcs/reach/cover; moving trials verify
live hits and physical defensive turns. Rendered checks use Linux Compatibility.
Manual dogfight feel and Windows Godot 4.7/ANGLE remain unverified.
