class_name GunnerDebugPanel
extends PanelContainer
## F3 companion panel; counters remain available after enemy wreck removal.
var session: Node3D
var counters: Label
var perception: Label
var skill_picker: OptionButton
var refresh_clock: float = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -440
	offset_right = -26
	offset_top = 180
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.05, 0.96)
	style.set_content_margin_all(10)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	add_child(column)
	var title: Label = Label.new()
	title.text = "GUNNERY · ACTUAL AIRCRAFT HITS / F3"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)
	counters = Label.new()
	counters.add_theme_font_size_override("font_size", 12)
	counters.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	counters.custom_minimum_size.x = 380
	column.add_child(counters)
	perception = Label.new()
	perception.add_theme_font_size_override("font_size", 12)
	column.add_child(perception)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	skill_picker = OptionButton.new()
	for value in ["Cadet", "Pilot", "Ace"]:
		skill_picker.add_item(value)
	skill_picker.focus_mode = Control.FOCUS_NONE
	row.add_child(skill_picker)
	skill_picker.item_selected.connect(_select_skill)
	var reset_button: Button = Button.new()
	reset_button.text = "RESET COUNTERS"
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(reset_statistics)
	row.add_child(reset_button)

func _select_skill(index: int) -> void:
	if is_instance_valid(session.enemy):
		session.enemy.rear_gunner.set_skill(index)

func reset_statistics() -> void:
	for statistics in [session.aircraft.guns.pool.statistics, session.enemy_front_statistics, session.enemy_rear_statistics]:
		if statistics != null:
			statistics.reset()

func _station(name: String, statistics: WeaponStatistics) -> String:
	if statistics == null:
		return name + ": no data"
	return "%s: %d shots · %d hits · %.1f%% · %.0f m\nParts: %s" % [name, statistics.shots, statistics.aircraft_hits, statistics.hit_percentage(), maxf(statistics.last_shot_distance, 0), statistics.components_text()]

func _process(delta: float) -> void:
	if not visible:
		return
	refresh_clock -= delta
	if refresh_clock > 0:
		return
	refresh_clock = 0.2
	counters.text = _station("PLAYER", session.aircraft.guns.pool.statistics) + "\n" + _station("STUKA FRONT", session.enemy_front_statistics) + "\n" + _station("REAR", session.enemy_rear_statistics)
	if is_instance_valid(session.enemy):
		var gunner: RearGunner = session.enemy.rear_gunner
		skill_picker.select(gunner.skill_level)
		skill_picker.disabled = false
		var statistics: WeaponStatistics = session.enemy_rear_statistics
		var state: String = "DESTROYED" if session.enemy.is_destroyed else gunner.status
		perception.text = "%s · %s · range %.0f m\nSight %.0f%% · motion %.1f°/s · aim σ %.2f°\nLast hit: %.0f m · travel %.2f s" % [gunner.skill_profile().skill_name, state, gunner.engagement_distance, gunner.visibility * 100, rad_to_deg(gunner.angular_motion), gunner.error_degrees, maxf(statistics.last_hit_distance, 0), statistics.last_flight_time]
	else:
		perception.text = "Enemy removed · retained counters · R for fresh session"
		skill_picker.disabled = true
