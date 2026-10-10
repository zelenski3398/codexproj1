class_name MaltaDepartureMenu
extends CanvasLayer
signal departed(field_id: String, kind: String)
signal back_requested
var selected_field: String = "ta_qali"
var selected_kind: String = "spitfire"
var chart: MaltaChart
var info: Label
var depart_button: Button
var fighter_picker: OptionButton
var field_picker: OptionButton
var active: bool = true

func _ready() -> void:
	layer = 25
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("101e25")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var root: HBoxContainer = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 32
	root.offset_right = -32
	root.offset_top = 28
	root.offset_bottom = -28
	root.add_theme_constant_override("separation", 30)
	add_child(root)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size.x = 405
	left.add_theme_constant_override("separation", 20)
	root.add_child(left)
	left.add_child(_label("WINGS OVER MALTA", 30))
	left.add_child(_label("ONE CONTINUOUS WORLD\nChoose your departure airfield", 19))
	field_picker = OptionButton.new()
	for record in MaltaGeography.data().airfields:
		field_picker.add_item(record.name)
	field_picker.item_selected.connect(func(index: int): select_field(MaltaGeography.data().airfields[index].id))
	left.add_child(field_picker)
	info = _label("", 17)
	info.custom_minimum_size = Vector2(405, 150)
	left.add_child(info)
	fighter_picker = OptionButton.new()
	fighter_picker.item_selected.connect(_choose_kind)
	left.add_child(fighter_picker)
	depart_button = Button.new()
	depart_button.text = "DEPART · SPAWN BESIDE AIRCRAFT"
	depart_button.custom_minimum_size.y = 58
	depart_button.pressed.connect(depart)
	left.add_child(depart_button)
	left.add_child(_label("E  Board / leave a stopped aircraft\nI  Start / stop engine\nWASD  Walk · Arrows  Turn on foot\nM  Navigation chart\nR  Full mission restart\n\nAll three airfields stay in the same world.\nDamage and fuel persist when switching.\n\nApproximate historical airfield positions;\nprototype runway layouts.", 16))
	var back: Button = Button.new()
	back.text = "BACK TO COUNTRYSIDE / AIRCRAFT"
	back.pressed.connect(func(): back_requested.emit())
	left.add_child(back)
	chart = MaltaChart.new()
	chart.selectable = true
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(chart)
	chart.field_selected.connect(select_field)
	select_field(selected_field)

func _label(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e9e8d7"))
	return label

func select_field(id: String) -> void:
	var record: Dictionary = MaltaGeography.field(id)
	if record.is_empty():
		return
	selected_field = id
	chart.home = id
	for index in range(MaltaGeography.data().airfields.size()):
		if MaltaGeography.data().airfields[index].id == id:
			field_picker.select(index)
	fighter_picker.clear()
	for kind in record.stationed_aircraft:
		fighter_picker.add_item("Spitfire Mk I" if kind == "spitfire" else "Gloster Sea Gladiator")
	var selected_index: int = record.stationed_aircraft.find(selected_kind)
	fighter_picker.select(maxi(selected_index, 0))
	_choose_kind(fighter_picker.selected)
	info.text = "%s\nDeparture strip: %d m\nAvailable: %s\nSpawn on foot at the dispersal area.\nFly freely to any other airfield." % [record.name, roundi(float(record.length)), " / ".join(record.stationed_aircraft).replace("spitfire", "Spitfire").replace("sea_gladiator", "Sea Gladiator")]

func _choose_kind(index: int) -> void:
	selected_kind = MaltaGeography.field(selected_field).stationed_aircraft[index]

func depart() -> void:
	if not active:
		return
	active = false
	get_viewport().gui_release_focus()
	departed.emit(selected_field, selected_kind)

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.is_echo():
		return
	var code: int = event.keycode if event.keycode != 0 else event.physical_keycode
	match code:
		KEY_1: select_field("ta_qali")
		KEY_2: select_field("luqa")
		KEY_3: select_field("hal_far")
		KEY_ENTER, KEY_KP_ENTER: depart()
		KEY_ESCAPE: back_requested.emit()
		_: return
	get_viewport().set_input_as_handled()
