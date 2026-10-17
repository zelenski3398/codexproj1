class_name ItalianEnemy
extends EnemyAircraft
@export var definition: EnemyAircraftDefinition
var additional_gunners: Array[RearGunner] = []

func configure_airframe() -> void:
	if definition == null:
		definition = EnemyAircraftDefinition.find("c200")
	aircraft_kind = definition.id
	marker_name = definition.marker
	display_name = definition.title
	team_id = CombatTeams.ENEMY
	collision_wing_span = definition.wingspan
	wing_area = definition.wing_area
	engine_thrust = definition.thrust
	parasite_drag = definition.drag
	stall_speed = definition.stall_speed
	pitch_torque = definition.control_torque.x
	rudder_torque = definition.control_torque.y
	roll_torque = definition.control_torque.z

func create_model() -> SpitfireModel:
	var visual: ItalianAircraftModel = definition.model_script.new()
	visual.kind = definition.id
	return visual

func default_damage_profile() -> AircraftDamageProfile:
	return definition.damage

func create_pilot() -> EnemyPilot:
	var controller: EnemyPilot = BomberPilot.new() if definition.bomber else EscortPilot.new()
	controller.cruise_speed = definition.cruise_speed
	controller.maximum_bank_degrees = definition.maximum_bank
	controller.maximum_tactical_bank_degrees = definition.maximum_bank
	return controller

func create_gunner() -> RearGunner:
	var gunner: RearGunner = RearGunner.new()
	if definition.bomber:
		gunner.mount_model = (model as ItalianAircraftModel).defensive_mounts[0]
		gunner.rounds_per_second = definition.defensive_rate
		gunner.bullet_damage = definition.defensive_damage
		gunner.minimum_elevation_degrees = -5
	else:
		# Retain the shared diagnostics interface; single-seat fighters have no gunner.
		var dummy: DefensiveGunMount = DefensiveGunMount.new()
		model.add_child(dummy)
		dummy.visible = false
		gunner.mount_model = dummy
		gunner.enabled = false
	return gunner

func _ready() -> void:
	super._ready()
	mass = definition.mass_kg
	inertia = definition.body_inertia
	health.max_hp = definition.maximum_hp
	health.reset()
	damage_effects.engine_source = Vector3(0, 0.32, -7 if definition.bomber else -3.2)
	gear.retractable = not definition.fixed_gear
	gear.extended = definition.fixed_gear
	guns.rounds_per_second = definition.gun_rate if not definition.bomber else 0
	guns.bullet_speed = definition.bullet_speed
	guns.bullet_damage = definition.bullet_damage
	guns.bullet_lifetime = definition.bullet_lifetime
	guns.spread_degrees = definition.dispersion
	# Replace only this type's coarse contact geometry, keeping actual bullet sensors.
	for child in get_children():
		if child is CollisionShape3D:
			remove_child(child)
			child.queue_free()
	_contact_box(definition.body_size, Vector3.ZERO)
	_contact_box(Vector3(definition.lower_wing_span if definition.lower_wing_span > 0 else definition.wingspan, 0.18, definition.wing_chord), Vector3(0, -0.3, -0.45))
	if definition.id == "cr42":
		_contact_box(Vector3(definition.wingspan, 0.18, 1.75), Vector3(0, 1.45, -0.8))
	_contact_box(Vector3(0.22, 1.6 if not definition.bomber else 2.5, 1.4 if not definition.bomber else 2.3), Vector3(0, 0.7 if not definition.bomber else 1, 3.4 if not definition.bomber else 6.5))
	if definition.bomber:
		var ventral: RearGunner = RearGunner.new()
		ventral.aircraft = self
		ventral.crew_component = &"ventral_gunner"
		ventral.mount_model = (model as ItalianAircraftModel).defensive_mounts[1]
		ventral.minimum_elevation_degrees = -55
		ventral.maximum_elevation_degrees = -5
		ventral.rounds_per_second = definition.defensive_rate
		ventral.bullet_damage = definition.defensive_damage
		ventral.aim_seed = 1979
		add_child(ventral)
		additional_gunners.append(ventral)
	pending_reset_velocity = Vector3(0, 0, -definition.cruise_speed)

func _contact_box(size: Vector3, at: Vector3) -> void:
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = at
	add_child(collider)

func _destroy() -> void:
	for gunner in additional_gunners:
		gunner.cease_fire()
		gunner.set_physics_process(false)
	super._destroy()

func _reset_life() -> void:
	super._reset_life()
	gear.extended = definition.fixed_gear
	for gunner in additional_gunners:
		gunner.reset()
		gunner.set_physics_process(true)
