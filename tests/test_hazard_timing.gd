extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Catalog = preload("res://scripts/enemy_catalog.gd")
const DT: float = 1.0 / 60.0
const TIMINGS: Dictionary = {
	"beam": 1.5, "prism_beam": 1.5, "prism_cross": 1.8,
	"stone_spikes": 1.6, "burrow": 1.5, "mortar": 1.4, "spore_bloom": 1.6,
}
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	for attack: String in TIMINGS:
		_timed_attack(attack)
	_test_unchanged_attacks()
	_test_variable_steps()
	_test_cancel_and_snapshot()
	print("HAZARD_TIMING_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS: ", label)
	else: failed += 1; push_error("FAIL: " + label)

func _fixture(attack: String, elapsed: float = 0.0) -> Dictionary:
	var sim = Simulation.new()
	sim.start_run([{"id": 1, "name": "Timing", "character": "ranger"}], 20203)
	var stage: int = 3 if attack in ["beam", "prism_beam", "prism_cross", "blink", "mend"] else (2 if attack in ["stone_spikes", "stone_charge", "burrow", "charge", "triple"] else 1)
	if stage != 1: sim._build_stage(stage)
	sim.state.enemies.clear(); sim.state.hazards.clear(); sim.state.chests.clear()
	sim.state.floor_y = 1000.0
	sim.state.platforms = [Rect2(0, 1000, sim.state.world_size.x, 100)]
	sim.state.time = elapsed
	sim._update_difficulty()
	sim._spawn_clock = 9999.0
	var player: Dictionary = sim.state.players[1]
	player.pos = Vector2(1000, 979); player.vel = Vector2.ZERO; player.grounded = true
	player.invuln = 0.0; player.hp = 10000.0; player.max_hp = 10000.0
	sim._reset_exploration(player, true)
	var kind: String = {"beam": "sentinel", "burrow": "burrower", "mortar": "spore_moth", "charge": "charger", "pounce": "crawler", "spit": "spitter", "triple": "drone", "blink": "skirmisher", "mend": "conductor"}.get(attack, "boss")
	var distance: float = 110.0 if attack in ["charge", "pounce"] else 350.0
	var enemy: Dictionary = sim._spawn_enemy(kind, Vector2(1000.0 - distance, 956.0 if kind == "boss" else 983.0))
	enemy.grounded = true; enemy.move_speed = 0.0; enemy.attack_cd = 0.0
	if attack in ["prism_cross", "stone_charge", "spore_bloom"]: enemy.attack_count = 1
	return {"sim": sim, "enemy": enemy, "player": player}

func _timed_attack(attack: String) -> void:
	var setup: Dictionary = _fixture(attack)
	var sim = setup.sim
	var expected: float = TIMINGS[attack]
	sim.step(DT, {})
	var enemy: Dictionary = setup.enemy
	var hazards: Array = sim.state.hazards.duplicate()
	var count: int = 3 if attack in ["prism_cross", "spore_bloom", "stone_spikes"] else 1
	_check(enemy.attack_kind == attack and hazards.size() == count and is_equal_approx(float(enemy.telegraph_max), expected), attack + ": real AI selects the dedicated authoritative duration and complete hazard set")
	var newborn: bool = float(setup.player.hp) == 10000.0
	for hazard: Dictionary in hazards:
		newborn = newborn and not hazard.active and is_equal_approx(float(hazard.delay), expected) and hazard.delay == enemy.telegraph
	_check(newborn, attack + ": creation tick exposes the complete harmless warning without consuming its first frame")
	var created_at: float = float(sim.state.time)
	var activation_time: float = -1.0
	var safe: bool = true
	var synchronized: bool = true
	for tick: int in range(int(ceil(expected / DT)) + 3):
		sim.step(DT, {})
		var elapsed: float = float(sim.state.time) - created_at
		var active: bool = bool(hazards[0].active)
		if elapsed < expected - 0.000001: safe = safe and not active and float(setup.player.hp) == 10000.0
		if not active:
			for hazard: Dictionary in hazards: synchronized = synchronized and is_equal_approx(float(hazard.delay), float(enemy.telegraph))
		if active:
			activation_time = elapsed
			break
	_check(safe and synchronized and activation_time >= expected - 0.000001 and activation_time <= expected + DT + 0.000001, attack + ": no early damage and attacker/hazard countdowns remain synchronized for the full duration")
	var impact_hp: float = float(setup.player.hp)
	for tick: int in range(35 if attack in ["beam","prism_beam","prism_cross"] else 16): sim.step(DT, {})
	_check(impact_hp < 10000.0 and float(setup.player.hp) == impact_hp and sim.state.hazards.is_empty(), attack + ": activation still damages the exposed player once and expires normally")
	var late: Dictionary = _fixture(attack, 3600.0)
	late.sim.step(DT, {})
	_check(float(late.sim.state.difficulty) > 20.0 and late.enemy.telegraph == enemy.telegraph_max and late.sim.state.hazards[0].delay == expected, attack + ": late-run difficulty never shortens the ready period")

func _test_unchanged_attacks() -> void:
	var unchanged: Dictionary = {"pounce": 0.65, "charge": 0.8, "stone_charge": 0.9, "spit": 0.75, "triple": 0.75, "spore_volley": 0.9, "blink": 0.7, "mend": 0.85}
	for attack: String in unchanged:
		var setup: Dictionary = _fixture(attack)
		setup.sim.step(DT, {})
		_check(setup.enemy.attack_kind == attack and is_equal_approx(float(setup.enemy.telegraph), float(unchanged[attack])) and setup.sim.state.hazards.is_empty(), attack + ": charge/projectile/support pattern keeps its previous windup and spawning behavior")
	for id: String in ["spore_moth", "burrower", "sentinel"]:
		var entry: Dictionary = Catalog.definition(id)
		_check(float(entry.windup) == float(TIMINGS[entry.attack_kind]), id + ": public enemy catalog agrees with the actual attack duration")

func _test_variable_steps() -> void:
	for dt: float in [0.05, 0.011]:
		var setup: Dictionary = _fixture("prism_cross")
		setup.sim.step(dt, {})
		var ready: bool = setup.sim.state.hazards[0].delay == 1.8
		var born: float = setup.sim.state.time
		var early: bool = false
		var elapsed: float = 0.0
		for tick: int in range(200):
			setup.sim.step(dt, {})
			elapsed = float(setup.sim.state.time) - born
			if elapsed < 1.8 - 0.000001 and float(setup.player.hp) < 10000.0: early = true
			if setup.sim.state.hazards[0].active: break
		_check(ready and not early and elapsed >= 1.8 - 0.000001 and elapsed <= 1.8 + dt + 0.000001, "Variable %.3fs authority steps preserve the entire 1.8-second reaction window" % dt)

func _test_cancel_and_snapshot() -> void:
	var setup: Dictionary = _fixture("mortar")
	setup.sim.step(DT, {})
	var replica = Simulation.new()
	replica.apply_snapshot(setup.sim.get_snapshot())
	_check(replica.state.hazards[0].delay == 1.4 and not replica.state.hazards[0].active, "A teammate's first replicated spore snapshot contains its complete ready interval")
	replica.state.hazards[0].delay = 0.0
	_check(setup.sim.state.hazards[0].delay == 1.4, "Client sampling cannot consume the host's spore warning")
	setup.enemy.hp = 0.0
	for tick: int in range(100): setup.sim.step(DT, {})
	_check(setup.sim.state.hazards.is_empty() and float(setup.player.hp) == 10000.0, "Owner death still cancels the longer warning without a late acid burst")
	var direct: Dictionary = _fixture("beam")
	direct.sim._begin_enemy_attack(direct.enemy, direct.player)
	direct.sim._step_hazards(0.1)
	_check(is_equal_approx(float(direct.sim.state.hazards[0].delay), 1.4), "Explicit hazard stepping remains usable outside the full frame orchestrator")
