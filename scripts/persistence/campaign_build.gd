extends RefCounted
## A reusable campaign setup; progress and live combat never travel with it.
const FORMAT := "hollow-vigil-campaign-build-v1"
const Configuration = preload("res://scripts/campaign/configuration.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Stats = preload("res://scripts/persistence/stat_configuration.gd")

static func encode(index: int, overrides: Dictionary, game: VigilState, title: String, description: String, stats_only: bool) -> String:
	var value := {"version": 1, "setup": {"name": title.strip_edges(), "description": description}, "level": index, "overrides": overrides.duplicate(true)}
	if not stats_only:
		value.loadout = {}
		for key in ["towers", "next_tower", "relics", "balance"]:
			if key == "relics": value.loadout[key] = game.data.get(key, {})
			else: value.loadout[key] = game.data.get(key)
	if not valid(value): return ""
	var payload := JSON.stringify(value, "", true, true)
	return JSON.stringify({"format": FORMAT, "payload": payload, "checksum": payload.sha256_text()})

static func decode(code: String) -> Dictionary:
	if code.to_utf8_buffer().size() > Stats.MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(code) != OK: return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.size() != 3 or envelope.get("format") != FORMAT or not envelope.get("payload") is String: return {}
	if envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK: return {}
	var value: Variant = parser.data
	return value if valid(value) else {}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.size() != (5 if value.has("loadout") else 4): return false
	if not Stats.valid({"version": 1, "setup": value.get("setup"), "tuning": {}}): return false
	if not Configuration._number(value.get("level"), 0, Configuration.Catalog.COUNT - 1, true): return false
	if not Configuration.valid_level(int(value.level), value.get("overrides")): return false
	if not value.has("loadout"): return true
	if not value.loadout is Dictionary or value.loadout.size() != 4: return false
	var run := Run.new(int(value.level), value.overrides)
	var snapshot := run.game.snapshot()
	for key in ["towers", "next_tower", "relics", "balance"]:
		if not value.loadout.has(key): return false
		snapshot[key] = value.loadout[key]
	if not VigilSaveStore.new().valid_loadout(snapshot): return false
	for tower in snapshot.towers.values():
		var allowed := false
		for socket in run.mission.sockets:
			if socket.region == tower.region and socket.pad == tower.pad: allowed = true
		if not allowed: return false
	return true

static func apply_loadout(run: RefCounted, value: Dictionary) -> void:
	if not valid(value) or int(value.level) != int(run.mission.index) or not value.has("loadout"): return
	for key in value.loadout:
		run.game.data[key] = value.loadout[key].duplicate(true) if value.loadout[key] is Dictionary else value.loadout[key]
	for tower in run.game.data.towers.values():
		tower.cooldown = 0.0
		tower.earnings = 0.0
		tower.erase("rebuild_remaining")
