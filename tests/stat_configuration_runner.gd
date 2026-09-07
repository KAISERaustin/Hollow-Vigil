extends "res://tests/test_runner.gd"

const Stats = preload("res://scripts/persistence/stat_configuration.gd")

func run() -> void:
	var source := legacy_core_fixture(42)
	source.data.balance = 100000.0
	source.economy.build("rapid", "0,0", 0)
	source.set_balance_stat("enemies", "basic", "hp", 222.0)
	source.set_tower_tier_stat("rapid:2", "cost", 17.0)
	source.set_balance_stat("session", "start", "starting_gold", 888.0)
	var before := source.data.duplicate(true)
	var code := Stats.encode(source.tuning, "Survival rules", "A fresh world with tuned enemies.")
	var config := Stats.decode(code)
	check(not config.is_empty() and config.tuning == source.tuning, "All configured stats round-trip")
	check(code == Stats.encode(source.tuning, "Survival rules", "A fresh world with tuned enemies."), "Export is deterministic")
	check(source.data == before, "Stats export does not mutate the source game")
	check(config.keys().size() == 3 and not config.has("towers") and not config.has("regions"), "Top-level schema contains metadata and tuning only")
	for runtime_key in ["balance", "regions", "castles", "relics", "cloud", "camera", "next_tower", "active_seconds", "kills", "lifetime_earnings"]:
		check(not config.has(runtime_key) and not config.tuning.has(runtime_key), "No runtime field: " + runtime_key)
	var slots := VigilSaveSlots.new()
	slots.base_path = "user://stats-transfer-" + str(Time.get_ticks_usec())
	check(slots.save_stat_configuration(source.tuning, config.setup.name, config.setup.description), "Configuration saved to local library")
	var reload := VigilSaveSlots.new()
	reload.base_path = slots.base_path
	check(reload.stat_configurations().size() == 1 and reload.configurations().is_empty(), "Stats library persists separately from world builds")
	var survival := slots.create(0, "survival", reload.stat_configurations()[0].code)
	check(survival != null and not survival.is_creative() and survival.tuning == source.tuning, "Survival starts with imported custom rules")
	check(survival.data.balance == 888.0 and survival.data.towers.is_empty() and survival.data.regions.size() == 1 and survival.data.kills == 0.0 and survival.combat.enemies.is_empty(), "New Survival has starting resources and no transferred runtime state")
	check(not survival.set_balance_stat("enemies", "basic", "hp", 333.0), "Survival configuration remains locked during play")
	check(survival.reset_progress() and survival.data.balance == 888.0 and survival.tuning == source.tuning, "Survival restart reapplies saved starting rules")
	check(not Stats.encode(survival.tuning, "Copy survival").is_empty(), "Survival rules can be exported again")
	var loaded := VigilState.new()
	loaded.save_path = survival.save_path
	check(loaded.load_save() and loaded.tuning == source.tuning and not loaded.is_creative(), "Imported rules persist on reload")
	var standard := Stats.encode({}, "Defaults")
	check(not Stats.decode(standard).is_empty(), "Empty sparse overrides use authored defaults")
	for invalid in ["", "[]", "bad json", code.replace("Survival rules", "tampered"), code.left(40), "x".repeat(Stats.MAX_BYTES + 1), slots.export_build(source, "World build")]:
		check(Stats.decode(invalid).is_empty(), "Malformed or world-state codes rejected")
	for mutation in ["version", "towers", "bad_stat"]:
		var bad := config.duplicate(true)
		if mutation == "version": bad.version = 999
		elif mutation == "towers": bad.towers = source.data.towers
		else: bad.tuning.enemies.basic.hp = "bad"
		var payload := JSON.stringify(bad)
		check(Stats.decode(JSON.stringify({"format": Stats.FORMAT, "payload": payload, "checksum": payload.sha256_text()})).is_empty(), "Validated payload rejects " + mutation)
	var creative := slots.create(1, "creative", code)
	check(creative != null and creative.is_creative() and creative.data.towers.is_empty(), "Stat configurations also support fresh Creative worlds")
	check(preload("res://tests/unit/developer_tier_checks.gd").same_values(slots.decode_build(slots.export_build(source, "Existing world")).towers, source.data.towers), "Existing world build format remains compatible")
	for slot in range(3): clean_test_save(slots.path_for(slot))
	var directory := DirAccess.open(slots.configurations_path())
	for file in directory.get_files(): DirAccess.remove_absolute(slots.configurations_path().path_join(file))
	DirAccess.remove_absolute(slots.configurations_path())
	print("STAT CONFIGURATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
