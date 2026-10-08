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
var fire: bool = false

# Bindings live in project.godot so the editor and embedded game share them.
# Each action accepts physical keys and keycode-only forwarded events.

func sample(delta: float) -> void:
	if automated:
		return
	pitch = Input.get_axis("pitch_down", "pitch_up")
	roll = Input.get_axis("roll_right", "roll_left")
	rudder = Input.get_axis("rudder_right", "rudder_left")
	throttle = clampf(throttle + Input.get_axis("throttle_down", "throttle_up") * throttle_rate * delta, 0.0, 1.0)
	brakes = Input.is_action_pressed("brake")
	fire = Input.is_action_pressed("fire")

func reset_commands() -> void:
	throttle = 0.0
	pitch = 0.0
	roll = 0.0
	rudder = 0.0
	brakes = false
	fire = false
