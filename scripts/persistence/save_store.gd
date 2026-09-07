class_name VigilSaveStore
extends RefCounted

var last_error := ""
const LEGACY_MAX_TOWER_LEVEL := 10000
const LEGACY_TOWER_COSTS := {"rapid": 60.0, "splash": 120.0, "heavy": 160.0}

func delete_files(path: String) -> bool:
	# Remove fallback candidates first so a deleted slot cannot recover itself.
	for suffix in [".tmp", ".bak", ".cloud-outbox", ""]:
		var candidate: String = path + suffix
		if FileAccess.file_exists(candidate) and DirAccess.remove_absolute(candidate) != OK:
			last_error = "Couldn't delete this saved game completely. Please retry."
			return false
	last_error = ""
	return true

func write(path: String, data: Dictionary) -> bool:
	# Validate before opening .tmp: it may be the only recoverable snapshot.
	if not valid_data(data):
		last_error = "Couldn't save invalid progress. Your previous save is safe."
		return false
	var payload := JSON.stringify(migrate_portal_unlocks(data), "", true, true)
	var envelope := JSON.stringify({"payload": payload, "checksum": payload.sha256_text()})
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		last_error = "Couldn't save your progress. Keep the game open while we try again."
		return false
	f.store_string(envelope)
	f.flush()
	f.close()
	if read_candidate(path + ".tmp").is_empty():
		last_error = "Couldn't update your save. Your previous save is safe."
		return false
	if FileAccess.file_exists(path) and not read_candidate(path).is_empty():
		var backup_error := DirAccess.rename_absolute(path, path + ".bak")
		if backup_error != OK:
			last_error = "Couldn't update your save. A recovery copy is available."
			return false
	var err := DirAccess.rename_absolute(path + ".tmp", path)
	last_error = "" if err == OK else "Saving was interrupted. A recovery copy is available."
	return err == OK

func read_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var envelope = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary:
		return {}
	if parsed.get("version") == 1:
		if not _valid_data(parsed, 1, LEGACY_MAX_TOWER_LEVEL):
			return {}
		parsed = _migrate_v1(parsed)
	return migrate_portal_unlocks(parsed) if valid_data(parsed) else {}

func migrate_portal_unlocks(data: Dictionary) -> Dictionary:
	# Called only after validation. Keep compatible purchases, refund retired ones
	# at their original price, and remove them so repeated restores cannot refund twice.
	var migrated := data.duplicate(true)
	# Other validated store subtypes, such as campaign progress, have no regions.
	for region in migrated.get("regions", {}).values():
		var portal := Balance.Content.portal(region.get("style", "forest"))
		var refund := portal.retired_unlock_refund(region.unlocks)
		migrated.balance = minf(Balance.MAX_MONEY, migrated.balance + refund)
		var costs := portal.unlock_costs()
		region.unlocks = region.unlocks.filter(func(kind): return costs.has(kind))
	return migrated

func _migrate_v1(legacy: Dictionary) -> Dictionary:
	var migrated := legacy.duplicate(true)
	migrated.version = Balance.VERSION
	for tower in migrated.towers.values():
		if tower.level <= 3:
			continue
		var base_cost: float = legacy.settings.get("developer_balance", {}).get("towers", {}).get(tower.kind, {}).get("cost", LEGACY_TOWER_COSTS[tower.kind])
		# Return the full, individually rounded prices paid for levels 4+.
		# These constants deliberately retain the version-one economy.
		for level in range(3, int(tower.level)):
			var refund := ceil(minf(Balance.MAX_MONEY, base_cost * 0.7 * pow(1.55, mini(level - 1, 700))))
			migrated.balance = minf(Balance.MAX_MONEY, migrated.balance + refund)
		tower.level = 3
		tower.cooldown = minf(tower.cooldown, Balance.stats(tower.kind, tower.level, migrated.settings.get("developer_balance", {})).period)
		# Relearn production for capped towers; old high-level income must not
		# continue generating offline gold. Already stored earnings stay owned.
		for region in migrated.regions.values():
			region.history.erase(tower.id)
	return migrated

func valid_data(d: Dictionary) -> bool:
	return _valid_data(d, Balance.VERSION, Balance.MAX_TOWER_LEVEL)

func _valid_data(d: Dictionary, version: int, max_tower_level: int) -> bool:
	for field in ["version", "sequence", "seed", "balance", "reserve", "lifetime_earnings", "kills", "escapes", "regions", "towers", "next_tower", "automation", "last_accounted", "active_seconds", "settings", "camera"]:
		if not d.has(field):
			return false
	if d.has("setup"):
		if not d.setup is Dictionary or not d.setup.get("name") is String or not d.setup.get("description") is String:
			return false
		if d.setup.name.strip_edges().is_empty() or d.setup.name.length() > 80 or d.setup.description.length() > 4000:
			return false
	if d.has("mode") and d.mode not in ["creative", "survival"]:
		return false
	if d.version != version or not d.regions is Dictionary or not d.towers is Dictionary or not d.regions.has("0,0"):
		return false
	for field in ["balance", "reserve", "lifetime_earnings", "kills", "escapes", "last_accounted", "active_seconds"]:
		if not number(d[field]):
			return false
	if not number(d.sequence, 0, 1.0e15, true) or not number(d.seed, 0, 1.0e15, true) or not number(d.next_tower, 1, 1.0e15, true):
		return false
	if not d.automation is bool or not d.settings is Dictionary or not d.camera is Array or d.camera.size() != 3:
		return false
	if d.has("first_property_required") and not d.first_property_required is bool:
		return false
	if not d.settings.get("low_power") is bool:
		return false
	if d.settings.has("text_scale") and (not number(d.settings.text_scale, 1.0, 1.5) or not d.settings.text_scale in [1.0, 1.25, 1.5]):
		return false
	if d.settings.has("reduced_motion") and not d.settings.reduced_motion is bool:
		return false
	if d.settings.has("audio"):
		if not d.settings.audio is Dictionary:
			return false
		for category in d.settings.audio:
			if category == "muted":
				if not d.settings.audio[category] is bool:
					return false
			elif category not in ["master", "menu", "towers", "enemies", "bosses", "music"] or not number(d.settings.audio[category], 0.0, 1.0):
				return false
	if d.settings.has("developer_balance") and not Balance.valid_tuning(d.settings.developer_balance):
		return false
	# Camera limits depend on the viewport and Creative's unrestricted mode.
	# Persist finite positive zoom; the battlefield enforces current view limits
	# on restore. The old fixed range rejected ordinary camera changes as progress.
	if not number(d.camera[0], -1.0e12, 1.0e12) or not number(d.camera[1], -1.0e12, 1.0e12) or not number(d.camera[2], 0.0, 1.0e12) or d.camera[2] <= 0.0:
		return false
	if d.has("cloud"):
		if not d.cloud is Dictionary or not number(d.cloud.get("revision"), 0, 1.0e15, true) or not d.cloud.get("include_audio") is bool:
			return false
		for field in ["world_id", "player_id"]:
			var identifier: Variant = d.cloud.get(field)
			if not identifier is String or identifier.length() != 36 or identifier.replace("-", "").length() != 32 or not identifier.replace("-", "").is_valid_hex_number():
				return false
	# Validate every region's shape before walking any parent chain.
	for id in d.regions:
		var r = d.regions[id]
		if not valid_coordinate(id) or not r is Dictionary:
			return false
		for field in ["id", "parent", "side", "bend", "traffic", "timer", "unlocks", "history", "history_time"]:
			if not r.has(field):
				return false
		if r.id != id or not r.parent is String or (r.parent != "" and not d.regions.has(r.parent)):
			return false
		if r.has("style") and (not r.style is String or (r.style not in ["forest", "castle_ruin"] and not r.style in VigilWorld.NEW_STYLES)):
			return false
		if r.has("boss") and not valid_boss(r.boss, id, d):
			return false
		if r.has("road_version") and not number(r.road_version, 1, 2, true):
			return false
		if (id == "0,0") != (r.parent == ""):
			return false
		if r.parent != "":
			if not valid_coordinate(r.parent) or Vector2(VigilWorld.coord(id) - VigilWorld.coord(r.parent)).length() != 1.0:
				return false
		if not number(r.side, 0, 3, true) or not number(r.traffic, 0, Balance.MAX_TRAFFIC_LEVEL, true) or not r.bend in [-24.0, 24.0]:
			return false
		if not number(r.timer, -10, 10) or not number(r.history_time, 0, Balance.HISTORY_SECONDS) or not r.history is Dictionary or not r.unlocks is Array:
			return false
		var seen_unlocks := {}
		for kind in r.unlocks:
			if not kind is String or not Balance.Content.portal(r.get("style", "forest")).saved_unlock_costs().has(kind) or seen_unlocks.has(kind):
				return false
			seen_unlocks[kind] = true
		for value in r.history.values():
			if not number(value):
				return false
	# All region shapes are now validated, so road reconstruction is safe.
	if not d.get("castles", {}) is Dictionary:
		return false
	const Areas = preload("res://scripts/world/hidden_areas.gd")
	for id in d.get("castles", {}):
		if not valid_coordinate(id) or not d.castles[id] is Dictionary:
			return false
		var sector := Areas.sector_for(VigilWorld.coord(id))
		var g := Areas.gate(sector, int(d.seed))
		if g.id != id or not d.regions.has(g.neighbor):
			return false
		var boss: Variant = d.castles[id].get("boss")
		if not valid_boss(boss, id, d):
			return false
		if boss.status == "active" and not valid_boss_road(boss, d.regions, int(d.seed)):
			return false
	for r in d.regions.values():
		if r.has("boss") and r.boss.status == "active" and not valid_boss_road(r.boss, d.regions):
			return false
	if not valid_loadout(d, max_tower_level):
		return false
	# Parent links describe purchase history, not enemy routes. Validate them
	# separately now that movement can also use non-parent neighbors.
	var rooted := {"0,0": true}
	for id in d.regions:
		var chain := {}
		var cursor: String = id
		while not rooted.has(cursor):
			if chain.has(cursor):
				return false
			chain[cursor] = true
			cursor = d.regions[cursor].parent
		rooted.merge(chain)
		for tower_id in d.regions[id].history:
			if not d.towers.has(tower_id):
				return false
	return true

func number(value: Variant, minimum: float = 0.0, maximum: float = Balance.MAX_MONEY, integer: bool = false) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(value) and value >= minimum and value <= maximum and (not integer or value == floor(value))

static func valid_coordinate(value: Variant) -> bool:
	if not value is String:
		return false
	var parts: PackedStringArray = value.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return false
	return str(int(parts[0])) + "," + str(int(parts[1])) == value and abs(int(parts[0])) < 100000000 and abs(int(parts[1])) < 100000000

func valid_boss(b: Variant, id: String, d: Dictionary) -> bool:
	const Bosses = preload("res://scripts/gameplay/encounters/bosses.gd")
	var castle: bool = d.get("castles", {}).has(id)
	var kind := Bosses.kind_at(id, int(d.seed), d.regions.get(id, {}).get("style", "")) if not castle else Bosses.castle_kind(Bosses.Areas.sector_for(VigilWorld.coord(id)), int(d.seed))
	var legacy := Bosses.legacy_kind_at(id, int(d.seed), castle)
	# Authored/developer terrain edits do not replace an already awakened boss.
	var generated := Bosses.kind_at(id, int(d.seed))
	# Older releases spawned biome bosses on starter tiles. Spawn eligibility
	# must not invalidate those saved encounters after the starter area expands.
	var saved_biome := Balance.Content.region(d.regions.get(id, {}).get("style", "forest"))
	var starter_kind: String = saved_biome.boss_kind() if not castle and VigilWorld.is_starter(id) and saved_biome != null else ""
	if not b is Dictionary or not b.get("kind") is String or b.kind == "" or b.kind not in [kind, legacy, generated, starter_kind]:
		return false
	if b.get("status") in ["defeated", "escaped"]:
		return true
	if b.get("status") != "active":
		return false
	for field in ["tile", "previous"]:
		if not b.get(field) is String or (not d.regions.has(b[field]) and not (field == "previous" and b[field] == id and d.get("castles", {}).has(id))):
			return false
	if Vector2(VigilWorld.coord(b.tile) - VigilWorld.coord(b.previous)).length() != 1.0:
		return false
	var stats := Balance.definition("bosses", b.kind, d.settings.get("developer_balance", {}))
	if not number(b.get("hp"), 0, stats.hp) or b.hp <= 0.0 or not number(b.get("steps"), 1, 1.0e15, true):
		return false
	if not number(b.get("shield"), 0, stats.get("shield", 600.0)) or not number(b.get("wards"), 0, stats.get("wards", 3), true):
		return false
	if not number(b.get("regen"), 0, stats.get("regen_period", 10.0)) or not number(b.get("toll"), 0, stats.get("toll_period", 8.0) + stats.get("toll_delay", 2.0)) or not b.get("toll_delayed") is bool:
		return false
	if not b.get("path") is Array or b.path.size() < 2 or b.path.size() > 49 or not number(b.get("segment"), 1, b.path.size() - 1, true):
		return false
	var points: Array = b.path.duplicate()
	points.append(b.get("pos"))
	for point in points:
		if not point is Array or point.size() != 2 or not number(point[0], -1.0e12, 1.0e12) or not number(point[1], -1.0e12, 1.0e12):
			return false
	return true

func valid_boss_road(b: Dictionary, regions: Dictionary, seed_value: int = -1) -> bool:
	var side := VigilWorld.DIRS.find(VigilWorld.coord(b.tile) - VigilWorld.coord(b.previous))
	var expected: Array[Vector2] = []
	# A purchased gate may still have its boss on the original 3-point
	# threshold plus the 24-point incoming spoke. Preserve that live route.
	if not regions.has(b.previous) or (seed_value >= 0 and b.steps == 1 and b.path.size() == 27):
		const Areas = preload("res://scripts/world/hidden_areas.gd")
		var g := Areas.gate(Areas.sector_for(VigilWorld.coord(b.previous)), seed_value)
		if b.previous != g.id or b.tile != g.neighbor:
			return false
		expected = Areas.emergence(g, regions)
	else:
		expected = VigilWorld.spoke(regions[b.previous], side)
		expected.reverse()
		expected.append_array(VigilWorld.spoke(regions[b.tile], (side + 2) % 4).slice(1))
	if expected.size() != b.path.size():
		return false
	for i in range(expected.size()):
		if expected[i].distance_to(Vector2(b.path[i][0], b.path[i][1])) > 0.01:
			return false
	var pos := Vector2(b.pos[0], b.pos[1])
	var segment := int(b.segment)
	return pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, expected[segment-1], expected[segment])) <= 0.01

# Shared tower/equipment validation for world snapshots and campaign setups.
func valid_loadout(d: Dictionary, max_tower_level: int = 4) -> bool:
	if not d.get("towers") is Dictionary or not d.get("regions") is Dictionary or not number(d.get("next_tower"), 1, 1.0e15, true) or not number(d.get("balance")): return false
	const Relics = preload("res://scripts/gameplay/progression/relics.gd")
	var inventory: Variant = d.get("relics", {})
	if not inventory is Dictionary:
		return false
	for relic_id in inventory:
		if not relic_id is String or not inventory[relic_id] is String or not Relics.DEFINITIONS.has(inventory[relic_id]):
			return false
		var parts: PackedStringArray = relic_id.split("#")
		if parts.size() > 2 or not valid_coordinate(parts[0]) or (parts.size() == 2 and parts[1] != inventory[relic_id]):
			return false
	var equipped := {}
	var occupied := {}
	for id in d.towers:
		var t = d.towers[id]
		if not t is Dictionary or not id is String or not id.is_valid_int():
			return false
		if int(id) < 1 or str(int(id)) != id:
			return false
		for field in ["id", "kind", "region", "pad", "level", "earnings", "cooldown", "angle"]:
			if not t.has(field):
				return false
		if t.id != id or int(id) >= d.next_tower or not Balance.TOWERS.has(t.kind) or not d.regions.has(t.region):
			return false
		if d.version == Balance.VERSION:
			var branch: Variant = t.get("branch", "")
			if not branch is String or (t.level == 4 and not Balance.valid_branch(t.kind, branch)) or (t.level != 4 and branch != ""):
				return false
		if not number(t.pad, 0, 3, true) or not number(t.level, 1, max_tower_level, true) or not number(t.earnings) or not number(t.cooldown, 0, maxf(10.0, Balance.TUNING_FIELDS.towers.period.max)) or not number(t.angle, -TAU, TAU):
			return false
		var relic_id: Variant = t.get("relic", "")
		if not relic_id is String or (relic_id != "" and (not inventory.has(relic_id) or equipped.has(relic_id))):
			return false
		if relic_id != "":
			equipped[relic_id] = true
		var socket := str(t.region) + "/" + str(int(t.pad))
		if not t.get("target_mode", "first") is String or not Balance.TARGET_MODES.has(t.get("target_mode", "first")):
			return false
		if t.has("rebuild_remaining") and not number(t.rebuild_remaining, 0, Balance.MAX_REBUILD_SECONDS):
			return false
		if occupied.has(socket):
			return false
		occupied[socket] = true
	return true
