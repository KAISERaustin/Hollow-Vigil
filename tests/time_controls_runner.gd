extends SceneTree

class SilentAudio extends Node:
	func set_suspended(_value: bool) -> void:
		pass

class ClockApp extends VigilApp:
	func _ready() -> void:
		audio = SilentAudio.new()
		add_child(audio)
		theme = UI.theme()
		build_interface()
		set_process(false)

var failures := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fixture() -> ClockApp:
	var app := ClockApp.new()
	app.load_saved_progress = false
	app.game = VigilState.new(12345)
	app.game.data.erase("first_property_required")
	app.game.data.balance = 10000
	app.game.economy.build("rapid", "0,0", 0)
	app.game.expand("-1,0")
	app.game.combat.rng.seed = 42
	app.game.combat.spawn("-1,0", "basic")
	root.add_child(app)
	return app

func advance(app: ClockApp, frames: int) -> void:
	for i in range(frames):
		app._process(Balance.STEP / 2.0)

func combat_snapshot(app: ClockApp) -> Array:
	return [app.game.combat.enemies.duplicate(true), app.game.combat.effects.duplicate(true), app.game.combat.pending_shots.duplicate(true), app.game.data.towers.duplicate(true), app.game.combat.simulation_time]

func run() -> void:
	var normal := fixture()
	var fast := fixture()
	fast.hud.speed_button.pressed.emit()
	advance(normal, 240)
	advance(fast, 120)
	check(combat_snapshot(normal) == combat_snapshot(fast), "2× matches twice the real time for enemies, shooting, projectiles and towers")
	check(fast.hud.speed_button.button_pressed, "2× visibly selected")
	fast.hud.pause_button.pressed.emit()
	var frozen := combat_snapshot(fast)
	var remainder := fast.accumulator
	advance(fast, 120)
	fast._process(3.0)
	check(combat_snapshot(fast) == frozen, "Pause freezes all combat, including across a long frame")
	check(fast.accumulator == remainder, "Pause preserves interpolation without accumulating catch-up time")
	check(fast.hud.pause_button.tooltip_text == "Play", "Paused button becomes play")
	check(fast.field.simulation_rate == 0.0, "Battlefield animations pause")
	fast.hud.pause_button.pressed.emit()
	advance(fast, 60)
	advance(normal, 120)
	check(combat_snapshot(normal) == combat_snapshot(fast), "Resume keeps 2× without a catch-up burst")
	fast.hud.speed_button.pressed.emit()
	check(fast.simulation_speed == 1.0 and not fast.hud.speed_button.button_pressed, "Speed toggles back to normal")
	normal.hide()
	root.size = Vector2i(390, 844)
	fast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	var settings := fast.hud.find_child("SettingsButton", true, false) as Button
	check(settings.get_global_rect().end.x <= fast.hud.pause_button.global_position.x, "Pause sits to the right of Settings")
	check(fast.hud.pause_button.get_global_rect().end.x <= fast.hud.speed_button.global_position.x, "Speed sits to the right of Pause")
	check(fast.hud.speed_button.get_global_rect().end.x <= 390, "Controls fit mobile width")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/time-controls.png")
	for app in [normal, fast]:
		app.queue_free()
	await process_frame
	print("Time controls: %d failures" % failures)
	quit(1 if failures else 0)
