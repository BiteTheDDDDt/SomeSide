class_name SideProcRules
extends RefCounted

## Serializable counters only. The simulation owns spawning and damage; these
## rules never run from player prediction or recursively from secondary hits.
const MAX_AURAS: int = 8
const MISSILE: Dictionary = {"range": 600.0, "cone": 80.0, "delay": 0.0, "duration": 1.15, "rate": 160.0, "turn": 110.0}
const COOLDOWNS: Array[String] = ["missile_cd", "landing_cd", "halo_cd", "ranger_cd", "vanguard_cd"]

static func reset(player: Dictionary) -> void:
	player.proc_state = {"missile_cd": 0.0, "landing_cd": 0.0, "halo_cd": 0.0,
		"ranger_cd": 0.0, "vanguard_cd": 0.0, "ranger_hits": 0, "ranger_window": 0.0,
		"ranger_seen": [], "hurt_charge": 0.0, "landing_group": -1, "landing_hits": []}
	player.reactive_shield = 0.0
	player.reactive_shield_timer = 0.0
	player.proc_epoch = 0
	player.fall_peak_y = Vector2(player.get("pos", Vector2.ZERO)).y

static func ensure(player: Dictionary) -> Dictionary:
	if not player.has("proc_state"): reset(player)
	return player.proc_state

static func cancel(player: Dictionary) -> void:
	var state: Dictionary = ensure(player)
	state.ranger_hits = 0
	state.ranger_window = 0.0
	state.hurt_charge = 0.0
	state.landing_hits = []
	state.landing_group = -1
	player.reactive_shield = 0.0
	player.reactive_shield_timer = 0.0
	player.fall_peak_y = Vector2(player.get("pos", Vector2.ZERO)).y

static func tick(player: Dictionary, dt: float) -> void:
	var state: Dictionary = ensure(player)
	for key: String in COOLDOWNS: state[key] = maxf(0.0, float(state[key]) - dt)
	state.ranger_window = maxf(0.0, float(state.ranger_window) - dt)
	if float(state.ranger_window) <= 0.0: state.ranger_hits = 0
	player.reactive_shield_timer = maxf(0.0, float(player.get("reactive_shield_timer", 0.0)) - dt)
	if float(player.reactive_shield_timer) <= 0.0: player.reactive_shield = 0.0

static func primary_hit(player: Dictionary, attack_id: int) -> bool:
	if bool(player.get("dead", false)) or str(player.get("character", "")) != "ranger" or attack_id <= 0: return false
	var state: Dictionary = ensure(player)
	if attack_id in state.ranger_seen: return false
	state.ranger_seen.append(attack_id)
	if state.ranger_seen.size() > 64: state.ranger_seen.pop_front()
	if float(state.ranger_cd) > 0.0: return false
	state.ranger_window = 2.0
	state.ranger_hits = mini(6, int(state.ranger_hits) + 1)
	if int(state.ranger_hits) < 6: return false
	state.ranger_hits = 0
	state.ranger_window = 0.0
	state.ranger_cd = 3.0
	return true

static func hurt(player: Dictionary, hp_lost: float) -> bool:
	if bool(player.get("dead", false)) or str(player.get("character", "")) != "vanguard" or hp_lost <= 0.0: return false
	var state: Dictionary = ensure(player)
	if float(state.vanguard_cd) > 0.0: return false
	state.hurt_charge = minf(30.0, float(state.hurt_charge) + hp_lost)
	if float(state.hurt_charge) < 30.0: return false
	state.hurt_charge = 0.0
	state.vanguard_cd = 6.0
	player.reactive_shield = 10.0
	player.reactive_shield_timer = 3.0
	return true

static func missile_damage(stacks: int) -> float:
	return 18.0 + 6.0 * clampi(stacks - 1, 0, 5)

static func landing_damage(stacks: int) -> float:
	return 12.0 + 4.0 * clampi(stacks - 1, 0, 5)

static func halo_damage(stacks: int) -> float:
	return 8.0 + 2.0 * clampi(stacks - 1, 0, 5)

static func halo_radius(stacks: int) -> float:
	return 105.0 + 5.0 * clampi(stacks - 1, 0, 5)
