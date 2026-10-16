class_name AircraftDamageHUD
extends PanelContainer
## Always-visible, read-only component status. Ratios come from the active
## airframe's existing damage profile, independently of whole-aircraft HP.
const HEALTHY := Color("64ce82")
const WARNING := Color("e4b957")
const CRITICAL := Color("e65c50")
const LABELS := {&"fuselage":"FUSELAGE", &"left_wing":"LEFT WING", &"right_wing":"RIGHT WING", &"engine":"ENGINE", &"cockpit":"COCKPIT", &"rudder":"RUDDER", &"elevator":"ELEVATOR", &"fuel_tank":"FUEL TANK"}
var labels: Dictionary = {}
var bars: Dictionary = {}
var fills: Dictionary = {}
var ratios: Dictionary = {}
var diagram: Diagram

static func health_color(ratio: float) -> Color:
	var value := clampf(ratio, 0, 1)
	return CRITICAL.lerp(WARNING, value * 2) if value < 0.5 else WARNING.lerp(HEALTHY, (value - 0.5) * 2)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055, 0.09, 0.085, 0.93)
	panel.set_corner_radius_all(4)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 7
	panel.content_margin_bottom = 7
	add_theme_stylebox_override("panel", panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	diagram = Diagram.new()
	diagram.custom_minimum_size = Vector2(190, 90)
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(diagram)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	row.add_child(grid)
	for id in AircraftDamage.IDS:
		var cell := VBoxContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 3)
		grid.add_child(cell)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 12)
		cell.add_child(label)
		labels[id] = label
		var bar := ProgressBar.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.show_percentage = false
		bar.custom_minimum_size.y = 6
		bar.max_value = 1
		var background := StyleBoxFlat.new()
		background.bg_color = Color("293c35")
		bar.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		bar.add_theme_stylebox_override("fill", fill)
		cell.add_child(bar)
		bars[id] = bar
		fills[id] = fill

func refresh(damage: AircraftDamage) -> void:
	if not is_instance_valid(damage):
		return
	var changed := false
	for id in AircraftDamage.IDS:
		var ratio := damage.integrity_ratio(id)
		if ratios.has(id) and is_equal_approx(ratios[id], ratio):
			continue
		ratios[id] = ratio
		var color := health_color(ratio)
		labels[id].text = "%s  %d%%" % [LABELS[id], ceili(ratio * 100)]
		labels[id].add_theme_color_override("font_color", color)
		bars[id].value = ratio
		fills[id].bg_color = color
		changed = true
	if changed:
		diagram.ratios = ratios
		diagram.queue_redraw()

class Diagram extends Control:
	var ratios: Dictionary = {}
	# Top-down silhouette, nose up. Separate patches avoid a single hull colour
	# concealing a failed engine, control surface or one damaged wing.
	const SHAPES := {
		&"engine": [[Vector2(86, 16), Vector2(95, 5), Vector2(104, 16), Vector2(104, 31), Vector2(86, 31)]],
		&"cockpit": [[Vector2(86, 33), Vector2(104, 33), Vector2(104, 44), Vector2(86, 44)]],
		&"fuselage": [[Vector2(82, 32), Vector2(84, 32), Vector2(84, 58), Vector2(92, 74), Vector2(88, 74), Vector2(81, 57)], [Vector2(106, 32), Vector2(108, 32), Vector2(109, 57), Vector2(102, 74), Vector2(98, 74), Vector2(106, 58)]],
		&"fuel_tank": [[Vector2(86, 46), Vector2(104, 46), Vector2(103, 57), Vector2(95, 71), Vector2(87, 57)]],
		&"left_wing": [[Vector2(79, 34), Vector2(32, 38), Vector2(12, 46), Vector2(8, 51), Vector2(17, 56), Vector2(49, 55), Vector2(79, 48)]],
		&"right_wing": [[Vector2(111, 34), Vector2(158, 38), Vector2(178, 46), Vector2(182, 51), Vector2(173, 56), Vector2(141, 55), Vector2(111, 48)]],
		&"elevator": [[Vector2(88, 73), Vector2(62, 77), Vector2(60, 83), Vector2(89, 82)], [Vector2(102, 73), Vector2(128, 77), Vector2(130, 83), Vector2(101, 82)]],
		&"rudder": [[Vector2(93, 73), Vector2(97, 73), Vector2(99, 86), Vector2(95, 90), Vector2(91, 86)]]
	}
	func _draw() -> void:
		for id in SHAPES:
			var color := AircraftDamageHUD.health_color(float(ratios.get(id, 1)))
			for shape in SHAPES[id]:
				var points := PackedVector2Array(shape)
				draw_colored_polygon(points, color)
				points.append(points[0])
				draw_polyline(points, Color("b6c7b5"), 1, true)
		draw_string(ThemeDB.fallback_font, Vector2(4, 11), "AIRFRAME", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b6c7b5"))
