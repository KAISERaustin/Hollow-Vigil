extends Battlefield

var actor_mode := "full"
var omit_map := false

func draw_enemy(enemy: Dictionary) -> void:
	if actor_mode == "none": return
	if actor_mode == "markers":
		draw_circle(screen(enemy.pos), maxf(1.5, 5.0 * zoom), Color("d9cfa4"))
		return
	super.draw_enemy(enemy)

func draw_tower(tower: Dictionary) -> void:
	if actor_mode == "none": return
	super.draw_tower(tower)

func draw_map() -> void:
	if not omit_map: super.draw_map()
