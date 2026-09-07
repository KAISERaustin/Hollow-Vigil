extends VigilSaveStore
## Selection persistence is separate from authored rules and each build's completion save.
const Playthrough = preload("res://scripts/persistence/campaign_playthrough.gd")
var path := "user://vigil-campaign-session.save"
var data := {"version": 1, "sequence": 0, "mode": "survival", "selections": {"creative": "", "survival": ""}}
var blocked := false

func valid_data(value: Dictionary) -> bool:
	if value.size() != 4 or value.get("version") != 1 or not number(value.get("sequence"), 0, 1e15, true): return false
	if value.get("mode") not in ["creative", "survival"] or not value.get("selections") is Dictionary or value.selections.size() != 2: return false
	for mode in ["creative", "survival"]:
		var code: Variant = value.selections.get(mode)
		if not code is String or (not code.is_empty() and Playthrough.decode(code).is_empty()): return false
	return true

func read_candidate(candidate_path: String) -> Dictionary:
	if not FileAccess.file_exists(candidate_path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(candidate_path)) != OK or not parser.data is Dictionary: return {}
	var envelope: Dictionary = parser.data
	if not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK or not parser.data is Dictionary or not valid_data(parser.data): return {}
	return parser.data

func load_session() -> void:
	var best := {}
	var found := false
	for suffix in ["", ".tmp", ".bak"]:
		found = found or FileAccess.file_exists(path + suffix)
		var candidate := read_candidate(path + suffix)
		if not candidate.is_empty() and (best.is_empty() or candidate.sequence > best.sequence): best = candidate
	blocked = found and best.is_empty()
	if not best.is_empty(): data = best
	last_error = "Campaign setup could not be read. Existing files are preserved." if blocked else ""

func select_build(mode: String, code: String) -> bool:
	if blocked: return false
	var next := data.duplicate(true)
	next.mode = mode
	next.selections[mode] = code
	next.sequence += 1
	if not valid_data(next) or not write(path, next): return false
	data = next
	return true

func identity(mode: String) -> String:
	var code: String = data.selections[mode]
	if code.is_empty(): return "default"
	# Titles do not change which rules a completion belongs to.
	return JSON.stringify(Playthrough.decode(code).levels, "", true, true).sha256_text()
