extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DT = 1.0 / 60.0
var passed = 0
var failed = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)


func _fresh(two_players: bool = false):
	var sim = Simulation.new()
	var roster = [{"id": 1, "name": "Test Ranger", "character": "ranger"}]
	if two_players:
		roster.append({"id": 2, "name": "Test Vanguard", "character": "vanguard"})
	sim.start_run(roster, 20261004)
	return sim


func _command(overrides: Dictionary = {}) -> Dictionary:
	var command = {
		"move": 0.0, "jump": false, "drop": false, "aim": Vector2.RIGHT,
		"fire": false, "skill": false, "dash": false, "interact": false
	}
	command.merge(overrides, true)
	return command


func _run() -> void:
	_test_roster_and_catalogs()
	_test_snapshot_isolation()
	_test_aim_and_projectiles()
	_test_prediction_matches_movement()
	_test_dynamic_world_edges()
	_test_seed_reproducibility()
	_test_chest_transaction()
	_test_coop_lifecycle()
	_test_revive()
	_test_drop_through_platform()
	_test_item_stacks()
	_test_continuous_projectile_hit()
	_test_gate_progression()
	_test_entity_limits()
	print("SIMULATION_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _test_roster_and_catalogs() -> void:
	var sim = _fresh(true)
	_check(sim.state.players.size() == 2, "A run preserves both peer identities")
	_check(sim.state.players[2].character == "vanguard", "Character selection survives run initialization")
	_check(sim.state.phase == "playing" and sim.state.stage == 1, "A run begins at stage one in playing phase")
	_check(sim.state.platforms.size() > 0, "A run has collision platforms")
	_check(Simulation.character_catalog().size() >= 2, "At least two playable characters are defined")
	var item_ids: Dictionary = {}
	for item in Simulation.item_catalog():
		item_ids[item.id] = true
	_check(item_ids.size() >= 6, "At least six uniquely identified stacking items are defined")


func _test_snapshot_isolation() -> void:
	var sim = _fresh()
	var original_hp = sim.state.players[1].hp
	var snapshot = sim.get_snapshot()
	snapshot.players[1].hp = 1.0
	snapshot.players[1].items["snapshot_probe"] = 999
	_check(sim.state.players[1].hp == original_hp, "Snapshot edits cannot change authoritative health")
	_check(not sim.state.players[1].items.has("snapshot_probe"), "Snapshots deep-copy nested inventories")
	var replica = _fresh()
	replica.apply_snapshot(snapshot)
	snapshot.players[1].hp = 0.0
	_check(replica.state.players[1].hp == 1.0, "Applying a snapshot also breaks external references")


func _test_aim_and_projectiles() -> void:
	var sim = _fresh()
	var diagonal = Vector2(3.0, -4.0)
	sim.step(DT, {1: _command({"aim": diagonal})})
	var actual_aim: Vector2 = sim.state.players[1].aim
	_check(actual_aim.is_equal_approx(diagonal.normalized()), "Aim direction is normalized in simulation")
	sim.step(DT, {1: _command({"aim": Vector2.ZERO})})
	_check(sim.state.players[1].aim.is_equal_approx(actual_aim), "Zero-length aim preserves the previous direction")
	sim.step(DT, {1: _command({"aim": Vector2.UP, "fire": true})})
	var aimed_up = false
	for projectile in sim.state.projectiles:
		if projectile.team == "player" and projectile.vel.normalized().dot(Vector2.UP) > 0.9:
			aimed_up = true
	_check(aimed_up, "A ranger can shoot upward independently of horizontal movement")


func _test_prediction_matches_movement() -> void:
	var sim = _fresh()
	for stage in range(1, 4):
		sim._build_stage(stage)
		var predicted: Dictionary = sim.state.players[1].duplicate(true)
		var largest_error = 0.0
		for tick in range(120):
			var command = _command({"move": 1.0 if tick < 80 else -1.0, "jump": tick == 30, "dash": tick == 60})
			sim.predict_player(predicted, command, DT)
			sim.step(DT, {1: command})
			largest_error = maxf(largest_error, predicted.pos.distance_to(sim.state.players[1].pos))
		_check(largest_error < 0.05, "Stage %d prediction matches authority through movement, jump and dash (error %.4f)" % [stage, largest_error])

func _test_dynamic_world_edges() -> void:
	var sim = _fresh()
	for stage in range(1, 4):
		sim._build_stage(stage)
		var player: Dictionary = sim.state.players[1]
		var world: Vector2 = sim.state.world_size
		player.pos = Vector2(world.x - 150.0, float(sim.state.floor_y) - Simulation.PLAYER_HALF.y)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.invuln = 9999.0
		var predicted: Dictionary = player.duplicate(true)
		for tick in range(90):
			var command = {"move": 1.0, "dash": tick == 0}
			sim.predict_player(predicted, command, DT)
			sim.step(DT, {1: command})
		_check(player.pos.x > world.x - 100.0 and player.pos.x <= world.x - Simulation.PLAYER_HALF.x and predicted.pos.distance_to(player.pos) < 0.05, "Stage %d authority and prediction use its actual right boundary beyond the old 3200px world" % stage)
		var pickup: Dictionary = sim._spawn_pickup(Vector2(world.x + 300.0, player.pos.y - 100.0), "item", "feather", 1)
		for tick in range(180):
			sim._step_pickups(DT)
		_check(Vector2(pickup.pos).x <= world.x and Vector2(pickup.pos).x > world.x - 100.0 and Vector2(pickup.pos).y < world.y, "Stage %d dropped loot is recovered inside the current map edge rather than the old world clamp" % stage)


func _test_seed_reproducibility() -> void:
	var first = _fresh(true)
	var second = _fresh(true)
	for tick in range(600):
		var commands = {
			1: _command({"move": sin(tick * 0.025), "fire": true, "jump": tick % 90 == 0}),
			2: _command({"move": -0.2, "fire": tick % 2 == 0, "skill": tick % 180 == 0})
		}
		first.step(DT, commands)
		second.step(DT, commands)
	_check(first.get_snapshot() == second.get_snapshot(), "Same initial seed and commands reproduce the authoritative simulation")


func _test_chest_transaction() -> void:
	var sim = _fresh()
	_check(sim.state.chests.size() > 0, "Stage contains purchasable chests")
	if sim.state.chests.is_empty():
		return
	var chest: Dictionary = sim.state.chests[0]
	var player: Dictionary = sim.state.players[1]
	player.pos = chest.pos
	player.coins = maxi(0, int(chest.cost) - 1)
	sim.step(DT, {1: _command({"interact": true})})
	_check(not chest.opened, "A chest rejects purchases with insufficient currency")
	for tick in range(15):
		sim.step(DT, {1: _command()})
	player.pos = chest.pos
	player.coins = int(chest.cost) + 100
	var coins_before = player.coins
	sim.step(DT, {1: _command({"interact": true})})
	_check(chest.opened, "An affordable chest opens when interacting nearby")
	_check(player.coins == coins_before - int(chest.cost), "Opening a chest charges exactly its displayed cost")
	var coins_after = player.coins
	for tick in range(15):
		sim.step(DT, {1: _command()})
	sim.step(DT, {1: _command({"interact": true})})
	_check(player.coins >= coins_after, "Repeated interaction with an open chest cannot charge twice")


func _test_coop_lifecycle() -> void:
	var sim = _fresh(true)
	sim.state.players[1].dead = true
	sim.state.players[1].hp = 0.0
	sim.step(DT, {2: _command()})
	_check(sim.state.phase == "playing", "One downed teammate does not end a cooperative run")
	sim.state.players[2].dead = true
	sim.state.players[2].hp = 0.0
	sim.step(DT, {})
	_check(sim.state.phase == "lost", "A full party wipe ends the run")
	var lobby = _fresh(true)
	lobby.remove_player(2)
	_check(lobby.state.players.size() == 1 and lobby.state.players.has(1), "Disconnect removes only the disconnected player")
	lobby.add_player(7, "Replacement", "vanguard")
	_check(lobby.state.players.has(7), "A newly connected peer receives its own player state")


func _test_revive() -> void:
	var sim = _fresh(true)
	var casualty: Dictionary = sim.state.players[1]
	var rescuer: Dictionary = sim.state.players[2]
	casualty.dead = true
	casualty.hp = 0.0
	rescuer.pos = casualty.pos + Vector2(35.0, 0.0)
	sim.step(DT, {2: _command({"interact": true})})
	_check(casualty.revive > 0.0, "A nearby teammate can start rescue with one interaction")
	for tick in range(112):
		sim.step(DT, {2: _command()})
	_check(not casualty.dead and casualty.hp > 0.0, "Rescue completes without repeating the interaction command")
	_check(casualty.hp <= casualty.max_hp and casualty.invuln > 0.0, "Rescue restores bounded health and temporary protection")


func _test_drop_through_platform() -> void:
	var sim = _fresh()
	var platform: Rect2 = sim.state.platforms[1]
	var player: Dictionary = sim.state.players[1]
	player.pos = Vector2(platform.get_center().x, platform.position.y - Simulation.PLAYER_HALF.y)
	player.vel = Vector2.ZERO
	player.grounded = true
	for tick in range(20):
		sim.step(DT, {1: _command({"drop": tick == 0})})
	_check(player.pos.y > platform.position.y + Simulation.PLAYER_HALF.y, "Drop input crosses a one-way platform instead of landing on it again")
	for tick in range(80):
		sim.step(DT, {1: _command()})
	_check(player.grounded and player.pos.y < sim.state.world_size.y, "The solid bottom floor catches a player after dropping")


func _test_item_stacks() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	var original_max = player.max_hp
	sim._grant_item(player, "vitality")
	sim._grant_item(player, "vitality")
	_check(player.items.vitality == 2 and player.max_hp == original_max + 50.0, "Repeated vitality items stack health exactly twice")
	_check(player.hp <= player.max_hp, "Item acquisition never heals above maximum health")
	sim._grant_item(player, "capacitor")
	sim._grant_item(player, "capacitor")
	_check(is_equal_approx(sim._damage_scale(player), 1.24), "Damage item stacks follow the displayed additive percentage rule")
	var coins_before = player.coins
	var items_before: Dictionary = player.items.duplicate(true)
	sim.predict_player(player.duplicate(true), _command({"fire": true, "skill": true, "interact": true}), DT)
	_check(sim.state.projectiles.is_empty() and player.coins == coins_before and player.items == items_before, "Movement prediction cannot spawn attacks or apply economy effects")


func _test_continuous_projectile_hit() -> void:
	var sim = _fresh()
	# Reverse the target order so an implementation which takes the first array entry fails.
	sim._spawn_enemy("crawler", Vector2(560.0, 500.0))
	sim._spawn_enemy("crawler", Vector2(410.0, 500.0))
	var farther: Dictionary = sim.state.enemies[0]
	var nearer: Dictionary = sim.state.enemies[1]
	farther.hp = 1000.0
	nearer.hp = 1000.0
	sim._spawn_projectile(Vector2(300.0, 500.0), Vector2(24000.0, 0.0), "player", "bullet", 10.0, 1, 1.0, 3.0)
	sim._step_projectiles(DT)
	_check(nearer.hp < 1000.0, "Fast projectiles hit enemies crossed between frames")
	_check(farther.hp == 1000.0, "A non-piercing projectile resolves the nearest collision, not array order")
	_check(sim.state.projectiles.is_empty(), "A consumed projectile cannot hit again on the next frame")


func _test_gate_progression() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim._grant_item(player, "capacitor")
	for stage in range(1, 4):
		var gate: Dictionary = sim.state.gate
		player.pos = gate.pos
		sim._interact(player, {"kind": "gate", "id": -1})
		_check(gate.active and sim.state.boss_alive, "Stage %d gate activation spawns its boss" % stage)
		player.pos = Vector2(100.0, 900.0)
		sim._step_gate(1.0)
		_check(gate.charge == 0.0, "Stage %d gate charging requires a nearby living player" % stage)
		player.pos = gate.pos
		for tick in range(1322):
			sim._step_gate(DT)
		_check(is_equal_approx(gate.charge, 1.0) and not gate.ready, "Stage %d full charge still requires defeating the boss" % stage)
		for enemy in sim.state.enemies:
			if enemy.kind == "boss":
				sim._damage_enemy(enemy, 1000000.0, 1, false, 0)
		sim._step_gate(DT)
		_check(gate.ready and not sim.state.boss_alive, "Stage %d gate unlocks after charge and boss defeat" % stage)
		sim._interact(player, {"kind": "gate", "id": -1})
		if stage < 3:
			_check(sim.state.stage == stage + 1 and player.items.capacitor == 1, "Stage transition advances the map while preserving the build")
	_check(sim.state.phase == "won", "Completing the third gate reaches the victory state")


func _test_entity_limits() -> void:
	var sim = _fresh()
	for index in range(Simulation.MAX_ENEMIES + 20):
		sim._spawn_enemy("crawler", Vector2(800.0, 900.0))
	_check(sim.state.enemies.size() <= Simulation.MAX_ENEMIES, "Ordinary enemy creation respects the entity budget")
	for index in range(Simulation.MAX_PROJECTILES + 20):
		sim._spawn_projectile(Vector2(700.0, 700.0), Vector2.RIGHT, "player", "bullet", 1.0, 1, 1.0, 2.0)
	_check(sim.state.projectiles.size() <= Simulation.MAX_PROJECTILES, "Projectile creation respects the entity budget")
	for index in range(Simulation.MAX_PICKUPS + 20):
		sim._spawn_pickup(Vector2(800.0, 900.0), "coin", "", 1)
	_check(sim.state.pickups.size() <= Simulation.MAX_PICKUPS, "Pickup creation respects the entity budget")
