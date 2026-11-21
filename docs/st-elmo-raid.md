# Raid on St Elmo and Stuka free roam

**Raid on St Elmo** is a fictional single-player Axis mission on the existing Malta map. Open **Missions → Raid on St Elmo → Start Raid**. You begin offshore in a Ju 87 with its engine running and one bomb on the rack. The gold marker and **M** map identify a fictional storehouse inside the fort. An Allied Sea Gladiator intercepts after a delay.

For repeatable practice, open **Malta · Airfield / Mode Options**, choose an airfield and select **Ju 87 Stuka · airborne bombing free roam**. The Stuka starts offshore and carries one ready bomb at a time, with unlimited reserves. The HUD shows a 15-second reload countdown. Bombs already falling remain active when another becomes available.

## Controls and results

| Control | Action |
| --- | --- |
| **X** | Release the attached bomb |
| **B** | Toggle the Stuka’s dive brakes |
| **F** | Fire its forward guns |
| **M** | Open the Malta map |
| **F1** | Show the full controls |
| **R** | Restart the session |

The rear gunner aims and fires automatically within its traverse and line-of-sight limits. The audio panel has saved **Raid commander volume** and **Raid subtitles** settings. Seven synthesized German radio lines have English subtitles. The falling bomb has its own positional whistle, separate from the aircraft’s dive siren.

| Result | Condition |
| --- | --- |
| **2 stars** | A direct hit on the marked storehouse deals enough damage to the designated target sections. The fighter may survive. |
| **1 star** | The released bomb misses or does insufficient target damage, and the fighter is destroyed. The order of those events does not matter. |
| **Continue** | The fighter is down and the bomb is still attached, or the bomb missed and the fighter is still active. |
| **Failed** | The Stuka is lost before a qualifying result. An attached bomb does not count as a drop. |

If the Stuka is lost with a bomb already falling, scoring waits for impact. **Retry** rebuilds the aircraft, objectives, structures and effects. Free-roam damage persists until **R** or leaving the session.

## Destruction and tuning

The target storehouse, its parapets, nearby raid annexes, and the procedural airfield hangars’ roof and wall panels have separately identified damage sections. A collapsed section drops bounded physical fragments, disables its intact collider and leaves persistent rubble. The original fort envelope and legacy imported Valletta, Mdina and Cottonera meshes still use combined static geometry and need segmented authoring before their masonry can collapse. Hangar trusses, gables and floors remain static.

Open-ground strikes leave a surface-aligned crater representation. Runways and stone receive surface marks, and sea impacts produce a splash. Terrain collision stays fixed.

- [PlayerStuka](../scripts/player_stuka.gd) sets the reserve policy and reload duration.
- [StElmoRaid](../scripts/st_elmo_raid.gd) owns the spawn delay, difficulty, scoring threshold and radio sequence.
- [RaidBomb](../scripts/raid_bomb.gd) owns the swept impact, positional audio and occlusion-aware section damage.
- [RaidRange](../scripts/raid_range.gd) and [BombStructureSection](../scripts/bomb_structure_section.gd) define stable section IDs, visual states and collapsed collision.

See the [development entry and verification](development-updates/2026-11-20-st-elmo-raid.md).
