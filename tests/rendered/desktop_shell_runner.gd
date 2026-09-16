extends SceneTree

const Shell = preload("res://scripts/app/desktop_shell.gd")
var shell: Control
var checks := 0
var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 180)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func frames() -> void:
	for index in 6: await process_frame

func target(key: String) -> BaseButton:
	for node in shell.app.find_children(key, "BaseButton", true, false):
		if node.is_visible_in_tree(): return node
	return null

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	await process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await frames()

func press(key: String) -> void:
	var button := target(key)
	check(button != null, "Visible desktop action: " + key)
	if button == null: return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await frames()
	var point := button.get_global_rect().get_center()
	if button.get_window() != root: point += Vector2(button.get_window().position)
	point *= shell.game_container.size / Vector2(Shell.PORTRAIT_SIZE)
	await click_at(point)

func capture(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/desktop-%s-%dx%d.png" % [label, root.size.x, root.size.y])

func run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i.ZERO
	shell = preload("res://scenes/desktop.tscn").instantiate()
	shell.load_saved_progress = false
	root.add_child(shell)
	await frames()
	var menu: Control = shell.app.slot_menu
	menu.campaign_slots.base_path = shell.app.game.save_path + "-slots"
	for desktop_size in [Vector2i(1280,800), Vector2i(1600,900), Vector2i(800,640)]:
		root.size = desktop_size
		await frames()
		check(shell.game_container.position == Vector2.ZERO, "Game stays on the far left")
		check(shell.game_container.size.y == root.size.y, "Game fills desktop height")
		check(absf(shell.game_container.size.aspect() - 540.0/960.0) < 0.002, "Game keeps portrait aspect")
		check(shell.app.size == Vector2(540,960), "Shared app keeps mobile layout units")
		check(shell.app.get_viewport_rect().size == Vector2(540,960), "Popups and camera see portrait viewport")
		check(shell.workspace.position.x == shell.game_container.size.x, "Workspace begins beside the game")
		check(shell.workspace.size.x > 0 and shell.workspace.get_rect().end == Vector2(root.size), "Workspace fills remainder")
		menu.show_main_menu()
		await capture("welcome")
		await click_at(shell.workspace.get_rect().get_center())
		check(menu.screen == "main", "Right-side clicks leave game unchanged")
		await press("OpenCampaign")
		check(menu.screen == "home", "Scaled mouse click opens Campaign")
		await press("NewGame")
		await press("ChooseCreative")
		await press("NextPlayStyle")
		await press("ReviewNewGame")
		check(menu.screen == "review", "Shared creation flow works inside shell")
		await press("SaveSlotChoice")
		var picker: Control = target("SaveSlotChoice")
		check(picker.popup.visible, "Shared picker opens in portrait panel")
		check(shell.game_viewport.get_embedded_subwindows().has(picker.popup), "Popup belongs to mobile viewport")
		check(Rect2(Vector2.ZERO, Vector2(540,960)).encloses(Rect2(Vector2(picker.popup.position), Vector2(picker.popup.size))), "Popup is contained inside portrait game")
		await capture("picker")
		await press("Choice_1")
		check(not picker.popup.visible and picker.selected == 1, "Scaled popup choice receives mouse input")
		var entry: LineEdit = shell.app.find_child("GameName", true, false)
		entry.grab_focus()
		var key := InputEventKey.new()
		key.keycode = KEY_X
		key.unicode = 120
		key.pressed = true
		Input.parse_input_event(key)
		await frames()
		check(entry.text.contains("x"), "Keyboard reaches mobile text field")
		key.pressed = false
		Input.parse_input_event(key)
		# A future desktop control must take focus without leaking typing to mobile.
		var desktop_entry := LineEdit.new()
		desktop_entry.size = Vector2(200,48)
		shell.workspace.add_child(desktop_entry)
		await click_at(shell.workspace.position + Vector2(80,24))
		var before := entry.text
		key.pressed = true
		Input.parse_input_event(key)
		await frames()
		check(desktop_entry.text == "x" and entry.text == before, "Workspace keyboard input is isolated")
		key.pressed = false
		Input.parse_input_event(key)
		desktop_entry.queue_free()
		menu.show_main_menu()
		await frames()
	for mode in ["creative", "survival"]:
		var slot := 0 if mode == "creative" else 1
		var saved: Dictionary = menu.campaign_slots.create(slot, mode, "Desktop " + mode)
		check(not saved.is_empty(), "Create isolated " + mode + " save")
		if saved.is_empty(): continue
		shell.app.open_campaign_slot(slot, saved)
		await frames()
		check(shell.app.campaign.page == "map", mode + " opens shared Campaign map")
		shell.app.campaign.start_mission(0)
		await frames()
		check(shell.app.campaign.page == "battle", mode + " runs in portrait viewport")
		await capture(mode + "-battle")
		var camera_before: Vector2 = shell.app.campaign.board.camera
		await click_at(shell.workspace.get_rect().get_center())
		check(shell.app.campaign.board.camera == camera_before, "Right workspace does not pan battlefield")
		shell.app.campaign.queue_free()
		shell.app.campaign = null
		await frames()
		menu.show_main_menu()
	shell.queue_free()
	await frames()
	print("DESKTOP_SHELL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
