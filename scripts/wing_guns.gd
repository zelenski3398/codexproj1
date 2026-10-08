class_name WingGuns
extends Node3D
@export_range(0, 60, 0.5) var rounds_per_second: float = 12.0 # per gun
@export var bullet_speed: float = 850.0 # metres / second, plus aircraft velocity
@export var bullet_lifetime: float = 2.0
@export var bullet_damage: float = 4.0
@export var convergence_distance: float = 250.0 # <= 0 means parallel guns
@export var tracer_every: int = 4
var aircraft: FlightAircraft
var pool: ProjectilePool
var cooldown: float = 0.0
var flash_times: Array[float] = []
var flashes: Array[MeshInstance3D] = []
var salvo_count: int = 0
var trigger_ready: bool = true

func _ready() -> void:
	pool = ProjectilePool.new()
	pool.name = "WorldSpaceBullets"
	add_child(pool)
	var mat := MeshKit.material(Color("ffe0a0"))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for port in aircraft.model.gun_ports:
		var flash := MeshKit.sphere(port, Vector3(0.14, 0.14, 0.45), Vector3(0, 0, -0.12), mat)
		flash.visible = false
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flashes.append(flash)
		flash_times.append(0.0)

func _physics_process(delta: float) -> void:
	for i in range(flashes.size()):
		flash_times[i] = maxf(flash_times[i] - delta, 0.0)
		flashes[i].visible = flash_times[i] > 0.0
	var held := aircraft.pilot.fire if aircraft.pilot.automated else Input.is_action_pressed("fire")
	if not held:
		trigger_ready = true
	if not held or not trigger_ready or aircraft.is_crashed or aircraft.is_destroyed or aircraft.reset_pending or rounds_per_second <= 0.0:
		cooldown = maxf(cooldown - delta, 0.0)
		return
	cooldown -= delta
	var catch_up := 0
	# Keep fractional time so firing rate does not drift with physics ticks.
	# Bound catch-up work for extreme tuning values or slow-frame situations.
	while cooldown <= 0.0 and catch_up < 8:
		_fire_salvo()
		cooldown += 1.0 / rounds_per_second
		catch_up += 1
	if catch_up == 8:
		cooldown = maxf(cooldown, 0.0)

func shot_direction(port: Marker3D) -> Vector3:
	var forward := -aircraft.global_basis.z.normalized()
	if convergence_distance <= 0.0:
		return forward
	var aim := aircraft.global_position + forward * convergence_distance
	return (aim - port.global_position).normalized()

func _fire_salvo() -> void:
	for i in range(aircraft.model.gun_ports.size()):
		var port := aircraft.model.gun_ports[i]
		var velocity := shot_direction(port) * bullet_speed + aircraft.linear_velocity
		pool.spawn(port.global_position, velocity, bullet_lifetime, bullet_damage, aircraft.get_rid(), (salvo_count + i) % maxi(tracer_every, 1) == 0)
		flash_times[i] = 0.035
		flashes[i].visible = true
	salvo_count += 1

func reset() -> void:
	pool.clear()
	cooldown = 0.0
	# Avoid a held Ctrl immediately spawning new rounds in the reset frame.
	trigger_ready = false
	for i in range(flashes.size()):
		flashes[i].visible = false
		flash_times[i] = 0.0
