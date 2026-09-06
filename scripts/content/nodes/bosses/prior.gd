extends "res://scripts/content/nodes/boss_node.gd"

func absorb_damage(enemy: Dictionary, amount: float, branch: String, _fire: bool, tuning: Dictionary = {}, pierce: bool = false) -> float:
	var stats := definition(tuning)
	if not pierce and enemy.wards > 0 and (branch != "doomstone" or stats.doom_bypass == 0):
		enemy.wards -= 1
		return 0.0
	return amount
