extends SceneTree
## Live scene integration: swept collision, real key events, bounded pools,
## health thresholds, engine-off physics, and reset of all new components.
var aircraft: FlightAircraft
var world: Node3D
var failures: int = 0
var checks: int = 0
var destruction_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	aircraft = world.aircraft
	aircraft.destroyed.connect(func(): destruction_count += 1)
	await _frames(3)
	_check(aircraft.health.hp == 100 and world.hud.hp_bar.value == 100 and world.hud.hp_label.text == "HP: 100/100", "Aircraft starts with 100 HP and visible numeric/bar health")
	var ports: Array[Marker3D] = aircraft.model.gun_ports
	_check(ports.size() == 8, "Eight firing origins exist")
	var correct: bool = true
	for i in range(4):
		var left: Vector3 = ports[i].position
		var right: Vector3 = ports[i + 4].position
		var t: float = absf(left.x) / 5.6
		var edge: float = -0.35 + t * 0.45 - 2.35 * sqrt(1 - t * t) * 0.5
		correct = correct and left.x < -2 and right.x > 2 and absf(left.x + right.x) < 0.01 and absf(left.z - (edge - 0.08)) < 0.01
	_check(correct, "Four symmetric ports per wing lie on the leading edge, not the nose")
	var convergence: Vector3 = aircraft.global_position - aircraft.global_basis.z * aircraft.guns.convergence_distance
	_check(aircraft.guns.shot_direction(ports[0]).dot((convergence - ports[0].global_position).normalized()) > 0.9999, "Convergence directions aim toward the configured aircraft-relative point")
	aircraft.guns.convergence_distance = 0
	_check(aircraft.guns.shot_direction(ports[0]).dot(-aircraft.global_basis.z) > 0.9999, "Disabling convergence makes guns parallel")
	aircraft.guns.convergence_distance = 250
	# Actual Ctrl events with modifiers must not suppress W, arrows or A/D.
	_key(KEY_CTRL, true)
	_key(KEY_W, true, true)
	_key(KEY_LEFT, true, true)
	_key(KEY_A, true, true)
	await _frames(30)
	_check(aircraft.guns.pool.total_spawned >= 24 and aircraft.guns.pool.total_spawned % 8 == 0, "Holding Ctrl repeatedly fires all eight guns")
	_check(aircraft.pilot.throttle > 0.05 and aircraft.pilot.roll == 1 and aircraft.pilot.rudder == 1, "Firing with Ctrl held preserves throttle, roll and rudder input")
	_check(aircraft.health.hp == 100, "Rounds exclude the firing aircraft's collision RID")
	_key(KEY_CTRL, false)
	_key(KEY_W, false)
	_key(KEY_LEFT, false)
	_key(KEY_A, false)
	await _frames(2)
	var count: int = aircraft.guns.pool.total_spawned
	await _frames(30)
	_check(aircraft.guns.pool.total_spawned == count, "Releasing Ctrl stops firing")
	_key(KEY_CTRL, true, true, false, true)
	await _frames(3)
	_check(aircraft.guns.pool.total_spawned > count, "Keycode-only Ctrl forwarded by embedded views fires guns")
	_key(KEY_CTRL, false, false, false, true)
	_key(KEY_H, true, false, false, true)
	_key(KEY_H, false, false, false, true)
	await _frames(3)
	_check(aircraft.health.hp == 90, "Keycode-only H applies one debug damage hit")
	# A real flight fixture makes steering response measurable, not just input.
	await _fixture(Vector3(-75, 100, 620), Vector3(0, 0, -65))
	aircraft.pilot.fire = true
	aircraft.pilot.roll = 0.4
	aircraft.pilot.throttle = 0.7
	var starting_salvos: int = aircraft.guns.salvo_count
	await _frames(150)
	_check(absi(aircraft.guns.salvo_count - starting_salvos - roundi(aircraft.guns.rounds_per_second * 1.25)) <= 1, "Configured firing rate is maintained across physics ticks")
	_check(absf(aircraft.global_basis.x.y) > 0.2 and aircraft.guns.pool.total_spawned > count + 80, "Aircraft banks physically while sustained guns keep firing")
	aircraft.pilot.fire = false
	await _frames(300)
	_check(aircraft.guns.pool.active.is_empty() and aircraft.guns.pool.free.size() == aircraft.guns.pool.capacity, "Expired bullets return to their bounded pool")
	# Align at the live practice panel. 850 m/s rounds hit its 25 cm thickness
	# even though one physics-step travel is over 7 m.
	await _fixture(Vector3(-75, 12, 620), Vector3.ZERO)
	aircraft.pilot.fire = true
	await _frames(90)
	aircraft.pilot.fire = false
	_check(world.practice_target.health.hp < 500 and aircraft.guns.pool.total_hits > 0, "Swept projectiles damage the airfield target")
	var impact_visible: bool = false
	for spark in aircraft.guns.pool.sparks:
		impact_visible = impact_visible or spark.visible
	_check(impact_visible, "Hits display pooled world-space impact effects")
	# Explicit overshoot: a single 30,000 m/s step crosses the whole thin target.
	var before: float = world.practice_target.health.hp
	aircraft.guns.pool.clear()
	aircraft.guns.pool.spawn(Vector3(-75, 12, 450), Vector3(0, 0, -30000), 1.0, 7.0, aircraft.get_rid(), true)
	await _frames(3)
	_check(world.practice_target.health.hp == before - 7, "Very fast bullets cannot tunnel and apply their configured damage exactly")
	# Reset, then exercise H as a press/release key (repeat must do nothing).
	await _fixture(Vector3(0, 100, 620), Vector3(0, 0, -55))
	aircraft.pilot.automated = false
	_key(KEY_H, true)
	_key(KEY_H, true, false, true)
	_key(KEY_H, false)
	await _frames(3)
	_check(aircraft.health.hp == 90, "H removes 10 HP once per press and ignores auto-repeat")
	for i in range(4):
		_key(KEY_H, true)
		_key(KEY_H, false)
		await _frames(2)
	await _frames(30)
	_check(aircraft.health.hp == 50 and not aircraft.damage_effects.emitting and aircraft.damage_effects.active_count() == 0, "Exactly 50 HP: neither smoke nor fire emits")
	aircraft.take_damage(1)
	await _frames(60)
	var smoke_visible: bool = false
	var flame_visible: bool = false
	for i in range(aircraft.damage_effects.particles.size()):
		if aircraft.damage_effects.particles[i].visible:
			smoke_visible = smoke_visible or aircraft.damage_effects.is_smoke[i]
			flame_visible = flame_visible or not aircraft.damage_effects.is_smoke[i]
	_check(aircraft.health.hp == 49 and aircraft.damage_effects.emitting and smoke_visible and flame_visible, "49 HP starts both visible engine smoke and fire")
	var low_intensity: float = aircraft.damage_effects.intensity
	aircraft.take_damage(29)
	_check(aircraft.damage_effects.intensity > low_intensity, "Damage effect intensity increases as HP decreases")
	var smoke_index: int = -1
	for i in range(aircraft.damage_effects.particles.size()):
		if aircraft.damage_effects.particles[i].visible and aircraft.damage_effects.is_smoke[i]:
			smoke_index = i
			break
	var particle_position: Vector3 = aircraft.damage_effects.particles[smoke_index].global_position
	var plane_position: Vector3 = aircraft.global_position
	await _frames(12)
	var smoke_travel: float = aircraft.damage_effects.particles[smoke_index].global_position.distance_to(particle_position)
	_check(aircraft.damage_effects.top_level and smoke_travel < aircraft.global_position.distance_to(plane_position) * 0.6, "Smoke remains behind the moving aircraft in world space")
	aircraft.health.heal(30)
	_check(aircraft.health.hp == 50 and not aircraft.damage_effects.emitting, "Healing to exactly 50 stops all new damage emission")
	await _frames(360)
	_check(aircraft.damage_effects.active_count() == 0, "Existing smoke/fire fade out after healing")
	aircraft.health.heal(999)
	_check(aircraft.health.hp == 100, "Healing clamps at maximum HP")
	aircraft.take_damage(-10)
	_check(aircraft.health.hp == 100, "Negative damage cannot increase HP")
	# Stationary at altitude: engine off must permit gravity to cause a fall.
	await _fixture(Vector3(0, 200, 620), Vector3.ZERO)
	aircraft.pilot.throttle = 1
	aircraft.pilot.fire = true
	aircraft.take_damage(999)
	aircraft.take_damage(10)
	var destroyed_y: float = aircraft.global_position.y
	await _frames(120)
	_check(aircraft.health.hp == 0 and aircraft.is_destroyed and destruction_count == 1, "HP clamps at zero and destruction occurs exactly once")
	_check(aircraft.pilot.throttle == 0 and aircraft.guns.pool.active.is_empty(), "Destroyed aircraft cannot fire or power its engine")
	_check(aircraft.global_position.y < destroyed_y - 3 and aircraft.linear_velocity.y < -5 and not aircraft.freeze, "Destroyed aircraft falls under existing rigid-body physics")
	_check(world.hud.overlay.visible and world.hud.overlay_title.text == "DESTROYED" and world.hud.hp_bar.value == 0, "Destruction displays 0 HP, destroyed message and reset controls")
	await _frames(30)
	_check(aircraft.damage_effects.active_count() > 0, "Engine damage effects remain active on the wreck")
	# Reset while Ctrl is held clears shots and does not immediately refire.
	aircraft.pilot.automated = false
	_key(KEY_CTRL, true)
	aircraft.request_reset()
	await _frames(5)
	_check(aircraft.health.hp == 100 and not aircraft.is_destroyed and not aircraft.is_crashed, "Reset restores 100 HP and normal aircraft state")
	var flashes_cleared: bool = true
	for flash in aircraft.guns.flashes:
		flashes_cleared = flashes_cleared and not flash.visible
	for spark in aircraft.guns.pool.sparks:
		flashes_cleared = flashes_cleared and not spark.visible
	_check(aircraft.guns.pool.active.is_empty() and flashes_cleared and aircraft.damage_effects.active_count() == 0 and not aircraft.damage_effects.emitting, "Reset immediately clears bullets, flashes and damage effects")
	_check(world.practice_target.health.hp == 500, "Reset also repairs the practice target")
	aircraft.pilot.automated = false
	_key(KEY_CTRL, false)
	await _frames(2)
	_key(KEY_CTRL, true)
	_key(KEY_W, true, true)
	await _frames(60)
	_check(aircraft.pilot.throttle > 0.1 and aircraft.guns.pool.active.size() > 0, "Throttle and firing work again after reset and trigger release")
	_key(KEY_CTRL, false)
	_key(KEY_W, false)
	# Stress sustained fire above capacity: slots are recycled, never allocated.
	await _fixture(Vector3(0, 300, 620), Vector3.ZERO)
	aircraft.pilot.fire = true
	await _frames(1200)
	_check(aircraft.guns.pool.total_spawned > aircraft.guns.pool.capacity and aircraft.guns.pool.active.size() <= aircraft.guns.pool.capacity and aircraft.guns.pool.dropped_rounds == 0, "Sustained firing recycles the fixed pool without dropped rounds")
	print("WEAPONS RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _fixture(position: Vector3, velocity: Vector3) -> void:
	aircraft.request_reset()
	aircraft.pending_reset_pose = Transform3D(Basis.IDENTITY, position)
	aircraft.pending_reset_velocity = velocity
	aircraft.pilot.automated = true
	await _frames(5)
	aircraft.gear.extended = false
	await _frames(2) # allow trigger release to arm guns

func _key(code: Key, pressed: bool, control: bool = false, echo: bool = false, logical_only: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = 0 if logical_only else code
	event.keycode = code
	event.ctrl_pressed = control or (code == KEY_CTRL and pressed)
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
