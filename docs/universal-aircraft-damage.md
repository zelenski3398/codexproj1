# Universal aircraft failures and crash outcomes

## Audit before implementation

The inspected source baseline is `7749042`. `FlightAircraft` (`scripts/aircraft.gd`) is the shared force-driven RigidBody3D for Spitfire, Sea Gladiator, Stuka and Italian aircraft. Current Italian definitions contain CR.42, C.200, C.202 and the three-engine SM.79. No Ju 88 scene, model or definition exists.

Reuse: `AircraftDamage` owns independent integrity and sensor hitboxes from aircraft-specific `.tres` profiles; `AircraftHitbox` forwards swept projectile hits; existing lift/drag/balance/power/control factors feed the original force integrator. `AircraftHealth` owns hull HP and one-shot depletion. `DamageEffects` pools 128 CPU mesh particles per aircraft in world space. `AircraftImpact` fragments actual model triangles into physical chunks; `AircraftImpactService` caps positional audio/effects and clears session ownership. Terrain, water exceptions, pilot interaction and mission destruction signals already work.

Gaps: engine/tank damage is aggregated, including all three SM.79 nacelles; health depletion always requests an airborne fireball; all dry crashes use one breakup; no load-dependent detachment, adjacency fire, component scars, landing-gear health, independent propellers or configurable crash categories exist. Fuel leaks already reduce endurance without reducing power until empty. AI already trims damaged wings using pilot commands. No existing high-fidelity metal/fabric tear, seizure or scraping recordings were found in the aircraft impact profile; existing synthesized impact/water/explosion assets must remain labelled placeholders.

The implementation extends these owners rather than replacing flight, projectiles or missions. `destroyed` remains the one-shot combat/mission loss event; it must not imply a fireball. Mechanical engine failure alone must not emit it. New resources and tests document the intended change from the former uniform explosion behaviour.
