extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func clean_test_save(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func run() -> void:
	preload("res://tests/unit/boss_checks.gd").run(self)
	preload("res://tests/unit/biome_cluster_boss_checks.gd").run(self)
	print("BIOME_BOSSES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
