class_name ComponentDamageVisuals
extends Node3D
## Small pooled puncture/tear meshes. No decals or renderer-specific shaders.
var aircraft: FlightAircraft
var marks: Array[MeshInstance3D] = []
var mark_components: Array[StringName] = []
var cursor: int = 0
var dirty_components: Dictionary = {}
var dark: StandardMaterial3D
var torn: StandardMaterial3D
func _ready() -> void:
	dark = MeshKit.material(Color("25251f"))
	torn = MeshKit.material(Color("797465"))
	for material in [dark,torn]:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-.7,0,-.1),Vector3(-.15,0,-.45),Vector3(.55,0,.2),Vector3(-.7,0,-.1),Vector3(.55,0,.2),Vector3(-.1,0,.55)]: mesh.surface_add_vertex(point)
	mesh.surface_end()
	for i in aircraft.components.profile.maximum_damage_marks:
		var mark := MeshKit.mesh(self,mesh,dark)
		mark.visible = false
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marks.append(mark)
		mark_components.append(&"")
	aircraft.components.component_hit.connect(_hit)
	aircraft.reset_completed.connect(clear)
	aircraft.components.component_failed.connect(_failed)
func _hit(id: StringName, point: Vector3, _severity: float) -> void:
	if marks.is_empty(): return
	var damage := aircraft.components
	var definition: AircraftComponentDefinition = damage.definitions[id]
	var source := damage.source_position(id)
	var local_point: Vector3 = aircraft.to_local(point) if point != Vector3.ZERO else source+Vector3.UP*definition.hitboxes[0].size.y*.51
	var normal := (local_point-source).normalized()
	if normal.length_squared() < 0.1: normal = Vector3.UP
	var mark: MeshInstance3D = marks[cursor]
	mark_components[cursor] = id
	cursor = (cursor+1)%marks.size()
	mark.position = local_point + normal*0.012
	mark.quaternion = Quaternion(Vector3.UP,normal)
	var ratio := damage.integrity_ratio(id)
	mark.scale = Vector3.ONE * lerpf(0.45,0.08,ratio)
	mark.material_override = torn if ratio < 0.5 else dark
	mark.visible = true
	# Cache surfaces whose integrity changed; effects use these local origins.
	dirty_components[id] = true

func _process(_delta: float) -> void:
	visible = aircraft.model.visible
	for i in marks.size():
		if aircraft.components.detached.has(mark_components[i]): marks[i].hide()
func clear() -> void:
	for mark in marks: mark.hide()
	dirty_components.clear()

func _failed(id: StringName) -> void:
	if aircraft.components.definitions[id].role == "engine" and aircraft.impact_effects != null:
		aircraft.impact_effects._play_event(&"engine_seizure",aircraft.components.source_position(id))
