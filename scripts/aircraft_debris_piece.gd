class_name AircraftDebrisPiece
extends RigidBody3D
## One simple collider for a major component, never one body per triangle.
var impact_owner: int
var secondary_done: bool = false
var water_rids: Array[RID] = []
var age: float = 0
var burning: bool = false
var previous_speed: float = 0
func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 2
	if burning:
		var active: int = 0
		for piece in get_tree().get_nodes_in_group("burning_aircraft_debris"): active += 1
		if active < 4:
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
			var ball := SphereMesh.new()
			ball.radial_segments = 6
			ball.rings = 3
			ball.material = MeshKit.material(Color(0.10,0.10,0.10))
			smoke.mesh = ball
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
			AircraftImpactService.obtain().burst_at(hit.position,hit.normal,true,0.3,impact_owner)
			linear_damp = 2
			angular_damp = 2
			# Flooded metal chunks sink. Foam/splashes provide the surface trace.
