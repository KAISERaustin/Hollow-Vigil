extends "res://scripts/content/nodes/content_node.gd"

## Launched abilities retain their defaults even if the owner changes form.
func resolve(tower_stats: Dictionary) -> Dictionary:
	var result := attributes()
	result.merge(tower_stats, true)
	return result

# Capture component configuration at launch, separate from live enemy state.
func impact_effects(stats: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in rule("components", []):
		var config := resolve(stats).merged(entry.config, true)
		config.status_id = id + "/" + entry.slot
		config.ability = id.trim_prefix("ability/")
		config.component_slot = entry.slot
		config.component = entry.component
		config.component_config = entry.config.duplicate(true)
		result.append({"attribute": entry.component, "config": config})
	return result

func owns_effect(config: Dictionary) -> bool:
	for entry in rule("components", []):
		if entry.slot == config.get("component_slot") and entry.component == config.get("component") and entry.config == config.get("component_config"):
			return true
	return false
