extends SceneTree

const InputChecks = preload("res://tests/rendered/visual_smoke.gd")
var failures: Array[String] = []

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func run() -> void:
	root.min_size = Vector2i.ZERO
	root.content_scale_size = Vector2i(540, 960)
	root.size = Vector2i(540, 960)
	var app = load("res://scripts/app/main.gd").new()
	app.load_saved_progress = false
	# Main's normal lifecycle and purchases only ever see this disposable save.
	app.game.save_path = "user://artwork-smoke.save"
	for suffix in ["", ".tmp", ".bak"]:
		DirAccess.remove_absolute(app.game.save_path + suffix)
	root.add_child(app)
	app.set_process(false)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	app.game.data.balance = 10000
	app.game.expand("1,0")
	app.game.expand("0,1")
	app.game.expand("1,1")
	app.game.data.regions["1,0"].style = "ashen_forge"
	app.game.data.regions["0,1"].style = "drowned_crypt"
	app.game.data.regions["1,1"].style = "bloodmoon_sanctuary"
	app.game.refresh_paths()
	app.field.camera = Vector2.ZERO
	app.field.zoom = 1.0
	app.field.queue_redraw()
	await InputChecks.tap(app, app.field.global_position + app.field.screen(VigilWorld.pad_position("0,0", 0)))
	check(app.panels.mode == "build", "Outlined socket opens the build menu")
	if app.panels.action_button != null:
		await InputChecks.tap(app, app.panels.action_button.get_global_rect().get_center())
	check(app.game.data.towers.size() == 1, "Build button places the redesigned tower")
	app.panels.close_sheet()
	for kind in ["splash", "heavy"]:
		app.game.economy.build(kind, "0,0", 1 if kind == "splash" else 2)
	await InputChecks.tap(app, app.field.global_position + app.field.screen(VigilWorld.CORE_POSITION), true)
	check(app.panels.mode == "core", "Mint core responds to touch")
	app.panels.close_sheet()
	app.field.camera = Vector2(300, 0)
	app.field.queue_redraw()
	await process_frame
	await InputChecks.tap(app, app.field.global_position + app.field.screen(Vector2(300, 0)))
	check(app.panels.mode == "rift", "Purple rift opens its controls")
	app.panels.close_sheet()
	app.field.camera = Vector2.ZERO
	app.field.queue_redraw()
	await process_frame
	await InputChecks.tap(app, app.field.global_position + app.field.screen(VigilWorld.pad_position("0,0", 0)))
	check(not app.field.selected_tower.is_empty(), "Redesigned tower remains selectable")
	app.panels.close_sheet()
	for id in ["1,0", "0,1", "1,1"]:
		for pad in range(4):
			app.game.economy.build(["rapid", "splash", "heavy", "electric"][pad], id, pad)
	app.game.data.balance = 280
	app.toast_label.modulate.a = 0.0
	app.update_hud()
	for viewport in [Vector2i(540, 960), Vector2i(360, 640)]:
		root.content_scale_size = viewport
		root.size = viewport
		await process_frame
		await process_frame
		app.field.camera = Vector2(150, 150)
		app.field.zoom = 0.78 if viewport.x == 540 else 0.49
		app.field.queue_redraw()
		await InputChecks.capture(app, "minimal-game-" + str(viewport.x))
		check(app.hud.collect_button.get_global_rect().end.x <= viewport.x, "Collect button fits " + str(viewport))
		var info: Button = app.find_child("InfoButton", true, false)
		await InputChecks.tap(app, info.get_global_rect().get_center())
		check(app.panels.mode == "info", "Field guide opens at " + str(viewport))
		await InputChecks.capture(app, "minimal-guide-" + str(viewport.x))
		var close: Button = app.panels.guide.find_child("CloseGuide", true, false)
		await InputChecks.tap(app, close.get_global_rect().get_center())
		check(not app.panels.visible, "Field guide closes at " + str(viewport))
	# A frozen real combat tick exposes all simultaneous lightning branches.
	app.game.data.towers.clear()
	app.game.data.balance = 10000.0
	var electric: String = app.game.economy.build("electric", "0,0", 0)
	app.game.economy.upgrade(electric)
	app.game.economy.upgrade(electric)
	var source := VigilWorld.pad_position("0,0", 0)
	for index in range(5):
		var enemy: Dictionary = app.game.combat.spawn("1,0", "heavy")
		enemy.pos = source + Vector2.from_angle(-2.8 + index * 0.7) * 105.0
		enemy.path = [enemy.pos, enemy.pos + Vector2(1000, 0)]
	app.game.combat.tick(Balance.STEP)
	check(app.game.combat.effects.filter(func(fx): return fx.kind == "shot" and fx.tower_kind == "electric").size() == 5, "Stormspire renders five simultaneous arcs")
	for viewport in [Vector2i(540, 960), Vector2i(360, 640)]:
		root.content_scale_size = viewport
		root.size = viewport
		await process_frame
		await process_frame
		app.field.camera = source
		app.field.zoom = 1.0
		app.field.queue_redraw()
		await InputChecks.capture(app, "electric-lightning-" + str(viewport.x))
	var report := "ARTWORK SMOKE: socket build, tower selection, core touch, rift controls, guide and five lightning arcs at 540x960 and 360x640; %d failures\n" % failures.size()
	for failure in failures:
		report += failure + "\n"
	print(report)
	FileAccess.open("res://artifacts/artwork-results.txt", FileAccess.WRITE).store_string(report)
	app.free()
	quit(0 if failures.is_empty() else 1)
