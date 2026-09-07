extends VigilSaveStore
## Checksummed, recoverable storage for composed documents with an owning validator.
var validator: Callable

func valid_data(value: Dictionary) -> bool:
	return validator.is_valid() and validator.call(value)

func read_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not envelope is Dictionary or not envelope.get("payload") is String: return {}
	if envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	var value: Variant = JSON.parse_string(envelope.payload)
	return value if value is Dictionary and valid_data(value) else {}

func latest(path: String) -> Dictionary:
	var best := {}
	for suffix in ["", ".tmp", ".bak"]:
		var candidate := read_candidate(path + suffix)
		if not candidate.is_empty() and (best.is_empty() or candidate.get("sequence", 0) > best.get("sequence", 0)):
			best = candidate
	return best

func exists(path: String) -> bool:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix): return true
	return false
