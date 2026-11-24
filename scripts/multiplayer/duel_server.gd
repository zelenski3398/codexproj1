extends Node

var listener := TCPServer.new()
var connections: Array[Dictionary] = []
var online: Dictionary = {}
var available: Dictionary = {}
var challenges: Dictionary = {}
var cooldowns: Dictionary = {}
var reservations: Dictionary = {}
var matches: Dictionary = {}
var store: DuelStore
var next_sync := 0
var dirty := false
var maximum_matches := 2
var invite_ms := 25000
var rules := {
	"load_seconds": 60.0, "prep_seconds": 180.0, "combat_seconds": 300.0,
	"boundary_seconds": 12.0, "reconnect_seconds": 12.0, "credit_seconds": 12.0,
	"mutual_seconds": 2.0, "waypoint_radius": 600.0, "waypoint_altitude": 130.0,
}
var names := RegEx.new()


func _ready() -> void:
	names.compile("^[\\p{L}\\p{N}][\\p{L}\\p{N} _.'-]{1,23}$")
	var path := OS.get_environment("DUEL_STORE")
	store = DuelStore.new(path if not path.is_empty() else "user://duel-profiles.json")
	if store.path.is_empty():
		get_tree().quit(1)
		return
	var port := int(OS.get_environment("DUEL_PORT")) if OS.has_environment("DUEL_PORT") else 9074
	var host := OS.get_environment("DUEL_BIND") if OS.has_environment("DUEL_BIND") else "127.0.0.1"
	for key in rules:
		var setting := OS.get_environment("DUEL_" + key.to_upper())
		if setting.is_valid_float() and is_finite(float(setting)) and float(setting) > 0:
			rules[key] = float(setting)
	if OS.has_environment("DUEL_INVITE_SECONDS"):
		invite_ms = clampi(OS.get_environment("DUEL_INVITE_SECONDS").to_int(), 1, 120) * 1000
	if listener.listen(port, host) != OK:
		push_error("Unable to listen for Dogfight connections")
		get_tree().quit(1)
		return
	print("Dogfight listening on %s:%d" % [host, port])


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	while listener.is_connection_available():
		var stream := listener.take_connection()
		if connections.size() >= 128:
			stream.disconnect_from_host()
			continue
		var peer := WebSocketPeer.new()
		peer.inbound_buffer_size = 16384
		peer.outbound_buffer_size = 65536
		var err := peer.accept_stream(stream)
		if err == OK:
			connections.append({"peer": peer, "id": "", "seen": now, "quota": 100, "window": now})
	for connection in connections.duplicate():
		_poll(connection, now)
	for id in challenges.keys():
		if now >= challenges[id].expires:
			_remove_invite(id, "Challenge expired.")
	for id in matches.keys():
		var match_data: Dictionary = matches[id]
		if match_data.get("result_pending", false) and now >= match_data.retry_at:
			_save_result(id)
		if now - match_data.touched >= 600000 and not match_data.get("result_pending", false) and match_data.state in ["selection", "results"]:
			_close_match(id, "The inactive duel lobby closed.")
	if dirty:
		dirty = false
		for id in online.keys(): _lobby(id)
	if now >= next_sync:
		next_sync = now + 50
		for id in matches:
			var match_data: Dictionary = matches[id]
			if match_data.state != "flight": continue
			var round_node: DuelRound = match_data.round
			if round_node.phase == "loading" and round_node.planes.any(func(plane): return plane.reset_pending):
				continue
			var snapshot := round_node.snapshot()
			snapshot.match_id = id
			snapshot.round_id = match_data.round_id
			for player in match_data.players: _send_to(player, snapshot, true)


func _poll(connection: Dictionary, now: int) -> void:
	var peer: WebSocketPeer = connection.peer
	peer.poll()
	if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED or now - connection.seen >= 12500:
		_drop(connection)
		return
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	if now - connection.window >= 1000:
		connection.window = now
		connection.quota = 100
	while peer.get_available_packet_count() > 0:
		var packet := peer.get_packet()
		connection.quota -= 1
		if packet.size() > 4096 or not peer.was_string_packet() or connection.quota < 0:
			_drop(connection)
			return
		var message: Variant = JSON.parse_string(packet.get_string_from_utf8())
		if message is Dictionary:
			_handle(connection, message, now)


func _send(connection: Dictionary, event: Dictionary, replaceable := false) -> void:
	var peer: WebSocketPeer = connection.peer
	if peer.get_ready_state() != WebSocketPeer.STATE_OPEN: return
	if peer.get_current_outbound_buffered_amount() > 32768:
		if not replaceable: peer.close(1008)
		return
	peer.send_text(JSON.stringify(event))


func _send_to(id: String, event: Dictionary, replaceable := false) -> void:
	if online.has(id): _send(online[id], event, replaceable)


func _notice(id: String, message: String) -> void:
	_send_to(id, {"type":"notice", "text":message})


func _authenticate(connection: Dictionary, message: Dictionary) -> void:
	var kind: String = str(message.get("type", ""))
	var credentials: Dictionary
	if kind == "create":
		var display_name := _display_name(message)
		if display_name.is_empty():
			_send(connection, {"type":"auth_error", "text":"Use 2–24 letters, digits or basic punctuation."})
			return
		credentials = store.create(display_name)
		if credentials.is_empty():
			_send(connection, {"type":"auth_error", "text":"Could not save the guest profile."})
			return
	elif kind == "resume":
		var id := str(message.get("id", ""))
		var token := str(message.get("token", ""))
		if not store.authorize(id, token):
			_send(connection, {"type":"auth_error", "text":"Guest credential could not be restored.", "invalid":true})
			return
		credentials = {"id": id}
	else:
		return
	var guest: String = credentials.id
	if online.has(guest):
		_send(connection, {"type":"auth_error", "text":"This guest is already connected in another tab."})
		return
	connection.id = guest
	online[guest] = connection
	if reservations.has(guest):
		var match_data: Dictionary = matches[reservations[guest]]
		if match_data.state == "flight": match_data.round.set_connected(match_data.players.find(guest), true)
	_send(connection, {"type":"profile", "profile":store.identity(guest),
		"stats":store.data.profiles[guest].stats, "credential":credentials.get("token", "")})
	_lobby(guest)


func _display_name(message: Dictionary) -> String:
	if message.get("name") is not String: return ""
	var candidate: String = message.name.strip_edges()
	return candidate if candidate.length() <= 24 and names.search(candidate) != null else ""


func _handle(connection: Dictionary, message: Dictionary, now: int) -> void:
	if message.get("type") is not String: return
	connection.seen = now
	var id: String = connection.id
	if id.is_empty():
		_authenticate(connection, message)
		return
	match message.type:
		"ping": _send(connection, {"type":"pong"})
		"rename":
			var display_name := _display_name(message)
			if not display_name.is_empty() and store.rename_guest(id, display_name):
				_notice(id, "Guest name updated.")
				dirty = true
			else: _notice(id, "Use 2–24 letters, digits or basic punctuation.")
		"find":
			if not reservations.has(id) and _invite_for(id).is_empty():
				if available.has(id): available.erase(id)
				else: available[id] = true
				dirty = true
		"challenge": _challenge(id, str(message.get("opponent", "")), now)
		"accept", "decline", "cancel": _respond(id, message)
		"select", "ready", "loaded", "input", "reset", "rematch", "leave":
			_match_action(id, message)


func _invite_for(id: String) -> String:
	for key in challenges:
		if id in challenges[key].players: return key
	return ""


func _challenge(from: String, to: String, now: int) -> void:
	if now < cooldowns.get(from, 0):
		_notice(from, "Wait a moment before sending another challenge.")
		return
	cooldowns[from] = now + 2200
	if from == to or not available.has(from) or not available.has(to):
		_notice(from, "That player is no longer available.")
		return
	available.erase(from)
	available.erase(to)
	challenges[_new_id()] = {"players":[from, to], "expires":now + invite_ms}
	dirty = true


func _respond(id: String, message: Dictionary) -> void:
	var key := _invite_for(id)
	if key.is_empty() or message.get("invite") != key: return
	var players: Array = challenges[key].players
	match message.type:
		"accept":
			if id != players[1]: return
			if matches.size() >= maximum_matches:
				_remove_invite(key, "The server is full. Try again shortly.")
				return
			challenges.erase(key)
			var match_id := _new_id()
			for player in players: reservations[player] = match_id
			matches[match_id] = {"players":players, "sides":[-1,-1], "kinds":["",""], "ready":[false,false],
				"rematch":[false,false], "state":"selection", "touched":Time.get_ticks_msec(), "round_id":""}
			dirty = true
		"decline":
			if id == players[1]: _remove_invite(key, "Challenge declined.")
		"cancel":
			if id == players[0]: _remove_invite(key, "Challenge cancelled.")


func _remove_invite(key: String, status: String) -> void:
	var players: Array = challenges[key].players
	challenges.erase(key)
	for player in players:
		if online.has(player):
			available[player] = true
			_notice(player, status)
	dirty = true


func _match_action(id: String, message: Dictionary) -> void:
	var key: String = reservations.get(id, "")
	if key.is_empty() or message.get("match_id") != key: return
	var current: Dictionary = matches[key]
	var slot: int = current.players.find(id)
	if current.state == "selection":
		if message.type == "leave":
			_close_match(key, "A player left the match lobby.")
		elif message.type == "select":
			var side: Variant = message.get("side")
			var kind := str(message.get("kind", ""))
			if (side is not int and side is not float) or (side != 0 and side != 1) or side == current.sides[1-slot] or kind not in (DuelAircraft.ALLIES if side == 0 else DuelAircraft.AXIS):
				_notice(id, "That side or fighter is unavailable.")
				_lobby(id)
				return
			current.sides[slot] = int(side)
			current.kinds[slot] = kind
			current.ready[slot] = false
			current.touched = Time.get_ticks_msec()
			dirty = true
		elif message.type == "ready" and not current.kinds[slot].is_empty():
			current.ready[slot] = not current.ready[slot]
			if current.ready[0] and current.ready[1]: _start(key)
			dirty = true
	elif current.state == "flight":
		if message.get("round_id") != current.round_id: return
		var round_node: DuelRound = current.round
		match message.type:
			"loaded": round_node.loaded[slot] = true
			"input": round_node.control(slot, message)
			"reset": round_node.reset_player(slot)
			"leave":
				if not current.has("leaving"): current.leaving = []
				if id not in current.leaving: current.leaving.append(id)
				round_node.leave(slot)
				if not matches.has(key): return
				if matches[key].state == "selection": _close_match(key, "A player left before combat.")
	elif current.state == "results":
		if message.type == "leave":
			if not current.get("result_pending", false): _close_match(key, "A player left the duel.")
		elif message.type == "rematch" and not current.has("leaving") and not current.get("result_pending", false):
			current.rematch[slot] = true
			if current.rematch[0] and current.rematch[1]: _selection(key)
			dirty = true


func _start(key: String) -> void:
	var current: Dictionary = matches[key]
	if current.sides[0] == 1:
		for field in ["players", "sides", "kinds"]: current[field].reverse()
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var round_node := DuelRound.new()
	viewport.add_child(round_node)
	current.viewport = viewport
	current.round = round_node
	current.round_id = _new_id()
	round_node.round_id = current.round_id
	current.state = "flight"
	round_node.completed.connect(_result.bind(key))
	round_node.preparation_cancelled.connect(_abort.bind(key))
	round_node.setup(current.kinds, rules)


func _abort(reason: String, key: String) -> void:
	if not matches.has(key): return
	var current: Dictionary = matches[key]
	for player in current.players: _notice(player, reason)
	if current.players.all(func(id): return online.has(id)):
		_selection(key)
	else:
		_close_match(key, reason)


func _result(winner: int, reason: String, forfeits: Array, kills: Array, key: String) -> void:
	var current: Dictionary = matches[key]
	current.state = "results"
	current.result = {"winner":winner, "reason":reason, "forfeits":forfeits, "kills":kills}
	current.result_pending = true
	current.touched = Time.get_ticks_msec()
	_save_result(key)
	dirty = true


func _save_result(key: String) -> void:
	var current: Dictionary = matches[key]
	var result: Dictionary = current.result
	if store.record(current.round_id, current.players, current.kinds, result.winner, result.forfeits, result.kills, result.reason):
		current.result_pending = false
		_free_round(current)
		if current.has("leaving"):
			for player in current.leaving: reservations.erase(player)
			dirty = true
	else:
		current.retry_at = Time.get_ticks_msec() + 3000
		for id in current.players: _notice(id, "Result saved in memory. Retrying career storage.")
	dirty = true


func _selection(key: String) -> void:
	var current: Dictionary = matches[key]
	_free_round(current)
	current.state = "selection"
	current.round_id = ""
	current.sides = [-1, -1]
	current.kinds = ["", ""]
	current.ready = [false, false]
	current.rematch = [false, false]
	current.touched = Time.get_ticks_msec()
	dirty = true


func _free_round(current: Dictionary) -> void:
	if current.has("viewport"):
		current.viewport.queue_free()
		current.erase("viewport")
		current.erase("round")


func _close_match(key: String, reason: String) -> void:
	var current: Dictionary = matches[key]
	for player in current.players:
		if reservations.get(player) == key:
			reservations.erase(player)
			_notice(player, reason)
	_free_round(current)
	matches.erase(key)
	dirty = true


func _lobby(id: String) -> void:
	var guests := []
	for peer_id in available:
		if peer_id != id: guests.append(store.identity(peer_id))
	var event := {"type":"lobby", "profile":store.identity(id), "stats":store.data.profiles[id].stats,
		"available":available.has(id), "guests":guests}
	var invite := _invite_for(id)
	if not invite.is_empty():
		var current: Dictionary = challenges[invite]
		var outgoing: bool = current.players[0] == id
		event.invite = {"id":invite, "outgoing":outgoing,
			"other":store.identity(current.players[1] if outgoing else current.players[0]),
			"seconds":maxf(0, (current.expires - Time.get_ticks_msec()) / 1000.0)}
	var match_id: String = reservations.get(id, "")
	if not match_id.is_empty():
		var current: Dictionary = matches[match_id]
		event.match = {"id":match_id, "round_id":current.round_id, "state":current.state,
			"players":current.players.map(func(player): return store.identity(player)), "you":current.players.find(id),
			"sides":current.sides, "kinds":current.kinds, "ready":current.ready, "rematch":current.rematch,
			"result":current.get("result", {}), "saving":current.get("result_pending", false),
			"can_rematch":not current.has("leaving")}
	_send_to(id, event)


func _drop(connection: Dictionary) -> void:
	connections.erase(connection)
	connection.peer.close()
	var id: String = connection.id
	if id.is_empty(): return
	online.erase(id)
	available.erase(id)
	var invite := _invite_for(id)
	if not invite.is_empty(): _remove_invite(invite, "Opponent disconnected.")
	var match_id: String = reservations.get(id, "")
	if not match_id.is_empty():
		var current: Dictionary = matches[match_id]
		if current.state == "flight": current.round.set_connected(current.players.find(id), false)
		elif current.state == "selection": _close_match(match_id, "Opponent disconnected in aircraft selection.")
	dirty = true


func _new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
