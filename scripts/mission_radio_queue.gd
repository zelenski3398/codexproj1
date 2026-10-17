class_name MissionRadioQueue
extends Node
## One channel; missing recordings are labelled subtitle-only, never fake speech.
var definition: HarbourDefinition
var player: AudioStreamPlayer
var caption: Label
var pending: Array[Dictionary] = []
var seen: Dictionary = {}
var current_id: String = ""
var remaining: float = 0
var cancelled: bool = false
var played: Array[String] = []

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.max_polyphony = 1
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.finished.connect(_end_current)
	var canvas := CanvasLayer.new()
	canvas.layer = 24
	add_child(canvas)
	caption = Label.new()
	caption.position = Vector2(270, 565)
	caption.size = Vector2(750, 100)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 19)
	caption.add_theme_color_override("font_color", Color("fff1cd"))
	caption.add_theme_color_override("font_shadow_color", Color.BLACK)
	caption.add_theme_constant_override("shadow_offset_x", 2)
	caption.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(caption)
	caption.hide()

func cue(id: String, text: String, voice: AudioStream = null, summary: bool = false, priority: bool = false) -> void:
	if cancelled or seen.has(id): return
	seen[id] = true
	if priority:
		pending.clear()
		_end_current()
	pending.append({"id":id, "text":text, "voice":voice, "summary":summary})

func _process(delta: float) -> void:
	if cancelled: return
	if current_id != "":
		remaining -= delta
		if remaining <= 0: _end_current()
	if current_id != "" or pending.is_empty(): return
	var mixer := GameAudioMixer.instance
	if mixer != null and mixer.radio_owner != 0: return
	var entry: Dictionary = pending.pop_front()
	current_id = entry.id
	caption.text = ("COMMANDER · recording summary: " if entry.summary else "COMMANDER: ") + entry.text
	var stream: AudioStream = entry.voice
	remaining = maxf(stream.get_length() + .5, 1) if stream != null else 6
	caption.show()
	if stream != null and mixer != null and mixer.playback_enabled and mixer.begin_radio(self, definition.radio_duck_db):
		player.stream = stream.duplicate()
		if player.stream is AudioStreamOggVorbis: player.stream.loop = false
		player.volume_db = definition.voice_volume_db
		player.play()
		played.append(current_id)
	elif stream == null:
		caption.text += " [subtitle only]"

func _end_current() -> void:
	player.stop()
	player.stream = null
	caption.hide()
	current_id = ""
	remaining = 0
	if is_instance_valid(GameAudioMixer.instance): GameAudioMixer.instance.end_radio(self)

func stop() -> void:
	cancelled = true
	pending.clear()
	_end_current()

func _exit_tree() -> void:
	stop()
