class_name AAWeaponDefinition
extends Resource
## Gameplay approximations, not historical fragmentation measurements.
@export var display_name: String = "QF 3.7-inch"
@export var heavy: bool = true
@export var velocity: float = 790
@export var reload_seconds: float = 5
@export var traverse: float = 18
@export var elevation: float = 14
@export var recoil_metres: float = .5
@export var ammunition: int = 80
@export var clip_size: int = 4
@export var clip_delay: float = .5
@export var minimum_fuze_seconds: float = .15
@export var fuze_adjustment_per_second: float = .3
@export var fuze_seconds: float = 1.14
@export var maximum_lifetime: float = 8
@export var dispersion_degrees: float = .35
@export var direct_damage: float = 200
@export var blast_radius: float = 15
@export var blast_knots: PackedVector2Array = PackedVector2Array([Vector2(0,150),Vector2(3,100),Vector2(8,50),Vector2(14,15),Vector2(15,0)])
@export var location_damage: Dictionary = {"fuselage":40.0,"left_wing":50.0,"right_wing":50.0,"engine":80.0,"fuel_tank":60.0,"cockpit":100.0,"rudder":40.0,"elevator":40.0}
@export var sound_volume_db: float = -12
@export var simultaneous_reports: int = 4
@export var sound_path: String = "res://assets/audio/aa_heavy_shot.ogg"

func damage_at_distance(distance: float) -> float:
	if distance < 0 or not is_finite(distance) or distance >= blast_radius:return 0
	for i in range(1,blast_knots.size()):
		if distance <= blast_knots[i].x:
			var a := blast_knots[i-1]
			var b := blast_knots[i]
			return lerpf(a.y,b.y,inverse_lerp(a.x,b.x,distance))
	return 0
