class_name VigilSaveSlots
extends RefCounted

const Stats = preload("res://scripts/persistence/stat_configuration.gd")
const CampaignBuild = preload("res://scripts/persistence/campaign_build.gd")
const CampaignPlaythrough = preload("res://scripts/persistence/campaign_playthrough.gd")
const Reusable = preload("res://scripts/persistence/reusable_build.gd")
const COUNT := 3
var base_path := "user://vigil"
var error := ""
var storage := VigilSaveStore.new()

func configurations_path() -> String:
	return base_path + "-configurations"

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
	var build := Reusable.decode(code)
	if not build.is_empty():
		return {"name": build.setup.name, "description": build.setup.description, "code": code, "kind": "build", "build": build}
	var value := CampaignPlaythrough.decode(code)
	var kind := "campaign"
	if value.is_empty():
		value = Stats.decode(code)
		kind = "stats"
	if value.is_empty():
		value = CampaignBuild.decode(code)
		kind = "campaign_build" if value.has("loadout") else "campaign_stats"
	if value.is_empty(): return {}
	return {"name": value.setup.name, "description": value.setup.description, "code": code, "kind": kind}

func save_shared(code: String) -> bool:
	var entry := shared_entry(code)
	if entry.is_empty():
		error = "Invalid or incompatible configuration."
		return false
	if entry.kind == "build":
		if DirAccess.make_dir_recursive_absolute(configurations_path()) != OK:
			error = "Couldn't open My builds. Please try again."
			return false
		var path := configurations_path().path_join(code.sha256_text() + ".hvshared")
		if FileAccess.file_exists(path): return FileAccess.get_file_as_string(path) == code
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		if file == null: return false
		file.store_string(code)
		file.flush()
		var ok := file.get_error() == OK
		file.close()
		if not ok or Reusable.decode(FileAccess.get_file_as_string(path + ".tmp")).is_empty(): return false
		return DirAccess.rename_absolute(path + ".tmp", path) == OK
	return _save_configuration_code(code, {"stats": "hvstats", "campaign_build": "hvcampaign", "campaign_stats": "hvcampaign", "campaign": "hvcampaign"}[entry.kind])

func shared_configurations(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(configurations_path())
	if directory == null: return result
	var files := directory.get_files()
	files.reverse()
	for filename in files:
		if filename.get_extension() not in ["hvstats", "hvcampaign", "hvshared"]: continue
		var entry := shared_entry(FileAccess.get_file_as_string(configurations_path().path_join(filename)))
		if not entry.is_empty() and (entry.get("kind") == kind or kind == "all"): result.append(entry)
	return result

func delete_shared(code: String) -> bool:
	var directory := DirAccess.open(configurations_path())
	if directory == null: return true
	for filename in directory.get_files():
		if filename.get_extension() not in ["hvstats", "hvcampaign", "hvshared"]: continue
		var path := configurations_path().path_join(filename)
		if FileAccess.get_file_as_string(path) == code and DirAccess.remove_absolute(path) != OK: return false
	return true

func reusable_entry(entry: Dictionary) -> Dictionary:
	if entry.has("build"): return entry
	var code: String = entry.get("code", "")
	var kind: String = entry.get("kind", "")
	var build := {}
	if kind == "stats":
		var stats := Stats.decode(code)
		var levels := {}
		for index in Reusable.Configuration.Catalog.COUNT:
			levels[str(index)] = {"overrides": {"tuning": stats.tuning.duplicate(true)}}
		build = Reusable.capture("campaign", null, levels, "all", -1, Reusable.all_contents("campaign", "rules"), entry.name, entry.description)
	elif kind in ["campaign", "campaign_build", "campaign_stats"]:
		var legacy: Dictionary = CampaignPlaythrough.decode(code) if kind == "campaign" else CampaignBuild.decode(code)
		var levels: Dictionary = legacy.levels if kind == "campaign" else {str(int(legacy.level)): {"overrides": legacy.overrides}}
		if kind != "campaign" and legacy.has("loadout"): levels[str(int(legacy.level))].loadout = legacy.loadout
		var contents := Reusable.all_contents("campaign")
		if kind == "campaign_stats": contents.erase("layout")
		build = Reusable.capture("campaign", null, levels, "all" if kind == "campaign" else "level", int(legacy.get("level", -1)), contents, entry.name, entry.description)
		# Reading an older library entry preserves its original contents. New
		# saves and shares pass through capture again and omit these layouts.
		if not build.is_empty() and kind != "campaign_stats":
			for index in levels:
				if levels[index].has("loadout"):
					build.contents.layout = true
					build.data.levels[index].layout = Reusable.clean_loadout(levels[index].loadout)
	if build.is_empty(): return {}
	return shared_entry(Reusable.encode(build))
