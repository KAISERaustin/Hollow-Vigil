extends Node

signal changed
signal session_refreshed(result: Dictionary)
const SessionStore = preload("res://scripts/cloud/session_store.gd")
var session_store := SessionStore.new()
var session_notice := ""
var refreshing_session := false
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
const CONFIG_PATH := "res://supabase/client.cfg"
var game: VigilState
var url := ""
var key := ""
var access_token := ""
var refresh_token := ""
var expires_at := 0.0
var player_id := ""
var email := ""
var display_name := ""
const MAX_NAME_LENGTH := 32
var busy := false
var status := "Your progress saves on this device. Sign in for automatic private backups."
var generation := 0
var enabled := true

func _ready() -> void:
	var cfg := ConfigFile.new()
	if url.is_empty() and cfg.load(CONFIG_PATH) == OK:
		url = str(cfg.get_value("supabase", "url", "")).trim_suffix("/")
		key = str(cfg.get_value("supabase", "publishable_key", ""))
	if not enabled and session_store.path == SessionStore.DEFAULT_PATH:
		session_store.path = game.save_path + ".account-session-test"
	if enabled and configured():
		call_deferred("restore_session")

func configured() -> bool:
	return url.begins_with("https://") and key.begins_with("sb_publishable_")

func signed_in() -> bool:
	return not player_id.is_empty() and not refresh_token.is_empty()

func _say(message: String) -> void:
	status = message + ("\n" + session_notice if signed_in() and not session_notice.is_empty() else "")
	changed.emit()

func send_code(address: String) -> void:
	if busy:
		return
	if not configured():
		_say("Cloud saves are not configured. Offline play is available.")
		return
	address = address.strip_edges()
	if not "@" in address or address.length() > 254:
		_say("Enter your email address.")
		return
	busy = true
	var epoch := generation
	_say("Sending sign-in code…")
	var result := await _request("/auth/v1/otp", {"email": address, "create_user": true}, false)
	if epoch != generation: return
	busy = false
	if result.ok:
		email = address
		_say("Enter the code from your email within 15 minutes, or paste its sign-in link. Keep playing while you wait.")
	else:
		_say(_error(result))

func verify_link(link: String) -> void:
	if busy or email.is_empty():
		return
	var credentials := parse_sign_in_link(link)
	var code := link.strip_edges()
	if code.length() == 8:
		var digits_only := true
		for digit in code:
			if digit < "0" or digit > "9":
				digits_only = false
		if digits_only:
			credentials = {"email": email, "token": code, "type": "email"}
	if credentials.is_empty():
		_say("Enter the eight-digit email code, or copy the sign-in link without opening it first.")
		return
	busy = true
	var epoch := generation
	_say("Signing in…")
	var result := await _request("/auth/v1/verify", credentials, false)
	if epoch != generation: return
	if result.ok and _accept_session(result.data):
		busy = false
		_say("Signed in. Campaign saves and My builds back up automatically.")
	else:
		busy = false
		_say(_error(result))

func parse_sign_in_link(link: String) -> Dictionary:
	link = link.strip_edges()
	var prefix := url + "/auth/v1/verify?"
	if not link.begins_with(prefix):
		return {}
	var params := {}
	for part in link.trim_prefix(prefix).split("&"):
		var pair := part.split("=", true, 1)
		if pair.size() == 2:
			params[pair[0]] = pair[1].uri_decode()
	var token: String = params.get("token", "")
	var kind: String = params.get("type", "")
	if token.length() < 32 or token.length() > 256 or not kind in ["magiclink", "signup", "email"]:
		return {}
	return {"token_hash": token, "type": kind}

func _accept_session(data: Variant) -> bool:
	if not data is Dictionary or not data.get("user") is Dictionary or not Codec.valid_uuid(data.user.get("id")):
		return false
	if not SessionStore.valid_token(data.get("access_token")) or not SessionStore.valid_token(data.get("refresh_token")):
		return false
	var lifetime: Variant = data.get("expires_in", 3600)
	if not (lifetime is float or lifetime is int) or not is_finite(lifetime) or lifetime < 1 or lifetime > 604800:
		return false
	access_token = data.access_token
	refresh_token = data.refresh_token
	player_id = data.user.id
	display_name = _user_name(data.user)
	email = str(data.user.get("email", email))
	expires_at = Time.get_unix_time_from_system() + float(lifetime)
	session_notice = "" if session_store.save_session(url, refresh_token) else session_store.last_error
	return true

static func valid_player_name(value: Variant) -> bool:
	if not value is String or value.strip_edges().is_empty() or value.length() > MAX_NAME_LENGTH:
		return false
	for character in value:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127:
			return false
	return true

func _user_name(user: Dictionary) -> String:
	var metadata: Variant = user.get("user_metadata", {})
	var value: Variant = metadata.get("display_name", "") if metadata is Dictionary else ""
	return value.strip_edges() if valid_player_name(value) else ""

func save_player_name(value: String) -> void:
	if busy or not signed_in():
		return
	value = value.strip_edges()
	if not valid_player_name(value):
		_say("Enter a player name with 1–32 characters, without line breaks.")
		return
	busy = true
	var epoch := generation
	_say("Saving player name…")
	var result := await _ensure_session()
	if result.ok:
		result = await _request("/auth/v1/user", {"data": {"display_name": value}}, true)
	if epoch != generation:
		return
	busy = false
	if result.ok and result.data is Dictionary and result.data.get("id") == player_id and _user_name(result.data) == value:
		display_name = value
		_say("Player name saved to your account.")
	else:
		_say(_error(result))

func sign_out() -> void:
	# Clear device credentials and invalidate in-flight callbacks together.
	generation += 1
	session_store.clear()
	session_notice = ""
	expires_at = 0.0
	email = ""
	access_token = ""
	refresh_token = ""
	player_id = ""
	display_name = ""
	busy = false
	_say("Signed out. Your local progress is safe and cloud uploads are stopped." if session_store.last_error.is_empty() else session_store.last_error)

func restore_session() -> void:
	if busy or signed_in() or not configured(): return
	var saved := session_store.read_session(url)
	if saved.is_empty():
		if not session_store.last_error.is_empty(): _say(session_store.last_error)
		return
	busy = true
	var epoch := generation
	refresh_token = saved
	expires_at = 0.0
	_say("Restoring sign-in…")
	var result := await _ensure_session()
	if epoch != generation: return
	busy = false
	if result.ok:
		_say("Signed in. Campaign saves and My builds back up automatically.")
	else:
		_say("Couldn't restore sign-in right now. Your saved sign-in is kept. Choose Retry sign-in when you're online." if int(result.get("code", 0)) not in [400, 401, 403] else _error(result))

func has_saved_session() -> bool:
	return not refresh_token.is_empty() and not signed_in()

func _ensure_session() -> Dictionary:
	if refresh_token.is_empty(): return {"ok": false, "code": 401, "data": null}
	if not access_token.is_empty() and Time.get_unix_time_from_system() < expires_at - 60.0:
		return {"ok": true}
	var epoch := generation
	if refreshing_session:
		var shared: Dictionary = await session_refreshed
		return shared if epoch == generation else {"ok": false, "code": 0, "data": null}
	refreshing_session = true
	var refreshed := await _request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false)
	if epoch != generation:
		refreshed = {"ok": false, "code": 0, "data": null}
	elif refreshed.ok:
		if _accept_session(refreshed.data):
			refreshed = {"ok": true}
		else:
			sign_out()
			refreshed = {"ok": false, "code": 401, "data": null}
	elif int(refreshed.code) in [400, 401, 403]:
		# Preserve retryable network/rate-limit failures; discard revoked credentials.
		sign_out()
		refreshed = {"ok": false, "code": 401, "data": null}
	refreshing_session = false
	session_refreshed.emit(refreshed)
	return refreshed

func _rpc(function: String, body: Dictionary) -> Dictionary:
	var epoch := generation
	var session := await _ensure_session()
	if epoch != generation: return {"ok": false, "code": 0, "data": null}
	if not session.ok:
		return session
	return await _request("/rest/v1/rpc/" + function, body, true)

func _request(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
	var epoch := generation
	var request := HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = (64 if path in ["/rest/v1/rpc/read_private_game", "/rest/v1/rpc/list_private_builds", "/rest/v1/rpc/read_public_build"] else 5) * 1024 * 1024
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + key])
	if authenticated:
		headers.append("Authorization: Bearer " + access_token)
	var method := HTTPClient.METHOD_PUT if path == "/auth/v1/user" else HTTPClient.METHOD_POST
	var err := request.request(url + path, headers, method, JSON.stringify(body, "", true, true))
	if err != OK:
		request.queue_free()
		return {"ok": false, "code": 0, "data": null}
	var response: Array = await request.request_completed
	request.queue_free()
	if epoch != generation:
		return {"ok": false, "code": 0, "data": null}
	return _decode_response(response)

func _decode_response(response: Array) -> Dictionary:
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "data": null}
	var body: String = response[3].get_string_from_utf8()
	var parser := JSON.new()
	var valid_json := body.is_empty() or parser.parse(body) == OK
	return {"ok": valid_json and response[1] >= 200 and response[1] < 300, "code": response[1], "data": parser.data if not body.is_empty() and valid_json else null}

func _error(result: Dictionary) -> String:
	var data: Variant = result.get("data")
	if data is Dictionary:
		match str(data.get("error_code", "")):
			"over_email_send_rate_limit":
				return "Cloud sign-in email quota reached. Try again later; your local progress is safe."
			"otp_expired":
				return "That email code has expired or was already used. Request a new code."
	match int(result.get("code", 0)):
		0: return "Unable to connect. Your progress stays on this device. Please try again when connected."
		401, 403: return "Sign in again to use cloud saves. Offline play is available."
		429: return "Cloud service is temporarily rate-limited. Wait a little before trying again."
		_: return "Cloud request failed. Your local progress is safe; please try again."
