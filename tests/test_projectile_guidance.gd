extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Guidance = preload("res://scripts/projectile_guidance.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_acquisition()
	_test_turn_limits()
	_test_real_storm()
	_test_target_lifecycle()
	_test_conductor()
	_test_serialization_and_bounds()
	print("PROJECTILE_GUIDANCE_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)

func _fresh(count: int = 1):
	var sim = Simulation.new()
	var roster: Array = []
	for id: int in range(1, count + 1): roster.append({"id": id, "name": "Guide", "character": "ranger"})
	sim.start_run(roster, 190019)
	sim.state.platforms = [Rect2(0, 1021, 7200, 100)]
	sim.state.floor_y = 1021.0
	sim.state.chests.clear()
	sim._spawn_clock = 9999.0
	for player: Dictionary in sim.state.players.values():
		player.pos = Vector2(1000, 1000)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.invuln = 0.0
		player.weapon = "storm_staff"
	return sim

func _dummy(sim, offset: Vector2) -> Dictionary:
	var enemy: Dictionary = sim._spawn_enemy("crawler", Vector2(sim.state.players[1].pos) + offset)
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	enemy.attack_cd = 9999.0
	return enemy

func _test_acquisition() -> void:
	var origin := Vector2(1000, 500)
	for index: int in range(8):
		var direction: Vector2 = Vector2.from_angle(index * PI / 4.0)
		var target: Dictionary = {"id": 1, "hp": 10.0, "pos": origin + direction.rotated(deg_to_rad(15.0)) * 300.0}
		var outside: Dictionary = {"id": 2, "hp": 10.0, "pos": origin + direction.rotated(deg_to_rad(21.0)) * 100.0}
		var dead: Dictionary = {"id": 3, "hp": 0.0, "pos": origin + direction * 90.0}
		var locked: Dictionary = Guidance.lock(origin, direction * 780.0, [outside, dead, target], Guidance.STORM)
		_check(int(locked.get("target_id", -1)) == 1, "Launch cone works in direction %d and excludes nearer off-angle/dead targets" % index)
	_check(Guidance.lock(origin, Vector2.RIGHT * 780, [{"id": 1, "hp": 1, "pos": origin + Vector2(521, 0)}], Guidance.STORM).is_empty(), "Storm never acquires beyond 520 units")
	_check(Guidance.lock(origin, Vector2.ZERO, [{"id": 1, "pos": origin}], Guidance.STORM).is_empty(), "A stationary projectile cannot acquire a target")

func _test_turn_limits() -> void:
	for preset: Dictionary in [Guidance.STORM, Guidance.CONDUCTOR]:
		var target: Dictionary = {"id": 1, "hp": 10.0, "pos": Vector2(300, 30)}
		var shot: Dictionary = {"pos": Vector2.ZERO, "vel": Vector2.RIGHT * 210.0, "guidance": Guidance.lock(Vector2.ZERO, Vector2.RIGHT, [target], preset)}
		var total: float = 0.0
		var bounded: bool = true
		for tick: int in range(120):
			# Alternating evasion exercises a cumulative, not merely net, turn cap.
			target.pos = Vector2(300, 100.0 if tick % 20 < 10 else -100.0)
			var before: Vector2 = shot.vel
			shot.vel = Guidance.steer(shot, target, DT)
			var turn: float = absf(before.angle_to(shot.vel))
			total += turn
			bounded = bounded and turn <= deg_to_rad(float(preset.rate)) * DT + 0.00001 and is_equal_approx(Vector2(shot.vel).length(), 210.0)
		_check(bounded, "Guidance bounds instantaneous turn rate and preserves bullet speed")
		_check(total <= deg_to_rad(float(preset.turn)) + 0.00001 and not bool(shot.guidance.active), "Zigzag targets cannot exceed the cumulative turn/lifetime budget")
	var target: Dictionary = {"id": 1, "hp": 10.0, "pos": Vector2(300, 60)}
	var shot: Dictionary = {"pos": Vector2.ZERO, "vel": Vector2.RIGHT * 210, "guidance": Guidance.lock(Vector2.ZERO, Vector2.RIGHT, [target], Guidance.CONDUCTOR)}
	for tick: int in range(13): shot.vel = Guidance.steer(shot, target, DT)
	_check(shot.vel == Vector2.RIGHT * 210, "Hostile guidance gives 0.22 seconds of straight flight after its windup")
	shot.vel = Guidance.steer(shot, target, DT)
	_check(Vector2(shot.vel).y > 0.0, "Hostile energy begins a gradual turn after its grace period")
	target.pos = Vector2(-40, 40)
	var previous: Vector2 = shot.vel
	shot.vel = Guidance.steer(shot, target, DT)
	_check(shot.vel == previous and not bool(shot.guidance.active), "Passing the target permanently disables steering without a U-turn")
	target.pos = Vector2(200, 0)
	shot.vel = Guidance.steer(shot, target, DT)
	_check(shot.vel == previous, "A missed projectile does not re-enable guidance if the target comes back")

func _test_real_storm() -> void:
	var guided = _fresh()
	var enemy: Dictionary = _dummy(guided, Vector2(350, 85))
	var player: Dictionary = guided.state.players[1]
	player.aim = Vector2.RIGHT
	guided._fire_weapon(player)
	var shot: Dictionary = guided.state.projectiles[0]
	_check(shot.pos == WeaponPose.muzzle_position(player) and shot.origin == shot.pos, "Real storm projectile still starts at its physical weapon muzzle")
	_check(guided.events.back().type == "shoot" and guided.events.back().pos == shot.pos and shot.has("sweep_origin"), "Shoot event and continuous barrel sweep keep the original muzzle contract")
	_check(shot.damage == 32.0 and shot.ttl == 1.25 and is_equal_approx(player.fire_cd, 0.48), "Storm damage, attack interval and lifetime are unchanged")
	var straight = _fresh()
	straight.apply_snapshot(guided.get_snapshot())
	straight.state.projectiles[0].erase("guidance")
	for tick: int in range(70):
		guided._step_projectiles(DT)
		straight._step_projectiles(DT)
	var direct_hits: Array = guided.events.filter(func(e: Dictionary) -> bool: return e.type == "hit" and not e.has("arc_from"))
	_check(direct_hits.size() == 1 and float(direct_hits[0].amount) == (64.0 if bool(direct_hits[0].crit) else 32.0) and float(enemy.hp) == 10000.0 - float(direct_hits[0].amount), "Actual curved storm flight hits a modestly off-axis target once, preserving the ordinary critical roll")
	_check(float(straight.state.enemies[0].hp) == 10000.0, "The same initial straight trajectory misses that target")
	_check(guided.state.projectiles.is_empty(), "A guided hit uses normal projectile removal")
	var close = _fresh()
	var near: Dictionary = _dummy(close, Vector2(24, -5))
	close._fire_weapon(close.state.players[1])
	close._step_projectiles(DT)
	_check(float(near.hp) in [9968.0, 9936.0], "Point-blank enemies behind the muzzle remain hittable by the launch sweep")
	var fast = _fresh()
	var middle: Dictionary = _dummy(fast, Vector2(100, -5))
	fast._fire_weapon(fast.state.players[1])
	fast.state.projectiles[0].vel = Vector2(10000, 0)
	fast._step_projectiles(0.05)
	_check(float(middle.hp) in [9968.0, 9936.0], "Guided projectiles retain continuous collision when crossing an enemy in one frame")
	var chain = _fresh()
	var a: Dictionary = _dummy(chain, Vector2(140, -5))
	var b: Dictionary = _dummy(chain, Vector2(220, 55))
	var c: Dictionary = _dummy(chain, Vector2(290, 95))
	chain._fire_weapon(chain.state.players[1])
	for tick: int in range(20): chain._step_projectiles(DT)
	_check(float(a.hp) in [9968.0, 9936.0] and b.hp == 9980.0 and c.hp == 9980.0, "Storm still hits once and chains to exactly two neighbors with original damage")

func _test_target_lifecycle() -> void:
	for remove: bool in [false, true]:
		var sim = _fresh()
		var target: Dictionary = _dummy(sim, Vector2(350, 85))
		_dummy(sim, Vector2(440, 100))
		sim._fire_weapon(sim.state.players[1])
		var shot: Dictionary = sim.state.projectiles[0]
		if remove: sim.state.enemies.erase(target)
		else: target.hp = 0.0
		sim._step_projectiles(DT)
		_check(not bool(shot.guidance.active) and shot.vel == Vector2.RIGHT * 780, "Lost target (%s) safely ends steering instead of selecting a replacement" % str(remove))
	var sim = _fresh()
	var target: Dictionary = _dummy(sim, Vector2(350, 85))
	sim._fire_weapon(sim.state.players[1])
	var shot: Dictionary = sim.state.projectiles[0]
	target.pos += Vector2(1000, 0)
	sim._step_projectiles(DT)
	_check(not bool(shot.guidance.active), "A teleported target outside the tracking range is released")
	for weapon: String in ["pulse_rifle", "scattergun", "railgun", "boomerang", "sun_lance"]:
		var ordinary = _fresh()
		_dummy(ordinary, Vector2(350, 30))
		ordinary.state.players[1].weapon = weapon
		ordinary._fire_weapon(ordinary.state.players[1])
		var unchanged: bool = true
		for projectile: Dictionary in ordinary.state.projectiles: unchanged = unchanged and not projectile.has("guidance")
		_check(unchanged, "%s does not gain unrequested aim assistance" % weapon)

func _conductor_fixture():
	var sim = _fresh()
	var enemy: Dictionary = sim._spawn_enemy("conductor", Vector2(600, 1000))
	enemy.attack_cd = 0.0
	enemy.vel = Vector2.ZERO
	sim._begin_enemy_attack(enemy, sim.state.players[1])
	return sim

func _test_conductor() -> void:
	var sim = _conductor_fixture()
	for tick: int in range(50): sim._step_enemies(DT)
	_check(sim.state.projectiles.is_empty(), "Conductor retains the full 0.85 second pre-shot windup")
	for tick: int in range(2): sim._step_enemies(DT)
	_check(sim.state.projectiles.size() == 1 and sim.state.projectiles[0].has("guidance"), "The real conductor release creates exactly one locked energy projectile")
	var shot: Dictionary = sim.state.projectiles[0]
	_check(is_equal_approx(Vector2(shot.vel).length(), 210.0) and float(shot.damage) == 8.0, "The guided enemy projectile is slower than the former 230-speed shot and keeps 8 base damage")
	var copy = _fresh()
	copy.apply_snapshot(sim.get_snapshot())
	for tick: int in range(145):
		sim._step_projectiles(DT)
		copy._move_player(copy.state.players[1], {"move": 1.0}, DT)
		copy._step_projectiles(DT)
	_check(float(sim.state.players[1].hp) == 92.0, "An undodged guided enemy projectile applies one ordinary damage hit")
	_check(float(copy.state.players[1].hp) == 100.0, "Ordinary movement can evade this slower finite-guidance shot")
	var jump = _conductor_fixture()
	for tick: int in range(52): jump._step_enemies(DT)
	for tick: int in range(160):
		jump._move_player(jump.state.players[1], {"jump": tick == 80, "jump_held": true}, DT)
		jump._step_projectiles(DT)
	_check(float(jump.state.players[1].hp) == 100.0, "A timed base jump dodges the enemy shot after guidance has expired")
	var coop = _fresh(2)
	coop.state.players[2].pos = Vector2(1020, 1080)
	var shooter: Dictionary = coop._spawn_enemy("conductor", Vector2(600, 1000))
	coop._enemy_shoot(shooter, Vector2.RIGHT, 210.0, 8.0, "energy")
	var coop_shot: Dictionary = coop.state.projectiles[0]
	coop.state.players[1].dead = true
	coop._step_projectiles(0.3)
	_check(not bool(coop_shot.guidance.active) and coop_shot.vel == Vector2.RIGHT * 210, "A dead player releases enemy guidance without transferring lock to the teammate")
	var beam = _fresh()
	var sentinel: Dictionary = beam._spawn_enemy("sentinel", Vector2(600, 1004))
	sentinel.grounded = true
	beam._begin_enemy_attack(sentinel, beam.state.players[1])
	var before: PackedByteArray = var_to_bytes(beam.state.hazards[0])
	beam.state.players[1].pos += Vector2(0, -150)
	beam._step_enemies(DT)
	_check(var_to_bytes(beam.state.hazards[0]) == before, "Locked beam geometry never follows the player's dodge")
	for kind: String in ["spit", "crystal", "pulse", "boss_spore_orb"]:
		beam._enemy_shoot(sentinel, Vector2.RIGHT, 235.0, 7.0, kind)
		_check(not beam.state.projectiles.back().has("guidance"), "%s remains an ordinary straight hostile projectile" % kind)

func _test_serialization_and_bounds() -> void:
	var sim = _fresh(4)
	_dummy(sim, Vector2(350, 85))
	sim._fire_weapon(sim.state.players[1])
	var snapshot: Dictionary = sim.get_snapshot()
	var encoded: PackedByteArray = var_to_bytes(snapshot)
	var client = _fresh()
	client.apply_snapshot(bytes_to_var(encoded))
	var predicted: Dictionary = client.state.players[1]
	client.predict_player(predicted, {"fire": true, "move": 1.0}, DT)
	_check(var_to_bytes(client.state.projectiles) == var_to_bytes(snapshot.projectiles) and client.state.enemies[0].hp == 10000.0, "Local movement prediction cannot steer bullets or damage authority targets")
	client.apply_snapshot(snapshot)
	for tick: int in range(12):
		sim._step_projectiles(DT)
		client._step_projectiles(DT)
	_check(var_to_bytes(sim.state.projectiles) == var_to_bytes(client.state.projectiles), "Serialized guidance state resumes the exact same trajectory")
	_check(var_to_bytes(snapshot) == encoded, "Guidance advancement never mutates retained snapshot copies")
	sim._build_stage(2)
	_check(sim.state.projectiles.is_empty(), "Stage changes clear all projectile locks")
	var stress = _fresh()
	for index: int in range(Simulation.MAX_ENEMIES): _dummy(stress, Vector2(400 + index, 90))
	for index: int in range(Simulation.MAX_PROJECTILES + 15): stress._fire_weapon(stress.state.players[1])
	_check(stress.state.projectiles.size() == Simulation.MAX_PROJECTILES and stress.events.size() <= 64, "Guided fire respects the existing projectile and event budgets")
	var base = _fresh()
	base.apply_snapshot(stress.get_snapshot())
	for projectile: Dictionary in base.state.projectiles: projectile.erase("guidance")
	var begin: int = Time.get_ticks_usec()
	for tick: int in range(120): base._step_projectiles(1.0 / 6000.0)
	var baseline_us: int = Time.get_ticks_usec() - begin
	begin = Time.get_ticks_usec()
	for tick: int in range(120): stress._step_projectiles(1.0 / 6000.0)
	var guidance_us: int = Time.get_ticks_usec() - begin
	var valid: bool = true
	for projectile: Dictionary in stress.state.projectiles:
		valid = valid and Vector2(projectile.pos).is_finite() and Vector2(projectile.vel).is_finite() and is_equal_approx(Vector2(projectile.vel).length(), 780.0)
	_check(valid and stress.state.projectiles.size() == 280, "280 concurrent guided shots and 44 targets keep finite bounded state")
	print("GUIDANCE_STRESS baseline_us_per_step=", baseline_us / 120.0, " guidance_us_per_step=", guidance_us / 120.0, " serialized_bytes=", var_to_bytes(stress.state.projectiles).size())
	for tick: int in range(90): stress._step_projectiles(DT)
	_check(stress.state.projectiles.is_empty(), "Guidance cannot extend the normal projectile lifetime")
