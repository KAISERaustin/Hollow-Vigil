extends "res://tests/test_runner.gd"

const Run = preload("res://scripts/campaign/run.gd")
const Progress = preload("res://scripts/campaign/progress.gd")
const Unlocks = preload("res://scripts/content/nodes/campaign_unlocks.gd")
const Migration = preload("res://scripts/persistence/campaign_catalog_migration.gd")
const Slots = preload("res://scripts/persistence/campaign_slots.gd")
const LevelBuild = preload("res://scripts/persistence/campaign_build.gd")

func run() -> void:
	for mode in ["creative", "survival"]:
		var progress := Progress.new()
		progress.path = "user://unlocks-" + mode + ".save"
		for index in 48:
			check(progress.unlocked(index) and not progress.unlocked(index + 1), mode + " opens exactly the next level")
			var battle := Run.new(index, {}, mode)
			progress.apply_equipment(battle)
			for kind in Balance.TOWERS:
				var position: int = Unlocks.ORDER.find(kind)
				check(battle.game.economy.tower_available(kind) == (index >= position), "Tower introduction: " + kind)
				for tier in range(2, 5):
					var required: int = 24 if tier == 4 else (tier - 1) * 8 + position
					check(battle.game.economy.tower_available(kind, tier) == (index >= required), "Tier milestone: " + kind)
				battle.game.data.balance = 100000.0
				var socket: Dictionary = battle.mission.sockets[0]
				var id := battle.game.economy.build(kind, socket.region, socket.pad)
				check(id.is_empty() == (index < position), "Build transaction enforces unlock")
				if not id.is_empty():
					for tier in range(2, 5):
						var money: float = battle.game.data.balance
						var branch: String = Balance.BRANCHES[kind].keys()[0] if tier == 4 else ""
						var allowed: bool = battle.game.economy.tower_available(kind, tier)
						check(battle.game.economy.upgrade(id, tier - 1, branch) == allowed, "Upgrade transaction enforces milestone")
						if not allowed:
							check(battle.game.data.balance == money, "Locked upgrade never spends gold")
							break
					battle.game.economy.sell(id)
			battle.phase = "defeat"
			check(progress.save_run(battle) and int(progress.data.completed_levels) == index, "Defeat earns no progress")
			battle.phase = "victory"
			check(progress.save_run(battle), "Victory persists milestone")
			var loaded := Progress.new()
			loaded.path = progress.path
			loaded.load_progress()
			check(int(loaded.data.completed_levels) == index + 1, "Milestone survives reload")
		var replay := Run.new(0, {}, mode)
		progress.apply_equipment(replay)
		check(replay.game.economy.tower_available("hex_lantern", 3), "Earned towers remain available on replay")
		check(Run.new(0, {}, mode).game.economy.tower_available("hex_lantern") == false, "New sessions do not inherit unlocks")
		clean_test_save(progress.path)
	for old in 30:
		var converted := Migration.document({"version": 2, "sequence": 0, "completed_levels": old}, "progress")
		check(converted.completed_levels == int(old / 5.0) * 8 + old % 5, "Old frontier maps to its chapter")
		check(Migration.document(converted, "progress") == converted, "Migration is idempotent")
		check(Balance.Content.level(Migration.index(old)).attributes().legacy_index == old, "Every old mission retains identity")
	var slots := Slots.new()
	slots.base_path = "user://unlock-migration"
	var old_slot := {"version": 1, "sequence": 1, "game_type": "campaign", "id": "12345678-1234-4234-8234-123456789012", "name": "Old save", "mode": "creative", "saved_at": 0, "completed": 10, "stats_version": 1, "levels": {"9": {"overrides": {"gold": 1234}}}, "checkpoint": {}}
	var payload := JSON.stringify(old_slot)
	var file := FileAccess.open(slots.path_for(0), FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.close()
	var migrated := slots.summary(0)
	check(not migrated.is_empty() and migrated.completed == 16 and migrated.levels["15"].overrides.gold == 1234, "Slot migration preserves chapter and custom mission")
	check(slots.save_slot(0, migrated) and slots.summary(0).completed == 16, "Migrated slot persists exactly once")
	check(slots.create(1, "survival", "New save").completed == 0, "Another slot starts locked")
	for slot in [0, 1]: clean_test_save(slots.path_for(slot))
	var imported := Run.new(0)
	imported.game.economy.campaign_completed = 48
	check(imported.build(6, "rapid") and imported.upgrade(6), "Unlocked setup fixture")
	var invested_balance: float = imported.game.data.balance
	imported.game.economy.campaign_completed = 0
	imported.game.economy.enforce_campaign_unlocks()
	check(imported.game.data.towers[imported.tower_at(6)].level == 1 and imported.game.data.balance == invested_balance + 60, "Imported locked upgrades refund their investment")
	print("Campaign unlocks: %d checks, %d failures" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
