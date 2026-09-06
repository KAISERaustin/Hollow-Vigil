extends RefCounted

const GEAR := {
	"warden": {"name": "Warden’s Rootheart", "root_period": 6.0, "root_duration": 0.75, "boss_root_duration": 0.35, "root_immunity": 3.0},
	"cindermaw": {"name": "Ember Fang", "speed_per_stack": 8.0, "stack_limit": 5.0, "stack_timeout": 3.0},
	"bell": {"name": "Tollstone", "attack_count": 4.0, "echo_multiplier": 0.5},
	"prior": {"name": "Eclipse Shard", "attack_count": 5.0, "damage_multiplier": 1.5, "defense_bypass": 1.0}
}

const PRESENTATION := {
	"warden": {"name": "Warden’s Rootheart", "color": "a9d58b", "symbol": "root", "description": "Every 6 seconds, a primary shot roots its target for 0.75 seconds (0.35 for bosses). Each enemy can be rooted only once every 3 seconds."},
	"cindermaw": {"name": "Ember Fang", "color": "ffa568", "symbol": "fang", "description": "Consecutive attacks on the same primary target gain 8% attack speed, up to 40%. Resets when the target changes or attacks stop for 3 seconds."},
	"bell": {"name": "Tollstone", "color": "8ce3dc", "symbol": "bell", "description": "Every fourth attack echoes the primary shot at 50% base damage. The echo keeps its blast radius but triggers no specialization or relic effects."},
	"prior": {"name": "Eclipse Shard", "color": "d2adf3", "symbol": "eclipse", "description": "Every fifth attack empowers its primary shot: +50% damage and bypasses boss shields, armor and wards. Its blast shares this power; secondary arrows, chains and damage over time do not pierce."}
}
