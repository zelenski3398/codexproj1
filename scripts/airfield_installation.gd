class_name AirfieldInstallation
extends StaticBody3D
## Existing projectile API, persistent HP and ruins; visiting a field never repairs it.
@export var max_hp: float = 250
@export var size: Vector3 = Vector3(22, 10, 32)
var hp: float = 250
var team_id: int = CombatTeams.NEUTRAL
var is_destroyed: bool = false
var display_name: String = "Hangar"
var visual: MeshInstance3D

func _ready() -> void:
	hp = max_hp
	visual = MeshKit.box(self, size, Vector3.ZERO, MeshKit.material(Color("a8997b")))
	visual.visibility_range_end = 4500
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	add_child(collision)

func take_damage(amount: float) -> void:
	if is_destroyed or not is_finite(amount) or amount <= 0:
		return
	hp = clampf(hp - amount, 0, max_hp)
	if hp == 0:
		is_destroyed = true
		visual.material_override = MeshKit.material(Color("443c33"))
		# Keep collision/ruins persistent; one destruction burst per installation.
		var burst: DestructionBurst = DestructionBurst.new()
		add_child(burst)

func get_team_id() -> int:
	return team_id
