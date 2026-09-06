extends RefCounted

const Art = preload("res://scripts/rendering/terrain_art.gd")
const Bosses = preload("res://scripts/model/bosses.gd")
const MATTE = preload("res://scripts/rendering/boss_matte.gdshader")
const SIZE_SCALE := 0.6
const TEXTURES := {
	"warden": preload("res://assets/bosses/warden.png"),
	"cindermaw": preload("res://assets/bosses/cindermaw.png"),
	"bell": preload("res://assets/bosses/bell.png"),
	"prior": preload("res://assets/bosses/prior.png")
}

static func begin_frame(c: CanvasItem) -> void:
	for sprite in c.get_meta("boss_sprites", {}).values():
		sprite.visible = false

static func end_frame(c: CanvasItem) -> void:
	var sprites: Dictionary = c.get_meta("boss_sprites", {})
	for id in sprites.keys():
		if not sprites[id].visible:
			sprites[id].queue_free()
			sprites.erase(id)

static func draw(c: CanvasItem, e: Dictionary, at: Vector2, z: float) -> void:
	z *= SIZE_SCALE
	var sprites: Dictionary = c.get_meta("boss_sprites", {})
	var id := str(e.get("id", e.kind))
	if not sprites.has(id):
		var sprite := Sprite2D.new()
		var material := ShaderMaterial.new()
		material.shader = MATTE
		sprite.material = material
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.show_behind_parent = true
		c.add_child(sprite)
		sprites[id] = sprite
		c.set_meta("boss_sprites", sprites)
	var sprite: Sprite2D = sprites[id]
	sprite.texture = TEXTURES[e.kind]
	sprite.position = at + Vector2(0,-5)*z
	sprite.scale = Vector2.ONE * (128.0*z / sprite.texture.get_width())
	sprite.visible = true
	# Ward charges are separate from the permanent crystal collar in the artwork.
	if e.kind == "prior":
		for index in range(int(e.get("wards",0))):
			var a := at+Vector2(-12+index*12,57)*z
			Art.shape(c,[Vector2(0,-4),Vector2(3,0),Vector2(0,4),Vector2(-3,0)],a,Vector2.ONE*z,Art.LILAC,z)
	# Persistent boss identity and defenses remain readable without opening a menu.
	var font := ThemeDB.fallback_font
	var title: String = Bosses.DEFINITIONS[e.kind].name
	var weakness: String = {"warden":"Weak: Cinderfield", "cindermaw":"Weak: Frostneedle", "bell":"Weak: Thunderseal", "prior":"Weak: Doomstone"}[e.kind]
	for row in range(2):
		var text: String = title if row == 0 else weakness
		var size := maxi(8, roundi((12 if row == 0 else 10)*z))
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		var p := at+Vector2(-width*0.5,(-81+row*13)*z)
		c.draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,3,Art.PAPER)
		c.draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color.BLACK)
	var start := at+Vector2(-30,-61)*z
	c.draw_line(start,start+Vector2(60,0)*z,Color.BLACK,6*z)
	c.draw_line(start,start+Vector2(60*clampf(e.hp/e.max_hp,0,1),0)*z,Art.CORAL,3*z)
	if e.get("shield",0.0)>0:
		c.draw_line(start+Vector2(0,5)*z,start+Vector2(60*e.shield/600.0,5)*z,Art.MINT,3*z)
