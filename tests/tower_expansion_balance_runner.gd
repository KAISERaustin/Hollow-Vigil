extends "res://tests/test_runner.gd"

const Integration = preload("res://tests/unit/tower_expansion_integration_checks.gd")
const Kinds := ["ironspike", "moonwheel", "hex_lantern", "caltrop_keep"]
const Duration := 90.0

func sample(kind: String, stage: Array, paired: bool = false) -> Dictionary:
	var total := {"kills": 0.0, "escapes": 0.0, "gold": 0.0, "runs": 0.0}
	for seed_value in [123, 314, 879]:
		for direction in VigilWorld.DIRS:
			var game := VigilState.new(seed_value)
			game.combat.rng.seed = seed_value
			game.data.balance = 100000.0
			var region := VigilWorld.key(direction)
			game.expand(region)
			game.data.regions[region].style = "forest"
			game.data.regions[region].traffic = Balance.MAX_TRAFFIC_LEVEL
			game.data.regions[region].unlocks = ["fast", "heavy"]
			var pad := 0 if direction.x < 0 or direction.y < 0 else (1 if direction.x > 0 else 2)
			if not kind.is_empty():
				var id := game.economy.build(kind, "0,0", pad)
				for level in range(1, stage[0]): game.economy.upgrade(id, level, stage[1] if level == 3 else "")
			if paired:
				var ally := game.economy.build("heavy", "0,0", (pad + 1) % 4)
				game.economy.upgrade(ally)
				game.economy.upgrade(ally)
			advance(game, Duration)
			game.data.regions[region].timer = 1000.0
			advance(game, 30.0)
			total.kills += game.data.kills
			total.escapes += game.data.escapes
			total.gold += game.data.lifetime_earnings
			total.runs += 1.0
	total.clear = total.kills / maxf(1.0, total.kills + total.escapes)
	return total

func run() -> void:
	var report := "scenario,tower,level,branch,clear_percent,gold_per_minute\n"
	var ally := sample("", [1, ""], true)
	report += row("ally-alone", "heavy", [3, ""], ally)
	for kind in Kinds:
		var previous := 0.0
		for stage in Integration.stages(kind):
			var result := sample(kind, stage, kind == "hex_lantern")
			var label := "%s/%s/%s" % [kind, stage[0], stage[1]]
			report += row("paired" if kind == "hex_lantern" else "solo", kind, stage, result)
			print("BALANCE SAMPLE ", label, " clear=", result.clear, " gold=", result.gold)
			check(result.gold > 0.0, label + " earns gold in live mixed traffic")
			if stage[0] <= 3:
				check(result.gold >= previous, label + " upgrades improve mixed-traffic production")
				previous = result.gold
			if kind == "hex_lantern": check(result.gold > ally.gold, label + " improves the same allied defense")
	FileAccess.open("res://artifacts/tower-expansion-balance.csv", FileAccess.WRITE).store_string(report)
	print("TOWER EXPANSION BALANCE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func row(scenario: String, kind: String, stage: Array, result: Dictionary) -> String:
	return "%s,%s,%d,%s,%.1f,%.1f\n" % [scenario, kind, stage[0], stage[1], result.clear * 100.0, result.gold / result.runs / (Duration / 60.0)]
