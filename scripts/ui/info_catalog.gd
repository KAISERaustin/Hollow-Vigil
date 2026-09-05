extends RefCounted

# Definitions are shared with combat and purchases. Adding a definition includes it
# automatically; add a stat descriptor here to display a new mechanic in every card.
const SECTIONS := {
	"towers": {
		"title": "Towers", "definitions": Balance.TOWERS,
		"intro": "Level 1 stats. Upgrades improve damage, attack speed and reach.",
		"hint": "To build, tap an empty stone socket on the map.",
		"stats": [
			{"key": "damage", "label": "Damage per hit"},
			{"key": "period", "label": "Attack interval", "suffix": " s"},
			{"key": "range", "label": "Reach", "suffix": " units"},
			{"key": "cost", "label": "Build cost", "suffix": " gold"},
			{"key": "splash", "label": "Blast radius", "suffix": " units", "positive_only": true}
		]
	},
	"enemies": {
		"title": "Enemies", "definitions": Balance.ENEMIES,
		"intro": "All enemy types, including those you can attune through Rifts.",
		"hint": "Defeats earn gold. Enemies that reach the core escape harmlessly.",
		"stats": [
			{"key": "hp", "label": "Health", "suffix": " HP"},
			{"key": "speed", "label": "Move speed", "suffix": " units/s"},
			{"key": "payout", "label": "Defeat reward", "suffix": " gold"}
		]
	}
}

static func entries(category: String) -> Array[Dictionary]:
	var section: Dictionary = SECTIONS[category]
	return build_entries(section.definitions, section.stats)

static func build_entries(definitions: Dictionary, stat_fields: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in definitions:
		var definition: Dictionary = definitions[id]
		var stats: Array[Dictionary] = []
		for field in stat_fields:
			if not definition.has(field.key):
				continue
			var value: float = definition[field.key]
			if field.get("positive_only", false) and value <= 0.0:
				continue
			stats.append({"label": field.label, "value": String.num(value, 2).trim_suffix(".0") + field.get("suffix", "")})
		result.append({
			"id": id, "name": definition.name, "role": definition.get("role", ""),
			"description": definition.get("description", ""),
			"color": definition.get("color", "d0b17d"), "stats": stats
		})
	return result
