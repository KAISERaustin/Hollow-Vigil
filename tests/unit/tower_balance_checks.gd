extends RefCounted

const DURATION := 120.0
const SEEDS := [123, 314, 879]

static func run(suite: SceneTree) -> void:
	var report := "scenario,tower,level,investment,defeats,escapes,clear_percent,gold_per_minute\n"
	for kind in Balance.TOWERS:
		var opening := sample(suite, [kind], 1, 0, false)
		suite.check(opening.clear >= 0.8, "%s is a viable first tower against basic starting traffic" % kind)
		report += row("opening", kind, 1, opening)
		for traffic in [0, Balance.MAX_TRAFFIC_LEVEL]:
			var first := 0.0
			var previous := 0.0
			for level in [1, 2, 3]:
				var result := sample(suite, [kind], level, traffic, true)
				suite.check(result.gold >= previous, "%s level %d does not lose mixed-traffic income at traffic %d" % [kind, level, traffic])
				if level == 1:
					first = result.gold
				if level == 3 and traffic == Balance.MAX_TRAFFIC_LEVEL:
					suite.check(result.gold >= first * 1.25, "%s's two upgrades meaningfully improve maximum-traffic production" % kind)
				previous = result.gold
				report += row("mixed-traffic-%d" % traffic, kind, level, result)
	var combined := sample(suite, ["rapid", "splash", "heavy"], 3, Balance.MAX_TRAFFIC_LEVEL, true)
	suite.check(combined.clear >= 0.95, "Three complementary level-three towers can handle a maximum-traffic mixed rift")
	report += row("mixed-traffic-12", "combined", 3, combined)
	FileAccess.open("res://artifacts/tower-balance.csv", FileAccess.WRITE).store_string(report)
	print("PASS GROUP: tower balance across three seeds, four approaches, basic openings and mixed rifts at base/max traffic")

static func sample(suite: SceneTree, kinds: Array, level: int, traffic: int, mixed: bool) -> Dictionary:
	var total := {"kills": 0.0, "escapes": 0.0, "gold": 0.0, "runs": 0.0, "investment": 0.0}
	for seed_value in SEEDS:
		for direction in VigilWorld.DIRS:
			var g := VigilState.new(seed_value)
			g.combat.rng.seed = seed_value
			g.data.balance = 100000.0
			var region := VigilWorld.key(direction)
			g.expand(region)
			g.data.regions[region].traffic = traffic
			if mixed:
				g.data.regions[region].unlocks = ["fast", "heavy"]
			# Use the core socket facing the approach; rotate the additional towers
			# through the remaining sockets so all four directions are represented.
			var pad := 0 if direction.x < 0 or direction.y < 0 else (1 if direction.x > 0 else 2)
			var invested := 0.0
			for index in range(kinds.size()):
				var id := g.economy.build(kinds[index], "0,0", (pad + index) % 4)
				invested += Balance.TOWERS[kinds[index]].cost
				for current in range(1, level):
					invested += Balance.upgrade_cost(g.data.towers[id])
					g.economy.upgrade(id, current)
			suite.advance(g, DURATION)
			# Stop spawning and let the same two-minute cohort finish its route.
			g.data.regions[region].timer = 1000.0
			suite.advance(g, 30.0)
			total.kills += g.data.kills
			total.escapes += g.data.escapes
			total.gold += g.data.lifetime_earnings
			total.runs += 1.0
			total.investment = invested
	total.clear = total.kills / (total.kills + total.escapes)
	return total

static func row(scenario: String, kind: String, level: int, result: Dictionary) -> String:
	return "%s,%s,%d,%.0f,%.0f,%.0f,%.1f,%.1f\n" % [scenario, kind, level, result.investment, result.kills, result.escapes, result.clear * 100.0, result.gold / result.runs / (DURATION / 60.0)]
