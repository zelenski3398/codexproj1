class_name AircraftHitbox
extends Area3D
## Bullet-only sensor: the parent aircraft's rigid body still handles terrain.
const LAYER: int = 8
var damage_system: AircraftDamage
var definition: AircraftComponentDefinition
var wires: Array[MeshInstance3D] = []
var wire_material: StandardMaterial3D

func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = false
	wire_material = StandardMaterial3D.new()
	wire_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wire_material.no_depth_test = true
	wire_material.albedo_color = definition.debug_color
	for spec in definition.hitboxes:
		var collision: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = spec.size
		collision.shape = box
		collision.position = spec.position
		collision.rotation_degrees = spec.rotation_degrees
		add_child(collision)
		var mesh: ImmediateMesh = ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var vertices: Array[Vector3] = []
		for i in range(8):
			vertices.append(Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1) * spec.size * 0.5)
		for i in range(8):
			for bit in [1, 2, 4]:
				if (i & bit) == 0:
					mesh.surface_add_vertex(vertices[i])
					mesh.surface_add_vertex(vertices[i | bit])
		mesh.surface_end()
		var wire: MeshInstance3D = MeshInstance3D.new()
		wire.mesh = mesh
		wire.material_override = wire_material
		wire.position = spec.position
		wire.rotation_degrees = spec.rotation_degrees
		wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wire)
		wires.append(wire)
	update_debug(false)

func get_team_id() -> int:
	return damage_system.aircraft.team_id

func take_damage(amount: float) -> void:
	damage_system.apply_damage(definition.id, amount)

func receive_projectile_hit(amount: float, point: Vector3) -> void:
	damage_system.apply_damage(definition.id, amount, point)

func update_debug(enabled: bool, selected: bool = false) -> void:
	for wire in wires:
		wire.visible = enabled
	if enabled:
		var ratio: float = damage_system.integrity_ratio(definition.id)
		var color: Color = Color.WHITE if selected else Color("ff5144").lerp(definition.debug_color, ratio)
		if wire_material.albedo_color != color:
			wire_material.albedo_color = color
