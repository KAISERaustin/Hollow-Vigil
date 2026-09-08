extends RefCounted

## Cache formatting on its label, so rebuilt screens cannot reuse stale values.
static func money(label: Label, value: float, suffix: String = "") -> void:
	var key := [value, suffix]
	if label.has_meta("money_value") and label.get_meta("money_value") == key: return
	label.text = Balance.money(value) + suffix
	label.set_meta("money_value", key)
