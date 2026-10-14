class_name DiveDefenceMission
extends Node3D
## Independent ground survival director. Only actual losses advance waves.
const WAVES: Array[int]=[1,1,2,2,3,1]
const BRIEFING: String="Stukas are approaching your position. Man an anti-aircraft gun and defend the airfield. They will attack your emplacement directly. Survive all six waves and destroy every attacker."
@export var definition: DiveDefenceDefinition=preload("res://mission_definitions/dive_defence.tres")
var session: Node3D
var guns: Array[BritishAAGun]=[]
var centre: Vector3
var phase: String="WAIT_MOUNT"
var wave: int=0
var clock: float=0
var wave_spawn_counts: Array[int]=[]
var alive: Array[EnemyAircraft]=[]
var retired_pools: Array[ProjectilePool]=[]
var total_spawned: int=0
var total_destroyed: int=0
var bombs_released: int=0
var result_count: int=0
var final_reason: String=""
var effects: Node3D
var canvas: CanvasLayer
var objective: Label
var marker: Label
var results: PanelContainer
var retry_button: Button
var return_button: Button
var _resolution_queued: bool=false
var cancelled: bool=false

func _ready() -> void:
	effects=Node3D.new()
	add_child(effects)
	_build_ui()
	call_deferred("_prepare")

func _prepare() -> void:
	for gun in session.malta_mission.world.aa_battery.guns:
		if String(gun.name).begins_with(session.home_airfield):
			guns.append(gun)
			gun.destroyed.connect(_queue_resolution)
	if guns.size()!=6:
		_finish(false,"Expected four heavy and two Bofors guns")
		return
	centre=Vector3.ZERO
	for gun in guns:centre+=gun.global_position/float(guns.size())
	var pilot: GroundPilot=session.malta_mission.pilot
	pilot.combat_enabled=true
	pilot.health.depleted.connect(_queue_resolution)
	pilot.add_to_group("damageable_ground_pilots")
	pilot.global_position=session.malta_mission.interaction.find_exit(guns[0],5)
	if not pilot.global_position.is_finite():pilot.global_position=guns[0].global_position+Vector3(7,1.1,0)
	pilot.velocity=Vector3.ZERO
	session.malta_mission._message("E Mount AA Gun · defend all six emplacements through six waves")

func is_finished() -> bool:return cancelled or phase in ["SUCCESS","FAILED"]
func choose_target(slot: int) -> BritishAAGun:
	var available: Array[BritishAAGun]=[]
	for gun in guns:
		if is_instance_valid(gun) and not gun.is_destroyed:available.append(gun)
	if available.is_empty():return null
	var mounted: BritishAAGun=session.malta_mission.interaction.occupied_gun
	if mounted!=null and available.has(mounted) and slot%2==0:return mounted
	return available[slot%available.size()]

func _physics_process(delta: float) -> void:
	for pool in retired_pools.duplicate():
		if pool.active.is_empty() and pool.spark_times.all(func(t):return t<=0):
			retired_pools.erase(pool)
			pool.queue_free()
	if is_finished() or guns.size()!=6:return
	_queue_resolution()
	if phase=="WAIT_MOUNT":
		if guns.has(session.malta_mission.interaction.occupied_gun):
			phase="PREPARING"
			clock=definition.first_countdown
	elif phase in ["PREPARING","INTERVAL"]:
		clock=maxf(0,clock-delta)
		if clock==0:
			phase="SPAWNING" # latch against reentrant/destruction callbacks
			call_deferred("_spawn_wave")
	elif phase=="DRAINING" and outstanding_ordnance()==0:
		if wave==WAVES.size():_queue_resolution()
		else:
			phase="INTERVAL"
			clock=definition.wave_interval

func _spawn_wave() -> void:
	if phase!="SPAWNING" or is_finished() or session.malta_mission.pilot.health.hp<=0 or operational_guns()==0:return
	wave+=1
	var count: int=WAVES[wave-1]
	var positions: Array[Vector3]=[]
	var forward: Vector3=(-session.malta_mission.world.fields[session.home_airfield].global_basis.z).rotated(Vector3.UP,deg_to_rad((wave-1)*30))
	var right: Vector3=forward.cross(Vector3.UP)
	for i in range(count):
		var point: Vector3=centre+forward*definition.spawn_distance+right*(i-(count-1)*.5)*definition.spawn_separation
		var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*3000,point-Vector3.UP*3000,1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		point.y=maxf(centre.y+definition.spawn_height,(float(hit.position.y) if not hit.is_empty() else 0)+definition.spawn_height)
		var sphere:=SphereShape3D.new()
		sphere.radius=20
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=sphere
		query.transform=Transform3D(Basis.IDENTITY,point)
		query.collision_mask=7
		if not get_world_3d().direct_space_state.intersect_shape(query).is_empty():
			_finish(false,"No safe attack-wave spawn")
			return
		positions.append(point)
	wave_spawn_counts.append(count)
	for i in range(count):
		var ace: bool=wave==6
		var foe: EnemyAircraft=session.create_encounter_enemy(positions[i],ace)
		var old: EnemyPilot=foe.ai
		foe.remove_child(old)
		old.queue_free()
		var ai:=DiveAttackPilot.new()
		ai.aircraft=foe
		ai.director=self
		ai.initial_slot=i
		ai.attack_delay=i*definition.attack_stagger
		ai.bomb_error=definition.ace_bomb_error if ace else definition.normal_bomb_error
		ai.strafe_error=definition.ace_strafe_error_degrees if ace else definition.normal_strafe_error_degrees
		ai.recovery_seconds=definition.ace_recovery_seconds if ace else definition.normal_recovery_seconds
		ai.aim_seed=1940+wave*10+i
		foe.ai=ai
		foe.add_child(ai)
		foe.guns.pool.hit_mask|=16
		foe.rear_gunner.guns.pool.hit_mask|=16
		foe.rear_gunner.set_physics_process(false)
		foe.rear_gunner.cease_fire()
		var direction: Vector3=((centre-positions[i])*Vector3(1,0,1)).normalized()
		foe.pending_reset_pose=Transform3D(Basis.looking_at(direction,Vector3.UP),positions[i])
		foe.pending_reset_velocity=direction*68
		session.encounters.track_enemy(foe)
		foe.health.changed.connect(_retain_hostile_rounds.bind(foe))
		foe.destroyed.connect(_enemy_destroyed.bind(foe))
		alive.append(foe)
		total_spawned+=1
	session.encounter_tracking_changed()
	phase="ACTIVE"

func release_bomb(foe: EnemyAircraft) -> void:
	if is_finished():return
	var bomb:=MissionBomb.new()
	bomb.velocity=foe.linear_velocity
	bomb.impact_effects=effects
	bomb.damage_pilots=true
	bomb.pilot_blast_damage=definition.player_blast_damage
	bomb.aa_blast_damage=definition.gun_blast_damage
	bomb.aa_blast_radius=definition.bomb_blast_radius
	effects.add_child(bomb)
	bomb.global_position=foe.to_global(Vector3(0,-1.4,1))
	bombs_released+=1

func outstanding_ordnance() -> int:
	var count: int=0
	for pool in retired_pools:
		if is_instance_valid(pool):count+=pool.active.size()
	for node in effects.get_children():
		if node is MissionBomb and not node.is_queued_for_deletion():count+=1
	for foe in session.encounters.active+session.encounters.wrecks:
		if not is_instance_valid(foe):continue
		count+=foe.guns.pool.active.size()+foe.rear_gunner.guns.pool.active.size()
	return count

func _retain_hostile_rounds(hp: float,_maximum: float,foe: EnemyAircraft) -> void:
	if hp>0 or cancelled:return
	# Aircraft destruction normally clears its gun pool. Detach live ordnance
	# before the shared depleted/destroy callbacks, without changing flight code.
	for guns_component in [foe.guns,foe.rear_gunner.guns]:
		var pool: ProjectilePool=guns_component.pool
		if pool.active.is_empty():continue
		pool.reparent(effects,true)
		retired_pools.append(pool)
		var empty:=ProjectilePool.new()
		empty.capacity=1
		empty.statistics=pool.statistics
		guns_component.pool=empty
		guns_component.add_child(empty)

func _enemy_destroyed(foe: EnemyAircraft) -> void:
	if not alive.has(foe):return
	alive.erase(foe)
	total_destroyed+=1
	if alive.is_empty() and phase=="ACTIVE":phase="DRAINING"
	_queue_resolution()
func operational_guns() -> int:
	var count: int=0
	for gun in guns:
		if is_instance_valid(gun) and not gun.is_destroyed:count+=1
	return count
func _queue_resolution() -> void:
	if session.malta_mission.pilot.health.hp<=0:
		for gun in guns:gun.stop_operation()
	if not _resolution_queued and not is_finished():
		_resolution_queued=true
		call_deferred("_resolve")
func _resolve() -> void:
	_resolution_queued=false
	if is_finished():return
	if session.malta_mission.pilot.health.hp<=0:_finish(false,"Operator killed")
	elif guns.size()==6 and operational_guns()==0:_finish(false,"All six AA emplacements destroyed")
	elif wave==6 and total_destroyed==10 and alive.is_empty() and outstanding_ordnance()==0:_finish(true,"All ten Stukas destroyed — airfield defended")
func _finish(won: bool,reason: String) -> void:
	if is_finished():return
	phase="SUCCESS" if won else "FAILED"
	final_reason=reason
	result_count+=1
	if session.malta_mission.interaction.occupied_vehicle!=null:session.malta_mission.interaction.occupied_vehicle.stop_driving()
	session.encounters.ended=true
	session.encounters.awaiting_confirmation=false
	for gun in session.malta_mission.world.aa_battery.guns:gun.stop_operation()
	for foe in session.encounters.active:
		foe.ai.set_physics_process(false)
		foe.pilot.fire=false
		foe.guns.external_fire=false
		foe.guns.externally_controlled=true
	results.visible=true
	results.get_child(0).get_child(0).text=("MISSION COMPLETE\n" if won else "MISSION FAILED\n")+reason
func cancel() -> void:
	cancelled=true
	for gun in guns:
		if is_instance_valid(gun):gun.stop_operation()
	for pool in retired_pools:
		if is_instance_valid(pool):pool.clear()
	for foe in session.encounters.active+session.encounters.wrecks:
		if is_instance_valid(foe):
			foe.guns.reset()
			foe.rear_gunner.guns.reset()

func _build_ui() -> void:
	canvas=CanvasLayer.new()
	canvas.layer=12
	add_child(canvas)
	objective=Label.new()
	objective.position=Vector2(32,150)
	objective.size=Vector2(750,200)
	objective.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_font_size_override("font_size",18)
	objective.add_theme_color_override("font_shadow_color",Color("17252b"))
	objective.add_theme_constant_override("shadow_offset_x",2)
	objective.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(objective)
	marker=Label.new()
	marker.add_theme_color_override("font_color",Color("ffe190"))
	canvas.add_child(marker)
	results=PanelContainer.new()
	results.position=Vector2(400,180)
	results.custom_minimum_size.x=480
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(.06,.1,.12,.96)
	style.set_content_margin_all(20)
	results.add_theme_stylebox_override("panel",style)
	canvas.add_child(results)
	var column:=VBoxContainer.new()
	results.add_child(column)
	var label:=Label.new()
	column.add_child(label)
	retry_button=Button.new()
	retry_button.text="RETRY"
	retry_button.pressed.connect(session.restart_malta,CONNECT_DEFERRED)
	column.add_child(retry_button)
	return_button=Button.new()
	return_button.text="RETURN TO MISSIONS"
	return_button.pressed.connect(session.return_to_missions,CONNECT_DEFERRED)
	column.add_child(return_button)
	results.hide()
func _process(_delta: float) -> void:
	if guns.size()!=6:return
	var screen: Vector2=get_viewport().get_visible_rect().size
	objective.position.x=32
	objective.size.x=screen.x-64
	var pilot: GroundPilot=session.malta_mission.pilot
	var instruction: String="Man an AA gun · E mount · arrows aim · Ctrl fire"
	if phase in ["PREPARING","INTERVAL"]:instruction="Prepare — next wave in %d s"%ceili(clock)
	elif phase=="DRAINING":instruction="Wave cleared — waiting for falling bombs / hostile rounds"
	elif phase=="ACTIVE":
		instruction="Defend your emplacement · E dismount · W/S airburst range"
		for foe in alive:
			if foe.ai is DiveAttackPilot and foe.ai.attack_state=="DIVE":instruction="STUKA DIVING ON THE EMPLACEMENTS — fire or reposition!"
	elif is_finished():instruction=final_reason
	var health_status := ""
	for i in range(guns.size()):health_status += " · %s %d: %dHP"%["HEAVY" if guns[i].weapon.heavy else "BOFORS",i+1,guns[i].hp]
	objective.text="UNDER DIVE-BOMBER ATTACK · WAVE %d/6 · %d REMAIN\nPLAYER HP %d/100%s\n%s"%[maxi(wave,1),alive.size(),pilot.health.hp,health_status,instruction]
	if phase=="WAIT_MOUNT":objective.text+="\n"+BRIEFING
	marker.hide()
	if is_finished() or session.malta_mission.interaction.occupied_gun!=null:return
	var nearest: BritishAAGun=null
	for gun in guns:
		if not gun.is_destroyed and (nearest==null or pilot.global_position.distance_to(gun.global_position)<pilot.global_position.distance_to(nearest.global_position)):nearest=gun
	var camera:=get_viewport().get_camera_3d()
	if nearest!=null and camera!=null:
		var target: Vector3=nearest.global_position+Vector3.UP*3
		var size: Vector2=get_viewport().get_visible_rect().size
		var point: Vector2=camera.unproject_position(target) if not camera.is_position_behind(target) else Vector2(size.x-160,size.y*.5)
		marker.position=Vector2(clampf(point.x-90,10,size.x-210),clampf(point.y,170,size.y-160))
		marker.text="◇ MOUNT AA GUN · %d m · E"%roundi(pilot.global_position.distance_to(nearest.global_position))
		marker.show()
