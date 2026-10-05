extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
const Content = preload("res://scripts/content.gd")
const Locale = preload("res://scripts/localization.gd")
const Icons = preload("res://scripts/item_icons.gd")
const Sound = preload("res://scripts/soundscape.gd")
const World = preload("res://scripts/world_view.gd")
var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _labels(node: Node) -> String:
	var text: String = node.text + "\n" if node is Label else ""
	for child in node.get_children(): text += _labels(child)
	return text

func _run() -> void:
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	var game = load("res://main.tscn").instantiate()
	game._smoke = "ability-feedback"
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.world.set_process(false)
	game.sound.shutdown()
	for language: String in ["zh", "en"]:
		Locale.set_language(language)
		for character: String in ["ranger", "vanguard"]:
			game.profile.character = character
			game._begin_local([{"id":1,"name":"Ability UI","character":character}],1601)
			var player: Dictionary = game.sim.state.players[1]
			var ability: Dictionary = Simulation.movement_ability(player)
			game._update_hud()
			var slot: Dictionary = game._slot_ui.dash
			_check(str(slot.id) == str(ability.id) and slot.name.text == Locale.text(str(ability.name)), "%s %s HUD names its own innate ability" % [language,character])
			_check(slot.icon.texture == Icons.texture(str(ability.id),72), "The role's Shift icon comes from its actual ability")
			player.items.thruster = 3
			ability = Simulation.movement_ability(player)
			player.dash_cd = float(ability.cooldown) * 0.5
			game._update_hud()
			_check(is_equal_approx(float(slot.bar.value),50.0) and slot.cooldown.text == str(ceili(float(player.dash_cd))), "HUD cooldown uses the role and its thruster-adjusted duration")
			player.weapon = "railgun"
			player.equipment = "aegis"
			var snapshot: PackedByteArray = var_to_bytes(game.sim.state)
			game._update_hud()
			_check(str(slot.id) == str(ability.id) and snapshot == var_to_bytes(game.sim.state), "Equipment changes cannot replace or reset the innate ability through HUD rendering")
		game._show_characters()
		var selection: String = _labels(game.ui)
		_check(selection.contains(Locale.text("相位闪身")) and selection.contains(Locale.text("破阵突进")), "Character selection explains both distinct abilities in " + language)
		game._show_guide()
		_check(_labels(game.ui).contains(Locale.text("角色技能：游侠闪身，先锋向前突进")), "The Shift guide explains role-specific controls in " + language)
		game._show_inventory()
		var ability_details: Dictionary = Simulation.movement_ability(game.sim.state.players[1])
		_check(_labels(game.ui).contains(Locale.text(str(ability_details.description))), "The build screen exposes innate ability mechanics and base cooldown in " + language)
	_check(Icons.texture("phase_dash",72).get_image().get_data() != Icons.texture("shoulder_rush",72).get_image().get_data(), "The two role icons have different silhouettes and colours")
	var sound := Sound.new()
	sound.enabled = false
	root.add_child(sound)
	_check(Sound.event_sound({"type":"dash","ability":"phase_dash"}) == "dash" and Sound.event_sound({"type":"dash","ability":"shoulder_rush"}) == "ability_shoulder_rush", "Phase dash and shoulder rush route to different movement sounds")
	_check(Sound.event_sound({"type":"ability_hit","ability":"shoulder_rush"}) == "ability_shoulder_hit" and Sound.event_sound({"type":"dash","enemy":true,"ability":"shoulder_rush"}) == "enemy_shift", "Shoulder impact has a distinct cue without changing enemy dash audio")
	_check(sound._streams.dash.data != sound._streams.ability_shoulder_rush.data and sound._streams.ability_shoulder_rush.data != sound._streams.ability_shoulder_hit.data, "Role activation and collision use distinct actual PCM samples")
	var simulation = Simulation.new()
	simulation.start_run([{"id":1,"name":"Audio","character":"vanguard"}],1602)
	simulation.state.world_size = Vector2(2400,1100)
	simulation.state.floor_y = 1000.0
	simulation.state.platforms = [Rect2(0,1000,2400,60)]
	simulation.state.enemies.clear()
	var actor: Dictionary = simulation.state.players[1]
	actor.pos = Vector2(800,979)
	actor.grounded = true
	actor.invuln = 0.0
	for index: int in range(3):
		var enemy: Dictionary = simulation._spawn_enemy("crawler",actor.pos+Vector2(27+index,0))
		enemy.hp = 10000.0
	simulation.step(1.0/60.0,{1:{"dash":true,"jump":true,"jump_held":true}})
	sound.enabled = true
	sound.wait_for_gesture = false
	var accepted: Dictionary = {}
	var impact_events: int = 0
	for event: Dictionary in simulation.events:
		var key: String = Sound.event_sound(event)
		if key == "ability_shoulder_hit": impact_events += 1
		if sound.play_game_event(event): accepted[key] = int(accepted.get(key,0)) + 1
	_check(accepted.has("jump") and accepted.has("ability_shoulder_rush"), "A real jump-and-rush batch keeps the role activation cue after its jump cue")
	_check(accepted.has("hit") and int(accepted.get("ability_shoulder_hit",0)) == 1 and impact_events == 3, "Real damage followed by three ability impacts plays the unique cue once without generic-hit suppression or stacking noise")
	sound.shutdown()
	sound.queue_free()
	var view := World.new()
	root.add_child(view)
	view.set_process(false)
	var events: Array = [{"type":"dash","ability":"phase_dash","pos":Vector2(50,50),"aim":Vector2.RIGHT}, {"type":"dash","ability":"shoulder_rush","pos":Vector2(50,50),"aim":Vector2.RIGHT}, {"type":"ability_hit","ability":"shoulder_rush","pos":Vector2(60,50),"aim":Vector2.RIGHT}]
	var before: PackedByteArray = var_to_bytes(events)
	view.push_events(events)
	var kinds: Array = view._effects.map(func(effect: Dictionary): return effect.kind)
	_check(kinds.has("dash") and kinds.has("rush") and kinds.has("rush_hit"), "Distinct event families create phase trails, rush fronts and collision arcs")
	_check(before == var_to_bytes(events), "Ability presentation leaves gameplay event payloads untouched")
	view.queue_free()
	game.queue_free()
	await process_frame
	var after: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if FileAccess.file_exists("user://profile.cfg") else PackedByteArray()
	_check(FileAccess.file_exists("user://profile.cfg") == existed and saved == after, "UI and feedback checks do not write the user's profile")
	print("ABILITY_FEEDBACK_TEST_RESULT passed=%d failed=%d" % [passed,failed])
	quit(0 if failed == 0 else 1)
