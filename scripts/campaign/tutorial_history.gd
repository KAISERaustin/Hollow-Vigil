extends RefCounted
## Device-wide learning history, independent of Campaign slots and progress resets.
var path := "user://tutorials.cfg"
var seen := {}
var skipped := false

func load_history() -> void:
	var file := ConfigFile.new()
	seen.clear()
	skipped = false
	if file.load(path) != OK: return
	skipped = file.get_value("tutorial", "skipped", false) == true
	for key in file.get_section_keys("seen") if file.has_section("seen") else []:
		if file.get_value("seen", key, false) == true: seen[key] = true

func allows(id: String) -> bool:
	return not skipped and not seen.has(id)

func acknowledge(ids: Array, skip_all: bool = false) -> bool:
	for id in ids: seen[str(id)] = true
	skipped = skipped or skip_all
	var file := ConfigFile.new()
	file.set_value("tutorial", "skipped", skipped)
	for id in seen: file.set_value("seen", id, true)
	return file.save(path) == OK
