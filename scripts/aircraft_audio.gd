class_name AircraftAudio
extends Node3D
## Two spatial loops per aircraft. No changes to flight forces or commands.
@export var engine_volume_db: float = -12.0
@export var audible_distance: float = 1800.0
@export var blend_seconds: float = 0.35
@export var minimum_pitch: float = 0.82
@export var maximum_pitch: float = 1.16
@export var enemy_flyby_profile: AircraftFlybyProfile = preload("res://audio_profiles/enemy_flyby.tres")
var flyby: EnemyFlybyAudio
var aircraft: FlightAircraft
var idle: AudioStreamPlayer3D
var flight: AudioStreamPlayer3D
var engine_gain: float = 0
var flight_mix: float = 0
var rpm: float = 0

func _exit_tree() -> void:
	clear()
	idle.stream = null
	flight.stream = null

func _ready() -> void:
	position = Vector3(0, 0, -2.8)
	idle = _make_player("IdleEngine", GameAudioMixer.instance.engine_stream(aircraft, false))
	flight = _make_player("FlightEngine", GameAudioMixer.instance.engine_stream(aircraft, true))
	if aircraft.team_id == CombatTeams.ENEMY:
		flyby = EnemyFlybyAudio.new()
		flyby.name = "EnemyFlybyAudio"
		flyby.audio = self
		flyby.profile = enemy_flyby_profile
		add_child(flyby)
	aircraft.reset_completed.connect(clear)
	aircraft.destroyed.connect(clear)
	aircraft.crashed.connect(func(_reason: String): clear())

func _make_player(player_name: String, stream: AudioStreamOggVorbis) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = GameAudioMixer.instance.loop_stream(stream)
	player.bus = "Aircraft"
	player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE if OS.has_feature("web") else AudioServer.PLAYBACK_TYPE_STREAM
	player.volume_db = -80
	player.max_db = 0
	player.unit_size = 12
	player.max_distance = audible_distance
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(player)
	return player

func _process(delta: float) -> void:
	if not GameAudioMixer.instance.playback_enabled:
		return
	var power: float = aircraft.components.power_factor()
	var running: bool = aircraft.engine_running and power > 0.01 and not aircraft.is_crashed and not aircraft.is_destroyed and not aircraft.reset_pending
	var desired_rpm: float = (0.24 + aircraft.pilot.throttle * 0.76) * power if running else 0.0
	rpm = move_toward(rpm, desired_rpm, delta / maxf(blend_seconds, 0.01))
	engine_gain = move_toward(engine_gain, 1.0 if running else 0.0, delta / maxf(blend_seconds, 0.01))
	# Throttle drives both timbre and RPM; high speed alone cannot restart an
	# engine that is shut down, out of fuel or destroyed.
	flight_mix = move_toward(flight_mix, aircraft.pilot.throttle * power if running else 0.0, delta / maxf(blend_seconds, 0.01))
	if running and not idle.playing:
		idle.play()
		flight.play()
	var mix: float = flight_mix
	var proximity: float = 1
	var shift: float = 1
	var volume: float = engine_volume_db
	if flyby != null:
		mix = flyby.effective_flight_mix()
		proximity = flyby.distance_gain * flyby.mix_gain(delta)
		shift = flyby.doppler_factor
		volume = flyby.profile.engine_volume_db
		flyby.apply_airflow()
	for player in [idle, flight]:
		player.pitch_scale = lerpf(minimum_pitch, maximum_pitch, rpm) * shift
	# Equal-power blend avoids a dip at half throttle. Samples were converted
	# to mono for 3D panning; bus/headroom prevents loud aircraft from clipping.
	var loudness: float = engine_gain * lerpf(0.6, 1.0, rpm) * proximity
	idle.volume_db = volume + linear_to_db(maxf(loudness * sqrt(1.0 - mix), 0.0001))
	flight.volume_db = volume + linear_to_db(maxf(loudness * sqrt(mix), 0.0001))
	if not running and engine_gain <= 0:
		idle.stop()
		flight.stop()

func clear() -> void:
	engine_gain = 0
	flight_mix = 0
	rpm = 0
	if is_instance_valid(flyby): flyby.clear()
	idle.stop()
	flight.stop()
