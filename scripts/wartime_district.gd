class_name WartimeDistrict
extends MostaVillage

var record: Dictionary
var churches: Dictionary = {}


func _ready() -> void:
	name = record.id
	section_prefix = record.id
	damage_limit = 5
	shell_visibility_range = 4200
	position = Vector3(record.origin[0], 0, record.origin[1])
	_build()


func _build() -> void:
	var start := Time.get_ticks_usec()
	for landmark in record.churches:
		var xz := Vector2(landmark.center_world[0] - position.x, landmark.center_world[1] - position.z)
		var yaw := deg_to_rad(float(landmark.yaw_deg))
		var half := Vector2(float(landmark.size[0]), float(landmark.size[1])) * .46
		var levels: Array[float] = [_ground(xz)]
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				levels.append(_ground(xz + Vector2(half.x * x, half.y * z).rotated(-yaw)))
		var top: float = levels.max()
		if not is_finite(top):
			continue
		var church := WartimeChurch.new()
		church.record = landmark
		church.foundation_depth = top - float(levels.min()) + .25
		church.position = Vector3(xz.x, top, xz.y)
		church.rotation.y = yaw
		add_child(church)
		churches[landmark.id] = church
	for landmark in record.military:
		_military_landmark(landmark)
	for lot in record.houses:
		_house(lot)
	for yard in record.yards:
		_garden(yard)
	_finish_batches()
	_ground_cache.clear()
	construction_usec = Time.get_ticks_usec() - start
	ready_for_flight = true

func _military_landmark(item: Dictionary) -> void:
	var xz := Vector2(item.center_world[0] - position.x, item.center_world[1] - position.z)
	var ground := _ground(xz)
	if not is_finite(ground):
		return
	var basis := Basis(Vector3.UP, deg_to_rad(float(item.yaw_deg)))
	var center := Vector3(xz.x, ground, xz.y)
	var width := float(item.size[0])
	var depth := float(item.size[1])
	var height := float(item.height)
	var stone := Color("b5a185")
	var base := center + Vector3.UP * (height * .5 - .6)
	var shell := Vector3(width, height + 1.2, depth)
	_batch_box(base, shell, basis, stone, false)
	_box_collision(_cell(center), base, shell, basis, item.id)
	_batch_box(center + Vector3.UP * height, Vector3(width + .54, .5, depth + .54), basis, stone.lightened(.18), false)
	var window_count := 7 if item.get("tower", false) else 9
	for side in [-1.0, 1.0]:
		for i in window_count:
			var x := lerpf(-width * .43, width * .43, float(i) / (window_count - 1))
			var slot := center + basis * Vector3(x, height * .53, side * (depth * .5 + .08))
			_batch_box(slot, Vector3(1.0, height * .32, .12), basis, Color("584c3c"), true)
	if item.get("tower", false):
		var tower := center + Vector3.UP * (height + 4)
		_batch_box(tower, Vector3(4.5, 8.5, 4.5), basis, stone, false)
		_box_collision(_cell(center), tower, Vector3(4.5, 8.5, 4.5), basis, "GuardhouseClockTower")
		_batch_box(tower + Vector3.UP * 4.3, Vector3(5.2, .7, 5.2), basis, stone.lightened(.1), false)
		_batch_box(tower + basis * Vector3(0, 1.6, 2.29), Vector3(1.35, 1.35, .06), basis, Color("d2c5aa"), true)
