extends "res://tests/test_runner.gd"

const App = preload("res://scripts/app/main.gd")
const Build = preload("res://scripts/persistence/reusable_build.gd")

func run() -> void:
	var app := App.new()
	app.load_saved_progress = false
	app.game.save_path = "user://campaign-only-" + str(Time.get_ticks_usec())
	root.add_child(app)
	await process_frame
	await process_frame
	var menu = app.slot_menu
	check(menu.screen == "main", "Startup opens main menu")
	check(app.game.suspended and app.game.combat.enemies.is_empty(), "No background battle runs at startup")
	check(menu.find_child("OpenCampaign", true, false) != null, "Campaign entry is present")
	check(not app.has_method("activate_slot"), "No world session activation API remains")
	check(not app.game.has_method("expand") and not app.game.has_method("apply_offline"), "No territory expansion or offline simulation remains")
	menu.open_mode("unsupported")
	check(menu.screen == "main", "Unsupported mode entry is rejected")
	menu.open_mode("campaign")
	check(menu.screen == "home", "Empty Campaign opens home")
	menu.begin_new(0)
	menu.new_game.mode = "creative"
	menu.new_game.name = "Campaign regression"
	menu.start_prepared(menu.prepare_new())
	await process_frame
	await process_frame
	check(is_instance_valid(app.campaign), "Creation starts Campaign")
	check(app.campaign.page == "map", "Campaign starts on world map")
	check(menu.campaign_slots.occupied(0), "Campaign slot is persisted")
	app.campaign.start_mission(0)
	await process_frame
	await process_frame
	check(app.campaign.page == "battle", "Authored mission opens")
	check(app.campaign.run.game.combat.scripted_spawns, "Battle uses authored spawns")
	app.show_game_menu()
	check(menu.screen == "game_menu" and app.campaign.paused, "Game menu pauses Campaign")
	menu.resume_game()
	check(not menu.visible, "Resume returns to battle")
	app.campaign.save_progress()
	check(menu.campaign_slots.summary(0).checkpoint.is_empty(), "Exiting a level preserves the existing fresh-attempt save policy")
	app.show_game_menu()
	menu.show_sound()
	app.audio.set_volume("music", 0.17)
	app.persist()
	app.game.data.settings.clear()
	app.load_preferences()
	check(is_equal_approx(app.audio.volume("music"), 0.17), "Sound preferences persist independently")
	menu.exit_game()
	await process_frame
	check(not is_instance_valid(app.campaign) and menu.screen == "home", "Exit returns to Campaign home")
	menu.continue_game(0)
	await process_frame
	check(is_instance_valid(app.campaign), "Saved Campaign continues")
	var build := Build.capture("campaign", null, {}, "all", -1, Build.all_contents("campaign", "rules"), "Rules", "")
	check(Build.valid(build) and not Build.decode(Build.encode(build)).is_empty(), "Campaign build round-trip")
	build.game_type = "unsupported"
	check(not Build.valid(build) and not Build.compatible(build, "campaign"), "Unsupported builds cannot enter Campaign")
	var backups = app.private_backups
	check(backups.local_games().size() == 1 and backups.local_games()[0].game_type == "campaign", "Backup enumeration contains Campaign slots only")
	check((await backups.read_backup("unsupported", 0)).is_empty(), "Unsupported restore is rejected before transport")
	app.campaign.close(false)
	app.queue_free()
	await process_frame
	print("CAMPAIGN_ONLY: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
