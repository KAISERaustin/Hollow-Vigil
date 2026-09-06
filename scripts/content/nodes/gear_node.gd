extends "res://scripts/content/nodes/content_node.gd"

const ContentNode = preload("res://scripts/content/nodes/content_node.gd")

func can_equip_on(target: ContentNode) -> bool:
	return target != null and target.is_a(_rules.get("equipped_on", "tower")) and _rules.slot in target.rule("equipment_slots", [])

func prepare(progress: Dictionary, target_id: int, now: float, stats: Dictionary, tuning: Dictionary = {}) -> Dictionary:
	var result := stats.duplicate()
	result.merge({"gear_effects": [], "gear_echoes": [], "gear_forks": [], "relic_damage_multiplier": 1.0, "relic_radius": 0.0, "relic_root": false, "relic_echo": false, "relic_pierce": false}, true)
	progress.attacks += 1
	var context := {"attacks": progress.attacks, "target": target_id, "previous_target": progress.target, "now": now, "last": progress.last}
	var states := sync_components(progress)
	for entry in rule("components", []):
		entry.component.prepare(states[entry.slot].state, context, result, definition(tuning).merged(entry.config, true))
	progress.target = target_id
	progress.last = now
	return result

func sync_components(progress: Dictionary) -> Dictionary:
	var states: Dictionary = progress.get("components", {})
	var slots := []
	for entry in rule("components", []):
		slots.append(entry.slot)
		if states.get(entry.slot, {}).get("definition") != entry.component:
			states[entry.slot] = {"definition": entry.component, "state": entry.component.make_record()}
	for slot in states.keys():
		if slot not in slots:
			states.erase(slot)
	progress.components = states
	return states

func retune(progress: Dictionary, now: float, previous: Dictionary, tuning: Dictionary) -> void:
	var states := sync_components(progress)
	for entry in rule("components", []):
		entry.component.retune(states[entry.slot].state, now, definition(previous).merged(entry.config, true), definition(tuning).merged(entry.config, true))
