class_name EnemyFlybyAudio
extends Node
## One continuous, spatial engine/airflow treatment per enemy. No pass-trigger
## sound spam and no motion changes. Godot still owns 3D listener-relative pan.
var audio: AircraftAudio
var profile: AircraftFlybyProfile
var airflow: AudioStreamPlayer3D
var distance: float = INF
var relative_speed: float = 0
var radial_speed: float = 0 # positive = receding
var distance_gain: float = 0
var fullness: float = 0
var doppler_factor: float = 1
var airflow_gain: float = 0
var crowd_gain: float = 1
var listener_id: int = 0
var listener_velocity: Vector3 = Vector3.ZERO
var listener_resets: int = 0
var airflow_starts: int = 0
var _last_listener_position: Vector3
var _settle_clock: float = 0
var _bound_stream: AudioStream

func _ready() -> void:
	add_to_group("enemy_flyby_audio")
	airflow = AudioStreamPlayer3D.new()
	airflow.name = "ClosePassAirflow"
	audio.add_child(airflow)
	configure_sources()

func configure_sources() -> void:
	for source in [audio.idle, audio.flight, airflow]:
		source.bus = "Aircraft" # Existing pause, volume and radio duck cover all layers.
		# Use exactly ONE Doppler calculation. Built-in Doppler cannot expose our
		# pitch limits/camera-reset guard consistently for native and web samples.
		source.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		# Custom continuous attenuation already includes the distant fade. Do not
		# multiply it by Godot's inverse/linear max-distance attenuation a second time.
		source.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		source.max_distance = 0
		source.max_db = 0
		source.panning_strength = profile.panning_strength
	airflow.volume_db = -80
	airflow.playback_type = audio.idle.playback_type
	_bind_stream()

func _bind_stream() -> void:
	if _bound_stream == profile.airflow_stream and airflow.stream != null:
		return
	airflow.stop()
	_bound_stream = profile.airflow_stream
	airflow.stream = _bound_stream.duplicate() as AudioStream if _bound_stream != null else null
	if airflow.stream is AudioStreamOggVorbis or airflow.stream is AudioStreamMP3:
		airflow.stream.loop = true
	elif airflow.stream is AudioStreamWAV:
		airflow.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		airflow.stream.loop_begin = 0
		airflow.stream.loop_end = roundi(airflow.stream.get_length() * airflow.stream.mix_rate)

func _physics_process(delta: float) -> void:
	if audio.aircraft.is_destroyed or audio.aircraft.is_crashed or audio.aircraft.reset_pending:
		return
	var viewport: Viewport = get_viewport()
	var listener: Node3D = viewport.get_audio_listener_3d()
	if listener == null: listener = viewport.get_camera_3d()
	if listener == null:
		_settle_clock = profile.listener_settle_seconds
		distance_gain = _blend(distance_gain, 0, delta, profile.distance_blend_seconds)
		airflow_gain = _blend(airflow_gain, 0, delta, profile.airflow_release_seconds)
		doppler_factor = _blend(doppler_factor, 1, delta, profile.doppler_blend_seconds)
		return
	var position: Vector3 = listener.get_camera_transform().origin if listener is Camera3D else listener.global_position
	var displacement: Vector3 = position - _last_listener_position
	var raw_velocity: Vector3 = displacement / maxf(delta, .0001)
	if listener_id != listener.get_instance_id() or displacement.length() > profile.listener_teleport_distance or raw_velocity.length() > profile.maximum_listener_speed:
		listener_id = listener.get_instance_id()
		listener_velocity = Vector3.ZERO
		_settle_clock = profile.listener_settle_seconds
		listener_resets += 1
	else:
		listener_velocity = listener_velocity.lerp(raw_velocity, 1 - exp(-delta / maxf(profile.listener_velocity_blend_seconds, .001)))
	_last_listener_position = position
	_settle_clock = maxf(0, _settle_clock - delta)
	var aircraft: FlightAircraft = audio.aircraft
	var source_velocity: Vector3 = aircraft.linear_velocity + aircraft.angular_velocity.cross(audio.global_position - aircraft.global_position)
	update_motion(audio.global_position, source_velocity, position, listener_velocity, delta, _settle_clock <= 0)

func update_motion(source: Vector3, source_velocity: Vector3, listener: Vector3, velocity: Vector3, delta: float, motion_ready: bool = true) -> void:
	# Pure acoustic state update, also used by disclosed deterministic test
	# trajectories. The game caller above samples the actual physics/listener.
	var offset: Vector3 = source - listener
	distance = offset.length()
	var direction: Vector3 = offset / maxf(distance, .001)
	var relative: Vector3 = source_velocity - velocity
	relative_speed = relative.length()
	radial_speed = relative.dot(direction)
	distance_gain = _blend(distance_gain, profile.engine_attenuation(distance), delta, profile.distance_blend_seconds)
	fullness = _blend(fullness, 1 - smoothstep(0, maxf(profile.full_engine_range, 1), distance), delta, profile.distance_blend_seconds)
	var shift: float = 1
	if motion_ready and profile.doppler_enabled and distance > 1:
		var sound_speed: float = maxf(profile.speed_of_sound, 100)
		var limit: float = minf(profile.maximum_radial_speed, sound_speed * .75)
		var source_radial: float = clampf(source_velocity.dot(direction), -limit, limit)
		var listener_radial: float = clampf(velocity.dot(direction), -limit, limit)
		shift = pow((sound_speed + listener_radial) / (sound_speed + source_radial), profile.doppler_strength)
		shift = clampf(shift, profile.minimum_doppler_pitch, maxf(profile.maximum_doppler_pitch, profile.minimum_doppler_pitch))
	doppler_factor = _blend(doppler_factor, shift, delta, profile.doppler_blend_seconds)
	# Matching formation speed yields zero airflow even if world speed is high.
	# A continuous proximity envelope naturally builds before, and trails after,
	# closest approach. No one-shot trigger/cooldown or per-frame restart exists.
	var target: float = profile.airflow_amount(distance, relative_speed) if motion_ready else 0.0
	airflow_gain = _blend(airflow_gain, target, delta, profile.airflow_attack_seconds if target > airflow_gain else profile.airflow_release_seconds)

func effective_flight_mix() -> float:
	return audio.flight_mix * lerpf(profile.distant_flight_mix, 1, fullness)

func estimated_peak() -> float:
	var mix: float = clampf(effective_flight_mix(), 0, 1)
	var engine: float = db_to_linear(profile.engine_volume_db) * audio.engine_gain * lerpf(.6, 1, audio.rpm) * distance_gain * (sqrt(1 - mix) + sqrt(mix))
	var air: float = db_to_linear(profile.airflow_volume_db) * airflow_gain if profile.airflow_stream != null else 0.0
	return engine + air

func mix_gain(delta: float) -> float:
	var total: float = 0
	for voice in get_tree().get_nodes_in_group("enemy_flyby_audio"):
		total += voice.estimated_peak()
	var target: float = minf(1, profile.enemy_peak_budget / maxf(total, .001))
	# Fast protection / gentle release without a compressor effect unsupported
	# by Godot's web sample mixer. Relative spatial loudness is retained.
	crowd_gain = minf(target, _blend(crowd_gain, target, delta, profile.mix_release_seconds))
	return crowd_gain

func apply_airflow() -> void:
	if _bound_stream != profile.airflow_stream: _bind_stream()
	airflow.volume_db = profile.airflow_volume_db + linear_to_db(maxf(airflow_gain * crowd_gain, .0001))
	airflow.pitch_scale = doppler_factor
	if airflow.stream == null or not GameAudioMixer.instance.playback_enabled:
		return # Missing recording remains silent, never replaced by a siren/noise.
	if airflow_gain > .001 and not airflow.playing:
		airflow.play()
		airflow_starts += 1
	elif airflow_gain <= .001 and airflow.playing:
		airflow.stop()

func clear() -> void:
	distance = INF
	relative_speed = 0
	radial_speed = 0
	distance_gain = 0
	fullness = 0
	doppler_factor = 1
	airflow_gain = 0
	crowd_gain = 1
	listener_id = 0
	listener_velocity = Vector3.ZERO
	if is_instance_valid(airflow):
		airflow.stop()
		airflow.volume_db = -80

func diagnostic_state() -> Dictionary:
	return {"distance":distance if is_finite(distance) else -1, "relative_speed":relative_speed, "radial_speed":radial_speed, "gain":distance_gain, "fullness":fullness, "doppler":doppler_factor, "airflow_gain":airflow_gain, "airflow_supplied":profile.airflow_stream != null, "airflow_playing":airflow.playing, "airflow_starts":airflow_starts, "crowd_gain":crowd_gain, "listener_id":listener_id, "listener_resets":listener_resets}

static func _blend(current: float, target: float, delta: float, seconds: float) -> float:
	return lerpf(current, target, 1 - exp(-maxf(delta, 0) / maxf(seconds, .001)))
