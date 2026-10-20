class_name AAMouseControls
extends Node
## Scoped to one occupied gun; never binds mouse buttons to aircraft fire.
static var sensitivity: float = 1.0
static var settings_loaded: bool = false
static var bofors_assist: bool = false
var gun: BritishAAGun
var target_yaw: float
var target_elevation: float
var recapture_required: bool = false
var release_fire: bool = false
var zoomed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not settings_loaded:
		var config := ConfigFile.new()
		if config.load("user://aa_controls.cfg") == OK:
			sensitivity = clampf(config.get_value("aa","sensitivity",1.0),.2,3)
			bofors_assist = bool(config.get_value("aa","bofors_assist",false))
		settings_loaded = true

static func set_sensitivity(value: float) -> void:
	sensitivity = clampf(value,.2,3)
	save_settings()

static func set_bofors_assist(value: bool) -> void:
	bofors_assist = value
	save_settings()

static func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("aa","sensitivity",sensitivity)
	config.set_value("aa","bofors_assist",bofors_assist)
	config.save("user://aa_controls.cfg")

func reset_target() -> void:
	target_yaw = gun.yaw.rotation.y
	target_elevation = gun.elevation.rotation.x

func begin() -> void:
	reset_target()
	recapture_required = false
	release_fire = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func finish() -> void:
	gun.camera.fov = 58
	zoomed = false
	release_fire = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func blocked() -> bool:
	if not gun.mounted or gun.is_destroyed or get_tree().paused or (DisplayServer.get_name() != "headless" and not get_window().has_focus()):return true
	if GameAudioMixer.instance.panel.visible:return true
	if gun.operator_session != null:
		if gun.operator_session.mission.pilot.combat_enabled and gun.operator_session.mission.pilot.health.hp<=0:return true
		return gun.operator_session.mission.chart_panel.visible or gun.operator_session.mission_ended()
	return false

func _process(_delta: float) -> void:
	if not gun.mounted:return
	if blocked():
		if gun.has_method("cancel_orders"):gun.cancel_orders()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		recapture_required = true
		release_fire = true
		zoomed = false
		reset_target()

func _input(event: InputEvent) -> void:
	if not gun.mounted or blocked():return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Browser pointer lock must be requested from a user gesture. This click
		# reacquires control without accidentally discharging a loaded heavy gun.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		recapture_required = false
		release_fire = true
		reset_target()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# screen_relative is independent of stretch/viewport size in Godot 4.3+.
		var scale: float = deg_to_rad(gun.weapon.mouse_degrees_per_pixel) * sensitivity * (gun.camera.fov / 58.0) * (.18 if Input.is_action_pressed("brake") else 1.0)
		target_yaw -= event.screen_relative.x * scale
		target_elevation -= event.screen_relative.y * scale
		limit_target()
		get_viewport().set_input_as_handled()

func limit_target() -> void:
	# Bound the queued angular error so a fast flick cannot wind up seconds of
	# unwanted movement. The barrel always respects its mechanical rate limits.
	target_yaw = gun.yaw.rotation.y + clampf(wrapf(target_yaw-gun.yaw.rotation.y,-PI,PI),-deg_to_rad(20),deg_to_rad(20))
	target_elevation = clampf(target_elevation,deg_to_rad(gun.minimum_elevation_degrees),deg_to_rad(gun.maximum_elevation_degrees))

func sample(delta: float) -> bool:
	if blocked():return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:reset_target()
	var fine: float = .18 if Input.is_action_pressed("brake") else 1.0
	if gun.weapon.arrow_aim_enabled:
		target_yaw -= Input.get_axis("roll_left","roll_right") * deg_to_rad(gun.traverse_degrees) * delta * fine
		target_elevation += Input.get_axis("pitch_up","pitch_down") * deg_to_rad(gun.elevation_degrees) * delta * fine
	# The battery predictor reuses mouse controls but has no Bofors barrel.
	if gun.aim_assist != null: gun.aim_assist.update(delta)
	limit_target()
	var blend: float = 1-exp(-gun.weapon.mouse_response*delta)
	gun.yaw.rotation.y += clampf(wrapf(target_yaw-gun.yaw.rotation.y,-PI,PI)*blend,-deg_to_rad(gun.traverse_degrees)*delta,deg_to_rad(gun.traverse_degrees)*delta)
	gun.elevation.rotation.x += clampf((target_elevation-gun.elevation.rotation.x)*blend,-deg_to_rad(gun.elevation_degrees)*delta,deg_to_rad(gun.elevation_degrees)*delta)
	zoomed = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("aa_zoom")
	gun.camera.fov = lerpf(gun.camera.fov,gun.weapon.zoom_fov if zoomed else 58.0,1-exp(-12*delta))
	var pressed := Input.is_action_pressed("fire") or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_action_pressed("aa_fire"))
	if release_fire:
		if not Input.is_action_pressed("fire") and not Input.is_action_pressed("aa_fire"):release_fire = false
		return false
	return pressed
