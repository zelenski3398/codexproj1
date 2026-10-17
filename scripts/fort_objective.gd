class_name FortObjective
extends Node3D
## Health belongs to this mission, not the geographical city meshes/collisions.
## Physical bomb impacts measure against the real fort footprint and elevation.
signal destroyed
var title: String
var maximum_hp: float = 1000
var hp: float = 1000
var footprint: PackedVector2Array
var destruction_count: int = 0

func _ready() -> void:
	add_to_group("mission_forts")
	hp = maximum_hp

func get_team_id() -> int: return CombatTeams.PLAYER

func blast_distance(point: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	var horizontal: float = 0
	if not Geometry2D.is_point_in_polygon(p, footprint):
		horizontal = INF
		for i in footprint.size():
			horizontal = minf(horizontal, p.distance_to(Geometry2D.get_closest_point_to_segment(p, footprint[i], footprint[(i + 1) % footprint.size()])))
	return Vector2(horizontal, maxf(absf(point.y - global_position.y) - 30, 0)).length()

func take_damage(amount: float) -> void:
	if hp <= 0 or amount <= 0: return
	hp = clampf(hp - amount, 0, maximum_hp)
	if hp == 0:
		destruction_count += 1
		destroyed.emit()
