extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const DT = 1.0 / 60.0
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_test_catalogs()
	_test_single_jump_and_feathers()
	_test_ground_loot()
	_test_exact_and_contested_pickup()
	_test_overlapping_candidates()
	_test_gear_replacement()
	_test_weapon_behaviors()
	_test_active_behaviors()
	_test_harmful_relic()
	_test_facilities()
	_test_rare_drops()
	print("LOOT_TEST_RESULT passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)


func _fresh(players: int = 1):
	var simulation = Simulation.new()
	var roster: Array = []
	for index in range(players):
		roster.append({"id": index + 1, "name": "Loot Tester", "character": "ranger" if index == 0 else "vanguard"})
	simulation.start_run(roster, 20261004)
	simulation._spawn_clock = 9999.0
	return simulation


func _loot(simulation, item: String, position: Vector2, cooldown: float = 0.0) -> Dictionary:
	simulation._spawn_pickup(position, "item", item, 1)
	var pickup: Dictionary = simulation.state.pickups.back()
	pickup.cooldown = cooldown
	return pickup


func _target(pickup: Dictionary) -> Dictionary:
	return {"kind": "pickup", "id": pickup.id}


func _has_pickup(simulation, id: int) -> bool:
	for pickup in simulation.state.pickups:
		if int(pickup.id) == id:
			return true
	return false


func _item_drops(simulation) -> Array:
	return simulation.state.pickups.filter(func(pickup): return pickup.kind == "item")


func _test_catalogs() -> void:
	var categories = {"passive": Simulation.item_catalog(), "weapon": Simulation.weapon_catalog(), "equipment": Simulation.equipment_catalog()}
	var complete = true
	var ids: Dictionary = {}
	for category in categories:
		for item in categories[category]:
			var definition: Dictionary = Simulation.loot_definition(item.id)
			for field in ["id", "name", "description", "color", "category", "rarity", "warning"]:
				complete = complete and definition.has(field)
			complete = complete and definition.get("category", "") == category and not ids.has(item.id)
			ids[item.id] = true
	_check(complete, "Every unique loot ID resolves to a complete, categorized definition")
	_check(categories.passive.size() == 27 and categories.weapon.size() == 8 and categories.equipment.size() == 8, "The catalog contains 27 passive relics, eight weapons and eight active equipment choices")
	_check(Simulation.loot_definition("glass").warning.length() > 0, "The harmful glass relic explicitly declares its downside")
	var simulation = _fresh(2)
	_check(simulation.state.players[1].weapon == "pulse_rifle" and simulation.state.players[1].equipment == "grenade", "Ranger starts with the rifle and grenade slots")
	_check(simulation.state.players[2].weapon == "arc_blade" and simulation.state.players[2].equipment == "shockwave", "Vanguard starts with blade and shockwave slots")


func _test_single_jump_and_feathers() -> void:
	for feather_count in [0, 1, 2]:
		var simulation = _fresh()
		var player: Dictionary = simulation.state.players[1]
		player.items = {} if feather_count == 0 else {"feather": feather_count}
		var accepted_jumps = 0
		for press in range(4):
			var velocity_before: float = player.vel.y
			simulation.predict_player(player, {"jump": true}, DT)
			if player.vel.y < velocity_before - 50.0:
				accepted_jumps += 1
			for tick in range(7):
				simulation.predict_player(player, {}, DT)
		_check(accepted_jumps == feather_count + 1, "%d feather stacks permit exactly %d total jumps before landing" % [feather_count, feather_count + 1])
		for tick in range(180):
			simulation.predict_player(player, {}, DT)
		_check(player.grounded and player.jumps == 0, "Landing resets the jump budget with %d feather stacks" % feather_count)
	var without_feather = _shortcut_reached(0)
	var with_feather = _shortcut_reached(1)
	_check(not without_feather and with_feather, "An extra-air-jump relic unlocks a genuine elevated shortcut which one jump cannot reach")


func _shortcut_reached(feathers: int) -> bool:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	var ground_y: float = player.pos.y + Simulation.PLAYER_HALF.y
	var shortcut_y: float = ground_y - 190.0
	simulation.state.platforms = [Rect2(0, ground_y, simulation.state.world_size.x, 80), Rect2(player.pos.x - 100.0, shortcut_y, 220, 25)]
	player.items = {} if feathers == 0 else {"feather": feathers}
	for tick in range(160):
		simulation.predict_player(player, {"jump": tick == 0 or tick == 20}, DT)
		if tick > 20 and player.grounded and absf(player.pos.y + Simulation.PLAYER_HALF.y - shortcut_y) < 0.1:
			return true
	return false


func _test_ground_loot() -> void:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	var pickup = _loot(simulation, "overclock", player.pos)
	var pickup_id = int(pickup.id)
	for tick in range(120):
		simulation.step(DT, {})
	_check(player.items.is_empty() and _has_pickup(simulation, pickup_id), "Standing on ground loot for two seconds never equips or attracts it")
	player.pos = pickup.pos
	var shown: Dictionary = simulation.interaction_for(1)
	_check(shown.get("kind", "") == "pickup" and int(shown.get("id", -1)) == pickup_id, "The nearby interaction panel identifies the exact ground item")
	_check(shown.get("title", "").length() > 0 and shown.get("description", "").length() > 0 and shown.get("prompt", "").contains("E"), "Ground loot exposes its name, effect and manual action prompt")
	simulation._interact(player, _target(pickup))
	_check(int(player.items.get("overclock", 0)) == 1 and not _has_pickup(simulation, pickup_id), "Explicit interaction grants one passive and consumes its world object")
	var coins = player.coins
	simulation._spawn_pickup(player.pos, "coin", "", 4)
	player.hp = player.max_hp - 20.0
	simulation._spawn_pickup(player.pos, "heal", "", 10)
	for tick in range(30):
		simulation.step(DT, {})
	_check(player.coins > coins and player.hp > player.max_hp - 20.0, "Currency and healing retain automatic collection")


func _test_exact_and_contested_pickup() -> void:
	var simulation = _fresh(2)
	var first: Dictionary = simulation.state.players[1]
	var second: Dictionary = simulation.state.players[2]
	second.pos = first.pos
	var intended = _loot(simulation, "capacitor", first.pos + Vector2(20, 0))
	var bystander = _loot(simulation, "overclock", first.pos)
	simulation._interact(first, _target(intended))
	_check(first.items.get("capacitor", 0) == 1 and first.items.get("overclock", 0) == 0 and _has_pickup(simulation, bystander.id), "Explicit E selects its shown ID even when another item is closer")
	simulation._interact(second, _target(intended))
	_check(second.items.is_empty() and _has_pickup(simulation, bystander.id), "A stale target cannot silently substitute another nearby item")
	var contested = _loot(simulation, "lens", first.pos)
	first.interact_cd = 0.0
	second.interact_cd = 0.0
	var command = {"interact": true, "interact_target": _target(contested)}
	simulation.step(DT, {1: command, 2: command})
	_check(int(first.items.get("lens", 0)) + int(second.items.get("lens", 0)) == 1, "Two players requesting the same loot in one tick receive only one grant")
	var far = _loot(simulation, "moss", first.pos + Vector2(500, 0))
	simulation._interact(first, _target(far))
	_check(_has_pickup(simulation, far.id) and first.items.get("moss", 0) == 0, "Authority rejects an exact target outside interaction range")
	var replica = _fresh(2)
	replica.apply_snapshot(simulation.get_snapshot())
	_check(replica.interaction_for(1) == simulation.interaction_for(1), "Interaction selection is reproducible on replicated state without RNG")


func _test_gear_replacement() -> void:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	player.fire_cd = 0.8
	var weapon = _loot(simulation, "railgun", player.pos)
	simulation._interact(player, _target(weapon))
	_check(player.weapon == "railgun" and not player.items.has("railgun"), "Picking a weapon replaces the primary slot instead of becoming a passive")
	var dropped_rifle: Dictionary = {}
	for pickup in _item_drops(simulation):
		if pickup.item == "pulse_rifle":
			dropped_rifle = pickup
	_check(not dropped_rifle.is_empty(), "Replacing the primary weapon places its predecessor on the ground")
	_check(player.fire_cd >= 0.8, "Weapon swapping cannot refresh an existing fire cooldown")
	player.skill_cd = 6.0
	var equipment = _loot(simulation, "aegis", player.pos, 9.0)
	simulation._interact(player, _target(equipment))
	_check(player.equipment == "aegis" and player.skill_cd >= 9.0, "Active replacement preserves the longer of current and dropped cooldowns")
	var old_equipment: Dictionary = {}
	for pickup in _item_drops(simulation):
		if pickup.item == "grenade":
			old_equipment = pickup
	_check(not old_equipment.is_empty() and old_equipment.get("cooldown", 0.0) >= 6.0, "The unequipped active item retains its remaining cooldown on the ground")
	if not old_equipment.is_empty():
		var cooldown_before = old_equipment.cooldown
		for tick in range(30):
			simulation.step(DT, {})
		_check(old_equipment.cooldown < cooldown_before and old_equipment.cooldown > 0.0, "Dropped equipment cooldown elapses normally without resetting")
		player.pos = old_equipment.pos
		var current_cooldown = player.skill_cd
		simulation._interact(player, _target(old_equipment))
		_check(player.equipment == "grenade" and player.skill_cd >= current_cooldown, "Swapping equipment back cannot bypass the currently active cooldown")


func _test_overlapping_candidates() -> void:
	var simulation = _fresh(2)
	var player: Dictionary = simulation.state.players[1]
	var glass = _loot(simulation, "glass", player.pos)
	var feather = _loot(simulation, "feather", player.pos)
	var choices: Array = simulation.interaction_candidates(1)
	_check(choices.size() >= 2 and choices[0].id == glass.id and choices[1].id == feather.id, "Overlapping harmful and beneficial items both remain selectable in a stable order")
	var replica = _fresh(2)
	replica.apply_snapshot(simulation.get_snapshot())
	_check(replica.interaction_candidates(1) == choices, "Replicated state preserves the same ordered interaction candidates")
	simulation._interact(player, {"kind": choices[1].kind, "id": choices[1].id})
	_check(player.items.get("feather", 0) == 1 and player.items.get("glass", 0) == 0 and _has_pickup(simulation, glass.id), "Selecting the second overlapping item grants the feather without forcing the harmful relic")
	var teammate: Dictionary = simulation.state.players[2]
	teammate.pos = player.pos
	teammate.dead = true
	teammate.hp = 0.0
	_check(simulation.interaction_candidates(1)[0].kind == "revive", "A downed teammate retains emergency priority over overlapping loot")


func _test_harmful_relic() -> void:
	var simulation = _fresh()
	var player: Dictionary = simulation.state.players[1]
	var initial_hp = player.max_hp
	var initial_damage = simulation._damage_scale(player)
	var glass = _loot(simulation, "glass", player.pos)
	var prompt: Dictionary = simulation.interaction_for(1)
	_check(prompt.get("warning", "").length() > 0, "Harm is visible in the interaction data before accepting a glass relic")
	simulation._interact(player, _target(glass))
	_check(player.max_hp < initial_hp and player.hp <= player.max_hp and simulation._damage_scale(player) > initial_damage, "Accepting glass trades maximum health for damage without invalid health")
	for index in range(30):
		simulation._grant_item(player, "glass")
	_check(player.max_hp >= initial_hp * 0.2 - 0.01 and player.hp <= player.max_hp, "Repeated harmful relics respect the declared health floor")


func _test_weapon_behaviors() -> void:
	for weapon in ["pulse_rifle", "scattergun"]:
		var simulation = _fresh()
		var player: Dictionary = simulation.state.players[1]
		player.weapon = weapon
		player.aim = Vector2.UP
		simulation.step(DT, {1: {"aim": Vector2.UP, "fire": true}})
		_check(simulation.state.projectiles.size() == (1 if weapon == "pulse_rifle" else 6), "%s emits its distinct single-shot or six-pellet attack" % weapon)
		if weapon == "scattergun":
			var angles: Dictionary = {}
			var limited_range = true
			for projectile in simulation.state.projectiles:
				angles[snappedf(projectile.vel.angle(), 0.01)] = true
				limited_range = limited_range and projectile.ttl < 0.5
			_check(angles.size() == 6 and limited_range, "Scattergun pellets spread into separate directions and have limited range")
	var blade_sim = _fresh()
	var wielder: Dictionary = blade_sim.state.players[1]
	wielder.weapon = "arc_blade"
	wielder.hp = 50.0
	var front: Dictionary = blade_sim._spawn_enemy("crawler", wielder.pos + Vector2(70, 0))
	var behind: Dictionary = blade_sim._spawn_enemy("crawler", wielder.pos - Vector2(70, 0))
	front.hp = 1000.0
	behind.hp = 1000.0
	blade_sim._fire_weapon(wielder)
	blade_sim._step_melee(wielder, float(wielder.melee.duration) * preload("res://scripts/melee_motion.gd").IMPACT)
	_check(front.hp < 1000.0 and behind.hp == 1000.0 and wielder.hp > 50.0, "An equipped blade damages the aimed arc and heals its wielder while sparing enemies behind")
	var rail_sim = _fresh()
	var shooter: Dictionary = rail_sim.state.players[1]
	shooter.weapon = "railgun"
	shooter.pos = Vector2(200, 500)
	var targets: Array = []
	for x in [250.0, 265.0, 295.0, 330.0]:
		var enemy: Dictionary = rail_sim._spawn_enemy("crawler", Vector2(x, 500))
		enemy.hp = 1000.0
		targets.append(enemy)
	rail_sim._fire_weapon(shooter)
	rail_sim._step_projectiles(DT)
	var first_hp = targets[0].hp
	for tick in range(6):
		rail_sim._step_projectiles(DT)
	_check(targets[0].hp == first_hp and first_hp < 1000.0, "A piercing rail shot cannot damage the same overlapping target on later frames")
	_check(targets[0].hp < 1000.0 and targets[1].hp < 1000.0 and targets[2].hp < 1000.0 and targets[3].hp == 1000.0, "A rail shot pierces exactly the first three targets")


func _test_active_behaviors() -> void:
	var repair_sim = _fresh(4)
	var healer: Dictionary = repair_sim.state.players[1]
	healer.equipment = "repair_field"
	for id in repair_sim.state.players:
		var teammate: Dictionary = repair_sim.state.players[id]
		teammate.pos = healer.pos + Vector2(50.0 * (int(id) - 1), 0)
		teammate.hp = 20.0
	repair_sim.state.players[3].pos = healer.pos + Vector2(400, 0)
	repair_sim.state.players[4].dead = true
	repair_sim.state.players[4].hp = 0.0
	repair_sim._use_skill(healer)
	_check(healer.hp > 20.0 and repair_sim.state.players[2].hp > 20.0, "Repair field heals its user and nearby living teammates")
	_check(repair_sim.state.players[3].hp == 20.0 and repair_sim.state.players[4].dead, "Repair field neither heals distant teammates nor substitutes for rescue")
	var shield_sim = _fresh()
	var bearer: Dictionary = shield_sim.state.players[1]
	bearer.equipment = "aegis"
	shield_sim.step(DT, {1: {"skill": true}})
	_check(bearer.shield > 0.0 and bearer.invuln > 0.0 and bearer.skill_cd > 0.0, "Aegis grants a temporary shield and starts its cooldown")
	for tick in range(365):
		shield_sim.step(DT, {})
	_check(bearer.shield == 0.0, "Aegis protection expires instead of becoming permanent")
	var shock_sim = _fresh()
	var attacker: Dictionary = shock_sim.state.players[1]
	attacker.equipment = "shockwave"
	var target: Dictionary = shock_sim._spawn_enemy("crawler", attacker.pos + Vector2(100, 0))
	target.hp = 1000.0
	shock_sim.step(DT, {1: {"skill": true, "aim": Vector2.RIGHT}})
	_check(target.hp < 1000.0 and attacker.dash_timer > 0.0 and attacker.invuln > 0.0, "Equipped shockwave combines area damage, directed movement and brief protection")
	var grenade_sim = _fresh()
	grenade_sim.step(DT, {1: {"skill": true, "aim": Vector2.UP}})
	_check(grenade_sim.state.projectiles.size() == 1 and grenade_sim.state.projectiles[0].kind == "grenade", "The grenade active throws an aimed explosive instead of using a character-bound skill")


func _find_facility(simulation, kind: String) -> Dictionary:
	for chest in simulation.state.chests:
		if chest.get("type", "cache") == kind:
			return chest
	return {}


func _open_facility(simulation, player: Dictionary, chest: Dictionary) -> void:
	player.pos = chest.pos
	simulation._interact(player, {"kind": "chest", "id": chest.id})


func _test_facilities() -> void:
	for kind in ["cache", "equipment", "choice", "blood", "combat"]:
		var simulation = _fresh()
		var player: Dictionary = simulation.state.players[1]
		var chest: Dictionary = _find_facility(simulation, kind)
		_check(not chest.is_empty(), "The map offers a %s facility" % kind)
		if chest.is_empty():
			continue
		player.coins = 1000
		var coins_before = player.coins
		var hp_before = player.hp
		var inventory_before: Dictionary = player.items.duplicate(true)
		_open_facility(simulation, player, chest)
		_check(player.items == inventory_before and player.weapon == "pulse_rifle" and player.equipment == "grenade", "%s rewards never auto-equip" % kind)
		if kind in ["cache", "equipment", "choice"]:
			_check(chest.opened and player.coins == coins_before - int(chest.cost), "%s charges exactly one displayed currency payment" % kind)
			_check(_item_drops(simulation).size() == 1, "%s emits one selectable ground reward" % kind)
			if kind == "equipment" and not _item_drops(simulation).is_empty():
				_check(Simulation.loot_definition(_item_drops(simulation)[0].item).category == "equipment", "Equipment facilities reward an active-slot item for explicit replacement")
			if kind == "choice":
				var locked = 0
				var coins_after = player.coins
				for sibling in simulation.state.chests:
					if sibling.get("group", -99) == chest.get("group", -98) and sibling.id != chest.id:
						if sibling.get("locked", false):
							locked += 1
						_open_facility(simulation, player, sibling)
				_check(locked >= 2 and player.coins == coins_after and _item_drops(simulation).size() == 1, "Choosing one of three terminals locks both siblings without extra charges or rewards")
		elif kind == "blood":
			_check(player.hp > 0.0 and player.hp < hp_before and player.coins == coins_before, "Blood facilities charge nonlethal health instead of currency")
			_check(_item_drops(simulation).size() == 1, "A blood payment creates one manual reward")
		else:
			_check(_item_drops(simulation).is_empty() and chest.get("status", "") == "active", "A combat shrine starts a linked wave without paying its reward early")
			var wave: Array = simulation.state.enemies.duplicate()
			_check(not wave.is_empty(), "Combat activation spawns its own challenge enemies")
			simulation._spawn_enemy("crawler", Vector2(40, player.pos.y))
			var ambient: Dictionary = simulation.state.enemies.back()
			for enemy in wave:
				simulation._damage_enemy(enemy, 1000000.0, 1, false, 0)
			simulation.step(DT, {})
			_check(chest.get("status", "") == "cleared" and ambient.hp > 0.0, "The combat reward unlocks after its linked wave dies even while ambient enemies remain")
			_check(_item_drops(simulation).size() >= 1, "A cleared combat shrine emits its promised manual reward")


func _test_rare_drops() -> void:
	var counts: Array[int] = []
	for elite in [false, true]:
		var simulation = _fresh()
		var drops = 0
		for index in range(2000):
			simulation.state.enemies.clear()
			simulation.state.pickups.clear()
			simulation._spawn_enemy("crawler", simulation.state.players[1].pos + Vector2(600, 0), elite)
			var enemy: Dictionary = simulation.state.enemies.back()
			simulation._damage_enemy(enemy, 1000000.0, 1, false, 0)
			drops += _item_drops(simulation).size()
			var pickup_count = simulation.state.pickups.size()
			simulation._damage_enemy(enemy, 1000000.0, 1, false, 0)
			if simulation.state.pickups.size() != pickup_count:
				_check(false, "A dead enemy cannot roll rewards again")
				break
		counts.append(drops)
		_check(drops >= (100 if elite else 25) and drops <= (230 if elite else 110), "%s loot stays rare across 2000 seeded kills (%d drops)" % ["Elite" if elite else "Common", drops])
	_check(counts[1] > counts[0], "Elite enemies have a higher rare-drop rate than common enemies")
	var boss_sim = _fresh()
	boss_sim._spawn_enemy("boss", Vector2(800, 900))
	var boss: Dictionary = boss_sim.state.enemies.back()
	boss_sim._damage_enemy(boss, 1000000.0, 1, false, 0)
	_check(_item_drops(boss_sim).size() == 2, "A defeated boss drops two guaranteed manual loot objects")
	var total = boss_sim.state.pickups.size()
	boss_sim._damage_enemy(boss, 1000000.0, 1, false, 0)
	_check(boss_sim.state.pickups.size() == total, "Repeated death damage cannot duplicate guaranteed boss loot")
