extends RefCounted

const Content = preload("res://scripts/content/registry.gd")

static func run(t) -> void:
	var assigned := {}
	for style in VigilWorld.ALL_STYLES:
		var portal := Content.portal(style)
		var kinds := portal.enemy_kinds()
		t.check(kinds.size() == 3, style + " has exactly three inhabitants")
		var game := VigilState.new(879)
		game.data.balance = 100000.0
		game.expand("1,0")
		game.expand("2,0")
		for id in ["1,0", "2,0"]:
			game.data.regions[id].style = style
			game.data.regions[id].timer = 8.0
		var costs := portal.unlock_costs()
		for kind in kinds:
			t.check(not assigned.has(kind) and Content.enemy(kind).is_a("enemy/" + style), "Each enemy inherits exactly its own biome family: " + kind)
			assigned[kind] = style
			var live := game.combat.spawn("1,0", kind)
			t.check(not live.is_empty() and live.pos == VigilWorld.center("1,0") and live.path[-1] == VigilWorld.CORE_POSITION, kind + " spawns on its own portal and routes to the core")
			var second := game.combat.spawn("2,0", kind)
			live.hp *= 0.5
			live.slow_until = 100.0
			t.check(second.hp == second.max_hp and not second.has("slow_until"), "Health and statuses are local to each " + kind)
			var pooled := {"slow_until": 100.0, "charges": {"1": 5}}
			Content.enemy(kind).create_into(pooled, 999, "2,0", second.path, style)
			t.check(not pooled.has("slow_until") and not pooled.has("charges") and pooled.hp == Balance.ENEMIES[kind].hp, "Recycling resets assigned enemy state: " + kind)
		for foreign in Balance.ENEMIES:
			if foreign not in kinds:
				t.check(game.combat.spawn("1,0", foreign).is_empty() and not game.economy.unlock("1,0", foreign), style + " rejects foreign spawns and purchases: " + foreign)
		for mask in range(1 << costs.size()):
			var unlocks: Array = []
			for index in range(costs.size()):
				if mask & (1 << index): unlocks.append(costs.keys()[index])
			var available := portal.available_kinds(unlocks)
			var mix := portal.spawn_mix(unlocks)
			var counts := {}
			for index in range(600):
				var kind := portal.choose_kind(unlocks, (index + 0.5) / 600.0)
				counts[kind] = counts.get(kind, 0) + 1
			var total := 0.0
			for kind in mix:
				total += mix[kind]
				t.check(kind in available and counts.get(kind, 0) == roundi(mix[kind] * 600), style + " selects available kinds at its configured share")
			t.check(is_equal_approx(total, 1.0), style + " probabilities sum to one")
		for kind in costs:
			t.check(game.economy.unlock("1,0", kind), style + " purchases its own attunements")
			t.check(game.data.regions["2,0"].unlocks.is_empty(), "Purchases never spread to another portal")
		game.combat.enemies.clear()
		game.combat.rng.seed = 9182
		var seen := {}
		for index in range(180):
			var enemy := game.combat.spawn("1,0")
			seen[enemy.kind] = true
			t.check(enemy.kind in kinds, "Natural spawning honors " + style + " roster")
		t.check(seen.size() == 3, "All three attuned " + style + " inhabitants naturally spawn")
		game.combat.enemies.clear()
		game.data.regions["1,0"].timer = 0.0
		game.combat.tick(Balance.STEP)
		t.check(game.combat.enemies.size() == 1 and game.combat.enemies[0].source == "1,0" and game.data.regions["2,0"].timer > 7.0, "Each portal owns its spawn timer")
		t.check(game.economy.buy_traffic("1,0") and game.data.regions["2,0"].traffic == 0, "Each portal owns its traffic upgrades")
		t.check(VigilState.new(879).data.regions["0,0"].unlocks.is_empty() and Content.portal(style).unlock_costs() == costs, "Sessions and shared definitions remain unchanged")
	t.check(assigned.size() == 18 and assigned.size() == Balance.ENEMIES.size(), "Six disjoint rosters cover all 18 enemies")
	t.check(Balance.ESCORT_KINDS == ["basic", "fast", "heavy", "lantern", "shade", "sentinel", "ruin_knight", "sepulcher"], "Saved numeric boss escort choices keep their original meaning")
	portal_presence(t)
	save_compatibility(t)
	print("PASS GROUP: 18 themed enemies, six exclusive rosters, portal transactions, probabilities, independent instances and legacy refunds")

static func portal_presence(t) -> void:
	for seed_value in [879, 123, 567]:
		var game := VigilState.new(seed_value)
		game.data.balance = 1.0e12
		for step in range(30):
			var frontier := VigilWorld.frontier(game.data.regions)
			var id: String = frontier.keys()[step % frontier.size()]
			t.check(not VigilWorld.has_rift(id, game.data.regions, seed_value), "Unclaimed land cannot expose a working portal")
			t.check(game.expand(id), "Connected territory unlocks")
			var style: String = game.data.regions[id].style
			if style != "castle_ruin":
				t.check(VigilWorld.has_rift(id, game.data.regions, seed_value) and not game.combat.spawn(id).is_empty(), "Every unlocked non-castle tile has a working centered portal")
			t.check(game.combat.spawn("0,0").is_empty(), "The receiving core portal never spawns onto itself")

static func save_compatibility(t) -> void:
	var game := VigilState.new(879)
	game.data.balance = 100000.0
	game.expand("1,0")
	var store := VigilSaveStore.new()
	var path := "user://portal-roster-migration.save"
	t.clean_test_save(path)
	for style in VigilWorld.ALL_STYLES:
		var portal := Content.portal(style)
		var snapshot := game.snapshot(1000.0)
		snapshot.regions["1,0"].style = style
		snapshot.regions["1,0"].unlocks = portal.rule("legacy_costs").keys()
		var original := snapshot.duplicate(true)
		var payload := JSON.stringify(snapshot, "", true, true)
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
		var loaded := store.read_candidate(path)
		t.check(not loaded.is_empty(), "Legacy " + style + " save remains readable")
		var refund: float = {"forest": 140.0, "ashen_forge": 270.0, "drowned_crypt": 410.0, "bloodmoon_sanctuary": 410.0, "castle_ruin": 1100.0, "mourning_orchard": 0.0}[style]
		t.check(loaded.balance == snapshot.balance + refund and snapshot == original, "Retired " + style + " attunements refund their original prices without mutating the source")
		for kind in loaded.regions["1,0"].unlocks:
			t.check(portal.unlock_costs().has(kind), "Reload retains only current portal purchases")
		t.check(store.migrate_portal_unlocks(loaded) == loaded, "Repeated normalization cannot duplicate gold")
		t.check(store.write(path, loaded) and store.read_candidate(path) == loaded, "Refunded progress round trips exactly")
		var build := JSON.stringify({"format": VigilSaveSlots.BUILD_FORMAT, "payload": payload, "checksum": payload.sha256_text()})
		t.check(VigilSaveSlots.new().decode_build(build) == loaded, "Creative build import uses the same migration")
		loaded.regions["1,0"].unlocks.append("missing_enemy")
		t.check(not store.valid_data(loaded), "Unknown saved attunements remain invalid")
	t.clean_test_save(path)
	for style in VigilWorld.ALL_STYLES:
		game.data.regions["1,0"].style = style
		game.data.regions["1,0"].unlocks = Balance.portal_unlock_costs(style).keys()
		for kind in Balance.portal_kinds(style): game.set_balance_stat("enemies", kind, "hp", 321.0)
		var snapshot := game.snapshot(1000.0)
		var expected: Dictionary = JSON.parse_string(JSON.stringify(snapshot, "", true, true))
		t.check(store.write(path, snapshot) and store.read_candidate(path) == expected, "New " + style + " purchases and tuning save exactly")
	t.clean_test_save(path)
