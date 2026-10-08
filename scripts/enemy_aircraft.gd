class_name EnemyAircraft
extends FlightAircraft
## Shares the player's actual force-driven flight, damage and gun components.
var ai: EnemyPilot
var target: FlightAircraft

func create_model() -> SpitfireModel:
	return StukaModel.new()

func _ready() -> void:
	reset_position = Vector3(-450, 160, 0)
	collision_wing_span = 13.6
	wing_area = 26.0
	engine_thrust = 11500.0
	super._ready()
	collision_layer = 4
	collision_mask = 3 # countryside and player aircraft
	pilot.automated = true
	pilot.throttle = 0.6
	guns.rounds_per_second = 6.0
	guns.name = "TwoWingGuns"
	guns.bullet_speed = 650.0
	guns.bullet_damage = 2.0
	guns.pool.tracer_material.albedo_color = Color("ff946a")
	ai = EnemyPilot.new()
	ai.aircraft = self
	ai.target = target
	ai.name = "EnemyPilot"
	add_child(ai)
	reset_completed.connect(ai.reset)
	request_reset()
	pending_reset_pose = Transform3D(Basis.IDENTITY, reset_position)
	pending_reset_velocity = Vector3(0, 0, -58)

func _input(_event: InputEvent) -> void:
	# Player keys, especially G/H, must never control or damage the enemy.
	pass

func reset_encounter() -> void:
	# Clear enemy rounds immediately when the player resets, not a tick later.
	guns.reset()
	damage_effects.clear()
	ai.reset()
	request_reset()
	pending_reset_pose = Transform3D(Basis.IDENTITY, reset_position)
	pending_reset_velocity = Vector3(0, 0, -58)

