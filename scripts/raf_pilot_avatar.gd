class_name RafPilotAvatar
extends Node3D
## Reusable original skinned character. Visual-only: never changes collision,
## locomotion, aircraft controls, camera transforms or boarding distances.
const ASSET_PATH: String = "res://assets/characters/raf_pilot.glb"
static var asset: PackedScene
var character: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var pose: String = ""
var first_person_hidden: bool = false

func _ready() -> void:
	# Load after import/startup, avoiding an autoload/type dependency trying to
	# preload a GLB before a fresh editor has created its import resource.
	if asset == null:
		asset = load(ASSET_PATH) as PackedScene
	character = asset.instantiate()
	add_child(character)
	animator = _find(character, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(character, "Skeleton3D") as Skeleton3D
	for key in animator.get_animation_list():
		var animation: Animation = animator.get_animation(key)
		animation.loop_mode = Animation.LOOP_LINEAR if String(key).ends_with("Idle") or String(key).ends_with("Walk") else Animation.LOOP_NONE
	set_pose("Idle")

func _find(node: Node, kind: String) -> Node:
	if node.is_class(kind):
		return node
	for child in node.get_children():
		var found: Node = _find(child, kind)
		if found != null:
			return found
	return null

func set_pose(value: String) -> void:
	if pose == value:
		return
	pose = value
	for key in animator.get_animation_list():
		if String(key).ends_with(value):
			animator.play(key, 0.0 if value == "Seated" else 0.15)
			animator.advance(0)
			return
	push_warning("RAF pilot animation missing: " + value)

func animate_walk(speed: float, _delta: float) -> void:
	set_pose("Walk" if speed > 0.1 else "Idle")
	animator.speed_scale = clampf(speed / 1.7, 0.7, 3.0) if speed > 0.1 else 1

func set_first_person_hidden(hidden: bool) -> void:
	# Existing game uses chase cameras. Future cockpit views can hide the body
	# through this explicit hook without removing the rig or changing controls.
	first_person_hidden = hidden
	character.visible = not hidden
