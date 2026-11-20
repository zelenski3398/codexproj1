extends SceneTree

var game: Node3D
var raid: StElmoRaid
var failures: int
var checks: int

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS: " if condition else "FAIL: ") + description)

func restart() -> void:
	game.restart_malta()
	await frames(8)
	raid = game.stuka_sortie

func release_over(point: Vector3, height: float = 60.0) -> RaidBomb:
	raid.player.freeze = true
	raid.player.global_basis = Basis.IDENTITY
	raid.player.global_position = point + Vector3(0, height, 0.43)
	raid.player.linear_velocity = Vector3.ZERO
	return raid.player.release_bomb()

func await_bomb(bomb: RaidBomb) -> void:
	for i in range(900):
		if not is_instance_valid(bomb): return
		await physics_frame
	check(false, "Bomb resolved inside the expected test time")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.show_missions()
	game.missions_menu._choose_mission(3)
	game.missions_menu.mission_picker.select(3)
	game.missions_menu._launch()
	await frames(12)
	raid = game.stuka_sortie
	if raid == null:
		check(false, "Mission menu creates the raid")
		quit(1)
		return
	check(game.game_mode == "st_elmo_raid" and raid.player.engine_running and raid.player.airspeed > 45 and raid.player.loaded_bomb.visible, "Mission menu launches a powered airborne Stuka with its bomb attached")
	check(raid.radio.seen.has("brief") and ResourceLoader.exists("res://assets/audio/raid/commander_brief.ogg"), "Opening radio event has a generated German recording")
	check(raid.range_scenery.sections.size() >= 14, "Fort has independently damageable target, parapets and representative buildings")
	var target: BombStructureSection = raid.range_scenery.sections[RaidRange.TARGET_WEST]
	var other: BombStructureSection = raid.range_scenery.sections[RaidRange.TARGET_EAST]
	raid.interceptor_delay = 0.1
	await frames(30)
	check(is_instance_valid(raid.interceptor) and raid.radio.seen.has("intercept"), "Configurable scramble spawns and announces the interceptor")
	raid.interceptor.freeze = true
	raid.player.freeze = true
	await frames(2)
	raid.player.global_basis = Basis.IDENTITY
	raid.player.global_position = Vector3(14000, 450, 1900)
	raid.interceptor.global_position = raid.player.global_position + Vector3(0, 10, -130)
	await frames(10)
	var gunner := raid.player.rear_gunner
	check(gunner.status == "OUTSIDE REAR ARC" and gunner.guns.salvo_count == 0, "Rear gunner will not fire forward")
	raid.interceptor.global_position = raid.player.global_position + Vector3(0, 35, 110)
	await frames(240)
	check(gunner.guns.salvo_count > 0, "Rear gunner observes and fires controlled bursts at a hostile aircraft")
	check(absf(gunner.yaw) <= deg_to_rad(gunner.horizontal_arc_degrees) and gunner.elevation <= deg_to_rad(gunner.maximum_elevation_degrees), "Gun animation stays inside the physical traverse")
	raid.interceptor.global_position = Vector3(14000, 450, 2400)
	var hangar_sections := get_nodes_in_group("bomb_structure_sections").filter(func(section): return String(section.section_id).begins_with("luqa_hangar_0_roof"))
	check(hangar_sections.size() >= 4, "Procedural airfield hangar roofs are sectioned during Stuka sorties")
	var impact := target.global_position
	var hit := release_over(impact)
	check(hit != null and not raid.player.loaded_bomb.visible and raid.bomb_in_flight and raid.player.release_bomb() == null, "Release removes the model and the mission cannot reload")
	check(absf(hit.global_position.x - impact.x) < 0.1 and hit.carrier == raid.player.get_rid(), "Bomb starts at the hardpoint with the carrier excluded")
	await await_bomb(hit)
	check(raid.stars == 2 and not raid.interceptor.is_destroyed, "Physical target hit earns two stars with the interceptor alive")
	check(target.hp == 0 and target.solid.disabled and other.hp < other.maximum_hp, "Direct roof collapses and nearby roof takes blast damage")
	var space := target.get_world_3d().direct_space_state
	var collapsed_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(impact + Vector3.UP * 4, impact - Vector3.UP * 4, 1))
	check(not collapsed_hit.is_empty() and collapsed_hit.position.y < impact.y, "The old roof collision is gone")
	var old_range := raid.range_scenery.get_instance_id()
	await restart()
	check(raid.range_scenery.get_instance_id() != old_range and raid.stars == -1 and raid.player.bomb_ready and raid.range_scenery.sections[RaidRange.TARGET_WEST].hp == 100, "Retry rebuilds ordnance, target health and score")
	raid.spawn_interceptor()
	raid.interceptor.take_damage(1000)
	check(raid.stars == -1 and raid.player.bomb_ready, "Fighter destroyed first keeps the bombing objective active")
	await await_bomb(release_over(Vector3(14000, 0, 2200)))
	check(raid.stars == 1, "Fighter destroyed first, then physical water miss earns one star")

	await restart()
	raid.spawn_interceptor()
	raid.interceptor.freeze = true
	await await_bomb(release_over(Vector3(14000, 0, 2200)))
	check(raid.stars == -1 and raid.objective_text() == "Destroy the Gladiator", "A miss with a living interceptor keeps the mission active")
	raid.interceptor.take_damage(1000)
	check(raid.stars == 1, "Miss followed by fighter destruction earns one star")

	await restart()
	var falling := release_over(raid.range_scenery.sections[RaidRange.TARGET_WEST].global_position)
	raid.player.take_damage(1000)
	await frames(3)
	check(raid.stars == -1 and raid.bomb_in_flight, "Aircraft loss does not score while a bomb is still falling")
	await await_bomb(falling)
	check(raid.stars == 2, "Qualifying impact after aircraft loss still earns two stars")

	await restart()
	raid.player._crash("test crash carrying the bomb")
	await frames(4)
	check(raid.stars == 0 and not raid.bomb_resolved, "Crash carrying the bomb gives no bombing credit")
	await restart()
	raid.spawn_interceptor()
	raid.interceptor.take_damage(1000)
	raid.player._crash("test crash after fighter kill")
	await frames(3)
	check(raid.stars == 0 and not raid.bomb_resolved, "Fighter kill and unreleased bomb do not qualify as a missed bombing attempt")
	game.return_to_missions()
	game.show_selection(false)
	game.show_malta_selection()
	game.malta_menu._choose_kind(game.malta_menu.fighter_picker.item_count - 1)
	game.malta_menu.depart()
	await frames(10)
	raid = game.stuka_sortie
	check(raid != null and not raid.raid_mode and raid.player.reserve_bombs, "The Malta aircraft picker launches Stuka free roam")
	var range_roof: BombStructureSection = raid.range_scenery.sections[RaidRange.TARGET_WEST]
	var deliberate := release_over(range_roof.global_position)
	check(raid.player.reload_remaining > 14.0, "Free roam starts a 15-second reload")
	raid.player._physics_process(15.0)
	var second := raid.player.release_bomb()
	check(raid.player.reserve_bombs and is_instance_valid(deliberate) and is_instance_valid(second), "Reload does not remove the previous falling bomb")
	await await_bomb(deliberate)
	check(range_roof.hp < range_roof.maximum_hp, "Free-roam target damage persists across drops")
	raid.player._physics_process(15.0)
	check(raid.player.bomb_ready and raid.player.loaded_bomb.visible, "Repeated reload restores the visible bomb")
	await restart()
	check(raid.player.reserve_bombs and raid.range_scenery.sections[RaidRange.TARGET_WEST].hp == 100 and get_nodes_in_group("raid_debris").is_empty(), "Free-roam restart clears damaged sections and debris")
	print("Raid checks: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
