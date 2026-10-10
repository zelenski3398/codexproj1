class_name WeaponAudio
extends Node3D
## One pooled sound voice per gun battery, not one sound/node per bullet.
## Successful emitted salvos trigger it; blocked muzzles and dry pools do not.
@export var gun_volume_db: float = -9.0
@export var audible_distance: float = 2200.0
@export var fade_seconds: float = 0.045
var guns: WingGuns
var player: AudioStreamPlayer3D
var since_shot: float = 1000
var gain: float = 0
var audible_salvos: int = 0

func _exit_tree() -> void:
	clear()
	player.stream = null

func _ready() -> void:
	player = AudioStreamPlayer3D.new()
	player.name = "GunBatterySound"
	player.stream = GameAudioMixer.instance.loop_stream(GameAudioMixer.instance.gun_stream(guns.aircraft))
	player.bus = "Guns"
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	player.volume_db = -80
	player.unit_size = 35
	player.max_distance = audible_distance
	player.max_db = 0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(player)
	guns.salvo_fired.connect(_salvo)
	guns.cleared.connect(clear)

func _salvo(_rounds: int) -> void:
	if not GameAudioMixer.instance.playback_enabled:
		return
	since_shot = 0
	audible_salvos += 1
	# Rear gun uses its traversing muzzle; wing batteries use the mean origin.
	var center: Vector3 = Vector3.ZERO
	for port in guns.firing_ports:
		center += to_local(port.global_position)
	if not guns.firing_ports.is_empty():
		player.position = center / guns.firing_ports.size()
	if not player.playing:
		player.play()

func _process(delta: float) -> void:
	since_shot += delta
	var grace: float = clampf(1.5 / maxf(guns.rounds_per_second, 1), 0.08, 0.35)
	var held: bool = guns.external_fire if guns.externally_controlled else (guns.aircraft.pilot.fire if guns.aircraft.pilot.automated else Input.is_action_pressed("fire"))
	var firing: bool = held and since_shot < grace and not guns.aircraft.is_destroyed and not guns.aircraft.is_crashed
	gain = move_toward(gain, 1.0 if firing else 0.0, delta / maxf(fade_seconds, 0.001))
	player.volume_db = gun_volume_db + linear_to_db(maxf(gain, 0.0001))
	if not firing and gain <= 0:
		player.stop()

func clear() -> void:
	since_shot = 1000
	gain = 0
	player.stop()
