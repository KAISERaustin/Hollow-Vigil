extends "res://tests/test_runner.gd"
const CampaignSlots = preload("res://scripts/persistence/campaign_slots.gd")
const Run = preload("res://scripts/campaign/run.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")

func run() -> void:
	var battle := Run.new(0, {}, "creative")
	check(battle.build(6, "rapid"), "Checkpoint fixture builds a tower")
	var starting_gold: float = battle.game.data.balance
	check(battle.start_wave(), "Start checkpoint wave")
	var checkpoint: Dictionary = battle.checkpoint()
	check(Run.valid_checkpoint(checkpoint), "Campaign checkpoint validates with authored sockets")
	for i in 40: battle.tick(Balance.STEP)
	battle.game.data.balance += 999
	battle.build(9, "rapid")
	check(battle.checkpoint() == checkpoint, "Mid-wave gold and tower edits cannot change the starting checkpoint")
	var restored: RefCounted = Run.from_checkpoint(JSON.parse_string(JSON.stringify(battle.checkpoint(), "", true, true)))
	check(restored != null, "Checkpoint survives serialized round trip")
	if restored != null:
		check(restored.wave == 0 and restored.phase == "wave" and restored.wave_time == 0, "Continue restarts the same wave")
		check(restored.game.data.balance == starting_gold and restored.game.data.towers.size() == 1, "Continue restores starting resources and tower state together")
		check(restored.game.combat.enemies.is_empty(), "Continue has no stale live enemies")
		check(JSON.parse_string(JSON.stringify(restored.checkpoint())) == JSON.parse_string(JSON.stringify(checkpoint)), "Repeated continue does not advance checkpoint")
	var slots := CampaignSlots.new()
	slots.base_path = "user://unified-" + str(Time.get_ticks_usec())
	var before: Array = []
	for slot in 3:
		var saved := slots.create(slot, "creative" if slot == 0 else "survival", "Campaign " + str(slot + 1))
		check(not saved.is_empty(), "Campaign slot can be created")
		before.append(slots.summary(slot))
	check(slots.create(3, "creative", "Hidden fourth").is_empty(), "No fourth Campaign slot")
	check(slots.create(0, "survival", "Unconfirmed replacement").is_empty(), "Occupied slot cannot be silently replaced")
	var saved: Dictionary = before[0].duplicate(true)
	saved.checkpoint = checkpoint
	var mismatched := saved.duplicate(true)
	mismatched.mode = "survival"
	check(not CampaignSlots.valid(mismatched), "Campaign slot cannot change play style through its checkpoint")
	check(slots.save_slot(0, saved), "Campaign persists incomplete wave")
	check(slots.summary(1) == before[1] and slots.summary(2) == before[2], "Saving one Campaign leaves siblings untouched")
	check(slots.replace(0, before[1]), "Confirmed replacement preserves recoverable game")
	check(slots.summary(0).id == before[1].id, "Replacement uses chosen game identity")
	var game := VigilState.new(7331, "creative")
	check(game.set_balance_stat("enemies", "basic", "hp", 431), "Configure individual enemy")
	check(game.set_balance_stat("bosses", "warden", "hp", 4567), "Configure independent boss")
	var selected := {"enemies": ["basic"]}
	var build := Build.capture("infinite", game, {}, "all", -1, selected, "One enemy", "Selected contents only")
	check(not build.is_empty(), "Capture individual enemy stats")
	if not build.is_empty():
		check(build.data.stats.keys() == ["enemies"] and build.data.stats.enemies.keys() == ["basic"], "No boss or sibling stats silently included")
		var decoded := Build.decode(Build.encode(build))
		check(JSON.parse_string(JSON.stringify(decoded)) == JSON.parse_string(JSON.stringify(build)), "Selected content round trip")
		var fresh := Build.infinite_snapshot(decoded, {}, "survival")
		check(fresh.ok and fresh.snapshot.towers.is_empty() and fresh.snapshot.regions.size() == 1, "Stats only starts a fresh world")
		check(fresh.snapshot.settings.developer_balance.enemies.basic.hp == 431, "Selected stats apply to new Survival game")
		check(not fresh.snapshot.settings.developer_balance.has("bosses"), "Omitted bosses use original defaults")
		var campaign := Build.compose_campaign(decoded, {"apply_to": "level", "target_level": 2})
		check(campaign.ok and campaign.levels.keys() == ["2"], "Portable stats target only explicitly selected Campaign level")
		check(not Build.compose_campaign(decoded, {}).ok, "Portable Campaign stats require scope choice")
	var all := Build.all_contents("campaign")
	var campaign_build := Build.capture("campaign", null, {}, "all", -1, all, "Full campaign", "")
	check(not campaign_build.is_empty(), "All Campaign contents capture")
	if not campaign_build.is_empty():
		check(Build.compose_campaign(campaign_build, {}).ok, "Whole campaign composes validated fresh levels")
		check(not Build.infinite_snapshot(campaign_build, {}, "creative").ok, "Whole Campaign stats require explicit source level in Infinite")
		check(Build.infinite_snapshot(campaign_build, {"source_level": 4}, "creative").ok, "Explicit Campaign level stats are portable")
	var library := VigilSaveSlots.new()
	library.base_path = slots.base_path
	var code := Build.encode(build)
	check(library.save_shared(code) and library.save_shared(code), "Private saving works offline and is idempotent")
	check(library.shared_configurations("all").size() == 1, "One exact build occupies one library entry")
	check(not library.occupied(0), "Private build saving never occupies an Infinite slot")
	game.set_balance_stat("session", "start", "starting_gold", 912.0)
	var resources := Build.capture("infinite", game, {}, "all", -1, {"resources": true}, "Starting gold", "")
	check(Build.infinite_snapshot(resources, {}, "survival").snapshot.balance == 912.0, "Selected resources preserve an explicitly edited starting-gold rule")
	var fixtures := FileAccess.open("res://artifacts/unified-cloud-fixtures.json", FileAccess.WRITE)
	var cloud_campaign: Dictionary = before[0].duplicate(true)
	cloud_campaign.checkpoint = checkpoint
	fixtures.store_string(JSON.stringify({"campaign": cloud_campaign, "infinite": game.data, "build": code}))
	fixtures.close()
	test_content_extension()
	test_grouped_contents()
	test_combinations()
	test_wave_and_equipment()
	var corrupted := FileAccess.open(slots.path_for(2), FileAccess.WRITE)
	corrupted.store_string("{ damaged test save")
	corrupted.close()
	check(slots.summary(2).is_empty() and slots.occupied(2), "Unreadable save remains occupied and cannot be overwritten")
	check(not slots.replace(2, before[1]), "Unreadable slot blocks replacement")
	print("UNIFIED_PERSISTENCE: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func test_content_extension() -> void:
	var original := Balance.Content.catalog()
	var registry := Balance.Content.new()
	Balance.Content._shared = registry
	for entry in [["enemies", "basic"], ["bosses", "warden"], ["towers", "rapid"]]:
		var category: String = entry[0]
		var parent: VigilContentNode = registry.find(category, entry[1])
		var node := parent.derive(parent.id + "_fixture", {"name": "Registered fixture"}, {"kind": "fixture"})
		check(registry.register_node(node, category, "fixture"), "One registration extends " + category)
		var group: VigilContentNode = registry.find("build_contents", category)
		check("fixture" in group.types(), "New registered type appears in " + category + " checklist without menu changes")
		check("fixture" in Build.all_contents("infinite", "rules")[category], "Rules option automatically includes new registered " + category)
		var value := Build.capture("infinite", VigilState.new(), {}, "all", -1, {category: ["fixture"]}, "Extension fixture", "")
		check(not value.is_empty() and not Build.decode(Build.encode(value)).is_empty(), "New type captures and round trips through " + category)
		if not value.is_empty(): check(value.data.stats[category].keys() == ["fixture"], "New type selection excludes parent and siblings")
	Balance.Content._shared = original
	check(not Build.all_contents("infinite").enemies.has("fixture"), "Fixture registration leaves unrelated catalog unchanged")

func test_grouped_contents() -> void:
	var partial := {"enemies": ["basic"]}
	var grouped := Build.grouped_contents("infinite", partial)
	check(partial == {"enemies": ["basic"]}, "Grouping an older build does not mutate its saved selection")
	check(grouped == Build.all_contents("infinite", "rules"), "Reopening a partial rules build selects all rules and resources")
	check(Build.grouped_contents("infinite", {"layout": true}) == {"layout": true, "terrain": true}, "Older layouts select explored tiles with equipment")
	check(Build.grouped_contents("infinite", {"terrain": true}) == {"layout": true, "terrain": true}, "Older terrain builds select layout and equipment together")
	check(Build.grouped_contents("campaign", {"timing": true}) == Build.all_contents("campaign", "rules"), "Campaign wave options join the complete rules group")
	check(Build.grouped_contents("campaign", {"layout": true}).is_empty(), "Campaign exports do not offer layout or equipment")
	var game := VigilState.new(845, "creative")
	var before := game.data.duplicate(true)
	for type in ["infinite", "campaign"]:
		for option in ["rules", "layout", ""]:
			var selected := Build.all_contents(type, option)
			if selected.is_empty(): continue
			var captured := Build.capture(type, game, {}, "level" if type == "campaign" else "all", 0, selected, "Grouped build", "")
			check(not captured.is_empty(), "Grouped " + type + " build captures " + option)
			if captured.is_empty(): continue
			var decoded := Build.decode(Build.encode(captured))
			check(not decoded.is_empty() and decoded.contents == selected, "Grouped " + type + " selection survives saving " + option)
			var composed := Build.compose_campaign(decoded, {}) if type == "campaign" else Build.infinite_snapshot(decoded, {}, "survival")
			check(composed.ok, "Grouped " + type + " build starts a fresh game " + option)
	check(game.data == before, "Capturing either group leaves the active session unchanged")

func test_combinations() -> void:
	var source := VigilState.new(73, "creative")
	for type in ["campaign", "infinite"]:
		var groups := Build.all_contents(type)
		var keys := groups.keys()
		for mask in range(1, 1 << keys.size()):
			var selected := {}
			for index in keys.size():
				if mask & (1 << index): selected[keys[index]] = groups[keys[index]]
			var value := Build.capture(type, source, {}, "level" if type == "campaign" else "all", 0, selected, "Combination", "")
			check(not value.is_empty(), "%s selection %d is independently composable" % [type, mask])
			if value.is_empty(): continue
			var decoded := Build.decode(Build.encode(value))
			check(not decoded.is_empty(), "%s selection %d survives serialization" % [type, mask])
			var composed := Build.compose_campaign(decoded, {}) if type == "campaign" else Build.infinite_snapshot(decoded, {}, "survival")
			check(composed.ok, "%s selection %d starts a fresh game" % [type, mask])

func test_wave_and_equipment() -> void:
	var level := Run.new(0, {}, "creative")
	check(level.build(6, "rapid"), "Layout fixture builds on an authored socket")
	level.game.data.relics["0,0"] = "warden"
	var tower: Dictionary = level.game.data.towers.values()[0]
	tower.relic = "0,0"
	var loadout := Build.clean_loadout(level.game.data)
	loadout.balance = level.game.data.balance
	var levels := {"0": {"overrides": {"gold": 500.0, "waves": {"0": {"groups": [["fast", 2, 0, 0.0, 0.5], ["basic", 3, 0, 2.0, 0.5]], "reward": 99.0}}}, "loadout": loadout}}
	var partial := Build.capture("campaign", level.game, levels, "level", 0, {"timing": true}, "Timing", "")
	check(not partial.is_empty(), "Incompatible group count remains readable for review")
	check(not Build.compose_campaign(partial, {}).ok, "Timing cannot silently replace enemy composition")
	var selected := {"timing": true, "composition": true, "resources": true, "rewards": true, "layout": true}
	check(Build.capture("campaign", level.game, levels, "level", 0, {"layout": true}, "Layout only", "").is_empty(), "Campaign cannot export only layout or equipment")
	var build := Build.capture("campaign", level.game, levels, "level", 0, selected, "Wave and layout", "")
	check(selected.has("layout") and level.game.data.relics == {"0,0": "warden"}, "Export filtering leaves source contents and owned equipment untouched")
	check(not build.is_empty() and not build.contents.has("layout"), "Campaign export strips requested layout while keeping wave content")
	if not build.is_empty():
		var composed := Build.compose_campaign(Build.decode(Build.encode(build)), {})
		check(composed.ok and composed.levels.keys() == ["0"], "One-level contents leave all other levels at defaults")
		check(composed.levels["0"].overrides.gold == 500.0 and composed.levels["0"].overrides.waves["0"].reward == 99.0, "Selected starting gold and wave rewards retain independent values")
		check(not composed.levels["0"].has("loadout"), "Fresh Campaign from exported content has no placed towers or owned equipment")
		# Earlier portable builds keep loading, but resaving them removes layouts.
		var legacy := build.duplicate(true)
		legacy.contents.layout = true
		legacy.data.levels["0"].layout = Build.clean_loadout(level.game.data)
		check(not Build.decode(Build.encode(legacy)).is_empty(), "Legacy Campaign layouts remain readable")
		check(Build.compose_campaign(legacy, {}).levels["0"].loadout.relics == {"0,0": "warden"}, "Legacy imports preserve existing equipment")
	level.start_wave()
	var restored: RefCounted = Run.from_checkpoint(JSON.parse_string(JSON.stringify(level.checkpoint())))
	check(restored != null and restored.game.data.relics == level.game.data.relics and restored.game.data.towers.values()[0].relic == "0,0", "Complete checkpoint restores equipment with its tower")
