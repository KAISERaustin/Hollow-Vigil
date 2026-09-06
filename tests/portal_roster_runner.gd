extends "res://tests/test_runner.gd"

func run() -> void:
	preload("res://tests/unit/portal_roster_checks.gd").run(self)
	print("PORTAL_ROSTERS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
