class_name AircraftImpact
extends Node3D
## Shared impact presentation. Flight remains force driven; debris reuses actual
## model triangles, split spatially into eight independently simulated pieces.
@export var crash_sound: AudioStream # Optional per-aircraft override; shared profile supplies the default.
@export var debris_lifetime: float = 12.0
@export var fragment_speed: float = 9.0
@export var water_drag: float = 1.8
@export var sinking_speed: float = 3.5
var aircraft: FlightAircraft
var started: bool = false
var water: bool = false
var age: float = 0.0
var fragments: Array[RigidBody3D] = []
var water_rids: Array[RID] = []
var generation:int=0
var explosion_count:int=0
var splash_count:int=0
var water_point:Vector3
var water_normal:Vector3=Vector3.UP
var previous_position:Vector3
var previous_valid:bool=false
var impact_speed:float=0
var last_water_strength:float=0
var impact_pose:Transform3D
var impact_velocity:Vector3
var debris_root:Node3D
var burst: DestructionBurst

func _ready() -> void:
	for surface in get_tree().get_nodes_in_group("aircraft_water"):
		if surface is PhysicsBody3D:
			aircraft.add_collision_exception_with(surface)
			water_rids.append(surface.get_rid())

func on_destroyed() -> void:
	# Sea detection latches water BEFORE resolving HP. Ground crash paths latch
	# their impact before HP depletion too. Only a genuinely airborne loss
	# starts the new immediate in-air explosion.
	if not water and not started and not aircraft.is_crashed and aircraft.gear.contact_count==0:
		start()

func integrate(state: PhysicsDirectBodyState3D) -> bool:
	var p:=state.transform.origin
	if not water and not water_rids.is_empty():
		# Query the actual exposed surface, including raised/translated water.
		# This also rejects the water plane underneath real terrain/buildings.
		var ray:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2000,p+Vector3.DOWN*2000,1,[aircraft.get_rid()])
		var hit:=aircraft.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider.is_in_group("aircraft_water"):
			var normal:Vector3=hit.normal.normalized()
			var clearance:float=AircraftImpactService.obtain().profile.water_hull_clearance
			var distance:float=(p-hit.position).dot(normal)-clearance
			if distance<=0:
				water=true
				water_normal=normal
				water_point=hit.position
				# Swept lower-hull intersection supplies the contact XZ as well
				# as its real surface elevation during a fast crossing.
				if previous_valid:
					var before:float=(previous_position-hit.position).dot(normal)-clearance
					if before>0:
						water_point=previous_position.lerp(p,clampf(before/(before-distance),0,1))-normal*clearance
				impact_speed=state.linear_velocity.length()
				start(true)
				aircraft._crash("Aircraft plunged into the sea · R to reset")
				if not aircraft.is_destroyed:aircraft.take_damage(aircraft.health.max_hp)
	previous_position=p
	previous_valid=true
	if not water:return false
	state.apply_central_force(-state.linear_velocity*aircraft.mass*water_drag)
	state.apply_central_force(Vector3.DOWN*aircraft.mass*(water_drag*sinking_speed-state.total_gravity.length()))
	state.apply_torque(-state.angular_velocity*16000+state.transform.basis.x*-2500)
	aircraft.gear.contact_count=0
	return true

func start(in_water: bool = false) -> void:
	var service:=AircraftImpactService.obtain()
	var profile:AircraftImpactProfile=service.profile
	var owner_id:=aircraft.get_instance_id()
	if in_water:
		if splash_count>0:return
		water=true
		splash_count+=1
		started=true
		var speed_factor:float=clampf(impact_speed/maxf(profile.full_water_impact_speed,1),0,1.5)
		var size_factor:float=clampf(sqrt(aircraft.wing_area/22.5),.65,1.6)
		last_water_strength=clampf((profile.water_effect_minimum+speed_factor*1.65)*size_factor,profile.water_effect_minimum,profile.water_effect_maximum)
		burst=service.burst_at(water_point,water_normal,true,last_water_strength,owner_id)
		service.play_at(profile.water_impact,water_point,profile.water_db+linear_to_db(last_water_strength),profile.water_range,40,1,randf_range(.94,1.06),owner_id,2)
		aircraft.damage_effects.clear()
		return # A healthy sea crash plunges intact. A previously exploded wreck
		# retains its separate earlier fragments; no repeat explosion/kill.
	if started:return
	started=true
	explosion_count+=1
	impact_pose=aircraft.model.global_transform
	impact_velocity=aircraft.linear_velocity
	burst=service.burst_at(aircraft.global_position,Vector3.UP,false,profile.explosion_strength,owner_id)
	service.play_at(crash_sound if crash_sound!=null else profile.explosion,aircraft.global_position,profile.explosion_db,profile.explosion_range,35,1,1,owner_id,3)
	aircraft.damage_effects.clear()
	call_deferred("_present",generation)

func _present(expected_generation:int) -> void:
	if expected_generation!=generation or not started or not is_inside_tree():return
	var service:=AircraftImpactService.obtain()
	debris_root=Node3D.new()
	debris_root.name="AircraftFragments"
	service.register_effect(debris_root,aircraft.get_instance_id(),debris_lifetime)
	_break_meshes(aircraft.model)
	for body in fragments:
		var bounds:=AABB()
		var first:=true
		for piece in body.get_children():
			if piece is MeshInstance3D:
				bounds=piece.get_aabb() if first else bounds.merge(piece.get_aabb())
				first=false
		var center:=bounds.get_center()
		for piece in body.get_children():piece.position-=center
		body.global_position+=body.global_basis*center
	aircraft.model.hide()
	var all_fragments:=get_tree().get_nodes_in_group("aircraft_fragments")
	for i in range(maxi(all_fragments.size()-64,0)):all_fragments[i].queue_free()

func _bucket(p: Vector3) -> int:
	if absf(p.x) > 1.0:
		return (0 if p.x < 0 else 2) + (1 if absf(p.x) > 3 else 0)
	return 4 if p.z < -1.4 else (5 if p.z < 1.5 else (6 if p.z < 3.1 else 7))

func _break_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is RafPilotAvatar:
			continue
		if child is MeshInstance3D and child.is_visible_in_tree() and child.mesh != null:
			for surface_index in range(child.mesh.get_surface_count()):
				var arrays: Array = child.mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var faces := PackedVector3Array()
				if indices.is_empty():
					faces = vertices
				else:
					for index in indices:
						faces.append(vertices[index])
				var local_pose: Transform3D = aircraft.model.global_transform.affine_inverse() * child.global_transform
				var builders: Dictionary = {}
				for i in range(0, faces.size(), 3):
					var center: Vector3 = local_pose * ((faces[i] + faces[i + 1] + faces[i + 2]) / 3)
					var key := _bucket(center)
					if not builders.has(key):
						var surface := SurfaceTool.new()
						surface.begin(Mesh.PRIMITIVE_TRIANGLES)
						builders[key] = surface
					for j in range(3):
						builders[key].add_vertex(local_pose * faces[i + j])
				for key in builders:
					while fragments.size() <= key:
						var body := RigidBody3D.new()
						body.add_to_group("aircraft_fragments")
						body.mass = 65
						body.collision_layer = 0
						body.collision_mask = 1
						body.top_level = true
						debris_root.add_child(body)
						body.global_transform = impact_pose
						for surface in get_tree().get_nodes_in_group("aircraft_water"):
							if surface is PhysicsBody3D:body.add_collision_exception_with(surface)
						body.linear_velocity = impact_velocity * 0.45 + Vector3(randf_range(-1, 1), randf_range(0.4, 1), randf_range(-1, 1)) * fragment_speed
						body.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
						fragments.append(body)
					builders[key].generate_normals()
					var geometry: ArrayMesh = builders[key].commit()
					var mat: Material = child.material_override if child.material_override != null else child.mesh.surface_get_material(surface_index)
					var piece := MeshKit.mesh(fragments[key], geometry, mat)
					# One compact collider per chunk, avoiding hundreds of collision shapes.
					if fragments[key].get_child_count() == 1:
						var collision := CollisionShape3D.new()
						var box := BoxShape3D.new()
						var bounds := piece.get_aabb()
						box.size = bounds.size.max(Vector3.ONE * 0.15)
						collision.shape = box
						collision.position = bounds.get_center()
						fragments[key].add_child(collision)
		_break_meshes(child)

func _physics_process(delta: float) -> void:
	if not started:
		return
	age += delta
	aircraft.damage_effects.clear()
	if age > debris_lifetime:
		for fragment in fragments:
			if is_instance_valid(fragment):
				fragment.queue_free()
		fragments.clear()
	if water and (aircraft.global_position-water_point).dot(water_normal)<-25:
		aircraft.model.hide()

func reset() -> void:
	generation+=1
	if is_instance_valid(AircraftImpactService.instance):AircraftImpactService.instance.clear_owner(aircraft.get_instance_id())
	explosion_count=0
	splash_count=0
	previous_valid=false
	started = false
	water = false
	age = 0
	for child in get_children():
		child.queue_free()
	fragments.clear()
	aircraft.model.show()
