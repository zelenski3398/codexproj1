class_name StElmoRaid
extends Node3D
## The director owns all raid ordnance, visuals, results and session transitions.

@export var interceptor_delay: float = 20.0
@export var interceptor_distance: float = 1550.0
@export var interceptor_aim_error: float = 0.32
@export var interceptor_aggression: float = 11.0
@export var interceptor_burst_duration: float = 0.65
@export var interceptor_burst_rest: float = 1.65
@export var required_target_damage: float = 85.0

var session: Node3D
var player: PlayerStuka
var interceptor: RaidInterceptor
var range_scenery: RaidRange
var radio: MissionRadioQueue
var raid_mode: bool = true
var fighter_defeated: bool = false
var fighter_spawned: bool = false
var player_lost: bool = false
var bomb_in_flight: bool = false
var bomb_resolved: bool = false
var stars: int = -1
var elapsed: float = 0
var result: PanelContainer

const RADIO := {
	"brief": "Your target is Fort St Elmo. Hit the marked target area with your bomb.",
	"intercept": "An enemy fighter is approaching. Continue the attack!",
	"release": "Bomb released. Pull up!",
	"hit": "Direct hit! The target has been struck. Good work!",
	"miss": "The bomb missed the target. Destroy the enemy fighter!",
	"fighter": "The enemy fighter has been shot down. However, the bombing attack failed.",
	"failure": "The mission has failed.",
}

func _ready() -> void:
	range_scenery = RaidRange.new()
	add_child(range_scenery)
	range_scenery.call_deferred("build", raid_mode)
	player.ordnance_root = self
	if not raid_mode: return
	player.bomb_released.connect(_on_release)
	player.destroyed.connect(_player_lost)
	player.crashed.connect(func(_reason: String): _player_lost())
	radio = MissionRadioQueue.new()
	radio.definition = HarbourDefinition.new()
	radio.definition.radio_duck_db = -5
	add_child(radio)
	radio.use_raid_audio_settings = true
	_cue("brief")

func _physics_process(delta: float) -> void:
	if not raid_mode:
		var nearest: FlightAircraft
		var distance := INF
		for candidate in session.encounters.active:
			if not is_instance_valid(candidate) or candidate.is_crashed or candidate.is_destroyed: continue
			var offset: Vector3 = candidate.global_position - player.global_position
			if offset.length_squared() < distance and player.rear_gunner.inside_arc(player.global_basis.transposed() * offset):
				nearest = candidate
				distance = offset.length_squared()
		player.rear_gunner.player_target = nearest
		return
	if stars >= 0: return
	elapsed += delta
	if not fighter_spawned and not player_lost and elapsed >= interceptor_delay:
		spawn_interceptor()

func spawn_interceptor() -> void:
	if fighter_spawned: return
	fighter_spawned = true
	interceptor = RaidInterceptor.new()
	var offset := Vector3(-0.70, 0.0, 0.71) * interceptor_distance
	var start := player.global_position + offset + Vector3.UP * 45
	start.y = maxf(start.y, 310)
	interceptor.reset_position = start
	add_child(interceptor)
	interceptor.request_reset()
	var direction := player.global_position - start
	direction.y = 0
	var facing := Basis.looking_at(direction.normalized(), Vector3.UP)
	interceptor.pending_reset_pose = Transform3D(facing, start)
	interceptor.pending_reset_velocity = -facing.z * 51
	interceptor.ai.target = player
	interceptor.ai.patrol_center = start
	interceptor.ai.engage_speed_bonus = interceptor_aggression
	interceptor.ai.aim_error_degrees = interceptor_aim_error
	interceptor.ai.burst_duration = interceptor_burst_duration
	interceptor.ai.burst_rest = interceptor_burst_rest
	interceptor.destroyed.connect(_interceptor_lost)
	player.rear_gunner.player_target = interceptor
	_cue("intercept")

func _on_release(bomb: RaidBomb) -> void:
	bomb_in_flight = true
	bomb.resolved.connect(_on_impact, CONNECT_ONE_SHOT)
	_cue("release")

func _on_impact(section_damage: Dictionary, direct_section: StringName) -> void:
	bomb_in_flight = false
	bomb_resolved = true
	var target_damage: float = 0
	for id in RaidRange.TARGET_IDS:
		target_damage += float(section_damage.get(id, 0.0))
	if String(direct_section).begins_with("st_elmo_store_") and target_damage >= required_target_damage:
		_finish(2, "The designated stores took enough damage.", "hit")
	else:
		_evaluate()
		if stars < 0: _cue("miss")

func _interceptor_lost() -> void:
	fighter_defeated = true
	_evaluate()

func _player_lost() -> void:
	player_lost = true
	# Evaluate after same-tick crash/destruction and impact signals settle.
	call_deferred("_evaluate")

func _evaluate() -> void:
	if stars >= 0 or bomb_in_flight: return
	if fighter_defeated and bomb_resolved:
		_finish(1, "Interceptor destroyed. Bombing objective incomplete.", "fighter")
	elif player_lost:
		_finish(0, "Stuka lost before a qualifying result.", "failure")

func objective_text() -> String:
	if stars >= 0:
		return "Mission failed" if stars == 0 else "Mission complete"
	if bomb_in_flight: return "Bomb released · awaiting impact"
	if bomb_resolved: return "Destroy the Gladiator"
	return "Bomb the marked stores at St Elmo"

func _cue(id: String, priority: bool = false) -> void:
	if not is_instance_valid(radio): return
	var path := "res://assets/audio/raid/commander_%s.ogg" % id
	var voice := load(path) as AudioStream if ResourceLoader.exists(path) else null
	radio.cue(id, RADIO[id], voice, false, priority)

func _finish(score: int, explanation: String, cue_id: String) -> void:
	if stars >= 0: return
	stars = score
	player.input_enabled = false
	player.pilot.automated = true
	player.pilot.reset_commands()
	if is_instance_valid(interceptor):
		interceptor.ai.combat_enabled = false
		interceptor.ai.target = null
	if is_instance_valid(range_scenery.target_marker): range_scenery.target_marker.hide()
	_cue(cue_id, true)
	call_deferred("_show_result", explanation)

func _show_result(explanation: String) -> void:
	if not is_inside_tree(): return
	var canvas := CanvasLayer.new()
	canvas.layer = 23
	add_child(canvas)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(center)
	result = PanelContainer.new()
	result.custom_minimum_size.x = 330
	center.add_child(result)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 12)
	result.add_child(contents)
	var heading := Label.new()
	heading.text = "MISSION FAILED" if stars == 0 else "%s  ·  %d / 2 STARS" % ["★".repeat(stars), stars]
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(heading)
	var detail := Label.new()
	detail.text = explanation
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(detail)
	for caption in ["Retry", "Return to Menu"]:
		var button := Button.new()
		button.text = caption
		contents.add_child(button)
		button.pressed.connect(session.restart_malta if caption == "Retry" else session.return_to_missions, CONNECT_DEFERRED)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
