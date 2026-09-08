extends RefCounted

static func sites(chapter: int, width: float) -> Array:
	var data: Array = str_to_var(FileAccess.get_file_as_string("res://assets/campaign/baked/layout.cfg"))
	var result: Array = data[chapter].duplicate(true)
	for site in result:
		site.rect.position.x *= width / 540.0
		site.rect.size.x *= width / 540.0
	return result

static func clear_site(site: Rect2, map: Control, chapter: int) -> bool:
	# Scenery and its road clearance scale together with the baked image. Live
	# text and button bounds are transformed back into those same coordinates.
	var scale_x: float = 540.0 / map.size.x
	var source := Rect2(Vector2(site.position.x * scale_x, site.position.y), Vector2(site.size.x * scale_x, site.size.y))
	var reserved: Array[Rect2] = []
	for rect in map.chapter_reserved(chapter):
		reserved.append(Rect2(Vector2(rect.position.x * scale_x, rect.position.y), Vector2(rect.size.x * scale_x, rect.size.y)))
	var roads: Array[PackedVector2Array] = map.chapter_roads(chapter)
	roads.append(preload("res://scripts/ui/shared/biome_map_art.gd").waterway(map.chapter_rect(chapter)))
	for road in roads.size():
		for point in roads[road].size(): roads[road][point].x *= scale_x
	return preload("res://scripts/ui/shared/biome_map_art.gd").clear_site(source, Rect2(0, chapter * 960, 540, 960), reserved, roads)
