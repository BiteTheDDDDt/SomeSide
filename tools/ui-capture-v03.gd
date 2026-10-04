extends SceneTree

var game: Node

func _initialize() -> void:
	call_deferred("_run")

func _capture(name_text: String) -> void:
	for index in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://tools/results/v03-" + name_text + ".png"
	root.get_texture().get_image().save_png(path)
	print("UI_CAPTURE ", path)

func _alt(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ALT
	event.physical_keycode = KEY_ALT
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	game.set("_smoke", "ui")
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game._show_guide()
	await _capture("guide")
	game._start_solo()
	game.set_physics_process(false)
	game._notice_time = 0
	game._notice.text = ""
	game.world.camera_position = Vector2(640, 740)
	await _capture("start")
	var player: Dictionary = game.sim.state.players[1]
	player.pos = Vector2(1020, 639)
	player.weapon = "railgun"
	player.equipment = "repair_field"
	player.skill_cd = 12.6
	player.coins = 82
	player.items = {"overclock": 3, "feather": 1, "lens": 2, "moss": 1, "capacitor": 2, "siphon": 1}
	game.sim.state.pickups.clear()
	game.world.camera_position = player.pos
	game._update_hud()
	await _capture("field")
	game.sim._spawn_pickup(player.pos + Vector2(58, 2), "item", "glass", 1)
	await _capture("loot")
	_alt(true)
	await _capture("inspect")
	print("DETAIL_LAYOUT ", game._loot_ui.description.text, " size=", game._loot_ui.description.size, " minimum=", game._loot_ui.description.get_combined_minimum_size(), " lines=", game._loot_ui.description.get_line_count(), " visible_lines=", game._loot_ui.description.get_visible_line_count())
	_alt(false)
	await _capture("collapsed")
	game._show_inventory()
	await _capture("inventory")
	game._resume()
	game.sim.state.pickups.clear()
	game.sim._spawn_pickup(player.pos + Vector2(58, 2), "item", "scattergun", 1)
	await _capture("weapon")
	game.sim.state.pickups.clear()
	for facility in ["blood", "choice", "combat"]:
		for chest in game.sim.state.chests:
			if chest.type == facility:
				player.pos = chest.pos + Vector2(-32, -4)
				game.world.camera_position = player.pos
				break
		await _capture(facility)
	game.sound.shutdown()
	await create_timer(0.15).timeout
	quit()
