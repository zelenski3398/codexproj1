class_name ProjectilePool
extends Node3D
## Fixed-size world-space pool. No per-shot nodes, rigid bodies, or timers.
## Every round (including invisible ones) sweeps its ENTIRE travelled segment.
@export var capacity: int = 384
@export_flags_3d_physics var hit_mask: int = 15
var active: Array[int] = []
var free: Array[int] = []
var positions: Array[Vector3] = []
var velocities: Array[Vector3] = []
var ages: Array[float] = []
var lifetimes: Array[float] = []
var damage: Array[float] = []
var excluded: Array[RID] = []
var excluded_hitboxes: Array[Array] = []
var teams: Array[int] = []
var tracers: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var spark_times: Array[float] = []
var impact_cursor: int = 0
var total_spawned: int = 0
var total_hits: int = 0
var dropped_rounds: int = 0
var tracer_material: StandardMaterial3D

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	var tracer_mat := MeshKit.material(Color("ffdb85"))
	tracer_material = tracer_mat
	tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var tracer_mesh := BoxMesh.new()
	tracer_mesh.size = Vector3(0.035, 0.035, 3.2)
	for i in range(capacity):
		free.append(i)
		positions.append(Vector3.ZERO)
		velocities.append(Vector3.ZERO)
		ages.append(0.0)
		lifetimes.append(0.0)
		damage.append(0.0)
		excluded.append(RID())
		excluded_hitboxes.append([])
		teams.append(CombatTeams.NEUTRAL)
		var visual := MeshKit.mesh(self, tracer_mesh, tracer_mat)
		visual.visible = false
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tracers.append(visual)
	for i in range(32):
		var spark := MeshKit.sphere(self, Vector3.ONE * 0.3, Vector3.ZERO, tracer_mat)
		spark.visible = false
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparks.append(spark)
		spark_times.append(0.0)

func spawn(origin: Vector3, velocity: Vector3, life: float, hit_damage: float, shooter: RID, visible_tracer: bool, shooter_team: int = CombatTeams.NEUTRAL) -> bool:
	if free.is_empty():
		dropped_rounds += 1
		return false
	var index: int = free.pop_back()
	active.append(index)
	positions[index] = origin
	velocities[index] = velocity
	ages[index] = 0.0
	lifetimes[index] = maxf(life, 0.001)
	damage[index] = hit_damage
	excluded[index] = shooter
	excluded_hitboxes[index] = []
	if shooter.is_valid():
		var owner_id: int = PhysicsServer3D.body_get_object_instance_id(shooter)
		var body: Object = instance_from_id(owner_id) if owner_id != 0 else null
		if body is FlightAircraft:
			excluded_hitboxes[index] = body.components.hitbox_rids
	teams[index] = shooter_team
	tracers[index].position = origin
	tracers[index].visible = visible_tracer
	if velocity.length_squared() > 0.01:
		tracers[index].look_at(origin + velocity)
	total_spawned += 1
	return true

func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for slot in range(active.size() - 1, -1, -1):
		var index := active[slot]
		var step := minf(delta, lifetimes[index] - ages[index])
		var next := positions[index] + velocities[index] * step
		var exclusions: Array[RID] = [excluded[index]]
		exclusions.append_array(excluded_hitboxes[index])
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(positions[index], next, hit_mask, exclusions)
		query.collide_with_areas = true
		query.hit_from_inside = true
		var hit: Dictionary = space.intersect_ray(query) if next.distance_squared_to(positions[index]) > 0.000001 else {}
		# Coarse rigid-body shapes are for landing/contact, not bullet locations.
		# Skip only these bodies, keeping the same segment and closest terrain,
		# hitbox or ordinary target. Owner body AND all owner areas are excluded.
		while not hit.is_empty() and hit.collider is FlightAircraft and (hit_mask & AircraftHitbox.LAYER) != 0:
			exclusions.append(hit.collider.get_rid())
			query.exclude = exclusions
			hit = space.intersect_ray(query)
		ages[index] += step
		if not hit.is_empty():
			total_hits += 1
			var collider: Object = hit.collider
			if is_instance_valid(collider) and collider.has_method("take_damage") and CombatTeams.can_damage(teams[index], collider):
				if collider.has_method("receive_projectile_hit"):
					collider.call("receive_projectile_hit", damage[index], hit.position)
				else:
					collider.call("take_damage", damage[index])
			_impact(hit.position)
			_release(slot)
		elif ages[index] >= lifetimes[index]:
			_release(slot)
		else:
			positions[index] = next
			tracers[index].position = next
	for i in range(sparks.size()):
		spark_times[i] = maxf(spark_times[i] - delta, 0.0)
		sparks[i].visible = spark_times[i] > 0.0
		sparks[i].scale = Vector3.ONE * (0.5 + spark_times[i] * 8.0)

func _release(slot: int) -> void:
	var index := active[slot]
	tracers[index].visible = false
	active[slot] = active.back()
	active.pop_back()
	free.append(index)

func _impact(point: Vector3) -> void:
	sparks[impact_cursor].position = point
	spark_times[impact_cursor] = 0.14
	sparks[impact_cursor].visible = true
	impact_cursor = (impact_cursor + 1) % sparks.size()

func clear() -> void:
	for index in active:
		tracers[index].visible = false
		free.append(index)
	active.clear()
	for i in range(sparks.size()):
		spark_times[i] = 0.0
		sparks[i].visible = false
