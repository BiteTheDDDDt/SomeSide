extends SceneTree

## Directed loadouts/loot using the production HUD and WorldView.
## No changes to the profile, gameplay resources, or source textures.
const Locale = preload("res://scripts/localization.gd")
const DIRECTORY: String = "res://tools/results/gear-v0181/"
var viewport: SubViewport
var game: Node

func _initialize() -> void: _run.call_deferred()

func _save(name: String) -> void:
	game.world.queue_redraw()
	for tick: int in range(4): await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(DIRECTORY + name + ".png") == OK)
	print("GEAR_CAPTURE ", name)

func _run() -> void:
	if DisplayServer.get_name() == "headless": quit(2); return
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	var existed: bool = FileAccess.file_exists("user://profile.cfg")
	var saved: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if existed else PackedByteArray()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game = load("res://main.tscn").instantiate()
	game.set("_smoke", "gear-capture")
	viewport.add_child(game)
	game.set_process(false); game.set_physics_process(false); game.world.set_process(false)
	game.sound.shutdown()
	game.profile.show_fps = false
	game.world.shake_enabled = false
	game.world.scenery_cache_enabled = false
	for language: String in ["zh", "en"]:
		Locale.set_language(language)
		game.profile.language = language
		game._begin_local([{"id":1, "name":"", "character":"ranger"}, {"id":2, "name":"", "character":"vanguard"}], 18018)
		game.sim.state.enemies.clear()
		game.sim.state.chests.clear()
		game.sim.state.time = 136.0
		var player: Dictionary = game.sim.state.players[1]
		var teammate: Dictionary = game.sim.state.players[2]
		player.pos = Vector2(2320, 1079)
		teammate.pos = Vector2(2180, 1079)
		player.weapon = "pulse_rifle"
		player.equipment = "graviton"
		teammate.weapon = "arc_blade"
		player.items = {"overclock":2,"feather":1,"arc":1,"lens":1,"vitality":2,"magnet":1,"plating":1}
		teammate.items = {"capacitor":1,"echo":1,"battery":1,"thruster":1,"coolant":1,"momentum":1}
		for actor: Dictionary in game.sim.state.players.values():
			actor.vel = Vector2.ZERO
			actor.aim = Vector2(1, -.12).normalized()
			actor.grounded = true
			actor.invuln = 0.0
			actor.coins = 268
		for index: int in range(6):
			var id: String = ["railgun", "coolant", "feather", "graviton", "phoenix", "sun_lance"][index]
			var loot: Dictionary = game.sim._spawn_pickup(Vector2(2385 + index * 57, 1093), "item", id, 1)
			loot.vel = Vector2.ZERO
			loot.age = 3.0
		game._notice.text = ""
		game._notice_time = 0.0
		game._fps_label.visible = false
		game.world.set_frame(game.sim.get_snapshot(), 1, 1.0)
		game.world.camera_position = Vector2(2420, 950)
		game.world._clock = 2.7
		game._update_hud()
		game._refresh_interaction_focus()
		game.world.interaction_target = game._focus_target
		game._update_interaction_panel(player)
		await _save("in-game-" + language)
		game._show_inventory()
		await _save("loadout-" + language)
		game._populate_inventory("weapon")
		await _save("weapons-" + language)
		game._resume()
		var saved_pickups: Array = game.sim.state.pickups.duplicate(true)
		game.sim.state.pickups.clear()
		_stage_shop()
		player.pos.x = 2375
		game.world.set_frame(game.sim.get_snapshot(), 1, 1.0)
		game.world.camera_position = Vector2(2420,950)
		game._refresh_interaction_focus()
		game.world.interaction_target = game._focus_target
		game._update_interaction_panel(player)
		await _save("choice-shop-" + language)
		game.sim.state.pickups = saved_pickups
		game.sim.state.chests.clear()
		player.pos.x = 2320
		game.world.set_frame(game.sim.get_snapshot(), 1, 1.0)
	# Same live world, a 2x closer camera for art review. No HUD enlargement.
	game.ui.visible = false
	viewport.size_2d_override = Vector2i(640, 360)
	viewport.size_2d_override_stretch = true
	game.world.screen_size = Vector2(640, 360)
	game.world.camera_position = Vector2(2420, 993)
	game.world.interaction_target = {}
	await _save("world-detail-2x")
	game.sim.state.pickups.clear()
	_stage_shop()
	game.world.set_frame(game.sim.get_snapshot(), 1, 1.0)
	game.world.camera_position = Vector2(2420,993)
	game.world.interaction_target = {}
	await _save("choice-detail-2x")
	var current: PackedByteArray = FileAccess.get_file_as_bytes("user://profile.cfg") if FileAccess.file_exists("user://profile.cfg") else PackedByteArray()
	assert(existed == FileAccess.file_exists("user://profile.cfg") and current == saved, "Capture must preserve player preferences")
	game.queue_free(); await process_frame
	print("GEAR_CAPTURE_RESULT captures=10 native=true profile_unchanged=true")
	quit(0)

func _stage_shop() -> void:
	game.sim.state.chests.clear()
	for index: int in range(3):
		var chest: Dictionary = game.sim._make_chest("choice",Vector2(2420+index*74,1083),45,["scattergun","feather","graviton"][index])
		chest.group = 1801
		game.sim.state.chests.append(chest)
