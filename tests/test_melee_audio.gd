extends SceneTree

const Sound = preload("res://scripts/soundscape.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
class Recorder extends Sound:
	var heard: Array[String] = []
	func _play_sound(key: String, _distance: float, _now: int) -> bool:
		heard.append(key)
		return true

var sound: Recorder
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _state() -> Dictionary:
	sound.heard.clear()
	sound.reset_game_audio()
	var state: Dictionary = {"seed":15, "stage":1, "phase":"playing", "players":{1:{"weapon":"arc_blade", "dead":false, "attack_count":1, "melee":{"id":1,"elapsed":0.0}}}}
	sound.sync_game_audio(state)
	return state

func _cue(predicted: bool = false, length: float = 0.36, id: int = 1) -> Dictionary:
	return {"type":"slash", "weapon":"arc_blade", "phase":"start", "player":1, "duration":length, "attack_id":id, "predicted":predicted}

func _run() -> void:
	sound = Recorder.new()
	sound.wait_for_gesture = false
	root.add_child(sound)
	var state: Dictionary = _state()
	var delay: float = Pose.melee_swing_time(.36)
	_check(sound.play_game_event(_cue()) and sound.heard.is_empty(), "Starting a blade windup does not play the sweep sound early")
	_check(not sound.play_game_event(_cue()) and sound._pending_melee.size() == 1, "A duplicated pending swing cannot queue its whoosh twice")
	sound.update_game_audio(delay * .5, state)
	_check(sound.heard.is_empty(), "The first half of the windup stays silent")
	sound.update_game_audio(delay * .5, state)
	_check(sound.heard == ["weapon_arc_blade"], "The shared swing threshold plays exactly one blade whoosh")
	sound.update_game_audio(1.0, state)
	_check(sound.heard.size() == 1, "Later presentation ticks never repeat that swing sound")
	state = _state()
	sound.play_game_event(_cue())
	sound.update_game_audio(2.0, state, true)
	_check(sound.heard.is_empty(), "Solo pause freezes the windup's pending cue")
	sound.update_game_audio(delay, state)
	_check(sound.heard.size() == 1, "Resuming finishes the same pending windup")
	for cancellation: String in ["death", "weapon", "departed", "stage", "seed", "menu", "finished"]:
		state = _state()
		sound.play_game_event(_cue())
		match cancellation:
			"death": state.players[1].dead = true
			"weapon": state.players[1].weapon = "pulse_rifle"
			"departed": state.players.clear()
			"stage": state.stage = 2
			"seed": state.seed = 16
			"finished": state.phase = "won"
		sound.update_game_audio(1.0, state, false, cancellation != "menu")
		_check(sound.heard.is_empty() and sound._pending_melee.is_empty(), cancellation + " cancels the unplayed melee cue")
	state = _state()
	state.players[1].melee.elapsed = .20
	sound.play_game_event(_cue())
	sound.update_game_audio(0.0, state)
	_check(sound.heard.size() == 1, "A remote snapshot already in the sweep advances its late-arriving sound")
	state = _state()
	state.players[1].melee.elapsed = .20
	sound.play_game_event(_cue(true))
	sound.update_game_audio(0.0, state)
	_check(sound.heard.is_empty(), "A local predicted swing never borrows elapsed time from an older server swing")
	state = _state()
	sound.play_game_event(_cue(true, .04))
	sound.update_game_audio(1.0/60.0, state)
	_check(sound.heard.size() == 1, "Maximum-speed attacks do not accumulate a normal-speed audio delay")
	state = _state()
	for id: int in range(100): sound.play_game_event(_cue(true, .36, id))
	_check(sound._pending_melee.size() <= Sound.MAX_VOICES, "Queued cosmetic audio remains bounded during event bursts")
	sound.shutdown()
	_check(sound._pending_melee.is_empty(), "Shutdown releases every pending cue")
	sound.queue_free()
	await process_frame
	print("MELEE_AUDIO_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)
