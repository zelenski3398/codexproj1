class_name DuelAircraft
extends RefCounted

const ALLIES := ["spitfire", "sea_gladiator", "hurricane"]
const AXIS := ["bf109_e4", "bf109_f4", "cr42", "c200", "c202"]
const CENTRE := Vector3(5400, 0, -2800)
const WAYPOINTS := [Vector3(3100, 480, 600), Vector3(7800, 480, -5100)]
const BOUNDARY := 7200.0
const FALLBACK_ROUNDS := 350

static func make(parent: Node3D, kind: String, side: int) -> FlightAircraft:
	var plane: FlightAircraft
	if kind in ALLIES:
		plane = AlliedAircraft.create(kind)
	elif kind in Bf109.KINDS:
		var german := Bf109.new()
		german.variant = kind
		plane = german
	else:
		var italian := ItalianEnemy.new()
		italian.definition = EnemyAircraftDefinition.find(kind)
		plane = italian
	parent.add_child(plane)
	plane.input_enabled = false
	plane.preserve_fired_rounds = true
	plane.set_process_input(false)
	plane.team_id = CombatTeams.PLAYER if side == 0 else CombatTeams.ENEMY
	plane.collision_mask = 1
	plane.pilot.automated = true
	plane.devices.remote_commands = true
	if plane is EnemyAircraft:
		var enemy := plane as EnemyAircraft
		var stop_ai := func():
			enemy.ai.set_physics_process(false)
			enemy.rear_gunner.set_physics_process(false)
		stop_ai.call()
		plane.reset_completed.connect(stop_ai)
	for battery in batteries(plane):
		var gun := battery as WingGuns
		if gun.rounds_per_port < 0:
			gun.rounds_per_port = FALLBACK_ROUNDS
		gun.remaining_by_port.fill(gun.rounds_per_port)
		gun.externally_controlled = true
	return plane

static func batteries(plane: FlightAircraft) -> Array[WingGuns]:
	if plane is Bf109:
		return [plane.guns, plane.cannon]
	return [plane.guns]

static func title(kind: String) -> String:
	if kind in ALLIES: return AlliedAircraft.title(kind)
	if kind in Bf109.KINDS: return Bf109.title(kind)
	var definition := EnemyAircraftDefinition.find(kind)
	return definition.title if definition != null else kind

static func nation(kind: String) -> String:
	if kind in ALLIES: return "British"
	return "German" if kind in Bf109.KINDS else "Italian"

static func spawn(plane: FlightAircraft, world: MaltaWorld, side: int) -> void:
	plane.request_reset()
	var field: MaltaAirfield = world.fields.ta_qali
	if side == 0:
		plane.pending_reset_pose = field.global_transform * Transform3D(Basis(Vector3.RIGHT, .117), Vector3(0, 1.6, 500))
	else:
		var start := Vector3(8950, 480, -6800)
		var direction: Vector3 = (WAYPOINTS[1] - start).normalized()
		plane.pending_reset_pose = Transform3D(Basis.looking_at(direction), start)
		plane.pending_reset_velocity = direction * 68.0
	plane.reset_completed.connect(func():
		plane.engine_running = true
		plane.gear.extended = side == 0 or not plane.gear.retractable
		plane.pilot.throttle = .66 if side == 1 else 0.0
	, CONNECT_ONE_SHOT)

static func pack(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func vector(v: Array) -> Vector3:
	return Vector3(float(v[0]), float(v[1]), float(v[2]))
