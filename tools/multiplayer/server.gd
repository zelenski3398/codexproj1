extends SceneTree

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	GameAudioMixer.instance.playback_enabled = false
	root.add_child(preload("res://scripts/multiplayer/duel_server.gd").new())
