extends "res://tests/test_runner.gd"

func run() -> void:
	preload("res://tests/unit/orchard_checks.gd").run(self)
	preload("res://tests/unit/combat_checks.gd").run(self)
	preload("res://tests/unit/attack_effect_checks.gd").run(self)
	preload("res://tests/unit/developer_balance_checks.gd").run(self)
	preload("res://tests/unit/gear_rework_checks.gd").run(self)
	print("TOWER EXPANSION REGRESSIONS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
