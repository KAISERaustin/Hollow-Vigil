extends RefCounted

const TowerChoice = preload("res://scripts/ui/towers/tower_choice.gd")

# Each menu host remembers its own catalog choice, independently of the visible
# preview. Closing or moving that preview must not erase navigation history.
var kind := ""
var details_open := false
var session: WeakRef

func bind_game(game: VigilState) -> void:
	if session == null or session.get_ref() != game:
		session = weakref(game)
		kind = ""
		details_open = false
	if not Balance.TOWERS.has(kind):
		kind = TowerChoice.first_kind()
		details_open = false

func select(value: String) -> void:
	if Balance.TOWERS.has(value):
		kind = value
		details_open = true

func show_choices() -> void:
	details_open = false
