extends Node3D
## Isolated deterministic acoustic fixture. Does not alter production AI/flight.
var enemy: EnemyAircraft
var flyby: EnemyFlybyAudio
var camera: Camera3D
var mode: String = "far"
var buttons: Dictionary = {}
var bridge: Object
var ready_audio: bool = false

func _ready() -> void:
	GameAudioMixer.instance.set_menu_active(false)
	GameAudioMixer.instance.set_muted(false, false)
	GameAudioMixer.instance.set_volume("Aircraft", .75, false)
	camera = Camera3D.new()
	add_child(camera)
	camera.position.y = 300
	camera.make_current()
	enemy = EnemyAircraft.new()
	add_child(enemy)
	for i in range(4): await get_tree().physics_frame
	enemy.freeze = true
	enemy.reset_pending = false
	enemy.ai.set_physics_process(false)
	enemy.rear_gunner.set_physics_process(false)
	enemy.pilot.automated = true
	enemy.pilot.throttle = .75
	enemy.engine_running = true
	flyby = enemy.aircraft_audio.flyby
	flyby.set_physics_process(false)
	var panel := VBoxContainer.new()
	panel.position = Vector2(30,30)
	add_child(panel)
	var title := Label.new()
	title.text = "ENGINE-ONLY ACOUSTIC TEST — airflow recording not supplied"
	panel.add_child(title)
	for entry in ["far", "near", "approach", "recede", "left", "right", "matching", "stop"]:
		var button := Button.new()
		button.text = entry
		button.custom_minimum_size = Vector2(240,50)
		panel.add_child(button)
		buttons[entry] = button
		button.pressed.connect(func(): mode = entry)
	bridge = Engine.get_singleton("JavaScriptBridge")
	ready_audio = true

func _physics_process(delta: float) -> void:
	if not ready_audio: return
	var offset := Vector3(0,0,-100)
	var source_velocity := Vector3.ZERO
	var listener_velocity := Vector3.ZERO
	match mode:
		"far": offset.z = -1800
		"near": offset.z = -50
		"approach": source_velocity.z = 110
		"recede":
			offset.z = 100
			source_velocity.z = 110
		"left": offset = Vector3(-60,0,-70)
		"right": offset = Vector3(60,0,-70)
		"matching":
			offset.z = -40
			source_velocity.x = 90
			listener_velocity.x = 90
		"stop": enemy.engine_running = false
	if mode != "stop": enemy.engine_running = true
	enemy.position = camera.position + offset
	flyby.update_motion(enemy.position, source_velocity, camera.position, listener_velocity, delta)

func _process(_delta: float) -> void:
	if not ready_audio or bridge == null: return
	var state: Dictionary = flyby.diagnostic_state()
	state.merge({"mode":mode,"idle_pitch":enemy.aircraft_audio.idle.pitch_scale,"flight_pitch":enemy.aircraft_audio.flight.pitch_scale,"playing":enemy.aircraft_audio.flight.playing})
	for entry in buttons:
		var center: Vector2 = get_viewport().get_final_transform() * (buttons[entry].get_global_transform_with_canvas() * (buttons[entry].size * .5))
		state[entry] = [center.x,center.y]
	bridge.eval("window.flybyTestState = " + JSON.stringify(state) + ";",true)
