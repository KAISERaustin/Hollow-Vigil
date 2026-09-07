extends "res://scripts/ui/save_slots_panel.gd"
## Shared navigation owner. Game-specific behavior lives in save/build/session services.
const Build = preload("res://scripts/persistence/reusable_build.gd")
const CampaignSlots = preload("res://scripts/persistence/campaign_slots.gd")
const CheckList = preload("res://scripts/ui/shared/contents_checklist.gd")
const Confirm = preload("res://scripts/ui/shared/confirmation_popup.gd")
var campaign_slots := CampaignSlots.new()
var game_type := "infinite"
var screen := "main"
var navigation_back: Callable
var new_game := {}
var library_return: Callable
var library_from_creation := false
var library_community := false
var library_page := 0
var library_entries: Array = []
var detail_entry := {}
var form := {}
var held := false
var held_paused := false
var pending_publish := ""
var pending_publish_owner := ""
var form_saved_code := ""
var account_return: Callable
var settings_return: Callable
var backup_return: Callable
var rules_return: Callable
var editor_game: VigilState
var rules_editor: Control
var root_layout: VBoxContainer
var restore_choice := {}

func _ready() -> void:
	super._ready()
	name = "UnifiedMenu"
	# Full pages cover gameplay's map rims and short tower dialogs as well.
	z_index = 200
	# One fixed header and action area; only the content scrolls.
	card.remove_child(scroll)
	root_layout = VBoxContainer.new()
	root_layout.add_theme_constant_override("separation", UI.GAP)
	card.add_child(root_layout)
	header.reparent(root_layout, false)
	root_layout.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer.reparent(root_layout, false)
	if not app.load_saved_progress:
		slots.base_path = app.game.save_path + ".unified"
	campaign_slots.base_path = slots.base_path
	show_main_menu()

func fit() -> void:
	var safe := UI.safe_rect(app).grow(-12 if app.size.x < 390 else -16)
	card.size = Vector2(minf(680, safe.size.x), safe.size.y)
	card.position = Vector2(safe.get_center().x - card.size.x * 0.5, safe.position.y)

func page_view(key: String, title: String, back: Callable) -> void:
	screen = key
	clear(title)
	message.hide()
	navigation_back = back
	if back.is_valid(): add_back(UI.button("Back", go_back))
	show()
	move_to_front()

func go_back() -> void:
	if navigation_back.is_valid(): navigation_back.call()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()

func action(text: String, callback: Callable, key: String, primary: bool = false) -> Button:
	var button := UI.gold_button(text, callback, 52) if primary else UI.button(text, callback)
	button.name = key
	return button

func style_entry(entry: Control) -> void:
	super.style_entry(entry)
	entry.custom_minimum_size.y = maxf(entry.custom_minimum_size.y, UI.TARGET)

func notice(text: String) -> void:
	message.text = text
	message.visible = not text.is_empty()

func show_main_menu() -> void:
	page_view("main", "Hollow Vigil", Callable())
	header.hide()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var welcome := preload("res://scripts/ui/welcome_menu.gd").new()
	welcome.configure(show_home.bind("campaign"), show_home.bind("infinite"))
	content.add_child(welcome)
	footer.add_child(action("Settings", func(): show_settings(show_main_menu), "MainSettings"))

func show_home(type: String = "") -> void:
	if not type.is_empty(): game_type = type
	held = false
	page_view("home", game_type.capitalize(), show_main_menu)
	for entry in [["Continue", show_slots, "Continue"], ["New game", func(): begin_new(), "NewGame"],
		["My builds", func(): open_library(false), "MyBuilds"], ["Community", func(): open_library(true), "Community"]]:
		content.add_child(action(entry[0], entry[1], entry[2], entry[0] == "Continue"))
	footer.add_child(action("Backups", func(): show_backups(show_home), "Backups"))
	footer.add_child(action("Settings", func(): show_settings(show_home), "Settings"))

func slot_summary(slot: int) -> Dictionary:
	return campaign_slots.summary(slot) if game_type == "campaign" else slots.summary(slot)

func slot_occupied(slot: int) -> bool:
	return campaign_slots.occupied(slot) if game_type == "campaign" else slots.occupied(slot)

func game_name(value: Dictionary, slot: int = -1) -> String:
	return value.get("name", value.get("setup", {}).get("name", "Game %d" % (slot + 1)))

func progress_text(value: Dictionary, type: String = "") -> String:
	if type.is_empty(): type = game_type
	if type == "campaign":
		var checkpoint: Dictionary = value.get("checkpoint", {})
		var text := "%d of %d levels completed" % [value.get("completed", 0), Build.Configuration.Catalog.COUNT]
		if not checkpoint.is_empty() and checkpoint.phase != "victory":
			text += "\nLevel %d · Start of wave %d" % [int(checkpoint.level) + 1, int(checkpoint.wave) + 1]
		return text
	return "%d explored tiles · %d towers" % [value.get("regions", {}).size(), value.get("towers", {}).size()]

func show_slots() -> void:
	page_view("slots", "Saved games", open_game_menu if held else show_home)
	content.add_child(UI.paragraph(game_type.capitalize() + " · Three slots shared by Creative and Survival."))
	for slot in 3:
		var value := slot_summary(slot)
		var exists := slot_occupied(slot)
		var body := add_card("Slot %d" % (slot + 1))
		body.name = "GameSlot" + str(slot + 1)
		if value.is_empty():
			body.add_child(UI.paragraph("Recovery needed. Your game is preserved." if exists else "Empty slot"))
			var button := action("New game", begin_new.bind(slot), "NewGameSlot" + str(slot + 1))
			button.disabled = exists
			body.add_child(button)
		else:
			body.add_child(UI.heading(game_name(value, slot), 18))
			body.add_child(UI.paragraph(str(value.get("mode", "creative")).capitalize() + "\n" + progress_text(value)))
			body.add_child(UI.paragraph(backup_status(game_type, slot)))
			body.add_child(action("Continue game", continue_game.bind(slot), "ContinueGameSlot" + str(slot + 1), true))

func begin_new(slot: int = -1, entry: Dictionary = {}) -> void:
	new_game = {"mode": "", "slot": slot, "name": "", "entry": entry.duplicate(true), "choices": {}}
	show_play_style()

func show_creation(slot: int, reset: bool = true) -> void:
	if reset or new_game.is_empty(): begin_new(slot)
	else: show_play_style()

func show_play_style() -> void:
	page_view("play_style", "New game", show_slots if int(new_game.slot) >= 0 else show_home)
	content.add_child(UI.heading("1. Play style", 18))
	for mode in ["creative", "survival"]:
		var choose := action(mode.capitalize(), func():
			new_game.mode = mode
			show_play_style()
		, "Choose" + mode.capitalize(), new_game.mode == mode)
		choose.toggle_mode = true
		choose.button_pressed = new_game.mode == mode
		content.add_child(choose)
		content.add_child(UI.paragraph("Edit rules while you play. All Campaign levels are available." if mode == "creative" else "Play with the chosen rules locked. Unlock Campaign levels in order."))
	var next := action("Next", show_starting_build, "NextPlayStyle", true)
	next.disabled = new_game.mode.is_empty()
	footer.add_child(next)

func show_starting_build() -> void:
	page_view("starting_build", "New game", show_play_style)
	content.add_child(UI.heading("2. Starting build", 18))
	content.add_child(action("Original", func():
		new_game.entry = {}
		new_game.choices = {}
		show_starting_build()
	, "ChooseOriginal", new_game.entry.is_empty()))
	content.add_child(action("My builds", func(): open_library(false, true), "ChooseMyBuilds"))
	content.add_child(action("Community", func(): open_library(true, true), "ChooseCommunity"))
	if new_game.entry.is_empty(): content.add_child(UI.paragraph("Original rules and a fresh starting layout."))
	else:
		content.add_child(UI.heading(new_game.entry.name, 18))
		content.add_child(UI.paragraph(Build.scope_label(new_game.entry.build) + "\n" + Build.summary(new_game.entry.build)))
	footer.add_child(action("Review", show_review, "ReviewNewGame", true))

func show_review() -> void:
	page_view("review", "New game", show_starting_build)
	content.add_child(UI.heading("3. Review", 18))
	content.add_child(UI.paragraph(game_type.capitalize() + " · " + str(new_game.mode).capitalize()))
	var title := LineEdit.new()
	title.name = "GameName"
	title.placeholder_text = "Name this game"
	title.max_length = 80
	title.text = new_game.name
	style_entry(title)
	title.text_changed.connect(func(text: String): new_game.name = text)
	content.add_child(UI.form_field("Game name", title))
	var destination := OptionButton.new()
	destination.name = "SaveSlotChoice"
	destination.custom_minimum_size.y = UI.TARGET
	destination.add_item("Choose a save slot")
	for slot in 3:
		var value := slot_summary(slot)
		var description := "Empty" if not slot_occupied(slot) else ("Recovery needed" if value.is_empty() else game_name(value, slot))
		destination.add_item("Slot %d · %s" % [slot + 1, description])
		destination.set_item_disabled(slot + 1, slot_occupied(slot) and value.is_empty())
	destination.select(int(new_game.slot) + 1)
	destination.item_selected.connect(func(index: int): new_game.slot = index - 1)
	content.add_child(UI.form_field("Save slot", destination))
	if not new_game.entry.is_empty():
		var build: Dictionary = new_game.entry.build
		content.add_child(UI.heading(new_game.entry.name, 18))
		content.add_child(UI.paragraph(Build.scope_label(build) + "\n" + Build.summary(build)))
		var dependency := Build.dependencies(build)
		if not dependency.is_empty(): content.add_child(UI.paragraph(dependency))
		if build.game_type != game_type:
			content.add_child(UI.paragraph("Only compatible starting stats will be used. Layouts, resources and waves from the other game type are unused."))
			if game_type == "campaign":
				var scope := OptionButton.new()
				scope.name = "ApplyStatsTo"
				scope.custom_minimum_size.y = UI.TARGET
				for text in ["Choose where to apply stats", "Whole campaign", "One level"]: scope.add_item(text)
				scope.select(["", "all", "level"].find(new_game.choices.get("apply_to", "")))
				scope.item_selected.connect(func(index: int): new_game.choices.apply_to = ["", "all", "level"][index]; show_review())
				content.add_child(UI.form_field("Apply to", scope))
				if new_game.choices.get("apply_to") == "level": level_choice("Level", "target_level")
			elif build.scope == "all": level_choice("Use stats from", "source_level")
		if game_type == "campaign": content.add_child(UI.paragraph("Using this build does not unlock levels in Survival. New games open the World map."))
	else: content.add_child(UI.paragraph("Original rules and a fresh starting layout."))
	content.add_child(UI.paragraph("Omitted contents use the game's original defaults. Other saved games stay in their own slots."))
	footer.add_child(action("Start game", request_start, "StartGame", true))

func level_choice(caption: String, key: String) -> void:
	var picker := OptionButton.new()
	picker.name = "LevelChoice_" + key
	picker.custom_minimum_size.y = UI.TARGET
	picker.add_item("Choose a level")
	for index in Build.Configuration.Catalog.COUNT: picker.add_item("%02d · %s" % [index + 1, Build.Configuration.Catalog.level(index).name])
	picker.select(int(new_game.choices.get(key, -1)) + 1)
	picker.item_selected.connect(func(index: int):
		if index == 0: new_game.choices.erase(key)
		else: new_game.choices[key] = index - 1
	)
	content.add_child(UI.form_field(caption, picker))

func request_start() -> void:
	if str(new_game.name).strip_edges().is_empty(): notice("Give this game a name before starting."); return
	if int(new_game.slot) < 0 or int(new_game.slot) >= 3: notice("Choose one of the three save slots."); return
	var prepared := prepare_new()
	if not prepared.ok: notice(prepared.get("error", "This build's contents cannot be used together. Review the selected contents.")); return
	if slot_occupied(int(new_game.slot)):
		confirm("Replace saved game?", "Replace “%s” in %s slot %d? A recovery copy will remain in Backups." % [game_name(slot_summary(int(new_game.slot)), int(new_game.slot)), game_type.capitalize(), int(new_game.slot) + 1], "Replace and start", start_prepared.bind(prepared))
	else: start_prepared(prepared)

func prepare_new() -> Dictionary:
	if new_game.entry.is_empty():
		return {"ok": true, "levels": {}} if game_type == "campaign" else {"ok": true, "snapshot": VigilState.new(0, new_game.mode).data}
	return Build.compose_campaign(new_game.entry.build, new_game.choices) if game_type == "campaign" else Build.infinite_snapshot(new_game.entry.build, new_game.choices, new_game.mode)

func start_prepared(prepared: Dictionary) -> void:
	if not release_session(): return
	var slot := int(new_game.slot)
	if game_type == "campaign":
		var value := {"version": 1, "sequence": 0, "game_type": "campaign", "id": preload("res://scripts/cloud/cloud_codec.gd").uuid(), "name": str(new_game.name).strip_edges(),
			"mode": new_game.mode, "saved_at": Time.get_unix_time_from_system(), "completed": 0, "levels": prepared.levels, "checkpoint": {}}
		if not campaign_slots.replace(slot, value): notice(campaign_slots.error); return
	else:
		var snapshot: Dictionary = prepared.snapshot.duplicate(true)
		snapshot.setup = {"name": str(new_game.name).strip_edges(), "description": ""}
		snapshot.session_id = preload("res://scripts/cloud/cloud_codec.gd").uuid()
		if not replace_infinite(slot, snapshot): return
	continue_game(slot)

func replace_infinite(slot: int, snapshot: Dictionary) -> bool:
	if slot < 0 or slot >= 3 or not slots.storage.valid_data(snapshot): notice("This game could not be restored. Your current games are safe."); return false
	var current := slots.summary(slot)
	if slots.occupied(slot):
		if current.is_empty(): notice("Recover the existing game before replacing this slot."); return false
		var recovery_path := slots.path_for(slot) + ".recovery-" + preload("res://scripts/cloud/cloud_codec.gd").uuid()
		if not slots.storage.write(recovery_path, current): notice(slots.storage.last_error); return false
	snapshot.sequence = maxi(int(snapshot.sequence), int(current.get("sequence", 0))) + 1
	if not slots.storage.write(slots.path_for(slot), snapshot): notice(slots.storage.last_error); return false
	return true

func release_session() -> bool:
	# A restore browser can be entered from a held session. Save that session
	# before opening another slot; the selected destination is never inferred.
	var target_type := game_type
	if live_campaign():
		if not app.campaign.persist_slot(): notice("Couldn't save the open game. Please try again."); return false
		app.campaign.close()
	elif app.slot_active:
		app.persist()
		if not app.game.save_error.is_empty(): notice("Couldn't save the open game. Please try again."); return false
		app.slot_active = false
	game_type = target_type
	held = false
	return true

func continue_game(slot: int) -> void:
	if not release_session(): return
	if game_type == "campaign":
		var value := campaign_slots.summary(slot)
		if value.is_empty(): notice("This Campaign needs recovery before it can continue."); return
		app.open_campaign_slot(slot, value)
	else: app.open_slot(slot)

func confirm(title: String, text: String, confirm_text: String, callback: Callable) -> void:
	var popup := Confirm.new()
	add_child(popup)
	popup.configure(title, text, confirm_text, func(): popup.hide(); callback.call())

func open_library(community: bool, from_creation: bool = false) -> void:
	library_community = community
	library_from_creation = from_creation
	library_return = show_starting_build if from_creation else show_home
	library_page = 0
	show_library()

func show_library() -> void:
	page_view("library", "Community" if library_community else "My builds", library_return)
	content.add_child(UI.paragraph("Named reusable content for new games. Saving a build does not use a game slot."))
	library_entries.clear()
	if not library_community:
		for entry in slots.shared_configurations("all"):
			var converted := slots.reusable_entry(entry)
			if not converted.is_empty() and Build.compatible(converted.build, game_type): library_entries.append(converted)
		show_library_entries()
		return
	notice("Loading Community builds…")
	var revision := view_revision
	var result: Dictionary = await app.public_builds.list_configurations(library_page, "all")
	if revision != view_revision: return
	if not result.get("ok", false) or not result.get("data") is Array:
		notice("Community is unavailable right now. Check your connection and try again.")
		footer.add_child(action("Retry", show_library, "RetryCommunity"))
		return
	for entry in result.data: library_entries.append(entry)
	notice("")
	show_library_entries()
	var paging := HBoxContainer.new()
	paging.add_theme_constant_override("separation", UI.GAP)
	footer.add_child(paging)
	var previous := action("Previous", func(): library_page = maxi(0, library_page - 1); show_library(), "PreviousBuilds")
	previous.disabled = library_page == 0
	paging.add_child(previous)
	var next := action("Next", func(): library_page += 1; show_library(), "NextBuilds")
	next.disabled = library_entries.size() < 20
	paging.add_child(next)
	footer.add_child(action("Refresh", show_library, "RefreshCommunity"))

func show_library_entries() -> void:
	if library_entries.is_empty(): content.add_child(UI.paragraph("No builds here yet."))
	for entry in library_entries:
		var body := add_card(entry.get("name", entry.get("title", "Untitled build")))
		var description: String = entry.get("description", "")
		if not description.is_empty(): body.add_child(UI.paragraph(description))
		if entry.has("build"): body.add_child(UI.paragraph(Build.scope_label(entry.build) + "\n" + Build.summary(entry.build)))
		elif entry.has("contents_summary"): body.add_child(UI.paragraph(entry.contents_summary))
		if entry.has("author_name"): body.add_child(UI.paragraph("By " + str(entry.author_name)))
		body.add_child(action("Details", read_detail.bind(entry), "BuildDetails"))

func read_detail(entry: Dictionary) -> void:
	var value := entry
	if not value.has("build"):
		var revision := view_revision
		notice("Opening build…")
		value = await app.public_builds.read_build(entry.id)
		if revision != view_revision: return
		value = slots.reusable_entry(value)
		if value.is_empty(): notice("This build could not be opened. Try another build or retry when connected."); return
		value.author_name = entry.get("author_name", "Player")
	detail_entry = value.duplicate(true)
	show_detail()

func show_detail() -> void:
	page_view("detail", "Build details", show_library)
	var build: Dictionary = detail_entry.build
	content.add_child(UI.heading(detail_entry.name, 24))
	if not detail_entry.description.is_empty(): content.add_child(UI.paragraph(detail_entry.description))
	if library_community: content.add_child(UI.paragraph("By " + str(detail_entry.get("author_name", "Player"))))
	content.add_child(UI.paragraph(Build.scope_label(build)))
	content.add_child(UI.heading("Contents", 18))
	content.add_child(UI.paragraph(Build.summary(build)))
	content.add_child(UI.paragraph(Build.dependencies(build)))
	content.add_child(UI.paragraph("Compatible starting stats can be used in Campaign and Infinite." if Build.has_stats(build) else "Content for " + build.game_type.capitalize() + "."))
	if not library_community: content.add_child(UI.paragraph("Saved privately on this device. " + library_backup_status()))
	var use := action("Use build", use_detail, "UseBuild", true)
	use.disabled = not Build.compatible(build, game_type)
	footer.add_child(use)
	if library_community:
		footer.add_child(action("Save privately", func():
			if slots.save_shared(detail_entry.code): notice("Saved privately to My builds."); mark_backup_pending()
			else: notice("Couldn't save this build. Please try again.")
		, "SaveCommunityPrivately"))
	else: footer.add_child(action("Share to Community", func(): open_saved_build_form(detail_entry), "SharePrivateBuild"))

func use_detail() -> void:
	if library_from_creation:
		new_game.entry = detail_entry.duplicate(true)
		new_game.choices = {}
		show_starting_build()
	else: begin_new(-1, detail_entry)

func backup_status(_type: String, _slot: int) -> String:
	if is_instance_valid(app.private_backups): return app.private_backups.game_status(_type, _slot)
	return "Saved on this device · Private backup pending" if app.cloud.signed_in() else "Saved on this device · Sign in for automatic backups"

func library_backup_status() -> String:
	if is_instance_valid(app.private_backups): return app.private_backups.library_status()
	return "Private backup pending." if app.cloud.signed_in() else "Sign in for automatic private backup."

func mark_backup_pending() -> void:
	if app.has_method("queue_private_backup"): app.queue_private_backup()

func live_campaign() -> bool:
	return is_instance_valid(app.campaign) and app.campaign.active_campaign_slot >= 0

func open_game_menu() -> void:
	if not held:
		game_type = "campaign" if live_campaign() else "infinite"
		held_paused = app.campaign.paused if live_campaign() else app.simulation_paused
		held = true
		if live_campaign():
			app.campaign.paused = true
			app.campaign.clear_selection()
			if app.campaign.page == "battle": app.campaign.update_time_controls()
		else:
			app.persist()
			app.game.suspended = true
			app.panels.close_sheet()
			app.tower_dialog.dismiss()
			if app.tower_move.visible: app.tower_move.cancel()
	page_view("game_menu", "Menu", resume_game)
	content.add_child(UI.paragraph(game_type.capitalize()))
	content.add_child(action("Resume game", resume_game, "ResumeGame", true))
	var creative: bool = app.campaign.can_author() if live_campaign() else app.game.is_creative()
	if creative: content.add_child(action("Edit rules", open_rules, "EditRules"))
	content.add_child(action("Save build", open_build_form, "SaveBuild"))
	content.add_child(action("Backups", func(): show_backups(open_game_menu), "GameBackups"))
	content.add_child(action("Settings", func(): show_settings(open_game_menu), "GameSettings"))
	footer.add_child(action("Exit game", exit_game, "ExitGame"))

func resume_game() -> void:
	hide()
	if held:
		if live_campaign():
			app.campaign.paused = held_paused
			if app.campaign.page == "battle": app.campaign.update_time_controls()
		else:
			app.simulation_paused = held_paused
			app.game.suspended = false
			app.refresh_time_controls()
	held = false

func exit_game() -> void:
	if live_campaign():
		if not app.campaign.persist_slot(): notice("Couldn't save this Campaign. Keep it open and try again."); return
		app.campaign.close()
	else:
		app.persist()
		if not app.game.save_error.is_empty(): notice("Couldn't save this game. Keep it open and try again."); return
		app.slot_active = false
		app.game.suspended = true
	mark_backup_pending()
	held = false
	show_home()

func open_build_form() -> void:
	var source: VigilState = app.campaign.game if live_campaign() else app.game
	var levels: Dictionary = app.campaign.session_levels() if live_campaign() else {}
	var index: int = app.campaign.run.mission.index if live_campaign() and app.campaign.run != null else -1
	form = {"game_type": game_type, "game": source, "levels": levels, "scope": "all", "level": index,
		"contents": Build.all_contents(game_type), "name": "", "description": "", "return": open_game_menu}
	form_saved_code = ""
	pending_publish = ""
	show_build_form()

func open_saved_build_form(entry: Dictionary) -> void:
	var build: Dictionary = entry.build
	var source: VigilState
	var levels := {}
	if build.game_type == "infinite":
		var composed := Build.infinite_snapshot(build, {}, "creative")
		if not composed.ok: notice("This build's layout needs compatible placement tiles."); return
		source = VigilState.new()
		source.data = composed.snapshot
	else:
		var composed := Build.compose_campaign(build, {})
		if not composed.ok: notice(composed.get("error", "This build has incompatible contents.")); return
		levels = composed.levels
	form = {"game_type": build.game_type, "game": source, "levels": levels, "scope": build.scope, "level": int(build.level),
		"contents": build.contents.duplicate(true), "name": build.setup.name, "description": build.setup.description, "return": show_detail}
	form_saved_code = entry.code
	pending_publish = ""
	show_build_form()

func prepared_form() -> Dictionary:
	return Build.capture(form.game_type, form.game, form.levels, form.scope, int(form.level), form.contents, form.name, form.description)

func show_build_form() -> void:
	page_view("save_build", "Save build", form.get("return", open_game_menu))
	if form.game_type == "campaign":
		var scope := OptionButton.new()
		scope.name = "BuildScope"
		scope.custom_minimum_size.y = UI.TARGET
		scope.add_item("Whole campaign")
		scope.add_item("This level")
		scope.set_item_disabled(1, int(form.level) < 0)
		scope.select(1 if form.scope == "level" else 0)
		scope.item_selected.connect(func(index: int): form.scope = "level" if index == 1 else "all"; show_build_form())
		content.add_child(UI.form_field("Scope", scope))
		if form.scope == "level": content.add_child(UI.paragraph("Level %d · %s" % [int(form.level) + 1, Build.Configuration.Catalog.level(int(form.level)).name]))
	content.add_child(UI.heading("Contents", 18))
	var checklist := CheckList.new()
	checklist.game_type = form.game_type
	checklist.selection = form.contents.duplicate(true)
	content.add_child(checklist)
	var summary := UI.paragraph("")
	summary.name = "IncludedContentsSummary"
	var update_summary := func():
		form.contents = checklist.selection.duplicate(true)
		var preview := {"game_type": form.game_type, "contents": form.contents}
		summary.text = Build.summary(preview) + "\n" + Build.dependencies(preview) + "\nOmitted contents use original defaults."
	checklist.changed.connect(update_summary)
	var title := LineEdit.new()
	title.name = "BuildName"
	title.max_length = 80
	title.placeholder_text = "Name this build"
	title.text = form.name
	style_entry(title)
	title.text_changed.connect(func(text: String): form.name = text)
	content.add_child(UI.form_field("Name", title))
	var description := TextEdit.new()
	description.name = "BuildDescription"
	description.custom_minimum_size.y = 100
	description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description.text = form.description
	style_entry(description)
	description.text_changed.connect(func(): form.description = description.text.left(4000))
	content.add_child(UI.form_field("Description (optional)", description))
	content.add_child(UI.heading("Included contents", 18))
	content.add_child(summary)
	update_summary.call()
	footer.add_child(action("Save privately", submit_build.bind(false), "SavePrivately", true))
	footer.add_child(action("Share to Community", submit_build.bind(true), "ShareToCommunity"))
	if not pending_publish.is_empty(): footer.add_child(action("Retry", retry_share, "RetryShare"))
	if not form_saved_code.is_empty(): notice("Private copy saved in My builds.")

func submit_build(publish: bool) -> void:
	if str(form.name).strip_edges().is_empty(): notice("Name this build before saving."); return
	if form.contents.is_empty(): notice("Choose at least one content group or type."); return
	var build := prepared_form()
	if build.is_empty(): notice("These contents could not be saved. Check the selected contents and try again."); return
	var compatible_content := Build.compose_campaign(build, {}) if build.game_type == "campaign" else Build.infinite_snapshot(build, {}, "creative")
	if not compatible_content.ok: notice(compatible_content.get("error", "This layout needs compatible placement tiles.")); return
	var code := Build.encode(build)
	if not slots.save_shared(code): notice("Couldn't save the private copy. Please try again."); return
	form_saved_code = code
	mark_backup_pending()
	if not publish: notice("Saved privately to My builds. " + library_backup_status()); return
	if not app.cloud.signed_in() or app.cloud.display_name.is_empty():
		show_account(show_build_form)
		notice("Your private copy and selections are ready. Sign in and choose a player name, then return to Share to Community.")
		return
	if pending_publish != code or pending_publish_owner != app.cloud.player_id:
		if not app.public_builds.queue_export(code): notice("Private copy saved. Couldn't prepare Community sharing. Please retry."); return
		pending_publish = code
		pending_publish_owner = app.cloud.player_id
	await retry_share()

func retry_share() -> void:
	if app.public_builds.busy or app.cloud.busy: notice("Another account operation is finishing. Please retry in a moment."); return
	if not app.cloud.signed_in() or app.cloud.display_name.is_empty(): show_account(show_build_form); return
	if pending_publish_owner != app.cloud.player_id:
		# Retry is an explicit publication action for the currently signed-in
		# player. An older account's pending upload remains owned by that account.
		if not app.public_builds.queue_export(pending_publish): notice("Couldn't prepare sharing. Your private copy is safe."); return
		pending_publish_owner = app.cloud.player_id
	var revision := view_revision
	notice("Sharing to Community… Your private copy is saved.")
	await app.public_builds.flush()
	if revision != view_revision: return
	var pending := false
	for item in app.public_builds.outbox:
		if item.owner in ["", pending_publish_owner] and item.configuration.get("checksum") == JSON.parse_string(pending_publish).get("checksum"): pending = true
	if pending:
		show_build_form()
		notice("Private copy saved. Community sharing hasn't finished. Check your connection and choose Retry.")
	else:
		pending_publish = ""
		show_build_form()
		notice("Shared to Community. A private copy is also in My builds.")

func show_export(source: VigilState = null, campaign: Dictionary = {}, return_to: Callable = Callable()) -> void:
	if source == null: source = app.game
	form = {"game_type": "campaign" if not campaign.is_empty() else "infinite", "game": source, "levels": campaign.get("levels", {}),
		"scope": "all", "level": int(campaign.get("index", -1)), "name": "", "description": "", "return": return_to if return_to.is_valid() else open_game_menu}
	form.contents = Build.all_contents(form.game_type)
	form_saved_code = ""
	pending_publish = ""
	show_build_form()

func show_settings(return_to: Callable = Callable()) -> void:
	if return_to.is_valid(): settings_return = return_to
	page_view("settings", "Settings", settings_return)
	content.add_child(action("Account", func(): show_account(show_settings), "SettingsAccount"))
	content.add_child(action("Sound", show_sound, "SettingsSound"))
	if held and (app.campaign.can_author() if live_campaign() else app.game.is_creative()):
		content.add_child(action("Creative tools", show_creative_tools, "CreativeTools"))

func show_sound() -> void:
	page_view("sound", "Sound", show_settings)
	var controls := preload("res://scripts/audio/audio_settings.gd").new()
	controls.app = app
	controls.return_to = show_sound
	content.add_child(controls)

func show_creative_tools() -> void:
	page_view("creative_tools", "Creative tools", show_settings)
	var field: Battlefield = app.campaign.field if live_campaign() else app.field
	var game: VigilState = app.campaign.game if live_campaign() else app.game
	if field != null:
		var camera := CheckList.check_box("Unrestricted zoom and pan", field.unrestricted_camera, field.set_unrestricted_camera)
		camera.name = "UnrestrictedCamera"
		content.add_child(camera)
		var health := CheckList.check_box("Show enemy and boss health", field.show_health_numbers, func(enabled: bool): field.show_health_numbers = enabled; field.queue_redraw())
		health.name = "ShowHealthNumbers"
		content.add_child(health)
	if game != null:
		content.add_child(action("Add 1,000,000 gold", func():
			game.add_developer_gold()
			if live_campaign(): app.campaign.persist()
			else: app.persist()
			notice("Gold added to this Creative game.")
		, "AddMillionGold"))

func show_account(return_to: Callable = Callable()) -> void:
	if return_to.is_valid(): account_return = return_to
	page_view("account", "Account", account_return)
	if app.cloud.signed_in():
		content.add_child(UI.paragraph("Signed in as " + app.cloud.email))
		var player_name := LineEdit.new()
		player_name.name = "PlayerName"
		player_name.max_length = app.cloud.MAX_NAME_LENGTH
		player_name.text = app.cloud.display_name
		style_entry(player_name)
		content.add_child(UI.form_field("Player name", player_name))
		content.add_child(action("Save name", func():
			var text := player_name.text
			await app.cloud.save_player_name(text)
			if screen == "account": notice(app.cloud.status)
		, "SavePlayerName"))
		content.add_child(action("Sign out", func(): app.cloud.sign_out(); show_account(), "SignOut"))
	else:
		content.add_child(UI.paragraph("Sign in for automatic private backups and Community sharing. Private saving is available offline."))
		var email := LineEdit.new()
		email.name = "AccountEmail"
		email.placeholder_text = "Email address"
		email.text = app.cloud.email
		email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		style_entry(email)
		content.add_child(UI.form_field("Email", email))
		content.add_child(action("Email me a sign-in code", func():
			await app.cloud.send_code(email.text)
			if screen == "account": notice(app.cloud.status)
		, "SendSignInCode"))
		var code := LineEdit.new()
		code.name = "AccountCode"
		code.placeholder_text = "Code or sign-in link"
		style_entry(code)
		content.add_child(UI.form_field("Sign-in code", code))
		content.add_child(preload("res://scripts/ui/shared/clipboard_entry.gd").paste_button(code))
		content.add_child(action("Sign in", func():
			await app.cloud.verify_link(code.text)
			if screen == "account": show_account(); notice(app.cloud.status)
		, "SignIn", true))
		if app.cloud.has_saved_session():
			content.add_child(action("Retry sign-in", func():
				await app.cloud.restore_session()
				if screen == "account": show_account(); notice(app.cloud.status)
			, "RetrySignIn"))
	footer.add_child(action("Done", func(): account_return.call(), "AccountDone", true))

func open_rules() -> void:
	if live_campaign(): show_rule_levels()
	else: show_infinite_rules()

func show_rule_levels() -> void:
	page_view("rule_levels", "Edit rules", open_game_menu)
	for index in Build.Configuration.Catalog.COUNT:
		content.add_child(action("%02d · %s" % [index + 1, Build.Configuration.Catalog.level(index).name], show_campaign_rules.bind(index), "EditLevel" + str(index + 1)))

func show_infinite_rules() -> void:
	page_view("rules", "Edit rules", rules_back)
	editor_game = VigilState.new(42, "creative", app.game.tuning)
	content.add_child(UI.paragraph("Changes stay in this draft until you choose Apply changes."))
	rules_editor = preload("res://scripts/ui/developer/developer_controls.gd").new()
	rules_editor.game = editor_game
	rules_editor.configuration_only = true
	rules_editor.categories.assign(Build.STAT_GROUPS + ["session"])
	content.add_child(rules_editor)
	footer.add_child(action("Apply changes", func():
		rules_editor.commit_fields()
		if app.game.apply_balance(editor_game.tuning): app.persist(); open_game_menu()
		else: notice("These changes could not be applied.")
	, "ApplyRules", true))
	footer.add_child(action("Cancel", cancel_rules, "CancelRules"))

func show_campaign_rules(index: int, wave: int = -1, return_to: Callable = Callable()) -> void:
	rules_return = return_to if return_to.is_valid() else show_rule_levels
	page_view("rules", "Edit rules", rules_back)
	var store := Build.Configuration.new()
	store.data.levels[str(index)] = app.campaign.level_setup(index).overrides.duplicate(true)
	rules_editor = preload("res://scripts/campaign/balance_panel.gd").new()
	rules_editor.store = store
	rules_editor.index = index
	rules_editor.initial_scope = wave
	rules_editor.shared_page = true
	if app.campaign.run != null and app.campaign.run.mission.index == index and app.campaign.page == "battle" and app.campaign.run.editable(): rules_editor.live_run = app.campaign.run
	rules_editor.apply_changes = app.campaign.save_configuration
	rules_editor.saved.connect(func(): app.campaign.persist_slot(); rules_return.call())
	content.add_child(rules_editor)
	footer.add_child(action("Apply changes", func(): rules_editor.save_changes(), "ApplyRules", true))
	footer.add_child(action("Cancel", cancel_rules, "CancelRules"))

func rules_back() -> void:
	var controls: Control = rules_editor.controls if live_campaign() else rules_editor
	if controls.editor.visible:
		controls.show_categories()
		scroll.scroll_vertical = 0
	else: cancel_rules()

func cancel_rules() -> void:
	confirm("Discard rule changes?", "Leave this draft and keep the game's existing rules?", "Discard changes", rules_return if live_campaign() else open_game_menu)

func show_backups(return_to: Callable = Callable()) -> void:
	if return_to.is_valid(): backup_return = return_to
	page_view("backups", "Backups", backup_return)
	content.add_child(UI.paragraph("Private protection for all six saved-game slots and My builds. Campaign battles recover at the start of the current wave."))
	content.add_child(action("Account", func(): show_account(show_backups), "BackupAccount"))
	if not is_instance_valid(app.private_backups): return
	var backups: Node = app.private_backups
	notice(backups.status)
	var backup := action("Back up now", func():
		var revision := view_revision
		await backups.sync_now()
		if revision == view_revision: show_backups()
	, "BackUpNow", true)
	backup.disabled = not app.cloud.signed_in() or backups.busy
	footer.add_child(backup)
	content.add_child(UI.paragraph("Back up now protects all six slots and every private build. Automatic backups retry when connected; differing versions wait for your choice."))
	content.add_child(UI.heading("Saved games", 18))
	for type in ["campaign", "infinite"]:
		for slot in 3:
			var value: Dictionary = campaign_slots.summary(slot) if type == "campaign" else slots.summary(slot)
			if value.is_empty(): continue
			content.add_child(UI.paragraph("%s · %s\n%s" % [type.capitalize(), game_name(value, slot), backups.game_status(type, slot)]))
	for remote in backups.remote_games:
		var body := add_card(str(remote.get("name", "Saved game")))
		body.add_child(UI.paragraph("%s · %s · Slot %d\n%s" % [str(remote.game_type).capitalize(), str(remote.get("mode", "creative")).capitalize(), int(remote.slot_number) + 1, remote.get("progress", "Saved progress")]))
		body.add_child(action("Restore backup", begin_restore.bind(remote), "RestoreBackup"))
	content.add_child(UI.heading("My builds", 18))
	content.add_child(UI.paragraph(backups.library_status() + " Private builds from your account are recovered automatically when connected."))
	content.add_child(action("Recover My builds", func():
		var revision := view_revision
		await backups.sync_now()
		if revision == view_revision: show_backups()
	, "RecoverMyBuilds"))
	content.add_child(UI.heading("Recovery copies on this device", 18))
	content.add_child(UI.paragraph("Replaced games stay here until you choose to restore them. Restoring uses one of the matching game type's three slots."))
	var recoveries: Array = backups.recovery_games()
	if recoveries.is_empty(): content.add_child(UI.paragraph("No recovery copies yet."))
	for recovery in recoveries:
		var body := add_card(game_name(recovery.snapshot))
		body.add_child(UI.paragraph(str(recovery.game_type).capitalize() + "\n" + progress_text(recovery.snapshot, recovery.game_type)))
		body.add_child(action("Restore backup", func():
			restore_choice = {"game_type": recovery.game_type, "snapshot": recovery.snapshot.duplicate(true), "source": "recovery", "destination": -1, "revision": 0, "slot_number": -1}
			show_restore_destination()
		, "RestoreRecoveryCopy"))

func begin_restore(remote: Dictionary) -> void:
	var revision := view_revision
	notice("Opening private backup…")
	var value: Dictionary = await app.private_backups.read_backup(remote.game_type, int(remote.slot_number))
	if revision != view_revision: return
	if value.is_empty(): notice("This backup couldn't be opened. Your local games are safe. Check your connection and retry."); return
	restore_choice = value.duplicate(true)
	restore_choice.source = "cloud"
	restore_choice.game_type = remote.game_type
	restore_choice.slot_number = int(remote.slot_number)
	restore_choice.destination = -1
	show_restore_destination()

func show_restore_destination() -> void:
	page_view("restore_destination", "Restore backup", show_backups)
	var type: String = restore_choice.game_type
	var snapshot: Dictionary = restore_choice.snapshot
	content.add_child(UI.heading(game_name(snapshot), 18))
	content.add_child(UI.paragraph(type.capitalize() + "\n" + progress_text(snapshot, type)))
	content.add_child(UI.paragraph("Choose a destination. Restoring recovers the complete saved game, including its rules, towers and equipment."))
	for slot in 3:
		var local: Dictionary = campaign_slots.summary(slot) if type == "campaign" else slots.summary(slot)
		var exists: bool = campaign_slots.occupied(slot) if type == "campaign" else slots.occupied(slot)
		var name := "Empty" if not exists else ("Recovery needed" if local.is_empty() else game_name(local, slot))
		var choose := action("Slot %d · %s" % [slot + 1, name], func(): restore_choice.destination = slot; review_restore(), "RestoreIntoSlot" + str(slot + 1))
		choose.disabled = exists and local.is_empty()
		content.add_child(choose)

func session_identity(value: Dictionary, type: String) -> String:
	if type == "campaign": return value.get("id", "")
	return value.get("session_id", value.get("cloud", {}).get("world_id", "legacy-" + str(value.get("seed", 0))))

func version_summary(value: Dictionary, type: String) -> String:
	var checkpoint: Dictionary = value.get("checkpoint", {})
	var state: Dictionary = checkpoint.get("state", {}) if type == "campaign" else value
	var saved := float(value.get("saved_at", value.get("last_accounted", 0)))
	var timestamp := Time.get_datetime_string_from_unix_time(int(saved)).replace("T", " ") + " UTC" if saved > 0 else "Time unavailable"
	var rules: Dictionary = value.get("levels", {}) if type == "campaign" else value.get("settings", {}).get("developer_balance", {})
	return progress_text(value, type) + "\nSaved " + timestamp + "\n%s gold · %d towers · %d gear items\n%s" % [UI.exact_money(float(state.get("balance", 0))), state.get("towers", {}).size(), state.get("relics", {}).size(), "Custom rules included" if not rules.is_empty() else "Original rules"]

func review_restore() -> void:
	page_view("restore_review", "Restore backup", show_restore_destination)
	var type: String = restore_choice.game_type
	var destination := int(restore_choice.destination)
	var local: Dictionary = campaign_slots.summary(destination) if type == "campaign" else slots.summary(destination)
	var remote: Dictionary = restore_choice.snapshot
	content.add_child(UI.heading("Backup · " + game_name(remote), 18))
	content.add_child(UI.paragraph(version_summary(remote, type)))
	if not local.is_empty():
		content.add_child(UI.heading("This device · " + game_name(local, destination), 18))
		content.add_child(UI.paragraph(version_summary(local, type)))
		content.add_child(UI.paragraph("The replaced game will remain in Recovery copies on this device. There are still only three active %s slots." % type.capitalize()))
		if session_identity(local, type) == session_identity(remote, type) and restore_choice.source == "cloud":
			content.add_child(UI.paragraph("Choose which version to keep. Neither version is selected automatically."))
			footer.add_child(action("Keep this device's version", keep_device_version, "KeepDeviceVersion"))
			footer.add_child(action("Use cloud version", func(): confirm("Use cloud version?", "Replace this device's progress for “%s” with the reviewed cloud version?" % game_name(local, destination), "Restore backup", apply_restore), "UseCloudVersion", true))
			return
		var same_game := session_identity(local, type) == session_identity(remote, type)
		content.add_child(UI.paragraph("This will recover earlier progress for “%s” in slot %d." % [game_name(local, destination), destination + 1] if same_game else "This will replace the different game “%s” in slot %d." % [game_name(local, destination), destination + 1]))
		if restore_choice.source == "cloud" and destination == int(restore_choice.slot_number):
			footer.add_child(action("Keep this device's version", func(): confirm("Replace the cloud game?", "Keep “%s” on this device and replace the cloud backup “%s”?" % [game_name(local, destination), game_name(remote)], "Keep this device's version", keep_device_version), "KeepDeviceVersion"))
	footer.add_child(action("Restore backup", func():
		var title := "Restore into empty slot?" if local.is_empty() else "Replace “%s”?" % game_name(local, destination)
		confirm(title, "Restore “%s” into %s slot %d?" % [game_name(remote), type.capitalize(), destination + 1], "Restore backup", apply_restore)
	, "ConfirmRestoreBackup", true))
	footer.add_child(action("Cancel", show_backups, "CancelRestore"))

func keep_device_version() -> void:
	var type: String = restore_choice.game_type
	var destination := int(restore_choice.destination)
	var revision := view_revision
	# Only replace the reviewed cloud slot when this device's corresponding slot
	# is the one being compared. Choosing local never calls a restore operation.
	if destination == int(restore_choice.slot_number):
		await app.private_backups.keep_local(type, destination, int(restore_choice.revision))
	if revision != view_revision: return
	game_type = type
	show_slots()

func apply_restore() -> void:
	var type: String = restore_choice.game_type
	var destination := int(restore_choice.destination)
	if live_campaign() and type == "campaign" and app.campaign.active_campaign_slot == destination:
		notice("Exit the current game before restoring over its slot.")
		return
	if app.slot_active and type == "infinite" and app.active_slot == destination and held:
		notice("Exit the current game before restoring over its slot.")
		return
	var ok: bool = campaign_slots.replace(destination, restore_choice.snapshot) if type == "campaign" else replace_infinite(destination, restore_choice.snapshot)
	if not ok: notice("Couldn't restore the backup. Your current game is preserved."); return
	if restore_choice.source == "cloud": app.private_backups.accept_restored(type, destination, int(restore_choice.slot_number), int(restore_choice.revision))
	game_type = type
	show_slots()
	notice("Backup restored. Choose Continue game when you're ready.")
