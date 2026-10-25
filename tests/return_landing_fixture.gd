extends RefCounted
## Test setup only. The integration-safe pose API is followed by real suspension
## and brakes; saved damage/fuel are restored after that fixture reset.
static func park(game: Node,field_id: String="") -> void:
	if field_id.is_empty():field_id=game.malta_mission.home
	var field: MaltaAirfield=game.field.fields[field_id]
	var plane: FlightAircraft=game.malta_mission.occupied
	var hp: float=plane.health.hp
	var saved: Dictionary={}
	for key in ["integrity","tank_fuel","leaking_tanks","fires","detached","fatigue","structural_hits","engine_seized","engine_temperature"]:
		saved[key]=plane.components.get(key).duplicate(true)
	plane.request_reset()
	plane.pending_reset_pose=Transform3D(field.global_basis*Basis(Vector3.RIGHT,.117),field.to_global(Vector3(0,1.18,0)))
	plane.pending_reset_velocity=Vector3.ZERO
	plane.engine_running=false;plane.pilot.automated=true;plane.pilot.brakes=true
	await plane.reset_completed
	plane.health.hp=hp
	for key in saved:plane.components.set(key,saved[key])
	for tick in 480:await game.get_tree().physics_frame
