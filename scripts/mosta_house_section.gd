class_name MostaHouseSection
extends BombStructureSection
## Near-square houses reuse the raid damage receiver and normal projectile hits.

func take_damage(amount: float) -> void:
	apply_blast(amount, global_position + global_basis.z * 4)
