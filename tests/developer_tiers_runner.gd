extends "res://tests/test_runner.gd"

func run() -> void:
	preload("res://tests/unit/developer_balance_checks.gd").run(self)
	preload("res://tests/unit/developer_tier_checks.gd").run(self)
	print("Developer checks: ", checks, " failures: ", failures.size())
	quit(0 if failures.is_empty() else 1)
