class_name MaltaDepartureMenu
extends CanvasLayer
signal departed(field_id: String, kind: String, mode: String)
signal back_requested
var selected_mode: String = "encounter"
var mode_picker: OptionButton
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
	left.add_theme_constant_override("separation", 14)
	root.add_child(left)
	left.add_child(_label("WINGS OVER MALTA", 30))
	left.add_child(_label("ONE CONTINUOUS WORLD\nChoose your departure / ground spawn", 19))
	field_picker = OptionButton.new()
	for record in StElmoLocations.options():
		field_picker.add_item(record.name)
	field_picker.item_selected.connect(func(index: int): select_field(StElmoLocations.options()[index].id))
	left.add_child(field_picker)
	info = _label("", 17)
	info.custom_minimum_size = Vector2(405, 120)
	left.add_child(info)
	fighter_picker = OptionButton.new()
	fighter_picker.item_selected.connect(_choose_kind)
	left.add_child(fighter_picker)
	mode_picker = OptionButton.new()
	mode_picker.add_item("FREE ROAM · C spawns a random enemy")
	mode_picker.add_item("SURVIVAL · Five stages, persistent damage")
	mode_picker.select(1 if selected_mode == "survival" else 0)
	mode_picker.item_selected.connect(func(index: int): selected_mode = "survival" if index == 1 else "encounter")
	left.add_child(mode_picker)
	depart_button = Button.new()
	depart_button.text = "DEPART · SPAWN BESIDE AIRCRAFT"
	depart_button.custom_minimum_size.y = 58
	depart_button.pressed.connect(depart)
	left.add_child(depart_button)
	left.add_child(_label("E  Board / leave · I  Engine\nWASD  Walk · Arrows  Turn on foot\nM  Navigation · C  Spawn / confirm fight\nR  Full mission restart\n\nAll airfields share one persistent world.\nAircraft damage and fuel persist.\n\nApproximate historical airfield positions;\nprototype runway layouts.", 16))
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
	if StElmoLocations.is_fort(id):
		selected_field=id
		chart.home="st_elmo"
		for i in range(StElmoLocations.options().size()):
			if StElmoLocations.options()[i].id==id:field_picker.select(i)
		fighter_picker.clear()
		fighter_picker.add_item("Spitfire / Gladiator remain parked at the airfields")
		fighter_picker.disabled=true
		info.text="Fort St Elmo · Three manual Bofors guns\nSpawn on foot, outside the gun positions.\nM Map → travel between St Elmo and airfields.\nE Mount · B Individual / Battery · LMB Fire"
		depart_button.text="DEPART · SPAWN AT ST ELMO"
		return
	fighter_picker.disabled=false
	depart_button.text="DEPART · SPAWN BESIDE AIRCRAFT"
	var record: Dictionary = MaltaGeography.field(id)
	if record.is_empty():
		return
	selected_field = id
	chart.home = id
	for index in range(MaltaGeography.data().airfields.size()):
		if MaltaGeography.data().airfields[index].id == id:
			field_picker.select(index)
	fighter_picker.clear()
	for kind in AlliedAircraft.roster(record):
		fighter_picker.add_item(AlliedAircraft.title(kind))
	var selected_index: int = AlliedAircraft.roster(record).find(selected_kind)
	fighter_picker.select(maxi(selected_index, 0))
	_choose_kind(fighter_picker.selected)
	info.text = "%s\nDeparture strip: %d m\nAvailable: %s\nSpawn on foot at the dispersal area.\nFly freely to any other airfield." % [record.name, roundi(float(record.length)), " / ".join(AlliedAircraft.roster(record).map(AlliedAircraft.title))]

func _choose_kind(index: int) -> void:
	if StElmoLocations.is_fort(selected_field):return
	selected_kind = AlliedAircraft.roster(MaltaGeography.field(selected_field))[index]

func depart() -> void:
	if not active:
		return
	active = false
	get_viewport().gui_release_focus()
	departed.emit(selected_field, selected_kind, selected_mode)

func _input(event: InputEvent) -> void:
	if not active or not event is InputEventKey or not event.pressed or event.is_echo():
		return
	# Let dropdowns consume Enter/arrows without accidentally departing.
	if mode_picker.get_popup().visible or fighter_picker.get_popup().visible or field_picker.get_popup().visible:
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
