extends VigilSaveStore

const Catalog = preload("res://scripts/campaign/catalog.gd")
var path := "user://vigil-campaign.save"
var data := {"version": 1, "sequence": 0, "medals": [], "checkpoint": {}}
var blocked := false

func _init() -> void:
	data.medals.resize(Catalog.COUNT)
	data.medals.fill(0)

# Campaign and sandbox use distinct contracts and files. The inherited writer
# supplies checked temporary writes and backup rotation, not sandbox validation.
func valid_data(value: Dictionary) -> bool:
	if value.get("version") != 1 or not number(value.get("sequence"), 0, 1e15, true):
		return false
	if not value.get("medals") is Array or value.medals.size() != Catalog.COUNT or not value.get("checkpoint") is Dictionary:
		return false
	var locked := false
	for medal in value.medals:
		if not number(medal, 0, 3, true) or (locked and medal > 0):
			return false
		locked = locked or medal == 0
	var saved: Dictionary = value.checkpoint
	if saved.is_empty():
		return true
	if not number(saved.get("level"), 0, Catalog.COUNT - 1, true):
		return false
	var index := int(saved.level)
	if index > 0 and value.medals[index - 1] == 0:
		return false
	var mission := Catalog.level(index)
	if not number(saved.get("wave"), 0, mission.waves.size() - 1, true) or not number(saved.get("health"), 1, Catalog.MAX_HEALTH, true) or not number(saved.get("gold"), 0, 1000000):
		return false
	if not saved.get("towers") is Array or saved.towers.size() > mission.pads.size():
		return false
	var occupied := {}
	for tower in saved.towers:
		if not tower is Dictionary or not number(tower.get("socket"), 0, 15, true) or int(tower.socket) not in mission.pads or occupied.has(int(tower.socket)):
			return false
		occupied[int(tower.socket)] = true
		if not tower.get("kind") is String or not Balance.TOWERS.has(tower.kind) or not number(tower.get("level"), 1, 4, true):
			return false
		if not tower.get("target_mode") is String or not Balance.TARGET_MODES.has(tower.target_mode) or not tower.get("branch") is String:
			return false
		if (tower.level == 4 and not Balance.valid_branch(tower.kind, tower.branch)) or (tower.level != 4 and tower.branch != ""):
			return false
	return true

func read_candidate(candidate_path: String) -> Dictionary:
	if not FileAccess.file_exists(candidate_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(candidate_path)) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary and valid_data(parsed) else {}

func load_progress() -> void:
	var best := {}
	var found := false
	for suffix in ["", ".tmp", ".bak"]:
		found = found or FileAccess.file_exists(path + suffix)
		var candidate := read_candidate(path + suffix)
		if not candidate.is_empty() and (best.is_empty() or candidate.sequence > best.sequence):
			best = candidate
	blocked = found and best.is_empty()
	last_error = "Campaign progress could not be read. Your files are preserved." if blocked else ""
	if not best.is_empty():
		data = best

func unlocked(index: int) -> bool:
	return not blocked and index >= 0 and index < Catalog.COUNT and (index == 0 or data.medals[index - 1] > 0)

func save_run(run: RefCounted) -> bool:
	if blocked:
		return false
	if run.phase == "victory":
		data.medals[run.mission.index] = maxi(int(data.medals[run.mission.index]), run.medal())
		data.checkpoint = {}
	else:
		data.checkpoint = run.checkpoint.duplicate(true)
	return flush()

func flush() -> bool:
	if blocked:
		return false
	data.sequence += 1
	return write(path, data)
