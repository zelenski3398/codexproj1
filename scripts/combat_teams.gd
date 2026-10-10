class_name CombatTeams
extends RefCounted
const NEUTRAL: int = 0
const PLAYER: int = 1
const ENEMY: int = 2

static func can_damage(shooter_team: int, receiver: Object) -> bool:
	if shooter_team == NEUTRAL or not receiver.has_method("get_team_id"):
		return true
	var receiver_team: int = int(receiver.call("get_team_id"))
	return receiver_team == NEUTRAL or receiver_team != shooter_team
