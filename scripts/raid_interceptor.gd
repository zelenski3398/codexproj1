class_name RaidInterceptor
extends FriendlyGladiator

func _ready() -> void:
	callsign = "Interceptor"
	super._ready()
	team_id = CombatTeams.ENEMY
	ai.takeoff_hold = false
	ai.departed = true
	ai.detection_range = 5000
	ai.pursuit_release_range = 6500

func create_combat_pilot() -> HarbourCombatPilot:
	return FlankingPilot.new()

class FlankingPilot extends HarbourCombatPilot:
	func _pursuit_point() -> Vector3:
		var point := super._pursuit_point()
		if not target is PlayerStuka: return point
		var offset := aircraft.global_position - target.global_position
		if offset.length() > 850 or not target.rear_gunner.inside_arc(target.global_basis.transposed() * offset):
			return point
		var side := -1.0 if offset.dot(target.global_basis.x) < 0 else 1.0
		tactic = "FLANK REAR GUN"
		return target.global_position + target.global_basis.x * side * 360 + Vector3.UP * 60
