class_name DamageEffects
extends Node3D
## CPU-updated, pooled mesh particles work in Compatibility/OpenGL/ANGLE.
## The pool is top-level: emitted smoke stays in world space as the plane moves.
@export var smoke_lifetime: float = 2.5
@export var smoke_rate: float = 32.0
@export var flame_rate: float = 35.0
var aircraft: FlightAircraft
var intensity: float = 0.0
var emitting: bool = false
var particles: Array[MeshInstance3D] = []
var velocities: Array[Vector3] = []
var ages: Array[float] = []
var lifetimes: Array[float] = []
var is_smoke: Array[bool] = []
var materials: Array[StandardMaterial3D] = []
var cursor: int = 0
var emission_clock: float = 0.0
var fire_clock: float = 0.0
var rng := RandomNumberGenerator.new()
var smoke_mesh: QuadMesh
var flame_mesh: SphereMesh
var smoke_texture: GradientTexture2D

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	rng.seed = 1941
	flame_mesh = SphereMesh.new()
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 4
	smoke_mesh = QuadMesh.new()
	smoke_mesh.size = Vector2(2, 2)
	# Original soft smoke sprite, made procedurally without asset downloads.
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.35, 1])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	smoke_texture = texture
	for i in range(128):
		var mat := MeshKit.material(Color(0.14, 0.15, 0.16, 0.6))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = texture
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.billboard_keep_scale = true
		var particle := MeshKit.mesh(self, smoke_mesh, mat)
		particle.visible = false
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.append(particle)
		materials.append(mat)
		velocities.append(Vector3.ZERO)
		ages.append(0.0)
		lifetimes.append(0.0)
		is_smoke.append(true)

func set_health(hp: float, _maximum: float) -> void:
	# Strict inequality is intentional: exactly 50 HP produces NO new effects.
	emitting = hp < 50.0
	intensity = clampf((50.0 - hp) / 50.0, 0.0, 1.0)
	if not emitting:
		emission_clock = 0.0
		fire_clock = 0.0

func _physics_process(delta: float) -> void:
	for i in range(particles.size()):
		if not particles[i].visible:
			continue
		ages[i] += delta
		if ages[i] >= lifetimes[i]:
			particles[i].visible = false
			continue
		var progress := ages[i] / lifetimes[i]
		particles[i].position += velocities[i] * delta
		velocities[i] *= exp(-delta * 1.5)
		velocities[i].y += delta * (1.4 if is_smoke[i] else 0.5)
		var radius := lerpf(0.25, 2.2, progress) if is_smoke[i] else lerpf(0.26, 0.08, progress)
		particles[i].scale = Vector3.ONE * radius
		var color := Color(0.11, 0.12, 0.13) if is_smoke[i] else Color(1.0, lerpf(0.75, 0.18, progress), 0.03)
		color.a = (1.0 - progress) * (0.55 if is_smoke[i] else 0.95)
		materials[i].albedo_color = color
	if not emitting:
		return
	var strength := 0.12 + intensity
	emission_clock += delta * smoke_rate * strength
	fire_clock += delta * flame_rate * strength
	while emission_clock >= 1.0:
		emission_clock -= 1.0
		_emit(true)
	while fire_clock >= 1.0:
		fire_clock -= 1.0
		_emit(false)

func _emit(smoke: bool) -> void:
	var i := cursor
	cursor = (cursor + 1) % particles.size()
	var jitter := Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.05, 0.35), rng.randf_range(-0.35, 0.35))
	particles[i].position = aircraft.to_global(Vector3(0, 0.32, -2.7) + jitter)
	# Partial inherited velocity lets smoke fall behind, then slow and linger.
	velocities[i] = aircraft.linear_velocity * (0.2 if smoke else 0.8) + Vector3.UP * 1.5
	ages[i] = 0.0
	lifetimes[i] = smoke_lifetime if smoke else 0.35
	is_smoke[i] = smoke
	particles[i].mesh = smoke_mesh if smoke else flame_mesh
	materials[i].billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if smoke else BaseMaterial3D.BILLBOARD_DISABLED
	# Flame spheres do not need the smoke sprite. Keep the texture reference
	# cached on the component rather than creating resources per emission.
	materials[i].albedo_texture = smoke_texture if smoke else null
	particles[i].scale = Vector3.ONE * 0.26
	materials[i].albedo_color = Color(0.12, 0.13, 0.14, 0.55) if smoke else Color(1, 0.75, 0.03, 0.95)
	particles[i].visible = true

func clear() -> void:
	emitting = false
	intensity = 0.0
	emission_clock = 0.0
	fire_clock = 0.0
	for particle in particles:
		particle.visible = false

func active_count() -> int:
	var count := 0
	for particle in particles:
		if particle.visible:
			count += 1
	return count
