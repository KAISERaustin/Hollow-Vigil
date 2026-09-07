extends RefCounted
## Three independent Campaign sessions. Level/Wave nodes still own gameplay rules.
const Configuration = preload("res://scripts/campaign/configuration.gd")
const LevelBuild = preload("res://scripts/persistence/campaign_build.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
const COUNT := 3
var base_path := "user://vigil"
var error := ""
var storage := preload("res://scripts/persistence/document_store.gd").new()

func _init() -> void:
	storage.validator = valid

func path_for(slot: int) -> String:
	return base_path + "-campaign-slot-" + str(slot + 1) + ".save"

func occupied(slot: int) -> bool:
	return slot >= 0 and slot < COUNT and storage.exists(path_for(slot))

func summary(slot: int) -> Dictionary:
	return storage.latest(path_for(slot)) if slot >= 0 and slot < COUNT else {}

static func valid(value: Dictionary) -> bool:
	if value.get("version") != 1 or value.get("game_type") != "campaign": return false
	if not value.get("id") is String or not Codec.valid_uuid(value.id): return false
	if not value.get("name") is String or value.name.strip_edges().is_empty() or value.name.length() > 80: return false
	if value.get("mode") not in ["creative", "survival"]: return false
	if not Configuration._number(value.get("sequence"), 0, 1e15, true): return false
	if not Configuration._number(value.get("saved_at")) or not Configuration._number(value.get("completed"), 0, Configuration.Catalog.COUNT, true): return false
	if not value.get("levels") is Dictionary or value.levels.size() > Configuration.Catalog.COUNT: return false
	for key in value.levels:
		if not key is String or not key.is_valid_int() or str(int(key)) != key: return false
		var entry: Variant = value.levels[key]
		if not entry is Dictionary: return false
		var level := {"version": 1, "level": int(key), "setup": {"name": value.name, "description": ""}, "overrides": entry.get("overrides", {})}
		if entry.has("loadout"): level.loadout = entry.loadout
		if not LevelBuild.valid(level): return false
	return value.get("checkpoint") is Dictionary and (value.checkpoint.is_empty() or Run.valid_checkpoint(value.checkpoint))

func create(slot: int, mode: String, title: String, levels: Dictionary = {}) -> Dictionary:
	if slot < 0 or slot >= COUNT or occupied(slot):
		error = "Choose an empty Campaign slot or confirm which game to replace."
		return {}
	var value := {"version": 1, "sequence": 0, "game_type": "campaign", "id": Codec.uuid(), "name": title.strip_edges(), "mode": mode,
		"saved_at": Time.get_unix_time_from_system(), "completed": 0, "levels": levels.duplicate(true), "checkpoint": {}}
	return value if save_slot(slot, value) else {}

func save_slot(slot: int, value: Dictionary) -> bool:
	if slot < 0 or slot >= COUNT or not valid(value):
		error = "This Campaign could not be saved. Your previous game is safe."
		return false
	var next := value.duplicate(true)
	next.sequence += 1
	next.saved_at = Time.get_unix_time_from_system()
	if not storage.write(path_for(slot), next):
		error = storage.last_error
		return false
	value.sequence = next.sequence
	value.saved_at = next.saved_at
	error = ""
	return true

func preserve(slot: int) -> bool:
	var value := summary(slot)
	if value.is_empty():
		error = "This game needs recovery before it can be replaced."
		return not occupied(slot)
	var path := path_for(slot) + ".recovery-" + Codec.uuid()
	var ok := storage.write(path, value)
	error = storage.last_error
	return ok

func replace(slot: int, value: Dictionary) -> bool:
	if not valid(value) or slot < 0 or slot >= COUNT: return false
	if occupied(slot) and not preserve(slot): return false
	var next := value.duplicate(true)
	next.sequence = maxi(int(next.sequence), int(summary(slot).get("sequence", 0)))
	return save_slot(slot, next)
