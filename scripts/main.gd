extends Node3D
var environment_id: String = "countryside"
var field: Node3D
var malta_menu: MaltaDepartureMenu
var malta_mission: MaltaMission
var home_airfield: String = "ta_qali"
var departure_kind: String = "spitfire"
var aircraft: FlightAircraft
var chase: ChaseCamera
var hud: FlightHUD
var enemy: EnemyAircraft
var component_debug: ComponentDamageDebug
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
var _rear_gunner_settings: Dictionary = {}
var enemy_front_statistics: WeaponStatistics
var enemy_rear_statistics: WeaponStatistics

func _ready() -> void:
	if OS.has_feature("web"):
		var web: WebSupport = WebSupport.new()
		web.session = self
		add_child(web)
	field = Airfield.new()
	field.name = "CountrysideAirfield"
	add_child(field)
	encounter_effects = Node3D.new()
	encounter_effects.name = "SessionEffects"
	add_child(encounter_effects)
	show_selection()

func show_selection() -> void:
	_remember_difficulty()
	_clear_malta()
	_clear_encounter_effects()
	_enemy_restart_queued = false
	enemy_defeated = false
	get_tree().paused = false
	get_viewport().gui_release_focus()
	# Removing nodes before queue_free prevents old pilots/HUD consuming input
	# and old world-space rounds persisting when returning from the pause menu.
	for node in [hud, component_debug, enemy, aircraft, chase, selector]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	aircraft = null
	enemy = null
	chase = null
	hud = null
	component_debug = null
	enemy_front_statistics = null
	enemy_rear_statistics = null
	selector = AircraftSelector.new()
	selector.name = "AircraftSelection"
	selector.chosen.connect(start_flight, CONNECT_DEFERRED)
	add_child(selector)
	selector.select(selected_aircraft)
	selector.malta_requested.connect(show_malta_selection, CONNECT_DEFERRED)

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
	component_debug = ComponentDamageDebug.new()
	component_debug.name = "ComponentDebug"
	component_debug.session = self
	add_child(component_debug)
	component_debug.toggled.connect(func(enabled: bool): hud.component_debugging = enabled)


func _exported_settings(component: Node) -> Dictionary:
	var settings: Dictionary = {}
	for property in component.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (int(property.usage) & PROPERTY_USAGE_EDITOR) != 0:
			settings[property.name] = component.get(property.name)
	return settings

func _remember_difficulty() -> void:
	if is_instance_valid(enemy):
		var settings: Dictionary = _exported_settings(enemy.ai)
		for key in ["world_extent", "measured_terrain"]:
			settings.erase(key)
		# Malta expands pursuit for this environment only; retain countryside tuning.
		if environment_id == "malta":
			settings.erase("pursuit_release_range")
			if _ai_settings.has("pursuit_release_range"):
				settings.pursuit_release_range = _ai_settings.pursuit_release_range
		_ai_settings = settings
		_gun_settings = _exported_settings(enemy.guns)
		_rear_gunner_settings = _exported_settings(enemy.rear_gunner)

func _spawn_enemy() -> void:
	_remember_difficulty()
	if is_instance_valid(enemy):
		remove_child(enemy)
		enemy.queue_free()
	enemy = EnemyAircraft.new()
	enemy.name = "EnemyStuka"
	enemy.target = aircraft
	var spawn: Vector3 = enemy_spawn_position
	if environment_id == "malta":
		spawn = aircraft.global_position + Vector3(-950, 220, -1000)
	# The normal runway start is >750 m away. Alternate player start positions
	# still receive clearance and safe terrain height, rather than overlapping.
	if spawn.distance_to(aircraft.global_position) < 400:
		spawn = aircraft.global_position + Vector3(-550, 100, -300)
	spawn.y = maxf(spawn.y, 500.0) if environment_id == "malta" else maxf(spawn.y, Airfield.height_at(spawn.x, spawn.z) + 120)
	enemy.reset_position = spawn
	add_child(enemy)
	for key in _ai_settings:
		enemy.ai.set(key, _ai_settings[key])
	for key in _gun_settings:
		enemy.guns.set(key, _gun_settings[key])
	for key in _rear_gunner_settings:
		enemy.rear_gunner.set(key, _rear_gunner_settings[key])
	if environment_id == "malta":
		enemy.ai.measured_terrain = true
		enemy.ai.world_extent = INF # no countryside boundary or island travel gate
		enemy.ai.patrol_center = spawn
		enemy.ai.pursuit_release_range = 100000
	enemy.ai.reset()
	enemy.rear_gunner.reset()
	aircraft.guns.telemetry_target = enemy
	enemy.guns.telemetry_target = aircraft
	enemy_front_statistics = enemy.guns.pool.statistics
	enemy_rear_statistics = enemy.rear_gunner.guns.pool.statistics
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
		enemy.rear_gunner.cease_fire()
		enemy.rear_gunner.set_physics_process(false)
		enemy.rear_gunner.guns.set_physics_process(false)
		enemy.rear_gunner.guns.pool.set_physics_process(false)
		enemy.rear_gunner.guns.reset()
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

func show_malta_selection() -> void:
	if is_instance_valid(malta_menu) or is_instance_valid(malta_mission):
		return
	if is_instance_valid(selector):
		remove_child(selector)
		selector.queue_free()
	selector = null
	environment_id = "malta"
	malta_menu = MaltaDepartureMenu.new()
	malta_menu.selected_field = home_airfield
	malta_menu.selected_kind = selected_aircraft
	malta_menu.departed.connect(start_malta, CONNECT_DEFERRED)
	malta_menu.back_requested.connect(show_selection, CONNECT_DEFERRED)
	add_child(malta_menu)

func _clear_malta() -> void:
	for node in [malta_menu, malta_mission]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	malta_menu = null
	malta_mission = null
	if environment_id == "malta":
		# Fleet lives under the mission and is already queued, not a direct child.
		aircraft = null
		if is_instance_valid(field):
			remove_child(field)
			field.queue_free()
		field = Airfield.new()
		field.name = "CountrysideAirfield"
		add_child(field)
	environment_id = "countryside"

func start_malta(field_id: String, kind: String) -> void:
	if MaltaGeography.field(field_id).is_empty() or kind not in ["spitfire", "sea_gladiator"]:
		return
	if is_instance_valid(malta_mission):
		return
	if is_instance_valid(malta_menu):
		remove_child(malta_menu)
		malta_menu.queue_free()
	malta_menu = null
	if is_instance_valid(selector):
		remove_child(selector)
		selector.queue_free()
	selector = null
	if is_instance_valid(field):
		remove_child(field)
		field.queue_free()
	environment_id = "malta"
	home_airfield = field_id
	selected_aircraft = kind
	departure_kind = kind
	field = MaltaWorld.new()
	add_child(field)
	malta_mission = MaltaMission.new()
	malta_mission.session = self
	malta_mission.world = field
	malta_mission.home = field_id
	malta_mission.initial_kind = kind
	add_child(malta_mission)
	aircraft = malta_mission.initial_aircraft
	_spawn_enemy()
	enemy.target = null
	enemy.ai.target = null
	get_viewport().gui_release_focus()

func attach_malta_player(player: FlightAircraft) -> void:
	for node in [hud, component_debug, chase]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	aircraft = player
	selected_aircraft = "sea_gladiator" if player is SeaGladiator else "spitfire"
	chase = ChaseCamera.new()
	chase.aircraft = player
	add_child(chase)
	chase.far = 100000
	hud = FlightHUD.new()
	hud.aircraft = player
	hud.enemy = enemy
	hud.enemy_defeated = enemy_defeated
	hud.mission = malta_mission
	add_child(hud)
	hud.change_aircraft_requested.connect(show_selection, CONNECT_DEFERRED)
	component_debug = ComponentDamageDebug.new()
	component_debug.session = self
	add_child(component_debug)
	component_debug.toggled.connect(func(enabled: bool): hud.component_debugging = enabled)

func restart_malta() -> void:
	if environment_id != "malta":
		return
	var saved_home: String = home_airfield
	var saved_kind: String = departure_kind
	show_selection()
	start_malta(saved_home, saved_kind)
