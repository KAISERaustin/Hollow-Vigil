extends RefCounted

const Bosses = preload("res://scripts/gameplay/encounters/bosses.gd")
const Fixtures = preload("res://tests/unit/boss_checks.gd")

static func run(t) -> void:
	for seed_value in [1, 879, 42178]:
		for y in range(-2, 3):
			for x in range(-2, 3):
				var id := VigilWorld.key(Vector2i(x, y))
				var region := VigilWorld.make_region(id, "0,0", seed_value)
				t.check(region.style == "forest" and not VigilWorld.is_ruin(id, seed_value), "Opening square is forest without ruin overlays")
				t.check(Bosses.kind_at(id, seed_value) == "" and Bosses.Clusters.at(id, seed_value).boss_tile == "", "Opening forest cluster has no boss")
				t.check(VigilWorld.has_rift(id, {id: region}, seed_value) == (id != "0,0"), "Opening tiles retain ordinary portals")
	var styles := {}
	for seed_value in [1, 879, 42178]:
		var visited := {}
		for y in range(-12, 13):
			for x in range(-12, 13):
				var id := VigilWorld.key(Vector2i(x, y))
				if visited.has(id):
					continue
				var cluster := Bosses.Clusters.at(id, seed_value)
				styles[cluster.style] = true
				var sites := 0
				for cell in cluster.cells:
					var tile := VigilWorld.key(cell)
					visited[tile] = true
					var same := Bosses.Clusters.at(tile, seed_value)
					t.check(same == cluster and VigilWorld.region_style(tile, seed_value) == cluster.style, "Connected visible biome shares one stable encounter site")
					if tile == cluster.boss_tile:
						sites += 1
					for direction in VigilWorld.DIRS:
						var neighbor: Vector2i = cell + direction
						if VigilWorld.region_style(VigilWorld.key(neighbor), seed_value) == cluster.style:
							t.check(cluster.cells.has(neighbor), "Cluster includes every edge-connected biome tile after overlays")
				t.check(sites == (0 if cluster.cells.has(Vector2i.ZERO) else 1) and cluster.boss_tile != "0,0", "One boss per outer biome cluster; none in starting forest")
				Bosses.Clusters._cache.clear()
				t.check(Bosses.Clusters.at(VigilWorld.key(cluster.cells[-1]), seed_value) == cluster, "Encounter tile survives cache eviction and reverse discovery")
	t.check(styles.size() == 6, "Cluster coverage includes all six biomes")
	for kind in Bosses.TYPES:
		for reverse_order in [false, true]:
			var game := Fixtures.fixture(kind)
			var source: String = game.combat.enemies[0].source
			var cluster := Bosses.Clusters.at(source, int(game.data.seed))
			game.data.regions[source].erase("boss")
			game.combat.enemies.clear()
			var pending: Array = cluster.cells.duplicate()
			if reverse_order:
				pending.reverse()
			while not pending.is_empty():
				var progress := false
				for cell in pending.duplicate():
					var tile := VigilWorld.key(cell)
					if game.data.regions.has(tile) or game.expand(tile):
						pending.erase(cell)
						progress = true
				t.check(progress, "Cluster tiles can be purchased through connected territory")
				if not progress:
					break
			for cell in cluster.cells:
				if VigilWorld.key(cell) != source:
					Bosses.awaken(game.combat, VigilWorld.key(cell))
			t.check(active_in_cluster(game, cluster).is_empty(), "Every non-encounter tile stays boss-free: " + kind)
			Bosses.awaken(game.combat, source)
			t.check(active_in_cluster(game, cluster).size() == 1, "Only the fixed encounter tile awakens the cluster boss: " + kind)
			migration(t, game, cluster)
	print("PASS GROUP: one deterministic boss per connected biome cluster, purchase order and per-tile save migration")

static func active_in_cluster(game: VigilState, cluster: Dictionary) -> Array:
	return game.combat.enemies.filter(func(e): return e.get("boss", false) and not e.dead and cluster.cells.has(VigilWorld.coord(e.source)))

static func migration(t, game: VigilState, cluster: Dictionary) -> void:
	var source: String = cluster.boss_tile
	var boss: Dictionary = active_in_cluster(game, cluster)[0]
	boss.hp -= 125.0
	var expected_hp: float = boss.hp
	game.data.balance = 100000.0
	var gold: float = game.data.balance
	# Reproduce the previous release's active per-tile encounters.
	for cell in cluster.cells:
		var tile := VigilWorld.key(cell)
		if tile != source and tile != "0,0":
			Bosses.create(game.combat, tile, boss.kind)
	game.save_path = "user://cluster-boss-migration.save"
	t.clean_test_save(game.save_path)
	t.check(game.save(1000), "Previous per-tile bosses remain readable for migration")
	var restored := VigilState.new()
	restored.save_path = game.save_path
	t.check(restored.load_save(1000), "Per-tile boss save reloads")
	var active := active_in_cluster(restored, cluster)
	t.check(active.size() == 1 and active[0].source == source and active[0].hp == expected_hp, "Migration retains canonical boss damage and removes duplicate active bosses")
	t.check(restored.data.balance == gold and restored.data.kills == game.data.kills, "Removing duplicates awards no gold or kills")
	t.check(restored.save(1000) and restored.load_save(1000) and active_in_cluster(restored, cluster).size() == 1, "Repeated save/load cannot resurrect duplicates")
	# A victory on any old tile completes the whole cluster; preserve its relic.
	var completed_source := source
	for cell in cluster.cells:
		var tile := VigilWorld.key(cell)
		if tile == source or tile == "0,0":
			continue
		completed_source = tile
		break
	if completed_source == source:
		active_in_cluster(restored, cluster)[0].dead = true
	Bosses.record(restored.combat, completed_source).boss = {"status": "defeated", "kind": boss.kind}
	if Balance.GEAR.has(boss.kind):
		restored.data.relics[completed_source] = boss.kind
	var relics: Dictionary = restored.data.relics.duplicate()
	const Relics = preload("res://scripts/gameplay/progression/relics.gd")
	for gear_kind in Relics.BOSS_DROPS[boss.kind]:
		relics[Relics.drop_id(completed_source, gear_kind, boss.kind)] = gear_kind
	t.check(restored.save(1000) and restored.load_save(1000), "Completed cluster migration round trips")
	t.check(active_in_cluster(restored, cluster).is_empty() and restored.data.relics == relics, "A prior victory suppresses the entire cluster, preserves earned relics and fills its equipment set")
	for cell in cluster.cells:
		Bosses.awaken(restored.combat, VigilWorld.key(cell))
	t.check(active_in_cluster(restored, cluster).is_empty(), "Completed cluster cannot respawn from a different tile")
	t.clean_test_save(game.save_path)
