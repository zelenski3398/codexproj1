class_name WreckFire
extends Node3D
## Bounded, world-owned Compatibility effect. Survives enemy wreck cleanup;
## visual burning adds neither another explosion nor another damage event.
var age: float = 0
var duration: float = 75
var aircraft: WeakRef
var captured: bool = false
var smoke: CPUParticles3D
var flames: CPUParticles3D
var remains: Node3D
var charred: StandardMaterial3D
func _ready() -> void:
	add_to_group("land_wreck_fires")
	remains = Node3D.new()
	remains.visible = false
	add_child(remains)
	charred = MeshKit.material(Color("353731"),.98)
	smoke = emitter(true)
	flames = emitter(false)
func emitter(is_smoke: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.amount = 24 if is_smoke else 18
	particles.lifetime = 5 if is_smoke else .65
	particles.local_coords = false
	particles.direction = Vector3.UP
	particles.spread = 22
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 3
	particles.gravity = Vector3(.3,.35,0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 1.3
	particles.scale_amount_min = .8 if is_smoke else .25
	particles.scale_amount_max = 2.5 if is_smoke else .75
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(.12,.12,.12,.6),Color(.22,.22,.22,0)]) if is_smoke else PackedColorArray([Color(1,.75,.1,.95),Color(1,.2,.02,0)])
	particles.color_ramp = ramp
	var material := MeshKit.material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if is_smoke:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0,.5,1])
		gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.7),Color(1,1,1,0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(.5,.5)
		texture.fill_to = Vector2(1,.5)
		texture.width = 32
		texture.height = 32
		material.albedo_texture = texture
		var quad := QuadMesh.new()
		quad.size = Vector2(2,2)
		quad.material = material
		particles.mesh = quad
	else:
		var mesh := SphereMesh.new()
		mesh.radial_segments = 8
		mesh.rings = 4
		mesh.material = material
		particles.mesh = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles
func _physics_process(delta: float) -> void:
	age += delta
	var source = aircraft.get_ref() if aircraft != null else null
	remains.visible = not is_instance_valid(source)
	if not captured and age > .8:
		captured = true
		if is_instance_valid(source):
			var count := 0
			for piece in source.impact_effects.fragments:
				if not is_instance_valid(piece) or piece.global_position.distance_to(global_position) > 18: continue
				for child in piece.get_children():
					if not child is MeshInstance3D or count >= 16: continue
					var mesh := MeshInstance3D.new()
					mesh.mesh = child.mesh
					mesh.material_override = charred
					remains.add_child(mesh)
					mesh.global_transform = child.global_transform
					mesh.visibility_range_end = 3000
					count += 1
			# A moderate crash can leave an intact burned hull instead of loose
			# fragments. Keep its actual geometry after enemy cleanup as well.
			if count == 0 and source.model.visible:
				for child in source.model.find_children("*", "MeshInstance3D", true, false):
					if not child.visible or count >= 16: continue
					var mesh := MeshInstance3D.new()
					mesh.mesh = child.mesh
					mesh.material_override = charred
					remains.add_child(mesh)
					mesh.global_transform = child.global_transform
					mesh.visibility_range_end = 3000
					count += 1
	if age > duration - 5:
		flames.emitting = false
		smoke.emitting = false
