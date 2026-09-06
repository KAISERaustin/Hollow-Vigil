extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
var app: VigilApp
var slots := VigilSaveSlots.new()
var content: VBoxContainer
var card: PanelContainer
var message: Label

func _ready() -> void:
	name = "SaveSlots"
	color = UI.BG
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 16))
	add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Save slots and setup")
	card.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	resized.connect(fit)
	show_slots()

func fit() -> void:
	var safe := UI.safe_rect(app).grow(-16)
	card.size = Vector2(minf(460, safe.size.x), safe.size.y)
	card.position = safe.position + (safe.size - card.size) * 0.5

func clear(title: String) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_child(UI.heading(title, 28))
	message = UI.paragraph("", 13)
	content.add_child(message)
	call_deferred("fit")

func show_slots() -> void:
	clear("Your saves")
	content.add_child(UI.paragraph("Three saves on this device. Creative lets you edit the rules. Survival locks developer controls.", 14))
	for slot in range(VigilSaveSlots.COUNT):
		var snapshot := slots.summary(slot)
		var exists := slots.occupied(slot)
		var title := "Save %d · Empty" % (slot + 1)
		if exists:
			title = "Save %d · Unreadable — recovery files preserved" % (slot + 1) if snapshot.is_empty() else "Save %d · %s" % [slot + 1, str(snapshot.get("mode", "creative")).capitalize()]
		content.add_child(UI.heading(title, 18))
		if not snapshot.is_empty():
			content.add_child(UI.paragraph(snapshot.get("setup", {}).get("name", "%d territories" % snapshot.regions.size()), 14))
		var button := UI.button("Continue" if exists else "Create save", func():
			if exists:
				app.open_slot(slot)
			else:
				show_creation(slot)
		)
		button.name = "SaveSlot%d" % (slot + 1)
		button.disabled = exists and snapshot.is_empty()
		add_action(button)
		if exists:
			add_action(UI.button("Archive and free slot", show_archive.bind(slot)))
		content.add_child(UI.rule())
	if app.slot_active:
		add_action(UI.button("Back to game", close))

func show_creation(slot: int) -> void:
	clear("Create save %d" % (slot + 1))
	content.add_child(UI.paragraph("Start fresh, or paste a previously exported setup. Choose how you want to play it.", 14))
	var code := TextEdit.new()
	code.name = "SetupImportCode"
	code.placeholder_text = "Optional setup export code"
	code.custom_minimum_size.y = 100
	code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	style_entry(code)
	content.add_child(code)
	add_action(UI.button("Paste setup", func(): code.text = DisplayServer.clipboard_get()))
	add_action(UI.button("Load setup file", func(): choose_file(false, func(path: String): code.text = FileAccess.get_file_as_string(path))))
	var preview := UI.paragraph("", 14)
	content.add_child(preview)
	code.text_changed.connect(func():
		var snapshot := slots.decode_build(code.text.strip_edges())
		preview.text = "" if code.text.strip_edges().is_empty() else "Invalid setup code"
		if not snapshot.is_empty():
			var setup: Dictionary = snapshot.get("setup", {})
			preview.text = setup.get("name", "Untitled setup") + "\n" + setup.get("description", "")
	)
	for mode in ["creative", "survival"]:
		var button := UI.button("Create " + mode.capitalize(), func():
			var game := slots.create(slot, mode, code.text.strip_edges())
			if game == null:
				message.text = slots.error
			else:
				app.activate_slot(game, slot)
		)
		button.name = "Create" + mode.capitalize()
		add_action(button)
	add_action(UI.button("Back", show_slots))

func show_export() -> void:
	clear("Export Creative setup")
	content.add_child(UI.paragraph("Includes your world, towers, resources and tuned values. Import into an empty save as Creative or Survival.", 14))
	var title := LineEdit.new()
	title.name = "SetupName"
	title.placeholder_text = "Setup name"
	title.max_length = 80
	title.text = app.game.data.get("setup", {}).get("name", "")
	title.custom_minimum_size.y = UI.TARGET
	style_entry(title)
	content.add_child(title)
	var description := TextEdit.new()
	description.name = "SetupDescription"
	description.placeholder_text = "Describe your changes (up to 4,000 characters)"
	description.text = app.game.data.get("setup", {}).get("description", "")
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.custom_minimum_size.y = 140
	style_entry(description)
	content.add_child(description)
	var output := TextEdit.new()
	output.name = "SetupExportCode"
	output.editable = false
	output.custom_minimum_size.y = 100
	output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	style_entry(output)
	var generate := func() -> String:
		if title.text.strip_edges().is_empty() or description.text.length() > 4000:
			message.text = "Enter a setup name and a description of at most 4,000 characters."
			return ""
		var code := slots.export_build(app.game, title.text, description.text)
		if code.is_empty():
			message.text = "Couldn't export this setup."
			return ""
		app.game.data.setup = {"name": title.text.strip_edges(), "description": description.text}
		app.persist()
		output.text = code
		return code
	add_action(UI.button("Copy export code", func():
		var code: String = generate.call()
		if not code.is_empty():
			DisplayServer.clipboard_set(code)
			message.text = "Copied. Paste this code when creating a save in either mode."
	))
	add_action(UI.button("Save setup file", func():
		var code: String = generate.call()
		if not code.is_empty():
			choose_file(true, func(path: String):
				var file := FileAccess.open(path, FileAccess.WRITE)
				if file == null:
					message.text = "Couldn't write that file. Choose another location."
				else:
					file.store_string(code)
					file.close()
					message.text = "Setup exported."
			)
	))
	content.add_child(output)
	add_action(UI.button("Back to game", close))

func choose_file(saving: bool, callback: Callable) -> void:
	var dialog := FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.hvbuild ; Hollow Vigil setup"])
	if saving:
		dialog.current_file = "setup.hvbuild"
	add_child(dialog)
	dialog.file_selected.connect(func(path: String): callback.call(path); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.85)

func close() -> void:
	if not app.slot_active:
		return
	app.game.suspended = false
	hide()

func show_archive(slot: int) -> void:
	clear("Free save %d?" % (slot + 1))
	content.add_child(UI.paragraph("This removes the save from the picker so you can create another. Its files are kept in the local save folder as an archive. Export any Creative setup you want to reuse first.", 14))
	add_action(UI.button("Cancel", show_slots))
	add_action(UI.accent_button("Archive and free slot", func():
		if not slots.archive(slot):
			message.text = slots.error
			return
		if app.slot_active and app.active_slot == slot:
			app.slot_active = false
		show_slots()
	, UI.DANGER))

func style_entry(entry: Control) -> void:
	for state in ["normal", "read_only"]:
		entry.add_theme_stylebox_override(state, UI.box(UI.SURFACE))
	entry.add_theme_stylebox_override("focus", UI.focus_box())
	entry.add_theme_color_override("font_color", UI.TEXT)
	entry.add_theme_color_override("font_readonly_color", UI.TEXT)
	entry.add_theme_color_override("font_placeholder_color", UI.MUTED)
	entry.add_theme_color_override("caret_color", UI.TEXT)
	entry.add_theme_font_size_override("font_size", UI.type_size(14))

func add_action(button: Button) -> void:
	var caption := button.text
	if caption.begins_with("Archive"): caption = "Archive"
	elif caption.begins_with("Create"): caption = "Create"
	elif caption.begins_with("Back"): caption = "Back"
	elif caption.begins_with("Paste"): caption = "Paste"
	elif caption.begins_with("Load"): caption = "Load"
	elif caption.begins_with("Copy"): caption = "Copy"
	elif caption.begins_with("Save"): caption = "Save"
	content.add_child(UI.action_row(button.text, button, caption))
