extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := F.infinite(40, true)
	for tick in range(900): game.combat.tick(Balance.STEP)
	var result := {"case": "infinite_40_true_false", "ticks": 900, "checksum_format": "stable-content-v2", "checksum": F.checksum(game), "counts": F.counts(game)}
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("FINGERPRINT ", result)
	quit()
