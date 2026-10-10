class_name DestructionBurst
extends Node3D
## One cosmetic impact burst. CPU meshes/billboard smoke support Compatibility.
## Owned by the session, so it can linger after the wreck and clear on restart.
var elapsed: float = 0
var particles: Array[MeshInstance3D] = []
var materials: Array[StandardMaterial3D] = []
var velocities: Array[Vector3] = []
var lifetimes: Array[float] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1943
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.3, 1])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	for i in range(32):
		var smoke: bool = i >= 12
		var mat: StandardMaterial3D = MeshKit.material(Color.WHITE)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var mesh: Mesh
		if smoke:
			var quad: QuadMesh = QuadMesh.new()
			quad.size = Vector2(2, 2)
			mesh = quad
			mat.albedo_texture = texture
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		else:
			var ball: SphereMesh = SphereMesh.new()
			ball.radial_segments = 8
			ball.rings = 4
			mesh = ball
		var particle: MeshInstance3D = MeshKit.mesh(self, mesh, mat)
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.append(particle)
		materials.append(mat)
		velocities.append(Vector3(rng.randf_range(-6, 6), rng.randf_range(2, 10), rng.randf_range(-6, 6)))
		lifetimes.append(rng.randf_range(1.5, 2.4) if smoke else rng.randf_range(0.3, 0.6))
	add_to_group("session_impact_effects")

func _physics_process(delta: float) -> void:
	elapsed += delta
	for i in range(particles.size()):
		var progress: float = elapsed / lifetimes[i]
		particles[i].visible = progress < 1
		if progress >= 1:
			continue
		particles[i].position += velocities[i] * delta
		velocities[i] *= exp(-delta * 2)
		particles[i].scale = Vector3.ONE * lerpf(0.8, 4.5 if i >= 12 else 2.0, progress)
		var color: Color = Color(0.12, 0.13, 0.14) if i >= 12 else Color(1, lerpf(0.8, 0.15, progress), 0.04)
		color.a = (1 - progress) * 0.8
		materials[i].albedo_color = color
	if elapsed > 2.5:
		queue_free()
