class_name WingmanSpotter
extends Node
## Only current, visible hostiles enter memory. Reports never read hidden positions.
var observer: FriendlyGladiator
var director: HarbourInterception
var sightings: Dictionary = {}
var visible: Dictionary = {}
var clock: float = 0
var scan_remaining: float = 0

func _physics_process(delta: float) -> void:
	clock += delta
	scan_remaining -= delta
	if scan_remaining <= 0:
		scan_remaining = director.definition.radio_spotting_interval
		scan()

func scan() -> void:
	visible.clear()
	if not is_instance_valid(observer) or observer.is_destroyed or observer.is_crashed: return
	for foe in director.session.encounters.active:
		if not is_instance_valid(foe) or foe.is_destroyed or foe.is_crashed: continue
		var offset: Vector3 = foe.global_position - observer.global_position
		if offset.length() > director.definition.radio_spotting_distance: continue
		if offset.length() > 1 and (-observer.global_basis.z).angle_to(offset) > deg_to_rad(director.definition.radio_spotting_fov * .5): continue
		var query := PhysicsRayQueryParameters3D.create(observer.global_position + Vector3.UP * 1.2, foe.global_position, 1)
		if not observer.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var record: Dictionary = {"id":foe.get_instance_id(), "position":foe.global_position, "time":clock, "kind":foe.aircraft_kind, "bomber":foe == director.bomber, "threat":"", "fort":""}
		# Inferred threats from observed heading/closure; do not read enemy AI intent.
		var friends: Array[FlightAircraft] = [director.session.aircraft]
		for friend in director.wingmen:
			if is_instance_valid(friend) and not friend.is_destroyed: friends.append(friend)
		for friend in friends:
			var toward: Vector3 = friend.global_position - foe.global_position
			if toward.length() > 1000 or toward.length() < 1: continue
			if (-foe.global_basis.z).dot(toward.normalized()) > .86 and (foe.linear_velocity - friend.linear_velocity).dot(toward.normalized()) > 5:
				record.threat = "Faith" if friend == director.session.aircraft else friend.callsign
				break
		if record.bomber and is_instance_valid(director.target_fort):
			var toward: Vector3 = director.target_fort.global_position - foe.global_position
			if toward.length() < 2500 and (-foe.global_basis.z).dot(toward.normalized()) > .7: record.fort = director.target_fort.title
		visible[record.id] = record
		sightings[record.id] = record
	for id in sightings.keys():
		if clock - float(sightings[id].time) > director.definition.radio_memory_seconds: sightings.erase(id)
