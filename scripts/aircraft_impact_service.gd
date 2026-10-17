class_name AircraftImpactService
extends Node3D
## Session-cleared world-space effects and capped positional audio. Never owned
## by a projectile/aircraft, so an entity's removal cannot truncate an impact.
static var instance: AircraftImpactService
@export var profile: AircraftImpactProfile = preload("res://audio_profiles/aircraft_impacts.tres")
var voices: Array[AudioStreamPlayer3D]=[]
var voice_owners: Array[int]=[]
var priorities: Array[int]=[]
var base_volumes: Array[float]=[]
var remaining: Array[float]=[]
var effects: Array[Node3D]=[]
var clock: float=0
var last_hits: Dictionary={}
var hits_confirmed: int=0
var hits_audible: int=0
var last_event: Dictionary={}

static func obtain() -> AircraftImpactService:
	if not is_instance_valid(instance):
		var service:=AircraftImpactService.new()
		service.name="AircraftImpactService"
		GameAudioMixer.instance.add_child(service)
	return instance
func _enter_tree() -> void:instance=self
func _exit_tree() -> void:
	for voice in voices:
		voice.stop();voice.stream=null
	if instance==self:instance=null
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_PAUSABLE
	for i in range(profile.audio_voices):
		var voice:=AudioStreamPlayer3D.new()
		voice.bus="Guns" # Existing volume control, pause mix and radio ducking.
		voice.max_db=0
		voice.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
		add_child(voice)
		voices.append(voice);voice_owners.append(0);priorities.append(0);remaining.append(0);base_volumes.append(0)
func play_at(stream:AudioStream,point:Vector3,db:float,audible_range:float,unit_size:float,attenuation:float,pitch:float,owner_id:int,priority:int=1,own:bool=false) -> int:
	if stream==null or not GameAudioMixer.instance.playback_enabled:return -1
	var slot:int=-1
	for i in range(voices.size()):
		if remaining[i]<=0:slot=i;break
	if slot<0:
		for i in range(voices.size()):
			if priorities[i]<priority and (slot<0 or remaining[i]<remaining[slot]):slot=i
	if slot<0:return -1
	var voice:=voices[slot]
	voice.stop()
	voice.stream=stream
	voice.global_position=point
	base_volumes[slot]=db
	voice.volume_db=db
	voice.max_distance=audible_range
	voice.unit_size=unit_size/maxf(attenuation,.1)
	voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED if own else AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	voice.pitch_scale=clampf(pitch,.7,1.35)
	voice_owners[slot]=owner_id;priorities[slot]=priority
	remaining[slot]=stream.get_length()/voice.pitch_scale+.08
	voice.play()
	return slot
func aircraft_hit(aircraft:FlightAircraft,point:Vector3,heavy:bool=false) -> void:
	hits_confirmed+=1
	var owner_id:=aircraft.get_instance_id()
	if clock-float(last_hits.get(owner_id,-100))<profile.hit_interval:return
	last_hits[owner_id]=clock
	var own:bool=aircraft.team_id==CombatTeams.PLAYER and aircraft.input_enabled
	var stream:AudioStream=profile.heavy_hit if heavy else (profile.metal_hits.pick_random() if not profile.metal_hits.is_empty() else null)
	var db:float=(profile.own_hit_db if own else profile.other_hit_db)+randf_range(-profile.volume_variation_db,profile.volume_variation_db)
	var slot:=play_at(stream,point,db,profile.own_hit_range if own else profile.hit_range,profile.hit_unit_size,profile.hit_attenuation,1+randf_range(-profile.pitch_variation,profile.pitch_variation),owner_id,2 if own else 0,own)
	if slot>=0:hits_audible+=1
	last_event={"kind":"heavy_hit" if heavy else "hit","point":point,"own":own,"voice":slot}
func register_effect(effect:Node3D,owner_id:int,lifetime:float) -> Node3D:
	effect.set_meta("impact_owner",owner_id)
	effect.set_meta("impact_expiry",clock+lifetime)
	add_child(effect)
	effects.append(effect)
	while effects.size()>profile.maximum_effects:
		var oldest:Node3D=effects.pop_front()
		if is_instance_valid(oldest):oldest.queue_free()
	return effect
func burst_at(point:Vector3,normal:Vector3,water:bool,strength:float,owner_id:int) -> DestructionBurst:
	var effect:DestructionBurst=SeaImpactBurst.new() if water else DestructionBurst.new()
	effect.strength=strength
	register_effect(effect,owner_id,3.5)
	effect.global_position=point
	if water and normal.dot(Vector3.UP)<.999:
		effect.quaternion=Quaternion(Vector3.UP,normal)
	return effect
func clear_owner(owner_id:int) -> void:
	release_particles(owner_id)
	for i in range(voices.size()):
		if voice_owners[i]==owner_id:
			voices[i].stop();remaining[i]=0;voices[i].stream=null
	for effect in effects:
		if is_instance_valid(effect) and int(effect.get_meta("impact_owner"))==owner_id:effect.queue_free()
	last_hits.erase(owner_id)
func clear_all() -> void:
	smoke_reservations.clear()
	flame_reservations.clear()
	for i in range(voices.size()):
		voices[i].stop();voices[i].stream=null;remaining[i]=0
	for effect in effects:
		if is_instance_valid(effect):effect.queue_free()
	effects.clear();last_hits.clear()
func _physics_process(delta:float) -> void:
	clock+=delta
	reservation_clock += delta
	if reservation_clock >= 0.1:
		reservation_clock = 0
		for reservations in [smoke_reservations,flame_reservations]:
			for i in range(reservations.size()-1,-1,-1):
				if reservations[i].expires<=clock: reservations.remove_at(i)
	var active_count:int=remaining.filter(func(value):return value>0).size()
	var headroom:float=profile.cluster_headroom_db*log(maxi(active_count,1))/log(2.0)
	for id in last_hits.keys():
		if clock-float(last_hits[id])>2:last_hits.erase(id)
	for i in range(voices.size()):
		if remaining[i]>0:
			voices[i].volume_db=move_toward(voices[i].volume_db,base_volumes[i]-headroom,delta*180)
			remaining[i]=maxf(remaining[i]-delta,0)
			if remaining[i]==0:voices[i].stop();voices[i].stream=null
	for i in range(effects.size()-1,-1,-1):
		var effect:Node3D=effects[i]
		if not is_instance_valid(effect):effects.remove_at(i)
		elif clock>=float(effect.get_meta("impact_expiry")):
			effect.queue_free();effects.remove_at(i)

# Conservative lifetimes include particles overwritten early in local pools.
# Reservation limits bound emission across all aircraft without per-frame
# searches over every aircraft's particle meshes.
var smoke_reservations: Array[Dictionary] = []
var reservation_clock: float = 0
var flame_reservations: Array[Dictionary] = []
func reserve_particle(smoke: bool, lifetime: float, owner_id: int) -> bool:
	var reservations: Array[Dictionary] = smoke_reservations if smoke else flame_reservations
	var maximum: int = profile.maximum_smoke_particles if smoke else profile.maximum_flame_particles
	if reservations.size() >= maximum: return false
	reservations.append({"expires":clock+lifetime,"owner":owner_id})
	return true
func release_particles(owner_id: int) -> void:
	for reservations in [smoke_reservations,flame_reservations]:
		for i in range(reservations.size()-1,-1,-1):
			if reservations[i].owner == owner_id: reservations.remove_at(i)
