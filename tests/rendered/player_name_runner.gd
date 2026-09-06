extends SceneTree

# Account UI fixture avoids loading unrelated audio assets or contacting the network.
class SilentAudio extends Node:
	func set_suspended(_value: bool) -> void:
		pass

class AccountApp extends VigilApp:
	func _ready() -> void:
		audio = SilentAudio.new()
		add_child(audio)
		theme = UI.theme()
		build_interface()
		cloud = preload("res://scripts/cloud/cloud_service.gd").new()
		cloud.game = game
		cloud.enabled = false
		add_child(cloud)
		cloud.url = "https://example.supabase.co"
		cloud.key = "sb_publishable_fixture"

var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var app := AccountApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://player-name-ui-test.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.cloud.enabled = false
	for viewport in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(540, 960)]:
		root.size = viewport
		root.content_scale_size = viewport
		app.cloud.player_id = "11111111-1111-4111-8111-111111111111"
		app.cloud.refresh_token = "synthetic"
		app.cloud.display_name = "W".repeat(32)
		app.panels.show_settings()
		await frame()
		var card := app.panels.find_child("PlayerNameCard", true, false) as PanelContainer
		var label := card.find_child("SettingsPlayerName", true, false) as Label
		check(label.text == app.cloud.display_name and label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Account name centered")
		check(app.panels.sheet_content.get_child(0) == card, "Player card comes first")
		check(app.panels.content_scroll.get_global_rect().encloses(card.get_global_rect()), "Long name card fits mobile settings")
		app.cloud.display_name = "Éowyn Starfall"
		app.cloud.changed.emit()
		await frame()
		check(label.text == "Éowyn Starfall", "Visible name refreshes with account")
		root.get_texture().get_image().save_png("res://artifacts/player-name-%d.png" % viewport.x)
		app.panels.show_cloud_saves()
		await frame()
		var entry := app.panels.find_child("PlayerNameInput", true, false) as LineEdit
		check(entry != null and entry.text == "Éowyn Starfall", "Account editor loads saved name")
		if entry != null:
			entry.text = "Draft name"
			entry.text_changed.emit(entry.text)
			app.cloud._say("Offline")
			await frame()
			entry = app.panels.find_child("PlayerNameInput", true, false) as LineEdit
			check(entry.text == "Draft name", "Status refresh preserves typed name")
		app.panels.show_settings()
		app.cloud.sign_out()
		await frame()
		label = app.panels.find_child("SettingsPlayerName", true, false) as Label
		check(label.text == "Guest", "Sign-out removes account name immediately")
	app.queue_free()
	await process_frame
	print("Player name UI: %d failures" % failures)
	quit(1 if failures else 0)
