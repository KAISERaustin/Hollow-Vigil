extends "res://tests/rendered/unified_menu_runner.gd"

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://slot-deletion-" + str(Time.get_ticks_usec())
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.private_backups.enabled = false
	app.show_game_menu()
	menu = app.slot_menu
	menu.resume_game()
	app.slot_active = false
	for dimensions in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for type in ["campaign", "infinite"]:
			for slot in 3: create_slot(type, slot)
		for type in ["campaign", "infinite"]:
			menu.show_home(type)
			menu.show_slots()
			await capture(type + "-delete-slots")
			for slot in 3:
				var owner: RefCounted = menu.campaign_slots if type == "campaign" else menu.slots
				var path: String = owner.path_for(slot)
				var before := FileAccess.get_file_as_string(path)
				for suffix in [".tmp", ".bak", ".cloud-outbox"]:
					var file := FileAccess.open(path + suffix, FileAccess.WRITE)
					file.store_string(before)
					file.close()
				await press("DeleteGameSlot" + str(slot + 1))
				check(FileAccess.get_file_as_string(path) == before, "Opening confirmation preserves " + type)
				if slot == 0:
					await capture(type + "-delete-confirmation")
					var popup: PopupPanel = button("ConfirmAction").get_window()
					check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(Rect2(Vector2(popup.position), Vector2(popup.size))), "Confirmation fits phone screen")
				await press("CancelConfirmation")
				for suffix in ["", ".tmp", ".bak", ".cloud-outbox"]:
					check(FileAccess.get_file_as_string(path + suffix) == before, "Cancel preserves every slot file")
				await press("DeleteGameSlot" + str(slot + 1))
				await press("ConfirmAction")
				check(not owner.occupied(slot) and owner.summary(slot).is_empty(), "Confirmed deletion frees " + type + " slot " + str(slot + 1))
				for suffix in ["", ".tmp", ".bak", ".cloud-outbox"]:
					check(not FileAccess.file_exists(path + suffix), "Deletion removes fallback and pending files")
				check(button("NewGameSlot" + str(slot + 1)) != null and button("DeleteGameSlot" + str(slot + 1)) == null, "Deleted card offers New game")
				for sibling in 3:
					if sibling > slot: check(owner.occupied(sibling), "Other slots stay saved")
				if type == "campaign":
					for other in 3: check(menu.slots.occupied(other), "Campaign deletion preserves Infinite slots")
				create_slot(type, slot)
				check(owner.occupied(slot), "Deleted slot can be reused")
				check(owner.delete_slot(slot), "Remove reused fixture")
		for owner in [menu.slots, menu.campaign_slots]:
			check(not owner.delete_slot(-1) and not owner.delete_slot(3), "Reject invalid slot indices")
	await check_active_deletion()
	await check_unreadable_deletion()
	app.queue_free()
	await frames()
	print("SAVE SLOT DELETE UI: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func create_slot(type: String, slot: int) -> void:
	var mode := "creative" if slot % 2 == 0 else "survival"
	if type == "campaign":
		check(not menu.campaign_slots.create(slot, mode, "Campaign " + str(slot + 1)).is_empty(), "Create Campaign fixture")
	else:
		check(menu.slots.create(slot, mode) != null, "Create Infinite fixture")

func check_active_deletion() -> void:
	for type in ["campaign", "infinite"]:
		create_slot(type, 0)
		menu.show_home(type)
		menu.continue_game(0)
		await frames()
		menu.open_game_menu()
		menu.show_slots()
		await press("DeleteGameSlot1")
		await press("CancelConfirmation")
		check(menu.live_campaign() if type == "campaign" else app.slot_active, "Cancel keeps active session")
		await press("DeleteGameSlot1")
		await press("ConfirmAction")
		check(not menu.live_campaign() if type == "campaign" else not app.slot_active, "Deletion releases active session")
		app.persist()
		await frames()
		check(not menu.slot_occupied(0), "Autosave cannot recreate deleted session")

func check_unreadable_deletion() -> void:
	for type in ["campaign", "infinite"]:
		var owner: RefCounted = menu.campaign_slots if type == "campaign" else menu.slots
		var file := FileAccess.open(owner.path_for(2) + ".tmp", FileAccess.WRITE)
		file.store_string("unreadable fixture")
		file.close()
		menu.show_home(type)
		menu.show_slots()
		await press("DeleteGameSlot3")
		await press("ConfirmAction")
		check(not owner.occupied(2), "Unreadable slot can be explicitly deleted")
