class_name WebSupport
extends Node
## Browser-only input fallback and opt-in read-only smoke-test telemetry.
## No aircraft state, transforms, velocities or damage are assigned here.
var session: Node3D
var bridge: Object
var sample_clock: float = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Browsers cannot borrow the desktop's system fallback fonts. Bundle the
	# arrows/aim-marker glyphs while retaining Godot's primary UI typeface.
	var font: Font = ThemeDB.fallback_font
	var fallbacks: Array[Font] = font.fallbacks
	fallbacks.append(preload("res://assets/fonts/DejaVuSans.ttf"))
	font.fallbacks = fallbacks
	for physical in [false, true]:
		var key: InputEventKey = InputEventKey.new()
		if physical:
			key.physical_keycode = KEY_F
		else:
			key.keycode = KEY_F
		InputMap.action_add_event("fire", key)
	bridge = Engine.get_singleton("JavaScriptBridge")
	set_process(bridge != null and bool(bridge.eval("new URLSearchParams(location.search).get('smoke') === '1'")))

func _process(delta: float) -> void:
	sample_clock -= delta
	if sample_clock > 0:
		return
	sample_clock = 0.2
	var state: Dictionary = {"selecting": session.selector != null, "selected": session.selected_aircraft, "paused": get_tree().paused, "environment": session.environment_id, "airfield_selecting": is_instance_valid(session.malta_menu), "on_foot": is_instance_valid(session.malta_mission) and session.malta_mission.pilot.active}
	state.missions_selecting = is_instance_valid(session.missions_menu)
	if is_instance_valid(session.missions_menu):
		state.mission_picker = _center(session.missions_menu.mission_picker)
		state.mission_selected = session.missions_menu.mission_picker.selected
		state.mission_depart_button = _center(session.missions_menu.launch_button)
		state.mission_back_button = _center(session.missions_menu.back_button)
	if is_instance_valid(session.aa_defence):
		var defence: DiveDefenceMission=session.aa_defence
		state.aa_defence={"phase":defence.phase,"wave":defence.wave,"remaining":defence.alive.size(),"spawned":defence.total_spawned,"lost":defence.total_destroyed,"clock":defence.clock,"bombs":defence.bombs_released,"ordnance":defence.outstanding_ordnance(),"gun_hp":defence.guns.map(func(g):return g.hp),"player_hp":session.malta_mission.pilot.health.hp,"result_count":defence.result_count,"markers":session.encounters.enemy_widgets.values().map(func(w):return w.visible),"retry":_center(defence.retry_button),"return":_center(defence.return_button)}
	if is_instance_valid(session.interception):
		state.interception = {"phase": session.interception.phase, "checkpoint_index": session.interception.checkpoint_index, "checkpoint_count": session.interception.definition.checkpoint_positions.size(), "activation_distance": session.interception.activation_distance, "elapsed": session.interception.elapsed, "activated": session.interception.activated, "result": session.interception.final_reason, "marker": session.interception.checkpoint_marker.visible, "nav_checkpoint": session.malta_mission.chart.show_objective, "retry": _center(session.interception.retry_button), "return": _center(session.interception.return_button)}
		var radio: MissionRadio = session.interception.radio
		state.interception.radio = {"supplied": radio.voice_clip != null, "triggered": radio.triggered, "playing": radio.player.playing, "transmissions": radio.transmissions_played, "subtitle": radio.subtitle.visible, "bearing": session.interception.activation_bearing}
	state.audio = {"menu_active": GameAudioMixer.instance.menu_active, "music_playing": GameAudioMixer.instance.music.playing, "music_gain": GameAudioMixer.instance.music_gain, "music_db": GameAudioMixer.instance.music.volume_db, "music_paused": GameAudioMixer.instance.music.stream_paused, "music_position": GameAudioMixer.instance.music.get_playback_position(), "muted": GameAudioMixer.instance.muted, "master_muted": AudioServer.is_bus_mute(0), "volumes": GameAudioMixer.instance.volumes, "panel_open": GameAudioMixer.instance.panel.visible, "gameplay_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("Aircraft"))}
	state.encounter = {"mode": session.game_mode, "stage": session.encounters.stage, "remaining": session.encounters.active.size(), "awaiting": session.encounters.awaiting_confirmation, "initial_pending": session.encounters.initial_spawn_pending, "ended": session.encounters.ended, "complete": session.encounters.complete}
	state.encounter.enemies = []
	for foe in session.encounters.active:
		state.encounter.enemies.append({"id": foe.get_instance_id(), "hp": foe.health.hp, "ace": foe.encounter_ace, "kind": foe.aircraft_kind})
	if is_instance_valid(session.component_debug):
		state.debug_target_popup = session.component_debug.target_picker.get_popup().visible
		state.debug_target_focus = session.component_debug.target_picker.get_popup().get_focused_item()
		state.debug_target_picker = _center(session.component_debug.target_picker)
		state.debug_damage_button = _center(session.component_debug.damage_button)
	state.confirm_button = _center(session.encounters.confirm_button)
	state.audio_button = _center(GameAudioMixer.instance.audio_button)
	state.audio_mute_button = _center(GameAudioMixer.instance.mute_button)
	if is_instance_valid(session.selector):
		state.selected = session.selector.selected
		state.spitfire_button = _center(session.selector.buttons[0])
		state.gladiator_button = _center(session.selector.buttons[1])
		state.fly_button = _center(session.selector.fly_button)
		state.malta_button = _center(session.selector.malta_button)
		state.missions_button = _center(session.selector.missions_button)
	if is_instance_valid(session.malta_menu):
		state.mode_popup = session.malta_menu.mode_picker.get_popup().visible
		state.mode_focus = session.malta_menu.mode_picker.get_popup().get_focused_item()
		state.mode_picker = _center(session.malta_menu.mode_picker)
		state.selected_mode = session.malta_menu.selected_mode
		state.home_airfield = session.malta_menu.selected_field
		state.st_elmo_button = _center(session.malta_menu.chart.buttons.st_elmo)
		state.spawn_picker = _center(session.malta_menu.field_picker)
		state.depart_button = _center(session.malta_menu.depart_button)
		state.ta_qali_button = _center(session.malta_menu.chart.buttons.ta_qali)
		state.luqa_button = _center(session.malta_menu.chart.buttons.luqa)
		state.hal_far_button = _center(session.malta_menu.chart.buttons.hal_far)
	if is_instance_valid(session.malta_mission):
		var fort: StElmoBattery=session.malta_mission.world.fort_battery
		state.fort={"guns":fort.guns.size(),"operational":fort.operational_count(),"command":fort.command_active(),"shots":fort.guns.map(func(g):return g.shots_fired),"seated":fort.guns.map(func(g):return g.crew.seated),"crew_waiting":fort.guns.map(func(g):return g.crew.waiting),"spawn":session.departure_spawn}
		state.travel_selected=session.malta_mission.travel_picker.selected
		state.travel_popup_focus=session.malta_mission.travel_picker.get_popup().get_focused_item()
		state.travel_notice=session.malta_mission.notice
		state.travel_picker=_center(session.malta_mission.travel_picker)
		state.travel_button=_center(session.malta_mission.travel_button)
		state.travel_enabled=session.malta_mission.can_travel()
		state.terrain = session.malta_mission.world.terrain_appearance.diagnostic_state()
		var city: VallettaCity = session.malta_mission.world.valletta_city
		state.valletta = {"ready":city.ready_for_flight,"buildings":city.layout.building_count,"structures":city.structure_count,"details":city.detail_count,"collision_chunks":city.collision_count,"visible":city.visible,"landmarks":city.layout.landmarks.size()}
		var mdina: MdinaCity = session.malta_mission.world.mdina_city
		state.mdina = {"ready":mdina.ready_for_flight,"buildings":mdina.layout.building_count,"structures":mdina.structure_count,"details":mdina.detail_count,"collision_chunks":mdina.collision_count,"visible":mdina.visible,"walls":mdina.layout.wall_segments,"x":mdina.position.x,"z":mdina.position.z,"elevation":mdina.layout.reference_terrain_height}
		var cottonera: CottoneraRegion = session.malta_mission.world.cottonera_region
		state.cottonera = {"status":cottonera.status,"regions":cottonera.regions.size(),"visuals":cottonera.visual_count,"collisions":cottonera.collision_count,"visible":cottonera.visible}
		var access_fields: Array=session.malta_mission.world.fields.values()
		state.base_access_count=access_fields.filter(func(f):return not f.access_record.is_empty()).size()
		state.base_access_widths=access_fields.map(func(f):return f.access_record.width)
		state.base_apron_lane_counts=access_fields.map(func(f):return int(f.apron_surface.material_override.get_shader_parameter("access_count")))
		state.corrected_access_segments=int(MaltaTerrainAppearance.LANDSCAPE.get_shader_parameter("new_access_count"))
		state.world_id = session.malta_mission.world.get_instance_id()
		state.fleet_count = session.malta_mission.fleet.size()
		var aa: AirfieldAABattery = session.malta_mission.world.aa_battery
		state.command_posts=[]
		for post in aa.command_stations:
			state.command_posts.append({"field":post.field_id,"position":[post.global_position.x,post.global_position.y,post.global_position.z],"mounted":post.mounted,"hp":post.hp,"salvos":post.salvos_issued,"shots":post.commanded_shots,"pending":post.orders.size(),"target":post.target.marker_name if is_instance_valid(post.target) else "","designated":post.designated,"valid":post.solutions.values().filter(func(s):return s.valid and s.aimable).size()})
		state.aa_count = aa.guns.size()
		if is_instance_valid(session.aa_defence):
			state.defence_sounds={"intro":session.aa_defence.audio.radio.player.playing,"intro_count":session.aa_defence.audio.radio.transmissions_played,"siren":session.aa_defence.audio.siren.playing,"siren_loop":session.aa_defence.audio.siren.stream.loop,"siren_starts":session.aa_defence.audio.siren_starts,"dives":session.encounters.active.map(func(f):return f.get_children().filter(func(c):return c is StukaDiveAudio and c.player.playing).size())}

		state.aa_heavy_count = aa.guns.filter(func(gun):return gun.weapon.heavy).size()
		state.aa_light_count = aa.guns.size()-state.aa_heavy_count
		state.aa_reload = session.malta_mission.interaction.occupied_gun.cooldown if session.malta_mission.interaction.occupied_gun != null else 0
		var mounted: BritishAAGun = session.malta_mission.interaction.occupied_gun
		state.aa_mouse = {"captured":Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"armed":mounted!=null and not mounted.mouse_controls.release_fire,"sensitivity":AAMouseControls.sensitivity,"yaw":mounted.yaw.rotation.y if mounted!=null else 0,"pitch":mounted.elevation.rotation.x if mounted!=null else 0,"fov":mounted.camera.fov if mounted!=null else 58,"settings":session.malta_mission.aa_settings.visible,"slider":_center(session.malta_mission.aa_sensitivity)}
		state.aa_healthy = aa.guns.all(func(gun): return gun.hp == gun.max_hp)
		state.aa_mounted = aa.guns.filter(func(gun): return gun.mounted).size()
		state.aa_shots = 0
		for gun in aa.guns: state.aa_shots += gun.shots_fired
		state.truck_count = session.malta_mission.world.trucks.size()
		var ground: AirfieldInteraction = session.malta_mission.interaction
		state.ground_mode = "gun" if ground.occupied_gun != null else ("truck" if ground.occupied_vehicle != null else ("aircraft" if session.malta_mission.occupied != null else "walking"))
		state.ground_prompt = ground.prompt()
		state.truck_speed = ground.occupied_vehicle.speed if ground.occupied_vehicle != null else 0
		state.ground_reticle = ground.sight.visible
		var pilot: GroundPilot = session.malta_mission.pilot
		state.ground_position = [pilot.global_position.x,pilot.global_position.y,pilot.global_position.z]
		state.pilot_yaw = pilot.yaw
		state.truck_positions = []
		for truck in session.malta_mission.world.trucks:
			state.truck_positions.append([truck.global_position.x,truck.global_position.y,truck.global_position.z])
		state.gun_positions = []
		for gun in aa.guns:
			state.gun_positions.append([gun.global_position.x,gun.global_position.y,gun.global_position.z])
		state.map_open = session.malta_mission.chart_panel.visible
		state.engine_running = session.aircraft.engine_running
		state.home_airfield = session.malta_mission.home
	if is_instance_valid(session.aircraft):
		var aircraft: FlightAircraft = session.aircraft
		state.audio.engine_playing = aircraft.aircraft_audio.idle.playing
		state.audio.engine_gain = aircraft.aircraft_audio.engine_gain
		state.audio.engine_rpm = aircraft.aircraft_audio.rpm
		state.audio.flight_mix = aircraft.aircraft_audio.flight_mix
		state.audio.gun_playing = aircraft.guns.weapon_audio.player.playing
		state.audio.gun_gain = aircraft.guns.weapon_audio.gain
		state.audio.audible_salvos = aircraft.guns.weapon_audio.audible_salvos
		state.merge({"throttle": aircraft.pilot.throttle, "hp": aircraft.health.hp, "shots": aircraft.guns.pool.statistics.shots, "speed": aircraft.airspeed, "altitude": aircraft.altitude, "gear": aircraft.gear.extended, "fixed_gear": not aircraft.gear.retractable, "destroyed": aircraft.is_destroyed, "crashed": aircraft.is_crashed, "debug_visible": session.component_debug.enabled if is_instance_valid(session.component_debug) else false, "fire_guide": session.hud.fire_key_label if is_instance_valid(session.hud) else "F", "smoke": aircraft.damage_effects.emitting})
		state.impact = {"started":aircraft.impact_effects.started,"water":aircraft.impact_effects.water,"fragments":aircraft.impact_effects.fragments.size(),"model_visible":aircraft.model.visible}
		state.enemy_count = session.encounters.active.size()
		state.enemy_hp = session.enemy.health.hp if is_instance_valid(session.enemy) else 0
		if is_instance_valid(session.hud):
			state.enemy_label = session.hud.enemy_label.text
			state.change_button = _center(session.hud.change_aircraft_button)
			state.change_visible = session.hud.change_aircraft_button.is_visible_in_tree()
	bridge.eval("window.firstSortieState = " + JSON.stringify(state) + ";")

func _center(control: Control) -> Array:
	var point: Vector2 = get_viewport().get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	return [point.x, point.y]
