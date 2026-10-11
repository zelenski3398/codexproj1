class_name EnemyEncounters
extends Node
## Session progression only: never resets the world, player or projectile pools.
## Destruction signals remove active enemies immediately; falling wrecks persist.
const STAGE_COUNTS: Array[int] = [1, 2, 2, 3, 3]
@export var enemy_types: Array[String] = ["stuka"]
@export var minimum_spawn_distance: float = 650.0
@export var spawn_distance: float = 1400.0
@export var spawn_clearance: float = 160.0
@export var spawn_separation: float = 180.0
@export_range(0.01, 1, 0.01) var ace_aim_error_scale: float = 0.20
@export_range(0.01, 1, 0.01) var ace_dispersion_scale: float = 0.25
var session: Node3D
var mode: String = "encounter"
var stage: int = 0
var active: Array[EnemyAircraft] = []
var wrecks: Array[EnemyAircraft] = []
var awaiting_confirmation: bool = false
var spawning: bool = false
var ended: bool = false
var complete: bool = false
var generation: int = 0
var canvas: CanvasLayer
var status: Label
var confirm_button: Button
var enemy_widgets: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas = CanvasLayer.new()
	canvas.layer = 9
	add_child(canvas)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = 22
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("e4bf75"))
	status.add_theme_color_override("font_shadow_color", Color("101e25"))
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status)
	confirm_button = Button.new()
	confirm_button.focus_mode = Control.FOCUS_NONE
	confirm_button.pressed.connect(confirm)
	panel.add_child(confirm_button)
	canvas.visible = false

func begin(selected_mode: String) -> void:
	clear()
	mode = selected_mode
	stage = 1
	ended = false
	complete = false
	canvas.visible = true
	status.visible = true
	_spawn_batch()

func clear() -> void:
	generation += 1 # invalidate confirmations queued before restart/menu changes
	awaiting_confirmation = false
	spawning = false
	stage = 0
	for foe in active + wrecks:
		if is_instance_valid(foe):
			foe.get_parent().remove_child(foe)
			foe.queue_free()
	active.clear()
	wrecks.clear()
	for widget in enemy_widgets.values():
		widget.queue_free()
	enemy_widgets.clear()
	if is_instance_valid(canvas):
		canvas.visible = false

func set_target(player: FlightAircraft) -> void:
	for foe in active:
		foe.target = player
		foe.ai.target = player
		foe.guns.telemetry_target = player
		foe.rear_gunner.guns.telemetry_target = player
	if is_instance_valid(player):
		player.guns.telemetry_target = session.enemy

func player_destroyed(source: FlightAircraft) -> void:
	if ended or source != session.aircraft or stage == 0:
		return
	ended = true
	awaiting_confirmation = false
	generation += 1
	spawning = false

func confirm() -> void:
	if not awaiting_confirmation or spawning or ended or complete or not _player_live() or get_tree().paused:
		return
	# Latch BEFORE deferral. Button spam/key repeat cannot queue another batch.
	awaiting_confirmation = false
	spawning = true
	call_deferred("_confirmed_spawn", generation)

func _confirmed_spawn(token: int) -> void:
	if token != generation or ended or complete or not _player_live():
		return
	stage += 1
	_spawn_batch()

func _player_live() -> bool:
	return is_instance_valid(session.aircraft) and not session.aircraft.is_destroyed and not session.aircraft.is_crashed

func _spawn_batch() -> void:
	var count: int = STAGE_COUNTS[stage - 1] if mode == "survival" else 1
	# Plan the WHOLE batch first. Never declare a partial Survival stage cleared.
	var positions: Array[Vector3] = []
	for index in range(count):
		var point: Vector3 = _safe_position(index, positions)
		if not point.is_finite():
			spawning = false
			ended = true
			status.text = "No safe enemy spawn found · R to restart"
			return
		positions.append(point)
	for index in range(count):
		var ace: bool = mode == "survival" and stage == 5 and index == 2
		var foe: EnemyAircraft = session.create_encounter_enemy(positions[index], ace, enemy_types[(stage - 1 + index) % enemy_types.size()] if not enemy_types.is_empty() else "stuka")
		track_enemy(foe)
	spawning = false
	session.encounter_tracking_changed()
	set_target(session.malta_mission.occupied if is_instance_valid(session.malta_mission) else session.aircraft)

func _safe_position(index: int, planned: Array[Vector3]) -> Vector3:
	var player: FlightAircraft = session.aircraft
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for attempt in range(32):
		var angle: float = deg_to_rad(-135.0 + index * 24.0 + attempt * 37.0)
		var radius: float = maxf(spawn_distance, minimum_spawn_distance + 100) + floorf(attempt / 8.0) * 300
		var point: Vector3 = player.global_position + Vector3(sin(angle), 0, cos(angle)) * radius
		if mode == "encounter" and stage == 1 and session.environment_id == "countryside" and attempt == 0:
			point = session.enemy_spawn_position
		if point.distance_to(player.global_position) < minimum_spawn_distance:
			continue
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(point.x, maxf(10000, player.global_position.y + 2000), point.z), Vector3(point.x, -2000, point.z), 1)
		var hit: Dictionary = space.intersect_ray(ray)
		var ground: float = float(hit.position.y) if not hit.is_empty() else 0.0
		point.y = maxf(point.y, maxf(player.global_position.y + 180, ground + spawn_clearance))
		if session.environment_id == "malta":
			point.y = maxf(point.y, 500)
		var separated: bool = true
		for other in planned:
			if other.distance_to(point) < spawn_separation:
				separated = false
		for foe in active + wrecks:
			if is_instance_valid(foe) and foe.global_position.distance_to(point) < spawn_separation:
				separated = false
		if not separated:
			continue
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 18
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY, point)
		query.collision_mask = 7
		if space.intersect_shape(query).is_empty():
			return point
	return Vector3(INF, INF, INF)

func _destroyed(foe: EnemyAircraft) -> void:
	if not active.has(foe):
		return
	if foe == session.enemy and not foe.encounter_ace:
		session._remember_difficulty()
	active.erase(foe)
	wrecks.append(foe)
	var id: int = foe.get_instance_id()
	if enemy_widgets.has(id):
		enemy_widgets[id].queue_free()
		enemy_widgets.erase(id)
	session.defeat_notifications += 1
	session.encounter_tracking_changed()
	if active.is_empty() and not ended and mode != "interception":
		if mode == "survival" and stage == STAGE_COUNTS.size():
			complete = true
		else:
			awaiting_confirmation = true

func _wreck_removed(foe: EnemyAircraft) -> void:
	wrecks.erase(foe)
	session.encounter_tracking_changed()

func _add_widget(foe: EnemyAircraft) -> void:
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color("e4bf75") if foe.encounter_ace else Color("ff946a"))
	label.add_theme_color_override("font_shadow_color", Color("101e25"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar)
	canvas.add_child(column)
	enemy_widgets[foe.get_instance_id()] = column

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("confirm_encounter") and not event.is_echo() and awaiting_confirmation:
		confirm()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if stage == 0:
		return
	if not _player_live():
		player_destroyed(session.aircraft)
	var prefix: String = "SURVIVAL · STAGE %d/5 · %d ENEMIES REMAINING" % [stage, active.size()] if mode == "survival" else "ENCOUNTER %d · %d ENEMY REMAINING" % [stage, active.size()]
	status.visible = mode != "interception"
	status.text = prefix
	if ended:
		status.text += "\nSURVIVAL ENDED · R to restart" if mode == "survival" else "\nAIRCRAFT LOST · R to restart"
	elif complete:
		status.text += "\nSurvival Complete"
	elif awaiting_confirmation:
		status.text += "\nStage Cleared — Confirm to Start Next Stage" if mode == "survival" else "\nEnemy destroyed"
	confirm_button.visible = awaiting_confirmation and not ended and not complete
	confirm_button.disabled = get_tree().paused or spawning
	confirm_button.text = "CONFIRM / START NEXT STAGE · C" if mode == "survival" else "CONFIRM / SPAWN NEXT ENEMY · C"
	var camera: Camera3D = get_viewport().get_camera_3d()
	for foe in active:
		var widget: VBoxContainer = enemy_widgets[foe.get_instance_id()]
		widget.visible = false
		# The existing HUD draws the focused enemy. Supplement the other aircraft.
		if foe == session.enemy or camera == null or get_tree().paused or not _player_live():
			continue
		var overhead: Vector3 = foe.global_position + Vector3.UP * 5
		var screen: Vector2 = get_viewport().get_visible_rect().size
		var nearby: bool = not camera.is_position_behind(overhead) and foe.global_position.distance_to(session.aircraft.global_position) <= 800
		var local: Vector3 = camera.to_local(overhead)
		var point: Vector2 = camera.unproject_position(overhead) if local.z < -0.1 else screen * 0.5 + Vector2(local.x, -local.y).normalized() * screen.length()
		nearby = nearby and get_viewport().get_visible_rect().has_point(point)
		widget.visible = true
		widget.position = Vector2(clampf(point.x - 75, 10, screen.x - 160), clampf(point.y - 35, 190, screen.y - 185))
		widget.get_child(0).text = "%s · %d m%s" % [("ACE " if foe.encounter_ace else "") + foe.marker_name, roundi(foe.global_position.distance_to(session.aircraft.global_position)), " · HP %d/%d" % [ceili(foe.health.hp), roundi(foe.health.max_hp)] if nearby else ""]
		widget.get_child(1).visible = nearby
		widget.get_child(1).max_value = foe.health.max_hp
		widget.get_child(1).value = foe.health.hp

func begin_external() -> void:
	clear()
	mode = "interception"
	stage = 1
	ended = false
	complete = false
	canvas.visible = true
	status.visible = false
	confirm_button.visible = false

func track_enemy(foe: EnemyAircraft) -> void:
	if active.has(foe):
		return
	active.append(foe)
	foe.destroyed.connect(_destroyed.bind(foe))
	foe.wreck_removed.connect(_wreck_removed.bind(foe))
	_add_widget(foe)
