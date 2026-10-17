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
var current_entry: Dictionary = {}
var gap_remaining: float = 0
var start_delay: float = 0
var voice_started: bool = false
signal transmission_started(id: String)
signal transmission_ended(id: String)

func has_group(group: String) -> bool:
	if current_id != "" and current_entry.get("group", "") == group: return true
	return pending.any(func(entry): return entry.get("group", "") == group)

func enqueue_report(id: String, speaker: String, build: Callable, valid: Callable) -> void:
	if cancelled: return
	pending.append({"id":id, "speaker":speaker, "build":build, "valid":valid, "group":"wingman_status", "gap_after":definition.radio_reply_gap})

func cancel_speaker(speaker: String) -> void:
	pending = pending.filter(func(entry): return entry.get("speaker", "COMMANDER") != speaker)
	if current_entry.get("speaker", "COMMANDER") == speaker: _end_current()

func urgent_cue(id: String, text: String, voice: AudioStream = null) -> void:
	if cancelled or seen.has(id): return
	seen[id] = true
	# Cancel routine reports; retain commander briefings and other mission cues.
	pending = pending.filter(func(entry): return entry.get("group", "") != "wingman_status")
	if current_entry.get("group", "") == "wingman_status": _end_current()
	pending.push_front({"id":id, "text":text, "voice":voice, "summary":false})


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Master"
	player.max_polyphony = 1
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
	player.finished.connect(_voice_finished)
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

func _valid(entry: Dictionary) -> bool:
	var predicate: Callable = entry.get("valid", Callable())
	return not predicate.is_valid() or bool(predicate.call())

func _process(delta: float) -> void:
	if cancelled: return
	gap_remaining = maxf(gap_remaining - delta, 0)
	if current_id != "":
		if not _valid(current_entry):
			_end_current()
		else:
			start_delay = maxf(start_delay - delta, 0)
			if start_delay <= 0:
				if not voice_started: _start_voice()
				remaining -= delta
				if remaining <= 0: _end_current()
	if current_id != "" or pending.is_empty() or gap_remaining > 0: return
	var mixer := GameAudioMixer.instance
	if mixer != null and mixer.radio_owner != 0: return
	while not pending.is_empty():
		var entry: Dictionary = pending.pop_front()
		if not _valid(entry): continue
		var builder: Callable = entry.get("build", Callable())
		if builder.is_valid():
			var report: Dictionary = builder.call()
			if report.is_empty(): continue
			entry.merge(report, true)
		current_entry = entry
		current_id = entry.id
		var speaker: String = entry.get("speaker", "COMMANDER")
		caption.add_theme_color_override("font_color", Color({"FAITH":"f5d995", "HOPE":"9ce9d6", "CHARITY":"9dd7ff"}.get(speaker, "fff1cd")))
		caption.text = speaker + (" · recording summary: " if entry.get("summary", false) else ": ") + String(entry.text)
		var stream: AudioStream = entry.get("voice")
		var duration: float = float(entry.get("duration", 6))
		remaining = maxf(stream.get_length() + .5, duration) if stream != null else duration
		start_delay = float(entry.get("start_delay", 0))
		voice_started = false
		if stream == null: caption.text += " [subtitle only]"
		if start_delay <= 0: _start_voice()
		transmission_started.emit(current_id)
		break

func _start_voice() -> void:
	voice_started = true
	caption.show()
	var stream: AudioStream = current_entry.get("voice")
	var mixer := GameAudioMixer.instance
	if stream == null or mixer == null or not mixer.playback_enabled: return
	if not mixer.begin_radio(self, definition.radio_duck_db): return
	player.stream = stream.duplicate()
	if player.stream is AudioStreamOggVorbis: player.stream.loop = false
	player.volume_db = definition.wingman_radio_volume_db if current_entry.get("group", "") == "wingman_status" else definition.voice_volume_db
	player.play()
	played.append(current_id)

func _voice_finished() -> void:
	# A short identification recording may finish before its detailed subtitle.
	player.stop()
	player.stream = null
	if is_instance_valid(GameAudioMixer.instance): GameAudioMixer.instance.end_radio(self)
	if current_entry.get("group", "") != "wingman_status": _end_current()

func _end_current() -> void:
	var ended: String = current_id
	gap_remaining = float(current_entry.get("gap_after", 0))
	player.stop()
	player.stream = null
	caption.hide()
	current_id = ""
	current_entry = {}
	remaining = 0
	start_delay = 0
	voice_started = false
	if is_instance_valid(GameAudioMixer.instance): GameAudioMixer.instance.end_radio(self)
	if ended != "": transmission_ended.emit(ended)

func stop() -> void:
	cancelled = true
	pending.clear()
	_end_current()

func _exit_tree() -> void:
	stop()
