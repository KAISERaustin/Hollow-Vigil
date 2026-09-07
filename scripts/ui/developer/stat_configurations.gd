extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Stats = preload("res://scripts/persistence/stat_configuration.gd")
const Controls = preload("res://scripts/ui/developer/developer_controls.gd")
var menu: Control
var slot := -1
var draft: VigilState
var picker: RefCounted

func show_page(target_slot: int = -1) -> void:
	slot = target_slot
	picker = preload("res://scripts/ui/configuration_picker.gd").new()
	picker.menu = menu
	picker.back = menu.show_creation.bind(slot, false) if slot >= 0 else menu.show_slots
	picker.create = show_editor.bind({})
	picker.selected = func(configuration: Dictionary):
		if slot >= 0:
			menu.selected_configuration = configuration
			menu.starting_rules = {}
			menu.show_creation(slot, false)
		else:
			show_editor(Stats.decode(configuration.code))
	picker.show_page()
	if menu.app.slot_active:
		var current := UI.button("Copy current game's stats", func():
			show_editor({"tuning": menu.app.game.tuning, "setup": menu.app.game.data.get("setup", {})})
		)
		current.name = "CopyCurrentStats"
		menu.content.add_child(current)

func show_editor(configuration: Dictionary) -> void:
	menu.clear("Edit stat configuration")
	menu.add_back(UI.button("Back to configurations", show_page.bind(slot)))
	draft = VigilState.new(42, "creative", configuration.get("tuning", {}))
	var title := LineEdit.new()
	title.name = "StatConfigurationName"
	title.placeholder_text = "Configuration name"
	title.max_length = 80
	title.text = configuration.get("setup", {}).get("name", "")
	title.custom_minimum_size.y = UI.TARGET
	menu.content.add_child(title)
	var description := TextEdit.new()
	description.name = "StatConfigurationDescription"
	description.placeholder_text = "Description (optional)"
	description.text = configuration.get("setup", {}).get("description", "")
	description.custom_minimum_size.y = 80
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	menu.content.add_child(description)
	var controls := Controls.new()
	controls.game = draft
	controls.configuration_only = true
	menu.content.add_child(controls)
	controls.layout_changed.connect(func(): menu.scroll.scroll_vertical = 0)
	var categories := UI.button("All stat categories", controls.show_categories)
	menu.footer.add_child(categories)
	var save := UI.gold_button("Save configuration", func():
		controls.commit_fields()
		if menu.slots.save_stat_configuration(draft.tuning, title.text, description.text):
			show_page(slot)
			menu.message.text = "Configuration saved on this device."
		else:
			menu.message.text = menu.slots.error
			menu.scroll.scroll_vertical = 0
	)
	save.name = "SaveStatConfiguration"
	menu.footer.add_child(save)
	var upload := UI.button("Upload stats to Community", func():
		controls.commit_fields()
		var code := Stats.encode(draft.tuning, title.text, description.text)
		if not menu.slots.save_shared(code):
			menu.message.text = menu.slots.error
			return
		if menu.app.public_builds.queue_export(code): menu.app.public_builds.flush()
		menu.message.text = menu.app.public_builds.status
		menu.upload_revision = menu.view_revision
		menu.scroll.scroll_vertical = 0
	)
	upload.name = "UploadStatConfiguration"
	menu.footer.add_child(upload)

func show_import() -> void:
	menu.clear("Import stat configuration")
	menu.add_back(UI.button("Back", show_page.bind(slot)))
	menu.content.add_child(UI.paragraph("Paste a stat configuration export code. World builds use My builds instead.", 14))
	var code := code_field("")
	code.name = "StatImportCode"
	var import_button := UI.gold_button("Import", func():
		var configuration := Stats.decode(code.text)
		if configuration.is_empty():
			menu.message.text = "Invalid or unsupported stat configuration. Existing configurations are unchanged."
		elif menu.slots.save_stat_configuration(configuration.tuning, configuration.setup.name, configuration.setup.description):
			show_page(slot)
		else:
			menu.message.text = menu.slots.error
	)
	import_button.name = "ConfirmStatImport"
	menu.footer.add_child(import_button)

func code_field(value: String) -> TextEdit:
	var code := TextEdit.new()
	code.text = value
	code.custom_minimum_size.y = 220
	code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code.accessibility_name = "Stat configuration code"
	menu.content.add_child(code)
	return code

func show_code(code: String) -> void:
	menu.clear("Export stat configuration")
	menu.add_back(UI.button("Back", show_page.bind(slot)))
	menu.content.add_child(UI.paragraph("Copy this code to transfer gameplay statistics to another device.", 14))
	code_field(code).editable = false
	var copy := UI.button("Copy export code", func():
		DisplayServer.clipboard_set(code)
		menu.message.text = "Export code copied."
	)
	copy.name = "CopyStatExport"
	menu.footer.add_child(copy)
