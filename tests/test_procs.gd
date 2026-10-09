extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
const Rules = preload("res://scripts/proc_rules.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_catalog_and_drops()
	_test_missiles()
	_test_ranger()
	_test_landing()
	_test_halo()
	_test_vanguard()
	_test_lifecycle_and_budget()
	print("PROCS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS: ", label)
	else: failed += 1; push_error("FAIL: " + label)

func _fresh(character: String = "ranger", count: int = 1):
	var sim = Simulation.new()
	var roster: Array = []
	for id: int in range(1, count + 1): roster.append({"id": id, "name": "Proc probe", "character": character})
	sim.start_run(roster, 200021)
	sim.state.platforms = [Rect2(0, 1000, 7200, 100)]
	sim.state.floor_y = 1000.0
	sim.state.chests.clear()
	sim._spawn_clock = 9999.0
	for player: Dictionary in sim.state.players.values():
		player.pos = Vector2(1000, 979)
		player.vel = Vector2.ZERO
		player.grounded = true
		player.invuln = 0.0
		Rules.reset(player)
	sim.events.clear()
	return sim

func _dummy(sim, offset: Vector2 = Vector2(180, 0)) -> Dictionary:
	var enemy: Dictionary = sim._spawn_enemy("crawler", Vector2(sim.state.players[1].pos) + offset)
	enemy.hp = 10000.0; enemy.max_hp = 10000.0; enemy.attack_cd = 9999.0
	return enemy

func _shots(sim, kind: String) -> Array:
	return sim.state.projectiles.filter(func(p: Dictionary) -> bool: return str(p.kind) == kind)

func _proc_events(sim, kind: String) -> Array:
	return sim.events.filter(func(e: Dictionary) -> bool: return e.type == "proc" and e.kind == kind)

func _land(sim, held_ticks: int = 80, use_prediction: bool = false) -> int:
	var first_wave: int = -1
	for tick: int in range(100):
		var command: Dictionary = {"jump": tick == 0, "jump_held": tick < held_ticks}
		if use_prediction: sim.predict_player(sim.state.players[1], command, DT)
		else: sim._step_player(sim.state.players[1], command, DT)
		if not _shots(sim, "shock_wave").is_empty() and first_wave < 0: first_wave = tick
		if first_wave >= 0: break
	return first_wave

func _test_catalog_and_drops() -> void:
	_check(Content.passives().size() == 27 and Content.weapons().size() == 10 and Content.equipment().size() == 9, "The live catalog contains 27 relics and 10+9 equipment entries")
	var ranger: Dictionary = Content.character_passive("ranger")
	var vanguard: Dictionary = Content.character_passive("vanguard")
	_check(ranger.id == "pursuit_protocol" and vanguard.id == "reactive_plating" and ranger.id != vanguard.id, "Both character-owned passive abilities have distinct stable IDs")
	ranger.description = "mutated"
	_check(Content.character_passive("ranger").description != "mutated" and Content.definition("pursuit_protocol").is_empty(), "Character passive data is isolated and cannot enter random equipment slots")
	var sim = _fresh()
	var seen: Dictionary = {}
	for index: int in range(6000): seen[sim._random_loot("ambient")] = true
	for id: String in ["missile_pod", "landing_coil", "frost_halo"]:
		_check(seen.has(id) and Content.definition(id).category == "passive", id + " is obtainable from actual seeded random rewards")
	_check(Rules.missile_damage(1000) == 48 and Rules.landing_damage(1000) == 32 and Rules.halo_damage(1000) == 18 and Rules.halo_radius(1000) == 130, "All new stack contributions have explicit damage and radius caps")

func _test_missiles() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items = {"missile_pod": 1, "lens": 100, "piercer": 100}
	var enemy: Dictionary = _dummy(sim)
	for index: int in range(12): sim._damage_enemy(enemy, 1.0, 1, true, 0)
	var shots: Array = _shots(sim, "seeker_missile")
	_check(shots.size() == 1 and _proc_events(sim, "missile_pod").size() == 1, "Real direct critical hits trigger one missile under the 1.25s cooldown")
	var missile: Dictionary = shots[0]
	_check(missile.damage == 18.0 and missile.pierce == 1 and missile.proc and missile.guidance.target_id == enemy.id, "Missiles retain their own damage/pierce cap and a real locked target")
	_check(is_equal_approx(Vector2(missile.vel).length(), 500.0) and missile.ttl == 1.6, "Proc missiles use finite speed and lifetime")
	var before: float = enemy.hp
	for tick: int in range(100): sim._step_projectiles(DT)
	_check(is_equal_approx(before - float(enemy.hp), 18.0), "The actual curved proc missile hits for noncritical damage exactly once")
	_check(_proc_events(sim, "missile_pod").size() == 1 and player.proc_state.ranger_hits == 0, "Missile impact cannot trigger another pod or advance the character's main-weapon chain")
	var snapshot: Dictionary = player.proc_state.duplicate(true)
	var pickup: Dictionary = sim._spawn_pickup(player.pos, "item", "railgun", 1)
	sim._take_loot(player, pickup)
	_check(player.proc_state == snapshot, "Equipping a different weapon leaves all proc cooldowns and progress intact")
	var secondary = _fresh()
	secondary.state.players[1].items = {"missile_pod": 8, "frost_halo": 8, "nova": 8, "ember": 8, "arc": 8, "toxin": 8, "frost": 8, "lens": 100}
	var small: Dictionary = _dummy(secondary)
	small.hp = 1.0
	var witness: Dictionary = _dummy(secondary, Vector2(205, 0))
	secondary._damage_enemy(small, 50.0, 1, false, 1)
	_check(secondary.state.projectiles.is_empty() and secondary.state.proc_effects.is_empty() and witness.hp == 10000.0, "Secondary lethal damage cannot recursively trigger new relics or old ember/arc/nova chains")
	_check(not witness.has("poison_timer") or float(witness.poison_timer) == 0.0, "Secondary damage does not leak into direct-hit status application")
	_check(secondary.state.kills == 1 and not secondary.state.coin_pickups.is_empty(), "Proc kills still earn the normal kill and gold rewards")

func _test_ranger() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	var target: Dictionary = _dummy(sim, Vector2(90, -5))
	for attack: int in range(5):
		sim._fire_weapon(player)
		for tick: int in range(8): sim._step_projectiles(DT)
		Rules.tick(player, 1.1)
	_check(player.proc_state.ranger_hits == 5 and _shots(sim, "seeker_missile").is_empty(), "Five spaced actual rifle hits accumulate despite the chain taking over two seconds total")
	sim._fire_weapon(player)
	for tick: int in range(6):
		sim._step_projectiles(DT)
		if not _shots(sim, "seeker_missile").is_empty(): break
	var found: Array = _shots(sim, "seeker_missile")
	_check(found.size() == 1 and found[0].damage == 8.0 and found[0].proc_source == "pursuit_protocol", "The sixth actual main-weapon hit launches the Ranger's modest 8-damage pursuit missile")
	_check(not found.is_empty() and found[0].age == 0.0 and found[0].pos == found[0].origin, "An impact-triggered missile is queued until the next physics step, never inserted into an active collision iteration")
	var burst = _fresh()
	burst.state.players[1].weapon = "scattergun"
	_dummy(burst, Vector2(70, 0))
	burst._fire_weapon(burst.state.players[1])
	for tick: int in range(20): burst._step_projectiles(DT)
	_check(burst.state.players[1].proc_state.ranger_hits == 1, "Six pellets from one shotgun action count as one character passive hit")
	Rules.tick(burst.state.players[1], 2.01)
	_check(burst.state.players[1].proc_state.ranger_hits == 0, "More than two seconds between valid hits clears unfinished pursuit progress")
	var melee = _fresh()
	melee.state.players[1].weapon = "arc_blade"
	_dummy(melee, Vector2(80, 0)); _dummy(melee, Vector2(90, 10))
	melee._fire_weapon(melee.state.players[1]); melee._step_melee(melee.state.players[1], 0.2)
	_check(melee.state.players[1].proc_state.ranger_hits == 1, "A Ranger using a blade still advances once for a multi-enemy swing")
	var stale = _fresh()
	var data: Dictionary = stale.state.players[1]
	Rules.primary_hit(data, 1); Rules.primary_hit(data, 2); Rules.primary_hit(data, 1)
	_check(data.proc_state.ranger_hits == 2, "Delayed piercing or returning projectiles cannot count an earlier attack again")
	var vanguard = _fresh("vanguard")
	for id: int in range(1, 20): Rules.primary_hit(vanguard.state.players[1], id)
	_check(vanguard.state.players[1].proc_state.ranger_hits == 0, "Vanguard never receives the Ranger's weapon-hit passive")
	_check(target.hp < 10000.0, "Pursuit progress comes from actual enemy health loss")

func _test_landing() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items.landing_coil = 1
	_check(_land(sim) > 0 and _shots(sim, "shock_wave").size() == 2, "A real full base jump has enough fall height to create two landing waves")
	var center: Dictionary = _dummy(sim, Vector2(0, 10))
	var left: Dictionary = _dummy(sim, Vector2(-95, 10))
	var right: Dictionary = _dummy(sim, Vector2(95, 10))
	for tick: int in range(30): sim._step_projectiles(DT)
	_check(center.hp == 9988.0 and left.hp == 9988.0 and right.hp == 9988.0, "Both directions hit, but their shared launch overlap cannot double-hit the same enemy")
	_check(_proc_events(sim, "landing_coil").size() == 1 and _shots(sim, "shock_wave").is_empty(), "One landing emits one proc event and its waves expire after 0.45s")
	var short_jump = _fresh()
	short_jump.state.players[1].items.landing_coil = 1
	_check(_land(short_jump, 2) == -1 and short_jump.state.projectiles.is_empty(), "A short tapped jump cannot farm landing waves below the 90-unit threshold")
	var predicted = _fresh()
	predicted.state.players[1].items.landing_coil = 1
	_land(predicted, 80, true)
	_check(predicted.state.projectiles.is_empty() and predicted.events.is_empty(), "Prediction follows the same jump but never spawns landing damage or feedback")
	var crowded = _fresh()
	crowded.state.players[1].items.landing_coil = 1000
	for index: int in range(12): _dummy(crowded, Vector2((index - 6) * 16.0, 10))
	crowded._landing_proc(crowded.state.players[1], 100.0)
	for tick: int in range(30): crowded._step_projectiles(DT)
	var damaged: int = 0
	for enemy: Dictionary in crowded.state.enemies:
		if enemy.hp < 10000: damaged += 1
	_check(damaged == 8 and crowded.state.players[1].proc_state.landing_hits.size() == 8, "Even extreme stacks cap each landing at eight unique damaged enemies")
	crowded._landing_proc(crowded.state.players[1], 100.0)
	_check(crowded.state.projectiles.is_empty(), "A second fall cannot bypass the landing internal cooldown")
	var airborne = _fresh()
	airborne.state.players[1].items.landing_coil = 1
	airborne.state.players[1].pos.y -= 140.0
	airborne.state.players[1].grounded = false
	airborne.state.players[1].land_ready = false
	for tick: int in range(60): airborne._step_player(airborne.state.players[1], {}, DT)
	_check(airborne.state.projectiles.is_empty(), "A spawned or revived body cannot claim an initial fall as a landing attack")

func _test_halo() -> void:
	var sim = _fresh()
	var player: Dictionary = sim.state.players[1]
	player.items.frost_halo = 1
	var victim: Dictionary = _dummy(sim, Vector2(80, 0)); victim.hp = 1
	var near: Dictionary = _dummy(sim, Vector2(100, 0))
	sim._damage_enemy(victim, 2.0, 1, true, 0)
	_check(sim.state.proc_effects.size() == 1 and near.hp == 10000.0, "A direct kill starts a timed aura rather than immediate extra damage")
	for tick: int in range(90): sim._step_proc_effects(DT)
	_check(near.hp == 9976.0 and sim.state.proc_effects.is_empty(), "The 1.5s aura applies exactly three 8-damage pulses, then disappears")
	_check(near.slow_factor == 0.75 and is_equal_approx(near.slow_timer, 0.65), "Aura pulses apply the advertised bounded 25 percent slow")
	var another: Dictionary = _dummy(sim, Vector2(80, 0)); another.hp = 1
	sim._damage_enemy(another, 2.0, 1, true, 0)
	_check(sim.state.proc_effects.is_empty(), "A second direct kill cannot ignore the four-second aura cooldown")
	var moving = _fresh()
	moving.state.players[1].items.frost_halo = 1000
	var killed: Dictionary = _dummy(moving); killed.hp = 1
	moving._damage_enemy(killed, 5, 1, true, 0)
	moving.state.players[1].pos += Vector2(150, 0)
	moving._step_proc_effects(DT)
	_check(moving.state.proc_effects[0].pos == moving.state.players[1].pos and moving.state.proc_effects[0].radius == 130 and moving.state.proc_effects[0].damage == 18, "High stacks stay capped while the aura follows its living owner")
	var weak: Dictionary = _dummy(moving, Vector2(70, 0)); weak.hp = 1
	Rules.tick(moving.state.players[1], 4.1)
	for tick: int in range(30): moving._step_proc_effects(DT)
	_check(_proc_events(moving, "frost_halo").size() == 1, "An aura's own kill cannot spawn a new aura even after the cooldown is available")
	var merged = _fresh()
	merged.state.players[1].items = {"frost_halo": 1, "frost": 1}
	var trigger: Dictionary = _dummy(merged, Vector2(-70, 0)); trigger.hp = 1
	var slowed: Dictionary = _dummy(merged, Vector2(80, 0))
	merged._damage_enemy(trigger, 5.0, 1, true, 0)
	for tick: int in range(30): merged._step_proc_effects(DT)
	merged._damage_enemy(slowed, 1.0, 1, true, 0)
	_check(slowed.hp < 9992.0 and slowed.slow_factor == 0.75 and slowed.slow_timer == 1.5, "A genuine low-stack frost hit preserves the active stronger halo slow and extends its timer")
	merged.state.players[1].items.frost = 7
	merged._damage_enemy(slowed, 1.0, 1, true, 0)
	for tick: int in range(30): merged._step_proc_effects(DT)
	_check(slowed.slow_factor == 0.5 and slowed.slow_timer == 1.5, "A later halo pulse also preserves stronger direct frost without shortening its duration")
	slowed.slow_timer = 0.0
	merged.state.players[1].items.frost = 1
	merged._damage_enemy(slowed, 1.0, 1, true, 0)
	_check(slowed.slow_factor == 0.8 and slowed.slow_timer == 1.5, "Expired stronger slows cannot permanently strengthen a new weak frost hit")

func _test_vanguard() -> void:
	var sim = _fresh("vanguard")
	var player: Dictionary = sim.state.players[1]
	sim._damage_player(player, 15.0, Vector2(900, 979)); player.invuln = 0
	sim._damage_player(player, 15.0, Vector2(900, 979))
	_check(player.hp == 115.0 and player.reactive_shield == 10 and player.reactive_shield_timer == 3.0, "Thirty actual lost HP grants Vanguard ten independent shield points")
	_check(_proc_events(sim, "reactive_plating").size() == 1, "Reactive armor triggers one readable authority event")
	player.invuln = 0; sim._damage_player(player, 8.0, Vector2(900, 979))
	_check(player.hp == 115.0 and player.reactive_shield == 2.0 and player.proc_state.hurt_charge == 0.0, "Temporary armor absorbs damage without feeding itself")
	player.shield = 25.0; player.shield_timer = 5.0
	Rules.tick(player, 3.01)
	_check(player.reactive_shield == 0.0 and player.shield == 25.0 and player.shield_timer == 5.0, "Character shield expiry never clears independent Aegis or battery shields")
	player.invuln = 0; sim._damage_player(player, 25.0, Vector2.ZERO)
	_check(player.hp == 115.0 and player.proc_state.hurt_charge == 0.0, "Damage fully absorbed by an equipment shield does not count as actual HP loss")
	var armor = _fresh("vanguard")
	armor.state.players[1].items.plating = 5
	armor._damage_player(armor.state.players[1], 20.0, Vector2.ZERO)
	_check(armor.state.players[1].proc_state.hurt_charge == 15.0, "Armor counts health lost after mitigation rather than incoming raw damage")
	var dead = _fresh("vanguard")
	dead.state.players[1].hp = 10.0
	dead._damage_player(dead.state.players[1], 100, Vector2.ZERO)
	_check(dead.state.players[1].dead and dead.state.players[1].reactive_shield == 0 and _proc_events(dead, "reactive_plating").is_empty(), "Lethal damage cannot create a shield on a downed player")
	var phoenix = _fresh("vanguard")
	phoenix.state.players[1].items.phoenix = 1
	phoenix.state.players[1].hp = 10
	phoenix._damage_player(phoenix.state.players[1], 100, Vector2.ZERO)
	_check(not phoenix.state.players[1].dead and phoenix.state.players[1].reactive_shield == 0 and phoenix.state.players[1].proc_state.hurt_charge == 0, "Phoenix revival does not turn fatal overkill into a reactive shield")
	var ranger = _fresh()
	ranger._damage_player(ranger.state.players[1], 40, Vector2.ZERO)
	_check(ranger.state.players[1].reactive_shield == 0, "Ranger never receives the Vanguard's defensive passive")
	var blood = _fresh("vanguard")
	var altar: Dictionary = blood._make_chest("blood", blood.state.players[1].pos, 40, "feather")
	blood.state.chests.append(altar)
	blood._interact(blood.state.players[1], {"kind": "chest", "id": altar.id})
	_check(blood.state.players[1].hp == 105 and blood.state.players[1].proc_state.hurt_charge == 0 and blood.state.players[1].reactive_shield == 0, "A real blood offering cannot farm the defensive passive")

func _test_lifecycle_and_budget() -> void:
	var sim = _fresh("ranger", 4)
	var target: Dictionary = _dummy(sim)
	for player: Dictionary in sim.state.players.values():
		player.items = {"frost_halo": 6, "missile_pod": 6, "landing_coil": 6}
		sim._direct_proc(player, true, true, 0)
	_check(sim.state.proc_effects.size() == 4 and _shots(sim, "seeker_missile").size() == 4, "Four teammates own separate aura and missile states")
	var saved: Dictionary = sim.get_snapshot()
	var encoded: PackedByteArray = var_to_bytes(saved)
	var replica = _fresh()
	replica.apply_snapshot(bytes_to_var(encoded))
	replica._step_proc_effects(DT)
	replica._step_projectiles(DT)
	_check(var_to_bytes(saved) == encoded, "Advancing replicated aura and projectile state cannot mutate the source snapshot")
	var doomed: Dictionary = sim.state.players[1]
	doomed.hp = 1; doomed.invuln = 0
	sim._damage_player(doomed, 100.0, Vector2.ZERO)
	_check(sim.state.proc_effects.size() == 3 and _shots(sim, "seeker_missile").size() == 3, "Death removes only that owner's proc entities and leaves teammate effects intact")
	sim._build_stage(2)
	_check(sim.state.proc_effects.is_empty() and sim.state.projectiles.is_empty() and sim.state.players[1].proc_state.ranger_hits == 0, "Stage transitions atomically clear all proc entities and transient progress")
	var full = _fresh()
	full.state.players[1].items = {"missile_pod": 100, "landing_coil": 100, "frost_halo": 100}
	_dummy(full)
	for index: int in range(Simulation.MAX_PROJECTILES): full._spawn_projectile(Vector2(0, 200), Vector2.RIGHT, "player", "bullet", 1, 1, 1, 2)
	full._direct_proc(full.state.players[1], true, false, 0)
	full._landing_proc(full.state.players[1], 200.0)
	_check(full.state.projectiles.size() == Simulation.MAX_PROJECTILES and full._pending_projectiles.is_empty(), "Full projectile capacity safely rejects both missiles and the atomic two-wave action")
	for index: int in range(Rules.MAX_AURAS): full.state.proc_effects.append({"id": index, "owner": 1, "kind": "frost_halo", "pos": Vector2.ZERO, "ttl": 1.5, "pulse": 0.5, "duration": 1.5, "radius": 105, "damage": 8, "slow_factor": 0.75})
	full._direct_proc(full.state.players[1], false, true, 0)
	_check(full.state.proc_effects.size() == Rules.MAX_AURAS and full.events.size() <= 64, "Aura and cosmetic event budgets remain hard capped")
	_check(target.hp == 10000, "Creating effects never applies hidden same-frame aura damage")
	var revival = _fresh()
	var revived: Dictionary = revival.state.players[1]
	revived.items = {"phoenix": 1, "frost_halo": 1, "missile_pod": 1}
	_dummy(revival)
	revival._direct_proc(revived, true, true, 1)
	var old_missile: Dictionary = revival.state.projectiles[0].duplicate(true)
	revived.hp = 1; revival._damage_player(revived, 100, Vector2.ZERO)
	# Simulate an already queued same-tick emission from before the fatal hit.
	revival._pending_projectiles.append(old_missile)
	revival._step_projectiles(DT)
	_check(not revived.dead and revival.state.projectiles.is_empty() and revival.state.proc_effects.is_empty(), "Phoenix invalidates old queued proc generations instead of resurrecting their damage")
	var tomb = _fresh()
	tomb.state.players[1].dead = true
	tomb.state.players[1].items = {"missile_pod": 100, "frost_halo": 100}
	_dummy(tomb)
	tomb._direct_proc(tomb.state.players[1], true, true, 1)
	_check(tomb.state.projectiles.is_empty() and tomb.state.proc_effects.is_empty(), "A downed owner cannot trigger or queue new conditional attacks")
