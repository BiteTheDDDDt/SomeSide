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
	_counter()
	_mitigation()
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

func _phases(events: Array, phase: String) -> Array:
	return events.filter(func(event: Dictionary): return event.get("type", "") == "ability" and event.get("ability", "") == "guard_burst" and event.get("phase", "") == phase)

func _finish(sim, ticks: int = 75) -> Array:
	var events: Array = []
	for tick in range(ticks):
		sim.step(DT, {})
		events.append_array(sim.events.duplicate(true))
	return events

func _catalog() -> void:
	var ranger: Dictionary = Content.movement_ability("ranger")
	var guard: Dictionary = Content.movement_ability("vanguard")
	_check(ranger.id == "phase_dash" and guard.id == "guard_burst", "Character skills distinguish mobile evasion from defensive counterplay")
	_check(guard.speed == 0.0 and guard.invuln == 0.0 and guard.cooldown == 5.5 and guard.reduction == 0.8, "Guard reduces damage without supplying dash speed or invulnerability")
	_check(guard.damage + guard.charge_cap * guard.charge_ratio == 42.0, "Stored damage has a modest explicit upper bound before build bonuses")
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items.thruster = 100
	_check(Sim.movement_ability(player).cooldown == 2.0, "The guard cooldown has a two-second floor with extreme thruster stacks")
	player.character = "ranger"
	_check(Sim.movement_ability(player).cooldown == 0.8, "Ranger preserves its original minimum cooldown")
	guard.damage = 9999.0
	_check(Content.movement_ability("vanguard").damage == 12.0, "HUD catalog copies cannot mutate gameplay rules")
	for record: Dictionary in [Content.movement_ability("ranger"), Content.movement_ability("vanguard")]:
		_check(Locale.has_translation(record.name) and Locale.has_translation(record.description), "Both languages explain the current skill: " + str(record.id))
	for record: Dictionary in Sim.character_catalog():
		_check(Locale.has_translation(record.description), "Character selection explains the real exclusive ability: " + str(record.id))

func _movement() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.step(DT, {1: {"dash": true, "aim": Vector2.UP}})
	var starts: Array = _phases(sim.events, "start")
	_check(starts.size() == 1 and starts[0].ability_id == 1 and starts[0].duration == 0.8, "Actual Shift emits one identifiable guard start")
	_check(player.pos == Vector2(800, 979) and player.vel == Vector2.ZERO and player.dash_timer == 0.0, "Guarding causes no forced horizontal or vertical movement")
	_check(player.guard_timer == 0.8 and player.guard_absorbed == 0.0 and player.guard_id == 1 and player.dash_cd == 5.5 and player.invuln == 0.0, "Serialized initial stance and cooldown match the public data")
	for tick in range(20): sim.step(DT, {1: {"dash": true, "move": 1.0}})
	_check(is_equal_approx(player.vel.x, Sim.MOVE_SPEED * 0.35) and player.pos.x < 831.0 and player.dash_id == 1, "Guard permits slow voluntary walking; held Shift cannot rearm it")
	sim = _fresh()
	player = sim.state.players[1]
	player.vel.x = 720.0
	sim.step(DT, {1: {"dash": true}})
	_check(absf(player.vel.x) <= Sim.MOVE_SPEED * 0.35 and player.pos.x < 802.0, "Bracing removes excess momentum instead of disguising an ongoing dash")
	var base = _fresh()
	var guarded = _fresh()
	var parity: bool = true
	for tick in range(70):
		var command: Dictionary = {"jump": tick == 0, "jump_held": tick < 18}
		base.step(DT, {1: command})
		command["dash"] = tick == 0
		guarded.step(DT, {1: command})
		if base.state.players[1].pos.y != guarded.state.players[1].pos.y or base.state.players[1].vel.y != guarded.state.players[1].vel.y: parity = false
	_check(parity, "Guard preserves actual jump/release/gravity/landing trajectories")
	sim = _fresh("ranger")
	player = sim.state.players[1]
	sim.step(DT, {1: {"dash": true, "aim": Vector2.UP}})
	_check(player.vel.y == -720.0 and player.dash_kind == "phase_dash" and player.guard_timer == 0.0, "Ranger still performs an aimed upward dash")
	_check(player.dash_cd == 2.4 and player.invuln == 0.23, "Ranger retains its original cooldown and protection")

func _counter() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	var front: Dictionary = _dummy(sim, Vector2(70, 0))
	var behind: Dictionary = _dummy(sim, Vector2(-90, 0))
	var far: Dictionary = _dummy(sim, Vector2(210, 0))
	sim.step(DT, {1: {"dash": true}})
	_check(front.hp == 10000.0 and behind.hp == 10000.0, "The stance produces no immediate contact or area damage")
	var events: Array = _finish(sim)
	_check(_phases(events, "release").size() == 1 and front.hp == 9988.0 and behind.hp == 9988.0 and far.hp == 10000.0, "Natural expiry produces one surrounding 12-damage counter with a finite radius")
	_check(player.guard_timer == 0.0 and player.guard_absorbed == 0.0, "Completion clears charge and live defense state")
	sim = _fresh()
	player = sim.state.players[1]
	front = _dummy(sim, Vector2(75, 0))
	sim._spawn_projectile(player.pos + Vector2(110, 0), Vector2(-600, 0), "enemy", "spit", 50.0, -1, 1.0, 6.0)
	sim.step(DT, {1: {"dash": true}})
	events = _finish(sim)
	_check(player.hp == 135.0 and front.hp == 9958.0, "A real hostile projectile loses 80% damage and powers a 42-damage counter")
	_check(_phases(events, "block").size() == 1 and _phases(events, "release").size() == 1 and _phases(events, "release")[0].absorbed == 40.0, "Projectile absorption and charged release each produce one authoritative event")
	sim = _fresh()
	player = sim.state.players[1]
	for item: String in ["lens", "arc", "toxin", "ember", "nova"]: player.items[item] = 100
	front = _dummy(sim, Vector2(65, 0))
	far = _dummy(sim, Vector2(220, 0))
	sim.step(DT, {1: {"dash": true}})
	_finish(sim)
	_check(front.hp == 9988.0 and far.hp == 10000.0 and float(front.get("poison_timer", 0.0)) == 0.0, "Extreme proc stacks cannot crit, poison or recursively chain the counter")
	sim = _fresh()
	player = sim.state.players[1]
	for index in range(Sim.MAX_ENEMIES): _dummy(sim, Vector2(70, 0))
	sim.step(DT, {1: {"dash": true}})
	events = _finish(sim)
	_check(sim.state.enemies.all(func(enemy: Dictionary): return enemy.hp == 9988.0) and _phases(events, "release").size() == 1, "A full enemy budget receives precisely one counter hit per target")
	sim.events.clear()
	for index in range(64): sim._emit("hit", Vector2.ZERO)
	sim._emit("ability", player.pos, {"ability": "guard_burst", "phase": "release"})
	_check(sim.events.size() == 64 and _phases(sim.events, "release").size() == 1, "Cosmetic saturation cannot swallow the counter release cue")
	for kind: String in ["crawler", "boss"]:
		sim = _fresh()
		front = _dummy(sim, Vector2(70, 0), kind)
		front.stun_timer = 0.0
		front.move_speed = 0.0
		front.attack_cd = 9999.0
		sim.step(DT, {1: {"dash": true}})
		for tick in range(60):
			sim.step(DT, {})
			if not _phases(sim.events, "release").is_empty(): break
		var expected: float = 0.06 if kind == "boss" else 0.28
		_check(front.stun_timer > expected - DT - 0.00001 and front.stun_timer <= expected, "Counter interruption is independently bounded for " + kind)

func _mitigation() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items.plating = 10
	player.shield = 25.0
	sim.step(DT, {1: {"dash": true}})
	sim._damage_player(player, 50.0, player.pos - Vector2.RIGHT)
	_check(player.hp == 145.0 and player.shield == 17.0 and player.guard_absorbed == 32.0, "Armor applies first, followed by guard reduction, then ordinary shields")
	_check(player.vel == Vector2.ZERO and player.guard_timer > 0.0, "Blocking resists knockback and retains the active guard")
	var charge: float = player.guard_absorbed
	sim._damage_player(player, 100.0, player.pos)
	_check(player.guard_absorbed == charge, "Damage immunity cannot be converted into stored energy")
	player.invuln = 0.0
	sim._damage_player(player, 100.0, player.pos)
	_check(player.guard_absorbed == 40.0, "Repeated accepted hits saturate at the charge cap")

func _cancellation() -> void:
	for reason: String in ["death", "stun", "stage", "shockwave"]:
		var sim = _fresh()
		var player: Dictionary = sim.state.players[1]
		var enemy: Dictionary = _dummy(sim, Vector2(-140, 0))
		sim.step(DT, {1: {"dash": true}})
		player.guard_absorbed = 30.0
		var cooldown: float = player.dash_cd
		match reason:
			"death": sim._damage_player(player, 10000.0, player.pos)
			"stun":
				player.stun_timer = 0.2
				sim.step(DT, {1: {"dash": true}})
			"stage": sim._build_stage(2)
			"shockwave": sim._use_skill(player)
		_check(player.guard_timer == 0.0 and player.guard_absorbed == 0.0, reason + " discards guard and charge")
		if reason != "stage": _check(player.dash_cd >= cooldown - DT - 0.00001, reason + " cannot refund the spent cooldown")
		_check(_phases(_finish(sim), "release").is_empty() and enemy.hp == 10000.0, reason + " cannot leak a delayed counter after cancellation")
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.stun_timer = 0.2
	sim.step(DT, {1: {"dash": true, "jump": true, "fire": true}})
	_check(player.guard_timer == 0.0 and player.dash_id == 0 and not player.has("melee"), "Control prevents guard and attack initiation")

func _equipment() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	sim.step(DT, {1: {"dash": true}})
	var cooldown: float = player.dash_cd
	for item: String in ["railgun", "grenade"]:
		var pickup: Dictionary = sim._spawn_pickup(player.pos, "item", item, 1)
		sim._take_loot(player, pickup)
	_check(Sim.movement_ability(player).id == "guard_burst" and player.dash_cd == cooldown and player.guard_timer == 0.8, "Gear replacement preserves the character's guard and cooldown")
	for character: String in ["ranger", "vanguard"]:
		sim = _fresh(character)
		player = sim.state.players[1]
		player.equipment = "shockwave"
		sim.step(DT, {1: {"skill": true, "aim": Vector2.UP}})
		sim.step(DT, {})
		_check(player.dash_kind == "shockwave" and player.vel.y == -Sim.DASH_SPEED and player.guard_timer == 0.0 and player.dash_id == 0, "Groundbreaker preserves its own movement on " + character)
		_check(_phases(_finish(sim), "release").is_empty(), "Groundbreaker never schedules a counter on " + character)

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
			for key: String in ["pos", "vel", "dash_timer", "dash_cd", "dash_kind", "dash_dir", "dash_id", "jumps", "jump_rising", "guard_timer", "guard_absorbed", "guard_id"]:
				if predicted[key] != player[key]: parity = false
		_check(parity, character + " authority and prediction match every stance, motion and cooldown tick")
	var sim = _fresh()
	var enemy: Dictionary = _dummy(sim, Vector2(40, 0))
	var before: PackedByteArray = var_to_bytes(sim.get_snapshot())
	var predicted: Dictionary = sim.state.players[1].duplicate(true)
	for tick in range(90): sim.predict_player(predicted, {"dash": tick == 0}, DT)
	_check(enemy.hp == 10000.0 and sim.events.is_empty() and var_to_bytes(sim.get_snapshot()) == before, "Completing predicted guard cannot release damage or mutate authority state")
	sim.step(DT, {1: {"dash": true}})
	sim._damage_player(sim.state.players[1], 20.0, Vector2.ZERO)
	var replica = Sim.new()
	replica.apply_snapshot(sim.get_snapshot())
	_check(replica.state.players[1].guard_timer == 0.8 and replica.state.players[1].guard_absorbed == 16.0 and replica.state.players[1].guard_id == 1, "Snapshots preserve remaining stance time, actual charge and action serial")
	replica.state.players[1].guard_absorbed = 0.0
	_check(sim.state.players[1].guard_absorbed == 16.0, "Client presentation cannot consume authority charge")
