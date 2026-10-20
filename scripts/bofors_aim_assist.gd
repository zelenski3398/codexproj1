class_name BoforsAimAssist
extends RefCounted
## Small opt-in nudge around the player's sight. Never fires or bends shells.
var gun: BritishAAGun
var target: FlightAircraft
var scan_clock: float = 0
func update(delta: float) -> void:
	if gun.weapon.heavy or not AAMouseControls.bofors_assist or not gun.mounted or gun.mouse_controls.blocked():
		target = null
		return
	scan_clock -= delta
	if scan_clock <= 0:
		scan_clock = .15
		target = null
		var best: float = deg_to_rad(gun.weapon.assist_cone_degrees)
		for unit in gun.get_tree().get_nodes_in_group("combat_aircraft"):
			if not eligible(unit): continue
			var angle: float = (-gun.muzzle.global_basis.z).angle_to(unit.global_position - gun.muzzle.global_position)
			if angle < best and visible_target(unit): best = angle; target = unit
	if not is_instance_valid(target) or not eligible(target) or not visible_target(target):
		target = null
		return
	if (-gun.muzzle.global_basis.z).angle_to(target.global_position-gun.muzzle.global_position) > deg_to_rad(gun.weapon.assist_cone_degrees):
		target = null
		return
	var solution := AAFireControl.solve(gun.muzzle.global_position, target.global_position, target.linear_velocity, gun.projectile_speed, gun.battery.pool_for(gun.weapon).gravity, gun.maximum_lifetime)
	if solution.is_empty() or not solution.valid: return
	var local: Vector3 = gun.yaw.get_parent().global_basis.inverse() * solution.direction
	var yaw: float = atan2(-local.x, -local.z)
	var pitch: float = atan2(local.y, Vector2(local.x, local.z).length())
	if pitch < deg_to_rad(gun.minimum_elevation_degrees) or pitch > deg_to_rad(gun.maximum_elevation_degrees): return
	var limit: float = deg_to_rad(gun.weapon.assist_degrees_per_second) * delta
	var blend: float = 1-exp(-gun.weapon.assist_strength*delta)
	gun.mouse_controls.target_yaw += clampf(wrapf(yaw-gun.mouse_controls.target_yaw,-PI,PI)*blend,-limit,limit)
	gun.mouse_controls.target_elevation += clampf((pitch-gun.mouse_controls.target_elevation)*blend,-limit,limit)
func eligible(unit: FlightAircraft) -> bool:
	return is_instance_valid(unit) and not unit.is_destroyed and not unit.is_crashed and unit.team_id == CombatTeams.ENEMY and unit.global_position.distance_to(gun.muzzle.global_position) <= gun.range_metres
func visible_target(unit: FlightAircraft) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(gun.muzzle.global_position, unit.global_position, 15, [gun.get_rid()])
	ray.collide_with_areas = true
	var hit: Dictionary = gun.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.collider == unit or (hit.collider is AircraftHitbox and hit.collider.damage_system.aircraft == unit)
