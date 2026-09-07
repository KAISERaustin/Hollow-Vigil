extends SceneTree

## Renders review-only artwork and a contact sheet; never opens or saves a game.
const Art = preload("res://tests/previews/tower_expansion/concept_art.gd")
const Data = preload("res://tests/previews/tower_expansion/concept_data.gd")
const A = preload("res://scripts/rendering/terrain/terrain_art.gd")
const UI = preload("res://scripts/ui/shared/interface.gd")
const OUTPUT := "res://docs/concepts/tower-expansion/"
var failures: Array[String] = []
var exports := 0

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 120)
	call_deferred("run")

func text(c: CanvasItem, value: String, at: Vector2, pixels: int = 18, width: float = 600, centered: bool = false, inverse: bool = false) -> void:
	var font := UI.font(600 if pixels < 24 else 700, pixels >= 30)
	c.draw_string(font, at, value, HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT, width, pixels, A.PAPER if inverse else A.INK)

func frame(c: CanvasItem, rect: Rect2) -> void:
	c.draw_style_box(UI.surface(UI.PANEL, UI.OUTLINE, UI.CARD_PADDING), rect)

func rule(c: CanvasItem, from: Vector2, to: Vector2) -> void:
	c.draw_line(from, to, A.INK, UI.OUTLINE, true)

func render(extent: Vector2i, painter: Callable, filename: String, transparent: bool = false) -> Image:
	var view := SubViewport.new()
	view.size = extent
	view.transparent_bg = transparent
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var canvas := Node2D.new()
	view.add_child(canvas)
	canvas.draw.connect(painter.bind(canvas))
	await process_frame
	await RenderingServer.frame_post_draw
	var result := view.get_texture().get_image()
	if result.save_png(OUTPUT + filename) != OK:
		failures.append("Could not export " + filename)
	exports += 1
	view.free()
	return result

func overview(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 1280, 900), A.BACKDROP)
	text(c, "Hollow Vigil", Vector2(28, 51), 34, 700, false, true)
	text(c, "FOUR NEW TOWERS / LEVEL ONE CONCEPTS", Vector2(28, 86), 18, 900, false, true)
	text(c, "Visual review · proposed mechanics", Vector2(858, 52), 16, 390, true, true)
	for index in range(4):
		var row := index / 2
		var col := index % 2
		var family: Dictionary = Data.FAMILIES[index]
		var x := 28.0 + col * 624
		var y := 116.0 + row * 292
		frame(c, Rect2(x, y, 600, 276))
		text(c, family.role, Vector2(x + 12, y + 28), 13, 575)
		Art.draw(c, family.id, Vector2(x + 133, y + 200), 3.1)
		text(c, family.name, Vector2(x + 270, y + 80), 28, 318)
		var lines: Array = [
			["A ballista that rewards", "lining up enemies.", "Strong on straights;", "awkward at bends."],
			["A crescent blade cuts", "out and back.", "Needs both passes", "for its full damage."],
			["Marks enemies so every", "tower hits harder.", "Low damage alone;", "strong in a cluster."],
			["Banks caltrops before", "enemies arrive.", "Needs preparation;", "traps expire unused."]
		][index]
		for i in range(4):
			text(c, lines[i], Vector2(x + 270, y + 117 + i * 26 + (12 if i >= 2 else 0)), 18, 318)
		text(c, "LEVEL 1", Vector2(x + 32, y + 260), 13, 202, true)
	text(c, "EXISTING LEVEL-ONE ROSTER / same native drawing language", Vector2(28, 739), 14, 1196, false, true)
	var kinds := ["rapid", "splash", "heavy", "electric"]
	for i in range(4):
		var x := 115 + i * 306
		A.sentinel(c, kinds[i], Vector2(x, 846), 1.6)
		text(c, Balance.TOWERS[kinds[i]].name, Vector2(x + 52, 816), 20, 176, false, true)
		text(c, Balance.TOWERS[kinds[i]].role, Vector2(x + 52, 843), 12, 176, false, true)

func progression(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 1480, 1250), A.BACKDROP)
	text(c, "Four paths into the Vigil", Vector2(28, 54), 34, 1200, false, true)
	text(c, "PROPOSED PROGRESSION / Level 3 opens two permanent level-4 choices", Vector2(28, 89), 17, 1400, false, true)
	var centers := [305, 527, 749, 1021, 1303]
	var headings := ["LEVEL 1", "LEVEL 2", "LEVEL 3", "LEVEL 4 / A", "LEVEL 4 / B"]
	for i in range(5): text(c, headings[i], Vector2(centers[i] - 100, 136), 15, 200, true, true)
	text(c, "OR", Vector2(1144, 136), 14, 36, true, true)
	for index in range(4):
		var family: Dictionary = Data.FAMILIES[index]
		var y := 157 + index * 264
		frame(c, Rect2(28, y, 1424, 252))
		text(c, family.name, Vector2(40, y + 38), 22, 244)
		var roles: Array = [["Piercing", "lanes"], ["Returning", "blades"], ["Team damage", "support"], ["Stored road", "traps"]][index]
		text(c, roles[0], Vector2(40, y + 75), 16, 170)
		text(c, roles[1], Vector2(40, y + 99), 16, 170)
		rule(c, Vector2(890, y + 12), Vector2(890, y + 240))
		for stage in range(5):
			var level := stage + 1 if stage < 3 else 4
			var branch: String = "" if stage < 3 else family.branches[stage - 3].id
			Art.draw(c, family.id, Vector2(centers[stage], y + 164), 2.35, level, branch)
			var title: String = family.name if stage == 0 else "Reinforced" if stage == 1 else "Fortified" if stage == 2 else family.branches[stage - 3].name
			text(c, title, Vector2(centers[stage] - 116, y + 227), 18, 232, true)
		text(c, "THEN CHOOSE", Vector2(908, y + 28), 12, 500, true)
	text(c, "Concept art only · each branch keeps its family's identity and changes its combat role", Vector2(28, 1231), 15, 1424, false, true)

func phone(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 0, 390, 844), A.BACKDROP)
	text(c, "Four new towers", Vector2(12, 40), 26, 366, false, true)
	text(c, "LEVEL 1 / VISUAL CONCEPTS", Vector2(12, 68), 14, 366, false, true)
	for i in range(4):
		var family: Dictionary = Data.FAMILIES[i]
		var y := 84 + i * 182
		frame(c, Rect2(12, y, 366, 170))
		Art.draw(c, family.id, Vector2(79, y + 116), 1.8)
		text(c, family.name, Vector2(143, y + 41), 21, 223)
		var lines: Array = [["Pierces a line of foes.", "Best on straight roads."], ["Hits out and back.", "Position for both passes."], ["Makes enemies vulnerable.", "Amplifies nearby towers."], ["Stores road traps.", "Prepare an ambush."]][i]
		text(c, lines[0], Vector2(143, y + 79), 14, 223)
		text(c, lines[1], Vector2(143, y + 102), 14, 223)
		text(c, "LEVEL 1", Vector2(26, y + 157), 12, 108, true)
	text(c, "Native silhouettes at a 390-unit phone width", Vector2(12, 832), 12, 366, false, true)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var signatures := {}
	for family in Data.FAMILIES:
		for stage in range(5):
			var level := stage + 1 if stage < 3 else 4
			var branch: String = "" if stage < 3 else family.branches[stage - 3].id
			var filename: String = family.id + ("-level-" + str(level) if branch.is_empty() else "-" + branch) + ".png"
			var img := await render(Vector2i(256, 256), func(c): Art.draw(c, family.id, Vector2(128, 203), 3.0, level, branch), filename, true)
			var used := img.get_used_rect()
			if used.position.x < 8 or used.position.y < 8 or used.end.x > 248 or used.end.y > 248:
				failures.append("Clipped portrait: " + filename)
			var signature := img.get_data().hex_encode().sha256_text()
			if signatures.has(signature): failures.append("Duplicate stage: " + filename)
			signatures[signature] = true
	await render(Vector2i(1280, 900), overview, "level-one-concepts.png")
	await render(Vector2i(1480, 1250), progression, "all-levels-and-branches.png")
	await render(Vector2i(390, 844), phone, "phone-390.png")
	for failure in failures: push_error(failure)
	print("TOWER CONCEPT PREVIEW: %d exports, %d unique portraits, %d failures" % [exports, signatures.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
