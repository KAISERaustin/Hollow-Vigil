extends "res://tests/test_runner.gd"

# Focused iteration for tower tuning without unrelated large-world stress tests.
func run() -> void:
	preload("res://tests/unit/economy_checks.gd").run(self)
	preload("res://tests/unit/tower_economy_checks.gd").run(self)
	preload("res://tests/unit/tower_progression_checks.gd").run(self)
	preload("res://tests/unit/tower_balance_checks.gd").run(self)
	preload("res://tests/unit/combat_checks.gd").run(self)
	preload("res://tests/unit/catalog_checks.gd").run(self)
	preload("res://tests/unit/persistence_checks.gd").run(self)
	var report := "Tower balance verification: %d checks, %d failures\n" % [checks, failures.size()]
	for failure in failures:
		report += "FAIL: " + failure + "\n"
	FileAccess.open("res://artifacts/tower-balance-results.txt", FileAccess.WRITE).store_string(report)
	print(report)
	quit(0 if failures.is_empty() else 1)
