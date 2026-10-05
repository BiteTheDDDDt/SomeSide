extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
const Locale = preload("res://scripts/localization.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_catalog()
	_movement()
	_collisions()
	_cancellation()
	_equipment()
	_prediction()
	print("CHARACTER_ABILITIES_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh(character: String = "vanguard"):
	var sim = Sim.new()
	sim.start_run([{"id": 1, "name": "Ability", "character": character}], 20261005)
	sim.state.world_size = Vector2(2400, 1100)
	sim.state.floor_y = 1000.0
	sim.state.platforms = [Rect2(0, 1000, 2400, 60)]
	sim.state.chests = []
	sim._spawn_clock = 9999.0
	var player: Dictionary = sim.state.players[1]
	player.pos = Vector2(800, 979)
	player.vel = Vector2.ZERO
	player.grounded = true
	player.invuln = 0.0
	player.explore_anchor = player.pos
	sim.events.clear()
	return sim

func _dummy(sim, offset: Vector2, kind: String = "crawler") -> Dictionary:
	var enemy: Dictionary = sim._spawn_enemy(kind, Vector2(sim.state.players[1].pos) + offset)
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	enemy.stun_timer = 9999.0
	return enemy

func _events(sim, type: String) -> Array:
	return sim.events.filter(func(event: Dictionary): return event.get("type", "") == type)

func _catalog() -> void:
	var ranger: Dictionary = Content.movement_ability("ranger")
	var vanguard: Dictionary = Content.movement_ability("vanguard")
	_check(ranger.id == "phase_dash" and vanguard.id == "shoulder_rush", "Character ability IDs are distinct and independent of replaceable gear")
	_check(ranger.damage == 0.0 and vanguard.damage == 16.0 and vanguard.cooldown > ranger.cooldown, "The short offensive rush trades longer cooldown for modest impact damage")
	_check(vanguard.speed * vanguard.duration < ranger.speed * ranger.duration and vanguard.invuln < ranger.invuln, "Vanguard gains neither Ranger's dash range nor its longer protection")
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items.thruster = 100
	_check(is_equal_approx(Sim.movement_ability(player).cooldown, 1.2), "HUD and simulation share the bounded Vanguard ability cooldown")
	player.character = "ranger"
	_check(is_equal_approx(Sim.movement_ability(player).cooldown, 0.8), "Ranger preserves the existing minimum cooldown with many thruster stacks")
	ranger.cooldown = 0.0
	_check(Content.movement_ability("ranger").cooldown == 2.4, "Editing an ability catalog copy cannot mutate the next player's rules")
	Locale.set_language("en")
	for record: Dictionary in [Content.movement_ability("ranger"), vanguard]:
		_check(Locale.has_translation(record.name) and Locale.has_translation(record.description), "Ability name and full numerical description have English coverage: " + str(record.id))
	for record: Dictionary in Sim.character_catalog():
		_check(Locale.has_translation(record.description), "The character's exclusive Shift ability is explained in both languages: " + str(record.id))

func _movement() -> void:
	var distances: Dictionary = {}
	for character: String in ["ranger", "vanguard"]:
		var sim = _fresh(character)
		var player: Dictionary = sim.state.players[1]
		var start: Vector2 = player.pos
		sim.step(DT, {1: {"dash": true, "aim": Vector2.RIGHT}})
		var starts: Array = _events(sim, "dash")
		_check(starts.size() == 1 and starts[0].ability == Content.movement_ability(character).id and starts[0].ability_id == 1 and starts[0].duration > 0.0, "The actual %s input emits one typed, serializable ability start" % character)
		_check(is_equal_approx(player.dash_cd, Sim.movement_ability(player).cooldown) and is_equal_approx(player.invuln, Content.movement_ability(character).invuln), "The %s cooldown and protection match its public ability data" % character)
		for tick in range(40):
			if player.dash_timer <= DT: break
			sim.step(DT, {})
		distances[character] = Vector2(player.pos).distance_to(start)
	_check(distances.vanguard < distances.ranger and distances.vanguard >= 85.0 and distances.vanguard <= 100.0, "Real fixed-step Vanguard travel stays short and below Ranger's displacement")
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.step(DT, {1: {"dash": true, "move": -1.0, "aim": Vector2.RIGHT}})
	_check(player.dash_dir == Vector2.LEFT and player.vel.x == -500.0, "Movement direction has priority over the cursor for the shoulder rush")
	sim = _fresh()
	player = sim.state.players[1]
	sim.step(DT, {1: {"dash": true, "aim": Vector2.UP}})
	_check(player.dash_dir == Vector2.RIGHT and player.pos.y == 979.0, "A vertical cursor cannot convert Vanguard's shoulder rush into an upward teleport")
	sim = _fresh()
	player = sim.state.players[1]
	sim.step(DT, {1: {"dash": true, "jump": true, "jump_held": true, "aim": Vector2.RIGHT}})
	_check(player.vel.y < -600.0 and player.jump_rising and _events(sim, "jump").size() == 1, "A shoulder rush preserves a real jump and its variable-height ownership")
	sim.step(DT, {1: {"jump_held": false}})
	_check(player.vel.y > -261.0 and not player.jump_rising, "Jump release still controls height during a shoulder rush")

func _collisions() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	var first: Dictionary = _dummy(sim, Vector2(32, 0))
	var second: Dictionary = _dummy(sim, Vector2(78, 0))
	var far: Dictionary = _dummy(sim, Vector2(210, 0))
	var impacts: Array = []
	for tick in range(20):
		sim.step(DT, {1: {"dash": tick == 0, "aim": Vector2.RIGHT}})
		impacts.append_array(_events(sim, "ability_hit"))
	_check(impacts.size() == 2 and impacts[0].enemy != impacts[1].enemy, "A complete rush hits each of two touched enemies once, never once per frame")
	_check(10000.0 - first.hp in [16.0, 32.0] and 10000.0 - second.hp in [16.0, 32.0] and far.hp == 10000.0, "Rush damage follows the existing critical rule without a hidden area attack")
	_check(player.dash_hits.is_empty() and player.dash_kind.is_empty(), "Expired actions release their bounded per-target state")
	sim = _fresh("ranger")
	first = _dummy(sim, Vector2(20, 0))
	sim.step(DT, {1: {"dash": true}})
	_check(first.hp == 10000.0 and _events(sim, "ability_hit").is_empty(), "The Ranger retains a purely evasive dash")
	sim = _fresh()
	first = _dummy(sim, Vector2(28, 0))
	first.stun_timer = 0.0
	sim.step(DT, {1: {"dash": true}})
	_check(first.stun_timer > 0.29 and first.stun_timer <= 0.32, "A real collision briefly interrupts an ordinary enemy")
	sim = _fresh()
	first = _dummy(sim, Vector2(28, 0), "boss")
	first.stun_timer = 0.0
	sim.step(DT, {1: {"dash": true}})
	_check(first.stun_timer > 0.05 and first.stun_timer <= 0.08, "Boss interruption has the smaller, bounded duration")
	sim = _fresh()
	player = sim.state.players[1]
	player.pos.x = 2378.0
	first = _dummy(sim, Vector2(-40, 0))
	sim.step(0.05, {1: {"dash": true, "aim": Vector2.RIGHT}})
	_check(player.pos.x <= 2380.0 and first.hp == 10000.0, "At a world wall collision uses the actual clipped path and cannot hit a target behind it")
	sim = _fresh()
	first = _dummy(sim, Vector2(22, 0))
	sim.step(0.05, {1: {"dash": true}})
	_check(first.hp < 10000.0, "Swept contact remains reliable at the maximum supported physics delta")
	sim = _fresh()
	player = sim.state.players[1]
	for index in range(Sim.MAX_ENEMIES): _dummy(sim, Vector2(15, 0))
	sim.step(DT, {1: {"dash": true}})
	_check(player.dash_hits.size() == Sim.MAX_ENEMIES and sim.events.size() <= 64, "Dense contact respects both the victim-state and event budgets")
	_check(sim.state.enemies.all(func(enemy: Dictionary): return 10000.0 - float(enemy.hp) in [16.0, 32.0]), "Budget pressure never repeats or silently drops the actual one-hit gameplay rule")

func _cancellation() -> void:
	for reason: String in ["hurt", "dead", "stun", "stage"]:
		var sim = _fresh()
		var player: Dictionary = sim.state.players[1]
		sim.step(DT, {1: {"dash": true}})
		var cooldown: float = player.dash_cd
		match reason:
			"hurt", "dead":
				player.invuln = 0.0
				sim._damage_player(player, 9999.0 if reason == "dead" else 2.0, player.pos - Vector2.RIGHT)
			"stun":
				player.stun_timer = 0.3
				sim.step(DT, {1: {"dash": true}})
			"stage": sim._build_stage(2)
		_check(player.dash_timer == 0.0 and player.dash_kind.is_empty() and player.dash_hits.is_empty(), reason + " cancels the rush without leaving live collision state")
		if reason != "stage": _check(player.dash_cd >= cooldown - DT - 0.00001, reason + " does not refund the spent ability cooldown")
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.stun_timer = 0.2
	sim.step(DT, {1: {"dash": true, "jump": true, "fire": true}})
	_check(player.dash_id == 0 and player.pos == Vector2(800, 979) and _events(sim, "dash").is_empty() and not player.has("melee"), "A controlled player cannot begin a rush, jump or attack until control returns")

func _equipment() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.step(DT, {1: {"dash": true}})
	var cooldown: float = player.dash_cd
	for item: String in ["railgun", "grenade"]:
		var pickup: Dictionary = sim._spawn_pickup(player.pos, "item", item, 1)
		sim._take_loot(player, pickup)
	_check(Sim.movement_ability(player).id == "shoulder_rush" and player.dash_cd == cooldown and player.dash_kind == "shoulder_rush", "Weapon and active-equipment swaps retain the character skill and its cooldown")
	for character: String in ["vanguard", "ranger"]:
		sim = _fresh(character)
		player = sim.state.players[1]
		player.equipment = "shockwave"
		var enemy: Dictionary = _dummy(sim, Vector2(20, 0))
		sim.step(DT, {1: {"skill": true, "aim": Vector2.UP}})
		var hp: float = enemy.hp
		sim.step(DT, {})
		_check(player.dash_kind == "shockwave" and player.vel.y == -Sim.DASH_SPEED and player.dash_id == 0 and player.dash_cd == 0.0, "Equipped shockwave preserves its original directional movement on " + character)
		_check(enemy.hp == hp and _events(sim, "ability_hit").is_empty(), "Shockwave never inherits shoulder collision damage on " + character)

func _prediction() -> void:
	for character: String in ["ranger", "vanguard"]:
		var sim = _fresh(character)
		var player: Dictionary = sim.state.players[1]
		player.items.feather = 1
		player.items.thruster = 2
		var predicted: Dictionary = player.duplicate(true)
		var parity: bool = true
		for tick in range(120):
			var command: Dictionary = {"move": 0.5, "dash": tick in [0, 85], "jump": tick in [0, 20], "jump_held": tick < 8 or tick >= 20, "aim": Vector2(-1, -1).normalized()}
			sim.predict_player(predicted, command, DT)
			sim.step(DT, {1: command})
			for key: String in ["pos", "vel", "dash_timer", "dash_cd", "dash_kind", "dash_dir", "dash_id", "jumps", "jump_rising"]:
				if predicted[key] != player[key]: parity = false
		_check(parity, character + " authority and local movement prediction match for every jump, dash and cooldown tick")
	var sim = _fresh()
	var target: Dictionary = _dummy(sim, Vector2(25, 0))
	var predicted: Dictionary = sim.state.players[1].duplicate(true)
	var before: PackedByteArray = var_to_bytes(sim.get_snapshot())
	sim.predict_player(predicted, {"dash": true}, DT)
	_check(target.hp == 10000.0 and sim.events.is_empty() and before == var_to_bytes(sim.get_snapshot()), "Client prediction changes only its supplied player and cannot deal damage or emit impact feedback")
	sim.step(DT, {1: {"dash": true}})
	var replica = Sim.new()
	replica.apply_snapshot(sim.get_snapshot())
	_check(replica.state.players[1].dash_hits == sim.state.players[1].dash_hits and replica.state.players[1].dash_kind == "shoulder_rush", "Action source, victim set and serial survive a cooperative snapshot")
	replica.state.players[1].dash_hits.clear()
	_check(not sim.state.players[1].dash_hits.is_empty(), "Snapshot consumers cannot mutate the authority victim set")
