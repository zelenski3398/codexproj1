class_name DuelClient
extends Node3D

signal closed
var socket: WebSocketPeer
var endpoint := ""
var credential: Dictionary = {}
var state: Dictionary = {}
var status := "Connect to a duel server."
var storage_available := false
var handshake := false
var reconnect := false
var connect_at := 0
var ping_at := 0
var retry_at := 0
var canvas: CanvasLayer
var panel: PanelContainer
var stack: VBoxContainer
var notice: Label
var view: DuelView
var round_id := ""
var showing_help := false
var screen: Control


func _ready() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	screen = Control.new()
	canvas.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	screen.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 0
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17241f")
	style.border_color = Color("c6aa70")
	style.set_border_width_all(1)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(650, 455)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	stack = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	endpoint = OS.get_environment("WINGS_DUEL_URL")
	if OS.has_feature("web"):
		var configured: Variant = JavaScriptBridge.eval("window.WINGS_DUEL_URL || ''", true)
		endpoint = str(configured)
		storage_available = bool(JavaScriptBridge.eval("(()=>{try{localStorage.setItem('wings-duel-test','1');localStorage.removeItem('wings-duel-test');return true}catch{return false}})()", true))
	if endpoint.is_empty():
		endpoint = str(JavaScriptBridge.eval("(location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/duel'", true)) if OS.has_feature("web") else "ws://127.0.0.1:9074"
	_render()
	if not endpoint.is_empty(): _connect_server.call_deferred(endpoint)


func _connect_server(url: String) -> void:
	var clean := url.strip_edges()
	if clean.length() > 300 or not (clean.begins_with("ws://") or clean.begins_with("wss://")) or clean.contains("@") or clean.contains("?") or clean.contains("#"):
		_set_notice("Enter a WebSocket server address without credentials.")
		return
	if OS.has_feature("web") and bool(JavaScriptBridge.eval("location.protocol === 'https:'", true)) and not clean.begins_with("wss://"):
		_set_notice("This HTTPS page requires a secure wss:// server address.")
		return
	if endpoint != clean:
		credential.clear()
	endpoint = clean
	if storage_available and credential.is_empty():
		var saved: Variant = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem(%s)}catch{return null}})()" % JSON.stringify(_storage_key()), true)
		if saved is String:
			var parsed: Variant = JSON.parse_string(saved)
			if parsed is Dictionary: credential = parsed
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 65536
	socket.outbound_buffer_size = 32768
	handshake = false
	connect_at = Time.get_ticks_msec()
	if socket.connect_to_url(endpoint) != OK:
		socket = null
		_set_notice("Could not open the server address.")
		return
	_set_notice("Connecting…")
	_render()


func _storage_key() -> String:
	return "wings-duel:" + endpoint


func _persist() -> void:
	if not storage_available: return
	storage_available = bool(JavaScriptBridge.eval("(()=>{try{localStorage.setItem(%s,%s);return true}catch{return false}})()" % [
		JSON.stringify(_storage_key()), JSON.stringify(JSON.stringify(credential))], true))


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if socket == null:
		if reconnect and now >= retry_at: _connect_server(endpoint)
		return
	socket.poll()
	var connection_state := socket.get_ready_state()
	if connection_state == WebSocketPeer.STATE_CLOSED or (connection_state == WebSocketPeer.STATE_CONNECTING and now - connect_at > 10000):
		socket = null
		retry_at = now + 2200
		status = "Connection lost · reconnecting…" if reconnect else "Unable to connect. Check the server address and try again."
		_render()
		return
	if connection_state != WebSocketPeer.STATE_OPEN: return
	if not handshake:
		handshake = true
		if credential.is_empty():
			_set_notice("Choose a guest display name.")
			_render()
		else:
			_send({"type":"resume", "id":credential.get("id", ""), "token":credential.get("token", "")})
	while socket.get_available_packet_count() > 0:
		var event: Variant = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if event is Dictionary: _receive(event)
	if now >= ping_at:
		ping_at = now + 3000
		_send({"type":"ping"})


func _receive(event: Dictionary) -> void:
	match event.get("type"):
		"profile":
			if not str(event.get("credential", "")).is_empty():
				credential = {"id":event.profile.id, "token":event.credential}
				_persist()
			reconnect = true
			_set_notice("Connected as " + _name(event.profile))
		"auth_error":
			reconnect = false
			if event.get("invalid", false):
				credential.clear()
				if storage_available: JavaScriptBridge.eval("try{localStorage.removeItem(%s)}catch{}" % JSON.stringify(_storage_key()), true)
			_set_notice(str(event.text))
			_render()
		"notice": _set_notice(str(event.text))
		"lobby":
			state = event
			var current: Dictionary = state.get("match", {})
			if current.get("state") == "flight":
				if round_id != current.round_id or not is_instance_valid(view):
					_open_flight(current)
			else:
				_close_flight()
			_render()
		"flight":
			if is_instance_valid(view) and event.get("round_id") == round_id:
				view.apply_snapshot(event)


func _open_flight(current: Dictionary) -> void:
	_close_flight()
	round_id = current.round_id
	view = DuelView.new()
	view.side = int(current.you)
	view.kinds = current.kinds
	view.loaded.connect(func(): _match_send({"type":"loaded"}))
	view.command.connect(_match_send)
	add_child(view)


func _close_flight() -> void:
	if is_instance_valid(view):
		remove_child(view)
		view.queue_free()
	view = null
	round_id = ""
	showing_help = false


func _send(event: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN and socket.get_current_outbound_buffered_amount() < 8192:
		socket.send_text(JSON.stringify(event))


func _match_send(event: Dictionary) -> void:
	var current: Dictionary = state.get("match", {})
	event.match_id = current.get("id", "")
	event.round_id = round_id
	_send(event)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(view) and not event.is_echo() and event.is_action_pressed("pause"):
		showing_help = not showing_help
		_render()
		get_viewport().set_input_as_handled()


func _render() -> void:
	var current: Dictionary = state.get("match", {})
	if is_instance_valid(view) and not showing_help:
		screen.hide()
		return
	screen.show()
	for child in stack.get_children():
		stack.remove_child(child)
		child.queue_free()
	notice = null
	_heading("MULTIPLAYER · 1V1 DOGFIGHT", 26)
	if is_instance_valid(view):
		_heading("Controls")
		_heading("↑ / ↓ pitch · ← / → bank · A / D rudder\nW / S throttle · Space brakes · G gear · Q flaps\nF fire · R reset a wreck during preparation\nEsc closes this panel. The duel keeps running.")
		_button("Resume flight", func(): showing_help = false; _render())
		_button("Leave duel", _leave_duel)
		return
	notice = _heading(status)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not state.has("profile"):
		var url := _input_field("wss://server.example/duel", endpoint, 300)
		_button("Connect", func(): _connect_server(url.text))
		if handshake and credential.is_empty() and socket != null:
			var guest_name := _input_field("Guest display name", "", 24)
			_button("Create guest", func(): _send({"type":"create", "name":guest_name.text}))
		_heading("Clearing browser data or changing browsers can lose this guest profile." if storage_available else "Temporary guest · browser storage is unavailable.")
		_button("Back to main menu", closed.emit)
		return
	if not current.is_empty():
		_render_match(current)
		return
	_heading("Guest · " + _name(state.profile), 20)
	var display_name := _input_field("New display name", state.profile.name, 24)
	_button("Rename", func(): _send({"type":"rename","name":display_name.text}))
	if not storage_available: _heading("Temporary guest · browser storage is unavailable.")
	_career(state.stats)
	if state.has("invite"):
		var invite: Dictionary = state.invite
		_heading(("%s · " % ("Challenge sent" if invite.outgoing else "Incoming challenge")) + _name(invite.other))
		var actions := ["cancel"] if invite.outgoing else ["accept","decline"]
		for action in actions:
			_button(action.capitalize(), func(): _send({"type":action,"invite":invite.id}))
	else:
		_button("Stop looking" if state.available else "Find a Duel", func(): _send({"type":"find"}))
		if state.available:
			if state.guests.is_empty(): _heading("Waiting for other available players…")
			for guest in state.guests:
				_button("Challenge " + _name(guest), func(): _send({"type":"challenge","opponent":guest.id}))
	_button("Back to main menu", closed.emit)


func _render_match(current: Dictionary) -> void:
	var slot := int(current.you)
	_heading("vs " + _name(current.players[1-slot]), 23)
	for i in 2:
		var aircraft_name := "selecting" if current.kinds[i].is_empty() else DuelAircraft.title(current.kinds[i])
		_heading("%s · %s%s" % [_name(current.players[i]), aircraft_name, " · Ready" if current.ready[i] else ""])
	if current.state == "selection":
		if not current.kinds[slot].is_empty():
			_button("Unready" if current.ready[slot] else "Ready", func(): _match_send({"type":"ready"}))
		for side in 2:
			if int(current.sides[1-slot]) == side: continue
			_heading("Allies" if side == 0 else "Axis", 18)
			var previous_nation := ""
			for kind in DuelAircraft.ALLIES if side == 0 else DuelAircraft.AXIS:
				var nation := DuelAircraft.nation(kind)
				if nation != previous_nation:
					_heading(nation)
					previous_nation = nation
				if current.kinds[slot] != kind:
					_button("Select " + DuelAircraft.title(kind), func(): _match_send({"type":"select","side":side,"kind":kind}))
	elif current.state == "results":
		var result: Dictionary = current.result
		var winner := int(result.winner)
		_heading("Draw" if winner < 0 else ("Victory" if winner == slot else "Defeat"), 23)
		_heading(result.reason)
		_career(state.stats)
		if current.saving: _heading("Saving career result…")
		elif not current.get("can_rematch", true): _heading("Opponent left the duel.")
		elif current.rematch[slot]: _heading("Waiting for opponent to accept rematch…")
		else: _button("Rematch", func(): _match_send({"type":"rematch"}))
	_button("Leave duel", _leave_duel)


func _leave_duel() -> void:
	if socket == null or socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		closed.emit()
		return
	_match_send({"type":"leave"})
	showing_help = false
	_render()


func _career(stats: Dictionary) -> void:
	_heading("Career · %d kills · %d wins · %d losses · %d draws · %d forfeits" % [
		int(stats.kills), int(stats.wins), int(stats.losses), int(stats.draws), int(stats.forfeits)])
	var groups := []
	for key in ["side", "nation", "aircraft"]:
		var entries := PackedStringArray()
		for value in stats[key]:
			entries.append("%s %d" % [DuelAircraft.title(value) if key == "aircraft" else value, int(stats[key][value])])
		if not entries.is_empty(): groups.append(" · ".join(entries))
	if not groups.is_empty(): _heading("\n".join(groups))


func _set_notice(message: String) -> void:
	status = message
	if is_instance_valid(notice): notice.text = message


func _heading(value: String, size := 16) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e7d9b5"))
	stack.add_child(label)
	return label


func _input_field(placeholder: String, value: String, limit: int) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.text = value
	field.max_length = limit
	stack.add_child(field)
	return field


func _button(title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	stack.add_child(button)


func _name(profile: Dictionary) -> String:
	return "%s #%s" % [profile.name, profile.tag]


func _exit_tree() -> void:
	if socket != null: socket.close()
