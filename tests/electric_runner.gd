extends "res://tests/test_runner.gd"

func run() -> void:
	preload("res://tests/unit/electric_checks.gd").run(self)
	preload("res://tests/unit/attack_effect_checks.gd").run(self)
	preload("res://tests/unit/combat_checks.gd").test_targeting(self)
	preload("res://tests/unit/tower_progression_checks.gd").test_attack_intervals(self)
	preload("res://tests/unit/relocation_checks.gd").run(self)
	print("ELECTRIC RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
