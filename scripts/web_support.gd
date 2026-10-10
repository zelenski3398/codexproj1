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
	var state: Dictionary = {"selecting": session.selector != null, "selected": session.selected_aircraft, "paused": get_tree().paused, "environment": session.environment_id, "airfield_selecting": is_instance_valid(session.malta_menu), "on_foot": is_instance_valid(session.malta_mission) and session.malta_mission.occupied == null}
	state.audio = {"menu_active": GameAudioMixer.instance.menu_active, "music_playing": GameAudioMixer.instance.music.playing, "music_gain": GameAudioMixer.instance.music_gain, "music_db": GameAudioMixer.instance.music.volume_db, "music_paused": GameAudioMixer.instance.music.stream_paused, "music_position": GameAudioMixer.instance.music.get_playback_position(), "muted": GameAudioMixer.instance.muted, "master_muted": AudioServer.is_bus_mute(0), "volumes": GameAudioMixer.instance.volumes, "panel_open": GameAudioMixer.instance.panel.visible, "gameplay_muted": AudioServer.is_bus_mute(AudioServer.get_bus_index("Aircraft"))}
	state.audio_button = _center(GameAudioMixer.instance.audio_button)
	state.audio_mute_button = _center(GameAudioMixer.instance.mute_button)
	if is_instance_valid(session.selector):
		state.selected = session.selector.selected
		state.spitfire_button = _center(session.selector.buttons[0])
		state.gladiator_button = _center(session.selector.buttons[1])
		state.fly_button = _center(session.selector.fly_button)
		state.malta_button = _center(session.selector.malta_button)
	if is_instance_valid(session.malta_menu):
		state.home_airfield = session.malta_menu.selected_field
		state.depart_button = _center(session.malta_menu.depart_button)
		state.ta_qali_button = _center(session.malta_menu.chart.buttons.ta_qali)
		state.luqa_button = _center(session.malta_menu.chart.buttons.luqa)
		state.hal_far_button = _center(session.malta_menu.chart.buttons.hal_far)
	if is_instance_valid(session.malta_mission):
		state.terrain = session.malta_mission.world.terrain_appearance.diagnostic_state()
		state.world_id = session.malta_mission.world.get_instance_id()
		state.fleet_count = session.malta_mission.fleet.size()
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
		state.enemy_count = 1 if is_instance_valid(session.enemy) else 0
		state.enemy_hp = session.enemy.health.hp if is_instance_valid(session.enemy) else 0
		if is_instance_valid(session.hud):
			state.change_button = _center(session.hud.change_aircraft_button)
			state.change_visible = session.hud.change_aircraft_button.is_visible_in_tree()
	bridge.eval("window.firstSortieState = " + JSON.stringify(state) + ";")

func _center(control: Control) -> Array:
	var point: Vector2 = get_viewport().get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	return [point.x, point.y]
