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
	var state: Dictionary = {"selecting": session.selector != null, "selected": session.selected_aircraft, "paused": get_tree().paused}
	if is_instance_valid(session.selector):
		state.selected = session.selector.selected
		state.spitfire_button = _center(session.selector.buttons[0])
		state.gladiator_button = _center(session.selector.buttons[1])
		state.fly_button = _center(session.selector.fly_button)
	if is_instance_valid(session.aircraft):
		var aircraft: FlightAircraft = session.aircraft
		state.merge({"throttle": aircraft.pilot.throttle, "hp": aircraft.health.hp, "shots": aircraft.guns.pool.statistics.shots, "speed": aircraft.airspeed, "altitude": aircraft.altitude, "gear": aircraft.gear.extended, "fixed_gear": not aircraft.gear.retractable, "destroyed": aircraft.is_destroyed, "crashed": aircraft.is_crashed, "debug_visible": session.component_debug.enabled, "fire_guide": session.hud.fire_key_label, "smoke": aircraft.damage_effects.emitting})
		state.enemy_count = 1 if is_instance_valid(session.enemy) else 0
		state.enemy_hp = session.enemy.health.hp if is_instance_valid(session.enemy) else 0
		state.change_button = _center(session.hud.change_aircraft_button)
		state.change_visible = session.hud.change_aircraft_button.is_visible_in_tree()
	bridge.eval("window.firstSortieState = " + JSON.stringify(state) + ";")

func _center(control: Control) -> Array:
	var point: Vector2 = get_viewport().get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
	return [point.x, point.y]
