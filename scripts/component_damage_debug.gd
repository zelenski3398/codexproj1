class_name ComponentDamageDebug
extends CanvasLayer
signal toggled(enabled: bool)
## Temporary test tools; no new flight-key bindings, transforms or automation.
var session: Node3D
var panel: PanelContainer
var target_picker: OptionButton
var part_picker: OptionButton
var force_fuel: CheckButton
var health_text: Label
var effects_text: Label
var damage_button: Button
var repair_button: Button
var enabled: bool = false
var refresh_clock: float = 0
var part_ids: Array[StringName] = []
@export var developer_tools_enabled: bool = (OS.is_debug_build() and not OS.has_feature("web")) or "--damage-debug" in OS.get_cmdline_user_args() or bool(ProjectSettings.get_setting("gameplay/enable_damage_debug", false))
var gunner_panel: GunnerDebugPanel

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.position = Vector2(26, 165)
	panel.custom_minimum_size = Vector2(415, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.05, 0.96)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.size.y = minf(620,get_viewport().get_visible_rect().size.y-190)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	column.add_child(_label("COMPONENT DAMAGE · DEBUG / F3", 18))
	column.add_child(_label("White boxes mark the selected component.\nPause with Esc to inspect; R restarts the encounter.", 13))
	target_picker = OptionButton.new()
	target_picker.add_item("Inspect / damage PLAYER")
	target_picker.add_item("Inspect / damage ENEMY")
	target_picker.focus_mode = Control.FOCUS_NONE
	column.add_child(target_picker)
	target_picker.item_selected.connect(_on_selection_changed)
	health_text = _label("", 14)
	column.add_child(health_text)
	effects_text = _label("", 13)
	column.add_child(effects_text)
	part_picker = OptionButton.new()
	part_ids.assign(AircraftDamage.IDS)
	for id in part_ids:
		part_picker.add_item(String(id).capitalize())
	part_picker.focus_mode = Control.FOCUS_NONE
	column.add_child(part_picker)
	part_picker.item_selected.connect(_on_selection_changed)
	force_fuel = CheckButton.new()
	force_fuel.text = "Force leak + fire for debug tank hits"
	force_fuel.focus_mode = Control.FOCUS_NONE
	column.add_child(force_fuel)
	damage_button = Button.new()
	damage_button.text = "APPLY 10 RAW DAMAGE TO SELECTED PART"
	damage_button.focus_mode = Control.FOCUS_NONE
	damage_button.pressed.connect(apply_selected_damage)
	column.add_child(damage_button)
	repair_button = Button.new()
	repair_button.text = "REPAIR THIS LIVE AIRCRAFT (TEST ONLY)"
	repair_button.focus_mode = Control.FOCUS_NONE
	repair_button.pressed.connect(repair_selected)
	column.add_child(repair_button)
	var scenario_picker := OptionButton.new()
	for caption in ["Engine shutdown", "Ignite selected part", "Fuel leak", "Detach selected part", "Controlled belly approach", "Steep crash approach", "Full structural breakup"]: scenario_picker.add_item(caption)
	column.add_child(scenario_picker)
	var scenario_button := Button.new()
	scenario_button.text = "RUN SELECTED DEBUG SCENARIO"
	scenario_button.pressed.connect(func(): run_scenario(scenario_picker.selected))
	column.add_child(scenario_button)
	panel.visible = false
	gunner_panel = GunnerDebugPanel.new()
	gunner_panel.session = session
	add_child(gunner_panel)
	gunner_panel.visible = false

func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e9e8d7"))
	return label

func _input(event: InputEvent) -> void:
	if not developer_tools_enabled: return
	if event.is_action_pressed("debug_components") and not event.is_echo():
		set_enabled(not enabled)
		get_viewport().set_input_as_handled()

func set_enabled(value: bool) -> void:
	if value and not developer_tools_enabled: return
	enabled = value
	panel.visible = enabled
	gunner_panel.visible = enabled
	toggled.emit(enabled)
	_update_hitboxes()
	get_viewport().gui_release_focus()

func _on_selection_changed(_index: int) -> void:
	_sync_parts()
	_update_hitboxes()
	_refresh()

func selected_aircraft() -> FlightAircraft:
	return session.aircraft if target_picker.selected == 0 else session.enemy

func apply_selected_damage() -> void:
	var target: FlightAircraft = selected_aircraft()
	if is_instance_valid(target) and not target.is_destroyed and not target.is_crashed:
		target.components.apply_damage(part_ids[part_picker.selected], 10, Vector3.ZERO, force_fuel.button_pressed)
		_refresh()

func repair_selected() -> void:
	var target: FlightAircraft = selected_aircraft()
	if is_instance_valid(target) and not target.is_destroyed and not target.is_crashed:
		target.components.reset()
		target.health.heal(target.health.max_hp)
		target.damage_effects.clear()
		_refresh()

func _update_hitboxes() -> void:
	for target in [session.aircraft, session.enemy]:
		if is_instance_valid(target):
			target.components.set_debug_visible(enabled)
			target.components.set_debug_selection(part_ids[part_picker.selected] if target == selected_aircraft() else &"")

func _process(delta: float) -> void:
	if not enabled:
		return
	refresh_clock -= delta
	if refresh_clock <= 0:
		refresh_clock = 0.1
		_update_hitboxes() # Fresh enemy instances inherit the debug visibility.
		_refresh()

func _refresh() -> void:
	var target: FlightAircraft = selected_aircraft()
	var available: bool = is_instance_valid(target)
	damage_button.disabled = not available or target.is_destroyed or target.is_crashed or target.reset_pending
	repair_button.disabled = damage_button.disabled
	if not available:
		health_text.text = "Enemy removed · C / Confirm continues · R restarts"
		effects_text.text = ""
		return
	var damage: AircraftDamage = target.components
	var rows: PackedStringArray = []
	_sync_parts()
	for id in damage.definitions:
		var definition: AircraftComponentDefinition = damage.definitions[id]
		rows.append("%-12s %5.1f/%3d %s" % [definition.display_name, float(damage.integrity[id]), roundi(definition.max_integrity), damage.component_state(id)])
	var engine_rows: PackedStringArray = []
	for id in damage.component_ids("engine"):
		engine_rows.append("%s: %d%% %s" % [id,roundi(damage.engine_power(id)*100),"SEIZED" if damage.engine_seized.has(id) else "available"])
	health_text.text = target.display_name + " · Hull HP %d/%d\n" % [floori(target.health.hp), roundi(target.health.max_hp)] + "\n".join(rows)
	effects_text.text = "\n".join(engine_rows) + "\n" + "Load %.1f G · Leak %.4f tank/s · Debris %d\nCrash: %s · Severity %.2f\n" % [damage.structural_load,damage.leak_rate,get_tree().get_nodes_in_group("aircraft_fragments").size()+get_tree().get_nodes_in_group("aircraft_major_debris").size(),target.impact_effects.crash_result.get("category","none"),target.impact_effects.crash_result.get("severity",0)] + "Lift L/R %d/%d%% · Extra drag %.3f\nPower %d%% · Rudder %d%% · Elevator %d%%\nPilot authority %d%% · Fuel %d%%\nLeak: %s · Fire: %s · Last hit: %s" % [roundi(damage.wing_efficiency(&"left_wing") * 100), roundi(damage.wing_efficiency(&"right_wing") * 100), damage.additional_drag(), roundi(damage.power_factor() * 100), roundi(damage.rudder_factor() * 100), roundi(damage.elevator_factor() * 100), roundi(damage.cockpit_factor() * 100), roundi(damage.fuel_remaining * 100), "YES" if damage.fuel_leaking else "no", "YES" if damage.fuel_burning else "no", String(damage.last_hit).capitalize() if damage.last_hit != &"" else "none"]

func _sync_parts() -> void:
	var target := selected_aircraft()
	if not is_instance_valid(target): return
	var ids := target.components.component_ids()
	if ids == part_ids: return
	var selection: int = maxi(part_picker.selected,0)
	part_ids = ids
	part_picker.clear()
	for id in part_ids: part_picker.add_item(target.components.definitions[id].display_name)
	part_picker.select(mini(selection,part_ids.size()-1))

func run_scenario(index: int) -> void:
	if not developer_tools_enabled: return
	var target := selected_aircraft()
	if not is_instance_valid(target) or target.is_destroyed: return
	var id: StringName = part_ids[part_picker.selected]
	match index:
		0:
			var engine: StringName = id if target.components.definitions[id].role == "engine" else &"engine"
			target.components.apply_damage(engine,10000,Vector3.ZERO,false,"mechanical")
		1: target.components.ignite(id)
		2:
			var tank: StringName = id if target.components.definitions[id].role == "fuel" else &"fuel_tank"
			target.components.leaking_tanks[tank] = true
			target.components.integrity[tank] = target.components.definitions[tank].max_integrity * 0.3
		3: target.components.detach(id)
		6: target.components.catastrophic_failure("Developer structural breakup", false)
		4,5:
			# Explicit fixture reset, never used by normal damage or flight logic.
			var position: Vector3 = target.global_position
			var ground: float = position.y-target.altitude
			target.request_reset()
			target.pending_reset_pose = Transform3D(Basis(Vector3.RIGHT,0.04 if index==4 else -0.8),Vector3(position.x,ground+8,position.z))
			target.pending_reset_velocity = Vector3(0,-1,-27) if index==4 else Vector3(0,-100,-90)
