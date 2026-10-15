class_name StukaDiveAudio
extends Node
## Original supplied Jericho recording, spatial and gated by real descent.
@export var minimum_speed: float=35
@export var minimum_descent: float=5
@export var volume_db: float=-8
var aircraft: EnemyAircraft
var director: Node3D
var player: AudioStreamPlayer3D
var gain: float=0
var requested: bool=false
var starts: int=0
func _ready() -> void:
	player=AudioStreamPlayer3D.new()
	var stream: AudioStreamOggVorbis=load("res://assets/audio/defence/jericho_trumpet.ogg").duplicate()
	stream.loop=true
	player.stream=stream
	player.bus="Aircraft"
	player.unit_size=500
	player.max_distance=6500
	player.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	aircraft.add_child(player)
func should_sound() -> bool:
	if not is_instance_valid(aircraft) or not is_instance_valid(director) or director.is_finished():return false
	if aircraft.is_destroyed or aircraft.is_crashed or not aircraft.ai is DiveAttackPilot:return false
	var descent: bool=aircraft.linear_velocity.y < -minimum_descent
	var pitch: float=(-aircraft.global_basis.z).y
	return aircraft.ai.attack_state in ["DIVE","PULL OUT"] and descent and pitch<-.10 and aircraft.linear_velocity.length()>minimum_speed
func _process(delta: float) -> void:
	var active:=should_sound()
	if active and not requested:starts+=1
	requested=active
	gain=move_toward(gain,1.0 if active else 0.0,delta*3)
	player.volume_db=volume_db+linear_to_db(maxf(gain,.0001))
	player.pitch_scale=clampf(.9+aircraft.linear_velocity.length()/500,.9,1.12)
	if gain>.01 and not player.playing and GameAudioMixer.instance.playback_enabled:player.play()
	elif gain<=.01 and player.playing:player.stop()
func stop() -> void:
	requested=false
	gain=0
	if is_instance_valid(player):player.stop()
