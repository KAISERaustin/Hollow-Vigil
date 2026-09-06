extends RefCounted

static func run(suite: SceneTree) -> void:
	test_info_catalog(suite)

static func test_info_catalog(suite: SceneTree) -> void:
	var catalog = preload("res://scripts/ui/info_catalog.gd")
	var definitions: Dictionary = Balance.TOWERS.duplicate(true)
	var extra: Dictionary = definitions.rapid.duplicate(true)
	extra.name = "Future sentinel"
	extra.damage = 7.25
	extra.splash = 18.5
	definitions["future"] = extra
	var before := definitions.duplicate(true)
	var entries: Array[Dictionary] = catalog.build_entries(definitions, catalog.SECTIONS.towers.stats)
	suite.check(entries.size() == Balance.TOWERS.size() + 1 and entries.back().name == "Future sentinel", "New definitions appear in the guide without a new UI branch")
	suite.check({"label": "Damage per hit", "value": "7.25"} in entries.back().stats, "Guide preserves fractional damage for future content")
	suite.check({"label": "Blast radius", "value": "18.5 units"} in entries.back().stats, "New splash towers display their mechanic automatically")
	suite.check(definitions == before, "Building guide entries never mutates gameplay definitions")
	var g := VigilState.new(51)
	for entry in catalog.entries("enemies"):
		var enemy: Dictionary = suite.fixture_enemy(g, entry.id)
		suite.check({"label": "Health", "value": String.num(enemy.max_hp, 2).trim_suffix(".0") + " HP"} in entry.stats, "Guide health matches spawned " + entry.name)
	suite.check(catalog.entries("towers").size() == Balance.TOWERS.size() and catalog.entries("enemies").size() == Balance.ENEMIES.size(), "Guide includes every defined tower and enemy, regardless of unlock state")
	for entry in catalog.entries("towers"):
		for level in [1, 2]:
			var cost := Balance.upgrade_cost({"kind": entry.id, "level": level})
			suite.check({"label": "Level %d upgrade" % (level + 1), "value": String.num(cost, 0) + " gold"} in entry.stats, "Guide quotes each purchasable upgrade for " + entry.name)
	print("PASS GROUP: reusable info catalog and live gameplay stats")
