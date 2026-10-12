extends Node
## Isolated browser audio test scene; excluded from the production export.
## Uses unchanged production MissionRadio, mixer and supplied voice recording.
var radio: MissionRadio
var bridge: Object
var buttons: Dictionary = {}

func _ready() -> void:
	GameAudioMixer.instance.set_menu_active(false)
	GameAudioMixer.instance.set_muted(false, false)
	GameAudioMixer.instance.set_volume("Aircraft", 0.6, false)
	GameAudioMixer.instance.set_volume("Guns", 0.5, false)
	bridge = Engine.get_singleton("JavaScriptBridge")
	var panel: VBoxContainer = VBoxContainer.new()
	panel.position = Vector2(30, 30)
	panel.add_theme_constant_override("separation", 12)
	add_child(panel)
	var title: Label = Label.new()
	title.text = "TEST FIXTURE · supplied commander recording / production radio component"
	panel.add_child(title)
	for entry in ["Transmit", "Retry", "Cancel", "Leave"]:
		var button: Button = Button.new()
		button.text = entry
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(200, 40)
		panel.add_child(button)
		buttons[entry.to_lower()] = button
	buttons.transmit.pressed.connect(func():
		if is_instance_valid(radio): radio.transmit_formation())
	buttons.retry.pressed.connect(_retry)
	buttons.cancel.pressed.connect(func():
		if is_instance_valid(radio): radio.stop())
	buttons.leave.pressed.connect(_leave)
	_retry()

func _retry() -> void:
	_leave()
	radio = MissionRadio.new()
	radio.voice_clip = preload("res://assets/audio/commander_formation_detected.ogg")
	add_child(radio)

func _leave() -> void:
	if is_instance_valid(radio):
		radio.stop()
		radio.queue_free()
		radio = null

func _process(_delta: float) -> void:
	if bridge == null:
		return
	var state: Dictionary = {"exists": is_instance_valid(radio), "duck_db": GameAudioMixer.instance.radio_duck_db,
		"engine_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Aircraft")),
		"guns_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Guns"))}
	for entry in buttons:
		var center: Vector2 = get_viewport().get_final_transform() * (buttons[entry].get_global_transform_with_canvas() * (buttons[entry].size * 0.5))
		state[entry] = [center.x, center.y]
	if is_instance_valid(radio):
		state.merge({"playing": radio.player.playing, "triggered": radio.triggered, "transmissions": radio.transmissions_played,
			"subtitle": radio.subtitle.visible, "text": radio.subtitle.text, "length": radio.voice_clip.get_length()})
	bridge.eval("window.radioTestState = " + JSON.stringify(state) + ";", true)
