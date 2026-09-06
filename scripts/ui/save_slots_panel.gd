extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
var app: VigilApp
var slots := VigilSaveSlots.new()
var header: HBoxContainer
var content: VBoxContainer
var card: PanelContainer
var scroll: ScrollContainer
var message: Label
var upload_revision := -1
var view_revision := 0
var public_browser: RefCounted
var creation_mode := "creative"
var selected_configuration: Dictionary = {}

func _ready() -> void:
	public_browser = preload("res://scripts/ui/public_builds_panel.gd").new()
	public_browser.menu = self
	app.public_builds.changed.connect(func():
		if is_instance_valid(message) and upload_revision == view_revision:
			message.text = app.public_builds.status
	)
	name = "SaveSlots"
	color = UI.BG
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 4, 16))
	add_child(card)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", UI.GAP)
	card.add_child(layout)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", UI.GAP)
	layout.add_child(header)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Save slots and setup")
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
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

func clear(title: String, header_action: Button = null) -> void:
	view_revision += 1
	for container in [header, content]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	scroll.set_deferred("scroll_vertical", 0)
	var heading := UI.heading(title, 28)
	heading.name = "ScreenTitle"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(heading)
	if header_action != null:
		header.add_child(header_action)
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
	add_action(UI.button("Public Builds", show_public_builds))
	if app.slot_active:
		add_back(UI.button("Back to game", close))

func show_creation(slot: int, reset: bool = true) -> void:
	if reset:
		creation_mode = "creative"
		selected_configuration = {}
	clear("Create save %d" % (slot + 1))
	content.add_child(UI.paragraph("Choose your world and how you want to play, then create your save.", 14))
	content.add_child(UI.heading("World configuration", 18))
	content.add_child(UI.paragraph(selected_configuration.get("name", "Fresh world"), 16))
	content.add_child(UI.paragraph(selected_configuration.get("description", "Start with the default world, resources and rules."), 14))
	var choose := UI.button("Choose saved configuration", show_configurations.bind(slot))
	choose.name = "ChooseConfiguration"
	add_action(choose)
	add_action(UI.button("Public Builds", show_public_builds.bind(slot)))
	if not selected_configuration.is_empty():
		add_action(UI.button("Use a fresh world", func():
			selected_configuration = {}
			show_creation(slot, false)
		))
	content.add_child(UI.rule())
	content.add_child(UI.heading("Game mode", 18))
	var modes := OptionButton.new()
	modes.name = "CreationMode"
	modes.custom_minimum_size.y = UI.TARGET
	modes.add_item("Creative")
	modes.add_item("Survival")
	modes.select(0 if creation_mode == "creative" else 1)
	content.add_child(modes)
	var mode_help := UI.paragraph("", 14)
	content.add_child(mode_help)
	var update_mode := func(index: int):
		creation_mode = "creative" if index == 0 else "survival"
		mode_help.text = "Adjust world rules and balance with Developer Controls." if index == 0 else "Play with your chosen rules. Developer Controls are locked."
	modes.item_selected.connect(update_mode)
	update_mode.call(modes.selected)
	content.add_child(UI.rule())
	add_back(UI.button("Back to saves", show_slots))
	var create := UI.button("Create save", func():
		var game := slots.create(slot, creation_mode, selected_configuration.get("code", ""))
		if game == null:
			message.text = slots.error
		else:
			app.activate_slot(game, slot)
	)
	create.name = "CreateSave"
	add_action(create)

func show_configurations(slot: int) -> void:
	clear("Saved configurations")
	content.add_child(UI.paragraph("Choose a configuration to use its world, towers, resources and rules. Your original save stays available.", 14))
	add_back(UI.button("Back to world options", show_creation.bind(slot, false)))
	add_action(UI.button("Public Builds", show_public_builds.bind(slot)))
	var saved := slots.configurations()
	if saved.is_empty():
		content.add_child(UI.paragraph("No configurations yet. Open a Creative world and use Settings → Upload build to add one.", 16))
	for configuration in saved:
		content.add_child(UI.heading(configuration.name, 18))
		if not configuration.description.is_empty():
			content.add_child(UI.paragraph(configuration.description, 14))
		var select := UI.button("Use this configuration", func():
			selected_configuration = configuration
			show_creation(slot, false)
		)
		select.name = "SelectConfiguration" + str(saved.find(configuration))
		add_action(select)
		content.add_child(UI.rule())

func show_export() -> void:
	clear("Upload build")
	content.add_child(UI.paragraph("Save and automatically publish this world, towers, resources and rules to Public Builds. Your account name, title and description will be visible to everyone. Offline exports upload after you sign in.", 14))
	content.add_child(UI.heading("Configuration name", 18))
	var title := LineEdit.new()
	title.name = "SetupName"
	title.placeholder_text = "For example, Stronger enemies"
	title.max_length = 80
	title.text = app.game.data.get("setup", {}).get("name", "")
	title.custom_minimum_size.y = UI.TARGET
	style_entry(title)
	content.add_child(title)
	content.add_child(UI.heading("Description", 18))
	var description := TextEdit.new()
	description.name = "SetupDescription"
	description.placeholder_text = "What did you change? (optional)"
	description.text = app.game.data.get("setup", {}).get("description", "")
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.custom_minimum_size.y = 140
	style_entry(description)
	content.add_child(description)
	add_back(UI.button("Back to game", close))
	var save := UI.button("Upload build", func():
		if title.text.strip_edges().is_empty() or description.text.length() > 4000:
			message.text = "Enter a name and keep the description under 4,001 characters."
			return
		if not slots.save_configuration(app.game, title.text, description.text):
			message.text = slots.error
			return
		var code := slots.export_build(app.game, title.text, description.text)
		app.public_builds.queue_export(code)
		app.game.data.setup = {"name": title.text.strip_edges(), "description": description.text}
		app.persist()
		clear("Build saved locally")
		message.text = app.public_builds.status
		upload_revision = view_revision
		content.add_child(UI.paragraph("“%s” is in your configuration library. To use it, open an empty save and choose Saved configuration." % title.text.strip_edges(), 16))
		add_action(UI.button("Public Builds", show_public_builds))
		if not app.cloud.signed_in() or app.cloud.display_name.is_empty():
			add_action(UI.button("Account & cloud saves", func():
				close()
				app.panels.show_cloud_saves()
			))
		add_action(UI.button("Your saves", show_slots))
		add_back(UI.button("Back to game", close))
	)
	save.name = "SaveConfiguration"
	add_action(save)

func show_public_builds(slot: int = -1) -> void:
	public_browser.show_page(slot)

func close() -> void:
	if not app.slot_active:
		return
	view_revision += 1
	app.game.suspended = false
	hide()

func show_archive(slot: int) -> void:
	clear("Free save %d?" % (slot + 1))
	content.add_child(UI.paragraph("This removes the save from the picker so you can create another. Its files are kept in the local save folder as an archive. Save a configuration of any Creative world you want to reuse first.", 14))
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

func add_back(back: Button) -> void:
	back.accessibility_name = back.text
	back.tooltip_text = back.text
	back.text = "←"
	back.name = "BackButton"
	back.custom_minimum_size.x = UI.TARGET
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	header.move_child(back, 0)

func add_action(button: Button) -> void:
	var caption := button.text
	if caption.begins_with("Archive"): caption = "Archive"
	elif caption.begins_with("Create"): caption = "Create"
	elif caption.begins_with("Paste"): caption = "Paste"
	elif caption.begins_with("Load"): caption = "Load"
	elif caption.begins_with("Copy"): caption = "Copy"
	elif caption.begins_with("Save"): caption = "Save"
	elif caption.begins_with("Choose"): caption = "Choose"
	elif caption.begins_with("Use"): caption = "Use"
	content.add_child(UI.action_row(button.text, button, caption))
