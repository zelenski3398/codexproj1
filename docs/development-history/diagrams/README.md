# Diagram sources

[Documentation contents](../README.md)

The numbered `.mmd` files are editable Mermaid sources. Matching blocks render within the corresponding chapters. The master repeats only the high-level architecture; diagram counts below count **unique diagrams**, not duplicated rendered blocks.

| Source | Rendered in |
| --- | --- |
| [01-architecture.mmd](01-architecture.mmd) | [Project overview](../01-project-overview.md) and master |
| [02-timeline.mmd](02-timeline.mmd) | [Timeline](../02-development-timeline.md) |
| [03-module-dependencies.mmd](03-module-dependencies.mmd) | [Architecture](../03-architecture.md) |
| [04-flight-states.mmd](04-flight-states.mmd) | [Flight](../04-aircraft-and-flight.md) |
| [05-damage-states.mmd](05-damage-states.mmd) | [Damage](../05-combat-and-damage.md) |
| [06-projectile-damage-sequence.mmd](06-projectile-damage-sequence.mmd) | [Combat](../05-combat-and-damage.md) |
| [07-player-controller-states.mmd](07-player-controller-states.mmd) | [Ground gameplay](../06-ground-vehicles-and-soldiers.md) |
| [08-terrain-pipeline.mmd](08-terrain-pipeline.mmd) | [Geography](../08-malta-terrain-and-geography.md) |
| [09-world-organization.mmd](09-world-organization.mmd) | [World organization](../08-malta-terrain-and-geography.md) |
| [10-aa-command-flow.mmd](10-aa-command-flow.mmd) | [AA systems](../07-anti-aircraft-systems.md) |
| [11-encounter-lifecycle.mmd](11-encounter-lifecycle.mmd) | [Encounters](../09-missions-and-ai.md) |
| [12-survival-lifecycle.mmd](12-survival-lifecycle.mmd) | [Survival](../09-missions-and-ai.md) |
| [13-interception-lifecycle.mmd](13-interception-lifecycle.mmd) | [Interception](../09-missions-and-ai.md) |
| [14-dive-defence-lifecycle.mmd](14-dive-defence-lifecycle.mmd) | [Defence mission](../09-missions-and-ai.md) |
| [15-dive-attack-ai.mmd](15-dive-attack-ai.mmd) | [Dive AI](../09-missions-and-ai.md) |
| [16-audio-routing.mmd](16-audio-routing.mmd) | [Audio](../10-audio-and-atmosphere.md) |
| [17-web-build.mmd](17-web-build.mmd) | [Web export](../11-performance-and-web-export.md) |

`development-activity.svg` is a separate static activity chart from actual UTC-normalized Git author dates in [activity.csv](../activity.csv), not another Mermaid diagram. Architecture edges express construction/calls or labelled inheritance, not a claim that every script is a separate Godot scene. State diagrams summarize verified guards/flags; only explicit mission strings are presented as literal runtime phase names. Geographic diagrams are data-flow/organization views, not invented maps.

For updating: edit the `.mmd` and the chapter's matching block together, parse with a GitHub-compatible Mermaid parser, and verify every named class/method against source. The validation report records the parser used for this snapshot.
