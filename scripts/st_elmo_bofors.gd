class_name StElmoBofors
extends BritishAAGun
var fort: StElmoBattery
var crew: StElmoCrew
var crew_wait: Vector3
func _ready() -> void:
	super._ready()
	crew=StElmoCrew.new()
	crew.gun=self
	add_child(crew)
func _input(event: InputEvent) -> void:
	if mounted and event.is_action_pressed("aa_battery_toggle") and not event.is_echo() and not mouse_controls.blocked():
		fort.toggle(self)
		get_viewport().set_input_as_handled()
func start_operation(operator: AirfieldInteraction=null) -> void:
	if crew.transitioning or is_destroyed:return
	var safe:=operator.find_exit(self,5) if operator!=null else to_global(Vector3(5,0,0))+Vector3.UP
	if safe==Vector3.INF:return
	if crew.health.hp>0:crew.move_to_wait(safe-Vector3.UP*1.05)
	else:crew.hide()
	super.start_operation(operator)
	# Hide the operator during the short seat-vacating walk to prevent overlap.
	mouse_controls.release_fire=true
func stop_operation() -> void:
	if is_instance_valid(fort) and fort.lead==self:fort.cancel()
	super.stop_operation()
	if is_instance_valid(crew) and not is_destroyed:crew.return_to_seat()
func take_damage(amount: float) -> void:
	super.take_damage(amount)
	if is_destroyed and is_instance_valid(crew):crew.fallen()
func fire_round(command_order: bool=false) -> bool:
	if is_instance_valid(crew) and crew.transitioning:return false
	# A short muzzle clearance test prevents firing into the fort's own walls.
	var query:=PhysicsRayQueryParameters3D.create(muzzle.global_position,muzzle.global_position-muzzle.global_basis.z*8,31,[get_rid()])
	query.collide_with_areas=true
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (not hit.collider.has_method("get_team_id") or hit.collider.get_team_id()!=CombatTeams.ENEMY):return false
	return super.fire_round(command_order)
func status_text() -> String:
	return super.status_text()+"\nST ELMO · %s · B toggle · Battery: %d/3 operational"%["BATTERY COMMAND" if fort.command_active() and fort.lead==self else "INDIVIDUAL GUN",fort.operational_count()]

func _physics_process(delta: float) -> void:
	if mounted and operator_session!=null and operator_session.mission.pilot.health.hp<=0:
		operator_session.leave_gun(true)
		return
	super._physics_process(delta)

func cancel_orders() -> void:
	if is_instance_valid(fort) and fort.lead==self:fort.cancel()
