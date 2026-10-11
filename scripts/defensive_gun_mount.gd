class_name DefensiveGunMount
extends Node3D
## Flexible rear-facing mount shared with the Stuka's human gunner logic.
var rear_mount: Node3D
var rear_cradle: Node3D
var rear_muzzle: Marker3D

func _ready() -> void:
	rear_mount = Node3D.new()
	add_child(rear_mount)
	rear_cradle = Node3D.new()
	rear_mount.add_child(rear_cradle)
	rear_muzzle = Marker3D.new()
	rear_muzzle.position = Vector3(0, 0, 1.05)
	rear_muzzle.rotation.y = PI
	rear_cradle.add_child(rear_muzzle)
	var metal: StandardMaterial3D = MeshKit.material(Color("292d28"))
	MeshKit.rod(rear_cradle, Vector3.ZERO, Vector3(0, 0, 1), 0.045, metal)

func set_rear_gun_angles(yaw: float, elevation: float) -> void:
	rear_mount.rotation.y = yaw
	rear_cradle.rotation.x = -elevation
