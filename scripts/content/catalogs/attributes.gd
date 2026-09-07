extends RefCounted

const TYPES := {
	"investment_refund": preload("res://scripts/content/nodes/attributes/investment_refund.gd"),
	"root": preload("res://scripts/content/nodes/attributes/root.gd"),
	"momentum_speed": preload("res://scripts/content/nodes/attributes/momentum.gd"),
	"momentum_damage": preload("res://scripts/content/nodes/attributes/momentum.gd"),
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

const RULES := {"momentum_speed": {"stat": "speed"}, "momentum_damage": {"stat": "damage"}, "damage_over_time": {"effect": "dot"}, "slow": {"effect": "slow"}, "expose": {"effect": "expose"}, "boss_damage": {"condition": "boss"}, "healthy_damage": {"condition": "healthy"}, "wounded_damage": {"condition": "wounded"}, "hindered_damage": {"condition": "hindered"}}
