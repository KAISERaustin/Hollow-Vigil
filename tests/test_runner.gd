extends SceneTree

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func advance(g: VigilState, seconds: float) -> void:
	for i in range(int(seconds / Balance.STEP)):
		g.combat.tick(Balance.STEP)

func fixture_enemy(g: VigilState, kind: String = "basic") -> Dictionary:
	# Generic combat fixtures use only their authored targets, not biome bosses.
	for encounter in g.combat.enemies.duplicate():
		if encounter.get("boss", false):
			g.combat.enemies.erase(encounter)
	if kind in Balance.ORCHARD_KINDS:
		var gate := preload("res://tests/support/orchard_fixture.gd").populate(g)
		return g.combat.spawn(gate, kind)
	if not g.data.regions.has("-1,0"):
		var balance: float = g.data.balance
		g.data.balance += Balance.expansion_cost(g.data.regions.size())
		g.expand("-1,0")
		g.data.balance = balance
		g.combat.enemies.clear()
	g.data.regions["-1,0"].style = Balance.enemy_portal_style(kind)
	var enemy := g.combat.spawn("-1,0", kind)
	# Generic combat assertions isolate base stats after using the real roster.
	enemy.rift_style = "forest"
	enemy.hp = Balance.tuned_value("enemies", kind, "hp", g.tuning)
	enemy.max_hp = enemy.hp
	return enemy

func legacy_core_fixture(seed_value: int) -> VigilState:
	# Existing core-only progress can build without new-game onboarding.
	var game := VigilState.new(seed_value)
	game.data.erase("first_property_required")
	return game

func clean_test_save(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func run() -> void:
	preload("res://tests/unit/content_node_checks.gd").run(self)
	preload("res://tests/unit/portal_roster_checks.gd").run(self)
	preload("res://tests/unit/portal_visual_checks.gd").run(self)
	preload("res://tests/unit/orchard_checks.gd").run(self)
	preload("res://tests/unit/rift_checks.gd").run(self)
	preload("res://tests/unit/economy_checks.gd").run(self)
	preload("res://tests/unit/tower_economy_checks.gd").run(self)
	preload("res://tests/unit/relocation_checks.gd").run(self)
	preload("res://tests/unit/tower_progression_checks.gd").run(self)
	preload("res://tests/unit/tower_balance_checks.gd").run(self)
	preload("res://tests/unit/combat_checks.gd").run(self)
	preload("res://tests/unit/spatial_checks.gd").run(self)
	preload("res://tests/unit/enemy_checks.gd").run(self)
	preload("res://tests/unit/attack_effect_checks.gd").run(self)
	preload("res://tests/unit/electric_checks.gd").run(self)
	preload("res://tests/unit/developer_balance_checks.gd").run(self)
	preload("res://tests/unit/developer_tier_checks.gd").run(self)
	preload("res://tests/unit/world_checks.gd").run(self)
	preload("res://tests/unit/routing_checks.gd").run(self)
	preload("res://tests/unit/terrain_checks.gd").run(self)
	preload("res://tests/unit/hidden_area_checks.gd").run(self)
	preload("res://tests/unit/castle_checks.gd").run(self)
	preload("res://tests/unit/boss_checks.gd").run(self)
	preload("res://tests/unit/biome_cluster_boss_checks.gd").run(self)
	preload("res://tests/unit/relic_checks.gd").run(self)
	preload("res://tests/unit/gear_catalog_checks.gd").run(self)
	preload("res://tests/unit/gear_rework_checks.gd").run(self)
	preload("res://tests/unit/persistence_checks.gd").run(self)
	preload("res://tests/unit/review_regressions.gd").run(self)
	preload("res://tests/unit/input_checks.gd").run(self)
	preload("res://tests/unit/simulation_checks.gd").run(self)
	check(checks >= 312, "All test groups reached their assertions")
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	var report: String = "Hollow Vigil — automated verification\nGodot " + Engine.get_version_info().string + "\n\n%d checks, %d failures\n" % [checks, failures.size()]
	for failure in failures:
		report += "FAIL: " + failure + "\n"
	var f := FileAccess.open("res://artifacts/test-results.txt", FileAccess.WRITE)
	f.store_string(report)
	f.close()
	quit(0 if failures.is_empty() else 1)
