class_name GameplayHUD
extends CanvasLayer
## One presentation layer. Mission controllers remain the source of truth.
static var instance: GameplayHUD
var session: Node3D
var root: Control
var tracker: PanelContainer
var title: Label
var objective: Label
var supporting: Label
var completion: Label
var vital: Label
var actions: Label
var notification: Label
var instruments: Label
var confirm_action: Button
var parts: AircraftDamageHUD
var pause_panel: PanelContainer
var pause_column: VBoxContainer
var help: PanelContainer
var help_text: RichTextLabel
var debug: Label
var previous_pause: bool
var previous_mouse: int
var help_open: bool = false
var age: float = 0
var previous_objective: String = ""
var completion_time: float = 0
var last_notice: String = ""
var notice_clock: float = 0
var tracked_session: int = -1
var interaction_context: String = ""

static func blocks_input() -> bool:
	return is_instance_valid(instance) and instance.help_open

static func binding(action: String) -> String:
	var names: Array[String]=[]
	for event in InputMap.action_get_events(action):
		var name: String=""
		if event is InputEventKey:
			name=OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
		elif event is InputEventMouseButton:
			name={1:"LMB",2:"RMB"}.get(event.button_index,event.as_text())
		if not name.is_empty() and name not in names:names.append(name)
	return " / ".join(names)

func _ready() -> void:
	instance=self
	layer=35;process_mode=Node.PROCESS_MODE_ALWAYS;process_priority=100
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	var health_box:=MarginContainer.new();health_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	health_box.offset_left=20;health_box.offset_top=20;root.add_child(health_box)
	vital=label(16);vital.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;vital.custom_minimum_size.x=250;health_box.add_child(vital)
	tracker=PanelContainer.new();tracker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tracker.offset_left=-360;tracker.offset_right=-20;tracker.offset_top=20;tracker.add_theme_stylebox_override("panel",panel_style());root.add_child(tracker)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",6);tracker.add_child(column)
	title=label(12,Color("d5b77a"));column.add_child(title)
	objective=label(19);objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;objective.custom_minimum_size.x=300;column.add_child(objective)
	supporting=label(14,Color("b9c3b5"));supporting.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(supporting)
	completion=label(12,Color("8bc49a"));column.add_child(completion)
	var bottom:=VBoxContainer.new();bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left=20;bottom.offset_right=-20;bottom.offset_top=-250;bottom.offset_bottom=-16;bottom.alignment=BoxContainer.ALIGNMENT_END;bottom.add_theme_constant_override("separation",7);root.add_child(bottom)
	actions=label(15,Color("e4bf75"));actions.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;bottom.add_child(actions)
	confirm_action=Button.new();confirm_action.text="Confirm / spawn · "+binding("confirm_encounter");confirm_action.focus_mode=Control.FOCUS_NONE;confirm_action.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;confirm_action.pressed.connect(func():session.encounters.confirm());bottom.add_child(confirm_action)
	instruments=label(15);bottom.add_child(instruments)
	parts=AircraftDamageHUD.new();parts.custom_minimum_size.y=100;bottom.add_child(parts)
	notification=label(16,Color("e4bf75"));notification.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;notification.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);notification.offset_left=-220;notification.offset_right=220;notification.offset_top=150;root.add_child(notification)
	debug=label(13);debug.position=Vector2(20,110);root.add_child(debug);debug.hide()
	pause_panel=panel(Vector2(.2,.12),Vector2(.8,.88));pause_column=VBoxContainer.new();pause_column.add_theme_constant_override("separation",10);pause_panel.add_child(pause_column)
	pause_column.add_child(label(26,Color("e4bf75"),"Paused"))
	button(pause_column,"Resume",func():get_tree().paused=false;restore_capture())
	button(pause_column,"Controls & Help · "+binding("controls_help"),open_help)
	button(pause_column,"Restart session",func():get_tree().paused=false;session.call_deferred("restart_malta") if is_instance_valid(session.malta_mission) else session.aircraft.request_reset())
	button(pause_column,"Return to menu",func():get_tree().paused=false;session.call_deferred("show_selection"))
	pause_panel.hide()
	help=panel(Vector2(.09,.06),Vector2(.91,.94));var help_column:=VBoxContainer.new();help.add_child(help_column)
	help_column.add_child(label(25,Color("e4bf75"),"Controls & Help"))
	help_text=RichTextLabel.new();help_text.bbcode_enabled=true;help_text.size_flags_vertical=Control.SIZE_EXPAND_FILL;help_text.add_theme_font_size_override("normal_font_size",17);help_column.add_child(help_text)
	button(help_column,"Close · "+binding("controls_help")+" / "+binding("pause"),close_help);help.hide()

func label(font_size: int,color: Color=Color("e9e8d7"),text: String="") -> Label:
	var item:=Label.new();item.text=text;item.mouse_filter=Control.MOUSE_FILTER_IGNORE;item.add_theme_font_size_override("font_size",font_size);item.add_theme_color_override("font_color",color);item.add_theme_color_override("font_shadow_color",Color.BLACK);item.add_theme_constant_override("shadow_offset_x",1);item.add_theme_constant_override("shadow_offset_y",1);return item

func panel_style() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color(.04,.065,.06,.77);style.set_content_margin_all(14);return style

func panel(start: Vector2,end: Vector2) -> PanelContainer:
	var item:=PanelContainer.new();root.add_child(item);item.anchor_left=start.x;item.anchor_top=start.y;item.anchor_right=end.x;item.anchor_bottom=end.y
	var style:=StyleBoxFlat.new();style.bg_color=Color(.035,.06,.055,.98);style.set_content_margin_all(18);item.add_theme_stylebox_override("panel",style);return item

func button(parent: Node,text: String,callback: Callable) -> void:
	var item:=Button.new();item.text=text;item.pressed.connect(callback);parent.add_child(item)

func active() -> bool:
	return is_instance_valid(session.malta_mission) or is_instance_valid(session.hud)

func _input(event: InputEvent) -> void:
	if not active() or event.is_echo():return
	if event.is_action_pressed("controls_help"):
		if help_open:close_help()
		else:open_help()
		get_viewport().set_input_as_handled()
	elif help_open:
		if event.is_action_pressed("pause"):close_help();get_viewport().set_input_as_handled()
		# Block keyboard/mouse gameplay, but let the GUI receive scroll/close clicks.
		elif event is InputEventKey:get_viewport().set_input_as_handled()
	if event.is_action_pressed("hud_debug") and not help_open:debug.visible=not debug.visible;get_viewport().set_input_as_handled()

func open_help() -> void:
	if help_open:return
	previous_pause=get_tree().paused;previous_mouse=Input.mouse_mode
	help_open=true;get_tree().paused=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	help_text.text=controls_text();help.show();pause_panel.hide()
	get_viewport().gui_release_focus()

func close_help() -> void:
	if not help_open:return
	help_open=false;help.hide();get_tree().paused=previous_pause
	for action in ["fire","aa_fire","aa_zoom","board","battery_command"]:Input.action_release(action)
	if not previous_pause:restore_capture()
	else:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_viewport().gui_release_focus()

func restore_capture() -> void:
	Input.mouse_mode=previous_mouse if not help_open else Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(session.malta_mission):
		var gun: BritishAAGun=session.malta_mission.interaction.occupied_gun
		if is_instance_valid(gun):
			gun.mouse_controls.release_fire=true;gun.mouse_controls.reset_target()
			# Browsers require a fresh user gesture for pointer lock.
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") else Input.MOUSE_MODE_CAPTURED

func controls_text() -> String:
	var text: String=""
	var sections: Dictionary={
		"On Foot":[["throttle_up","Walk forward"],["throttle_down","Walk back"],["rudder_left","Walk left"],["rudder_right","Walk right"],["roll_left","Turn left"],["roll_right","Turn right"],["board","Enter / exit nearest aircraft, gun or truck (safe conditions apply)"],["battery_command","Enter / exit nearby command post"]],
		"Aircraft":[["pitch_up","Nose up"],["pitch_down","Nose down"],["roll_left","Bank left"],["roll_right","Bank right"],["rudder_left","Left rudder"],["rudder_right","Right rudder"],["throttle_up","Increase throttle"],["throttle_down","Decrease throttle"],["engine","Start / stop engine"],["gear","Retract / extend gear; Gladiator gear is fixed"],["brake","Wheel brakes"],["fire","Forward guns"]],
		"AA Guns":[["aa_fire","Fire: heavy single shot / 5 s reload; Bofors automatic / 0.5 s reload"],["aa_zoom","Gun-sight zoom; at the heavy command post, designate a target / approximate area (aim estimate)"],["brake","Fine aim"],["board","Mount / dismount gun"],["throttle_up","Heavy gun: increase timed fuze"],["throttle_down","Heavy gun: decrease timed fuze"],["aa_battery_toggle","Bofors post: toggle battery aim assist; St Elmo gun: gunner relay"],["battery_command","Operate / exit predictor or heavy command station"]],
		"Vehicles":[["throttle_up","Accelerate"],["throttle_down","Brake / reverse"],["rudder_left","Steer left"],["rudder_right","Steer right"],["brake","Brake"],["board","Enter / exit at low speed; recovery truck returns to base"]],
		"Radio":[["wingman_status","Faith, Hope and Charity: request wingman status; unavailable in other modes"]],
		"Recovery":[["call_transport","Request transport after aircraft loss or away from base, if pilot survives"]],
		"General":[["navigation_map","Navigation / on-foot travel; map does not pause"],["confirm_encounter","Spawn random enemy / confirm next encounter or Survival stage"],["pause","Pause / resume (closes Help first)"],["controls_help","Toggle this window; pauses simulation and mission timers"],["reset","Full session restart"],["hud_debug","Toggle HUD diagnostics"],["debug_components","Developer component inspection, when enabled"],["debug_terrain_heatmap","Developer terrain heatmap"],["debug_damage","Developer damage test"]]}
	for heading in sections:
		text+="[color=#e4bf75][b]"+heading+"[/b][/color]\n"
		for entry in sections[heading]:text+="[b]"+binding(entry[0])+"[/b] — "+entry[1]+"\n"
		if heading=="AA Guns":text+="Mouse moves the actual barrel; arrows remain an alternative. Esc settings: sensitivity and Manual / Assisted / Training sights.\nBofors post: hold LMB to fire connected guns; mouse lays the battery. B toggles predictive aim assist. Tab selects a visible target, Enter assigns it for assisted lead, G selects gun/battery scope. RMB zooms. Heavy post: LMB orders a salvo. No autonomous firing.\n"
		text+="\n"
	return text

func suppress_legacy() -> void:
	var old: FlightHUD=session.hud
	if is_instance_valid(old):
		for child in old.get_child(0).get_children():
			if child not in [old.aim_marker,old.enemy_marker,old.enemy_health_widget]:child.hide()
		old.enemy_label.visible=false
	var mission: MaltaMission=session.malta_mission
	if is_instance_valid(mission):
		mission.status.hide();mission.recovery.status.hide()
		if is_instance_valid(session.aa_defence):
			# Nearby 3D equipment captions can fill the screen through the gun camera.
			# The contextual HUD already identifies the only eligible interaction.
			for gun in session.aa_defence.guns:
				var caption: Node=gun.get_node_or_null("FriendlyAALabel")
				if caption!=null:caption.hide()
			for truck in mission.world.trucks:
				for child in truck.get_children():
					if child is Label3D:child.hide()
		if mission.aa_settings.get_parent()!=pause_column:
			var settings: PanelContainer=mission.aa_settings
			settings.reparent(pause_column)
			mission.tree_exiting.connect(func():if is_instance_valid(settings):settings.queue_free())
		mission.aa_settings.visible=get_tree().paused and not help_open and mission.interaction.occupied_gun!=null
	for controller in [session.interception,session.harbour,session.aa_defence]:
		if is_instance_valid(controller):controller.objective.hide()
	session.encounters.status.hide();session.encounters.confirm_button.hide()
	GameAudioMixer.instance.audio_button.visible=not active() or (get_tree().paused and not help_open)

func _process(delta: float) -> void:
	root.visible=active()
	if not root.visible:
		if help_open:close_help()
		age=0;previous_objective="";GameAudioMixer.instance.audio_button.show();return
	var identity: int=session.malta_mission.get_instance_id() if is_instance_valid(session.malta_mission) else session.hud.get_instance_id()
	if identity!=tracked_session:
		tracked_session=identity;age=0;previous_objective="";last_notice="";notice_clock=0;completion_time=0
	suppress_legacy()
	if not get_tree().paused:age+=delta;completion_time=maxf(0,completion_time-delta);notice_clock=maxf(0,notice_clock-delta)
	var mission: MaltaMission=session.malta_mission
	var player: FlightAircraft=mission.occupied if is_instance_valid(mission) else session.aircraft
	var alive: bool=not is_instance_valid(mission) or mission.survival.alive()
	var playing: bool=not get_tree().paused and alive
	confirm_action.visible=playing and session.encounters.awaiting_confirmation and not session.encounters.ended and not session.encounters.complete
	confirm_action.disabled=session.encounters.spawning
	confirm_action.text=("Confirm next stage · " if session.game_mode=="survival" else "Spawn next enemy · ")+binding("confirm_encounter")
	pause_panel.visible=get_tree().paused and not help_open
	
	if get_tree().paused:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	help.visible=help_open
	vital.text="Pilot · %d HP"%ceili(mission.pilot.health.hp) if is_instance_valid(mission) else ""
	if is_instance_valid(player):vital.text="%s · %d HP"%[player.display_name,ceili(player.health.hp)]
	parts.visible=is_instance_valid(player)
	if parts.visible:
		parts.refresh(player.components)
		parts.diagram.visible=get_viewport().get_visible_rect().size.x>=1100
		parts.grid.columns=6 if get_viewport().get_visible_rect().size.x>=1100 else 4
	instruments.visible=is_instance_valid(player)
	if instruments.visible:instruments.text="%d km/h    AGL %d m    Power %d%%    Gear %s    Fuel %d%%"%[roundi(player.airspeed*3.6),roundi(player.altitude),roundi(player.pilot.throttle*100),"down" if player.gear.extended else "up",roundi(player.components.fuel_remaining*100)]
	if is_instance_valid(mission) and mission.interaction.occupied_gun!=null:
		var gun: BritishAAGun=mission.interaction.occupied_gun
		vital.text="%s · %d HP   |   Pilot %d HP"%["Command post" if gun is AACommandStation else "AA gun",gun.hp,ceili(mission.pilot.health.hp)]
		instruments.show()
		instruments.text="\n".join(Array(gun.status_text().split("\n")).slice(0,3)) if gun is AACommandStation else ("Ready" if gun.cooldown<=0 else "Reload %.1f s"%gun.cooldown)
	elif is_instance_valid(mission) and mission.interaction.occupied_vehicle!=null:
		instruments.show();instruments.text="Truck · %d km/h"%roundi(absf(mission.interaction.occupied_vehicle.speed)*3.6)
	var context: String="foot"
	if is_instance_valid(mission):
		if is_instance_valid(mission.occupied):context="aircraft:%d"%mission.occupied.get_instance_id()
		elif is_instance_valid(mission.interaction.occupied_gun):context="gun:%d"%mission.interaction.occupied_gun.get_instance_id()
		elif is_instance_valid(mission.interaction.occupied_vehicle):context="truck:%d"%mission.interaction.occupied_vehicle.get_instance_id()
		if not alive or mission.interaction.mission_ended():context="ended"
	if context!=interaction_context:
		interaction_context=context;notice_clock=0
		last_notice=mission.notice.split("\n")[0].left(100) if is_instance_valid(mission) else ""
	actions.text=context_actions();actions.visible=playing and not actions.text.is_empty()
	update_objective()
	keep_markers_clear()
	if is_instance_valid(mission) and mission.notice_time>0 and mission.notice.split("\n")[0].left(100)!=last_notice:
		last_notice=mission.notice.split("\n")[0].left(100);notice_clock=4
	notification.text=binding("controls_help")+" — Controls" if age<5 else (last_notice if notice_clock>0 else "")
	if is_instance_valid(player) and player.stalled:notification.text="Stall — lower the nose"
	notification.visible=playing and context!="ended" and not notification.text.is_empty()
	debug.text="DEBUG · mode %s · active enemies %d · session %d"%[session.game_mode,session.encounters.active.size(),session.session_number]

func keep_markers_clear() -> void:
	if not tracker.visible:return
	var reserved: Rect2=tracker.get_global_rect().grow(8)
	var markers: Array[Control]=[]
	if is_instance_valid(session.hud):markers.append(session.hud.enemy_health_widget)
	for widget in session.encounters.enemy_widgets.values():markers.append(widget)
	for marker in markers:
		if marker.is_visible_in_tree() and marker.get_global_rect().intersects(reserved):marker.position.y=reserved.end.y+8

func context_actions() -> String:
	var mission: MaltaMission=session.malta_mission
	var hints: Array[String]=[]
	if is_instance_valid(mission):
		var interaction: AirfieldInteraction=mission.interaction
		if not mission.survival.alive() or interaction.mission_ended():return ""
		if is_instance_valid(mission.occupied):
			var plane: FlightAircraft=mission.occupied
			if plane.is_crashed or plane.is_destroyed or (plane.gear.contact_count>0 and plane.airspeed<=mission.maximum_exit_speed and not plane.engine_running and plane.pilot.throttle<=.01):hints.append(binding("board")+" — Leave aircraft")
			if session.game_mode=="harbour" and not session.harbour.is_finished() and session.harbour.wingman_radio.cooldown<=0 and not session.harbour.radio.has_group("wingman_status"):hints.append(binding("wingman_status")+" — Radio status")
		elif is_instance_valid(interaction.occupied_gun):
			var gun: BritishAAGun=interaction.occupied_gun
			hints.append(binding("battery_command" if gun is AACommandStation else "board")+" — Exit "+("post" if gun is AACommandStation else "gun"))
			if gun is BoforsCommandPost:
				hints.append(binding("aa_fire")+" — Fire battery")
				hints.append(binding("aa_battery_toggle")+" — Assist "+("on" if gun.battery_aim_assist else "off"))
			hints.append(binding("aa_zoom")+ (" — Designate / aim estimate" if gun is AACommandStation and not gun is BoforsCommandPost else " — Optics zoom"))
		elif is_instance_valid(interaction.occupied_vehicle):
			if absf(interaction.occupied_vehicle.speed)<=mission.maximum_exit_speed and interaction.occupied_vehicle.grounded:hints.append(binding("board")+" — Exit truck")
		else:
			var command: BritishAAGun=interaction.nearest_command()
			var object: Node3D=interaction.nearest()
			if command!=null:hints.append(binding("battery_command")+" — Operate "+("Bofors predictor" if command is BoforsCommandPost else "heavy command post"))
			elif object!=null:hints.append(binding("board")+" — "+("Mount AA gun" if object is BritishAAGun else ("Enter truck" if object is MilitaryTruck else "Enter aircraft")))
		if not interaction.is_operating() and mission.recovery.state=="IDLE" and mission.recovery.available():hints.append(binding("call_transport")+" — Call transport")
		elif not interaction.is_operating() and mission.recovery.state=="READY" and is_instance_valid(mission.recovery.truck):
			var anchor: Node3D=mission.occupied if is_instance_valid(mission.occupied) else mission.pilot
			var offset: Vector3=mission.recovery.truck.global_position-anchor.global_position
			hints.append("Pickup · %d m · %03d°"%[roundi(offset.length()),roundi(fposmod(rad_to_deg(atan2(offset.x,-offset.z)),360))])
		elif not interaction.is_operating() and mission.recovery.state in ["REQUESTED","ARRIVING"]:hints.append("Transport · "+mission.recovery.state.to_lower())
	return "    ·    ".join(hints.slice(0,4))

func update_objective() -> void:
	var current: String="";var details: String="";var heading: String=""
	var director: Node=session.interception
	if is_instance_valid(director):
		heading="DEFEND VALLETTA"
		if director.phase=="CHECKPOINT":
			var anchor: Node3D=session.malta_mission.occupied if is_instance_valid(session.malta_mission.occupied) else session.malta_mission.pilot
			current="Reach checkpoint %d/%d"%[director.checkpoint_index+1,director.definition.checkpoint_positions.size()]
			details="%d m · timer not started"%roundi(anchor.global_position.distance_to(director.current_checkpoint()))
		elif director.phase=="ACTIVE":
			current="Intercept bomber and escort" if not director.bomber_destroyed else ("Destroy the remaining escort" if not director.escort_destroyed else "Hold until time expires")
			var seconds:=ceili(director.remaining_seconds());details="Time remaining: %02d:%02d\nEnemy aircraft remaining: %d"%[seconds/60,seconds%60,int(not director.bomber_destroyed)+int(not director.escort_destroyed)]
		else:current="Mission complete" if director.success else "Mission failed"
	elif is_instance_valid(session.harbour):
		director=session.harbour;heading="FAITH, HOPE AND CHARITY"
		current={"TAKEOFF":"Board Faith and take off","REGROUP":"Regroup over the harbour","SUCCESS":"Harbour defended","FAILED":"Mission failed"}.get(director.phase,"Intercept the incoming bombers")
		details="Wave %d/3 · enemies %d\nSt Elmo %d HP · St Angelo %d HP"%[maxi(director.wave,1),session.encounters.active.size(),ceili(director.forts[0].hp),ceili(director.forts[1].hp)]
	elif is_instance_valid(session.aa_defence):
		director=session.aa_defence;heading="UNDER DIVE-BOMBER ATTACK"
		current="Mount an AA gun" if director.phase=="WAIT_MOUNT" and not is_instance_valid(session.malta_mission.interaction.occupied_gun) else ("Mission complete" if director.phase=="SUCCESS" else ("Mission failed" if director.phase=="FAILED" else "Defend the position"))
		var surviving: int=director.guns.filter(func(gun):return not gun.is_destroyed).size()
		details="Wave %d/6 · aircraft remaining %d\nOperational guns: %d"%[maxi(director.wave,1),director.alive.size(),surviving]
		if director.phase in ["PREPARING","INTERVAL"]:details+=" · next wave %d s"%ceili(director.clock)
		elif director.phase=="DRAINING":details+=" · ordnance clearing"
	elif session.game_mode=="survival":
		heading="MALTA SURVIVAL";var encounter: EnemyEncounters=session.encounters
		current="Survival Complete" if encounter.complete else ("Run ended" if encounter.ended else ("Stage cleared — confirm next stage" if encounter.awaiting_confirmation else "Destroy the attacking aircraft"))
		details="Stage %d/5 · enemies remaining: %d"%[encounter.stage,encounter.active.size()]
	if is_instance_valid(session.malta_mission) and session.malta_mission.return_flow.pending:
		var returning: MissionReturn=session.malta_mission.return_flow
		current="Return and land at "+session.malta_mission.world.fields[returning.destination].record.name
		var anchor: Node3D=session.malta_mission.occupied if is_instance_valid(session.malta_mission.occupied) else session.malta_mission.pilot
		details="Objectives secured · %d m\nLand at a friendly airfield and slow below %d km/h"%[roundi(anchor.global_position.distance_to(returning.objective_point())),roundi(returning.maximum_landing_speed*3.6)]
	tracker.visible=not current.is_empty()
	if not current.is_empty() and previous_objective!="" and previous_objective!=current:completion_time=2
	completion.text="✓ Previous objective complete" if completion_time>0 and "failed" not in current.to_lower() and "ended" not in current.to_lower() else ""
	completion.visible=not completion.text.is_empty()
	previous_objective=current;title.text=heading;objective.text=current;supporting.text=details

func _exit_tree() -> void:
	if instance==self:instance=null
