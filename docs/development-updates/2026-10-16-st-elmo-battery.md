# 16 October 2026 — St Elmo battery, spawning and continuous ground travel

[Update index](README.md) · [Controls, previews, files and assumptions](../st-elmo-battery.md)

Inspected exclusive range:
`73344f14724c745f3fd822fad36f02bfe0926896..ace5393b3ebc4d37d0d9057ba4980a0df67b9711`.

- `752fb4f` published the previous Cottonera documentation only.
- [37c6c83](https://github.com/zelenski3398/codexproj1/commit/37c6c83)
  made Pages artifact upload/deploy names explicit, retained uploads seven days,
  added export/upload checks and updated the official Pages actions to Node 24.
  This followed reported missing-site/missing-artifact deployment errors; it is
  not evidence of a confirmed live Pages deployment.
- [f0b6548](https://github.com/zelenski3398/codexproj1/commit/f0b6548d2c583f5b9adb9b5851d48a1fdcdd9d4f)
  implemented the fort, three crewed Bofors guns, local battery-command relay,
  fort departure choices and persistent soldier travel through the existing map.
- [ace5393](https://github.com/zelenski3398/codexproj1/commit/ace5393b3ebc4d37d0d9057ba4980a0df67b9711)
  closed the court/ramp seam, verified actual soldier traversal and corrected
  browser test assertion scoping. No aircraft physics changes were required.

## Before and after

The previous St Elmo was an angular rim/star mass with an empty drill court,
without selectable soldier starts or a fort battery. Malta departure exposed
only three airfields. The new fort has coastline-clipped layered walls, a raised
court with solid steps and a parallel ramp, open portico/barracks, an entrance
ramp and three supported firing platforms. It retains the original projected
anchor/orientation. Generation asserts that every platform lies entirely on the
supported deck. No supplied photo lighting, modern bridge, cars or watermark
were baked into the meshes.

`MaltaWorld` creates one `StElmoBattery` beside its existing `AirfieldAABattery`.
The airfield list stays at 18 guns for existing authored mission targeting;
the shared friendly-AA group now contains 21. `AirfieldInteraction` includes
both owners in its existing mounting/exclusive-control flow and checks friendly
crew clearance when choosing exits. Two old total-group assertions were updated
to reflect the three intentional additions, retaining all original gun checks.

`StElmoBofors` extends the existing manual gun instead of duplicating ballistics.
It reuses the light AA definition/model/pools/damage/effects and applies a quieter
fort report gain. `StElmoCrew` reuses the existing skinned pilot avatar and poses,
with khaki material overrides and an original helmet. Operators walk aside and
return on dismount; no dedicated boarding or crank animation is claimed.

The mounted gun is the battery aim leader. Explicit B toggles the mode. Other
guns individually traverse/elevate toward the same ray-designated world point,
check limits/alignment/obstructions, and fire physical rounds only while the
player holds fire. Stagger and every gun's reload remain independent. No target
search, autonomous aim/fire or perfect aircraft prediction was introduced.
Remote gun loss preserves remaining command; occupied loss releases the player.

`StElmoLocations` supplies one fort and three gun-side entries to the existing
departure picker/chart and in-game map travel row. `main.departure_spawn` stores
the original soldier departure separately from the supporting airfield/fleet.
Travel requires an alive on-foot player and a clear live-world floor/capsule
position; it changes no mission, enemy, aircraft, damage or fuel state. Retry
still recreates the complete mission and restores its selected initial spawn.

## Evidence and limits

Native checks passed **336**: St Elmo 35, AA 114, Malta 36, Valletta 17,
heavy/light AA 55, dive defence 47 and mouse aiming 32. The added traversal
check walks the existing `GroundPilot` up the court ramp. Firing tests exercise
all three muzzles and a real blocking shape. Existing tests cover aircraft
hits, mission kills, surviving/dead operators and Stuka mouse tracking.

The actual release browser suite passed **18/18** for departure, three seated
crews, pointer lock/LMB, individual and commanded fire, pause/dismount, same-world
travel and retry. Its fixture is the normal playable production export with
read-only opt-in telemetry, not a state-mutation shortcut. Native Compatibility
rendered the linked fort/court/emplacement previews. The final corrected ramp
was rebuilt/imported and verified through native soldier physics.

Protected Valletta building records, landmarks, grid orientation and terrain
hash match their pre-change values. Original historical documentation validation
still passes the frozen 50-commit audit and 859 links; updated local Markdown
targets and Git whitespace checks passed. Live GitHub Pages deployment cannot be
confirmed from the environment's blocked external API access.

Geometry and gun sites are original reference-inspired gameplay approximations,
not surveyed WWII placements. The supplied coastline constrains the fort's
footprint. There are no complete interiors or precise moat excavation. Fine
uniform/hand fitting, interrupted handoff clipping, full entrance/stair/platform
walking and subjective three-gun/radio listening remain manual checks. A separate
traverse-mechanism recording is absent; existing cannon reports are used. Close
flat masonry can show the pre-existing Compatibility shadow/moire artifact.
