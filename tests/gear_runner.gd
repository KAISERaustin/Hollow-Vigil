extends "res://tests/test_runner.gd"

func run() -> void:
	preload("res://tests/unit/gear_catalog_checks.gd").run(self)
	preload("res://tests/unit/relic_checks.gd").run(self)
	preload("res://tests/unit/developer_balance_checks.gd").test_gear_tuning(self)
	print("GEAR: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
