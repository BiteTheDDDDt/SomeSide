extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
const SEED: int = 1517
var passed: int = 0
var failed: int = 0
var completed: bool = false
var game
var audio: AudioProbe

class AudioProbe extends Soundscape:
	var heard: Array[String] = []
	var routed: Array = []
	func play_game_event(event: Dictionary, distance: float = 0.0) -> bool:
		routed.append(event.duplicate(true))
		return super.play_game_event(event, distance)
	func _play_sound(key: String, _distance: float, _now: int) -> bool:
		if key.is_empty(): return false
		heard.append(key)
		return true

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _run() -> void:
	await _integration()
	_check(completed, "Every real-main stage ordering fixture completed without a script exception")
	print("EVENT_STAGES_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _integration() -> void:
	game = load("res://main.tscn").instantiate()
	audio = AudioProbe.new()
	game.sound.free()
	game.sound = audio
	game._smoke = "event-stages"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	audio.enabled = true
	audio.wait_for_gesture = false
	_test_snapshot_first()
	_test_events_first()
	_test_mixed_packet_and_direct_delivery()
	_test_legacy_and_packet_guards()
	_test_budget_and_lifecycle()
	game.online = false
	audio.shutdown()
	await create_timer(0.12).timeout
	game.queue_free()
	await process_frame
	completed = true

func _fixture():
	game._begin_local([
		{"id": 1, "name": "Local", "character": "vanguard"},
		{"id": 2, "name": "Remote", "character": "vanguard"}
	], SEED)
	game.local_id = 1
	game.online = true
	game.hosting = false
	game._process(0.0)
	audio.heard.clear()
	audio.routed.clear()
	game._notify("baseline")
	var authority = Simulation.new()
	authority.apply_snapshot(game.sim.get_snapshot())
	return authority

func _snapshot(authority, tick: int) -> Dictionary:
	var value: Dictionary = authority.get_snapshot()
	value["_tick"] = tick
	value["_ack"] = {}
	return value

func _attack_and_notice(authority, message: String) -> Array:
	authority.events.clear()
	authority._fire_weapon(authority.state.players[2])
	authority._notice(authority.state.players[1], message)
	return authority.events.duplicate(true)

func _feedback(type: String, stage: int, extra: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {"type": type, "stage": stage, "player": 1, "pos": game.sim.state.players[1].pos}
	event.merge(extra, true)
	return event

func _balances() -> Array:
	var values: Array = []
	for player: Dictionary in game.sim.state.players.values():
		values.append([player.coins, player.hp])
	return values

func _test_snapshot_first() -> void:
	var authority = _fixture()
	var old: Array = _attack_and_notice(authority, "old-stage notice")
	_check(old.size() == 2 and old.all(func(event: Dictionary): return int(event.get("stage", -1)) == 1), "Actual authority slash and notice events retain their originating stage")
	authority._build_stage(2)
	_check(int(authority.events.back().get("stage", -1)) == 2, "The transition event is marked with the new stage in the same event buffer")
	game._receive_snapshot(_snapshot(authority, 10))
	var balances: Array = _balances()
	# Reproduce channel 2 overtaking an old reliable channel 3 event packet.
	game._receive_events(old, 9, SEED)
	_check(game._pending_stage_events.is_empty(), "A late old-stage packet is rejected even when its packet tick is otherwise new")
	game._process(0.0)
	_check(game.world._render_stage == 2 and game.world._melee_tracks.is_empty(), "Snapshot-first delivery cannot rebuild an old swing after the world changes stage")
	_check(audio.routed.is_empty() and audio._pending_melee.is_empty() and audio.heard.is_empty(), "No late old-stage action enters the sound dispatcher or delayed melee cue queue")
	_check(game._notice.text == "baseline" and balances == _balances(), "Old-stage feedback neither replaces the new-stage notice nor changes replicated life or currency")

func _test_events_first() -> void:
	var authority = _fixture()
	authority._build_stage(2)
	var future: Array = _attack_and_notice(authority, "future-stage notice")
	game._receive_events(future, 20, SEED)
	var frozen: PackedByteArray = var_to_bytes(game._pending_stage_events)
	future[1].message = "mutated transport buffer"
	future[1].message_key = "mutated transport buffer"
	_check(var_to_bytes(game._pending_stage_events) == frozen, "Queued feedback owns a deep copy rather than aliasing a reused transport buffer")
	game._process(0.0)
	_check(game._pending_stage_events.size() == 2 and game.world._render_stage == 1, "Future-stage actions and notices wait for the matching snapshot")
	_check(audio.routed.is_empty() and game._notice.text == "baseline", "Waiting future feedback creates no old-map sound or premature notice")
	game._receive_snapshot(_snapshot(authority, 21))
	_check(game.world._render_stage == 1 and audio.routed.is_empty(), "Receiving a snapshot alone does not flush presentation before the world's stage reset")
	game._process(0.0)
	_check(game.world._render_stage == 2 and game._pending_stage_events.is_empty(), "The normal process boundary resets the world before consuming matching queued feedback")
	_check(game.world._melee_tracks.has(2) and bool(game.world.melee_pose(game.sim.state.players[2]).get("active", false)), "A new-stage remote action survives the visual reset and has an active pose")
	_check(game._notice.text == "future-stage notice" and audio._pending_melee.size() == 1, "Deferred notices and the actual sound windup queue are both delivered in the correct stage")
	audio.update_game_audio(Pose.melee_swing_time(0.36), game.sim.state)
	_check(audio.heard.count("weapon_arc_blade") == 1, "The deferred swing produces one real scheduled sweep sound")
	var routed: int = audio.routed.size()
	game._process(0.0)
	game._receive_events(future, 20, SEED)
	game._process(0.0)
	_check(audio.routed.size() == routed and audio.heard.count("weapon_arc_blade") == 1, "Further frames and a duplicate reliable packet do not replay the flushed action")

func _test_mixed_packet_and_direct_delivery() -> void:
	var authority = _fixture()
	var old: Array = _attack_and_notice(authority, "stale mixed notice")
	authority._build_stage(2)
	var current: Array = _attack_and_notice(authority, "current mixed notice")
	var next: Dictionary = _feedback("notice", 3, {"message_key": "third-stage notice"})
	game._receive_snapshot(_snapshot(authority, 30))
	game._receive_events(old + current + [next], 29, SEED)
	game._process(0.0)
	_check(audio.routed.size() == 3 and game._notice.text == "current mixed notice", "One packet containing old, current and future stages presents only current-stage feedback")
	# The third routed event is the main UI's semantic ui_error notice sound.
	_check(game._pending_stage_events.size() == 1 and game._pending_stage_events[0].stage == 3, "A mixed-stage packet preserves its future notice instead of discarding the whole packet")
	authority._build_stage(3)
	game._receive_snapshot(_snapshot(authority, 31))
	game._process(0.0)
	_check(game._pending_stage_events.is_empty() and game._notice.text == "third-stage notice", "The remaining future notice is delivered exactly when its own stage becomes current")
	_check(audio._pending_melee.is_empty() and game.world._melee_tracks.is_empty(), "A later stage clears an earlier stage's unfinished sound and visual actions")
	for host_mode: bool in [false, true]:
		authority = _fixture()
		old = _attack_and_notice(authority, "stale direct notice")
		authority._build_stage(2)
		game.sim.apply_snapshot(authority.get_snapshot())
		game.online = host_mode
		game.hosting = host_mode
		game._consume_events(old + [_feedback("notice", 2, {"message_key": "valid direct notice"})])
		_check(audio._pending_melee.is_empty() and game._notice.text == "valid direct notice" and audio.routed.all(func(event: Dictionary): return not event.has("weapon")), "The %s direct-consume path also filters old actions accumulated before a same-tick transition" % ("host" if host_mode else "solo"))

func _test_legacy_and_packet_guards() -> void:
	var authority = _fixture()
	var legacy: Dictionary = _feedback("notice", 1, {"message_key": "legacy notice"})
	legacy.erase("stage")
	game._receive_events([legacy], 1, SEED)
	_check(game._pending_stage_events.size() == 1 and game._pending_stage_events[0].stage == 1, "An untagged compatibility event is assigned the stage at reception")
	authority._build_stage(2)
	game._receive_snapshot(_snapshot(authority, 2))
	game._process(0.0)
	_check(game._pending_stage_events.is_empty() and game._notice.text == "baseline", "An untagged event cannot acquire a different stage merely because its flush was delayed")
	game._receive_events([_feedback("notice", 2)], 3, SEED + 1)
	_check(game._pending_stage_events.is_empty() and game._last_event_tick == 1, "A different run seed cannot enqueue feedback or advance the valid packet watermark")
	game._receive_events([_feedback("notice", 2, {"message_key": "one delivery"})], 3, SEED)
	game._receive_events([_feedback("notice", 2)], 3, SEED)
	game._receive_events([_feedback("notice", 2)], 2, SEED)
	_check(game._pending_stage_events.size() == 1, "Repeated and out-of-order packet ticks still preserve exactly-once delivery")
	game._process(0.0)
	_check(game._notice.text == "one delivery", "A valid current-stage notice still presents after the guards reject other packets")

func _test_budget_and_lifecycle() -> void:
	var authority = _fixture()
	var overload: Array = [_feedback("notice", 2, {"message_key": "budget notice"})]
	for index in range(game.MAX_PENDING_STAGE_EVENTS * 3):
		overload.append(_feedback("hit", 2, {"amount": 1.0, "owner": 2}))
	overload.append(_feedback("pickup", 2, {"kind": "coin", "automatic": true, "amount": 1000, "recipients": [1, 2]}))
	game._receive_events(overload, 40, SEED)
	_check(game._pending_stage_events.size() == game.MAX_PENDING_STAGE_EVENTS, "A long snapshot gap has a strict presentation queue bound")
	_check(game._pending_stage_events.any(func(event: Dictionary): return event.get("message_key", "") == "budget notice") and game._pending_stage_events.any(func(event: Dictionary): return event.get("type", "") == "pickup"), "Cosmetic overflow evicts hit effects before intentional notices and currency feedback")
	authority._build_stage(2)
	game._receive_snapshot(_snapshot(authority, 41))
	var before: Array = _balances()
	game._process(0.0)
	_check(game._pending_stage_events.is_empty() and game._notice.text == "budget notice", "The bounded backlog flushes once the matching stage arrives")
	_check(before == _balances() and audio.heard.count("coin") == 1, "Queued currency and damage events are presentation only; authority balances remain unchanged")
	game._receive_events([_feedback("notice", 3)], 42, SEED)
	game._begin_local([{"id": 1, "name": "Restart", "character": "vanguard"}], SEED)
	_check(game._pending_stage_events.is_empty(), "Restarting even with the same seed clears presentation queued for the previous run")
	game._receive_events([_feedback("notice", 2)], 1, SEED)
	game._disconnect()
	_check(game._pending_stage_events.is_empty(), "Disconnecting clears all pending future-stage feedback")
