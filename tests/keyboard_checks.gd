extends SceneTree
## Exercises Godot's actual event -> InputMap -> gameplay path. Action injection
## alone cannot catch missing physical/logical key mappings or GUI consumption.
var aircraft: FlightAircraft
var hud: FlightHUD
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	aircraft = world.aircraft
	hud = world.hud
	await _frames(3)
	for physical in [true, false]:
		var mode: String = "Physical" if physical else "Keycode-only"
		aircraft.request_reset()
		await _frames(3)
		_key(KEY_W, true, physical)
		await _frames(120)
		_key(KEY_W, false, physical)
		var held := aircraft.pilot.throttle
		_check(held > 0.25 and held < 0.35, mode + " W increases throttle")
		await _frames(30)
		_check(is_equal_approx(held, aircraft.pilot.throttle), mode + " W release holds throttle")
		_key(KEY_S, true, physical)
		await _frames(60)
		_key(KEY_S, false, physical)
		_check(aircraft.pilot.throttle < held - 0.1, mode + " S reduces throttle")
		_key(KEY_UP, true, physical)
		_key(KEY_LEFT, true, physical)
		_key(KEY_D, true, physical)
		_key(KEY_SPACE, true, physical)
		await _frames(3)
		_check(aircraft.pilot.pitch == -1 and aircraft.pilot.roll == 1 and aircraft.pilot.rudder == -1 and aircraft.pilot.brakes, mode + " arrows, rudder and brakes reach the pilot")
		for code in [KEY_UP, KEY_LEFT, KEY_D, KEY_SPACE]:
			_key(code, false, physical)
		_key(KEY_DOWN, true, physical)
		_key(KEY_RIGHT, true, physical)
		_key(KEY_A, true, physical)
		await _frames(3)
		_check(aircraft.pilot.pitch == 1 and aircraft.pilot.roll == -1 and aircraft.pilot.rudder == 1 and not aircraft.pilot.brakes, mode + " opposite axes and key releases work")
		for code in [KEY_DOWN, KEY_RIGHT, KEY_A]:
			_key(code, false, physical)
		aircraft.pilot.throttle = 0.6
		_key(KEY_R, true, physical)
		_key(KEY_R, false, physical)
		await _frames(3)
		_check(aircraft.pilot.throttle == 0.0 and not aircraft.reset_pending, mode + " R resets the aircraft")
		_key(KEY_G, true, physical)
		_key(KEY_G, false, physical)
		await _frames(3)
		_check(aircraft.gear.extended and aircraft.gear.last_notice.contains("LOCKED"), mode + " G reaches the ground safety lock")
		_key(KEY_ESCAPE, true, physical)
		_key(KEY_ESCAPE, false, physical)
		await _frames(3)
		_check(paused, mode + " Escape pauses")
		# Auto-repeat must not repeatedly unpause/toggle/reset the aircraft.
		_key(KEY_ESCAPE, true, physical, true)
		await _frames(2)
		_check(paused, mode + " Escape auto-repeat keeps the game paused")
		_key(KEY_ESCAPE, false, physical)
		# Force keyboard focus on a button to simulate a menu click/navigation.
		hud.resume_button.focus_mode = Control.FOCUS_ALL
		hud.resume_button.grab_focus()
		_key(KEY_ESCAPE, true, physical)
		_key(KEY_ESCAPE, false, physical)
		await _frames(3)
		_check(not paused, mode + " Escape resumes despite GUI focus")
		_key(KEY_ESCAPE, true, physical)
		_key(KEY_ESCAPE, false, physical)
		await _frames(3)
		hud.resume_button.grab_focus()
		_key(KEY_R, true, physical)
		_key(KEY_R, false, physical)
		await _frames(3)
		_check(not paused and aircraft.pilot.throttle == 0.0, mode + " R resets while paused with GUI focus")
		_check(root.gui_get_focus_owner() == null, mode + " returning to flight releases GUI keyboard focus")
	print("KEYBOARD RESULT: ", checks - failures, "/", checks, " passed; ", failures, " failed")
	quit(1 if failures else 0)

func _key(code: Key, pressed: bool, physical: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	if physical:
		event.physical_keycode = code
	else:
		event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for tick in range(count):
		await physics_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
