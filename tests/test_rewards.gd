extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const STARTERS: Array[String] = ["pulse_rifle", "arc_blade", "grenade", "shockwave"]
const GRADES: Dictionary = {"common": 0, "uncommon": 1, "rare": 2, "legendary": 3}
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_test_distribution_and_seed()
	_test_equipment_exclusions()
	_test_history_recovery()
	_test_choice_groups()
	_test_reward_quality()
	print("REWARDS_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _fresh(seed_value: int = 20261004):
	var simulation = Simulation.new()
	simulation.start_run([{"id": 1, "name": "Drop sampler", "character": "ranger"}, {"id": 2, "name": "Teammate", "character": "vanguard"}], seed_value)
	return simulation

func _test_distribution_and_seed() -> void:
	var simulation = _fresh()
	simulation.state.chests.clear()
	simulation.state.pickups.clear()
	simulation.state.loot_history = {"gear": [], "passive": []}
	var counts: Dictionary = {"passive": 0, "weapon": 0, "equipment": 0}
	var valid: bool = true
	var starter_count: int = 0
	var recent: Array[String] = []
	var adjacent_gear_duplicate: bool = false
	for index in range(12000):
		var id: String = simulation._random_loot("ambient")
		var definition: Dictionary = Simulation.loot_definition(id)
		valid = valid and not definition.is_empty() and GRADES.has(definition.get("rarity", ""))
		var category: String = str(definition.get("category", "invalid"))
		counts[category] = int(counts.get(category, 0)) + 1
		if id in STARTERS:
			starter_count += 1
		if category != "passive":
			adjacent_gear_duplicate = adjacent_gear_duplicate or (not recent.is_empty() and recent.back() == id)
			recent.append(id)
	_check(valid and starter_count == 0, "12000 ordinary rewards resolve to real four-tier items and never roll starting equipment")
	_check(absf(float(counts.passive) / 12000.0 - 0.88) < 0.025 and absf(float(counts.weapon) / 12000.0 - 0.07) < 0.018 and absf(float(counts.equipment) / 12000.0 - 0.05) < 0.015, "Ordinary rewards remain approximately 88%% relic / 7%% weapon / 5%% active with history enabled: %s" % counts)
	_check(not adjacent_gear_duplicate, "Equipment rewards cannot repeat immediately while other equipment remains available")
	var first = _fresh(51392)
	var second = _fresh(51392)
	var equal_sequence: bool = true
	for index in range(300):
		equal_sequence = equal_sequence and first._random_loot("ambient") == second._random_loot("ambient")
	_check(equal_sequence and first.state.loot_history == second.state.loot_history, "Identical authority seeds reproduce both loot sequence and anti-repeat history")
	var snapshot: Dictionary = first.get_snapshot()
	var replica = _fresh()
	replica.apply_snapshot(snapshot)
	snapshot.loot_history.clear()
	_check(replica.state.loot_history == first.state.loot_history, "Loot-history snapshot state is deep-copied rather than aliased")
	print("LOOT_DISTRIBUTION samples=12000 counts=", counts)

func _test_equipment_exclusions() -> void:
	var simulation = _fresh()
	simulation.state.players[1].weapon = "scattergun"
	simulation.state.players[1].equipment = "repair_field"
	simulation.state.players[2].weapon = "railgun"
	simulation.state.players[2].equipment = "aegis"
	var excluded: Array[String] = STARTERS.duplicate()
	excluded.append_array(["scattergun", "repair_field", "railgun", "aegis"])
	var world_gear: Array[String] = ["flamethrower", "graviton"]
	for id in world_gear:
		simulation._spawn_pickup(simulation.state.spawn, "item", id, 1)
		excluded.append(id)
	var avoided: bool = true
	for index in range(1200):
		avoided = avoided and str(simulation._random_loot("ambient")) not in excluded
	_check(avoided, "Random equipment excludes both teammates' equipped slots and existing ground gear")
	for definition in Simulation.weapon_catalog() + Simulation.equipment_catalog():
		simulation._spawn_pickup(simulation.state.spawn, "item", str(definition.id), 1)
	var safe_fallback: bool = true
	for index in range(400):
		var definition: Dictionary = Simulation.loot_definition(simulation._random_loot("ambient"))
		safe_fallback = safe_fallback and not definition.is_empty() and definition.category == "passive"
	_check(safe_fallback, "Exhausting all gear candidates safely falls back to stackable relics without empty or duplicate gear rewards")

func _test_history_recovery() -> void:
	var fresh = _fresh()
	var reserved: Array[String] = []
	for chest in fresh.state.chests:
		if Simulation.loot_definition(str(chest.get("item", ""))).get("category", "passive") != "passive":
			reserved.append(str(chest.item))
	var late_gear: int = 0
	var avoided: bool = true
	for index in range(3000):
		var id: String = fresh._random_loot("ambient")
		avoided = avoided and id not in reserved
		if index >= 2000 and Simulation.loot_definition(id).category != "passive": late_gear += 1
	_check(late_gear >= 50 and avoided, "A real unopened stage continues producing gear after history fills without duplicating reserved facility gear")
	var recoverable: bool = true
	for available_count in range(2, 9):
		var simulation = _fresh(421 + available_count)
		simulation.state.chests.clear()
		simulation.state.loot_history = {"gear": [], "passive": []}
		var allowed: Array[String] = []
		var hard_blocked: Array[String] = STARTERS.duplicate()
		for definition in Simulation.weapon_catalog() + Simulation.equipment_catalog():
			if definition.id in STARTERS: continue
			if allowed.size() < available_count:
				allowed.append(str(definition.id))
			else:
				hard_blocked.append(str(definition.id))
				simulation._spawn_pickup(simulation.state.spawn, "item", str(definition.id), 1)
		var tail_count: int = 0
		var previous: String = ""
		for index in range(1600):
			var id: String = simulation._random_loot("ambient")
			recoverable = recoverable and id not in hard_blocked
			if Simulation.loot_definition(id).category != "passive":
				recoverable = recoverable and id in allowed and id != previous
				previous = id
				if index >= 800: tail_count += 1
		_check(tail_count >= 15, "A hard-available pool of %d gear items still yields late rewards after recent-history exhaustion" % available_count)
	_check(recoverable, "History recovery never violates equipped, ground or starter exclusions and avoids consecutive gear duplicates")

func _test_choice_groups() -> void:
	var simulation = _fresh()
	var unique: bool = true
	var composition: bool = true
	var groups_tested: int = 0
	for stage in range(1, 4):
		simulation._build_stage(stage)
		var groups: Dictionary = {}
		for chest in simulation.state.chests:
			if chest.type == "choice":
				if not groups.has(chest.group):
					groups[chest.group] = []
				groups[chest.group].append(str(chest.item))
		for choices in groups.values():
			groups_tested += 1
			var ids: Dictionary = {}
			var relics: int = 0
			for id in choices:
				unique = unique and not ids.has(id) and id not in STARTERS
				ids[id] = true
				if Simulation.loot_definition(id).category == "passive":
					relics += 1
			composition = composition and choices.size() == 3 and relics >= 2
	_check(groups_tested >= 3 and unique, "Every authored three-choice group contains unique non-starter item IDs across all stages")
	_check(composition, "Three-choice groups offer at least two relics and at most one replaceable equipment item")

func _quality(stage: int, source: String) -> float:
	var simulation = _fresh(97013)
	simulation._build_stage(stage)
	var sum: float = 0.0
	for index in range(5000):
		var definition: Dictionary = Simulation.loot_definition(simulation._random_loot(source))
		sum += float(GRADES.get(definition.get("rarity", ""), -10))
	return sum / 5000.0

func _test_reward_quality() -> void:
	var ordinary: float = _quality(1, "ambient")
	var later: float = _quality(3, "ambient")
	var boss: float = _quality(1, "boss")
	var trial: float = _quality(1, "trial")
	_check(later > ordinary + 0.12, "Later-stage reward samples shift measurably toward higher item tiers")
	_check(boss > ordinary + 0.2 and trial > ordinary + 0.1, "Boss and trial reward samples have meaningfully higher rarity than ordinary early rewards")
	print("RARITY_METRICS ambient_stage1=", ordinary, " ambient_stage3=", later, " boss=", boss, " trial=", trial)
