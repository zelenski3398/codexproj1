class_name PilotInput
extends Node
## Controls produce commands only. Aircraft physics owns all motion.

@export var throttle_rate: float = 0.3
var throttle: float = 0.0
var pitch: float = 0.0
var roll: float = 0.0
var rudder: float = 0.0
var brakes: bool = false
var automated: bool = false

func _ready() -> void:
	_bind("pitch_down", KEY_UP)
	_bind("pitch_up", KEY_DOWN)
	_bind("roll_left", KEY_LEFT)
	_bind("roll_right", KEY_RIGHT)
	_bind("rudder_left", KEY_A)
	_bind("rudder_right", KEY_D)
	_bind("throttle_up", KEY_W)
	_bind("throttle_down", KEY_S)
	_bind("gear", KEY_G)
	_bind("brake", KEY_SPACE)
	_bind("reset", KEY_R)
	_bind("pause", KEY_ESCAPE)

func _bind(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func sample(delta: float) -> void:
	if automated:
		return
	pitch = Input.get_axis("pitch_down", "pitch_up")
	roll = Input.get_axis("roll_right", "roll_left")
	rudder = Input.get_axis("rudder_right", "rudder_left")
	throttle = clampf(throttle + Input.get_axis("throttle_down", "throttle_up") * throttle_rate * delta, 0.0, 1.0)
	brakes = Input.is_action_pressed("brake")

func reset_commands() -> void:
	throttle = 0.0
	pitch = 0.0
	roll = 0.0
	rudder = 0.0
	brakes = false

