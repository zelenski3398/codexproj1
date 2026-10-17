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
var crash_result: Dictionary = {}
var original_meshes: Dictionary = {}
var original_visibility: Dictionary = {}
var removed_regions: Dictionary = {}
var component_debris_count: int = 0
var burst: DestructionBurst

func _ready() -> void:
	for surface in get_tree().get_nodes_in_group("aircraft_water"):
		if surface is PhysicsBody3D:
			aircraft.add_collision_exception_with(surface)
			water_rids.append(surface.get_rid())

func on_destroyed() -> void:
	# A combat loss is a mission event, not evidence of explosive ignition.
	# Fuel/structure controllers explicitly request catastrophic presentation.
	if aircraft.components.catastrophic and not started: start()

func ground_contact(velocity: Vector3, normal: Vector3, surface: String = "terrain") -> void:
	if started or water: return
	crash_result = AircraftCrashSolver.assess(aircraft,velocity,normal,surface)
	impact_speed = velocity.length()
	if crash_result.category in ["controlled","moderate"]:
		started = true
		var effect := DestructionBurst.new()
		effect.dust_only = true
		effect.hard_surface = surface == "hard"
		effect.strength = 0.3 if crash_result.category == "controlled" else 0.65
		AircraftImpactService.obtain().register_effect(effect,aircraft.get_instance_id(),3)
		effect.global_position = aircraft.global_position
		burst = effect
		aircraft.components.integrity[&"landing_gear"] = 0
		if crash_result.category == "moderate":
			detach_component(&"landing_gear")
			aircraft.components.engine_seized[&"engine"] = true
		_play_event(&"hard_landing")
		_play_event(&"propeller_impact")
	else:
		start()

func _play_event(kind: StringName, local_source: Vector3 = Vector3.ZERO) -> void:
	var service := AircraftImpactService.obtain()
	var stream: AudioStream = service.profile.event_sounds.get(kind)
	if stream != null: service.play_at(stream,aircraft.to_global(local_source),-10,1000,20,1,1,aircraft.get_instance_id(),2)

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
		crash_result = AircraftCrashSolver.assess(aircraft, aircraft.linear_velocity, water_normal, "water")
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
	var ignition: bool = aircraft.components.catastrophic_ignition or bool(crash_result.get("ignition", false))
	if ignition: explosion_count+=1
	impact_pose=aircraft.model.global_transform
	impact_velocity=aircraft.linear_velocity
	burst = DestructionBurst.new()
	burst.random_seed = aircraft.components.rng.randi()
	burst.dust_only = not ignition
	burst.strength = profile.explosion_strength * clampf(sqrt(aircraft.mass/3000.0),0.7,2.0)
	service.register_effect(burst,owner_id,3.5)
	burst.global_position = aircraft.global_position
	if ignition:
		service.play_at(crash_sound if crash_sound!=null else profile.explosion,aircraft.global_position,profile.explosion_db,profile.explosion_range,35,1,1,owner_id,3)
	else:
		_play_event(&"ground_crash")
		_play_event(&"structural_breakup")
	aircraft.damage_effects.clear()
	call_deferred("_present",generation)

func _present(expected_generation:int) -> void:
	if expected_generation!=generation or not started or not is_inside_tree():return
	var service:=AircraftImpactService.obtain()
	debris_root=Node3D.new()
	debris_root.name="AircraftFragments"
	service.register_effect(debris_root,aircraft.get_instance_id(),debris_lifetime)
	_break_meshes(aircraft.model)
	for i in range(fragments.size()-1,-1,-1):
		if not fragments[i].get_children().any(func(child): return child is MeshInstance3D):
			fragments[i].queue_free()
			fragments.remove_at(i)
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
		body.linear_velocity += aircraft.angular_velocity.cross(body.global_position-impact_pose.origin)
	aircraft.model.hide()
	_limit_debris()
	var all_fragments:=get_tree().get_nodes_in_group("aircraft_fragments")
	for i in range(maxi(all_fragments.size()-aircraft.components.profile.maximum_debris,0)):all_fragments[i].queue_free()

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
						var body := AircraftDebrisPiece.new()
						body.impact_owner = aircraft.get_instance_id()
						body.add_to_group("aircraft_fragments")
						body.mass = aircraft.mass / 12
						body.maximum_burning_emitters = aircraft.components.profile.maximum_fire_emitters
						body.burning = (explosion_count > 0 or not aircraft.components.fires.is_empty()) and fragments.size() < aircraft.components.profile.maximum_fire_emitters
						body.collision_layer = 0
						body.collision_mask = 1
						body.top_level = true
						debris_root.add_child(body)
						body.global_transform = impact_pose
						for surface in get_tree().get_nodes_in_group("aircraft_water"):
							if surface is PhysicsBody3D:
								body.add_collision_exception_with(surface)
								body.water_rids.append(surface.get_rid())
						body.linear_velocity = impact_velocity + Vector3(aircraft.components.rng.randf_range(-1, 1), aircraft.components.rng.randf_range(0.4, 1), aircraft.components.rng.randf_range(-1, 1)) * fragment_speed
						body.angular_velocity = aircraft.angular_velocity + Vector3(aircraft.components.rng.randf_range(-2, 2), aircraft.components.rng.randf_range(-2, 2), aircraft.components.rng.randf_range(-2, 2))
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
	for mesh_instance in original_meshes:
		if is_instance_valid(mesh_instance):
			mesh_instance.mesh = original_meshes[mesh_instance]
			mesh_instance.visible = original_visibility[mesh_instance]
	original_meshes.clear()
	original_visibility.clear()
	removed_regions.clear()
	component_debris_count = 0
	crash_result.clear()
	aircraft.model.show()

func detach_component(id: StringName) -> void:
	if removed_regions.has(id): return
	removed_regions[id] = true
	call_deferred("_detach_now", id, generation)

func _matches_region(id: StringName, point: Vector3) -> bool:
	var definition: AircraftComponentDefinition = aircraft.components.definitions.get(id)
	if definition == null: return false
	if definition.fragment_region != &"": id = definition.fragment_region
	if id in [&"left_wing", &"right_wing"]:
		var side: float = -1 if id == &"left_wing" else 1
		return point.x*side > 1.05 and point.z < (4.2 if aircraft.wing_area > 40 else 1.9)
	if id == &"tail": return point.z > (4.7 if aircraft.wing_area > 40 else 2.6)
	for spec in definition.hitboxes:
		var local_point: Vector3 = Basis.from_euler(spec.rotation_degrees*PI/180.0).inverse() * (point-spec.position)
		if AABB(-spec.size*0.6,spec.size*1.2).has_point(local_point): return true
	return false

func _detach_now(id: StringName, expected_generation: int) -> void:
	if generation != expected_generation or not is_inside_tree() or not aircraft.model.visible: return
	var root := Node3D.new()
	root.name = "Detached_"+String(id)
	var config := aircraft.components.profile
	AircraftImpactService.obtain().register_effect(root, aircraft.get_instance_id(), config.major_debris_lifetime)
	var body := AircraftDebrisPiece.new()
	body.impact_owner = aircraft.get_instance_id()
	body.add_to_group("aircraft_major_debris")
	body.buoyant = aircraft.components.definitions[id].material_kind == "fabric"
	body.float_seconds = config.debris_float_seconds
	body.maximum_burning_emitters = config.maximum_fire_emitters
	body.burning = aircraft.components.fires.has(id)
	body.mass = aircraft.mass * (0.08 if String(id).contains("wing") else 0.025)
	body.collision_layer = 0
	body.collision_mask = 1
	body.top_level = true
	root.add_child(body)
	body.global_transform = aircraft.model.global_transform
	_partition_model(aircraft.model,id,body)
	if body.get_child_count() == 0:
		root.queue_free()
		return
	var bounds := AABB()
	var first: bool = true
	for piece in body.get_children():
		if piece is MeshInstance3D:
			bounds = piece.get_aabb() if first else bounds.merge(piece.get_aabb())
			first = false
	var center := bounds.get_center()
	for piece in body.get_children(): piece.position -= center
	body.global_position += body.global_basis * center
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size.max(Vector3.ONE*0.1)
	collision.shape = box
	body.add_child(collision)
	body.linear_velocity = aircraft.linear_velocity + aircraft.angular_velocity.cross(body.global_position-aircraft.global_position)
	body.angular_velocity = aircraft.angular_velocity + Vector3(0.4,0.3,0.8)
	var outward := (body.global_position-aircraft.global_position).normalized()
	body.apply_central_impulse((outward+Vector3.DOWN*0.1)*body.mass*2)
	for water_surface in get_tree().get_nodes_in_group("aircraft_water"):
		if water_surface is PhysicsBody3D:
			body.add_collision_exception_with(water_surface)
			body.water_rids.append(water_surface.get_rid())
	component_debris_count += 1
	_play_event(&"fabric_tear" if aircraft.components.definitions[id].material_kind == "fabric" else &"metal_tear")
	_limit_debris()

func _partition_model(node: Node, id: StringName, body: RigidBody3D) -> void:
	for child in node.get_children():
		if child is RafPilotAvatar: continue
		if child is MeshInstance3D and child.mesh != null and child.is_visible_in_tree():
			var local_pose: Transform3D = aircraft.model.global_transform.affine_inverse()*child.global_transform
			var replacement := ArrayMesh.new()
			var changed: bool = false
			for surface_index in child.mesh.get_surface_count():
				var arrays: Array = child.mesh.surface_get_arrays(surface_index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				if indices.is_empty():
					for index in vertices.size(): indices.append(index)
				var keep := SurfaceTool.new()
				var separate := SurfaceTool.new()
				keep.begin(Mesh.PRIMITIVE_TRIANGLES)
				separate.begin(Mesh.PRIMITIVE_TRIANGLES)
				var kept: int = 0
				var removed: int = 0
				for triangle in range(0, indices.size()-2, 3):
					var center: Vector3 = (vertices[indices[triangle]]+vertices[indices[triangle+1]]+vertices[indices[triangle+2]])/3
					var selected: bool = _matches_region(id,local_pose*center)
					var builder: SurfaceTool = separate if selected else keep
					if selected: removed+=1
					else: kept+=1
					for corner in 3:
						var index: int = indices[triangle+corner]
						if arrays[Mesh.ARRAY_TEX_UV] != null and arrays[Mesh.ARRAY_TEX_UV].size() > index: builder.set_uv(arrays[Mesh.ARRAY_TEX_UV][index])
						if arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() > index: builder.set_color(arrays[Mesh.ARRAY_COLOR][index])
						builder.add_vertex(local_pose*vertices[index] if selected else vertices[index])
				var material: Material = child.material_override if child.material_override != null else child.mesh.surface_get_material(surface_index)
				if kept > 0:
					keep.generate_normals()
					keep.set_material(material)
					keep.commit(replacement)
				if removed > 0:
					changed = true
					separate.generate_normals()
					MeshKit.mesh(body,separate.commit(),material)
			if changed:
				if not original_meshes.has(child):
					original_meshes[child] = child.mesh
					original_visibility[child] = child.visible
				child.mesh = replacement if replacement.get_surface_count() > 0 else null
				child.visible = child.mesh != null
		_partition_model(child,id,body)

func _limit_debris() -> void:
	var config := aircraft.components.profile
	var all := get_tree().get_nodes_in_group("aircraft_fragments")
	# Component debris uses this same group and global budget as full crashes.
	for fragment in get_tree().get_nodes_in_group("aircraft_major_debris"):
		if not all.has(fragment): all.append(fragment)
	var camera := get_viewport().get_camera_3d()
	for i in all.size():
		var fragment: RigidBody3D = all[i]
		if i < all.size()-config.maximum_debris:
			fragment.queue_free()
		elif i < all.size()-config.maximum_colliding_debris or (camera != null and camera.global_position.distance_to(fragment.global_position) > config.detailed_debris_distance):
			fragment.collision_mask = 0
			fragment.set_physics_process(false)
		if (i < all.size()-config.maximum_detailed_debris or (camera != null and camera.global_position.distance_to(fragment.global_position)>config.detailed_debris_distance)) and not fragment.has_meta("coarse_debris"):
			fragment.set_meta("coarse_debris",true)
			for geometry in fragment.get_children():
				if geometry is MeshInstance3D:
					var bounds: AABB = geometry.get_aabb()
					var proxy := BoxMesh.new()
					proxy.size = bounds.size.max(Vector3.ONE*0.1)
					geometry.position += bounds.get_center()
					geometry.mesh = proxy
