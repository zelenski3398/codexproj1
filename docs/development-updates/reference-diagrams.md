# Supplied reference diagrams, reconstructed against the source

[Documentation updates](README.md) · [Complete historical report](../WWII-Malta-Development-Complete.md)

These four diagrams preserve the concepts in the user's pasted text: development evolution, aircraft damage/combat, player interaction and Malta geography. The paste contained rendered-chart CSS and concatenated labels rather than editable Mermaid or recoverable edge definitions. They have therefore been redrawn as clean Mermaid, using inspected implementation rather than copying styling or claiming the lost layout was recovered exactly.

## 1. Development evolution

The original illustrative grouping put “combat and missions” before Malta. Git shows basic combat before Malta, but authored missions after it; this chronology separates them. Earlier dates and changes are traceable through the [23-milestone timeline](../development-history/02-development-timeline.md). The final update is documented separately in the [encounter addendum](2026-10-16-random-encounters.md).

```mermaid
flowchart TD
    A["7 Oct: force-driven Spitfire flight prototype"] --> B["8-10 Oct: aircraft guns, enemy AI and localized damage"]
    B --> C["10 Oct: elevated continuous Malta, airfields and boarding"]
    C --> D["11-12 Oct: Survival and authored interception missions"]
    D --> E["13-15 Oct: truck, manual AA, dive defence and battery command"]
    E --> F["15-16 Oct: Valletta and Mdina, source-gated Cottonera tooling"]
    F --> G["16 Oct update: requested random free-roam encounters and C.202"]
```

## 2. Aircraft damage and combat flow

The supplied “Critical hit?” concept is shown as actual component-integrity degradation and fuel-hazard rolls. There is no invented standalone critical-hit manager. Hull transfer occurs alongside integrity loss; mechanical failure need not wait for zero hull HP. Source: [ProjectilePool](../../scripts/projectile_pool.gd), [AircraftHitbox](../../scripts/aircraft_hitbox.gd), [AircraftDamage](../../scripts/aircraft_damage.gd), [AircraftHealth](../../scripts/health.gd) and [FlightAircraft](../../scripts/aircraft.gd).

```mermaid
flowchart TD
    W["WingGuns fires from actual ports"] --> P["ProjectilePool swept collision"]
    P --> H["AircraftHitbox.receive_projectile_hit"]
    H --> D["AircraftDamage.apply_damage and component multipliers"]
    D --> C["Component integrity and optional fuel-hazard rolls"]
    C --> Critical{"Mechanical degradation or tank hazard?"}
    Critical -->|Yes| Failure["Reduced lift, drag balance, power or controls / fuel leakage or fire"]
    Critical -->|No| Normal["Retain existing component performance"]
    D --> Hull["AircraftHealth updates hull HP"]
    Hull --> State{"HP depleted?"}
    State -->|Yes| Dead["FlightAircraft._destroy disables engine commands and guns once"]
    State -->|No| Live["Continue current aircraft life"]
    Failure --> Physics["Next shared flight-force integration"]
    Normal --> Physics
    Live --> Physics
    Dead --> Wreck["Passive physics and enemy ground-impact wreck lifecycle"]
```

## 3. Player interaction state machine

The original OnFoot/Aircraft/Truck/AAGun diagram is retained and extended with the implemented battery post. Guards come from [MaltaMission](../../scripts/malta_mission.gd) and [AirfieldInteraction](../../scripts/airfield_interaction.gd). These are behavioural states, not a claim that one controller enum owns every entity. Free-roam C requests an enemy without changing this control state.

```mermaid
stateDiagram-v2
    [*] --> OnFoot
    OnFoot --> Aircraft: E near stopped serviceable aircraft
    Aircraft --> OnFoot: E grounded, stopped, engine off, clear exit
    OnFoot --> Truck: E near stopped truck
    Truck --> OnFoot: E low speed, grounded, clear exit
    OnFoot --> AAGun: E near operational gun
    AAGun --> OnFoot: E or occupied gun destroyed
    OnFoot --> BatteryCommand: F near operational post
    BatteryCommand --> OnFoot: F or E or post destroyed
    note right of OnFoot
        Exclusive controller ownership through MaltaMission and AirfieldInteraction.
        No remote truck-to-gun mounting.
        Aircraft entry is disabled in the dedicated AA-defence mission.
    end note
```

## 4. Malta geographic data pipeline

This is a conceptual data-flow diagram, not a fabricated geographic map. Source: [prepare_malta.py](../../tools/prepare_malta.py), [grade_malta_terrain.py](../../tools/grade_malta_terrain.py), [malta_road_surface.py](../../tools/malta_road_surface.py), [HistoricCity](../../scripts/historic_city.gd) and [MaltaWorld](../../scripts/malta_world.gd). Historical settlements are additive assets; they do not regenerate the island. Cottonera remains gated by missing source geometry.

```mermaid
flowchart TD
    Data["Geographic datasets: supplied OSM coast and 2012 DTM overview"] --> Convert["EPSG:32633 local metres relative to 14.4 E / 35.93 N"]
    Convert --> Terrain["Source elevation mesh, local grading and road refinement"]
    Convert --> Fields["world_data.json airfield positions and chart frame"]
    Scan["Historic road scan and landmark control points"] --> Roads["Warped road paths and terrain UV coverage"]
    Terrain --> Roads
    Fields --> Bases["Terrain-supported runways, parking and access"]
    Terrain --> Cities["Terrain-fitted Valletta and Mdina approximation assets"]
    Roads --> Cities
    Reviewed["Locally supplied, licensed and reviewed Cottonera features"] -.-> Gated["Cottonera import/compiler - empty pending real geometry"]
    Terrain --> Gated
    Terrain --> World["One continuous MaltaWorld with static collision"]
    Roads --> World
    Bases --> World
    Cities --> World
    Gated --> World
    Fields --> Map["MaltaGeography chart_uv / chart_to_world"]
```

The original audit's [17 detailed diagrams](../development-history/diagrams/README.md) remain unchanged. These four supplemental sources add readable overviews without rewriting the frozen history snapshot.
