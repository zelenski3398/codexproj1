class_name BritishAAGun
extends StaticBody3D
## Supportive, finite-speed British flak. Fuzed bursts are gameplay abstraction.
@export var max_hp: float = 150
@export var range_metres: float = 2400
@export var projectile_speed: float = 700
@export var rounds_per_second: float = 1.4
@export var maximum_lifetime: float = 4
@export var direct_damage: float = 22
@export var aim_error_degrees: float = 1.15
@export var reaction_seconds: float = 1.5
@export var traverse_degrees: float = 65
@export var elevation_degrees: float = 35
var hp: float = 150
var is_destroyed: bool = false
var battery: AirfieldAABattery
var target: FlightAircraft
var yaw: Node3D
var elevation: Node3D
var muzzle: Node3D
var elevation_origin: Vector3
var sound: AudioStreamPlayer3D
var flash: MeshInstance3D
var scan_time: float = 0
var reaction: float = 0
var cooldown: float = 0
var recoil: float = 0
var shots_fired: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("friendly_aa")
	rng.randomize()
	hp = max_hp
	collision_layer = 1
	collision_mask = 0
	var asset: PackedScene = load("res://assets/ground/british_aa/British_AA_Emplacement.glb")
	var model := asset.instantiate()
	add_child(model)
	_cull_visuals(model)
	yaw = model.find_child("YawPivot", true, false)
	elevation = model.find_child("ElevationPivot", true, false)
	muzzle = model.find_child("Muzzle", true, false)
	elevation_origin = elevation.position
	# Sparse solid shapes, not hundreds of individual sandbag collisions.
	for spec in [Vector3(6.8,0.8,0.6),Vector3(1.9,2.0,1.9)]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec
		shape.shape = box
		shape.position = Vector3(0,0.4,2.8) if spec.x > 3 else Vector3(0,1,0)
		add_child(shape)
	flash = MeshKit.sphere(muzzle, Vector3.ONE * 0.35, Vector3.ZERO, MeshKit.material(Color("ffdf98")))
	flash.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.visible = false
	sound = AudioStreamPlayer3D.new()
	sound.stream = load(GameAudioMixer.SPITFIRE_GUNS)
	sound.bus = "Guns"
	sound.volume_db = -13
	sound.pitch_scale = 0.65
	sound.unit_size = 25
	sound.max_distance = 2000
	sound.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	muzzle.add_child(sound)

func get_team_id() -> int:
	return CombatTeams.PLAYER

func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0 or not is_finite(amount): return
	hp = clampf(hp - amount, 0, max_hp)
	if hp == 0:
		is_destroyed = true
		target = null
		sound.stop()
		flash.visible = false
		battery.effects.puff(global_position + Vector3.UP, "air", 2)

func _select_target() -> void:
	var best: FlightAircraft = null
	var score := INF
	for aircraft in battery.candidates():
		var distance := global_position.distance_to(aircraft.global_position)
		if distance > range_metres: continue
		var assigned := 0
		for other in battery.guns:
			if other != self and other.target == aircraft and not other.is_destroyed: assigned += 1
		var value := distance + assigned * 750
		if aircraft == target: value -= 350
		if value < score:
			score = value
			best = aircraft
	if target != best: reaction = reaction_seconds
	target = best

func clear_line(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position, point, 15, [get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return true
	if hit.collider is AircraftHitbox: return hit.collider.damage_system.aircraft == target
	return hit.collider == target

func _physics_process(delta: float) -> void:
	if is_destroyed: return
	cooldown -= delta
	reaction -= delta
	recoil = maxf(0, recoil - delta * 0.7)
	elevation.position = elevation_origin + Vector3(0,0,recoil)
	flash.visible = recoil > 0.08
	scan_time -= delta
	if scan_time <= 0:
		scan_time = 0.45 + rng.randf() * 0.15
		_select_target()
	if not is_instance_valid(target) or target.is_destroyed: return
	var time := muzzle.global_position.distance_to(target.global_position) / projectile_speed
	var aim := target.global_position + target.linear_velocity * time * 0.94
	var local: Vector3 = global_basis.inverse() * (aim - yaw.global_position)
	var desired_yaw := atan2(-local.x, -local.z)
	var desired_elevation := atan2(local.y, Vector2(local.x,local.z).length())
	yaw.rotation.y = rotate_toward(yaw.rotation.y, desired_yaw, deg_to_rad(traverse_degrees) * delta)
	elevation.rotation.x = move_toward(elevation.rotation.x, clampf(desired_elevation, deg_to_rad(8), deg_to_rad(85)), deg_to_rad(elevation_degrees) * delta)
	if reaction > 0 or cooldown > 0 or desired_elevation < deg_to_rad(8): return
	var forward: Vector3 = -muzzle.global_basis.z
	if forward.angle_to((aim - muzzle.global_position).normalized()) > deg_to_rad(3) or not clear_line(aim): return
	var spread := deg_to_rad(aim_error_degrees)
	var direction := (forward + muzzle.global_basis.x * rng.randfn(0,spread) + muzzle.global_basis.y * rng.randfn(0,spread)).normalized()
	var endpoint := muzzle.global_position + direction * projectile_speed * time
	if not clear_line(endpoint): return
	if battery.projectiles.spawn(muzzle.global_position, direction * projectile_speed, clampf(time + rng.randf_range(-0.06,0.06),0.1,maximum_lifetime), direct_damage, get_rid(), true, CombatTeams.PLAYER):
		shots_fired += 1
		cooldown = 1 / rounds_per_second
		recoil = 0.12
		battery.effects.puff(muzzle.global_position, "muzzle", 0.25)
		if GameAudioMixer.instance.playback_enabled: sound.play()

func _cull_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		node.visibility_range_end = 3500
		node.visibility_range_end_margin = 250
	for child in node.get_children(): _cull_visuals(child)
