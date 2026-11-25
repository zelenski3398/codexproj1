class_name DuelStore
extends RefCounted

var path: String
var data: Dictionary = {"profiles": {}, "results": {}}

func _init(storage: String) -> void:
	path = storage
	if FileAccess.file_exists(path):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if loaded is Dictionary and loaded.get("profiles") is Dictionary and loaded.get("results") is Dictionary:
			data = loaded
		else:
			push_error("Invalid duel profile store; refusing to replace it")
			path = ""

func commit(updated: Dictionary) -> bool:
	if path.is_empty(): return false
	var stream := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if stream == null: return false
	stream.store_string(JSON.stringify(updated))
	stream.flush()
	var saved := stream.get_error() == OK
	stream.close()
	if not saved or DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) != OK:
		return false
	data = updated
	return true

func create(display_name: String) -> Dictionary:
	var crypto := Crypto.new()
	var id := crypto.generate_random_bytes(16).hex_encode()
	var token := crypto.generate_random_bytes(32).hex_encode()
	var updated := data.duplicate(true)
	updated.profiles[id] = {"name": display_name, "credential_hash": token.sha256_text(),
		"stats": {"wins": 0, "losses": 0, "draws": 0, "forfeits": 0, "kills": 0,
			"side": {}, "nation": {}, "aircraft": {}}}
	return {"id": id, "token": token} if commit(updated) else {}

func authorize(id: String, token: String) -> bool:
	if id.length() != 32 or token.length() != 64 or not data.profiles.has(id): return false
	var expected: String = data.profiles[id].credential_hash
	return Crypto.new().constant_time_compare(expected.to_ascii_buffer(), token.sha256_text().to_ascii_buffer())

func rename_guest(id: String, display_name: String) -> bool:
	var updated := data.duplicate(true)
	updated.profiles[id].name = display_name
	return commit(updated)

func identity(id: String) -> Dictionary:
	return {"id": id, "name": data.profiles[id].name, "tag": id.left(8)}

func record(match_id: String, players: Array, kinds: Array, winner: int, forfeits: Array, kills: Array, reason: String) -> bool:
	if data.results.has(match_id): return true
	var updated := data.duplicate(true)
	var events := []
	for side in 2:
		var stats: Dictionary = updated.profiles[players[side]].stats
		var outcome := "draws" if winner < 0 else ("wins" if winner == side else "losses")
		stats[outcome] += 1
		if forfeits[side]: stats.forfeits += 1
		if not kills[side]: continue
		stats.kills += 1
		var side_name := "Allies" if side == 0 else "Axis"
		var nation := DuelAircraft.nation(kinds[side])
		for item in [["side", side_name], ["nation", nation], ["aircraft", kinds[side]]]:
			stats[item[0]][item[1]] = stats[item[0]].get(item[1], 0) + 1
		events.append({"id": "%s:%d" % [match_id, side], "guest": players[side],
			"aircraft": kinds[side], "defeated": kinds[1 - side]})
	updated.results[match_id] = {"players": players, "aircraft": kinds, "winner": winner,
		"forfeits": forfeits, "reason": reason, "kills": events}
	return commit(updated)
