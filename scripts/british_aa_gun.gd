class_name BritishAAGun
extends StaticBody3D
## Manual-only British AA. Empty positions never select targets or aim/fire.
signal destroyed
@export var max_hp: float = 150
@export var range_metres: float = 2400
@export var projectile_speed: float = 700
@export var rounds_per_second: float = 2.0
@export var maximum_lifetime: float = 4
@export var direct_damage: float = 22
@export var aim_error_degrees: float = 0.35
@export var traverse_degrees: float = 45
@export var elevation_degrees: float = 30
@export var minimum_elevation_degrees: float = 5
@export var maximum_elevation_degrees: float = 85
@export var fuse_distance: float = 900
var hp: float = 150
var is_destroyed: bool = false
var mounted: bool = false
var operator_session: AirfieldInteraction
var battery: AirfieldAABattery
var yaw: Node3D
var elevation: Node3D
var muzzle: Node3D
var elevation_origin: Vector3
var sound: AudioStreamPlayer3D
var flash: MeshInstance3D
var camera: Camera3D
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
	var label := Label3D.new()
	label.name = "FriendlyAALabel"
	label.text = "FRIENDLY AA · MANUAL"
	label.position = Vector3(0, 4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("acd7ac")
	label.font_size = 30
	label.pixel_size = 0.03
	label.visibility_range_end = 500
	add_child(label)
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
	camera = Camera3D.new()
	camera.name = "GunnerCamera"
	camera.fov = 58
	camera.far = 100000
	# Sight ahead of the barrel tip: gun geometry cannot obstruct this view.
	camera.position = Vector3(0,0.22,-1.0)
	muzzle.add_child(camera)
	sound = AudioStreamPlayer3D.new()
	sound.stream = load("res://assets/audio/aa_cannon_shot.ogg")
	sound.bus = "Guns"
	sound.volume_db = -6
	sound.pitch_scale = 1.0
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
		stop_operation()
		battery.effects.puff(global_position + Vector3.UP, "air", 2)
		destroyed.emit()

func start_operation(operator: AirfieldInteraction = null) -> void:
	if is_destroyed: return
	mounted = true
	operator_session = operator
	camera.make_current()

func stop_operation() -> void:
	mounted = false
	operator_session = null
	sound.stop()
	flash.visible = false
	recoil = 0
	elevation.position = elevation_origin

func _physics_process(delta: float) -> void:
	cooldown = maxf(0,cooldown-delta)
	recoil = maxf(0, recoil - delta * 0.7)
	elevation.position = elevation_origin + Vector3(0,0,recoil)
	flash.visible = mounted and recoil > 0.08
	if not mounted or is_destroyed: return
	if operator_session != null and operator_session.mission_ended():
		stop_operation()
		return
	var fine: float = 0.18 if Input.is_action_pressed("brake") else 1.0
	yaw.rotation.y -= Input.get_axis("roll_left", "roll_right") * deg_to_rad(traverse_degrees) * delta * fine
	elevation.rotation.x = clampf(elevation.rotation.x + Input.get_axis("pitch_up", "pitch_down") * deg_to_rad(elevation_degrees) * delta * fine, deg_to_rad(minimum_elevation_degrees), deg_to_rad(maximum_elevation_degrees))
	fuse_distance = clampf(fuse_distance + Input.get_axis("throttle_down", "throttle_up") * 180 * delta,100,range_metres)
	if Input.is_action_pressed("fire"): fire_round()

func fire_round() -> bool:
	if not mounted or is_destroyed or cooldown > 0: return false
	if operator_session != null and operator_session.mission_ended(): return false
	var forward: Vector3 = -muzzle.global_basis.z
	var spread := deg_to_rad(aim_error_degrees)
	var direction := (forward + muzzle.global_basis.x * rng.randfn(0,spread) + muzzle.global_basis.y * rng.randfn(0,spread)).normalized()
	# Friendly bodies block shots; terrain/buildings receive normal swept impacts.
	var query := PhysicsRayQueryParameters3D.create(muzzle.global_position,muzzle.global_position + direction * fuse_distance,15,[get_rid()])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("get_team_id") and hit.collider.get_team_id() == CombatTeams.PLAYER: return false
	if not battery.projectiles.spawn(muzzle.global_position, direction * projectile_speed, minf(fuse_distance/projectile_speed,maximum_lifetime), direct_damage, get_rid(), true, CombatTeams.PLAYER): return false
	shots_fired += 1
	cooldown = 1 / rounds_per_second
	recoil = 0.12
	battery.effects.puff(muzzle.global_position, "muzzle", 0.25)
	if GameAudioMixer.instance.playback_enabled:
		sound.pitch_scale = rng.randf_range(0.97,1.03)
		sound.play()
	return true

func _cull_visuals(node: Node) -> void:
	if node is MeshInstance3D:
		node.visibility_range_end = 3500
		node.visibility_range_end_margin = 250
	for child in node.get_children(): _cull_visuals(child)
