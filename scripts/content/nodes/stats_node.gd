extends "res://scripts/content/nodes/content_node.gd"

## Shared stat ownership for Entity, Tower, Enemy and Boss. Values are save-local.
const Stats = preload("res://scripts/content/catalogs/stats.gd")

func definition(tuning: Dictionary = {}) -> Dictionary:
	var category: String = rule("tuning_category", "")
	var kind: String = rule("kind", "")
	if category in Stats.CATEGORIES and Stats.Frozen.VALUES[category].has(kind):
		return Stats.resolve(category, kind, attributes(), tuning)
	return super.definition(tuning)
