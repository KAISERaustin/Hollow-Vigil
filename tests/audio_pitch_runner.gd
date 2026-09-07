extends "res://tests/audio_runner.gd"

class MissingMusic extends Director:
	func load_stream(cue: String) -> AudioStream:
		return null if cue == "lantern_watch" else super.load_stream(cue)

func run() -> void:
	app = VigilApp.new()
	app.load_saved_progress = false
	app.game.save_path = "user://audio-pitch-" + str(Time.get_ticks_usec()) + ".save"
	root.add_child(app)
	app.set_process(false)
	var a: Node = app.audio
	a.set_suspended(false)
	a.set_muted(false)
	a.pitch_rng.seed = 391
	var gameplay_state: int = app.game.combat.rng.state
	var specs := Director.CATALOG.duplicate(true)
	for cue in Director.CATALOG:
		var observed := {}
		var rate: int = a.streams[cue].mix_rate
		if cue == "lantern_watch":
			check(a.playback_pitch(cue) == 1.0 and a.music.pitch_scale == 1.0, "Music keeps normal pitch")
			continue
		for iteration in range(32):
			a.stop_effects()
			a.elapsed += float(Director.CATALOG[cue].cooldown) + 1.0
			var accepted: int = a.accepted_events
			a.play(cue)
			var active: Array = a.voices[Director.CATALOG[cue].category].filter(func(voice): return voice.playing)
			check(a.accepted_events == accepted + 1 and active.size() == 1, "Playback accepted for " + cue)
			if active.is_empty(): continue
			var pitch: float = active[0].pitch_scale
			check(pitch >= 0.9 and pitch <= 1.1, "Playback pitch bounds: " + cue)
			observed[pitch] = true
		check(observed.size() > 1, "Independent playback variation: " + cue)
		check(observed.keys().min() < 1.0 and observed.keys().max() > 1.0, "Pitch varies above and below normal: " + cue)
		check(a.streams[cue].mix_rate == rate, "Playback does not modify source stream: " + cue)
	check(app.game.combat.rng.state == gameplay_state, "Audio variation never consumes gameplay RNG")
	check(Director.CATALOG == specs, "Playback never changes shared audio configuration")
	var other := Director.new()
	other.pitch_rng.seed = 77
	var other_state: int = other.pitch_rng.state
	a.playback_pitch("shot_rapid")
	check(other.pitch_rng.state == other_state, "Audio instances own independent random state")
	other.free()
	a.stop_effects()
	a.elapsed += 1.0
	var accepted: int = a.accepted_events
	var pitch_state: int = a.pitch_rng.state
	var saved: AudioStream = a.streams.shot_frostneedle
	a.streams.shot_frostneedle = null
	a.play("shot_frostneedle")
	a.play("missing_cue")
	check(a.accepted_events == accepted and a.pitch_rng.state == pitch_state, "Unavailable cues do not play or consume pitch RNG")
	check(a.load_stream("missing_cue") == null, "Missing asset lookup fails quietly")
	a.streams.shot_frostneedle = saved
	a.set_muted(true)
	a.play("shot_frostneedle")
	check(a.pitch_rng.state == pitch_state, "Muted playback does not consume pitch RNG")
	var missing := MissingMusic.new()
	missing.app = app
	app.add_child(missing)
	check(missing.music.stream == null and not missing.music.playing, "Missing music asset does not interrupt startup")
	missing.queue_free()
	a.stop_effects()
	a.music.stop()
	a.music.stream = null
	for pool in a.voices.values():
		for voice in pool: voice.stream = null
	await create_timer(0.1).timeout
	app.queue_free()
	await create_timer(0.1).timeout
	check(AudioServer.bus_count == initial_buses, "Audio instances release playback resources")
	print("AUDIO PITCH: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
