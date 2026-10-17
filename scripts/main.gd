extends Node3D
var game_mode: String = "encounter"
var encounters: EnemyEncounters
var environment_id: String = "countryside"
var field: Node3D
var missions_menu: MissionsMenu
var aa_defence: DiveDefenceMission
var harbour: HarbourInterception
var interception: VallettaInterception
var malta_menu: MaltaDepartureMenu
var malta_mission: MaltaMission
var home_airfield: String = "ta_qali"
var departure_spawn: String = "ta_qali"
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
	encounters = EnemyEncounters.new()
	encounters.session = self
	add_child(encounters)
	show_selection()

func show_selection() -> void:
	if is_instance_valid(harbour):
		harbour.cancel()
		remove_child(harbour)
		harbour.queue_free()
	harbour = null
	GameAudioMixer.instance.set_menu_active(true)
	_remember_difficulty()
	if is_instance_valid(aa_defence):
		aa_defence.cancel()
		remove_child(aa_defence)
		aa_defence.queue_free()
	aa_defence=null
	if is_instance_valid(interception):
		interception.cancel()
		remove_child(interception)
		interception.queue_free()
	interception = null
	encounters.clear()
	enemy = null
	_clear_malta()
	_clear_encounter_effects()
	_enemy_restart_queued = false
	enemy_defeated = false
	get_tree().paused = false
	get_viewport().gui_release_focus()
	# Removing nodes before queue_free prevents old pilots/HUD consuming input
	# and old world-space rounds persisting when returning from the pause menu.
	for node in [hud, component_debug, aircraft, chase, selector]:
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
	selector.missions_requested.connect(show_missions, CONNECT_DEFERRED)

func start_flight(kind: String) -> void:
	if is_instance_valid(aircraft) or kind not in ["spitfire", "sea_gladiator"]:
		return
	GameAudioMixer.instance.set_menu_active(false)
	game_mode = "encounter"
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
	aircraft.destroyed.connect(encounters.player_destroyed.bind(aircraft))
	aircraft.reset_completed.connect(_on_player_reset)
	chase = ChaseCamera.new()
	chase.name = "ChaseCamera"
	chase.aircraft = aircraft
	add_child(chase)
	aircraft.reset_completed.connect(chase.snap)
	hud = FlightHUD.new()
	hud.encounters = encounters
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
	if game_mode=="aa_defence":return # mission attack settings never leak into normal encounters
	# Never copy ace aiming overrides back into normal pilots.
	if is_instance_valid(enemy) and not enemy.encounter_ace and enemy.aircraft_kind == "stuka":
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
	enemy = null
	enemy_defeated = false
	defeat_notifications = 0
	session_number += 1
	encounters.begin(game_mode)

func create_encounter_enemy(spawn: Vector3, ace: bool, kind: String = "stuka") -> EnemyAircraft:
	var definition: EnemyAircraftDefinition = EnemyAircraftDefinition.find(kind)
	var foe: EnemyAircraft = EnemyAircraft.new() if definition == null else ItalianEnemy.new()
	if definition != null:
		(foe as ItalianEnemy).definition = definition
	foe.name = ("Ace" if ace else "Enemy") + ("Stuka" if definition == null else definition.marker.replace(".", ""))
	foe.encounter_ace = ace
	foe.target = aircraft
	foe.reset_position = spawn
	add_child(foe)
	for key in _ai_settings if definition == null else {}:
		foe.ai.set(key, _ai_settings[key])
	for key in _gun_settings if definition == null else {}:
		foe.guns.set(key, _gun_settings[key])
	for key in _rear_gunner_settings if definition == null else {}:
		foe.rear_gunner.set(key, _rear_gunner_settings[key])
	if ace:
		foe.display_name = "ACE · " + foe.display_name
		foe.ai.aim_error_degrees *= encounters.ace_aim_error_scale
		foe.guns.spread_degrees *= encounters.ace_dispersion_scale
	if environment_id == "malta":
		foe.ai.measured_terrain = true
		foe.ai.world_extent = INF
		foe.ai.patrol_center = spawn
		foe.ai.pursuit_release_range = 100000
	foe.ai.reset()
	foe.rear_gunner.reset()
	foe.ground_impact.connect(_on_enemy_ground_impact.bind(foe))
	return foe

func encounter_tracking_changed() -> void:
	# Keep legacy HUD/debug's focused enemy reference; the director owns ALL lives.
	if not encounters.active.is_empty():
		enemy = encounters.active[0]
	elif not encounters.wrecks.is_empty():
		enemy = encounters.wrecks.back()
	else:
		enemy = null
	# A peaceful departure is not a kill. This distinction also keeps the
	# flight HUD from announcing ENEMY DESTROYED before the first request.
	enemy_defeated = encounters.active.is_empty() and not encounters.initial_spawn_pending
	if is_instance_valid(enemy):
		enemy_front_statistics = enemy.guns.pool.statistics
		enemy_rear_statistics = enemy.rear_gunner.guns.pool.statistics
	if is_instance_valid(aircraft):
		aircraft.guns.telemetry_target = enemy
	if is_instance_valid(hud):
		hud.enemy = enemy
		hud.enemy_defeated = enemy_defeated

func _on_player_reset() -> void:
	if _enemy_restart_queued:
		return
	_enemy_restart_queued = true
	for foe in encounters.active + encounters.wrecks:
		if not is_instance_valid(foe):
			continue
		foe.ai.set_physics_process(false)
		foe.pilot.fire = false
		foe.guns.set_physics_process(false)
		foe.guns.reset()
		foe.rear_gunner.cease_fire()
		foe.rear_gunner.set_physics_process(false)
		foe.rear_gunner.guns.reset()
	# Removing physics bodies is deferred until the physics server is unlocked.
	call_deferred("_restart_enemy")

func _restart_enemy() -> void:
	if not _enemy_restart_queued or not is_instance_valid(aircraft):
		return
	_enemy_restart_queued = false
	_clear_encounter_effects()
	_spawn_enemy()

func _on_enemy_ground_impact(point: Vector3, source: EnemyAircraft) -> void:
	if not encounters.wrecks.has(source) or _enemy_restart_queued:
		return
	var burst: DestructionBurst = DestructionBurst.new()
	burst.visual_enabled = false
	encounter_effects.add_child(burst)
	burst.global_position = point

func _clear_encounter_effects() -> void:
	if is_instance_valid(AircraftImpactService.instance):AircraftImpactService.instance.clear_all()
	if not is_instance_valid(encounter_effects):
		return
	for effect in encounter_effects.get_children():
		encounter_effects.remove_child(effect)
		effect.queue_free()

func show_malta_selection() -> void:
	if is_instance_valid(malta_menu) or is_instance_valid(malta_mission):
		return
	GameAudioMixer.instance.set_menu_active(true)
	if is_instance_valid(selector):
		remove_child(selector)
		selector.queue_free()
	selector = null
	environment_id = "malta"
	malta_menu = MaltaDepartureMenu.new()
	malta_menu.selected_field = departure_spawn
	malta_menu.selected_kind = selected_aircraft
	malta_menu.departed.connect(start_malta, CONNECT_DEFERRED)
	malta_menu.back_requested.connect(show_selection, CONNECT_DEFERRED)
	add_child(malta_menu)

func _clear_malta() -> void:
	for node in [malta_menu, malta_mission, missions_menu]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	malta_menu = null
	malta_mission = null
	missions_menu = null
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

func start_malta(field_id: String, kind: String, selected_mode: String = "encounter") -> void:
	var spawn_id: String=field_id
	if StElmoLocations.is_fort(field_id):
		if selected_mode not in ["encounter","survival"]:return
		field_id="luqa"
	if selected_mode not in ["encounter", "survival", "interception", "aa_defence", "harbour"]:
		return
	if MaltaGeography.field(field_id).is_empty() or kind not in ["spitfire", "sea_gladiator"]:
		return
	if is_instance_valid(malta_mission):
		return
	GameAudioMixer.instance.set_menu_active(false)
	if is_instance_valid(missions_menu):
		remove_child(missions_menu)
		missions_menu.queue_free()
	missions_menu = null
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
	game_mode = selected_mode
	home_airfield = field_id
	departure_spawn = spawn_id
	selected_aircraft = kind
	departure_kind = kind
	field = MaltaWorld.new()
	add_child(field)
	malta_mission = MaltaMission.new()
	malta_mission.session = self
	malta_mission.world = field
	malta_mission.home = field_id
	malta_mission.initial_spawn_id = spawn_id
	malta_mission.initial_kind = kind
	add_child(malta_mission)
	aircraft = malta_mission.initial_aircraft
	if game_mode == "harbour":
		session_number += 1
		defeat_notifications = 0
		enemy_defeated = false
		encounters.begin_external()
		harbour = HarbourInterception.new()
		harbour.session = self
		add_child(harbour)
	elif game_mode == "aa_defence":
		session_number+=1
		defeat_notifications=0
		enemy_defeated=false
		encounters.begin_external()
		aa_defence=DiveDefenceMission.new()
		aa_defence.session=self
		add_child(aa_defence)
	elif game_mode == "interception":
		session_number += 1
		defeat_notifications = 0
		enemy_defeated = false
		encounters.begin_external()
		interception = VallettaInterception.new()
		interception.session = self
		add_child(interception)
	else:
		_spawn_enemy()
	encounters.set_target(null)
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
	hud.encounters = encounters
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
	var saved_home: String = departure_spawn
	var saved_kind: String = departure_kind
	var saved_mode: String = game_mode
	show_selection()
	start_malta(saved_home, saved_kind, saved_mode)

func show_missions() -> void:
	if is_instance_valid(missions_menu) or is_instance_valid(malta_mission):
		return
	if is_instance_valid(selector):
		remove_child(selector)
		selector.queue_free()
	selector = null
	missions_menu = MissionsMenu.new()
	missions_menu.launch_requested.connect(start_interception, CONNECT_DEFERRED)
	missions_menu.harbour_requested.connect(start_harbour, CONNECT_DEFERRED)
	missions_menu.aa_requested.connect(start_aa_defence,CONNECT_DEFERRED)
	missions_menu.back_requested.connect(show_selection, CONNECT_DEFERRED)
	add_child(missions_menu)

func start_interception(kind: String) -> void:
	start_malta("ta_qali", kind, "interception")

func return_to_missions() -> void:
	show_selection()
	show_missions()

func start_aa_defence() -> void:
	start_malta("luqa","spitfire","aa_defence")

func start_harbour() -> void:
	start_malta("hal_far", "sea_gladiator", "harbour")
