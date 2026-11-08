class_name GameIntro
extends CanvasLayer
## Startup-only presentation. The existing selector stays alive underneath.
signal completed
@export var opening_seconds: float = 1.2
@export var poster_fade_seconds: float = 2.8
@export var exit_fade_seconds: float = 1.6
@export var menu_fade_seconds: float = 1.6
@export var decode_video: bool = true
@export var poster_music_volume_db: float = -3.0
const POSTER = preload("res://assets/intro/malta_poster.png")
const POSTER_AUDIO = preload("res://assets/intro/wings_over_malta_cinematic_march.ogg")
const MOVIE = preload("res://assets/intro/malta_poster.ogv")
enum Phase { OPENING, POSTER, LEAVING, MENU, DONE }
var phase: Phase = Phase.OPENING
var elapsed: float = 0.0
var surface: Control
var artwork: Control
var still: TextureRect
var poster_audio: AudioStreamPlayer
var music_starts: int = 0
var video_last_position: float = -1
var video_stalled: float = 0
var video_restarts: int = 0
var movie: VideoStreamPlayer
var destination: String = "menu"
var tutorial_button: Button
var play_button: Button
var opening: Label
var blackout: ColorRect
var poster_rect: Rect2
var _audio_button_visible: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameAudioMixer.instance.set_menu_active(false)
	_audio_button_visible = GameAudioMixer.instance.audio_button.visible
	GameAudioMixer.instance.audio_button.hide()
	surface = Control.new()
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = Color("101b21")
	surface.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork = Control.new()
	surface.add_child(artwork)
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	still = TextureRect.new()
	still.texture = POSTER
	still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.add_child(still)
	still.mouse_filter = Control.MOUSE_FILTER_IGNORE
	movie = VideoStreamPlayer.new()
	movie.stream = MOVIE
	movie.expand = true
	movie.loop = true
	movie.bus = &"Music"
	movie.volume_db = -80
	movie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.add_child(movie)
	movie.process_mode = Node.PROCESS_MODE_ALWAYS
	poster_audio=AudioStreamPlayer.new()
	poster_audio.stream=POSTER_AUDIO.duplicate()
	poster_audio.stream.loop=true
	poster_audio.bus=&"Music"
	poster_audio.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	poster_audio.volume_db=-80
	add_child(poster_audio)
	play_button = Button.new()
	play_button.text = "P L A Y"
	play_button.add_theme_color_override("font_color", Color("722c1e"))
	play_button.add_theme_color_override("font_hover_color", Color("351d14"))
	for variant in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e8c58b") if variant != "hover" else Color("f7dfa8")
		style.border_color = Color("916038")
		style.set_border_width_all(3 if variant == "focus" else 2)
		style.set_corner_radius_all(2)
		play_button.add_theme_stylebox_override(variant, style)
	artwork.add_child(play_button)
	play_button.pressed.connect(begin_play)
	tutorial_button=Button.new();tutorial_button.text="T U T O R I A L"
	for variant in ["normal","hover","pressed","focus"]:
		tutorial_button.add_theme_stylebox_override(variant,play_button.get_theme_stylebox(variant))
	tutorial_button.add_theme_color_override("font_color",Color("722c1e"))
	artwork.add_child(tutorial_button);tutorial_button.pressed.connect(begin_tutorial)
	opening = Label.new()
	opening.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opening.text = "WINGS OVER MALTA\n1940 — 1942"
	opening.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opening.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	opening.add_theme_color_override("font_color", Color("e8c58b"))
	opening.add_theme_font_size_override("font_size", 42)
	surface.add_child(opening)
	opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blackout = ColorRect.new()
	blackout.color = Color.BLACK
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(blackout)
	blackout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_visuals()
	call_deferred("_start_video")
	call_deferred("_start_audio")

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor: float = minf(viewport_size.x / 834.0, viewport_size.y / 1112.0)
	var dimensions := Vector2(834, 1112) * scale_factor
	poster_rect = Rect2((viewport_size - dimensions) * 0.5, dimensions)
	artwork.position = poster_rect.position
	artwork.size = dimensions
	still.size = dimensions
	movie.size = dimensions
	# Printed-poster style panel in the lower-left sea; preserve the original slogan.
	play_button.position = dimensions * Vector2(0.055, 0.935)
	play_button.size = dimensions * Vector2(0.46, 0.052)
	tutorial_button.position=dimensions*Vector2(.055,.878)
	tutorial_button.size=dimensions*Vector2(.46,.044)
	tutorial_button.add_theme_font_size_override("font_size",maxi(12,int(dimensions.y*.022)))
	play_button.add_theme_font_size_override("font_size", maxi(16, int(dimensions.y * 0.027)))

func _input(event: InputEvent) -> void:
	# Retry a browser-blocked initial request on any real user gesture, without
	# restarting a track that is already running or tying it to video wraps.
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo):
		_start_audio()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			if get_viewport().gui_get_focus_owner()==tutorial_button:begin_tutorial()
			else:begin_play()
		elif event.keycode==KEY_TAB and phase==Phase.POSTER:
			if get_viewport().gui_get_focus_owner()==tutorial_button:play_button.grab_focus()
			else:tutorial_button.grab_focus()
		get_viewport().set_input_as_handled()

func begin_tutorial() -> void:
	if phase!=Phase.POSTER:return
	destination="tutorial"
	begin_play()

func begin_play() -> void:
	if phase != Phase.POSTER:
		return
	phase = Phase.LEAVING
	elapsed = 0.0
	play_button.disabled = true
	get_viewport().gui_release_focus()

func _process(delta: float) -> void:
	elapsed += delta
	if decode_video and phase in [Phase.OPENING,Phase.POSTER] and DisplayServer.get_name()!="headless":
		var position:=movie.stream_position
		# A slow frame/background tab is not a stopped decoder. Only recover
		# an unexpectedly stopped player; normal looping belongs to Godot.
		video_stalled=video_stalled+minf(delta,.25) if not movie.is_playing() else 0
		video_last_position=position
		if video_stalled>2.0:
			# Recover a stopped decoder only; never reset a playing clip.
			movie.play()
			video_stalled=0
			video_last_position=-1
			video_restarts+=1
	if phase == Phase.OPENING and elapsed >= opening_seconds + poster_fade_seconds:
		phase = Phase.POSTER
		elapsed = 0.0
	elif phase == Phase.LEAVING and elapsed >= exit_fade_seconds:
		phase = Phase.MENU
		elapsed = 0.0
		movie.stop()
		poster_audio.stop()
		surface.hide()
		GameAudioMixer.instance.set_menu_active(destination=="menu")
	elif phase == Phase.MENU and elapsed >= menu_fade_seconds:
		phase = Phase.DONE
		completed.emit()
	_update_visuals()

func _update_visuals() -> void:
	var reveal: float = smoothstep(opening_seconds, opening_seconds + poster_fade_seconds, elapsed) if phase == Phase.OPENING else 1.0
	artwork.modulate.a = reveal
	opening.modulate.a = (1.0 - reveal) * smoothstep(0.0, opening_seconds * 0.7, elapsed) if phase == Phase.OPENING else 0.0
	play_button.disabled = phase != Phase.POSTER
	tutorial_button.disabled = phase != Phase.POSTER
	play_button.modulate.a = smoothstep(0.65, 1.0, reveal)
	var shade: float = 0.0
	if phase == Phase.LEAVING:
		shade = smoothstep(0.0, exit_fade_seconds, elapsed)
	elif phase == Phase.MENU:
		shade = 1.0 if destination=="tutorial" else 1.0 - smoothstep(0.0, menu_fade_seconds, elapsed)
	blackout.color.a = shade
	poster_audio.volume_db = linear_to_db(maxf(0.0001, reveal * (1.0 - shade) * db_to_linear(poster_music_volume_db)))

func _start_video() -> void:
	if not is_inside_tree() or phase not in [Phase.OPENING,Phase.POSTER] or not decode_video or DisplayServer.get_name()=="headless":return
	if not movie.is_playing():movie.play()

func _start_audio() -> void:
	if not is_inside_tree() or phase not in [Phase.OPENING,Phase.POSTER]: return
	if GameAudioMixer.instance.playback_enabled and not poster_audio.playing:
		poster_audio.play()
		music_starts += 1

func _exit_tree() -> void:
	if is_instance_valid(poster_audio):poster_audio.stop();poster_audio.stream=null
	if is_instance_valid(movie):
		movie.stop()
		movie.stream = null
	if is_instance_valid(GameAudioMixer.instance):
		GameAudioMixer.instance.audio_button.visible = _audio_button_visible
