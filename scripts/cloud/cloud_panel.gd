extends VBoxContainer

const UI = preload("res://scripts/ui/shared/interface.gd")
var app: VigilApp
var service: Node
var confirmation_world := ""
var confirm_local := false
var name_draft := ""
var name_edited := false

func _ready() -> void:
	service = app.cloud
	service.changed.connect(rebuild)
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
			add_child(_button("Sign in", func(): service.verify_link(code.text)))
		add_child(UI.paragraph("No password is needed. Sign in again after restarting the game. Offline play always works.", 12))
		return
	if confirmation_world != "":
		add_child(UI.paragraph("Restore this cloud world on this device? Your current progress will be kept in a local recovery save. Earnings from separate saves will not be combined.", 14))
		add_child(_button("Restore cloud progress", func():
			var selected := confirmation_world
			confirmation_world = ""
			service.restore_world(selected)))
		add_child(_button("Cancel", func(): confirmation_world = ""; rebuild()))
		return
	if confirm_local:
		add_child(UI.paragraph("Replace the cloud version with this device's current progress? Other devices will need to restore this version. Their separate progress will not be merged.", 14))
		add_child(_button("Use this device's progress", func(): confirm_local = false; service.keep_local()))
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
	add_child(UI.paragraph("Private cloud backup for Save %d · %s. Refresh lists backups; Sync uploads this save. Public sharing is under Settings → Upload build." % [app.active_slot + 1, str(app.game.data.get("mode", "creative")).capitalize()], 12))
	var audio_toggle := CheckButton.new()
	audio_toggle.text = "Sync sound preferences"
	audio_toggle.button_pressed = service.include_audio
	audio_toggle.disabled = service.busy
	audio_toggle.toggled.connect(func(value):
		service.include_audio = value
		if service.linked():
			app.game.data.cloud.include_audio = value
			app.persist()
			service.sync_now())
	add_child(UI.action_row("Sync sound preferences", audio_toggle))
	if not service.conflict.is_empty():
		add_child(_button("Keep this device's progress…", func(): confirm_local = true; rebuild()))
		add_child(_button("Use cloud progress…", func(): confirmation_world = service.conflict.world_id; rebuild()))
	else:
		add_child(_button("Sync now" if service.linked() else "Sync this save", service.sync_now if service.linked() else service.start_backup))
	add_child(_button("Refresh cloud saves", service.refresh_worlds))
	for world in service.worlds:
		var world_id: String = world.world_id
		var date: String = str(world.updated_at).substr(0, 16).replace("T", " ")
		add_child(_button("Restore world %s · %s…" % [str(int(world.seed)), date], func(): confirmation_world = world_id; rebuild()))
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
	elif title == "Sync now": caption = "Sync"
	elif title == "Sync this save": caption = "Sync"
	elif title.begins_with("Refresh"): caption = "Refresh"
	return UI.action_row(title, button, caption)
