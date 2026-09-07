extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
const Stats = preload("res://scripts/persistence/stat_configuration.gd")
const Controls = preload("res://scripts/ui/developer/developer_controls.gd")
var menu: Control
var slot := -1
var draft: VigilState

func show_page(target_slot: int = -1) -> void:
	slot = target_slot
	menu.clear("Stat configurations")
	menu.add_back(UI.button("Back", menu.show_creation.bind(slot, false) if slot >= 0 else menu.show_slots))
	menu.content.add_child(UI.paragraph("Gameplay statistics only. Each configuration starts a fresh world with no buildings or progress.", 14))
	var create := UI.button("Create configuration", show_editor.bind({}))
	create.name = "CreateStatConfiguration"
	menu.content.add_child(create)
	if menu.app.slot_active:
		var current := UI.button("Copy current game's stats", func():
			show_editor({"tuning": menu.app.game.tuning, "setup": menu.app.game.data.get("setup", {})})
		)
		current.name = "CopyCurrentStats"
		menu.content.add_child(current)
	var import_button := UI.button("Import configuration code", show_import)
	import_button.name = "ImportStatConfiguration"
	menu.content.add_child(import_button)
	for configuration in menu.slots.stat_configurations():
		var card: VBoxContainer = menu.add_card(configuration.name)
		card.add_child(UI.paragraph(configuration.description, 14))
		if slot >= 0:
			var use := UI.button("Use these stats", func():
				menu.selected_configuration = configuration
				menu.starting_rules = {}
				menu.show_creation(slot, false)
			)
			use.name = "UseStatConfiguration"
			card.add_child(use)
		card.add_child(UI.button("Edit a copy", show_editor.bind(Stats.decode(configuration.code))))
		card.add_child(UI.button("Export code", show_code.bind(configuration.code)))

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
