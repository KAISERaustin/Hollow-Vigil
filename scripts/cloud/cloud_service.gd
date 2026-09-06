extends Node

signal changed
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
var busy := false
var status := "Cloud saves are optional. Your progress stays on this device until you sign in."
var worlds: Array = []
var conflict: Dictionary = {}
var pending: Dictionary = {}
var include_audio := false
var sync_timer := 0.0
var retry_after := 0.0
var generation := 0
var enabled := true

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		url = str(cfg.get_value("supabase", "url", "")).trim_suffix("/")
		key = str(cfg.get_value("supabase", "publishable_key", ""))
	include_audio = game.data.get("cloud", {}).get("include_audio", false)

func configured() -> bool:
	return url.begins_with("https://") and key.begins_with("sb_publishable_")

func signed_in() -> bool:
	return not player_id.is_empty() and not refresh_token.is_empty()

func linked() -> bool:
	return signed_in() and game.data.get("cloud", {}).get("player_id", "") == player_id

func _process(delta: float) -> void:
	if not enabled or game == null or game.suspended or not linked() or busy or not conflict.is_empty():
		return
	sync_timer += delta
	if sync_timer >= 60.0 and Time.get_ticks_msec() / 1000.0 >= retry_after:
		sync_timer = 0.0
		sync_now()

func _say(message: String) -> void:
	status = message
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
	_say("Sending sign-in link…")
	var result := await _request("/auth/v1/otp", {"email": address, "create_user": true}, false)
	busy = false
	if result.ok:
		email = address
		_say("Copy the sign-in link from your email and paste it below. You can keep playing while you wait.")
	else:
		_say(_error(result))

func verify_link(link: String) -> void:
	if busy or email.is_empty():
		return
	var credentials := parse_sign_in_link(link)
	if credentials.is_empty():
		_say("Copy the sign-in link from the email for this game. Paste the link itself, without opening it first.")
		return
	busy = true
	_say("Signing in…")
	var result := await _request("/auth/v1/verify", credentials, false)
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
	if not data.get("access_token") is String or not data.get("refresh_token") is String:
		return false
	access_token = data.access_token
	refresh_token = data.refresh_token
	player_id = data.user.id
	expires_at = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	return true

func sign_out() -> void:
	# No account tokens are stored on disk. Invalidate in-flight callbacks too.
	generation += 1
	access_token = ""
	refresh_token = ""
	player_id = ""
	worlds.clear()
	conflict.clear()
	pending.clear()
	busy = false
	_say("Signed out. Your local progress is safe and cloud uploads are stopped.")

func refresh_worlds() -> void:
	if busy or not signed_in():
		return
	busy = true
	var result := await _rpc("list_saves", {})
	busy = false
	if result.ok and result.data is Array:
		worlds = result.data
		_say("Signed in. Choose a cloud save to restore, or back up this device's world." if not linked() else "Cloud saves are connected. This device syncs every minute while online.")
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
	if result.ok and result.data is Dictionary and result.data.get("status") == "ok":
		meta.revision = int(result.data.revision)
		meta.include_audio = include_audio
		if game.save():
			pending.clear()
			_save_pending()
			_say("Saved to cloud. You can continue on another device.")
		else:
			_say("Cloud save succeeded, but local sync confirmation could not be saved. It will retry safely.")
	elif result.ok and result.data is Dictionary and result.data.get("status") == "conflict":
		conflict = {"world_id": meta.world_id, "revision": int(result.data.revision)}
		_say("Another device saved this world. Choose which progress to continue. Neither balance will be added to the other.")
	else:
		retry_after = Time.get_ticks_msec() / 1000.0 + 60.0
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
	_say("Reading cloud save…")
	var result := await _rpc("read_save", {"world": world_id})
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

func _rpc(function: String, body: Dictionary) -> Dictionary:
	if Time.get_unix_time_from_system() >= expires_at - 60.0:
		var refreshed := await _request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false)
		if not refreshed.ok or not _accept_session(refreshed.data):
			return {"ok": false, "code": 401, "data": null}
	return await _request("/rest/v1/rpc/" + function, body, true)

func _request(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
	var epoch := generation
	var request := HTTPRequest.new()
	request.timeout = 15.0
	request.body_size_limit = 5 * 1024 * 1024
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + key])
	if authenticated:
		headers.append("Authorization: Bearer " + access_token)
	var err := request.request(url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(body, "", true, true))
	if err != OK:
		request.queue_free()
		return {"ok": false, "code": 0, "data": null}
	var response: Array = await request.request_completed
	request.queue_free()
	if epoch != generation:
		return {"ok": false, "code": 0, "data": null}
	var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8())
	return {"ok": response[0] == HTTPRequest.RESULT_SUCCESS and response[1] >= 200 and response[1] < 300, "code": response[1], "data": parsed}

func _error(result: Dictionary) -> String:
	match int(result.get("code", 0)):
		0: return "Offline or unable to reach cloud saves. Keep playing; queued progress will retry later."
		401, 403: return "Sign in again to use cloud saves. Offline play is available."
		429: return "Too many sign-in attempts. Wait a little before trying again."
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
