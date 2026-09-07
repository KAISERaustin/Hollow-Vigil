extends RefCounted
## Account credentials are separate from world saves, build codes and backups.
## Persist only the rotating refresh credential; identity is verified on startup.

const DEFAULT_PATH := "user://vigil-account-session.json"
const MAX_BYTES := 65536
var path := DEFAULT_PATH
var last_error := ""

static func valid_token(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 8192:
		return false
	for character in value:
		if character.unicode_at(0) <= 32 or character.unicode_at(0) == 127:
			return false
	return true

func read_session(project_url: String) -> String:
	last_error = ""
	if not FileAccess.file_exists(path): return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		last_error = "Saved sign-in could not be read. Sign in again."
		return ""
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		last_error = "Saved sign-in could not be read. Sign in again."
		return ""
	var envelope: Dictionary = parser.data
	if not envelope.get("payload") is String or envelope.get("checksum") != envelope.payload.sha256_text() or parser.parse(envelope.payload) != OK:
		last_error = "Saved sign-in could not be read. Sign in again."
		return ""
	var data: Variant = parser.data
	if not data is Dictionary or data.size() != 3 or data.get("version") != 1 or data.get("project_url") != project_url or not valid_token(data.get("refresh_token")):
		last_error = "Saved sign-in is unavailable for this account service. Sign in again."
		return ""
	return data.refresh_token

func save_session(project_url: String, token: String) -> bool:
	last_error = "This device couldn't remember your sign-in. You can use this session, but may need to sign in after restarting."
	if not valid_token(token): return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	# Mobile user:// is app-private; desktop Unix files additionally restrict access.
	if OS.get_name() in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		if FileAccess.set_unix_permissions(path + ".tmp", FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER) != OK:
			file.close()
			DirAccess.remove_absolute(path + ".tmp")
			return false
	var payload := JSON.stringify({"version": 1, "project_url": project_url, "refresh_token": token}, "", true, true)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.flush()
	var written := file.get_error() == OK
	file.close()
	if not written or DirAccess.rename_absolute(path + ".tmp", path) != OK: return false
	last_error = ""
	return true

func clear() -> bool:
	last_error = ""
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(path + suffix) and DirAccess.remove_absolute(path + suffix) != OK:
			# An interrupted temporary write is never read during restoration.
			if suffix == "":
				var file := FileAccess.open(path, FileAccess.WRITE)
				if file != null:
					file.store_string("{}")
					file.close()
				else:
					last_error = "Signed out here, but the saved sign-in couldn't be removed from this device."
	return last_error.is_empty()
