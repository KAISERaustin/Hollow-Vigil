extends "res://tests/test_runner.gd"

const Stats = preload("res://scripts/content/catalogs/stats.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Slots = preload("res://scripts/persistence/campaign_slots.gd")
const Migration = preload("res://scripts/persistence/stats_migration.gd")

func unit(g: VigilState, id: String = "tower", kind: String = "rapid") -> Dictionary:
	var tower := Balance.Content.tower(kind).create(id, "0,0", 0)
	g.data.towers[id] = tower
	return tower

func spawn(g: VigilState, kind: String = "basic") -> Dictionary:
	g.combat.scripted_spawns = true
	return g.combat.spawn_on_path(kind, [Vector2.ZERO, Vector2(0, 1000)])

func run() -> void:
	for category in ["enemies", "bosses", "towers"]:
		for kind in Stats.Frozen.VALUES[category]:
			var node = Balance.Content.catalog().find(category, kind)
			check(node.is_a("stats"), category + "/" + kind + " inherits Stats")
			var actual: Dictionary = node.stats() if category == "towers" else node.definition()
			for field in Stats.Frozen.VALUES[category][kind]:
				if not Stats.editable_stat(category, field): continue
				check(is_equal_approx(Balance.configuration_value(category, kind, field), Stats.Frozen.VALUES[category][kind][field]), "Frozen default " + category + "/" + kind + "/" + field)
				check(is_equal_approx(float(actual[field]), Stats.Frozen.VALUES[category][kind][field]), "Runtime matches frozen default " + kind + "/" + field)
			check(Balance.valid_tuning(Stats.reset({}, category, kind)), "Reset is valid " + category + "/" + kind)
			if category == "towers":
				check(not Balance.valid_tuning(Stats.edit({}, category, kind, "enabled_splash", 0)), "Cannot disable tower blast radius " + kind)
				check(Balance.valid_tuning(Stats.edit({}, category, kind, "splash", 0)), "Tower blast radius accepts zero " + kind)
			if category in ["enemies", "bosses"]:
				for required in ["payout", "escape_damage"]:
					check(not Balance.valid_tuning(Stats.edit({}, category, kind, "enabled_" + required, 0)), "Cannot disable " + category + "/" + kind + "/" + required)
					check(Balance.valid_tuning(Stats.edit({}, category, kind, required, 12)), "Required value remains editable " + category + "/" + kind + "/" + required)
			for ability in Stats.capabilities(category):
				if category != "towers" or ability.begins_with("gear_"): continue
				var candidate := Stats.attach({}, category, kind, ability)
				check(Balance.valid_tuning(candidate), "Attachment validates " + category + "/" + kind + "/" + ability)
				check(Stats.ability_enabled(category, kind, ability, candidate), "Attachment is enabled " + ability)
	var game := VigilState.new(971)
	var tower := unit(game)
	check(game.set_tower_tier_stat("rapid", "damage", 123), "Base tier edit succeeds")
	check(Balance.stats("rapid", 2, game.tuning).damage == 10, "Tier two remains independent")
	check(game.set_tower_tier_stat("rapid:2", "cost", 777), "Upgrade cost edit")
	check(Balance.upgrade_cost(tower, game.tuning) == 777, "Economy uses independent upgrade cost")
	var enemy := spawn(game)
	enemy.hp = enemy.max_hp * 0.4
	tower.cooldown = 0.24
	check(game.set_balance_stat("enemies", "basic", "hp", 200), "Live health edit")
	check(is_equal_approx(enemy.hp, 80) and enemy.max_hp == 200, "Live enemy preserves health percentage")
	check(game.set_balance_stat("towers", "rapid", "period", 0.8), "Live tower edit")
	check(is_equal_approx(tower.cooldown, 0.4), "Live cooldown preserves progress")
	check(game.reset_developer_balance("enemies", "basic"), "Reset selected enemy")
	check(enemy.max_hp == 45, "Reset restores frozen health")
	check(Balance.stats("rapid", 1, game.tuning).damage == 123, "Reset preserves other entities")
	check(not Balance.valid_tuning({"towers": {"rapid": {"hp": 100}}}), "Reject tower health")
	check(not Balance.valid_tuning({"enemies": {"basic": {"enabled_hp": 0}}}), "Reject disabling essential health")
	check(not Balance.valid_tuning({"enemies": {"basic": {"poison_resistance": 101}}}), "Resistance bounds")
	check(not Balance.valid_tuning({"enemies": {"basic": {"unknown_stat": 3}}}), "Reject unknown catalog entry")
	transferred_attacks()
	var migrated := Migration.tuning({"towers": {"rapid": {"damage": 12.0, "cost": 120.0}}})
	check(migrated.towers["rapid:2"].damage == 20 and migrated.towers["rapid:2"].cost == 120, "Legacy inherited tier values migrate to absolute values")
	check(not Balance.valid_tuning({"towers": {"rapid": {"use_road_traps": 1, "use_returning_attack": 1}}}), "Imports reject conflicting primary attacks")
	var disabled := Stats.compact({"enemies": {"basic": {"poison_resistance": 65, "enabled_poison_resistance": 0}}})
	check(not Stats.enabled("enemies", "basic", "poison_resistance", disabled) and Stats.value("enemies", "basic", "poison_resistance", disabled) == 65, "Save compaction retains disabled custom values")
	var warden_health := []
	for index in range(30):
		var run := Run.new(index, {}, "creative")
		warden_health.append(Balance.definition("bosses", "warden", run.game.tuning).hp)
	check(warden_health.all(func(hp): return hp == 3200), "All 30 levels use identical Warden defaults")
	var live := Run.new(0, {}, "creative")
	var live_enemy := spawn(live.game)
	live_enemy.hp = 9
	check(live.apply_configuration({"tuning": {"enemies": {"basic": {"hp": 90}}}}), "Campaign applies stat changes")
	check(live_enemy.max_hp == 90 and is_equal_approx(live_enemy.hp, 18), "Campaign updates live enemy immediately")
	var levels := Migration.levels({"0": {"overrides": {"tuning": game.tuning}}, "4": {"overrides": {"tuning": {"bosses": {"warden": {"hp": 1800.0, "shield": 300.0, "regen_period": 12.0}}}}}})
	check(levels.size() == 30 and levels["0"].overrides.tuning == levels["29"].overrides.tuning, "Rules global across all levels")
	var slots := Slots.new()
	slots.base_path = "res://.runtime/stats-slot-" + str(Time.get_ticks_usec())
	var first := slots.create(0, "creative", "Edited", levels)
	var other := slots.create(1, "creative", "Independent")
	check(not first.is_empty() and not other.is_empty(), "Save slots persist valid rules")
	check(slots.summary(0).levels["0"].overrides.tuning == levels["0"].overrides.tuning, "Slot readback preserves stats and attachments")
	check(slots.summary(1).levels["0"].overrides.tuning.is_empty(), "Other slot remains unchanged")
	var code := preload("res://scripts/persistence/stat_configuration.gd").encode(game.tuning, "Stats")
	check(not code.is_empty() and preload("res://scripts/persistence/stat_configuration.gd").decode(code).tuning == game.tuning, "Portable stats roundtrip")
	var exported := preload("res://scripts/persistence/reusable_build.gd").selected_stats(game.tuning, {"enemies": ["basic"], "towers": ["rapid"]})
	check(exported.enemies.basic.enabled_poison_resistance == 0, "Selective build exports preserve disabled membership")
	var all_defaults := {}
	for category in ["enemies", "bosses", "towers"]:
		for kind in Stats.Frozen.VALUES[category]: all_defaults = Stats.reset(all_defaults, category, kind)
	var all_levels := Migration.levels({"0": {"overrides": {"tuning": all_defaults}}})
	var full_code := preload("res://scripts/persistence/campaign_playthrough.gd").encode(all_levels, "All defaults", "")
	check(not full_code.is_empty(), "Full reset of all 64 definitions remains exportable")
	print("STATS SYSTEM: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)

func transferred_attacks() -> void:
	var game := VigilState.new(973)
	var tower := unit(game, "tower", "heavy")
	var enemy := spawn(game, "sepulcher")
	for ability in ["frostneedle", "thorn_volley", "vulnerability_mark"]:
		check(game.apply_balance(Stats.attach(game.tuning, "towers", "heavy", ability)), "Transfer " + ability)
	var shot := game.combat.Projectiles.make_shot(game.combat, tower, Vector2.ZERO, enemy, game.combat.tower_stats(tower))
	game.combat.resolve_shot(shot, enemy)
	check(enemy.get("slow_percent", 0) == 25, "Transferred frost works")
	check(enemy.get("gear_status", {}).values().any(func(s): return s.type == "dot"), "Transferred poison works")
	check(game.combat.Relics.strength(enemy, "expose", 0) == 75, "Transferred hex works")
	check(game.apply_balance(Stats.attach(game.tuning, "towers", "heavy", "thorn_volley", false)), "Disable transferred poison")
	game.combat.Relics.advance(game.combat, 0.05)
	check(not enemy.get("gear_status", {}).values().any(func(s): return s.type == "dot"), "Removed poison cleans active status")
	var candidate := Stats.attach(game.tuning, "towers", "heavy", "road_traps")
	candidate = Stats.attach(candidate, "towers", "heavy", "returning_attack")
	check(not Stats.ability_enabled("towers", "heavy", "road_traps", candidate), "Primary attack replacement is exclusive")
