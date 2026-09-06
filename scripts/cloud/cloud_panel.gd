extends VBoxContainer

const UI = preload("res://scripts/ui/shared/interface.gd")
var app: VigilApp
var service: Node
var confirmation_world := ""
var confirm_local := false

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
		var address := LineEdit.new()
		address.name = "CloudEmail"
		address.placeholder_text = "Email address"
		address.text = service.email
		address.custom_minimum_size.y = 48
		address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		add_child(address)
		add_child(_button("Email me a sign-in link", func(): service.send_code(address.text)))
		if not service.email.is_empty():
			var code := LineEdit.new()
			code.name = "CloudSignInLink"
			code.placeholder_text = "Paste sign-in link from email"
			code.secret = true
			code.custom_minimum_size.y = 48
			code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
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
	var audio_toggle := CheckButton.new()
	audio_toggle.text = "Sync sound preferences"
	audio_toggle.button_pressed = service.include_audio
	audio_toggle.disabled = service.busy
	audio_toggle.toggled.connect(func(value):
		service.include_audio = value
		if service.linked():
			app.game.data.cloud.include_audio = value
			app.persist())
	add_child(audio_toggle)
	if not service.conflict.is_empty():
		add_child(_button("Keep this device's progress…", func(): confirm_local = true; rebuild()))
		add_child(_button("Use cloud progress…", func(): confirmation_world = service.conflict.world_id; rebuild()))
	else:
		add_child(_button("Sync now" if service.linked() else "Back up this device's world", service.sync_now if service.linked() else service.start_backup))
	add_child(_button("Refresh cloud saves", service.refresh_worlds))
	for world in service.worlds:
		var world_id: String = world.world_id
		var date: String = str(world.updated_at).substr(0, 16).replace("T", " ")
		add_child(_button("Restore world %s · %s…" % [str(int(world.seed)), date], func(): confirmation_world = world_id; rebuild()))
	add_child(_button("Sign out", service.sign_out))
	add_child(UI.paragraph("Only progress, world reconstruction, save revisions and reward checkpoints are uploaded. Sound preferences are optional. Art, code, camera and developer settings stay on this device.", 12))

func _button(title: String, action: Callable) -> Button:
	var button := UI.button(title, action)
	button.disabled = service.busy
	return button
