extends SceneTree
## Scripted mission fixtures; damage/ballistics use the real shared components.
var session: Node3D
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func _check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS: " if value else "FAIL: ", message)
func _frames(count: int) -> void:
	for i in count: await physics_frame
func _fresh() -> HarbourInterception:
	if is_instance_valid(session):
		session.queue_free()
		await _frames(3)
	session = preload("res://main.tscn").instantiate()
	root.add_child(session)
	session.start_harbour()
	await _frames(180)
	return session.harbour
func _activate(m: HarbourInterception) -> void:
	m.phase = "SPAWNING"
	m._spawn_wave()
	await _frames(5)
	# Keep branch tests deterministic; navigation tested separately.
	for foe in session.encounters.active:
		foe.ai.set_physics_process(false)
	for friend in m.wingmen: friend.ai.set_physics_process(false)
func _fire_at(shooter: FlightAircraft, victim: EnemyAircraft) -> void:
	var hitbox: AircraftHitbox = victim.components.hitboxes[0]
	# Aim at the actual fuselage sensor, clear of the upper wing and crew.
	# Match target velocity during this short swept-hit fixture. An engine
	# failure alone is deliberately no longer a guaranteed aircraft kill.
	var point: Vector3 = victim.to_global(hitbox.definition.hitboxes[0].position)
	var start: Vector3 = point + victim.global_basis.x * 8
	shooter.guns.pool.spawn(start, victim.linear_velocity - victim.global_basis.x * 900, .2, 1000, shooter.get_rid(), true, shooter.team_id)
	await _frames(25)
func _run() -> void:
	var m := await _fresh()
	_check(session.game_mode == "harbour" and session.malta_mission.home == "hal_far", "New mission uses continuous Malta / Hal Far")
	_check(session.aircraft is SeaGladiator and session.aircraft.display_name.begins_with("Faith"), "Player aircraft is Faith, Sea Gladiator")
	_check(session.malta_mission.occupied == null and not session.aircraft.engine_running and session.aircraft.gear.contact_count > 0, "Ground start preserves manual boarding and engine start")
	_check(m.wingmen.size() == 2 and m.wingmen[0].callsign == "Hope" and m.wingmen[1].callsign == "Charity", "Two named friendly Gladiators")
	_check(m.wingmen.all(func(f): return f.get_team_id() == CombatTeams.PLAYER and f.ai.takeoff_hold and f.gear.contact_count > 0), "Wingmen safely grounded and hold runway until player takes off")
	_check(m.wingmen[0].global_position.distance_to(m.wingmen[1].global_position) > 100, "Wingmen runway positions separated")
	_check(session.encounters.active.is_empty() and m.phase == "TAKEOFF", "No waves before takeoff; AI takeoff does not gate mission progress")
	_check(m.forts.size() == 2 and m.forts.all(func(f): return f.hp == 1000 and Geometry2D.is_point_in_polygon(Vector2(f.global_position.x,f.global_position.z),f.footprint)), "Both fort health receivers use actual geographic footprints")
	_check(m.definition.intro_voice != null and m.definition.success_voice != null and m.definition.intro_voice.get_length() > 18 and m.definition.success_voice.get_length() > 14, "Both supplied commander recordings are assigned")
	_check(m.radio.seen.has("intro") and m.radio.current_id == "intro", "Briefing queued once on mission start")
	_check(session.malta_mission.board_nearest(), "Faith is boardable using existing interaction")
	var world_id: int = session.field.get_instance_id()
	var player_id: int = session.aircraft.get_instance_id()
	session.aircraft.take_damage(10)
	await _activate(m)
	_check(m.wave == 1 and m.wave_spawn_counts == [4] and m.roster.active.size() == 4, "Wave one creates exactly bomber plus three escorts")
	_check(m.bomber.aircraft_kind == "sm79" and m.escorts.all(func(e): return e.aircraft_kind == "cr42" and not e.encounter_ace), "Early-war SM79 / normal CR42 formation")
	_check(m.target_fort == m.forts[0], "Wave one targets Fort St Elmo")
	_check(m.escorts.all(func(e): return e.ai is HarbourCombatPilot and e.ai.leader == m.bomber), "Escorts share flight controller and protect bomber")
	_check(m.bomber.global_position.distance_to(session.aircraft.global_position) >= 1000 and m.bomber.altitude >= 220, "Formation spawns safely away and above terrain")
	m.phase = "SPAWNING" # invalid duplicate request while active would be externally forged; API phase gate below
	m.phase = "ACTIVE"
	m._spawn_wave()
	_check(m.wave == 1 and m.roster.active.size() == 4, "Duplicate wave callback cannot spawn another formation")
	for friend in m.wingmen: friend.ai.departed = true
	m._assign_targets()
	_check(m.wingmen.all(func(f): return f.ai.target != null) and m.wingmen[0].ai.target != m.wingmen[1].ai.target, "Friendly AI distributes live targets")
	_check(m.escorts.any(func(e): return e.ai.target != null), "Escorts acquire nearby player/friendly aircraft")
	_check(not CombatTeams.can_damage(CombatTeams.PLAYER, m.wingmen[0].components.hitboxes[0]), "Shared team filtering prevents friendly damage")
	await _fire_at(m.wingmen[0], m.escorts[0])
	_check(m.escorts[0].is_destroyed and m.friendly_kills == 1 and m.escorts_destroyed == 1, "Real swept friendly projectile kill advances wave statistics")
	var friend: FriendlyGladiator = m.wingmen[0]
	friend.take_damage(1000)
	friend.take_damage(1000)
	_check(m.wingman_states.Hope == "LOST" and m.radio.seen.has("lost_Hope"), "Wingman loss persists and announces once")
	friend.queue_free()
	await _frames(3)
	m._assign_targets()
	_check(m.wingmen[0] == null and m.wingman_states.Hope == "LOST", "Removed wingman wreck retains loss state without stale AI references")
	var old_escort: EnemyAircraft = m.escorts[1]
	await _fire_at(session.aircraft, m.bomber)
	_check(m.bomber.is_destroyed and m.bombers_intercepted == 1 and m.player_kills == 1, "Player swept rounds destroy bomber with accurate last-hit credit")
	m._release_payload()
	_check(m.bombs_released == 0 and not m.payload_released, "Destroyed bomber cannot subsequently release")
	_check(not old_escort.is_destroyed and m.roster.active.has(old_escort), "Bomber loss retains live escorts")
	# Test wreck cleanup before escort withdrawal: no freed-bomber softlock.
	m.bomber.wreck_removed.emit()
	m.bomber.queue_free()
	await _frames(3)
	m.withdrawal_clock = m.definition.escort_engagement_seconds + m.definition.withdrawal_timeout
	m._order_withdrawal()
	m._retire_withdrawn()
	await _frames(5)
	_check(m.phase == "REGROUP" and m.escaped_escorts == 2 and m.escorts_destroyed == 1 and m.player_kills == 1 and m.friendly_kills == 1, "Explicit withdrawal after wreck cleanup progresses, no false kill credit")
	_check(session.field.get_instance_id() == world_id and session.aircraft.get_instance_id() == player_id and session.aircraft.health.hp == 90, "Wave transition preserves world, player and health")
	m.clock = 0
	await _frames(5)
	for foe in session.encounters.active: foe.ai.set_physics_process(false)
	_check(m.wave == 2 and m.wave_spawn_counts == [4,4] and m.roster.active.size() == 4 and m.target_fort == m.forts[1], "Wave two: bomber plus three normal escorts target St Angelo")
	_check(m.wingman_states.Hope == "LOST" and m.wingmen.size() == 2 and m.wingmen[1].health.hp == 100, "No wingman replacement or automatic repairs between waves")
	m.forts[0].take_damage(200)
	for foe in m.roster.active.duplicate(): foe.take_damage(1000)
	await _frames(5)
	m.clock = 0
	await _frames(5)
	for foe in session.encounters.active: foe.ai.set_physics_process(false)
	_check(m.wave_spawn_counts == [4,4,3] and m.wave == 3 and m.target_fort == m.forts[0], "Third wave has exactly three and selects lower-health fort")
	_check(m.escorts.size() == 2 and m.escorts.all(func(e): return e.encounter_ace and e.ai.aim_error_degrees < .05 and e.guns.bullet_damage == EnemyAircraftDefinition.find("cr42").bullet_damage), "Final two escorts are aces with better aim, unchanged projectile damage")
	_check(m.radio.seen.has("wave_3"), "Final ace warning queued")
	for foe in m.roster.active.duplicate(): foe.take_damage(1000)
	await _frames(5)
	_check(m.phase == "SUCCESS" and m.result_count == 1 and m.bombers_intercepted == 3, "All three bombers stopped, waves resolved, forts alive yields success once")
	_check(m.radio.seen.has("success") and m.radio.pending.size() + int(m.radio.current_id != "") == 1, "Success recording replaces pending cues without overlap")
	_check(m.result_label.text.contains("Player kills: 1") and m.result_label.text.contains("friendly AI kills: 1") and m.result_label.text.contains("surviving wingmen: 1/2"), "Result contains kills, survivors and fort health")
	var old_radio: MissionRadioQueue = m.radio
	session.restart_malta()
	await _frames(180)
	m = session.harbour
	_check(not is_instance_valid(old_radio) and m.wave == 0 and m.wingmen.size() == 2 and m.forts.all(func(f): return f.hp == 1000) and session.encounters.active.is_empty(), "Retry clears aircraft, ordnance, radio and restores forts / wingmen / mission")
	await _activate(m)
	m.bomber.ai.arrived = true
	await _frames(5)
	_check(m.phase == "FAILED" and m.payload_released and m.bombs_released == 1 and m.result_count == 1, "Actual bomber arrival releases physical bomb and fails immediately")
	await _frames(240)
	_check(m.bombs_released == m.definition.payload_count and m.effects.get_children().any(func(n):return n is MissionBomb), "Physical bomb sequence continues after failure, not timer-based fort damage")
	var hp_before: float = m.forts[1].hp
	var bomb := MissionBomb.new()
	bomb.fort_blast_radius = 90
	bomb.fort_blast_damage = 520
	bomb.impact_effects = m.effects
	m.effects.add_child(bomb)
	bomb.explode(m.forts[1].global_position)
	bomb.explode(m.forts[1].global_position)
	_check(is_equal_approx(m.forts[1].hp, hp_before - 520), "Physical impact blast damages actual fort once, duplicate explosion guarded")
	m = await _fresh()
	for ally in m.wingmen: ally.take_damage(1000)
	await _frames(3)
	_check(not m.is_finished() and m.wingman_states.Hope == "LOST" and m.wingman_states.Charity == "LOST", "Losing both wingmen does not fail the mission")
	await _activate(m)
	_check(m.wave == 1 and m.roster.active.size() == 4, "Faith can continue the three-wave mission alone")
	m.forts[0].take_damage(1000)
	await _frames(3)
	_check(m.phase == "FAILED" and m.result_count == 1, "Fort destruction immediately fails mission")
	m = await _fresh()
	session.aircraft.take_damage(1000)
	await _frames(3)
	_check(m.phase == "FAILED" and session.encounters.active.is_empty(), "Player destruction fails even before first wave")
	m._spawn_wave()
	_check(session.encounters.active.is_empty(), "No spawning after player loss")
	m = await _fresh()
	session.aircraft.is_crashed = true
	session.aircraft.crashed.emit("Crash fixture")
	await _frames(3)
	_check(m.phase == "FAILED" and m.result_count == 1, "Player crash signal immediately resolves mission failure")
	session.return_to_missions()
	await _frames(5)
	_check(session.harbour == null and session.missions_menu != null and get_nodes_in_group("mission_forts").is_empty(), "Leaving mission removes forts, friendly aircraft and radio")
	session.missions_menu._choose_mission(2)
	_check(session.missions_menu.aircraft_picker.disabled and session.missions_menu.mission_chart.home == "hal_far", "New mission selection locks Faith and geographic Hal Far departure")
	print("HARBOUR RESULT: ", checks - failures, "/", checks, " passed")
	session.queue_free()
	await _frames(5)
	quit(1 if failures else 0)
