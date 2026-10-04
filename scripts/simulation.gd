class_name SideSimulation
extends RefCounted

const Content = preload("res://scripts/content.gd")
const StageLayouts = preload("res://scripts/stage_layouts.gd")

## Authoritative, scene-independent game rules. State contains only serializable
## values. All positions are centers; platforms are one-way from above.

const WORLD_SIZE: Vector2 = Vector2(3200.0, 1100.0)
const PLAYER_HALF: Vector2 = Vector2(12.0, 21.0)
const GRAVITY: float = 1750.0
const JUMP_SPEED: float = 665.0
const MOVE_SPEED: float = 245.0
const DASH_SPEED: float = 720.0
const DASH_COOLDOWN: float = 2.4
const EXPLORE_DISTANCE: float = 240.0
const EXPLORE_SITE_RADIUS: float = 200.0
const EXPLORE_WINDOW: float = 3.0
const EXPLORE_BUDGET: int = 2
const MAX_ENEMIES: int = 44
const MAX_PROJECTILES: int = 280
const MAX_PICKUPS: int = 90
const GATE_SECONDS: float = 22.0

var state: Dictionary = {}
var events: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_id: int = 100
var _spawn_clock: float = 1.8


static func character_catalog() -> Array:
	return [
		{"id": "ranger", "name": "游侠", "description": "初始：脉冲步枪 + 震荡手雷\n100生命；所有武器与主动装备都可在局内替换。", "color": Color("65e2d6")},
		{"id": "vanguard", "name": "先锋", "description": "初始：共鸣弧刃 + 裂地冲击\n145生命；所有武器与主动装备都可在局内替换。", "color": Color("ffa66a")},
	]


static func item_catalog() -> Array:
	return Content.passives()


static func weapon_catalog() -> Array:
	return Content.weapons()


static func equipment_catalog() -> Array:
	return Content.equipment()


static func loot_definition(id: String) -> Dictionary:
	return Content.definition(id)

static func attack_interval(player: Dictionary) -> float:
	var definition: Dictionary = Content.definition(str(player.get("weapon", "pulse_rifle")))
	var items: Dictionary = player.get("items", {})
	var rate: float = (1.0 + int(items.get("overclock", 0)) * 0.13) * (1.6 if float(player.get("chrono_timer", 0.0)) > 0.0 else 1.0)
	return maxf(0.045, float(definition.get("fire_interval", 0.19)) / rate)

static func rarity_name(rarity: String) -> String:
	return Content.rarity_name(rarity)

static func rarity_color(rarity: String) -> Color:
	return Content.rarity_color(rarity)

static func rarity_rank(rarity: String) -> int:
	return Content.rarity_rank(rarity)

func start_run(roster: Array, seed_value: int = 1) -> void:
	_rng.seed = seed_value
	_next_id = 100
	events.clear()
	state = {
		"phase": "playing", "stage": 1, "time": 0.0, "stage_time": 0.0, "threat_time": 0.0,
		"seed": seed_value, "kills": 0, "difficulty": 1.0,
		"players": {}, "enemies": [], "projectiles": [], "pickups": [],
		"chests": [], "platforms": [], "world_size": WORLD_SIZE,
		"deployables": [], "effects": [], "loot_history": {"gear": [], "passive": []},
		"gate": {}, "boss_alive": false,
		"director": {"mode": "rest", "resting": true, "explorers": [], "event_active": false, "threat_time": 0.0},
	}
	for entry_value in roster:
		var entry: Dictionary = entry_value
		add_player(int(entry.get("id", 1)), str(entry.get("name", "旅人")), str(entry.get("character", "ranger")))
	_build_stage(1)


func add_player(id: int, player_name: String, character: String) -> void:
	if state.is_empty():
		return
	var players: Dictionary = state.get("players", {})
	if players.has(id) or players.size() >= 4:
		return
	var chosen: String = character if character in ["ranger", "vanguard"] else "ranger"
	var health: float = 145.0 if chosen == "vanguard" else 100.0
	var position: Vector2 = Vector2(state.get("spawn", Vector2(210.0, WORLD_SIZE.y - 101.0))) + Vector2(players.size() * 42.0, 0.0)
	for other_value in players.values():
		var other: Dictionary = other_value
		if not bool(other.get("dead", false)):
			position = other.get("pos", position) + Vector2(28.0, -10.0)
			break
	players[id] = {
		"id": id, "name": player_name.left(24), "character": chosen,
		"weapon": "arc_blade" if chosen == "vanguard" else "pulse_rifle",
		"equipment": "shockwave" if chosen == "vanguard" else "grenade",
		"pos": position, "vel": Vector2.ZERO, "aim": Vector2.RIGHT,
		"hp": health, "max_hp": health, "shield": 0.0, "coins": 35,
		"items": {}, "dead": false, "grounded": false, "fire_cd": 0.0,
		"skill_cd": 0.0, "dash_cd": 0.0, "invuln": 1.5,
		"kills": 0, "revive": 0.0, "coyote": 0.0, "jumps": 0,
		"drop_timer": 0.0, "dash_timer": 0.0, "dash_dir": Vector2.RIGHT,
		"hurt_timer": 0.0, "revive_timer": 0.0, "interact_cd": 0.0, "shield_timer": 0.0,
		"explore_anchor": position, "explore_sites": [position], "explore_window": 0.0, "explore_budget": 0,
		"chrono_timer": 0.0, "momentum_timer": 0.0, "nova_cd": 0.0, "attack_count": 0, "phoenix_spent": 0,
	}
	state["players"] = players


func remove_player(id: int) -> void:
	var players: Dictionary = state.get("players", {})
	players.erase(id)


func get_snapshot() -> Dictionary:
	return state.duplicate(true)


func apply_snapshot(snapshot: Dictionary) -> void:
	state = snapshot.duplicate(true)
	events.clear()


func predict_player(player: Dictionary, command: Dictionary, delta: float) -> void:
	if bool(player.get("dead", false)):
		return
	_move_player(player, command, clampf(delta, 0.0, 0.05))


func step(delta: float, commands: Dictionary) -> void:
	events.clear()
	if state.is_empty() or str(state.get("phase", "")) != "playing":
		return
	var dt: float = clampf(delta, 0.0, 0.05)
	state["time"] = float(state["time"]) + dt
	state["stage_time"] = float(state["stage_time"]) + dt
	_update_difficulty()
	var players: Dictionary = state["players"]
	var stage_at_start: int = int(state["stage"])
	for player_id in players:
		var player: Dictionary = players[player_id]
		var command: Dictionary = commands.get(player_id, {})
		_step_player(player, command, dt)
		# A transition is an atomic boundary. Commands sampled in the old arena
		# must not fire skills or move later players in the newly loaded arena.
		if str(state["phase"]) != "playing" or int(state["stage"]) != stage_at_start:
			return
	_step_enemies(dt)
	_step_deployables(dt)
	_step_effects(dt)
	_step_projectiles(dt)
	_cleanup_enemies()
	_step_challenges()
	_step_pickups(dt)
	_step_gate(dt)
	_step_director(dt)
	var alive: int = _alive_count()
	if not players.is_empty() and alive == 0:
		state["phase"] = "lost"
		_emit("lose", _world_size() * Vector2(0.5, 0.6))


func _step_player(player: Dictionary, command: Dictionary, dt: float) -> void:
	for key in ["fire_cd", "skill_cd", "invuln", "hurt_timer", "interact_cd", "nova_cd"]:
		player[key] = maxf(0.0, float(player.get(key, 0.0)) - dt)
	if float(player.get("shield_timer", 0.0)) > 0.0:
		player["shield_timer"] = maxf(0.0, float(player["shield_timer"]) - dt)
		if float(player["shield_timer"]) <= 0.0:
			player["shield"] = 0.0
	if bool(player["dead"]):
		player["chrono_timer"] = maxf(0.0, float(player.get("chrono_timer", 0.0)) - dt)
		player["momentum_timer"] = maxf(0.0, float(player.get("momentum_timer", 0.0)) - dt)
		var corpse_velocity: Vector2 = player.get("vel", Vector2.ZERO)
		corpse_velocity.x = move_toward(corpse_velocity.x, 0.0, 1000.0 * dt)
		corpse_velocity.y = minf(1100.0, corpse_velocity.y + GRAVITY * dt)
		var corpse_movement: Dictionary = _move_body(player["pos"], corpse_velocity, dt, PLAYER_HALF)
		player["pos"] = corpse_movement["pos"]
		player["vel"] = corpse_movement["vel"]
		if float(player.get("revive_timer", 0.0)) > 0.0:
			player["revive_timer"] = maxf(0.0, float(player["revive_timer"]) - dt)
			player["revive"] = clampf(1.0 - float(player["revive_timer"]) / 1.8, 0.0, 1.0)
			if float(player["revive_timer"]) <= 0.0:
				player["dead"] = false
				player["hp"] = float(player["max_hp"]) * 0.55
				player["invuln"] = 2.5
				player["revive"] = 0.0
				_reset_exploration(player, false)
				_emit("revive", player["pos"], {"player": player["id"]})
		return
	var was_dash: float = float(player.get("dash_timer", 0.0))
	_move_player(player, command, dt)
	if float(player.get("dash_timer", 0.0)) > was_dash:
		player["momentum_timer"] = 1.2
		player["invuln"] = maxf(float(player["invuln"]), 0.23)
		_emit("dash", player["pos"], {"aim": player["dash_dir"], "player": player["id"]})
	var moss: int = _stacks(player, "moss")
	if _stacks(player, "battery") > 0 and float(player["hurt_timer"]) <= 0.0:
		var shield_cap: float = minf(float(player["max_hp"]) * 0.6, _stacks(player, "battery") * 8.0)
		if float(player["shield"]) < shield_cap:
			player["shield"] = minf(shield_cap, float(player["shield"]) + dt * 4.0 * _stacks(player, "battery"))
	if moss > 0:
		var regen: float = moss * 0.65 * dt * (2.0 if float(player["hurt_timer"]) <= 1.0 else 1.0)
		player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + regen)
	if bool(command.get("fire", false)) and float(player["fire_cd"]) <= 0.0:
		_fire_weapon(player)
	if bool(command.get("skill", false)) and float(player["skill_cd"]) <= 0.0:
		_use_skill(player)
	if bool(command.get("interact", false)) and float(player["interact_cd"]) <= 0.0:
		player["interact_cd"] = 0.2
		_interact(player, command.get("interact_target", {}))


func _move_player(player: Dictionary, command: Dictionary, dt: float) -> void:
	player["chrono_timer"] = maxf(0.0, float(player.get("chrono_timer", 0.0)) - dt)
	player["momentum_timer"] = maxf(0.0, float(player.get("momentum_timer", 0.0)) - dt)
	var direction: Vector2 = command.get("aim", player.get("aim", Vector2.RIGHT))
	if direction.is_finite() and direction.length_squared() > 0.0001:
		player["aim"] = direction.normalized()
	var move: float = clampf(float(command.get("move", 0.0)), -1.0, 1.0)
	var velocity: Vector2 = player.get("vel", Vector2.ZERO)
	var position: Vector2 = player.get("pos", state.get("spawn", Vector2(210.0, _floor_y() - PLAYER_HALF.y)))
	var grounded: bool = bool(player.get("grounded", false))
	player["coyote"] = 0.105 if grounded else maxf(0.0, float(player.get("coyote", 0.0)) - dt)
	player["drop_timer"] = maxf(0.0, float(player.get("drop_timer", 0.0)) - dt)
	player["dash_cd"] = maxf(0.0, float(player.get("dash_cd", 0.0)) - dt)
	player["dash_timer"] = maxf(0.0, float(player.get("dash_timer", 0.0)) - dt)
	var speed: float = MOVE_SPEED * (1.0 + minf(1.1, _stacks(player, "thruster") * 0.09)) * (1.3 if float(player["chrono_timer"]) > 0.0 else 1.0)
	if bool(command.get("drop", false)) and position.y + PLAYER_HALF.y < _floor_y() - 5.0:
		player["drop_timer"] = 0.22
		position.y += 5.0
		velocity.y = maxf(velocity.y, 100.0)
		grounded = false
		player["coyote"] = 0.0
	elif bool(command.get("jump", false)):
		if grounded or float(player["coyote"]) > 0.0:
			velocity.y = -JUMP_SPEED
			player["jumps"] = 1
			player["coyote"] = 0.0
			grounded = false
		elif int(player.get("jumps", 0)) < 1 + _stacks(player, "feather") and _stacks(player, "feather") > 0:
			velocity.y = -JUMP_SPEED * 0.91
			player["jumps"] = maxi(1, int(player.get("jumps", 0))) + 1
	if bool(command.get("dash", false)) and float(player["dash_cd"]) <= 0.0:
		var dash_direction: Vector2 = Vector2(move, 0.0)
		if absf(move) < 0.1:
			dash_direction = player.get("aim", Vector2.RIGHT)
		player["dash_dir"] = dash_direction.normalized()
		player["dash_timer"] = 0.16
		player["dash_cd"] = maxf(0.8, DASH_COOLDOWN / (1.0 + _stacks(player, "thruster") * 0.1))
	if float(player["dash_timer"]) > 0.0:
		velocity = Vector2(player["dash_dir"]) * DASH_SPEED
	else:
		velocity.x = move_toward(velocity.x, move * speed, (2500.0 if grounded else 1800.0) * dt)
		velocity.y = minf(1100.0, velocity.y + GRAVITY * dt)
	var result: Dictionary = _move_body(position, velocity, dt, PLAYER_HALF, float(player["drop_timer"]) > 0.0)
	player["pos"] = result["pos"]
	player["vel"] = result["vel"]
	player["grounded"] = result["grounded"]
	if bool(result["grounded"]):
		player["jumps"] = 0
	if Vector2(player["pos"]).y > _world_size().y + 80.0:
		# Safety floor recovery, also identical during local prediction.
		player["pos"] = Vector2(clampf(position.x, 30.0, _world_size().x - 30.0), _floor_y() - PLAYER_HALF.y - 24.0)
		player["vel"] = Vector2.ZERO


func _move_body(position: Vector2, velocity: Vector2, dt: float, half: Vector2, drop: bool = false) -> Dictionary:
	var next: Vector2 = position + velocity * dt
	next.x = clampf(next.x, half.x + 8.0, _world_size().x - half.x - 8.0)
	next.y = maxf(next.y, 35.0)
	var grounded: bool = false
	var landing_y: float = INF
	if velocity.y >= 0.0:
		var platforms: Array = state.get("platforms", [])
		for platform_value in platforms:
			var platform: Rect2 = platform_value
			if drop and platform.position.y < _floor_y() - 5.0:
				continue
			if next.x + half.x <= platform.position.x or next.x - half.x >= platform.end.x:
				continue
			var foot_before: float = position.y + half.y
			var foot_after: float = next.y + half.y
			if foot_before <= platform.position.y + 2.0 and foot_after >= platform.position.y:
				landing_y = minf(landing_y, platform.position.y - half.y)
	if landing_y != INF:
		next.y = landing_y
		velocity.y = 0.0
		grounded = true
	return {"pos": next, "vel": velocity, "grounded": grounded}


func _fire_weapon(player: Dictionary) -> void:
	var aim: Vector2 = player["aim"]
	var position: Vector2 = player["pos"]
	var weapon: String = str(player.get("weapon", "pulse_rifle"))
	player["fire_cd"] = attack_interval(player)
	player["attack_count"] = int(player.get("attack_count", 0)) + 1
	match weapon:
		"arc_blade":
			_emit("slash", position + aim * 34.0, {"aim": aim, "radius": 105.0, "player": player["id"]})
			var enemies: Array = state["enemies"]
			for enemy_value in enemies.duplicate():
				var enemy: Dictionary = enemy_value
				var offset: Vector2 = Vector2(enemy["pos"]) - position
				if float(enemy["hp"]) > 0.0 and offset.length() <= 110.0 + _enemy_radius(enemy) and (offset.length() < 34.0 or offset.normalized().dot(aim) > -0.12):
					_damage_enemy(enemy, 24.0 * _damage_scale(player), int(player["id"]), true, 0)
					if str(enemy["kind"]) != "boss":
						enemy["vel"] = Vector2(enemy["vel"]) + aim * 170.0
					player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + 0.35)
		"scattergun":
			for pellet in range(6):
				var spread: float = (float(pellet) - 2.5) * 0.075 + _rng.randf_range(-0.012, 0.012)
				_spawn_projectile(position + aim * 21.0, aim.rotated(spread) * 820.0, "player", "pellet", 8.0 * _damage_scale(player), int(player["id"]), 0.43, 4.0)
			_emit("shoot", position + aim * 22.0, {"aim": aim, "player": player["id"], "kind": "scattergun"})
		"railgun":
			_spawn_projectile(position + aim * 21.0, aim * 2500.0, "player", "rail", 70.0 * _damage_scale(player), int(player["id"]), 0.6, 5.0)
			_emit("shoot", position + aim * 22.0, {"aim": aim, "player": player["id"], "kind": "railgun"})
		"flamethrower":
			_emit("slash", position + aim * 50.0, {"aim": aim, "radius": 170.0, "player": player["id"], "kind": "flame"})
			for enemy_value in Array(state["enemies"]).duplicate():
				var enemy: Dictionary = enemy_value
				var offset: Vector2 = Vector2(enemy["pos"]) - position
				if offset.length() < 170.0 + _enemy_radius(enemy) and offset.normalized().dot(aim) > 0.55:
					_damage_enemy(enemy, 8.0 * _damage_scale(player), int(player["id"]), true, 0)
					enemy["burn_timer"] = 2.0
					enemy["burn_dps"] = 5.0 * _damage_scale(player)
					enemy["burn_owner"] = int(player["id"])
		"boomerang":
			_spawn_projectile(position + aim * 22.0, aim * 620.0, "player", "boomerang", 26.0 * _damage_scale(player), int(player["id"]), 1.3, 10.0)
			_emit("shoot", position, {"aim": aim, "player": player["id"], "kind": "boomerang"})
		"storm_staff":
			_spawn_projectile(position + aim * 22.0, aim * 780.0, "player", "storm", 32.0 * _damage_scale(player), int(player["id"]), 1.25, 8.0)
			_emit("shoot", position, {"aim": aim, "player": player["id"], "kind": "storm"})
		"sun_lance":
			_spawn_projectile(position + aim * 22.0, aim * 2400.0, "player", "lance", 120.0 * _damage_scale(player), int(player["id"]), 0.75, 8.0)
			_emit("shoot", position, {"aim": aim, "player": player["id"], "kind": "lance"})
		_:
			var spread: float = _rng.randf_range(-0.018, 0.018)
			_spawn_projectile(position + aim * 21.0, aim.rotated(spread) * 1100.0, "player", "bullet", 8.0 * _damage_scale(player), int(player["id"]), 1.3, 3.0)
			_emit("shoot", position + aim * 22.0, {"aim": aim, "player": player["id"], "kind": "bullet"})
	if _stacks(player, "echo") > 0 and int(player["attack_count"]) % 6 == 0:
		var target: Dictionary = _nearest_enemy(position, 650.0)
		if not target.is_empty():
			_damage_enemy(target, 12.0 * mini(8, _stacks(player, "echo")) * _damage_scale(player), int(player["id"]), false, 1)
			_emit("explosion", target["pos"], {"radius": 55.0, "owner": player["id"], "kind": "echo", "team": "player"})


func _use_skill(player: Dictionary) -> void:
	var aim: Vector2 = player["aim"]
	var position: Vector2 = player["pos"]
	var equipment: String = str(player.get("equipment", "grenade"))
	var definition: Dictionary = loot_definition(equipment)
	var cooldown_scale: float = maxf(0.35, 1.0 / (1.0 + _stacks(player, "coolant") * 0.16))
	player["skill_cd"] = float(definition.get("cooldown", 5.0)) * cooldown_scale
	match equipment:
		"shockwave":
			player["invuln"] = maxf(float(player["invuln"]), 0.45)
			player["dash_timer"] = 0.2
			player["dash_dir"] = aim
			var center: Vector2 = position + aim * 90.0
			_explode(center, 150.0, 60.0 * _damage_scale(player), int(player["id"]), "player", 0)
			_emit("slash", center, {"aim": aim, "radius": 150.0, "player": player["id"], "skill": true})
		"repair_field":
			for teammate_value in Dictionary(state["players"]).values():
				var teammate: Dictionary = teammate_value
				if not bool(teammate["dead"]) and Vector2(teammate["pos"]).distance_to(position) <= 260.0:
					teammate["hp"] = minf(float(teammate["max_hp"]), float(teammate["hp"]) + float(teammate["max_hp"]) * 0.35)
			_emit("explosion", position, {"radius": 260.0, "team": "player", "owner": player["id"], "healing": true, "visual_only": true})
		"aegis":
			player["shield"] = maxf(float(player["shield"]), float(player["max_hp"]) * 0.6)
			player["shield_timer"] = 6.0
			player["invuln"] = maxf(float(player["invuln"]), 0.4)
			_emit("explosion", position, {"radius": 60.0, "team": "player", "owner": player["id"], "shield": true, "visual_only": true})
		"graviton":
			var center: Vector2 = position + aim * 160.0
			for enemy_value in Array(state["enemies"]).duplicate():
				var enemy: Dictionary = enemy_value
				if Vector2(enemy["pos"]).distance_to(center) <= 300.0:
					enemy["pos"] = Vector2(enemy["pos"]).move_toward(center, 130.0)
					enemy["stun_timer"] = 0.45 if str(enemy["kind"]) == "boss" else 1.4
					_damage_enemy(enemy, 55.0 * _damage_scale(player), int(player["id"]), true, 0)
			_emit("explosion", center, {"radius": 300.0, "owner": player["id"], "kind": "graviton", "team": "player"})
		"turret":
			var turrets: Array = state.get("deployables", [])
			if turrets.size() >= 4:
				turrets.pop_front()
			var turret_pos: Vector2 = position + Vector2(aim.x * 60.0, 0.0)
			turret_pos.y = _surface_below(turret_pos.x, position.y - 30.0) - 16.0
			turrets.append({"id": _id(), "kind": "turret", "pos": turret_pos, "ttl": 8.0, "fire_cd": 0.0, "owner": player["id"], "damage": 14.0 * _damage_scale(player)})
			state["deployables"] = turrets
			_emit("explosion", turret_pos, {"radius": 55.0, "owner": player["id"], "kind": "turret", "team": "player"})
		"meteor":
			var effects: Array = state.get("effects", [])
			for index in range(3):
				if effects.size() >= 24:
					break
				var impact: Vector2 = position + aim * 300.0 + Vector2((index - 1) * 110.0, 0.0)
				impact.x = clampf(impact.x, 20.0, _world_size().x - 20.0)
				effects.append({"id": _id(), "kind": "meteor", "pos": impact, "delay": 0.5 + index * 0.25, "radius": 150.0, "damage": 140.0 * _damage_scale(player), "owner": player["id"]})
			state["effects"] = effects
		"time_warp":
			for teammate_value in Dictionary(state["players"]).values():
				var teammate: Dictionary = teammate_value
				if not bool(teammate["dead"]) and Vector2(teammate["pos"]).distance_to(position) <= 350.0:
					teammate["chrono_timer"] = 5.0
					teammate["invuln"] = maxf(float(teammate["invuln"]), 0.3)
			_emit("explosion", position, {"radius": 350.0, "owner": player["id"], "kind": "time_warp", "team": "player"})
		_:
			_spawn_projectile(position + aim * 24.0, aim * 640.0 + Vector2(0.0, -90.0), "player", "grenade", 70.0 * _damage_scale(player), int(player["id"]), 0.95, 7.0)
			_emit("shoot", position + aim * 22.0, {"aim": aim, "player": player["id"], "kind": "grenade"})

func _spawn_projectile(position: Vector2, velocity: Vector2, team: String, kind: String, damage: float, owner: int, ttl: float, radius: float) -> void:
	var projectiles: Array = state["projectiles"]
	if projectiles.size() >= MAX_PROJECTILES:
		return
	var player: Dictionary = Dictionary(state.get("players", {})).get(owner, {})
	var base_pierce: int = 3 if kind == "rail" else (6 if kind == "lance" else (4 if kind == "boomerang" else 1))
	var extra_pierce: int = mini(3, _stacks(player, "piercer")) if kind != "grenade" and not player.is_empty() else 0
	projectiles.append({"id": _id(), "pos": position, "vel": velocity, "team": team,
		"kind": kind, "ttl": ttl, "radius": radius, "damage": damage, "owner": owner,
		"hit_ids": [], "pierce": mini(9, base_pierce + extra_pierce), "max_pierce": mini(9, base_pierce + extra_pierce), "age": 0.0, "returning": false})
	var projectile: Dictionary = projectiles.back()
	projectile.merge(_visual_data(owner), true)


func _step_projectiles(dt: float) -> void:
	var projectiles: Array = state["projectiles"]
	var kept: Array = []
	for projectile_value in projectiles:
		var projectile: Dictionary = projectile_value
		var previous: Vector2 = projectile["pos"]
		var velocity: Vector2 = projectile["vel"]
		var kind: String = projectile["kind"]
		projectile["age"] = float(projectile.get("age", 0.0)) + dt
		if kind == "boomerang" and float(projectile["age"]) >= 0.5:
			if not bool(projectile.get("returning", false)):
				projectile["returning"] = true
				projectile["hit_ids"] = []
				projectile["pierce"] = int(projectile.get("max_pierce", 4))
			var owner_player: Dictionary = Dictionary(state["players"]).get(int(projectile["owner"]), {})
			if not owner_player.is_empty():
				velocity = (Vector2(owner_player["pos"]) - previous).normalized() * 720.0
				if previous.distance_to(owner_player["pos"]) < 20.0:
					continue
		if kind == "grenade":
			velocity.y += 700.0 * dt
		projectile["vel"] = velocity
		var next: Vector2 = previous + velocity * dt
		projectile["pos"] = next
		projectile["ttl"] = float(projectile["ttl"]) - dt
		var removed: bool = false
		if str(projectile["team"]) == "player":
			var target: Dictionary = {}
			var nearest_t: float = 2.0
			var enemies: Array = state["enemies"]
			var rail_hits: Array = []
			for enemy_value in enemies:
				var enemy: Dictionary = enemy_value
				if float(enemy["hp"]) <= 0.0 or int(enemy["id"]) in Array(projectile.get("hit_ids", [])):
					continue
				var hit_t: float = _segment_circle(previous, next, enemy["pos"], _enemy_radius(enemy) + float(projectile["radius"]))
				if (int(projectile.get("pierce", 1)) > 1 or kind in ["rail", "lance", "boomerang"]) and hit_t >= 0.0:
					rail_hits.append({"enemy": enemy, "t": hit_t})
				if hit_t >= 0.0 and hit_t < nearest_t:
					nearest_t = hit_t
					target = enemy
			if int(projectile.get("pierce", 1)) > 1 or kind in ["rail", "lance", "boomerang"]:
				rail_hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
				for hit_value in rail_hits:
					var hit: Dictionary = hit_value
					var enemy: Dictionary = hit["enemy"]
					if float(enemy["hp"]) <= 0.0:
						continue
					_damage_enemy(enemy, float(projectile["damage"]), int(projectile["owner"]), true, 0)
					_projectile_secondary(projectile, enemy)
					projectile["hit_ids"].append(int(enemy["id"]))
					projectile["pierce"] = int(projectile["pierce"]) - 1
					if int(projectile["pierce"]) <= 0:
						if kind == "boomerang" and not bool(projectile.get("returning", false)):
							projectile["age"] = 0.5
						else:
							removed = true
						break
			elif not target.is_empty():
				projectile["pos"] = previous.lerp(next, nearest_t)
				if kind == "grenade":
					_explode(projectile["pos"], 135.0, float(projectile["damage"]), int(projectile["owner"]), "player", 0)
				else:
					_damage_enemy(target, float(projectile["damage"]), int(projectile["owner"]), true, 0)
					_projectile_secondary(projectile, target)
				removed = true
		else:
			var players: Dictionary = state["players"]
			var target_player: Dictionary = {}
			var nearest_t: float = 2.0
			for player_value in players.values():
				var player: Dictionary = player_value
				if bool(player["dead"]):
					continue
				var hit_t: float = _segment_circle(previous, next, player["pos"], 17.0 + float(projectile["radius"]))
				if hit_t >= 0.0 and hit_t < nearest_t:
					nearest_t = hit_t
					target_player = player
			if not target_player.is_empty():
				_damage_player(target_player, float(projectile["damage"]), previous)
				removed = true
		if not removed and kind == "grenade" and velocity.y > 0.0:
			var platforms: Array = state["platforms"]
			for platform_value in platforms:
				var platform: Rect2 = platform_value
				var crosses_surface: bool = previous.y <= platform.position.y and next.y >= platform.position.y
				var starts_in_floor: bool = platform.position.y >= _floor_y() - 5.0 and previous.y >= platform.position.y
				if next.x >= platform.position.x and next.x <= platform.end.x and (crosses_surface or starts_in_floor):
					_explode(Vector2(next.x, platform.position.y - 6.0), 135.0, float(projectile["damage"]), int(projectile["owner"]), "player", 0)
					removed = true
					break
		if not removed and float(projectile["ttl"]) <= 0.0:
			if kind == "grenade":
				_explode(next, 135.0, float(projectile["damage"]), int(projectile["owner"]), "player", 0)
			removed = true
		if not removed and next.x > -100.0 and next.x < _world_size().x + 100.0 and next.y > -100.0 and next.y < _world_size().y + 100.0:
			kept.append(projectile)
	state["projectiles"] = kept


func _segment_circle(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var offset: Vector2 = from - center
	var direction: Vector2 = to - from
	var a: float = direction.length_squared()
	if offset.length_squared() <= radius * radius:
		return 0.0
	if a < 0.00001:
		return -1.0
	var b: float = 2.0 * offset.dot(direction)
	var c: float = offset.length_squared() - radius * radius
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var t: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return t if t >= 0.0 and t <= 1.0 else -1.0


func _damage_enemy(enemy: Dictionary, amount: float, owner: int, can_proc: bool, depth: int) -> void:
	if float(enemy.get("hp", 0.0)) <= 0.0:
		return
	var players: Dictionary = state["players"]
	var player: Dictionary = players.get(owner, {})
	var critical: bool = false
	if can_proc and not player.is_empty():
		critical = _rng.randf() < minf(0.85, 0.05 + _stacks(player, "lens") * 0.08)
	if critical:
		amount *= 2.0
	if can_proc and depth == 0 and not player.is_empty():
		if _stacks(player, "frost") > 0:
			enemy["slow_timer"] = 1.5
			enemy["slow_factor"] = 1.0 - minf(0.5, 0.15 + 0.05 * _stacks(player, "frost"))
		if _stacks(player, "toxin") > 0:
			enemy["poison_timer"] = 4.0
			enemy["poison_dps"] = 3.0 * mini(8, _stacks(player, "toxin")) * _damage_scale(player)
			enemy["poison_owner"] = owner
	enemy["hp"] = maxf(0.0, float(enemy["hp"]) - amount)
	enemy["flash"] = 0.1
	_emit("hit", enemy["pos"], {"amount": amount, "crit": critical, "owner": owner})
	if float(enemy["hp"]) <= 0.0:
		_kill_enemy(enemy, player, owner, depth)
	if critical and depth == 0 and not player.is_empty() and _stacks(player, "nova") > 0 and float(player.get("nova_cd", 0.0)) <= 0.0:
		player["nova_cd"] = 0.75
		_explode(enemy["pos"], 130.0, 16.0 * mini(8, _stacks(player, "nova")) * _damage_scale(player), owner, "player", 1, "nova")
	if can_proc and not player.is_empty() and depth == 0:
		var arc: int = _stacks(player, "arc")
		if arc > 0 and _rng.randf() < minf(0.65, 0.18 + arc * 0.07):
			var targets: Array = state["enemies"]
			var hits: int = 0
			for target_value in targets:
				var target: Dictionary = target_value
				if int(target["id"]) == int(enemy["id"]) or float(target["hp"]) <= 0.0:
					continue
				if Vector2(target["pos"]).distance_squared_to(enemy["pos"]) < 230.0 * 230.0:
					_emit("hit", target["pos"], {"amount": 0.0, "crit": false, "arc_from": enemy["pos"], "owner": owner})
					_damage_enemy(target, (8.0 + arc * 5.0) * _damage_scale(player), owner, false, 1)
					hits += 1
					if hits >= mini(3, arc + 1):
						break


func _kill_enemy(enemy: Dictionary, player: Dictionary, owner: int, depth: int) -> void:
	if bool(enemy.get("counted_dead", false)):
		return
	enemy["counted_dead"] = true
	state["kills"] = int(state["kills"]) + 1
	var position: Vector2 = enemy["pos"]
	_emit("death", position, {"kind": enemy["kind"], "elite": enemy["elite"]})
	if not player.is_empty():
		player["kills"] = int(player["kills"]) + 1
		player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + _stacks(player, "siphon") * 1.8)
	_spawn_pickup(position, "coin", "", 4 if not bool(enemy["elite"]) else 9)
	if _rng.randf() < 0.12:
		_spawn_pickup(position + Vector2(12.0, -12.0), "heal", "", 18)
	if str(enemy["kind"]) == "boss":
		state["boss_alive"] = false
		for p_value in Dictionary(state["players"]).values():
			var p: Dictionary = p_value
			p["coins"] = int(p["coins"]) + 35
			if not bool(p["dead"]):
				p["hp"] = minf(float(p["max_hp"]), float(p["hp"]) + 35.0)
		_spawn_pickup(position + Vector2(-25.0, -16.0), "item", _random_loot("boss"), 1)
		_spawn_pickup(position + Vector2(25.0, -16.0), "item", _random_loot("boss"), 1)
	elif _rng.randf() < (0.08 if bool(enemy["elite"]) else 0.03):
		_spawn_pickup(position + Vector2(0.0, -20.0), "item", _random_loot(), 1)
	# Only the initiating kill may produce an ember explosion. Secondary kills
	# cannot recurse, bounding the worst-case proc work even at high item stacks.
	if depth == 0 and not player.is_empty() and _stacks(player, "ember") > 0:
		_explode(position, 115.0, (12.0 + _stacks(player, "ember") * 9.0) * _damage_scale(player), owner, "player", 1)


func _explode(position: Vector2, radius: float, damage: float, owner: int, team: String, depth: int, effect_kind: String = "") -> void:
	var actor: Dictionary = Dictionary(state.get("players", {})).get(owner, {})
	if team == "player" and not actor.is_empty():
		var resonator_stacks: int = _stacks(actor, "resonator")
		if resonator_stacks > 0:
			radius *= 1.0 + minf(0.8, 0.3 + (resonator_stacks - 1) * 0.1)
	_emit("explosion", position, {"radius": radius, "team": team, "owner": owner, "proc": depth > 0, "kind": effect_kind})
	if team == "player":
		var enemies: Array = state["enemies"]
		for enemy_value in enemies.duplicate():
			var enemy: Dictionary = enemy_value
			if Vector2(enemy["pos"]).distance_to(position) <= radius + _enemy_radius(enemy):
				_damage_enemy(enemy, damage, owner, depth == 0, depth)
	else:
		for player_value in Dictionary(state["players"]).values():
			var player: Dictionary = player_value
			if Vector2(player["pos"]).distance_to(position) <= radius + 15.0:
				_damage_player(player, damage, position)


func _damage_player(player: Dictionary, amount: float, source: Vector2) -> void:
	if bool(player["dead"]) or float(player["invuln"]) > 0.0:
		return
	amount -= minf(amount * 0.6, float(_stacks(player, "plating")))
	var shield: float = float(player["shield"])
	var absorbed: float = minf(shield, amount)
	player["shield"] = shield - absorbed
	amount -= absorbed
	player["hp"] = maxf(0.0, float(player["hp"]) - amount)
	player["invuln"] = 0.48
	player["hurt_timer"] = 6.0
	var push: float = signf(Vector2(player["pos"]).x - source.x)
	player["vel"] = Vector2(push * 165.0, -150.0)
	_emit("hit", player["pos"], {"amount": amount, "crit": false, "player": player["id"], "friendly": true})
	if float(player["hp"]) <= 0.0:
		if int(player.get("phoenix_spent", 0)) < mini(2, _stacks(player, "phoenix")):
			player["phoenix_spent"] = int(player.get("phoenix_spent", 0)) + 1
			player["hp"] = float(player["max_hp"]) * 0.35
			player["invuln"] = 2.0
			_emit("revive", player["pos"], {"player": player["id"], "phoenix": true})
			return
		player["dead"] = true
		player["revive"] = 0.0
		player["revive_timer"] = 0.0
		_emit("death", player["pos"], {"player": player["id"], "kind": "player"})


func _step_enemies(dt: float) -> void:
	var enemies: Array = state["enemies"]
	var time: float = state["time"]
	for enemy_value in enemies:
		var enemy: Dictionary = enemy_value
		if float(enemy["hp"]) <= 0.0:
			continue
		_step_enemy_status(enemy, dt)
		if float(enemy["hp"]) <= 0.0:
			continue
		if float(enemy.get("stun_timer", 0.0)) > 0.0:
			enemy["vel"] = Vector2.ZERO
			continue
		enemy["attack_cd"] = maxf(0.0, float(enemy.get("attack_cd", 0.0)) - dt)
		enemy["jump_cd"] = maxf(0.0, float(enemy.get("jump_cd", 0.0)) - dt)
		enemy["flash"] = maxf(0.0, float(enemy.get("flash", 0.0)) - dt)
		var target: Dictionary = _nearest_player(enemy["pos"])
		if target.is_empty():
			continue
		var position: Vector2 = enemy["pos"]
		var target_pos: Vector2 = target["pos"]
		var offset: Vector2 = target_pos - position
		var velocity: Vector2 = enemy["vel"]
		var direction: float = signf(offset.x)
		var kind: String = enemy["kind"]
		var elite_scale: float = 1.15 if bool(enemy["elite"]) else 1.0
		var movement_scale: float = elite_scale * (float(enemy.get("slow_factor", 1.0)) if float(enemy.get("slow_timer", 0.0)) > 0.0 else 1.0)
		if kind == "drone":
			var desired: Vector2 = target_pos + Vector2(sin(time * 1.3 + int(enemy["id"])) * 125.0, -100.0)
			velocity = velocity.move_toward((desired - position).normalized() * 145.0 * movement_scale, 350.0 * dt)
			position += velocity * dt
			position.y = clampf(position.y, 80.0, _floor_y() - 35.0)
			if offset.length() < 510.0 and float(enemy["attack_cd"]) <= 0.0:
				_enemy_shoot(enemy, offset.normalized(), 300.0, 8.0, "orb")
				enemy["attack_cd"] = 2.0 + _rng.randf() * 0.7
		elif kind == "boss":
			_step_boss(enemy, target, dt)
			continue
		else:
			var speed: float = (116.0 if kind == "crawler" else 78.0) * movement_scale
			var move_direction: float = direction
			if kind == "spitter" and absf(offset.x) < 300.0:
				move_direction = -direction * 0.5 if absf(offset.x) < 180.0 else 0.0
			velocity.x = move_toward(velocity.x, move_direction * speed, 750.0 * dt)
			velocity.y = minf(1000.0, velocity.y + GRAVITY * dt)
			var grounded: bool = bool(enemy.get("grounded", false))
			if grounded and float(enemy["jump_cd"]) <= 0.0 and (offset.y < -48.0 or (kind == "crawler" and absf(offset.x) < 160.0)):
				velocity.y = -650.0 if offset.y < -90.0 else -450.0
				enemy["jump_cd"] = 1.35 + _rng.randf() * 0.8
			var result: Dictionary = _move_body(position, velocity, dt, Vector2(15.0, 17.0))
			position = result["pos"]
			velocity = result["vel"]
			enemy["grounded"] = result["grounded"]
			if kind == "spitter" and offset.length() < 650.0 and float(enemy["attack_cd"]) <= 0.0:
				_enemy_shoot(enemy, (offset + Vector2(target["vel"]) * 0.18).normalized(), 350.0, 11.0, "spit")
				enemy["attack_cd"] = 2.5 + _rng.randf() * 0.6
		enemy["pos"] = position
		enemy["vel"] = velocity
		if position.distance_to(target_pos) < 32.0:
			_damage_player(target, 10.0 * elite_scale * _enemy_damage_scale(), position)


func _step_boss(enemy: Dictionary, target: Dictionary, dt: float) -> void:
	var position: Vector2 = enemy["pos"]
	var velocity: Vector2 = enemy["vel"]
	var offset: Vector2 = Vector2(target["pos"]) - position
	var enraged: bool = float(enemy["hp"]) < float(enemy["max_hp"]) * 0.45
	var phase_time: float = float(enemy.get("phase_time", 0.0)) + dt
	enemy["phase_time"] = phase_time
	var telegraph: float = float(enemy.get("telegraph", 0.0))
	if telegraph > 0.0:
		telegraph = maxf(0.0, telegraph - dt)
		enemy["telegraph"] = telegraph
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * dt)
		if telegraph <= 0.0:
			var aim: Vector2 = offset.normalized()
			var count: int = 7 if enraged else 5
			for index in range(count):
				var spread: float = (index - (count - 1) * 0.5) * 0.18
				_enemy_shoot(enemy, aim.rotated(spread), 340.0 if enraged else 280.0, 16.0, "boss_orb")
			_emit("explosion", position, {"radius": 62.0, "team": "enemy", "visual_only": true})
			enemy["attack_cd"] = 2.2 if enraged else 3.1
	elif float(enemy["attack_cd"]) <= 0.0:
		enemy["telegraph"] = 0.65
	else:
		var slow: float = float(enemy.get("slow_factor", 1.0)) if float(enemy.get("slow_timer", 0.0)) > 0.0 else 1.0
		velocity.x = move_toward(velocity.x, signf(offset.x) * (125.0 if enraged else 82.0) * slow, 400.0 * dt)
	velocity.y = minf(1000.0, velocity.y + GRAVITY * dt)
	if bool(enemy.get("grounded", false)) and float(enemy["jump_cd"]) <= 0.0:
		velocity.y = -700.0 if offset.y < -70.0 else -460.0
		enemy["jump_cd"] = 2.4 if enraged else 3.6
	var was_grounded: bool = bool(enemy.get("grounded", false))
	var fall_speed: float = velocity.y
	var result: Dictionary = _move_body(position, velocity, dt, Vector2(39.0, 44.0))
	enemy["pos"] = result["pos"]
	enemy["vel"] = result["vel"]
	enemy["grounded"] = result["grounded"]
	if bool(result["grounded"]) and not was_grounded and fall_speed > 300.0:
		_explode(enemy["pos"], 95.0, 18.0 * _enemy_damage_scale(), -1, "enemy", 0)
	if Vector2(enemy["pos"]).distance_to(target["pos"]) < 56.0:
		_damage_player(target, 17.0 * _enemy_damage_scale(), enemy["pos"])


func _enemy_shoot(enemy: Dictionary, aim: Vector2, speed: float, damage: float, kind: String) -> void:
	_spawn_projectile(Vector2(enemy["pos"]) + aim * (_enemy_radius(enemy) + 3.0), aim * speed, "enemy", kind, damage * _enemy_damage_scale(), -1, 4.0, 6.0 if kind != "boss_orb" else 9.0)
	_emit("shoot", enemy["pos"], {"aim": aim, "kind": kind, "enemy": true})


func _cleanup_enemies() -> void:
	var kept: Array = []
	for enemy_value in Array(state["enemies"]):
		var enemy: Dictionary = enemy_value
		if float(enemy["hp"]) > 0.0:
			if str(enemy.get("spawn_source", "")) == "exploration" and int(enemy.get("challenge_id", -1)) < 0:
				var nearby: bool = false
				for player_value in Dictionary(state["players"]).values():
					var player: Dictionary = player_value
					if not bool(player["dead"]) and Vector2(player["pos"]).distance_to(enemy["pos"]) < 2000.0:
						nearby = true
						break
				if not nearby:
					continue
			kept.append(enemy)
	state["enemies"] = kept


func _nearest_player(position: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var distance: float = INF
	for player_value in Dictionary(state["players"]).values():
		var player: Dictionary = player_value
		if bool(player["dead"]):
			continue
		var squared: float = Vector2(player["pos"]).distance_squared_to(position)
		if squared < distance:
			distance = squared
			nearest = player
	return nearest


func _reset_exploration(player: Dictionary, clear_sites: bool) -> void:
	var position: Vector2 = player["pos"]
	player["explore_anchor"] = position
	player["explore_window"] = 0.0
	player["explore_budget"] = 0
	if clear_sites:
		player["explore_sites"] = [position]
	else:
		var sites: Array = player.get("explore_sites", [])
		var already_known: bool = false
		for site_value in sites:
			if Vector2(site_value).distance_to(position) < EXPLORE_SITE_RADIUS:
				already_known = true
				break
		if not already_known:
			sites.append(position)
		player["explore_sites"] = sites


func _step_director(dt: float) -> void:
	var gate: Dictionary = state["gate"]
	var gate_ready: bool = bool(gate.get("ready", false))
	var gate_active: bool = bool(gate.get("active", false)) and not gate_ready
	var explorers: Array = []
	var exploration_targets: Array = []
	var gate_targets: Array = []
	var event_active: bool = false
	var previous_director: Dictionary = state.get("director", {})
	var spawned: int = int(previous_director.get("spawned", 0))
	for player_value in Dictionary(state["players"]).values():
		var player: Dictionary = player_value
		var position: Vector2 = player["pos"]
		if bool(player["dead"]):
			player["explore_anchor"] = position
			player["explore_window"] = 0.0
			player["explore_budget"] = 0
			continue
		player["explore_window"] = maxf(0.0, float(player.get("explore_window", 0.0)) - dt)
		if float(player["explore_window"]) <= 0.0:
			player["explore_budget"] = 0
		var anchor: Vector2 = player.get("explore_anchor", position)
		if position.distance_to(anchor) >= EXPLORE_DISTANCE:
			# Refresh the local anchor even when this is a previously visited
			# patch. Walking a loop cannot repeatedly retry the same frontier.
			player["explore_anchor"] = position
			var sites: Array = player.get("explore_sites", [anchor])
			var fresh: bool = true
			for site_value in sites:
				if Vector2(site_value).distance_to(position) < EXPLORE_SITE_RADIUS:
					fresh = false
					break
			if fresh:
				sites.append(position)
				player["explore_sites"] = sites
				if not gate_ready:
					# Replace the allowance; never accumulate a delayed wave.
					player["explore_window"] = EXPLORE_WINDOW
					player["explore_budget"] = EXPLORE_BUDGET
		if gate_ready:
			player["explore_window"] = 0.0
			player["explore_budget"] = 0
		if float(player["explore_window"]) > 0.0:
			explorers.append(int(player["id"]))
			if int(player.get("explore_budget", 0)) > 0:
				exploration_targets.append(player)
		if gate_active and position.distance_to(gate["pos"]) < 640.0:
			gate_targets.append(player)
	if not gate_targets.is_empty():
		event_active = true
	for chest_value in Array(state.get("chests", [])):
		var chest: Dictionary = chest_value
		if str(chest.get("type", "")) != "combat" or str(chest.get("status", "idle")) != "active":
			continue
		for player_value in Dictionary(state["players"]).values():
			var player: Dictionary = player_value
			if not bool(player["dead"]) and Vector2(player["pos"]).distance_to(chest["pos"]) < 640.0:
				event_active = true
				break
	var advancing: bool = not explorers.is_empty() or event_active
	_update_difficulty()
	state["director"] = {"mode": "event" if event_active else ("exploring" if not explorers.is_empty() else "rest"),
		"resting": not advancing, "explorers": explorers, "event_active": event_active,
		"threat_time": float(state.get("threat_time", 0.0)), "spawned": spawned}
	var targets: Array = gate_targets if gate_active else exploration_targets
	if gate_ready or targets.is_empty():
		# No banked elapsed timer: resuming cannot release an idle backlog.
		_spawn_clock = 0.3
		return
	_spawn_clock -= dt
	if _spawn_clock > 0.0:
		return
	var difficulty: float = state["difficulty"]
	var players_count: int = maxi(1, Dictionary(state["players"]).size())
	_spawn_clock = maxf(0.85, 2.1 / (1.0 + difficulty * 0.15 + (targets.size() - 1) * 0.12)) * (0.8 if gate_active else 1.0)
	var enemies: Array = state["enemies"]
	var cap: int = mini(MAX_ENEMIES, 10 + int(state["stage"]) * 3 + players_count * 3)
	if enemies.size() >= cap:
		return
	var reference: Dictionary = targets[_rng.randi_range(0, targets.size() - 1)]
	var protected_ids: Array = explorers.duplicate()
	if gate_active:
		protected_ids.clear()
		for participant_value in gate_targets:
			var participant: Dictionary = participant_value
			protected_ids.append(int(participant["id"]))
	var target_pos: Vector2 = reference["pos"]
	var position: Vector2 = _director_spawn_position(reference, protected_ids)
	if not position.is_finite():
		return
	var kind: String = "crawler"
	var roll: float = _rng.randf()
	if roll > 0.77:
		kind = "spitter"
	elif roll > 0.52:
		kind = "drone"
	if position.y - target_pos.y > 240.0:
		# A ground enemy several storeys below an isolated balcony cannot
		# participate. Use a flying approach instead of filling the entity
		# budget with unreachable enemies on the distant safety floor.
		kind = "drone"
	if kind == "drone":
		position.y = clampf(target_pos.y - _rng.randf_range(100.0, 230.0), 100.0, _floor_y() - 80.0)
	var enemy: Dictionary = _spawn_enemy(kind, position, _rng.randf() < minf(0.24, 0.025 + (difficulty - 1.0) * 0.05))
	if enemy.is_empty():
		return
	enemy["director_target"] = int(reference["id"])
	enemy["spawn_source"] = "gate" if gate_active else "exploration"
	enemy["spawn_origin"] = target_pos
	state["director"]["spawned"] = spawned + 1
	if not gate_active:
		reference["explore_budget"] = maxi(0, int(reference["explore_budget"]) - 1)


func _director_spawn_position(reference: Dictionary, participating_ids: Array) -> Vector2:
	var target_pos: Vector2 = reference["pos"]
	for attempt in range(8):
		var x: float = clampf(target_pos.x + _rng.randf_range(360.0, 610.0) * (-1.0 if _rng.randf() < 0.5 else 1.0), 60.0, _world_size().x - 60.0)
		if absf(x - target_pos.x) < 300.0:
			x = target_pos.x - 440.0 if target_pos.x > _world_size().x * 0.5 else target_pos.x + 440.0
		var candidate: Vector2 = Vector2(x, _surface_below(x, target_pos.y - 40.0) - 17.0)
		var safe: bool = true
		for player_value in Dictionary(state["players"]).values():
			var player: Dictionary = player_value
			if bool(player["dead"]) or int(player["id"]) in participating_ids:
				continue
			var position: Vector2 = player["pos"]
			# A spawn aimed at an explorer must not appear on top of a distant
			# teammate who stopped to read or inspect equipment.
			if position.distance_to(target_pos) > 260.0 and absf(candidate.x - position.x) < 320.0:
				safe = false
				break
		if safe:
			return candidate
	return Vector2(INF, INF)

func _spawn_enemy(kind: String, position: Vector2, elite: bool = false) -> Dictionary:
	var enemies: Array = state["enemies"]
	if enemies.size() >= MAX_ENEMIES and kind != "boss":
		return {}
	var base: float = 36.0
	match kind:
		"drone": base = 28.0
		"spitter": base = 48.0
		"boss": base = 700.0 + (int(state["stage"]) - 1) * 260.0
	var count: int = maxi(1, Dictionary(state["players"]).size())
	var health: float = base * (1.0 + (count - 1) * 0.6) * (1.0 + (float(state["difficulty"]) - 1.0) * 0.28)
	if elite:
		health *= 1.85
	var enemy: Dictionary = {"id": _id(), "kind": kind, "pos": position, "vel": Vector2.ZERO,
		"hp": health, "max_hp": health, "elite": elite, "attack_cd": 1.0 + _rng.randf(),
		"jump_cd": 1.0, "grounded": false, "flash": 0.0, "telegraph": 0.0, "phase_time": 0.0, "challenge_id": -1,
		"spawn_difficulty": float(state["difficulty"])}
	enemies.append(enemy)
	return enemy


func _step_gate(dt: float) -> void:
	var gate: Dictionary = state["gate"]
	if not bool(gate.get("active", false)) or bool(gate.get("ready", false)):
		return
	var nearby: bool = false
	for player_value in Dictionary(state["players"]).values():
		var player: Dictionary = player_value
		if not bool(player["dead"]) and Vector2(player["pos"]).distance_to(gate["pos"]) < 640.0:
			nearby = true
			break
	if nearby:
		gate["charge"] = minf(1.0, float(gate["charge"]) + dt / GATE_SECONDS)
	if float(gate["charge"]) >= 1.0 and not bool(state["boss_alive"]):
		gate["ready"] = true
		_emit("gate", gate["pos"], {"ready": true})


func interaction_for(player_id: int) -> Dictionary:
	var candidates: Array = interaction_candidates(player_id)
	return candidates[0] if not candidates.is_empty() else {}


func interaction_candidates(player_id: int) -> Array:
	var player: Dictionary = Dictionary(state.get("players", {})).get(player_id, {})
	if player.is_empty() or bool(player.get("dead", false)):
		return []
	var position: Vector2 = player["pos"]
	var ranked: Array = []
	# All candidates remain independently addressable even at the exact same
	# coordinates. Rescue is suggested first; explicit cycling may select
	# another object without changing the authoritative ID-validation rules.
	for other_value in Dictionary(state["players"]).values():
		var other: Dictionary = other_value
		var distance: float = position.distance_to(other["pos"])
		if int(other["id"]) != player_id and bool(other["dead"]) and distance < 105.0:
			ranked.append({"record": _interaction_record("revive", other, player), "score": distance - 10000.0})
	for pickup_value in Array(state.get("pickups", [])):
		var pickup: Dictionary = pickup_value
		if str(pickup["kind"]) != "item":
			continue
		var distance: float = position.distance_to(pickup["pos"])
		if distance < 96.0:
			ranked.append({"record": _interaction_record("pickup", pickup, player), "score": distance - 12.0})
	for chest_value in Array(state.get("chests", [])):
		var chest: Dictionary = chest_value
		if bool(chest.get("opened", false)) or bool(chest.get("locked", false)):
			continue
		var distance: float = position.distance_to(chest["pos"])
		if distance < 105.0:
			ranked.append({"record": _interaction_record("chest", chest, player), "score": distance})
	var gate: Dictionary = state.get("gate", {})
	if not gate.is_empty():
		var distance: float = position.distance_to(gate["pos"])
		if distance < 130.0:
			ranked.append({"record": _interaction_record("gate", gate, player), "score": distance})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["score"]), float(b["score"])):
			return float(a["score"]) < float(b["score"])
		return int(Dictionary(a["record"])["id"]) < int(Dictionary(b["record"])["id"])
	)
	var result: Array = []
	for entry_value in ranked:
		var entry: Dictionary = entry_value
		result.append(entry["record"])
	return result

func _interaction_record(kind: String, target: Dictionary, player: Dictionary) -> Dictionary:
	var result: Dictionary = {"kind": kind, "id": int(target.get("id", -1)), "pos": target["pos"], "title": "", "description": "", "prompt": "", "warning": "", "item": "", "category": "", "affordable": true}
	if kind == "revive":
		result["title"] = "救援 · " + str(target.get("name", "旅者"))
		result["description"] = "靠近按 E 启动1.8秒重建；队友恢复55%生命。全员倒下则救援中止。"
		result["prompt"] = "E · 启动救援" if float(target.get("revive_timer", 0.0)) <= 0.0 else "正在重建 · %.1f秒" % float(target["revive_timer"])
		result["affordable"] = float(target.get("revive_timer", 0.0)) <= 0.0
		return result
	if kind == "gate":
		result["id"] = -1
		result["title"] = "裂隙门"
		if bool(target.get("ready", false)):
			result["description"] = "共鸣已稳定。全队进入下一关并恢复生命。" if int(state["stage"]) < 3 else "最终共鸣已稳定，完成远征。"
			result["prompt"] = "E · 前往下一关" if int(state["stage"]) < 3 else "E · 完成远征"
		elif bool(target.get("active", false)):
			result["description"] = "留在640范围内完成充能，并击败裂隙守卫。"
			result["prompt"] = "充能 %d%% · %s" % [int(float(target["charge"]) * 100.0), "守卫仍在" if bool(state["boss_alive"]) else "守卫已击败"]
			result["affordable"] = false
		else:
			result["description"] = "召唤守卫并开始22秒共鸣充能。准备妥当后启动。"
			result["prompt"] = "E · 激活裂隙门"
		return result
	var item: String = str(target.get("item", ""))
	var definition: Dictionary = loot_definition(item)
	result["item"] = item
	result["category"] = str(definition.get("category", "passive"))
	result["title"] = str(definition.get("name", item))
	result["description"] = str(definition.get("description", ""))
	result["warning"] = str(definition.get("warning", ""))
	if kind == "pickup":
		result["prompt"] = "E · 拾取遗物"
		if str(result["category"]) in ["weapon", "equipment"]:
			var slot: String = str(result["category"])
			var old: Dictionary = loot_definition(str(player.get(slot, "")))
			result["prompt"] = "E · 替换主武器" if slot == "weapon" else "E · 替换主动装备"
			result["warning"] = "将替换「%s」，旧装备会落地；换装保留未结束的冷却。" % str(old.get("name", "当前装备"))
		return result
	var facility: String = str(target.get("type", "cache"))
	result["facility_type"] = facility
	var price: int = int(target.get("cost", 0))
	match facility:
		"blood":
			result["title"] = "生命献祭 · " + str(result["title"])
			result["description"] = "消耗%d当前生命（不会致死），奖励落地后再按E选择。\n" % price + str(result["description"])
			result["warning"] = "代价：立即扣除%d当前生命；当前生命必须高于%d。" % [price, price] + ("\n" + str(result["warning"]) if not str(result["warning"]).is_empty() else "")
			result["prompt"] = "E · 献祭 %d 生命" % price
			result["affordable"] = float(player["hp"]) > price
		"combat":
			result["title"] = "试炼信标 · " + str(result["title"])
			var status: String = str(target.get("status", "idle"))
			result["description"] = "召唤4名专属试炼敌人；全部击败后奖励落地。无金币费用。\n" + str(result["description"])
			result["warning"] = "风险：立即进入战斗；周围普通敌人不会计入试炼进度。"
			result["prompt"] = "E · 开始战斗试炼" if status == "idle" else "试炼进行中 · 剩余 %d" % int(target.get("remaining", 0))
			result["affordable"] = status == "idle"
		_:
			var label: String = "三选一商店" if facility == "choice" else ("装备仓" if facility == "equipment" else "补给箱")
			result["title"] = label + " · " + str(result["title"])
			result["description"] = "支付%d金币；奖励落地后再按E选择。\n" % price + str(result["description"])
			if facility == "choice":
				result["description"] = "同组三个终端仅可购买一个。\n" + str(result["description"])
			result["prompt"] = "E · 支付 %d 金币" % price
			result["affordable"] = int(player["coins"]) >= price
	return result


func _interact(player: Dictionary, target: Dictionary = {}) -> void:
	var requested: Dictionary = target
	if requested.is_empty():
		requested = interaction_for(int(player["id"]))
	if requested.is_empty():
		return
	var kind: String = str(requested.get("kind", ""))
	var target_id: int = int(requested.get("id", -99999))
	var selected: Dictionary = {}
	var radius: float = 0.0
	match kind:
		"revive":
			selected = Dictionary(state["players"]).get(target_id, {})
			radius = 105.0
		"gate":
			if target_id == -1:
				selected = state["gate"]
			radius = 130.0
		"pickup", "chest":
			for candidate_value in Array(state["pickups"] if kind == "pickup" else state["chests"]):
				var candidate: Dictionary = candidate_value
				if int(candidate["id"]) == target_id:
					selected = candidate
					break
			radius = 96.0 if kind == "pickup" else 105.0
	if selected.is_empty() or Vector2(player["pos"]).distance_to(selected["pos"]) >= radius or bool(player["dead"]):
		_notice(player, "目标已离开范围或已被其他旅者拿走。")
		return
	if kind == "revive":
		if int(selected["id"]) == int(player["id"]) or not bool(selected["dead"]):
			return
		if float(selected.get("revive_timer", 0.0)) <= 0.0:
			selected["revive_timer"] = 1.8
			selected["revive"] = 0.01
			_emit("revive", selected["pos"], {"player": selected["id"], "started": true})
		return
	if kind == "gate":
		if bool(selected["ready"]):
			if int(state["stage"]) >= 3:
				state["phase"] = "won"
				_emit("win", selected["pos"])
			else:
				_build_stage(int(state["stage"]) + 1)
		elif not bool(selected["active"]):
			selected["active"] = true
			state["boss_alive"] = true
			_spawn_enemy("boss", Vector2(selected["pos"]) + Vector2(-340.0, -150.0))
			_emit("gate", selected["pos"], {"active": true})
		return
	if kind == "pickup":
		if str(selected["kind"]) != "item":
			return
		_take_loot(player, selected)
		return
	if bool(selected.get("opened", false)) or bool(selected.get("locked", false)):
		_notice(player, "这个设施已被使用。")
		return
	var facility: String = str(selected.get("type", "cache"))
	if facility == "combat":
		if str(selected.get("status", "idle")) == "idle":
			_start_challenge(selected, player)
		return
	if not _has_loot_room():
		_notice(player, "地面遗物过多，请先拾取附近物品。")
		return
	var cost: int = int(selected.get("cost", 0))
	if facility == "blood":
		if float(player["hp"]) <= cost:
			_notice(player, "生命不足：献祭后必须至少保留1点生命。")
			return
		player["hp"] = float(player["hp"]) - cost
		player["hurt_timer"] = 6.0
	else:
		if int(player["coins"]) < cost:
			_notice(player, "金币不足：需要%d金币。" % cost)
			return
		player["coins"] = int(player["coins"]) - cost
	selected["opened"] = true
	if facility == "choice":
		for other_value in Array(state["chests"]):
			var other: Dictionary = other_value
			if other.get("group", -1) == selected.get("group", -2) and int(other["id"]) != int(selected["id"]):
				other["locked"] = true
				other["opened"] = true
	_spawn_pickup(Vector2(selected["pos"]) + Vector2(0.0, -18.0), "item", str(selected["item"]), 1)
	_emit("interact", selected["pos"], {"player": player["id"], "kind": facility, "item": selected["item"]})


func _take_loot(player: Dictionary, pickup: Dictionary) -> void:
	var item: String = str(pickup["item"])
	var definition: Dictionary = loot_definition(item)
	if definition.is_empty():
		return
	var pickups: Array = state["pickups"]
	pickups.erase(pickup)
	var category: String = str(definition["category"])
	if category in ["weapon", "equipment"]:
		var old: String = str(player.get(category, ""))
		var cooldown_key: String = "fire_cd" if category == "weapon" else "skill_cd"
		var remaining: float = float(player.get(cooldown_key, 0.0))
		if not old.is_empty():
			_spawn_pickup(Vector2(pickup["pos"]) + Vector2(26.0, -6.0), "item", old, 1, remaining)
		player[category] = item
		player[cooldown_key] = maxf(maxf(remaining, float(pickup.get("cooldown", 0.0))), 0.18 if category == "weapon" else 0.5)
	else:
		_grant_item(player, item)
	_emit("pickup", pickup["pos"], {"player": player["id"], "item": item, "category": category, "kind": "item"})


func _start_challenge(chest: Dictionary, player: Dictionary) -> void:
	# Reserve four actual enemies. An overflowing ambient wave is reduced,
	# never counted as part of the linked challenge reward.
	var enemies: Array = state["enemies"]
	while enemies.size() > MAX_ENEMIES - 4:
		var removed: bool = false
		for index in range(enemies.size() - 1, -1, -1):
			var candidate: Dictionary = enemies[index]
			if str(candidate["kind"]) != "boss" and int(candidate.get("challenge_id", -1)) < 0:
				enemies.remove_at(index)
				removed = true
				break
		if not removed:
			_notice(player, "当前有其他试炼尚未完成。")
			return
	chest["status"] = "active"
	chest["remaining"] = 4
	var supporting: Rect2 = Rect2(0, _floor_y(), _world_size().x, 80)
	for platform_value in Array(state["platforms"]):
		var platform: Rect2 = platform_value
		if absf(platform.position.y - (Vector2(chest["pos"]).y + 17.0)) < 3.0 and platform.has_point(Vector2(Vector2(chest["pos"]).x, platform.position.y + 1.0)):
			supporting = platform
			break
	for index in range(4):
		var x: float = clampf(Vector2(chest["pos"]).x + (-1.0 if index % 2 == 0 else 1.0) * (140.0 + index * 28.0), 40.0, _world_size().x - 40.0)
		x = clampf(x, supporting.position.x + 40.0, supporting.end.x - 40.0)
		var kind: String = "drone" if index == 3 else ("spitter" if index == 2 else "crawler")
		var y: float = _surface_below(x, Vector2(chest["pos"]).y - 35.0) - 17.0
		var enemy: Dictionary = _spawn_enemy(kind, Vector2(x, y if kind != "drone" else y - 100.0), index == 0)
		enemy["challenge_id"] = int(chest["id"])
	_emit("interact", chest["pos"], {"player": player["id"], "kind": "combat"})


func _step_challenges() -> void:
	for chest_value in Array(state.get("chests", [])):
		var chest: Dictionary = chest_value
		if str(chest.get("type", "cache")) != "combat" or str(chest.get("status", "idle")) != "active":
			continue
		var count: int = 0
		for enemy_value in Array(state["enemies"]):
			var enemy: Dictionary = enemy_value
			if float(enemy["hp"]) > 0.0 and int(enemy.get("challenge_id", -1)) == int(chest["id"]):
				count += 1
		chest["remaining"] = count
		if count == 0 and _has_loot_room():
			chest["opened"] = true
			chest["status"] = "cleared"
			_spawn_pickup(Vector2(chest["pos"]) + Vector2(0, -20), "item", str(chest["item"]), 1)
			_emit("interact", chest["pos"], {"kind": "combat_clear", "item": chest["item"]})


func _has_loot_room() -> bool:
	var pickups: Array = state["pickups"]
	if pickups.size() < MAX_PICKUPS:
		return true
	for pickup_value in pickups:
		var pickup: Dictionary = pickup_value
		if str(pickup["kind"]) != "item":
			return true
	return false


func _spawn_pickup(position: Vector2, kind: String, item: String, amount: int, cooldown: float = 0.0) -> Dictionary:
	var pickups: Array = state["pickups"]
	if pickups.size() >= MAX_PICKUPS:
		var removed: bool = false
		for index in range(pickups.size()):
			if str(Dictionary(pickups[index])["kind"]) != "item":
				pickups.remove_at(index)
				removed = true
				break
		if not removed:
			return {}
	var definition: Dictionary = loot_definition(item) if kind == "item" else {}
	var pickup: Dictionary = {"id": _id(), "pos": position, "kind": kind, "item": item,
		"amount": amount, "age": 0.0, "vel": Vector2(_rng.randf_range(-35.0, 35.0), -100.0),
		"cooldown": cooldown, "category": str(definition.get("category", "")),
		"rarity": str(definition.get("rarity", "common")), "color": definition.get("color", Color.WHITE), "warning": str(definition.get("warning", ""))}
	pickups.append(pickup)
	return pickup


func _notice(player: Dictionary, message: String) -> void:
	_emit("notice", player["pos"], {"player": player["id"], "message": message})

func _step_pickups(dt: float) -> void:
	var kept: Array = []
	for pickup_value in Array(state["pickups"]):
		var pickup: Dictionary = pickup_value
		pickup["age"] = float(pickup.get("age", 0.0)) + dt
		pickup["cooldown"] = maxf(0.0, float(pickup.get("cooldown", 0.0)) - dt)
		var position: Vector2 = pickup["pos"]
		var velocity: Vector2 = pickup.get("vel", Vector2.ZERO)
		velocity.y = minf(600.0, velocity.y + 700.0 * dt)
		velocity.x = move_toward(velocity.x, 0.0, 100.0 * dt)
		var moved: Dictionary = _move_body(position, velocity, dt, Vector2(7.0, 7.0))
		position = moved["pos"]
		pickup["vel"] = moved["vel"]
		if str(pickup["kind"]) == "item":
			# All real loot remains on the ground until the exact displayed ID
			# is explicitly selected. Proximity never changes a player's build.
			pickup["pos"] = position
			kept.append(pickup)
			continue
		var target: Dictionary = {}
		var target_distance: float = INF
		for candidate_value in Dictionary(state["players"]).values():
			var candidate: Dictionary = candidate_value
			if bool(candidate["dead"]) or (str(pickup["kind"]) == "heal" and float(candidate["hp"]) >= float(candidate["max_hp"])):
				continue
			var candidate_distance: float = position.distance_squared_to(candidate["pos"])
			var candidate_radius: float = minf(350.0, 145.0 + _stacks(candidate, "magnet") * 35.0)
			if candidate_distance < candidate_radius * candidate_radius and candidate_distance < target_distance:
				target_distance = candidate_distance
				target = candidate
		var taken: bool = false
		if not target.is_empty():
			var distance: float = position.distance_to(target["pos"])
			var kind: String = pickup["kind"]
			var can_take: bool = kind != "heal" or float(target["hp"]) < float(target["max_hp"])
			var collect_radius: float = minf(350.0, 145.0 + _stacks(target, "magnet") * 35.0)
			if can_take and distance < collect_radius:
				position = position.move_toward(target["pos"], 440.0 * dt)
				if distance < 30.0:
					match kind:
						"coin":
							var reward: int = int(round(int(pickup["amount"]) * (1.0 + minf(1.0, _stacks(target, "harvest") * 0.15))))
							for player_value in Dictionary(state["players"]).values():
								var player: Dictionary = player_value
								player["coins"] = int(player["coins"]) + reward
						"heal":
							target["hp"] = minf(float(target["max_hp"]), float(target["hp"]) + int(pickup["amount"]))
					_emit("pickup", position, {"player": target["id"], "item": pickup["item"], "kind": kind})
					taken = true
		pickup["pos"] = position
		if not taken and (str(pickup["kind"]) == "item" or float(pickup["age"]) < 50.0):
			kept.append(pickup)
	state["pickups"] = kept


func _grant_item(player: Dictionary, item: String) -> void:
	var definition: Dictionary = loot_definition(item)
	if definition.is_empty() or str(definition["category"]) != "passive":
		return
	var inventory: Dictionary = player["items"]
	inventory[item] = int(inventory.get(item, 0)) + 1
	if item in ["vitality", "glass"]:
		var before: float = float(player["max_hp"])
		var base: float = 145.0 if str(player["character"]) == "vanguard" else 100.0
		player["max_hp"] = maxf(base * 0.2, (base + _stacks(player, "vitality") * 25.0) * pow(0.85, _stacks(player, "glass")))
		player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + maxf(0.0, float(player["max_hp"]) - before))


func _build_stage(stage: int) -> void:
	events.clear()
	state["stage"] = stage
	state["stage_time"] = 0.0
	state["enemies"] = []
	state["projectiles"] = []
	state["pickups"] = []
	state["chests"] = []
	state["deployables"] = []
	state["effects"] = []
	state["boss_alive"] = false
	_spawn_clock = 0.3
	state["director"] = {"mode": "rest", "resting": true, "explorers": [], "event_active": false,
		"threat_time": float(state.get("threat_time", 0.0)), "spawned": 0}
	var layout: Dictionary = StageLayouts.build(stage)
	for key in ["world_size", "floor_y", "spawn", "stage_name", "biome", "platforms", "landmarks"]:
		state[key] = layout[key]
	state["gate"] = {"pos": layout["gate"], "active": false, "charge": 0.0, "ready": false}
	var chests: Array = []
	var groups: Dictionary = {}
	var group_slots: Dictionary = {}
	var group_rewards: Dictionary = {}
	var facility_counts: Dictionary = {}
	for site_value in Array(layout["facility_sites"]):
		var site: Dictionary = site_value
		var type: String = str(site["type"])
		var number: int = int(facility_counts.get(type, 0))
		facility_counts[type] = number + 1
		var cost: int = 25 + (stage - 1) * 8 + mini(number, 4) * 3
		var item: String = ""
		match type:
			"choice":
				var local_group: int = int(site.get("group", 0))
				if not groups.has(local_group):
					groups[local_group] = _id()
					group_slots[local_group] = 0
					group_rewards[local_group] = _shop_options()
				var slot_index: int = int(group_slots[local_group])
				group_slots[local_group] = slot_index + 1
				item = str(Array(group_rewards[local_group])[slot_index % 3])
				cost = 32 + stage * 5
			"blood":
				cost = 18 + stage * 4
				item = _random_item(stage > 1, "trial")
			"combat":
				cost = 0
				item = _random_loot("trial")
			"equipment":
				cost = 38 + stage * 6
				item = _random_equipment()
			_:
				item = _random_item(false, "cache") if bool(site.get("starter", false)) else _random_loot("cache")
		var chest: Dictionary = _make_chest(type, site["pos"], cost, item)
		if type == "choice":
			chest["group"] = groups[int(site.get("group", 0))]
		chests.append(chest)
		state["chests"] = chests
	state["chests"] = chests
	var slot: int = 0
	for player_value in Dictionary(state["players"]).values():
		var player: Dictionary = player_value
		player["pos"] = Vector2(state["spawn"]) + Vector2(slot * 44.0, 0.0)
		player["vel"] = Vector2.ZERO
		player["hp"] = float(player["max_hp"])
		player["dead"] = false
		player["grounded"] = true
		player["invuln"] = 2.0
		player["revive"] = 0.0
		player["revive_timer"] = 0.0
		player["fire_cd"] = 0.0
		player["skill_cd"] = 0.0
		player["dash_cd"] = 0.0
		player["dash_timer"] = 0.0
		player["drop_timer"] = 0.0
		player["shield"] = 0.0
		player["shield_timer"] = 0.0
		player["jumps"] = 0
		player["phoenix_spent"] = 0
		player["chrono_timer"] = 0.0
		player["momentum_timer"] = 0.0
		player["nova_cd"] = 0.0
		player["attack_count"] = 0
		_reset_exploration(player, true)
		slot += 1
	_update_difficulty()
	_emit("stage", state["spawn"], {"stage": stage, "stage_name": state["stage_name"]})

func _make_chest(type: String, position: Vector2, cost: int, item: String) -> Dictionary:
	return {"id": _id(), "pos": position, "cost": cost, "opened": false, "item": item,
		"type": type, "group": -1, "locked": false, "status": "idle", "remaining": 0}

func _surface_below(x: float, from_y: float) -> float:
	var surface: float = _floor_y()
	for platform_value in Array(state["platforms"]):
		var platform: Rect2 = platform_value
		if x >= platform.position.x and x <= platform.end.x and platform.position.y >= from_y:
			surface = minf(surface, platform.position.y)
	return surface


func _world_size() -> Vector2:
	return state.get("world_size", WORLD_SIZE)


func _floor_y() -> float:
	return float(state.get("floor_y", _world_size().y - 80.0))


func _update_difficulty() -> void:
	# Elapsed expedition time now raises threat even while resting. Rest only
	# suppresses ambient spawning; it never banks future enemy waves.
	state["threat_time"] = maxf(0.0, float(state.get("time", 0.0)) - 45.0)
	state["difficulty"] = 1.0 + float(state["threat_time"]) / 120.0 + (int(state.get("stage", 1)) - 1) * 0.45
	state["tier"] = maxi(1, int(floor(float(state["difficulty"]))))
	state["difficulty_tier"] = int(state["tier"])


func _visual_data(owner: int) -> Dictionary:
	var player: Dictionary = Dictionary(state.get("players", {})).get(owner, {})
	var count: int = 0
	if not player.is_empty():
		for item in ["overclock", "capacitor", "arc", "ember", "toxin", "echo", "piercer", "resonator", "nova"]:
			count += _stacks(player, item)
	var strength: int = 0 if count == 0 else (1 if count < 4 else (2 if count < 8 else 3))
	return {"visual_stacks": count, "visual_strength": strength}


func _random_item(allow_harm: bool = true, source: String = "ambient", excluded: Array = []) -> String:
	var catalog: Array = item_catalog()
	catalog = catalog.filter(func(entry: Dictionary) -> bool:
		return (allow_harm or str(entry["warning"]).is_empty()) and str(entry["id"]) not in excluded
	)
	return _weighted_loot(catalog, source)


func _random_loot(source: String = "ambient") -> String:
	# Category and rarity are independent decisions. A depleted equipment
	# category safely becomes a passive instead of returning starter gear.
	var roll: float = _rng.randf()
	if roll < 0.88:
		return _random_item(true, source)
	var category: String = "weapon" if roll < 0.95 else "equipment"
	var candidates: Array = _gear_candidates(category, true)
	if candidates.is_empty():
		var fallback: String = _least_recent_gear(_gear_candidates(category, false), false)
		if not fallback.is_empty():
			_remember_loot(fallback)
			return fallback
		return _random_item(true, source)
	return _weighted_loot(candidates, source)


func _least_recent_gear(candidates: Array, allow_single_repeat: bool) -> String:
	if candidates.is_empty():
		return ""
	var history: Array = Dictionary(state.get("loot_history", {})).get("gear", [])
	if not allow_single_repeat and candidates.size() == 1 and not history.is_empty() and str(history.back()) == str(Dictionary(candidates[0])["id"]):
		return ""
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return history.rfind(str(a["id"])) < history.rfind(str(b["id"]))
	)
	return str(Dictionary(candidates[0])["id"])


func _random_equipment(source: String = "equipment", excluded: Array = []) -> String:
	var candidates: Array = _gear_candidates("", true)
	candidates = candidates.filter(func(entry: Dictionary) -> bool: return str(entry["id"]) not in excluded)
	if candidates.is_empty():
		# A dedicated vault may reuse the least recently offered gear, but
		# never currently equipped gear, visible ground gear, or starters.
		candidates = _gear_candidates("", false)
		candidates = candidates.filter(func(entry: Dictionary) -> bool: return str(entry["id"]) not in excluded)
		if not candidates.is_empty():
			var result: String = _least_recent_gear(candidates, true)
			_remember_loot(result)
			return result
	if candidates.is_empty():
		return _random_item(true, source, excluded)
	return _weighted_loot(candidates, source)


func _gear_candidates(category: String, respect_recent: bool) -> Array:
	var unavailable: Array = ["pulse_rifle", "arc_blade", "grenade", "shockwave"]
	for player_value in Dictionary(state.get("players", {})).values():
		var player: Dictionary = player_value
		unavailable.append(str(player.get("weapon", "")))
		unavailable.append(str(player.get("equipment", "")))
	for pickup_value in Array(state.get("pickups", [])):
		var pickup: Dictionary = pickup_value
		if str(pickup.get("kind", "")) == "item":
			unavailable.append(str(pickup.get("item", "")))
	# Unopened facilities already advertise their reward; reserve those IDs
	# too so a monster cannot offer an identical weapon next to its vault.
	for chest_value in Array(state.get("chests", [])):
		var chest: Dictionary = chest_value
		if not bool(chest.get("opened", false)) and not bool(chest.get("locked", false)):
			unavailable.append(str(chest.get("item", "")))
	if respect_recent:
		unavailable.append_array(Dictionary(state.get("loot_history", {})).get("gear", []))
	var catalog: Array = weapon_catalog() + equipment_catalog()
	return catalog.filter(func(entry: Dictionary) -> bool:
		return (category.is_empty() or str(entry["category"]) == category) and str(entry["id"]) not in unavailable
	)


func rarity_weights(source: String = "ambient") -> Array:
	var stage: int = clampi(int(state.get("stage", 1)), 1, 3)
	if source in ["boss"]:
		return [maxf(2.0, 12.0 - stage * 3.0), 35.0 - stage * 2.0, 41.0, 12.0 + stage * 5.0]
	if source in ["trial", "combat", "equipment"]:
		return [30.0 - stage * 5.0, 40.0, 25.0 + stage * 3.0, 5.0 + stage * 2.0]
	return [65.0 - (stage - 1) * 11.0, 26.0 + (stage - 1) * 4.0, 8.0 + (stage - 1) * 5.0, 1.0 + (stage - 1) * 2.0]


func _weighted_loot(candidates: Array, source: String) -> String:
	if candidates.is_empty():
		return "vitality"
	var weights: Array = rarity_weights(source)
	var tier_counts: Array = [0, 0, 0, 0]
	for entry_value in candidates:
		var entry: Dictionary = entry_value
		var rank: int = Content.rarity_rank(str(entry["rarity"]))
		tier_counts[rank] = int(tier_counts[rank]) + 1
	var history: Array = Dictionary(state.get("loot_history", {})).get("passive", [])
	var sums: Array = []
	var total: float = 0.0
	for entry_value in candidates:
		var entry: Dictionary = entry_value
		var rank: int = Content.rarity_rank(str(entry["rarity"]))
		var weight: float = float(weights[rank]) / maxi(1, int(tier_counts[rank]))
		if str(entry["category"]) == "passive" and str(entry["id"]) in history:
			weight *= 0.25
		total += weight
		sums.append(total)
	var roll: float = _rng.randf() * total
	for index in range(candidates.size()):
		if roll <= float(sums[index]):
			var selected: String = str(Dictionary(candidates[index])["id"])
			_remember_loot(selected)
			return selected
	return str(Dictionary(candidates.back())["id"])


func _remember_loot(id: String) -> void:
	var definition: Dictionary = loot_definition(id)
	var key: String = "passive" if str(definition.get("category", "passive")) == "passive" else "gear"
	var history: Dictionary = state.get("loot_history", {"gear": [], "passive": []})
	var records: Array = history.get(key, [])
	records.append(id)
	while records.size() > (4 if key == "passive" else 8):
		records.pop_front()
	history[key] = records
	state["loot_history"] = history


func _shop_options() -> Array:
	var result: Array = []
	result.append(_random_item(false, "cache", result))
	result.append(_random_item(true, "cache", result))
	if _rng.randf() < 0.4:
		result.append(_random_equipment("cache", result))
	else:
		result.append(_random_item(true, "cache", result))
	return result

func _stacks(player: Dictionary, item: String) -> int:
	var inventory: Dictionary = player.get("items", {})
	return int(inventory.get(item, 0))


func _damage_scale(player: Dictionary) -> float:
	var momentum: float = minf(0.6, _stacks(player, "momentum") * 0.15) if float(player.get("momentum_timer", 0.0)) > 0.0 else 0.0
	return (1.0 + _stacks(player, "capacitor") * 0.12) * (1.0 + _stacks(player, "glass") * 0.30) * (1.0 + momentum)


func _enemy_damage_scale() -> float:
	return 1.0 + (float(state["difficulty"]) - 1.0) * 0.16


func _nearest_enemy(position: Vector2, radius: float, excluded: Array = []) -> Dictionary:
	var selected: Dictionary = {}
	var best: float = radius * radius
	for enemy_value in Array(state.get("enemies", [])):
		var enemy: Dictionary = enemy_value
		if float(enemy["hp"]) <= 0.0 or int(enemy["id"]) in excluded:
			continue
		var distance: float = position.distance_squared_to(enemy["pos"])
		if distance < best:
			best = distance
			selected = enemy
	return selected


func _projectile_secondary(projectile: Dictionary, target: Dictionary) -> void:
	var owner: int = int(projectile["owner"])
	var player: Dictionary = Dictionary(state["players"]).get(owner, {})
	var scale: float = _damage_scale(player) if not player.is_empty() else 1.0
	if str(projectile["kind"]) == "storm":
		var excluded: Array = [int(target["id"])]
		var origin: Vector2 = target["pos"]
		for index in range(2):
			var chained: Dictionary = _nearest_enemy(origin, 240.0, excluded)
			if chained.is_empty():
				break
			excluded.append(int(chained["id"]))
			_emit("hit", chained["pos"], {"amount": 20.0 * scale, "crit": false, "arc_from": origin, "owner": owner})
			_damage_enemy(chained, 20.0 * scale, owner, false, 1)
			origin = chained["pos"]
	elif str(projectile["kind"]) == "lance":
		_explode(target["pos"], 70.0, 22.0 * scale, owner, "player", 1, "lance")


func _step_enemy_status(enemy: Dictionary, dt: float) -> void:
	for key in ["slow_timer", "stun_timer"]:
		enemy[key] = maxf(0.0, float(enemy.get(key, 0.0)) - dt)
	enemy["dot_tick"] = float(enemy.get("dot_tick", 0.0)) + dt
	if float(enemy["dot_tick"]) >= 0.25:
		enemy["dot_tick"] = 0.0
		for status in ["poison", "burn"]:
			if float(enemy.get(status + "_timer", 0.0)) > 0.0:
				_damage_enemy(enemy, float(enemy.get(status + "_dps", 0.0)) * 0.25, int(enemy.get(status + "_owner", -1)), false, 1)
	for key in ["poison_timer", "burn_timer"]:
		enemy[key] = maxf(0.0, float(enemy.get(key, 0.0)) - dt)


func _step_deployables(dt: float) -> void:
	var kept: Array = []
	for turret_value in Array(state.get("deployables", [])):
		var turret: Dictionary = turret_value
		turret["ttl"] = float(turret["ttl"]) - dt
		if float(turret["ttl"]) <= 0.0 or not Dictionary(state["players"]).has(int(turret["owner"])):
			continue
		turret["fire_cd"] = float(turret["fire_cd"]) - dt
		if float(turret["fire_cd"]) <= 0.0:
			var target: Dictionary = _nearest_enemy(turret["pos"], 650.0)
			if not target.is_empty():
				var aim: Vector2 = (Vector2(target["pos"]) - Vector2(turret["pos"])).normalized()
				_spawn_projectile(Vector2(turret["pos"]) + aim * 18.0, aim * 1000.0, "player", "bullet", float(turret["damage"]), int(turret["owner"]), 0.7, 4.0)
				_emit("shoot", turret["pos"], {"owner": turret["owner"], "aim": aim, "kind": "turret"})
				turret["fire_cd"] = 0.35
		kept.append(turret)
	state["deployables"] = kept


func _step_effects(dt: float) -> void:
	var kept: Array = []
	for effect_value in Array(state.get("effects", [])):
		var effect: Dictionary = effect_value
		effect["delay"] = float(effect["delay"]) - dt
		if float(effect["delay"]) <= 0.0:
			_explode(effect["pos"], float(effect["radius"]), float(effect["damage"]), int(effect["owner"]), "player", 0, str(effect["kind"]))
		else:
			kept.append(effect)
	state["effects"] = kept


func _enemy_radius(enemy: Dictionary) -> float:
	match str(enemy["kind"]):
		"boss": return 44.0
		"drone": return 18.0
		"spitter": return 21.0
		_: return 19.0


func _alive_count() -> int:
	var count: int = 0
	for player_value in Dictionary(state["players"]).values():
		var player: Dictionary = player_value
		if not bool(player["dead"]):
			count += 1
	return count


func _id() -> int:
	_next_id += 1
	return _next_id


func _emit(type: String, position: Vector2, extra: Dictionary = {}) -> void:
	if events.size() >= 64:
		if type not in ["notice", "pickup", "interact", "gate", "revive", "stage", "win", "lose"]:
			return
		# Keep intentional interactions and progression feedback visible even
		# when a large proc chain fills the cosmetic hit/shot event budget.
		var replaced: bool = false
		for index in range(events.size()):
			if str(Dictionary(events[index]).get("type", "")) in ["hit", "shoot", "slash", "explosion", "death"]:
				events.remove_at(index)
				replaced = true
				break
		if not replaced:
			return
	var event: Dictionary = {"type": type, "pos": position}
	event.merge(extra, true)
	if type in ["shoot", "hit", "explosion", "slash", "dash"]:
		var actor: int = int(extra.get("owner", extra.get("player", -1)))
		if bool(extra.get("friendly", false)):
			actor = -1
		event.merge(_visual_data(actor), false)
	events.append(event)
