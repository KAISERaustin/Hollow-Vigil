extends "res://scripts/content/nodes/content_node.gd"

## Launched abilities retain their defaults even if the owner changes form.
func resolve(tower_stats: Dictionary) -> Dictionary:
	var result := attributes()
	result.merge(tower_stats, true)
	return result
