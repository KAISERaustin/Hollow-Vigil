extends SceneTree
var failures: Array[String] = []
class Lineup extends Node2D:
	func _draw() -> void:
		var row := 0
		var font := ThemeDB.fallback_font
		for kind in Balance.BRANCHES:
			var col := 0
			for branch in Balance.BRANCHES[kind]:
				var pos := Vector2(225+col*460,145+row*185)
				VigilTerrainArt.sentinel(self,kind,pos,2.0,4,branch)
				draw_string(font,pos+Vector2(-95,55),Balance.BRANCHES[kind][branch].name,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
				col += 1
			row += 1
func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")
func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	root.size = Vector2i(920,800)
	root.content_scale_size = root.size
	var bg := ColorRect.new()
	bg.color = VigilTerrainArt.BACKDROP
	bg.size = root.size
	root.add_child(bg)
	var art := Lineup.new()
	root.add_child(art)
	await frame()
	root.get_texture().get_image().save_png("res://artifacts/level-four-branches.png")
	art.queue_free()
	bg.queue_free()
	await process_frame
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://branch-ui.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.game.data.balance = 100000
	app.game.expand("-1,0")
	var id := app.game.economy.build("rapid","0,0",0)
	app.game.economy.upgrade(id)
	app.game.economy.upgrade(id)
	app.field.camera = Vector2.ZERO
	app.field.zoom = 1.0
	app.panels.close_sheet()
	app.field.selected_tower = id
	app.tower_actions.blocked = false
	app.update_hud()
	for dimensions in [Vector2i(360,640),Vector2i(360,900),Vector2i(540,900)]:
		var width: int = dimensions.x
		root.size = dimensions
		root.content_scale_size = root.size
		await frame()
		app.tower_actions.request_upgrade()
		await frame()
		if not app.tower_actions.branch_bar.visible: failures.append("Choices not visible")
		var index := 0
		for kind in Balance.BRANCHES:
			var tower: Dictionary = app.game.data.towers[id]
			tower.kind = kind
			app.tower_actions.cancel_upgrade()
			app.tower_actions.request_upgrade()
			for side in range(2):
				await preload("res://tests/rendered/visual_smoke.gd").tap(app,app.tower_actions.branch_bar.get_child(side).get_global_rect().get_center(),side == 1)
				await frame()
				var card: PanelContainer = app.tower_actions.branch_card
				if not card.visible: failures.append("Preview not visible "+kind)
				if card.position.y < 0 or card.get_rect().end.x > app.field.size.x: failures.append("Preview overflow "+kind)
				if card.get_rect().end.y > app.tower_actions.branch_bar.position.y: failures.append("Preview overlaps choices")
				root.get_texture().get_image().save_png("res://artifacts/branch-%s-%d-%d.png" % [kind,side,width])
			index += 1
		app.tower_actions.cancel_upgrade()
	# Purchasing through the real control fires normal persistence hooks.
	app.game.data.towers[id].kind = "rapid"
	app.tower_actions.request_upgrade()
	app.tower_actions.choose_branch(0)
	await frame()
	await preload("res://tests/rendered/visual_smoke.gd").tap(app,app.tower_actions.branch_confirm.get_global_rect().get_center())
	if app.game.data.towers[id].get("branch","") != "frostneedle": failures.append("Confirm button did not purchase")
	if app.tower_actions.branch_bar.visible: failures.append("Choices did not dismiss")
	# Exercise branch artwork and live effect drawing, not only the preview portraits.
	app.field.selected_tower = ""
	for kind in Balance.BRANCHES:
		for branch in Balance.BRANCHES[kind]:
			var t: Dictionary = app.game.data.towers[id]
			t.kind = kind
			t.branch = branch
			t.cooldown = 0.0
			var combat := app.game.combat
			combat.enemies.clear()
			combat.pending_shots.clear()
			combat.effects.clear()
			combat.burning_ground.clear()
			var origin := VigilWorld.pad_position("0,0",0)
			for index in range(15):
				var e := combat.spawn("-1,0", "heavy" if index % 3 == 0 else "basic")
				e.hp = 10000.0
				e.max_hp = e.hp
				e.pos = origin + Vector2(35+index*4,-30+index%3*16)
				e.path = [e.pos,e.pos+Vector2(1000,0)]
				e.segment = 1
			for tick in range(44):
				combat.tick(0.05)
			app.field.queue_redraw()
			await frame()
			root.get_texture().get_image().save_png("res://artifacts/branch-combat-%s.png" % branch)
	print("BRANCH VISUAL: ", failures)
	quit(0 if failures.is_empty() else 1)
