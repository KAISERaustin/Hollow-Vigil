extends "res://scripts/content/nodes/content_node.gd"

const ContentNode = preload("res://scripts/content/nodes/content_node.gd")

func can_equip_on(target: ContentNode) -> bool:
	return target != null and target.is_a(_rules.get("equipped_on", "tower")) and _rules.slot in target.rule("equipment_slots", [])

func modify_stats(stats: Dictionary, tuning: Dictionary = {}) -> Dictionary:
	var result := stats.duplicate()
	for entry in rule("components", []):
		entry.component.modify_stats(result, definition(tuning).merged(entry.config, true))
	return result

func credited_kill(progress: Dictionary, now: float, tuning: Dictionary = {}) -> void:
	var states := sync_components(progress)
	for entry in rule("components", []):
		entry.component.credited_kill(states[entry.slot].state, now, definition(tuning).merged(entry.config, true))

func prepare(progress: Dictionary, target_id: int, now: float, stats: Dictionary, tuning: Dictionary = {}) -> Dictionary:
	var result := stats.duplicate()
	result.merge({"gear_effects": [], "gear_echoes": [], "gear_forks": [], "relic_damage_multiplier": 1.0, "relic_radius": 0.0, "relic_root": false, "relic_echo": false, "relic_pierce": false}, true)
	progress.attacks += 1
	var states := sync_components(progress)
	for entry in rule("components", []):
		var state: Dictionary = states[entry.slot].state
		state.attacks = int(state.get("attacks", 0)) + 1
		var context := {"attacks": state.attacks, "target": target_id, "previous_target": state.get("target", -1), "now": now, "last": state.get("last", -100.0)}
		var config := definition(tuning).merged(entry.config, true)
		config.gear_slot = entry.slot
		config.gear_component = entry.component
		config.gear_config = entry.config.duplicate(true)
		entry.component.prepare(state, context, result, config)
		state.target = target_id
		state.last = now
	progress.target = target_id
	progress.last = now
	return result

func owns_effect(config: Dictionary) -> bool:
	for entry in rule("components", []):
		if entry.slot == config.get("gear_slot") and entry.component == config.get("gear_component") and entry.config == config.get("gear_config"):
			return true
	return false

func sync_components(progress: Dictionary) -> Dictionary:
	var states: Dictionary = progress.get("components", {})
	var slots := []
	for entry in rule("components", []):
		slots.append(entry.slot)
		var previous: Dictionary = states.get(entry.slot, {})
		if previous.get("definition") != entry.component or previous.get("config") != entry.config:
			states[entry.slot] = {"definition": entry.component, "config": entry.config.duplicate(true), "state": entry.component.make_record()}
	for slot in states.keys():
		if slot not in slots:
			states.erase(slot)
	progress.components = states
	return states

func retune(progress: Dictionary, now: float, previous: Dictionary, tuning: Dictionary) -> void:
	var states := sync_components(progress)
	for entry in rule("components", []):
		entry.component.retune(states[entry.slot].state, now, definition(previous).merged(entry.config, true), definition(tuning).merged(entry.config, true))
