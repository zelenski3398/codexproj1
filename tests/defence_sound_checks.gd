extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in range(n):await physics_frame
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS: ",label)
	else:failed+=1;push_error("FAIL: "+label)
func run() -> void:
	GameAudioMixer.instance.playback_enabled=true
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(8)
	game.start_aa_defence()
	await frames(20)
	var mission: DiveDefenceMission=game.aa_defence
	var sound: DiveDefenceAudio=mission.audio
	check(sound.radio.triggered and sound.radio.transmissions_played==1,"Supplied Harrington recording starts exactly once at mission start")
	check(sound.radio.player.stream.resource_path.is_empty() or sound.radio.voice_clip.resource_path.ends_with("harrington_intro.ogg"),"Radio uses complete supplied clip, not Italian formation recording")
	check(not sound.radio.subtitle.visible,"No invented speech transcript is displayed")
	check(absf(sound.radio.voice_clip.get_length()-30.19755)<.02,"Complete 30.2-second supplied radio recording retained")
	check(GameAudioMixer.instance.radio_duck_db==-8,"Mission introduction ducks engine/gun/siren mix")
	check(sound.warned_waves.is_empty() and not sound.siren.playing,"No premature siren before approaching aircraft exist")
	var interaction: AirfieldInteraction=game.malta_mission.interaction
	var gun: BritishAAGun=mission.guns[0]
	game.malta_mission.pilot.global_position=interaction.find_exit(gun,5)
	await frames(2)
	interaction.mount_gun(gun)
	await frames(2)
	mission.clock=.01
	await frames(15)
	var foe: EnemyAircraft=mission.alive[0]
	check(sound.warned_waves==[1] and sound.siren.playing,"First approaching wave triggers positional air-raid siren")
	await frames(20)
	check(sound.warned_waves==[1],"One approach never duplicates the air-raid warning")
	var dive: StukaDiveAudio
	for child in foe.get_children():
		if child is StukaDiveAudio:dive=child
	check(dive!=null and dive.player.get_parent()==foe and dive.player.stream.loop,"Each Stuka owns spatial loop of supplied eight-second Jericho recording")
	foe.ai.set_physics_process(false)
	foe.freeze=true
	foe.reset_pending=false
	foe.ai.attack_state="DIVE"
	foe.linear_velocity=Vector3(0,0,-80)
	check(not dive.should_sound(),"Dive-state flag alone cannot make level flight sound like a dive")
	foe.global_basis=Basis(Vector3.RIGHT,deg_to_rad(-30))
	foe.linear_velocity=Vector3(0,-40,-70)
	check(dive.should_sound(),"Real negative pitch, descent and airspeed enable Jericho trumpet")
	dive._process(.4)
	check(dive.player.playing and dive.starts==1 and dive.gain==1,"Dive recording plays once with fade-in, spatial falloff and speed pitch")
	foe.linear_velocity=Vector3(0,30,-70)
	dive._process(.4)
	check(not dive.player.playing and dive.gain==0,"Recovery/ascent fades and stops the dive sound")
	foe.ai.attack_state="DIVE"
	foe.linear_velocity=Vector3(0,-40,-70)
	dive._process(.4)
	foe.take_damage(1000)
	dive._process(.4)
	check(not dive.player.playing,"Destroyed aircraft cannot continue its attack siren")
	mission.cancel()
	check(not sound.siren.playing and not sound.radio.player.playing and GameAudioMixer.instance.radio_owner==0,"Leaving/cancelling mission stops all sounds and restores previous mix")
	game.restart_malta()
	await frames(20)
	check(game.aa_defence.audio!=sound and game.aa_defence.audio.radio.transmissions_played==1 and game.aa_defence.audio.warned_waves.is_empty(),"Retry owns fresh one-shot intro and resets wave warning latches")
	game.restart_malta()
	var aborted: DiveDefenceAudio=game.aa_defence.audio
	game.aa_defence.cancel()
	await frames(3)
	check(aborted.radio.transmissions_played==0 and GameAudioMixer.instance.radio_owner==0,"Immediate cancellation suppresses queued introduction and cannot steal the next radio mix")
	print("DEFENCE SOUND RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
