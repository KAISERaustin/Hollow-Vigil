extends SceneTree
const Director = preload("res://scripts/audio/audio_director.gd")
var failures: Array[String] = []
var checks := 0
var app: VigilApp
var events: Array[String] = []
var initial_buses := AudioServer.bus_count

func _initialize() -> void:
	preload("res://tests/support/timeout.gd").arm(self, 90)
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func record(cue: String, _position: Vector2) -> void:
	events.append(cue)

func settle() -> void:
	for i in range(8):
		await process_frame

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://audio-check.save"
	root.add_child(app)
	app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.set_process(false)
	await settle()
	var a: Node = app.audio
	check(a.streams.size() == Director.CATALOG.size(), "Every catalog cue loads")
	for cue in Director.CATALOG:
		check(a.streams[cue] is AudioStreamWAV and a.streams[cue].get_length() > 0, "Playable cue: " + cue)
	check(AudioServer.get_bus_effect(AudioServer.get_bus_index(a.bus_name), 0) is AudioEffectHardLimiter, "Mix has a peak limiter")
	check(a.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Music loops")
	check(a.music.stream.loop_end == 64 * a.music.stream.mix_rate, "Music loops at sample frame count, independent of import compression")
	check(is_equal_approx(a.music.stream.get_length(), 64.0), "Full 64-second score")
	for category in Director.DEFAULTS:
		a.set_volume(category, 1.0)
	a.set_muted(false)
	var master_bus := AudioServer.get_bus_index(a.master_bus_name)
	const UI = preload("res://scripts/ui/shared/interface.gd")
	for icon in [UI.close_button(func(): pass), UI.back_button("Back to categories", func(): pass)]:
		app.add_child(icon)
		a.elapsed += 2
		a.last_cue.clear()
		icon.pressed.emit()
		check(a.last_cue.has("menu_close"), "Drawn navigation icons retain dismissal audio through their accessible names")
		icon.queue_free()
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(a.bus_name)) == a.master_bus_name, "All effects pass through the final master bus")
	check(AudioServer.get_bus_send(master_bus) == &"Master", "Private master feeds device Master")
	check(a.music.bus == a.bus_name, "Music uses the same master route")
	a.set_volume("towers", .65)
	var full_tower_gain: float = a.gain("towers")
	var full_music_gain: float = a.music.volume_linear
	a.set_volume("master", .1)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(master_bus)) * a.volume("towers"), .065), "10% master times 65% towers is 6.5%")
	check(is_equal_approx(a.gain("towers"), full_tower_gain) and is_equal_approx(a.music.volume_linear, full_music_gain), "Master attenuation happens once downstream of category gains")
	for pool in a.voices.values():
		for voice in pool:
			check(voice.bus == a.bus_name, "Every pooled voice uses the master route")
	a.set_volume("master", 0.0)
	check(AudioServer.is_bus_mute(master_bus), "Zero master mutes the output bus")
	a.set_volume("master", 1.0)
	a.set_volume("towers", 1.0)
	for category in Director.LIMITS:
		check(a.voices[category].size() == Director.LIMITS[category], "Bounded voices: " + category)
	a.elapsed += 2
	a.play("shot_rapid")
	var accepted: int = a.accepted_events
	for i in range(1000):
		a.play("shot_rapid")
	check(a.accepted_events == accepted, "Crowd bursts are coalesced without queues")
	a.play("shot_heavy")
	check(a.accepted_events == accepted + 1, "Simultaneous different weapons remain audible")
	accepted = a.accepted_events
	a.set_volume("towers", 0.0)
	for voice in a.voices.towers:
		check(voice.volume_linear == 0.0, "Zero number silences active tower voices")
		check(not voice.playing, "Category mute discards effects instead of reviving their tails")
	check(a.music.volume_linear > 0.0, "Tower mute leaves music audible")
	a.set_volume("towers", 1.0)
	a.elapsed += 2
	a.play("shot_rapid", Vector2(100000, 100000))
	check(a.accepted_events == accepted, "Distant combat is inaudible")
	a.set_muted(true)
	a.play("menu_collect")
	check(a.accepted_events == accepted and a.music.volume_linear == 0, "Master mute silences all categories")
	a.set_muted(false)
	check(not a.voices.towers.any(func(voice): return voice.playing), "Unmute does not revive old tower effects")
	a.elapsed += 2
	a.play("boss_bell_ability")
	check(a.voices.bosses.any(func(voice): return voice.playing), "Boss preview starts before master mute")
	a.set_volume("master", 0.0)
	a.set_volume("master", 1.0)
	check(not a.voices.bosses.any(func(voice): return voice.playing), "Master zero discards old effects")
	a.elapsed += 2
	a.play("boss_bell_ability")
	a.set_muted(true)
	a.set_muted(false)
	check(not a.voices.bosses.any(func(voice): return voice.playing), "Mute toggle discards old effects")
	a.set_suspended(true)
	check(a.music.stream_paused, "Background music pauses on suspension")
	for pool in a.voices.values():
		for voice in pool:
			check(not voice.playing, "Suspension stops transient sounds")
	a.set_suspended(false)
	check(not a.music.stream_paused, "Resume continues music")
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(a.suspended, "Focus gain cannot override application pause")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(a.suspended, "Application resume cannot override lost focus")
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not a.suspended, "Audio resumes once both lifecycle blockers clear")
	app.slot_active = false
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not a.suspended and not a.music.stream_paused, "Resume restores menu audio without a loaded slot")
	app.slot_active = true
	app.game.suspended = false
	# Actual combat events, not cosmetic effect inspection.
	a.stop_effects()
	a.elapsed += 2
	var visible_position: Vector2 = app.field.world(app.field.size * .5)
	a.play("shot_heavy", visible_position)
	accepted = a.accepted_events
	check(a.voices.towers.any(func(voice): return voice.playing), "Visible combat starts a voice")
	app.hud.hide()
	a._process(0.0)
	check(not a.voices.towers.any(func(voice): return voice.playing), "Hiding the world stops existing combat tails")
	a.elapsed += 2
	a.play("shot_heavy", visible_position)
	check(a.accepted_events == accepted, "Hidden world rejects new combat")
	app.hud.show()
	a.elapsed += 2
	app.game.economy.sound_requested.emit("menu_build", Vector2.INF)
	check(a.voices.menu.any(func(voice): return voice.playing), "Visible world accepts transaction feedback")
	app.hud.hide()
	a._process(0.0)
	check(not a.voices.menu.any(func(voice): return voice.playing), "Hidden world stops non-positional transaction tails")
	accepted = a.accepted_events
	a.elapsed += 2
	app.game.economy.sound_requested.emit("menu_upgrade", Vector2.INF)
	check(a.accepted_events == accepted, "Hidden world rejects non-positional simulation feedback")
	a.play("shot_heavy")
	check(a.accepted_events == accepted + 1, "Explicit settings previews remain available without a visible world")
	a.stop_effects()
	accepted = a.accepted_events
	app.hud.show()
	app.slot_active = false
	a.play("shot_heavy", visible_position)
	check(a.accepted_events == accepted, "No loaded slot produces no world effects")
	app.slot_active = true
	var g := app.game
	g.data.balance = 1000000.0
	g.expand("-1,0")
	g.data.regions["-1,0"].style = "forest" # Weapon tests use a Forest target.
	g.combat.sound_requested.connect(record)
	g.economy.sound_requested.connect(record)
	for kind in Balance.TOWERS:
		var tower_id := g.economy.build(kind, "0,0", 0)
		check(events.has("menu_build"), "Successful build produces confirmation")
		var t: Dictionary = g.data.towers[tower_id]
		for branch in [kind] + Balance.BRANCHES[kind].keys():
			events.clear()
			g.combat.enemies.clear()
			g.combat.pending_shots.clear()
			var enemy := g.combat.spawn("-1,0", "basic")
			enemy.pos = VigilWorld.pad_position("0,0", 0)
			enemy.hp = 100000.0
			enemy.max_hp = enemy.hp
			t.cooldown = 0.0
			if branch == kind:
				t.erase("branch")
			else:
				t.branch = branch
				t.level = 4
			g.combat.tick(Balance.STEP)
			check(events.has("shot_" + branch), "Weapon emits its own cue: " + branch)
			g.combat.advance_shots(1.0)
			if kind != "electric":
				check(events.has("impact_" + branch), "Projectile impact: " + branch)
			if branch == "cinderfield":
				check(events.has("power_ignite"), "Cinderfield ignition cue")
			if branch == "grave_echo":
				check(events.has("power_fragments"), "Grave Echo fragmentation cue")
			if branch == "thunderseal":
				for i in range(5):
					g.combat.branch_hit({"tower_id": tower_id, "branch": branch, "damage": 1.0}, enemy)
				check(events.has("power_seal"), "Thunderseal detonation cue")
		g.combat.enemies.clear()
		g.combat.pending_shots.clear()
		g.economy.sell(tower_id)
	var id := g.economy.build("rapid", "0,0", 0)
	for kind in Balance.ENEMIES:
		events.clear()
		g.data.regions["-1,0"].style = Balance.enemy_portal_style(kind)
		var source := preload("res://tests/support/orchard_fixture.gd").populate(g) if kind in Balance.ORCHARD_KINDS else "-1,0"
		var enemy := g.combat.spawn(source, kind)
		g.combat.hit(enemy, 100000.0, id)
		g.combat.hit(enemy, 100000.0, id)
		var cue: String = Balance.Content.enemy(kind).rule("death_cue")
		check(events.count(cue) == 1 and Director.CATALOG.has(cue), "Exactly one assigned death cue: " + kind)
	for kind in Balance.BOSSES:
		events.clear()
		var boss: Dictionary = g.combat.Bosses.create(g.combat, "-1,0", kind)
		check(events.has(Balance.Content.boss(kind).sound_cue("awaken")), "Boss awakening: " + kind)
		g.combat.Bosses.advance(g.combat, .05)
		check(events.has(Balance.Content.boss(kind).sound_cue("step")), "Boss movement: " + kind)
		boss.regen = .01
		boss.toll = .01
		boss.hp = boss.max_hp * .25
		g.combat.Bosses.advance(g.combat, .05)
		if kind == "warden":
			check(not events.has("boss_warden_ability"), "Warden never plays automatic shield refill audio")
		if kind in ["cindermaw", "bell", "prior"]:
			check(events.has("boss_" + kind + "_ability"), "Boss special ability: " + kind)
		boss.shield = 0.0
		boss.wards = 0
		g.combat.hit(boss, 1000000.0, id)
		check(events.has(Balance.Content.boss(kind).sound_cue("death")), "Boss death: " + kind)
	# Save validation, old saves, reset persistence and live settings widgets.
	var old_combat := g.combat
	var old_economy := g.economy
	app.reset_progress()
	a.stop_effects() # The explicit reset confirmation is allowed; idle effects are not.
	a.set_volume("music", 0.0)
	accepted = a.accepted_events
	old_combat.sound_requested.emit("shot_heavy", visible_position)
	old_economy.sound_requested.emit("menu_build", Vector2.INF)
	check(a.accepted_events == accepted, "Reset disconnects both stale simulation services")
	for i in range(600):
		g.combat.tick(Balance.STEP)
	check(a.accepted_events == accepted, "Fresh empty reset produces no spontaneous sound effects")
	check(a.music.volume_linear == 0.0, "Music zero silences the continuous background track")
	var snapshot := g.snapshot()
	snapshot.settings.erase("audio")
	check(g.storage.valid_data(snapshot), "Old saves need no audio fields")
	for invalid in [-.01, 1.01, NAN, "loud", true]:
		snapshot.settings.audio = {"towers": invalid}
		check(not g.storage.valid_data(snapshot), "Reject invalid audio values: " + str(invalid))
	a.set_volume("enemies", .17)
	a.set_muted(true)
	check(g.save(), "Audio preferences save")
	var restored := VigilState.new()
	restored.save_path = g.save_path
	check(restored.load_save(), "Audio preferences reload")
	check(restored.data.settings.audio.enemies == .17 and restored.data.settings.audio.muted, "Volumes and mute survive reload")
	for viewport in [Vector2i(540, 960), Vector2i(360, 640), Vector2i(390, 844)]:
		root.size = viewport
		root.content_scale_size = viewport
		app.panels.show_sound_settings()
		await settle()
		for category in Director.DEFAULTS:
			var number := app.panels.find_child("Audio_" + category, true, false) as SpinBox
			check(number != null, "Accessible number: " + category)
			check(number.global_position.x >= 0 and number.get_global_rect().end.x <= viewport.x, "Input fits narrow viewport")
			number.value = 23
			check(is_equal_approx(a.volume(category), .23), "Input changes live volume: " + category)
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("res://artifacts/audio-settings-%d.png" % viewport.x)
	var music_number := app.panels.find_child("Audio_music", true, false) as SpinBox
	var master_number := app.panels.find_child("Audio_master", true, false) as SpinBox
	master_number.get_line_edit().text = "10"
	master_number.get_line_edit().text_changed.emit("10")
	await settle()
	check(is_equal_approx(a.volume("master"), .1), "Typing 10 updates master without Enter or focus loss")
	music_number.get_line_edit().grab_focus()
	await settle()
	check(app.panels.content_scroll.get_global_rect().encloses(music_number.get_global_rect()), "Keyboard focus scrolls music number into view")
	var key := InputEventKey.new()
	var music_plus := music_number.get_parent().get_child(1).get_child(1)
	app.panels.content_scroll.ensure_control_visible(music_plus)
	await settle()
	music_plus.grab_focus()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	key.pressed = false
	Input.parse_input_event(key)
	await settle()
	check(a.volume("music") > .23, "Keyboard activates audio plus button")
	app.reset_progress()
	check(is_equal_approx(a.volume("enemies"), .23), "Progress reset preserves sound preferences")
	check(a.combat == g.combat and a.economy == g.economy, "Reset reconnects audio to the new simulation")
	a.set_muted(false)
	a.stop_effects()
	var campaign := preload("res://scripts/campaign/screen.gd").new()
	campaign.app = app
	campaign.progress.path = "user://audio-campaign-check.save"
	app.add_child(campaign)
	campaign.start_mission(0)
	await settle()
	campaign.set_process(false)
	check(campaign.run.start_wave(), "Campaign audio fixture starts a wave")
	a.elapsed += 2
	accepted = a.accepted_events
	campaign.run.game.combat.sound_requested.emit("shot_heavy", Vector2(100000, 100000))
	check(a.accepted_events == accepted, "Campaign preserves positions and rejects offscreen combat")
	campaign.run.game.combat.sound_requested.emit("shot_heavy", campaign.board.world(campaign.board.size * .5))
	check(a.accepted_events == accepted + 1, "Visible campaign combat is audible")
	campaign.paused = true
	a._process(0.0)
	check(not a.voices.towers.any(func(voice): return voice.playing), "Campaign pause stops combat tails")
	a.elapsed += 2
	accepted = a.accepted_events
	campaign.run.game.combat.sound_requested.emit("shot_heavy", campaign.board.world(campaign.board.size * .5))
	check(a.accepted_events == accepted, "Paused campaign rejects combat cues")
	campaign.paused = false
	campaign.run.game.combat.sound_requested.emit("shot_heavy", campaign.board.world(campaign.board.size * .5))
	check(a.accepted_events == accepted + 1, "Unpaused wave can play fresh combat")
	# Finish an actual wave through the simulation transition, then wait in planning.
	campaign.run.schedule.clear()
	campaign.run.next_spawn = 0
	campaign.run.tick(Balance.STEP)
	check(campaign.run.phase == "planning", "Empty completed wave enters planning")
	a._process(0.0)
	check(not a.voices.towers.any(func(voice): return voice.playing), "Wave completion stops combat tails")
	accepted = a.accepted_events
	for i in range(1200):
		campaign.run.tick(Balance.STEP)
		a._process(Balance.STEP)
	check(a.accepted_events == accepted, "One minute between waves produces no new effects")
	campaign.run.game.combat.sound_requested.emit("shot_heavy", campaign.board.world(campaign.board.size * .5))
	check(a.accepted_events == accepted, "Planning rejects late combat signals")
	campaign.run.game.economy.sound_requested.emit("menu_build", Vector2.INF)
	check(a.accepted_events == accepted + 1, "Planning retains building feedback")
	check(campaign.run.start_wave(), "Next wave starts normally")
	campaign.run.game.combat.sound_requested.emit("shot_heavy", campaign.board.world(campaign.board.size * .5))
	check(a.accepted_events == accepted + 2, "Next wave accepts fresh combat without stale cooldowns")
	campaign.show_map()
	a._process(0.0)
	check(not a.voices.towers.any(func(voice): return voice.playing), "Leaving campaign battle stops its combat tails")
	campaign.queue_free()
	await settle()
	var other := VigilApp.new()
	other.load_saved_progress = false
	other.game.save_path = "user://audio-other-check.save"
	root.add_child(other)
	other.set_process(false)
	await settle()
	var other_master := AudioServer.get_bus_index(other.audio.master_bus_name)
	var other_gain := AudioServer.get_bus_volume_db(other_master)
	a.set_volume("master", 0.0)
	check(not AudioServer.is_bus_mute(other_master) and AudioServer.get_bus_volume_db(other_master) == other_gain, "Independent app instances do not share master settings")
	other.queue_free()
	await settle()
	app.queue_free()
	await create_timer(.15).timeout
	check(AudioServer.bus_count == initial_buses, "App exit releases its private audio bus")
	print("AUDIO RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
