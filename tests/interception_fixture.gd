extends RefCounted
## Explicit pose/cursor fixture ONLY for isolated combat and outcome branches.
## Production checkpoint tests and departure tests exercise the actual sequence.
static func prepare_final_entry(session: Node3D) -> void:
	if not is_instance_valid(session.malta_mission.occupied):
		session.malta_mission.board_nearest()
	var mission: VallettaInterception = session.interception
	mission.checkpoint_index = mission.definition.checkpoint_positions.size() - 1
	mission._update_checkpoint_visual()
	var checkpoints: PackedVector3Array = mission.definition.checkpoint_positions
	var direction: Vector3 = (checkpoints[-1] - checkpoints[-2]).normalized()
	var player: FlightAircraft = session.aircraft
	player.request_reset()
	player.pending_reset_pose = Transform3D(Basis.looking_at(direction, Vector3.UP), checkpoints[-1])
	player.pending_reset_velocity = direction * 70
