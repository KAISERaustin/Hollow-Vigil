extends SceneTree

const Map = preload("res://scripts/campaign/world_map.gd")
const Content = preload("res://scripts/content/registry.gd")
const Kit = preload("res://scripts/rendering/terrain/map_landmark_art.gd")
const Nature = preload("res://scripts/rendering/terrain/map_nature_art.gd")
var checks := 0
var failures := 0

class Motif extends Node2D:
	var kind := ""
	var profile: Dictionary
	var major := false
	func _draw() -> void:
		if major: Kit.draw(self,kind,Rect2(8,8,120,108),profile)
		else: Nature.draw(self,kind,Rect2(8,8,120,108),profile)

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	var chapter := Content.catalog().get_node("level/chapter/0")
	var sibling := Content.catalog().get_node("level/chapter/1")
	var original: Array = chapter.rule("components")
	var attachment: Dictionary = original.filter(func(entry):return entry.slot=="map_landscape")[0]
	var cleared := chapter.without_component("preview/cleared","map_landscape")
	check(cleared.rule("components").size()==original.size()-1,"Landscape can be removed independently")
	var replaced := chapter.with_component("preview/replaced","map_landscape",attachment.component,{"landmarks":["belfry"]})
	check(chapter.rule("components")==original,"Replacing a landscape preserves its source Chapter")
	check(sibling.rule("components").filter(func(entry):return entry.slot=="map_landscape")[0].config.landmarks[0]=="foundry","Other chapters keep their own assignments")
	var copy: Dictionary = attachment.component.presentation(attachment.config)
	copy.landmarks[0]="fortress"
	check(attachment.component.presentation(attachment.config).landmarks[0]=="watchtower","Presentation returns independent mutable layout data")
	check(replaced.rule("components").filter(func(entry):return entry.slot=="map_landscape").size()==1,"Replacement never duplicates the presentation attachment")

	var viewport := SubViewport.new()
	viewport.size=Vector2i(136,124)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var motif := Motif.new()
	viewport.add_child(motif)
	var gallery := Image.create(390*3,960*2,false,Image.FORMAT_RGBA8)
	for profile in Content.ChapterMaps.PROFILES.values():
		motif.profile=profile
		for kind in profile.landmarks+profile.scenery:
			motif.kind=kind
			motif.major=kind in profile.landmarks or kind=="ruins"
			motif.queue_redraw()
			await frame()
			var picture := viewport.get_texture().get_image()
			check(not picture.is_invisible(),"Every assigned landscape motif renders: "+kind)
			check(Rect2i(8,8,120,108).grow(2).encloses(picture.get_used_rect()),"Illustration stays inside its reserved extent: "+kind)
	viewport.queue_free()
	await process_frame
	var progress := preload("res://scripts/campaign/progress.gd").new()
	progress.allow_all=true
	for width in [360,390,540]:
		var width_gallery := Image.create(width*3,960*2,false,Image.FORMAT_RGBA8)
		viewport=SubViewport.new()
		viewport.size=Vector2i(width,960)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var map := Map.new()
		map.progress=progress
		viewport.add_child(map)
		map.size.x=width
		await frame()
		var first_sites: Array=map.landscapes[0].sites.duplicate(true)
		map.arrange()
		check(map.landscapes[0].sites==first_sites,"Repeated layout preserves every landmark position")
		for index in Map.Catalog.CHAPTERS.size():
			map.position.y=-index*Map.CHAPTER_HEIGHT
			await frame()
			var picture := viewport.get_texture().get_image()
			picture.save_png("res://artifacts/campaign-landscape-%d-%d.png"%[width,index+1])
			width_gallery.blit_rect(picture,Rect2i(0,0,width,960),Vector2i((index%3)*width,int(index/3.0)*960))
			if width==390: gallery.blit_rect(picture,Rect2i(0,0,390,960),Vector2i((index%3)*390,int(index/3.0)*960))
		width_gallery.save_png("res://artifacts/campaign-landscape-gallery-%d.png"%width)
		viewport.queue_free()
		await process_frame
	gallery.save_png("res://artifacts/campaign-landscape-gallery.png")
	print("CAMPAIGN LANDSCAPE: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
