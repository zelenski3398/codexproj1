class_name MissionsMenu
extends CanvasLayer
signal launch_requested(kind: String)
signal harbour_requested
signal aa_requested
signal back_requested
var mission_picker: OptionButton
var title: Label
var briefing: Label
var guide: Label
var mission_note: Label
var mission_chart: MaltaChart
var aircraft_picker: OptionButton
var launch_button: Button
var back_button: Button
const DEFINITION: InterceptionDefinition = preload("res://mission_definitions/valletta.tres")

func _ready() -> void:
	layer = 25
	var root: ColorRect = ColorRect.new()
	root.color = Color("111f25")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	root.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.add_theme_constant_override("separation", 18)
	row.add_child(column)
	_label(column, "WINGS OVER MALTA · MISSIONS", 25)
	mission_picker=OptionButton.new()
	mission_picker.add_item("Defend Valletta — Ta’ Qali Interception")
	mission_picker.add_item("Under Dive-Bomber Attack — Ħal Luqa")
	mission_picker.add_item("Faith, Hope and Charity — Harbour Interception")
	mission_picker.custom_minimum_size.y=44
	column.add_child(mission_picker)
	mission_picker.item_selected.connect(_choose_mission)
	title = _label(column, DEFINITION.title, 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing = _label(column, DEFINITION.briefing, 20)
	briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	briefing.custom_minimum_size = Vector2(480, 200)
	guide = _label(column, "CONTINUOUS MALTA · RAF TA’ QALI\nStart on foot · E board · I start engine\nW power · arrows fly · two nearby gold checkpoints", 17)
	aircraft_picker = OptionButton.new()
	aircraft_picker.add_item("Spitfire Mk I · faster interception")
	aircraft_picker.add_item("Sea Gladiator · slower, more challenging")
	aircraft_picker.custom_minimum_size.y = 44
	column.add_child(aircraft_picker)
	launch_button = Button.new()
	launch_button.text = "DEPART FROM TA’ QALI"
	launch_button.custom_minimum_size.y = 56
	launch_button.pressed.connect(_launch)
	column.add_child(launch_button)
	mission_note = _label(column, "Small fictional interception · one bomber and one escort", 14)
	back_button = Button.new()
	back_button.text = "BACK TO MAIN MENU"
	back_button.pressed.connect(func(): back_requested.emit())
	column.add_child(back_button)
	var chart: MaltaChart = MaltaChart.new()
	chart.custom_minimum_size = Vector2(650, 600)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(chart)
	mission_chart=chart

func _label(parent: Node, content: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("eee7ce"))
	parent.add_child(label)
	return label

func _launch() -> void:
	if launch_button.disabled:
		return
	launch_button.disabled = true
	if mission_picker.selected==2:harbour_requested.emit()
	elif mission_picker.selected==1:aa_requested.emit()
	else:launch_requested.emit("sea_gladiator" if aircraft_picker.selected == 1 else "spitfire")

func _input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() in [mission_picker,aircraft_picker]:return
	if event is InputEventKey and event.pressed and not event.is_echo() and not aircraft_picker.get_popup().visible and not mission_picker.get_popup().visible:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_launch()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			back_requested.emit()
			get_viewport().set_input_as_handled()

func _choose_mission(index: int) -> void:
	if index == 2:
		var harbour: HarbourDefinition = preload("res://mission_definitions/harbour.tres")
		title.text = harbour.title
		briefing.text = harbour.briefing
		guide.text = "RAF ĦAL FAR · FAITH / HOPE / CHARITY\nE board · I engine · W power · arrows fly · F guns\nFriendly wingmen follow after takeoff.\n%s: request wingman status. Three waves." % WingmanRadio.binding_text()
		mission_note.text = "Fictional defence inspired by Malta, 1940 · SM.79 / CR.42"
		mission_chart.home = "hal_far"
		aircraft_picker.set_item_text(1, "Sea Gladiator · Faith (assigned)")
		aircraft_picker.select(1)
		aircraft_picker.disabled = true
		launch_button.text = "DEPART FROM ĦAL FAR · FLY FAITH"
		return
	aircraft_picker.set_item_text(1, "Sea Gladiator · slower, more challenging")
	var aa: bool=index==1
	title.text="Under Dive-Bomber Attack" if aa else DEFINITION.title
	briefing.text=DiveDefenceMission.BRIEFING if aa else DEFINITION.briefing
	guide.text="RAF ĦAL LUQA · TWO MANUAL AA GUNS\nE mount / dismount · arrows aim · Ctrl fire\nW/S airburst distance · six waves, ten Stukas" if aa else "CONTINUOUS MALTA · RAF TA’ QALI\nStart on foot · E board · I start engine\nW power · arrows fly · two nearby gold checkpoints"
	mission_note.text="Six waves · ten Stukas · final ace · manual AA only" if aa else "Small fictional interception · one bomber and one escort"
	mission_chart.home="luqa" if aa else "ta_qali"
	aircraft_picker.disabled=aa
	launch_button.text="DEFEND ĦAL LUQA" if aa else "DEPART FROM TA’ QALI"
