extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Pose = preload("res://scripts/weapon_pose.gd")
const Soundscape = preload("res://scripts/soundscape.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0
var _main_completed: bool = false

class AudioProbe extends Soundscape:
	var heard: Array = []
	func play_game_event(event: Dictionary, distance: float = 0.0) -> bool:
		heard.append({"event": event.duplicate(true), "distance": distance})
		return true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_strike_timing()
	_test_locked_aim_and_cadence()
	_test_cancellation()
	_test_snapshot_and_prediction()
	await _test_main_feedback()
	_check(_main_completed, "The entire real-main integration fixture completed without an early script failure")
	print("MELEE_INTEGRATION_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh(count: int = 1):
	var sim = Simulation.new()
	var roster: Array = []
	for id in range(1, count + 1):
		roster.append({"id": id, "name": "Blade %d" % id, "character": "vanguard"})
	sim.start_run(roster, 1515)
	sim.state.world_size = Vector2(1800.0, 1100.0)
	sim.state.floor_y = 1000.0
	sim.state.platforms = [Rect2(0.0, 1000.0, 1800.0, 60.0)]
	sim.state.chests = []
	sim._spawn_clock = 9999.0
	sim.events.clear()
	for player: Dictionary in sim.state.players.values():
		player.pos = Vector2(500.0 + int(player.id) * 300.0, 979.0)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.invuln = 9999.0
		player.aim = Vector2.RIGHT
		player.explore_anchor = player.pos
	return sim

func _dummy(sim, offset: Vector2) -> Dictionary:
	var enemy: Dictionary = sim._spawn_enemy("crawler", Vector2(sim.state.players[1].pos) + offset)
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	enemy.stun_timer = 9999.0
	return enemy

func _swings(events: Array) -> Array:
	return events.filter(func(event: Dictionary): return event.get("type") == "slash" and event.get("weapon") == "arc_blade")

func _hits(events: Array, owner: int = 1) -> Array:
	return events.filter(func(event: Dictionary): return event.get("type") == "hit" and int(event.get("owner", -1)) == owner and float(event.get("amount", 0.0)) > 0.0)

func _finish(sim, ticks: int = 45) -> Array:
	var result: Array = []
	for tick in range(ticks):
		sim.step(DT, {})
		result.append_array(sim.events.duplicate(true))
	return result

func _test_strike_timing() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.hp = 70.0
	var enemy: Dictionary = _dummy(sim, Vector2(70.0, 0.0))
	sim.step(DT, {1: {"fire": true}})
	var start: Array = _swings(sim.events)
	_check(start.size() == 1 and start[0].get("phase") == "start" and start[0].has("duration") and start[0].has("attack_id"), "Real fire input produces exactly one identifiable swing-start event")
	_check(enemy.hp == 10000.0 and _hits(sim.events).is_empty() and not Dictionary(player.get("melee", {})).is_empty(), "The windup poses before dealing damage instead of retaining the former instant hit")
	_check(player.hp == 70.0, "Melee life recovery also waits for the actual strike")
	var after: Array = _finish(sim)
	var hits: Array = _hits(after)
	_check(hits.size() == 1 and float(hits[0].amount) in [24.0, 48.0], "One full swing damages a nearby enemy once, including the existing critical-roll rule")
	_check(is_equal_approx(float(player.hp), 70.35), "One successful target restores exactly the existing 0.35 life")
	_check(_swings(after).is_empty(), "The impact and recovery phases do not emit a second swing or sound event")
	var multiple = _fresh()
	var first: Dictionary = _dummy(multiple, Vector2(65.0, 0.0))
	var second: Dictionary = _dummy(multiple, Vector2(95.0, 0.0))
	multiple.step(DT, {1: {"fire": true}})
	var all_events: Array = _finish(multiple)
	_check(_hits(all_events).size() == 2 and first.hp < 10000.0 and second.hp < 10000.0, "The blade keeps its cleave while hitting each of two targets only once")

func _test_locked_aim_and_cadence() -> void:
	var sim = _fresh()
	var front: Dictionary = _dummy(sim, Vector2(80.0, 0.0))
	var behind: Dictionary = _dummy(sim, Vector2(-80.0, 0.0))
	sim.step(DT, {1: {"fire": true, "aim": Vector2.RIGHT}})
	for tick in range(45):
		sim.step(DT, {1: {"aim": Vector2.LEFT}})
	_check(front.hp < 10000.0 and behind.hp == 10000.0, "Turning the cursor during the windup cannot redirect a committed strike behind the wielder")
	for haste: int in [0, 100]:
		var repeat = _fresh()
		var player: Dictionary = repeat.state.players[1]
		player.items.overclock = haste
		player.chrono_timer = 5.0 if haste > 0 else 0.0
		_dummy(repeat, Vector2(70.0, 0.0))
		var starts: Array = []
		var strikes: Array = []
		for tick in range(90):
			repeat.step(DT, {1: {"fire": true}})
			starts.append_array(_swings(repeat.events))
			strikes.append_array(_hits(repeat.events))
		strikes.append_array(_hits(_finish(repeat)))
		var ids: Dictionary = {}
		for event: Dictionary in starts:
			ids[event.get("attack_id", -1)] = true
		_check(starts.size() > 1 and strikes.size() == starts.size() and ids.size() == starts.size(), "Held fire with %d haste stacks produces one unique strike per accepted swing, without recovery overlap" % haste)

func _test_cancellation() -> void:
	var swapped = _fresh()
	var player: Dictionary = swapped.state.players[1]
	var enemy: Dictionary = _dummy(swapped, Vector2(70.0, 0.0))
	var pickup: Dictionary = swapped._spawn_pickup(player.pos, "item", "pulse_rifle", 1)
	swapped.step(DT, {1: {"fire": true, "interact": true, "interact_target": {"kind": "pickup", "id": pickup.id}}})
	var cooldown: float = player.fire_cd
	var events: Array = _finish(swapped)
	_check(player.weapon == "pulse_rifle" and Dictionary(player.get("melee", {})).is_empty() and enemy.hp == 10000.0 and _hits(events).is_empty(), "An actual E weapon swap during windup cancels the pending hit")
	_check(cooldown >= Simulation.loot_definition("arc_blade").fire_interval - DT, "Cancelling by weapon swap does not reset the existing attack cooldown")
	var equipped = _fresh()
	var active_pickup: Dictionary = equipped._spawn_pickup(equipped.state.players[1].pos, "item", "aegis", 1)
	var survivor: Dictionary = _dummy(equipped, Vector2(70.0, 0.0))
	equipped.step(DT, {1: {"fire": true, "interact": true, "interact_target": {"kind": "pickup", "id": active_pickup.id}}})
	_finish(equipped)
	_check(equipped.state.players[1].equipment == "aegis" and survivor.hp < 10000.0, "Changing only active equipment does not cancel a main-weapon swing")
	var dead = _fresh(2)
	var victim: Dictionary = _dummy(dead, Vector2(70.0, 0.0))
	dead.step(DT, {1: {"fire": true}})
	dead.state.players[1].invuln = 0.0
	dead._damage_player(dead.state.players[1], 100000.0, Vector2.ZERO)
	_finish(dead)
	_check(dead.state.players[1].dead and Dictionary(dead.state.players[1].get("melee", {})).is_empty() and victim.hp == 10000.0, "A killed player cannot finish a pending slash while a teammate keeps the run alive")
	var stage = _fresh()
	stage.step(DT, {1: {"fire": true}})
	stage._build_stage(2)
	var new_enemy: Dictionary = _dummy(stage, Vector2(65.0, 0.0))
	_finish(stage)
	_check(Dictionary(stage.state.players[1].get("melee", {})).is_empty() and new_enemy.hp == 10000.0, "A stage transition cannot carry pending melee damage into the next map")
	var echo = _fresh()
	echo.state.players[1].items.echo = 1
	echo.state.players[1].attack_count = 5
	var distant: Dictionary = _dummy(echo, Vector2(450.0, 0.0))
	echo.step(DT, {1: {"fire": true}})
	_check(distant.hp == 10000.0, "The sixth-swing echo waits for the real impact rather than leaking damage during windup")
	var rifle: Dictionary = echo._spawn_pickup(echo.state.players[1].pos, "item", "pulse_rifle", 1)
	echo._take_loot(echo.state.players[1], rifle)
	_finish(echo)
	_check(distant.hp == 10000.0, "Cancelling the sixth slash cancels its delayed echo proc too")

func _test_snapshot_and_prediction() -> void:
	var sim = _fresh()
	_dummy(sim, Vector2(70.0, 0.0))
	sim.step(DT, {1: {"fire": true, "aim": Vector2(1.0, -0.1).normalized()}})
	var snapshot: Dictionary = bytes_to_var(var_to_bytes(sim.get_snapshot()))
	var replica = Simulation.new()
	replica.apply_snapshot(snapshot)
	_check(replica.state.players[1].get("melee", {}) == sim.state.players[1].get("melee", {}) and not Dictionary(snapshot.players[1].get("melee", {})).is_empty(), "A pending melee action round-trips intact through a cooperative snapshot")
	var before_enemies: PackedByteArray = var_to_bytes(replica.state.enemies)
	for tick in range(30):
		replica.predict_player(replica.state.players[1], {"fire": true}, DT)
	_check(var_to_bytes(replica.state.enemies) == before_enemies and replica.events.is_empty(), "Client movement replay cannot apply or emit authority melee damage")
	snapshot.players[1].melee.aim = Vector2.DOWN
	_check(replica.state.players[1].melee.aim != Vector2.DOWN and sim.state.players[1].melee.aim != Vector2.DOWN, "Melee state copies do not alias the authority or local replica")
	var original_hits: Array = _hits(_finish(sim))
	_check(original_hits.size() == 1, "Serializing or replaying the pending swing cannot duplicate its authority hit")

func _test_main_feedback() -> void:
	var game = load("res://main.tscn").instantiate()
	var audio := AudioProbe.new()
	game.sound.free()
	game.sound = audio
	game._smoke = "melee-integration"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game._start_solo()
	game.sim = _fresh(2)
	game.local_id = 1
	game.online = true
	game.hosting = false
	var world = game.world
	var player: Dictionary = game.sim.state.players[1]
	world.set_frame(game.sim.get_snapshot(), 1, DT)
	audio.heard.clear()
	game._local_fire_timer = 0.0
	var before: PackedByteArray = var_to_bytes(game.sim.get_snapshot())
	game._predict_attack_feedback({"fire": true, "aim": Vector2.RIGHT}, DT)
	var initial: Dictionary = world.melee_pose(player)
	_check(bool(initial.get("active", false)) and bool(initial.get("predicted", false)) and audio.heard.size() == 1, "The real owning-client command starts a visible predicted swing and one sound immediately")
	_check(is_equal_approx(float(audio.heard[0].event.get("duration", -1.0)), Pose.melee_duration(Simulation.attack_interval(player))), "The blade-specific duration replaces generic ranged metadata in the predicted event")
	_check(before == var_to_bytes(game.sim.get_snapshot()), "Predicting the visible blade never changes authority melee, hit points or cooldowns")
	world._process(0.12)
	initial = world.melee_pose(player)
	_check(bool(initial.get("active", false)) and float(initial.get("elapsed", -1.0)) >= 0.119, "A predicted slash remains visible through its real swing phase instead of collapsing to a 40ms flash")
	var authority = Simulation.new()
	authority.apply_snapshot(game.sim.get_snapshot())
	authority._fire_weapon(authority.state.players[1])
	var packet: Array = authority.events.duplicate(true)
	game._receive_events(packet, 1, int(authority.state.seed))
	game._receive_events(packet, 1, int(authority.state.seed))
	game._process(0.0)
	var confirmed: Dictionary = world.melee_pose(player)
	_check(audio.heard.size() == 1 and bool(confirmed.get("active", false)) and is_equal_approx(float(confirmed.get("elapsed", -1.0)), float(initial.get("elapsed", -2.0))), "The authority event and a duplicate packet cannot restart or replay the local predicted swing")
	var snapshot: Dictionary = authority.get_snapshot()
	snapshot["_tick"] = 2
	snapshot["_ack"] = {}
	game._receive_snapshot(snapshot)
	world.set_frame(game.sim.get_snapshot(), 1, DT)
	_check(audio.heard.size() == 1 and bool(world.melee_pose(game.sim.state.players[1]).get("active", false)), "The following real snapshot acknowledgement keeps one local action without a second sound")
	authority.events.clear()
	authority._fire_weapon(authority.state.players[2])
	game._receive_events(authority.events, 3, int(authority.state.seed))
	game._process(0.0)
	var remote: Dictionary = world.melee_pose(game.sim.state.players[2])
	_check(bool(remote.get("active", false)) and not bool(remote.get("predicted", true)) and audio.heard.size() == 2, "The same client presents a teammate's authoritative swing exactly once")
	world._melee_tracks.clear()
	world.set_frame(authority.get_snapshot(), 1, DT)
	var reconstructed: Dictionary = world.melee_pose(authority.state.players[2])
	_check(bool(reconstructed.get("active", false)) and audio.heard.size() == 2, "A pending remote swing can be recovered from the snapshot even without its start-event presentation")
	world.combat_paused = true
	var paused_elapsed: float = float(world.melee_pose(authority.state.players[2]).get("elapsed", -1.0))
	world._process(0.15)
	_check(is_equal_approx(float(world.melee_pose(authority.state.players[2]).get("elapsed", -2.0)), paused_elapsed), "Solo-style combat pause cannot silently finish the visible slash")
	world.combat_paused = false
	var swapped: Dictionary = authority.get_snapshot()
	swapped.players[2].weapon = "pulse_rifle"
	swapped.players[2].melee = {}
	world.set_frame(swapped, 1, DT)
	_check(not bool(world.melee_pose(swapped.players[2]).get("active", false)), "A replicated weapon swap immediately removes the old teammate blade action")
	world.set_frame(authority.get_snapshot(), 1, DT)
	var killed: Dictionary = authority.get_snapshot()
	killed.players[2].dead = true
	killed.players[2].melee = {}
	world.set_frame(killed, 1, DT)
	_check(not bool(world.melee_pose(killed.players[2]).get("active", false)), "A replicated death cancels the visible swing even if its original duration has not elapsed")
	authority._build_stage(2)
	world.set_frame(authority.get_snapshot(), 1, DT)
	_check(not bool(world.melee_pose(authority.state.players[1]).get("active", false)) and not bool(world.melee_pose(authority.state.players[2]).get("active", false)), "Changing stages removes both predicted and remote melee presentation")
	game.sim.apply_snapshot(authority.get_snapshot())
	game._local_fire_timer = 0.0
	game._predict_attack_feedback({"fire": true, "aim": Vector2.RIGHT}, DT)
	var first_id: int = int(audio.heard.back().event.get("attack_id", -1))
	var authority_count: int = int(game.sim.state.players[1].attack_count)
	world._process(0.6)
	game._local_fire_timer = 0.0
	game._predict_attack_feedback({"fire": true, "aim": Vector2.RIGHT}, DT)
	var second_id: int = int(audio.heard.back().event.get("attack_id", -1))
	_check(second_id > first_id and int(game.sim.state.players[1].attack_count) == authority_count, "A delayed snapshot cannot reuse the same attack ID for two locally predicted swings")
	_check(bool(world.melee_pose(game.sim.state.players[1]).get("active", false)), "The second high-latency predicted swing remains visible without waiting for authority attack_count")
	game.online = false
	audio.shutdown()
	await create_timer(0.12).timeout
	game.queue_free()
	await process_frame
	_main_completed = true
