extends SceneTree

const F = preload("res://tests/performance/fixtures.gd")
const Probe = preload("res://tests/performance/probe.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rows := []
	var cases := [[4, false, false], [20, true, false], [40, false, false], [40, true, false], [80, true, false], [4, true, true]]
	for item in cases:
		for repeat in range(1 if OS.get_environment("PERF_INSTRUMENTED") == "1" else 3):
			Probe.enabled = false
			var game := F.infinite(item[0], item[1], item[2])
			for step in range(600): game.combat.tick(Balance.STEP)
			var before := F.counts(game)
			Probe.reset()
			Probe.enabled = true
			var samples := []
			for step in range(300):
				var start := Time.get_ticks_usec()
				game.combat.tick(Balance.STEP)
				samples.append((Time.get_ticks_usec() - start) / 1000.0)
			Probe.enabled = false
			var row := {"case": "infinite_%d_%s_%s" % [item[0], str(item[1]), str(item[2])], "repeat": repeat,
				"before": before, "after": F.counts(game), "tick_ms": F.stats(samples), "samples_ms": samples,
				"checksum": F.checksum(game), "profile": Probe.report(), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}
			rows.append(row)
			print("SIM ", row.case, " ", repeat, " ", row.tick_ms)
			await process_frame
	var output := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "rows": rows}, "\t"))
	quit()
