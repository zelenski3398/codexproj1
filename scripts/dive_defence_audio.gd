class_name DiveDefenceAudio
extends Node
## Mission-long looping airfield alarm, one-shot radio and bounded dive sources.
var director: Node3D
var radio: MissionRadio
var siren: AudioStreamPlayer3D
var siren_starts: int=0
var stopped: bool=false
func _ready() -> void:
	radio=MissionRadio.new()
	radio.voice_clip=load("res://assets/audio/defence/harrington_intro.ogg")
	radio.subtitle_text="" # No verified transcript was supplied for this recording.
	radio.duck_db=-8
	add_child(radio)
	call_deferred("_start_mission_audio")
	siren=AudioStreamPlayer3D.new()
	var stream: AudioStreamOggVorbis=load("res://assets/audio/defence/air_raid_siren.ogg").duplicate()
	stream.loop=true
	siren.stream=stream
	siren.bus="Aircraft"
	siren.volume_db=-12
	siren.unit_size=1000
	siren.max_distance=10000
	siren.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	director.add_child(siren)
func _start_mission_audio() -> void:
	if stopped or not is_inside_tree() or director.is_finished():return
	radio.transmit_formation()
	if GameAudioMixer.instance.playback_enabled:
		siren.play()
		siren_starts+=1

func attach(aircraft: EnemyAircraft) -> StukaDiveAudio:
	var sound:=StukaDiveAudio.new()
	sound.aircraft=aircraft
	sound.director=director
	aircraft.add_child(sound)
	return sound
func _process(_delta: float) -> void:
	if stopped or director.is_finished():return
	siren.global_position=director.centre+Vector3.UP*5
func stop() -> void:
	stopped=true
	if is_instance_valid(radio):radio.stop()
	if is_instance_valid(siren):siren.stop()
	for foe in director.session.encounters.active+director.session.encounters.wrecks:
		if is_instance_valid(foe):
			for child in foe.get_children():
				if child is StukaDiveAudio:child.stop()
func _exit_tree() -> void:
	if is_instance_valid(radio):radio.stop()
	if is_instance_valid(siren):siren.stop()
