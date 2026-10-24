class_name BoforsAimAssist
extends RefCounted
## Read-only sight data from a player-assigned predictor. No automatic target
## acquisition, aim movement, firing, damage or projectile steering.
var gun: BritishAAGun
var target: FlightAircraft
var solution: Dictionary = {}
var scan_clock: float = 0 # Retained for older diagnostic callers.
func update(_delta: float) -> void:
	target=null;solution.clear()
	if gun.weapon.heavy or AAMouseControls.fire_control_mode==0 or not gun.mounted or gun.mouse_controls.blocked():return
	if not is_instance_valid(gun.predictor_post) or gun.predictor_post.is_destroyed:return
	solution=gun.predictor_post.get_solution(gun).duplicate()
	if not solution.is_empty():target=gun.predictor_post.target
