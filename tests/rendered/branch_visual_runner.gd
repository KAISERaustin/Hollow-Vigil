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
	for step in range(5): await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	# Artwork contact sheet, sized for every current tower family.
	root.size = Vector2i(920, Balance.BRANCHES.size() * 185 + 40)
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
	app.game.data.balance = 1000000000
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
	for dimensions in [Vector2i(360,640),Vector2i(390,844),Vector2i(540,960)]:
		var width: int = dimensions.x
		root.size = dimensions
		root.content_scale_size = root.size
		await frame()
		# The shared management card now owns branch previews and confirmation.
		for kind in Balance.BRANCHES:
			var tower: Dictionary = app.game.data.towers[id]
			tower.kind = kind
			for side in range(2):
				tower.level = 3
				tower.branch = ""
				var branch: String = Balance.BRANCHES[kind].keys()[side]
				app.field.selected_tower = id
				app.tower_dialog.open_action("info")
				app.tower_dialog.arm_upgrade(branch)
				await frame()
				var dialog: VigilTowerDialog = app.tower_dialog
				if not dialog.upgrade_armed or dialog.tower_branch != branch: failures.append("Choice not armed " + kind)
				if tower.level != 3: failures.append("First click purchased " + kind)
				if not Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(dialog.card.get_global_rect()): failures.append("Branch card outside portrait " + kind)
				if not dialog.card.get_global_rect().encloses(dialog.confirm.get_global_rect()): failures.append("Branch confirmation outside card " + kind)
				root.get_texture().get_image().save_png("res://artifacts/branch-%s-%d-%d.png" % [kind,side,width])
				var before: float = app.game.data.balance
				var cost: float = dialog.cost
				await preload("res://tests/rendered/visual_smoke.gd").tap(app, dialog.confirm.get_global_rect().get_center(), true)
				await frame()
				if tower.level != 4 or tower.branch != branch: failures.append("Confirm did not purchase " + branch)
				if not is_equal_approx(app.game.data.balance, before - cost): failures.append("Branch charged incorrect gold " + branch)
				dialog.dismiss()
	# Exercise branch artwork and live effect drawing, not only the preview portraits.
	app.field.selected_tower = ""
	for kind in Balance.BRANCHES:
		for branch in Balance.BRANCHES[kind]:
			var t: Dictionary = app.game.data.towers[id]
			t.kind = kind
			t.level = 4
			t.branch = branch
			t.cooldown = 0.0
			var combat := app.game.combat
			combat.enemies.clear()
			combat.pending_shots.clear()
			combat.effects.clear()
			combat.burning_ground.clear()
			combat.line_projectiles.clear()
			combat.traps.clear()
			combat.effect_fields.clear()
			combat.clear_tower_components(id)
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
