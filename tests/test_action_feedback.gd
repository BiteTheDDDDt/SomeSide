extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_jump_and_landing()
	_test_false_triggers()
	_test_reset_and_prediction()
	_test_meteor()
	print("ACTION_FEEDBACK_TEST_RESULT passed=%d failed=%d" % [passed, failed])
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
		roster.append({"id": id, "name": "Feedback %d" % id, "character": "ranger"})
	sim.start_run(roster, 1511)
	sim.state.world_size = Vector2(1800.0, 1100.0)
	sim.state.floor_y = 1000.0
	sim.state.platforms = [Rect2(0.0, 1000.0, 1800.0, 60.0)]
	sim.state.chests = []
	sim._spawn_clock = 9999.0
	sim.events.clear()
	for player: Dictionary in sim.state.players.values():
		player.pos = Vector2(500.0 + int(player.id) * 50.0, 979.0)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.invuln = 9999.0
		player.explore_anchor = player.pos
	return sim

func _events(sim, type: String) -> Array:
	return sim.events.filter(func(event: Dictionary): return event.type == type)

func _test_jump_and_landing() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	var jumps: Array = _events(sim, "jump")
	_check(jumps.size() == 1 and jumps[0].player == 1 and not jumps[0].double and jumps[0].pos == player.pos and player.vel.y < 0.0, "An accepted ground jump emits one authority event at the actual moved position")
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	_check(_events(sim, "jump").is_empty(), "A rejected air jump emits no sound cue")
	player.items.feather = 1
	sim.step(DT, {1: {"jump": true, "jump_held": true}})
	jumps = _events(sim, "jump")
	_check(jumps.size() == 1 and jumps[0].double and player.jumps == 2, "A real feather jump emits the distinct double-jump cue")
	var landings: Array = []
	var extra_jumps: int = 0
	for tick in range(150):
		sim.step(DT, {1: {"jump_held": true}})
		landings.append_array(_events(sim, "land"))
		extra_jumps += _events(sim, "jump").size()
	_check(landings.size() == 1 and landings[0].player == 1 and float(landings[0].impact_speed) > 120.0 and landings[0].pos.y == 979.0, "The full flight produces one landing event with pre-collision impact speed")
	_check(extra_jumps == 0 and player.grounded, "Held jump and subsequent grounded frames do not replay jump or landing feedback")
	player.coyote = 0.08
	player.grounded = false
	player.pos.y -= 3.0
	sim.step(DT, {1: {"jump": true}})
	jumps = _events(sim, "jump")
	_check(jumps.size() == 1 and not jumps[0].double, "A coyote-time jump is classified as the first jump")

func _test_false_triggers() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	var initial_landings: int = 0
	player.grounded = false
	player.pos.y -= 130.0
	for tick in range(120):
		sim.step(DT, {})
		initial_landings += _events(sim, "land").size()
	_check(initial_landings == 0 and player.grounded and player.land_ready, "An initial spawn fall stays silent and establishes subsequent landing readiness")
	player.grounded = false
	player.pos.y -= 0.1
	player.vel.y = 10.0
	sim.step(DT, {})
	_check(_events(sim, "land").is_empty() and player.grounded, "A subpixel ground settle cannot emit a landing cue")
	sim.state.platforms.append(Rect2(400.0, 800.0, 500.0, 18.0))
	player.pos.y = 779.0
	player.vel = Vector2.ZERO
	sim.step(DT, {1: {"drop": true, "jump": true}})
	_check(_events(sim, "jump").is_empty() and player.vel.y > 0.0, "Dropping through a platform never emits a jump cue")
	var drop_landings: int = 0
	for tick in range(90):
		sim.step(DT, {})
		drop_landings += _events(sim, "land").size()
	_check(drop_landings == 1, "A real platform drop still emits its one eventual landing")
	sim.step(DT, {1: {"jump": true, "dash": true, "aim": Vector2.UP}})
	_check(_events(sim, "jump").is_empty() and _events(sim, "dash").size() == 1, "A simultaneous dash that replaces jump motion emits only the dash cue")

func _test_reset_and_prediction() -> void:
	var sim = _fresh(2)
	var player: Dictionary = sim.state.players[1]
	var replica = Simulation.new()
	replica.apply_snapshot(sim.get_snapshot())
	var predicted: Dictionary = replica.state.players[1]
	var matching: bool = true
	var authority_landings: int = 0
	for tick in range(130):
		var command: Dictionary = {"jump": tick == 0, "jump_held": tick < 4}
		replica.predict_player(predicted, command, DT)
		sim.step(DT, {1: command})
		for key in ["pos", "vel", "grounded", "land_ready"]:
			matching = matching and predicted[key] == player[key]
		authority_landings += _events(sim, "land").size()
	_check(matching and replica.events.is_empty() and authority_landings == 1, "Prediction follows the exact same short jump and landing state without emitting replayed audio")
	var snapshot: Dictionary = bytes_to_var(var_to_bytes(sim.get_snapshot()))
	_check(snapshot.players[1].land_ready == player.land_ready, "Landing readiness survives the existing cooperative snapshot serialization")
	player.dead = true
	player.revive_timer = DT
	sim.step(DT, {})
	_check(not player.dead and not player.land_ready and _events(sim, "land").is_empty(), "Revival clears the old life's landing feedback readiness")
	player.land_ready = true
	sim._build_stage(2)
	_check(not player.land_ready, "Stage transitions reset landing readiness")
	sim.step(DT, {})
	_check(_events(sim, "land").is_empty(), "Arrival in the next stage never creates a synthetic landing cue")
	var co_op = _fresh(2)
	co_op.step(DT, {1: {"jump": true}, 2: {"jump": true}})
	var ids: Array = []
	for event: Dictionary in _events(co_op, "jump"):
		ids.append(event.player)
	_check(ids == [1, 2], "Simultaneous cooperative jumps retain each authority player ID")

func _test_meteor() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.equipment = "meteor"
	sim.step(DT, {1: {"skill": true}})
	var equipment: Array = _events(sim, "equipment")
	_check(equipment.size() == 1 and equipment[0].equipment == "meteor" and equipment[0].player == 1 and sim.state.effects.size() == 3, "A successful meteor cast emits one equipment cue for three scheduled impacts")
	sim.step(DT, {1: {"skill": true}})
	_check(_events(sim, "equipment").is_empty(), "Holding meteor during cooldown cannot replay its cast cue")
	var saturated = _fresh()
	var caster: Dictionary = saturated.state.players[1]
	caster.equipment = "meteor"
	for index in range(8):
		saturated._use_skill(caster)
	saturated.events.clear()
	saturated._use_skill(caster)
	_check(saturated.state.effects.size() == 24 and _events(saturated, "equipment").is_empty(), "A fully saturated effects budget cannot claim a successful meteor cast")
	saturated.state.effects.pop_back()
	saturated._use_skill(caster)
	_check(saturated.state.effects.size() == 24 and _events(saturated, "equipment").size() == 1, "A partially available effects budget reports the one actual cast exactly once")
	var other_cues: int = 0
	for id: String in ["grenade", "shockwave", "repair_field", "aegis", "graviton", "turret", "time_warp"]:
		var other = _fresh()
		other.state.players[1].equipment = id
		other.step(DT, {1: {"skill": true}})
		other_cues += _events(other, "equipment").size()
	_check(other_cues == 0, "The other seven active items keep their existing event types without duplicate generic cues")
