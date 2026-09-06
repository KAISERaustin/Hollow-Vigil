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
var offline_award := 0.0
var suspended := false
var save_path := "user://vigil.save"
var tuning: Dictionary:
	get: return data.settings.get("developer_balance", {})

func _init(seed_value: int = 0) -> void:
	rng.randomize()
	var world_seed := seed_value if seed_value != 0 else int(rng.randi())
	data = {
		"version": Balance.VERSION, "sequence": 0, "seed": world_seed,
		"balance": Balance.STARTING_GOLD, "reserve": 0.0, "lifetime_earnings": 0.0, "kills": 0.0, "escapes": 0.0,
		"regions": {"0,0": VigilWorld.make_region("0,0", "", world_seed)}, "towers": {}, "castles": {},
		"next_tower": 1, "automation": false, "first_property_required": true, "last_accounted": Time.get_unix_time_from_system(),
		"active_seconds": 0.0, "settings": {"low_power": false},
		"camera": [0.0, 0.0, 1.0]
	}
	economy = VigilEconomy.new(data)
	combat = VigilCombat.new(data, economy, paths)
	refresh_paths()

func refresh_paths() -> void:
	combat.rebuild_routes()
	terrain_revision += 1

func set_balance_stat(category: String, kind: String, stat: String, value: float) -> bool:
	var candidate := tuning.duplicate(true)
	if not candidate.has(category):
		candidate[category] = {}
	if not candidate[category].has(kind):
		candidate[category][kind] = {}
	candidate[category][kind][stat] = value
	if not Balance.valid_tuning(candidate):
		return false
	# Store only differences so future defaults remain the source of truth.
	if is_equal_approx(value, Balance.definitions(category)[kind][stat]):
		candidate[category][kind].erase(stat)
		if candidate[category][kind].is_empty():
			candidate[category].erase(kind)
		if candidate[category].is_empty():
			candidate.erase(category)
	return apply_balance(candidate)

func reset_developer_balance(category: String = "", kind: String = "") -> bool:
	var candidate := tuning.duplicate(true)
	if category == "":
		candidate.clear()
	elif candidate.has(category):
		candidate[category].erase(kind)
		if candidate[category].is_empty():
			candidate.erase(category)
	return apply_balance(candidate)

func apply_balance(candidate: Dictionary) -> bool:
	if not Balance.valid_tuning(candidate):
		return false
	if candidate == tuning:
		return true
	var previous := tuning
	data.settings.developer_balance = candidate.duplicate(true)
	# Preserve damage already taken and progress toward the next shot.
	for enemy in combat.enemies:
		if enemy.dead:
			continue
		var boss: bool = enemy.get("boss", false)
		var category := "bosses" if boss else "enemies"
		var health := Balance.tuned_value(category, enemy.kind, "hp", tuning)
		if boss:
			combat.Bosses.apply_balance(enemy, previous, tuning)
		else:
			health *= combat.rift_health_multiplier(enemy)
		enemy.hp = health * clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)
		enemy.max_hp = health
	for tower in data.towers.values():
		var before := Balance.tower_stats(tower, previous)
		var after := Balance.tower_stats(tower, tuning)
		tower.cooldown = after.period * clampf(tower.cooldown / before.period, 0.0, 1.0)
	# Relearn production under this balance; already earned gold stays owned.
	for region in data.regions.values():
		region.history.clear()
		region.history_time = 0.0
	combat.income_events.clear()
	return true

func expand(id: String) -> bool:
	var options := VigilWorld.frontier(data.regions, int(data.seed))
	if not options.has(id) or not economy.spend(Balance.expansion_cost(data.regions.size())):
		return false
	data.regions[id] = VigilWorld.make_region(id, options[id], data.seed)
	data.first_property_required = false
	economy.sound_requested.emit("menu_expand", Vector2.INF)
	# A new neighbor can add an equal route or shorten an older rift's route.
	combat.rebuild_routes()
	combat.Bosses.awaken(combat, id)
	combat.Bosses.discover_castles(combat)
	terrain_revision += 1
	return true

func apply_offline(now: float) -> float:
	if not is_finite(now) or now < 0.0:
		return 0.0
	var elapsed := clampf(now - data.last_accounted, 0.0, Balance.MAX_OFFLINE_SECONDS)
	# Keep a high-water timestamp through backward clock changes.
	data.last_accounted = maxf(now, data.last_accounted)
	var total := 0.0
	var rebuilding := {}
	for tower in data.towers.values():
		var remaining: float = tower.get("rebuild_remaining", 0.0)
		if remaining > 0.0:
			rebuilding[tower.id] = minf(elapsed, remaining)
			tower.rebuild_remaining = maxf(0.0, remaining - elapsed)
	if elapsed < 2.0:
		return total
	for r in data.regions.values():
		for id in r.history:
			var earning_seconds: float = elapsed - rebuilding.get(id, 0.0)
			var amount: float = r.history[id] / maxf(Balance.MIN_PRODUCTION_SAMPLE, r.history_time) * Balance.OFFLINE_FACTOR * earning_seconds
			economy.credit(id, amount)
			total += amount
	# Lifetime kills counts only actual simulated defeats, never estimated offline kills.
	if data.automation:
		economy.collect()
	offline_award = total
	return total

func snapshot(now: float = -1.0) -> Dictionary:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	data.last_accounted = maxf(data.last_accounted, now)
	var result := data.duplicate(true)
	combat.Bosses.capture(combat, result.regions, result.get("castles", {}))
	return result

func save(now: float = -1.0) -> bool:
	# Preserve unrecognized/corrupt snapshots until the player explicitly resets.
	if save_blocked:
		return false
	data.sequence += 1
	var ok := storage.write(save_path, snapshot(now))
	save_error = storage.last_error
	return ok

func reset_progress() -> bool:
	var fresh := VigilState.new()
	fresh.save_path = save_path
	# Sound is a player preference, independent of progression.
	if data.settings.has("audio"):
		fresh.data.settings.audio = data.settings.audio.duplicate(true)
	# Recovery chooses the highest sequence, so supersede every saved candidate.
	fresh.data.sequence = data.sequence
	for suffix in ["", ".tmp", ".bak"]:
		var candidate := storage.read_candidate(save_path + suffix)
		if not candidate.is_empty():
			fresh.data.sequence = maxf(fresh.data.sequence, candidate.sequence)
	if not fresh.save():
		save_error = fresh.save_error
		return false
	data = fresh.data
	economy = fresh.economy
	paths = fresh.paths
	terrain_revision += 1
	combat = fresh.combat
	offline_award = 0.0
	suspended = false
	save_blocked = false
	# Replace the recovery copy too; even a damaged primary must start fresh.
	if not save():
		# The reset is committed. Remove the old backup if its replacement failed.
		var backup_path := save_path + ".bak"
		if FileAccess.file_exists(backup_path):
			if DirAccess.remove_absolute(backup_path) != OK:
				save_error = "Progress reset, but the old recovery save could not be removed."
	return true

func load_save(now: float = -1.0) -> bool:
	var best := {}
	var found_files := false
	for suffix in ["", ".tmp", ".bak"]:
		found_files = found_files or FileAccess.file_exists(save_path + suffix)
		var candidate := storage.read_candidate(save_path + suffix)
		if not candidate.is_empty() and (best.is_empty() or candidate.sequence > best.sequence):
			best = candidate
	if best.is_empty():
		save_blocked = found_files
		save_error = "Your save could not be read. Existing files are preserved. Restore a recovery copy or use Reset progress to start over." if found_files else ""
		return false
	save_blocked = false
	data = best
	data.castles = data.get("castles", {})
	economy = VigilEconomy.new(data)
	combat = VigilCombat.new(data, economy, paths)
	# JSON numbers are floats; convert discrete counters before using them as IDs.
	data.next_tower = int(data.next_tower)
	data.seed = int(data.seed)
	for r in data.regions.values():
		r.style = r.get("style", "forest")
		# Old saves have no live enemies; rebuild their routes with the new curves.
		r.road_version = int(r.get("road_version", 2))
		r.side = int(r.side)
		r.traffic = int(r.traffic)
	for t in data.towers.values():
		t.target_mode = t.get("target_mode", "first")
		t.pad = int(t.pad)
		t.level = int(t.level)
		t.rebuild_remaining = float(t.get("rebuild_remaining", 0.0))
	refresh_paths()
	combat.enemies.clear()
	combat.Bosses.restore(combat)
	apply_offline(Time.get_unix_time_from_system() if now < 0.0 else now)
	# Commit reward and its timestamp together before the player can collect it.
	save(now)
	return true
