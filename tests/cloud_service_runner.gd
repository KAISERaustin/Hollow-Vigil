extends SceneTree

const Codec = preload("res://scripts/cloud/cloud_codec.gd")
const Service = preload("res://scripts/cloud/cloud_service.gd")
class FakeService extends Service:
	var responses: Array = []
	var requests: Array = []
	func _request(path: String, body: Dictionary, authenticated: bool) -> Dictionary:
		requests.append({"path":path,"body":body.duplicate(true),"authenticated":authenticated})
		if responses.is_empty():
			return {"ok":false,"code":0,"data":null}
		return responses.pop_front()

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g := VigilState.new(42)
	g.save_path = "user://cloud-test-" + Codec.uuid() + ".save"
	var s := FakeService.new()
	s.game = g
	s.enabled = false
	root.add_child(s)
	var test_link := s.url + "/auth/v1/verify?token=" + "a".repeat(56) + "&type=signup&redirect_to=http://localhost:3000"
	check(s.parse_sign_in_link(test_link).get("type") == "signup", "Default signup link can be exchanged in game")
	check(s.parse_sign_in_link(test_link.replace(s.url,"https://unrelated.example")).is_empty(), "Foreign sign-in link rejected")
	check(s.parse_sign_in_link(test_link.replace("type=signup","type=recovery")).is_empty(), "Password-recovery links are not used for game sign-in")
	check(g.save(), "Local save works without account")
	await s.sync_now()
	check(s.requests.is_empty(), "Signed-out game makes no upload")
	s.player_id = Codec.uuid()
	s.access_token = "synthetic"
	s.refresh_token = "synthetic"
	s.expires_at = Time.get_unix_time_from_system() + 3600
	s.responses.append({"ok":false,"code":0,"data":null})
	await s.start_backup()
	check(not s.pending.is_empty() and g.data.cloud.revision == 0, "Failed network retains outbox without advancing revision")
	var mutation: String = s.pending.mutation
	var payload: Dictionary = s.pending.payload.duplicate(true)
	g.data.balance += 37.0
	s.responses.append({"ok":true,"code":200,"data":{"status":"ok","revision":1}})
	await s.sync_now()
	check(s.requests[-1].body.mutation == mutation and s.requests[-1].body.payload == payload, "Lost-response retry uses identical mutation and snapshot")
	check(g.data.cloud.revision == 1 and s.pending.is_empty(), "Acknowledged revision persists and clears outbox")
	check(g.data.balance == Balance.STARTING_GOLD + 37.0, "Upload response does not overwrite newer local play")
	s.responses.append({"ok":true,"code":200,"data":{"status":"conflict","revision":2}})
	await s.sync_now()
	check(s.conflict.revision == 2 and g.data.cloud.revision == 1, "Conflict preserves local progress and base revision")
	var before := s.requests.size()
	await s.sync_now()
	check(s.requests.size() == before, "Conflict blocks automatic overwrite")
	s.responses.append({"ok":true,"code":200,"data":{"status":"ok","revision":3}})
	await s.keep_local()
	check(s.requests[-1].body.expected_revision == 2 and s.requests[-1].body.mutation != mutation, "Explicit local choice still uses compare-and-swap")
	check(s.conflict.is_empty() and g.data.cloud.revision == 3, "Resolved conflict resumes synchronization")
	# Crash/restart while offline: reload the queued snapshot under the same account.
	s.responses.append({"ok":false,"code":0,"data":null})
	await s.sync_now()
	var queued: String = s.pending.mutation
	var s2 := FakeService.new()
	s2.game = g
	s2.enabled = false
	root.add_child(s2)
	s2.player_id = s.player_id
	s2.refresh_token = "synthetic"
	s2._load_pending()
	check(s2.pending.get("mutation") == queued, "Outbox survives restart")
	s2.player_id = Codec.uuid()
	s2._load_pending()
	check(s2.pending.is_empty(), "Different account cannot send previous account outbox")
	s.sign_out()
	check(not s.signed_in() and s.pending.is_empty(), "Sign-out clears tokens and in-memory upload")
	check(g.save(), "Offline play saves after sign-out")
	for suffix in ["", ".bak", ".tmp", ".cloud-outbox", ".cloud-outbox.tmp"]:
		if FileAccess.file_exists(g.save_path + suffix):
			DirAccess.remove_absolute(g.save_path + suffix)
	s.queue_free()
	s2.queue_free()
	print("Cloud service: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
