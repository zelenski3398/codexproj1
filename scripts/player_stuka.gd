class_name PlayerStuka
extends FlightAircraft

signal bomb_released(bomb: RaidBomb)

@export var reserve_bombs: bool = false
@export var reload_seconds: float = 15.0
var ordnance_root: Node3D
var loaded_bomb: Node3D
var rear_gunner: RearGunner
var reload_remaining: float = 0.0
var bomb_ready: bool = true

func default_damage_profile() -> AircraftDamageProfile:
	return preload("res://damage_profiles/stuka.tres")

func create_model() -> SpitfireModel:
	return StukaModel.new()

func _ready() -> void:
	display_name = "Ju 87 Stuka"
	gun_description = "Two wing guns and automatic rear gunner"
	collision_wing_span = 13.6
	flaps_available = true
	airbrakes_available = true
	flap_landing_degrees = 40
	flap_operating_speed = 60
	wing_area = 26.0
	engine_thrust = 11500.0
	super._ready()
	gear.retractable = false
	collision_mask = 7
	guns.rounds_per_second = 6
	guns.bullet_speed = 650
	guns.bullet_damage = 2
	guns.spread_degrees = 0.08
	loaded_bomb = Node3D.new()
	loaded_bomb.name = "BombReleasePoint"
	model.add_child(loaded_bomb)
	loaded_bomb.position = Vector3(0, -0.94, -0.43)
	RaidBomb.build_visual(loaded_bomb)
	rear_gunner = RearGunner.new()
	rear_gunner.aircraft = self
	rear_gunner.crew_component = &"rear_gunner"
	rear_gunner.maximum_distance = 650
	add_child(rear_gunner)
	var dive_audio := StukaDiveAudio.new()
	dive_audio.aircraft = self
	dive_audio.volume_db = -15
	add_child(dive_audio)

func _input(event: InputEvent) -> void:
	super._input(event)
	if input_enabled and not get_tree().paused and not GameplayHUD.blocks_input() and not event.is_echo() and event.is_action_pressed("bomb_release"):
		release_bomb()
		get_viewport().set_input_as_handled()

func release_bomb() -> RaidBomb:
	if not bomb_ready or is_destroyed or is_crashed or reset_pending or not is_instance_valid(ordnance_root):
		return null
	bomb_ready = false
	loaded_bomb.hide()
	reload_remaining = reload_seconds if reserve_bombs else 0.0
	var bomb := RaidBomb.new()
	bomb.velocity = linear_velocity
	bomb.carrier = get_rid()
	bomb.position = ordnance_root.to_local(loaded_bomb.global_position)
	ordnance_root.add_child(bomb)
	bomb.global_basis = global_basis
	bomb_released.emit(bomb)
	return bomb

func _physics_process(delta: float) -> void:
	if is_destroyed or is_crashed:
		loaded_bomb.hide()
		return
	if reserve_bombs and not bomb_ready:
		reload_remaining = maxf(reload_remaining - delta, 0)
		if reload_remaining <= 0:
			bomb_ready = true
			loaded_bomb.show()

func bomb_status() -> String:
	if is_destroyed or is_crashed: return "Bomb · unavailable"
	if bomb_ready: return "Bomb · ready"
	return "Bomb · reload %d s" % ceili(reload_remaining) if reserve_bombs else "Bomb · spent"
