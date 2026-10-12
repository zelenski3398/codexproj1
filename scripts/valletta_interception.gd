class_name VallettaInterception
extends Node3D
## Mission progression only. Never repairs or moves the player on a transition.
signal checkpoint_reached(number: int)
signal formation_detected(distance: float)
signal finished(success: bool, reason: String)
@export var definition: InterceptionDefinition = preload("res://mission_definitions/valletta.tres")
var session: Node3D
var phase: String = "CHECKPOINT"
var checkpoint_index: int = 0
var activation_distance: float = 0
var bomber_route_length: float = 0
var activation_approach: Vector3 = Vector3.FORWARD
var activation_bearing: float = 0
var radio: MissionRadio
var activated: bool = false
var activation_queued: bool = false
var elapsed: float = 0
var countdown_started: bool = false
var bomber: EnemyAircraft
var escort: EnemyAircraft
var bomber_destroyed: bool = false
var escort_destroyed: bool = false
var bomber_kill_time: float = INF
var escort_kill_time: float = INF
var success: bool = false
var final_reason: String = ""
var result_count: int = 0
var checkpoint_mesh: MeshInstance3D
var canvas: CanvasLayer
var objective: Label
var checkpoint_marker: Label
var results: PanelContainer
var result_label: Label
var retry_button: Button
var return_button: Button
var bombing: bool = false
var bombs_released: int = 0
var bomb_impacts: int = 0
var bomb_clock: float = 0
var effects: Node3D
var _resolution_queued: bool = false
var player_impact_started: bool = false
var player_impact_count: int = 0

func _ready() -> void:
	# Derived release lead belongs to this run, never the shared menu resource.
	definition = definition.duplicate() as InterceptionDefinition
	radio = MissionRadio.new()
	radio.voice_clip = definition.commander_voice
	radio.voice_volume_db = definition.commander_volume_db
	radio.duck_db = definition.radio_duck_db
	add_child(radio)
	formation_detected.connect(radio.transmit_formation)
	effects = Node3D.new()
	add_child(effects)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = definition.checkpoint_radius * 0.78
	ring.outer_radius = definition.checkpoint_radius * 0.82
	ring.rings = 48
	ring.ring_segments = 8
	var material: StandardMaterial3D = MeshKit.material(Color("e4bf75"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	checkpoint_mesh = MeshKit.mesh(self, ring, material)
	_update_checkpoint_visual()
	checkpoint_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_ui()
	for player in session.malta_mission.fleet:
		player.destroyed.connect(_player_destroyed.bind(player))
		player.crashed.connect(_player_crashed.bind(player))
	if definition.checkpoint_positions.is_empty():
		_finish(false, "No navigation checkpoints configured — retry mission")

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	objective = Label.new()
	objective.position = Vector2(400, 24)
	objective.size = Vector2(540, 110)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_size_override("font_size", 18)
	_style_label(objective)
	canvas.add_child(objective)
	checkpoint_marker = Label.new()
	_style_label(checkpoint_marker)
	canvas.add_child(checkpoint_marker)
	results = PanelContainer.new()
	results.position = Vector2(420, 150)
	results.custom_minimum_size.x = 500
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.12, 0.95)
	style.set_content_margin_all(18)
	results.add_theme_stylebox_override("panel", style)
	canvas.add_child(results)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	results.add_child(column)
	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.custom_minimum_size.x = 460
	result_label.add_theme_font_size_override("font_size", 23)
	_style_label(result_label)
	column.add_child(result_label)
	retry_button = Button.new()
	retry_button.text = "RETRY MISSION"
	retry_button.focus_mode = Control.FOCUS_NONE
	retry_button.pressed.connect(_retry)
	column.add_child(retry_button)
	return_button = Button.new()
	return_button.text = "RETURN TO MISSIONS"
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.pressed.connect(_return_to_missions)
	column.add_child(return_button)
	results.visible = false

func cancel() -> void:
	# Deferred callbacks from the old physics tick must not finish a NEW run.
	phase = "CANCELLED"
	radio.stop()
	set_physics_process(false)
	set_process(false)

func _retry() -> void:
	if retry_button.disabled:
		return
	retry_button.disabled = true
	return_button.disabled = true
	session.call_deferred("restart_malta")

func _return_to_missions() -> void:
	if return_button.disabled:
		return
	retry_button.disabled = true
	return_button.disabled = true
	session.call_deferred("return_to_missions")

func _style_label(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("e4bf75"))
	label.add_theme_color_override("font_shadow_color", Color("101e25"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

func _player_destroyed(player: FlightAircraft) -> void:
	if player == session.aircraft and phase in ["CHECKPOINT", "ACTIVE"]:
		_finish(false, "Player aircraft destroyed — interception failed")

func _player_crashed(_reason: String, player: FlightAircraft) -> void:
	if player != session.aircraft or phase == "CANCELLED":
		return
	_player_impact(player.global_position)
	if phase in ["CHECKPOINT", "ACTIVE"]:
		_finish(false, "Player aircraft destroyed — interception failed")

func _player_impact(point: Vector3) -> void:
	if player_impact_started:
		return
	player_impact_started = true
	call_deferred("_show_player_impact", point)

func _show_player_impact(point: Vector3) -> void:
	if phase == "CANCELLED" or is_queued_for_deletion():
		return
	var burst: DestructionBurst = DestructionBurst.new()
	effects.add_child(burst)
	burst.global_position = point
	player_impact_count += 1

func remaining_seconds() -> float:
	return maxf(definition.deadline_seconds - elapsed, 0)

func _physics_process(delta: float) -> void:
	var player: FlightAircraft = session.aircraft
	if phase in ["CHECKPOINT", "ACTIVE"] and is_instance_valid(player) and (player.is_destroyed or player.is_crashed):
		_finish(false, "Player aircraft destroyed — interception failed")
	# An aircraft destroyed in the air keeps falling; explode only on contact.
	if is_instance_valid(player) and player.is_destroyed and not player_impact_started:
		var grounded: bool = player.gear.contact_count > 0
		for body in player.get_colliding_bodies():
			if body is CollisionObject3D and (body.collision_layer & 1) != 0:
				grounded = true
		if grounded:
			_player_impact(player.global_position)
	if phase == "CHECKPOINT" and not activation_queued and is_instance_valid(session.malta_mission.occupied) and player.gear.contact_count == 0 and player.altitude >= definition.minimum_checkpoint_agl and absf(player.global_position.y - current_checkpoint().y) <= definition.checkpoint_vertical_tolerance and player.global_position.distance_to(current_checkpoint()) <= definition.checkpoint_radius:
		activation_queued = true # latch before deferred physics-safe body insertion
		call_deferred("_advance_checkpoint", checkpoint_index)
	if phase == "ACTIVE" and countdown_started:
		elapsed += delta
		_queue_resolution()
	if bombing and is_instance_valid(bomber) and not bomber.is_destroyed and bombs_released < definition.bomb_count:
		bomb_clock -= delta
		if bomb_clock <= 0:
			bomb_clock += definition.bomb_interval
			_drop_bomb()

func current_checkpoint() -> Vector3:
	return definition.checkpoint_positions[clampi(checkpoint_index, 0, definition.checkpoint_positions.size() - 1)] if not definition.checkpoint_positions.is_empty() else Vector3.ZERO

func _update_checkpoint_visual() -> void:
	checkpoint_mesh.position = current_checkpoint()
	checkpoint_mesh.rotation.x = PI / 2
	var previous: Vector3 = definition.checkpoint_positions[checkpoint_index - 1] if checkpoint_index > 0 and checkpoint_index < definition.checkpoint_positions.size() else MaltaGeography.vector(MaltaGeography.field(definition.home_airfield).position)
	var direction: Vector3 = current_checkpoint() - previous
	checkpoint_mesh.rotation.y = atan2(direction.x, direction.z)

func _advance_checkpoint(expected_index: int) -> void:
	if phase != "CHECKPOINT" or expected_index != checkpoint_index:
		return # old/deferred duplicate entry cannot advance a later checkpoint
	if session.aircraft.is_destroyed or session.aircraft.is_crashed or session.encounters.ended:
		_finish(false, "Player aircraft destroyed — interception failed")
		return
	checkpoint_index += 1
	checkpoint_reached.emit(checkpoint_index)
	activation_queued = false
	if checkpoint_index == definition.checkpoint_positions.size():
		activate()
	else:
		_update_checkpoint_visual()

func _approach_direction() -> Vector3:
	# Clock bearings are relative to the aircraft's nose, not its velocity/slip.
	var forward: Vector3 = -session.aircraft.global_basis.z * Vector3(1, 0, 1)
	if forward.length_squared() < 0.0001:
		forward = session.aircraft.linear_velocity * Vector3(1, 0, 1)
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	return forward.normalized()

func _formation_spawn() -> Vector3:
	var player: FlightAircraft = session.aircraft
	activation_approach = _approach_direction()
	# Godot's positive yaw turns left; a clockwise/right bearing uses -angle.
	var bearing_direction: Vector3 = activation_approach.rotated(Vector3.UP, -deg_to_rad(definition.formation_bearing_degrees))
	var distance: float = definition.formation_spawn_distance
	var candidate: Vector3 = player.global_position + bearing_direction * distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(candidate + Vector3.UP * 5000, candidate + Vector3.DOWN * 5000, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var ground: float = float(hit.position.y) if not hit.is_empty() else 0
	var height: float = maxf(player.global_position.y + definition.formation_height_offset, ground + definition.spawn_clearance)
	var height_difference: float = height - player.global_position.y
	if height_difference >= distance or height_difference > definition.maximum_formation_height_difference or distance <= 600:
		return Vector3(INF, INF, INF)
	# Exact 3D separation, not a flat distance plus an unaccounted height offset.
	var horizontal: float = sqrt(distance * distance - height_difference * height_difference)
	candidate = player.global_position + bearing_direction * horizontal
	candidate.y = height
	activation_bearing = rad_to_deg(atan2(bearing_direction.dot(activation_approach.cross(Vector3.UP)), bearing_direction.dot(activation_approach)))
	return candidate

func _release_waypoint(start: Vector3) -> Vector3:
	if not definition.automatic_release_lead:
		return definition.bombing_point
	var flat: Vector3 = (definition.target_area - start) * Vector3(1, 0, 1)
	var fall_seconds: float = sqrt(2 * maxf(definition.bombing_point.y - definition.target_area.y, 0) / 9.81)
	# v = (target distance - arrival allowance)/(approach time + fall time).
	# Therefore release distance / v remains the requested approach duration,
	# while inherited horizontal velocity carries the falling bomb to Valletta.
	var speed: float = (flat.length() - definition.arrival_radius * 0.5) / (definition.deadline_seconds + fall_seconds)
	var point: Vector3 = definition.target_area - flat.normalized() * speed * fall_seconds
	point.y = definition.bombing_point.y
	return point

func activate() -> void:
	if activated or phase != "CHECKPOINT" or session.encounters.ended or definition.checkpoint_positions.is_empty() or checkpoint_index != definition.checkpoint_positions.size():
		return
	activated = true
	activation_queued = false
	checkpoint_mesh.visible = false
	phase = "ACTIVE"
	var start: Vector3 = _formation_spawn()
	if not start.is_finite():
		_finish(false, "No safe formation spawn — retry mission")
		return
	definition.bombing_point = _release_waypoint(start)
	var point: Vector3 = definition.bombing_point
	# Spawn ahead of the approaching player; the bomber turns NO corner on
	# insertion: its initial forward axis and velocity already face Valletta.
	var direction: Vector3 = ((point - start) * Vector3(1, 0, 1)).normalized()
	bomber_route_length = ((point - start) * Vector3(1, 0, 1)).length()
	var approach_speed: float = (bomber_route_length - definition.arrival_radius * 0.5) / definition.deadline_seconds
	# Existing throttle pacing can handle this route without artificial holds.
	if approach_speed < BomberPilot.DEFAULT_MINIMUM_SPEED or approach_speed > BomberPilot.DEFAULT_MAXIMUM_SPEED:
		_finish(false, "Interception area outside bomber pacing limits — check navigation route")
		return
	var wingman: Vector3 = start + direction.cross(Vector3.UP) * definition.escort_separation - direction * 120 + Vector3.UP * 40
	if not _safe_spawn(start, 25) or not _safe_spawn(wingman, 16) or start.distance_to(wingman) < 80:
		_finish(false, "No safe formation spawn — retry mission")
		return
	bomber = session.create_encounter_enemy(start, false, "sm79")
	escort = session.create_encounter_enemy(wingman, false, definition.escort_type)
	var pose: Basis = Basis.looking_at(direction, Vector3.UP)
	for foe in [bomber, escort]:
		foe.pending_reset_pose = Transform3D(pose, start if foe == bomber else wingman)
		foe.pending_reset_velocity = direction * approach_speed
		session.encounters.track_enemy(foe)
		foe.destroyed.connect(_enemy_destroyed.bind(foe))
	activation_distance = session.aircraft.global_position.distance_to(bomber.global_position)
	var route: BomberPilot = bomber.ai as BomberPilot
	route.assign_route(start, point, definition.deadline_seconds)
	route.arrival_radius = definition.arrival_radius
	var wingman_ai: EscortPilot = escort.ai as EscortPilot
	wingman_ai.escorted = bomber
	wingman_ai.mission_active = true
	wingman_ai.route_anchor = start
	wingman_ai.route_direction = direction
	wingman_ai.route_speed = approach_speed
	session.encounter_tracking_changed()
	session.encounters.set_target(session.malta_mission.occupied)
	elapsed = 0
	# First force integration applies airborne spawn. Count from that tick, not
	# from loading/inserting resources in the preceding deferred callback.
	countdown_started = true
	formation_detected.emit(activation_distance)

func _safe_spawn(point: Vector3, radius: float) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ground: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3000, point + Vector3.DOWN * 3000, 1))
	if not ground.is_empty() and point.y < float(ground.position.y) + definition.spawn_clearance:
		return false
	if point.distance_to(session.aircraft.global_position) < 600:
		return false
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 7
	return space.intersect_shape(query).is_empty()

func _enemy_destroyed(foe: EnemyAircraft) -> void:
	if phase != "ACTIVE":
		return
	if foe == bomber and not bomber_destroyed:
		bomber_destroyed = true
		bomber_kill_time = elapsed
	elif foe == escort and not escort_destroyed:
		escort_destroyed = true
		escort_kill_time = elapsed
	_queue_resolution()

func _queue_resolution() -> void:
	if not _resolution_queued:
		_resolution_queued = true
		call_deferred("_resolve")

func _resolve() -> void:
	_resolution_queued = false
	if phase != "ACTIVE":
		return
	# Enemy losses and bombing never end the run early. Only the deadline (or
	# immediate player loss) resolves it, after all same-tick events settle.
	if is_instance_valid(bomber) and not bomber.is_destroyed and (bomber.ai as BomberPilot).arrived:
		bombing = true
	if elapsed < definition.deadline_seconds:
		return
	if bombing:
		_finish(false, "Valletta bombed — interception failed")
	elif bomber_destroyed and escort_destroyed and maxf(bomber_kill_time, escort_kill_time) < definition.deadline_seconds:
		_finish(true, "Bomber and escort destroyed — Valletta defended")
	else:
		_finish(false, "Interception incomplete" if bomber_destroyed else "Time expired — interception failed")

func _finish(won: bool, reason: String) -> void:
	if phase in ["SUCCESS", "FAILED"]:
		return
	phase = "SUCCESS" if won else "FAILED"
	success = won
	final_reason = reason
	result_count += 1
	checkpoint_mesh.visible = false
	checkpoint_marker.visible = false
	results.visible = true
	result_label.text = ("MISSION COMPLETE\n" if won else "MISSION FAILED\n") + reason
	session.encounters.ended = true
	session.encounters.awaiting_confirmation = false
	finished.emit(won, reason)

func _drop_bomb() -> void:
	var bomb: MissionBomb = MissionBomb.new()
	bomb.velocity = bomber.linear_velocity
	bomb.impact_effects = effects
	effects.add_child(bomb)
	bomb.global_position = bomber.to_global(Vector3(0, -1.4, 1))
	bomb.impacted.connect(func(_point: Vector3): bomb_impacts += 1)
	bombs_released += 1

func _process(_delta: float) -> void:
	objective.position.x = 740 if not is_instance_valid(session.malta_mission.occupied) else 400
	if phase == "CHECKPOINT":
		var player_position: Vector3 = session.aircraft.global_position if is_instance_valid(session.malta_mission.occupied) else session.malta_mission.pilot.global_position
		var distance: int = roundi(player_position.distance_to(current_checkpoint()))
		objective.text = "TA’ QALI INTERCEPTION · CHECKPOINT %d/%d\nFollow the navigation route · timer not started\n%d m · checkpoint altitude %d m" % [checkpoint_index + 1, definition.checkpoint_positions.size(), distance, roundi(current_checkpoint().y)]
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			var screen: Vector2 = get_viewport().get_visible_rect().size
			var local: Vector3 = camera.to_local(current_checkpoint())
			var point: Vector2 = camera.unproject_position(current_checkpoint()) if local.z < -0.1 else screen * 0.5 + Vector2(local.x, -local.y).normalized() * screen.length()
			checkpoint_marker.position = Vector2(clampf(point.x - 90, 20, screen.x - 220), clampf(point.y - 20, 180, screen.y - 180))
			checkpoint_marker.text = "◇ CHECKPOINT %d/%d · %d m" % [checkpoint_index + 1, definition.checkpoint_positions.size(), distance]
			checkpoint_marker.visible = true
	elif phase == "ACTIVE":
		var seconds: int = ceili(remaining_seconds())
		var goal: String = "Bomber stopped — destroy the remaining escort" if bomber_destroyed else "Destroy the bomber and escort before they reach Valletta"
		if bomber_destroyed and escort_destroyed:
			goal = "All enemies lost — hold position until timer expires"
		if bombing:
			goal = "Bombing run begun — results at timer expiry"
		if elapsed < definition.detection_notice_seconds and not bomber_destroyed:
			goal = MissionRadio.FORMATION_LINE
		objective.text = "%02d:%02d · %s\nBomber: %s    Escort: %s" % [seconds / 60, seconds % 60, goal, "DESTROYED" if bomber_destroyed else "APPROACHING", "DESTROYED" if escort_destroyed else "ACTIVE"]
		checkpoint_marker.visible = false
	else:
		objective.text = "TA’ QALI INTERCEPTION · " + phase
