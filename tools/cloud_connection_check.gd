extends SceneTree

const Service = preload("res://scripts/cloud/cloud_service.gd")
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
var service: Node
var label: Label
var email: LineEdit
var link: LineEdit
var started := false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.title = "Hollow Vigil — Cloud connection check"
	root.size = Vector2i(600,500)
	service = Service.new()
	service.game = VigilState.new(424242)
	service.game.save_path = "user://cloud-connection-check.save"
	service.enabled = false
	root.add_child(service)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side,24)
	root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",16)
	margin.add_child(box)
	label = Label.new()
	label.text = "Sign in to verify live cloud saves.\nThis uses a separate test world; your game progress stays untouched."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	email = LineEdit.new()
	email.placeholder_text = "Supabase project owner's email address"
	email.custom_minimum_size.y = 44
	box.add_child(email)
	var send := Button.new()
	send.text = "Email me a sign-in link"
	send.custom_minimum_size.y = 44
	send.pressed.connect(func(): service.send_code(email.text))
	box.add_child(send)
	link = LineEdit.new()
	link.placeholder_text = "Copy the sign-in link from email and paste it here"
	link.secret = true
	link.custom_minimum_size.y = 44
	box.add_child(link)
	var verify := Button.new()
	verify.text = "Sign in and test cloud saves"
	verify.custom_minimum_size.y = 44
	verify.pressed.connect(func():
		var value := link.text
		link.clear()
		service.verify_link(value))
	box.add_child(verify)
	service.changed.connect(func():
		label.text = service.status
		send.disabled = service.busy or started
		verify.disabled = service.busy or started
		if service.signed_in() and not service.busy and not started:
			started = true
			call_deferred("check_live"))

func check_live() -> void:
	await service.start_backup()
	if not service.linked() or int(service.game.data.cloud.revision) != 1:
		label.text = "Live upload did not complete: " + service.status
		return
	var wid: String = service.game.data.cloud.world_id
	var read: Dictionary = await service._rpc("read_save", {"world":wid})
	var restored := Codec.new().decode(read.data.get("payload")) if read.ok and read.data is Dictionary else {}
	if restored.is_empty() or restored.seed != 424242 or restored.balance != 280:
		label.text = "Live restore did not match the uploaded test world."
		return
	var payload: Dictionary = read.data.payload
	var conflict: Dictionary = await service._rpc("publish_save", {"payload":payload,"expected_revision":0,"mutation":Codec.uuid()})
	if not conflict.ok or conflict.data.get("status") != "conflict":
		label.text = "Live conflict check failed."
		return
	var file := FileAccess.open("res://artifacts/cloud-live-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"world_id":wid,"checks":["email authentication","authenticated upload","cross-client restore payload","stale revision rejection"]}))
	file.close()
	label.text = "Passed: email sign-in, live upload, restore and conflict detection.\nTest world: 424242\nYou can close this window and use Settings → Cloud saves in the game."
	print("PASS: live cloud authentication, upload, restore and conflict rejection")
