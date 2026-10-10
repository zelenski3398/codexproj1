class_name EnemyAircraft
extends FlightAircraft
## Separate visual, shared flight/health/guns, and a one-shot wreck lifecycle.
signal ground_impact(point: Vector3)
signal wreck_removed
@export var wreck_remove_delay: float = 4.0
var ai: EnemyPilot
var target: FlightAircraft
var impact_started: bool = false
var wreck_age: float = 0
var impact_count: int = 0

func _init() -> void:
	reset_position = Vector3(-450, 160, 0)

func default_damage_profile() -> AircraftDamageProfile:
	return preload("res://damage_profiles/stuka.tres")

func create_model() -> SpitfireModel:
	return StukaModel.new()

func _ready() -> void:
	display_name = "Ju 87 Stuka"
	team_id = CombatTeams.ENEMY
	collision_wing_span = 13.6
	wing_area = 26.0
	engine_thrust = 11500.0
	super._ready()
	collision_layer = 4
	collision_mask = 3
	gear.retractable = false
	pilot.automated = true
	guns.rounds_per_second = 6.0
	guns.name = "TwoWingGuns"
	guns.bullet_speed = 650.0
	guns.bullet_damage = 2.0
	guns.spread_degrees = 0.08
	guns.pool.tracer_material.albedo_color = Color("ff946a")
	ai = EnemyPilot.new()
	ai.aircraft = self
	ai.target = target
	ai.patrol_center.y = reset_position.y
	ai.name = "EnemyPilot"
	add_child(ai)
	reset_completed.connect(_reset_life)
	request_reset()
	pending_reset_pose = Transform3D(Basis.IDENTITY, reset_position)
	pending_reset_velocity = Vector3(0, 0, -58)

func _input(_event: InputEvent) -> void:
	pass # Only the player's aircraft receives G/H and other pilot shortcuts.

func _reset_life() -> void:
	impact_started = false
	wreck_age = 0
	ai.set_physics_process(true)
	ai.reset()

func _destroy() -> void:
	if is_destroyed:
		return
	ai.mode = "DESTROYED"
	ai.set_physics_process(false)
	super._destroy()

func _crash(_reason: String) -> void:
	# Fatal airframe/terrain contact enters the same single destroyed life.
	if not is_destroyed:
		take_damage(health.max_hp)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(state)
	if not is_destroyed or impact_started:
		return
	var grounded: bool = gear.contact_count > 0
	for i in range(state.get_contact_count()):
		var collider: Object = state.get_contact_collider_object(i)
		if collider is CollisionObject3D and (collider.collision_layer & 1) != 0:
			grounded = true
	if grounded:
		impact_started = true # latch inside physics before deferring the visual
		call_deferred("_finish_impact", state.transform.origin)

func _finish_impact(point: Vector3) -> void:
	if is_queued_for_deletion():
		return
	impact_count += 1
	damage_effects.clear()
	freeze = true # after contact only; airborne wrecks remain force-driven
	ground_impact.emit(point)

func _physics_process(delta: float) -> void:
	if not impact_started:
		return
	wreck_age += delta
	if wreck_age >= wreck_remove_delay:
		wreck_removed.emit()
		queue_free()
		set_physics_process(false)
