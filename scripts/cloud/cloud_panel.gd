extends VBoxContainer

const UI = preload("res://scripts/ui/shared/interface.gd")
var app: VigilApp
var service: Node
var confirmation_world := ""
var confirm_local := false
var confirm_campaign := ""
var restore_slot := 0
var name_draft := ""
var name_edited := false

func _ready() -> void:
	service = app.cloud
	service.changed.connect(rebuild)
	restore_slot = app.active_slot
	if is_instance_valid(app.campaign_backup): app.campaign_backup.changed.connect(rebuild)
	rebuild()

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)
	add_child(UI.paragraph(service.status, 14))
	if not service.configured():
		return
	if not service.signed_in():
		name_draft = ""
		name_edited = false
		if service.has_saved_session():
			var retry := UI.button("Retry sign-in", service.restore_session)
			retry.name = "RetryAccountSession"
			retry.disabled = service.busy
			add_child(retry)
		var address := LineEdit.new()
		address.name = "CloudEmail"
		address.placeholder_text = "Email address"
		address.text = service.email
		address.custom_minimum_size.y = 48
		address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		add_child(address)
		add_child(_button("Email me a sign-in code", func(): service.send_code(address.text)))
		if not service.email.is_empty():
			var code := LineEdit.new()
			code.name = "CloudSignInLink"
			code.placeholder_text = "Email code or sign-in link"
			code.secret = true
			code.custom_minimum_size.y = 48
			code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
			add_child(code)
			add_child(preload("res://scripts/ui/shared/clipboard_entry.gd").paste_button(code))
			add_child(_button("Sign in", func(): service.verify_link(code.text)))
		add_child(UI.paragraph("No password is needed. Your sign-in is remembered on this device until you sign out. Offline play always works.", 12))
		return
	if confirmation_world != "":
		add_child(UI.paragraph("Replace the game in the selected Infinite slot with this cloud backup? This also restores its Creative or Survival mode and rules. Your current game is kept in a local recovery file. Separate progress is not merged.", 14))
		add_child(_button("Restore cloud progress", func():
			var selected := confirmation_world
			confirmation_world = ""
			app.restore_infinite_backup(restore_slot, selected)))
		add_child(_button("Cancel", func(): confirmation_world = ""; rebuild()))
		return
	if confirm_local:
		add_child(UI.paragraph("Replace the cloud version with this device's current progress? Other devices will need to restore this version. Their separate progress will not be merged.", 14))
		add_child(_button("Use this device's progress", func(): confirm_local = false; app.upload_infinite_backup(service.backup_slot if service.backup_slot >= 0 else app.active_slot, true)))
		add_child(_button("Cancel", func(): confirm_local = false; rebuild()))
		return
	add_child(UI.heading("Player name", 18))
	var player_name := LineEdit.new()
	player_name.name = "PlayerNameInput"
	player_name.accessibility_name = "Player name"
	player_name.placeholder_text = "Choose your player name"
	player_name.text = name_draft if name_edited else service.display_name
	player_name.max_length = service.MAX_NAME_LENGTH
	player_name.custom_minimum_size.y = 48
	player_name.expand_to_text_length = false
	player_name.editable = not service.busy
	player_name.text_changed.connect(func(value: String): name_draft = value; name_edited = true)
	add_child(player_name)
	var save_name := UI.button("Save name", func(): service.save_player_name(player_name.text))
	save_name.name = "SavePlayerName"
	save_name.disabled = service.busy
	add_child(UI.action_row("Name on your account", save_name, "Save"))
	add_child(UI.paragraph("1–32 characters. Your name follows your account across devices.", 12))
	add_child(UI.rule())
	if confirm_campaign != "":
		var upload := confirm_campaign == "upload"
		add_child(UI.paragraph("Replace the cloud campaign backup with this device's completed-level count?" if upload else "Restore the campaign's completed-level count from cloud? An unfinished level will be discarded. Your previous local progress gets a recovery copy.", 14))
		add_child(_button("Replace campaign backup" if upload else "Restore campaign", func():
			confirm_campaign = ""
			if upload: app.campaign_backup.upload(true)
			else: app.campaign_backup.restore()
		))
		add_child(_button("Cancel", func(): confirm_campaign = ""; rebuild()))
		return
	add_child(UI.heading("Campaign", 18))
	add_child(UI.paragraph("%d of %d levels completed on this device. No medals or unfinished-level progress are saved." % [app.campaign_progress.data.completed_levels, app.campaign_progress.Catalog.COUNT], 12))
	add_child(UI.paragraph(app.campaign_backup.status, 13))
	var campaign_upload := UI.button("Retry campaign upload" if app.campaign_backup.state.has("pending") and app.campaign_backup.state.get("player_id") == service.player_id else "Upload campaign backup", func(): app.campaign_backup.upload())
	campaign_upload.name = "UploadCampaignBackup"
	campaign_upload.disabled = service.busy or app.campaign_progress.blocked
	add_child(UI.action_row("Campaign progress", campaign_upload, "Upload"))
	if app.campaign_backup.conflict.get("player_id") == service.player_id:
		add_child(_button("Replace campaign backup…", func(): confirm_campaign = "upload"; rebuild()))
	add_child(_button("Restore campaign…", func(): confirm_campaign = "restore"; rebuild()))
	add_child(_button("Refresh campaign backup", app.campaign_backup.refresh))
	add_child(UI.rule())
	add_child(UI.heading("Infinite worlds", 18))
	add_child(UI.paragraph("Each slot saves on this device. Upload affects only the slot you choose. Signing in and playing never upload progress.", 12))
	for slot in range(VigilSaveSlots.COUNT):
		var target := app.backup_game(slot)
		var upload := UI.button("Upload slot %d backup" % (slot + 1), func(): app.upload_infinite_backup(slot))
		upload.name = "UploadInfinite%d" % (slot + 1)
		upload.disabled = service.busy or target == null or target.save_blocked
		var title := "Slot %d · Empty or unreadable" % (slot + 1) if target == null else "Slot %d · %s" % [slot + 1, str(target.data.get("mode", "creative")).capitalize()]
		add_child(UI.action_row(title, upload, "Upload"))
	if not service.conflict.is_empty():
		add_child(_button("Replace slot %d cloud backup…" % (service.backup_slot + 1), func(): confirm_local = true; rebuild()))
	var audio_toggle := CheckButton.new()
	audio_toggle.button_pressed = service.include_audio
	audio_toggle.disabled = service.busy
	audio_toggle.toggled.connect(func(value): service.include_audio = value)
	add_child(UI.action_row("Include sound preferences in the next Infinite upload", audio_toggle))
	add_child(UI.heading("Restore an Infinite backup", 18))
	var destination := preload("res://scripts/ui/shared/illustrated_picker.gd").new()
	destination.name = "BackupRestoreSlot"
	destination.menu_title = "Choose restore slot"
	destination.illustration = "slots"
	destination.custom_minimum_size.y = 48
	for slot in range(VigilSaveSlots.COUNT): destination.add_item("Restore into slot %d" % (slot + 1))
	destination.select(restore_slot)
	destination.disabled = service.busy
	destination.item_selected.connect(func(index): restore_slot = index)
	add_child(destination)
	add_child(_button("Refresh cloud saves", service.refresh_worlds))
	for world in service.worlds:
		var world_id: String = world.world_id
		var date: String = str(world.updated_at).substr(0, 16).replace("T", " ")
		var title := str(world.get("title", "World %s" % str(int(world.seed))))
		add_child(_button("Restore %s\n%s · %s UTC" % [title, str(world.get("mode", "")).capitalize(), date], func(): confirmation_world = world_id; rebuild()))
	add_child(_button("Sign out", service.sign_out))
	add_child(UI.paragraph("Your player name is stored on your account. Only progress, world reconstruction, save revisions and reward checkpoints are uploaded. Sound preferences are optional. Game mode, configuration and tuned rules are included. Art, code and camera stay on this device.", 12))

func _button(title: String, action: Callable) -> HBoxContainer:
	var button := UI.button(title, action)
	button.disabled = service.busy
	var caption := "Restore" if title.begins_with("Restore") else "Use save"
	if title.begins_with("Email"): caption = "Send code"
	elif title == "Sign in": caption = "Sign in"
	elif title == "Sign out": caption = "Sign out"
	elif title == "Cancel": caption = "Cancel"
	elif title.begins_with("Upload"): caption = "Upload"
	elif title.begins_with("Replace"): caption = "Replace"
	elif title.begins_with("Refresh"): caption = "Refresh"
	return UI.action_row(title, button, caption)
