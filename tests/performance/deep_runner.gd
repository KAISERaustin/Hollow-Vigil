extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")
const Probe = preload("res://tests/performance/probe.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rows := []
	for radius in [40, 80]:
		Probe.enabled = false
		var game := F.infinite(radius, true)
		for tick in range(600): game.combat.tick(Balance.STEP)
		Probe.reset()
		Probe.enabled = true
		var samples := []
		for tick in range(300):
			var start := Time.get_ticks_usec()
			game.combat.tick(Balance.STEP)
			samples.append((Time.get_ticks_usec() - start) / 1000.0)
		Probe.enabled = false
		rows.append({"radius": radius, "tick_ms": F.stats(samples), "profile": Probe.report(), "checksum": F.checksum(game), "counts": F.counts(game)})
		print("DEEP ", radius, " ", F.stats(samples))
	var file := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
