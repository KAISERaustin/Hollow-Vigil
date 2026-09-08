extends VigilSaveStore

const Catalog = preload("res://scripts/campaign/catalog.gd")
var path := "user://vigil-campaign.save"
var data := {"version": 2, "sequence": 0, "completed_levels": 0}
var blocked := false
var legacy_candidates := {}
var allow_all := false

func valid_data(value: Dictionary) -> bool:
	return valid_map_progress(value) and value.get("version") == 2 and number(value.get("sequence"), 0, 1e15, true) and number(value.get("completed_levels"), 0, Catalog.COUNT, true)

static func valid_map_progress(value: Dictionary) -> bool:
	if not valid_equipment(value.get("relics", {})): return false
	var beaten: Variant = value.get("beaten_levels", [])
	if not beaten is Array or beaten.size() > Catalog.COUNT: return false
	var seen := {}
	for index in beaten:
		if not (index is int or index is float): return false
		if index != int(index) or index < 0 or index >= Catalog.COUNT or seen.has(int(index)): return false
		seen[int(index)] = true
	var current: Variant = value.get("current_level", -1)
	return (current is int or current is float) and current == int(current) and current >= -1 and current < Catalog.COUNT

static func valid_equipment(inventory: Variant) -> bool:
	var snapshot := {"towers": {}, "regions": {}, "next_tower": 1, "balance": 0, "relics": inventory}
	return VigilSaveStore.new().valid_loadout(snapshot)

func apply_equipment(run: RefCounted) -> void:
	run.game.data.relics.merge(data.get("relics", {}).duplicate(true))

func level_completed(index: int) -> bool:
	if index < int(data.completed_levels): return true
	if allow_all:
		for beaten in data.get("beaten_levels", []):
			if int(beaten) == index: return true
	return false

func current_level() -> int:
	if allow_all and int(data.get("current_level", -1)) >= 0:
		return int(data.current_level)
	return int(data.completed_levels)

func read_candidate(candidate_path: String) -> Dictionary:
	legacy_candidates.erase(candidate_path)
	if not FileAccess.file_exists(candidate_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(candidate_path)) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary:
		return {}
	var parsed: Dictionary = parser.data
	if parsed.get("version") == 1:
		if not number(parsed.get("sequence"), 0, 1e15, true) or not parsed.get("medals") is Array or parsed.medals.size() not in [Catalog.LEGACY_COUNT, Catalog.COUNT]:
			return {}
		var completed := 0
		var locked := false
		for medal in parsed.medals:
			if not number(medal, 0, 3, true) or (locked and medal > 0):
				return {}
			locked = locked or medal == 0
			if medal > 0: completed += 1
		# Legacy checkpoints are deliberately discarded; only victories migrate.
		legacy_candidates[candidate_path] = true
		parsed = {"version": 2, "sequence": parsed.sequence, "completed_levels": completed}
	return parsed if valid_data(parsed) else {}

func load_progress() -> void:
	var best := {}
	var best_path := ""
	var found := false
	for suffix in ["", ".tmp", ".bak"]:
		found = found or FileAccess.file_exists(path + suffix)
		var candidate := read_candidate(path + suffix)
		if not candidate.is_empty() and (best.is_empty() or candidate.sequence > best.sequence):
			best = candidate
			best_path = path + suffix
	blocked = found and best.is_empty()
	last_error = "Campaign progress could not be read. Your files are preserved. Restore a cloud backup to recover." if blocked else ""
	if not best.is_empty():
		data = best
		if legacy_candidates.has(best_path):
			var archive := path + ".before-v2-" + str(Time.get_ticks_usec())
			if DirAccess.copy_absolute(best_path, archive) != OK:
				blocked = true
				last_error = "Couldn't preserve the old campaign save. Your files are unchanged."
			elif not flush():
				blocked = true

func unlocked(index: int) -> bool:
	return not blocked and index >= 0 and index < Catalog.COUNT and (allow_all or index <= int(data.completed_levels))

func save_run(run: RefCounted) -> bool:
	if blocked:
		return false
	var inventory: Dictionary = data.get("relics", {}).duplicate(true)
	inventory.merge(run.game.data.relics)
	var equipment_changed: bool = inventory != data.get("relics", {})
	data.relics = inventory
	if allow_all:
		var index := int(run.mission.index)
		data.current_level = index
		if run.phase == "victory":
			var beaten: Array = []
			for saved_index in data.get("beaten_levels", []): beaten.append(int(saved_index))
			if index not in beaten: beaten.append(index)
			data.beaten_levels = beaten
			while int(data.completed_levels) < Catalog.COUNT and level_completed(int(data.completed_levels)):
				data.completed_levels += 1
			data.current_level = int(data.completed_levels) if int(data.completed_levels) < Catalog.COUNT else -1
		return flush()
	if run.phase != "victory":
		return flush() if equipment_changed else true
	var completed := int(run.mission.index) + 1
	if completed > int(data.completed_levels) + 1:
		last_error = "Complete the preceding level first."
		return false
	data.completed_levels = maxi(int(data.completed_levels), completed)
	return flush()

func flush() -> bool:
	if blocked:
		return false
	data.sequence += 1
	return write(path, data)

func reset_progress() -> bool:
	return _replace_progress(0, "reset")

func restore_completed_levels(completed: int) -> bool:
	return _replace_progress(completed, "cloud")

func _replace_progress(completed: int, reason: String) -> bool:
	if completed < 0 or completed > Catalog.COUNT:
		return false
	var sequence := int(data.sequence)
	var archive := path + ".before-" + reason + "-" + str(Time.get_ticks_usec())
	# Preserve even unreadable originals before a deliberate recovery.
	for suffix in ["", ".tmp", ".bak"]:
		var candidate := read_candidate(path + suffix)
		sequence = maxi(sequence, int(candidate.get("sequence", 0)))
		if FileAccess.file_exists(path + suffix) and DirAccess.copy_absolute(path + suffix, archive + suffix) != OK:
			last_error = "Couldn't preserve the current campaign. Your progress is unchanged."
			return false
	var replacement := {"version": 2, "sequence": sequence + 1, "completed_levels": completed}
	replacement.relics = data.get("relics", {}).duplicate(true)
	if not write(path, replacement):
		return false
	data = replacement
	blocked = false
	return true
