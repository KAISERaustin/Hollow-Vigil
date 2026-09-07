extends Node
## Shared local/community catalog for any portable configuration family.
const UI = preload("res://scripts/ui/shared/interface.gd")
var menu: Control
var kind := "stats"
var selected: Callable
var back: Callable
var create: Callable
var level := -1

func show_page(community: bool = false, page: int = 0) -> void:
	menu.clear("Community stats" if community and kind.ends_with("stats") else "Choose stats" if kind.ends_with("stats") else "Choose campaign build")
	menu.message.custom_minimum_size.y = UI.type_size(16)
	var revision: int = menu.view_revision
	menu.add_back(UI.button("Back", back))
	menu.content.add_child(UI.paragraph("uull campaign builds include all 20 levels, wave schedules and gameplay rules. Play in Survival or edit a copy in Creative." if kind == "campaign" else "Choose gameplay rules for a fresh start, with no towers or progress." if kind.ends_with("stats") else "Choose a campaign setup with towers, equipment and gameplay rules.", 14))
	var sources := HBoxContainer.new()
	menu.content.add_child(sources)
	for source in [false, true]:
		var button := UI.button("Community" if source else "On this device", show_page.bind(source, 0))
		button.name = "CommunityConfigurations" if source else "OfflineConfigurations"
		button.toggle_mode = true
		button.button_pressed = source == community
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sources.add_child(button)
	if create.is_valid():
		var button := UI.button("Create configuration", create)
		button.name = "CreateStatConfiguration"
		menu.content.add_child(button)
	if not community:
		var entries: Array = menu.slots.shared_configurations(kind)
		var count := 0
		for entry in entries:
			if not compatible(entry): continue
			add_entry(entry, false, revision)
			count += 1
		if count == 0: menu.message.text = "No saved configurations yet. Create one or browse Community."
		return
	menu.message.text = "Loading community configurations…"
	var result: Dictionary = await menu.app.public_builds.list_configurations(page, kind, level)
	if not is_instance_valid(menu) or menu.view_revision != revision: return
	if not result.get("ok", false) or not result.get("data") is Array:
		menu.message.text = "Couldn't load community configurations. Check your connection or choose On this device."
		menu.content.add_child(UI.button("Retry", show_page.bind(true, page)))
		return
	menu.message.text = "No community configurations yet." if result.data.is_empty() else "Page %d" % (page + 1)
	for row in result.data:
		add_entry({"name": row.title, "description": row.description, "author": row.author_name, "id": row.id}, true, revision)
	if page > 0: menu.content.add_child(UI.button("Previous page", show_page.bind(true, page - 1)))
	if result.data.size() == 20: menu.content.add_child(UI.button("Next page", show_page.bind(true, page + 1)))

func compatible(entry: Dictionary) -> bool:
	if level < 0: return true
	return int(VigilSaveSlots.CampaignBuild.decode(entry.code).get("level", -1)) == level

func add_entry(entry: Dictionary, community: bool, revision: int) -> void:
	var card: VBoxContainer = menu.add_card(entry.name)
	if community: card.add_child(UI.paragraph("By " + str(entry.author), 13))
	card.add_child(UI.paragraph(entry.description, 14))
	var use := UI.button("Use these stats" if kind.ends_with("stats") else "Use this build", func():
		var value: Dictionary = await menu.app.public_builds.read_build(entry.id) if community else entry
		if not is_instance_valid(menu) or menu.view_revision != revision: return
		if value.is_empty() or value.get("kind", kind) != kind or not compatible(value):
			menu.message.text = "This configuration is unavailable, incompatible, or belongs to another campaign level."
			menu.scroll.scroll_vertical = 0
			return
		selected.call(value)
	)
	use.name = "UseStatConfiguration" if kind.ends_with("stats") else "UseCampaignBuild"
	card.add_child(use)
	if community:
		card.add_child(UI.button("Save on this device", func():
			var value: Dictionary = await menu.app.public_builds.read_build(entry.id)
			if not is_instance_valid(menu) or menu.view_revision != revision: return
			menu.message.text = "Saved on this device." if not value.is_empty() and value.get("kind") == kind and menu.slots.save_shared(value.code) else "Couldn't save this configuration."
			menu.scroll.scroll_vertical = 0
		))
