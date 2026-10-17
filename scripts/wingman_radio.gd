class_name WingmanRadio
extends Node
## Request orchestration only: never changes pilot commands or combat targets.
const REQUEST_LINE: String = "Hope, Charity — report your status and enemy positions. Over."
var director: HarbourInterception
var spotters: Dictionary = {}
var cooldown: float = 0
var request_number: int = 0
var notice: Label
var notice_remaining: float = 0
var reports_built: Dictionary = {}

func _ready() -> void:
	for friend in director.wingmen:
		if not is_instance_valid(friend): continue
		var spotter := WingmanSpotter.new()
		spotter.observer = friend
		spotter.director = director
		add_child(spotter)
		spotters[friend.callsign] = spotter
		friend.destroyed.connect(_lost.bind(friend.callsign))
	var canvas := CanvasLayer.new()
	canvas.layer = 23
	add_child(canvas)
	notice = Label.new()
	notice.position = Vector2(350, 195)
	notice.add_theme_font_size_override("font_size", 18)
	notice.add_theme_color_override("font_color", Color("a9e3e9"))
	notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	notice.add_theme_constant_override("shadow_offset_x", 2)
	notice.add_theme_constant_override("shadow_offset_y", 2)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(notice)
	notice.hide()

func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0)
	notice_remaining = maxf(notice_remaining - delta, 0)
	notice.visible = notice_remaining > 0

static func binding_text() -> String:
	var names: PackedStringArray = []
	for event in InputMap.action_get_events("wingman_status"):
		var text: String = event.as_text()
		if event is InputEventKey:
			text = OS.get_keycode_string(event.get_physical_keycode_with_modifiers() if event.physical_keycode != 0 else event.get_keycode_with_modifiers())
		if not names.has(text): names.append(text)
	return " / ".join(names) if not names.is_empty() else "Unbound"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("wingman_status") and not event.is_echo() and not get_tree().paused:
		if director.session.malta_mission.occupied != director.session.aircraft: return
		request_status()
		get_viewport().set_input_as_handled()

func request_status() -> bool:
	if director.is_finished() or get_tree().paused or not director._player_alive(): return false
	if director.radio.has_group("wingman_status"):
		_notice("Radio request already pending")
		return false
	if cooldown > 0:
		_notice("Radio ready in %d s" % ceili(cooldown))
		return false
	cooldown = director.definition.radio_request_cooldown
	request_number += 1
	var prefix: String = "status_%d_" % request_number
	director.radio.enqueue_report(prefix + "Faith", "FAITH", _faith_report, _mission_live)
	# Include slots now, but decide pilot availability and build contents at playback.
	for callsign in ["Hope", "Charity"]:
		director.radio.enqueue_report(prefix + callsign, callsign.to_upper(), _reply.bind(callsign), _responsive.bind(callsign))
	director.radio.enqueue_report(prefix + "no_response", "FAITH", _no_response, _none_responsive)
	return true

func _notice(text: String) -> void:
	notice.text = text
	notice_remaining = 2.5
	notice.show()

func _mission_live() -> bool: return not director.is_finished()
func _responsive(callsign: String) -> bool:
	if not _mission_live() or not spotters.has(callsign): return false
	var friend: FriendlyGladiator = spotters[callsign].observer if is_instance_valid(spotters[callsign].observer) else null
	return friend != null and not friend.is_destroyed and not friend.is_crashed and friend.health.hp > 0
func _none_responsive() -> bool: return _mission_live() and not _responsive("Hope") and not _responsive("Charity")

func _faith_report() -> Dictionary:
	return {"text":"Control, this is Faith. " + REQUEST_LINE, "voice":director.definition.faith_status_voice}
func _no_response() -> Dictionary:
	return {"text":"No response.", "voice":null, "duration":3.0, "start_delay":1.0}

func _lost(callsign: String) -> void:
	director.radio.cancel_speaker(callsign.to_upper())

func _condition(friend: FriendlyGladiator) -> Dictionary:
	var damage: AircraftDamage = friend.components
	var fire: bool = damage.fuel_burning or friend.health.hp < 50
	var lowest: float = 1
	for id in AircraftDamage.IDS: lowest = minf(lowest, damage.integrity_ratio(id))
	var severity: String = "sound"
	if friend.health.hp < 30 or lowest < .2: severity = "critical"
	elif friend.health.hp < 65 or lowest < .55 or damage.integrity_ratio(&"engine") < .65: severity = "significant"
	elif friend.health.hp < 98 or lowest < .98: severity = "minor"
	var text: String = "Aircraft sound"
	if severity == "minor": text = "Minor damage"
	elif severity == "significant": text = "Significant damage"
	elif severity == "critical": text = "Critical damage"
	if fire: text += "; fire on board"
	elif damage.integrity_ratio(&"engine") < .65: text += "; engine damaged"
	elif damage.integrity_ratio(&"elevator") < .65 or damage.integrity_ratio(&"rudder") < .65 or damage.integrity_ratio(&"cockpit") < .65: text += "; controls damaged"
	elif damage.fuel_remaining <= 0: text += "; fuel exhausted"
	elif damage.fuel_leaking: text += "; fuel leaking"
	return {"text":text, "severity":severity, "fire":fire}

func _activity(friend: FriendlyGladiator, visible: Dictionary) -> String:
	if friend.ai.takeoff_hold: return "Waiting for takeoff"
	if not friend.ai.departed: return "Taking off"
	if friend.ai.withdrawing: return "Withdrawing"
	if friend.ai.mode == "EVADE": return "Avoiding terrain" if friend.ai.terrain_avoiding else "Evading"
	if is_instance_valid(friend.ai.target) and visible.has(friend.ai.target.get_instance_id()):
		return "Attacking a bomber" if visible[friend.ai.target.get_instance_id()].bomber else "Engaging a fighter"
	if is_instance_valid(friend.ai.target) and not friend.ai.target.is_destroyed: return "Manoeuvring; no visual on my target"
	return "Forming up on Faith; no visual target"

func _reply(callsign: String) -> Dictionary:
	if not _responsive(callsign): return {}
	var spotter: WingmanSpotter = spotters[callsign]
	spotter.scan() # Re-sample NOW, not when the button was pressed.
	var friend: FriendlyGladiator = spotter.observer
	var condition := _condition(friend)
	var activity: String = _activity(friend, spotter.visible)
	var selected: Dictionary = {}
	var best: float = -INF
	for record in spotter.visible.values():
		var score: float = 0
		if record.threat != "": score += 8
		if record.fort != "": score += 6
		if is_instance_valid(friend.ai.target) and record.id == friend.ai.target.get_instance_id(): score += 3
		score -= friend.global_position.distance_to(record.position) / 10000
		if score > best: selected = record; best = score
	var tactical: String = "No enemy aircraft in sight"
	if not selected.is_empty():
		var title: String = "SM.79 bomber" if selected.bomber else _type_name(selected.kind)
		tactical = "%s, %s, about %d metres" % [title, bearing(selected.position), approximate_distance(selected.position)]
		if selected.threat != "": tactical += "; threatening " + selected.threat
		elif selected.fort != "": tactical += "; approaching " + selected.fort
		elif spotter.visible.size() > 1: tactical += "; %d contacts spotted" % spotter.visible.size()
	elif not spotter.sightings.is_empty():
		var newest: Dictionary = {}
		for record in spotter.sightings.values():
			if newest.is_empty() or record.time > newest.time: newest = record
		if spotter.clock - float(newest.time) <= director.definition.radio_memory_seconds:
			tactical = "Last seen %s, about %d metres; lost visual" % [bearing(newest.position), approximate_distance(newest.position)]
	var text: String = "Control, this is %s. %s. %s. %s. Over." % [callsign, condition.text, activity, tactical]
	reports_built[callsign] = text
	# Complete recordings are selected only when their factual variant matches.
	var voice: AudioStream = director.definition.hope_status_ack if callsign == "Hope" else director.definition.charity_status_ack
	var voices: Dictionary = director.definition.hope_status_variants if callsign == "Hope" else director.definition.charity_status_variants
	var variant: String = condition.severity
	if condition.fire: variant = "fire"
	elif friend.components.integrity_ratio(&"engine") < .65: variant = "engine_damage"
	elif friend.components.integrity_ratio(&"elevator") < .65 or friend.components.integrity_ratio(&"rudder") < .65 or friend.components.integrity_ratio(&"cockpit") < .65: variant = "controls_damage"
	elif friend.components.fuel_remaining <= 0: variant = "fuel_empty"
	elif friend.components.fuel_leaking: variant = "fuel_leak"
	if voices.has(variant): voice = voices[variant]
	return {"text":text, "voice":voice, "duration":director.definition.radio_subtitle_seconds}

func _type_name(kind: String) -> String:
	return {"cr42":"CR.42 fighter", "c200":"C.200 fighter", "c202":"C.202 fighter", "stuka":"Stuka"}.get(kind, "Enemy aircraft")

func bearing(position: Vector3) -> String:
	var faith: FlightAircraft = director.session.aircraft
	var offset: Vector3 = (position - faith.global_position) * Vector3(1, 0, 1)
	if offset.length() < 20: return "close by"
	var forward: Vector3 = -faith.global_basis.z * Vector3(1, 0, 1)
	var flat_speed: float = (faith.linear_velocity * Vector3(1, 0, 1)).length()
	if forward.length_squared() < .1 or flat_speed < 8:
		var index: int = posmod(roundi(atan2(offset.x, -offset.z) / (PI / 4)), 8)
		return ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"][index]
	forward = forward.normalized()
	var angle: float = atan2(offset.dot(forward.cross(Vector3.UP)), offset.dot(forward))
	var hour: int = posmod(roundi(angle / (TAU / 12)), 12)
	return "your %d o'clock" % (12 if hour == 0 else hour)

func approximate_distance(position: Vector3) -> int:
	return maxi(100, roundi(director.session.aircraft.global_position.distance_to(position) / 100) * 100)
