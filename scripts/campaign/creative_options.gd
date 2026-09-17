extends RefCounted
## Save-local Creative conveniences, separate from earned progression and builds.
const KEYS := ["levels", "towers", "tutorials"]

static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if key not in KEYS or not value[key] is bool: return false
	return true

static func enabled(save: Dictionary, key: String) -> bool:
	return save.get("mode", "") == "creative" and save.get("creative_options", {}).get(key, false) == true
