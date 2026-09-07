extends Node

signal changed
signal session_refreshed(result: Dictionary)
const SessionStore = preload("res://scripts/cloud/session_store.gd")
var session_store := SessionStore.new()
var session_notice := ""
var refreshing_session := false
signal restore_requested(snapshot: Dictionary, world_id: String, revision: int)
const Codec = preload("res://scripts/cloud/cloud_codec.gd")
const CONFIG_PATH := "res://supabase/client.cfg"
var game: VigilState
var codec := Codec.new()
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
var status := "Your progress saves on this device. Cloud backups upload only when you choose Upload."
var worlds: Array = []
var backup_slot := -1
var conflict: Dictionary = {}
var pending: Dictionary = {}
var include_audio := false
var generation := 0
var enabled := true

func _ready() -> void:
	var cfg := ConfigFile.new()
	if url.is_empty() and cfg.load(CONFIG_PATH) == OK:
		url = str(cfg.get_value("supabase", "url", "")).trim_suffix("/")
		key = str(cfg.get_value("supabase", "publishable_key", ""))
	include_audio = game.data.get("cloud", {}).get("include_audio", false)
	if not enabled and session_store.path == SessionStore.DEFAULT_PATH:
		session_store.path = game.save_path + ".account-session-test"
	if enabled and configured():
		call_deferred("restore_session")

func configured() -> bool:
	return url.begins_with("https://") and key.begins_with("sb_publishable_")

func signed_in() -> bool:
	return not player_id.is_empty() and not refresh_token.is_empty()

func linked() -> bool:
	return signed_in() and game.data.get("cloud", {}).get("player_id", "") == player_id

# Uploads are manual only. In particular, legacy outboxes never run on a timer.
func _process(_delta: float) -> void:
	pass

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
		_load_pending()
		busy = false
		await refresh_worlds()
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
	worlds.clear()
	conflict.clear()
	pending.clear()
	busy = false
	_say("Signed out. Your local progress is safe and cloud uploads are stopped." if session_store.last_error.is_empty() else session_store.last_error)

func refresh_worlds() -> void:
	if busy or not signed_in():
		return
	busy = true
	var epoch := generation
	var result := await _rpc("list_saves", {})
	if epoch != generation: return
	busy = false
	if result.ok and result.data is Array:
		worlds = result.data
		_say("Signed in. Saved games and My builds back up automatically. Open Backups to check their status or restore a game.")
	else:
		_say(_error(result))

func start_backup() -> void:
	if busy or not signed_in():
		return
	if not linked():
		pending.clear()
		var previous: Variant = game.data.get("cloud")
		game.data.cloud = {"player_id": player_id, "world_id": Codec.uuid(), "revision": 0, "include_audio": include_audio}
		if not game.save():
			if previous == null: game.data.erase("cloud")
			else: game.data.cloud = previous
			_say(game.save_error)
			return
	await sync_now()

func sync_now() -> void:
	if busy or not linked() or not conflict.is_empty() or game.save_blocked:
		return
	busy = true
	var epoch := generation
	_say("Saving to cloud…")
	var meta: Dictionary = game.data.cloud
	if pending.is_empty():
		if not game.save():
			busy = false
			_say(game.save_error)
			return
		var payload := codec.encode(game.snapshot(), meta.world_id, include_audio)
		if payload.is_empty():
			busy = false
			_say(codec.error)
			return
		pending = {"player_id": player_id, "payload": payload, "expected_revision": int(meta.revision), "mutation": Codec.uuid()}
		if not _save_pending():
			pending.clear()
			busy = false
			_say("Couldn't queue the cloud save. Local progress is safe.")
			return
	var result := await _rpc("publish_save", {"payload": pending.payload, "expected_revision": pending.expected_revision, "mutation": pending.mutation})
	if epoch != generation: return
	if result.ok and result.data is Dictionary and result.data.get("status") == "ok":
		meta.revision = int(result.data.revision)
		meta.include_audio = include_audio
		if game.save():
			pending.clear()
			_save_pending()
			_say("Saved to cloud · revision %d. You can continue on another device." % int(meta.revision))
		else:
			_say("Cloud save succeeded, but local sync confirmation could not be saved. Choose Retry upload to confirm this attempt.")
	elif result.ok and result.data is Dictionary and result.data.get("status") == "conflict":
		conflict = {"world_id": meta.world_id, "revision": int(result.data.revision)}
		_say("Another device saved this world. Choose which progress to continue. Neither balance will be added to the other.")
	else:
		_say(_error(result))
	busy = false
	changed.emit()

func keep_local() -> void:
	if busy or conflict.is_empty() or not linked():
		return
	# Explicit conflict choice; compare-and-swap still prevents racing a third save.
	game.data.cloud.revision = conflict.revision
	if not game.save():
		_say(game.save_error)
		return
	pending.clear()
	_save_pending()
	conflict.clear()
	await sync_now()

func restore_world(world_id: String) -> void:
	if busy or not signed_in() or not Codec.valid_uuid(world_id):
		return
	busy = true
	var epoch := generation
	_say("Reading cloud save…")
	var result := await _rpc("read_save", {"world": world_id})
	if epoch != generation: return
	if result.ok and result.data is Dictionary and result.data.get("payload") is Dictionary:
		var snapshot := codec.decode(result.data.payload, game.data.settings, game.data.camera, include_audio)
		if not snapshot.is_empty():
			snapshot.cloud = {"player_id": player_id, "world_id": world_id, "revision": int(result.data.revision), "include_audio": include_audio}
			restore_requested.emit(snapshot, world_id, int(result.data.revision))
		else:
			_say(codec.error)
	else:
		_say("Cloud save is unavailable. Your local progress is safe." if result.ok else _error(result))
	busy = false
	changed.emit()

func restore_completed(ok: bool) -> void:
	if ok:
		pending.clear()
		_save_pending()
		conflict.clear()
		_say("Cloud progress restored. Your previous local save has a recovery copy.")
	else:
		_say("Couldn't restore the cloud save. Your previous progress is preserved.")

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
		_load_pending()
		await refresh_worlds()
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

func _pending_path() -> String:
	return game.save_path + ".cloud-outbox"

func _save_pending() -> bool:
	var cfg := ConfigFile.new()
	cfg.set_value("sync", "outbox", pending)
	var path := _pending_path()
	if cfg.save(path + ".tmp") != OK:
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func _load_pending() -> void:
	pending.clear()
	var cfg := ConfigFile.new()
	if cfg.load(_pending_path()) != OK:
		return
	var saved: Variant = cfg.get_value("sync", "outbox", {})
	if saved is Dictionary and saved.get("player_id") == player_id and saved.get("payload") is Dictionary and linked():
		if saved.payload.get("world", {}).get("id") == game.data.cloud.world_id and Codec.valid_uuid(saved.get("mutation")) and saved.get("expected_revision") is int:
			if not codec.decode(saved.payload).is_empty():
				pending = saved
