extends "res://tests/campaign_balance_runner.gd"
## Legal playthroughs for the appended chapters and old-save/build compatibility.
const Playthrough = preload("res://scripts/persistence/campaign_playthrough.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	check(Catalog.COUNT == 30 and Catalog.CHAPTERS.size() == 6, "Six complete five-level chapters")
	var styles: Array = []
	for chapter in Catalog.CHAPTERS: styles.append(chapter.style)
	check(styles == preload("res://scripts/content/catalogs/world.gd").ALL_STYLES, "Every registered biome has one campaign chapter")
	var progress := Progress.new()
	progress.path = "user://six-biome-playthrough.save"
	check(progress.restore_completed_levels(Catalog.LEGACY_COUNT), "Existing twenty-level completion remains readable")
	check(progress.unlocked(20) and not progress.unlocked(21), "Old completion unlocks the first added level only")
	for index in range(Catalog.LEGACY_COUNT, Catalog.COUNT):
		var victory: RefCounted
		for strategy in range(16):
			var battle := Run.new(index)
			var steps := 0
			while battle.phase in ["planning", "wave"] and steps < 20000:
				if battle.phase == "planning":
					invest(battle, strategy)
					battle.start_wave()
				battle.tick(Balance.STEP)
				steps += 1
			if battle.phase == "victory":
				victory = battle
				print("EXPANSION LEVEL %d: victory, strategy %d, integrity %d" % [index + 1, strategy, battle.health])
				break
			await process_frame
		check(victory != null, "New level %d has a legal winning strategy" % (index + 1))
		if victory != null: check(progress.save_run(victory), "Victory unlocks the next added level")
		await process_frame
	check(progress.data.completed_levels == Catalog.COUNT, "New chapter progression reaches the final level")
	var portable := Playthrough.decode(Playthrough.encode({"19": {"overrides": {"gold": 4321.0}}}, "Legacy campaign", ""))
	for index in range(Catalog.LEGACY_COUNT, Catalog.COUNT): portable.levels.erase(str(index))
	check(Playthrough.valid(portable), "Twenty-level portable builds remain valid")
	check(Playthrough.level_build(portable, 19).overrides.gold == 4321.0 and Playthrough.level_build(portable, 20).is_empty(), "Old custom rules persist while appended levels use defaults")
	var invalid := portable.duplicate(true)
	invalid.levels["20"] = invalid.levels["19"]
	check(not Playthrough.valid(invalid), "Partial expansions cannot masquerade as complete builds")
	var source := VigilState.new(71)
	var reusable := Build.capture("campaign", source, {}, "all", -1, {"resources": true}, "Legacy resources", "")
	for index in range(Catalog.LEGACY_COUNT, Catalog.COUNT): reusable.data.levels.erase(str(index))
	check(Build.valid(reusable) and Build.compose_campaign(reusable, {}).ok, "Old reusable whole-campaign builds still compose")
	for index in [19, 20, 24, 29]:
		var battle := Run.new(index)
		var restored: RefCounted = Run.from_checkpoint(JSON.parse_string(JSON.stringify(battle.checkpoint())))
		check(restored != null and restored.mission.index == index and restored.mission.style == Catalog.level(index).style, "Old and new level checkpoints retain their content identity")
	var medals: Array = []
	medals.resize(Catalog.LEGACY_COUNT)
	medals.fill(1)
	var payload := JSON.stringify({"version": 1, "sequence": 1, "medals": medals})
	var legacy_path := "user://six-biome-legacy.save"
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.close()
	check(progress.read_candidate(legacy_path).get("completed_levels") == Catalog.LEGACY_COUNT, "Original twenty-medal saves migrate without losing victories")
	for path in [progress.path, legacy_path]:
		for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(path + suffix)
	print("CAMPAIGN EXPANSION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
