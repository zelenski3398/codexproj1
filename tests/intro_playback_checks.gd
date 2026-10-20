extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1
	else:failed+=1
	print("PASS: " if ok else "FAIL: ",label)
func wait(seconds: float) -> void:await create_timer(seconds,true).timeout
func run() -> void:
	var game=load("res://main.tscn").instantiate();root.add_child(game)
	var intro: GameIntro=game.startup_intro
	check(intro!=null and intro.process_mode==Node.PROCESS_MODE_ALWAYS,"Native startup poster owns an always-processing presentation")
	game.show_intro()
	check(game.startup_intro==intro and intro.find_children("*","VideoStreamPlayer",true,false).size()==1,"Repeated show_intro does not create a second decoder or transition")
	await wait(1.1)
	var first:=intro.movie.stream_position
	var hash_before:=hash(intro.movie.get_video_texture().get_image().get_data())
	await wait(.8)
	check(intro.movie.is_playing() and intro.movie.stream_position!=first and hash(intro.movie.get_video_texture().get_image().get_data())!=hash_before,"Actual native video frames and clock advance, not merely the phase timer")
	paused=true
	first=intro.movie.stream_position
	await wait(.8)
	check(paused and intro.movie.stream_position!=first,"Poster decoder keeps moving even when gameplay is paused")
	paused=false
	await wait(4.5)
	check(intro.phase==GameIntro.Phase.POSTER and intro.movie.is_playing() and intro.video_restarts==0,"Source clip loops continuously past its five-second end without watchdog intervention")
	var first_id:=intro.get_instance_id()
	intro.begin_play();intro.begin_play()
	await wait(3.7)
	check(game.startup_intro==null and game.selector.active,"One Play transition reaches active main menu")
	game.show_selection()
	await wait(1.0)
	var again: GameIntro=game.startup_intro
	check(again!=null and again.get_instance_id()!=first_id and again.movie.is_playing(),"Returning to title creates one fresh, playing poster")
	first=again.movie.stream_position
	await wait(.8)
	check(again.movie.stream_position!=first,"Returned poster continues animating")
	game.show_selection(false)
	await wait(.2)
	check(game.startup_intro==null,"Programmatic restart can bypass the poster safely")
	GameAudioMixer.instance.music.stop();GameAudioMixer.instance.music.stream=null
	game.queue_free();await wait(.2)
	print("INTRO PLAYBACK RESULT: ",passed,"/",passed+failed," passed")
	quit(0 if failed==0 else 1)
