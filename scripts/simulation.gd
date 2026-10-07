class_name SideSimulation
extends RefCounted

const Content = preload("res://scripts/content.gd")
const StageLayouts = preload("res://scripts/stage_layouts.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const WeaponAction = preload("res://scripts/weapon_action_motion.gd")
const Guidance = preload("res://scripts/projectile_guidance.gd")
const Procs = preload("res://scripts/proc_rules.gd")
const EnemyCatalog = preload("res://scripts/enemy_catalog.gd")
const Locale = preload("res://scripts/localization.gd")
const BeamEnvelope = preload("res://scripts/beam_envelope.gd")

## Authoritative, scene-independent game rules. State contains only serializable
## values. All positions are centers; platforms are one-way from above.

const WORLD_SIZE: Vector2 = Vector2(3200.0, 1100.0)
const PLAYER_HALF: Vector2 = Vector2(12.0, 21.0)
const GRAVITY: float = 1750.0
const JUMP_SPEED: float = 665.0
const JUMP_RELEASE_SPEED: float = 260.0
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
const MAX_COIN_PICKUPS: int = 64
const MAX_HAZARDS: int = 24
const GATE_SECONDS: float = 22.0

var state: Dictionary = {}
var events: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_id: int = 100
var _spawn_clock: float = 1.8
var _projectiles_stepping: bool = false
var _pending_projectiles: Array = []


static func character_catalog() -> Array:
	return [
		{"id": "ranger", "name": "游侠", "description": "初始：脉冲步枪 + 震荡手雷\n100生命；Shift专属相位闪身。武器与主动装备可替换，角色技能保持不变。", "color": Color("65e2d6")},
		{"id": "vanguard", "name": "先锋", "description": "初始：共鸣弧刃 + 裂地冲击\n145生命；Shift专属铁壁反击，减伤蓄能后释放周围冲击。武器与主动装备可替换，角色技能保持不变。", "color": Color("ffa66a")},
	]

static func movement_ability(player: Dictionary) -> Dictionary:
	var definition: Dictionary = Content.movement_ability(str(player.get("character", "ranger")))
	var stacks: int = maxi(0, int(Dictionary(player.get("items", {})).get("thruster", 0)))
	definition["base_cooldown"] = definition.cooldown
	definition["cooldown"] = maxf(float(definition.minimum_cooldown), float(definition.cooldown) / (1.0 + stacks * 0.1))
	return definition


static func item_catalog() -> Array:
	return Content.passives()

static func character_passive(character: String) -> Dictionary:
	return Content.character_passive(character)


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
		"players": {}, "enemies": [], "projectiles": [], "pickups": [], "coin_pickups": [],
		"chests": [], "platforms": [], "world_size": WORLD_SIZE,
		"deployables": [], "effects": [], "proc_effects": [], "hazards": [], "loot_history": {"gear": [], "passive": []},
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
		"kills": 0, "revive": 0.0, "coyote": 0.0, "jumps": 0, "jump_rising": false, "land_ready": false,
		"drop_timer": 0.0, "dash_timer": 0.0, "dash_dir": Vector2.RIGHT,
		"dash_kind": "", "dash_speed": DASH_SPEED, "dash_id": 0, "dash_hits": [], "dash_damage": 0.0, "stun_timer": 0.0,
		"guard_timer": 0.0, "guard_absorbed": 0.0, "guard_id": 0,
		"hurt_timer": 0.0, "revive_timer": 0.0, "interact_cd": 0.0, "shield_timer": 0.0,
		"explore_anchor": position, "explore_sites": [position], "explore_window": 0.0, "explore_budget": 0,
		"chrono_timer": 0.0, "momentum_timer": 0.0, "nova_cd": 0.0, "attack_count": 0, "phoenix_spent": 0,
	}
	state["players"] = players
	Procs.reset(players[id])


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
	# A warning first appears at this step's end. It must receive its entire
	# advertised windup starting with the next step, just like its attacker.
	var new_hazard_min_id: int = _next_id + 1
	_step_enemies(dt)
	_step_deployables(dt)
	_step_effects(dt)
	_step_proc_effects(dt)
	_step_projectiles(dt)
	_step_hazards(dt, new_hazard_min_id)
	_cleanup_enemies()
	_step_challenges()
	_step_coin_pickups(dt)
	_step_pickups(dt)
	_step_gate(dt)
	_step_director(dt)
	var alive: int = _alive_count()
	if not players.is_empty() and alive == 0:
		_flush_coin_pickups()
		state["phase"] = "lost"
		_emit("lose", _world_size() * Vector2(0.5, 0.6))


func _step_player(player: Dictionary, command: Dictionary, dt: float) -> void:
	Procs.tick(player, dt)
	for key in ["fire_cd", "skill_cd", "invuln", "hurt_timer", "interact_cd", "nova_cd"]:
		player[key] = maxf(0.0, float(player.get(key, 0.0)) - dt)
	if float(player.get("shield_timer", 0.0)) > 0.0:
		player["shield_timer"] = maxf(0.0, float(player["shield_timer"]) - dt)
		if float(player["shield_timer"]) <= 0.0:
			player["shield"] = 0.0
	if bool(player["dead"]):
		Procs.cancel(player)
		_cancel_movement_ability(player)
		_cancel_guard(player)
		player.erase("melee")
		player.erase("attack_pose")
		player["jump_rising"] = false
		player["land_ready"] = false
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
				player["jump_rising"] = false
				_reset_exploration(player, false)
				_emit("revive", player["pos"], {"player": player["id"]})
		return
	var previous_dash_id: int = int(player.get("dash_id", 0))
	var controlled: bool = float(player.get("stun_timer", 0.0)) > 0.0
	var stored_charge: float = float(player.get("guard_absorbed", 0.0))
	var guard_finished: bool = _move_player(player, command, dt, true)
	if int(player.get("dash_id", 0)) > previous_dash_id:
		var ability: Dictionary = movement_ability(player)
		player["invuln"] = maxf(float(player["invuln"]), float(ability.invuln))
		if str(ability.id) == "guard_burst":
			_emit("ability", player["pos"], {"ability": "guard_burst", "phase": "start", "player": player.id,
				"duration": ability.duration, "ability_id": player.guard_id})
		else:
			_emit("dash", player["pos"], {"aim": player["dash_dir"], "player": player["id"],
				"ability": ability.id, "duration": ability.duration, "ability_id": player["dash_id"]})
	if guard_finished:
		_release_guard(player, stored_charge)
	_step_melee(player, dt)
	if player.has("attack_pose"):
		player.attack_pose.elapsed = float(player.attack_pose.elapsed) + dt
		if str(player.attack_pose.weapon) != str(player.get("weapon", "")) or float(player.attack_pose.elapsed) >= float(player.attack_pose.duration):
			player.erase("attack_pose")
	var moss: int = _stacks(player, "moss")
	if _stacks(player, "battery") > 0 and float(player["hurt_timer"]) <= 0.0:
		var shield_cap: float = minf(float(player["max_hp"]) * 0.6, _stacks(player, "battery") * 8.0)
		if float(player["shield"]) < shield_cap:
			player["shield"] = minf(shield_cap, float(player["shield"]) + dt * 4.0 * _stacks(player, "battery"))
	if moss > 0:
		var regen: float = moss * 0.65 * dt * (2.0 if float(player["hurt_timer"]) <= 1.0 else 1.0)
		player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + regen)
	if not controlled and bool(command.get("fire", false)) and float(player["fire_cd"]) <= 0.0:
		_fire_weapon(player)
	if not controlled and bool(command.get("skill", false)) and float(player["skill_cd"]) <= 0.0:
		_use_skill(player)
	if bool(command.get("interact", false)) and float(player["interact_cd"]) <= 0.0:
		player["interact_cd"] = 0.2
		_interact(player, command.get("interact_target", {}))


func _move_player(player: Dictionary, command: Dictionary, dt: float, report_events: bool = false) -> bool:
	var controlled: bool = float(player.get("stun_timer", 0.0)) > 0.0
	player["stun_timer"] = maxf(0.0, float(player.get("stun_timer", 0.0)) - dt)
	if controlled:
		_cancel_movement_ability(player)
		_cancel_guard(player)
		player.erase("melee")
		player.erase("attack_pose")
	player["chrono_timer"] = maxf(0.0, float(player.get("chrono_timer", 0.0)) - dt)
	player["momentum_timer"] = maxf(0.0, float(player.get("momentum_timer", 0.0)) - dt)
	var guard_finished: bool = float(player.get("guard_timer", 0.0)) > 0.0 and float(player.get("guard_timer", 0.0)) <= dt
	player["guard_timer"] = maxf(0.0, float(player.get("guard_timer", 0.0)) - dt)
	if float(player["guard_timer"]) <= 0.0: player["guard_absorbed"] = 0.0
	var direction: Vector2 = command.get("aim", player.get("aim", Vector2.RIGHT))
	if direction.is_finite() and direction.length_squared() > 0.0001:
		player["aim"] = direction.normalized()
	var move: float = clampf(float(command.get("move", 0.0)), -1.0, 1.0)
	if controlled: move = 0.0
	var velocity: Vector2 = player.get("vel", Vector2.ZERO)
	var position: Vector2 = player.get("pos", state.get("spawn", Vector2(210.0, _floor_y() - PLAYER_HALF.y)))
	var grounded: bool = bool(player.get("grounded", false))
	var was_grounded: bool = grounded
	var jumped: bool = false
	var double_jump: bool = false
	# New arrivals must establish ground contact before their first landing
	# sound. Prediction maintains this state too, but never emits feedback.
	if grounded:
		player["land_ready"] = true
		player["fall_peak_y"] = position.y
	else:
		player["fall_peak_y"] = minf(float(player.get("fall_peak_y", position.y)), position.y)
	# Only a deliberate jump owns variable-height control. Dash momentum,
	# knockback and simply walking off a ledge must never be cut by this input.
	if grounded or velocity.y >= 0.0 or float(player.get("dash_timer", 0.0)) > 0.0:
		player["jump_rising"] = false
	player["coyote"] = 0.105 if grounded else maxf(0.0, float(player.get("coyote", 0.0)) - dt)
	player["drop_timer"] = maxf(0.0, float(player.get("drop_timer", 0.0)) - dt)
	player["dash_cd"] = maxf(0.0, float(player.get("dash_cd", 0.0)) - dt)
	player["dash_timer"] = maxf(0.0, float(player.get("dash_timer", 0.0)) - dt)
	if float(player["dash_timer"]) <= 0.0:
		_cancel_movement_ability(player)
	var speed: float = MOVE_SPEED * (1.0 + minf(1.1, _stacks(player, "thruster") * 0.09)) * (1.3 if float(player["chrono_timer"]) > 0.0 else 1.0)
	if bool(command.get("drop", false)):
		# Down+jump is only a drop request, even on the bottom floor.
		if position.y + PLAYER_HALF.y < _floor_y() - 5.0:
			player["drop_timer"] = 0.22
			position.y += 5.0
			velocity.y = maxf(velocity.y, 100.0)
			grounded = false
			player["coyote"] = 0.0
			player["jump_rising"] = false
	elif not controlled and bool(command.get("jump", false)):
		if grounded or float(player["coyote"]) > 0.0:
			velocity.y = -JUMP_SPEED
			player["jumps"] = 1
			player["coyote"] = 0.0
			player["jump_rising"] = true
			grounded = false
			jumped = true
		elif int(player.get("jumps", 0)) < 1 + _stacks(player, "feather") and _stacks(player, "feather") > 0:
			velocity.y = -JUMP_SPEED * 0.91
			player["jumps"] = maxi(1, int(player.get("jumps", 0))) + 1
			player["jump_rising"] = true
			jumped = true
			double_jump = true
	if not controlled and bool(command.get("dash", false)) and float(player["dash_cd"]) <= 0.0:
		var ability: Dictionary = movement_ability(player)
		var dash_direction: Vector2 = Vector2(move, 0.0)
		if absf(move) < 0.1:
			dash_direction = player.get("aim", Vector2.RIGHT)
		if bool(ability.horizontal):
			dash_direction = Vector2(-1.0 if dash_direction.x < 0.0 else 1.0, 0.0)
		player["dash_dir"] = dash_direction.normalized()
		player["dash_cd"] = ability.cooldown
		player["dash_id"] = int(player.get("dash_id", 0)) + 1
		player["momentum_timer"] = 1.2
		if str(ability.id) == "guard_burst":
			_cancel_movement_ability(player)
			player["guard_timer"] = ability.duration
			player["guard_absorbed"] = 0.0
			player["guard_id"] = player["dash_id"]
		else:
			player["dash_timer"] = ability.duration
			player["dash_kind"] = ability.id
			player["dash_speed"] = ability.speed
	if float(player["guard_timer"]) > 0.0:
		var guarding_ability: Dictionary = Content.movement_ability("vanguard")
		speed *= float(guarding_ability.move_scale)
		# Brace horizontal momentum immediately, without changing the jump arc.
		velocity.x = clampf(velocity.x, -speed, speed)
	if float(player["dash_timer"]) > 0.0:
		player["jump_rising"] = false
		velocity = Vector2(player["dash_dir"]) * float(player.get("dash_speed", DASH_SPEED))
	else:
		# Missing held state preserves the original full arc for old commands.
		# A release consumes this jump's control once; pressing again cannot
		# restore upward speed without a separate, available feather jump.
		if bool(player.get("jump_rising", false)) and not bool(command.get("jump_held", true)):
			velocity.y = maxf(velocity.y, -JUMP_RELEASE_SPEED)
			player["jump_rising"] = false
		velocity.x = move_toward(velocity.x, move * speed, (2500.0 if grounded else 1800.0) * dt)
		velocity.y = minf(1100.0, velocity.y + GRAVITY * dt)
	if jumped:
		player["land_ready"] = true
	var result: Dictionary = _move_body(position, velocity, dt, PLAYER_HALF, float(player["drop_timer"]) > 0.0)
	player["pos"] = result["pos"]
	player["vel"] = result["vel"]
	player["grounded"] = result["grounded"]
	if report_events:
		if jumped and float(player["dash_timer"]) <= 0.0:
			_emit("jump", player["pos"], {"player": player["id"], "double": double_jump})
		if not was_grounded and bool(result["grounded"]) and bool(player.get("land_ready", false)) and velocity.y >= 120.0:
			_emit("land", player["pos"], {"player": player["id"], "impact_speed": velocity.y})
			_landing_proc(player, maxf(0.0, Vector2(player.pos).y - float(player.get("fall_peak_y", player.pos.y))))
	if bool(result["grounded"]):
		player["jumps"] = 0
		player["land_ready"] = true
	if bool(result["grounded"]) or Vector2(result["vel"]).y >= 0.0:
		player["jump_rising"] = false
	if Vector2(player["pos"]).y > _world_size().y + 80.0:
		# Safety floor recovery, also identical during local prediction.
		player["pos"] = Vector2(clampf(position.x, 30.0, _world_size().x - 30.0), _floor_y() - PLAYER_HALF.y - 24.0)
		player["vel"] = Vector2.ZERO
		player["jump_rising"] = false
		player["land_ready"] = false
		player["fall_peak_y"] = Vector2(player.pos).y
		_cancel_movement_ability(player)
		_cancel_guard(player)
		guard_finished = false
	return guard_finished


func _cancel_movement_ability(player: Dictionary) -> void:
	player["dash_timer"] = 0.0
	player["dash_kind"] = ""
	player["dash_hits"] = []
	player["dash_damage"] = 0.0
	player["dash_speed"] = DASH_SPEED


func _cancel_guard(player: Dictionary) -> void:
	player["guard_timer"] = 0.0
	player["guard_absorbed"] = 0.0


## Only the authoritative player step consumes a naturally completed guard.
## Client movement replay advances its stance but never calls this function.
func _release_guard(player: Dictionary, charge: float) -> void:
	var ability: Dictionary = Content.movement_ability("vanguard")
	var absorbed: float = clampf(charge, 0.0, float(ability.charge_cap))
	var damage: float = (float(ability.damage) + absorbed * float(ability.charge_ratio)) * _damage_scale(player)
	# Emit once before target hits so heavy contact cannot consume the feedback
	# budget first. This is a counter, not a recursive item-triggering explosion.
	_emit("ability", player["pos"], {"ability": "guard_burst", "phase": "release", "player": player.id,
		"ability_id": player.guard_id, "radius": ability.radius, "damage": damage, "absorbed": absorbed})
	for enemy: Dictionary in Array(state["enemies"]):
		if float(enemy.get("hp", 0.0)) <= 0.0: continue
		if Vector2(enemy.pos).distance_to(player.pos) > float(ability.radius) + _enemy_radius(enemy): continue
		var stun: float = float(ability.boss_stun) if str(enemy.kind) == "boss" else float(ability.stun)
		enemy["stun_timer"] = maxf(float(enemy.get("stun_timer", 0.0)), stun)
		_damage_enemy(enemy, damage, int(player.id), false, 1)


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
	var aim: Vector2 = WeaponPose.normalized_aim(Vector2(player["aim"]))
	var position: Vector2 = player["pos"]
	var shoulder: Vector2 = WeaponPose.shoulder_position(position)
	var muzzle: Vector2 = WeaponPose.muzzle_position(player, aim)
	var weapon: String = str(player.get("weapon", "pulse_rifle"))
	player["fire_cd"] = attack_interval(player)
	player["attack_count"] = int(player.get("attack_count", 0)) + 1
	if weapon != "arc_blade":
		player["attack_pose"] = {"id":int(player.attack_count), "weapon":weapon, "elapsed":0.0,
			"duration":WeaponAction.duration(weapon, float(player.fire_cd)), "aim":aim, "interval":float(player.fire_cd)}
	match weapon:
		"arc_blade":
			var duration: float = WeaponPose.melee_duration(float(player.fire_cd))
			player["melee"] = {"id": int(player.attack_count), "elapsed": 0.0, "duration": duration,
				"aim": aim, "struck": false, "damage": 24.0 * _damage_scale(player),
				"echo": _stacks(player, "echo") > 0 and int(player.attack_count) % 6 == 0}
			_emit("slash", muzzle, {"aim": aim, "radius": 105.0, "player": player["id"], "weapon": weapon,
				"phase": "start", "duration": duration, "attack_id": int(player.attack_count)})
		"scattergun":
			for pellet in range(6):
				var spread: float = (float(pellet) - 2.5) * 0.075 + _rng.randf_range(-0.012, 0.012)
				_spawn_projectile(muzzle, aim.rotated(spread) * 820.0, "player", "pellet", 8.0 * _damage_scale(player), int(player["id"]), 0.43, 4.0, shoulder)
			_emit("shoot", muzzle, {"aim": aim, "player": player["id"], "kind": "scattergun", "weapon": weapon})
		"railgun":
			_spawn_projectile(muzzle, aim * 2500.0, "player", "rail", 70.0 * _damage_scale(player), int(player["id"]), 0.6, 5.0, shoulder)
			_emit("shoot", muzzle, {"aim": aim, "player": player["id"], "kind": "railgun", "weapon": weapon})
		"flamethrower":
			_emit("slash", muzzle, {"aim": aim, "radius": 170.0, "player": player["id"], "kind": "flame", "weapon": weapon})
			for enemy_value in Array(state["enemies"]).duplicate():
				var enemy: Dictionary = enemy_value
				var offset: Vector2 = Vector2(enemy["pos"]) - position
				if offset.length() < 170.0 + _enemy_radius(enemy) and offset.normalized().dot(aim) > 0.55:
					_damage_enemy(enemy, 8.0 * _damage_scale(player), int(player["id"]), true, 0, int(player.attack_count))
					enemy["burn_timer"] = 2.0
					enemy["burn_dps"] = 5.0 * _damage_scale(player)
					enemy["burn_owner"] = int(player["id"])
		"boomerang":
			_spawn_projectile(muzzle, aim * 620.0, "player", "boomerang", 26.0 * _damage_scale(player), int(player["id"]), 1.3, 10.0, shoulder)
			_emit("shoot", muzzle, {"aim": aim, "player": player["id"], "kind": "boomerang", "weapon": weapon})
		"storm_staff":
			_spawn_projectile(muzzle, aim * 780.0, "player", "storm", 32.0 * _damage_scale(player), int(player["id"]), 1.25, 8.0, shoulder)
			_emit("shoot", muzzle, {"aim": aim, "player": player["id"], "kind": "storm", "weapon": weapon})
		"sun_lance":
			_spawn_projectile(muzzle, aim * 2400.0, "player", "lance", 120.0 * _damage_scale(player), int(player["id"]), 0.75, 8.0, shoulder)
			_emit("shoot", muzzle, {"aim": aim, "player": player["id"], "kind": "lance", "weapon": weapon})
		_:
			var spread: float = _rng.randf_range(-0.018, 0.018)
			_spawn_projectile(muzzle, aim.rotated(spread) * 1100.0, "player", "bullet", 8.0 * _damage_scale(player), int(player["id"]), 1.3, 3.0, shoulder)
			_emit("shoot", muzzle, {"aim": aim, "player": player["id"], "kind": "bullet", "weapon": weapon})
	if weapon != "arc_blade" and _stacks(player, "echo") > 0 and int(player["attack_count"]) % 6 == 0:
		_fire_echo(player)


func _fire_echo(player: Dictionary) -> void:
	var target: Dictionary = _nearest_enemy(Vector2(player.pos), 650.0)
	if not target.is_empty():
		_damage_enemy(target, 12.0 * mini(8, _stacks(player, "echo")) * _damage_scale(player), int(player["id"]), false, 1)
		_emit("explosion", target["pos"], {"radius": 55.0, "owner": player["id"], "kind": "echo", "team": "player"})


func _step_melee(player: Dictionary, dt: float) -> void:
	if not player.has("melee"):
		return
	if bool(player.get("dead", false)) or str(player.get("weapon", "")) != "arc_blade":
		player.erase("melee")
		return
	var melee: Dictionary = player.melee
	melee.elapsed = float(melee.elapsed) + maxf(0.0, dt)
	if not bool(melee.struck) and float(melee.elapsed) + 0.000001 >= WeaponPose.melee_impact_time(float(melee.duration)):
		# Mark before procs: recursive relic damage cannot resolve this swing twice.
		melee.struck = true
		var aim: Vector2 = melee.aim
		for enemy_value: Variant in Array(state["enemies"]).duplicate():
			var enemy: Dictionary = enemy_value
			var offset: Vector2 = Vector2(enemy["pos"]) - Vector2(player.pos)
			if float(enemy["hp"]) > 0.0 and offset.length() <= 110.0 + _enemy_radius(enemy) and (offset.length() < 34.0 or offset.normalized().dot(aim) > -0.12):
				_damage_enemy(enemy, float(melee.damage), int(player["id"]), true, 0, int(melee.id))
				if str(enemy["kind"]) != "boss":
					enemy["vel"] = Vector2(enemy["vel"]) + aim * 170.0
				player["hp"] = minf(float(player["max_hp"]), float(player["hp"]) + 0.35)
		if bool(melee.get("echo", false)):
			_fire_echo(player)
	if float(melee.elapsed) >= float(melee.duration):
		player.erase("melee")


func _use_skill(player: Dictionary) -> void:
	var aim: Vector2 = player["aim"]
	var position: Vector2 = player["pos"]
	var equipment: String = str(player.get("equipment", "grenade"))
	var definition: Dictionary = loot_definition(equipment)
	var cooldown_scale: float = maxf(0.35, 1.0 / (1.0 + _stacks(player, "coolant") * 0.16))
	player["skill_cd"] = float(definition.get("cooldown", 5.0)) * cooldown_scale
	match equipment:
		"shockwave":
			_cancel_movement_ability(player)
			_cancel_guard(player)
			player["jump_rising"] = false
			player["invuln"] = maxf(float(player["invuln"]), 0.45)
			player["dash_timer"] = 0.2
			player["dash_dir"] = aim
			player["dash_kind"] = "shockwave"
			player["dash_speed"] = DASH_SPEED
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
			var effects_before: int = effects.size()
			for index in range(3):
				if effects.size() >= 24:
					break
				var impact: Vector2 = position + aim * 300.0 + Vector2((index - 1) * 110.0, 0.0)
				impact.x = clampf(impact.x, 20.0, _world_size().x - 20.0)
				effects.append({"id": _id(), "kind": "meteor", "pos": impact, "delay": 0.5 + index * 0.25, "radius": 150.0, "damage": 140.0 * _damage_scale(player), "owner": player["id"]})
			state["effects"] = effects
			if effects.size() > effects_before:
				_emit("equipment", position, {"equipment": "meteor", "player": player["id"]})
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

func _spawn_projectile(position: Vector2, velocity: Vector2, team: String, kind: String, damage: float, owner: int, ttl: float, radius: float, sweep_origin: Vector2 = Vector2(INF, INF)) -> Dictionary:
	var projectiles: Array = state["projectiles"]
	if projectiles.size() + _pending_projectiles.size() >= MAX_PROJECTILES:
		return {}
	if _projectiles_stepping: projectiles = _pending_projectiles
	var player: Dictionary = Dictionary(state.get("players", {})).get(owner, {})
	var base_pierce: int = 3 if kind == "rail" else (6 if kind == "lance" else (4 if kind == "boomerang" else 1))
	var extra_pierce: int = mini(3, _stacks(player, "piercer")) if kind != "grenade" and not player.is_empty() else 0
	projectiles.append({"id": _id(), "pos": position, "origin": position, "travel_distance": 0.0, "vel": velocity, "team": team,
		"kind": kind, "ttl": ttl, "radius": radius, "damage": damage, "owner": owner,
		"hit_ids": [], "pierce": mini(9, base_pierce + extra_pierce), "max_pierce": mini(9, base_pierce + extra_pierce), "age": 0.0, "returning": false})
	var projectile: Dictionary = projectiles.back()
	if team == "player" and kind == "storm":
		var guidance: Dictionary = Guidance.lock(position, velocity, state["enemies"], Guidance.STORM)
		if not guidance.is_empty():
			projectile["guidance"] = guidance
	if sweep_origin.is_finite():
		projectile["sweep_origin"] = sweep_origin
		projectile["primary_attack"] = int(player.get("attack_count", 0))
	projectile.merge(_visual_data(owner), true)
	return projectile


func _step_projectiles(dt: float) -> void:
	var projectiles: Array = state["projectiles"]
	var kept: Array = []
	# Build at most one ID index per step; guided shots never scan the enemy
	# table again after launch, even when their original target disappears.
	var guidance_enemies: Dictionary = {}
	var guidance_index_ready: bool = false
	_projectiles_stepping = true
	for projectile_value in projectiles:
		var projectile: Dictionary = projectile_value
		if not _proc_projectile_valid(projectile): continue
		var previous: Vector2 = projectile["pos"]
		var sweep_origin: Vector2 = projectile.get("sweep_origin", previous)
		var launch_sweep: bool = projectile.has("sweep_origin")
		projectile.erase("sweep_origin")
		var velocity: Vector2 = projectile["vel"]
		var kind: String = projectile["kind"]
		var guidance: Dictionary = projectile.get("guidance", {})
		if bool(guidance.get("active", false)):
			var target_id: int = int(guidance.get("target_id", -1))
			var guide_target: Dictionary = {}
			if str(projectile["team"]) == "player":
				if not guidance_index_ready:
					for enemy: Dictionary in state["enemies"]:
						guidance_enemies[int(enemy.id)] = enemy
					guidance_index_ready = true
				guide_target = guidance_enemies.get(target_id, {})
			else:
				guide_target = Dictionary(state["players"]).get(target_id, {})
			velocity = Guidance.steer(projectile, guide_target, dt)
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
		projectile["travel_distance"] = float(projectile.get("travel_distance", 0.0)) + previous.distance_to(next)
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
				if launch_sweep:
					# The first collision path includes the barrel, but its hidden
					# shoulder-to-muzzle leg never becomes a visible bullet trail.
					var barrel_t: float = _segment_circle(sweep_origin, previous, enemy["pos"], _enemy_radius(enemy) + float(projectile["radius"]))
					hit_t = barrel_t * 0.5 if barrel_t >= 0.0 else (0.5 + hit_t * 0.5 if hit_t >= 0.0 else -1.0)
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
					if not _projectile_can_hit(projectile, enemy): continue
					_projectile_damage(projectile, enemy)
					projectile["hit_ids"].append(int(enemy["id"]))
					projectile["pierce"] = int(projectile["pierce"]) - 1
					if int(projectile["pierce"]) <= 0:
						if kind == "boomerang" and not bool(projectile.get("returning", false)):
							projectile["age"] = 0.5
						else:
							removed = true
						break
			elif not target.is_empty():
				if launch_sweep:
					projectile["pos"] = sweep_origin.lerp(previous, nearest_t * 2.0) if nearest_t <= 0.5 else previous.lerp(next, (nearest_t - 0.5) * 2.0)
				else:
					projectile["pos"] = previous.lerp(next, nearest_t)
				if kind == "grenade":
					_explode(projectile["pos"], 135.0, float(projectile["damage"]), int(projectile["owner"]), "player", 0)
				else:
					if _projectile_can_hit(projectile, target): _projectile_damage(projectile, target)
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
				_damage_player(target_player, float(projectile["damage"]), previous, {"attack_kind":str(projectile.get("kind","")),"enemy_id":int(projectile.get("enemy_id",-1)),"aim":Vector2(projectile.vel).normalized()})
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
	_projectiles_stepping = false
	kept.append_array(_pending_projectiles)
	_pending_projectiles.clear()
	state["projectiles"] = kept.filter(_proc_projectile_valid)


func _proc_projectile_valid(projectile: Dictionary) -> bool:
	if not bool(projectile.get("proc", false)): return true
	var owner: Dictionary = Dictionary(state["players"]).get(int(projectile["owner"]), {})
	return not owner.is_empty() and not bool(owner.get("dead", false)) and int(projectile.get("proc_epoch", -1)) == int(owner.get("proc_epoch", 0))


func _projectile_can_hit(projectile: Dictionary, enemy: Dictionary) -> bool:
	if str(projectile["kind"]) != "shock_wave": return true
	var owner: Dictionary = Dictionary(state["players"]).get(int(projectile["owner"]), {})
	if owner.is_empty(): return false
	var data: Dictionary = Procs.ensure(owner)
	if int(data.landing_group) != int(projectile.get("proc_group", -2)) or data.landing_hits.size() >= 8 or int(enemy.id) in data.landing_hits:
		return false
	data.landing_hits.append(int(enemy.id))
	return true


func _projectile_damage(projectile: Dictionary, enemy: Dictionary) -> void:
	var secondary: bool = bool(projectile.get("proc", false))
	_damage_enemy(enemy, float(projectile["damage"]), int(projectile["owner"]), not secondary, 1 if secondary else 0, 0 if secondary else int(projectile.get("primary_attack", 0)))
	if not secondary: _projectile_secondary(projectile, enemy)


func _launch_proc_missile(player: Dictionary, source: String, damage: float) -> bool:
	if player.is_empty() or bool(player.get("dead", false)): return false
	var origin: Vector2 = Vector2(player.pos) + Vector2(0, -15)
	var target: Dictionary = _nearest_enemy(origin, 600.0)
	if target.is_empty(): return false
	var direction: Vector2 = WeaponPose.normalized_aim(Vector2(target.pos) - origin).rotated(-0.30)
	var missile: Dictionary = _spawn_projectile(origin, direction * 500.0, "player", "seeker_missile", damage * _damage_scale(player), int(player.id), 1.6, 5.0)
	if missile.is_empty(): return false
	missile.merge({"proc": true, "proc_source": source, "proc_group": int(missile.id), "proc_epoch": int(player.get("proc_epoch", 0)), "pierce": 1, "max_pierce": 1}, true)
	missile["guidance"] = Guidance.lock(origin, direction * 500.0, [target], Procs.MISSILE)
	_emit("proc", origin, {"kind": source, "player": player.id, "owner": player.id, "proc_id": missile.id, "aim": direction, "duration": 0.3, "radius": 14.0})
	return true


func _direct_proc(player: Dictionary, critical: bool, killed: bool, primary_attack: int) -> void:
	if player.is_empty() or bool(player.get("dead", false)): return
	var data: Dictionary = Procs.ensure(player)
	if critical and _stacks(player, "missile_pod") > 0 and float(data.missile_cd) <= 0.0:
		# Start the cooldown before creating anything so procs cannot re-enter.
		data.missile_cd = 1.25
		_launch_proc_missile(player, "missile_pod", Procs.missile_damage(_stacks(player, "missile_pod")))
	if Procs.primary_hit(player, primary_attack):
		_launch_proc_missile(player, "pursuit_protocol", 8.0)
	if killed and _stacks(player, "frost_halo") > 0 and float(data.halo_cd) <= 0.0:
		var effects: Array = state.get("proc_effects", [])
		if effects.size() >= Procs.MAX_AURAS: return
		data.halo_cd = 4.0
		var stacks: int = _stacks(player, "frost_halo")
		var aura: Dictionary = {"id": _id(), "kind": "frost_halo", "owner": int(player.id), "pos": Vector2(player.pos), "radius": Procs.halo_radius(stacks),
			"ttl": 1.5, "duration": 1.5, "pulse": 0.5, "damage": Procs.halo_damage(stacks) * _damage_scale(player), "slow_factor": 0.75}
		effects.append(aura)
		state["proc_effects"] = effects
		_emit("proc", player.pos, {"kind": "frost_halo", "player": player.id, "owner": player.id, "proc_id": aura.id, "radius": aura.radius, "duration": aura.duration})


func _landing_proc(player: Dictionary, height: float) -> void:
	var stacks: int = _stacks(player, "landing_coil")
	var data: Dictionary = Procs.ensure(player)
	if stacks <= 0 or height < 90.0 or float(data.landing_cd) > 0.0 or bool(player.get("dead", false)): return
	if Array(state["projectiles"]).size() + _pending_projectiles.size() > MAX_PROJECTILES - 2: return
	data.landing_cd = 2.0
	data.landing_group = _id()
	data.landing_hits = []
	var origin: Vector2 = Vector2(player.pos) + Vector2(0, 13)
	for direction: float in [-1.0, 1.0]:
		var wave: Dictionary = _spawn_projectile(origin, Vector2(direction * 420.0, 0), "player", "shock_wave", Procs.landing_damage(stacks) * _damage_scale(player), int(player.id), 0.45, 13.0)
		wave.merge({"proc": true, "proc_source": "landing_coil", "proc_group": int(data.landing_group), "proc_epoch": int(player.get("proc_epoch", 0)), "pierce": 8, "max_pierce": 8}, true)
	_emit("proc", origin, {"kind": "landing_coil", "player": player.id, "owner": player.id, "proc_id": data.landing_group, "radius": 32.0, "duration": 0.45})


func _step_proc_effects(dt: float) -> void:
	var kept: Array = []
	for aura: Dictionary in state.get("proc_effects", []):
		var owner: Dictionary = Dictionary(state["players"]).get(int(aura.owner), {})
		if owner.is_empty() or bool(owner.get("dead", false)): continue
		aura.pos = Vector2(owner.pos)
		aura.ttl = float(aura.ttl) - dt
		aura.pulse = float(aura.pulse) - dt
		if float(aura.pulse) <= 0.000001:
			aura.pulse = float(aura.pulse) + 0.5
			# One bounded pulse, one pass, one hit per enemy. Secondary damage
			# never adds new auras or projectiles during this traversal.
			for enemy: Dictionary in state["enemies"]:
				if float(enemy.hp) <= 0.0 or Vector2(enemy.pos).distance_squared_to(aura.pos) > pow(float(aura.radius) + _enemy_radius(enemy), 2.0): continue
				_damage_enemy(enemy, float(aura.damage), int(aura.owner), false, 1)
				enemy.slow_factor = minf(float(enemy.get("slow_factor", 1.0)) if float(enemy.get("slow_timer", 0.0)) > 0.0 else 1.0, float(aura.slow_factor))
				enemy.slow_timer = maxf(float(enemy.get("slow_timer", 0.0)), 0.65)
		if float(aura.ttl) > 0.000001: kept.append(aura)
	state["proc_effects"] = kept


func _cancel_owner_procs(player: Dictionary) -> void:
	player.proc_epoch = int(player.get("proc_epoch", 0)) + 1
	var owner_id: int = int(player.id)
	state["proc_effects"] = Array(state.get("proc_effects", [])).filter(func(a: Dictionary) -> bool: return int(a.owner) != owner_id)
	state["projectiles"] = Array(state["projectiles"]).filter(func(p: Dictionary) -> bool: return not bool(p.get("proc", false)) or int(p.owner) != owner_id)


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


func _damage_enemy(enemy: Dictionary, amount: float, owner: int, can_proc: bool, depth: int, primary_attack: int = 0) -> void:
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
			var frost_factor: float = 1.0 - minf(0.5, 0.15 + 0.05 * _stacks(player, "frost"))
			var active_factor: float = float(enemy.get("slow_factor", 1.0)) if float(enemy.get("slow_timer", 0.0)) > 0.0 else 1.0
			enemy["slow_factor"] = minf(active_factor, frost_factor)
			enemy["slow_timer"] = maxf(float(enemy.get("slow_timer", 0.0)), 1.5)
		if _stacks(player, "toxin") > 0:
			enemy["poison_timer"] = 4.0
			enemy["poison_dps"] = 3.0 * mini(8, _stacks(player, "toxin")) * _damage_scale(player)
			enemy["poison_owner"] = owner
	enemy["hp"] = maxf(0.0, float(enemy["hp"]) - amount)
	enemy["flash"] = 0.1
	_emit("hit", enemy["pos"], {"amount": amount, "crit": critical, "owner": owner})
	if float(enemy["hp"]) <= 0.0:
		_kill_enemy(enemy, player, owner, depth)
	if can_proc and depth == 0 and not player.is_empty() and not bool(player.get("dead", false)):
		_direct_proc(player, critical, float(enemy["hp"]) <= 0.0, primary_attack)
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
	# Gold briefly scatters, then seeks a living teammate automatically. Its
	# amount is locked at death and the full squad is credited once on arrival.
	_drop_coin_pickup(9 if bool(enemy["elite"]) else 4, position, owner, 35 if str(enemy["kind"]) == "boss" else 0)
	if _rng.randf() < 0.12:
		_spawn_pickup(position + Vector2(12.0, -12.0), "heal", "", 18)
	if str(enemy["kind"]) == "boss":
		state["boss_alive"] = false
		for p_value in Dictionary(state["players"]).values():
			var p: Dictionary = p_value
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


func _coin_bonus_player() -> Dictionary:
	var best: Dictionary = {}
	for value in Dictionary(state.get("players", {})).values():
		var player: Dictionary = value
		if bool(player.get("dead", false)):
			continue
		if best.is_empty() or _stacks(player, "harvest") > _stacks(best, "harvest") or (_stacks(player, "harvest") == _stacks(best, "harvest") and int(player["id"]) < int(best["id"])):
			best = player
	return best


func _credit_coins(base_amount: int, position: Vector2, collector: Dictionary, source: String = "pickup", owner: int = -1, fixed_bonus: int = 0) -> int:
	var harvest: int = 0 if collector.is_empty() else _stacks(collector, "harvest")
	var reward: int = int(round(maxi(0, base_amount) * (1.0 + minf(1.0, harvest * 0.15)))) + maxi(0, fixed_bonus)
	return _credit_coin_amount(reward, position, {"source":source, "owner":owner, "bonus_player":-1 if collector.is_empty() else int(collector.id), "base_amount":base_amount, "fixed_bonus":fixed_bonus})


func _credit_coin_amount(reward: int, position: Vector2, metadata: Dictionary) -> int:
	var players: Dictionary = state.get("players", {})
	if reward <= 0 or players.is_empty():
		return 0
	var recipients: Array = players.keys()
	recipients.sort()
	for id: Variant in recipients:
		var recipient: Dictionary = players[id]
		recipient["coins"] = int(recipient["coins"]) + reward
	var data: Dictionary = {"kind":"coin", "item":"", "automatic":true, "amount":reward, "recipients":recipients}
	for key: String in ["source", "owner", "bonus_player", "base_amount", "fixed_bonus"]:
		if metadata.has(key): data[key] = metadata[key]
	data["coin_id"] = int(metadata.get("id", -1))
	data["player"] = int(metadata.get("collector", metadata.get("bonus_player", -1)))
	if int(data.player) < 0: data.player = int(recipients[0])
	_emit("pickup", position, data)
	return reward


func _coin_target(position: Vector2, preferred: int = -1) -> Dictionary:
	var players: Dictionary = state.get("players", {})
	if players.has(preferred) and not bool(players[preferred].dead): return players[preferred]
	var best: Dictionary = {}
	var distance: float = INF
	for player: Dictionary in players.values():
		if bool(player.dead): continue
		var candidate: float = position.distance_squared_to(player.pos)
		if candidate < distance or (is_equal_approx(candidate, distance) and (best.is_empty() or int(player.id) < int(best.id))):
			distance = candidate
			best = player
	return best


func _drop_coin_pickup(base_amount: int, position: Vector2, owner: int, fixed_bonus: int = 0) -> Dictionary:
	var bonus: Dictionary = _coin_bonus_player()
	var harvest: int = 0 if bonus.is_empty() else _stacks(bonus, "harvest")
	var reward: int = int(round(maxi(0, base_amount) * (1.0 + minf(1.0, harvest * 0.15)))) + maxi(0, fixed_bonus)
	if reward <= 0: return {}
	var target: Dictionary = _coin_target(position)
	var id_value: int = _id()
	var phase: float = fposmod(float(id_value) * 2.39996323, TAU)
	var coin: Dictionary = {"id":id_value, "pos":position, "origin":position, "vel":Vector2(sin(phase) * 130.0, -170.0 - cos(phase) * 45.0),
		"age":0.0, "delay":0.22 + fposmod(phase, 0.10), "seeking":false, "amount":reward,
		"target":-1 if target.is_empty() else int(target.id), "owner":owner, "bonus_player":-1 if bonus.is_empty() else int(bonus.id),
		"base_amount":base_amount, "fixed_bonus":fixed_bonus, "source":"enemy_kill"}
	var coins: Array = state.get("coin_pickups", [])
	if coins.size() >= MAX_COIN_PICKUPS:
		# Settle the oldest bundle before replacement: no item eviction, no gold
		# loss, and no dependence on the cosmetic event queue having free space.
		var oldest: Dictionary = coins.pop_front()
		_credit_coin_amount(int(oldest.amount), oldest.pos, oldest)
	coins.append(coin)
	state["coin_pickups"] = coins
	_emit("coin_drop", position, {"amount":reward, "coin_id":id_value, "target":coin.target})
	return coin


func _step_coin_pickups(dt: float) -> void:
	var kept: Array = []
	for coin: Dictionary in state.get("coin_pickups", []):
		coin.age = float(coin.age) + dt
		var target: Dictionary = _coin_target(coin.pos, int(coin.target))
		if target.is_empty():
			_credit_coin_amount(int(coin.amount), coin.pos, coin)
			continue
		coin.target = int(target.id)
		var destination: Vector2 = Vector2(target.pos) + Vector2(0, -4)
		var position: Vector2 = coin.pos
		var velocity: Vector2 = coin.vel
		if float(coin.age) < float(coin.delay):
			velocity.y += 760.0 * dt
			var moved: Dictionary = _move_body(position, velocity, dt, Vector2(3, 3))
			position = moved.pos
			velocity = moved.vel
		else:
			coin.seeking = true
			var offset: Vector2 = destination - position
			var seek_age: float = float(coin.age) - float(coin.delay)
			var speed: float = minf(1900.0, 340.0 + seek_age * 1900.0) * (1.0 + minf(0.6, _stacks(target, "magnet") * 0.12))
			# There is no pickup radius and no terrain collision during attraction;
			# coins cannot get stuck beneath a platform or require backtracking.
			velocity = velocity.lerp(offset.normalized() * speed, minf(1.0, dt * 12.0))
			var next: Vector2 = position + velocity * dt
			if offset.length() < 22.0 or _segment_circle(position, next, destination, 22.0) >= 0.0 or float(coin.age) >= 4.0:
				coin["collector"] = int(target.id)
				_credit_coin_amount(int(coin.amount), destination, coin)
				continue
			position = next
		coin.pos = position
		coin.vel = velocity
		kept.append(coin)
	state["coin_pickups"] = kept


func _flush_coin_pickups() -> void:
	var pending: Array = state.get("coin_pickups", [])
	state["coin_pickups"] = []
	for coin: Dictionary in pending:
		var target: Dictionary = _coin_target(coin.pos, int(coin.target))
		coin["collector"] = -1 if target.is_empty() else int(target.id)
		_credit_coin_amount(int(coin.amount), coin.pos if target.is_empty() else target.pos, coin)


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


func _damage_player(player: Dictionary, amount: float, source: Vector2, visual: Dictionary = {}) -> void:
	if bool(player["dead"]) or float(player["invuln"]) > 0.0 or not is_finite(amount) or amount <= 0.0:
		return
	amount -= minf(amount * 0.6, float(_stacks(player, "plating")))
	var guarding: bool = float(player.get("guard_timer", 0.0)) > 0.0 and float(player.get("stun_timer", 0.0)) <= 0.0
	if guarding:
		var ability: Dictionary = Content.movement_ability("vanguard")
		var prevented: float = amount * float(ability.reduction)
		player["guard_absorbed"] = minf(float(ability.charge_cap), float(player.get("guard_absorbed", 0.0)) + prevented)
		amount -= prevented
		_emit("ability", player["pos"], {"ability": "guard_burst", "phase": "block", "player": player.id,
			"ability_id": player.guard_id, "amount": prevented, "absorbed": player.guard_absorbed})
	var hp_before: float = float(player["hp"])
	var reactive_absorbed: float = minf(float(player.get("reactive_shield", 0.0)), amount)
	player["reactive_shield"] = float(player.get("reactive_shield", 0.0)) - reactive_absorbed
	amount -= reactive_absorbed
	var shield: float = float(player["shield"])
	var absorbed: float = minf(shield, amount)
	player["shield"] = shield - absorbed
	amount -= absorbed
	player["hp"] = maxf(0.0, float(player["hp"]) - amount)
	player["invuln"] = 0.48
	player["hurt_timer"] = 6.0
	if not guarding:
		var push: float = signf(Vector2(player["pos"]).x - source.x)
		player["vel"] = Vector2(push * 165.0, -150.0)
		player["jump_rising"] = false
		_cancel_movement_ability(player)
		_cancel_guard(player)
	var feedback: Dictionary = {"amount": amount, "crit": false, "player": player["id"], "friendly": true}
	# Optional presentation provenance; no damage, RNG, or state changes.
	feedback.merge(visual)
	_emit("hit", player["pos"], feedback)
	if float(player["hp"]) <= 0.0:
		_cancel_owner_procs(player)
		Procs.cancel(player)
		_cancel_guard(player)
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
	elif Procs.hurt(player, hp_before - float(player["hp"])):
		_emit("proc", player["pos"], {"kind": "reactive_plating", "player": player.id, "owner": player.id, "proc_id": _id(), "radius": 34.0, "duration": 3.0, "amount": 10.0})


func _step_enemies(dt: float) -> void:
	# Observe real support once per player, not once per pursuer. Airborne
	# height is not a navigation goal: a short hop should not cue the crowd.
	var target_supports: Dictionary = {}
	for player: Dictionary in Dictionary(state["players"]).values():
		if bool(player.get("grounded", false)) and not bool(player.get("dead", false)):
			target_supports[int(player.id)] = _enemy_support_surface(player.pos, PLAYER_HALF)
	for enemy_value in Array(state["enemies"]):
		var enemy: Dictionary = enemy_value
		if float(enemy["hp"]) <= 0.0:
			continue
		_step_enemy_status(enemy, dt)
		if float(enemy["hp"]) <= 0.0:
			continue
		for timer in ["attack_cd", "jump_cd", "flash"]:
			enemy[timer] = maxf(0.0, float(enemy.get(timer, 0.0)) - dt)
		if float(enemy.get("stun_timer", 0.0)) > 0.0:
			_cancel_enemy_attack(enemy)
			enemy["vel"] = Vector2.ZERO
			continue
		var target: Dictionary = _nearest_player(enemy["pos"])
		if target.is_empty():
			continue
		if float(enemy.get("telegraph", 0.0)) > 0.0:
			enemy["telegraph"] = maxf(0.0, float(enemy["telegraph"]) - dt)
			if float(enemy["telegraph"]) <= 0.0:
				_release_enemy_attack(enemy, target)
		elif float(enemy["attack_cd"]) <= 0.0 and float(enemy.get("charge_timer", 0.0)) <= 0.0:
			if Vector2(enemy["pos"]).distance_to(target["pos"]) <= float(enemy.get("attack_range", 650.0)):
				_begin_enemy_attack(enemy, target)
		_move_enemy(enemy, target, dt, target_supports.get(int(target.id), Rect2()))


func _move_enemy(enemy: Dictionary, target: Dictionary, dt: float, target_support: Rect2 = Rect2()) -> void:
	var position: Vector2 = enemy["pos"]
	var offset: Vector2 = Vector2(target["pos"]) - position
	var velocity: Vector2 = enemy["vel"]
	var boss: bool = str(enemy["kind"]) == "boss"
	var elite_scale: float = 1.15 if bool(enemy["elite"]) else 1.0
	var slow: float = float(enemy.get("slow_factor", 1.0)) if float(enemy.get("slow_timer", 0.0)) > 0.0 else 1.0
	var winding: bool = float(enemy.get("telegraph", 0.0)) > 0.0
	var charging: bool = float(enemy.get("charge_timer", 0.0)) > 0.0
	var navigation: Dictionary = {} if bool(enemy.get("flying", false)) else _enemy_platform_navigation(enemy, target, target_support, dt)
	if str(enemy.get("attack_kind", "")) in ["beam", "prism_beam", "prism_cross"] and (winding or float(enemy["attack_cd"]) > float(enemy["attack_cooldown"]) - 0.58):
		# Beam geometry remains fixed through both warning and active frames.
		# A hovering boss stops in place; a ground sentinel only starts landed.
		enemy["vel"] = Vector2.ZERO
		return
	if charging:
		enemy["charge_timer"] = maxf(0.0, float(enemy["charge_timer"]) - dt)
		velocity.x = Vector2(enemy["attack_dir"]).x * float(enemy.get("charge_speed", 340.0)) * slow
	elif bool(enemy.get("flying", false)):
		var hover: float = -125.0 if not boss else -95.0
		var desired: Vector2 = Vector2(target["pos"]) + Vector2(sin(float(state["time"]) * 0.9 + int(enemy["id"])) * 130.0, hover)
		var desired_velocity: Vector2 = Vector2.ZERO if winding else (desired - position).limit_length(1.0) * float(enemy["move_speed"]) * elite_scale * slow
		velocity = velocity.move_toward(desired_velocity, 380.0 * dt)
	else:
		var move_direction: float = signf(offset.x)
		if str(enemy["kind"]) in ["spitter", "sentinel", "skirmisher"] and absf(offset.x) < 290.0:
			move_direction = -move_direction * 0.5 if absf(offset.x) < 160.0 else 0.0
		if navigation.has("move"):
			move_direction = float(navigation.move)
		if winding:
			move_direction = 0.0
		velocity.x = move_toward(velocity.x, move_direction * float(enemy["move_speed"]) * elite_scale * slow, 750.0 * dt)
	if bool(enemy.get("flying", false)):
		position += velocity * dt
		position.x = clampf(position.x, 30.0, _world_size().x - 30.0)
		position.y = clampf(position.y, 70.0, _floor_y() - 35.0)
	else:
		velocity.y = minf(1000.0, velocity.y + GRAVITY * dt)
		if not winding and not charging and bool(enemy.get("grounded", false)) and float(enemy["jump_cd"]) <= 0.0 and navigation.has("jump_speed"):
			velocity.y = -float(navigation.jump_speed)
			enemy["nav_jumps"] = int(enemy.get("nav_jumps", 0)) + 1
			enemy["jump_cd"] = 1.05 + _enemy_navigation_variant(int(enemy.id), int(enemy.nav_jumps) + 5) * 0.8
		var moved: Dictionary = _move_body(position, velocity, dt, Vector2(39.0, 44.0) if boss else Vector2(15.0, 17.0))
		position = moved["pos"]
		velocity = moved["vel"]
		enemy["grounded"] = moved["grounded"]
	enemy["pos"] = position
	enemy["vel"] = velocity
	# Contact is limited by each player's existing damage immunity. A charged
	# dash additionally records victims, so it cannot multi-hit one teammate.
	for player_value in Dictionary(state["players"]).values():
		var player: Dictionary = player_value
		if bool(player["dead"]) or position.distance_to(player["pos"]) >= (55.0 if boss else 31.0):
			continue
		if charging:
			var hit_ids: Array = enemy.get("charge_hit_ids", [])
			if int(player["id"]) in hit_ids:
				continue
			hit_ids.append(int(player["id"]))
			enemy["charge_hit_ids"] = hit_ids
		var damage: float = (17.0 if boss else (14.0 if charging else 10.0)) * elite_scale
		_damage_player(player, damage * _enemy_damage_scale(), position, {"attack_kind":str(enemy.get("attack_kind","")),"enemy_id":int(enemy.id),"aim":(Vector2(player.pos)-position).normalized()})


func _enemy_navigation_variant(id: int, salt: int) -> float:
	# Stable serializable personality, without consuming combat/drop RNG.
	return float(posmod(id * 92821 + int(state.get("seed", 0)) * 37 + salt * 68917, 997)) / 996.0


func _enemy_support_surface(position: Vector2, half: Vector2) -> Rect2:
	for platform: Rect2 in Array(state.get("platforms", [])):
		if absf(position.y + half.y - platform.position.y) <= 3.0 and position.x + half.x > platform.position.x and position.x - half.x < platform.end.x:
			return platform
	return Rect2()


func _enemy_platform_navigation(enemy: Dictionary, target: Dictionary, support: Rect2, dt: float) -> Dictionary:
	var id: int = int(enemy.id)
	var half: Vector2 = Vector2(39, 44) if str(enemy.kind) == "boss" else Vector2(15, 17)
	var position: Vector2 = enemy.pos
	var feet: float = position.y + half.y
	if int(enemy.get("nav_target", -1)) != int(target.id):
		enemy["nav_target"] = int(target.id)
		enemy["nav_support"] = Rect2()
		enemy["nav_stable"] = 0.0
		enemy["nav_plan"] = Rect2()
	if support.size != Vector2.ZERO:
		if Rect2(enemy.get("nav_support", Rect2())) != support:
			enemy["nav_support"] = support
			enemy["nav_stable"] = 0.0
			enemy["nav_plan"] = Rect2()
		else:
			enemy["nav_stable"] = float(enemy.get("nav_stable", 0.0)) + dt
		enemy["nav_air_age"] = 0.0
	else:
		enemy["nav_air_age"] = float(enemy.get("nav_air_age", 0.0)) + dt
		if float(enemy.nav_air_age) > 0.75:
			enemy["nav_support"] = Rect2()
			enemy["nav_stable"] = 0.0
	var goal: Rect2 = enemy.get("nav_support", Rect2())
	var plan: Rect2 = enemy.get("nav_plan", Rect2())
	enemy["nav_decision_cd"] = maxf(0.0, float(enemy.get("nav_decision_cd", 0.0)) - dt)
	# Keep a chosen landing point through the airborne part of a jump.
	if bool(enemy.get("grounded", false)) and (plan.size == Vector2.ZERO or feet <= plan.position.y + 3.0):
		enemy["nav_plan"] = Rect2()
		plan = Rect2()
		if goal.size == Vector2.ZERO or float(enemy.get("nav_stable", 0.0)) < 0.18 + _enemy_navigation_variant(id, 1) * 0.24:
			return {}
		if float(enemy.nav_decision_cd) <= 0.0:
			enemy["nav_decision_cd"] = 0.14 + _enemy_navigation_variant(id, 2) * 0.19
			var own: Rect2 = _enemy_support_surface(position, half)
			var climbing: bool = goal.position.y < feet - 24.0
			var heading: float = signf(Vector2(target.pos).x - position.x)
			var edge_x: float = own.end.x + 1.0 if heading >= 0.0 else own.position.x - 1.0
			var ahead_y: float = _surface_below(edge_x, feet - 3.0)
			# Adjacent/overlapping rectangles can form one continuous bridge.
			# A different support ID alone is not a reason to hop across its seam.
			var gap: bool = not climbing and goal != own and absf(goal.position.y - feet) <= 24.0 and ahead_y > feet + 24.0
			var best_score: float = INF
			if climbing or gap:
				for platform: Rect2 in Array(state.get("platforms", [])):
					var rise: float = feet - platform.position.y
					if platform == own or platform.size.x < half.x * 2.0 + 8.0 or rise < (-24.0 if gap else 24.0) or rise > 128.0 or platform.position.y < goal.position.y - 3.0:
						continue
					if gap and (absf(rise) > 24.0 or (platform.get_center().x - position.x) * (Vector2(target.pos).x - position.x) <= 0.0):
						continue
					var landing_x: float = clampf(position.x, platform.position.x + half.x + 4.0, platform.end.x - half.x - 4.0)
					var goal_x: float = clampf(Vector2(target.pos).x, platform.position.x, platform.end.x)
					var score: float = absf(landing_x - position.x) + absf(goal_x - Vector2(target.pos).x) * 0.35 + absf(platform.position.y - goal.position.y) * 0.4
					if score < best_score:
						best_score = score
						plan = platform
						enemy["nav_landing_x"] = landing_x
				enemy["nav_plan"] = plan
	if plan.size == Vector2.ZERO:
		return {}
	var destination: float = float(enemy.get("nav_landing_x", position.x))
	var distance: float = destination - position.x
	var result: Dictionary = {"move": signf(distance) if absf(distance) > 5.0 else 0.0}
	if bool(enemy.get("grounded", false)) and float(enemy.get("jump_cd", 0.0)) <= 0.0:
		var rise: float = feet - plan.position.y
		if rise < -24.0 or rise > 128.0:
			enemy["nav_plan"] = Rect2()
			return {}
		var variation: float = _enemy_navigation_variant(id, int(enemy.get("nav_jumps", 0)) + 3)
		var jump_speed: float = maxf(630.0 + variation * 48.0, sqrt(2.0 * GRAVITY * (maxf(0.0, rise) + 10.0)) + variation * 12.0)
		var flight: float = (jump_speed + sqrt(maxf(0.0, jump_speed * jump_speed - 2.0 * GRAVITY * rise))) / GRAVITY
		var travel_speed: float = float(enemy.move_speed) * (1.15 if bool(enemy.elite) else 1.0) * float(enemy.get("slow_factor", 1.0) if float(enemy.get("slow_timer", 0.0)) > 0.0 else 1.0)
		if absf(distance) <= maxf(5.0, travel_speed * flight * 0.65):
			result["jump_speed"] = jump_speed
	return result


func _begin_enemy_attack(enemy: Dictionary, target: Dictionary) -> void:
	if float(enemy["hp"]) <= 0.0:
		return
	var kind: String = str(enemy.get("primary_attack", "spit"))
	if kind == "beam" and not bool(enemy.get("grounded", false)):
		return
	if str(enemy["kind"]) == "boss":
		var cycle: int = int(enemy.get("attack_count", 0))
		match str(enemy.get("boss_style", "spore")):
			"stone": kind = "stone_spikes" if cycle % 2 == 0 else "stone_charge"
			"prism": kind = "prism_beam" if cycle % 2 == 0 else "prism_cross"
			_: kind = "spore_volley" if cycle % 2 == 0 else "spore_bloom"
		enemy["attack_count"] = cycle + 1
	var windup: float = EnemyCatalog.attack_windup(kind, float(enemy.get("windup", 0.8)))
	enemy["telegraph"] = windup
	enemy["telegraph_max"] = windup
	enemy["attack_kind"] = kind
	enemy["attack_target"] = Vector2(target["pos"])
	enemy["attack_dir"] = WeaponPose.normalized_aim(Vector2(target["pos"]) - Vector2(enemy["pos"]))
	if kind in ["pounce", "charge", "stone_charge"]:
		enemy["attack_dir"] = Vector2(-1.0 if Vector2(target["pos"]).x < Vector2(enemy["pos"]).x else 1.0, 0.0)
	enemy["charge_hit_ids"] = []
	# Lock the target and danger geometry once. Dodging after the warning
	# starts must work; attacks never re-aim at the release frame.
	match kind:
		"mortar":
			_spawn_hazard(enemy, "spore_mortar", target["pos"], "circle", Vector2.RIGHT, 0.0, 48.0, windup, 12.0)
		"burrow":
			var ground_mark: Vector2 = Vector2(Vector2(target["pos"]).x, _surface_below(Vector2(target["pos"]).x, Vector2(target["pos"]).y - 8.0) - 17.0)
			enemy["attack_target"] = ground_mark
			_spawn_hazard(enemy, "burrow", ground_mark, "circle", Vector2.RIGHT, 0.0, 48.0, windup, 13.0)
		"beam":
			_spawn_hazard(enemy, "beam", enemy["pos"], "line", enemy["attack_dir"], 720.0, 12.0, windup, 12.0)
		"blink":
			var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
			var blink_x: float = clampf(Vector2(target["pos"]).x + side * 190.0, 40.0, _world_size().x - 40.0)
			enemy["blink_target"] = Vector2(blink_x, _surface_below(blink_x, Vector2(target["pos"]).y - 8.0) - 17.0)
		"spore_bloom":
			for x in [-105.0, 0.0, 105.0]:
				_spawn_hazard(enemy, "boss_spore", Vector2(target["pos"]) + Vector2(x, 0), "circle", Vector2.RIGHT, 0.0, 54.0, windup, 15.0)
		"stone_spikes":
			for x in [-150.0, 0.0, 150.0]:
				var spike_x: float = clampf(Vector2(target["pos"]).x + x, 20.0, _world_size().x - 20.0)
				var spike_position: Vector2 = Vector2(spike_x, _surface_below(spike_x, Vector2(target["pos"]).y - 8.0) - 17.0)
				_spawn_hazard(enemy, "stone_spike", spike_position, "circle", Vector2.UP, 0.0, 42.0, windup, 16.0)
		"prism_beam", "prism_cross":
			_spawn_hazard(enemy, "boss_beam", enemy["pos"], "line", enemy["attack_dir"], 850.0, 17.0, windup, 16.0)
			if kind == "prism_cross":
				_spawn_hazard(enemy, "boss_beam", enemy["pos"], "line", Vector2(enemy["attack_dir"]).rotated(PI * 0.5), 620.0, 14.0, windup, 14.0)
				_spawn_hazard(enemy, "boss_beam", enemy["pos"], "line", Vector2(enemy["attack_dir"]).rotated(-PI * 0.5), 620.0, 14.0, windup, 14.0)


func _release_enemy_attack(enemy: Dictionary, target: Dictionary) -> void:
	var aim: Vector2 = enemy.get("attack_dir", Vector2.RIGHT)
	var kind: String = str(enemy.get("attack_kind", ""))
	enemy["attack_cd"] = float(enemy.get("attack_cooldown", 3.0))
	match kind:
		"pounce":
			enemy["vel"] = Vector2(signf(aim.x) * 320.0, -330.0)
			enemy["charge_timer"] = 0.35
			enemy["charge_speed"] = 320.0
			enemy["attack_dir"] = Vector2(signf(aim.x) if absf(aim.x) > 0.05 else 1.0, 0)
		"charge", "stone_charge":
			enemy["charge_timer"] = 0.58 if kind == "charge" else 0.72
			enemy["charge_speed"] = 430.0 if kind == "charge" else 370.0
			enemy["attack_dir"] = Vector2(signf(aim.x) if absf(aim.x) > 0.05 else 1.0, 0)
		"spit":
			_enemy_shoot(enemy, aim, 270.0, 10.0, "spit")
		"triple", "salvo":
			for spread in [-0.2, 0.0, 0.2]:
				_enemy_shoot(enemy, aim.rotated(spread), 235.0 if kind == "triple" else 285.0, 7.0, "crystal" if kind == "triple" else "pulse")
		"spore_volley":
			var count: int = 7 if float(enemy["hp"]) < float(enemy["max_hp"]) * 0.45 else 5
			for index in range(count):
				_enemy_shoot(enemy, aim.rotated((index - (count - 1) * 0.5) * 0.21), 225.0, 12.0, "boss_spore_orb")
		"burrow":
			var marked: Vector2 = enemy["attack_target"]
			enemy["pos"] = Vector2(clampf(marked.x, 30.0, _world_size().x - 30.0), _surface_below(marked.x, marked.y - 8.0) - 17.0)
			enemy["vel"] = Vector2.ZERO
			_emit("dash", enemy["pos"], {"aim": Vector2.UP, "enemy": true, "kind": "burrow"})
		"blink":
			enemy["pos"] = enemy["blink_target"]
			enemy["vel"] = Vector2.ZERO
			enemy["telegraph"] = 0.7
			enemy["telegraph_max"] = 0.7
			enemy["attack_kind"] = "salvo"
			enemy["attack_target"] = Vector2(target["pos"])
			enemy["attack_dir"] = WeaponPose.normalized_aim(Vector2(target["pos"]) - Vector2(enemy["pos"]))
			_emit("dash", enemy["pos"], {"aim": enemy["attack_dir"], "enemy": true, "kind": "blink"})
		"mend":
			var healed: int = 0
			var budget: float = float(enemy.get("heal_budget", 0.0))
			for ally_value in Array(state["enemies"]):
				var ally: Dictionary = ally_value
				if healed >= 3 or budget <= 0.0:
					break
				if int(ally["id"]) == int(enemy["id"]) or str(ally["kind"]) == "boss" or float(ally["hp"]) <= 0.0 or float(ally["hp"]) >= float(ally["max_hp"]):
					continue
				if Vector2(ally["pos"]).distance_to(enemy["pos"]) > 260.0:
					continue
				var amount: float = minf(8.0, minf(budget, float(ally["max_hp"]) - float(ally["hp"])))
				ally["hp"] = float(ally["hp"]) + amount
				budget -= amount
				healed += 1
			enemy["heal_budget"] = budget
			if healed > 0:
				_emit("explosion", enemy["pos"], {"radius": 260.0, "team": "enemy", "healing": true, "visual_only": true})
			_enemy_shoot(enemy, aim, 210.0, 8.0, "energy")


func _cancel_enemy_attack(enemy: Dictionary) -> void:
	enemy["telegraph"] = 0.0
	enemy["charge_timer"] = 0.0
	enemy["attack_cd"] = maxf(0.6, float(enemy.get("attack_cd", 0.0)))
	var owner: int = int(enemy["id"])
	state["hazards"] = Array(state.get("hazards", [])).filter(func(hazard: Dictionary) -> bool: return int(hazard["owner"]) != owner)


func _spawn_hazard(enemy: Dictionary, kind: String, position: Vector2, shape: String, direction: Vector2, length: float, radius: float, delay: float, damage: float) -> Dictionary:
	var hazards: Array = state.get("hazards", [])
	if hazards.size() >= MAX_HAZARDS:
		return {}
	var hazard: Dictionary = {"id": _id(), "kind": kind, "shape": shape, "pos": position,
		"dir": WeaponPose.normalized_aim(direction), "length": length, "radius": radius,
		"delay": maxf(0.55, delay), "telegraph_max": maxf(0.55, delay), "active": false,
		"ttl": 0.55 if shape == "line" else 0.22, "damage": damage, "owner": int(enemy["id"]), "hit_ids": [], "biome": str(enemy.get("biome", state.get("biome", "rainforest")))}
	hazards.append(hazard)
	state["hazards"] = hazards
	return hazard


func _step_hazards(dt: float, new_hazard_min_id: int = -1) -> void:
	var living: Dictionary = {}
	for enemy_value in Array(state["enemies"]):
		var enemy: Dictionary = enemy_value
		if float(enemy["hp"]) > 0.0:
			living[int(enemy["id"])] = true
	var kept: Array = []
	for hazard_value in Array(state.get("hazards", [])):
		var hazard: Dictionary = hazard_value
		if not living.has(int(hazard["owner"])):
			continue
		if not bool(hazard["active"]):
			if new_hazard_min_id >= 0 and int(hazard["id"]) >= new_hazard_min_id:
				kept.append(hazard)
				continue
			hazard["delay"] = maxf(0.0, float(hazard["delay"]) - dt)
			if float(hazard["delay"]) > 0.0:
				kept.append(hazard)
				continue
			hazard["active"] = true
			_emit("explosion", hazard["pos"], {"radius": hazard["radius"], "team": "enemy", "kind": hazard["kind"], "visual_only": true})
		hazard["ttl"] = float(hazard["ttl"]) - dt
		if float(hazard["ttl"])<=0.0: continue
		for player_value in Dictionary(state["players"]).values():
			var player: Dictionary = player_value
			if bool(player["dead"]) or int(player["id"]) in Array(hazard["hit_ids"]):
				continue
			var hit: bool = false
			if str(hazard["shape"]) == "line":
				var envelope: Vector2 = BeamEnvelope.sample(float(hazard["ttl"]))
				hit = envelope.y>0.0 and _segment_circle(hazard["pos"], Vector2(hazard["pos"]) + Vector2(hazard["dir"]) * float(hazard["length"])*envelope.x, player["pos"], float(hazard["radius"])*envelope.y + 15.0) >= 0.0
			else:
				hit = Vector2(player["pos"]).distance_to(hazard["pos"]) <= float(hazard["radius"]) + 15.0
			if hit:
				hazard["hit_ids"].append(int(player["id"]))
				_damage_player(player, float(hazard["damage"]) * _enemy_damage_scale(), hazard["pos"], {"attack_kind":str(hazard.kind),"enemy_id":int(hazard.owner),"aim":hazard.dir})
		if float(hazard["ttl"]) > 0.0:
			kept.append(hazard)
	state["hazards"] = kept


func _enemy_shoot(enemy: Dictionary, aim: Vector2, speed: float, damage: float, kind: String) -> void:
	var direction: Vector2 = WeaponPose.normalized_aim(aim)
	var muzzle: Vector2 = Vector2(enemy["pos"]) + direction * (_enemy_radius(enemy) + 3.0)
	var before: int = Array(state["projectiles"]).size()
	_spawn_projectile(muzzle, direction * speed, "enemy", kind, damage * _enemy_damage_scale(), -1, 4.0, 9.0 if kind.begins_with("boss") else 6.0)
	var metadata: Dictionary = {"enemy_id": int(enemy["id"]), "biome": str(enemy.get("biome", "")), "boss_style": str(enemy.get("boss_style", ""))}
	if Array(state["projectiles"]).size() > before:
		var projectile: Dictionary = state["projectiles"].back()
		projectile.merge(metadata)
		if kind == "energy" and str(enemy.get("kind", "")) == "conductor":
			var guidance: Dictionary = Guidance.lock(muzzle, direction * speed, Dictionary(state["players"]).values(), Guidance.CONDUCTOR)
			if not guidance.is_empty():
				projectile["guidance"] = guidance
	metadata.merge({"aim": direction, "kind": kind, "enemy": true})
	_emit("shoot", muzzle, metadata)

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
	var pool: Array[String] = EnemyCatalog.pool(str(state.get("biome", "rainforest")))
	var kind: String = pool[0]
	var roll: float = _rng.randf()
	if roll > 0.77:
		kind = pool[1]
	elif roll > 0.52:
		kind = pool[2]
	if position.y - target_pos.y > 240.0:
		# A ground enemy several storeys below an isolated balcony cannot
		# participate. Use a flying approach instead of filling the entity
		# budget with unreachable enemies on the distant safety floor.
		kind = EnemyCatalog.flying_kind(str(state.get("biome", "rainforest")))
	if bool(EnemyCatalog.definition(kind).get("flying", false)):
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
	var biome: String = str(state.get("biome", "rainforest"))
	var definition: Dictionary = EnemyCatalog.boss_definition(biome) if kind == "boss" else EnemyCatalog.definition(kind)
	if definition.is_empty():
		return {}
	var base: float = float(definition.get("health", 36.0))
	var count: int = maxi(1, Dictionary(state["players"]).size())
	var health: float = base * (1.0 + (count - 1) * 0.6) * (1.0 + (float(state["difficulty"]) - 1.0) * 0.28)
	if elite:
		health *= 1.85
	var enemy: Dictionary = {"id": _id(), "kind": kind, "pos": position, "vel": Vector2.ZERO,
		"hp": health, "max_hp": health, "elite": elite, "attack_cd": 1.0 + _rng.randf(),
		"jump_cd": 1.0, "grounded": false, "flash": 0.0, "telegraph": 0.0, "phase_time": 0.0, "challenge_id": -1,
		"spawn_difficulty": float(state["difficulty"]), "biome": str(definition.get("biome", biome)),
		"name": str(definition.get("name", kind)), "boss_style": str(definition.get("boss_style", "")),
		"radius": float(definition.get("radius", 19.0)), "flying": bool(definition.get("flying", false)),
		"move_speed": float(definition.get("speed", 78.0)), "attack_range": float(definition.get("range", 950.0)),
		"windup": float(definition.get("windup", 0.9)), "attack_cooldown": float(definition.get("cooldown", 3.1)),
		"primary_attack": str(definition.get("attack_kind", "")), "attack_kind": "", "attack_dir": Vector2.RIGHT,
		"attack_target": position, "telegraph_max": float(definition.get("windup", 0.9)), "blink_target": position,
		"charge_timer": 0.0, "charge_hit_ids": [], "attack_count": 0, "heal_budget": 48.0 if kind == "conductor" else 0.0}
	enemy["jump_cd"] = 0.25 + _enemy_navigation_variant(int(enemy.id), 0) * 0.7
	enemy["nav_target"] = -1
	enemy["nav_support"] = Rect2()
	enemy["nav_stable"] = 0.0
	enemy["nav_air_age"] = 0.0
	enemy["nav_plan"] = Rect2()
	enemy["nav_decision_cd"] = _enemy_navigation_variant(int(enemy.id), 2) * 0.3
	enemy["nav_jumps"] = 0
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
		result["title"] = Locale.text("救援 · ") + str(target.get("name", Locale.text("旅者")))
		result["description"] = Locale.text("靠近按 E 启动1.8秒重建；队友恢复55%生命。全员倒下则救援中止。")
		result["prompt"] = Locale.text("E · 启动救援") if float(target.get("revive_timer", 0.0)) <= 0.0 else Locale.format("正在重建 · %.1f秒", [float(target["revive_timer"])])
		result["affordable"] = float(target.get("revive_timer", 0.0)) <= 0.0
		return result
	if kind == "gate":
		result["id"] = -1
		result["title"] = Locale.text("裂隙门")
		if bool(target.get("ready", false)):
			result["description"] = Locale.text("共鸣已稳定。全队进入下一关并恢复生命。" if int(state["stage"]) < 3 else "最终共鸣已稳定，完成远征。")
			result["prompt"] = Locale.text("E · 前往下一关" if int(state["stage"]) < 3 else "E · 完成远征")
		elif bool(target.get("active", false)):
			result["description"] = Locale.text("留在640范围内完成充能，并击败裂隙守卫。")
			result["prompt"] = Locale.format("充能 %d%% · %s", [int(float(target["charge"]) * 100.0), Locale.text("守卫仍在" if bool(state["boss_alive"]) else "守卫已击败")])
			result["affordable"] = false
		else:
			result["description"] = Locale.text("召唤守卫并开始22秒共鸣充能。准备妥当后启动。")
			result["prompt"] = Locale.text("E · 激活裂隙门")
		return result
	var item: String = str(target.get("item", ""))
	var definition: Dictionary = loot_definition(item)
	result["item"] = item
	result["category"] = str(definition.get("category", "passive"))
	# This transient inspection record is built independently on each peer.
	# IDs, prices and the authoritative catalog/state remain language-neutral.
	result["title"] = Locale.text(str(definition.get("name", item)))
	result["description"] = Locale.text(str(definition.get("description", "")))
	result["warning"] = Locale.text(str(definition.get("warning", "")))
	if kind == "pickup":
		result["prompt"] = Locale.text("E · 拾取遗物")
		if str(result["category"]) in ["weapon", "equipment"]:
			var slot: String = str(result["category"])
			var old: Dictionary = loot_definition(str(player.get(slot, "")))
			result["prompt"] = Locale.text("E · 替换主武器" if slot == "weapon" else "E · 替换主动装备")
			result["warning"] = Locale.format("将替换「%s」，旧装备会落地；换装保留未结束的冷却。", [Locale.text(str(old.get("name", "当前装备")))])
		return result
	var facility: String = str(target.get("type", "cache"))
	result["facility_type"] = facility
	var price: int = int(target.get("cost", 0))
	match facility:
		"blood":
			result["title"] = Locale.text("生命献祭 · ") + str(result["title"])
			result["description"] = Locale.format("消耗%d当前生命（不会致死），奖励落地后再按E选择。\n", [price]) + str(result["description"])
			result["warning"] = Locale.format("代价：立即扣除%d当前生命；当前生命必须高于%d。", [price, price]) + ("\n" + str(result["warning"]) if not str(result["warning"]).is_empty() else "")
			result["prompt"] = Locale.format("E · 献祭 %d 生命", [price])
			result["affordable"] = float(player["hp"]) > price
		"combat":
			result["title"] = Locale.text("试炼信标 · ") + str(result["title"])
			var status: String = str(target.get("status", "idle"))
			result["description"] = Locale.text("召唤4名专属试炼敌人；全部击败后奖励落地。无金币费用。\n") + str(result["description"])
			result["warning"] = Locale.text("风险：立即进入战斗；周围普通敌人不会计入试炼进度。")
			result["prompt"] = Locale.text("E · 开始战斗试炼") if status == "idle" else Locale.format("试炼进行中 · 剩余 %d", [int(target.get("remaining", 0))])
			result["affordable"] = status == "idle"
		_:
			var label: String = "三选一商店" if facility == "choice" else ("装备仓" if facility == "equipment" else "补给箱")
			result["title"] = Locale.text(label) + " · " + str(result["title"])
			result["description"] = Locale.format("支付%d金币；奖励落地后再按E选择。\n", [price]) + str(result["description"])
			if facility == "choice":
				result["description"] = Locale.text("同组三个终端仅可购买一个。\n") + str(result["description"])
			result["prompt"] = Locale.format("E · 支付 %d 金币", [price])
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
				_flush_coin_pickups()
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
			_notice(player, "金币不足：需要%d金币。", [cost])
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
		if category == "weapon":
			player.erase("melee")
			player.erase("attack_pose")
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
		var stage_pool: Array[String] = EnemyCatalog.pool(str(state.get("biome", "rainforest")))
		var kind: String = stage_pool[index % stage_pool.size()]
		var y: float = _surface_below(x, Vector2(chest["pos"]).y - 35.0) - 17.0
		var enemy: Dictionary = _spawn_enemy(kind, Vector2(x, y - 100.0 if bool(EnemyCatalog.definition(kind).get("flying", false)) else y), index == 0)
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


func _notice(player: Dictionary, message: String, arguments: Array = []) -> void:
	# Send untranslated templates and values: every client chooses its own UI language.
	_emit("notice", player["pos"], {"player": player["id"], "message": message if arguments.is_empty() else message % arguments, "message_key": message, "message_args": arguments.duplicate()})

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
							# Retain support for explicitly authored/legacy coin pickups.
							_credit_coins(int(pickup["amount"]), position, target)
						"heal":
							target["hp"] = minf(float(target["max_hp"]), float(target["hp"]) + int(pickup["amount"]))
					if kind != "coin":
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
	_flush_coin_pickups()
	events.clear()
	state["stage"] = stage
	state["stage_time"] = 0.0
	state["enemies"] = []
	state["projectiles"] = []
	state["pickups"] = []
	state["chests"] = []
	state["deployables"] = []
	state["effects"] = []
	state["proc_effects"] = []
	_pending_projectiles.clear()
	_projectiles_stepping = false
	state["hazards"] = []
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
		_cancel_movement_ability(player)
		_cancel_guard(player)
		player["dash_id"] = 0
		player["guard_id"] = 0
		player["stun_timer"] = 0.0
		player["drop_timer"] = 0.0
		player["shield"] = 0.0
		player["shield_timer"] = 0.0
		player["jumps"] = 0
		player["jump_rising"] = false
		player["land_ready"] = false
		player["phoenix_spent"] = 0
		player["chrono_timer"] = 0.0
		player["momentum_timer"] = 0.0
		player["nova_cd"] = 0.0
		player["attack_count"] = 0
		Procs.reset(player)
		player.erase("melee")
		player.erase("attack_pose")
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
	if enemy.has("radius"):
		return float(enemy["radius"])
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
		if type not in ["notice", "pickup", "interact", "gate", "revive", "stage", "win", "lose", "ability"]:
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
	var event: Dictionary = {"type": type, "pos": position, "stage": int(state.get("stage", 1))}
	event.merge(extra, true)
	if event.has("weapon") and type in ["shoot", "slash"]:
		var wielder: Dictionary = Dictionary(state.get("players", {})).get(int(event.get("player", -1)), {})
		var action: Dictionary = wielder.get("attack_pose", {})
		if not action.is_empty() and str(action.weapon) == str(event.weapon):
			event.merge({"attack_id":int(action.id), "duration":float(action.duration), "interval":float(action.interval)}, false)
	if type in ["shoot", "hit", "explosion", "slash", "dash"]:
		var actor: int = int(extra.get("owner", extra.get("player", -1)))
		if bool(extra.get("friendly", false)):
			actor = -1
		event.merge(_visual_data(actor), false)
	events.append(event)
