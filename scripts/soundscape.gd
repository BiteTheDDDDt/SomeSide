class_name SideSoundscape
extends Node

const Content = preload("res://scripts/content.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const SAMPLE_RATE: int = 22050
const MAX_VOICES: int = 12
const COMBAT_VOICES: int = 8
const SAMPLE_PEAK: float = 0.22
const VOICE_DB: float = -10.0
const MAX_SAMPLE_BYTES: int = 2 * 1024 * 1024
static var _sample_cache: Dictionary = {}
static var _recipes: Dictionary = {}
static var _ambient_cache: AudioStreamWAV
var enabled: bool = true
var wait_for_gesture: bool = OS.has_feature("web")
var _gesture_received: bool = false
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _voice_until: Array[int] = []
var _voice_priority: Array[int] = []
var _last: Dictionary = {}
var _ambient: AudioStreamPlayer
var _played: int = 0
var _dropped: int = 0
var _last_sound: String = ""
var _pending_melee: Array[Dictionary] = []
var _audio_seed: int = -1
var _audio_stage: int = -1

func _ready() -> void:
	_prepare_samples()
	_streams = _sample_cache.duplicate()
	for index in range(MAX_VOICES):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
		_voice_until.append(0)
		_voice_priority.append(-1)
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)
	_ambient.stream = _ambient_cache
	_ambient.volume_db = -15.0
	if enabled and not wait_for_gesture and DisplayServer.get_name() != "headless":
		_ambient.play()

## Complete deterministic PCM WAVs support Web Sample playback. No streaming
## generator, external audio assets, or gameplay RNG are involved.
func activate_from_gesture() -> void:
	_gesture_received = true
	if enabled and is_instance_valid(_ambient) and not _ambient.playing and DisplayServer.get_name() != "headless":
		_ambient.play()

func play_game_event(event: Dictionary, distance: float = 0.0) -> bool:
	if str(event.get("weapon", "")) == "arc_blade" and str(event.get("phase", "")) == "start":
		if not enabled or (wait_for_gesture and not _gesture_received) or not is_finite(distance) or distance > 1600.0:
			return false
		var owner: int = int(event.get("player", -1))
		var attack_id: int = int(event.get("attack_id", 0))
		var predicted: bool = bool(event.get("predicted", false))
		for pending: Dictionary in _pending_melee:
			if pending.player == owner and pending.attack_id == attack_id and pending.predicted == predicted:
				return false
		if _pending_melee.size() >= MAX_VOICES:
			_pending_melee.pop_front()
		_pending_melee.append({"player":owner, "attack_id":attack_id, "predicted":predicted,
			"delay":WeaponPose.melee_swing_time(float(event.get("duration", 0.36))), "age":0.0, "distance":distance})
		return true
	return _play_sound(event_sound(event), distance, Time.get_ticks_msec())

## The blade is audible as the fast sweep begins, after the visible windup.
## Advance from the game's presentation tick so solo pause also pauses the cue.
func reset_game_audio() -> void:
	_pending_melee.clear()
	_audio_seed = -1
	_audio_stage = -1

func sync_game_audio(state: Dictionary) -> void:
	var seed: int = int(state.get("seed", -1))
	var stage: int = int(state.get("stage", -1))
	if seed != _audio_seed or stage != _audio_stage:
		_pending_melee.clear()
		_audio_seed = seed
		_audio_stage = stage

func update_game_audio(delta: float, state: Dictionary, paused: bool = false, active: bool = true) -> void:
	sync_game_audio(state)
	if not active or not enabled or str(state.get("phase", "playing")) != "playing":
		_pending_melee.clear()
		return
	var players: Dictionary = state.get("players", {})
	for index: int in range(_pending_melee.size() - 1, -1, -1):
		var cue: Dictionary = _pending_melee[index]
		var owner: Dictionary = players.get(int(cue.player), {})
		if owner.is_empty() or bool(owner.get("dead", false)) or str(owner.get("weapon", "")) != "arc_blade":
			_pending_melee.remove_at(index)
			continue
		if paused:
			continue
		cue.age += maxf(0.0, delta)
		# Remote start events can arrive alongside an already-progressed snapshot.
		# Predicted local serials are independent and must not consume server time.
		if not bool(cue.predicted):
			var swing: Dictionary = owner.get("melee", {})
			if int(swing.get("id", -1)) == int(cue.attack_id):
				cue.age = maxf(float(cue.age), float(swing.get("elapsed", 0.0)))
			elif int(owner.get("attack_count", 0)) >= int(cue.attack_id):
				_pending_melee.remove_at(index)
				continue
		if float(cue.age) + 0.000001 >= float(cue.delay):
			_pending_melee.remove_at(index)
			_play_sound("weapon_arc_blade", float(cue.distance), Time.get_ticks_msec())

func play_event(kind: String, distance: float = 0.0) -> bool:
	return play_game_event({"type": kind}, distance)

## Pure dispatch; never annotate an authority event or player state.
static func event_sound(event: Dictionary) -> String:
	var type: String = str(event.get("type", ""))
	var kind: String = str(event.get("kind", ""))
	if type in ["shoot", "slash"] and event.has("weapon"):
		return "weapon_" + str(event.weapon) if str(event.weapon) in ["pulse_rifle", "arc_blade", "scattergun", "railgun", "flamethrower", "boomerang", "storm_staff", "sun_lance"] else ""
	match type:
		"equipment":
			var equipment: String = str(event.get("equipment", kind))
			return "equipment_" + equipment if equipment in ["grenade", "shockwave", "repair_field", "aegis", "graviton", "turret", "meteor", "time_warp"] else ""
		"shoot":
			if event.get("enemy", false):
				return "enemy_spit" if kind in ["spit", "boss_spore_orb"] else ("enemy_crystal" if kind == "crystal" else "enemy_pulse")
			if kind == "grenade": return "equipment_grenade"
			if kind == "turret": return "turret_shot"
			return "weapon_pulse_rifle"
		"slash": return "equipment_shockwave" if event.get("skill", false) else "weapon_arc_blade"
		"explosion":
			if event.get("healing", false): return "heal" if str(event.get("team", "")) == "enemy" else "equipment_repair_field"
			if event.get("shield", false): return "equipment_aegis"
			if kind in ["graviton", "turret", "time_warp"]: return "equipment_" + kind
			if kind == "meteor": return "meteor_impact"
			if kind in ["beam", "boss_beam"]: return "enemy_beam"
			if kind in ["echo", "nova", "lance"]: return "resonance"
			return "explosion"
		"hit":
			if event.get("friendly", false): return "damage"
			if event.has("arc_from"): return "arc_hit"
			return "critical" if event.get("crit", false) else "hit"
		"death":
			if kind == "player" or event.has("player"): return "player_down"
			if kind == "boss": return "boss_defeat"
			if kind in ["sentinel", "skirmisher", "conductor", "drone"]: return "death_metal"
			if kind in ["charger", "burrower"]: return "death_stone"
			return "death_organic"
		"pickup":
			if kind == "coin": return "coin"
			if kind == "heal": return "heal"
			var rarity: String = str(event.get("rarity", ""))
			if rarity.is_empty(): rarity = str(Content.definition(str(event.get("item", ""))).get("rarity", "common"))
			return "pickup_" + rarity if rarity in ["common", "uncommon", "rare", "legendary"] else "pickup_common"
		"interact":
			if kind in ["blood", "combat", "combat_clear", "choice"]: return "facility_" + kind
			return "facility_open"
		"jump": return "double_jump" if event.get("double", false) else "jump"
		"double_jump", "land", "heal", "coin", "ui", "ui_back", "ui_error", "stage", "win", "lose", "boss_spawn": return type
		"dash":
			if event.get("enemy", false): return "enemy_shift"
			return "ability_shoulder_rush" if event.get("ability", "") == "shoulder_rush" else "dash"
		"ability_hit": return "ability_shoulder_hit" if event.get("ability", "") == "shoulder_rush" else ""
		"gate": return "gate_ready" if event.get("ready", false) else "gate_active"
		"revive": return "phoenix" if event.get("phoenix", false) else ("revive_start" if event.get("started", false) else "revive")
	return ""

func _play_sound(key: String, distance: float, now: int) -> bool:
	if not enabled or (wait_for_gesture and not _gesture_received) or not _streams.has(key) or _players.is_empty():
		return false
	var recipe: Dictionary = _recipes[key]
	var priority: int = int(recipe.priority)
	var group: String = str(recipe.group)
	if not is_finite(distance) or (distance > 1600.0 and priority < 3):
		_dropped += 1
		return false
	if now - int(_last.get(key, -100000)) < int(recipe.gap) or (not group.is_empty() and now - int(_last.get("group:" + group, -100000)) < int(recipe.group_gap)):
		_dropped += 1
		return false
	# Combat only uses eight slots; pickups/damage/progression can use all
	# twelve and can steal lower priorities. Cosmetic hits cannot steal them.
	var limit: int = COMBAT_VOICES if priority < 3 else MAX_VOICES
	var slot: int = -1
	for index in range(limit):
		if _voice_until[index] <= now:
			slot = index
			break
	if slot < 0:
		for index in range(limit):
			if _voice_priority[index] <= priority and (slot < 0 or _voice_priority[index] < _voice_priority[slot] or (_voice_priority[index] == _voice_priority[slot] and _voice_until[index] < _voice_until[slot])):
				slot = index
	if slot < 0:
		_dropped += 1
		return false
	_last[key] = now
	if not group.is_empty(): _last["group:" + group] = now
	var player: AudioStreamPlayer = _players[slot]
	player.stop()
	player.stream = _streams[key]
	player.volume_db = VOICE_DB - clampf(maxf(0.0, distance) / 85.0, 0.0, 20.0)
	player.pitch_scale = 1.0
	_voice_until[slot] = now + int(ceil(player.stream.get_length() * 1000.0))
	_voice_priority[slot] = priority
	# Dedicated/headless sessions keep routing and voice accounting, but have
	# no audible output. Do not allocate dummy mixer playback instances there.
	if DisplayServer.get_name() != "headless": player.play()
	_played += 1
	_last_sound = key
	return true

func stats() -> Dictionary:
	var bytes: int = 0
	for sample: AudioStreamWAV in _streams.values(): bytes += sample.data.size()
	return {"samples": _streams.size(), "pcm_bytes": bytes, "max_voices": MAX_VOICES, "combat_voices": COMBAT_VOICES, "played": _played, "dropped": _dropped, "last_sound": _last_sound, "gesture_received": _gesture_received}

static func _layer(shape: String, duration: float, gain: float, start: float, finish: float = -1.0, delay: float = 0.0, decay: float = 2.0, texture: float = 0.0) -> Dictionary:
	return {"shape": shape, "duration": duration, "gain": gain, "start": start, "finish": start if finish < 0.0 else finish, "delay": delay, "decay": decay, "texture": texture}

static func _add(key: String, layers: Array, priority: int = 1, gap: int = 80, group: String = "", group_gap: int = 0, peak: float = SAMPLE_PEAK) -> void:
	_recipes[key] = {"layers": layers, "priority": priority, "gap": gap, "group": group, "group_gap": group_gap, "peak": minf(peak, SAMPLE_PEAK)}

static func _notes(notes: Array, step: float, duration: float, shape: String = "bell") -> Array:
	var layers: Array = []
	for index in range(notes.size()): layers.append(_layer(shape, duration, 0.55, float(notes[index]), -1.0, float(index) * step, 2.0))
	return layers

static func _prepare_samples() -> void:
	if not _sample_cache.is_empty(): return
	# Distinct material AND timing: electronic snap, sweeping blade, pellet
	# blast, ringing rail, gas/flutter, rotating metal, crackle, solar chord.
	_add("weapon_pulse_rifle", [_layer("fm", .10, .65, 980, 310, 0, 2.4, 2.5), _layer("sine", .075, .5, 175, 80), _layer("noise", .015, .3, 6000, 2200)], 1, 45, "shots", 24)
	_add("weapon_arc_blade", [_layer("air", .23, .8, 800, 4600, 0, .8), _layer("metal", .30, .35, 590, 420, .04, 2.6)], 1, 85, "shots", 24)
	_add("weapon_scattergun", [_layer("sine", .24, .95, 115, 38), _layer("noise", .15, 1.1, 7500, 500), _layer("metal", .055, .24, 1100, 800, .017), _layer("metal", .07, .2, 620, 290, .046)], 1, 90, "shots", 24)
	_add("weapon_railgun", [_layer("fm", .04, .42, 550, 2900, 0, .3, 5), _layer("noise", .038, .9, 8000, 1200, .023), _layer("metal", .37, .7, 1150, 190, .023, 2.8), _layer("sine", .16, .55, 145, 48, .025)], 1, 100, "shots", 24)
	_add("weapon_flamethrower", [_layer("noise", .155, 1, 1450, 720, 0, .6), _layer("flutter", .14, .45, 85, 62, 0, .7, 34)], 1, 90, "shots", 24, .16)
	_add("weapon_boomerang", [_layer("air", .29, .65, 2500, 600, 0, .9), _layer("flutter", .36, .5, 580, 440, 0, 1.5, 23), _layer("metal", .09, .25, 1450, 1000)], 1, 90, "shots", 24)
	_add("weapon_storm_staff", [_layer("fm", .21, .65, 420, 145, 0, 1.5, 8), _layer("crackle", .31, .7, 7000, 1800, .016, 1.4, 42), _layer("sine", .13, .5, 96, 48)], 1, 100, "shots", 24)
	_add("weapon_sun_lance", [_layer("sine", .35, .65, 220, 110), _layer("bell", .48, .45, 880, 660, .006), _layer("bell", .39, .3, 1320, 990, .012), _layer("air", .095, .65, 5500, 1400)], 1, 100, "shots", 24)
	_add("equipment_grenade", [_layer("metal", .03, .5, 1800, 1100), _layer("sine", .15, .85, 280, 92, .025), _layer("noise", .06, .4, 1500, 200, .03)], 3, 160)
	_add("equipment_shockwave", [_layer("sine", .32, .8, 145, 32), _layer("air", .28, .85, 5100, 450, .01, 1.2), _layer("fm", .08, .32, 400, 65, 0, 1.8, 5)], 3, 200)
	_add("equipment_repair_field", _notes([523.25, 659.25, 783.99, 1046.5], .08, .38), 3, 250)
	_add("equipment_aegis", [_layer("swell", .35, .65, 330, 440), _layer("bell", .46, .5, 880), _layer("bell", .40, .3, 1320, -1, .075)], 3, 250)
	_add("equipment_graviton", [_layer("swell", .48, .7, 260, 42), _layer("flutter", .55, .6, 115, 35, 0, .5, 17), _layer("air", .22, .35, 1900, 200, .28)], 3, 250)
	_add("equipment_turret", [_layer("metal", .045, .5, 750, 280), _layer("metal", .045, .5, 920, 440, .065), _layer("metal", .055, .5, 1100, 620, .13), _layer("fm", .19, .35, 210, 590, .16, 1.4, 2)], 3, 250)
	_add("equipment_meteor", [_layer("swell", .58, .6, 1040, 145), _layer("air", .61, .5, 6800, 300, 0, .5), _layer("bell", .35, .2, 138.59, -1, .14)], 3, 250)
	_add("equipment_time_warp", [_layer("swell", .60, .45, 320, 640), _layer("fm", .16, .6, 1250, 180, 0, 2, 4), _layer("fm", .16, .45, 1250, 180, .12, 2, 4), _layer("fm", .16, .3, 1250, 180, .24, 2, 4), _layer("bell", .30, .3, 960, -1, .32)], 3, 250)
	_add("jump", [_layer("sine", .14, .6, 125, 360, 0, 1.2), _layer("noise", .065, .35, 650, 220)], 1, 100, "movement", 65, .16)
	_add("double_jump", [_layer("air", .19, .4, 1700, 5200, 0, 1.1), _layer("bell", .24, .5, 780, 1120), _layer("bell", .17, .3, 1560, 2240, .035)], 1, 100, "movement", 65, .18)
	_add("land", [_layer("sine", .085, .7, 105, 46), _layer("noise", .065, .6, 1600, 350)], 1, 120, "movement", 65, .13)
	_add("dash", [_layer("air", .18, .75, 6500, 1100, 0, .65), _layer("fm", .13, .35, 130, 760, 0, 1.3, 2)], 1, 120, "movement", 65, .18)
	# Generic jump/hit events precede these in the same authoritative tick.
	# Own-key rate limits preserve their identity without bypassing voice caps.
	_add("ability_shoulder_rush", [_layer("metal", .065, .65, 390, 125), _layer("air", .21, .55, 1750, 420), _layer("fm", .18, .55, 125, 48, .02, 1.2, 2)], 2, 160, "", 0, .20)
	_add("ability_shoulder_hit", [_layer("sine", .14, .7, 105, 36), _layer("metal", .11, .6, 430, 100), _layer("noise", .09, .45, 1800, 270)], 2, 95, "", 0, .21)
	_add("hit", [_layer("noise", .04, .6, 2400, 800), _layer("sine", .06, .45, 225, 110)], 0, 75, "impacts", 45, .12)
	_add("critical", [_layer("metal", .12, .65, 1450, 660), _layer("noise", .035, .45, 3800, 1200)], 1, 100, "impacts", 45, .17)
	_add("arc_hit", [_layer("crackle", .095, .5, 5500, 1800, 0, 2, 68), _layer("fm", .08, .45, 860, 420, 0, 2, 7)], 0, 100, "impacts", 45, .12)
	_add("damage", [_layer("sine", .20, .75, 145, 47), _layer("metal", .11, .55, 420, 160), _layer("noise", .06, .4, 1100, 250)], 4, 170)
	_add("death_organic", [_layer("noise", .19, .9, 900, 130), _layer("fm", .18, .4, 185, 35, 0, 2, 3)], 0, 100, "deaths", 80, .16)
	_add("death_stone", [_layer("noise", .26, .85, 3300, 380), _layer("sine", .21, .6, 95, 32), _layer("noise", .07, .28, 4600, 950, .08)], 0, 100, "deaths", 80, .17)
	_add("death_metal", [_layer("metal", .28, .65, 460, 220), _layer("metal", .12, .25, 1280, 800, .075), _layer("noise", .10, .45, 4400, 950)], 0, 100, "deaths", 80, .17)
	_add("explosion", [_layer("noise", .36, .8, 3400, 90), _layer("sine", .30, .7, 82, 26)], 1, 110, "blasts", 80)
	_add("meteor_impact", [_layer("noise", .56, 1, 6600, 160), _layer("sine", .50, .9, 105, 25), _layer("crackle", .33, .35, 3000, 700, .15, 2, 31)], 2, 170, "blasts", 80)
	_add("resonance", [_layer("bell", .20, .6, 660, 320), _layer("fm", .12, .4, 440, 140, 0, 2, 4)], 1, 130, "blasts", 80, .17)
	_add("turret_shot", [_layer("metal", .06, .55, 880, 480), _layer("noise", .045, .35, 3300, 1400)], 0, 90, "shots", 24, .13)
	_add("enemy_spit", [_layer("fm", .17, .55, 240, 70, 0, 1.2, 6), _layer("noise", .12, .6, 780, 180)], 0, 140, "enemy_shots", 100, .15)
	_add("enemy_crystal", [_layer("metal", .21, .6, 1240, 980), _layer("air", .055, .35, 4600, 1700)], 0, 140, "enemy_shots", 100, .15)
	_add("enemy_pulse", [_layer("fm", .18, .55, 470, 180, 0, 2, 7), _layer("sine", .10, .4, 100, 55)], 0, 140, "enemy_shots", 100, .15)
	_add("enemy_beam", [_layer("flutter", .25, .6, 175, 85, 0, 1.2, 55), _layer("noise", .18, .45, 3000, 800)], 2, 180)
	_add("enemy_shift", [_layer("air", .15, .6, 1500, 5200), _layer("fm", .09, .3, 400, 60, 0, 2, 5)], 0, 180, "enemy_shots", 100, .13)
	_add("coin", _notes([1568, 2093], .028, .085), 3, 90, "", 0, .11)
	_add("heal", _notes([523.25, 783.99], .06, .24, "sine"), 3, 180, "", 0, .17)
	_add("pickup_common", _notes([659.25, 987.77], .085, .22), 4, 130, "", 0, .18)
	_add("pickup_uncommon", _notes([523.25, 659.25, 1046.5], .085, .26), 4, 130)
	_add("pickup_rare", _notes([440, 659.25, 880, 1318.5], .09, .40), 4, 160)
	_add("pickup_legendary", _notes([261.63, 392, 523.25, 659.25, 1046.5], .12, .55) + [_layer("swell", .78, .22, 130.81)], 5, 200)
	_add("facility_open", [_layer("metal", .075, .6, 540, 180), _layer("noise", .16, .45, 800, 190, .05), _layer("bell", .24, .25, 660, -1, .13)], 3, 220)
	_add("facility_choice", _notes([660, 880, 1320], .055, .20), 3, 220)
	_add("facility_blood", [_layer("sine", .23, .7, 92, 48), _layer("sine", .21, .55, 92, 48, .13), _layer("metal", .36, .2, 311.13)], 3, 220)
	_add("facility_combat", _notes([220, 233.08, 220], .11, .20, "fm"), 4, 350)
	_add("facility_combat_clear", _notes([392, 523.25, 783.99], .10, .34), 4, 350)
	_add("gate_active", [_layer("swell", .85, .65, 110, 220), _layer("metal", .65, .35, 233.08), _layer("metal", .65, .25, 349.23, -1, .18)], 5, 500)
	_add("gate_ready", _notes([392, 523.25, 659.25, 783.99], .12, .48), 5, 500)
	_add("boss_spawn", [_layer("swell", .85, .75, 65.4, 82.4), _layer("metal", .60, .4, 155.56), _layer("metal", .45, .3, 164.81, -1, .25)], 5, 650)
	_add("boss_defeat", [_layer("noise", .75, .65, 3000, 110), _layer("sine", .60, .7, 100, 30)] + _notes([196, 293.66, 392], .19, .65), 5, 650)
	_add("revive_start", _notes([440, 523.25], .09, .25, "sine"), 4, 350)
	_add("revive", _notes([329.63, 440, 659.25, 880], .10, .38), 5, 350)
	_add("phoenix", [_layer("air", .40, .55, 650, 4500)] + _notes([261.63, 523.25, 1046.5], .13, .47), 5, 450)
	_add("player_down", _notes([220, 164.81, 110], .14, .36, "metal"), 5, 450)
	_add("stage", _notes([261.63, 392, 523.25], .13, .40), 5, 500)
	_add("win", _notes([261.63, 329.63, 392, 523.25, 783.99], .14, .48), 5, 750)
	_add("lose", _notes([293.66, 220, 146.83], .20, .44, "sine"), 5, 750)
	_add("ui", [_layer("sine", .045, .55, 880, 1120), _layer("bell", .065, .2, 1760)], 3, 45, "", 0, .10)
	_add("ui_back", [_layer("sine", .075, .6, 660, 440)], 3, 60, "", 0, .10)
	_add("ui_error", _notes([185, 174.61], .09, .10, "fm"), 4, 250, "", 0, .14)
	for key: String in _recipes: _sample_cache[key] = _synthesize(key, _recipes[key])
	_ambient_cache = _make_ambient()

static func _synthesize(key: String, recipe: Dictionary) -> AudioStreamWAV:
	var duration: float = 0.0
	for layer: Dictionary in recipe.layers: duration = maxf(duration, float(layer.delay) + float(layer.duration))
	var count: int = int(ceil(duration * SAMPLE_RATE)) + 1
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	for layer: Dictionary in recipe.layers:
		var offset: int = int(float(layer.delay) * SAMPLE_RATE)
		var length: int = maxi(2, int(float(layer.duration) * SAMPLE_RATE))
		var shape: String = str(layer.shape)
		var gain: float = float(layer.gain)
		var start: float = float(layer.start)
		var finish: float = float(layer.finish)
		var decay: float = float(layer.decay)
		var texture: float = float(layer.texture)
		var phase: float = 0.0
		var filtered: float = 0.0
		for index in range(length):
			var progress: float = float(index) / float(length - 1)
			var seconds: float = float(index) / SAMPLE_RATE
			var frequency: float = lerpf(start, finish, progress)
			phase += TAU * frequency / SAMPLE_RATE
			var envelope: float = minf(seconds / .0025, 1.0) * pow(1.0 - progress, decay)
			var wave: float = 0.0
			match shape:
				"noise", "air", "crackle":
					var noise: float = rng.randf_range(-1.0, 1.0)
					filtered += (noise - filtered) * clampf(TAU * frequency / SAMPLE_RATE, .02, .95)
					wave = filtered if shape != "air" else (noise - filtered) * .7
					if shape == "crackle": wave *= .15 + .85 * pow(maxf(0.0, sin(TAU * seconds * texture)), 3.0)
				"metal": wave = (sin(phase) + .50 * sin(phase * 1.473) + .27 * sin(phase * 2.091)) * .6
				"bell": wave = (sin(phase) + .40 * sin(phase * 2.0) * (1.0 - progress) + .17 * sin(phase * 4.012) * pow(1.0 - progress, 3)) * .7
				"fm": wave = sin(phase + sin(phase * 2.71) * (texture if texture > 0.0 else 2.0) * (1.0 - progress))
				"flutter": wave = (sin(phase) + .23 * sin(phase * 3.0)) * (.55 + .45 * sin(TAU * seconds * texture))
				"swell":
					wave = sin(phase) + .20 * sin(phase * 2.003)
					envelope = pow(maxf(0.0, sin(PI * progress)), .8)
				_: wave = sin(phase) + .09 * sin(phase * 2.0)
			mix[offset + index] += wave * envelope * gain
	var peak: float = .001
	for value: float in mix: peak = maxf(peak, absf(value))
	var scale: float = float(recipe.peak) / peak
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count): data.encode_s16(index * 2, int(clampf(mix[index] * scale, -SAMPLE_PEAK, SAMPLE_PEAK) * 32767.0))
	return _wav(data)

static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = SAMPLE_RATE
	sound.data = data
	return sound

static func _make_ambient() -> AudioStreamWAV:
	var count: int = SAMPLE_RATE * 8
	var data := PackedByteArray()
	data.resize(count * 2)
	for index in range(count):
		var t: float = float(index) / SAMPLE_RATE
		var wave: float = (sin(TAU * 55.0 * t) * .18 + sin(TAU * 82.5 * t) * .08 + sin(TAU * 110.0 * t) * .04) * (.7 + .3 * sin(TAU * t / 8.0))
		data.encode_s16(index * 2, int(wave * 32767.0))
	var sound: AudioStreamWAV = _wav(data)
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = count
	return sound

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	enabled = false
	_pending_melee.clear()
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.stream = null
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_streams.clear()
	_last.clear()
	_voice_until.fill(0)
