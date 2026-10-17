class_name FriendlyGladiator
extends SeaGladiator
## Same SeaGladiator airframe, guns, component damage and crash physics as Faith.
var callsign: String = "Hope"
var ai: HarbourCombatPilot
var wreck_age: float = 0

func _ready() -> void:
	input_enabled = false
	engine_running = true
	fuel_consumption_rate = 1.0 / 7200.0
	super._ready()
	display_name = callsign + " · Sea Gladiator"
	collision_mask = 7
	pilot.automated = true
	seated_pilot.visible = true
	ai = HarbourCombatPilot.new()
	ai.aircraft = self
	ai.measured_terrain = true
	ai.world_extent = INF
	ai.grace_period = 0
	ai.cruise_speed = 48
	ai.engage_speed_bonus = 10
	ai.detection_range = 3600
	ai.pursuit_release_range = 4600
	ai.minimum_agl = 60
	ai.takeoff_hold = true
	add_child(ai)

func _input(_event: InputEvent) -> void:
	pass

func _physics_process(delta: float) -> void:
	if is_crashed and not is_destroyed: take_damage(health.max_hp)
	if is_destroyed:
		wreck_age += delta
		if wreck_age >= 25: queue_free()
