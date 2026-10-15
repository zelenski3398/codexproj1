class_name MissionBomb
extends Node3D
## Inherited velocity, gravity and swept impact. Operator damage is opt-in for
## the AA survival mission; interception retains its previous gun-only blast.
signal impacted(point: Vector3)
var velocity: Vector3
@export var aa_blast_radius: float = 35
@export var aa_blast_damage: float = 180
@export var damage_pilots: bool = false
@export var pilot_blast_damage: float = 130
@export var sandbag_transmission: float = 0.35
var age: float = 0
var impact_effects: Node3D
var resolved: bool = false
func _ready() -> void:
	MeshKit.sphere(self,Vector3(.22,.22,.75),Vector3.ZERO,MeshKit.material(Color("292d25")))
	MeshKit.box(self,Vector3(.4,.03,.2),Vector3(0,0,.3),MeshKit.material(Color("857859")))
func _physics_process(delta: float) -> void:
	if resolved:return
	age+=delta
	velocity.y-=9.81*delta
	var next: Vector3=global_position+velocity*delta
	var ray:=PhysicsRayQueryParameters3D.create(global_position,next,17 if damage_pilots else 1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():explode(hit.position)
	else:
		global_position=next
		if velocity.length_squared()>1:look_at(global_position+velocity)
	if age>40:resolved=true;queue_free()
func explode(point: Vector3) -> void:
	if resolved:return
	resolved=true # all callbacks / duplicate impacts share this latch
	var burst:=DestructionBurst.new()
	impact_effects.add_child(burst)
	burst.global_position=point
	burst.scale=Vector3.ONE*2
	if damage_pilots and GameAudioMixer.instance.playback_enabled and get_tree().get_nodes_in_group("bomb_impact_audio").size()<4:
		var sound:=AudioStreamPlayer3D.new()
		sound.stream=load("res://assets/audio/aa_cannon_shot.ogg")
		sound.bus="Guns"
		sound.pitch_scale=.7
		sound.unit_size=60
		sound.max_distance=2000
		sound.playback_type=AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
		burst.add_child(sound)
		sound.add_to_group("bomb_impact_audio")
		sound.finished.connect(sound.queue_free)
		sound.play()
	# Snapshot receivers/amounts BEFORE gun destruction can eject the operator.
	# Apply operator damage first, then independent gun damage from this impact.
	var receivers: Array=[]
	if damage_pilots:
		for pilot in get_tree().get_nodes_in_group("damageable_ground_pilots"):
			if pilot.health.hp<=0:continue
			var d: float=pilot.global_position.distance_to(point)
			if d>=aa_blast_radius:continue
			var cover: float=0
			for height in [-.5,0.0,.7]:
				var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.5,pilot.global_position+Vector3.UP*height,1)
				var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
				cover+=1.0 if hit.is_empty() else (sandbag_transmission if hit.collider is BritishAAGun else (.6 if hit.collider is MilitaryTruck else 0.0))
			receivers.append([pilot,pilot_blast_damage*(1-d/aa_blast_radius)*cover/3])
	for gun in get_tree().get_nodes_in_group("friendly_aa")+get_tree().get_nodes_in_group("friendly_aa_commands"):
		var d: float=gun.global_position.distance_to(point)
		if d>=aa_blast_radius:continue
		var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.2,gun.global_position+Vector3.UP,1)
		var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.collider==gun:receivers.append([gun,aa_blast_damage*(1-d/aa_blast_radius)])
	for entry in receivers:
		if is_instance_valid(entry[0]):entry[0].take_damage(entry[1])
	impacted.emit(point)
	queue_free()
