class_name RaidBomb
extends Node3D

signal resolved(damage_by_section: Dictionary, direct_section: StringName)

@export var drag: float = 0.002
@export var blast_radius: float = 22.0
@export var blast_damage: float = 140.0
var velocity: Vector3
var carrier: RID
var age: float
var finished: bool
var whistle: AudioStreamPlayer3D

static func build_visual(parent: Node3D) -> void:
	MeshKit.sphere(parent, Vector3(0.32, 0.32, 1.12), Vector3.ZERO, MeshKit.material(Color("393e34")))
	MeshKit.box(parent, Vector3(0.46, 0.035, 0.24), Vector3(0, 0, 0.48), MeshKit.material(Color("66684d")))
	MeshKit.box(parent, Vector3(0.035, 0.46, 0.24), Vector3(0, 0, 0.48), MeshKit.material(Color("66684d")))

func _ready() -> void:
	build_visual(self)
	whistle = _sound(self, preload("res://assets/audio/raid/bomb_whistle.ogg"), 35, 800)
	whistle.volume_db = -24
	if GameAudioMixer.instance.playback_enabled: whistle.play()

func _physics_process(delta: float) -> void:
	if finished: return
	age += delta
	velocity = (velocity + Vector3.DOWN * 9.81 * delta) / (1.0 + drag * velocity.length() * delta)
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1, [carrier])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		detonate(hit.position, hit.normal, hit.collider)
		return
	global_position = next
	if velocity.length_squared() > 1.0:
		look_at(next + velocity, Vector3.RIGHT if absf(velocity.normalized().y) > 0.99 else Vector3.UP)
	var descent := clampf(-velocity.y / 65.0, 0.0, 1.0)
	whistle.pitch_scale = lerpf(0.72, 1.35, descent)
	whistle.volume_db = lerpf(-28.0, -14.0, descent)
	if GameAudioMixer.instance.playback_enabled and not whistle.playing: whistle.play()
	elif not GameAudioMixer.instance.playback_enabled and whistle.playing: whistle.stop()
	if age >= 60: _finish({}, &"")

func detonate(point: Vector3, normal: Vector3, collider: Node3D) -> void:
	if finished: return
	var water := collider.is_in_group("aircraft_water")
	var damage: Dictionary = {}
	var direct := collider as BombStructureSection
	if not water:
		var origin := point + normal * 0.15
		var space := get_world_3d().direct_space_state
		for receiver in get_tree().get_nodes_in_group("bomb_structure_sections"):
			var section := receiver as BombStructureSection
			var closest := section.closest_point(point)
			var distance := point.distance_to(closest)
			if distance >= blast_radius: continue
			if section != direct:
				var endpoint := closest + normal * 0.09
				var line := PhysicsRayQueryParameters3D.create(origin, endpoint, 1)
				# Coplanar sections can receive the blast along the impacted face.
				# An exterior wall still shields receivers behind that face.
				if direct != null and (closest - point).dot(normal) >= -0.14:
					line.exclude = [direct.get_rid()]
				var blocked := space.intersect_ray(line)
				if not blocked.is_empty() and blocked.collider != section: continue
			damage[section.section_id] = section.apply_blast(blast_damage * (1.0 - distance / blast_radius), origin)
	_create_impact(point, normal, collider, water)
	_finish(damage, direct.section_id if direct != null else &"")

func _finish(damage: Dictionary, direct_section: StringName) -> void:
	finished = true
	whistle.stop()
	hide()
	resolved.emit(damage, direct_section)
	queue_free()

func _create_impact(point: Vector3, normal: Vector3, collider: Node3D, water: bool) -> void:
	var burst := DestructionBurst.new()
	burst.water_impact = water
	burst.hard_surface = not collider.is_in_group("terrain") or _on_runway(point)
	burst.strength = 1.7
	get_parent().add_child(burst)
	burst.global_position = point
	var sound := _sound(burst, preload("res://assets/audio/raid/bomb_impact.ogg"), 65, 1600)
	sound.volume_db = -10
	sound.pitch_scale = 0.84 if water else (1.04 if burst.hard_surface else 0.94)
	if GameAudioMixer.instance.playback_enabled: sound.play()
	if water: return
	var previous_marks := get_tree().get_nodes_in_group("raid_impact_marks")
	if previous_marks.size() >= 96: previous_marks[0].queue_free()
	var mark := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = 0.08
	mesh.top_radius = 3.4
	mesh.bottom_radius = 4.6
	mesh.radial_segments = 16
	mark.mesh = mesh
	mark.material_override = MeshKit.material(Color("3a3228") if burst.hard_surface else Color("433829"))
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mark)
	mark.add_to_group("raid_impact_marks")
	mark.global_position = point + normal * 0.06
	mark.global_basis = Basis(Quaternion(Vector3.UP, normal))
	if collider is BombStructureSection and collider.hp <= 0:
		mark.global_position.y = collider.global_position.y - collider.size.y * 0.25
	if not burst.hard_surface:
		for i in range(12):
			var angle := TAU * i / 12.0
			MeshKit.sphere(mark, Vector3(1.5, 0.36, 0.85), Vector3(cos(angle), 0.05, sin(angle)) * 3.8, MeshKit.material(Color("645247")))

func _on_runway(point: Vector3) -> bool:
	for field in get_tree().get_nodes_in_group("bomb_runways"):
		var local: Vector3 = field.to_local(point)
		if absf(local.x) <= 27 and absf(local.z) <= field.runway_length * 0.5 and absf(local.y) < 3:
			return true
	return false

func _sound(parent: Node3D, stream: AudioStream, unit: float, distance: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.bus = "Guns"
	sound.unit_size = unit
	sound.max_distance = distance
	sound.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	parent.add_child(sound)
	return sound
