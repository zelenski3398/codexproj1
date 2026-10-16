class_name StElmoCrew
extends CharacterBody3D
## Existing rig reused with khaki cloth and an original Brodie-style helmet.
## Visual transitions are brief walks, not a new boarding-animation claim.
var gun: BritishAAGun
var avatar: RafPilotAvatar
var waiting: bool=false
var transitioning: bool=false
var seated: bool=false
var health: AircraftHealth
var transition: Tween
func _ready() -> void:
	health=AircraftHealth.new()
	add_child(health)
	health.depleted.connect(fallen)
	add_to_group("damageable_ground_pilots")
	collision_layer=16
	collision_mask=1
	var collider:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.height=1.7;capsule.radius=.3
	collider.shape=capsule
	collider.position.y=.85
	add_child(collider)
	avatar=RafPilotAvatar.new()
	add_child(avatar)
	_recolour(avatar)
	var attachment:=BoneAttachment3D.new()
	attachment.bone_name="Head"
	avatar.skeleton.add_child(attachment)
	var steel:=MeshKit.material(Color("555b3f"))
	MeshKit.sphere(attachment,Vector3(.31,.11,.34),Vector3(0,.14,0),steel)
	MeshKit.cylinder(attachment,.19,.015,Vector3(0,.1,0),steel)
	seat()
func _recolour(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var mat: Material=node.mesh.surface_get_material(i)
			if mat!=null and ("RAF blue" in mat.resource_name or "Raised seams" in mat.resource_name):
				var copy: StandardMaterial3D=mat.duplicate()
				copy.albedo_color=Color("72715a")
				node.set_surface_override_material(i,copy)
	for child in node.get_children():_recolour(child)
func seat() -> void:
	if gun.is_destroyed or health.hp<=0:return
	seated=true
	waiting=false
	reparent(gun.yaw,false)
	position=Vector3(.95,-.15,.8)
	rotation=Vector3.ZERO
	avatar.set_pose("Seated")
	# Collision at the visible torso/seat, not an invisible standing capsule.
	for child in get_children():
		if child is CollisionShape3D:child.position.y=1
func move_to_wait(point: Vector3) -> void:
	if transition!=null:transition.kill()
	seated=false
	waiting=true
	transitioning=true
	reparent(gun.get_parent(),true)
	avatar.set_pose("Walk")
	look_at(Vector3(point.x,global_position.y,point.z))
	transition=create_tween()
	transition.tween_property(self,"global_position",point,.65)
	transition.tween_callback(func(): transitioning=false;avatar.set_pose("Idle"))
func return_to_seat() -> void:
	if gun.is_destroyed or health.hp<=0 or not waiting:return
	if transition!=null:transition.kill()
	transitioning=true
	avatar.set_pose("Walk")
	transition=create_tween()
	transition.tween_property(self,"global_position",gun.yaw.to_global(Vector3(.95,-.15,.8)),.65)
	transition.tween_callback(func():transitioning=false;seat())
func get_team_id() -> int:return CombatTeams.PLAYER
func take_damage(amount: float) -> void:
	health.take_damage(amount)
func fallen() -> void:
	if transition!=null:transition.kill()
	if not is_inside_tree():return
	if health!=null:health.hp=0
	if get_parent()==gun.yaw:reparent(gun.get_parent(),true)
	collision_layer=0
	avatar.set_pose("Idle")
	rotation.z=PI*.5
	seated=false
	transitioning=false
	waiting=false
