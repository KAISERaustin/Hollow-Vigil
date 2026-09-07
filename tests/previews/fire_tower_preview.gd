extends SceneTree

class Lineup extends Node2D:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1100,470), VigilTerrainArt.ROAD)
		draw_string(font,Vector2(26,33),"PYRE  /  FIRE WATCHTOWER",HORIZONTAL_ALIGNMENT_LEFT,-1,23,VigilTerrainArt.INK)
		var titles := ["Level 1", "Level 2", "Level 3", "Cinderfield", "Rupture Pyre"]
		for index in range(5):
			var at := Vector2(110+index*220,222)
			var branch := "" if index < 3 else ["cinderfield", "rupture_pyre"][index-3]
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
	root.add_child(Lineup.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://artifacts/fire-tower-preview.png")
	print("FIRE TOWER PREVIEW: ", error_string(result))
	quit(0 if result == OK else 1)
