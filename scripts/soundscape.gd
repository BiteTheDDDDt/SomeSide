class_name SideSoundscape
extends Node

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _last: Dictionary = {}
var _ambient: AudioStreamPlayer

func _ready() -> void:
	for i in range(12):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_streams["shoot"] = _tone(750.0, 190.0, 0.075, 0.2, 0.2)
	_streams["hit"] = _tone(210.0, 75.0, 0.075, 0.25, 0.65)
	_streams["death"] = _tone(170.0, 30.0, 0.21, 0.25, 0.6)
	_streams["explosion"] = _tone(110.0, 23.0, 0.36, 0.35, 0.8)
	_streams["slash"] = _tone(600.0, 70.0, 0.18, 0.2, 0.6)
	_streams["dash"] = _tone(160.0, 850.0, 0.16, 0.15, 0.4)
	_streams["pickup"] = _tone(640.0, 1280.0, 0.18, 0.18, 0.0)
	_streams["gate"] = _tone(120.0, 440.0, 0.7, 0.18, 0.0)
	_streams["stage"] = _tone(400.0, 850.0, 0.6, 0.22, 0.0)
	_streams["win"] = _tone(440.0, 1320.0, 1.0, 0.2, 0.0)
	_streams["lose"] = _tone(240.0, 55.0, 0.9, 0.2, 0.0)
	_streams["revive"] = _streams["stage"]
	_streams["ui"] = _tone(520.0, 820.0, 0.06, 0.09, 0.0)
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)
	_ambient.stream = _make_ambient()
	_ambient.volume_db = -15.0
	if enabled and DisplayServer.get_name() != "headless":
		_ambient.play()

func play_event(kind: String, distance: float = 0.0) -> void:
	if not enabled or not _streams.has(kind) or _players.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var spacing: int = 55 if kind in ["shoot", "hit"] else 100
	if now - int(_last.get(kind, -1000)) < spacing:
		return
	_last[kind] = now
	var player: AudioStreamPlayer = _players[_cursor % _players.size()]
	_cursor += 1
	player.stream = _streams[kind]
	player.volume_db = -6.0 - clampf(distance / 80.0, 0.0, 20.0)
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()

func _tone(start: float, finish: float, duration: float, volume: float, noise_mix: float) -> AudioStreamWAV:
	var rate: int = 22050
	var count: int = int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(start)
	for i in range(count):
		var t: float = float(i) / float(count)
		phase += TAU * lerpf(start, finish, t) / float(rate)
		var envelope: float = minf(t * 40.0, 1.0) * pow(1.0 - t, 2.0)
		var wave: float = lerpf(sin(phase) + sin(phase * 2.01) * 0.15, rng.randf_range(-1.0, 1.0), noise_mix)
		data.encode_s16(i * 2, int(clampf(wave * envelope * volume, -1.0, 1.0) * 32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = data
	return sound

func _make_ambient() -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 8.0
	var count: int = int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(rate)
		var breath: float = 0.7 + 0.3 * sin(TAU * t / duration)
		var wave: float = (sin(TAU * 55.0 * t) * 0.18 + sin(TAU * 82.5 * t) * 0.08 + sin(TAU * 110.0 * t) * 0.04) * breath
		data.encode_s16(i * 2, int(wave * 32767.0))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = count
	sound.data = data
	return sound

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	enabled = false
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.stream = null
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_streams.clear()
