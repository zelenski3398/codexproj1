class_name MissionBomb
extends Node3D
## Finite cosmetic ordnance: inherited aircraft velocity, gravity and a swept
## terrain ray. No direct damage to the player, no mass-raid simulation.
signal impacted(point: Vector3)
var velocity: Vector3
var age: float = 0
var impact_effects: Node3D

func _ready() -> void:
	MeshKit.sphere(self, Vector3(0.22, 0.22, 0.75), Vector3.ZERO, MeshKit.material(Color("292d25")))
	MeshKit.box(self, Vector3(0.4, 0.03, 0.2), Vector3(0, 0, 0.3), MeshKit.material(Color("857859")))

func _physics_process(delta: float) -> void:
	age += delta
	velocity.y -= 9.81 * delta
	var next: Vector3 = global_position + velocity * delta
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, next, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var burst: DestructionBurst = DestructionBurst.new()
		impact_effects.add_child(burst)
		burst.global_position = hit.position
		burst.scale = Vector3.ONE * 2
		impacted.emit(hit.position)
		queue_free()
	else:
		global_position = next
		if velocity.length_squared() > 1:
			look_at(global_position + velocity)
	if age > 40:
		queue_free()
