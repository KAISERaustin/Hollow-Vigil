extends "res://tests/test_runner.gd"

func run() -> void:
	inspect("res://scripts")
	inspect("res://tests")
	print("SOURCE LOAD: %d scripts, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func inspect(path: String) -> void:
	var directory := DirAccess.open(path)
	for name in directory.get_files():
		if name.ends_with(".gd"):
			var script = load(path.path_join(name))
			check(script is GDScript and script.can_instantiate(), "Script compiles: " + path.path_join(name))
	for name in directory.get_directories(): inspect(path.path_join(name))
