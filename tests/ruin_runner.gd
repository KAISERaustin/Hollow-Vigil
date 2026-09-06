extends "res://tests/test_runner.gd"

func run() -> void:
	preload("res://tests/unit/castle_checks.gd").run(self)
	preload("res://tests/unit/enemy_checks.gd").run(self)
	preload("res://tests/unit/developer_balance_checks.gd").run(self)
	preload("res://tests/unit/world_checks.gd").run(self)
	preload("res://tests/unit/simulation_checks.gd").run(self)
	print("Ruin checks: ", checks, " failures: ", failures.size())
	quit(0 if failures.is_empty() else 1)
