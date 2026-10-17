class_name AircraftDebrisPiece
extends RigidBody3D
## One simple collider for a major component, never one body per triangle.
var impact_owner: int
var secondary_done: bool = false
var water_rids: Array[RID] = []
var age: float = 0
var burning: bool = false
var previous_speed: float = 0
var maximum_burning_emitters: int = 4
var buoyant: bool = false
var float_seconds: float = 8
var in_water: bool = false
var surface_point: Vector3 = Vector3.ZERO
var surface_normal: Vector3 = Vector3.UP
func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	if burning:
		var active: int = 0
		for piece in get_tree().get_nodes_in_group("burning_aircraft_debris"): active += 1
		if active < maximum_burning_emitters:
			add_to_group("burning_aircraft_debris")
			var smoke := CPUParticles3D.new()
			smoke.amount = 12
			smoke.lifetime = 3
			smoke.local_coords = false
			smoke.direction = Vector3.UP
			smoke.initial_velocity_min = 1
			smoke.initial_velocity_max = 2
			smoke.gravity = Vector3(0,0.3,0)
			smoke.scale_amount_min = 0.4
			smoke.scale_amount_max = 1.2
			var gradient := Gradient.new()
			gradient.offsets = PackedFloat32Array([0,0.4,1])
			gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,0.55),Color(1,1,1,0)])
			var texture := GradientTexture2D.new()
			texture.gradient = gradient
			texture.width = 32
			texture.height = 32
			texture.fill = GradientTexture2D.FILL_RADIAL
			texture.fill_from = Vector2(0.5,0.5)
			texture.fill_to = Vector2(1,0.5)
			var material := MeshKit.material(Color(0.10,0.10,0.10,0.45))
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			material.albedo_texture = texture
			var quad := QuadMesh.new()
			quad.size = Vector2(2,2)
			quad.material = material
			smoke.mesh = quad
			smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(smoke)
func _physics_process(delta: float) -> void:
	age += delta
	if age < 0.15 or secondary_done: return
	var speed: float = maxf(previous_speed,linear_velocity.length())
	previous_speed = linear_velocity.length()
	if get_contact_count() > 0 and speed > 5:
		secondary_done = true
		var service := AircraftImpactService.obtain()
		var effect := DestructionBurst.new()
		effect.dust_only = not burning
		effect.strength = 0.25
		service.register_effect(effect,impact_owner,3)
		effect.global_position = global_position
		var sound: AudioStream = service.profile.event_sounds.get(&"secondary_impact")
		if sound != null: service.play_at(sound,global_position,-18,500,8,1,1,impact_owner,0)
	# Water approximation is a real surface query, not an assumed y=0 plane.
	if age > 0.3 and not water_rids.is_empty():
		var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*20,global_position+Vector3.DOWN*20,1,[get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider.is_in_group("aircraft_water") and global_position.y < hit.position.y+0.3:
			secondary_done = true
			in_water = true
			surface_point = hit.position
			surface_normal = hit.normal
			AircraftImpactService.obtain().burst_at(hit.position,hit.normal,true,0.3,impact_owner)
			linear_damp = 2
			angular_damp = 2
			# Flooded metal chunks sink. Foam/splashes provide the surface trace.

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not in_water: return
	state.apply_central_force(-state.linear_velocity*mass*2)
	if buoyant and age < float_seconds:
		var depth: float = (surface_point-state.transform.origin).dot(surface_normal)
		state.apply_central_force(surface_normal*mass*9.81*clampf((depth+0.1)*4,0,1.4))
