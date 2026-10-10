class_name GameAudioMixer
extends Node
## Session-independent mixer: one menu theme, three buses and saved volumes.
## Aircraft sounds are owned by their aircraft/weapons, never by menu previews.
const SETTINGS_PATH: String = "user://audio.cfg"
const THEME: String = "res://assets/audio/main_menu.ogg"
const SPITFIRE_IDLE: String = "res://assets/audio/spitfire_engine_idle_loop.ogg"
const SPITFIRE_FLIGHT: String = "res://assets/audio/spitfire_engine_flight_loop.ogg"
const SPITFIRE_GUNS: String = "res://assets/audio/spitfire_303_guns_burst.ogg"
const GLADIATOR_IDLE: String = "res://assets/audio/gladiator_engine_idle_loop.ogg"
const GLADIATOR_FLIGHT: String = "res://assets/audio/gladiator_engine_flight_loop.ogg"
const GLADIATOR_GUNS: String = "res://assets/audio/gladiator_303_guns_burst.ogg"
@export var menu_fade_seconds: float = 0.7
static var instance: GameAudioMixer
var volumes: Dictionary = {"Master": 0.8, "Music": 0.65, "Aircraft": 0.75, "Guns": 0.75}
var muted: bool = false
var menu_active: bool = false
var music_gain: float = 0.0
## Headless regression runs have no audio device; opt in for lifecycle checks.
var playback_enabled: bool = DisplayServer.get_name() != "headless"
var music: AudioStreamPlayer
var audio_button: Button
var panel: PanelContainer
var mute_button: CheckButton
var sliders: Dictionary = {}

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	if instance == self:
		instance = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A saved layout initializes all buses together. Runtime bus insertion in
	# the Godot 4.6.3 web sample mixer can reorder Master and create a send loop.
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.set_bus_layout(load("res://default_bus_layout.tres") as AudioBusLayout)
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		for bus in volumes:
			volumes[bus] = clampf(float(settings.get_value("volume", bus, volumes[bus])), 0, 1)
		muted = bool(settings.get_value("volume", "muted", false))
	for bus in volumes:
		_apply_volume(bus)
	AudioServer.set_bus_mute(0, muted)
	music = AudioStreamPlayer.new()
	music.name = "MenuTheme"
	music.stream = loop_stream(load(THEME) as AudioStreamOggVorbis)
	music.bus = "Music"
	music.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	music.volume_db = -80
	add_child(music)
	_build_controls()

func loop_stream(source: AudioStreamOggVorbis) -> AudioStreamOggVorbis:
	var stream: AudioStreamOggVorbis = source.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	return stream

func is_radial(aircraft: FlightAircraft) -> bool:
	return aircraft is SeaGladiator

func engine_stream(aircraft: FlightAircraft, flight: bool) -> AudioStreamOggVorbis:
	if is_radial(aircraft):
		return load(GLADIATOR_FLIGHT if flight else GLADIATOR_IDLE) as AudioStreamOggVorbis
	# No Stuka-specific sample supplied. Its inline engine uses the Spitfire
	# recording as an explicitly documented placeholder, not a Jumo recording.
	return load(SPITFIRE_FLIGHT if flight else SPITFIRE_IDLE) as AudioStreamOggVorbis

func gun_stream(aircraft: FlightAircraft) -> AudioStreamOggVorbis:
	return load(GLADIATOR_GUNS if is_radial(aircraft) else SPITFIRE_GUNS) as AudioStreamOggVorbis

func set_menu_active(active: bool) -> void:
	menu_active = active
	panel.visible = false
	if active and playback_enabled and not music.playing:
		music.play()

func set_volume(bus: String, value: float, persist: bool = true) -> void:
	if not volumes.has(bus):
		return
	volumes[bus] = clampf(value, 0, 1)
	_apply_volume(bus)
	if sliders.has(bus):
		sliders[bus].set_value_no_signal(volumes[bus])
	if persist:
		_save_settings()

func _apply_volume(bus: String) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(float(volumes[bus]), 0.0001)))

func set_muted(value: bool, persist: bool = true) -> void:
	muted = value
	AudioServer.set_bus_mute(0, muted)
	if is_instance_valid(mute_button):
		mute_button.set_pressed_no_signal(muted)
	if persist:
		_save_settings()

func _save_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	for bus in volumes:
		settings.set_value("volume", bus, volumes[bus])
	settings.set_value("volume", "muted", muted)
	settings.save(SETTINGS_PATH)

func _process(delta: float) -> void:
	# Gameplay audio is silent during pause; the saved volume/mute is retained.
	for bus in ["Aircraft", "Guns"]:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), get_tree().paused)
	music_gain = move_toward(music_gain, 1.0 if menu_active else 0.0, delta / maxf(menu_fade_seconds, 0.01))
	music.volume_db = linear_to_db(maxf(music_gain, 0.0001))
	if not menu_active and music_gain <= 0 and music.playing:
		music.stop()

func _build_controls() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 80
	add_child(canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	audio_button = Button.new()
	audio_button.text = "AUDIO"
	audio_button.focus_mode = Control.FOCUS_NONE
	root.add_child(audio_button)
	audio_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	audio_button.offset_left = -122
	audio_button.offset_right = -26
	audio_button.offset_top = 200
	audio_button.offset_bottom = 236
	panel = PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -310
	panel.offset_right = -26
	panel.offset_top = 245
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.1, 0.08, 0.96)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var stack: VBoxContainer = VBoxContainer.new()
	panel.add_child(stack)
	for bus in volumes:
		var label: Label = Label.new()
		label.text = bus + " volume"
		stack.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.max_value = 1
		slider.step = 0.01
		slider.value = volumes[bus]
		slider.focus_mode = Control.FOCUS_NONE
		slider.custom_minimum_size = Vector2(250, 22)
		slider.value_changed.connect(func(value: float): set_volume(bus, value))
		stack.add_child(slider)
		sliders[bus] = slider
	mute_button = CheckButton.new()
	mute_button.text = "Mute all audio"
	mute_button.focus_mode = Control.FOCUS_NONE
	mute_button.button_pressed = muted
	mute_button.toggled.connect(set_muted)
	stack.add_child(mute_button)
	panel.visible = false
	audio_button.pressed.connect(func(): panel.visible = not panel.visible)
