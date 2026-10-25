extends Node
## Isolated test harness: production controllers, explicit victory/pose fixtures.
var game: Node
var bridge: Object
var buttons: Dictionary={}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	bridge=Engine.get_singleton("JavaScriptBridge")
	game=load("res://main.tscn").instantiate();add_child(game);game.start_harbour()
	var canvas:=CanvasLayer.new();canvas.layer=60;add_child(canvas)
	var row:=HBoxContainer.new();row.position=Vector2(20,110);canvas.add_child(row)
	for name in ["Secure objectives (fixture)","Land (pose fixture)","Crash (fixture)","Retry"]:
		var button:=Button.new();button.text=name;button.focus_mode=Control.FOCUS_NONE;row.add_child(button);buttons[name]=button
	buttons["Secure objectives (fixture)"].pressed.connect(func():game.harbour._finish(true,"Harbour objectives secured"))
	buttons["Land (pose fixture)"].pressed.connect(_land)
	buttons["Crash (fixture)"].pressed.connect(func():game.aircraft.is_crashed=true)
	buttons.Retry.pressed.connect(_retry)
	await get_tree().create_timer(.5).timeout
	_airborne()
func _airborne() -> void:
	game.malta_mission.board_nearest()
	var field: MaltaAirfield=game.field.fields.hal_far
	game.aircraft.global_transform=Transform3D(field.global_basis,field.to_global(Vector3(0,500,-100)))
	game.aircraft.linear_velocity=-field.global_basis.z*60
	game.aircraft.pilot.automated=true;game.aircraft.pilot.throttle=.7;game.aircraft.engine_running=true
func _land() -> void:
	var field: MaltaAirfield=game.field.fields.hal_far
	game.aircraft.request_reset()
	game.aircraft.pending_reset_pose=Transform3D(field.global_basis*Basis(Vector3.RIGHT,.117),field.to_global(Vector3(0,1.18,0)))
	game.aircraft.pending_reset_velocity=Vector3.ZERO
	game.aircraft.engine_running=false;game.aircraft.pilot.automated=true;game.aircraft.pilot.brakes=true
func _retry() -> void:
	game.restart_malta()
	await get_tree().create_timer(.5).timeout
	_airborne()
func _process(_delta: float) -> void:
	if bridge==null or not is_instance_valid(game.harbour):return
	var state: Dictionary={"phase":game.harbour.phase,"pending":game.malta_mission.return_flow.pending,"panel":game.harbour.results.visible,"count":game.harbour.result_count,"congratulations":game.harbour.radio.seen.has("success"),"voice_playing":game.harbour.radio.current_id=="success" and game.harbour.radio.player.playing,"objective":game.gameplay_hud.objective.text,"world":game.field.get_instance_id(),"wheels":game.aircraft.gear.contact_count,"speed":game.aircraft.linear_velocity.length()}
	for name in buttons:
		var item: Button=buttons[name]
		var centre: Vector2=get_viewport().get_final_transform()*(item.get_global_transform_with_canvas()*(item.size*.5))
		state[name]=[centre.x,centre.y]
	bridge.eval("window.returnTestState="+JSON.stringify(state)+";",true)
