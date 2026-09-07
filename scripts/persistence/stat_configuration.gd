extends RefCounted
## Portable gameplay rules. Never accepts or serializes a playable snapshot.
const FORMAT := "hollow-vigil-stat-configuration-v1"
const MAX_BYTES := 1024 * 1024

static func encode(tuning: Dictionary, title: String, description: String = "") -> String:
	var value := {"version": 1, "setup": {"name": title.strip_edges(), "description": description}, "tuning": tuning.duplicate(true)}
	if not valid(value): return ""
	var payload := JSON.stringify(value, "", true, true)
	return JSON.stringify({"format": FORMAT, "payload": payload, "checksum": payload.sha256_text()}, "", true, true)

static func decode(code: String) -> Dictionary:
	if code.to_utf8_buffer().size() > MAX_BYTES: return {}
	var parser := JSON.new()
	if parser.parse(code) != OK or not parser.data is Dictionary: return {}
	var envelope: Dictionary = parser.data
	if envelope.size() != 3 or envelope.get("format") != FORMAT or not envelope.get("payload") is String: return {}
	if envelope.get("checksum") != envelope.payload.sha256_text(): return {}
	if parser.parse(envelope.payload) != OK or not valid(parser.data): return {}
	return parser.data

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1: return false
	if not value.get("setup") is Dictionary or value.setup.size() != 2: return false
	var setup: Dictionary = value.setup
	return setup.get("name") is String and not setup.name.strip_edges().is_empty() and setup.name.length() <= 80 and setup.get("description") is String and setup.description.length() <= 4000 and Balance.valid_tuning(value.get("tuning"))
