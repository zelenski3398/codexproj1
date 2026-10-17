class_name AircraftWaveRoster
extends RefCounted
## Reusable distinction between actual destruction and explicit withdrawal.
signal removed(aircraft: EnemyAircraft, killed: bool)
var active: Array[EnemyAircraft] = []
var losses: int = 0
var escapes: int = 0

func register(aircraft: EnemyAircraft) -> void:
	if active.has(aircraft): return
	active.append(aircraft)
	aircraft.destroyed.connect(resolve.bind(aircraft, true))

func resolve(aircraft: EnemyAircraft, killed: bool) -> void:
	if not active.has(aircraft): return
	active.erase(aircraft)
	if killed: losses += 1
	else: escapes += 1
	removed.emit(aircraft, killed)

static func composition(wave: int) -> Array[Dictionary]:
	if wave < 1 or wave > 3: return []
	var result: Array[Dictionary] = [{"kind":"sm79", "ace":false}]
	for i in (2 if wave == 3 else 3): result.append({"kind":"cr42", "ace":wave == 3})
	return result
