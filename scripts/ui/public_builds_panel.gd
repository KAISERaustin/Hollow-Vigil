extends RefCounted

const UI = preload("res://scripts/ui/shared/interface.gd")
var menu: Control

func show_page(slot: int = -1, page: int = 0) -> void:
	menu.clear("Public Builds")
	var revision: int = menu.view_revision
	menu.content.add_child(UI.paragraph("Worlds and rules shared by other players. Choose a build for a new Creative or Survival playthrough.", 14))
	menu.add_action(UI.button("Back to world options" if slot >= 0 else "Back to saves", func():
		if slot >= 0: menu.show_creation(slot, false)
		else: menu.show_slots()
	))
	menu.message.text = "Loading public builds…"
	var result: Dictionary = await menu.app.public_builds.list_page(page)
	if not is_instance_valid(menu) or menu.view_revision != revision:
		return
	if not result.ok or not result.data is Array:
		menu.message.text = "Couldn't load public builds. Check your connection and try again."
		menu.add_action(UI.button("Retry", show_page.bind(slot, page)))
		return
	menu.message.text = "No public builds yet." if result.data.is_empty() else "Page %d" % (page + 1)
	for build in result.data:
		menu.content.add_child(UI.heading(str(build.title), 18))
		menu.content.add_child(UI.paragraph("By %s · %s" % [build.author_name, str(build.created_at).replace("T", " ").replace("+00:00", " UTC").replace("Z", " UTC")], 13))
		menu.content.add_child(UI.paragraph(str(build.description), 14))
		var choose := UI.button("Use this build", select_build.bind(str(build.id), slot, revision))
		choose.name = "SelectPublicBuild" + str(result.data.find(build))
		menu.add_action(choose)
		menu.content.add_child(UI.rule())
	if page > 0:
		menu.add_action(UI.button("Previous page", show_page.bind(slot, page - 1)))
	if result.data.size() == 20:
		menu.add_action(UI.button("Next page", show_page.bind(slot, page + 1)))
	menu.add_action(UI.button("Refresh", show_page.bind(slot, 0)))

func select_build(id: String, slot: int, revision: int) -> void:
	if menu.view_revision != revision:
		return
	menu.message.text = "Reading configuration…"
	var configuration: Dictionary = await menu.app.public_builds.read_build(id)
	if not is_instance_valid(menu) or menu.view_revision != revision:
		return
	if configuration.is_empty():
		menu.message.text = "This build is unavailable or incompatible. Your saves are unchanged."
		return
	menu.selected_configuration = configuration
	if slot >= 0:
		menu.show_creation(slot, false)
		return
	menu.creation_mode = "creative"
	menu.clear("Choose a save for this build")
	menu.content.add_child(UI.paragraph(configuration.name, 18))
	var available := false
	for index in range(VigilSaveSlots.COUNT):
		if not menu.slots.occupied(index):
			available = true
			menu.add_action(UI.button("Create in save %d" % (index + 1), menu.show_creation.bind(index, false)))
	if not available:
		menu.content.add_child(UI.paragraph("All three saves are occupied. Archive a save from Your saves to free a slot, then choose this build again.", 14))
	menu.add_action(UI.button("Back to public builds", show_page.bind(-1, 0)))
	menu.add_action(UI.button("Your saves", menu.show_slots))
