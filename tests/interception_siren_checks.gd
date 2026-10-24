extends SceneTree
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1
	print("PASS: " if ok else "FAIL: ", label)
func run() -> void:
	GameAudioMixer.instance.playback_enabled = true
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	var alarm: InterceptionSiren = game.encounters.siren
	check(not alarm.requested and not alarm.player.playing, "Main menu has no air-raid alarm")
	for mode in ["interception", "harbour"]:
		game.start_malta("hal_far" if mode == "harbour" else "ta_qali", "sea_gladiator", mode)
		await frames(12)
		check(alarm.requested and alarm.player.playing and alarm.player.stream.loop, mode+": supplied siren loops from mission departure")
		check(game.encounters.active.is_empty(), mode+": siren does not depend on early enemy spawning")
		var starts: int = alarm.starts
		await frames(180)
		check(alarm.starts == starts and alarm.gain > .99, mode+": one continuous alarm with smooth fade-in, no per-frame restarts")
		check(alarm.player.bus == "Aircraft" and alarm.volume_db <= -18, mode+": restrained mix uses existing radio-ducked aircraft bus")
		if mode == "interception": game.interception._finish(false,"Test result")
		else: game.harbour._finish(false,"Test result")
		await frames(150)
		check(not alarm.requested and not alarm.player.playing, mode+": results fade and stop the alarm")
		game.restart_malta(); await frames(12)
		check(alarm.requested and alarm.starts == starts+1, mode+": retry starts exactly one fresh transmission")
		game.show_selection(false); await frames(3)
		check(not alarm.player.playing and alarm.gain == 0, mode+": return to menu immediately clears alarm")
	game.start_free_roam("spitfire");await frames(12)
	check(not alarm.requested and not alarm.player.playing,"Peaceful Malta free roam remains quiet")
	game.encounters.confirm();await frames(12)
	check(game.encounters.active.size() == 1 and alarm.requested and alarm.player.playing,"Manual enemy spawn starts the encounter alarm")
	game.encounters.active[0].take_damage(1000);await frames(150)
	check(not alarm.requested and not alarm.player.playing,"Cleared encounter stops the alarm while awaiting confirmation")
	game.show_selection(false);game.start_malta("luqa","spitfire","survival");await frames(12)
	check(alarm.requested and alarm.player.playing,"Survival stage also has an air-raid warning")
	game.encounters.pilot_died();await frames(150)
	check(not alarm.player.playing,"Player death stops Survival alarm")
	game.show_selection(false);game.start_aa_defence();await frames(20)
	check(not alarm.requested and not alarm.player.playing and game.aa_defence.audio.siren.playing,"AA defence retains its original siren without doubling alarms")
	game.show_selection(false);await frames(3)
	check(get_nodes_in_group("defence_mission_audio").is_empty() and not alarm.player.playing,"Leaving AA removes its own sound and leaves no interception alarm")
	game.queue_free();await frames(5)
	print("INTERCEPTION SIREN RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed == 0 else 1)
