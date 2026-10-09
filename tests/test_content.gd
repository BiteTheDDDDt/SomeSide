extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
const WeaponPose = preload("res://scripts/weapon_pose.gd")
const DT: float = 1.0 / 60.0
var passed: int = 0
var failed: int = 0
var exercised: Dictionary = {}

func _initialize() -> void:
	_test_definition_isolation()
	_test_rarity_contract()
	_test_core_relics()
	_test_utility_relics()
	_test_cooperative_magnet()
	_test_proc_relics()
	_test_advanced_weapons()
	_test_advanced_equipment()
	_test_conditional_relics()
	var missing: Array[String] = []
	for definition in Simulation.item_catalog() + Simulation.weapon_catalog() + Simulation.equipment_catalog():
		if not exercised.has(definition.id):
			missing.append(definition.id)
	_check(missing.is_empty(), "Every one of the 46 catalog IDs has an exercised gameplay effect: missing=%s" % [missing])
	print("CONTENT_TEST_RESULT passed=", passed, " failed=", failed)
	quit(0 if failed == 0 else 1)

func _test_definition_isolation() -> void:
	var original: Dictionary = Content.definition("pulse_rifle")
	var changed: Dictionary = Content.definition("pulse_rifle")
	changed.fire_interval = 99.0
	changed.name = "Changed by caller"
	changed.erase("rarity")
	_check(Content.definition("pulse_rifle") == original, "Editing a returned definition cannot corrupt later gameplay lookups")
	var catalog: Array = Content.weapons()
	catalog[0].fire_interval = 88.0
	_check(Content.definition("pulse_rifle") == original, "Editing a catalog cannot corrupt indexed item definitions")
	_check(Content.definition("not-an-item").is_empty(), "Unknown item definitions remain empty")

func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _cover(id: String, condition: bool, message: String) -> void:
	exercised[id] = true
	_check(condition, id + ": " + message)

func _fresh(item: String = "", count: int = 1):
	var simulation = Simulation.new()
	var roster: Array = []
	for index in range(count):
		roster.append({"id": index + 1, "name": "Content probe", "character": "ranger"})
	simulation.start_run(roster, 20261005)
	for player in simulation.state.players.values():
		player.invuln = 9999.0
	if not item.is_empty():
		simulation._grant_item(simulation.state.players[1], item)
	return simulation

func _dummy(simulation, offset: Vector2 = Vector2(100, 0)) -> Dictionary:
	var enemy: Dictionary = simulation._spawn_enemy("crawler", simulation.state.players[1].pos + offset)
	enemy.hp = 100000.0
	enemy.max_hp = 100000.0
	return enemy

func _advance(simulation, ticks: int) -> void:
	for tick in range(ticks):
		simulation.step(DT, {})

func _test_rarity_contract() -> void:
	var seen: Dictionary = {}
	var colors: Dictionary = {}
	var complete: bool = true
	for definition in Simulation.item_catalog() + Simulation.weapon_catalog() + Simulation.equipment_catalog():
		var rarity: String = definition.rarity
		complete = complete and rarity in ["common", "uncommon", "rare", "legendary"] and not str(Content.rarity_name(rarity)).is_empty() and definition.color == Content.rarity_color(rarity)
		seen[rarity] = true
		colors[Content.rarity_color(rarity)] = true
	_check(complete and seen.size() == 4 and colors.size() == 4, "All 43 items use one consistent four-tier rarity name/color contract")

func _test_core_relics() -> void:
	var base = _fresh()
	var fast = _fresh("overclock")
	base._fire_weapon(base.state.players[1])
	fast._fire_weapon(fast.state.players[1])
	_cover("overclock", fast.state.players[1].fire_cd < base.state.players[1].fire_cd, "ordinary attacks recover faster")
	var damage = _fresh("capacitor")
	damage._fire_weapon(damage.state.players[1])
	_cover("capacitor", damage.state.projectiles[0].damage > base.state.projectiles[0].damage, "actual weapon projectiles deal more damage")
	var healthy = _fresh("vitality")
	_cover("vitality", healthy.state.players[1].max_hp > base.state.players[1].max_hp and healthy.state.players[1].hp > base.state.players[1].hp, "acquisition increases real maximum and current health")
	var swift = _fresh("thruster")
	var a: Dictionary = base.state.players[1].duplicate(true)
	var b: Dictionary = swift.state.players[1].duplicate(true)
	for tick in range(60):
		base.predict_player(a, {"move": 1.0}, DT)
		swift.predict_player(b, {"move": 1.0}, DT)
	base.predict_player(a, {"move": 1.0, "dash": true}, DT)
	swift.predict_player(b, {"move": 1.0, "dash": true}, DT)
	_cover("thruster", b.pos.x > a.pos.x and b.dash_cd < a.dash_cd, "movement gains distance and dash cooldown is shorter")
	var wing = _fresh("feather")
	var jumper: Dictionary = wing.state.players[1]
	wing.predict_player(jumper, {"jump": true}, DT)
	for tick in range(20): wing.predict_player(jumper, {}, DT)
	var falling_speed: float = jumper.vel.y
	wing.predict_player(jumper, {"jump": true}, DT)
	_cover("feather", jumper.vel.y < falling_speed - 100.0 and jumper.jumps == 2, "a second airborne jump changes the player's actual velocity")
	var glass = _fresh("glass")
	glass._fire_weapon(glass.state.players[1])
	_cover("glass", glass.state.players[1].max_hp < base.state.players[1].max_hp and glass.state.projectiles[0].damage > base.state.projectiles[0].damage, "the risk trades actual maximum health for real projectile damage")
	var moss = _fresh("moss")
	moss.state.players[1].hp = 20.0
	_advance(moss, 120)
	_cover("moss", moss.state.players[1].hp > 20.5, "health regenerates during real simulation ticks")
	var siphon = _fresh("siphon")
	siphon.state.players[1].hp = 20.0
	var prey: Dictionary = _dummy(siphon)
	prey.hp = 1.0
	siphon._damage_enemy(prey, 5.0, 1, false, 0)
	_cover("siphon", siphon.state.players[1].hp > 20.0, "a real kill restores health")
	var cool = _fresh("coolant")
	base._use_skill(base.state.players[1])
	cool._use_skill(cool.state.players[1])
	_cover("coolant", cool.state.players[1].skill_cd < base.state.players[1].skill_cd, "using active equipment starts a shorter real cooldown")
	var crit_base = _fresh()
	var lens = _fresh("lens")
	lens.state.players[1].items.lens = 8
	var normal_target: Dictionary = _dummy(crit_base)
	var lens_target: Dictionary = _dummy(lens)
	for index in range(200):
		crit_base._damage_enemy(normal_target, 10.0, 1, true, 0)
		lens._damage_enemy(lens_target, 10.0, 1, true, 0)
	_cover("lens", 100000.0 - lens_target.hp > (100000.0 - normal_target.hp) * 1.3, "critical hits measurably increase repeated real hit damage")

func _test_utility_relics() -> void:
	var bare = _fresh()
	var armored = _fresh("plating")
	for simulation in [bare, armored]:
		simulation.state.players[1].invuln = 0.0
		simulation._damage_player(simulation.state.players[1], 20.0, simulation.state.players[1].pos)
	_cover("plating", armored.state.players[1].hp > bare.state.players[1].hp and armored.state.players[1].hp < armored.state.players[1].max_hp, "armor reduces an incoming hit without erasing it")
	var plain = _fresh()
	var magnet = _fresh("magnet")
	for simulation in [plain, magnet]:
		var coin: Dictionary = simulation._spawn_pickup(simulation.state.players[1].pos + Vector2(165, 14), "coin", "", 10)
		coin.vel = Vector2.ZERO
		_advance(simulation, 90)
	_cover("magnet", magnet.state.players[1].coins > plain.state.players[1].coins, "a coin beyond baseline attraction range is actually collected")
	var harvest = _fresh("harvest", 2)
	var farmer: Dictionary = harvest.state.players[1]
	var before: int = farmer.coins
	harvest._spawn_pickup(farmer.pos, "coin", "", 20)
	_advance(harvest, 10)
	_cover("harvest", farmer.coins - before > 20 and farmer.coins == harvest.state.players[2].coins, "coin pickup grants a larger reward shared with the teammate")
	var battery = _fresh("battery")
	battery.state.players[1].hurt_timer = 6.0
	_advance(battery, 60)
	var early_shield: float = battery.state.players[1].shield
	_advance(battery, 480)
	_cover("battery", early_shield == 0.0 and battery.state.players[1].shield > 0.0 and battery.state.players[1].shield <= battery.state.players[1].max_hp * 0.6, "shield regenerates only after the recovery delay and respects its health-relative limit")
	var momentum = _fresh("momentum")
	momentum.step(DT, {1: {"dash": true, "aim": Vector2.RIGHT}})
	momentum._fire_weapon(momentum.state.players[1])
	var boosted: float = momentum.state.projectiles.back().damage
	momentum.state.projectiles.clear()
	_advance(momentum, 100)
	momentum._fire_weapon(momentum.state.players[1])
	_cover("momentum", boosted > momentum.state.projectiles.back().damage, "dashing grants a temporary actual damage boost which expires")
	var phoenix = _fresh("phoenix")
	var survivor: Dictionary = phoenix.state.players[1]
	survivor.invuln = 0.0
	phoenix._damage_player(survivor, 10000.0, survivor.pos)
	var survived: bool = not survivor.dead and survivor.hp > 0.0 and survivor.invuln > 0.0
	survivor.invuln = 0.0
	phoenix._damage_player(survivor, 10000.0, survivor.pos)
	_cover("phoenix", survived and survivor.dead, "one relic prevents exactly one lethal hit before its per-stage charge is spent")

func _test_cooperative_magnet() -> void:
	for kind in ["coin", "heal"]:
		var simulation = _fresh("magnet", 2)
		var first: Dictionary = simulation.state.players[1]
		var second: Dictionary = simulation.state.players[2]
		first.items.magnet = 2
		first.pos = Vector2(1000, simulation.state.floor_y - 21)
		second.pos = first.pos + Vector2(20, 0)
		first.hp = 50.0
		second.hp = 50.0
		var pickup: Dictionary = simulation._spawn_pickup(first.pos + Vector2(180, 14), kind, "", 4)
		pickup.vel = Vector2.ZERO
		simulation._step_pickups(DT)
		_check(pickup.pos.x < 1180.0, "A closer teammate outside their own pickup range cannot block the eligible magnet holder from attracting " + kind)

func _test_proc_relics() -> void:
	var arc = _fresh("arc")
	var arc_main: Dictionary = _dummy(arc)
	var arc_neighbor: Dictionary = _dummy(arc, Vector2(160, 0))
	for hit in range(80): arc._damage_enemy(arc_main, 1.0, 1, true, 0)
	_cover("arc", arc_neighbor.hp < 100000.0, "direct hits damage a nearby secondary target through chain lightning")
	var ember = _fresh("ember")
	var ember_main: Dictionary = _dummy(ember)
	var ember_neighbor: Dictionary = _dummy(ember, Vector2(170, 0))
	ember_main.hp = 1.0
	ember._damage_enemy(ember_main, 2.0, 1, false, 0)
	_cover("ember", ember_neighbor.hp < 100000.0, "killing a target damages a nearby enemy through its explosion")
	var unchilled = _fresh()
	var frost = _fresh("frost")
	var moving: Dictionary = _dummy(unchilled, Vector2(300, 0))
	var chilled: Dictionary = _dummy(frost, Vector2(300, 0))
	unchilled._damage_enemy(moving, 1.0, 1, true, 0)
	frost._damage_enemy(chilled, 1.0, 1, true, 0)
	var initial_x: float = chilled.pos.x
	_advance(unchilled, 60)
	_advance(frost, 60)
	_cover("frost", absf(chilled.pos.x - initial_x) < absf(moving.pos.x - initial_x), "a directly hit enemy covers less real distance while chilled")
	var toxin = _fresh("toxin")
	var poisoned: Dictionary = _dummy(toxin)
	toxin._damage_enemy(poisoned, 1.0, 1, true, 0)
	var after_hit: float = poisoned.hp
	_advance(toxin, 120)
	_cover("toxin", poisoned.hp < after_hit - 1.0, "a direct hit causes additional damage over subsequent simulation ticks")
	var echo = _fresh("echo")
	var echo_target: Dictionary = _dummy(echo)
	for shot in range(5): echo._fire_weapon(echo.state.players[1])
	var before_sixth: float = echo_target.hp
	echo._fire_weapon(echo.state.players[1])
	_cover("echo", before_sixth == 100000.0 and echo_target.hp < before_sixth, "the sixth attack adds an automatic damaging echo without projectile simulation")
	var piercing = _fresh("piercer")
	var front: Dictionary = _dummy(piercing, Vector2(65, 0))
	var back: Dictionary = _dummy(piercing, Vector2(130, 0))
	piercing._fire_weapon(piercing.state.players[1])
	for tick in range(15): piercing._step_projectiles(DT)
	_cover("piercer", front.hp < 100000.0 and back.hp < 100000.0, "an ordinary bullet damages a second target instead of disappearing after the first")
	var resonator = _fresh("resonator")
	resonator.state.players[1].items.resonator = 5
	var beyond: Dictionary = _dummy(resonator, Vector2(145, 0))
	resonator._explode(resonator.state.players[1].pos, 100.0, 10.0, 1, "player", 0)
	_cover("resonator", beyond.hp < 100000.0, "a damage explosion reaches an enemy beyond its unmodified radius")
	for count in [0, 1, 6, 100]:
		var area = _fresh()
		area.state.players[1].items.resonator = count
		var reach: float = 100.0 if count == 0 else (130.0 if count == 1 else 180.0)
		# Circle collision includes the crawler's 19px body radius.
		var inside: Dictionary = _dummy(area, Vector2(reach + 18.0, 0))
		var outside: Dictionary = _dummy(area, Vector2(reach + 20.0, 0))
		area._explode(area.state.players[1].pos, 100.0, 10.0, 1, "player", 0)
		_check(inside.hp < 100000.0 and outside.hp == 100000.0, "Resonator %d-stack real explosion includes its intended radius and excludes targets just beyond it" % count)
	var nova = _fresh("nova")
	nova.state.players[1].items.lens = 20
	var primary: Dictionary = _dummy(nova)
	var neighbor: Dictionary = _dummy(nova, Vector2(175, 0))
	for hit in range(20): nova._damage_enemy(primary, 1.0, 1, true, 0)
	var damage_done: float = 100000.0 - neighbor.hp
	for hit in range(20): nova._damage_enemy(primary, 1.0, 1, true, 0)
	_cover("nova", damage_done > 0.0 and is_equal_approx(100000.0 - neighbor.hp, damage_done), "critical hits create a damaging nova whose internal cooldown prevents immediate recursive spam")

func _test_advanced_weapons() -> void:
	# The existing loot suite verifies aimed blade healing, six-pellet spread,
	# rail piercing and basic rifle fire. Exercise each here through a real hit.
	for id in ["pulse_rifle", "arc_blade", "scattergun", "railgun", "flamethrower", "boomerang", "storm_staff", "sun_lance", "arc_needle", "star_seeker"]:
		var simulation = _fresh()
		var player: Dictionary = simulation.state.players[1]
		player.weapon = id
		var enemy: Dictionary = _dummy(simulation, Vector2(70, 0))
		simulation._fire_weapon(player)
		if id == "arc_blade":
			simulation._step_melee(player, WeaponPose.melee_impact_time(float(player.melee.duration)))
		for tick in range(30): simulation._step_projectiles(DT)
		_cover(id, enemy.hp < 100000.0 and player.fire_cd > 0.0, "the equipped weapon actually damages its aimed target and starts its own cadence")
	var common = _fresh()
	var legendary = _fresh()
	legendary.state.players[1].weapon = "sun_lance"
	common._fire_weapon(common.state.players[1])
	legendary._fire_weapon(legendary.state.players[1])
	_check(legendary.state.projectiles[0].damage / legendary.state.players[1].fire_cd > common.state.projectiles[0].damage / common.state.players[1].fire_cd * 1.5, "The legendary lance has materially higher real damage per cadence than the common starter rifle")
	var flames = _fresh()
	flames.state.players[1].weapon = "flamethrower"
	var burned: Dictionary = _dummy(flames, Vector2(90, 0))
	var behind: Dictionary = _dummy(flames, Vector2(-90, 0))
	flames._fire_weapon(flames.state.players[1])
	var immediate_hp: float = burned.hp
	_advance(flames, 60)
	_check(immediate_hp < 100000.0 and burned.hp < immediate_hp and behind.hp == 100000.0, "Flamethrower applies aimed cone damage and lingering burn without hitting behind its wielder")
	var returning = _fresh()
	returning.state.players[1].weapon = "boomerang"
	var return_target: Dictionary = _dummy(returning, Vector2(100, 0))
	returning._fire_weapon(returning.state.players[1])
	for tick in range(15): returning._step_projectiles(DT)
	var outbound_hp: float = return_target.hp
	for tick in range(80): returning._step_projectiles(DT)
	_check(outbound_hp < 100000.0 and return_target.hp < outbound_hp, "Boomerang can damage a target again on its actual return flight")
	var storm = _fresh()
	storm.state.players[1].weapon = "storm_staff"
	var chain: Array = [_dummy(storm, Vector2(80, 0)), _dummy(storm, Vector2(145, 35)), _dummy(storm, Vector2(180, -35))]
	storm._fire_weapon(storm.state.players[1])
	for tick in range(30): storm._step_projectiles(DT)
	_check(chain[0].hp < 100000.0 and chain[1].hp < 100000.0 and chain[2].hp < 100000.0, "Storm staff's impact chains real damage to two off-axis neighboring targets")
	var sun = _fresh()
	sun.state.players[1].weapon = "sun_lance"
	_dummy(sun, Vector2(80, 0))
	var splash: Dictionary = _dummy(sun, Vector2(85, 50))
	sun._fire_weapon(sun.state.players[1])
	for tick in range(20): sun._step_projectiles(DT)
	_check(splash.hp < 100000.0, "Sun lance hits release real blast damage outside the projectile's direct line")
	var full_pierce = _fresh("piercer")
	full_pierce.state.players[1].items.piercer = 9
	full_pierce.state.players[1].weapon = "sun_lance"
	full_pierce._fire_weapon(full_pierce.state.players[1])
	_check(full_pierce.state.projectiles[0].pierce == 9, "Legendary lance gains all three relic pierces beyond its six baseline targets, with a bounded total")
	var full_return = _fresh("piercer")
	full_return.state.players[1].items.piercer = 9
	full_return.state.players[1].weapon = "boomerang"
	var victims: Array = []
	for index in range(7): victims.append(_dummy(full_return, Vector2(60 + index * 34, 0)))
	full_return._fire_weapon(full_return.state.players[1])
	_check(full_return.state.projectiles[0].pierce == 7, "Boomerang receives all three extra pierces beyond its four baseline targets")
	var outbound_damage: Array[float] = []
	for tick in range(60):
		full_return._step_projectiles(DT)
		if not full_return.state.projectiles.is_empty() and full_return.state.projectiles[0].pierce == 0:
			for victim in victims: outbound_damage.append(float(victim.hp))
			break
	for tick in range(90): full_return._step_projectiles(DT)
	var returned_to_all: bool = outbound_damage.size() == 7
	for index in range(outbound_damage.size()):
		returned_to_all = returned_to_all and outbound_damage[index] < 100000.0 and victims[index].hp < outbound_damage[index]
	_check(returned_to_all, "Exhausting all seven outbound boomerang hits still restores its pierce budget and damages those targets again on return")

func _test_advanced_equipment() -> void:
	# More detailed delayed, support and crowd-control assertions are kept here
	# alongside ordinary damage, so catalogue-only additions cannot pass.
	for id in ["grenade", "shockwave", "repair_field", "aegis", "graviton", "turret", "meteor", "time_warp", "hunting_beacon"]:
		var simulation = _fresh("", 2)
		var player: Dictionary = simulation.state.players[1]
		player.equipment = id
		player.hp = 30.0
		var ally: Dictionary = simulation.state.players[2]
		ally.pos = player.pos + Vector2(60, 0)
		ally.hp = 30.0
		var enemy: Dictionary = _dummy(simulation, Vector2(260 if id in ["graviton", "meteor"] else 100, 0))
		var origin: Vector2 = enemy.pos
		simulation._use_skill(player)
		var cooldown_started: bool = player.skill_cd > 0.0
		var useful: bool = false
		match id:
			"repair_field": useful = player.hp > 30.0 and ally.hp > 30.0
			"aegis": useful = player.shield > 0.0
			"time_warp":
				var reference = _fresh()
				reference._fire_weapon(reference.state.players[1])
				simulation._fire_weapon(player)
				simulation._fire_weapon(ally)
				useful = player.fire_cd < reference.state.players[1].fire_cd and ally.fire_cd < reference.state.players[1].fire_cd
			"graviton": useful = enemy.hp < 100000.0 and Vector2(enemy.pos).distance_to(origin) > 1.0
			_:
				_advance(simulation, 180)
				useful = enemy.hp < 100000.0
		_cover(id, useful and cooldown_started, "using the active produces its real damage, control, shield or cooperative support effect")

func _test_conditional_relics() -> void:
	var missile = _fresh("missile_pod")
	missile.state.players[1].items.lens = 100
	var target: Dictionary = _dummy(missile, Vector2(180, 0))
	for index: int in range(12): missile._damage_enemy(target, 1.0, 1, true, 0)
	var spawned: bool = missile.state.projectiles.size() == 1 and missile.state.projectiles[0].kind == "seeker_missile"
	var before: float = target.hp
	for tick: int in range(100): missile._step_projectiles(DT)
	_cover("missile_pod", spawned and is_equal_approx(before - float(target.hp), 18.0), "a direct critical hit launches a real noncritical guided missile")
	var landing = _fresh("landing_coil")
	var waves: bool = false
	for tick: int in range(90):
		landing._step_player(landing.state.players[1], {"jump": tick == 0, "jump_held": true}, DT)
		waves = waves or (landing.state.projectiles.size() == 2 and landing.state.projectiles[0].kind == "shock_wave")
	var struck: Dictionary = _dummy(landing, Vector2(60, 10))
	for tick: int in range(30): landing._step_projectiles(DT)
	_cover("landing_coil", waves and struck.hp == 99988.0, "a full-height landing creates actual horizontal impact damage")
	var frost = _fresh("frost_halo")
	var victim: Dictionary = _dummy(frost, Vector2(80, 0)); victim.hp = 1
	var neighbor: Dictionary = _dummy(frost, Vector2(100, 0))
	frost._damage_enemy(victim, 5.0, 1, true, 0)
	for tick: int in range(90): frost._step_proc_effects(DT)
	_cover("frost_halo", neighbor.hp == 99976.0 and neighbor.slow_factor == 0.75, "a direct kill creates three bounded slowing aura damage pulses")
