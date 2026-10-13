class_name FlakEffectPool
extends Node3D
## Bounded world-space CPU effects; no GPU-particle dependency or per-shot nodes.
const CAPACITY: int = 192
var particles: Array[MeshInstance3D] = []
var materials: Array[StandardMaterial3D] = []
var velocities: Array[Vector3] = []
var remaining: Array[float] = []
var growth: Array[float] = []
var emitted: Dictionary = {"air":0,"ground":0,"water":0,"muzzle":0}
var cursor: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	for i in range(CAPACITY):
		var mat := MeshKit.material(Color.WHITE)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh := SphereMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 3
		var particle := MeshKit.mesh(self, mesh, mat)
		particle.visible = false
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.append(particle)
		materials.append(mat)
		velocities.append(Vector3.ZERO)
		remaining.append(0)
		growth.append(0)

func puff(point: Vector3, kind: String = "air", strength: float = 1) -> void:
	emitted[kind] = int(emitted.get(kind, 0)) + 1
	for i in range(9):
		var slot := cursor
		cursor = (cursor + 1) % CAPACITY
		var smoke: bool = i > 2
		var color: Color = Color("34383c") if smoke else Color("ffc66b")
		if kind == "ground": color = Color("a39373")
		if kind == "water": color = Color("bedce3")
		if kind == "muzzle": color = Color("868b89") if smoke else Color("ffe6a4")
		materials[slot].albedo_color = color
		particles[slot].global_position = point
		particles[slot].scale = Vector3.ONE * (0.9 if smoke else 0.22) * strength
		remaining[slot] = rng.randf_range(0.6, 1.3) if smoke else 0.16
		if kind == "muzzle" and smoke: remaining[slot] = 0.4
		growth[slot] = 0.7 * strength
		velocities[slot] = Vector3(rng.randf_range(-2,2), rng.randf_range(1,4), rng.randf_range(-2,2)) * strength
		particles[slot].visible = true

func _physics_process(delta: float) -> void:
	for i in range(CAPACITY):
		if remaining[i] <= 0: continue
		remaining[i] -= delta
		particles[i].visible = remaining[i] > 0
		particles[i].position += velocities[i] * delta
		particles[i].scale += Vector3.ONE * delta * growth[i]
		var color := materials[i].albedo_color
		color.a = minf(remaining[i], 0.65)
		materials[i].albedo_color = color
