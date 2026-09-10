extends "res://tests/test_runner.gd"
const Progress = preload("res://scripts/campaign/progress.gd")

func run() -> void:
	var store := Progress.new()
	store.path = "user://campaign-reset-" + str(Time.get_ticks_usec()) + ".save"
	check(store.reset_progress(), "Fresh progression can reset")
	check(store.restore_completed_levels(Progress.Catalog.COUNT), "Existing completion prepares")
	check(store.reset_progress() and store.data.completed_levels == 0, "All campaign completion resets")
	var loaded := Progress.new()
	loaded.path = store.path
	loaded.load_progress()
	check(not loaded.blocked and loaded.data.completed_levels == 0 and loaded.data.sequence == store.data.sequence, "New reset sequence wins over recovery files")
	var file := FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string("broken save")
	file.close()
	for suffix in [".bak", ".tmp"]: DirAccess.remove_absolute(store.path + suffix)
	loaded.load_progress()
	check(loaded.blocked, "Unreadable progress remains protected")
	check(loaded.reset_progress() and not loaded.blocked, "Explicit reset can recover unreadable progression with archive")
	var preserved := false
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(store.path.get_file() + ".before-reset"):
			preserved = preserved or FileAccess.get_file_as_string("user://" + filename) == "broken save"
	check(preserved, "Reset preserves original unreadable file")
	store.path = "user://missing-reset-parent/progress.save"
	store.data.completed_levels = 8
	check(not store.reset_progress() and store.data.completed_levels == 8, "Failed reset does not clear in-memory progress")
	for filename in DirAccess.get_files_at("user://"):
		if filename.begins_with(loaded.path.get_file()): DirAccess.remove_absolute("user://" + filename)
	print("CAMPAIGN RESET: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
