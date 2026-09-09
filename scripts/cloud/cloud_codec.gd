extends RefCounted
## Shared identifiers for account-private saves and builds.

static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	return _format_uuid(bytes.hex_encode())

static func _format_uuid(h: String) -> String:
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]

static func valid_uuid(value: Variant) -> bool:
	if not value is String or value.length() != 36:
		return false
	var h: String = value.replace("-", "")
	return h.length() == 32 and h.is_valid_hex_number() and value == _format_uuid(h)
