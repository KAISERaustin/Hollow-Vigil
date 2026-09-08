extends Translation
## Presentation-only substitution: original strings remain readable to assistive
## technology and game/save identifiers are never changed.
const SYMBOL := "\ue000"
var words := RegEx.new()

func _init() -> void:
	locale = "en"
	words.compile("(?i)\\bgold\\b")

func _get_message(source: StringName, _context: StringName) -> StringName:
	return StringName(words.sub(String(source), SYMBOL, true))
