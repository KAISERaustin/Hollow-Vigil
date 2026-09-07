extends RefCounted

const TYPES := {
	"piercing_attack": preload("res://scripts/content/nodes/attributes/line_attack.gd"),
	"returning_attack": preload("res://scripts/content/nodes/attributes/line_attack.gd"),
	"orbit_attack": preload("res://scripts/content/nodes/attributes/orbit_attack.gd"),
	"road_traps": preload("res://scripts/content/nodes/attributes/road_traps.gd"),
	"vulnerability_mark": preload("res://scripts/content/nodes/attributes/vulnerability_mark.gd"),
	"tower_boss_damage": preload("res://scripts/content/nodes/attributes/tower_boss_damage.gd"),
	"investment_refund": preload("res://scripts/content/nodes/attributes/investment_refund.gd"),
	"root": preload("res://scripts/content/nodes/attributes/root.gd"),
	"momentum_speed": preload("res://scripts/content/nodes/attributes/momentum.gd"),
	"momentum_damage": preload("res://scripts/content/nodes/attributes/momentum.gd"),
	"kill_momentum": preload("res://scripts/content/nodes/attributes/kill_momentum.gd"),
	"range_bonus": preload("res://scripts/content/nodes/attributes/range_bonus.gd"),
	"ground_damage": preload("res://scripts/content/nodes/attributes/ground_damage.gd"),
	"echo": preload("res://scripts/content/nodes/attributes/echo.gd"),
	"empower": preload("res://scripts/content/nodes/attributes/empower.gd"),
	"damage_over_time": preload("res://scripts/content/nodes/attributes/affliction.gd"),
	"slow": preload("res://scripts/content/nodes/attributes/affliction.gd"),
	"expose": preload("res://scripts/content/nodes/attributes/affliction.gd"),
	"boss_damage": preload("res://scripts/content/nodes/attributes/conditional_damage.gd"),
	"healthy_damage": preload("res://scripts/content/nodes/attributes/conditional_damage.gd"),
	"wounded_damage": preload("res://scripts/content/nodes/attributes/conditional_damage.gd"),
	"hindered_damage": preload("res://scripts/content/nodes/attributes/conditional_damage.gd"),
	"blast": preload("res://scripts/content/nodes/attributes/blast.gd"),
	"knockback": preload("res://scripts/content/nodes/attributes/knockback.gd"),
	"stun": preload("res://scripts/content/nodes/attributes/stun.gd"),
	"fork": preload("res://scripts/content/nodes/attributes/fork.gd"),
	"opening": preload("res://scripts/content/nodes/attributes/opening.gd")
}

const RULES := {"orbit_attack": {"presentation": "orbit"}, "returning_attack": {"returning": true}, "momentum_speed": {"stat": "speed"}, "momentum_damage": {"stat": "damage"}, "damage_over_time": {"effect": "dot"}, "slow": {"effect": "slow"}, "expose": {"effect": "expose"}, "boss_damage": {"condition": "boss"}, "healthy_damage": {"condition": "healthy"}, "wounded_damage": {"condition": "wounded"}, "hindered_damage": {"condition": "hindered"}}
