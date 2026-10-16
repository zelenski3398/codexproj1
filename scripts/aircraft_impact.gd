class_name AircraftImpact
extends Node3D
## Shared impact presentation. Flight remains force driven; debris reuses actual
## model triangles, split spatially into eight independently simulated pieces.
@export var crash_sound: AudioStream = preload("res://assets/audio/aircraft_crash.ogg")
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
var burst: DestructionBurst

func _ready() -> void:
	for surface in get_tree().get_nodes_in_group("aircraft_water"):
		if surface is PhysicsBody3D:
			aircraft.add_collision_exception_with(surface)
			water_rids.append(surface.get_rid())

func integrate(state: PhysicsDirectBodyState3D) -> bool:
	if not water and not water_rids.is_empty() and state.transform.origin.y < 1.0:
		# A ray from above distinguishes exposed sea from land over the same
		# infinite water plane. No coastline/terrain geometry is changed.
		var p := state.transform.origin
		var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 2000, p.z), Vector3(p.x, -2, p.z), 1, [aircraft.get_rid()])
		var hit := aircraft.get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider.is_in_group("aircraft_water"):
			water = true
			aircraft._crash("Aircraft plunged into the sea · R to reset")
			if not aircraft.is_destroyed:
				aircraft.take_damage(100)
			if not started:
				start(true)
	if not water:
		return false
	# Simplified flooded-airframe resistance: drag damps forward motion while
	# gravity balances vertical drag at a slow sinking speed. No teleporting.
	state.apply_central_force(-state.linear_velocity * aircraft.mass * water_drag)
	state.apply_central_force(Vector3.DOWN * aircraft.mass * (water_drag * sinking_speed - state.total_gravity.length()))
	state.apply_torque(-state.angular_velocity * 16000 + state.transform.basis.x * -2500)
	aircraft.gear.contact_count = 0
	return true

func start(in_water: bool = false) -> void:
	if started:
		return
	started = true
	water = in_water
	call_deferred("_present")

func _present() -> void:
	if not started or not is_inside_tree():
		return
	aircraft.damage_effects.clear()
	burst = DestructionBurst.new()
	burst.water_impact = water
	burst.strength = 1.8
	add_child(burst)
	burst.top_level = true
	burst.global_position = Vector3(aircraft.global_position.x, 0, aircraft.global_position.z) if water else aircraft.global_position
	if water:
		return # Flooded aircraft remains visible as it physically submerges.
	if GameAudioMixer.instance != null and GameAudioMixer.instance.playback_enabled and get_tree().get_nodes_in_group("aircraft_crash_audio").size() < 4:
		var sound := AudioStreamPlayer3D.new()
		sound.stream = crash_sound
		sound.bus = "Guns"
		sound.unit_size = 35
		sound.max_distance = 1800
		sound.volume_db = -8
		sound.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
		burst.add_child(sound)
		sound.add_to_group("aircraft_crash_audio")
		sound.play()
	_break_meshes(aircraft.model)
	for body in fragments:
		var bounds := AABB()
		var first := true
		for piece in body.get_children():
			if piece is MeshInstance3D:
				bounds = piece.get_aabb() if first else bounds.merge(piece.get_aabb())
				first = false
		var center := bounds.get_center()
		for piece in body.get_children():
			piece.position -= center
		body.global_position += body.global_basis * center
	aircraft.model.hide()
	var all_fragments := get_tree().get_nodes_in_group("aircraft_fragments")
	for i in range(maxi(all_fragments.size() - 64, 0)):
		all_fragments[i].queue_free()

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
						add_child(body)
						body.global_transform = aircraft.model.global_transform
						body.linear_velocity = aircraft.linear_velocity * 0.45 + Vector3(randf_range(-1, 1), randf_range(0.4, 1), randf_range(-1, 1)) * fragment_speed
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
	if water and aircraft.global_position.y < -25:
		aircraft.model.hide()

func reset() -> void:
	started = false
	water = false
	age = 0
	for child in get_children():
		child.queue_free()
	fragments.clear()
	aircraft.model.show()
