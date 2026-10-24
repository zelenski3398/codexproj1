class_name InterceptionSiren
extends Node
## One quiet, listener-relative alarm per encounter director. Reuses the
## supplied air-raid recording and Aircraft bus (including radio ducking).
@export var volume_db: float = -22
@export var fade_seconds: float = 1.0
var player: AudioStreamPlayer
var requested: bool = false
var starts: int = 0
var gain: float = 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	player = AudioStreamPlayer.new()
	var clip: AudioStreamOggVorbis = preload("res://assets/audio/defence/air_raid_siren.ogg").duplicate()
	clip.loop = true
	player.stream = clip
	player.bus = "Aircraft"
	player.volume_db = -60
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	add_child(player)
func set_active(value: bool) -> void:
	requested = value
func stop() -> void:
	requested = false
	gain = 0
	if is_instance_valid(player): player.stop()
func _process(delta: float) -> void:
	if requested and not player.playing and GameAudioMixer.instance.playback_enabled:
		player.play()
		starts += 1
	gain = move_toward(gain,1.0 if requested else 0.0,delta/maxf(fade_seconds,.05))
	player.volume_db = volume_db + linear_to_db(maxf(gain,.001))
	if not requested and gain == 0: player.stop()
func _exit_tree() -> void:
	stop()
