extends RefCounted

const TUNING_FIELDS := {
	"gear": {
		"root_period": {"label": "Root attack interval", "suffix": " s", "min": 0.1, "max": 120.0, "step": 0.1},
		"root_duration": {"label": "Enemy root duration", "suffix": " s", "min": 0.0, "max": 60.0, "step": 0.01},
		"boss_root_duration": {"label": "Boss root duration", "suffix": " s", "min": 0.0, "max": 60.0, "step": 0.01},
		"root_immunity": {"label": "Enemy root immunity", "suffix": " s", "min": 0.0, "max": 60.0, "step": 0.1},
		"speed_per_stack": {"label": "Attack speed per stack", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"stack_limit": {"label": "Maximum speed stacks", "suffix": "", "min": 0.0, "max": 100.0, "step": 1.0, "integer": true},
		"stack_timeout": {"label": "Speed stack timeout", "suffix": " s", "min": 0.1, "max": 120.0, "step": 0.1},
		"attack_count": {"label": "Attacks per activation", "suffix": "", "min": 1.0, "max": 100.0, "step": 1.0, "integer": true},
		"echo_multiplier": {"label": "Echo damage", "suffix": "× hit damage", "min": 0.0, "max": 20.0, "step": 0.1},
		"damage_multiplier": {"label": "Empowered damage", "suffix": "× hit damage", "min": 0.0, "max": 20.0, "step": 0.1},
		"defense_bypass": {"label": "Bypass boss defenses (0 off, 1 on)", "suffix": "", "min": 0.0, "max": 1.0, "step": 1.0, "integer": true}
	},
	"bosses": {
		"push_resistance": {"label": "Knockback resistance", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"escort_kind": {"label": "Escort type: 0 Hollow, 1 Wraith, 2 Revenant, 3 Lantern, 4 Shade, 5 Sentinel", "suffix": "", "min": 0.0, "max": 5.0, "step": 1.0, "integer": true},
		"hp": {"label": "Health", "suffix": " HP", "min": 1.0, "max": 100000.0, "step": 1.0},
		"speed": {"label": "Move speed", "suffix": " units/s", "min": 1.0, "max": 250.0, "step": 1.0},
		"payout": {"label": "Gold per defeat", "suffix": " gold", "min": 0.0, "max": 10000.0, "step": 1.0},
		"shield": {"label": "Root shield", "suffix": " HP", "min": 0.0, "max": 10000.0, "step": 1.0},
		"regen_period": {"label": "Defense regrowth interval", "suffix": " s", "min": 0.1, "max": 120.0, "step": 0.1},
		"fire_multiplier": {"label": "Cinderfield shield damage", "suffix": "×", "min": 1.0, "max": 10.0, "step": 0.1},
		"regrowth_suppression": {"label": "Counter-tower regrowth suppression", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"rage_threshold": {"label": "Haste / armor health threshold", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"haste_multiplier": {"label": "Low-health speed", "suffix": "×", "min": 1.0, "max": 5.0, "step": 0.1},
		"armor_reduction": {"label": "High-health damage reduction", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"frost_multiplier": {"label": "Frostneedle damage received", "suffix": "×", "min": 0.0, "max": 10.0, "step": 0.1},
		"quench": {"label": "Frostneedle haste suppression", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"toll_period": {"label": "Escort summon interval", "suffix": " s", "min": 0.1, "max": 120.0, "step": 0.1},
		"escort_count": {"label": "Escorts per toll", "suffix": "", "min": 0.0, "max": 20.0, "step": 1.0, "integer": true},
		"escort_limit": {"label": "Living escort limit", "suffix": "", "min": 0.0, "max": 50.0, "step": 1.0, "integer": true},
		"seal_multiplier": {"label": "Thunderseal detonation damage", "suffix": "× hit damage", "min": 0.0, "max": 15.0, "step": 0.1},
		"toll_delay": {"label": "Thunderseal toll delay", "suffix": " s", "min": 0.0, "max": 60.0, "step": 0.1},
		"wards": {"label": "Protective wards", "suffix": " hits", "min": 0.0, "max": 20.0, "step": 1.0, "integer": true},
		"doom_bypass": {"label": "Doomstone bypasses wards (0 off, 1 on)", "suffix": "", "min": 0.0, "max": 1.0, "step": 1.0, "integer": true},
		"curse_threshold": {"label": "Doomstone stacks to suppress regrowth", "suffix": " stacks", "min": 0.0, "max": 100.0, "step": 1.0, "integer": true}
	},
	"rifts": {
		"strength": {"label": "Effect strength", "suffix": "%", "min": 0.0, "max": 100.0, "step": 0.25}
	},
	"enemies": {
		"push_resistance": {"label": "Knockback resistance", "suffix": "%", "min": 0.0, "max": 100.0, "step": 1.0},
		"hp": {"label": "Health", "suffix": " HP", "min": 1.0, "max": 100000.0, "step": 1.0},
		"speed": {"label": "Move speed", "suffix": " units/s", "min": 1.0, "max": 250.0, "step": 1.0},
		"payout": {"label": "Gold per defeat", "suffix": " gold", "min": 0.0, "max": 10000.0, "step": 1.0}
	},
	"towers": {
		"targets": {"label": "Targets per attack", "suffix": "", "min": 1, "max": 50, "step": 1, "integer": true},
		"slow_percent": {"label": "Slow strength (%)", "suffix": "", "min": 0, "max": 100, "step": 1},
		"slow_duration": {"label": "Slow duration (s)", "suffix": "", "min": 0, "max": 60, "step": 0.1},
		"arrow_count": {"label": "Arrows per volley", "suffix": "", "min": 1, "max": 31, "step": 1, "integer": true},
		"fan_angle": {"label": "Fan spread (radians)", "suffix": "", "min": 0, "max": 3.14, "step": 0.01},
		"burn_duration": {"label": "Burn duration (s)", "suffix": "", "min": 0.1, "max": 60, "step": 0.1},
		"burn_multiplier": {"label": "Burn damage per second / hit damage", "suffix": "", "min": 0, "max": 10, "step": 0.01},
		"push_distance": {"label": "Knockback distance", "suffix": "", "min": 0, "max": 300, "step": 1},
		"push_immunity": {"label": "Knockback immunity (s)", "suffix": "", "min": 0, "max": 60, "step": 0.1},
		"fragment_count": {"label": "Seeking fragments", "suffix": "", "min": 0, "max": 50, "step": 1, "integer": true},
		"fragment_range": {"label": "Fragment reach", "suffix": "", "min": 0, "max": 600, "step": 1},
		"fragment_multiplier": {"label": "Fragment damage / hit damage", "suffix": "", "min": 0, "max": 10, "step": 0.01},
		"curse_limit": {"label": "Maximum curse stacks", "suffix": "", "min": 0, "max": 100, "step": 1, "integer": true},
		"curse_multiplier": {"label": "Bonus damage per curse stack", "suffix": "", "min": 0, "max": 10, "step": 0.01},
		"arc_range": {"label": "Chain lightning reach", "suffix": "", "min": 0, "max": 600, "step": 1},
		"arc_multiplier": {"label": "Chain damage / hit damage", "suffix": "", "min": 0, "max": 10, "step": 0.01},
		"seal_hits": {"label": "Hits per seal", "suffix": "", "min": 1, "max": 100, "step": 1, "integer": true},
		"seal_damage": {"label": "Seal bonus / hit damage", "suffix": "", "min": 0, "max": 20, "step": 0.1},
		"stun_duration": {"label": "Stun duration (s)", "suffix": "", "min": 0, "max": 60, "step": 0.1},
		"stun_immunity": {"label": "Stun immunity (s)", "suffix": "", "min": 0, "max": 60, "step": 0.1},
		"damage": {"label": "Damage per hit", "suffix": "", "min": 0.1, "max": 100000.0, "step": 0.1},
		"period": {"label": "Attack interval", "suffix": " s", "min": 0.1, "max": 120.0, "step": 0.01},
		"range": {"label": "Reach", "suffix": " units", "min": 10.0, "max": 600.0, "step": 1.0},
		"cost": {"label": "Build / upgrade cost", "suffix": " gold", "min": 1.0, "max": 100000.0, "step": 1.0},
		"splash": {"label": "Blast radius", "suffix": " units", "min": 0.0, "max": 300.0, "step": 1.0}
	}
}
