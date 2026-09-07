extends ColorRect

const UI = preload("res://scripts/ui/shared/interface.gd")
var app: VigilApp
var slots := VigilSaveSlots.new()
var header: HBoxContainer
var footer: VBoxContainer
var content: VBoxContainer
var card: PanelContainer
var scroll: ScrollContainer
var welcome_paper: TextureRect
var message: Label
var upload_revision := -1
var view_revision := 0
var public_browser: RefCounted
var stat_browser: RefCounted
var creation_mode := "creative"
var starting_rules: Dictionary = {}
var selected_configuration: Dictionary = {}

func _ready() -> void:
	public_browser = preload("res://scripts/ui/public_builds_panel.gd").new()
	public_browser.menu = self
	stat_browser = preload("res://scripts/ui/developer/stat_configurations.gd").new()
	stat_browser.menu = self
	app.public_builds.changed.connect(func():
		if is_instance_valid(message) and upload_revision == view_revision:
			message.text = app.public_builds.status
	)
	name = "SaveSlots"
	color = UI.BG
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	welcome_paper = UI.fullscreen_parchment()
	add_child(welcome_paper)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.plain())
	add_child(card)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UI.keyboard_scroll(scroll, "Save slots and setup")
	card.add_child(scroll)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", UI.GAP)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", UI.GAP)
	layout.add_child(header)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	layout.add_child(content)
	footer = VBoxContainer.new()
	footer.name = "SaveActions"
	footer.add_theme_constant_override("separation", UI.GAP)
	layout.add_child(footer)
	resized.connect(fit)
	show_main_menu()

func fit() -> void:
	var safe := UI.safe_rect(app).grow(-16)
	card.size = safe.size
	card.position = safe.position

func clear(title: String, header_action: Button = null) -> void:
	view_revision += 1
	header.get_parent().add_theme_constant_override("separation", UI.GAP)
	header.show()
	footer.show()
	content.size_flags_vertical = Control.SIZE_FILL
	for container in [header, content, footer]:
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

func show_main_menu() -> void:
	clear("Hollow Vigil")
	for child in header.get_children():
		header.remove_child(child)
		child.queue_free()
	header.hide()
	footer.hide()
	message.hide()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var welcome := preload("res://scripts/ui/welcome_menu.gd").new()
	welcome.configure(app.show_campaign, show_slots)
	content.add_child(welcome)

func show_slots() -> void:
	clear("Saved games")
	message.hide()
	header.get_parent().add_theme_constant_override("separation", content.get_theme_constant("separation"))
	add_back(UI.button("Back to main menu", show_main_menu))
	content.add_child(UI.paragraph("Three game slots on this device. Progress saves automatically while you play.", 14))
	for slot in range(VigilSaveSlots.COUNT):
		var snapshot := slots.summary(slot)
		var exists := slots.occupied(slot)
		var title := "Slot %d · New game" % (slot + 1)
		if exists:
			title = "Slot %d · Recovery needed" % (slot + 1) if snapshot.is_empty() else "Slot %d · %s" % [slot + 1, str(snapshot.get("mode", "creative")).capitalize()]
		var body := add_card(title)
		if not snapshot.is_empty():
			if snapshot.has("setup"):
				body.add_child(UI.paragraph(snapshot.setup.name, 16))
			body.add_child(UI.paragraph("%d territories · %d towers" % [snapshot.regions.size(), snapshot.towers.size()], 13))
			var synced := int(snapshot.get("cloud", {}).get("revision", 0)) > 0
			body.add_child(UI.paragraph("Cloud backup available · Upload changes manually" if synced else "On this device · Upload a backup whenever you choose", 12))
		elif exists:
			body.add_child(UI.paragraph("This game could not be read. Its recovery files are preserved.", 14))
		else:
			body.add_child(UI.paragraph("Start fresh, use one of your builds, or try a community build.", 14))
		var button := UI.button("Continue game" if exists else "New game", func():
			if exists: app.open_slot(slot)
			else: show_creation(slot)
		)
		button.name = "SaveSlot%d" % (slot + 1)
		button.disabled = exists and snapshot.is_empty()
		body.add_child(button)
		if exists:
			body.add_child(UI.action_row("Make room for a new game", UI.button("Archive game", show_archive.bind(slot)), "Archive"))
	content.add_child(UI.rule())
	if not app.public_builds.outbox.is_empty():
		add_action(UI.button("Retry public uploads", app.public_builds.flush))
	add_action(UI.button("Account & backups", app.show_backups))
	add_action(UI.button("Browse community builds", show_public_builds))
	footer.hide()

func show_creation(slot: int, reset: bool = true) -> void:
	if reset:
		creation_mode = "creative"
		starting_rules = {}
		selected_configuration = {}
	clear("New game")
	message.hide()
	add_back(UI.button("Back to saved games", show_slots))
	content.add_child(UI.paragraph("Slot %d · Choose a world and a mode." % (slot + 1), 14))
	content.add_child(UI.heading("1. Starting world", 18))
	if not selected_configuration.is_empty():
		content.add_child(UI.paragraph(selected_configuration.get("name", ""), 18))
	if not selected_configuration.get("description", "").is_empty():
		content.add_child(UI.paragraph(selected_configuration.description, 14))
	var choose := UI.button("My builds", show_configurations.bind(slot))
	choose.name = "ChooseConfiguration"
	var sources := HBoxContainer.new()
	sources.add_theme_constant_override("separation", 8)
	content.add_child(sources)
	choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sources.add_child(choose)
	var community := UI.button("Community", show_public_builds.bind(slot))
	community.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sources.add_child(community)
	var stats_button := UI.button("Stats", show_stat_configurations.bind(slot))
	stats_button.name = "ChooseStatConfiguration"
	sources.add_child(stats_button)
	if not selected_configuration.is_empty():
		content.add_child(UI.button("Use a fresh world instead", func():
			selected_configuration = {}
			show_creation(slot, false)
		))
	content.add_child(UI.rule())
	content.add_child(UI.heading("2. Choose your mode", 18))
	var starting_gold := SpinBox.new()
	starting_gold.name = "StartingGold"
	var limits := Balance.field_limits("session", "start", "starting_gold")
	starting_gold.min_value = limits.min
	starting_gold.max_value = limits.max
	starting_gold.step = limits.step
	var selected_code: String = selected_configuration.get("code", "")
	var build_rules: Dictionary = slots.decode_build(selected_code).get("settings", {}).get("developer_balance", {})
	var stat_rules := VigilSaveSlots.Stats.decode(selected_code)
	if not stat_rules.is_empty(): build_rules = stat_rules.tuning
	starting_gold.value = Balance.tuned_value("session", "start", "starting_gold", Balance.merge_tuning(build_rules, starting_rules))
	starting_gold.accessibility_name = "Starting gold"
	starting_gold.value_changed.connect(func(value: float):
		starting_rules = Balance.merge_tuning(starting_rules, {"session": {"start": {"starting_gold": value}}})
	)
	var gold_row := UI.number_row("Starting gold", starting_gold)
	gold_row.visible = creation_mode == "creative"
	content.add_child(gold_row)
	var create := UI.button("Start %s game" % creation_mode.capitalize(), func():
		starting_gold.apply()
		var game := slots.create(slot, creation_mode, selected_configuration.get("code", ""), starting_rules)
		if game == null:
			message.text = slots.error
			message.show()
		else: app.activate_slot(game, slot)
	)
	create.name = "CreateSave"
	var group := ButtonGroup.new()
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 8)
	content.add_child(modes)
	var mode_help := UI.paragraph("", 14)
	var descriptions := {"creative": "Edit the rules, experiment with towers, and make builds to share.", "survival": "Play with the selected rules locked. Developer Controls are unavailable."}
	mode_help.text = descriptions[creation_mode]
	for game_mode in ["creative", "survival"]:
		var button := UI.button(game_mode.capitalize(), func():
			creation_mode = game_mode
			gold_row.visible = game_mode == "creative"
			create.text = "Start %s game" % game_mode.capitalize()
			mode_help.text = descriptions[game_mode]
		)
		button.name = "Mode" + game_mode.capitalize()
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = game_mode == creation_mode
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(button)
	content.add_child(mode_help)
	content.move_child(gold_row, content.get_child_count() - 1)
	footer.add_child(create)

func add_card(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.SURFACE))
	content.add_child(panel)
	var body := UI.margin(panel, 12)
	body.add_theme_constant_override("separation", 10)
	body.add_child(UI.heading(title, 18))
	return body

func show_configurations(slot: int) -> void:
	clear("My builds")
	content.add_child(UI.paragraph("Reusable worlds saved on this device. Choosing a build starts a separate game.", 14))
	add_back(UI.button("Back to new game", show_creation.bind(slot, false)))
	add_action(UI.button("Browse community builds", show_public_builds.bind(slot)))
	var saved := slots.configurations()
	if saved.is_empty():
		content.add_child(UI.paragraph("No builds saved yet. In a Creative game, open Settings → Upload build, then choose Save to My builds.", 16))
	for configuration in saved:
		var select := UI.button("Use", func():
			selected_configuration = configuration
			show_creation(slot, false)
		)
		select.name = "SelectConfiguration" + str(saved.find(configuration))
		var build := VBoxContainer.new()
		build.add_theme_constant_override("separation", 10)
		content.add_child(build)
		var title_row := UI.action_row(configuration.name, select, "Use")
		var title := title_row.get_child(0) as Label
		title.add_theme_font_override("font", UI.font(700))
		title.add_theme_font_size_override("font_size", UI.type_size(18))
		build.add_child(title_row)
		if not configuration.description.is_empty():
			var description_box := PanelContainer.new()
			description_box.add_theme_stylebox_override("panel", UI.surface(UI.PANEL, 2, 10))
			build.add_child(description_box)
			description_box.add_child(UI.paragraph(configuration.description, 14))

func show_export() -> void:
	clear("Save or share a build")
	add_back(UI.button("Back to game", close))
	content.add_child(UI.paragraph("A build is a reusable copy of this world's layout, towers, gold and rules. Your current game continues separately.", 14))
	content.add_child(UI.heading("Build name", 18))
	var title := LineEdit.new()
	title.name = "SetupName"
	title.placeholder_text = "For example, Stronger enemies"
	title.max_length = 80
	title.text = app.game.data.get("setup", {}).get("name", "")
	title.custom_minimum_size.y = UI.TARGET
	style_entry(title)
	content.add_child(title)
	content.add_child(UI.heading("Description · optional", 18))
	var description := TextEdit.new()
	description.name = "SetupDescription"
	description.placeholder_text = "What makes this build different?"
	description.text = app.game.data.get("setup", {}).get("description", "")
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.custom_minimum_size.y = 120
	style_entry(description)
	content.add_child(description)
	content.add_child(UI.rule())
	content.add_child(UI.paragraph("Save to My builds keeps a private copy on this device. Upload public build shares it with everyone, including your player name and description. Account details and sound settings are excluded.", 13))
	if not app.cloud.signed_in() or app.cloud.display_name.is_empty():
		content.add_child(UI.paragraph("Public uploads require sign-in and a player name. Failed attempts need an explicit retry. Local builds need no account.", 13))
	var local := UI.button("Save to My builds", save_build.bind(title, description, false))
	local.name = "SaveLocalBuild"
	footer.add_child(local)
	var upload := UI.accent_button("Upload public build", save_build.bind(title, description, true), UI.GOLD)
	upload.name = "SaveConfiguration"
	footer.add_child(upload)

func save_build(title: LineEdit, description: TextEdit, publish: bool) -> void:
	var build_name := title.text.strip_edges()
	var details := description.text
	if build_name.is_empty() or details.length() > 4000:
		message.text = "Enter a build name and keep the description to 4,000 characters or fewer."
		scroll.scroll_vertical = 0
		return
	if not slots.save_configuration(app.game, build_name, details):
		message.text = slots.error
		return
	if publish:
		if app.public_builds.queue_export(slots.export_build(app.game, build_name, details)):
			app.public_builds.flush()
	app.game.data.setup = {"name": build_name, "description": details}
	app.persist()
	clear("Build upload" if publish else "Build saved")
	message.text = app.public_builds.status if publish else "Saved to My builds on this device. This copy is private."
	upload_revision = view_revision if publish else -1
	content.add_child(UI.heading(build_name, 18))
	content.add_child(UI.paragraph("To play this build, open an empty game slot and choose My builds. You can start it in Creative or Survival.", 14))
	if publish:
		add_action(UI.button("View community builds", show_public_builds))
		if not app.cloud.signed_in() or app.cloud.display_name.is_empty():
			add_action(UI.button("Sign in / choose player name", func():
				close()
				app.panels.show_cloud_saves()
			))
	add_action(UI.button("Saved games", show_slots))
	add_back(UI.button("Back to game", close))

func show_public_builds(slot: int = -1) -> void:
	public_browser.show_page(slot)

func close() -> void:
	if not app.slot_active:
		return
	view_revision += 1
	app.game.suspended = false
	hide()

func show_archive(slot: int) -> void:
	if get_node_or_null("ArchiveConfirmation") != null:
		return
	var popup := preload("res://scripts/ui/shared/confirmation_popup.gd").new()
	popup.name = "ArchiveConfirmation"
	add_child(popup)
	popup.configure("Archive game %d?" % (slot + 1), "Free this slot for a new game. Its files stay in a local archive, hidden from Saved games. Any cloud backup remains available.", "Archive and free slot", func():
		if not slots.archive(slot):
			popup.show_error(slots.error)
			return
		if app.slot_active and app.active_slot == slot:
			app.slot_active = false
		popup.hide()
		show_slots()
	)

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
	back.accessibility_description = back.text
	back.text = "←"
	back.name = "BackButton"
	back.custom_minimum_size.x = UI.TARGET
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(back)
	header.move_child(back, 0)

func add_action(button: Button) -> void:
	var caption := button.text
	if caption.begins_with("Browse") or caption.begins_with("View community"): caption = "Browse"
	elif caption == "Saved games": caption = "Open"
	elif caption.begins_with("Archive"): caption = "Archive"
	elif caption.begins_with("Create"): caption = "Create"
	elif caption.begins_with("Paste"): caption = "Paste"
	elif caption.begins_with("Load"): caption = "Load"
	elif caption.begins_with("Copy"): caption = "Copy"
	elif caption.begins_with("Save"): caption = "Save"
	elif caption.begins_with("Choose"): caption = "Choose"
	elif caption.begins_with("Use"): caption = "Use"
	content.add_child(UI.action_row(button.text, button, caption))

func show_stat_configurations(slot: int = -1) -> void:
	stat_browser.show_page(slot)
