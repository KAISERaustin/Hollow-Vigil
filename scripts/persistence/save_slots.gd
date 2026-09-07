class_name VigilSaveSlots
extends RefCounted

const Stats = preload("res://scripts/persistence/stat_configuration.gd")
const CampaignBuild = preload("res://scripts/persistence/campaign_build.gd")
const CampaignPlaythrough = preload("res://scripts/persistence/campaign_playthrough.gd")
const COUNT := 3
const BUILD_FORMAT := "hollow-vigil-creative-build-v1"
var base_path := "user://vigil"
var error := ""
var storage := VigilSaveStore.new()

func path_for(slot: int) -> String:
	return base_path + ".save" if slot == 0 else base_path + "-slot-" + str(slot + 1) + ".save"

func occupied(slot: int) -> bool:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path_for(slot) + suffix):
			return true
	return false

func summary(slot: int) -> Dictionary:
	var best := {}
	for suffix in ["", ".tmp", ".bak"]:
		var candidate := storage.read_candidate(path_for(slot) + suffix)
		if not candidate.is_empty() and (best.is_empty() or candidate.sequence > best.sequence):
			best = candidate
	return best

func create(slot: int, mode: String, build_code: String = "", starting_rules: Dictionary = {}) -> VigilState:
	error = ""
	if slot < 0 or slot >= COUNT or occupied(slot) or mode not in ["creative", "survival"] or not Balance.valid_tuning(starting_rules):
		error = "Choose an empty save slot and a game mode."
		return null
	var game := VigilState.new(0, mode, starting_rules)
	game.save_path = path_for(slot)
	if not build_code.is_empty():
		var configuration := Stats.decode(build_code)
		if not configuration.is_empty():
			game = VigilState.new(0, mode, Balance.merge_tuning(configuration.tuning, starting_rules))
			game.save_path = path_for(slot)
			game.data.setup = configuration.setup.duplicate(true)
			if not game.save():
				error = game.save_error
				return null
			return game
		var snapshot := decode_build(build_code)
		if snapshot.is_empty():
			error = "This is not a valid Creative build. Copy the complete export code."
			return null
		snapshot.settings.developer_balance = Balance.merge_tuning(snapshot.settings.get("developer_balance", {}), starting_rules)
		if snapshot.settings.developer_balance.get("session", {}).get("start", {}).has("starting_gold"):
			snapshot.balance = Balance.tuned_value("session", "start", "starting_gold", snapshot.settings.developer_balance)
		snapshot.mode = mode
		snapshot.sequence = 0
		snapshot.last_accounted = Time.get_unix_time_from_system()
		# Builds carry the layout, resources and rules, never cloud identity or offline income.
		snapshot.erase("cloud")
		for region in snapshot.regions.values():
			region.history.clear()
			region.history_time = 0.0
		if not storage.write(game.save_path, snapshot) or not game.load_save(snapshot.last_accounted):
			error = storage.last_error if not storage.last_error.is_empty() else game.save_error
			return null
	elif not game.save():
		error = game.save_error
		return null
	return game

func export_build(game: VigilState, setup_name: String = "Untitled setup", description: String = "") -> String:
	var snapshot := game.snapshot()
	snapshot.mode = "creative"
	snapshot.setup = {"name": setup_name.strip_edges().left(80), "description": description.left(4000)}
	if snapshot.setup.name.is_empty():
		return ""
	snapshot.erase("cloud")
	# Personal preferences are not part of a shared build.
	snapshot.settings = {"low_power": false, "developer_balance": game.tuning.duplicate(true)}
	if not storage.valid_data(snapshot):
		return ""
	var payload := JSON.stringify(snapshot, "", true, true)
	return JSON.stringify({"format": BUILD_FORMAT, "payload": payload, "checksum": payload.sha256_text()})

func decode_build(code: String) -> Dictionary:
	if code.length() > 16 * 1024 * 1024:
		return {}
	var parser := JSON.new()
	if parser.parse(code) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("format") != BUILD_FORMAT or not envelope.get("payload") is String:
		return {}
	if envelope.get("checksum") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var snapshot: Variant = parser.data
	if not snapshot is Dictionary or snapshot.get("mode") != "creative" or not storage.valid_data(snapshot):
		return {}
	return storage.migrate_portal_unlocks(snapshot)

func archive(slot: int) -> bool:
	if slot < 0 or slot >= COUNT:
		return false
	var prefix := path_for(slot)
	var destination := prefix + ".archived-" + str(Time.get_unix_time_from_system()) + "-" + str(Time.get_ticks_usec())
	var moved: Array[String] = []
	for suffix in ["", ".tmp", ".bak", ".cloud-outbox"]:
		if not FileAccess.file_exists(prefix + suffix):
			continue
		if DirAccess.rename_absolute(prefix + suffix, destination + suffix) != OK:
			error = "Couldn't archive this save. Existing files are preserved."
			for previous in moved:
				if DirAccess.rename_absolute(destination + previous, prefix + previous) != OK:
					error += " A recovery file remains at " + destination + previous
			return false
		moved.append(suffix)
	error = ""
	return true

# Each configuration is an independent snapshot, kept separately from playable slots.
func configurations_path() -> String:
	return base_path + "-configurations"

func save_configuration(game: VigilState, title: String, description: String) -> bool:
	error = ""
	var code := export_build(game, title, description)
	if code.is_empty():
		error = "Enter a configuration name and save from a Creative world."
		return false
	return _save_configuration_code(code, "hvbuild")

func save_stat_configuration(tuning: Dictionary, title: String, description: String = "") -> bool:
	var code := Stats.encode(tuning, title, description)
	if code.is_empty():
		error = "Enter a name and valid gameplay statistics."
		return false
	return _save_configuration_code(code, "hvstats")

func _save_configuration_code(code: String, extension: String) -> bool:
	error = ""
	if DirAccess.make_dir_recursive_absolute(configurations_path()) != OK:
		error = "Couldn't create the configuration library. Please try again."
		return false
	var path := configurations_path().path_join(str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + str(Time.get_ticks_usec()) + "." + extension)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		error = "Couldn't save the configuration. Please try again."
		return false
	file.store_string(code)
	file.flush()
	var success := file.get_error() == OK
	file.close()
	if not success:
		error = "Couldn't finish saving the configuration. Please try again."
	return success

func configurations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(configurations_path())
	if directory == null:
		return result
	var files := directory.get_files()
	files.sort()
	files.reverse()
	for filename in files:
		if filename.get_extension() != "hvbuild":
			continue
		var code := FileAccess.get_file_as_string(configurations_path().path_join(filename))
		var snapshot := decode_build(code)
		if not snapshot.is_empty():
			result.append({"name": snapshot.setup.name, "description": snapshot.setup.description, "code": code})
	return result

func stat_configurations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(configurations_path())
	if directory == null: return result
	var files := directory.get_files()
	files.sort()
	files.reverse()
	for filename in files:
		if filename.get_extension() != "hvstats": continue
		var code := FileAccess.get_file_as_string(configurations_path().path_join(filename))
		var configuration := Stats.decode(code)
		if not configuration.is_empty():
			result.append({"name": configuration.setup.name, "description": configuration.setup.description, "code": code})
	return result

func shared_entry(code: String) -> Dictionary:
	var value := CampaignPlaythrough.decode(code)
	var kind := "campaign"
	if value.is_empty():
		value = Stats.decode(code)
		kind = "stats"
	if value.is_empty():
		value = CampaignBuild.decode(code)
		kind = "campaign_build" if value.has("loadout") else "campaign_stats"
	if value.is_empty():
		value = decode_build(code)
		kind = "world"
	if value.is_empty(): return {}
	return {"name": value.setup.name, "description": value.setup.description, "code": code, "kind": kind}

func save_shared(code: String) -> bool:
	var entry := shared_entry(code)
	if entry.is_empty():
		error = "Invalid or incompatible configuration."
		return false
	return _save_configuration_code(code, {"world": "hvbuild", "stats": "hvstats", "campaign_build": "hvcampaign", "campaign_stats": "hvcampaign", "campaign": "hvcampaign"}[entry.kind])

func shared_configurations(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(configurations_path())
	if directory == null: return result
	var files := directory.get_files()
	files.reverse()
	for filename in files:
		if filename.get_extension() not in ["hvbuild", "hvstats", "hvcampaign"]: continue
		var entry := shared_entry(FileAccess.get_file_as_string(configurations_path().path_join(filename)))
		if entry.get("kind") == kind: result.append(entry)
	return result
