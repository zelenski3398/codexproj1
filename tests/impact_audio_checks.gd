extends SceneTree
## Real swept hits/physics and native mixer capture. Initial poses are fixtures,
## never gameplay shortcuts; audio measures need wall-clock mixer buffers.
var game:Node3D
var plane:FlightAircraft
var service:AircraftImpactService
var checks:int=0
var failures:int=0
var deaths:int=0
var enemy_deaths:int=0
var capture:AudioEffectCapture
var camera:Camera3D
func _initialize() -> void:call_deferred("run")
func frames(n:int) -> void:
	for i in range(n):await physics_frame
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",message)
func fixture(body:FlightAircraft,point:Vector3,velocity:Vector3=Vector3.ZERO) -> void:
	body.freeze=false
	body.request_reset()
	body.pending_reset_pose=Transform3D(Basis.IDENTITY,point)
	body.pending_reset_velocity=velocity
	await frames(4)
	body.pilot.automated=true
func run() -> void:
	GameAudioMixer.instance.playback_enabled=true
	GameAudioMixer.instance.set_muted(false,false)
	GameAudioMixer.instance.set_volume("Guns",.75,false)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_flight("spitfire")
	plane=game.aircraft
	game.enemy.ai.combat_enabled=false
	plane.destroyed.connect(func():deaths+=1)
	await fixture(plane,Vector3(0,150,0))
	plane.freeze=true
	plane.engine_running=false
	plane.aircraft_audio.clear()
	game.enemy.engine_running=false
	game.enemy.aircraft_audio.clear()
	service=AircraftImpactService.obtain()
	var pool:=ProjectilePool.new()
	pool.capacity=12
	game.add_child(pool)
	var before:=plane.health.hp
	pool.spawn(plane.position+Vector3(0,.1,-8),Vector3(0,0,1500),.2,1,RID(),false,CombatTeams.ENEMY)
	await frames(2)
	check(plane.health.hp<before and service.hits_confirmed==1,"Actual swept projectile damage triggers one hit event")
	var slot:int=service.last_event.voice
	check(slot>=0 and service.last_event.own and service.voices[slot].global_position.is_equal_approx(service.last_event.point),"Own-aircraft hit is positional at the confirmed collision")
	check(service.voices[slot].attenuation_model==AudioStreamPlayer3D.ATTENUATION_DISABLED,"Own hit stays readable in cockpit and external cameras")
	var confirmed:=service.hits_confirmed
	pool.spawn(plane.position+Vector3(30,0,-8),Vector3(0,0,1500),.01,1,RID(),false,CombatTeams.ENEMY)
	pool.spawn(plane.position+Vector3(0,.1,-8),Vector3(0,0,1500),.2,1,RID(),false,CombatTeams.PLAYER)
	await frames(3)
	check(service.hits_confirmed==confirmed,"Misses and friendly-fire exclusions do not create aircraft hit audio")
	await frames(10)
	var heavy:=AAWeaponDefinition.new()
	heavy.direct_damage=1
	pool.shell_definition=heavy
	pool.spawn(plane.position+Vector3(0,.1,-8),Vector3(0,0,1500),.2,1,RID(),false,CombatTeams.ENEMY)
	await frames(2)
	check(service.last_event.kind=="heavy_hit" and service.voices[service.last_event.voice].stream==service.profile.heavy_hit,"Existing AA projectile type selects a heavier impact sample")
	pool.shell_definition=null
	var foe:EnemyAircraft=game.enemy
	await fixture(foe,Vector3(30,150,-50))
	foe.freeze=true
	pool.spawn(foe.position+Vector3(0,.1,-10),Vector3(0,0,1700),.2,1,RID(),false,CombatTeams.PLAYER)
	await frames(2)
	slot=service.last_event.voice
	check(not service.last_event.own and slot>=0 and service.voices[slot].attenuation_model==AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE and service.voices[slot].max_distance==service.profile.hit_range,"Enemy hits use range-limited 3D distance attenuation")
	var own_dead_count:=deaths
	plane.take_damage(999)
	plane.take_damage(999)
	check(plane.is_destroyed and plane.impact_effects.explosion_count==0 and deaths==own_dead_count+1,"Zero HP in flight creates one combat loss without an automatic explosion")
	check(not plane.aircraft_audio.idle.playing and not plane.guns.weapon_audio.player.playing,"Destruction immediately stops engine and gun loops")
	plane.components.catastrophic_failure("Explicit fuel ignition fixture")
	await frames(2)
	check(plane.impact_effects.fragments.size()==8 and not plane.model.visible,"Airborne explosion releases bounded real model fragments")
	var explosion:DestructionBurst=plane.impact_effects.burst
	var debris:Node3D=plane.impact_effects.debris_root
	check(explosion.get_parent()==service and debris.get_parent()==service,"Destruction effect and debris ownership are independent of the aircraft")
	foe.destroyed.connect(func():enemy_deaths+=1)
	foe.take_damage(999)
	foe.take_damage(999)
	await frames(2)
	check(enemy_deaths==1 and foe.impact_effects.explosion_count==0 and not foe.ai.is_physics_processing() and not foe.rear_gunner.guns.weapon_audio.player.playing,"Enemy loss disables AI and audio without a forced explosion")
	# A raised sea plane proves contact effects do not assume world Y=0.
	var sea:=StaticBody3D.new()
	sea.add_to_group("aircraft_water")
	sea.position.y=40
	game.add_child(sea)
	var collision:=CollisionShape3D.new()
	collision.shape=WorldBoundaryShape3D.new()
	sea.add_child(collision)
	plane.add_collision_exception_with(sea)
	plane.impact_effects.water_rids.append(sea.get_rid())
	await fixture(plane,Vector3(20000,43,0),Vector3(0,-5,-5))
	var water_deaths:=deaths
	await frames(160)
	check(plane.impact_effects.water and plane.impact_effects.splash_count==1 and plane.impact_effects.explosion_count==0 and deaths==water_deaths+1,"Healthy player sea crash creates one splash/death and no airborne fireball")
	check(absf(plane.impact_effects.water_point.y-40)<.01 and plane.impact_effects.burst.global_position.is_equal_approx(plane.impact_effects.water_point),"Splash uses the real elevated sea contact position")
	var gentle:float=plane.impact_effects.last_water_strength
	var splash:DestructionBurst=plane.impact_effects.burst
	check(splash is SeaImpactBurst and is_instance_valid((splash as SeaImpactBurst).foam),"Sea impact includes CPU spray, mist and a surface foam ring")
	await fixture(plane,Vector3(20000,45,0),Vector3(0,-70,-90))
	await frames(20)
	check(plane.impact_effects.last_water_strength>gentle*1.5,"Fast water impact has substantially stronger intensity than gentle contact")
	await fixture(plane,Vector3(20000,50,0),Vector3(0,-30,-20))
	plane.components.catastrophic_failure("Explicit burning wreck fixture")
	var air_point:Vector3=plane.impact_effects.burst.global_position
	var after_air:=deaths
	await frames(90)
	check(plane.impact_effects.explosion_count==1 and plane.impact_effects.splash_count==1 and deaths==after_air,"Exploded wreck crossing water splashes once without another explosion or death")
	check(air_point.y>40 and absf(plane.impact_effects.water_point.y-40)<.01,"Air explosion and later water splash retain distinct actual event positions")
	# Enemy water contact uses its own freshly created component registry.
	var other:=EnemyAircraft.new()
	other.reset_position=Vector3(20100,43,0)
	game.add_child(other)
	other.ai.combat_enabled=false
	await fixture(other,Vector3(20100,43,0),Vector3(0,-12,-20))
	await frames(60)
	check(other.impact_effects.splash_count==1 and other.impact_effects.explosion_count==0 and other.impact_count==1,"Enemy sea crash resolves through the same splash and single loss path")
	var lingering:DestructionBurst=other.impact_effects.burst
	var sound_slots:Array[int]=[]
	for i in range(service.voices.size()):
		if service.voice_owners[i]==other.get_instance_id() and service.remaining[i]>0:sound_slots.append(i)
	other.queue_free()
	await frames(2)
	check(is_instance_valid(lingering) and not sound_slots.is_empty() and service.remaining[sound_slots[0]]>0,"Splash particles and sound survive removal of the enemy scene")
	await frames(460)
	check(not is_instance_valid(lingering) and sound_slots.all(func(i):return service.remaining[i]==0),"Independent tails and effects finish and release bounded resources")
	# Real native mixer samples establish panning, range, own-hit readability and
	# headroom without pretending to have listened to speakers.
	camera=Camera3D.new()
	game.add_child(camera)
	camera.global_position=Vector3(0,200,0)
	camera.make_current()
	root.set_as_audio_listener_3d(true)
	capture=AudioEffectCapture.new()
	capture.buffer_length=1
	var bus:int=AudioServer.get_bus_index("Guns")
	AudioServer.add_bus_effect(bus,capture)
	var left:Dictionary=await measure(Vector3(-8,200,-8))
	var right:Dictionary=await measure(Vector3(8,200,-8))
	check(left.left>left.right*1.15 and right.right>right.left*1.15,"Real mixer stereo energy follows left/right impact positions")
	var near:Dictionary=await measure(Vector3(0,200,-10))
	var far:Dictionary=await measure(Vector3(0,200,-120))
	var beyond:Dictionary=await measure(Vector3(0,200,-240))
	print("IMPACT RMS near=",near.rms," far=",far.rms," outside=",beyond.rms)
	check(near.rms>.0001 and near.rms>far.rms*3 and beyond.rms<near.rms*.02,"Native enemy-hit audio fades with range and becomes inaudible beyond its limit")
	var cockpit:Dictionary=await measure(Vector3(0,200,-1),true)
	var chase:Dictionary=await measure(Vector3(0,200,-25),true)
	check(cockpit.rms>.0001 and chase.rms>cockpit.rms*.4,"Native own-hit mix remains audible from cockpit and external listener distances")
	var cluster:Dictionary=await measure(Vector3(0,200,-8),true,8)
	check(cluster.rms>.001 and cluster.peak<.95 and service.voices.size()==service.profile.audio_voices,"Cluster headroom keeps actual summed impact samples below clipping with a fixed voice budget")
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1)
	service.clear_all()
	check(service.remaining.all(func(v):return v==0) and service.effects.is_empty(),"Session cleanup clears all transient audio and effects")
	game.queue_free()
	await frames(3)
	OS.delay_msec(200) # Let the native mixer retire stopped Ogg playbacks.
	await frames(3)
	print("IMPACT AUDIO RESULT: ",checks-failures,"/",checks," passed")
	quit(1 if failures else 0)
func measure(point:Vector3,own:bool=false,count:int=1) -> Dictionary:
	service.clear_all()
	capture.clear_buffer()
	for i in range(count):
		service.play_at(service.profile.metal_hits[i%3],point,service.profile.own_hit_db if own else service.profile.other_hit_db,service.profile.own_hit_range if own else service.profile.hit_range,service.profile.hit_unit_size,service.profile.hit_attenuation,1,i,2 if own else 0,own)
	await process_frame
	await process_frame
	OS.delay_msec(220)
	var samples:PackedVector2Array=capture.get_buffer(capture.get_frames_available())
	var l:float=0
	var r:float=0
	var peak:float=0
	for sample in samples:
		l+=sample.x*sample.x;r+=sample.y*sample.y
		peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	return {"left":sqrt(l/maxi(samples.size(),1)),"right":sqrt(r/maxi(samples.size(),1)),"rms":sqrt((l+r)/maxi(samples.size()*2,1)),"peak":peak}
