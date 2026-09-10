extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func fixture_enemy(g: VigilState, kind: String = "basic") -> Dictionary:
	var route: Array[Vector2] = [Vector2(-250, 0), Vector2(0, 0)]
	return g.combat.spawn_on_path(kind, route)

func clean_test_save(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func run() -> void:
	print("Use the Campaign test runners through launch.ps1 -Tests.")
	quit()
