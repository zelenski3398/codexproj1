class_name HarbourInterception
extends Node3D
## Fictional harbour defence. Existing forces, bullets, component HP and bombs.
signal finished(success: bool, reason: String)
@export var definition: HarbourDefinition = preload("res://mission_definitions/harbour.tres")
var session: Node3D
var phase: String = "TAKEOFF"
var player_sea_crash: bool = false
var wave: int = 0
var roster: AircraftWaveRoster
var bomber: EnemyAircraft
var escorts: Array[EnemyAircraft] = []
var wingmen: Array[FriendlyGladiator] = []
var friendly_ids: Array[int] = []
var bomber_stopped: bool = false
var wingman_states: Dictionary = {"Hope":"OPERATIONAL", "Charity":"OPERATIONAL"}
var forts: Array[FortObjective] = []
var target_fort: FortObjective
var wingman_radio: WingmanRadio
var radio: MissionRadioQueue
var effects: Node3D
var canvas: CanvasLayer
var objective: Label
var marker: Label
var friendly_markers: Array[Label] = []
var results: PanelContainer
var result_label: Label
var retry_button: Button
var return_button: Button
var airborne_clock: float = 0
var wave_clock: float = 0
var clock: float = 0
var scan_clock: float = 0
var withdrawal_clock: float = -1
var attack_warned: bool = false
var payload_released: bool = false
var payload_remaining: int = 0
var payload_clock: float = 0
var bombs_released: int = 0
var bombers_intercepted: int = 0
var escorts_destroyed: int = 0
var player_kills: int = 0
var friendly_kills: int = 0
var other_losses: int = 0
var escaped_escorts: int = 0
var result_count: int = 0
var final_reason: String = ""
var wave_spawn_counts: Array[int] = []
var cancelled: bool = false
var _resolution_queued: bool = false

func _ready() -> void:
	effects = Node3D.new()
	add_child(effects)
	_build_ui()
	radio = MissionRadioQueue.new()
	radio.definition = definition
	add_child(radio)
	call_deferred("_prepare")

func _prepare() -> void:
	if cancelled: return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mission_definitions/harbour_forts.json"))
	for record in data.forts:
		var fort := FortObjective.new()
		fort.title = record.title
		fort.maximum_hp = definition.fort_max_hp
		for point in record.footprint: fort.footprint.append(Vector2(point[0], point[1]))
		add_child(fort)
		fort.global_position = Vector3(record.centre[0], 0, record.centre[1])
		fort.global_position.y = _ground(fort.global_position)
		fort.destroyed.connect(_queue_resolution)
		forts.append(fort)
	var faith: FlightAircraft = session.aircraft
	faith.display_name = "Faith · Sea Gladiator"
	faith.destroyed.connect(_queue_resolution)
	for aircraft in session.malta_mission.fleet:
		aircraft.crashed.connect(_player_crashed.bind(aircraft))
	session.malta_mission.pilot.combat_enabled = true
	session.malta_mission.pilot.health.depleted.connect(_queue_resolution)
	var field: MaltaAirfield = session.field.fields.hal_far
	for i in 2:
		var friend := FriendlyGladiator.new()
		friend.callsign = "Hope" if i == 0 else "Charity"
		friend.name = friend.callsign
		friend.reset_position = field.to_global(Vector3(0, 1.18, field.runway_length * (.41 + i * .08)))
		add_child(friend)
		friend.request_reset()
		friend.pending_reset_pose = Transform3D(field.global_basis * Basis(Vector3.RIGHT, .117), friend.reset_position)
		friend.ai.leader = faith
		friend.ai.formation_offset = Vector3(-160 if i == 0 else 160, 35 + i * 30, 160 + i * 80)
		friend.ai.takeoff_delay = i * 12
		friend.ai.takeoff_direction = -field.global_basis.z
		friend.destroyed.connect(_wingman_lost.bind(friend.callsign))
		friend.tree_exiting.connect(_wingman_retired.bind(i))
		wingmen.append(friend)
		friendly_ids.append(friend.get_instance_id())
	wingman_radio = WingmanRadio.new()
	wingman_radio.director = self
	add_child(wingman_radio)
	_cue("intro", "Faith, Hope and Charity: take off from Ħal Far. Protect St Elmo and St Angelo; intercept bombers before release.", definition.intro_voice, true)
	session.malta_mission._message("Faith · E board your Sea Gladiator · I engine · W power · Hope and Charity follow after takeoff")

func _ground(point: Vector3) -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x, 3000, point.z), Vector3(point.x, -100, point.z), 1))
	return float(hit.position.y) if not hit.is_empty() else 0

func is_finished() -> bool: return cancelled or phase in ["SUCCESS", "FAILED"]

func _physics_process(delta: float) -> void:
	# Released ordnance keeps falling after failure; later bombs still require a live bomber.
	if payload_remaining > 0 and is_instance_valid(bomber) and not bomber.is_destroyed:
		payload_clock -= delta
		if payload_clock <= 0:
			_drop_bomb()
			payload_clock += definition.payload_interval
	if is_finished() or forts.size() != 2: return
	_queue_resolution()
	var faith: FlightAircraft = session.aircraft
	if phase == "TAKEOFF":
		var flying: bool = session.malta_mission.occupied == faith and faith.gear.contact_count == 0 and faith.altitude >= definition.takeoff_activation_agl
		airborne_clock = airborne_clock + delta if flying else 0
		if airborne_clock >= definition.takeoff_activation_seconds:
			for friend in wingmen:
				if is_instance_valid(friend): friend.ai.takeoff_hold = false
			phase = "SPAWNING"
			call_deferred("_spawn_wave")
	elif phase == "ACTIVE":
		wave_clock += delta
		scan_clock -= delta
		if scan_clock <= 0:
			_assign_targets()
			scan_clock = .4
		if is_instance_valid(bomber) and not bomber.is_destroyed and not payload_released:
			var route: BomberPilot = bomber.ai
			var seconds: float = bomber.global_position.distance_to(route.route_end) / maxf(definition.bomber_speed, 1)
			if not attack_warned and seconds < definition.attack_warning_seconds:
				attack_warned = true
				_cue("attack_%d" % wave, "Bomber lining up on %s — stop it before release!" % target_fort.title)
			if route.arrived: _release_payload()
			elif wave_clock > definition.bomber_watchdog_seconds:
				_finish(false, "Bomber could not be intercepted — contact lost beyond the mission boundary")
		if bomber_stopped:
			if withdrawal_clock < 0: withdrawal_clock = 0
			withdrawal_clock += delta
			if withdrawal_clock >= definition.escort_engagement_seconds:
				_order_withdrawal()
				_retire_withdrawn()
	elif phase == "REGROUP":
		clock = maxf(clock - delta, 0)
		if clock == 0:
			phase = "SPAWNING"
			call_deferred("_spawn_wave")

func _spawn_wave() -> void:
	if phase != "SPAWNING" or is_finished(): return
	if not _player_alive() or forts.any(func(f): return f.hp <= 0):
		_queue_resolution()
		return
	wave += 1
	if wave > 3:
		_finish(false, "Invalid wave configuration")
		return
	target_fort = forts[0] if wave == 1 else forts[1]
	if wave == 3: target_fort = forts[0] if forts[0].hp <= forts[1].hp else forts[1]
	var player: FlightAircraft = session.aircraft
	var inward: Vector3 = ((target_fort.global_position - player.global_position) * Vector3(1, 0, 1)).normalized()
	if inward.length_squared() < .1: inward = Vector3.FORWARD
	# Crossing inbound formation rather than a faster bomber fleeing directly ahead.
	var start: Vector3 = player.global_position - inward * definition.incoming_distance * .65 + inward.cross(Vector3.UP) * definition.incoming_distance * .76
	var outward: Vector3 = ((start - target_fort.global_position) * Vector3(1, 0, 1)).normalized()
	if start.distance_to(target_fort.global_position) < 3800: start = target_fort.global_position + outward * 3800
	start.y = maxf(maxf(player.global_position.y + 60, definition.approach_height), _ground(start) + 220)
	var direction: Vector3 = ((target_fort.global_position - start) * Vector3(1, 0, 1)).normalized()
	var composition := AircraftWaveRoster.composition(wave)
	var planned: Array[Vector3] = [start]
	for i in composition.size() - 1:
		var point: Vector3 = start + direction.cross(Vector3.UP) * (i - 1) * definition.escort_separation - direction * (200 + (i % 2) * 130)
		point.y = maxf(start.y + 45 + i * 35, _ground(point) + 220)
		planned.append(point)
	for i in planned.size():
		if not _spawn_safe(planned[i], planned, i):
			_finish(false, "Formation spawn obstructed — retry mission")
			return
	roster = AircraftWaveRoster.new()
	roster.removed.connect(_enemy_removed)
	escorts.clear()
	for i in composition.size():
		var item: Dictionary = composition[i]
		# Ace parameters applied explicitly here; normal pilots remain unchanged.
		var foe: EnemyAircraft = session.create_encounter_enemy(planned[i], false, item.kind)
		foe.encounter_ace = item.ace
		foe.marker_name = "SM.79 BOMBER" if i == 0 else ("ACE CR.42" if item.ace else "CR.42 ESCORT")
		foe.pending_reset_pose = Transform3D(Basis.looking_at(direction), planned[i])
		foe.pending_reset_velocity = direction * definition.bomber_speed
		if i == 0:
			bomber = foe
			var route: BomberPilot = bomber.ai
			# Inherited-velocity ballistic release point: aim the falling payload at the fort.
			var fall: float = sqrt(2 * maxf(start.y - target_fort.global_position.y, 1) / 9.81)
			var release: Vector3 = target_fort.global_position - direction * definition.bomber_speed * fall
			release.y = start.y
			route.arrival_radius = 28
			route.pace_minimum_speed = definition.bomber_speed
			route.pace_maximum_speed = definition.bomber_speed
			route.assign_route(start, release, start.distance_to(release) / definition.bomber_speed)
		else:
			foe.ai.get_parent().remove_child(foe.ai)
			foe.ai.queue_free()
			var ai := HarbourCombatPilot.new()
			ai.aircraft = foe
			ai.leader = bomber
			ai.departed = true
			ai.formation_offset = Vector3((i - 2) * 180, 45 + i * 25, 200)
			ai.measured_terrain = true
			ai.world_extent = INF
			ai.grace_period = 0
			ai.detection_range = 2400
			ai.pursuit_release_range = 3200
			ai.aim_seed += wave * 100 + i
			if item.ace:
				ai.aim_error_degrees *= definition.ace_aim_scale
				ai.pursuit_prediction_seconds = 5
				foe.guns.spread_degrees *= definition.ace_dispersion_scale
			foe.ai = ai
			foe.add_child(ai)
			escorts.append(foe)
		session.encounters.track_enemy(foe)
		roster.register(foe)
	wave_spawn_counts.append(composition.size())
	bomber_stopped = false
	attack_warned = false
	payload_released = false
	withdrawal_clock = -1
	wave_clock = 0
	phase = "ACTIVE"
	session.encounter_tracking_changed()
	_assign_targets()
	_cue("wave_%d" % wave, "Formation %d detected: bomber heading for %s. %s" % [wave, target_fort.title, "Two ace escorts — stay together!" if wave == 3 else "Three fighter escorts."])

func _spawn_safe(point: Vector3, planned: Array[Vector3], index: int) -> bool:
	if point.distance_to(session.aircraft.global_position) < definition.minimum_player_separation: return false
	for i in index:
		if point.distance_to(planned[i]) < 95: return false
	var sphere := SphereShape3D.new()
	sphere.radius = 25
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 7
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()

func _assign_targets() -> void:
	if roster == null: return
	var defenders: Array[FlightAircraft] = []
	if _player_alive() and session.malta_mission.occupied == session.aircraft: defenders.append(session.aircraft)
	for friend in wingmen:
		if is_instance_valid(friend) and not friend.is_destroyed and not friend.is_crashed and friend.ai.departed: defenders.append(friend)
	var assigned: Dictionary = {}
	for i in wingmen.size():
		if not is_instance_valid(wingmen[i]): continue
		var friend: FriendlyGladiator = wingmen[i]
		if not is_instance_valid(friend) or friend.is_destroyed: continue
		friend.ai.leader = session.aircraft
		var selected: FlightAircraft
		var score: float = INF
		for foe in roster.active:
			if not is_instance_valid(foe) or foe.is_destroyed: continue
			var d: float = friend.global_position.distance_to(foe.global_position)
			var priority: float = .8 if foe == bomber else 1
			if foe == bomber and foe.global_position.distance_to(target_fort.global_position) < 2300: priority = .30
			var value: float = d * priority + float(assigned.get(foe.get_instance_id(), 0)) * 850
			if value < score and d < 4400: score = value; selected = foe
		friend.ai.target = selected
		friend.guns.telemetry_target = selected
		if selected != null: assigned[selected.get_instance_id()] = int(assigned.get(selected.get_instance_id(), 0)) + 1
	var counts: Dictionary = {}
	for escort in escorts:
		if not is_instance_valid(escort) or escort.is_destroyed or not roster.active.has(escort): continue
		var ai: HarbourCombatPilot = escort.ai
		if ai.withdrawing: continue
		var selected: FlightAircraft
		var score: float = INF
		for defender in defenders:
			# Keep live-bomber protection central; distributed threats inside its leash.
			if is_instance_valid(bomber) and not bomber.is_destroyed and defender.global_position.distance_to(bomber.global_position) > 2500: continue
			var d: float = escort.global_position.distance_to(defender.global_position)
			var value: float = d + float(counts.get(defender.get_instance_id(), 0)) * (700 if escort.encounter_ace else 350)
			if value < score and d < 3100: score = value; selected = defender
		ai.target = selected
		escort.target = selected
		escort.guns.telemetry_target = selected
		if selected != null: counts[selected.get_instance_id()] = int(counts.get(selected.get_instance_id(), 0)) + 1
	if is_instance_valid(bomber) and not bomber.is_destroyed:
		var nearest: FlightAircraft
		var distance: float = INF
		for defender in defenders:
			var d: float = defender.global_position.distance_to(bomber.global_position)
			if d < distance: distance = d; nearest = defender
		bomber.ai.target = nearest
		bomber.target = nearest

func _enemy_removed(foe: EnemyAircraft, killed: bool) -> void:
	if is_finished(): return
	if killed:
		if foe == bomber:
			bomber_stopped = true
			if not payload_released: bombers_intercepted += 1
		else: escorts_destroyed += 1
		var source: int = int(foe.get_meta("last_hostile_shooter_id", 0))
		var recent: bool = Engine.get_physics_frames() - int(foe.get_meta("last_hostile_hit_frame", -100000)) < Engine.physics_ticks_per_second * 20
		if recent and source == session.aircraft.get_instance_id(): player_kills += 1
		elif recent and friendly_ids.has(source): friendly_kills += 1
		else: other_losses += 1
	else: escaped_escorts += 1
	_queue_resolution()

func _wingman_lost(callsign: String) -> void:
	if cancelled or wingman_states[callsign] == "LOST": return
	wingman_states[callsign] = "LOST"
	if is_finished(): return
	_cue("lost_" + callsign, callsign + " is down. Faith, continue the interception.")

func _wingman_retired(index: int) -> void:
	wingmen[index] = null

func _order_withdrawal() -> void:
	for escort in escorts:
		if not is_instance_valid(escort) or escort.is_destroyed: continue
		var ai: HarbourCombatPilot = escort.ai
		if ai.withdrawing: continue
		ai.withdrawing = true
		ai.target = null
		var outward: Vector3 = ((escort.global_position - target_fort.global_position) * Vector3(1, 0, 1)).normalized()
		if outward.length_squared() < .1: outward = Vector3.RIGHT
		ai.withdrawal_goal = escort.global_position + outward * 16000 + Vector3.UP * 120
	_cue("withdraw_%d" % wave, "Surviving escorts are withdrawing. Escaped aircraft are not counted as kills.")

func _retire_withdrawn() -> void:
	for escort in escorts:
		if not is_instance_valid(escort) or not roster.active.has(escort): continue
		var separated: bool = escort.global_position.distance_to(session.aircraft.global_position) > definition.withdrawal_distance
		if not separated and withdrawal_clock < definition.escort_engagement_seconds + definition.withdrawal_timeout: continue
		roster.resolve(escort, false)
		session.encounters.active.erase(escort)
		var id: int = escort.get_instance_id()
		if session.encounters.enemy_widgets.has(id):
			session.encounters.enemy_widgets[id].queue_free()
			session.encounters.enemy_widgets.erase(id)
		escort.queue_free()
	session.encounter_tracking_changed()

func _release_payload() -> void:
	if payload_released or phase != "ACTIVE" or not is_instance_valid(bomber) or bomber.is_destroyed or bomber.is_crashed: return
	payload_released = true
	payload_remaining = definition.payload_count
	payload_clock = 0
	_drop_bomb()
	payload_clock = definition.payload_interval
	# Continue physically beyond the fort along the assigned course.
	var route: BomberPilot = bomber.ai
	route.route_end = bomber.global_position + route.route_direction * 15000
	route.route_start = bomber.global_position
	route.route_elapsed = 0
	route.route_duration = 300
	route.arrived = false
	_finish(false, "Bomber released its payload on %s — interception failed" % target_fort.title)

func _drop_bomb() -> void:
	if payload_remaining <= 0 or not is_instance_valid(bomber) or bomber.is_destroyed: return
	var bomb := MissionBomb.new()
	bomb.velocity = bomber.linear_velocity
	bomb.impact_effects = effects
	bomb.fort_blast_radius = definition.bomb_blast_radius
	bomb.fort_blast_damage = definition.bomb_damage
	effects.add_child(bomb)
	bomb.global_position = bomber.to_global(Vector3(0, -1.4, 1))
	payload_remaining -= 1
	bombs_released += 1

func _player_alive() -> bool:
	return session.malta_mission.pilot.health.hp > 0

func _player_crashed(_reason: String, aircraft: FlightAircraft) -> void:
	# Only the currently occupied aircraft can cause the mission's sea loss.
	# Water is set by the real swept surface check before crashed is emitted.
	if session.malta_mission.occupied == aircraft and aircraft.impact_effects.water:
		player_sea_crash = true
	_queue_resolution()

func _queue_resolution() -> void:
	if _resolution_queued or is_finished(): return
	_resolution_queued = true
	call_deferred("_resolve")

func _resolve() -> void:
	_resolution_queued = false
	if is_finished(): return
	if not _player_alive(): _finish(false, "Faith lost — harbour defence failed"); return
	if player_sea_crash: _finish(false, "Aircraft lost at sea — harbour defence failed"); return
	if forts.any(func(f): return f.hp <= 0): _finish(false, "A defended fort has been destroyed"); return
	if phase != "ACTIVE" or roster == null or not roster.active.is_empty(): return
	if not bomber_stopped: return
	if wave == 3:
		_finish(bombers_intercepted == 3, "All three formations resolved — both forts defended")
	else:
		phase = "REGROUP"
		clock = definition.regroup_seconds
		_cue("regroup_%d" % wave, "Formation cleared. Regroup with surviving wingmen; hold position for the next wave.")

func _cue(id: String, text: String, voice: AudioStream = null, summary: bool = false) -> void:
	if voice == null: voice = definition.cue_voices.get(id)
	if id.begins_with("attack_") or id.begins_with("lost_"):
		radio.urgent_cue(id, text, voice)
	else:
		radio.cue(id, text, voice, summary)

func _finish(won: bool, reason: String) -> void:
	if is_finished(): return
	phase = "SUCCESS" if won else "FAILED"
	final_reason = reason
	result_count += 1
	session.encounters.ended = true
	session.encounters.awaiting_confirmation = false
	for unit in session.encounters.active + wingmen:
		if not is_instance_valid(unit): continue
		unit.ai.target = null
		unit.ai.combat_enabled = false
		unit.pilot.fire = false
		unit.guns.reset(false)
		if unit is EnemyAircraft:
			unit.target = null
			unit.rear_gunner.cease_fire()
			unit.rear_gunner.enabled = false
			if unit is ItalianEnemy:
				for gunner in unit.additional_gunners:
					gunner.cease_fire()
					gunner.enabled = false
	results.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_results()
	radio.cue("success" if won else "failure", "All three bombers intercepted. Both forts stand. Well done, Faith, Hope and Charity." if won else reason, definition.success_voice if won else definition.cue_voices.get("failure"), won, true)
	finished.emit(won, reason)

func _update_results() -> void:
	var survivors: int = wingman_states.values().filter(func(s): return s != "LOST").size()
	result_label.text = "%s\n%s\n\nBombers intercepted: %d/3\nEscorts destroyed: %d · withdrawn: %d\nPlayer kills: %d · friendly AI kills: %d\nOther losses: %d · surviving wingmen: %d/2\nSt Elmo: %d/%d HP · St Angelo: %d/%d HP" % ["HARBOUR DEFENDED" if phase == "SUCCESS" else "MISSION FAILED", final_reason, bombers_intercepted, escorts_destroyed, escaped_escorts, player_kills, friendly_kills, other_losses, survivors, ceili(forts[0].hp), ceili(forts[0].maximum_hp), ceili(forts[1].hp), ceili(forts[1].maximum_hp)]

func cancel() -> void:
	cancelled = true
	radio.stop()
	for friend in wingmen:
		if is_instance_valid(friend): friend.pilot.fire = false; friend.guns.reset()

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)
	objective = Label.new()
	objective.position = Vector2(400, 25)
	objective.size = Vector2(560, 170)
	objective.add_theme_font_size_override("font_size", 16)
	objective.add_theme_color_override("font_color", Color("ffe1a0"))
	objective.add_theme_color_override("font_shadow_color", Color.BLACK)
	objective.add_theme_constant_override("shadow_offset_x", 2)
	objective.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(objective)
	marker = Label.new()
	marker.add_theme_color_override("font_color", Color("ff946a"))
	canvas.add_child(marker)
	for i in 2:
		var label := Label.new()
		label.add_theme_color_override("font_color", Color("94e8e4"))
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		canvas.add_child(label)
		friendly_markers.append(label)
	results = PanelContainer.new()
	results.position = Vector2(330, 240)
	results.custom_minimum_size = Vector2(670, 300)
	canvas.add_child(results)
	var col := VBoxContainer.new()
	results.add_child(col)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 20)
	col.add_child(result_label)
	retry_button = Button.new()
	retry_button.text = "RETRY FROM ĦAL FAR · R"
	retry_button.pressed.connect(func(): session.call_deferred("restart_malta"))
	col.add_child(retry_button)
	return_button = Button.new()
	return_button.text = "RETURN TO MISSIONS"
	return_button.pressed.connect(func(): session.call_deferred("return_to_missions"))
	col.add_child(return_button)
	results.hide()

func _marker(label: Label, point: Vector3, text: String, edge: bool) -> void:
	var camera := get_viewport().get_camera_3d()
	label.hide()
	if camera == null: return
	var screen := get_viewport().get_visible_rect()
	if not edge and camera.is_position_behind(point): return
	var local: Vector3 = camera.to_local(point)
	var uv: Vector2 = camera.unproject_position(point) if local.z < -.1 else screen.size * .5 + Vector2(local.x, -local.y).normalized() * screen.size.length()
	label.position = Vector2(clampf(uv.x - 90, 15, screen.size.x - 260), clampf(uv.y - 30, 210, screen.size.y - 270))
	label.text = text
	label.show()

func _process(_delta: float) -> void:
	if forts.size() != 2: return
	if results.visible: _update_results()
	for friend in wingmen:
		if is_instance_valid(friend) and not friend.is_destroyed: wingman_states[friend.callsign] = "DAMAGED" if friend.health.hp < 75 else "OPERATIONAL"
	objective.text = "FAITH, HOPE AND CHARITY · WAVE %d/3\nIntercept the bombers before they release their bombs.\nSt Elmo %d/%d HP · St Angelo %d/%d HP\nHope: %s · Charity: %s\n%s" % [maxi(wave, 1), ceili(forts[0].hp), ceili(forts[0].maximum_hp), ceili(forts[1].hp), ceili(forts[1].maximum_hp), wingman_states.Hope, wingman_states.Charity, ("I engine · taxi and take off; wingmen follow" if session.malta_mission.occupied != null else "E board Faith · I engine · take off; wingmen follow") if phase == "TAKEOFF" else ("Regroup · next formation in %d s" % ceili(clock) if phase == "REGROUP" else phase)]
	marker.hide()
	if is_instance_valid(bomber) and not bomber.is_destroyed:
		_marker(marker, bomber.global_position + Vector3.UP * 20, "▼ SM.79 → %s · %d m" % [target_fort.title, roundi(session.aircraft.global_position.distance_to(bomber.global_position))], true)
	for i in friendly_markers.size():
		friendly_markers[i].hide()
		if i < wingmen.size() and is_instance_valid(wingmen[i]) and not wingmen[i].is_destroyed:
			_marker(friendly_markers[i], wingmen[i].global_position + Vector3.UP * 8, "◆ %s · %d HP · %d m" % [wingmen[i].callsign.to_upper(), ceili(wingmen[i].health.hp), roundi(session.aircraft.global_position.distance_to(wingmen[i].global_position))], true)

			if i > 0 and friendly_markers[0].visible and absf(friendly_markers[i].position.y - friendly_markers[0].position.y) < 24 and absf(friendly_markers[i].position.x - friendly_markers[0].position.x) < 260:
				friendly_markers[i].position.y -= 24
