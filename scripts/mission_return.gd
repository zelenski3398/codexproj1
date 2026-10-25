class_name MissionReturn
extends Node
## Defers success presentation only. Flight, damage and landing remain physical.
@export var maximum_landing_speed: float = 8.0
@export var maximum_vertical_speed: float = 1.5
@export var settled_seconds: float = 2.0
var mission: MaltaMission
var pending: bool = false
var director: Node
var approved_owner: Node
var reason: String = ""
var required_aircraft: FlightAircraft
var destination: String = ""
var settled: float = 0
var generation: int = 0
var delivery_queued: bool = false
var marker: Label

func _ready() -> void:
	marker=Label.new();marker.mouse_filter=Control.MOUSE_FILTER_IGNORE
	marker.add_theme_font_size_override("font_size",16)
	marker.add_theme_color_override("font_color",Color("e4bf75"))
	marker.add_theme_color_override("font_shadow_color",Color.BLACK)
	marker.add_theme_constant_override("shadow_offset_x",1)
	marker.add_theme_constant_override("shadow_offset_y",1)
	mission.canvas.add_child(marker);marker.hide()

func landed_field(aircraft: FlightAircraft) -> String:
	if not is_instance_valid(aircraft) or aircraft.is_destroyed or aircraft.is_crashed or not aircraft.gear.extended or aircraft.gear.contact_count<2:return ""
	if aircraft.linear_velocity.length()>maximum_landing_speed or absf(aircraft.linear_velocity.y)>maximum_vertical_speed:return ""
	if aircraft.global_basis.y.dot(Vector3.UP)<.85:return ""
	for id in mission.world.fields:
		var field: MaltaAirfield=mission.world.fields[id]
		var local: Vector3=field.to_local(aircraft.global_position)
		# Runway or existing apron; countryside alone and the sea do not count.
		var runway: bool=absf(local.x)<=27 and absf(local.z)<=field.runway_length*.5
		var apron: bool=absf(local.x-61)<=48 and absf(local.z-field.runway_length*.31)<=115
		if (runway or apron) and absf(local.y)<3:return id
	return ""

func _ground_base() -> String:
	var anchor: Node3D=mission.pilot
	if is_instance_valid(mission.interaction.occupied_gun):anchor=mission.interaction.occupied_gun
	elif is_instance_valid(mission.interaction.occupied_vehicle):
		if not mission.interaction.occupied_vehicle.grounded:return ""
		anchor=mission.interaction.occupied_vehicle
	for id in mission.world.fields:
		if mission.world.fields[id].contains(anchor.global_position):return id
	# Fort AA is a valid ground duty station, never an aircraft landing area.
	if mission.initial_spawn_id.begins_with("st_elmo") and anchor.global_position.distance_to(StElmoLocations.position_for("st_elmo"))<200:return "st_elmo"
	return ""

func hold_success(controller: Node,message: String) -> bool:
	if approved_owner==controller:return false
	if pending:return true
	var plane: FlightAircraft=mission.occupied
	if is_instance_valid(plane):
		if not landed_field(plane).is_empty():return false
	elif not _ground_base().is_empty():return false
	pending=true;director=controller;reason=message;required_aircraft=plane
	settled=0;delivery_queued=false;generation+=1
	destination=mission.home
	if not controller is EnemyEncounters:controller.phase="RETURNING"
	mission.session.encounters.awaiting_confirmation=false
	_stand_down()
	mission._message("Objectives secured — return to a friendly airfield and land safely")
	return true

func _stand_down() -> void:
	var units: Array=[]
	units.append_array(mission.session.encounters.active)
	if is_instance_valid(mission.session.harbour):units.append_array(mission.session.harbour.wingmen)
	for unit in units:
		if not is_instance_valid(unit):continue
		unit.ai.target=null;unit.ai.combat_enabled=false;unit.pilot.fire=false
		unit.guns.external_fire=false;unit.guns.reset(false)
		if unit is EnemyAircraft:
			unit.target=null;unit.rear_gunner.cease_fire();unit.rear_gunner.enabled=false

func cancel_owner(controller: Node) -> void:
	if director==controller:clear()

func clear() -> void:
	generation+=1;pending=false;director=null;approved_owner=null;required_aircraft=null
	reason="";settled=0;delivery_queued=false
	if is_instance_valid(marker):marker.hide()

func _fail(message: String) -> void:
	var controller: Node=director
	clear()
	if not is_instance_valid(controller):return
	if controller is EnemyEncounters:controller.finish_survival(false,message)
	else:controller._finish(false,message)

func _physics_process(delta: float) -> void:
	if not pending or get_tree().paused:return
	if not is_instance_valid(director) or not director.is_inside_tree() or director.is_queued_for_deletion():clear();return
	if not mission.survival.alive():_fail("Pilot lost during return to base");return
	var field: String=""
	if required_aircraft!=null:
		if not is_instance_valid(required_aircraft) or required_aircraft.is_crashed or required_aircraft.is_destroyed:
			_fail("Aircraft lost before completing its return and landing");return
		if mission.occupied==required_aircraft:field=landed_field(required_aircraft)
	else:
		field=landed_field(mission.occupied) if is_instance_valid(mission.occupied) else _ground_base()
	settled=settled+delta if not field.is_empty() else 0
	if settled>=settled_seconds and not delivery_queued:
		delivery_queued=true;call_deferred("_deliver",generation)

func _deliver(token: int) -> void:
	if token!=generation or not pending or not is_inside_tree() or not is_instance_valid(director):return
	if not director.is_inside_tree() or director.is_queued_for_deletion():return
	if not mission.survival.alive():_fail("Pilot lost during return to base");return
	# Recheck after deferred destruction callbacks, before granting success.
	if required_aircraft!=null and (not is_instance_valid(required_aircraft) or mission.occupied!=required_aircraft or landed_field(required_aircraft).is_empty()):
		settled=0;delivery_queued=false;return
	if get_tree().paused:
		delivery_queued=false;return
	if required_aircraft==null:
		var field: String=landed_field(mission.occupied) if is_instance_valid(mission.occupied) else _ground_base()
		if field.is_empty():settled=0;delivery_queued=false;return
	approved_owner=director
	if director is EnemyEncounters:director.finish_survival(true,reason)
	else:director._finish(true,reason)
	clear()

func objective_point() -> Vector3:
	return mission.world.fields[destination].global_position if mission.world.fields.has(destination) else mission.world.fields[mission.home].global_position

func _process(_delta: float) -> void:
	marker.visible=pending and not get_tree().paused
	if not marker.visible:return
	var camera:=get_viewport().get_camera_3d()
	if camera==null:marker.hide();return
	var target: Vector3=objective_point()+Vector3.UP*12
	var size: Vector2=get_viewport().get_visible_rect().size
	var local: Vector3=camera.to_local(target)
	var direction:=Vector2(local.x,-local.y)
	if direction.length_squared()<.001:direction=Vector2.RIGHT
	var point: Vector2=camera.unproject_position(target) if local.z<-.1 else size*.5+direction.normalized()*size.length()
	marker.position=Vector2(clampf(point.x-100,20,size.x-280),clampf(point.y,200,size.y-270))
	marker.text="◇ LAND · %s · %d m"%[mission.world.fields[destination].record.name,roundi(camera.global_position.distance_to(target))]
