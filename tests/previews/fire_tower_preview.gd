extends SceneTree

class Lineup extends Node2D:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1100,470), VigilTerrainArt.ROAD)
		draw_string(font,Vector2(26,33),"PYRE  /  FIRE WATCHTOWER",HORIZONTAL_ALIGNMENT_LEFT,-1,23,VigilTerrainArt.INK)
		var titles := ["Level 1", "Level 2", "Level 3", "Cinderfield", "Rupture Pyre"]
		for index in range(5):
			var at := Vector2(110+index*220,222)
			var branch: String = "" if index < 3 else ["cinderfield", "rupture_pyre"][index-3]
			VigilTerrainArt.sentinel(self,"splash",at,2.5,mini(index+1,4),branch)
			draw_string(font,Vector2(at.x-66,282),titles[index],HORIZONTAL_ALIGNMENT_LEFT,-1,20,VigilTerrainArt.INK)
		draw_rect(Rect2(0,308,1100,162),VigilTerrainArt.ground_color("bloodmoon_sanctuary"))
		draw_string(font,Vector2(26,339),"IN-GAME SCALE  /  EXISTING ART",HORIZONTAL_ALIGNMENT_LEFT,-1,18,VigilTerrainArt.INK)
		for index in range(3):
			var at := Vector2(90+index*105,425)
			VigilTerrainArt.socket(self,at)
			VigilTerrainArt.sentinel(self,"splash",at,1.0,index+1)
		for index in range(4):
			var at := Vector2(480+index*120,425)
			VigilTerrainArt.socket(self,at)
			VigilTerrainArt.sentinel(self,["rapid","heavy","electric","rapid"][index],at,1.0,4 if index == 3 else 3,"frostneedle" if index == 3 else "")
		VigilTerrainArt.portal(self,Vector2(1000,413),1.2,true)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1100,470)
	root.content_scale_size = root.size
	var lineup := Lineup.new()
	root.add_child(lineup)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/fire-tower-preview.png")
	lineup.queue_free()
	await process_frame
	var app := VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://fire-tower-preview.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	app.field.set_process(false)
	app.game.data.balance = 100000
	app.game.expand("1,0")
	var id := app.game.economy.build("splash", "0,0", 1)
	for viewport in [Vector2i(360,640),Vector2i(390,844),Vector2i(540,960)]:
		root.size = viewport
		root.content_scale_size = viewport
		for level in [1,3,4]:
			var tower: Dictionary = app.game.data.towers[id]
			tower.level = level
			tower.branch = "rupture_pyre" if level == 4 else ""
			app.panels.select_pad("0,0",1)
			# Let normal shared camera framing finish above the actual upgrade sheet.
			for tick in range(30):
				app.field._process(1.0/60.0)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/fire-tower-phone-%d-%d.png" % [level,viewport.x])
			app.tower_dialog.dismiss()
	app.free()
	print("FIRE TOWER PREVIEW: ", error_string(result))
	quit(0 if result == OK else 1)
