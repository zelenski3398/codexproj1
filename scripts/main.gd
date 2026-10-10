extends Node3D
var aircraft: FlightAircraft
var chase: ChaseCamera
var hud: FlightHUD
var enemy: EnemyAircraft
var selector: AircraftSelector
var selected_aircraft: String = "spitfire"
@export var enemy_spawn_position: Vector3 = Vector3(-450, 160, 0)
var encounter_effects: Node3D
var enemy_defeated: bool = false
var defeat_notifications: int = 0
var session_number: int = 0
var _enemy_restart_queued: bool = false
var _ai_settings: Dictionary = {}
var _gun_settings: Dictionary = {}

func _ready() -> void:
	var field := Airfield.new()
	field.name = "CountrysideAirfield"
	add_child(field)
	encounter_effects = Node3D.new()
	encounter_effects.name = "SessionEffects"
	add_child(encounter_effects)
	show_selection()

func show_selection() -> void:
	_remember_difficulty()
	_clear_encounter_effects()
	_enemy_restart_queued = false
	enemy_defeated = false
	get_tree().paused = false
	get_viewport().gui_release_focus()
	# Removing nodes before queue_free prevents old pilots/HUD consuming input
	# and old world-space rounds persisting when returning from the pause menu.
	for node in [hud, enemy, aircraft, chase, selector]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	aircraft = null
	enemy = null
	chase = null
	hud = null
	selector = AircraftSelector.new()
	selector.name = "AircraftSelection"
	selector.chosen.connect(start_flight, CONNECT_DEFERRED)
	add_child(selector)
	selector.select(selected_aircraft)

func start_flight(kind: String) -> void:
	if is_instance_valid(aircraft) or kind not in ["spitfire", "sea_gladiator"]:
		return
	selected_aircraft = kind
	if is_instance_valid(selector):
		remove_child(selector)
		selector.queue_free()
	selector = null
	get_viewport().gui_release_focus()
	aircraft = SeaGladiator.new() if kind == "sea_gladiator" else FlightAircraft.new()
	aircraft.name = "SeaGladiator" if kind == "sea_gladiator" else "Spitfire"
	add_child(aircraft)
	_spawn_enemy()
	aircraft.collision_mask = 5 # terrain and enemy airframes
	aircraft.reset_completed.connect(_on_player_reset)
	chase = ChaseCamera.new()
	chase.name = "ChaseCamera"
	chase.aircraft = aircraft
	add_child(chase)
	aircraft.reset_completed.connect(chase.snap)
	hud = FlightHUD.new()
	hud.aircraft = aircraft
	hud.enemy = enemy
	add_child(hud)
	hud.change_aircraft_requested.connect(show_selection, CONNECT_DEFERRED)


func _exported_settings(component: Node) -> Dictionary:
	var settings: Dictionary = {}
	for property in component.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (int(property.usage) & PROPERTY_USAGE_EDITOR) != 0:
			settings[property.name] = component.get(property.name)
	return settings

func _remember_difficulty() -> void:
	if is_instance_valid(enemy):
		_ai_settings = _exported_settings(enemy.ai)
		_gun_settings = _exported_settings(enemy.guns)

func _spawn_enemy() -> void:
	_remember_difficulty()
	if is_instance_valid(enemy):
		remove_child(enemy)
		enemy.queue_free()
	enemy = EnemyAircraft.new()
	enemy.name = "EnemyStuka"
	enemy.target = aircraft
	var spawn: Vector3 = enemy_spawn_position
	# The normal runway start is >750 m away. Alternate player start positions
	# still receive clearance and safe terrain height, rather than overlapping.
	if spawn.distance_to(aircraft.global_position) < 400:
		spawn = aircraft.global_position + Vector3(-550, 100, -300)
	spawn.y = maxf(spawn.y, Airfield.height_at(spawn.x, spawn.z) + 120)
	enemy.reset_position = spawn
	add_child(enemy)
	for key in _ai_settings:
		enemy.ai.set(key, _ai_settings[key])
	for key in _gun_settings:
		enemy.guns.set(key, _gun_settings[key])
	enemy.ai.reset()
	enemy.destroyed.connect(_on_enemy_destroyed.bind(enemy))
	enemy.ground_impact.connect(_on_enemy_ground_impact.bind(enemy))
	enemy.wreck_removed.connect(_on_wreck_removed.bind(enemy))
	enemy_defeated = false
	defeat_notifications = 0
	session_number += 1
	if is_instance_valid(hud):
		hud.enemy = enemy
		hud.enemy_defeated = false

func _on_player_reset() -> void:
	if _enemy_restart_queued:
		return
	_enemy_restart_queued = true
	if is_instance_valid(enemy):
		enemy.ai.set_physics_process(false)
		enemy.pilot.fire = false
		enemy.guns.set_physics_process(false)
		enemy.guns.pool.set_physics_process(false)
		enemy.guns.reset()
	# Removing physics bodies is deferred until the physics server is unlocked.
	call_deferred("_restart_enemy")

func _restart_enemy() -> void:
	if not _enemy_restart_queued or not is_instance_valid(aircraft):
		return
	_enemy_restart_queued = false
	_clear_encounter_effects()
	_spawn_enemy()

func _on_enemy_destroyed(source: EnemyAircraft) -> void:
	if source != enemy or enemy_defeated:
		return
	enemy_defeated = true
	defeat_notifications += 1
	if is_instance_valid(hud):
		hud.enemy_defeated = true

func _on_enemy_ground_impact(point: Vector3, source: EnemyAircraft) -> void:
	if source != enemy or _enemy_restart_queued:
		return
	var burst: DestructionBurst = DestructionBurst.new()
	encounter_effects.add_child(burst)
	burst.global_position = point

func _on_wreck_removed(source: EnemyAircraft) -> void:
	if source != enemy:
		return
	_remember_difficulty()
	enemy = null
	if is_instance_valid(hud):
		hud.enemy = null

func _clear_encounter_effects() -> void:
	if not is_instance_valid(encounter_effects):
		return
	for effect in encounter_effects.get_children():
		encounter_effects.remove_child(effect)
		effect.queue_free()
