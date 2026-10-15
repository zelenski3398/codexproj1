class_name MissionRadio
extends Node
## Non-spatial player radio. Voice filtering/static/clicks are baked into the
## supplied recording offline so desktop streaming and web samples sound alike.
## Missing speech stays silent: no generated speech, beep or noise replacement.
const FORMATION_LINE: String = "Italian formation detected, one o’clock — intercept!"
@export var subtitle_text: String = FORMATION_LINE
@export var voice_clip: AudioStream
@export_range(-24, 6, 0.5) var voice_volume_db: float = 0
@export_range(-12, 0, 0.5) var duck_db: float = -4
var triggered: bool = false
var transmissions_played: int = 0
var missing_asset: bool = false
var player: AudioStreamPlayer
var subtitle: Label

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "CommanderRadio"
	player.bus = "Master"
	player.max_polyphony = 1
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	player.finished.connect(stop)
	add_child(player)
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 24
	add_child(canvas)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	subtitle = Label.new()
	root.add_child(subtitle)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	# Leave the bottom instruments and right-hand pilot notes unobstructed.
	subtitle.offset_left = -310
	subtitle.offset_right = 310
	subtitle.offset_top = -210
	subtitle.offset_bottom = -125
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.text = "COMMANDER: “" + subtitle_text + "”"
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.04, 0.05, 0.88)
	background.set_content_margin_all(10)
	background.set_corner_radius_all(4)
	subtitle.add_theme_stylebox_override("normal", background)
	subtitle.hide()

func transmit_formation(_distance: float = 0) -> void:
	if triggered:
		return
	triggered = true # latch even when a recording/device is unavailable
	if voice_clip == null:
		missing_asset = true
		push_warning("Commander radio voice clip not supplied; speech playback is disabled.")
		return
	var mixer: GameAudioMixer = GameAudioMixer.instance
	if mixer == null or not mixer.playback_enabled or not mixer.begin_radio(self, duck_db):
		return
	# Imported loop settings must never repeat a commander transmission.
	player.stream = voice_clip.duplicate() as AudioStream
	if player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = false
	elif player.stream is AudioStreamWAV:
		(player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	player.volume_db = voice_volume_db
	player.play()
	transmissions_played += 1
	if not subtitle_text.is_empty():subtitle.show()

func stop() -> void:
	if is_instance_valid(player):
		player.stop()
		player.stream = null
	if is_instance_valid(subtitle):
		subtitle.hide()
	if is_instance_valid(GameAudioMixer.instance):
		GameAudioMixer.instance.end_radio(self)

func _exit_tree() -> void:
	stop()
