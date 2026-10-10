class_name MaltaChart
extends Control
## Selection and flight navigation use the exact same texture/coordinate transform.
signal field_selected(id: String)
var home: String = "ta_qali"
var selectable: bool = false
var player_position: Vector3 = Vector3.ZERO
var player_heading: Vector3 = Vector3.FORWARD
var show_player: bool = false
var contact_position: Vector3
var show_contact: bool = false
var buttons: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(650, 600)
	var texture: TextureRect = TextureRect.new()
	texture.texture = preload("res://assets/malta/navigation.png")
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.show_behind_parent = true
	add_child(texture)
	for record in MaltaGeography.data().airfields:
		var button: Button = Button.new()
		button.text = String(record.name)
		button.add_theme_font_size_override("font_size", 15)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = not selectable
		button.custom_minimum_size = Vector2(124, 30)
		button.pressed.connect(func(): field_selected.emit(String(record.id)))
		add_child(button)
		buttons[record.id] = button
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	for record in MaltaGeography.data().airfields:
		var point: Vector2 = MaltaGeography.chart_uv(MaltaGeography.vector(record.position)) * size
		buttons[record.id].position = point + Vector2(8, -15)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for record in MaltaGeography.data().airfields:
		var point: Vector2 = MaltaGeography.chart_uv(MaltaGeography.vector(record.position)) * size
		draw_circle(point, 7, Color("e4bf75") if record.id == home else Color("eee7ce"))
		if record.id == home:
			draw_arc(point, 12, 0, TAU, 32, Color("e4bf75"), 2)
	for landmark in MaltaGeography.data().landmarks:
		var point: Vector2 = MaltaGeography.chart_uv(MaltaGeography.vector(landmark.position)) * size
		draw_string(ThemeDB.fallback_font, point, landmark.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e7ddbc"))
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), "N ↑    MALTA / GOZO / COMINO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("eee7ce"))
	draw_string(ThemeDB.fallback_font, Vector2(20, size.y - 20), "Planning Authority DTM 2012 · © OpenStreetMap contributors", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("c6d1c8"))
	if show_player:
		var point: Vector2 = MaltaGeography.chart_uv(player_position) * size
		var direction: Vector2 = Vector2(player_heading.x, player_heading.z).normalized()
		if direction.length_squared() < 0.1:
			direction = Vector2.UP
		var side: Vector2 = Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([point + direction * 13, point - direction * 8 + side * 7, point - direction * 5, point - direction * 8 - side * 7]), Color("ffffff"))
	if show_contact:
		var point: Vector2 = MaltaGeography.chart_uv(contact_position) * size
		draw_circle(point, 5, Color("ed7759"))
