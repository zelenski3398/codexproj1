class_name DiveDefenceAudio
extends Node
## Mission-owned radio, one warning per approaching wave, bounded dive sources.
@export var approach_distance: float=2200
var director: Node3D
var radio: MissionRadio
var siren: AudioStreamPlayer3D
var warned_waves: Array[int]=[]
var stopped: bool=false
func _ready() -> void:
	radio=MissionRadio.new()
	radio.voice_clip=load("res://assets/audio/defence/harrington_intro.ogg")
	radio.subtitle_text="" # No verified transcript was supplied for this recording.
	radio.duck_db=-8
	add_child(radio)
	call_deferred("_start_radio")
	siren=AudioStreamPlayer3D.new()
	siren.stream=load("res://assets/audio/defence/air_raid_siren.ogg")
	siren.bus="Aircraft"
	siren.volume_db=-12
	siren.unit_size=1000
	siren.max_distance=10000
	siren.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	director.add_child(siren)
func _start_radio() -> void:
	if not stopped and is_inside_tree() and not director.is_finished():radio.transmit_formation()

func attach(aircraft: EnemyAircraft) -> StukaDiveAudio:
	var sound:=StukaDiveAudio.new()
	sound.aircraft=aircraft
	sound.director=director
	aircraft.add_child(sound)
	return sound
func _process(_delta: float) -> void:
	if stopped or director.is_finished():return
	siren.global_position=director.centre+Vector3.UP*5
	if director.wave<1 or warned_waves.has(director.wave):return
	for foe in director.alive:
		if not foe.is_destroyed and foe.global_position.distance_to(director.centre)<=approach_distance:
			warned_waves.append(director.wave)
			# No stacked sirens: an already audible warning finishes naturally.
			if not siren.playing and GameAudioMixer.instance.playback_enabled:siren.play()
			break
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
