extends RefCounted

## Resolved configuration belongs to one combat. Mutable effect progress remains
## on its existing enemy/tower owners, never on shared definitions.
var tuning_snapshot: Dictionary = {}
var inventory_snapshot: Dictionary = {}
var definitions: Dictionary = {}
var towers: Dictionary = {}
var revision := 0

func synchronize(tuning: Dictionary, inventory: Dictionary) -> void:
	# Value comparison also catches in-place editor and Campaign rule changes.
	if tuning != tuning_snapshot:
		tuning_snapshot = tuning.duplicate(true)
		definitions.clear()
		towers.clear()
		revision += 1
	if inventory != inventory_snapshot:
		inventory_snapshot = inventory.duplicate(true)
		towers.clear()
		revision += 1

func definition(category: String, kind: String) -> Dictionary:
	var key := category + "/" + kind
	if not definitions.has(key):
		var resolved := Balance.definition(category, kind, tuning_snapshot)
		resolved.make_read_only()
		definitions[key] = resolved
	return definitions[key]

func tower_stats(tower: Dictionary) -> Dictionary:
	var signature := [tower.kind, tower.level, tower.get("branch", ""), tower.get("relic", "")]
	var cached: Dictionary = towers.get(tower.id, {})
	if cached.get("signature") != signature:
		var stats := Balance.tower_stats(tower, tuning_snapshot, inventory_snapshot)
		stats.make_read_only()
		cached = {"signature": signature, "stats": stats}
		towers[tower.id] = cached
	return cached.stats

func prune(live_towers: Dictionary) -> void:
	for id in towers.keys():
		if not live_towers.has(id): towers.erase(id)
