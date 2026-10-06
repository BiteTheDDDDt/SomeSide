extends SceneTree

const Sound = preload("res://scripts/soundscape.gd")
const Content = preload("res://scripts/content.gd")
const Simulation = preload("res://scripts/simulation.gd")
var passed: int = 0
var failed: int = 0
var sound: Node
var measurements: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, title: String) -> void:
	if value:
		passed += 1
		print("PASS: ", title)
	else:
		failed += 1
		push_error("FAIL: " + title)

func _measure(sample: AudioStreamWAV) -> Dictionary:
	var data: PackedByteArray = sample.data
	var count: int = data.size() / 2
	var peak: float = 0.0
	var sum: float = 0.0
	var energy: float = 0.0
	var crossings: int = 0
	var previous: float = 0.0
	var envelope: Array[float] = [0, 0, 0, 0, 0, 0, 0, 0]
	for index in range(count):
		var value: float = float(data.decode_s16(index * 2)) / 32767.0
		peak = maxf(peak, absf(value))
		sum += value
		energy += value * value
		envelope[mini(7, index * 8 / count)] += value * value
		if index > 0 and value * previous < 0.0: crossings += 1
		previous = value
	for index in range(8): envelope[index] /= maxf(energy, 0.000001)
	return {"seconds": sample.get_length(), "bytes": data.size(), "peak": peak, "rms": sqrt(energy / count), "dc": sum / count, "crossings_per_second": float(crossings) / sample.get_length(), "envelope": envelope}

func _reset_voices() -> void:
	sound._last.clear()
	sound._voice_until.fill(0)
	sound._voice_priority.fill(-1)
	for player: AudioStreamPlayer in sound._players: player.stop()

func _preview(keys: Array, filename: String) -> Array:
	var data := PackedByteArray()
	var timeline: Array = []
	for key: String in keys:
		var sample: AudioStreamWAV = sound._streams[key]
		timeline.append({"at_seconds": float(data.size()) / (2 * Sound.SAMPLE_RATE), "sound": key})
		data.append_array(sample.data)
		data.resize(data.size() + int(0.45 * Sound.SAMPLE_RATE) * 2)
	var wav: AudioStreamWAV = Sound._wav(data)
	_check(wav.save_to_wav(filename) == OK, "The original PCM listening preview exports: " + filename.get_file())
	return timeline

func _run() -> void:
	var profile_exists: bool = FileAccess.file_exists("user://profile.cfg")
	var profile_bytes: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if profile_exists else PackedByteArray()
	var started: int = Time.get_ticks_usec()
	sound = Sound.new()
	sound.enabled = false
	sound.wait_for_gesture = true
	root.add_child(sound)
	var cold_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	_check(sound._streams.size() >= 55 and sound._players.size() == 12, "The sound bank covers the event families with a fixed twelve-player pool")
	var format_ok: bool = true
	var levels_ok: bool = true
	var edges_ok: bool = true
	var fingerprints: Dictionary = {}
	for key: String in sound._streams:
		var sample: AudioStreamWAV = sound._streams[key]
		var metrics: Dictionary = _measure(sample)
		measurements[key] = metrics
		format_ok = format_ok and sample.mix_rate == 22050 and sample.format == AudioStreamWAV.FORMAT_16_BITS and not sample.stereo and sample.loop_mode == AudioStreamWAV.LOOP_DISABLED
		levels_ok = levels_ok and metrics.peak <= Sound.SAMPLE_PEAK + 0.0001 and metrics.rms > 0.008 and metrics.rms < 0.13 and absf(metrics.dc) < 0.008
		edges_ok = edges_ok and sample.data.decode_s16(0) == 0 and sample.data.decode_s16(sample.data.size() - 2) == 0 and metrics.seconds >= 0.04 and metrics.seconds <= 1.2
		fingerprints[sample.data.hex_encode().sha256_text()] = true
	_check(format_ok, "Every effect is a complete non-looping mono 16-bit 22050 Hz WAV for Web Sample playback")
	_check(levels_ok, "Every generated effect is audible, DC-balanced and capped at 0.22 peak without clipping")
	_check(edges_ok, "Effects have silent endpoints and bounded short durations rather than hard cut clicks")
	_check(fingerprints.size() == sound._streams.size(), "All sound entries have distinct actual PCM data")
	var stats: Dictionary = sound.stats()
	_check(int(stats.pcm_bytes) + sound._ambient.stream.data.size() < Sound.MAX_SAMPLE_BYTES, "Effects plus loop ambience fit within the 2 MiB PCM budget")
	_check(Sound.MAX_VOICES * Sound.SAMPLE_PEAK * db_to_linear(Sound.VOICE_DB) + 0.30 * db_to_linear(-15.0) < 0.95, "Even twelve coherently aligned peak effects plus ambience preserve mix headroom")
	_check(sound._ambient.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and sound._ambient.stream.get_length() == 8.0, "The existing quiet ambience remains a complete eight-second looping WAV")
	started = Time.get_ticks_usec()
	var other: Node = Sound.new()
	other.enabled = false
	root.add_child(other)
	var warm_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	_check(other._streams.weapon_railgun == sound._streams.weapon_railgun and other._ambient.stream == sound._ambient.stream, "Additional game nodes share immutable samples instead of synthesizing duplicate banks")
	other.shutdown()
	_check(sound._streams.weapon_railgun.data.size() > 0, "Shutting down another soundscape cannot clear the shared sample resources")
	other.queue_free()
	_check(Sound._synthesize("weapon_storm_staff", Sound._recipes.weapon_storm_staff).data == sound._streams.weapon_storm_staff.data, "Noise, modulation and envelopes reproduce exactly without global gameplay randomness")
	var sim: Variant = Simulation.new()
	sim.start_run([{"id": 1, "name": "Audio", "character": "ranger"}], 1401)
	var player: Dictionary = sim.state.players[1]
	player.pos = Vector2(640, 650)
	player.aim = Vector2.RIGHT
	var weapon_keys: Array = []
	var equipment_keys: Array = []
	var material_signatures: Dictionary = {}
	var envelope_signatures: Dictionary = {}
	for definition: Dictionary in Content.weapons():
		player.weapon = definition.id
		player.fire_cd = 0.0
		sim.events.clear()
		sim._fire_weapon(player)
		var found: String = ""
		var before: PackedByteArray = var_to_bytes(sim.events)
		for event: Dictionary in sim.events:
			if event.has("weapon"): found = Sound.event_sound(event)
		var key: String = "weapon_" + str(definition.id)
		_check(found == key and sound._streams.has(key) and before == var_to_bytes(sim.events), "Actual " + str(definition.id) + " attack selects its authored sound without changing the event")
		weapon_keys.append(key)
		var shapes: Array = []
		for layer: Dictionary in Sound._recipes[key].layers: shapes.append(layer.shape)
		material_signatures[str(shapes)] = true
		var quantized: Array = []
		for value: float in measurements[key].envelope: quantized.append(roundi(value * 20.0))
		envelope_signatures[str(quantized)] = true
	_check(material_signatures.size() >= 7 and envelope_signatures.size() >= 6, "Weapons differ in synthesis materials AND measured temporal envelopes, not just pitch")
	for definition: Dictionary in Content.equipment():
		player.equipment = definition.id
		player.skill_cd = 0.0
		sim.events.clear()
		sim._use_skill(player)
		var key: String = "equipment_" + str(definition.id)
		var found: bool = false
		for event: Dictionary in sim.events: found = found or Sound.event_sound(event) == key
		_check(found and sound._streams.has(key), "Actual successful " + str(definition.id) + " activation selects its unique cast sound")
		equipment_keys.append(key)
	for rarity: String in ["common", "uncommon", "rare", "legendary"]:
		_check(Sound.event_sound({"type": "pickup", "kind": "item", "rarity": rarity}) == "pickup_" + rarity, rarity + " item rarity selects its own pickup motif")
	_check(Sound.event_sound({"type": "pickup", "kind": "item", "item": "nova"}) == "pickup_legendary", "A legacy pickup resolves its rarity from the content catalog")
	_check(Sound.event_sound({"type": "pickup", "kind": "coin", "automatic": true, "amount": 8}) == "coin" and Sound.event_sound({"type": "pickup", "kind": "heal"}) == "heal", "Automatic team coins and healing pickups remain distinct from item fanfares")
	var routes: Array = [
		[{"type": "jump"}, "jump"], [{"type": "jump", "double": true}, "double_jump"], [{"type": "land"}, "land"], [{"type": "dash"}, "dash"],
		[{"type": "hit", "friendly": true}, "damage"], [{"type": "hit", "crit": true}, "critical"], [{"type": "hit", "arc_from": Vector2.ZERO}, "arc_hit"],
		[{"type": "death", "kind": "boss"}, "boss_defeat"], [{"type": "death", "kind": "player"}, "player_down"],
		[{"type": "gate", "active": true}, "gate_active"], [{"type": "gate", "ready": true}, "gate_ready"],
		[{"type": "revive", "started": true}, "revive_start"], [{"type": "revive"}, "revive"], [{"type": "revive", "phoenix": true}, "phoenix"],
		[{"type": "explosion", "kind": "meteor"}, "meteor_impact"], [{"type": "shoot", "kind": "turret"}, "turret_shot"],
		[{"type": "shoot", "kind": "spit", "enemy": true}, "enemy_spit"], [{"type": "shoot", "kind": "crystal", "enemy": true}, "enemy_crystal"]]
	for route: Array in routes: _check(Sound.event_sound(route[0]) == route[1], "Event routing: " + str(route[1]))
	for facility: String in ["cache", "choice", "blood", "combat", "combat_clear"]:
		_check(sound._streams.has(Sound.event_sound({"type": "interact", "kind": facility})), "Facility feedback exists for " + facility)
	_check(Sound.event_sound({"type": "notice", "message": "Player supplied text"}).is_empty() and Sound.event_sound({"type": "equipment", "equipment": "unknown"}).is_empty(), "Unknown events and arbitrary notice text do not accidentally fire a generic sound")
	sound.enabled = true
	_check(not sound.play_event("ui") and sound._played == 0 and not sound._ambient.playing, "Web audio cannot start before a real input gesture")
	sound.activate_from_gesture()
	_check(sound.play_event("ui") and sound._gesture_received, "A gesture unlocks backward-compatible UI playback")
	sound.enabled = false
	_check(not sound.play_game_event({"type": "gate", "ready": true}), "The existing mute guard still suppresses every new event")
	sound.enabled = true
	_reset_voices()
	var coins: int = 0
	for index in range(200):
		if sound._play_sound("coin", 0.0, 1000): coins += 1
	_check(coins == 1 and sound._play_sound("coin", 0.0, 1090), "A mass coin reward plays one short chime per 90 ms and recovers at the next window")
	_reset_voices()
	_check(sound._play_sound("weapon_pulse_rifle", 0.0, 2000) and not sound._play_sound("weapon_pulse_rifle", 0.0, 2020) and not sound._play_sound("weapon_scattergun", 0.0, 2020) and sound._play_sound("weapon_pulse_rifle", 0.0, 2045), "Per-weapon and shared attack cooldowns prevent multi-pellet and cooperative shot bursts from clipping the mix")
	_reset_voices()
	_check(sound._play_sound("hit",0.0,2100) and sound._play_sound("proc_missile",0.0,2100), "A triggering hit and its missile launch can both be heard in one authority tick")
	_check(not sound._play_sound("proc_wave",0.0,2105) and sound._play_sound("proc_halo",0.0,2200), "Cooperative trigger bursts share a bounded cue rate and recover after the window")
	_reset_voices()
	for index in range(8):
		sound._voice_until[index] = 4000
		sound._voice_priority[index] = 2
	_check(not sound._play_sound("hit", 0.0, 3000), "Low-priority hits never steal a full combat pool from stronger effects")
	_check(sound._play_sound("pickup_legendary", 0.0, 3000) and sound._players[8].stream == sound._streams.pickup_legendary, "Legendary pickup feedback uses a reserved slot during saturated combat")
	_check(sound._play_sound("damage", 0.0, 3000), "Player damage remains audible alongside a major pickup and dense combat")
	for index in range(12):
		sound._voice_until[index] = 5000
		sound._voice_priority[index] = 5
	_check(not sound._play_sound("coin", 0.0, 3100), "Repeated coin ticks cannot interrupt twelve higher-priority progression cues")
	_reset_voices()
	_check(not sound._play_sound("enemy_pulse", 1700.0, 6000) and not sound._play_sound("enemy_pulse", INF, 6000), "Inaudible or invalid distant effects do not consume mixer voices")
	_check(sound._play_sound("weapon_pulse_rifle", 850.0, 6000) and is_equal_approx(sound._players[0].volume_db, -20.0), "Distance attenuates nearby combat smoothly without altering pitch")
	var table_size: int = Sound._recipes.size()
	for index in range(5000): sound.play_game_event({"type": "unknown_" + str(index), "owner": index})
	_check(sound._players.size() == 12 and sound._last.size() <= table_size + 8, "Arbitrary entity IDs and event spam cannot grow the voice pool or cooldown registry")
	var report: Dictionary = {"cold_build_ms": cold_ms, "warm_node_ms": warm_ms, "sound": stats, "ambient_pcm_bytes": sound._ambient.stream.data.size(), "measurements": measurements}
	if "--audio-preview" in OS.get_cmdline_user_args():
		var directory: String = "res://tools/results/audio-preview"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		report["weapons_timeline"] = _preview(weapon_keys, directory + "/weapons.wav")
		report["equipment_timeline"] = _preview(equipment_keys, directory + "/equipment.wav")
		report["feedback_timeline"] = _preview(["jump", "double_jump", "land", "dash", "coin", "pickup_common", "pickup_uncommon", "pickup_rare", "pickup_legendary", "damage", "heal", "facility_open", "gate_active", "gate_ready", "boss_defeat", "revive"], directory + "/feedback.wav")
		var file := FileAccess.open(directory + "/report.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	print("AUDIO_STATS ", JSON.stringify({"cold_build_ms": cold_ms, "warm_node_ms": warm_ms, "samples": stats.samples, "pcm_bytes": stats.pcm_bytes, "ambient_bytes": sound._ambient.stream.data.size()}))
	sound.shutdown()
	_check(sound._streams.is_empty() and sound._ambient.stream == null and sound._players.all(func(p: AudioStreamPlayer) -> bool: return p.stream == null), "Shutdown releases node playback and stream references")
	var after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if FileAccess.file_exists("user://profile.cfg") else PackedByteArray()
	_check(FileAccess.file_exists("user://profile.cfg") == profile_exists and after == profile_bytes, "Audio validation and previews leave the user's profile untouched")
	sound.queue_free()
	await process_frame
	# The dummy mixer consumes queued stop/free commands on its own tick.
	# Let it drain before exiting this unusually dense playback fixture.
	await create_timer(0.10).timeout
	print("AUDIO_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
