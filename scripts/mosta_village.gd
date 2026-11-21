class_name MostaVillage
extends Node3D
## Terrain is authoritative. The layout contains only local X/Z and dimensions.

const LAYOUT := "res://assets/malta/mosta/layout.json"
const STONE := [Color("ad997b"), Color("bba98d"), Color("c1ab89"), Color("aa987d")]
const CELL_SIZE := 128.0
const DETAIL_DISTANCE := 330.0
const DISTANT_DISTANCE := 8500.0
const SITE_RADIUS := 950.0

static var _layout: Dictionary
static var _footprints: Array[Dictionary] = []
var terrain_root: Node3D
var section_prefix := "mosta"
var damage_limit := 40
var shell_visibility_range := DISTANT_DISTANCE
var rotunda: MostaRotunda
var ready_for_flight: bool
var construction_usec: int
var house_positions: Dictionary = {}
var collision_count: int
var draw_batches: int
var damageable_count: int
var skipped_plots: int
var _batches: Dictionary = {}
var _cells: Dictionary = {}
var _materials: Dictionary = {}
var _ground_cache: Dictionary = {}

static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
		for area in _layout.exclusions:
			var holes: Array[PackedVector2Array] = []
			for hole in area.holes: holes.append(_polygon(hole))
			_footprints.append({"shell":_polygon(area.shell),"holes":holes})
	return _layout

static func _polygon(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(float(point[0]), float(point[1])))
	return result

static func anchor() -> Vector3:
	return MaltaGeography.vector(layout().origin_world)

static func recovery_street_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	var origin := anchor()
	for street in layout().streets:
		var points := _polygon(street.points)
		for i in range(points.size()-1):
			var count := maxi(1,ceili(points[i].distance_to(points[i+1])/4.0))
			for step in count:
				result.append(Vector2(origin.x,origin.z)+points[i].lerp(points[i+1],float(step)/count))
	return result

static func replaces_scenery(point: Vector3) -> bool:
	var delta := point - anchor()
	var xz := Vector2(delta.x, delta.z)
	if xz.length_squared() > SITE_RADIUS * SITE_RADIUS: return false
	for area in _footprints:
		if not Geometry2D.is_point_in_polygon(xz,area.shell): continue
		if not area.holes.any(func(hole): return Geometry2D.is_point_in_polygon(xz,hole)): return true
	return false

func _ready() -> void:
	name = "WartimeMosta"
	position = anchor()
	call_deferred("_build")

func _build() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	var start := Time.get_ticks_usec()
	var model := layout()
	var ground := _ground(Vector2.ZERO)
	if not is_finite(ground): return
	rotunda = MostaRotunda.new()
	rotunda.parameters = model.rotunda
	var lowest := ground
	var radius := float(model.rotunda.drum_diameter) * .44
	for i in 12:
		var angle := TAU * i / 12.0
		lowest = minf(lowest,_ground(Vector2.from_angle(angle)*radius))
	rotunda.foundation_depth = clampf(ground-lowest+.30,.8,7.0)
	rotunda.position.y = ground
	rotunda.rotation.y = float(model.facade_yaw)
	add_child(rotunda)
	var plaza: Array = model.square
	_boundary(plaza, "ForecourtEdge", Color("b6a385"), 0.22, 0.48, false, 2)
	for record in model.houses:
		_house(record)
	for orchard in model.gaps:
		_garden(orchard)
	for yard in model.farms:
		_boundary(yard.points, yard.id, Color("ae987a"), 1.5, .43, true, 1)
	for plot in model.fields:
		_boundary(plot, "FieldWall", Color("9e8d71"), 0.9, .53, false, 1)
	_finish_batches()
	_ground_cache.clear()
	construction_usec = Time.get_ticks_usec() - start
	ready_for_flight = true

func _ground(point: Vector2) -> float:
	if _ground_cache.has(point): return float(_ground_cache[point])
	var world := global_position + Vector3(point.x, 0, point.y)
	var ray := PhysicsRayQueryParameters3D.create(world + Vector3.UP * 450, world - Vector3.UP * 10, 1)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(ray)
	var excluded: Array[RID] = []
	while not hit.is_empty() and not terrain_root.is_ancestor_of(hit.collider):
		excluded.append(hit.rid)
		ray.exclude = excluded
		hit = space.intersect_ray(ray)
	var height := float(hit.position.y) if not hit.is_empty() else INF
	_ground_cache[point] = height
	return height

func _house(record: Dictionary) -> void:
	var xz := Vector2(float(record.xz[0]), float(record.xz[1]))
	var width := float(record.size[0])
	var depth := float(record.size[1])
	var height := float(record.height)
	var yaw := deg_to_rad(float(record.yaw_deg))
	var basis := Basis(Vector3.UP, yaw)
	var levels: Array[float] = [_ground(xz)]
	for x in [-0.47, 0.47]:
		for z in [-0.47, 0.47]:
			var offset := basis * Vector3(x * width, 0, z * depth)
			levels.append(_ground(xz + Vector2(offset.x, offset.z)))
	var high: float = levels.max()
	var low: float = levels.min()
	if not is_finite(high) or high - low > 4.3:
		skipped_plots += 1
		return
	var base := high + .05
	var roofline := base + height
	var dimensions := Vector3(width, roofline - low + .35, depth)
	var center := Vector3(xz.x, (roofline + low - .35) * .5, xz.y)
	var colour: Color = STONE[int(record.stone)]
	var chunk := _cell(center)
	house_positions[record.id] = center
	# Townhouses facing the square and some farm wings have independent damage.
	if (xz.length() < 104 or record.kind == "farm") and damageable_count < damage_limit:
		var section := MostaHouseSection.new()
		section.name = record.id
		section.section_id = StringName(section_prefix + "_" + record.id)
		section.size = dimensions
		section.position = center
		section.rotation.y = yaw
		section.limestone = _material(colour)
		add_child(section)
		_house_details(section, Vector3(0, base-center.y, 0), Basis.IDENTITY, width, depth, height, colour, record)
		damageable_count += 1
	else:
		_batch_box(center, dimensions, basis, colour, false)
		_box_collision(chunk, center, dimensions, basis, record.id)
		_house_details(null, Vector3(xz.x, base, xz.y), basis, width, depth, height, colour, record)
	collision_count += 1

func _house_details(section: MostaHouseSection, base: Vector3, basis: Basis, width: float, depth: float, height: float, colour: Color, record: Dictionary) -> void:
	var trim := colour.lightened(.10)
	var shadow := Color("574e40")
	var level := height - .005
	for side in [-1.0, 1.0]:
		_detail_box(section, base, basis, Vector3(0, level+.24, side*(depth*.5-.18)), Vector3(width, .48, .25), trim, false)
		_detail_box(section, base, basis, Vector3(side*(width*.5-.18), level+.24, 0), Vector3(.25, .48, depth-.25), trim, false)
	if record.roof_room:
		_detail_box(section, base, basis, Vector3(width*.17,height+.99,-depth*.24), Vector3(width*.32,2.02,depth*.34), colour.darkened(.06), false)
		_detail_box(section, base, basis, Vector3(-width*.34,height+.42,-depth*.28), Vector3(.61,.84,.58), trim, true)
	var front := depth*.5
	_detail_box(section,base,basis,Vector3(-width*.22,1.29,front+.023),Vector3(1.15,2.55,.06),shadow,true)
	_detail_box(section,base,basis,Vector3(-width*.22,2.67,front+.05),Vector3(1.32,.20,.16),trim,true)
	for floor_index in range(0,ceili(height/3.4)):
		var y := float(floor_index)*2.94+1.95
		if y > height-.65: break
		for side in ([.23] if floor_index == 0 else [-.22,.22]):
			_detail_box(section,base,basis,Vector3(width*side,y-.07,front+.02),Vector3(.97,1.19,.062),shadow,true)
			_detail_box(section,base,basis,Vector3(width*side,y-.71,front+.08),Vector3(1.22,.15,.18),trim,true)
	if record.balcony:
		_detail_box(section,base,basis,Vector3(width*.20,4.78,front+.43),Vector3(2.19,1.71,.85),Color("535949"),true)
		_detail_box(section,base,basis,Vector3(width*.20,3.87,front+.41),Vector3(2.34,.20,.95),trim,true)

func _detail_box(section: MostaHouseSection, base: Vector3, basis: Basis, offset: Vector3, dimensions: Vector3, colour: Color, close: bool) -> void:
	if section != null:
		var part := MeshKit.box(section, dimensions, base+basis*offset, _material(colour))
		part.visibility_range_end = DETAIL_DISTANCE if close else shell_visibility_range
		section.collapsed.connect(func(_id: StringName): part.hide())
	else:
		_batch_box(base+basis*offset, dimensions, basis, colour, close)

func _boundary(points: Array, label: String, colour: Color, height: float, width: float, solid: bool, gaps: int) -> void:
	for i in range(points.size()-1):
		var a := Vector2(float(points[i][0]), float(points[i][1]))
		var b := Vector2(float(points[i+1][0]), float(points[i+1][1]))
		var count := maxi(1, ceili(a.distance_to(b)/4.8))
		for j in count:
			if i == 0 and j < gaps: continue
			var left := a.lerp(b,float(j)/count)
			var right := a.lerp(b,float(j+1)/count)
			var p := (left+right)*.5
			var ground := _ground(p)
			if not is_finite(ground): continue
			var direction := right-left
			var yaw := -direction.angle()
			var basis := Basis(Vector3.UP,yaw)
			var center := Vector3(p.x,ground+height*.48,p.y)
			var dimensions := Vector3(direction.length()+.025,height,width)
			_batch_box(center,dimensions,basis,colour.lightened(.018 * ((i+j)%4)), false)
			if solid: _box_collision(_cell(center),center,dimensions,basis,"%s_%02d_%02d"%[label,i,j])

func _garden(points: Array) -> void:
	_boundary(points, "Garden", Color("a28c6d"), 1.05, .42, false, 1)
	var polygon := _polygon(points)
	var center := Vector2.ZERO
	for point in polygon: center += point / polygon.size()
	for i in range(9):
		var point := center + Vector2(sin(i*2.4),cos(i*2.4))* (5.0 + i*2.25)
		if not Geometry2D.is_point_in_polygon(point,polygon): continue
		var ground := _ground(point)
		if not is_finite(ground): continue
		_batch_box(Vector3(point.x,ground+.67,point.y),Vector3(.22,1.4,.22),Basis.IDENTITY,Color("716347"),true)
		_queue_primitive(Vector3(point.x,ground+2.18,point.y),Vector3(3.6,2.6,3.65),Basis.IDENTITY,Color("595d3c"),false,"tree")

func _material(colour: Color) -> StandardMaterial3D:
	if not _materials.has(colour): _materials[colour] = MeshKit.material(colour)
	return _materials[colour]

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x/CELL_SIZE),floori(point.z/CELL_SIZE))

func _cell_origin(cell: Vector2i) -> Vector3:
	return Vector3(cell.x*CELL_SIZE,0,cell.y*CELL_SIZE)

func _box_collision(cell: Vector2i, center: Vector3, dimensions: Vector3, basis: Basis, id: String) -> void:
	if not _cells.has(cell):
		var body := StaticBody3D.new()
		body.name = "%s_Block_%d_%d" % [section_prefix, cell.x, cell.y]
		body.position = _cell_origin(cell)
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
		_cells[cell] = body
	var box := BoxShape3D.new()
	box.size = dimensions
	var collider := CollisionShape3D.new()
	collider.name = id
	collider.shape = box
	collider.transform = Transform3D(basis, center - _cell_origin(cell))
	_cells[cell].add_child(collider)

func _batch_box(point: Vector3, dimensions: Vector3, basis: Basis, colour: Color, close: bool) -> void:
	_queue_primitive(point,dimensions,basis,colour,close,"box")

func _queue_primitive(point: Vector3, dimensions: Vector3, basis: Basis, colour: Color, close: bool, kind: String) -> void:
	var cell := _cell(point)
	var key := "%d_%d_%d_%s" % [cell.x,cell.y,int(close),kind]
	if not _batches.has(key): _batches[key] = {"cell":cell,"close":close,"kind":kind,"poses":[],"colours":[]}
	_batches[key].poses.append(Transform3D(basis.scaled_local(dimensions),point-_cell_origin(cell)))
	_batches[key].colours.append(colour)

func _finish_batches() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var palette := MeshKit.material(Color.WHITE)
	palette.vertex_color_use_as_albedo = true
	palette.vertex_color_is_srgb = true
	var tree := SphereMesh.new()
	tree.radius = .5
	tree.height = 1
	tree.radial_segments = 8
	tree.rings = 4
	for record in _batches.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = box if record.kind == "box" else tree
		multi.instance_count = record.poses.size()
		for i in multi.instance_count:
			multi.set_instance_transform(i, record.poses[i])
			multi.set_instance_color(i, record.colours[i])
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multi
		batch.position = _cell_origin(record.cell)
		batch.material_override = palette
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = DETAIL_DISTANCE if record.close else shell_visibility_range
		add_child(batch)
		draw_batches += 1
	_batches.clear()
