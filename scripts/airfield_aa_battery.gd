class_name AirfieldAABattery
extends Node3D
## One battery per continuous world. Retry frees this owner, shells and effects.
@export var burst_radius: float = 24
@export var blast_damage: float = 75
@export var falloff_exponent: float = 1.0
@export var aerial_burst_visual_scale: float = 4.0
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
			# Existing apron: X 13..109, Z centre ±115. These positions leave
			# the runway, parked aircraft, hangars and a continuous driving lane clear.
			var local := Vector3(37,0.025,field.runway_length * 0.31 + side * 90)
			var gun := BritishAAGun.new()
			gun.battery = self
			gun.name = String(field.record.id) + "_AA_" + str(side)
			add_child(gun)
			gun.global_transform = field.global_transform * Transform3D(Basis.IDENTITY,local)
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
	effects.puff(point, kind, aerial_burst_visual_scale if kind == "air" else 1.0)
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
			closest.receive_projectile_hit(damage_at_distance(distance), point)

func damage_at_distance(distance: float) -> float:
	if not is_finite(distance) or distance < 0 or burst_radius <= 0 or distance >= burst_radius: return 0
	return maxf(blast_damage,0)*pow(1-distance/burst_radius,maxf(falloff_exponent,0.1))
