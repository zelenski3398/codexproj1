class_name AirfieldAABattery
extends Node3D
## One battery per continuous world. Retry frees this owner, shells and effects.
@export var burst_radius: float = 12
@export var blast_damage: float = 8
var world: MaltaWorld
var guns: Array[BritishAAGun] = []
var projectiles: ProjectilePool
var effects: FlakEffectPool

func _ready() -> void:
	projectiles = ProjectilePool.new()
	projectiles.capacity = 96
	add_child(projectiles)
	projectiles.round_finished.connect(_burst)
	effects = FlakEffectPool.new()
	add_child(effects)
	# Defer until the physics server has registered imported terrain BVHs.
	call_deferred("_place")

func _place() -> void:
	if not is_inside_tree() or not guns.is_empty(): return
	for field in world.fields.values():
		for side in [-1, 1]:
			var point: Vector3 = field.to_global(Vector3(-72, 0, side * field.runway_length * 0.28))
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1000, point - Vector3.UP * 1000, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty(): continue
			var gun := BritishAAGun.new()
			gun.battery = self
			gun.name = String(field.record.id) + "_AA_" + str(side)
			add_child(gun)
			gun.global_position = hit.position + Vector3.UP * 0.025
			# Align the model's ground pad with the measured local surface normal.
			var normal: Vector3 = hit.normal.normalized()
			var right := Vector3.FORWARD.cross(normal).normalized()
			gun.global_basis = Basis(right, normal, right.cross(normal)).orthonormalized()
			guns.append(gun)

func candidates() -> Array[FlightAircraft]:
	var result: Array[FlightAircraft] = []
	for body in get_tree().get_nodes_in_group("combat_aircraft"):
		if body is FlightAircraft and body.team_id == CombatTeams.ENEMY and not body.is_destroyed and not body.is_crashed:
			result.append(body)
	return result

func _burst(point: Vector3, direct: Object, _team: int) -> void:
	var kind := "air"
	if direct != null and not direct is AircraftHitbox and not direct is FlightAircraft:
		kind = "water" if direct is Node and direct.name == "MediterraneanSea" else "ground"
	effects.puff(point, kind)
	var direct_aircraft: FlightAircraft = direct.damage_system.aircraft if direct is AircraftHitbox else (direct if direct is FlightAircraft else null)
	for aircraft in candidates():
		# One shell cannot apply both direct-hit and blast damage to the same plane.
		if aircraft == direct_aircraft: continue
		var closest: AircraftHitbox = null
		var distance := burst_radius
		var closest_point := Vector3.ZERO
		for hitbox in aircraft.components.hitboxes:
			for shape in hitbox.get_children():
				if not shape is CollisionShape3D: continue
				var local: Vector3 = shape.to_local(point)
				var half: Vector3 = shape.shape.size * 0.5
				var contact: Vector3 = shape.to_global(local.clamp(-half, half))
				var d := point.distance_to(contact)
				if d < distance:
					distance = d
					closest = hitbox
					closest_point = contact
		if closest == null: continue
		var query := PhysicsRayQueryParameters3D.create(point, closest_point, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			closest.receive_projectile_hit(blast_damage * (1 - distance / burst_radius), point)
