class_name FlightHUD
extends CanvasLayer
signal change_aircraft_requested
const INK := Color("e9e8d7")
const MUTED := Color("abb8ad")
const GOLD := Color("e4bf75")
const PANEL := Color(0.055, 0.09, 0.085, 0.90)
const CONTROLS := "↑ / ↓   Nose down / up\n← / →   Bank left / right\nA / D   Rudder left / right\nW / S   Increase / decrease throttle\nCTRL (hold)   %s\nG   %s\nSPACE   Hold wheel brakes\nH   DEBUG: remove 10 HP\nR   Reset both aircraft\nESC   Pause / controls"
var aircraft: FlightAircraft
var enemy: EnemyAircraft
var enemy_label: Label
var enemy_marker: Label
var speed_label: Label
var altitude_label: Label
var throttle_label: Label
var gear_label: Label
var state_label: Label
var heading_label: Label
var help_label: Label
var notice_label: Label
var overlay: PanelContainer
var overlay_title: Label
var overlay_detail: Label
var resume_button: Button
var elapsed: float = 0.0
var hp_label: Label
var hp_bar: ProgressBar
var aim_marker: Label
var hp_fill: StyleBoxFlat
var change_aircraft_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	aim_marker = _label("⊕", 26, GOLD)
	aim_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(aim_marker)
	enemy_marker = _label("◇ STUKA", 16, Color("ff946a"))
	enemy_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(enemy_marker)
	var masthead := PanelContainer.new()
	masthead.position = Vector2(26, 18)
	masthead.add_theme_stylebox_override("panel", _style(Color(0.055, 0.09, 0.085, 0.76), 12))
	root.add_child(masthead)
	var header := VBoxContainer.new()
	masthead.add_child(header)
	header.add_child(_label("R A F   /   S O U T H E R N   E N G L A N D   /   1 9 4 0", 12, MUTED))
	header.add_child(_label("FIRST SORTIE", 34, INK))
	header.add_child(_label(aircraft.display_name.to_upper() + " · AIRFIELD ENCOUNTER", 13, GOLD))
	var status_panel := PanelContainer.new()
	status_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_panel.offset_left = -310
	status_panel.offset_right = -26
	status_panel.offset_top = 20
	status_panel.offset_bottom = 100
	status_panel.add_theme_stylebox_override("panel", _style(PANEL))
	root.add_child(status_panel)
	var top_right := VBoxContainer.new()
	status_panel.add_child(top_right)
	state_label = _label("ON THE RUNWAY", 17, GOLD)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(state_label)
	heading_label = _label("", 13, MUTED)
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_right.add_child(heading_label)
	hp_label = _label("HP: 100/100", 20, INK)
	top_right.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(230, 14)
	hp_bar.add_theme_stylebox_override("background", _style(Color("28332d"), 0))
	hp_fill = _style(Color("88b279"), 0)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	top_right.add_child(hp_bar)
	enemy_label = _label("STUKA · PATROL", 13, Color("ff946a"))
	top_right.add_child(enemy_label)
	var footer := MarginContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 38
	footer.offset_right = -38
	footer.offset_top = -128
	footer.offset_bottom = -30
	root.add_child(footer)
	var footer_box := VBoxContainer.new()
	footer_box.add_theme_constant_override("separation", 12)
	footer.add_child(footer_box)
	help_label = _label("HOLD W TO SET POWER  ·  AT 160–180 KM/H, GENTLY HOLD ↓ TO LIFT OFF", 13, GOLD)
	footer_box.add_child(help_label)
	var instruments := HBoxContainer.new()
	instruments.add_theme_constant_override("separation", 12)
	footer_box.add_child(instruments)
	speed_label = _instrument(instruments, "AIRSPEED", "0", "KM/H")
	altitude_label = _instrument(instruments, "ABOVE GROUND", "0", "METRES")
	throttle_label = _instrument(instruments, "ENGINE", "0", "% THROTTLE")
	gear_label = _instrument(instruments, "UNDERCARRIAGE", "DOWN", "THREE WHEELS")
	var strip := PanelContainer.new()
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	strip.offset_left = -402
	strip.offset_right = -38
	strip.offset_top = -355
	strip.offset_bottom = -155
	strip.add_theme_stylebox_override("panel", _style(PANEL))
	root.add_child(strip)
	var list := VBoxContainer.new()
	strip.add_child(list)
	list.add_child(_label("PILOT NOTES", 12, GOLD))
	list.add_child(_label("ARROWS  Pitch / bank     A / D  Rudder\nW / S  Throttle     G  Gear     SPACE  Brakes\nCTRL (hold)  %s\nH  DEBUG: −10 HP     R  Reset     ESC  Pause" % aircraft.gun_description, 13, INK))
	list.add_child(_label("APPROACH  %s km/h · %s\nFlare gently · aim for less than 3 m/s sink" % [aircraft.approach_speed_hint, "gear down" if aircraft.gear.retractable else "fixed gear"], 12, MUTED))
	notice_label = _label("", 16, GOLD)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	notice_label.offset_left = -310
	notice_label.offset_right = 310
	notice_label.offset_top = 135
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(notice_label)
	# Full-screen pause/crash overlay with keyboard and clickable actions.
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.offset_left = -290
	overlay.offset_right = 290
	overlay.offset_top = -330
	overlay.offset_bottom = 330
	overlay.add_theme_stylebox_override("panel", _style(Color(0.035, 0.06, 0.055, 0.97), 28))
	root.add_child(overlay)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 14)
	overlay.add_child(menu)
	menu.add_child(_label("F I R S T   S O R T I E", 13, GOLD))
	overlay_title = _label("PAUSED", 32, INK)
	menu.add_child(overlay_title)
	overlay_detail = _label("Take your time. The aircraft is waiting.", 14, MUTED)
	menu.add_child(overlay_detail)
	menu.add_child(HSeparator.new())
	menu.add_child(_label(CONTROLS % [aircraft.gun_description, "Toggle landing gear" if aircraft.gear.retractable else "Fixed landing gear (cannot retract)"], 17, INK))
	resume_button = Button.new()
	resume_button.text = "RESUME FLIGHT  /  ESC"
	resume_button.focus_mode = Control.FOCUS_NONE
	resume_button.pressed.connect(_resume)
	menu.add_child(resume_button)
	var reset_button := Button.new()
	reset_button.text = "RESET AT RUNWAY START  /  R"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(_reset)
	menu.add_child(reset_button)
	change_aircraft_button = Button.new()
	change_aircraft_button.text = "CHOOSE ANOTHER AIRCRAFT"
	change_aircraft_button.focus_mode = Control.FOCUS_NONE
	change_aircraft_button.pressed.connect(func(): change_aircraft_requested.emit())
	menu.add_child(change_aircraft_button)
	overlay.visible = false

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.03, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _style(color: Color, padding: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.7, 0.75, 0.6, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _instrument(parent: HBoxContainer, title: String, value: String, unit: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(PANEL, 12))
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(_label(title, 11, MUTED))
	var number := _label(value, 28, INK)
	left.add_child(number)
	var units := _label(unit, 11, MUTED)
	units.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(units)
	return number

func _input(event: InputEvent) -> void:
	# Handle flight shortcuts before GUI navigation can consume them. This
	# CanvasLayer processes while paused, so Escape and R always remain usable.
	if event.is_echo():
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
		get_viewport().gui_release_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset"):
		_reset()
		get_viewport().set_input_as_handled()

func _reset() -> void:
	get_tree().paused = false
	get_viewport().gui_release_focus()
	aircraft.request_reset()

func _resume() -> void:
	get_tree().paused = false
	get_viewport().gui_release_focus()

func _process(delta: float) -> void:
	if not is_instance_valid(aircraft):
		return
	if not get_tree().paused:
		elapsed += delta
	speed_label.text = "%03d" % roundi(aircraft.airspeed * 3.6)
	altitude_label.text = "%04d" % roundi(aircraft.altitude)
	throttle_label.text = "%d" % roundi(aircraft.pilot.throttle * 100.0)
	gear_label.text = "FIXED" if not aircraft.gear.retractable else ("DOWN" if aircraft.gear.extended else "UP")
	hp_label.text = "HP: %d/%d" % [floori(aircraft.health.hp), roundi(aircraft.health.max_hp)]
	hp_bar.value = aircraft.health.hp
	hp_fill.bg_color = Color("db744d") if aircraft.health.hp < 50.0 else Color("88b279")
	var camera := get_viewport().get_camera_3d()
	var aim := aircraft.global_position - aircraft.global_basis.z * maxf(aircraft.guns.convergence_distance, 250.0)
	aim_marker.visible = camera != null and not camera.is_position_behind(aim) and not aircraft.is_destroyed and not aircraft.is_crashed and not get_tree().paused
	if aim_marker.visible:
		aim_marker.position = camera.unproject_position(aim) - aim_marker.size * 0.5
	_update_enemy(camera)
	gear_label.modulate = GOLD if not aircraft.gear.extended else Color.WHITE
	var heading := fposmod(rad_to_deg(atan2(-aircraft.global_basis.z.x, aircraft.global_basis.z.z)), 360.0)
	heading_label.text = "HDG %03d°    ·    RUNWAY 18 / 36" % roundi(heading)
	if aircraft.is_destroyed:
		state_label.text = "DESTROYED · R TO RESET"
	elif aircraft.is_crashed:
		state_label.text = "AIRCRAFT LOST"
	elif aircraft.stalled:
		state_label.text = "STALL · LOWER THE NOSE"
	elif aircraft.gear.contact_count > 0:
		state_label.text = "BRAKING" if aircraft.pilot.brakes else "ON THE RUNWAY"
	else:
		state_label.text = "AIRBORNE"
	notice_label.text = ""
	if aircraft.stalled and not aircraft.is_crashed:
		notice_label.text = "STALL WARNING   /   NOSE DOWN · ADD POWER"
	elif not aircraft.gear.last_notice.is_empty():
		notice_label.text = aircraft.gear.last_notice
	elif is_instance_valid(enemy) and not aircraft.is_destroyed and not aircraft.is_crashed:
		if enemy.is_destroyed or enemy.is_crashed:
			notice_label.text = "ENEMY DOWN · R TO RESTART THE ENCOUNTER"
		elif enemy.pilot.fire:
			notice_label.text = "INCOMING FIRE · BANK TO EVADE"
	if aircraft.is_destroyed:
		help_label.text = "AIRCRAFT DESTROYED · ENGINE AND GUNS OFF · PRESS R TO RESET"
	elif aircraft.is_crashed:
		help_label.text = "AIRCRAFT LOST · PRESS R TO RESET"
	elif aircraft.gear.contact_count > 0:
		help_label.text = "HOLD W TO SET POWER  ·  AT %s KM/H, GENTLY HOLD ↓ TO LIFT OFF" % aircraft.takeoff_speed_hint
	else:
		help_label.text = "CTRL  FIRE · FOLLOW THE STUKA MARKER · KEEP AIRSPEED ABOVE %d KM/H" % aircraft.safe_speed_hint
	if not get_window().has_focus() and not aircraft.is_crashed and not aircraft.is_destroyed and not get_tree().paused:
		help_label.text = "CLICK INSIDE THE GAME VIEW TO FOCUS IT · THEN HOLD W TO SET POWER"
	overlay.visible = get_tree().paused or aircraft.is_crashed or aircraft.is_destroyed
	resume_button.disabled = aircraft.is_crashed or aircraft.is_destroyed
	if overlay.visible:
		overlay_title.text = "DESTROYED" if aircraft.is_destroyed else ("AIRCRAFT LOST" if aircraft.is_crashed else "PAUSED")
		overlay_detail.text = "0 HP · engine and guns disabled.\nPress R for a fresh aircraft." if aircraft.is_destroyed else (aircraft.crash_reason + "\nPress R for a fresh aircraft." if aircraft.is_crashed else "Take your time. The aircraft is waiting.")

func _update_enemy(camera: Camera3D) -> void:
	enemy_marker.visible = false
	if not is_instance_valid(enemy):
		return
	var delta: Vector3 = enemy.global_position - aircraft.global_position
	var bearing: float = fposmod(rad_to_deg(atan2(delta.x, -delta.z)), 360.0)
	enemy_label.text = "STUKA %d HP · %03d° · %d m\n%s" % [ceili(enemy.health.hp), roundi(bearing), roundi(delta.length()), enemy.ai.mode]
	if enemy.is_destroyed or enemy.is_crashed:
		enemy_label.text = "STUKA DOWN · R FOR A NEW ENCOUNTER"
		return
	if camera == null or get_tree().paused or aircraft.is_destroyed or aircraft.is_crashed:
		return
	# Keep a directional cue at screen edges even when the enemy is behind us.
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var local: Vector3 = camera.to_local(enemy.global_position)
	var projected: Vector2 = screen * 0.5
	if local.z > -0.1:
		projected = screen * 0.5 + Vector2(local.x, -local.y).normalized() * screen.length()
		if absf(local.x) < 0.001 and absf(local.y) < 0.001:
			projected = Vector2(screen.x - 60, screen.y * 0.5)
	else:
		projected = camera.unproject_position(enemy.global_position)
	var in_view: bool = local.z < -0.1 and Rect2(Vector2(60, 180), screen - Vector2(180, 340)).has_point(projected)
	enemy_marker.text = "◇ STUKA  %d m" % roundi(delta.length()) if in_view else "STUKA →" if projected.x > screen.x / 2 else "← STUKA"
	enemy_marker.position = Vector2(clampf(projected.x - 50, 20, screen.x - 170), clampf(projected.y - 20, 190, screen.y - 170))
	enemy_marker.visible = true
