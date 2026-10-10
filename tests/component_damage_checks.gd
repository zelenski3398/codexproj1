extends SceneTree
## Model-specific swept sensor hits and force-driven damage/AI behavior.
var world: Node3D
var player: FlightAircraft
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.start_flight("spitfire")
	player = world.aircraft
	player.pilot.automated = true
	world.enemy.ai.combat_enabled = false
	await _frames(6)
	for kind in ["spitfire", "sea_gladiator", "stuka"]:
		var target: FlightAircraft = _make_target(kind)
		await _frames(6)
		target.freeze = true
		await _frames(3)
		_check(target.components.hitboxes.size() == 8 and target.components.integrity.size() == 8 and target.components.hitbox_rids.size() == 8, kind + ": eight independently damageable components")
		var safe: bool = true
		for hitbox in target.components.hitboxes:
			safe = safe and hitbox.collision_layer == AircraftHitbox.LAYER and hitbox.collision_mask == 0 and not hitbox.monitoring
		_check(safe and target.collision_layer != AircraftHitbox.LAYER, kind + ": hitboxes are sensors, separate from landing/body contact")
		for id in AircraftDamage.IDS:
			target.components.reset()
			target.health.reset()
			var definition: AircraftComponentDefinition = target.components.definitions[id]
			var spec: DamageHitboxSpec = definition.hitboxes[-1] if id == &"fuselage" and kind != "sea_gladiator" else definition.hitboxes[0]
			var normal: Vector3 = Vector3.RIGHT if id in [&"fuselage", &"engine", &"rudder"] else Vector3.DOWN if id == &"fuel_tank" else Vector3.UP
			var origin: Vector3 = target.to_global(spec.position + normal * 15)
			var velocity: Vector3 = -(target.global_basis * normal) * 30000
			var pool: ProjectilePool = player.guns.pool
			var shooter: FlightAircraft = player if target.team_id != player.team_id else world.enemy
			pool.spawn(origin, velocity, 0.02, 7, shooter.get_rid(), true, shooter.team_id)
			await _frames(3)
			var expected: float = definition.max_integrity - 7 * definition.damage_multiplier
			_check(target.components.last_hit == id and is_equal_approx(float(target.components.integrity[id]), expected) and is_equal_approx(target.health.hp, 100 - 7 * definition.airframe_multiplier), kind + ": swept bullet identifies " + String(id) + " and applies local/hull multipliers")
			var others_healthy: bool = true
			for other in AircraftDamage.IDS:
				if other != id:
					others_healthy = others_healthy and target.components.integrity_ratio(other) == 1
			_check(others_healthy, kind + ": " + String(id) + " hit preserves unrelated components")
			var spark: bool = false
			for effect in pool.sparks:
				spark = spark or effect.visible
			_check(spark, kind + ": component hit retains pooled impact sparks")
		if kind == "sea_gladiator":
			for upper in [false, true]:
				target.components.reset()
				target.health.reset()
				var spec: DamageHitboxSpec = (target.components.definitions[&"right_wing"] as AircraftComponentDefinition).hitboxes[2 if upper else 0]
				var normal: Vector3 = Vector3.UP if upper else Vector3.DOWN
				player.guns.pool.spawn(target.to_global(spec.position + normal * 10), -(target.global_basis * normal) * 30000, 0.02, 4, world.enemy.get_rid(), true, CombatTeams.ENEMY)
				await _frames(3)
				_check(target.components.last_hit == &"right_wing", "Gladiator upper/lower hits share the correct wing-side integrity")
		# Rotated targets still use model-local hitboxes, not world-space zones.
		target.freeze = false
		target.request_reset()
		target.pending_reset_pose = Transform3D(Basis.from_euler(Vector3(0.2, 0.7, -0.4)), Vector3(1800, 400, 1500))
		await _frames(4)
		target.freeze = true
		await _frames(3)
		var engine: DamageHitboxSpec = (target.components.definitions[&"engine"] as AircraftComponentDefinition).hitboxes[0]
		var shooter: FlightAircraft = player if target.team_id != player.team_id else world.enemy
		player.guns.pool.spawn(target.to_global(engine.position + Vector3.RIGHT * 15), -target.global_basis.x * 30000, 0.02, 5, shooter.get_rid(), true, shooter.team_id)
		await _frames(3)
		_check(target.components.last_hit == &"engine", kind + ": hitboxes follow pitch, bank and heading")
		target.components.reset()
		target.health.reset()
		target.guns.pool.spawn(target.to_global(engine.position + Vector3.RIGHT * 15), -target.global_basis.x * 30000, 0.02, 100, target.get_rid(), true, target.team_id)
		await _frames(3)
		_check(target.health.hp == 100 and target.components.integrity_ratio(&"engine") == 1 and target.components.last_hit == &"", kind + ": owner body and all owner hitboxes are excluded")
		player.guns.pool.spawn(target.to_global(engine.position + Vector3.RIGHT * 15), -target.global_basis.x * 30000, 0.02, 100, player.get_rid(), true, target.team_id)
		await _frames(3)
		_check(target.health.hp == 100 and target.components.integrity_ratio(&"engine") == 1, kind + ": same-team hits cannot damage components or hull")
		await _physical_trials(target, kind)
		await _fuel_trials(target, kind)
		target.queue_free()
		await _frames(3)

	# Production enemy compensates using bounded commands in real flight.
	var enemy: EnemyAircraft = world.enemy
	enemy.request_reset()
	enemy.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(-450, 300, 0))
	enemy.pending_reset_velocity = Vector3(0, 0, -58)
	await _frames(5)
	enemy.ai.patrol_center.y = 300
	enemy.ai.evade_on_damage = false
	var healthy_throttle: float = enemy.pilot.throttle
	enemy.components.apply_damage(&"left_wing", 20)
	enemy.components.apply_damage(&"engine", 10)
	enemy.components.apply_damage(&"elevator", 10)
	enemy.components.apply_damage(&"rudder", 10)
	var minimum: float = INF
	var max_step: float = 0
	var trim: float = 0
	var previous_roll: float = enemy.pilot.roll
	for tick in range(3600):
		await physics_frame
		minimum = minf(minimum, enemy.altitude)
		trim = maxf(trim, absf(enemy.ai.roll_trim))
		max_step = maxf(max_step, absf(enemy.pilot.roll - previous_roll))
		previous_roll = enemy.pilot.roll
	print("Damaged AI altitude=", minimum, " roll trim=", trim, " throttle=", enemy.pilot.throttle)
	_check(not enemy.is_destroyed and minimum > 120 and trim > 0.01 and enemy.airspeed > 35, "Damaged Stuka uses measured bank/altitude feedback to survive 30 seconds")
	_check(enemy.pilot.throttle > healthy_throttle and max_step <= enemy.ai.command_slew_rate / 120.0 + 0.001, "AI increases throttle/trim with bounded ordinary pilot commands")
	_check(enemy.components.integrity_ratio(&"left_wing") < 1 and enemy.components.power_factor() < 1 and enemy.health.hp < 100, "Compensation cannot repair parts or restore lost power")

	_key(KEY_F3, true)
	_key(KEY_F3, false)
	await _frames(3)
	await process_frame
	_check(world.component_debug.enabled and world.component_debug.panel.visible and player.components.debug_visible and enemy.components.debug_visible, "F3 shows both aircraft hitboxes and the inspector")
	world.component_debug.target_picker.select(1)
	world.component_debug._on_selection_changed(1)
	world.component_debug.part_picker.select(3)
	world.component_debug.apply_selected_damage()
	_check(enemy.components.power_factor() < 1 and player.components.power_factor() == 1 and world.component_debug.health_text.text.contains("Ju 87 Stuka"), "Inspector switches to and damages the enemy without affecting the player")
	world.component_debug.repair_selected()
	world.component_debug.target_picker.select(0)
	world.component_debug._on_selection_changed(0)
	world.component_debug.part_picker.select(3)
	world.component_debug.apply_selected_damage()
	_check(player.components.last_hit == &"engine" and player.components.power_factor() < 1 and world.component_debug.health_text.text.contains("Engine"), "Debug selector damages the chosen player component")
	world.component_debug.repair_selected()
	world.component_debug.part_picker.select(7)
	world.component_debug.force_fuel.button_pressed = true
	world.component_debug.apply_selected_damage()
	_check(player.components.fuel_leaking and player.components.fuel_burning and player.damage_effects.fuel_emitting, "Debug fuel override gives deterministic hazard testing")
	paused = true
	var fuel: float = player.components.fuel_remaining
	for frame in range(15):
		await process_frame # Unpause outside the physics-frame callback.
	_check(player.components.fuel_remaining == fuel and world.component_debug.panel.visible, "Pause freezes hazards while the inspector stays usable")
	world.component_debug.repair_selected()
	_check(player.components.fuel_remaining == 1 and not player.components.fuel_burning and player.health.hp == 100 and player.damage_effects.active_count() == 0, "Live-aircraft debug repair clears mechanical damage and hazards")
	paused = false
	player.components.apply_damage(&"left_wing", 20)
	enemy.components.apply_damage(&"right_wing", 20)
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(6)
	enemy = world.enemy
	_check(player.components.lift_factor() == 1 and enemy.components.lift_factor() == 1 and player.components.power_factor() == 1 and player.components.fuel_remaining == 1 and player.health.hp == 100, "R restores all components, fuel and hull for both aircraft")
	_key(KEY_F3, true)
	_key(KEY_F3, false)
	await _frames(3)
	await process_frame
	_check(not world.component_debug.enabled and not player.components.debug_visible and not enemy.components.debug_visible, "Hidden visualization leaves hit detection active")
	_key(KEY_F3, true, true)
	_key(KEY_F3, false, true)
	await _frames(3)
	_check(world.component_debug.enabled and player.components.debug_visible, "Keycode-only F3 from embedded views also opens the inspector")
	world.show_selection()
	_check(world.component_debug == null and world.aircraft == null, "Aircraft switching removes the old inspector and hitboxes")
	world.start_flight("sea_gladiator")
	await _frames(5)
	_check(world.aircraft.components.integrity_ratio(&"left_wing") == 1 and world.component_debug != null, "Aircraft selection creates an independent healthy framework")
	print("COMPONENT RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _make_target(kind: String) -> FlightAircraft:
	var target: FlightAircraft = EnemyAircraft.new() if kind == "stuka" else SeaGladiator.new() if kind == "sea_gladiator" else FlightAircraft.new()
	target.reset_position = Vector3(1800, 220, 1500)
	target.damage_profile = (load("res://damage_profiles/" + kind + ".tres") as AircraftDamageProfile).duplicate(true) as AircraftDamageProfile
	target.damage_profile.fuel_fire_probability = 0
	target.damage_profile.fuel_leak_probability = 0
	if target is EnemyAircraft:
		target.target = player
	world.add_child(target)
	target.collision_mask = 0
	target.pilot.automated = true
	if target is EnemyAircraft:
		target.ai.combat_enabled = false
		target.ai.set_physics_process(false)
	return target

func _physical_trials(target: FlightAircraft, kind: String) -> void:
	var healthy: Dictionary = await _trial(target)
	var left: Dictionary = await _trial(target, &"left_wing", 20)
	var right: Dictionary = await _trial(target, &"right_wing", 20)
	_check(left.bank > healthy.bank + 0.08 and right.bank < healthy.bank - 0.08 and left.velocity.y < healthy.velocity.y, kind + ": wing loss reduces lift and rolls the actual body toward the damaged side")
	_check(target.components.additional_drag() > 0 and target.components.lift_factor() < 1, kind + ": wings add configurable drag and lift loss")
	healthy = await _trial(target, &"", 0, Vector3.ZERO, 1)
	var damaged: Dictionary = await _trial(target, &"engine", 40, Vector3.ZERO, 1)
	_check(damaged.velocity.z > healthy.velocity.z + 0.2 and target.components.power_factor() < 0.2 and target.health.hp > 0, kind + ": engine damage lowers physical forward acceleration while alive")
	target.components.apply_damage(&"engine", 10)
	_check(target.components.power_factor() == 0 and target.health.hp > 0 and not target.is_destroyed, kind + ": engine failure precedes hull destruction")
	healthy = await _trial(target)
	damaged = await _trial(target, &"fuselage", 50)
	_check(damaged.velocity.z > healthy.velocity.z + 0.06 and target.components.additional_drag() > 0, kind + ": fuselage damage increases aerodynamic drag")
	healthy = await _trial(target, &"", 0, Vector3(0, 0.5, 0))
	damaged = await _trial(target, &"rudder", 30, Vector3(0, 0.5, 0))
	_check(absf(damaged.omega.y) < absf(healthy.omega.y) * 0.7 and target.components.rudder_factor() < 0.3, kind + ": rudder loss reduces actual yaw and fin authority")
	healthy = await _trial(target, &"", 0, Vector3(0.5, 0, 0))
	damaged = await _trial(target, &"elevator", 30, Vector3(0.5, 0, 0))
	_check(absf(damaged.omega.x) < absf(healthy.omega.x) * 0.7 and target.components.elevator_factor() < 0.4, kind + ": elevator loss reduces actual pitch response")
	healthy = await _trial(target, &"", 0, Vector3(0, 0, 0.5))
	damaged = await _trial(target, &"cockpit", 20, Vector3(0, 0, 0.5))
	_check(absf(damaged.omega.z) < absf(healthy.omega.z) * 0.85 and target.components.cockpit_factor() < 1, kind + ": cockpit damage reduces pilot control torque")
	var ratio: float = target.components.cockpit_factor()
	target.health.heal(100)
	_check(target.components.cockpit_factor() == ratio, kind + ": hull healing does not repair mechanical components")

func _trial(target: FlightAircraft, id: StringName = &"", amount: float = 0, commands: Vector3 = Vector3.ZERO, throttle: float = 0) -> Dictionary:
	target.freeze = false
	target.request_reset()
	target.pending_reset_pose = Transform3D(Basis.IDENTITY, Vector3(1800, 500, 1500))
	target.pending_reset_velocity = Vector3(0, 0, -65)
	await _frames(4)
	if target is EnemyAircraft:
		target.ai.set_physics_process(false)
	if target.gear.retractable:
		target.gear.extended = false
	target.pilot.pitch = commands.x
	target.pilot.rudder = commands.y
	target.pilot.roll = commands.z
	target.pilot.throttle = throttle
	if id != &"":
		target.components.apply_damage(id, amount)
	await _frames(90)
	return {"velocity": target.linear_velocity, "omega": target.global_basis.transposed() * target.angular_velocity, "bank": target.global_basis.x.y}

func _fuel_trials(target: FlightAircraft, kind: String) -> void:
	await _trial(target)
	target.components.profile.fuel_leak_probability = 0
	target.components.profile.fuel_fire_probability = 0
	target.components.apply_damage(&"fuel_tank", 10)
	await _frames(30)
	_check(not target.components.fuel_leaking and not target.components.fuel_burning and target.components.fuel_remaining == 1, kind + ": probability zero prevents leak/fire")
	target.components.reset()
	target.health.reset()
	target.components.profile.fuel_leak_probability = 1
	target.components.profile.fuel_fire_probability = 1
	target.components.apply_damage(&"fuel_tank", 10)
	await _frames(120)
	var smoke: bool = false
	var fire: bool = false
	for i in range(target.damage_effects.particles.size()):
		if target.damage_effects.particles[i].visible:
			smoke = smoke or target.damage_effects.is_smoke[i]
			fire = fire or not target.damage_effects.is_smoke[i]
	_check(target.components.fuel_leaking and target.components.fuel_burning and target.components.fuel_remaining < 1 and target.health.hp < 92 and target.health.hp > 50, kind + ": probability one drains fuel and burns hull HP above 50")
	_check(smoke and fire and target.damage_effects.fuel_emitting and not target.damage_effects.emitting, kind + ": tank effects reuse the pool while engine effects retain the <50 rule")
	target.components.profile.fuel_leak_rate = 1
	target.components.profile.fuel_burn_rate = 1
	await _frames(160)
	_check(target.components.fuel_remaining == 0 and target.components.power_factor() == 0 and not target.components.fuel_burning and not target.damage_effects.fuel_emitting, kind + ": empty tank removes power and stops tank emission")
	target.request_reset()
	await _frames(5)
	if target is EnemyAircraft:
		target.ai.set_physics_process(false)
	_check(target.components.fuel_remaining == 1 and not target.components.fuel_leaking and not target.components.fuel_burning and target.damage_effects.active_count() == 0 and target.components.power_factor() == 1, kind + ": reset restores integrity/fuel/power and clears particles")
	target.take_damage(100)
	target.components.apply_damage(&"fuel_tank", 100, Vector3.ZERO, true)
	_check(target.is_destroyed and target.components.last_hit == &"" and not target.components.fuel_burning, kind + ": destroyed aircraft reject component hits and hazard rolls")

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _key(code: Key, pressed: bool, logical_only: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = 0 if logical_only else code
	event.pressed = pressed
	Input.parse_input_event(event)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
