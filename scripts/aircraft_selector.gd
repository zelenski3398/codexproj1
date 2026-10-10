class_name AircraftSelector
extends Node3D
## Startup selection owns only a display model; no aircraft physics or combat
## exist until Fly is chosen. Keyboard navigation works in embedded game views.
signal chosen(kind: String)
const GOLD: Color = Color("e4bf75")
const INK: Color = Color("e9e8d7")
var selected: String = "spitfire"
var active: bool = true
var preview: SpitfireModel
var preview_camera: Camera3D
var preview_gear: LandingGear
var buttons: Array[Button] = []
var details: Label
var preview_title: Label
var fly_button: Button

func _ready() -> void:
	preview_gear = LandingGear.new()
	add_child(preview_gear)
	preview_camera = Camera3D.new()
	preview_camera.fov = 48
	preview_camera.far = 14000
	add_child(preview_camera)
	preview_camera.global_position = Vector3(10, 7.2, 638)
	preview_camera.look_at(Vector3(0, 1.3, 650))
	preview_camera.h_offset = -4.1
	preview_camera.make_current()
	_build_ui()
	select("spitfire")

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var title: PanelContainer = PanelContainer.new()
	title.position = Vector2(38, 24)
	title.add_theme_stylebox_override("panel", _style(Color(0.05, 0.08, 0.075, 0.92)))
	root.add_child(title)
	var heading: VBoxContainer = VBoxContainer.new()
	title.add_child(heading)
	heading.add_child(_label("FIRST SORTIE", 32, INK))
	heading.add_child(_label("CHOOSE YOUR AIRCRAFT", 15, GOLD))
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(38, 145)
	panel.custom_minimum_size.x = 470
	panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.08, 0.075, 0.95)))
	root.add_child(panel)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	panel.add_child(stack)
	stack.add_child(_label("SELECT A FIGHTER", 14, GOLD))
	var group: ButtonGroup = ButtonGroup.new()
	var kinds: Array[String] = ["spitfire", "sea_gladiator"]
	var names: Array[String] = ["SPITFIRE Mk I\nFaster monoplane · eight wing guns", "GLOSTER SEA GLADIATOR\nSlower biplane · four machine guns"]
	for i in range(2):
		var button: Button = Button.new()
		button.text = names[i]
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(426, 92)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_stylebox_override("normal", _style(Color("25332d")))
		button.add_theme_stylebox_override("pressed", _style(Color("46533e")))
		button.add_theme_stylebox_override("hover", _style(Color("34453b")))
		button.pressed.connect(select.bind(kinds[i]))
		stack.add_child(button)
		buttons.append(button)
	details = _label("", 17, INK)
	details.custom_minimum_size = Vector2(420, 112)
	stack.add_child(details)
	fly_button = Button.new()
	fly_button.custom_minimum_size.y = 54
	fly_button.add_theme_font_size_override("font_size", 20)
	fly_button.add_theme_color_override("font_color", Color("18231d"))
	fly_button.add_theme_stylebox_override("normal", _style(GOLD))
	fly_button.add_theme_stylebox_override("hover", _style(Color("f1d499")))
	fly_button.pressed.connect(_fly)
	stack.add_child(fly_button)
	stack.add_child(_label("Click an aircraft, then Fly.\n← / → or 1 / 2 select · ENTER starts", 14, Color("abb8ad")))
	preview_title = _label("", 22, INK)
	preview_title.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	preview_title.offset_left = -530
	preview_title.offset_right = -38
	preview_title.offset_top = -155
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(preview_title)
	var fire_key: String = "F" if OS.has_feature("web") else "CTRL"
	var guide: Label = _label("ARROWS  Pitch / bank    W / S  Throttle    A / D  Rudder    %s  Fire\nSPACE  Brakes    G  Gear (Spitfire only)    R  Reset    ESC  Pause" % fire_key, 15, INK)
	guide.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	guide.offset_left = 38
	guide.offset_right = -38
	guide.offset_top = -84
	guide.offset_bottom = -25
	root.add_child(guide)

func _label(value: String, size: int, color: Color) -> Label:
	var result: Label = Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", Color("132019"))
	result.add_theme_constant_override("shadow_offset_x", 1)
	result.add_theme_constant_override("shadow_offset_y", 1)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _style(color: Color) -> StyleBoxFlat:
	var result: StyleBoxFlat = StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = Color(0.85, 0.79, 0.6, 0.35)
	result.set_border_width_all(1)
	result.set_corner_radius_all(5)
	result.content_margin_left = 20
	result.content_margin_right = 20
	result.content_margin_top = 14
	result.content_margin_bottom = 14
	return result

func select(kind: String) -> void:
	if not active or kind not in ["spitfire", "sea_gladiator"]:
		return
	if selected == kind and is_instance_valid(preview):
		return
	selected = kind
	buttons[0].set_pressed_no_signal(kind == "spitfire")
	buttons[1].set_pressed_no_signal(kind == "sea_gladiator")
	if is_instance_valid(preview):
		remove_child(preview)
		preview.queue_free()
	preview = SeaGladiatorModel.new() if kind == "sea_gladiator" else SpitfireModel.new()
	add_child(preview)
	preview.global_transform = Transform3D(Basis(Vector3.RIGHT, 0.117), Vector3(0, 1.18, 650))
	preview.animate(0, 0, preview_gear, false)
	if kind == "spitfire":
		details.text = "Higher speed and stronger climb\nRetractable landing gear\nEight wing guns · 100 HP\nTakeoff: 160–180 km/h"
		fly_button.text = "FLY THE SPITFIRE"
		preview_title.text = "SPITFIRE Mk I\nRAF fighter · 1940"
	else:
		details.text = "Lower speed and reduced climb\nFixed landing gear · lower stall speed\nFour machine guns · 100 HP\nTakeoff: 115–135 km/h"
		fly_button.text = "FLY THE SEA GLADIATOR"
		preview_title.text = "GLOSTER SEA GLADIATOR\nFAITH · late-1930s naval biplane"

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.is_echo():
		return
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	match code:
		KEY_LEFT, KEY_UP, KEY_1:
			select("spitfire")
		KEY_RIGHT, KEY_DOWN, KEY_2:
			select("sea_gladiator")
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_fly()
	# Do not forward menu navigation to flight controls in the starting frame.
	get_viewport().set_input_as_handled()

func _fly() -> void:
	if not active:
		return
	active = false
	get_viewport().gui_release_focus()
	chosen.emit(selected)

func _process(delta: float) -> void:
	if is_instance_valid(preview):
		preview.animate(delta, 0.05, preview_gear, false)
