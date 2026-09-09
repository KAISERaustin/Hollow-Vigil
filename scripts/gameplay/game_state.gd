class_name VigilState
extends RefCounted

var data: Dictionary
var economy: VigilEconomy
var combat: VigilCombat
var storage := VigilSaveStore.new()
var paths: Dictionary = {}
var terrain_revision := 0
var rng := RandomNumberGenerator.new()
var save_error := ""
var save_blocked := false
var suspended := false
var save_path := "user://vigil.save"
var tuning: Dictionary:
	get: return data.settings.get("developer_balance", {})

func is_creative() -> bool:
	# Saves from before modes existed retain their editor access.
	var mode := Balance.Content.catalog().get_node("level/campaign/" + data.get("mode", "creative"))
	return mode != null and mode.rule("developer_controls", false)

func add_developer_gold() -> bool:
	if not is_creative():
		return false
	data.balance = minf(Balance.MAX_MONEY, data.balance + 1_000_000.0)
	return true

func _init(seed_value: int = 0, play_mode: String = "creative", starting_rules: Dictionary = {}) -> void:
	rng.randomize()
	var world_seed := seed_value if seed_value != 0 else int(rng.randi())
	data = {
		"version": Balance.VERSION, "sequence": 0, "seed": world_seed, "mode": play_mode,
		"balance": Balance.STARTING_GOLD, "reserve": 0.0, "lifetime_earnings": 0.0, "kills": 0.0, "escapes": 0.0,
		"regions": {"0,0": VigilWorld.make_region("0,0", "", world_seed)}, "towers": {}, "castles": {}, "relics": {},
		"next_tower": 1, "automation": true, "last_accounted": Time.get_unix_time_from_system(),
		"active_seconds": 0.0, "settings": {"low_power": false},
		"camera": [0.0, 0.0, 1.0]
	}
	if not starting_rules.is_empty() and Balance.valid_tuning(starting_rules):
		data.settings.developer_balance = starting_rules.duplicate(true)
		data.balance = Balance.tuned_value("session", "start", "starting_gold", tuning)
	economy = VigilEconomy.new(data)
	combat = VigilCombat.new(data, economy, paths)
	refresh_paths()

func refresh_paths() -> void:
	combat.rebuild_routes()
	terrain_revision += 1

# Target changes share validation and lock invalidation.
func set_tower_target(id: String, mode: String) -> bool:
	if not data.towers.has(id) or not Balance.TARGET_MODES.has(mode):
		return false
	if data.towers[id].get("target_mode", "first") != mode:
		data.towers[id].target_mode = mode
		combat.target_locks.erase(id)
	return true

func set_balance_stat(category: String, kind: String, stat: String, value: float) -> bool:
	if category in Balance.Stats.CATEGORIES:
		return apply_balance(Balance.Stats.edit(tuning, category, kind, stat, value))
	var candidate := tuning.duplicate(true)
	if not candidate.has(category):
		candidate[category] = {}
	if not candidate[category].has(kind):
		candidate[category][kind] = {}
	candidate[category][kind][stat] = value
	if not is_creative() or not Balance.valid_tuning(candidate):
		return false
	# Store only differences so future defaults remain the source of truth.
	if is_equal_approx(value, Balance.definitions(category)[kind][stat]):
		candidate[category][kind].erase(stat)
		if candidate[category][kind].is_empty():
			candidate[category].erase(kind)
		if candidate[category].is_empty():
			candidate.erase(category)
	return apply_balance(candidate)

# The tier editor writes absolute values. Keep legacy base-scaling saves readable,
# but freeze sibling tiers before changing tier one through the new editor.
func set_tower_tier_stat(key: String, stat: String, value: float) -> bool:
	return set_balance_stat("towers", key, stat, value)

func _legacy_set_tower_tier_stat(key: String, stat: String, value: float) -> bool:
	var candidate := tuning.duplicate(true)
	if not candidate.has("towers"):
		candidate.towers = {}
	if Balance.TOWERS.has(key):
		for level in range(2, 5):
			var branches: Array = Balance.BRANCHES[key].keys() if level == 4 else [""]
			for branch in branches:
				var sibling := Balance.tier_key(key, level, branch)
				if not candidate.towers.has(sibling):
					candidate.towers[sibling] = {}
				var current := Balance.stats(key, level, tuning, branch)
				candidate.towers[sibling][stat] = Balance.upgrade_cost({"kind": key, "level": level - 1}, tuning, branch) if stat == "cost" else float(current.get(stat, value))
	if not candidate.towers.has(key):
		candidate.towers[key] = {}
	candidate.towers[key][stat] = value
	return apply_balance(candidate)

func reset_developer_balance(category: String = "", kind: String = "") -> bool:
	if category in Balance.Stats.CATEGORIES: return apply_balance(Balance.Stats.reset(tuning, category, kind))
	var candidate := tuning.duplicate(true)
	if category == "":
		candidate.clear()
	elif candidate.has(category):
		candidate[category].erase(kind)
		if candidate[category].is_empty():
			candidate.erase(category)
	return apply_balance(candidate)

func apply_balance(candidate: Dictionary) -> bool:
	if not is_creative() or not Balance.valid_tuning(candidate):
		return false
	if candidate == tuning:
		return true
	var previous := tuning
	data.settings.developer_balance = candidate.duplicate(true)
	combat.configuration.synchronize(tuning, data.relics)
	var previous_gameplay := previous.duplicate(true)
	var next_gameplay := candidate.duplicate(true)
	previous_gameplay.erase("session")
	next_gameplay.erase("session")
	if previous_gameplay == next_gameplay:
		return true # New-session resources do not change current production.
	combat.Relics.apply_balance(combat, previous, tuning)
	# Preserve remaining health percentage and progress toward the next shot.
	for enemy in combat.enemies:
		if enemy.dead:
			continue
		var boss: bool = enemy.get("boss", false)
		var category := "bosses" if boss else "enemies"
		var health := Balance.tuned_value(category, enemy.kind, "hp", tuning)
		combat.EnemyCapabilities.retune(enemy, previous, tuning)
		if not boss:
			health *= combat.rift_health_multiplier(enemy)
		enemy.hp = health * clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)
		enemy.max_hp = health
	for tower in data.towers.values():
		var before := Balance.tower_stats(tower, previous, data.relics)
		var after := Balance.tower_stats(tower, tuning, data.relics)
		tower.cooldown = after.period * clampf(tower.cooldown / before.period, 0.0, 1.0)
	combat.TowerComponents.sync(combat)
	# Relearn production under this balance; already earned gold stays owned.
	for region in data.regions.values():
		region.history.clear()
		region.history_time = 0.0
	combat.income_events.clear()
	return true

func snapshot(now: float = -1.0) -> Dictionary:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	data.last_accounted = maxf(data.last_accounted, now)
	var result := data.duplicate(true)
	return result
