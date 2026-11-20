class_name BombStructureSection
extends StaticBody3D
## Reusable box-section receiver for raid scenery. IDs are stable across retries.

signal collapsed(section_id: StringName)

@export var section_id: StringName
@export var size: Vector3 = Vector3(4, 3, 4)
@export var maximum_hp: float = 100.0
var hp: float
var visual: MeshInstance3D
var solid: CollisionShape3D
var limestone := MeshKit.material(Color("b2a184"))
var damaged_stone := MeshKit.material(Color("786954"))

func _ready() -> void:
	hp = maximum_hp
	collision_layer = 1
	collision_mask = 0
	visual = MeshKit.box(self, size, Vector3.ZERO, limestone)
	solid = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	solid.shape = box
	add_child(solid)
	add_to_group("bomb_structure_sections")

func closest_point(point: Vector3) -> Vector3:
	var half := size * 0.5
	return to_global(to_local(point).clamp(-half, half))

func apply_blast(amount: float, origin: Vector3) -> float:
	if amount <= 0 or hp <= 0: return 0
	var dealt := minf(hp, amount)
	hp -= dealt
	if hp < maximum_hp * 0.65:
		visual.material_override = damaged_stone
	if hp <= 0:
		visual.hide()
		solid.set_deferred("disabled", true)
		call_deferred("_collapse", origin)
		collapsed.emit(section_id)
	return dealt

func _collapse(origin: Vector3) -> void:
	var thickness := minf(size.y * 0.24, 0.65)
	var rubble := MeshKit.box(self, Vector3(size.x * 0.78, thickness, size.z * 0.78), Vector3.DOWN * (size.y - thickness) * 0.5, damaged_stone)
	rubble.rotation.y = 0.12
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x * 0.75, thickness, size.z * 0.75)
	shape.shape = box
	shape.position = rubble.position
	add_child(shape)
	var available := 20 - get_tree().get_nodes_in_group("raid_debris").size()
	for i in range(mini(4, available)):
		var debris := RigidBody3D.new()
		debris.collision_layer = 0
		debris.collision_mask = 1
		debris.mass = 5
		var fragment := Vector3(0.55 + i * 0.13, 0.4, 0.55)
		var chunk := CollisionShape3D.new()
		var hull := BoxShape3D.new()
		hull.size = fragment
		chunk.shape = hull
		debris.add_child(chunk)
		MeshKit.box(debris, fragment, Vector3.ZERO, limestone)
		add_child(debris)
		debris.add_to_group("raid_debris")
		debris.position = Vector3(cos(i * 2.4), 0.5, sin(i * 2.4)) * 1.2
		var outward := (debris.global_position - origin).normalized()
		debris.linear_velocity = outward * 5.0 + Vector3.UP * (2.0 + i)
		debris.angular_velocity = Vector3(1.2, 2.1, i)
		var cleanup := Timer.new()
		cleanup.one_shot = true
		cleanup.autostart = true
		cleanup.wait_time = 9
		debris.add_child(cleanup)
		cleanup.timeout.connect(debris.queue_free)
