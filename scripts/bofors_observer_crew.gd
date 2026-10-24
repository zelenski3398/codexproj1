class_name BoforsObserverCrew
extends StElmoCrew
## Same khaki avatar, health and walk transitions; a ground-level observer
## stance instead of the elevated Bofors gunner seat.
const STAND := Vector3(1.3,0,1.2)
func seat() -> void:
	if gun.is_destroyed or health.hp<=0:return
	seated=false;waiting=false
	if get_parent()!=gun:reparent(gun,false)
	position=STAND;rotation=Vector3.ZERO
	avatar.set_pose("Idle")
	for child in get_children():
		if child is CollisionShape3D:child.position.y=.85
func return_to_seat() -> void:
	if gun.is_destroyed or health.hp<=0 or not waiting:return
	if transition!=null:transition.kill()
	transitioning=true;avatar.set_pose("Walk")
	transition=create_tween()
	transition.tween_property(self,"global_position",gun.to_global(STAND),.65)
	transition.tween_callback(func():transitioning=false;seat())
