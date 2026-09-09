extends RefCounted

## Executes immutable attachments with state and overrides owned by one combat.
static func definition(combat, tower: Dictionary):
	if combat.tower_overrides.has(tower.id):
		return combat.tower_overrides[tower.id]
	combat.configuration.synchronize(combat.tuning, combat.data.relics)
	return combat.configuration.component_node(Balance.tier_key(tower.kind, tower.level, tower.get("branch", "")))

static func apply_auras(combat, recipient: Dictionary, stats: Dictionary) -> void:
	stats.damage *= 1.0 + aura_bonus(combat, recipient) / 100.0

## Shared live query for gameplay and recipient presentation; never changes stats.
static func aura_bonus(combat, recipient: Dictionary) -> float:
	var bonus := 0.0
	var position := VigilWorld.pad_position(recipient.region, recipient.pad)
	for source in combat.data.towers.values():
		if source.id == recipient.id or source.get("rebuild_remaining", 0.0) > 0.0: continue
		var node = definition(combat, source)
		if node == null: continue
		for entry in node.rule("components", []):
			if not entry.component.has_method("aura_bonus"): continue
			# Read unmodified source stats so mutually supporting towers cannot recurse.
			var config: Dictionary = combat.configuration.tower_stats(source).merged(entry.config, true)
			bonus = maxf(bonus, entry.component.aura_bonus(VigilWorld.pad_position(source.region, source.pad), position, config))
	return bonus

static func sync(combat) -> void:
	for id in combat.tower_component_state.keys():
		if not combat.data.towers.has(id): clear(combat, id)
	for tower in combat.data.towers.values(): ensure(combat, tower)

static func ensure(combat, tower: Dictionary) -> Dictionary:
	var node = definition(combat, tower)
	var signature := "%s:%s:%s:%s:%s" % [tower.kind, tower.level, tower.get("branch", ""), tower.region, tower.pad]
	var old: Dictionary = combat.tower_component_state.get(tower.id, {})
	if old.get("signature", "") == signature and old.get("node") == node:
		return old
	clear(combat, tower.id, old.get("signature", "") == signature and old.get("node") != node)
	combat.component_serial += 1
	var record := {"signature": signature, "node": node, "epoch": combat.component_serial, "states": {}, "entries": node.rule("components", [])}
	combat.tower_component_state[tower.id] = record
	return record

static func set_definition(combat, id: String, node) -> bool:
	if not combat.data.towers.has(id) or (node != null and not node.is_a("tower")): return false
	clear(combat, id)
	if node == null: combat.tower_overrides.erase(id)
	else: combat.tower_overrides[id] = node
	ensure(combat, combat.data.towers[id])
	return true

static func clear(combat, id: String, changed_configuration: bool = false) -> void:
	combat.tower_component_state.erase(id)
	combat.line_projectiles = combat.line_projectiles.filter(func(p): return p.tower_id != id)
	combat.traps = combat.traps.filter(func(p): return p.tower_id != id)
	if changed_configuration: combat.pending_shots = combat.pending_shots.filter(func(p): return p.tower_id != id)
	combat.burning_ground = combat.burning_ground.filter(func(p): return p.tower_id != id)
	combat.curses.erase(id)
	combat.effect_fields = combat.effect_fields.filter(func(p): return p.tower_id != id or not p.config.has("direct_assignment"))
	for enemy in combat.enemies:
		if enemy.get("slow_owner", "") == id:
			enemy.erase("slow_until")
			enemy.erase("slow_owner")
		if enemy.get("stun_owner", "") == id:
			enemy.erase("stun_until")
			enemy.erase("stun_owner")
		enemy.get("charges", {}).erase(id)
		var statuses: Dictionary = enemy.get("gear_status", {})
		var removed_root: bool = enemy.get("direct_root_owner", "") == id
		if removed_root: enemy.erase("direct_root_owner")
		for key in statuses.keys():
			if statuses[key].owner == id and statuses[key].has("tower_epoch"):
				removed_root = removed_root or statuses[key].type == "root"
				statuses.erase(key)
		if removed_root:
			enemy.root_until = 0.0
			for status in statuses.values():
				if status.type == "root": enemy.root_until = maxf(enemy.root_until, status.until)
	if not combat.data.towers.has(id): combat.tower_overrides.erase(id)

static func prepare_attributes(combat, tower: Dictionary, target: Dictionary, stats: Dictionary) -> Dictionary:
	var record := ensure(combat, tower)
	var result := stats.duplicate(true)
	for assignment in preload("res://scripts/gameplay/combat/stat_composition.gd").direct_gear(tower, combat.tuning, combat.data.relics):
		var key: String = "gear_" + assignment.kind
		var progress: Dictionary = record.states.get(key, assignment.node.make_record())
		var prepared: Dictionary = assignment.node.prepare(progress, target.id, combat.simulation_time, result)
		record.states[key] = progress
		for list in ["gear_effects", "gear_echoes", "gear_forks"]:
			var combined: Array = result.get(list, []).duplicate()
			for effect in prepared.get(list, []):
				if list == "gear_effects":
					effect.config.direct_assignment = assignment.kind
					effect.config.tower_epoch = record.epoch
				combined.append(effect)
			prepared[list] = combined
		prepared.relic_damage_multiplier *= result.get("relic_damage_multiplier", 1.0)
		prepared.relic_radius = maxf(prepared.relic_radius, result.get("relic_radius", 0.0))
		prepared.relic_pierce = prepared.relic_pierce or result.get("relic_pierce", false)
		result = prepared
	result.gear_epoch = combat.relic_epochs.get(tower.id, 0)
	return result

static func credited_kill(combat, tower_id: String) -> void:
	if not combat.data.towers.has(tower_id): return
	var tower: Dictionary = combat.data.towers[tower_id]
	var record := ensure(combat, tower)
	for assignment in preload("res://scripts/gameplay/combat/stat_composition.gd").direct_gear(tower, combat.tuning, combat.data.relics):
		var key: String = "gear_" + assignment.kind
		var progress: Dictionary = record.states.get(key, assignment.node.make_record())
		assignment.node.credited_kill(progress, combat.simulation_time)
		record.states[key] = progress

static func reset(combat) -> void:
	for id in combat.tower_component_state.keys(): clear(combat, id)
	combat.line_projectiles.clear()
	combat.traps.clear()

static func snapshot(combat, tower: Dictionary, stats: Dictionary) -> Array:
	var record := ensure(combat, tower)
	if record.get("snapshot_stats") == stats:
		return record.snapshot
	var result := []
	for entry in record.entries:
		var config := stats.merged(entry.config, true)
		config.make_read_only()
		var snapshot_entry := {"component": entry.component, "slot": entry.slot, "config": config, "epoch": record.epoch}
		snapshot_entry.make_read_only()
		result.append(snapshot_entry)
	result.make_read_only()
	record.snapshot_stats = stats.duplicate(true)
	record.snapshot = result
	return result

static func valid(combat, id: String, epoch: int) -> bool:
	return combat.data.towers.has(id) and combat.tower_component_state.get(id, {}).get("epoch", -1) == epoch

static func attack_entry(combat, tower: Dictionary, stats: Dictionary) -> Dictionary:
	for entry in snapshot(combat, tower, stats):
		if entry.component.has_method("attack"): return entry
	return {}

static func before_hit(combat, shot: Dictionary, enemy: Dictionary) -> void:
	for entry in shot.get("tower_effects", []):
		if valid(combat, shot.tower_id, entry.epoch) and entry.component.has_method("before_hit"):
			entry.component.before_hit(combat, shot, enemy, entry.config)

static func after_hit(combat, shot: Dictionary, enemy: Dictionary) -> void:
	if enemy.dead: return
	for entry in shot.get("tower_effects", []):
		if valid(combat, shot.tower_id, entry.epoch) and entry.component.has_method("after_hit"):
			entry.component.after_hit(combat, shot, enemy, entry.config.merged({"tower_epoch": entry.epoch}))

static func killed(combat, enemy: Dictionary) -> void:
	# The status carries its source capability, so death propagation is reusable.
	for status in enemy.get("gear_status", {}).values().duplicate():
		if status.has("tower_epoch") and status.until > combat.simulation_time and valid(combat, status.owner, status.tower_epoch):
			if status.component.has_method("marked_death"): status.component.marked_death(combat, enemy, status)

static func advance(combat, delta: float) -> void:
	preload("res://scripts/gameplay/combat/line_projectiles.gd").advance(combat, delta)
	preload("res://scripts/gameplay/combat/road_traps.gd").advance(combat)
