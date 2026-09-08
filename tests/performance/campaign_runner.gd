extends "res://tests/campaign_balance_runner.gd"

const F = preload("res://tests/performance/fixtures.gd")
const Probe = preload("res://tests/performance/probe.gd")

func run() -> void:
	var rows := []
	for index in range(Catalog.COUNT):
		var battle := Run.new(index)
		var survival_guard := OS.get_environment("PERF_SURVIVAL_GUARD") == "1"
		if survival_guard: battle.health = 1000000
		var samples := []
		var peak := 0
		var steps := 0
		Probe.reset()
		Probe.enabled = true
		while battle.phase in ["planning", "wave"] and steps < 20000:
			if battle.phase == "planning": invest(battle, STRATEGIES[index]); battle.start_wave()
			var start := Time.get_ticks_usec()
			battle.tick(Balance.STEP)
			samples.append((Time.get_ticks_usec() - start) / 1000.0)
			peak = maxi(peak, battle.game.combat.enemies.size())
			steps += 1
		Probe.enabled = false
		var row := {"level": index + 1, "name": battle.mission.name, "phase": battle.phase, "health": battle.health,
			"peak_enemies": peak, "ticks": steps, "tick_ms": F.stats(samples), "counts": F.counts(battle.game), "profile": Probe.report(),
			"survival_guard": survival_guard, "waves_completed": battle.wave, "waves_total": battle.mission.waves.size()}
		rows.append(row)
		print("CAMPAIGN ", row.level, " ", row.phase, " ", row.tick_ms)
		await process_frame
	var output := FileAccess.open(OS.get_environment("PERF_OUTPUT"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"rows": rows}, "\t"))
	quit()
