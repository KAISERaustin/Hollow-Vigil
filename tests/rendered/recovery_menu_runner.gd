extends "res://tests/rendered/unified_menu_runner.gd"
## Exercise recovery copies through the same native page/confirmation controls.
const Codec = preload("res://scripts/cloud/cloud_codec.gd")

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://recovery-ui-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	app.slot_active = false
	install_network()
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await frames()
		for type in ["campaign", "infinite"]:
			var prefix: String = app.game.save_path + "." + type + str(dimensions.x)
			menu.slots.base_path = prefix
			menu.campaign_slots.base_path = prefix
			app.private_backups.slots.base_path = prefix
			app.private_backups.campaign_slots.base_path = prefix
			var original: Dictionary
			if type == "campaign":
				original = menu.campaign_slots.create(0, "creative", "Recovery original")
				var replacement := original.duplicate(true)
				replacement.id = Codec.uuid()
				replacement.name = "Different Campaign"
				check(menu.campaign_slots.replace(0, replacement), "Create Campaign recovery through replacement owner")
			else:
				var source := VigilState.new(7134, "creative")
				source.data.setup = {"name": "Recovery original", "description": ""}
				original = source.data.duplicate(true)
				check(menu.slots.storage.write(menu.slots.path_for(0), original), "Create original Infinite game")
				var replacement := VigilState.new(8134, "survival")
				replacement.data.setup = {"name": "Different Infinite", "description": ""}
				check(menu.replace_infinite(0, replacement.data), "Create Infinite recovery through replacement owner")
			menu.show_home(type)
			var existing: Dictionary = menu.slot_summary(0).duplicate(true)
			var code := Build.encode(Build.capture("infinite", VigilState.new(), {}, "all", -1, {"enemies": ["basic"]}, "Recovered library", ""))
			await network._rpc("put_private_build", {"build_hash": code.sha256_text(), "configuration": code})
			await press("Backups")
			await press("RecoverMyBuilds")
			check(not menu.slots.shared_configurations("all").is_empty(), "Recover My builds button restores account library")
			await press("RestoreRecoveryCopy")
			check(menu.restore_choice.source == "recovery" and menu.restore_choice.game_type == type, "Recovery card carries its game type and snapshot")
			await press("RestoreIntoSlot2")
			await capture(type + "-recovery-empty")
			await press("ConfirmRestoreBackup")
			await press("CancelConfirmation")
			check(not menu.slot_occupied(1), "Cancel leaves empty recovery destination empty")
			await press("ConfirmRestoreBackup")
			await press("ConfirmAction")
			check(menu.screen == "slots" and menu.game_name(menu.slot_summary(1)) == "Recovery original", "Confirmed local recovery returns to matching Saved games")
			check(menu.slot_summary(0) == existing and not menu.slot_occupied(2), "Restoring into empty slot preserves occupied sibling and third slot")
			menu.show_home(type)
			await press("Backups")
			await press("RestoreRecoveryCopy")
			await press("RestoreIntoSlot1")
			await capture(type + "-recovery-replacement")
			await press("ConfirmRestoreBackup")
			await press("CancelConfirmation")
			check(menu.slot_summary(0) == existing, "Cancel replacement preserves different named game")
			await press("ConfirmRestoreBackup")
			await press("ConfirmAction")
			check(menu.game_name(menu.slot_summary(0)) == "Recovery original", "Confirmed recovery replaces the chosen different game")
			check(app.private_backups.recovery_games().any(func(entry): return menu.game_name(entry.snapshot) == menu.game_name(existing)), "Replaced destination becomes another browsable recovery copy")
			await press("ContinueGameSlot1")
			if type == "campaign": app.campaign.set_process(false)
			await open_game_menu()
			await press("GameBackups")
			await press("RestoreRecoveryCopy")
			await press("RestoreIntoSlot1")
			await press("ConfirmRestoreBackup")
			await press("ConfirmAction")
			check(menu.screen == "restore_review" and menu.message.text.contains("Exit the current game"), "Held active game cannot be overwritten through recovery")
			await press("BackButton")
			await press("BackButton")
			await press("BackButton")
			await press("ExitGame")
	print("RECOVERY_MENU: %d checks, %d failures" % [checks, failures.size()])
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
