class_name PracticeTarget
extends StaticBody3D
## Reusable take_damage receiver on a thin collision panel beside the airfield.
var health: AircraftHealth
var label: Label3D
var panel: MeshInstance3D
var live_material := MeshKit.material(Color("a16e46"))
var dead_material := MeshKit.material(Color("343834"))

func _ready() -> void:
	collision_layer = 5 # normal terrain collision plus the damageable-target layer
	collision_mask = 2
	position = Vector3(-75, 12, 440)
	health = AircraftHealth.new()
	health.max_hp = 500.0
	add_child(health)
	var shape := BoxShape3D.new()
	shape.size = Vector3(14, 14, 0.25)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	panel = MeshKit.box(self, shape.size, Vector3.ZERO, live_material)
	for radius in [5.0, 3.4, 1.5]:
		var disc := MeshKit.cylinder(self, radius, 0.03, Vector3(0, 0, 0.16 + (5.0 - radius) * 0.015), MeshKit.material(Color("e8dfc3") if radius == 3.4 else Color("a13f36")))
		disc.rotation.x = PI / 2.0
	for x in [-5.0, 5.0]:
		MeshKit.box(self, Vector3(0.5, 5, 0.5), Vector3(x, -9.5, 0), MeshKit.material(Color("6d6650")))
	label = Label3D.new()
	label.position = Vector3(0, 9.0, 0.3)
	label.font_size = 72
	label.pixel_size = 0.04
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	health.changed.connect(_update_label)
	_update_label(health.hp, health.max_hp)

func take_damage(amount: float) -> void:
	health.take_damage(amount)

func reset_target() -> void:
	health.reset()

func _update_label(hp: float, maximum: float) -> void:
	label.text = "PRACTICE TARGET  %d/%d HP" % [ceili(hp), roundi(maximum)] if hp > 0 else "TARGET DESTROYED · R TO RESET"
	panel.material_override = live_material if hp > 0 else dead_material
