class_name AirfieldAABattery
extends Node3D
## One battery per continuous world. Retry frees this owner, shells and effects.
@export var aerial_burst_visual_scale: float = 4.0
var world: MaltaWorld
var guns: Array[BritishAAGun] = []
var projectiles: ProjectilePool
var light_projectiles: ProjectilePool
var heavy_definition: AAWeaponDefinition = preload("res://weapon_definitions/heavy_aa.tres")
var light_definition: AAWeaponDefinition = preload("res://weapon_definitions/bofors_aa.tres")
var effects: FlakEffectPool

func _ready() -> void:
	projectiles = ProjectilePool.new()
	projectiles.capacity = 96
	projectiles.gravity = 9.81
	projectiles.shell_definition = heavy_definition
	add_child(projectiles)
	projectiles.round_finished.connect(_burst)
	light_projectiles = ProjectilePool.new()
	light_projectiles.capacity = 96
	light_projectiles.gravity = 9.81
	light_projectiles.shell_definition = light_definition
	add_child(light_projectiles)
	light_projectiles.round_finished.connect(_light_impact)
	effects = FlakEffectPool.new()
	add_child(effects)
	# Defer until the physics server has registered imported terrain BVHs.
	call_deferred("_place")

func _place() -> void:
	if not is_inside_tree() or not guns.is_empty(): return
	for field in world.fields.values():
		# Six spaced emplacements on the graded apron; X78 driving lane and X59 parking stay clear.
		for slot in range(6):
			var local := Vector3(37,0.025,field.runway_length * .31 + [-90,90,-30,30,-60,60][slot])
			var gun := BritishAAGun.new()
			gun.weapon = heavy_definition if slot < 4 else light_definition
			gun.battery = self
			gun.name = String(field.record.id) + "_AA_" + str(slot)
			add_child(gun)
			gun.global_transform = field.global_transform * Transform3D(Basis.IDENTITY,local)
			guns.append(gun)

func pool_for(definition: AAWeaponDefinition) -> ProjectilePool:
	return projectiles if definition.heavy else light_projectiles

func _light_impact(point: Vector3, collider: Object, _team: int) -> void:
	# Impact fuze only: a miss expires silently, never creates timed flak damage.
	if collider == null:return
	var kind := "water" if collider is Node and collider.name == "MediterraneanSea" else "ground"
	if collider is AircraftHitbox or collider is FlightAircraft:kind = "air"
	effects.puff(point,kind,.45)

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
		var distance := heavy_definition.blast_radius
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
			closest.receive_projectile_hit(damage_at_distance(distance) / maxf(closest.definition.airframe_multiplier,.001), point)

func damage_at_distance(distance: float) -> float:
	return heavy_definition.damage_at_distance(distance)
